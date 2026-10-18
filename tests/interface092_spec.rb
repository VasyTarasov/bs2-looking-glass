# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
class Nav091Keys
  attr_accessor :keys
  def initialize;@keys=[];end
  def down;@keys.dup;end
  def focused?;true;end
end
def step(scene,keys=[]);@raw.keys=keys;scene.update;end
def key(scene,n);step(scene);step(scene,[n]);end
def show(scene);SceneManager.instance_variable_set(:@scene,scene);scene.start;scene;end
def capture(name)
  Graphics.transition(0);Graphics.brightness=255
  if defined?(BS2Suite::HDDisplay)
    hd=BS2Suite::HDDisplay;hd.poll(true)
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I')
    read.call('',0);w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    raise 'Missing composite capture' unless size==pixels.bytesize
    header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
    File.open('BS2QA_092_'+name+'.bmp','wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
  else
    3.times { Graphics.update };SuiteCapture.save('BS2QA_092_'+name+'.bmp')
  end
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'native interface092 ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  [102,157,278,168].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT) if defined?(BS2Suite::HDDisplay)
  @raw=Nav091Keys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
  shop=Scene_Shop.new;shop.prepare((1..38).map { |i| [0,i,0,0] },false);show(shop);shop.command_buy
  buy=shop.instance_variable_get(:@buy_window);buy.openness=255
  $game_message.add('Synthetic event awaiting shop return')
  key(shop,118)
  check(BS2QoL::Reference.active?(shop),'F7 opens actual shop list despite pending map event message')
  check(shop.instance_variable_get(:@bs2q_reference_window).card.title==$data_items[1].name,'shop reference describes the selected purchase item')
  capture('shop_reference')
  key(shop,27);check(!BS2QoL::Reference.active?(shop) && buy.active,'Esc closes shop reference and restores buying list')
  $game_message.clear
  first=buy.index;page=buy.page_item_max;key(shop,39)
  check(buy.index==[first+page,buy.item_max-1].min,'Right advances real shop list by a visible screen')
  key(shop,37);check(buy.index==first,'Left returns by a visible screen')
  buy.select(buy.item_max-3);key(shop,39);check(buy.index==buy.item_max-1,'last partial page stops on final item')
  key(shop,39);check(buy.index==buy.item_max-1,'Right at the end never wraps to the start')
  $game_party.gain_gold(100000);shop.on_buy_ok
  number=shop.instance_variable_get(:@number_window);number.openness=255;key(shop,118)
  check(BS2QoL::Reference.active?(shop),'F7 also opens the selected item in the purchase quantity dialog')
  key(shop,27);check(number.active,'closing quantity reference preserves the pending purchase dialog')
  number.process_cancel
  [:@buy_window,:@number_window,:@command_window,:@category_window].each { |name| w=shop.instance_variable_get(name);w.deactivate if w }
  $game_party.gain_item($data_items[3],1)
  sell=shop.instance_variable_get(:@sell_window);sell.category=:item;sell.refresh;sell.select(0);sell.show.activate;sell.openness=255
  key(shop,118)
  check(BS2QoL::Reference.active?(shop) && shop.instance_variable_get(:@bs2q_reference_window).card.title==sell.item.name,'F7 also describes the actual sell-list selection')
  key(shop,27);check(sell.active,'sell-list reference returns without selling')
  shop.terminate
  Game_Interpreter.new.w_recipe_all_switch_on
  craft=show(Scene_ItemSynthesis.new)
  category=craft.instance_variable_get(:@category_window);category.deactivate
  list=craft.instance_variable_get(:@list_window);list.category=:weapon;list.refresh;list.show.activate;list.openness=255;list.select(0)
  $game_message.add('Synthetic event awaiting smith return')
  key(craft,118)
  check(BS2QoL::Reference.active?(craft),'F7 opens actual bear weapon-upgrade list')
  check(craft.instance_variable_get(:@bs2q_reference_window).card.title==list.item.name,'craft reference describes the selected upgrade output')
  key(craft,27);check(list.active && !BS2QoL::Reference.active?(craft),'Esc returns to crafting without buying anything')
  before=list.index;key(craft,39)
  check(list.index==[before+list.page_item_max,list.item_max-1].min,'bear upgrade list supports screen-sized horizontal paging')
  craft.terminate;$game_message.clear
  equip=show(Scene_Equip.new);equip.instance_variable_get(:@command_window).deactivate
  slot=equip.instance_variable_get(:@slot_window);slot.activate;slot.openness=255;key(equip,118)
  check(equip.instance_variable_get(:@bs2q_reference_window).is_a?(BS2Suite::EquipmentDetailsWindow),'broad F7 routing preserves equipment-slot actor totals instead of replacing them with an item card')
  key(equip,27);equip.terminate
  # Keep native horizontal tab controls and short lists intact.
  tabs=Window_ItemCategory.new
  check(!BS2Suite::ListNavigation.pageable?(tabs),'item category tabs retain their native horizontal navigation')
  tabs.dispose
  (1..45).each { |id| $game_party.gain_item($data_items[id],1) }
  items=show(Scene_Item.new);items.instance_variable_get(:@category_window).deactivate
  inventory=items.instance_variable_get(:@item_window);inventory.category=:item;inventory.refresh;inventory.select(0);inventory.activate;inventory.openness=255
  first=inventory.index;key(items,39)
  check(inventory.index==[first+inventory.page_item_max,inventory.item_max-1].min,'two-column inventory uses screen-sized paging while category tabs are inactive')
  key(items,37);check(inventory.index==first,'inventory reverse paging returns to its first screen')
  items.terminate
  # Synthetic battle, no unknown enemy data or sprites.
  enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='Манекен';enemy.battler_name='';enemy.params=[10000,100,50,50,50,50,50,50]
  $data_enemies[5000]=enemy;troop=RPG::Troop.new;troop.id=79
  troop.members=(0..2).map { |i| m=RPG::Troop::Member.new;m.enemy_id=5000;m.x=120+i*140;m.y=190;m }
  $data_troops[79]=troop
  BS2Suite::Arsenal093::CATEGORIES.map { |g| g[1] }.flatten.each { |id| $game_party.gain_item($data_weapons[id],1) }
  BS2Suite::FamilyInventory.normalize
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)])
  actor.instance_variable_set(:@action_input_index,0)
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  scene=show(Scene_Battle.new);scene.start_actor_command_selection
  commands=scene.instance_variable_get(:@actor_command_window);commands.openness=255
  symbols=commands.instance_variable_get(:@list).map { |r| r[:symbol] }
  check(!symbols.include?(:bs2_enemy_info) && !symbols.include?(:bs2modules_effects),'battle commands omit duplicate F4 enemies and hero effects buttons')
  BS2Suite::Semantic.sync(actor);%w(V B M N).each { |p| BS2Suite::Semantic.acknowledge(actor,p) }
  key(scene,78);key(scene,51);popup=BS2Suite::Palette.current(scene)
  check(popup.group==3 && popup.page==0,'N3 opens its one ten-entry group')
  key(scene,87);check(popup.group==4 && popup.page==0,'W switches N3 to N4, not a second page')
  key(scene,81);check(popup.group==3,'Q returns to the preceding group')
  key(scene,39);check(popup.group==4,'Right switches to next group once')
  key(scene,37);check(popup.group==3,'Left switches to previous group once')
  row=popup.entries.find { |r| r[:present] };worn=actor.equips[0];count=actor.actions.size;key(scene,row[:digit]+48)
  check(actor.equips[0].id==row[:id] && actor.actions.size==count,'N3 equips immediately without spending an action')
  key(scene,78);key(scene,51);popup=BS2Suite::Palette.current(scene);popup.select(0);worn=actor.equips[0];key(scene,68)
  check(BS2Suite::DirectWeapons.selected_id(actor)==popup.item.id && actor.equips[0]==worn,'D nominates an executor independently of N group')
  key(scene,27)
  key(scene,78);key(scene,78)
  check(!BS2Suite::Palette.current(scene) && !BS2Suite::DirectWeapons.selected_id(actor),'N N clears intent')
  %w(V B M).each do |letter|
    key(scene,letter.ord);popup=BS2Suite::Palette.current(scene)
    popup.set_group(1);key(scene,letter.ord)
    check(BS2Suite::Palette.current(scene).equal?(popup) && popup.group.nil?,letter+' group → repeated letter returns to groups')
    key(scene,letter.ord)
    check(!BS2Suite::Palette.current(scene) && commands.active,letter+' at group root closes to battle commands')
  end
  actor.add_buff(2,3);$game_troop.members[0].add_state(8)
  key(scene,72);effects=scene.instance_variable_get(:@bs2080_effects)
  check(effects && effects.item.equal?(actor),'H opens selectable participants with the hero selected')
  BS2Suite::HDDisplay.poll(true) if defined?(BS2Suite::HDDisplay)
  log('HD error='+BS2Suite::HDDisplay.error.to_s) if defined?(BS2Suite::HDDisplay)
  check(effects.visible==!defined?(BS2Suite::HDDisplay),'H uses one renderer: native without HD, sidebar with HD')
  capture('participants')
  key(scene,13)
  check(BS2QoL::Reference.active?(scene),'Enter on hero in H opens calculated actor details')
  capture('hero_details')
  key(scene,27)
  check(!BS2QoL::Reference.active?(scene) && effects.active,'Esc in nested reference returns to H')
  effects.select(1);key(scene,118)
  card=scene.instance_variable_get(:@bs2q_reference_window).card
  check(card.sections.flatten.join.include?('неизвестны'),'F7 on an unknown enemy in H respects knowledge limits')
  key(scene,27);key(scene,27)
  check(!scene.instance_variable_get(:@bs2080_effects) && commands.active,'Esc exits H and restores the original command window')
  plan=scene.instance_variable_get(:@bs2q_plan);plan.display(actor)
  check(plan.visible,'queue appears with two actual actions')
  actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);plan.display(actor)
  check(!plan.visible,'queue disappears with one actual action regardless of equipment')
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  scene.command_attack;target=scene.instance_variable_get(:@enemy_window);target.openness=255
  check(target.active && target.item_max==3,'ordinary single-target attack opens numbered group target list')
  capture('target_digits')
  key(scene,57);check(target.active && actor.input.target_index<0,'unavailable digit cannot commit another target or command')
  key(scene,50)
  check(actor.actions[0].target_index==1 && !target.active,'digit 2 directly confirms second enemy without Enter')
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  scene.start_actor_command_selection
  $game_troop.members[0].hp=0
  scene.command_attack;target.openness=255;key(scene,50)
  check(actor.actions[0].target_index==2,'digit addresses live displayed rows rather than stale troop indices')
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0);scene.start_actor_command_selection
  actor.recover_all
  rows=BS2Suite::Semantic.groups(actor,'V').map { |g| BS2Suite::Semantic.rows(actor,'V',g[:number]) }.flatten
  row=rows.find { |r| r[:id]==105 && r[:present] && r[:usable] && r[:object].for_opponent? && r[:object].for_one? }
  check(!!row,'owned weapons supply a usable single-target technique for integration')
  BS2Suite::Palette.open(scene,commands,actor,'V');popup=BS2Suite::Palette.current(scene);popup.set_group(row[:group]);BS2Suite::Palette.choose(scene,row)
  target.openness=255
  check(target.active,'selecting a real V technique opens its target list')
  selected=actor.input.item.id;key(scene,49)
  check(actor.actions[0].item.id==selected && actor.actions[0].target_index==1,'V technique then digit 1 preserves the skill and chooses first living row')

  # Friendly targeting, actual battle windows. No unique-ally automatic commit.
  (2..3).each do |id|
    data=Marshal.load(Marshal.dump($data_actors[1]));data.id=id;data.name='Спутник '+(id-1).to_s
    $data_actors[id]=data;$game_party.add_actor(id);$game_actors[id].recover_all
  end
  heal=RPG::Skill.new;heal.id=4998;heal.name='Тестовое лечение';heal.stype_id=1;heal.scope=7;heal.occasion=1
  heal.effects=[RPG::UsableItem::Effect.new(11,0,0.3,0)];heal.mp_cost=0;$data_skills[4998]=heal;actor.learn_skill(4998)
  potion=RPG::Item.new;potion.id=4998;potion.name='Тестовый предмет';potion.scope=7;potion.occasion=1
  potion.effects=[RPG::UsableItem::Effect.new(11,0,0.3,0)];$data_items[4998]=potion;$game_party.gain_item(potion,3)
  [[:skill,4998,1],[:skill,4998,2],[:item,4998,3]].each do |kind,id,digit|
    actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
    scene.start_actor_command_selection;scene.bs2q_apply_binding([kind,id],:commands)
    target=scene.instance_variable_get(:@actor_window);target.openness=255
    check(target.active,'friendly '+kind.to_s+' awaits a numbered ally')
    key(scene,digit+48)
    check(actor.actions[0].target_index==digit-1 && !target.active,'friendly '+kind.to_s+' confirms numbered target without Enter')
  end
  revive=RPG::Skill.new;revive.id=4996;revive.name='Тестовое воскрешение';revive.stype_id=1;revive.scope=9;revive.occasion=1
  revive.effects=[RPG::UsableItem::Effect.new(22,1,1,0),RPG::UsableItem::Effect.new(11,0,0.3,0)];$data_skills[4996]=revive;actor.learn_skill(4996)
  $game_actors[3].hp=0
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  scene.start_actor_command_selection;scene.bs2q_apply_binding([:skill,4996],:commands);target=scene.instance_variable_get(:@actor_window);target.openness=255
  key(scene,49);check(target.active,'revive cannot confirm the living hero')
  key(scene,51);check(actor.actions[0].target_index==2 && !target.active,'revive digit 3 selects fallen companion without Enter')
  $game_actors[3].recover_all
  companion=$game_actors[2];companion.learn_skill(4998);companion.instance_variable_set(:@ap,ATB::MAX_AP)
  companion.instance_variable_set(:@actions,[Game_Action.new(companion),Game_Action.new(companion)]);companion.instance_variable_set(:@action_input_index,0)
  BattleManager.instance_variable_set(:@actor_index,1);scene.start_actor_command_selection;scene.bs2q_apply_binding([:skill,4998],:commands)
  target.openness=255;key(scene,49)
  check(companion.actions[0].target_index==1,'digit 1 means self even when the acting ally is not first in party order')
  BattleManager.instance_variable_set(:@actor_index,0)
  # Journalling shows only effects which occurred, and pauses/resumes the exact battle context.
  BS2Suite::CombatJournal.reset
  enemy=$game_troop.alive_members[0];attack=RPG::Skill.new;attack.id=4997;attack.name='Увиденный удар';attack.hit_type=2
  attack.damage.type=1;attack.damage.formula='10';attack.damage.variance=0;attack.scope=1;$data_skills[4997]=attack
  actor.item_apply(enemy,attack)
  check(BS2Suite::CombatJournal.entries.size==1 && BS2Suite::CombatJournal.entries[0][:hit]==2,'journal captures the actual enemy magic hit')
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0);scene.start_actor_command_selection
  BattleManager.instance_variable_set(:@phase,:input)
  saved=[actor.hp,actor.mp,actor.actions.map { |a| a.item },$game_troop.turn_count]
  key(scene,116);journal=scene.instance_variable_get(:@bs2092_journal)
  check(journal && journal.item.id==4997,'F5 opens observed attacks in the current fight')
  scene.process_action;scene.process_event
  check([actor.hp,actor.mp,actor.actions.map { |a| a.item },$game_troop.turn_count]==saved,'journal blocks native event/action processing from its opening frame')
  capture('journal');key(scene,118)
  check(BS2QoL::Reference.active?(scene) && scene.instance_variable_get(:@bs2q_reference_window).card.title==attack.name,'F7 on journal entry describes the actual enemy attack')
  capture('journal_reference');key(scene,27)
  check(journal.active && !BS2QoL::Reference.active?(scene),'Esc returns from attack reference to journal')
  key(scene,27)
  check(!scene.instance_variable_get(:@bs2092_journal) && commands.active,'Esc closes journal and restores commands')
  after=[actor.hp,actor.mp,actor.actions.map { |a| a.item },$game_troop.turn_count]
  log('journal before='+saved.inspect+' after='+after.inspect)
  check([actor.hp,actor.mp,actor.actions.map { |a| a.item },$game_troop.turn_count]==saved,'journal and reference do not spend resources or advance battle')
  check(BS2Suite::Options.get('weapon_notes')==1 && BS2Suite::Options.get('palette_notes')==1,'short explanations default to enabled')
  check(BS2Suite::ShortNotes.describe($data_skills[110]).include?('Крит'),'short skill explanation identifies the benefit')
  check(BS2Suite::Options.set('palette_notes',0) && BS2Suite::ShortNotes.for_row({:object=>heal},'M').empty?,'VBM notes can be disabled independently')
  check(BS2Suite::ShortNotes.for_row({:object=>$data_weapons[278]},'N').include?('СКР'),'weapon explanations remain enabled independently')
  check(BS2Suite::Options.set('palette_notes',1),'VBM explanation preference restores')
  if defined?(BS2Suite::HDDisplay)
    hd=BS2Suite::HDDisplay;BS2QoL::Hotkeys.clear_notice
    map=Scene_Map.new;check(hd.lines(map).empty?,'map sidebar has no permanent stats or commands')
    BS2QoL::Hotkeys.notice('Краткое уведомление')
    check(hd.lines(map).join.include?('Краткое уведомление'),'map reserve displays a temporary mod notice')
    $game_message.add('Тестовый диалог');check(hd.lines(map).empty?,'dialogue suppresses sidebar notifications');$game_message.clear
    now=Win32API.new('kernel32','GetTickCount',[],'L').call
    BS2QoL::Hotkeys.instance_variable_set(:@notice_tick,(now-1800)&0xffffffff)
    check(hd.lines(map).empty?,'map notice expires by wall clock')
    check(hd.lines(Scene_Title.new).empty?,'title screen has no mirrored commands')
    before=Marshal.dump([actor,$game_party.instance_variable_get(:@weapons)])
    scene.instance_variable_set(:@bs2q_reference_window,Window_BS2QReference.new($data_weapons[278],actor))
    scene.instance_variable_set(:@bs2q_reference_origin,commands)
    hd.poll(true);reference=scene.instance_variable_get(:@bs2q_reference_window)
    width=hd.text_width
    check(reference.lines.all? { |line| hd.measure(line)<=width },'every HD reference line fits exact native font metrics')
    viewport=hd.status[8,6]
    hd.poll(true);check(hd.status[8,6]==viewport,'opening reference preserves scene geometry')
    check(hd.apply(hd.current.merge('sidebar'=>0)) && reference.visible,'disabling HD restores reference text and backing plate')
    check(hd.apply(hd.current.merge('sidebar'=>1)) && !reference.visible,'re-enabling HD moves the same reference into the rail')
    BS2QoL::Reference.close(scene);hd.poll(true)
    check(Marshal.dump([actor,$game_party.instance_variable_get(:@weapons)])==before,'reference resizing preserves live equipment and inventory')
    BS2Suite::Palette.open(scene,commands,actor,'N');palette=BS2Suite::Palette.current(scene);palette.acknowledge;palette.set_group(1)
    normal=hd.current.dup;check(hd.apply(normal.merge('ui'=>150)),'large-text HD mode applies')
    palette.select(palette.entries.size-1);hd.poll(true)
    visible=hd.lines(scene)
    check(visible.any? { |line| line.start_with?("K\t"+palette.entries[-1][:digit].to_s+'  ') },'large-text palette keeps selected final entry visible without new pages')
    capture('large_text_palette')
    original=hd.instance_variable_get(:@text)
    broken=Object.new;def broken.call(*args);0;end
    hd.instance_variable_set(:@text,broken);hd.instance_variable_set(:@last_text,nil);hd.poll(true)
    check(palette.visible,'text transport failure restores the original usable palette')
    hd.instance_variable_set(:@text,original);hd.poll(true)
    check(!palette.visible && hd.error.nil?,'recovered transport returns the same input controller to HD')
    BS2Suite::Palette.close(scene);hd.apply(normal)

  end
  check(!BS2Suite::IDS.include?('scaling') && !BS2Suite::Keys::DEFAULT.has_key?(:scale),'obsolete scaling module and key retired')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  scene.terminate if scene
  $game_party.on_battle_end if $game_party && $game_party.in_battle
  SuiteCapture.close
end
end
