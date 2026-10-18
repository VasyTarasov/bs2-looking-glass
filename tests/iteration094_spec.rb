# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
class Keys094
  attr_accessor :keys
  def initialize;@keys=[];end
  def down;@keys.dup;end
  def focused?;true;end
end
class QueuedKeys094 < Keys094
  def initialize(sequence);@sequence=sequence;end
  def down;@sequence.shift || [];end
end
def frame(keys=[]);@raw.keys=keys;@scene.update;end
def key(n);frame;frame([n]);end
def close_palette;BS2Suite::Palette.close(@scene) if BS2Suite::Palette.current(@scene);end
begin
  File.open('test_result.txt','w') { |f| f.puts 'iteration094 native '+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_actors[1];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons;support=BS2Suite::BattleSupport
  BS2Suite::Options.set('knowledge_threshold',0)
  BS2Suite::Arsenal093::CATEGORIES.map { |g| g[1] }.flatten.each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[101]);actor.recover_all
  [61,105,3,19].each { |id| $game_party.gain_item($data_items[id],15) }
  armor=$data_armors[79]
  $game_party.gain_item(armor,4);slot=actor.equip_slots.index(4);actor.change_equip(slot,armor)
  BS2Suite::FamilyInventory.normalize
  check($game_party.item_number(armor)==3 && actor.equips[slot]==armor,'all spare and equipped ring copies are retained')
  $game_party.gain_item($data_weapons[101],5);BS2Suite::FamilyInventory.normalize
  check($game_party.item_number($data_weapons[101])<=1,'identical spare weapon copies also capped')
  check($game_party.item_number($data_items[61])==15,'ordinary consumable quantities remain intact')
  $game_party.gain_item($data_armors[9],3);armor_before=$game_party.instance_variable_get(:@armors).dup
  Game_Party.class_eval { alias bs2094_loss lose_item;def lose_item(item,amount,include_equip=false);result=bs2094_loss(item,amount,include_equip);if @bs2094_fail_armor && item.is_a?(RPG::Armor);@bs2094_fail_armor=false;raise 'synthetic armor deletion failure';end;result;end }
  $game_party.instance_variable_set(:@bs2094_fail_armor,true)
  check(BS2Suite::FamilyInventory.normalize==false && $game_party.instance_variable_get(:@armors)==armor_before,'failed armor cleanup restores exact inventory after partial deletion')
  BS2Suite::FamilyInventory.normalize
  $game_party.gain_item($data_armors[79],1);$game_party.gain_item($data_armors[161],1);BS2Suite::FamilyInventory.normalize
  check($game_party.item_number($data_armors[79])==4 && $game_party.item_number($data_armors[161])==1,'base and upgraded ring tiers coexist without deletion')
  check(BS2Modules::Loadouts.item(159)==$data_armors[161],'old loadout ring references resolve to the retained upgrade')
  # One-column pages, native two-column navigation.
  inventory=Window_ItemList.new(0,0,640,150);inventory.category=:item;inventory.refresh;inventory.select(0)
  check(inventory.col_max>1 && !BS2Suite::ListNavigation.pageable?(inventory),'multi-column inventory is never intercepted for paging')
  inventory.cursor_right;check(inventory.index==1,'inventory Right changes to right column');inventory.dispose
  equip=Window_EquipItem.new(0,0,640,150);equip.actor=actor;equip.slot_id=slot;equip.refresh
  check(equip.col_max>1 && !BS2Suite::ListNavigation.pageable?(equip),'equipment and ring columns retain native navigation');equip.dispose
  shop=Window_ShopBuy.new(0,0,150,(1..50).map { |i| [0,i,0,0] });shop.select(0)
  check(BS2Suite::ListNavigation.pageable?(shop),'single-column shop can page by screen');shop.dispose
  check(BS2Suite::Keys.token(:R)=='E','next mod page defaults to E')
  check(BS2Suite::Options.get('experimental_support')==0,'tempo prediction defaults off')
  check(support.eligible?($data_items[61]) && !support.eligible?($data_items[3]) && !support.eligible?($data_items[19]),'only safe instant items can be armed')
  check(!support.eligible?($data_skills[110]) && !support.eligible?($data_skills[127]),'ordinary techniques and magic excluded from support')
  check(support.eligible?($data_skills[18]),'Gun Break is an explicit exception')
  dummy=RPG::Enemy.new;dummy.id=5000;dummy.name='Манекен';dummy.battler_name='';dummy.params=[10000,100,50,50,50,50,50,50];$data_enemies[5000]=dummy
  troop=RPG::Troop.new;troop.id=79
  troop.members=(0..1).map { |i| m=RPG::Troop::Member.new;m.enemy_id=5000;m.x=220+i*180;m.y=190;m };$data_troops[79]=troop
  support.instance_variable_set(:@definitions,[]);support.persist
  actor.learn_skill(18);actor.learn_skill(127)
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  commands=@scene.instance_variable_get(:@actor_command_window);commands.openness=255
  BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT) if defined?(BS2Suite::HDDisplay)
  @raw=Keys094.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;frame
  %w(N V B M).each { |p| model.acknowledge(actor,p) }
  key(68);check(!support.active? && support.definitions.empty?,'D in battle commands does not toggle any support')
  key(66);popup=BS2Suite::Palette.current(@scene);key(68)
  check(support.definitions.empty?,'D at group root cannot arm a whole group')
  group=popup.entries.find { |g| model.rows(actor,'B',g[:group_number]).any? { |r| r[:id]==61 } };popup.set_group(group[:group_number])
  popup.select(popup.entries.index { |r| r[:id]==61 });key(68)
  check(support.active? && support.configured?(actor,$data_items[61]),'D on B item arms only that item')
  key(27);before=$game_party.item_number($data_items[61]);actor.clear_buffs
  24.times { frame }
  check(actor.instance_variable_get(:@buffs)[2]==2 && $game_party.item_number($data_items[61])==before-2,'basic maintenance reaches maximum using native instant items')
  enemy=$game_troop.members[0];3.times { support.tick_clock(enemy,:buff) };actor.make_actions;support.new_epoch(actor)
  check(support.reserve(enemy,:buff)==1,'basic maintenance does not infer target tempo')
  BS2Suite::Options.set('experimental_support',1)
  check(support.reserve(enemy,:buff)>1,'experimental tempo reserve remains opt-in');BS2Suite::Options.set('experimental_support',0)
  actor.instance_variable_get(:@buff_turns)[2]=1;before=$game_party.item_number($data_items[61]);24.times { frame }
  check($game_party.item_number($data_items[61])==before-1,'basic maintenance refreshes expiring maximum once')
  # Native item list gets the same D; magic does not.
  @scene.command_item;items=@scene.instance_variable_get(:@item_window);items.openness=255;items.select(items.instance_variable_get(:@data).index($data_items[61]));key(68)
  check(!support.configured?(actor,$data_items[61]),'D in native item list disables the selected rule');@scene.on_item_cancel
  @scene.command_skill;skills=@scene.instance_variable_get(:@skill_window);skills.openness=255;skills.select(skills.instance_variable_get(:@data).index($data_skills[18]));key(68)
  check(support.configured?(actor,$data_skills[18]),'D in native techniques arms highlighted Gun Break')
  skills.select(skills.instance_variable_get(:@data).index($data_skills[127]));key(68)
  check(!support.definitions.any? { |r| r['kind']=='skill' && r['id']==127 },'D on magic never adds a rule')
  @scene.on_skill_cancel;support.instance_variable_set(:@master,false)
  # Neighbour groups versus neighbour cards, all with Q/E.
  key(78);key(49);popup=BS2Suite::Palette.current(@scene);group=popup.group;index=popup.index
  key(87);check(popup.group==group,'W no longer switches mod groups')
  key(69);check(popup.group!=group,'E switches to next actual group');key(81);check(popup.group==group,'Q switches back')
  key(118);reference=@scene.instance_variable_get(:@bs2q_reference_window);title=reference.card.title
  key(69);check(reference.card.title!=title && popup.group==group,'E in VBMN F7 changes neighbouring object within same group')
  key(81);check(reference.card.title==title,'Q returns to preceding object card')
  # H suspends and restores references and palettes, including nested details.
  original=reference;original_index=popup.index;key(72)
  check(@scene.instance_variable_get(:@bs2080_effects) && !@scene.instance_variable_get(:@bs2s_palette),'H opens from palette reference without leaving a competing palette')
  key(118);check(BS2QoL::Reference.active?(@scene),'F7 inside H can open a nested participant card')
  key(27);check(!BS2QoL::Reference.active?(@scene) && @scene.instance_variable_get(:@bs2080_effects),'Esc returns from nested participant details to H')
  key(27);check(@scene.instance_variable_get(:@bs2q_reference_window).equal?(original) && BS2Suite::Palette.current(@scene).equal?(popup) && popup.index==original_index,'Esc from H restores the exact suspended F7 and palette selection')
  key(27);check(popup.active,'Esc from original F7 restores palette input')
  key(72);key(72);check(BS2Suite::Palette.current(@scene).equal?(popup) && popup.active,'H toggle also restores a plain palette')
  close_palette
  @scene.command_attack;target_window=@scene.instance_variable_get(:@enemy_window);target_window.openness=255;position=target_window.index
  key(72);check(@scene.instance_variable_get(:@bs2080_effects),'H also opens during native target selection')
  key(27);check(target_window.active && target_window.index==position,'H returns to the same target without selecting or attacking');@scene.on_enemy_cancel
  key(116);journal=@scene.instance_variable_get(:@bs2092_journal);key(72)
  check(journal && @scene.instance_variable_get(:@bs2080_effects) && !@scene.instance_variable_get(:@bs2092_journal),'H opens above the combat journal')
  key(27);check(@scene.instance_variable_get(:@bs2092_journal).equal?(journal) && journal.active,'H restores the original combat journal controller');key(27)
  commands.deactivate
  @raw.keys=[];BS2QoL::Keyboard.backend=QueuedKeys094.new([[],[72],[],[72]]);BS2QoL::Keyboard.reset;Graphics.update;Input.update
  resources=[actor.hp,actor.mp,actor.actions.size];marker=@scene.instance_variable_get(:@bs2094_h_frame)
  @scene.update_for_wait
  check(@scene.instance_variable_get(:@bs2094_h_frame)!=marker && !@scene.instance_variable_get(:@bs2080_effects) && !commands.active,'H opens and returns during animation wait without enabling actor input')
  check(resources==[actor.hp,actor.mp,actor.actions.size],'animation-wait inspection preserves hero resources and action count')
  BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;Graphics.update;Input.update;commands.activate
  # Audit every named native skill card, without an actor or hidden enemy forecast.
  audit=[];ordered=['Применение','Эффекты','Особенности','Расчёт','По целям']
  $data_skills.compact.reject { |s| s.name.to_s.empty? }.each do |skill|
    card=BS2QoL::PracticalCard.new(skill,nil,:ru)
    indices=card.section_names.map { |n| ordered.index(n) }.compact
    raise 'skill card order '+skill.id.to_s unless indices==indices.sort
    audit<<{'id'=>skill.id,'sections'=>card.section_names,'formula'=>skill.damage.formula,'guard_tag'=>skill.note.include?('<防御状態無視率:')}
  end
  check(audit.size>900,'all named native skill cards constructed and ordered')
  File.open('skill_audit_count.txt','w') { |f| f.puts audit.size }
  File.open('skill_card_audit.tsv','w') { |f| f.puts "id\tsections\tformula\tguard_tag";audit.each { |r| f.puts [r['id'],r['sections'].join(' / '),r['formula'].gsub(/[\r\n\t]/,' '),r['guard_tag']].join("\t") } }
  card=BS2QoL::PracticalCard.new($data_skills[100],actor,:ru);text=card.sections.flatten.join(' ')
  check(text.include?('без вычитания ЗАЩ') && text.include?('Guard на 100%') && !text.include?('Это не игнорирование ЗАЩ'),'Armor Piercing consistently distinguishes formula DEF and Guard')
  # Approximate means weight guard probability, criticals and hit probability.
  skill=RPG::Skill.new;skill.id=4998;skill.name='Тест урона';skill.scope=1;skill.occasion=1;skill.hit_type=1;skill.success_rate=100;skill.damage.type=1;skill.damage.formula='100';skill.damage.variance=0;skill.damage.critical=true;skill.note='<防御状態無視率:25>';$data_skills[4998]=skill
  guard=RPG::State.new;guard.id=900;guard.name='Тест защиты';guard.features=[RPG::BaseItem::Feature.new(62,Game_BattlerBase::FLAG_ID_GUARD,1)];$data_states[900]=guard;enemy.clear_states;enemy.add_state(900)
  prediction=BS2QoL::Forecast::Prediction.new(actor,enemy,skill)
  multiplier=Hi_ru_Difficulty::DIFFICULTY_SETTING[11][$game_variables[Hi_ru_Difficulty::VARIABLES]]
  expected=100*prediction.element*prediction.rate*(0.25+0.75/(2*enemy.grd))*prediction.chance*((1-prediction.crit_chance)+prediction.crit_chance*multiplier)
  check((prediction.expected_formula-expected).abs<1,'mean explicitly weights partial Guard bypass, critical and hit probability')
  if defined?(BS2Suite::HDDisplay)
    actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
    quick=BS2Suite::QuickDamage
    check(quick.lines(@scene,skill,actor).any? { |s| s.start_with?('~') && !s.include?('?') },'single-target candidate means shown before selecting from a group')
    rng=srand(701);expected_rand=rand;srand(701)
    before=Marshal.dump([actor,$game_troop.members]);result=quick.lines(@scene,skill,actor,nil,enemy)
    check(result.any? { |s| s.start_with?('≈ ') && !s.include?('?') },'chosen target enables compact approximate damage')
    check(rand==expected_rand && before==Marshal.dump([actor,$game_troop.members]),'inline forecast never rolls RNG or mutates battlers')
    # Nomination applies to the last slot of a multi-action turn; sole techniques keep their source.
    prep=RPG::Skill.new;prep.id=4995;prep.name='Подготовка теста';prep.scope=11;$data_skills[prep.id]=prep;actor.learn_skill(prep.id)
    opening=Game_Action.new(actor);opening.set_skill(prep.id)
    actor.instance_variable_set(:@actions,[opening,Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,1)
    plain=quick.lines(@scene,$data_skills[100],actor,nil,enemy).join[/≈ (\d+)/,1].to_i
    worn=actor.equips[0];direct.select(actor,$data_weapons[123])
    stronger=quick.lines(@scene,$data_skills[100],actor,nil,enemy).join[/≈ (\d+)/,1].to_i
    check(stronger>plain && actor.equips[0]==worn,'executor nomination immediately refreshes cached mean without equipping')
    direct.clear(actor)
    baseline=quick.lines(@scene,skill,actor,nil,enemy).join[/≈ (\d+)/,1].to_i
    actor.learn_skill(110);buff=Game_Action.new(actor);buff.set_skill(110)
    actor.instance_variable_set(:@actions,[buff,Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,1)
    before=Marshal.dump([actor,$game_troop.members]);buffed=quick.lines(@scene,skill,actor,nil,enemy).join[/≈ (\d+)/,1].to_i
    check(buffed>baseline && before==Marshal.dump([actor,$game_troop.members]),'queued critical buff contributes to later mean without executing')
    actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
    BS2Suite::Options.set('knowledge_threshold',100)
    check(quick.lines(@scene,skill,actor,nil,enemy).join.include?('закрыты'),'inline mean respects unknown target boundary');BS2Suite::Options.set('knowledge_threshold',0)
    footer=@scene.instance_variable_get(:@bs2q_footer)
    30.times { footer.display(@scene,actor,:commands);Graphics.update;raise 'flashing classic footer' if footer.visible }
    check(!footer.visible,'HD footer remains hidden on every rendered frame despite legacy display calls')
    check(BS2Suite::HDDisplay.data['filter']==0,'sharp pixel filter defaults on')
    # Capture the actual sidebar, including the selected-target estimate.
    actor.input.set_skill(skill.id);actor.input.target_index=enemy.index;@scene.select_enemy_selection;target_window.openness=255
    hd=BS2Suite::HDDisplay;Graphics.transition(0);Graphics.brightness=255;hd.poll(true)
    check(hd.lines(@scene).join.include?('Тест урона') && hd.lines(@scene).any? { |r| r.include?('≈ ') && !r.include?('?') },'actual target sidebar prioritises the queued attack and renders its estimate')
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I');read.call('',0)
    w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    check(size==pixels.bytesize,'native sidebar frame captured with target estimate')
    header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
    File.open('BS2QA_094_damage.bmp','wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
  end
  @scene.terminate;$game_party.on_battle_end
  if defined?(BS2Suite::HDDisplay)
    hd=BS2Suite::HDDisplay;BS2Suite::Store.write('hd_display','');hd.instance_variable_set(:@data,nil)
    monitor=([0]*6).pack('l*');hd.instance_variable_get(:@monitor).call(monitor);dimensions=monitor.unpack('l*')[1,2]
    check(hd.data.values_at('width','height')==dimensions && hd.data['mode']==1,'fresh HD target remembers monitor resolution')
    hd.singleton_class.class_eval { alias bs2094_saved_dpi dpi;alias bs2094_saved_restart restart_dpi;def dpi;[1,0,96,2560,1440,2048,1152,1];end;def restart_dpi;@bs2094_restarted=true;SceneManager.exit;true;end }
    $bs2s_private_qa=false;old_retry=ENV['BS2_CRISP_RETRY'];ENV.delete('BS2_CRISP_RETRY')
    title=Scene_Title.new;SceneManager.instance_variable_set(:@scene,title);title.start;title.post_start
    check(hd.instance_variable_get(:@bs2094_restarted) && title.instance_variable_get(:@command_window),'crisp startup initialises title safely before handing off, without loading a save')
    check(!hd.crisp_start,'crisp startup cannot loop its handoff')
    title.terminate;$bs2s_private_qa=true;old_retry ? ENV['BS2_CRISP_RETRY']=old_retry : ENV.delete('BS2_CRISP_RETRY')
    hd.singleton_class.class_eval { alias dpi bs2094_saved_dpi;alias restart_dpi bs2094_saved_restart }
  end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end

