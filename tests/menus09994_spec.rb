# encoding: UTF-8
rgss_main do
  load 'BS2QA_native_capture.rb'
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class MenuKeys09994
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def queue(actor,n=4)
    actor.instance_variable_set(:@actions,Array.new(n) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0)
    actor.instance_variable_set(:@ap,ATB::MAX_AP)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  end
  def frame(keys=[]);@raw.keys=keys;@scene.update_basic;end
  def tap(keys);frame;frame(keys);end
  def native_item(object)
    @scene.instance_variable_get(:@actor_command_window).deactivate
    @scene.command_item;w=@scene.instance_variable_get(:@item_window);w.openness=255
    w.select(w.instance_variable_get(:@data).index(object));w
  end
  def open_palette(actor,prefix,object)
    BS2Suite::Semantic.acknowledge(actor,prefix)
    BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),actor,prefix)
    w=BS2Suite::Palette.current(@scene)
    groups=prefix=='N' ? BS2Suite::DirectWeapons.groups(actor) : BS2Suite::Semantic.groups(actor,prefix)
    group=groups.find do |g|
      rows=prefix=='N' ? BS2Suite::DirectWeapons.rows(actor,g[:number]) : BS2Suite::Semantic.rows(actor,prefix,g[:number])
      rows.any? { |r| r[:object]==object }
    end
    raise 'missing palette object '+prefix+': '+object.name unless group
    w.set_group(group[:number]);w.select(w.entries.index { |r| r[:object]==object });w
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'repeat menus and physical input '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
    [101,277,391].each { |id| $game_party.gain_item($data_weapons[id],1) }
    actor.change_equip(0,$data_weapons[101]);actor.recover_all
    troop=RPG::Troop.new;troop.id=79
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    @raw=MenuKeys09994.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    item=$data_items[61];$game_party.gain_item(item,20)
    queue(actor);@scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
    BS2Suite::BattleSupport.instance_variable_set(:@master,false)
    which=File.file?('menu_case.txt') ? File.read('menu_case.txt').strip : 'all'
    if ['all','favorite'].include?(which)
      w=native_item(item);before=BS2QoL::Preferences.favorite?(:item,item.id)
      tap([65]);check(BS2QoL::Preferences.favorite?(:item,item.id)!=before,'physical A toggles favorite from the ordinary battle item list')
      check(w.active && w.visible && w.item==item,'favorite toggle retains native list and selected item')
      tap([83]);check(w.bs2q_only,'physical S enables favorites filter in ordinary list')
      @scene.on_item_cancel
    end
    if ['all','escape'].include?(which)
      queue(actor);actor.actions[0].set_guard;actor.actions[1].set_guard;actor.instance_variable_set(:@action_input_index,2);@scene.start_actor_command_selection
      open_palette(actor,'B',item)
      tap([27]);tap([27])
      check(actor.actions.all? { |a| !a.item },'two physical Esc presses from a palette cancel the entire unpaid queue')
      queue(actor);actor.actions[0].set_guard;actor.actions[1].set_guard;actor.instance_variable_set(:@action_input_index,2);@scene.start_actor_command_selection;native_item(item)
      tap([27]);tap([27]);check(actor.actions.all? { |a| !a.item },'two physical Esc presses from the ordinary item list cancel the unpaid queue')
      queue(actor);actor.actions[0].set_guard;actor.actions[1].set_guard;actor.instance_variable_set(:@action_input_index,2);@scene.start_actor_command_selection
      BS2Suite::Macros.open(@scene,@scene.instance_variable_get(:@actor_command_window));tap([27]);tap([27])
      check(actor.actions.all? { |a| !a.item },'two physical Esc presses from C cancel the unpaid queue')
      queue(actor);actor.actions[0].set_guard;actor.actions[1].set_guard;actor.instance_variable_set(:@action_input_index,2);@scene.start_actor_command_selection;open_palette(actor,'B',item)
      tap([27]);frame([27]);frame([27])
      check(actor.actions.count { |a| a.item }==2,'holding a single Esc cannot act as a double press')
      @scene.instance_variable_set(:@bs2s_cancel_stamp,[actor.id,BS2Suite::Performance.now-600]);tap([27])
      check(actor.actions.count { |a| a.item }==1,'an expired double-press interval keeps single-slot cancellation')
    end
    if ['all','switch'].include?(which)
      queue(actor);@scene.start_actor_command_selection
      BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),actor,'V')
      tap([67])
      check(!BS2Suite::Palette.current(@scene) && @scene.instance_variable_get(:@bs2s_macros),'physical C switches directly from V to macros')
      tap([86])
      check(BS2Suite::Palette.current(@scene) && BS2Suite::Palette.current(@scene).prefix=='V' && !@scene.instance_variable_get(:@bs2s_macros),'physical V switches directly back from macros')
      BS2Suite::Palette.close(@scene)
    end
    if ['all','native'].include?(which)
      queue(actor);@scene.start_actor_command_selection;w=native_item(item)
      before=$game_party.item_number(item);tap([13])
      check($game_party.item_number(item)==before-1,'native instant item spends once')
      check(w.active && w.visible && w.item==item,'native instant item returns to the same list and selection')
      tap([13]);check($game_party.item_number(item)==before-2,'same native instant item can be used again without reopening its menu')
      @scene.on_item_cancel
    end
    if ['all','palette'].include?(which)
      queue(actor);@scene.start_actor_command_selection;w=open_palette(actor,'B',item);group=w.group
      before=$game_party.item_number(item);tap([13])
      w=BS2Suite::Palette.current(@scene)
      check($game_party.item_number(item)==before-1,'palette instant item spends once')
      check(w && w.prefix=='B' && w.group==group && w.item==item,'B stays in its group with the same instant item selected')
      tap([13]);check($game_party.item_number(item)==before-2,'same B item can be used again without reopening')
      BS2Suite::Palette.close(@scene)
    end
    if ['all','paid'].include?(which)
      magic=RPG::Skill.new;magic.id=5001;magic.name='QA menu magic';magic.scope=1;magic.stype_id=1;magic.hit_type=2;magic.mp_cost=5;magic.damage.type=1;magic.damage.formula='a.mat*2';magic.damage.variance=0;$data_skills[5001]=magic;actor.learn_skill(5001)
      tech=$data_skills[$data_weapons[101].features.find { |f| f.code==43 }.data_id]
      entries=[['B','item',61,0],['M','skill',magic.id,0],['V','skill',tech.id,101],['N','weapon',101,101],['N','weapon',277,277]].each_with_index.map { |(p,k,id,source),i| {'prefix'=>p,'group'=>1,'digit'=>p=='N' && id==277 ? 2 : 1,'kind'=>k,'id'=>id,'source'=>source} }
      BS2Suite::Semantic.customs['u9994']={'name'=>'QA repeated menus','groups'=>{},'entries'=>entries,'behaviors'=>{'N1'=>'now'}}
      BS2Suite::Semantic.state['active'][actor.id.to_s]='u9994'
      queue(actor);@scene.start_actor_command_selection
      command=@scene.instance_variable_get(:@actor_command_window);command.select(command.instance_variable_get(:@list).index { |r| r[:symbol]==:skill });command.deactivate;@scene.command_skill
      w=@scene.instance_variable_get(:@skill_window);w.openness=255;w.select(w.instance_variable_get(:@data).index(tech))
      before=BS2QoL::Preferences.favorite?(:skill,tech.id);tap([65])
      check(BS2QoL::Preferences.favorite?(:skill,tech.id)!=before && w.active && w.item==tech,'physical A adds an equipment technique from the ordinary skill list')
      check(BS2Suite::BattleMenus.favorite_hint(w).include?('избранного'),'native technique hint exposes the remove-favorite action')
      tap([83]);check(w.bs2q_only && w.instance_variable_get(:@data).include?(tech),'native technique list filters favorites with S')
      BS2QoL::Preferences.instance_variable_set(:@lists,nil)
      check(BS2QoL::Preferences.favorite?(:skill,tech.id),'native technique favorite survives a profile reload')
      @scene.on_skill_cancel
      queue(actor);@scene.start_actor_command_selection
      command.select(command.instance_variable_get(:@list).index { |r| r[:symbol]==:skill });command.deactivate;@scene.command_skill
      w=@scene.instance_variable_get(:@skill_window);w.openness=255;w.select(w.instance_variable_get(:@data).index(magic));tap([13])
      check(actor.actions[0].item==magic && w.active && w.item==magic,'ordinary skill selection stays in the ordinary skill list after a paid command')
      tap([13]);check(actor.actions[1].item==magic && w.active,'ordinary skill can be queued again without reopening its list')
      @scene.on_skill_cancel
      queue(actor);@scene.start_actor_command_selection;open_palette(actor,'M',magic);mp=actor.mp
      tap([13]);w=BS2Suite::Palette.current(@scene)
      check(actor.actions[0].item==magic && actor.instance_variable_get(:@action_input_index)==1 && w && w.item==magic,'one-target paid magic returns to the same M selection')
      tap([13]);check(actor.actions[1].item==magic && actor.mp==mp,'repeating paid magic queues a second slot without paying before execution')
      BS2Suite::Palette.close(@scene)
      queue(actor);@scene.start_actor_command_selection;open_palette(actor,'N',$data_weapons[277]);tap([13])
      w=BS2Suite::Palette.current(@scene)
      check(actor.equips[0]==$data_weapons[277] && w && w.prefix=='N' && w.item==$data_weapons[277] && actor.actions.all? { |a| !a.item },'equipping in N stays in N without using a paid action')
      tap([16,13]);w=BS2Suite::Palette.current(@scene)
      check(actor.actions[0].instance_variable_get(:@bs2s_normal_attack) && w && w.prefix=='N' && w.item==$data_weapons[277],'Shift Enter queues a normal attack and returns to the same N weapon')
      BS2Suite::Palette.close(@scene)
      $game_troop.members<<Game_Enemy.new(1,5000)
      queue(actor);@scene.start_actor_command_selection;open_palette(actor,'V',tech);tap([13])
      check(@scene.instance_variable_get(:@enemy_window).active && !BS2Suite::Palette.current(@scene),'multiple enemies retain the ordinary native technique target picker')
      tap([50]);w=BS2Suite::Palette.current(@scene)
      check(actor.actions[0].target_index==1 && w && w.prefix=='V' && w.item==tech,'confirming target two returns to the same V technique')
      tap([13]);tap([27]);w=BS2Suite::Palette.current(@scene)
      check(actor.input && !actor.input.item && w && w.prefix=='V' && actor.actions[0].item==tech,'cancelling the next target returns to V and preserves the earlier paid slot')
      BS2Suite::Palette.close(@scene)
      queue(actor);actor.actions[0].set_guard;actor.instance_variable_set(:@action_input_index,1);@scene.start_actor_command_selection;open_palette(actor,'M',magic);tap([13]);tap([27]);tap([27])
      check(actor.actions.all? { |a| !a.item },'two Esc presses spanning a target picker and its returned menu cancel the unpaid queue')
      queue(actor);@scene.start_actor_command_selection;open_palette(actor,'N',$data_weapons[277]);tap([16,13])
      check(@scene.instance_variable_get(:@enemy_window).active,'Shift attack still asks for a target when there are multiple enemies')
      tap([50]);w=BS2Suite::Palette.current(@scene)
      check(actor.actions[0].target_index==1 && w && w.prefix=='N','Shift attack returns to N after native target confirmation')
      BS2Suite::Palette.close(@scene);$game_troop.members.pop
      # A paid consumable uses the same native ally picker and return contract.
      potion=RPG::Item.new;potion.id=5001;potion.name='QA menu potion';potion.scope=7;potion.occasion=1;potion.consumable=true;potion.effects=[RPG::UsableItem::Effect.new(11,0,0,10)];$data_items[5001]=potion;$game_party.gain_item(potion,10)
      BS2Suite::Semantic.customs['u9994']['entries']<<{'prefix'=>'B','group'=>1,'digit'=>2,'kind'=>'item','id'=>potion.id,'source'=>0}
      queue(actor);@scene.start_actor_command_selection;w=native_item(potion);tap([13])
      check(actor.actions[0].item==potion && w.active && w.visible && w.item==potion,'ordinary paid item auto-selects a sole ally and returns to its native list')
      @scene.on_item_cancel
      ally=$game_actors[2];$game_party.add_actor(2);ally.recover_all
      queue(actor);@scene.start_actor_command_selection;open_palette(actor,'B',potion);tap([13])
      check(@scene.instance_variable_get(:@actor_window).active && !BS2Suite::Palette.current(@scene),'multiple allies retain the ordinary native item target picker')
      tap([50]);w=BS2Suite::Palette.current(@scene)
      check(actor.actions[0].target_index==1 && w && w.prefix=='B' && w.item==potion,'confirming an ally returns to the same B item')
      BS2Suite::Palette.close(@scene);$game_party.remove_actor(2)
      # Real paid execution, then a fresh native input opportunity.
      queue(actor,1);@scene.start_actor_command_selection;open_palette(actor,'M',magic);tap([13])
      check(BattleManager.in_turn? && !BS2Suite::Palette.current(@scene),'the last paid slot executes with menus inactive')
      @scene.instance_variable_set(:@subject,actor);actor.current_action.prepare;mp=actor.mp;@scene.execute_action
      check(actor.mp==mp-actor.skill_mp_cost(magic),'paid execution consumes the native magic cost exactly once')
      actor.remove_current_action;actor.on_action_end
      queue(actor,1);@scene.start_actor_command_selection;w=BS2Suite::Palette.current(@scene)
      check(w && w.prefix=='M' && w.item==magic,'the same menu resumes at the actor next input after paid execution')
      BS2Suite::Palette.close(@scene,false);$game_party.add_actor(2);queue(ally,2);BattleManager.instance_variable_set(:@actor_index,1);@scene.start_actor_command_selection
      check(!BS2Suite::Palette.current(@scene),'one actor never inherits another actor remembered menu')
      queue(actor,1);@scene.start_actor_command_selection;w=BS2Suite::Palette.current(@scene)
      check(w && w.prefix=='M' && w.item==magic,'the original actor retains its own remembered menu after a companion input')
      $game_party.remove_actor(2)
      tap([27]);queue(actor,1);@scene.start_actor_command_selection
      check(!BS2Suite::Palette.current(@scene),'explicit Esc exit clears automatic menu return')
      queue(actor);@scene.start_actor_command_selection
      $game_party.gain_item(item,1-$game_party.item_number(item));open_palette(actor,'B',item);tap([13]);w=BS2Suite::Palette.current(@scene)
      check($game_party.item_number(item)==0 && w && w.prefix=='B','using the last instant item keeps the menu open')
      check(w.item==item && !w.current_item_enabled?,'the depleted palette selection stays disabled instead of selecting another item')
      tap([13])
      check($game_party.item_number(item)==0 && actor.actions.all? { |a| !a.item },'repeating an exhausted item neither spends nor creates an action')
      BS2Suite::Palette.close(@scene)
      $game_party.gain_item(item,1);queue(actor);@scene.start_actor_command_selection;w=native_item(item);tap([13])
      check(w.active && w.item==item && !w.current_item_enabled?,'the last native item remains selected and disabled in its ordinary list')
      tap([13]);check($game_party.item_number(item)==0 && actor.actions.all? { |a| !a.item },'native repeated confirm cannot switch silently to another consumable')
      @scene.on_item_cancel
    end
    if ['all','hd'].include?(which)
      display=BS2Suite::HDDisplay;display.apply(display::DEFAULT.merge('width'=>960,'height'=>720))
      90.times { Graphics.update;Input.update;break if display.active? }
      check(display.active?,'physical menu checks run with the real HD renderer active')
      $game_party.gain_item(item,5)
      queue(actor);actor.actions[0].set_guard;actor.actions[1].set_guard;actor.instance_variable_set(:@action_input_index,2);@scene.start_actor_command_selection
      w=open_palette(actor,'B',item);frame
      check(w.active && !w.visible,'HD owns the palette presentation while its native window is hidden')
      tap([27]);tap([27]);check(actor.actions.all? { |a| !a.item },'physical double Esc also cancels the queue from an HD palette')
      queue(actor);actor.actions[0].set_guard;actor.actions[1].set_guard;actor.instance_variable_set(:@action_input_index,2);@scene.start_actor_command_selection
      BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),actor,'V');tap([67])
      check(@scene.instance_variable_get(:@bs2s_macros) && !BS2Suite::Palette.current(@scene),'physical V to C switching works with HD presentation')
      frame;tap([27]);tap([27]);check(actor.actions.all? { |a| !a.item },'physical double Esc also cancels the queue from HD C')
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
