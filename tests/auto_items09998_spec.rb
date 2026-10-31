# encoding: UTF-8
# Catalog expectations are independent of BattleSupport::ITEMS and eligible?.
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class AutoItems09998Keys
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def stock(item,n);$game_party.gain_item(item,n-$game_party.item_number(item));end
  def queue
    @support.instance_variable_set(:@master,false)
    @scene.bs2s_hide_selection;@scene.bs2s_forget_menu
    @actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(@actor) })
    @actor.instance_variable_set(:@action_input_index,0);@actor.instance_variable_set(:@ap,ATB::MAX_AP)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    @scene.start_actor_command_selection
    @scene.instance_variable_get(:@actor_command_window).openness=255
  end
  def arm(item,n)
    queue;@actor.recover_all;@actor.clear_states;@actor.clear_buffs;stock(item,n)
    @support.reset;@support.instance_variable_set(:@definitions,[])
    check(@support.toggle_object(@actor,item),'arm '+@actor.id.to_s+':'+item.id.to_s)
  end
  def maintain
    @support.before_menu(@scene)
    12.times { @scene.update_basic }
  end
  def fresh_queue
    queue;@support.instance_variable_set(:@master,true)
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Independent automatic item catalog and real resin/pollen execution' }
    DataManager.init;DataManager.setup_new_game
    @support=BS2Suite::BattleSupport
    check(@support.eligible?($data_items[32]),'fire resin is a supported native weapon buff')
    check(@support.eligible?($data_items[102]),'pollen is supported with native party scope')
    expected=[4,5,6,22,32,33,34,53,54,56,57,58,59,60,61,76,94,97,100,101,102,104,105,107]
    actual=$data_items.compact.select { |item| @support.eligible?(item) }.map { |item| item.id }.sort
    check(actual==expected,'independent complete accepted item catalog: '+actual.inspect)
    # These have tactical effects beyond routine maintenance, or deal damage.
    [1,2,3,8,19,81,98,108].each do |id|
      check(!@support.eligible?($data_items[id]),'manual recovery/cleanse/extra-action/immortality/madness/damage '+id.to_s)
    end
    # Only the original fire resin's frostbite removal is allowed as a side effect.
    altered=Marshal.load(Marshal.dump($data_items[32]))
    altered.effects<<RPG::UsableItem::Effect.new(22,2,1,0)
    check(!@support.eligible?(altered),'additional cleansing on resin is still rejected')
    altered=Marshal.load(Marshal.dump($data_items[33]))
    altered.effects<<RPG::UsableItem::Effect.new(22,162,1,0)
    check(!@support.eligible?(altered),'thaw exception is not granted to other items')
    [1,2].each do |hero_id|
      DataManager.init;DataManager.setup_new_game
      $game_party.members.map { |a| a.id }.each { |id| $game_party.remove_actor(id) }
      $game_party.add_actor(hero_id)
      @actor=$game_party.leader;@actor.change_class(1);@actor.change_level(70,false);@actor.clear_equipments;@actor.recover_all
      SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
      troop=RPG::Troop.new;troop.id=79
      enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA auto items';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
      member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
      BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
      @raw=AutoItems09998Keys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
      @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
      # Each elemental resin must apply its own real state without using a paid slot.
      {32=>21,33=>23,34=>24,97=>22}.each do |id,state|
        item=$data_items[id];arm(item,6)
        @actor.add_state(162) if id==32
        paid=@actor.actions.dup;before=$game_party.item_number(item);maintain
        check(@actor.state?(state) && $game_party.item_number(item)==before-1,'native resin applied once '+hero_id.to_s+':'+id.to_s)
        check(@actor.actions==paid && paid.all? { |a| !a.item } && !@support.busy?,'native resin preserves paid slots '+hero_id.to_s+':'+id.to_s)
        check(!@actor.state?(162),'native fire resin thaws frostbite '+hero_id.to_s) if id==32
        before=$game_party.item_number(item);maintain
        check($game_party.item_number(item)==before,'fresh resin is not wasted '+hero_id.to_s+':'+id.to_s)
        if id==32
          @actor.result.clear;@actor.add_state(162)
          check(@actor.state?(162),'fresh action can apply frostbite '+hero_id.to_s)
          maintain
          check(@actor.state?(162) && $game_party.item_number(item)==before,'fresh fire is not recast solely to cleanse frostbite '+hero_id.to_s)
        end
        @actor.instance_variable_get(:@state_turns)[state]=2;@actor.on_action_end;fresh_queue
        maintain
        check(@actor.state?(state) && @actor.instance_variable_get(:@state_turns)[state]>=9 && $game_party.item_number(item)==before-1,'resin renewed at real paid-period boundary '+hero_id.to_s+':'+id.to_s)
        @actor.instance_variable_get(:@state_turns)[state]=1;@actor.on_action_end
        check(!@actor.state?(state),'native resin expiry '+hero_id.to_s+':'+id.to_s)
        stock(item,0);fresh_queue;maintain
        check(!@actor.state?(state) && @support.active?,'empty resin stock waits '+hero_id.to_s+':'+id.to_s)
        stock(item,1);maintain
        check(@actor.state?(state) && $game_party.item_number(item)==0,'refilled resin resumes '+hero_id.to_s+':'+id.to_s)
      end
      # Standard item-window hotkey, then reread the actual saved definition.
      item=$data_items[32];arm(item,3)
      @support.toggle_object(@actor,item)
      @scene.instance_variable_get(:@actor_command_window).deactivate;@scene.command_item
      window=@scene.instance_variable_get(:@item_window);window.openness=255
      window.select(window.instance_variable_get(:@data).index(item))
      @raw.keys=[];Graphics.update;Input.update
      @raw.keys=[BS2Suite::Keys::BASE[BS2Suite::Keys.token(:Z)]];Graphics.update;Input.update
      check(BS2Suite::ItemAutomation.route(window) && @support.configured?(@actor,item),'standard item window arms fire resin '+hero_id.to_s)
      @raw.keys=[];Graphics.update;Input.update
      @support.instance_variable_set(:@definitions,nil);@support.instance_variable_set(:@expanded_key,nil)
      check(@support.configured?(@actor,item),'fire resin saved definition survives reread '+hero_id.to_s)
      fresh_queue;maintain
      check(@actor.state?(21),'window-armed fire resin really executes '+hero_id.to_s)
      # Party-wide items retain the existing protagonist-only automation policy.
      item=$data_items[102];arm(item,4)
      ally_id=hero_id==1 ? 2 : 1;$game_party.add_actor(ally_id);ally=$game_actors[ally_id];ally.recover_all
      before=$game_party.item_number(item);maintain
      check(!@actor.state?(39) && !ally.state?(39) && $game_party.item_number(item)==before,'pollen waits while a living companion is present '+hero_id.to_s)
      $game_party.remove_actor(ally_id);fresh_queue;maintain
      check(@actor.state?(39) && $game_party.item_number(item)==before-1,'native pollen applies for solo protagonist '+hero_id.to_s)
      before=$game_party.item_number(item);maintain
      check($game_party.item_number(item)==before,'fresh pollen is not recast '+hero_id.to_s)
      @scene.terminate;$game_party.on_battle_end
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
