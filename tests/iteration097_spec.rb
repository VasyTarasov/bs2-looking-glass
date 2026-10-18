# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
class Keys095
  attr_accessor :keys
  def initialize;@keys=[];end
  def down;@keys.dup;end
  def focused?;true;end
end
def frame(keys=[]);@raw.keys=keys;@scene.update;end
def key(n);frame;frame([n]);end
def queue(actor,n=2)
  actor.instance_variable_set(:@actions,Array.new(n) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0)
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'iteration095 native '+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_actors[1];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons;start=BS2Suite::StartingWeapon
  BS2Suite::Options.set('knowledge_threshold',0)
  [101,277,167,391,123].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[277]);actor.recover_all
  check(start.toggle(actor,$data_weapons[101]),'starting weapon can be stored independently')
  check(start.selected(actor)==$data_weapons[101] && !direct.selected(actor),'starting choice does not nominate final executor')
  start.instance_variable_set(:@data,nil)
  check(start.selected(actor)==$data_weapons[101],'starting choice survives preferences reload')
  check(start.toggle(actor,$data_weapons[101]) && !start.selected(actor),'repeat assignment clears start choice')
  # Real D route in equipment choice and inventory weapon category.
  @scene=Scene_Equip.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
  @raw=Keys095.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
  @scene.command_equip;@scene.instance_variable_get(:@slot_window).select(0);@scene.on_slot_ok
  window=@scene.instance_variable_get(:@item_window);window.slot_id=0;window.refresh;window.select(window.instance_variable_get(:@data).index($data_weapons[101]));window.show.activate;window.openness=255
  @scene.instance_variable_get(:@command_window).deactivate;@scene.instance_variable_get(:@slot_window).deactivate
  key(68)
  check(start.selected(actor)==$data_weapons[101] && actor.equips[0]==$data_weapons[277],'D in real equipment list assigns without equipping now')
  check(@scene.instance_variable_get(:@help_window).instance_variable_get(:@text).include?('начало хода'),'equipment shows a visible D hint')
  key(68);check(!start.selected(actor),'D in equipment toggles off rather than duplicating')
  @scene.terminate
  @scene=Scene_Item.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
  category=@scene.instance_variable_get(:@category_window);category.select(category.instance_variable_get(:@list).index { |r| r[:symbol]==:weapon });category.process_ok
  window=@scene.instance_variable_get(:@item_window);window.category=:weapon;window.refresh;window.select(window.instance_variable_get(:@data).index($data_weapons[101]));window.show.activate;window.openness=255
  @scene.instance_variable_get(:@category_window).deactivate
  key(68);check(start.selected(actor)==$data_weapons[101],'D in actual Items Weapons assigns start weapon')
  @scene.terminate
  # Three synthetic opponents with unequal DEF and an element resistance.
  troop=RPG::Troop.new;troop.id=79
  troop.members=(0..2).map do |i|
    enemy=RPG::Enemy.new;enemy.id=5000+i;enemy.name='Манекен '+(i+1).to_s;enemy.battler_name='';enemy.params=[10000,100,50,20+i*30,50,50,50,50]
    $data_enemies[enemy.id]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=enemy.id;member.x=140+i*180;member.y=190;member
  end
  $data_troops[79]=troop
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);queue(actor)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  commands=@scene.instance_variable_get(:@actor_command_window);commands.openness=255
  check(actor.equips[0]==$data_weapons[101],'first battle input uses nominated starting weapon')
  original_actions=actor.actions.dup
  BS2QoL::Model.change_weapon(actor,$data_weapons[277]);@scene.start_actor_command_selection
  check(actor.equips[0]==$data_weapons[277] && actor.actions==original_actions,'returning to same turn preserves manual weapon and slots')
  actor.instance_variable_set(:@actions,actor.actions.clone);@scene.start_actor_command_selection
  check(actor.equips[0]==$data_weapons[277],'QuickSkills restored cloned queue does not restart weapon')
  queue(actor);@scene.start_actor_command_selection
  check(actor.equips[0]==$data_weapons[101],'fresh turn returns to starting weapon')
  start.toggle(actor,$data_weapons[101]);BS2QoL::Model.change_weapon(actor,$data_weapons[277]);queue(actor);@scene.start_actor_command_selection
  check(actor.equips[0]==$data_weapons[277],'cleared start choice leaves fresh turn weapon alone')
  start.toggle(actor,$data_weapons[101]);direct.select(actor,$data_weapons[167]);queue(actor);@scene.start_actor_command_selection
  check(actor.equips[0]==$data_weapons[101] && direct.selected(actor)==$data_weapons[167],'start assignment never overwrites final executor')
  # Resolve family upgrades; missing ownership cannot conjure a weapon.
  $game_party.gain_item($data_weapons[102],1)
  check(start.selected(actor)==$data_weapons[102],'start nomination resolves upgraded family member')
  $game_party.lose_item($data_weapons[102],1)
  # Test real one-action final swaps with magic and Knight weapon technique.
  source=$data_weapons[101];tech_id=source.features.find { |f| f.code==43 }.data_id
  log('Knight technique ID='+tech_id.to_s+' '+$data_skills[tech_id].name)
  magic=$data_skills.compact.find { |s| s.magical? && s.for_one? && s.damage.to_hp? && !s.damage.recover? && s.damage.formula.include?('a.mat') && s.mp_cost>0 }
  log('Scenario: '+$data_weapons[277].name+' -> '+$data_weapons[391].name+'; magic '+magic.id.to_s+' '+magic.name)
  [magic.id,tech_id].each do |id|
    actor.learn_skill(id);actor.recover_all;BS2QoL::Model.change_weapon(actor,$data_weapons[277]);queue(actor,1)
    if id==tech_id
      @scene.start_actor_command_selection
      @scene.bs2v2_cast([:skill,id,source.id],:commands)
      @scene.instance_variable_get(:@enemy_window).hide.deactivate
    end
    action=actor.input;action.set_skill(id);action.target_index=0
    executor=id==tech_id ? source : $data_weapons[391]
    direct.select(actor,$data_weapons[391]);direct.arm(actor)
    projected=BS2Suite::SequenceForecast.new(actor,direct.selected(actor));step=projected.steps[0]
    check(step[:weapon]==executor && step[:cost],'one-action forecast uses correct platform for skill '+id.to_s)
    card=BS2QoL::PracticalCard.new(action.item,actor,:ru)
    check(card.actor.equips[0]==executor && card.sections.flatten.join.include?(id==tech_id ? 'Источник единственной техники' : 'Исполнение последнего действия'),'F7 uses correct executor/source '+id.to_s)
    action.prepare
    check(actor.equips[0]==executor && action.item.id==id && action.target_index==0 && actor.actions.size==1,'native prepare respects single-slot technique source and magic executor '+id.to_s)
    live=BS2QoL::Forecast::Prediction.new(actor,$game_troop.members[0],action.item)
    if step[:rows].any?
      check((step[:rows][0][:mean]-live.expected_formula*(live.stable ? live.repeats : 1)).abs<1,'forecast and prepared native platform agree '+id.to_s)
    end
    check(step[:cost][1][0]==actor.skill_mp_cost(action.item),'projected MP price matches actual executing Catalyst '+id.to_s)
    before_mp=actor.mp;target=$game_troop.members[0];target.recover_all;hp=target.hp
    actor.use_item(action.item);target.item_apply(actor,action.item)
    check(before_mp-actor.mp==step[:cost][1][0],'native item use pays forecast Catalyst price '+id.to_s)
    row=step[:rows][0]
    check(hp-target.hp>=row[:min] && hp-target.hp<=row[:max],'actual native hit lies in forecast range '+id.to_s) if row
    target.recover_all

  end
  # Last remaining slot in a two-action turn keeps the existing final policy.
  actor.recover_all;actor.cool_time.clear;BS2QoL::Model.change_weapon(actor,source);queue(actor,2)
  actor.actions[0].set_guard;actor.actions[1].set_skill(tech_id);actor.actions[1].target_index=0
  direct.select(actor,$data_weapons[391]);direct.arm(actor)
  report=BS2Suite::SequenceForecast.new(actor)
  check(report.steps[1][:weapon]==$data_weapons[391],'two-action forecast retains nominated final weapon for last technique')
  actor.actions.shift;actor.instance_variable_set(:@action_input_index,0);last=actor.current_action
  check(!direct.sole_source(actor,last.item,0,last),'remaining slot remembers original two-action budget')
  log('Multi available '+[actor.usable?(last.item),BS2Suite::Projection.weapon(actor,$data_weapons[391]).usable?(last.item),last.instance_variable_get(:@bs2s_direct_count)].inspect)
  last.prepare
  check(actor.equips[0]==$data_weapons[391] && last.item.id==tech_id,'last remaining multi-action technique still executes on nominated weapon')
  # Ordinary action-consuming items keep their executor and matching F7 platform.
  item=RPG::Item.new;item.id=4995;item.name='Тест предмета с действием';item.scope=1;item.occasion=1;item.damage.type=1;item.damage.formula='a.atk + a.mat';item.damage.variance=0;$data_items[item.id]=item;$game_party.gain_item(item,2)
  actor.recover_all;BS2QoL::Model.change_weapon(actor,$data_weapons[277]);queue(actor,1)
  actor.input.set_item(item.id);actor.input.target_index=0;direct.select(actor,$data_weapons[391]);direct.arm(actor)
  report=BS2Suite::SequenceForecast.new(actor);card=BS2QoL::PracticalCard.new(item,actor,:ru)
  check(report.steps[0][:weapon]==$data_weapons[391] && card.actor.equips[0]==$data_weapons[391],'ordinary item forecast and F7 keep nominated Catalyst')
  actor.input.prepare;count=$game_party.item_number(item);actor.use_item(item)
  check(actor.equips[0]==$data_weapons[391] && $game_party.item_number(item)==count-1,'ordinary item executes on Catalyst and consumes one item')
  direct.clear(actor);start.toggle(actor,$data_weapons[101]);actor.recover_all;queue(actor)
  # Failed preference writes and forced queues cannot change the assignment.
  stored=start.selected(actor)
  BS2Suite::Store.singleton_class.class_eval { alias bs2095_saved_write write;def write(name,text);name=='starting_weapons' ? false : bs2095_saved_write(name,text);end }
  check(!start.toggle(actor,$data_weapons[277]) && start.selected(actor)==stored,'failed preference write restores previous starting choice')
  BS2Suite::Store.singleton_class.class_eval { alias write bs2095_saved_write }
  # Actual skill-list self confirmation path, preserving companion selection.
  skill=RPG::Skill.new;skill.id=4999;skill.name='Тест на себя';skill.scope=7;skill.stype_id=1;skill.occasion=0;skill.mp_cost=1;skill.effects=[RPG::UsableItem::Effect.new(31,2,3,0)];$data_skills[4999]=skill;actor.learn_skill(4999)
  @scene.start_actor_command_selection;@scene.command_skill;window=@scene.instance_variable_get(:@skill_window);window.select(window.instance_variable_get(:@data).index(skill));window.process_ok
  check(!@scene.instance_variable_get(:@actor_window).active && actor.actions[0].target_index==actor.index && actor.instance_variable_get(:@action_input_index)==1,'native technique skips sole hero target confirmation exactly once')
  ally=$game_actors[2];$game_party.add_actor(2);ally.recover_all;queue(actor);@scene.start_actor_command_selection;@scene.command_skill;window.select(window.instance_variable_get(:@data).index(skill));window.process_ok
  check(@scene.instance_variable_get(:@actor_window).active && actor.instance_variable_get(:@action_input_index)==0,'living companion retains actual actor target window')
  @scene.instance_variable_get(:@actor_window).process_cancel;@scene.instance_variable_get(:@skill_window).process_cancel
  ally.hp=0
  check(BS2Suite::SoloTarget.hero_only?(skill,actor,true),'dead companion is not a living heal target')
  revive=RPG::Item.new;revive.scope=9
  check(!BS2Suite::SoloTarget.hero_only?(revive,actor,true),'only dead companion never redirects revive to hero')
  $game_party.remove_actor(2);queue(actor);@scene.start_actor_command_selection
  %w(V B M N).each { |p| model.acknowledge(actor,p) }
  quick_item=$data_items[61];$game_party.gain_item(quick_item,3)
  count=$game_party.item_number(quick_item)
  start.toggle(actor,$data_weapons[101]);queue(actor);@scene.start_actor_command_selection
  BS2QoL::Model.change_weapon(actor,$data_weapons[277]);before_actions=actor.actions.dup
  @scene.command_item;window=@scene.instance_variable_get(:@item_window);window.select(window.instance_variable_get(:@data).index(quick_item));window.process_ok
  check($game_party.item_number(quick_item)==count-1 && actor.actions==before_actions && actor.equips[0]==$data_weapons[277],'real instant item skips sole hero confirmation and preserves queue and manually chosen weapon')
  start.toggle(actor,$data_weapons[101]);queue(actor);@scene.start_actor_command_selection
  # Forecast display against multiple targets is N-only; V/M still needs a target.
  if defined?(BS2Suite::QuickDamage)
    BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT)
    actor.recover_all;BS2QoL::Model.change_weapon(actor,$data_weapons[101]);queue(actor,1);direct.clear(actor)
    quick=BS2Suite::QuickDamage;weapon=$data_weapons[101];view=BS2Suite::Projection.weapon(actor,weapon);normal=$data_skills[view.attack_skill_id]
    snapshot=Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items),$game_party.gold]);srand(713);expected=rand;srand(713)
    values=$game_troop.alive_members.map { |t| quick.target_mean(normal,actor,weapon,t)[0] }
    text=quick.lines(@scene,normal,actor,weapon,nil,weapon).join
    check(text.include?(quick.compact_means(values)) && text.scan(/~\d+/).size==3,'N shows minimum arithmetic mean maximum for three unequal opponents')
    check(snapshot==Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items),$game_party.gold]) && rand==expected,'multi-target preview preserves battlers inventory and RNG')
    check(quick.lines(@scene,normal,actor,weapon).empty?,'ordinary technique preview still waits for target against a group')
    $game_troop.members[2].hide
    text=quick.lines(@scene,normal,actor,weapon,nil,weapon).join
    check(text.scan(/~\d+/).size==2,'two visible enemies show two expected values')
    area=Marshal.load(Marshal.dump(normal));area.id=4997;area.name='Тест массовой атаки';area.scope=2;$data_skills[area.id]=area;actor.learn_skill(area.id)
    area_values=$game_troop.alive_members.map { |t| quick.target_mean(area,actor,weapon,t)[0] }
    check(quick.lines(@scene,area,actor,weapon,nil,weapon).join.include?(quick.compact_means(area_values)),'all-target N displays per-enemy estimates rather than summed damage')
    random=Marshal.load(Marshal.dump(area));random.id=4996;random.name='Тест случайной атаки';random.scope=4;$data_skills[random.id]=random;actor.learn_skill(random.id)
    random_values=$game_troop.alive_members.map { |t| quick.target_mean(random,actor,weapon,t)[0] }
    check(quick.lines(@scene,random,actor,weapon,nil,weapon).join.include?(quick.compact_means(random_values)),'random N includes target selection probability in per-enemy estimate')
    actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,1)
    check(quick.target_mean(random,actor,weapon,$game_troop.members[0]).nil?,'random-target series with prior slots declines an unsupported total')
    queue(actor,1)
    check(quick.compact_means([100,101,102])=='~100','near-equal estimates collapse by three percent')
    check(quick.compact_means([0,0,0])=='~0','identical zero estimates collapse once')
    $game_troop.members[1].hide
    check(quick.lines(@scene,normal,actor,weapon,nil,weapon).join.include?('≈ '),'one enemy retains normal inline estimate')
    $game_troop.members.each { |e| e.appear };BS2Suite::Options.set('knowledge_threshold',100)
    check(quick.lines(@scene,normal,actor,weapon,nil,weapon).join.include?('закрыты'),'multi-target N does not expose unknown resistance')
    BS2Suite::Options.set('knowledge_threshold',0)
    @scene.start_actor_command_selection;commands.openness=255
    key(78);key(49);popup=BS2Suite::Palette.current(@scene)
    check(BS2Suite::HDDisplay.palette_rows(popup).any? { |r| r.include?('~') },'real N sidebar includes multi-target estimate')
    hd=BS2Suite::HDDisplay;Graphics.transition(0);Graphics.brightness=255;hd.poll(true)
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I');read.call('',0)
    w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    check(size==pixels.bytesize,'native N multi-enemy sidebar frame captured')
    header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
    File.open('BS2QA_095_n.bmp','wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }

  end
  @scene.terminate;$game_party.on_battle_end
  # Menu items and magic use normal resource application without actor popup.
  item=RPG::Item.new;item.id=4999;item.name='Тест лечения';item.scope=7;item.occasion=0;item.effects=[RPG::UsableItem::Effect.new(11,0,0,100)];$data_items[item.id]=item;$game_party.gain_item(item,3)
  actor.recover_all;actor.hp-=500
  @scene=Scene_Item.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
  category=@scene.instance_variable_get(:@category_window);category.select(0);category.process_ok
  list=@scene.instance_variable_get(:@item_window);list.category=:item;list.refresh;list.select(list.instance_variable_get(:@data).index(item))
  hp=actor.hp;count=$game_party.item_number(item);@scene.on_item_ok
  check(actor.hp==hp+100 && $game_party.item_number(item)==count-1 && !@scene.instance_variable_get(:@actor_window).active && list.active,'menu item auto-confirms hero and consumes exactly one item')
  $game_party.add_actor(2);ally.recover_all;list.select(list.instance_variable_get(:@data).index(item));@scene.on_item_ok
  check(@scene.instance_variable_get(:@actor_window).active && $game_party.item_number(item)==count-1,'menu item retains confirmation with living companion')
  @scene.on_actor_cancel;@scene.terminate;$game_party.remove_actor(2)
  @scene=Scene_Skill.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
  list=@scene.instance_variable_get(:@item_window);list.stype_id=1;list.refresh;list.select(list.instance_variable_get(:@data).index(skill));list.activate
  mp=actor.mp;@scene.on_item_ok
  check(actor.mp==mp-actor.skill_mp_cost(skill) && !@scene.instance_variable_get(:@actor_window).active && list.active,'menu skill auto-confirms hero and pays MP once')
  @scene.terminate
  check(start.selected(actor).nil?,'cleared starting choice remains cleared after battle')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
