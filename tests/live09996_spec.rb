# encoding: UTF-8
# Integration regressions from the 0.9994 audit. Real native windows/input/costs.
rgss_main do
  load 'BS2QA_native_capture.rb'
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class MenuKeys09995
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def frame(keys=[]);@raw.keys=keys;@scene.update_basic;end
  def tap(keys);frame;frame(keys);end
  def queue
    BS2Suite::Palette.close(@scene,false) if BS2Suite::Palette.current(@scene)
    @scene.bs2s_hide_selection;@scene.bs2s_forget_menu
    @actor.instance_variable_set(:@actions,Array.new(4) { Game_Action.new(@actor) })
    @actor.instance_variable_set(:@action_input_index,0);@actor.instance_variable_set(:@ap,ATB::MAX_AP)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    @scene.start_actor_command_selection
  end
  def row(prefix,group,digit,kind,id,source=0)
    {'prefix'=>prefix,'group'=>group,'digit'=>digit,'kind'=>kind,'id'=>id,'source'=>source}
  end
  def profile(entries)
    BS2Suite::Semantic.customs['u9995']={'name'=>'QA menu integration','groups'=>{},'entries'=>entries,'behaviors'=>{'N1'=>'now'}}
    BS2Suite::Semantic.state['active'][@actor.id.to_s]='u9995'
  end
  def open_menu(prefix,group=1,index=0)
    BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),@actor,prefix)
    w=BS2Suite::Palette.current(@scene);w.set_group(group);w.select(index);w
  end
  def native_item(item)
    @scene.instance_variable_get(:@actor_command_window).deactivate;@scene.command_item
    w=@scene.instance_variable_get(:@item_window);w.openness=255;w.select(w.instance_variable_get(:@data).index(item));w
  end
  def stock(item,n);$game_party.gain_item(item,n-$game_party.item_number(item));end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Live report regressions '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    $game_party.remove_actor(1);$game_party.add_actor(2)
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    @actor=$game_party.leader;@actor.change_class(1);@actor.change_level(70,false);@actor.clear_equipments
    $game_party.gain_item($data_weapons[101],1);@actor.change_equip(0,$data_weapons[101]);@actor.recover_all
    troop=RPG::Troop.new;troop.id=79
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    @raw=MenuKeys09995.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;queue
    support=BS2Suite::BattleSupport;support.instance_variable_set(:@master,false)
    if defined?(BS2Suite::HDDisplay)
      hd=BS2Suite::HDDisplay;hd.apply(hd::DEFAULT.merge('width'=>1280,'height'=>720))
      20.times { frame };check(hd.active?,'new integration suite uses the real HD compositor')
    end
    item=$data_items[61];stock(item,8);@actor.clear_buffs
    check(support.hero==@actor,'actor 2 is recognised as protagonist')
    support.reset;support.instance_variable_set(:@definitions,[])
    w=native_item(item);tap([68])
    check(support.configured?(@actor,item) && support.active?,'D in ordinary item menu arms automation for actor 2')
    before=$game_party.item_number(item);30.times { frame;support.tick(@scene) }
    check($game_party.item_number(item)==before,'marking an item keeps inspection paused until native input boundary')
    @scene.on_item_cancel;40.times { frame;support.tick(@scene) }
    check($game_party.item_number(item)==before-2,'two real quick item uses spend exactly two Carpenter Bolts')
    check(@actor.instance_variable_get(:@buffs)[2]==2,'two automatic uses reach native maximum attack buff')
    check(@actor.actions.all? { |a| !a.item },'quick automatic buffs leave paid action slots free')
    50.times { frame;support.tick(@scene) }
    check($game_party.item_number(item)==before-2,'maximum buff does not waste a third item')
    @actor.on_action_end
    check(@actor.instance_variable_get(:@buffs)[2]==2,'maximum buff remains after native action end')
    support.instance_variable_set(:@master,false);queue;@actor.clear_buffs;stock(item,1)
    support.reset;support.instance_variable_set(:@definitions,[{'actor'=>2,'kind'=>'item','id'=>61}]);support.instance_variable_set(:@master,true)
    50.times { frame;support.tick(@scene) }
    check($game_party.item_number(item)==0 && @actor.instance_variable_get(:@buffs)[2]==1,'one available item gives one stack and stops without crashing')
    check(support.active? && !support.busy?,'empty stock does not break automation state')
    support.instance_variable_set(:@master,false)
    $game_party.add_actor(3);other_actor=$game_actors[3];other_actor.clear_buffs
    check(!support.toggle_object(other_actor,item),'companions cannot be armed for automatic items')
    check(other_actor.instance_variable_get(:@buffs)[2]==0,'companion receives no automatic buff')
    $game_party.remove_actor(3)
    BS2QoL::Preferences.lists[:skill]=[17,18,19,20,875,877]
    @actor.clear_equipments;@actor.recover_all;queue
    @scene.command_skill
    sw=@scene.instance_variable_get(:@skill_window);sw.instance_variable_set(:@bs2q_only,true);sw.refresh
    check((sw.instance_variable_get(:@data).map { |o| o.id } & [17,18,19,20,875,877]).empty?,'favorites cannot reinsert unavailable Gun Breaks while no gun is equipped')
    shield=$data_armors.find { |a| a && a.etype_id==1 && !a.features.any? { |f| f.code==43 } && @actor.equippable?(a) }
    check(!!shield,'fixture has an actual equippable shield')
    $game_party.gain_item(shield,1);@actor.change_equip(1,shield);sw.refresh
    check(@actor.equips.include?(shield) && sw.instance_variable_get(:@data).empty?,'shield keeps all favorited Gun Breaks hidden')
    gun=$data_armors[66];$game_party.gain_item(gun,1);@actor.change_equip(1,gun);@actor.recover_all;sw.refresh
    check(@actor.equips.include?(gun) && @actor.skills.include?($data_skills[18]),'real equipped rifle supplies its native interrupt')
    check(sw.instance_variable_get(:@data).map { |o| o.id }==[18],'only the currently supplied and usable interrupt is shown')
    @actor.cool_time[18]=2;sw.refresh
    check(sw.instance_variable_get(:@data).empty?,'interrupt on native cooldown is hidden until usable')
    @actor.cool_time[18]=0;sw.refresh
    check(sw.instance_variable_get(:@data).map { |o| o.id }==[18],'available interrupt returns after cooldown')
    @actor.change_equip(1,shield);sw.refresh
    check(sw.instance_variable_get(:@data).empty?,'changing back to shield removes the interrupt again')
    ordinary=$data_skills[138];@actor.learn_skill(ordinary.id);BS2QoL::Preferences.lists[:skill]<<ordinary.id;@actor.mp=0;sw.refresh
    check(sw.instance_variable_get(:@data).include?(ordinary),'unavailable ordinary learned skills keep their existing visible behavior')
    BS2Suite::Semantic.customs['u9996']={'name'=>'QA interrupt slots','groups'=>{},'entries'=>[row('V',1,1,'skill',18),row('M',1,2,'skill',17)],'behaviors'=>{}}
    BS2Suite::Semantic.state['active'][@actor.id.to_s]='u9996'
    @scene.on_skill_cancel;queue;pw=open_menu('V')
    check(pw.entries.empty?,'custom V cannot display a Gun Break absent from actual battle equipment')
    BS2Suite::Palette.close(@scene,false);pw=open_menu('M')
    check(pw.entries.empty?,'custom M cannot display an unavailable Gun Break')
    BS2Suite::Palette.close(@scene,false)
    $game_party.instance_variable_set(:@in_battle,false)
    check(BS2QoL::Model.battle_skill_visible?(@actor,$data_skills[18]),'outside battle favorite management can still inspect stored interrupts')
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
