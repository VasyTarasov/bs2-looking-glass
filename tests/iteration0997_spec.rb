# encoding: UTF-8
rgss_main do
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
  begin
    File.open('test_result.txt','w') { |f| f.puts 'current queue/executor/macros '+BS2Suite::VERSION }
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
    start=BS2Suite::StartingWeapon;direct=BS2Suite::DirectWeapons
    start.toggle(actor,$data_weapons[101]);@scene.start_actor_command_selection
    check(actor.equips[0]==$data_weapons[101],'starting nomination applies on first battle input')
    BS2QoL::Model.change_weapon(actor,$data_weapons[277]);queue(actor);@scene.start_actor_command_selection
    check(actor.equips[0]==$data_weapons[277],'new action array on later turn never reapplies starting weapon')
    start.toggle(actor,$data_weapons[101])
    # Real native immediate item selection after the first paid action.
    actor.learn_skill(124);actor.recover_all;actor.hp=actor.mhp/2;queue(actor)
    actor.actions[0].set_skill(124);actor.actions[0].target_index=actor.index;actor.next_command
    first=actor.actions[0];instant=$data_items[61];$game_party.gain_item(instant,3);before=$game_party.item_number(instant)
    @scene.start_actor_command_selection;@scene.command_item
    w=@scene.instance_variable_get(:@item_window);w.select(w.instance_variable_get(:@data).index(instant));w.process_ok
    check($game_party.item_number(instant)==before-1,'instant item actually executes and consumes one copy')
    check(actor.actions[0].equal?(first) && first.item==$data_skills[124],'instant item preserves already planned first paid action')
    check(actor.instance_variable_get(:@action_input_index)==1 && actor.input.item.nil?,'instant item returns to the same blank second slot')
    check(actor.actions.size==2,'instant item neither consumes nor regenerates paid slots')
    knight=$data_weapons[101].features.find { |f| f.code==43 }.data_id
    BS2QoL::Model.change_weapon(actor,$data_weapons[101]);actor.input.set_skill(knight);actor.input.target_index=0
    report=BS2Suite::SequenceForecast.new(actor)
    check(report.steps[1] && report.steps[1][:rows].any? && !report.steps[1][:reason],'second-action forecast follows planned Ambition and an already used instant item')
    previous=actor.actions[0].dup
    actor.actions[0].set_skill(93);actor.actions[0].target_index=actor.index;actor.cool_time.clear
    pride=BS2Suite::SequenceForecast.new(actor)
    check(pride.steps[1][:rows].any? && !pride.steps[1][:reason],'self healing plus Knight Pride state no longer blocks the next damage estimate')
    actor.actions[0].set_skill(1);actor.actions[0].target_index=0
    after_attack=BS2Suite::SequenceForecast.new(actor)
    check(after_attack.steps[1][:rows].any? && !after_attack.steps[1][:reason],'ordinary attack TP gain no longer blocks the following damage estimate')
    actor.actions[0]=previous
    # Commit through the real turn_start; no direct.arm call in this scenario.
    direct.select(actor,$data_weapons[391]);@scene.next_command
    last=actor.actions.last
    check(last.instance_variable_get(:@bs2s_direct_count)==2 && actor.instance_variable_get(:@bs2s_direct_final).equal?(last),'turn commit arms final weapon after BattleManager cleared input actor')
    actor.actions.shift;actor.instance_variable_set(:@action_input_index,0);last.prepare
    check(actor.equips[0]==$data_weapons[391] && last.item.id==knight,'last multi-action technique actually switches to nominated executor')
    # One paid action still protects its technique source. Magic uses executor.
    queue(actor,1);BS2QoL::Model.change_weapon(actor,$data_weapons[101]);actor.input.set_skill(knight);actor.input.target_index=0;direct.arm(actor);actor.input.prepare
    check(actor.equips[0]==$data_weapons[101],'sole weapon technique remains on its source')
    magic=RPG::Skill.new;magic.id=5001;magic.name='QA magic';magic.scope=1;magic.stype_id=1;magic.hit_type=2;magic.damage.type=1;magic.damage.formula='a.mat*2';magic.damage.variance=0;$data_skills[5001]=magic;actor.learn_skill(5001)
    queue(actor,1);actor.input.set_skill(5001);actor.input.target_index=0;direct.arm(actor);actor.input.prepare
    check(actor.equips[0]==$data_weapons[391],'sole magic uses nominated executor at native preparation')
    direct.clear(actor)
    # Native macro effects interleave with paid actions, in exact row order.
    quick=RPG::Item.new;quick.id=5002;quick.name='QA free buff';quick.scope=11;quick.occasion=1;quick.note='[hzm]ターン消費無し:99';quick.effects=[RPG::UsableItem::Effect.new(31,2,5,0)];$data_items[5002]=quick;$game_party.gain_item(quick,4)
    check(BS2Suite::BattleSupport.quick?(quick),'test item uses real native QuickSkill tag')
    macros=BS2Suite::Macros;row=lambda { |kind,id| {'kind'=>kind,'id'=>id,'source'=>0,'target'=>0} }
    set={'name'=>'QA native order','key'=>1,'rows'=>[row.call('skill',5001),row.call('item',5002),row.call('skill',5001),row.call('item',5002)]}
    queue(actor);actor.recover_all;actor.remove_all_buffs
    check(macros.paid(set,actor)==2 && !macros.problem(set,actor),'six-row macros count only paid actions')
    check(macros.save(actor,1,set),'macro profile saves in bounded text')
    macros.instance_variable_set(:@data,nil);check(macros.get(actor,1)==set,'named rows key and target survive reload')
    duplicate=BS2Modules.clone(set);check(!macros.save(actor,2,duplicate),'duplicate quick slot is rejected without modifying presets')
    too_big=BS2Modules.clone(set);too_big['rows']<<row.call('skill',5001)
    check(!!macros.problem(too_big,actor),'macro exceeding remaining paid budget is unavailable')
    before=$game_party.item_number(quick);@scene.start_actor_command_selection
    check(macros.commit(@scene,actor,set,0).nil?,'macro queues through actual native turn commit')
    forecast=BS2Suite::SequenceForecast.new(actor)
    check(forecast.steps.size==2 && forecast.steps[1][:rows].any?,'macro forecast retains paid row addresses while projecting intervening instant effects')
    check($game_party.item_number(quick)==before,'interleaved instant items are not executed ahead of earlier paid actions')
    first=actor.current_action;first.prepare;@scene.instance_variable_set(:@subject,actor);@scene.execute_action;actor.actions.shift
    check($game_party.item_number(quick)==before,'first paid action does not prematurely run next row')
    actor.current_action.prepare
    check($game_party.item_number(quick)==before-1 && actor.buff?(2),'instant item runs between the two paid actions')
    @scene.execute_action
    check($game_party.item_number(quick)==before-2 && actor.instance_variable_get(:@buffs)[2]==2,'last instant row runs after last paid action and preserves native buff stacking')
    # Profiles are transactional, bounded, and have unique usable default keys.
    seven=BS2Modules.clone(set);seven['rows']+=Array.new(3) { row.call('guard',0) }
    check(!macros.save(actor,1,seven),'seventh action row cannot be saved')
    saved=BS2Modules.clone(macros.get(actor,1))
    BS2Suite::Store.singleton_class.class_eval { alias bs20997_write write;def write(name,text);name=='macros' ? false : bs20997_write(name,text);end }
    changed=BS2Modules.clone(saved);changed['name']='Failed write'
    check(!macros.save(actor,1,changed) && macros.get(actor,1)==saved,'failed profile write preserves in-memory and persisted preset')
    BS2Suite::Store.singleton_class.class_eval { alias write bs20997_write }
    moved=BS2Modules.clone(saved);moved['key']=8;check(macros.save(actor,1,moved),'custom numeric quick slot can be stored')
    check((1..8).map { |i| macros.get(actor,i)['key'] }.uniq.size==8,'unfilled defaults do not shadow a reassigned numeric slot')
    macros.save(actor,1,saved)
    queue(actor);actor.recover_all
    missing={'name'=>'QA missing midrun','key'=>2,'rows'=>[row.call('item',5002),row.call('skill',5001)]}
    check(macros.commit(@scene,actor,missing,0).nil?,'partially filled native turn accepts a shorter macro')
    $game_party.lose_item(quick,99);before_mp=actor.mp
    actor.current_action.prepare
    check(actor.current_action.item.nil? && actor.mp==before_mp,'lost item at execution stops remaining macro without spending later paid action')
    cancelled=actor.actions[0]
    check(cancelled.instance_variable_get(:@bs2s_macro_token).nil? && cancelled.instance_variable_get(:@bs2s_macro_before).empty?,'cancelled macro detaches scheduled instant rows so they cannot run later')
    # Both Shift routes use the normal attack command, rather than a skill cast.
    queue(actor);actor.recover_all;@scene.start_actor_command_selection
    BS2Suite::Semantic.sync(actor);popup=BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),actor,'N')
    popup=BS2Suite::Palette.current(@scene);popup.acknowledge;popup.set_group(1)
    selected=popup.entries.find { |r| r[:object]==$data_weapons[277] }
    check(!!selected,'recommended N contains owned Knuckles for actual shortcut test')
    frame;frame([16,48+selected[:digit]]);BS2Suite::Palette.update(@scene)
    check(actor.actions[0].instance_variable_get(:@bs2s_normal_attack) && actor.equips[0]==$data_weapons[277],'Shift plus N digit enters native normal attack with the selected weapon')
    @scene.instance_variable_get(:@enemy_window).hide.deactivate
    queue(actor);@scene.start_actor_command_selection
    BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),actor,'N');popup=BS2Suite::Palette.current(@scene);popup.acknowledge;popup.set_group(1)
    popup.select(popup.entries.index { |r| r[:object]==$data_weapons[101] })
    frame;frame([16,13]);BS2Suite::Palette.update(@scene)
    check(actor.actions[0].instance_variable_get(:@bs2s_normal_attack) && actor.equips[0]==$data_weapons[101],'Shift Enter enters native normal attack with highlighted weapon')
    @scene.instance_variable_get(:@enemy_window).hide.deactivate
    queue(actor);@scene.start_actor_command_selection
    command=@scene.instance_variable_get(:@actor_command_window);command.openness=255
    2.times do
      frame;frame([67]);BS2QoL::Hotkeys.handle(command)
      picker=@scene.instance_variable_get(:@bs2s_macros);check(!!picker,'physical C opens native macro picker')
      picker.update
      check(@scene.instance_variable_get(:@bs2s_macros).equal?(picker),'opening key cannot immediately close newly created or reused picker')
      if defined?(BS2Suite::HDDisplay)
        BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT)
        BS2Suite::HDDisplay.poll(true)
        check(!picker.visible && BS2Suite::HDDisplay.lines(@scene).any? { |r| r.include?('Связки') },'active HD mode moves macro choice into sidebar')
      end
      frame;frame([72]);picker.process_handling
      check(@scene.instance_variable_get(:@bs2080_effects) && !@scene.instance_variable_get(:@bs2s_macros),'H suspends macro picker while inspecting participant effects')
      BS2Suite::CombatEffects.close(@scene)
      check(@scene.instance_variable_get(:@bs2s_macros).equal?(picker) && picker.active,'closing effects restores macro picker and its active state')
      frame;frame([67]);picker.process_handling
      check(!@scene.instance_variable_get(:@bs2s_macros) && command.active,'C closes macro picker and restores command input')
    end
    actor.input.set_skill(5001)
    frame;frame([67]);BS2QoL::Hotkeys.handle(command)
    check(!!@scene.instance_variable_get(:@bs2s_macros),'macro picker also opens when a cancelled native target left a provisional item in current slot')
    BS2Suite::Macros.close(@scene)
    queue(actor);actor.recover_all
    Window_MenuCommand.init_command_position;menu=Window_MenuCommand.new;symbols=menu.instance_variable_get(:@list).map { |r| r[:symbol] }
    check(symbols.index(:bs2s_macros)==symbols.index(:bs2modules_loadouts)+1,'macro editor is directly below loadouts in game menu');menu.dispose
    check(BS2Suite::Keys.token(:macros)=='C','macro shortcut uses free physical C')
    # Repeated source assignments and preview never conjure equipment.
    actor.singleton_class.send(:remove_method,:make_action_times)
    before=Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items)]);srand(997);expected=rand;srand(997)
    macros.problem(set,actor);macros.paid(set,actor)
    check(Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items)])==before && rand==expected,'macro validation preserves world inventory and RNG')
    @scene.terminate
    $game_party.on_battle_end
    editor=BS2Suite::MacroScene.new;SceneManager.instance_variable_set(:@scene,editor);editor.start
    editor.instance_variable_get(:@list).select(0);editor.choose
    editor.instance_variable_get(:@list).select(0);editor.choose
    editor.instance_variable_get(:@list).select(0);editor.choose
    editor.instance_variable_get(:@list).select(1);editor.choose
    check(editor.instance_variable_get(:@stage)==:groups,'actual editor offers semantic roles after choosing item type')
    list=editor.instance_variable_get(:@list);list.select(list.item_max-1);editor.choose
    check(editor.choices.any? { |r| r['kind']=='item' },'full available item list remains accessible beyond recommended roles')
    editor.terminate
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
