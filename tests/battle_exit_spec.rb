# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
load 'BS2QA_exit_helpers.rb'
begin
  File.open('test_result.txt','w') { |f| f.puts 'battle exit probe '+BS2Suite::VERSION }
  DataManager.init
  ExitProbe.log('native damaging quick skills='+$data_skills.compact.select { |s| BS2Suite::ActionRules.quick?(s) && [1,2,5,6].include?(s.damage.type) }.map { |s| [s.id,s.name] }.inspect)
  checks=0
  modes=[['no_ctrl',false,0],['checkbox_on_no_ctrl',false,1],['stock_ctrl',true,0],['instant_ctrl',true,1]]
  modes.each do |mode,ctrl,instant|
  ExitProbe.ctrl=ctrl;BS2Suite::Options.set('instant_battle_ctrl',instant)
  cases=['ordinary_quick','native_quick_skill']
  cases+=['macro_free','macro_before','macro_after','macro_priority_fault'] if defined?(BS2Suite::Macros)
  cases.each do |name|
    actor=setup_battle;gold=$game_party.gold;error=nil;reason=nil
    begin
      if ['ordinary_quick','native_quick_skill'].include?(name)
        object=$data_items[5002]
        if name=='native_quick_skill'
          object=$data_skills[932];actor.learn_skill(object.id);actor.recover_all;$game_troop.members[0].hp=1
          ExitProbe.log('native_quick_skill_usable='+actor.usable?(object).to_s+' formula='+object.damage.formula)
          actor.input.set_skill(object.id)
        else;actor.input.set_item(5002);end
        actor.input.target_index=0;@scene.instance_variable_set(:@hzm_vxa_quickSkill_skill,object);@scene.next_command
        ExitProbe.log('before_native_update '+{:victories=>ExitProbe.victories,:phase=>BattleManager.instance_variable_get(:@phase),:in_battle=>$game_party.in_battle,:scene_changing=>@scene.scene_changing?}.inspect)
        @scene.update
      else
        rows=[row('item',5002),row('item',5003)]
        if name=='macro_before';rows=[row('item',5002),row('skill',5004)]
        elsif name=='macro_after';rows=[row('skill',5004),row('item',5002),row('item',5003)];end
        ExitProbe.inject_priority=name=='macro_priority_fault'
        set={'name'=>'QA exit sequence','key'=>1,'rows'=>rows}
        actor.instance_variable_set(:@action_input_index,0)
        reason=BS2Suite::Macros.commit(@scene,actor,set,0)
        if ['macro_before','macro_after'].include?(name)
          @scene.process_action
        end
      end
    rescue Exception=>e
      error=e.class.to_s+': '+e.message;ExitProbe.log(e.backtrace.take(8).join("\n"))
    end
    ExitProbe.log('CASE '+name+' '+{:victories=>ExitProbe.victories,:battle_end_calls=>ExitProbe.ends,:phase=>BattleManager.instance_variable_get(:@phase),:in_battle=>$game_party.in_battle,:scene_changing=>@scene.scene_changing?,:scene=>SceneManager.scene && SceneManager.scene.class.to_s,:actions=>actor.actions.map { |a| a && a.item && a.item.id },:input_index=>actor.instance_variable_get(:@action_input_index),:late_next=>ExitProbe.late_next,:steps=>ExitProbe.quick_steps,:gold_delta=>$game_party.gold-gold,:following_items_left=>$game_party.item_number($data_items[5003]),:macro_result=>reason,:error=>error}.inspect)
    if name=='macro_priority_fault'
      BattleManager.judge_win_loss
      ExitProbe.log('CASE repeat_after_priority_fault '+{:victories=>ExitProbe.victories,:gold_delta=>$game_party.gold-gold,:phase=>BattleManager.instance_variable_get(:@phase),:scene=>SceneManager.scene && SceneManager.scene.class.to_s}.inspect)
    end
    raise mode+' '+name+' unexpected error: '+error.to_s if error
    raise mode+' '+name+' must award one victory' unless ExitProbe.victories==1 && ExitProbe.ends==1 && $game_party.gold-gold==23
    raise mode+' '+name+' must return to the map' unless SceneManager.scene.is_a?(Scene_Map)
    raise mode+' '+name+' must leave the battle finalized' unless !$game_party.in_battle && BattleManager.instance_variable_get(:@phase).nil?
    raise mode+' '+name+' must not recreate finished actions' unless actor.actions.empty? && actor.instance_variable_get(:@action_input_index)==0
    raise mode+' '+name+' must not resume the next command' unless ExitProbe.late_next==0
    raise mode+' '+name+' must not execute a following instant step' unless $game_party.item_number($data_items[5003])==5 && ExitProbe.quick_steps.size<=1
    raise mode+' '+name+' must not disguise an engine error as macro rejection' unless reason.nil?
    raise mode+' '+name+' must leave QuickSkill inactive' if HZM_VXA::QuickSkill.quickSkill?
    checks+=8;ExitProbe.log('PASS '+mode+' '+name)
    ExitProbe.inject_priority=false
  end
  end
  ExitProbe.log('result=PASS; checks='+checks.to_s)
rescue Exception=>e
  ExitProbe.log('result=FAIL; '+e.class.to_s+': '+e.message);ExitProbe.log(e.backtrace.join("\n"))
ensure
  @scene.terminate if @scene
  BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  SuiteCapture.close
end
end
