# encoding: UTF-8
@checks=0
def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
def check(v,label);raise 'Assertion: '+label unless v;@checks+=1;log('PASS '+label);end
module Graphics
  class << self
    alias qa060_graphics update
    def update
      @qa060_frames=(@qa060_frames || 0)+1;raise 'QA frame budget' if @qa060_frames>950
      qa060_graphics
    end
  end
end
class BS2V2ShowRaw
  attr_accessor :keys,:sequence,:captures,:pulse
  attr_reader :calls
  def initialize;@keys=[];@sequence=[];@captures={};@calls=0;end
  def focused?;true;end
  def down
    @calls+=1
    if @captures[@calls]
      SuiteCapture.frame(@captures[@calls])
    end
    @keys=@sequence.shift unless @sequence.empty?
    return @calls.even? ? [] : [13] if @pulse && @keys==[13]
    @keys.dup
  end
end
def frame(keys=[],window=nil)
  @raw.keys=keys;Graphics.update;Input.update;window.update if window
end
def capture(name)
  Graphics.transition(0);3.times { Graphics.update };SuiteCapture.frame('BS2QA_060_'+name+'.bmp')
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'showcase_060; native UI and real input handlers' }
  load 'BS2QA_native_capture.rb'
  module SuiteCapture
    # Read the real RGSS rendered frame; GDI can return a stale frame on a hidden desktop.
    def self.frame(path)
      bitmap=Graphics.snap_to_bitmap;w=bitmap.width;h=bitmap.height;pixels=''.force_encoding('ASCII-8BIT')
      h.times do |y|
        w.times do |x|
          color=bitmap.get_pixel(x,y);pixels<<[color.blue,color.green,color.red,255].pack('C4')
        end
      end
      header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
      File.open(path,'wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
    ensure;bitmap.dispose if bitmap;end
  end
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  [101,156,255].each { |id| $game_party.gain_item($data_weapons[id],1) }
  [82,137,217].each { |id| $game_party.gain_item($data_armors[id],1) }
  actor.change_equip(0,$data_weapons[255]);actor.change_equip(1,$data_armors[217]);actor.change_equip(actor.equip_slots.index(4),$data_armors[137]);actor.recover_all
  [14,120,340,838].each { |id| actor.learn_skill(id) };[308,110].each { |id| actor.forget_skill(id) }
  BS2Suite::Keys.instance_variable_set(:@data,BS2Suite::Keys::DEFAULT.dup)
  BS2QoL::Reference.language=:ru
  @raw=BS2V2ShowRaw.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;frame
  $game_party.menu_actor=actor
  equip=Scene_Equip.new;SceneManager.instance_variable_set(:@scene,equip);equip.start;equip.command_equip
  slots=equip.instance_variable_get(:@slot_window);slots.openness=255;slots.select(0)
  frame([],slots);frame([118],slots)
  check(BS2QoL::Reference.active?(equip) && equip.instance_variable_get(:@bs2q_reference_window).card.object==$data_weapons[255],'F7 works on actual native equipped weapon slot')
  capture('weapon_ru');BS2QoL::Reference.close(equip)
  slots.select(1);frame([],slots);frame([118],slots)
  check(BS2QoL::Reference.active?(equip) && equip.instance_variable_get(:@bs2q_reference_window).card.object==$data_armors[217],'F7 works on actual native equipped armor slot')
  equip.instance_variable_get(:@bs2q_reference_window).move_section(1);capture('armor_properties_ru')
  BS2QoL::Reference.close(equip);equip.terminate
  [340,838].each do |id|
    popup=Window_BS2QReference.new($data_skills[id],actor);capture(id==340 ? 'dodo_ru' : 'grudge_ru');popup.dispose
  end
  BS2QoL::Reference.language=:en
  popup=Window_BS2QReference.new($data_skills[838],actor);capture('grudge_en');popup.dispose
  BS2QoL::Reference.language=:ru
  popup=Window_BS2QReference.new($data_armors[232],actor);capture('indomitable_ru');popup.dispose
  BS2QoL::Reference.language=:en
  popup=Window_BS2QReference.new($data_armors[232],actor);capture('indomitable_en');popup.dispose
  BS2QoL::Reference.language=:ru

  BattleManager.setup(79,true,false);BattleManager.save_bgm_and_bgs;BattleManager.method_wait_for_message=nil;BattleManager.battle_start;$game_message.clear;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
  commands=scene.instance_variable_get(:@actor_command_window);commands.openness=255
  bindings=BS2QoL::Bindings;bindings.instance_variable_set(:@data,{})
  [255,156,101].each_with_index { |id,i| bindings.set('weapons','S'+(i+1).to_s,:weapon,id) }
  bindings.set('weapon255','C1',:skill,308);bindings.set('weapon156','C1',:skill,110)
  bindings.set('cast','CS1',:skill,308,255)
  # The actual F4 dispatch enters a modal chooser; Enter opens the real card,
  # arrows select its state table, Esc returns twice without choosing a target.
  start=@raw.calls
  Graphics.transition(0);3.times { Graphics.update }
  @raw.captures={start+4=>'BS2QA_060_enemy_elements.bmp',start+6=>'BS2QA_060_enemy_states.bmp'}
  @raw.sequence=[[115],[],[13],[],[39],[],[27],[],[27],[]]
  selected_before=actor.actions.map { |a| a.item && a.item.id }
  scene.update
  check(commands.active && !BS2QoL::Reference.active?(scene),'real F4 Enter arrows Esc path restores battle command control')
  check(actor.actions.map { |a| a.item && a.item.id }==selected_before,'enemy inspection never queues a battle action')
  @raw.sequence=[];@raw.keys=[];@raw.captures={};frame
  scene.command_skill;skills=scene.instance_variable_get(:@skill_window);skills.select(skills.instance_variable_get(:@data).index($data_skills[308]));skills.openness=255
  frame([],skills);frame([117],skills)
  frame([]);frame([16,17,49]);BS2QoL::Hotkeys.update_modal(scene)
  check(scene.instance_variable_get(:@bs2q_binding_window).pending==['cast','CS1'],'real editor captures Ctrl Shift1 as an auto-equip pair')
  capture('binding_autoequip');BS2QoL::Hotkeys.close_binding(scene);scene.on_skill_cancel

  # Execute the requested three-step preparation in a complete native fight.
  $game_troop.members[1..-1].each { |e| e.hide };$game_troop.members[0].hp=1
  actor.recover_all;before_mp=actor.mp
  [[16,49],[17,49],[16,50],[17,49],[16,51],[49]].each do |keys|
    frame([],commands);frame(keys,commands)
  end
  uses=[]
  class << actor
    alias qa060_original_use use_item
    attr_accessor :qa060_uses
    def use_item(item);(@qa060_uses||=[])<<item.id;qa060_original_use(item);end
  end
  actor.qa060_uses=[]
  @raw.pulse=true
  650.times do |i|
    break if SceneManager.scene!=scene || !$game_party.in_battle
    @raw.keys=(commands.active && i.even?) ? [49] : [13]
    scene.update
  end
  check(actor.qa060_uses.include?(308) && actor.qa060_uses.include?(110) && actor.qa060_uses.include?(1),'queued weapon-specific techniques and attack actually execute in native battle')
  check(actor.mp<before_mp,'executed techniques pay actual costs')
  check(BS2Suite::BattleRecord.last && BS2Suite::BattleRecord.last[:result]==0,'complete shortcut fight reaches normal victory')
  scene.terminate;$game_party.on_battle_end

  DataManager.setup_new_game;actor=$game_party.members[0];actor.learn_skill(120)
  $game_player.perform_transfer;$game_map.events.clear;$game_map.interpreter.clear;$game_message.clear;$game_temp.clear_common_event
  $game_system.save_disabled=false;BS2Suite::AutoStealth.instance_variable_set(:@actor_id,0)
  map=Scene_Map.new;SceneManager.instance_variable_set(:@scene,map);map.start
  @raw.sequence=[];@raw.keys=[];frame
  (100..104).each { |i| File.delete(DataManager.make_filename(i)) if File.file?(DataManager.make_filename(i)) }
  @raw.keys=[114];map.update
  check(File.file?(DataManager.make_filename(100)),'F3 through real Scene_Map.update writes a quick save without opening a menu')
  capture('quicksave_toast');map.terminate
  field=BS2Suite::FieldScene.new;SceneManager.instance_variable_set(:@scene,field);field.start
  list=field.instance_variable_get(:@item_window);list.openness=255;list.select(list.instance_variable_get(:@data).index($data_skills[120]))
  @raw.keys=[];field.update;@raw.keys=[68];field.update
  check(BS2Suite::AutoStealth.actor_id==actor.id,'D in real field skill scene enables automatic invisibility')
  capture('field_auto');@raw.keys=[];field.update;@raw.keys=[68];field.update
  check(BS2Suite::AutoStealth.actor_id==0,'D in real field scene also disables automatic invisibility')
  field.terminate
  load_scene=Scene_Load.new;SceneManager.instance_variable_set(:@scene,load_scene);load_scene.start
  files=load_scene.instance_variable_get(:@bs2_files);files.select(100);capture('quick_history');load_scene.terminate
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  (100..104).each { |i| p=DataManager.make_filename(i);File.delete(p) if File.file?(p) } if defined?(BS2Suite::QuickSaves)
  exit
end
