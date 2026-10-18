# encoding: UTF-8
@checks=0
def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
def check(v,label);raise 'Assertion: '+label unless v;@checks+=1;log('PASS '+label);end
class BS2QReferenceRaw
  attr_accessor :keys,:focus
  def initialize;@keys=[];@focus=true;end
  def down;@keys.dup;end
  def focused?;@focus;end
end
module Input
  class << self
    attr_accessor :spec_key
    def trigger?(key);@spec_key==key;end
    def repeat?(key);@spec_key==key;end
    def press?(key);@spec_key==key;end
  end
end
def frame(keys=[],window=nil,scene=nil)
  @raw.keys=keys;Graphics.update;Input.update
  window.update if window
  BS2QoL::Reference.update(scene) if scene
end
def raw_key(vk,window=nil,scene=nil)
  frame([],window,scene);frame([vk],window,scene)
end
def logical_key(key,scene)
  Input.spec_key=key;frame([],nil,scene);Input.spec_key=nil
end
def texts(card);card.sections.flatten.join("\n");end
def snapshot
  temp=$game_temp.instance_variables.sort.map { |key| [key,$game_temp.instance_variable_get(key).inspect] }
  Marshal.dump([$game_party,$game_actors,temp,$game_variables,$game_switches])
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'reference_suite; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(20,false);actor.clear_equipments
  [14,18,31,350].each { |id| actor.learn_skill(id) }
  $game_party.gain_item($data_items[1],5)
  $game_party.gain_item($data_weapons[384],1);actor.change_equip(0,$data_weapons[384])
  $game_party.gain_item($data_armors[137],1)
  slot=actor.equip_slots.index(4);actor.change_equip(slot,$data_armors[137]);actor.recover_all
  check(BS2QoL::VERSION=='0.7.1-alpha','reference release loads in native RGSS3')
  check(BS2QoL::ReferenceData::EN[:skill].size==990 && BS2QoL::ReferenceData::EN[:item].size==246,'English names and source descriptions cover every named skill and item')
  ru=BS2QoL::ReferenceCard.new($data_skills[14],actor,:ru)
  en=BS2QoL::ReferenceCard.new($data_skills[14],actor,:en)
  check(ru.title.include?('Стрела Души') && en.title.include?('Soul Arrow'),'both languages use verified game names')
  check(en.sections[0].include?('Current cost: '+en.costs($data_skills[14])),'current price uses final actor cost methods')
  check(texts(en).include?('damage x3.'),'critical card reflects final difficulty override rather than base x2')
  check(texts(en).include?('MAT of user * 5 - MDF of target * 2'),'formula is also readable with stat names')
  actor.add_state(66)
  variant=BS2QoL::ReferenceCard.new($data_skills[350],actor,:en)
  action=Game_Action.new(actor);action.set_skill(350)
  check(variant.resolved.id==action.item.id && variant.resolved.id==351,'card variant agrees with native Game_Action state substitution')
  check(variant.sections[0].any? { |s| s.include?('Current variant:') },'card distinguishes original selection from resolved variant')
  actor.remove_state(66)
  counter=$data_skills.compact.find { |s| s.note.include?('<使用後追加行動:922,-2,50>') }
  check(counter && texts(BS2QoL::ReferenceCard.new(counter,actor,:en)).include?('chance 51%'),'inclusive post-action threshold is disclosed as 51 percent')
  probe=Marshal.load(Marshal.dump(actor))
  class << probe
    attr_accessor :reference_roll
    def rand(limit);@reference_roll;end
  end
  [0,49,50,51,99].each do |roll|
    probe.reference_roll=roll
    probe.instance_variable_set(:@actions,[Game_Action.new(probe)])
    probe.add_after_action(counter)
    check(probe.actions.size==(roll<=50 ? 2 : 1),'native follow-up comparison boundary roll '+roll.to_s)
  end
  penetration=$data_skills.compact.find { |s| s.note.include?('<ダメージ率貫通:1,100>') }
  check(texts(BS2QoL::ReferenceCard.new(penetration,actor,:en)).include?('no standalone effect'),'inactive passive penetration tag on skill is not advertised as working penetration')
  flask=BS2QoL::ReferenceCard.new($data_items[1],actor,:en)
  check(texts(flask).include?('MaxHP * 0.5') && texts(flask).include?('REC * PHA'),'flask recovery exposes actual percentage and both recovery multipliers')
  check(texts(flask).include?('whole party') && texts(flask).include?('storage'),'instant party limit and storage meaning explained')
  soul=$data_items.compact.find { |i| i.effects.any? { |e| e.code==44 && e.data_id==24 } }
  check(texts(BS2QoL::ReferenceCard.new(soul,actor,:en)).include?('Gain souls: +2000.'),'common-event currency item shows verified numeric reward')
  green=$data_items.compact.find { |i| i.effects.any? { |e| e.code==44 && e.data_id==225 } }
  check(texts(BS2QoL::ReferenceCard.new(green,actor,:en)).include?('ATK +2'),'stat soul uses actual event amount rather than assumed plus one')
  cure=BS2QoL::ReferenceCard.new($data_skills[31],actor,:en)
  check($data_skills[31].effects.count { |e| e.code==22 }==cure.sections[1].count { |s| s.start_with?('Remove ') },'Cure enumerates actual removable states rather than all debuffs')
  check(BS2QoL::ReferenceCard.new($data_skills[18],actor,:en).read_cooldown($data_skills[18])==0,'reading absent cooldown does not create an entry')

  # Exhaustive cards: malicious eval detector, exact state snapshot, and RNG oracle.
  class RPG::UsableItem::Damage
    alias bs2q_reference_test_eval eval
    def eval(*args);raise 'Reference executed a damage formula';end
  end
  before=snapshot;srand(7712);expected=Array.new(12) { rand };srand(7712)
  exports=[];count=0;gaps=[]
  [:ru,:en].each do |lang|
    [[:skill,$data_skills],[:item,$data_items]].each do |kind,objects|
      objects.compact.each do |obj|
        next if obj.name.strip.empty?
        card=BS2QoL::ReferenceCard.new(obj,actor,lang)
        raise 'Empty reference section' unless card.sections.size==5 && card.sections.all? { |s| s.is_a?(Array) && !s.empty? }
        gaps << [kind,obj.id] if texts(card).include?('full outcome has not yet been decoded')
        offline=BS2QoL::ReferenceCard.new(obj,nil,lang)
        exports << [lang.to_s,kind.to_s,obj.id,offline.title,offline.section_names,offline.sections]
        count+=1
      end
    end
  end
  check(count==2472,'all 1236 records build successfully in both languages')
  check(rand==expected[0] && Array.new(11) { rand }==expected[1,11],'exhaustive card generation consumes no RNG')
  check(snapshot==before,'exhaustive cards leave actors inventory resources states variables cooldowns and queue byte-identical')
  File.open('reference_export.bin','wb') { |f| Marshal.dump(exports,f) }
  File.open('reference_gaps.txt','w') { |f| f.puts gaps.uniq.map { |r| r.join(':') } }
  class RPG::UsableItem::Damage
    alias eval bs2q_reference_test_eval
  end
  check(actor.apply_critical(100)==300,'final native critical calculation confirms threefold multiplier')
  before_mp=actor.mp;price=actor.skill_mp_cost($data_skills[14]);actor.pay_skill_cost($data_skills[14])
  check(before_mp-actor.mp==price,'displayed effective MP cost equals the native resource deduction')
  actor.recover_all
  # Verify representative descriptions against native outcomes on disposable fixtures.
  actor.hp=1
  expected_heal=((actor.mhp*0.5)*actor.rec*actor.pha).to_i
  old_hp=actor.hp;actor.item_apply(actor,$data_items[1])
  check(actor.hp==[old_hp+expected_heal,actor.mhp].min,'flask effect matches stated percentage times REC times PHA in actual item_apply')
  target=Game_Actor.new(1);target.change_class(1);target.clear_equipments
  $game_party.gain_item($data_armors[82],1);target.change_equip(target.equip_slots.index(4),$data_armors[82]);target.recover_all
  neutral=Marshal.load(Marshal.dump($data_skills[14]));neutral.damage.formula='1000';neutral.damage.variance=0;neutral.damage.element_id=1;neutral.hit_type=1
  target.result.clear;target.make_damage_value(actor,neutral)
  check(target.result.hp_damage==640,'real Ring of Steel Protection produces 640 from 1000 through independent element and PDR multipliers')
  neutral.hit_type=0;target.result.clear;target.make_damage_value(actor,neutral)
  check(target.result.hp_damage==800,'base certain-hit type skips PDR but retains elemental multiplier')
  actor.recover_all

  # Test the true input route in battle, including modal isolation and cancellation.
  @raw=BS2QReferenceRaw.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@phase,:input);BattleManager.instance_variable_set(:@actor_index,0)
  scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
  command=scene.instance_variable_get(:@actor_command_window);command.openness=255
  frame([],command);raw_key(0x32,command)
  skills=scene.instance_variable_get(:@skill_window);skills.openness=255;skills.select(skills.instance_variable_get(:@data).index($data_skills[14]))
  BS2QoL::Reference.language=:ru
  before=snapshot;raw_key(0x76,skills,scene)
  popup=scene.instance_variable_get(:@bs2q_reference_window)
  check(popup && !skills.active && popup.card.object.id==14,'raw F7 opens the selected native skill and suspends its list')
  check(!BS2QoL::Hotkeys.context(scene),'battle command hotkeys have no context under the reference')
  frame([0x76],skills,scene)
  check(scene.instance_variable_get(:@bs2q_reference_window)==popup,'holding F7 does not immediately close the reference')
  frame([],skills,scene);frame([0x11,0x31],skills,scene)
  check(snapshot==before,'Ctrl quick slot cannot use an item behind the reference')
  logical_key(:RIGHT,scene);logical_key(:RIGHT,scene)
  check(popup.card.section_names[popup.section]=='Расчёт','native right key selects concise calculation section')
  logical_key(:R,scene);check(popup.offset>=0 && popup.lines.size>0,'native page key handles concise explanations')
  raw_key(0x77,nil,scene)
  check(popup.card.language==:en && popup.card.title.start_with?('Soul Arrow'),'raw F8 switches all card text and title to English')
  BS2QoL::Reference.instance_variable_set(:@language,nil)
  check(BS2QoL::Reference.language==:en,'language choice survives disk reload')
  logical_key(:B,scene)
  check(!scene.instance_variable_get(:@bs2q_reference_window) && skills.active && skills.item.id==14,'Esc returns to the exact original selection')
  check(snapshot==before,'opening scrolling changing language and closing do not alter battle state')
  # Loss of focus and modifiers must not open the card.
  frame([],skills);frame([0x10,0x76],skills)
  check(!scene.instance_variable_get(:@bs2q_reference_window),'Shift F7 is ignored')
  @raw.focus=false;raw_key(0x76,skills);check(!scene.instance_variable_get(:@bs2q_reference_window),'unfocused F7 is ignored')
  @raw.focus=true;frame([0x76],skills);check(!scene.instance_variable_get(:@bs2q_reference_window),'returning focus with F7 held does not open reference')
  raw_key(0x76,skills,scene);check(!!scene.instance_variable_get(:@bs2q_reference_window),'released and repressed F7 works after refocus')
  raw_key(0x76,nil,scene);check(skills.active,'F7 also closes and restores control')
  Input.spec_key=:C;frame([],skills);Input.spec_key=nil
  enemy=scene.instance_variable_get(:@enemy_window)
  check(enemy.active,'native confirm proceeds from inspected skill to enemy selection')
  raw_key(0x76,enemy,scene);check(!!scene.instance_variable_get(:@bs2q_reference_window),'F7 inspects selected enemy without choosing the target');BS2QoL::Reference.close(scene)
  Input.spec_key=:B;frame([],enemy);Input.spec_key=nil
  check(skills.active && !enemy.active,'native target cancel returns to skill list after reference use')
  # Cannot use F7 through the assignment editor.
  raw_key(0x75,skills);BS2QoL::Hotkeys.update_modal(scene)
  check(!!scene.instance_variable_get(:@bs2q_binding_window),'F6 assignment editor still works')
  raw_key(0x76,skills,scene);check(!scene.instance_variable_get(:@bs2q_reference_window),'reference does not open through binding editor')
  BS2QoL::Hotkeys.close_binding(scene)
  # Selected item, including an unusable field item, is inspectable without use.
  skills.deactivate;scene.command_item
  items=scene.instance_variable_get(:@item_window);items.openness=255
  items.select(items.instance_variable_get(:@data).index($data_items[1]))
  $game_party.menu_actor=$game_actors[2]
  raw_key(0x76,items,scene)
  check(scene.instance_variable_get(:@bs2q_reference_window).card.object==$data_items[1],'native battle item list opens the correct item card')
  check(scene.instance_variable_get(:@bs2q_reference_window).card.actor==actor,'battle item card uses current combat actor rather than menu actor')
  $game_party.menu_actor=actor
  BS2QoL::Reference.close(scene)
  scene.terminate

  menu=Scene_BS2QFavorites.new;SceneManager.instance_variable_set(:@scene,menu);menu.start;menu.open_item
  list=menu.instance_variable_get(:@collection);list.openness=255;list.select(0)
  raw_key(0x76,list,menu)
  check(!!menu.instance_variable_get(:@bs2q_reference_window),'reference works in the existing menu collection')
  menu.terminate
  check(!menu.instance_variable_get(:@bs2q_reference_window),'scene termination disposes a still-open reference safely')
  $game_party.add_actor(2);other=$game_actors[2];other.recover_all
  class << other;def pha;3.0;end;end
  field=Scene_Item.new;SceneManager.instance_variable_set(:@scene,field);field.start
  list=field.instance_variable_get(:@item_window);list.category=:item;list.openness=255;list.activate
  list.select(list.instance_variable_get(:@data).index($data_items[1]))
  raw_key(0x76,list,field)
  check(field.instance_variable_get(:@bs2q_reference_window).card.actor==field.user && field.user==other,'field item card follows the native highest-PHA user selection')
  field.terminate;$game_party.remove_actor(2)

  # Layout uses the real RGSS font metrics and bounded pages at 640x480.
  layout_cases=[[:skill,14],[:skill,31],[:skill,350],[:skill,469],[:skill,853],[:item,1],[:item,9],[:item,84]]
  [:ru,:en].each do |lang|
    BS2QoL::Reference.language=lang
    layout_cases.each do |kind,id|
      obj=(kind==:skill ? $data_skills : $data_items)[id]
      win=Window_BS2QReference.new(obj,actor)
      5.times do
        check(win.lines.all? { |s| win.text_size(s).width<=win.contents.width-16 },'native font wrapping '+lang.to_s+' '+kind.to_s+id.to_s+' section '+win.section.to_s)
        win.scroll(999999);check(win.offset==[win.lines.size-win.page_size,0].max,'bottom of page reachable without clipping')
        win.move_section(1)
      end
      win.dispose
    end
  end
  BS2QoL::Reference.language=:ru
  log('records='+count.to_s+'; unresolved_event_records='+gaps.uniq.size.to_s)
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  exit
end
