# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
class FollowupKeys
  attr_accessor :keys
  def initialize;@keys=[];end
  def down;@keys;end
  def focused?;true;end
end
def press(code)
  @raw.keys=[];Graphics.update;Input.update
  @raw.keys=[code];Graphics.update;Input.update
end
def close_ref(scene);BS2QoL::Reference.close(scene) if BS2QoL::Reference.active?(scene);end
begin
  File.open('test_result.txt','w') { |f| f.puts 'followup080; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  $game_variables[14]=actor.id
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  $game_party.items.each { |w| $game_party.lose_item(w,999) }
  [102,256,157,362,277,178,145,211,223].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  model=BS2Suite::Semantic;model.sync(actor)
  groups=model.groups(actor,'V')
  check(groups.size==2,'progression splits a twelve-technique inventory')
  groups.each { |g| rows=model.rows(actor,'V',g[:number]);check(rows.map { |r| r[:digit] }==BS2Suite::Semantic::DIGITS[0,rows.size].chars.map { |s| s.to_i },'split group uses consecutive visible digits '+g[:number].to_s) }
  layout=model.state['layouts'][model.layout_key(actor,'V')]
  layout['groups'][0]['digits'][layout['groups'][0]['keys'][1]]=9
  model.sync(actor)
  check(model.rows(actor,'V',1)[1][:digit]==2,'existing 071 layout holes migrate without acquiring more items')
  layout['moves']=['old → new'];saved=Marshal.load(Marshal.dump($game_system))
  check(model.pending_moves(actor,'V').any?,'new movement notice appears')
  model.acknowledge(actor,'V');$game_system=saved
  check(model.pending_moves(actor,'V').empty?,'loading before acknowledgement does not repeat identical notice')
  n1=BS2Suite::DirectWeapons.shelf(actor).select { |r| r['group']==1 }.map { |r| BS2Suite::WeaponFamilies.root(r['id']) }
  check(n1.include?(BS2Suite::WeaponFamilies.root(157)) && n1.include?(BS2Suite::WeaponFamilies.root(223)),'N1 includes Club and Hunter Saw manual sources')
  armor=$data_armors[75];$game_party.gain_item(armor,1);actor.change_equip(1,armor)
  check(actor.equips[1]==armor,'offhand cannon equipped in native shield slot')
  model.sync(actor)
  row=model.groups(actor,'V').map { |g| model.rows(actor,'V',g[:number]) }.flatten.find { |r| r[:id]==17 }
  check(row && row[:source]==armor && row[:present],'offhand cannon grants its V technique')
  # Notice cannot survive either clock expiry or a frame-counter rewind.
  BS2QoL::Hotkeys.notice('test');check(BS2QoL::Hotkeys.current_notice=='test','new notice visible')
  BS2QoL::Hotkeys.instance_variable_set(:@notice_tick,(Win32API.new('kernel32','GetTickCount',[],'L').call-2000)&0xffffffff)
  check(!BS2QoL::Hotkeys.current_notice,'notice expires by monotonic elapsed time')
  BS2QoL::Hotkeys.notice('rewind');BS2QoL::Hotkeys.instance_variable_set(:@notice_frame,Graphics.frame_count+5)
  check(!BS2QoL::Hotkeys.current_notice,'frame counter rewind clears notice')
  # Souls: real database and native param/SEN operations.
  [9,10,11,12,13,14,15,16,17,79,35,85,273,84,80].each { |id| $game_party.gain_item($data_items[id],2) }
  before=actor.instance_variable_get(:@param_plus).dup;sen=$game_variables[38]
  check(BS2Suite::SoulBatch.apply(:colors),'ordinary colored soul batch applies')
  check((9..16).all? { |id| $game_party.item_number($data_items[id])==0 },'all eight ordinary colors consumed')
  check(actor.instance_variable_get(:@param_plus).zip(before).map { |a,b| a-b }==[40,20,4,4,4,4,4,4],'colored batch matches eight native common-event formulas')
  check($game_party.item_number($data_items[17])==2 && $game_variables[38]==sen,'ordinary option preserves black souls and SEN')
  before=actor.instance_variable_get(:@param_plus).dup
  check(BS2Suite::SoulBatch.apply(:black),'black batch applies only after explicit mode selection')
  check(actor.instance_variable_get(:@param_plus).zip(before).map { |a,b| a-b }==[80,40,8,8,8,8,8,8] && $game_variables[38]==sen-80,'black and dirty black match native gains and SEN loss')
  gold=$game_party.gold
  check(BS2Suite::SoulBatch.apply(:currency) && $game_party.gold==gold+50100,'currency batch uses verified gold-only common events')
  check([273,84,80].all? { |id| $game_party.item_number($data_items[id])==2 },'key, external and dream souls excluded')
  # Equipped upgrade with no loose copy.
  actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  $game_party.gain_item($data_weapons[102],1);actor.change_equip(0,$data_weapons[102]);$game_party.gain_item($data_items[26],3)
  recipe=WD_itemsynthesis_ini::W_recipe[103]
  $game_system.w_rcp_sw[103]=true;$game_system.w_rcp_sw[104]=true
  list=Window_ItemSynthesisList.new(0,72,320);list.category=:weapon
  check(list.have_mat?(recipe),'craft list counts equipped upgrade ingredient')
  check($game_party.item_number($data_weapons[102])==0,'virtual craft count never changes ordinary inventory queries')
  scene=Scene_ItemSynthesis.new;scene.instance_variable_set(:@item,$data_weapons[103]);scene.instance_variable_set(:@list_window,list)
  scene.instance_variable_set(:@gold_window,Struct.new(:value).new($game_party.gold))
  check(scene.max_buy==1,'max craft includes exactly one equipped copy')
  check(scene.do_syntetic(1),'native crafting transaction succeeds')
  check(actor.equips[0]==$data_weapons[103] && $game_party.item_number($data_weapons[102])==0 && $game_party.item_number($data_weapons[103])==0 && $game_party.item_number($data_items[26])==0,'upgrade preserves equipped ownership, consumes exact material and creates no duplicate')
  $game_party.gain_item($data_items[26],5)
  before=Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_party.gold])
  scene.instance_variable_set(:@item,$data_weapons[104])
  result=BS2Suite::EquippedUpgrade.craft(scene,1) { raise 'injected native failure' }
  after=Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_party.gold])
  old=Marshal.load(before);now=Marshal.load(after)
  same_actor=actor.instance_variables.all? { |k| Marshal.dump(old[0].instance_variable_get(k))==Marshal.dump(now[0].instance_variable_get(k)) }
  check(!result && same_actor && old[1..3]==now[1..3],'failed native upgrade rolls back actor, inventory and currency')
  list.dispose
  # Shop F7 uses a real buy list, not a mock item getter.
  @raw=FollowupKeys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
  shop=Scene_Shop.new;SceneManager.instance_variable_set(:@scene,shop)
  honey=$data_items.find { |i| i && i.name.include?('Мёд') }
  honey ||= $data_items[3]
  buy=Window_ShopBuy.new(0,72,280,[[0,honey.id,0,0]])
  buy.activate;buy.openness=255;press(118)
  check(BS2QoL::Hotkeys.handle(buy) && BS2QoL::Reference.active?(shop),'F7 opens an actual shop-buy item')
  close_ref(shop);buy.dispose
  equip=Scene_Equip.new;SceneManager.instance_variable_set(:@scene,equip);equip.start
  origin=equip.instance_variable_get(:@command_window);origin.openness=255;press(118)
  before=Marshal.dump([actor,$game_party])
  check(BS2QoL::Hotkeys.handle(origin) && BS2QoL::Reference.active?(equip),'F7 on native equipment command opens totals')
  card=equip.instance_variable_get(:@bs2q_reference_window).card
  check(card.sections[0].join.include?('Состояния'),'equipment reference includes state susceptibility')
  check(before==Marshal.dump([actor,$game_party]),'equipment reference does not mutate inventory or actor')
  Graphics.transition(0);3.times { Graphics.update };SuiteCapture.save('BS2QA_equipment080.bmp');close_ref(equip);equip.terminate
  $game_party.gain_item($data_armors[82],1);actor.change_equip(4,$data_armors[82])
  BS2Modules::Loadouts.save(actor,1,'QA knight');set=BS2Modules::Loadouts.get(actor,1);actor.change_equip(4,nil)
  before=Marshal.dump([actor,$game_party]);view=BS2Suite::EquipmentDetails.view(actor,set)
  check(view.equips!=actor.equips && before==Marshal.dump([actor,$game_party]),'loadout totals projection preserves live state')
  check(BS2Suite::EquipmentDetails.lines(actor,view).join.include?('→'),'loadout totals show before-after changes')
  # Battle UI, real offhand technique and modal compact effects.
  $game_party.gain_item(armor,1);actor.change_equip(1,armor);actor.recover_all
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  battle=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,battle);battle.start;battle.start_actor_command_selection
  origin=battle.instance_variable_get(:@actor_command_window);origin.openness=255
  oldweapon=actor.equips[0];battle.bs2v2_cast([:skill,17,nil],:commands)
  check(actor.input.item.id==17 && actor.equips[0]==oldweapon && actor.equips[1]==armor,'offhand V cast queues native cannon skill without changing either hand')
  battle.on_enemy_cancel if battle.instance_variable_get(:@enemy_window).active
  origin.activate
  enemy=$game_troop.alive_members[0];enemy.add_state(8)
  check(BS2Suite::CombatEffects.icons(enemy).any?,'compact effects include visible enemy states and durations')
  ap=actor.instance_variable_get(:@ap);BS2Suite::CombatEffects.open(battle,origin)
  @raw.keys=[];4.times { battle.update }
  check(actor.instance_variable_get(:@ap)==ap,'compact effects modal pauses native battle time')
  Graphics.transition(0);3.times { Graphics.update };SuiteCapture.save('BS2QA_effects080.bmp');BS2Suite::CombatEffects.close(battle)
  check(origin.active,'closing effects restores the original input window')
  # Duplicate cursor update within one graphics frame must not skip a command.
  press(40);origin.select(0);origin.process_cursor_move;index=origin.index;origin.process_cursor_move
  check(index==1 && origin.index==1,'same-frame duplicate cursor update moves only once')
  # Compare native item presentation with the optional fast path.
  heal=$data_items.find { |i| i && i.itype_id==1 && i.consumable && i.effects.any? { |e| e.code==11 && (e.value1-0.3).abs<0.0001 } && !i.effects.any? { |e| e.code==44 } }
  raise 'No 30 percent healing fixture item' unless heal
  reports=[]
  [0,1].each do |fast|
    BS2Suite::Options.set('fast_items',fast)
    $game_party.gain_item(heal,2)
    actor.hp=actor.mhp/10;actor.mp=actor.mmp;actor.tp=0
    action=Game_Action.new(actor);action.set_item(heal.id);action.target_index=actor.index
    actor.instance_variable_set(:@actions,[action]);battle.instance_variable_set(:@subject,actor)
    count=$game_party.item_number(heal);hp=actor.hp;start=Graphics.frame_count
    battle.use_item
    reports<<[actor.hp-hp,count-$game_party.item_number(heal),Graphics.frame_count-start]
  end
  log('healing presentation='+reports.inspect)
  check(reports[0][0,2]==reports[1][0,2] && reports[1][1]==1,'fast item mode preserves native healing and exact consumption')
  check(reports[1][2]<reports[0][2],'fast item mode reduces actual native presentation frames')
  BS2Suite::Options.set('fast_items',0)
  battle.terminate;$game_party.on_battle_end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
