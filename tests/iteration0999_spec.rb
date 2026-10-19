# encoding: UTF-8
rgss_main do
  load 'BS2QA_native_capture.rb'
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class Keys0997
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def queue(a,n=2)
    a.instance_variable_set(:@actions,Array.new(n) { Game_Action.new(a) });a.instance_variable_set(:@action_input_index,0)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  end
  def frame(keys=[]);@raw.keys=keys;Graphics.update;Input.update;end
def capture(name)
  bitmap=Graphics.snap_to_bitmap
  raw=''.force_encoding('ASCII-8BIT')
  bitmap.height.times do |y|
    raw << "\0"
    bitmap.width.times do |x|
      c=bitmap.get_pixel(x,y);raw << [c.red.to_i,c.green.to_i,c.blue.to_i,c.alpha.to_i].pack('C4')
    end
  end
  chunk=lambda { |tag,data| [data.bytesize].pack('N')+tag+data+[Zlib.crc32(tag+data)].pack('N') }
  png="\x89PNG\r\n\x1a\n".force_encoding('ASCII-8BIT')+chunk.call('IHDR',[bitmap.width,bitmap.height,8,6,0,0,0].pack('NNCCCCC'))+chunk.call('IDAT',Zlib::Deflate.deflate(raw))+chunk.call('IEND','')
  File.open(name,'wb') { |f| f.write(png) };bitmap.dispose
end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'grouped macro and sequence regressions '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
    [101,277,391].each { |id| $game_party.gain_item($data_weapons[id],1) }
    actor.change_equip(0,$data_weapons[277]);actor.recover_all
    actor.singleton_class.class_eval { def make_action_times;2;end }
    troop=RPG::Troop.new;troop.id=79
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA';enemy.battler_name='';enemy.params=[100000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@ap,ATB::MAX_AP);queue(actor)
    @raw=Keys0997.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
    BS2Suite::Options.set('knowledge_threshold',0)

    macros=BS2Suite::Macros;direct=BS2Suite::DirectWeapons
    macros.instance_variable_set(:@data,nil)
    BS2Suite::Store.write('macros',"format=1\n[#{actor.id},1]\nname=QA retained\nkey=7\nrow=guard,0,0,0\n")
    macros.instance_variable_set(:@data,nil)
    old=macros.get(actor,1);check(old['name']=='QA retained' && old['key']==7,'legacy names keys and rows belong to group one')
    row=lambda { |kind,id,source=0| {'kind'=>kind,'id'=>id,'source'=>source,'target'=>0} }
    set={'name'=>'QA second group','key'=>7,'rows'=>[row.call('guard',0)]}
    check(macros.save(actor,1,set,2),'same digit is independent across four groups')
    macros.instance_variable_set(:@data,nil)
    check(macros.get(actor,1,1)==old && macros.get(actor,1,2)==set,'grouped file roundtrip retains original group and new group')
    check(BS2Suite::Store.read('macros').include?('['+actor.id.to_s+',1,1]') && BS2Suite::Store.read('macros').include?('['+actor.id.to_s+',2,1]'),'saved format explicitly records group')
    check(!macros.save(actor,1,set,5),'fifth group refused')
    check(!macros.save(actor,9,set,2),'ninth preset refused')
    queue(actor);@scene.start_actor_command_selection
    command=@scene.instance_variable_get(:@actor_command_window);command.openness=255
    macros.open(@scene,command);picker=@scene.instance_variable_get(:@bs2s_macros)
    check(picker.records.size==2 && picker.records.all? { |n,v,e| v['macro_group'] },'battle hides the two empty groups')
    frame;frame([50]);picker.process_handling
    check(picker.instance_variable_get(:@macro_group)==2 && picker.records.size==1,'C group digit opens only populated presets')
    Graphics.transition(0);3.times { Graphics.update };capture('BS2QA_macros0999.png')
    check(picker.records[0][0].include?('ОМ') && picker.records[0][0].include?('КД'),'battle preset displays actions MP and cooldown')
    frame;frame([67]);picker.process_handling
    check(picker.instance_variable_get(:@macro_group).nil?,'C returns from preset group to group picker')
    frame;frame([67]);picker.process_handling
    check(!@scene.instance_variable_get(:@bs2s_macros) && command.active,'second C returns from group picker to battle')
    # Both confirm keys work, including an independently reassigned primary.
    frame;frame([32]);check(Input.trigger?(:C) && Input.press?(:C),'Space is an additional native-style confirm')
    frame;frame([13]);check(Input.trigger?(:C),'Enter still confirms')
    keys=BS2Suite::Keys.data;original=keys[:C];keys[:C]='J'
    frame;frame([32]);check(Input.trigger?(:C),'Space survives primary-confirm reassignment')
    frame;frame([74]);check(Input.trigger?(:C),'custom primary confirm remains functional');keys[:C]=original
    # Reset only selected, unpaid actions; already-applied consumables stay applied.
    queue(actor);actor.actions[0].set_skill(124);actor.actions[0].target_index=actor.index;actor.next_command
    instant=$data_items[61];$game_party.gain_item(instant,3);actor.hp=actor.mhp/2
    actor.use_item(instant);actor.item_apply(actor,instant)
    kept=[actor.hp,actor.mp,$game_party.item_number(instant)]
    @scene.start_actor_command_selection
    frame;@scene.prior_command;frame;@scene.prior_command
    check(actor.actions.size==2 && actor.actions.all? { |a| a.item.nil? } && actor.instance_variable_get(:@action_input_index)==0,'double command Esc resets existing paid slots without regenerating the count')
    check([actor.hp,actor.mp,$game_party.item_number(instant)]==kept,'series cancellation never undoes actual instant effects or refunds items')
    # Local executor is independent of the battle-wide nomination.
    actor.recover_all;queue(actor,1);direct.select(actor,$data_weapons[101])
    guarded={'name'=>'QA executor','key'=>2,'executor'=>391,'rows'=>[row.call('guard',0)]}
    check(macros.executor_allowed?(guarded,actor),'guard permits explicit executor')
    check(macros.save(actor,2,guarded,2),'executor selection is persisted')
    check(macros.commit(@scene,actor,guarded,0).nil?,'eligible macro commits with its own executor')
    forecast=BS2Suite::SequenceForecast.new(actor)
    check(forecast.steps[0][:weapon]==$data_weapons[391],'macro forecast uses local executor even if N nominates another weapon')
    actor.current_action.prepare
    check(actor.equips[0]==$data_weapons[391] && direct.selected_id(actor)==101,'actual guard uses preset executor without altering N nomination')
    check(!macros.executor_allowed?({'rows'=>[row.call('weapon',101)]},actor),'normal attack cannot override its explicit weapon via macro executor')
    check(!macros.executor_allowed?({'rows'=>[row.call('skill',124)]},actor),'skill row cannot acquire the item/guard-only executor setting')
    direct.clear(actor)
    # An earlier instant recovery may fund a later paid skill.
    refill=RPG::Item.new;refill.id=5001;refill.name='QA MP refill';refill.scope=11;refill.occasion=1;refill.note='[hzm]ターン消費無し:99';refill.effects=[RPG::UsableItem::Effect.new(12,0,0,50)];$data_items[5001]=refill;$game_party.gain_item(refill,1)
    spend=RPG::Skill.new;spend.id=5002;spend.name='QA MP spend';spend.scope=11;spend.mp_cost=20;$data_skills[5002]=spend;actor.learn_skill(5002)
    funded={'name'=>'QA refill then cast','key'=>3,'rows'=>[row.call('item',5001),row.call('skill',5002)]}
    queue(actor,1);actor.recover_all;actor.mp=0
    check(macros.problem(funded,actor).nil?,'current low MP does not disable a macro whose earlier instant item restores MP')
    before=$game_party.item_number(refill);macros.commit(@scene,actor,funded,0);actor.current_action.prepare
    check($game_party.item_number(refill)==before-1 && actor.current_action.valid?,'actual native preparation receives the instant MP restoration before checking the paid skill')
    # Cached rows must not grow on every render.
    queue(actor);@scene.start_actor_command_selection;BS2Suite::Semantic.sync(actor)
    BS2Suite::Palette.open(@scene,command,actor,'N');popup=BS2Suite::Palette.current(@scene);popup.acknowledge;popup.set_group(1)
    if defined?(BS2Suite::HDDisplay)
      counts=Array.new(30) { BS2Suite::HDDisplay.palette_rows(popup).count { |v| v.include?('Shift+Enter / Shift+цифра') } }
      check(counts.all? { |n| n==1 },'repeated N sidebar rendering never appends duplicate Shift hints')
    end
    BS2Suite::Palette.close(@scene)
    # Use the installed game's actual skill IDs and formula/effect metadata.
    [123,262,414,420].each { |id| $game_party.gain_item($data_weapons[id],1) }
    [108,308,494,496].each { |id| actor.learn_skill(id) }
    target=$game_troop.members[0]
    target.enemy.features=[RPG::BaseItem::Feature.new(22,1,0),RPG::BaseItem::Feature.new(23,6,1),RPG::BaseItem::Feature.new(23,7,1)]
    actor.change_level(200,false);actor.recover_all
    actor.singleton_class.send(:remove_method,:make_action_times)
    def simulate_pair(actor,first,second,weapon,scene,count)
      sum=0.0
      count.times do |seed|
        actor.clear_states;actor.remove_all_buffs;actor.recover_all;actor.cool_time.clear
        BS2QoL::Model.change_weapon(actor,weapon)
        $game_troop.members.each { |t| t.clear_states;t.remove_all_buffs;t.recover_all }
        queue(actor);actor.actions[0].set_skill(first);actor.actions[0].target_index=first==308 ? actor.index : 0
        actor.actions[1].set_skill(second);actor.actions[1].target_index=0
        srand(90000+seed)
        2.times do |slot|
          action=actor.current_action;action.prepare;item=action.item;actor.use_item(item)
          action.make_targets.compact.each do |t|
            item.repeats.times do
              t.item_apply(actor,item)
              sum+=t.result.hp_damage if slot==1 && t.enemy?
            end
          end
          actor.remove_current_action
        end
      end
      sum/count
    end
    # Self-flagellation -> Triple Shot used to ignore the queued buff entirely.
    gun=$data_weapons.compact.find { |w| w.features.any? { |f| f.code==43 && f.data_id==108 } }
    $game_party.gain_item(gun,1);BS2QoL::Model.change_weapon(actor,gun)
    actor.clear_states;actor.remove_all_buffs;actor.recover_all;actor.cool_time.clear;queue(actor)
    actor.actions[0].set_skill(308);actor.actions[0].target_index=actor.index;actor.instance_variable_set(:@action_input_index,1)
    actor.actions[1].set_skill(108);actor.actions[1].target_index=0
    snapshot=Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items)])
    srand(707);expected=rand;srand(707)
    report=BS2Suite::SequenceForecast.new(actor)
    check(report.steps[1][:rows].any? && !report.steps[1][:reason],'self-damage buff permits the following random-target triple shot forecast')
    predicted=report.steps[1][:rows].inject(0.0) { |n,r| n+r[:mean] }
    ui=BS2Suite::QuickDamage.calculate($data_skills[108],actor,nil,[$game_troop.members[0]],nil,nil)
    check(ui[0].include?(predicted.round.to_s) && ui[0].include?('суммарно'),'short random-attack estimate uses all shots after the queued buff')
    check(Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items)])==snapshot && rand==expected,'full repeat/target preview preserves the world inventory cooldowns and RNG')
    timer=BS2Suite::Performance.now
    20.times { BS2Suite::QuickDamage.calculate($data_skills[108],actor,nil,[$game_troop.members[0]],nil,nil) }
    elapsed=((BS2Suite::Performance.now-timer)&0xffffffff)/20.0
    log('Uncached full two-action forecast ms='+elapsed.to_s)
    actual=simulate_pair(actor,308,108,gun,@scene,400)
    log('SelfFlagellation TripleShot predicted='+predicted.to_s+' observed='+actual.to_s)
    check((predicted-actual).abs/[actual,1].max<0.08,'400 native executions agree with the queued-buff/random-shot expected damage within sampling tolerance')
    # Jubjub random normal ID survives the immediate switch to Two-Handed Sword.
    actor.clear_states;actor.remove_all_buffs;actor.recover_all;actor.cool_time.clear
    BS2QoL::Model.change_weapon(actor,$data_weapons[420]);queue(actor);actor.actions[0].set_attack;actor.actions[0].target_index=0;actor.instance_variable_set(:@action_input_index,1)
    sword=$data_weapons[123];view=BS2Suite::Projection.weapon(actor,sword);normal=$data_skills[view.attack_skill_id]
    step=BS2Suite::QuickDamage.candidate_step(normal,actor,sword,target,sword)
    check(step && !step[:reason] && step[:rows].any?,'Jubjub normal attack no longer blocks the next hovered sword estimate')
    predicted=step[:rows][0][:mean];first=actor.actions[0].item.id
    actual=simulate_pair(actor,first,normal.id,sword,@scene,400)
    log('Jubjub Sword predicted='+predicted.to_s+' observed='+actual.to_s)
    check((predicted-actual).abs/[actual,1].max<0.08,'400 native Jubjub then sword executions agree with the second-action preview')
    # MP in queued lines uses projected earlier effects instead of per-frame sums.
    actor.clear_states;actor.recover_all;actor.cool_time.clear;queue(actor);actor.learn_skill(124)
    actor.actions[0].set_skill(124);actor.actions[0].target_index=actor.index;actor.actions[1].set_skill(108);actor.actions[1].target_index=0
    check(BS2Suite::QueueEdit.mp(actor,1).include?('ОМ'),'selected action line exposes its projected MP price')
    @scene.terminate;$game_party.on_battle_end
    editor=BS2Suite::MacroScene.new;SceneManager.instance_variable_set(:@scene,editor);editor.start
    check(editor.instance_variable_get(:@stage)==:macro_groups && editor.instance_variable_get(:@list).item_max==4,'editor offers all four groups including empty ones')
    3.times { editor.instance_variable_get(:@list).select(0);editor.choose }
    editor.instance_variable_get(:@list).select(3);editor.choose
    list=editor.instance_variable_get(:@list);list.select(list.item_max-1);editor.choose
    check(editor.instance_variable_get(:@stage)==:choices && list.records.all? { |name,v,on| name =~ /\A[0-9] / },'weapon editor choices have numeric labels with a maximum of ten rows')
    Graphics.transition(0);3.times { Graphics.update };capture('BS2QA_editor0999.png')
    wanted=list.records[1][1];frame;@raw.keys=[50];editor.update
    check(editor.instance_variable_get(:@stage)==:edit && editor.set['rows'][0]==wanted,'physical digit edits the matching numbered weapon row')
    editor.terminate
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
