# encoding: UTF-8
@checks=0
def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
def check(value,label);raise 'Assertion: '+label unless value;@checks+=1;log('PASS '+label);end
module Graphics
  class << self
    alias bs2q_spec_native_update update
    def update
      bs2q_spec_native_update
      @bs2q_spec_frames=(@bs2q_spec_frames || 0)+1
            raise 'Native frame budget exceeded' if @bs2q_spec_frames>1100
    end
  end
end
class BS2QRawFixture
  attr_accessor :keys,:focus
  def initialize;@keys=[];@focus=true;end
  def focused?;@focus;end
  def down;@keys.dup;end
end
module Input
  class << self
    attr_accessor :spec_key
    def trigger?(key);@spec_key==key || (key==:C && $game_message && ($game_message.busy? || $game_message.visible) && Graphics.frame_count.even?);end
    def repeat?(key);@spec_key==key;end
    def press?(key);@spec_key==key;end
  end
end
def frame(keys=[],window=nil)
  @raw.keys=keys
  Graphics.update
  Input.update
  window.update if window
end
def chord(name,window)
  frame([],window)
  keys=[]
  keys<<0x10 if name[0,1]=='S'
  keys<<0x11 if name[0,1]=='C'
  keys<<name[-1,1].to_i+0x30
  frame(keys,window)
end
def native_key(key,window)
  Input.spec_key=key
  frame([],window)
  Input.spec_key=nil
end
def action_ids(actor);[actor.actions.object_id,actor.actions.map { |a| [a.object_id,a.item && a.item.id,a.target_index] }];end
begin
  File.open('test_result.txt','w') { |f| f.puts 'keys_suite; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(20,false);actor.name='QA'
  actor.clear_equipments
  [101,112,384].each { |id| $game_party.gain_item($data_weapons[id],1) }
  [137,147,217].each { |id| $game_party.gain_item($data_armors[id],1) }
  actor.change_equip(0,$data_weapons[384]);actor.change_equip(1,$data_armors[217])
  ring_slots=actor.equip_slots.each_index.select { |i| actor.equip_slots[i]==4 }
  actor.change_equip(ring_slots[0],$data_armors[137]);actor.change_equip(ring_slots[1],$data_armors[147])
  check(actor.equips.include?($data_armors[137]) && actor.equips.include?($data_armors[147]),'two actual action rings equip through native slots')
  check([137,147,217].all? { |id| actor.equippable?($data_armors[id]) },'fixture uses legal native equipment')
  [14,18,31,181,350].each { |id| actor.learn_skill(id) }
  actor.recover_all;actor.hp=500
  $game_party.gain_item($data_items[1],6)
  prefs=BS2QoL::Preferences
  prefs.instance_variable_set(:@lists,{:weapon=>[384,112],:item=>[1],:skill=>[14,18]})
  bindings=BS2QoL::Bindings
  bindings.instance_variable_set(:@data,{})
  check(BS2QoL::VERSION=='0.7.1-alpha','keyboard module version loads on RGSS')
  load 'Mods/BS2Suite/main.rb'
  check(BS2QoL::VERSION=='0.7.1-alpha','bootstrap remains idempotent')
  parsed=bindings.parse("scope=weapon112\nbind=weapons,S1,weapon,384\nbind=weapons,C2,weapon,101\nbind=quick,C1,item,1\nbind=quick,S2,skill,14\nbind=quick,C3,skill,0\nexec=anything\n")
  check(parsed['weapons']=={'S1'=>[:weapon,384]},'binding parser rejects invalid contexts and chords')
  check(parsed['quick']=={'C1'=>[:item,1]},'binding parser rejects zero IDs and unknown lines')
  check(parsed['weapon112']=={},'empty weapon profile survives parsing')
  check(bindings.ensure_scope('weapons',actor)['S2']==[:weapon,112],'old favorite weapons seed direct slots once')
  check(bindings.ensure_scope('quick',actor)['C1']==[:item,1],'favorite item seeds direct Ctrl slot')
  check(bindings.get('quick','C2',actor)==[:skill,14],'common magic seeds stable shared slot')
  check(bindings.ensure_scope('weapon384',actor)['S1']==[:skill,95],'Andor profile comes from real weapon features')
  check(bindings.ensure_scope('weapon112',actor)['S1']==[:skill,151],'dagger profile uses different technique on same chord')
  check($data_skills[14].stype_id==$data_skills[95].stype_id,'magic and weapon techniques actually share native skill type')
  check(bindings.persist && bindings.error.nil?,'binding profile writes successfully')
  expected=Marshal.load(Marshal.dump(bindings.data))
  bindings.instance_variable_set(:@data,nil)
  check(bindings.data==expected,'binding file survives reload')
  bindings.data['weapon101']={}
  bindings.persist;bindings.instance_variable_set(:@data,nil)
  check(bindings.ensure_scope('weapon101',actor).empty?,'cleared profile does not regenerate defaults')
  invalid=bindings.set('weapons','C1',:item,1)
  check(!invalid,'invalid assignments refused before mutation')
  check(BS2QoL::Model.ordered([$data_weapons[101],$data_weapons[112],$data_weapons[384]]).map { |o| o.id }==[384,112,101],'normal collection promotes favorites preserving manual order')

  # The real Win32 adapter must never poll keys for another foreground process.
  class BS2QCall
    def initialize(&block);@block=block;end
    def call(*args);@block.call(*args);end
  end
  adapter=BS2QoL::WindowsKeys.new
  polls=0
  adapter.instance_variable_set(:@foreground,BS2QCall.new { 0 })
  adapter.instance_variable_set(:@async,BS2QCall.new { |vk| polls+=1;0x8000 })
  check(adapter.down.empty? && polls==0,'Win32 adapter performs no key polling without owned foreground window')
  process=adapter.instance_variable_get(:@process)
  adapter.instance_variable_set(:@foreground,BS2QCall.new { 42 })
  adapter.instance_variable_set(:@owner,BS2QCall.new { |window,buffer| buffer[0,4]=[process+1].pack('L');1 })
  check(adapter.down.empty? && polls==0,'foreign foreground process blocks all key polling')
  adapter.instance_variable_set(:@owner,BS2QCall.new { |window,buffer| buffer[0,4]=[process].pack('L');1 })
  adapter.instance_variable_set(:@async,BS2QCall.new { |vk| vk==0x31 ? 0x8000 : (vk==0x32 ? 1 : 0) })
  check(adapter.down==[0x31],'Win32 adapter uses only high down-state bit, ignoring unreliable recent-press bit')
  @raw=BS2QRawFixture.new
  BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
  frame([])
  frame([0x10,0x31]);check(BS2QoL::Keyboard.first=='S1','raw Shift plus digit resolves as chord')
  frame([0x10,0x31]);check(BS2QoL::Keyboard.first.nil?,'held chord does not repeat')
  frame([0x31]);check(BS2QoL::Keyboard.first.nil?,'modifier release does not create command digit')
  frame([0x10,0x31]);check(BS2QoL::Keyboard.first.nil?,'modifier added to held digit does not create weapon change')
  @raw.focus=false;frame([]);check(BS2QoL::Keyboard.first.nil?,'unfocused input is ignored')
  @raw.focus=true;frame([0x11,0x31]);check(BS2QoL::Keyboard.first.nil?,'refocus while held does not invoke action')
  frame([]);frame([0x11,0x31]);check(BS2QoL::Keyboard.first=='C1','release then press works after focus recovery')
  Input.update;check(BS2QoL::Keyboard.first.nil?,'second native input flush clears same-frame trigger')
  frame([]);frame([0x12,0x31]);check(BS2QoL::Keyboard.first.nil?,'Alt digits ignored to avoid system chords')
  frame([]);frame([0x10,0x11,0x31]);check(BS2QoL::Keyboard.first=='CS1','mixed modifiers enter only the auto-equip namespace')

  frame([]);frame([0x5B,0x31]);check(BS2QoL::Keyboard.first.nil?,'system modifier plus digit cannot invoke a combat command')
  frame([]);frame([0x12,0x75]);check(BS2QoL::Keyboard.first.nil?,'Alt+F6 does not open binding editor')
  frame([]);frame([0x11,0x75]);check(BS2QoL::Keyboard.first.nil?,'modified F6 does not leak into editor shortcut')
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP)
  srand(415);actor.make_actions
  check(actor.actions.size>=3,'several action slots arise from real equipment features')
  log('native_slots='+actor.actions.size.to_s+'; equips='+actor.equips.map { |i| i && i.id }.inspect)
  BattleManager.instance_variable_set(:@phase,:input);BattleManager.instance_variable_set(:@actor_index,0)
  scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
  command=scene.instance_variable_get(:@actor_command_window);command.openness=255
  check(!command.instance_variable_get(:@list).any? { |r| r[:symbol]==:bs2q_favorites },'battle has no extra favorites submenu')
  check(command.instance_variable_get(:@list).find { |r| r[:symbol]==:attack }[:name][0].start_with?('1 '),'native commands display numeric shortcuts')
  before=action_ids(actor);srand(442);expected_rand=rand;srand(442)
  chord('S2',command)
  check(actor.equips[0].id==112,'Shift+2 changes weapon directly from command window')
  check(action_ids(actor)==before,'direct weapon change preserves queue objects, commands and targets')
  check(rand==expected_rand,'direct weapon change and hints consume no combat RNG')
  chord('2',command)
  skills=scene.instance_variable_get(:@skill_window)
  check(skills.active && !command.active,'2 opens native skill list in one key')
  check(skills.instance_variable_get(:@data)[0].id==14,'favorite magic promoted in normal technique list')
  field=$data_skills.compact.find { |s| s.occasion==2 && !s.name.empty? }
  if field
    actor.learn_skill(field.id);prefs.lists[:skill]<<field.id;skills.bs2q_only=true;skills.refresh
    check(!skills.instance_variable_get(:@data).include?(field),'battle favorite filter retains native exclusion of field-only skills')
    prefs.lists[:skill].delete(field.id);actor.forget_skill(field.id);skills.bs2q_only=false;skills.refresh
  end
  chord('S1',skills)
  enemies=scene.instance_variable_get(:@enemy_window)
  check(enemies.active && actor.input.item.id==151,'same Shift+1 selects current dagger technique')
  mp=actor.mp
  chord('S1',enemies)
  check(actor.equips[0].id==112 && enemies.active,'weapon binding blocked in target selection')
  native_key(:B,enemies)
  check(skills.active && actor.mp==mp,'local technique target cancel restores list without payment')
  native_key(:B,skills)
  check(command.active,'ordinary list cancel returns to commands')
  chord('S1',command);check(actor.equips[0].id==384,'Shift+1 equips Andor without opening categories')
  chord('2',command);chord('S1',skills)
  check(enemies.active && actor.input.item.id==95,'same local chord now selects Andor technique')
  native_key(:B,enemies);native_key(:B,skills)
  actor.skill_seal << 14
  sealed_mp=actor.mp;sealed_actions=action_ids(actor)
  chord('C2',command)
  check(command.active && !skills.active && !enemies.active && actor.mp==sealed_mp && action_ids(actor)==sealed_actions,'hidden direct skill refuses without changing input context, queue or MP')
  actor.skill_seal.delete(14)
  mp=actor.mp
  chord('C2',command)
  check(enemies.active && actor.input.item.id==14,'Ctrl+2 opens stable common magic directly')
  raw_weapon=actor.equips[0]
  chord('S2',enemies)
  Input.spec_key=:B;frame([0x10,0x32],enemies);Input.spec_key=nil
  check(command.active && !skills.active && actor.mp==mp,'direct magic cancellation returns straight to commands without cost')
  frame([0x10,0x32],command)
  check(actor.equips[0]==raw_weapon,'held target-window shortcut does not fire after cancellation')
  frame([],command)
  before_hp=actor.hp;before_stock=$game_party.item_number($data_items[1])
  chord('C1',command)
  check(actor.hp>before_hp,'one Ctrl+1 heals unique ally through native handler')
  check($game_party.item_number($data_items[1])==before_stock-1,'direct flask paid exactly once')
  check(command.active && !scene.instance_variable_get(:@actor_window).active,'unique ally target needs no extra confirmation')
  8.times { frame([0x11,0x31],command) }
  check($game_party.item_number($data_items[1])==before_stock-1,'held direct item does not consume additional flasks')
  chord('4',command)
  items=scene.instance_variable_get(:@item_window)
  check(items.active,'4 opens ordinary item list directly')
  actor.hp=500;stock=$game_party.item_number($data_items[1])
  chord('S1',items)
  check(actor.hp>500 && $game_party.item_number($data_items[1])==stock-1,'4 then Shift+1 uses contextual flask binding')
  8.times { frame([],command) }
  # Ambiguous ally targets must still require ordinary confirmation.
  $game_party.gain_item($data_items[1],2)
  $game_party.add_actor(2);$game_actors[2].recover_all
  stock=$game_party.item_number($data_items[1])
  chord('C1',command)
  allies=scene.instance_variable_get(:@actor_window)
  check(allies.active && $game_party.item_number($data_items[1])==stock,'multiple allies preserve target choice and defer consumption')
  native_key(:B,allies)
  check(command.active && !items.active && $game_party.item_number($data_items[1])==stock,'ambiguous direct-item cancellation returns cleanly without cost')
  $game_party.remove_actor(2)
  $game_party.lose_item($data_items[1],99)
  chord('C1',command)
  check(command.active && $game_party.item_number($data_items[1])==0,'zero-stock shortcut fails without opening or paying')
  saved_mp=actor.mp;actor.mp=0
  chord('C2',command)
  check(command.active && !enemies.active,'unaffordable magic does not enter target selection')
  actor.mp=saved_mp

  chord('2',command)
  data=skills.instance_variable_get(:@data);skills.select(data.index($data_skills[95]))
  frame([],skills);frame([0x75],skills)
  popup=scene.instance_variable_get(:@bs2q_binding_window)
  check(popup && !skills.active,'F6 opens binding editor on selected technique')
  frame([]);frame([0x10,0x33]);BS2QoL::Hotkeys.update_modal(scene)
  check(popup.pending==[bindings.weapon_scope(actor),'S3'],'editor captures context-sensitive chord')
  check(bindings.get('weapon384','S3',actor).nil?,'editor proposal does not overwrite before confirmation')
  Input.spec_key=:C;BS2QoL::Hotkeys.update_modal(scene);Input.spec_key=nil
  check(bindings.get('weapon384','S3',actor)==[:skill,95] && skills.active,'Enter commits binding and restores original list focus')
  skills.select(skills.instance_variable_get(:@data).index($data_skills[14]))
  frame([],skills);frame([0x75],skills)
  frame([]);frame([0x10,0x33]);BS2QoL::Hotkeys.update_modal(scene)
  check(bindings.get('weapon384','S3',actor)==[:skill,95],'conflicting proposal leaves old binding until confirmation')
  Input.spec_key=:B;BS2QoL::Hotkeys.update_modal(scene);Input.spec_key=nil
  check(bindings.get('weapon384','S3',actor)==[:skill,95] && skills.active,'cancelled reassignment preserves previous technique')
  frame([],skills);frame([0x75],skills)
  frame([]);frame([0x11,0x37]);BS2QoL::Hotkeys.update_modal(scene)
  Input.spec_key=:C;BS2QoL::Hotkeys.update_modal(scene);Input.spec_key=nil
  check(bindings.get('quick','C7',actor)==[:skill,14],'editor supports stable shared magic assignment')
  frame([],skills);frame([0x75],skills)
  frame([]);frame([0x2E]);BS2QoL::Hotkeys.update_modal(scene)
  check(!bindings.get('quick','C7',actor) && !bindings.get('quick','C2',actor),'Delete removes selected object assignments')
  check(skills.active && !scene.instance_variable_get(:@bs2q_binding_window),'Delete restores focus and closes editor')

  # A failed settings write retains both the previous file and memory state.
  original_path=bindings.path
  previous=File.open(original_path,'rb') { |f| f.read }
  class << bindings
    alias bs2q_spec_real_path path
    def path;File.join(Dir.pwd,'QA_missing_bindings_parent','child','bindings.ini');end
  end
  bindings.set('quick','C8',:skill,31)
  check(bindings.error==:write_failed && bindings.get('quick','C8',actor).nil?,'failed write does not commit an assignment')
  check(File.open(original_path,'rb') { |f| f.read }==previous,'write failure preserves previous binding file')
  class << bindings;alias path bs2q_spec_real_path;end
  check(bindings.persist && bindings.error.nil?,'binding file writes recover after transient failure')

  # Real management cancel was missed in the earlier release: retain regression.
  native_key(:B,skills)
  scene.terminate
  menu=Scene_BS2QFavorites.new;SceneManager.instance_variable_set(:@scene,menu)
  menu.start;menu.open_weapon
  collection=menu.instance_variable_get(:@collection);collection.openness=255
  native_key(:B,collection)
  check(menu.instance_variable_get(:@tabs).active && !collection.active,'management Esc returns safely to category tabs')
  # Actual ordinary lists, not merely a sorted helper array.
  equip=Window_EquipItem.new(0,0,320,240)
  equip.actor=actor;equip.slot_id=0;equip.refresh
  check(equip.instance_variable_get(:@data).compact.first.id==112,'ordinary equipment list places carried favorite weapon first')
  equip.select(0);equip.activate
  frame([],equip);frame([0x75],equip)
  frame([]);frame([0x11,0x31]);BS2QoL::Hotkeys.update_modal(menu)
  popup=menu.instance_variable_get(:@bs2q_binding_window)
  check(popup && !popup.pending,'weapon editor rejects conflicting Ctrl namespace')
  frame([]);frame([0x10,0x39]);BS2QoL::Hotkeys.update_modal(menu)
  Input.spec_key=:C;BS2QoL::Hotkeys.update_modal(menu);Input.spec_key=nil
  check(bindings.get('weapons','S9',actor)==[:weapon,112] && equip.active,'weapon binding can be edited from ordinary equipment list')
  equip.dispose
  $game_party.gain_item($data_items[1],1);$game_party.gain_item($data_items[2],1)
  prefs.instance_variable_set(:@lists,{:weapon=>[384,112],:item=>[2],:skill=>[14]})
  ordinary=Window_ItemList.new(0,0,320,240);ordinary.category=:item;ordinary.refresh
  check(ordinary.instance_variable_get(:@data).first.id==2,'ordinary item list moves selected favorite ahead of lower database ID')
  ordinary.dispose
  menu.terminate
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>error
  log('result=FAIL; '+error.class.to_s+': '+error.message+"\n"+error.backtrace.join("\n"))
end
exit

