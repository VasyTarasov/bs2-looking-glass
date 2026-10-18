# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
def roots(actor,group)
  BS2Suite::DirectWeapons.rows(actor,group).map { |r| BS2Suite::WeaponFamilies.root(r[:id]) }
end
def give(ids);ids.each { |id| $game_party.gain_item($data_weapons[id],1) };end
def snapshot(actor)
  Marshal.dump([actor.equips.map { |w| w && w.id },actor.hp,actor.mp,actor.tp,actor.actions.map { |a| [a.item && a.item.id,a.target_index] },$game_party.weapons.map { |w| [w.id,$game_party.item_number(w)] }])
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'arsenal082 ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons
  give([102,256]);actor.change_equip(0,$data_weapons[102]);actor.recover_all;model.sync(actor)
  check(roots(actor,1)==[101] && roots(actor,2)==[101],'early Knight appears once on each main shelf; Broken excluded')
  give([157,362]);model.sync(actor)
  check(roots(actor,1)==[101,156,361],'Knight Club Hans append in acquisition order')
  check(roots(actor,2).sort==[101,156,361].sort,'early final shelf separates power defense and Hans')
  give([223,278]);model.sync(actor)
  check(roots(actor,1).sort==[101,156,222,277,361].sort,'real Saw and Knuckles become early recommendations')
  check(!roots(actor,2).include?(222) && roots(actor,2).include?(277),'Knuckles supply a speed finisher; Saw remains a manual technique source')
  check(direct.rows(actor,2).find { |r| r[:id]==362 }[:hint].include?('чужой ID'),'Hans caveat present on final row')
  give([168,124,234]);model.sync(actor)
  check([101,156].all? { |id| roots(actor,1).include?(id) },'progression retains early alternatives with free capacity')
  check(roots(actor,2).include?(123) && !roots(actor,2).include?(156) && roots(actor,2).include?(233),'final author substitutions have explicit power and defense candidates')
  model.set_mode(actor,'advanced')
  check(!roots(actor,1).include?(101) && !roots(actor,1).include?(156),'advanced moves superseded early recommendations off main shelf')
  check(direct.shelf(actor).any? { |r| r['group']>=3 && r['id']==156 },'superseded Club remains in additional arsenal')
  model.set_mode(actor,'progression')
  # Full author catalogue: no empty gaps, no page overflow, no default whole-inventory shelf.
  ids=(BS2Suite::ArsenalCatalog::EXTRA.map { |r| r[2] }.flatten+BS2Suite::ArsenalCatalog::MAIN+[255,211,288,403]).uniq
  give(ids);model.sync(actor)
  check(roots(actor,1).sort==BS2Suite::ArsenalCatalog::MAIN.sort,'mature main shelf is precisely the recommended ten')
  check(roots(actor,2).size.between?(8,10),'mature final shelf shares multi-role candidates within its ten-entry limit')
  groups=direct.groups(actor)
  check(groups.map { |g| g[:number] }==(1..groups.size).to_a && groups.size<=10,'only present categories get consecutive group digits')
  groups.each do |g|
    rows=direct.rows(actor,g[:number])
    check(rows.size<=10 && rows.map { |r| r[:digit] }==model::DIGITS[0,rows.size].chars.map { |d| d.to_i },'dense bounded rows in N'+g[:number].to_s)
    check(rows.map { |r| BS2Suite::WeaponFamilies.root(r[:id]) }.uniq.size==rows.size,'no duplicate family upgrades in N'+g[:number].to_s)
    check(direct.behavior(actor,g[:number])==([2,3].include?(g[:number]) ? 'last' : 'now'),'explicit behavior N'+g[:number].to_s)
  end
  check([255,211,288,403].all? { |id| direct.shelf(actor).any? { |r| r['group']>=4 && r['id']==id } },'complete manual arsenal remains accessible only after recommendations')
  check(direct.final_entries(actor).all? { |r| [2,3].include?(r['group']) },'sequence comparison excludes additional manual shelves')
  card=BS2QoL::PracticalCard.new($data_weapons[362],actor,:ru)
  check(card.sections.flatten.join.include?('Чужой ID не превращается'),'F7 explains Hans selection caveat without target knowledge')
  # Acknowledgement survives loading an older primitive profile snapshot.
  saved=Marshal.load(Marshal.dump($game_system));check(model.pending_moves(actor,'N').any?,'changed N layout requires acknowledgement')
  model.acknowledge(actor,'N');$game_system=saved
  check(model.pending_moves(actor,'N').empty?,'same N layout does not repeat its notice after reload')
  # Old automatic whole-inventory state is not mistaken for user pins.
  key=model.layout_key(actor,'N');model.state['layouts'].delete(key)
  model.state['layouts'][actor.id.to_s+':N']={'manual_ids'=>[255,211,288,403],'ids'=>[255]}
  direct.sync(actor)
  check(!roots(actor,1).include?(255) && model.pending_moves(actor,'N').any?,'legacy automatic catalogue migrates with notice and without flooding')
  before=snapshot(actor);direct.select(actor,$data_weapons[362]);intent=direct.selected_id(actor)
  model.set_mode(actor,'advanced');model.set_mode(actor,'progression')
  check(snapshot(actor)==before && direct.selected_id(actor)==intent,'profile changes preserve live equipment resources actions and selected intent')
  # Freeze addresses throughout battle, including acquisitions and disappearance.
  model.acknowledge(actor,'N');BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
  initial=direct.shelf(actor).map { |r| [r['group'],r['digit'],r['id']] }
  $game_party.lose_item($data_weapons[361],999,true);$game_party.lose_item($data_weapons[362],999,true)
  give([366]);direct.sync(actor)
  check(direct.shelf(actor).map { |r| [r['group'],r['digit'],r['id']] }==initial,'battle acquisitions do not reorder addresses')
  row=direct.rows(actor,1).find { |r| BS2Suite::WeaponFamilies.root(r[:id])==361 }
  check(row && row[:id]==366 && row[:present],'owned family upgrade resolves without moving digit')
  $game_party.lose_item($data_weapons[366],999,true)
  check(!direct.rows(actor,1).find { |r| BS2Suite::WeaponFamilies.root(r[:id])==361 }[:present],'lost weapon disables its frozen row')
  give([366])
  # Actual modal selection: N3+ is immediate and must not change existing intent.
  model.acknowledge(actor,'N')
  popup=BS2Suite::Palette.open(scene,scene.instance_variable_get(:@actor_command_window),actor,'N')
  window=BS2Suite::Palette.current(scene);window.set_group(4)
  BS2Suite::Palette.update_header(scene)
  check(window.banner.include?('Серии и контроль') && window.banner.include?('Сменить сейчас'),'open extra shelf visibly names its purpose and immediate action')
  Graphics.transition(0);Graphics.brightness=255;window.openness=255
  12.times { Graphics.update;window.update }
  bitmap=Graphics.snap_to_bitmap
  width=bitmap.width;height=bitmap.height;pixels=''.force_encoding('ASCII-8BIT')
  height.times do |y|
    width.times do |x|
      color=bitmap.get_pixel(x,y);pixels<<[color.blue.to_i,color.green.to_i,color.red.to_i,255].pack('C4')
    end
  end
  header=[40,width,-height,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
  File.open('BS2QA_082_extra.bmp','wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) };bitmap.dispose
  chosen=window.entries.find { |r| r[:present] && r[:object]!=actor.equips[0] }
  action_count=actor.actions.size;intent=direct.selected_id(actor)
  BS2Suite::Palette.choose(scene,chosen)
  check(actor.equips[0]==chosen[:object] && direct.selected_id(actor)==intent && actor.actions.size==action_count,'N4 selection switches immediately without replacing direct intent or spending action')
  BS2Suite::Palette.open(scene,scene.instance_variable_get(:@actor_command_window),actor,'N');window=BS2Suite::Palette.current(scene);window.set_group(2)
  chosen=window.entries.find { |r| r[:present] && r[:object]!=actor.equips[0] };before=snapshot(actor)
  BS2Suite::Palette.choose(scene,chosen)
  check(snapshot(actor)==before && direct.selected_id(actor)==chosen[:id],'N2 selection sets only future intent')
  # Native special attacks: keep their selected identity and native target/repeat rules.
  give([133,468,415,418,420,474,361,362])
  [[361,549,2,1],[362,549,4,1],[366,549,12,1],[278,348,1,2],[415,494,2,1],[418,495,3,1],[420,496,4,1],[468,852,1,1],[474,891,1,1]].each do |weapon,skill,targets,repeats|
    actor.clear_states;actor.change_equip(0,$data_weapons[weapon]);actor.recover_all
    action=Game_Action.new(actor);action.set_attack;action.target_index=0
    check(action.item.id==skill && action.make_targets.size==targets && action.item.repeats==repeats,'native source attack shape '+weapon.to_s)
    actor.instance_variable_set(:@actions,[action]);direct.select(actor,$data_weapons[133]);direct.arm(actor);action.prepare
    check(actor.equips[0].id==133 && action.item.id==skill && !action.attack?,'last swap keeps special ID '+weapon.to_s)
    check(action.make_targets.size==([361,362,366].include?(weapon) ? 1 : targets) && action.item.repeats==repeats,'only Hans atk_times_add disappears; intrinsic shape remains '+weapon.to_s)
  end
  actor.clear_states;actor.change_equip(0,$data_weapons[468]);actor.recover_all;actor.add_state(184)
  action=Game_Action.new(actor);action.set_attack
  check(action.item.id==855 && action.item.repeats==4,'Angels Focus selects intrinsic four-repeat skill')
  actor.instance_variable_set(:@actions,[action]);direct.select(actor,$data_weapons[133]);direct.arm(actor);action.prepare
  check(action.item.id==855 && action.item.repeats==4,'Focus variant persists across final platform swap')
  (0..7).each do |stack|
    actor.clear_states;actor.change_equip(0,$data_weapons[468]);actor.recover_all;actor.add_state(181+stack) if stack>0
    action=Game_Action.new(actor);action.set_attack
    check(action.item.id==852+stack && action.item.repeats==stack+1,'native Focus selection stack '+stack.to_s)
    actor.instance_variable_set(:@actions,[action]);direct.select(actor,$data_weapons[133]);direct.arm(actor);action.prepare
    check(action.item.id==852+stack && action.item.repeats==stack+1,'Focus repeat survives platform change stack '+stack.to_s)
  end
  [191,192].each do |ammo|
    actor.clear_states;actor.change_equip(0,$data_weapons[474]);actor.recover_all;actor.add_state(ammo)
    action=Game_Action.new(actor);action.set_attack;id=action.item.id;repeats=action.item.repeats
    check(id==(ammo==191 ? 892 : 893),'Gunblade ammo chooses its own variant '+ammo.to_s)
    actor.instance_variable_set(:@actions,[action]);direct.select(actor,$data_weapons[133]);direct.arm(actor);action.prepare
    check(action.item.id==id && action.item.repeats==repeats,'Gunblade ammo variant persists after swap '+ammo.to_s)
  end
  actor.clear_states;actor.change_equip(0,$data_weapons[102]);actor.recover_all;action=Game_Action.new(actor);action.set_attack;action.target_index=0
  actor.instance_variable_set(:@actions,[action]);direct.select(actor,$data_weapons[366]);direct.arm(actor);action.prepare
  check(action.item.id==1 && !action.attack? && action.make_targets.size==1,'equipping Hans cannot turn Knight attack into a machine gun')
  scene.terminate;$game_party.on_battle_end;scene=nil;model.sync(actor)
  # Copy/edit/round trip of explicit actions and legacy custom profiles.
  custom=model.clone_profile(actor)
  check(custom && direct.behavior(actor,2)=='last' && direct.behavior(actor,3)=='last','copy preserves explicit group behavior')
  check(model.assign(actor,'N',3,0,$data_weapons[256]),'player can pin excluded weapon in custom arsenal')
  check(model.set_behavior(actor,3,'last'),'custom group can explicitly become an executor shelf')
  model.instance_variable_set(:@customs,nil)
  check(direct.behavior(actor,3)=='last' && direct.rows(actor,3).any? { |r| r[:digit]==0 && r[:id]==256 },'explicit action and user binding persist in bounded text')
  check(model.set_behavior(actor,3,'now'),'custom group can explicitly return to immediate behavior')
  model.customs['u9999']={'name'=>'Legacy','groups'=>{'N3'=>'Old final'},'entries'=>[{'prefix'=>'N','group'=>3,'digit'=>1,'kind'=>'weapon','id'=>362,'source'=>0}]}
  model.state['active'][actor.id.to_s]='u9999'
  check(direct.behavior(actor,3)=='last','version-1 custom N3 remains delayed rather than silently changing meaning')
  check(model.persist,'legacy profile can be saved with version-2 format')
  model.instance_variable_set(:@customs,nil)
  check(direct.behavior(actor,3)=='last','legacy inferred action remains stable after text round trip')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  scene.terminate if scene
  SuiteCapture.close
end
end
