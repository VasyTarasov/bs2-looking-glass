# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class Cleanse09999Keys
    def down;[];end
    def focused?;true;end
  end
  def stock(item,n);$game_party.gain_item(item,n-$game_party.item_number(item));end
  def queue
    @support.instance_variable_set(:@master,false)
    @scene.bs2s_hide_selection if @scene.respond_to?(:bs2s_hide_selection)
    @scene.bs2s_forget_menu if @scene.respond_to?(:bs2s_forget_menu)
    @actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(@actor) })
    @actor.instance_variable_set(:@action_input_index,0);@actor.instance_variable_set(:@ap,ATB::MAX_AP)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    @scene.start_actor_command_selection;@scene.instance_variable_get(:@actor_command_window).openness=255
  end
  def arm(item,n)
    queue;@actor.recover_all;@actor.clear_states;@actor.clear_buffs;@actor.result.clear;stock(item,n)
    @support.reset;@support.instance_variable_set(:@definitions,[])
    check(@support.toggle_object(@actor,item),'arm '+@actor.id.to_s+':'+item.id.to_s)
  end
  def apply_state(id);@actor.result.clear;@actor.add_state(id);check(@actor.state?(id),'test state really present '+id.to_s);end
  def maintain
    @support.before_menu(@scene);12.times { @scene.update_basic }
  end
  def period
    @actor.on_action_end;queue;@support.instance_variable_set(:@master,true)
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Native cleansing without spending caps; intentional effects and wine' }
    DataManager.init;DataManager.setup_new_game
    @support=BS2Suite::BattleSupport
    expected=[4,5,6,22,32,33,34,53,54,56,57,58,59,60,61,76,94,97,100,101,102,104,105,107]
    check($data_items.compact.select { |o| @support.eligible?(o) }.map { |o| o.id }.sort==expected,'independent 24-item catalog')
    [1,2,3,8,19,23,81,98,108].each { |id| check(!@support.eligible?($data_items[id]),'deferred item remains manual '+id.to_s) }
    [1,2].each do |hero_id|
      DataManager.init;DataManager.setup_new_game
      $game_party.members.map { |a| a.id }.each { |id| $game_party.remove_actor(id) };$game_party.add_actor(hero_id)
      @actor=$game_party.leader;@actor.change_class(1);@actor.change_level(70,false);@actor.clear_equipments;@actor.recover_all
      SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
      troop=RPG::Troop.new;troop.id=79
      enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA cleansing';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
      m=RPG::Troop::Member.new;m.enemy_id=5000;m.x=300;m.y=180;troop.members=[m];$data_troops[79]=troop
      BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
      BS2QoL::Keyboard.backend=Cleanse09999Keys.new;BS2QoL::Keyboard.reset
      @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
      {4=>[2,3],5=>[26],6=>[28],53=>[5,29],54=>[55],76=>[56],94=>[17]}.each do |id,states|
        item=$data_items[id];arm(item,8);before=$game_party.item_number(item);maintain
        check($game_party.item_number(item)==before && !@support.next_plan(@actor),'cleanse absent states costs nothing '+hero_id.to_s+':'+id.to_s)
        states.each do |state|
          arm(item,8);apply_state(state);paid=@actor.actions.dup;before=$game_party.item_number(item);maintain
          check(!@actor.state?(state) && $game_party.item_number(item)==before-1,'native state removed by one actual item '+hero_id.to_s+':'+id.to_s+':'+state.to_s)
          check(@actor.actions==paid && paid.all? { |a| !a.item } && !@support.busy?,'cleanse preserves paid actions '+hero_id.to_s+':'+id.to_s)
          before=$game_party.item_number(item);maintain
          check($game_party.item_number(item)==before,'cleansed state causes no repeat '+hero_id.to_s+':'+id.to_s)
        end
        arm(item,0);apply_state(states[0]);maintain
        check(@actor.state?(states[0]) && @support.active?,'empty cleanse stock waits '+hero_id.to_s+':'+id.to_s)
        stock(item,1);maintain
        check(!@actor.state?(states[0]) && $game_party.item_number(item)==0,'refilled cleanse resumes '+hero_id.to_s+':'+id.to_s)
      end
      # One narrow item handles both of its actual native targets in one use.
      [4,53].each do |id|
        item=$data_items[id];arm(item,5);@support::CLEANSES[id].each { |state| apply_state(state) };maintain
        check(@support::CLEANSES[id].none? { |state| @actor.state?(state) } && $game_party.item_number(item)==4,'combined states take one narrow cleanse '+hero_id.to_s+':'+id.to_s)
      end
      item=$data_items[4];arm(item,1);apply_state(2);maintain
      check(!@actor.state?(2) && $game_party.item_number(item)==0,'last stocked item has no reserved floor '+hero_id.to_s)
      item=$data_items[5];arm(item,10)
      4.times do |n|
        apply_state(26);maintain
        check($game_party.item_number(item)==9-n && !@actor.state?(26),'manual activation has no battle spending cap '+hero_id.to_s+':'+n.to_s)
        apply_state(26);maintain
        check($game_party.item_number(item)==9-n,'reapplied state waits until next native period '+hero_id.to_s+':'+n.to_s)
        period
      end
      check($game_party.item_number(item)==6 && @support.spent(@actor,item)==4,'a fourth native period has no removed three-use cap '+hero_id.to_s)
      # Inject a real removal refusal; do not substitute the item executor.
      item=$data_items[4];arm(item,8);apply_state(2)
      original=@actor.method(:remove_state)
      @actor.define_singleton_method(:remove_state) { |id| id==2 ? nil : original.call(id) }
      maintain;before=$game_party.item_number(item);maintain
      check(@actor.state?(2) && before==7 && $game_party.item_number(item)==7,'failed native cleanse makes one attempt without a loop '+hero_id.to_s)
      @actor.singleton_class.send(:remove_method,:remove_state)
      period;maintain
      check(!@actor.state?(2) && $game_party.item_number(item)==6,'a later native period can retry a failed cleanse '+hero_id.to_s)
      # Auto-maintained and deliberately self-applied madness are protected.
      item=$data_items[6];arm(item,8);@support.toggle_object(@actor,$data_items[60]);apply_state(28);maintain
      check(@actor.state?(28) && $game_party.item_number(item)==8,'configured madness upkeep takes precedence over sedative '+hero_id.to_s)
      arm(item,8);@actor.item_apply(@actor,$data_items[60]);maintain
      check(@actor.state?(28) && $game_party.item_number(item)==8,'manual native self-inflicted madness is preserved '+hero_id.to_s)
      @actor.remove_state(28);apply_state(28);maintain
      check(!@actor.state?(28) && $game_party.item_number(item)==7,'later hostile madness does not inherit intentional marker '+hero_id.to_s)
      arm(item,8);apply_state(223);apply_state(28);maintain
      check(@actor.state?(28) && $game_party.item_number(item)==8,'loaded Necronomicon state protects madness '+hero_id.to_s)
      # Fire renewal retains its native thaw effect, with no separate mode setting.
      item=$data_items[32];arm(item,8);apply_state(21);apply_state(162);maintain
      check(@actor.state?(162) && $game_party.item_number(item)==8,'fresh fire is not recast only for thaw '+hero_id.to_s)
      @actor.remove_state(21);period;maintain
      check(!@actor.state?(162) && @actor.state?(21) && $game_party.item_number(item)==7,'normal fire renewal also executes native thaw '+hero_id.to_s)
      # Cleansing order is independent of saved insertion order, without RNG.
      arm($data_items[32],8);stock($data_items[4],8);@support.toggle_object(@actor,$data_items[4]);apply_state(2)
      srand(9999);expected_rng=rand;srand(9999);plan=@support.next_plan(@actor);actual_rng=rand
      check(plan[:object].id==4 && expected_rng==actual_rng,'narrow cleanse precedes upkeep and planning consumes no RNG '+hero_id.to_s)
      # Native use itself records wine, including a player's manual use.
      item=$data_items[107];arm(item,1);paid=@actor.actions.dup;maintain
      check(@actor.state?(222) && $game_party.item_number(item)==1 && @actor.actions==paid,'wine applies native bonus without consumption or extra paid slots '+hero_id.to_s)
      @actor.remove_state(222);period;maintain
      check(!@actor.state?(222) && !@support.next_plan(@actor),'wine is not reapplied later in the same battle '+hero_id.to_s)
      arm(item,1);@actor.use_item(item);@actor.item_apply(@actor,item);@actor.remove_state(222);maintain
      check(!@actor.state?(222) && !@support.next_plan(@actor),'manual wine use also prevents automatic repetition '+hero_id.to_s)
      # The actor must remain able to use an item under native restrictions.
      item=$data_items[4];arm(item,8);apply_state(2);apply_state(6);maintain
      check(@actor.state?(2) && $game_party.item_number(item)==8,'sleep/input restrictions are not bypassed '+hero_id.to_s)
      @actor.remove_state(6);queue;@support.instance_variable_set(:@master,true);maintain
      check(!@actor.state?(2) && $game_party.item_number(item)==7,'cleansing resumes after native restriction ends '+hero_id.to_s)
      @actor.use_item($data_items[107]);@actor.item_apply(@actor,$data_items[107])
      @scene.terminate;$game_party.on_battle_end
      check(@support.spent(@actor,$data_items[4])==0 && @support.instance_variable_get(:@wine_used).empty?,'native battle exit resets spending and wine '+hero_id.to_s)
      BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
      @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;queue
      @support.instance_variable_set(:@definitions,[{'actor'=>hero_id,'kind'=>'item','id'=>107}]);@support.instance_variable_set(:@master,true)
      @actor.remove_state(222);maintain
      check(@actor.state?(222) && $game_party.item_number($data_items[107])==1,'wine can execute again in the next native battle '+hero_id.to_s)
      @scene.terminate;$game_party.on_battle_end
    end
    check(!BS2Suite.const_defined?(:AutomationScene) && !@support.const_defined?(:Rules),'removed reserve/limit settings have no runtime screen')
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
