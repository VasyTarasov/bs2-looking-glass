# encoding: UTF-8
# Real item execution, both protagonist records, stock boundaries and map renewal.
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class SupportKeys09997
    def down;[];end
    def focused?;true;end
  end
  def stock(item,n);$game_party.gain_item(item,n-$game_party.item_number(item));end
  def queue
    @actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(@actor) })
    @actor.instance_variable_set(:@action_input_index,0);@actor.instance_variable_set(:@ap,ATB::MAX_AP)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    @scene.bs2s_hide_selection if @scene.respond_to?(:bs2s_hide_selection)
    @scene.start_actor_command_selection
  end
  def case_for(item,n)
    @support.instance_variable_set(:@master,false);@actor.recover_all;@actor.clear_states;@actor.clear_buffs
    $game_troop.members.each { |e| e.recover_all;e.clear_states;e.clear_buffs }
    queue;stock(item,n);@support.reset;@support.instance_variable_set(:@definitions,[])
    check(@support.toggle_object(@actor,item),'arm '+@actor.id.to_s+':'+item.id.to_s)
    @support.new_epoch(@actor)
  end
  def maintain
    @support.before_menu(@scene)
    20.times { @scene.update_basic;@support.tick(@scene) }
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Complete automatic-item policy and native execution matrix' }
    [1,2].each do |hero_id|
      DataManager.init;DataManager.setup_new_game
      $game_party.members.map { |a| a.id }.each { |id| $game_party.remove_actor(id) }
      $game_party.add_actor(hero_id)
      @actor=$game_party.leader;@actor.change_class(1);@actor.change_level(70,false);@actor.clear_equipments;@actor.recover_all
      SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
      troop=RPG::Troop.new;troop.id=79
      enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA support';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
      troop.members=(0..2).map { |i| m=RPG::Troop::Member.new;m.enemy_id=5000;m.x=200+i*100;m.y=180;m };$data_troops[79]=troop
      BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
      BS2QoL::Keyboard.backend=SupportKeys09997.new;BS2QoL::Keyboard.reset
      @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
      @support=BS2Suite::BattleSupport
      expected=[22,32,33,34,56,57,58,59,60,61,97,100,101,102,104,105]
      actual=$data_items.compact.select { |item| @support.eligible?(item) }.map { |item| item.id }.sort
      check(actual==(expected+[4,5,6,53,54,76,94,107]).sort,'independent complete automatic item catalog '+hero_id.to_s)
      expected.each do |id|
        item=$data_items[id]
        case_for(item,12)
        before=$game_party.item_number(item);maintain;spent=before-$game_party.item_number(item)
        recipients=item.for_opponent? ? 3 : 1
        check(spent>0 && spent<=2*recipients,'bounded real stock '+hero_id.to_s+':'+id.to_s+' spent='+spent.to_s)
        check(@support.active? && !@support.busy? && @actor.actions.all? { |a| !a.item },'automatic item leaves paid slots free '+hero_id.to_s+':'+id.to_s)
        stable=$game_party.item_number(item);maintain
        check($game_party.item_number(item)==stable,'fresh effect is not recast '+hero_id.to_s+':'+id.to_s)
        case_for(item,0);maintain
        check(@support.next_plan(@actor).nil? && @support.active?,'empty stock waits without disabling '+hero_id.to_s+':'+id.to_s)
        stock(item,1);maintain
        check($game_party.item_number(item)==0 && @support.active?,'one refilled item resumes without rearming '+hero_id.to_s+':'+id.to_s)
      end
      item=$data_items[61];case_for(item,4)
      @actor.add_debuff(2,5)
      check(@support.next_plan(@actor).nil?,'automatic buff does not silently cleanse opposing debuff '+hero_id.to_s)
      item=$data_items[105];case_for(item,12)
      $game_troop.members.each { |e| e.enemy.features=[RPG::BaseItem::Feature.new(12,3,0),RPG::BaseItem::Feature.new(12,5,0)] }
      before=$game_party.item_number(item);maintain
      check(before-$game_party.item_number(item)==3,'failed debuff is attempted only once per target '+hero_id.to_s)
      stable=$game_party.item_number(item);maintain
      check($game_party.item_number(item)==stable,'failed support does not loop on immune targets '+hero_id.to_s)
      @scene.terminate;$game_party.on_battle_end
      check(!@support.active?,'support is reset on battle exit '+hero_id.to_s)
    end
    if BS2Suite.enabled?('field_skills')
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.learn_skill(120);actor.recover_all
    stealth=BS2Suite::AutoStealth;check(stealth.toggle(actor),'map stealth can be armed')
    map=Scene_Map.new;SceneManager.instance_variable_set(:@scene,map)
    $game_temp.clear_common_event;$game_player.instance_variable_set(:@stealth_count,0)
    before=actor.mp;cost=actor.skill_mp_cost($data_skills[120]);stealth.update(map)
    check(actor.mp==before-cost && stealth.remaining==150,'map renewal uses native MP price and 150 steps')
    paid=actor.mp;5.times { stealth.update(map) }
    check(actor.mp==paid,'remaining stealth and pending event prevent duplicate payment')
    $game_temp.clear_common_event;$game_player.instance_variable_set(:@stealth_count,0);actor.mp=0
    stealth.update(map);check(actor.mp==0 && stealth.status.include?('не хватает'),'map renewal explains insufficient MP')
    actor.mp=actor.mmp;before=actor.mp;stealth.update(map)
    check(actor.mp==before-cost && stealth.remaining==150,'map renewal resumes after MP recovery')
    else
      check(!defined?(BS2Suite::AutoStealth),'standalone battle support does not load field automation')
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
