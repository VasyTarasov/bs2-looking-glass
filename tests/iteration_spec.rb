# encoding: UTF-8
@checks=0
def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
def check(v,label);raise 'Assertion: '+label unless v;@checks+=1;log('PASS '+label);end
class BS2V2Raw
  attr_accessor :keys,:focus
  def initialize;@keys=[];@focus=true;end
  def down;@keys.dup;end
  def focused?;@focus;end
end
def frame(keys=[],window=nil)
  @raw.keys=keys;Graphics.update;Input.update;window.update if window
end
def chord(key,window=nil)
  frame([],window);values=[]
  values<<16 if key.start_with?('S') || key.start_with?('CS')
  values<<17 if key.start_with?('C')
  values<<key[-1,1].to_i+48
  frame(values,window)
end
def battle(actor,troop=79)
  BattleManager.setup(troop,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  @commands=@scene.instance_variable_get(:@actor_command_window)
  @commands.openness=255
end
def end_battle
  @scene.terminate;$game_party.on_battle_end
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'iteration_060; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  [101,156,255].each { |id| $game_party.gain_item($data_weapons[id],1) }
  [137,217].each { |id| $game_party.gain_item($data_armors[id],1) }
  actor.change_equip(0,$data_weapons[255]);actor.change_equip(1,$data_armors[217]);actor.change_equip(actor.equip_slots.index(4),$data_armors[137]);actor.recover_all
  [308,110].each { |id| actor.forget_skill(id) };actor.learn_skill(14);actor.learn_skill(120);actor.learn_skill(340)
  @raw=BS2V2Raw.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;frame
  bindings=BS2QoL::Bindings;bindings.instance_variable_set(:@data,{})
  BS2Suite::Keys.instance_variable_set(:@data,BS2Suite::Keys::DEFAULT.dup)
  check(BS2Suite::Keys::DEFAULT.size==BS2Suite::Keys::LABELS.size,'every new configurable mod action has a label')
  check(BS2Suite::WeaponFamilies.root(156)==BS2Suite::WeaponFamilies.root(157),'club +1 follows the actual synthesis recipe')
  check(BS2Suite::WeaponFamilies.root(156)==BS2Suite::WeaponFamilies.root(166),'renamed final club remains in same recipe family')
  check(BS2Suite::WeaponFamilies.root(255)!=BS2Suite::WeaponFamilies.root(156),'unrelated weapons remain separate')
  check(bindings.set('quick','C1',:skill,308),'legacy weapon technique assignment accepted')
  check(bindings.get('quick','C1',actor)==[:skill,308] && !bindings.data['quick'].has_key?('C1'),'old global technique migrates to the weapon family')
  check(bindings.set('weapon156','C1',:skill,110),'same Ctrl slot can hold another weapon technique')
  check(bindings.set('quick','C2',:skill,14),'learned magic has a stable shared slot')
  [255,156,101].each_with_index { |id,i| bindings.set('weapons','S'+(i+1).to_s,:weapon,id) }
  battle(actor)
  check(actor.actions.size>=3,'example uses native extra actions from real equipment')
  chord('S1',@commands);chord('C1',@commands)
  log('trace='+[actor.equips[0].id,actor.actions.map { |a| a.item && a.item.id },BS2QoL::Hotkeys.current_notice,BS2QoL::Hotkeys.context(@scene),actor.usable?($data_skills[308]),actor.skills.map { |s| s.id }].inspect)
  check(actor.actions.any? { |a| a.item && a.item.id==308 },'Broken Sword Ctrl1 queues Self-Flagellation through native input')
  chord('S2',@commands);chord('C1',@commands)
  check(actor.actions.any? { |a| a.item && a.item.id==110 },'Club Ctrl1 queues Battle Surge without replacing Broken Sword slot')
  check(bindings.get('quick','C2',actor)==[:skill,14],'shared magic is stable after weapon switch')
  chord('S3',@commands)
  check(actor.equips[0].id==101,'third direct weapon remains independent of technique profiles')
  chord('1',@commands)
  check(@scene.instance_variable_get(:@enemy_window).active,'multiple living enemies retain target selection')
  old=actor.equips[0];chord('S1',@scene.instance_variable_get(:@enemy_window))
  check(actor.equips[0]==old,'weapon keys cannot leak through target selection')
  enemy_window=@scene.instance_variable_get(:@enemy_window)
  frame([],enemy_window);frame([118],enemy_window)
  check(BS2QoL::Reference.active?(@scene),'F7 on a selected enemy opens resistances')
  popup=@scene.instance_variable_get(:@bs2q_reference_window)
  check(popup.card.object.is_a?(Game_Enemy) && popup.card.section_names.include?('Состояния'),'enemy card separates damage resistances and state susceptibility')
  BS2QoL::Reference.close(@scene)
  check(enemy_window.active,'enemy card returns to original target selection')
  end_battle
  actor.change_equip(0,$data_weapons[156]);$game_party.lose_item($data_weapons[156],99,true);$game_party.gain_item($data_weapons[157],1)
  battle(actor);chord('S2',@commands)
  check(actor.equips[0].id==157,'existing weapon shortcut resolves +1 after original weapon is consumed')
  check(bindings.get('quick','C1',actor)==[:skill,110],'weapon technique profile survives upgrade')
  check(bindings.set('cast','CS1',:skill,308,255),'auto-equip technique assignment persists source weapon')
  frame([],@commands);frame([16,17,49],@commands)
  check(actor.equips[0].id==255 && actor.actions.any? { |a| a.item && a.item.id==308 },'Ctrl Shift1 switches to source and queues the real technique')
  before=actor.actions.map { |a| a.item && a.item.id };frame([16,17,49],@commands)
  check(actor.actions.map { |a| a.item && a.item.id }==before,'held triple chord does not repeat')
  end_battle
  actor.change_equip(0,$data_weapons[157]);actor.mp=0
  battle(actor);before=Marshal.dump([$game_party,$game_actors]);chord('CS1',@commands)
  check(Marshal.dump([$game_party,$game_actors])==before,'failed auto-equip skill restores weapon resources inventory and queue')
  end_battle;actor.recover_all
  battle(actor)
  $game_troop.members[1..-1].each { |e| e.hide };chord('1',@commands)
  check(!@scene.instance_variable_get(:@enemy_window).active && actor.actions.any? { |a| a.item && a.target_index==0 },'single living enemy is confirmed automatically using its real index')
  end_battle
  battle(actor)
  window=@scene.instance_variable_get(:@skill_window);@scene.command_skill;window.refresh
  window.select(window.instance_variable_get(:@data).index($data_skills[110]));frame([],window);frame([117],window)
  popup=@scene.instance_variable_get(:@bs2q_binding_window)
  check(!!popup,'F6 opens actual assignment editor')
  chord('C0');BS2QoL::Hotkeys.update_modal(@scene)
  check(popup.pending==['weapon156','C0'],'editor assigns Ctrl0 in the current weapon family')
  frame([]);frame([13]);BS2QoL::Hotkeys.update_modal(@scene)
  check(bindings.get('quick','C0',actor)==[:skill,110],'editor confirms ten-slot weapon profile through real Enter input')
  end_battle
  saved=Marshal.dump(bindings.data);bindings.persist;bindings.instance_variable_set(:@data,nil)
  check(bindings.data==Marshal.load(saved),'v2 profiles and source weapons survive settings reload')

  raw=Marshal.dump([$game_party,$game_actors,$game_variables,$game_switches]);srand(613);expected=rand(1000000);srand(613)
  [120,340].each do |id|
    card=BS2QoL::PracticalCard.new($data_skills[id],actor,:ru)
    check(card.sections.size==1 && !card.sections.flatten.join.include?($data_skills[id].damage.formula),'field card omits inactive formula and empty tabs '+id.to_s)
  end
  [101,157,255,166].each { |id| check(!BS2QoL::PracticalCard.new($data_weapons[id],actor,:en).sections.empty?,'English weapon card '+id.to_s) }
  [82,137,217].each { |id| check(!BS2QoL::PracticalCard.new($data_armors[id],actor,:ru).sections.empty?,'armor card '+id.to_s) }
  check(Marshal.dump([$game_party,$game_actors,$game_variables,$game_switches])==raw && rand(1000000)==expected,'equipment and field cards preserve game state and RNG')
  battle(actor);target=$game_troop.alive_members[0];skill=$data_skills[838];actor.learn_skill(838)
  actor.mp=actor.skill_mp_cost(skill)
  native=skill.damage.eval(actor,target,$game_variables)
  actor.pay_skill_cost(skill);zero=skill.damage.eval(actor,target,$game_variables)
  check(actor.mp==0 && zero==0,'Rending Grudge zero-MP edge is confirmed by native Damage.eval')
  actor.recover_all
  card=BS2QoL::PracticalCard.new(skill,actor,:ru)
  check(card.sections[0].join.include?('ПОСЛЕ') && card.sections[0].join.include?('0 урона'),'special Grudge card explains cost timing and zero-MP trap first')
  probe=Game_Actor.new(actor.id);probe.change_class(1);probe.clear_equipments;probe.clear_states;probe.clear_buffs
  $game_party.gain_item($data_armors[232],1);probe.change_equip(probe.equip_slots.index(4),$data_armors[232])
  baseline=[probe.param_rate(3),probe.param_rate(5),probe.hrg,probe.mrg]
  probe.on_battle_start
  check(probe.state?(170) && probe.param_rate(3)==baseline[0]*9 && probe.param_rate(5)==baseline[1]*9 && probe.hrg==baseline[2]+1 && probe.mrg==baseline[3],'Indomitable ring native battle-start state is DEF MDF x9 HP regen only')
  [:ru,:en].each do |language|
    ring=BS2QoL::PracticalCard.new($data_armors[232],probe,language)
    check(ring.sections.flatten.join.include?('+800%'),'Indomitable ring description discrepancy is explicit in '+language.to_s)
  end
  feature_before=Marshal.dump([$data_weapons,$data_armors,$data_states].map { |db| db.compact.map { |x| x.features } })
  count=0
  [$data_skills,$data_items,$data_weapons,$data_armors].each do |database|
    database.compact.each do |object|
      next if object.name.empty?
      [:ru,:en].each do |lang|
        c=BS2QoL::PracticalCard.new(object,actor,lang)
        raise 'Empty or mismatched card '+object.id.to_s unless !c.sections.empty? && c.sections.size==c.section_names.size && c.sections.all? { |v| !v.empty? }
        count+=1
      end
    end
  end
  check(count>3000,'all named skills items weapons and armors build useful nonempty RU EN sections: '+count.to_s)
  check(feature_before==Marshal.dump([$data_weapons,$data_armors,$data_states].map { |db| db.compact.map { |x| x.features } }),'practical trait aggregation leaves every original equipment and state feature unchanged')
  end_battle

  map=Scene_Map.new;SceneManager.instance_variable_set(:@scene,map);$game_map.interpreter.clear
  $game_player.moveto(0,0);$game_message.clear;$game_temp.clear_common_event
  auto=BS2Suite::AutoStealth;auto.instance_variable_set(:@actor_id,0);actor.recover_all
  check(auto.toggle(actor) && auto.actor_id==actor.id,'field invisibility auto-cast can be enabled')
  $game_player.reset_stealth;mp=actor.mp;price=actor.skill_mp_cost($data_skills[120]);auto.update(map)
  check(actor.mp==mp-price && auto.remaining==150 && $game_temp.common_event_reserved?,'auto-cast pays actual cost and follows native stealth and common-event path')
  mp=actor.mp;auto.update(map);check(actor.mp==mp,'active stealth is not recast or charged twice')
  $game_temp.clear_common_event;$game_player.reset_stealth;actor.mp=0;auto.update(map)
  check(actor.mp==0 && auto.remaining==0 && auto.status.include?('MP'),'insufficient MP suspends renewal without repeated side effects')
  actor.recover_all;$game_message.add('QA dialogue');mp=actor.mp;auto.update(map)
  check(actor.mp==mp && auto.remaining==0,'dialogue blocks automatic field casting')
  $game_message.clear;auto.toggle(actor);auto.update(map)
  check(auto.actor_id==0 && auto.remaining==0,'auto-cast can be disabled in field settings')

  # Only these new QA files are created in the verified isolated test directory.
  (100..104).each { |id| File.delete(DataManager.make_filename(id)) if File.file?(DataManager.make_filename(id)) }
  check(DataManager.savefile_max==105,'five extra quick slots preserve all 100 manual slots')
  $game_system.save_disabled=false
  5.times { |i| check(BS2Suite::QuickSaves.save(map),'quick save writes reserved slot '+(i+1).to_s) }
  check((100..104).all? { |id| File.file?(DataManager.make_filename(id)) },'five rotating quick saves are real independent native files')
  (100..104).each { |id| File.utime(Time.at(1000+id),Time.at(1000+id),DataManager.make_filename(id)) }
  check(BS2Suite::QuickSaves.next_slot==100,'sixth quick save chooses oldest history entry')
  before=File.open(DataManager.make_filename(100),'rb') { |f| f.read }
  module BS2Suite::Saves
    class << self
      alias qa_v2_replace replace
      def replace(*args);raise IOError,'QA quick write failure';end
    end
  end
  check(!BS2Suite::QuickSaves.save(map) && File.open(DataManager.make_filename(100),'rb') { |f| f.read }==before,'failed quick save preserves previous complete entry')
  module BS2Suite::Saves;class << self;alias replace qa_v2_replace;end;end
  $game_system.save_disabled=true
  check(!BS2Suite::QuickSaves.save(map),'game save prohibition blocks quick save')
  $game_system.save_disabled=false;$game_message.add('QA dialogue')
  check(!BS2Suite::QuickSaves.save(map),'dialogue blocks quick save')
  $game_message.clear
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  (100..104).each { |id| path=DataManager.make_filename(id);File.delete(path) if File.file?(path) } if defined?(BS2Suite::QuickSaves)
  exit
end
