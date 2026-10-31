# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class GunKeys09997
    def down;[];end
    def focused?;true;end
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Gun Break native source, cooldown and proposal contracts' }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments;actor.recover_all
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA Gun Break';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
    troop=RPG::Troop.new;troop.id=79
    member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    BS2QoL::Keyboard.backend=GunKeys09997.new;BS2QoL::Keyboard.reset
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    support=BS2Suite::BattleSupport
    [[17,75],[18,66],[19,67],[20,65]].each do |sid,aid|
      actor.clear_equipments;actor.recover_all;actor.cool_time.clear
      gun=$data_armors[aid];$game_party.gain_item(gun,1);actor.change_equip(1,gun)
      $game_troop.members.each { |e| e.recover_all;e.clear_states }
      actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0);actor.instance_variable_set(:@ap,ATB::MAX_AP)
      BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input);scene.start_actor_command_selection
      skill=$data_skills[sid];support.reset;support.instance_variable_set(:@definitions,[])
      check(actor.skills.include?(skill),'real equipment supplies Gun Break '+sid.to_s)
      check(support.toggle_object(actor,skill) && support.available?(actor,skill),'supplied Gun Break can be armed '+sid.to_s)
      plan=support.next_plan(actor);check(plan && plan[:object]==skill,'planner selects supplied Gun Break '+sid.to_s)
      if support.quick?(skill)
        count=actor.actions.size;support.quick_run(scene,plan)
        check(actor.actions.size==count && actor.actions.all? { |a| !a.item },'native instant Gun Break preserves paid slots '+sid.to_s)
        check(actor.cool_time.fetch(sid,0)>0 && !support.available?(actor,skill),'native cooldown blocks immediate repeat '+sid.to_s)
      else
        before=[actor.hp,actor.mp,actor.tp,$game_party.gold,actor.instance_variable_get(:@action_input_index)]
        support.propose(scene,plan)
        check(support.pending && actor.input.item==skill,'noninstant Gun Break remains a proposal '+sid.to_s)
        check(before==[actor.hp,actor.mp,actor.tp,$game_party.gold,actor.instance_variable_get(:@action_input_index)],'proposal spends no resource or input slot '+sid.to_s)
        support.cancel_pending;check(actor.input.item.nil?,'proposal can be cancelled '+sid.to_s)
      end
      actor.change_equip(1,nil)
      check(!support.available?(actor,skill),'removed equipment withdraws Gun Break '+sid.to_s)
    end
    actor.clear_equipments
    [875,877].each do |sid|
      skill=$data_skills[sid]
      check(!actor.skills.include?(skill) && !support.available?(actor,skill),'follow-up service ID is not a free selectable Gun Break '+sid.to_s)
    end
    scene.terminate;$game_party.on_battle_end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
