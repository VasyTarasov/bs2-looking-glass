# encoding: UTF-8
rgss_main do
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
class Keys092Dev
  attr_accessor :keys,:focus
  def initialize;@keys=[];@focus=true;end
  def focused?;@focus;end
  def down;@keys.dup;end
end
class ModalKeys092Dev < Keys092Dev
  attr_reader :observations
  def initialize(sequence,scene)
    super();@sequence=sequence;@scene=scene;@calls=0;@observations=[]
  end
  def down
    @calls+=1;raise Exception,'modal dispatcher failed to return within its bounded input sequence' if @calls>90
    chooser=@scene.instance_variable_get(:@bs2092_enemy_chooser)
    effects=@scene.instance_variable_get(:@bs2080_effects)
    ref=@scene.instance_variable_get(:@bs2q_reference_window)
    @observations<<[!!effects,!!ref,chooser && chooser.active]
    value=@sequence.shift || []
    raise Exception,'synthetic modal interruption' if value==:abort
    value
  end
end
def tick(keys=[])
  @raw.keys=keys;Graphics.update;Input.update
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'Looking Glass 0.92-dev native regression' }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_actors[1];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  [101,277,391].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[101]);actor.recover_all
  [19,88].each { |id| $game_party.gain_item($data_items[id],2) }
  model=BS2Suite::Semantic
  %w(progression advanced).each do |mode|
    model.set_mode(actor,mode)
    groups=model.groups(actor,'B')
    rows=groups.map { |g| model.rows(actor,'B',g[:number]) }.flatten
    check(rows.any? { |r| r[:id]==19 },'owned clock is manually available in B '+mode)
    check(groups.all? { |g| model.rows(actor,'B',g[:number]).size<=10 },'B remains at most ten entries per group '+mode)
  end
  check(!BS2Suite::BattleSupport.eligible?($data_items[19]),'clock cannot be armed for automatic use')
  BS2Suite::Options.set('knowledge_threshold',0)
  troop=RPG::Troop.new;troop.id=79
  troop.members=(0..2).map do |i|
    enemy=RPG::Enemy.new;enemy.id=5000+i;enemy.name='QA '+i.to_s;enemy.params=[50000,100,50,20+i*30,50,30+i*20,50,50]
    $data_enemies[enemy.id]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=enemy.id;member.x=150+i*160;member.y=180;member
  end
  $data_troops[79]=troop
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP)
  actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  commands=@scene.instance_variable_get(:@actor_command_window);commands.openness=255
  if defined?(BS2Suite::HDDisplay)
    hd=BS2Suite::HDDisplay
    hd.apply(hd::DEFAULT.merge('width'=>960,'height'=>720))
    60.times { Graphics.update;Input.update;break if hd.active? }
    check(hd.active?,'actual HD compositor is active for modal regression')
  end
  # Reproduce the player's F4 -> H dead end. The loop must dispatch H, then
  # return to the existing chooser, then restore battle commands. No turns run.
  [[[],[72],[],[27],[],[27]],
   [[],[72],[],[13],[],[118],[],[27],[],[27]],
   [[],[13],[],[72],[],[27],[],[118],[],[27]]].each_with_index do |sequence,i|
    raw=ModalKeys092Dev.new(sequence,@scene)
    BS2QoL::Keyboard.backend=raw;BS2QoL::Keyboard.reset
    before=Marshal.dump([actor,$game_troop.members])
    BS2Suite::EnemyInfo.open(@scene)
    check(!@scene.instance_variable_get(:@bs2080_effects) && !BS2QoL::Reference.active?(@scene) && commands.active,'F4 nested modal returns to battle '+i.to_s)
    check(raw.observations.any? { |r| r[0] },'H really opened above the F4 chooser or its F7 '+i.to_s)
    check(raw.observations.any? { |r| r[0]==false && r[2] },'original chooser regains control '+i.to_s)
    check(before==Marshal.dump([actor,$game_troop.members]),'nested inspection never executes battle or costs '+i.to_s)
  end
  interrupted=ModalKeys092Dev.new([[],[13],[],[72],:abort],@scene)
  BS2QoL::Keyboard.backend=interrupted;BS2QoL::Keyboard.reset
  begin
    BS2Suite::EnemyInfo.open(@scene)
    raise 'expected synthetic modal interruption'
  rescue Exception=>e
    raise e unless e.message=='synthetic modal interruption'
  end
  check(!@scene.instance_variable_get(:@bs2080_effects) && !BS2QoL::Reference.active?(@scene) && !@scene.instance_variable_get(:@bs2092_enemy_chooser) && commands.active,'interrupted F4 F7 H stack disposes restored child and returns control')
  @raw=Keys092Dev.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;tick
  if defined?(BS2Suite::QuickDamage)
    quick=BS2Suite::QuickDamage
    attack=$data_skills[105];magic=$data_skills[14]
    actor.learn_skill(magic.id)
    [attack,magic].each do |skill|
      before=Marshal.dump([actor,$game_troop.members]);srand(99);expected_random=rand;srand(99)
      result=quick.lines(@scene,skill,actor)
      means=$game_troop.alive_members.map { |enemy| quick.candidate_mean(skill,actor,nil,enemy) }
      check(result.join.include?(quick.compact_means(means.map { |v| v[0] })) && !result.join.include?('?'),'technique or magic compares alternative enemies '+skill.id.to_s)
      check(Marshal.dump([actor,$game_troop.members])==before && rand==expected_random,'multi-target preview preserves state and RNG '+skill.id.to_s)
      selected=quick.lines(@scene,skill,actor,nil,$game_troop.members[1])
      check(selected.size==1 && selected[0].start_with?('≈ '),'target selection shows only the selected target '+skill.id.to_s)
    end
    aoe=magic.dup;aoe.id=4999;aoe.name='QA area';aoe.scope=2;$data_skills[aoe.id]=aoe;actor.learn_skill(aoe.id)
    area=quick.lines(@scene,aoe,actor)
    check(area.join.include?('суммарно') && !area.join.include?('?'),'AoE shows total over actual enemies, not alternative target average')
    %w(V M).each do |prefix|
      model.sync(actor);model.acknowledge(actor,prefix)
      BS2Suite::Palette.open(@scene,commands,actor,prefix)
      popup=BS2Suite::Palette.current(@scene)
      id=prefix=='V' ? attack.id : magic.id
      group=model.groups(actor,prefix).find { |g| model.rows(actor,prefix,g[:number]).any? { |r| r[:id]==id } }
      popup.set_group(group[:number]);popup.select(popup.entries.index { |r| r[:id]==id })
      rows=BS2Suite::HDDisplay.palette_rows(popup)
      mean_index=rows.index { |r| r.start_with?("S\t~") }
      note_index=rows.rindex { |r| r.start_with?("H\t") }
      check(mean_index && note_index && mean_index>note_index,'real '+prefix+' sidebar renders group estimate beneath selected description')
      BS2Suite::Palette.close(@scene)
    end
    BS2Suite::Options.set('knowledge_threshold',100)
    check(quick.lines(@scene,magic,actor).join.include?('закрыты'),'group comparison preserves unknown-enemy boundary')
    BS2Suite::Options.set('knowledge_threshold',0)
  end
  @scene.terminate;$game_party.on_battle_end
  @scene=Scene_Map.new;SceneManager.instance_variable_set(:@scene,@scene)
  # Gear has only global event effects, so its native use_item keeps the choices.
  check($data_items[88].effects.all? { |e| e.code==44 } && !$data_items[88].consumable,'gear is nonconsumable and only reserves its original common event')
  $game_temp.clear_common_event
  stock=$game_party.item_number($data_items[88]);sen=$game_variables[1]
  check(BS2Suite::MadnessGear.use(@scene),'map shortcut can use owned usable gear')
  event=$data_items[88].effects.find { |e| e.code==44 }.data_id
  check($game_temp.common_event_reserved? && $game_temp.reserved_common_event==$data_common_events[event],'original gear event is queued without skipping choices')
  check(stock==$game_party.item_number($data_items[88]) && sen==$game_variables[1],'gear shortcut does not consume stock or directly choose SEN')
  check(!BS2Suite::MadnessGear.use(@scene),'second use cannot overwrite pending common event')
  $game_temp.clear_common_event
  $game_message.add('QA dialog');check(!BS2Suite::MadnessGear.use(@scene),'map dialog blocks gear shortcut');$game_message.clear
  if defined?(BS2Suite::HDDisplay)
    hd=BS2Suite::HDDisplay
    check(BS2Suite::Keys.token(:fullscreen)=='F10' && BS2Suite::Keys.token(:field)=='SHIFT+F10','F10 display and Shift F10 field shortcuts coexist')
    saved_keys=BS2Suite::Store.read('keys')
    BS2Suite::Store.write('keys',"note=F10\nstats=SHIFT+F10\nrun=J\n")
    BS2Suite::Keys.instance_variable_set(:@data,nil)
    check(BS2Suite::Keys.token(:note)=='F10' && BS2Suite::Keys.token(:stats)=='SHIFT+F10' && BS2Suite::Keys.token(:run)=='J','new display defaults preserve existing custom control map on conflict')
    check(BS2Suite::Keys.token(:fullscreen)!='F10' && BS2Suite::Keys.token(:field)!='SHIFT+F10','new commands choose free keys rather than stealing existing custom bindings')
    BS2Suite::Store.write('keys',saved_keys);BS2Suite::Keys.instance_variable_set(:@data,nil)
    BS2Suite::Store.write('hd_display','');hd.instance_variable_set(:@data,nil)
    check(hd.data['launch']==0 && hd.data.values_at('width','height')==hd.monitor_size,'fresh preferences start windowed and remember monitor-size HD target')
    hd.startup;check(hd.status[1]==0,'unchecked startup really restores original window')
    tick;tick([121]);check(hd.status[6,2]==hd.monitor_size && hd.status[1]==1,'actual first F10 input uses native monitor size')
    tick;tick([121]);check(hd.status[1]==0,'actual second F10 input restores original window');tick
    value=hd.data.merge('width'=>960,'height'=>720,'mode'=>0,'filter'=>1)
    check(hd.start_trial(value) && hd.confirm,'custom HD size is confirmed normally')
    hd.toggle;hd.toggle
    check(hd.status[6,2]==[960,720] && hd.status[3]==0,'F10 remembers confirmed size and forces sharp pixels')
    check(hd.data['filter']==0,'mandatory sharp filter is also persisted')
    hd.persist(hd.data.merge('launch'=>1));hd.startup
    check(hd.status[6,2]==[960,720],'checked startup applies preferred HD size')
    # Own-window lifecycle: minimise before startup applies, restore it, then
    # let the usual graphics poll repair the deferred configuration.
    hwnd=BS2Suite::SteamBridge.stats[14]
    show=Win32API.new('user32','ShowWindow',['L','I'],'I')
    hd.instance_variable_get(:@configure).call(800,600,0,0,1,100)
    show.call(hwnd,6);check(hd.iconic?,'private fixture is actually minimised')
    hd.startup
    show.call(hwnd,9)
    90.times { Graphics.update;Input.update;break if hd.status[6,2]==[960,720] && !hd.iconic? }
    check(!hd.iconic? && hd.status[6,2]==[960,720],'restore after immediate startup minimise reapplies chosen size')
    check(hd.status[3]==0,'restore retains mandatory sharp filter')
    # A late engine resize during startup is repaired by geometry, not by
    # falsely treating a successful Configure call as successful placement.
    hd.instance_variable_get(:@configure).call(800,600,0,0,1,100)
    hd.instance_variable_set(:@repair_tick,nil);hd.maintain
    check(hd.status[6,2]==[960,720],'late startup resize is repaired to requested actual client size')
  end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
end
end
