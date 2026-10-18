# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
def capture_hd(name)
  path='Mods/BS2Suite/native/bs2_steam_bridge.dll';read=Win32API.new(path,'BS2_HDReadback',['P','I'],'I')
  BS2Suite::HDDisplay.poll(true);read.call('',0)
  w,h=BS2Suite::HDDisplay.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');actual=0
  90.times do
    Graphics.update;Input.update
    actual=read.call(pixels,pixels.bytesize);break if actual==pixels.bytesize
  end
  unless actual==pixels.bytesize
    log('readback expected='+pixels.bytesize.to_s+' actual='+actual.to_s+' hd='+BS2Suite::HDDisplay.status.inspect+' bridge='+BS2Suite::SteamBridge.stats.inspect)
    raise 'HD readback unavailable'
  end
  header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
  File.open('BS2QA_HD_'+name+'.bmp','wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
end
class HDTestKeys
  attr_accessor :keys
  def initialize;@keys=[];end
  def down;@keys.dup;end
  def focused?;true;end
end
def frame(keys=[])
  @raw.keys=keys;Graphics.update;Input.update
  popup=BS2Suite::Palette.current(@scene)
  if popup;popup.update;BS2Suite::Palette.update(@scene)
  elsif BS2QoL::Reference.active?(@scene);BS2QoL::Reference.update(@scene)
  else;@scene.instance_variable_get(:@actor_command_window).update;end
end
def key(n);frame;frame([n]);end
begin
  File.open('test_result.txt','w') { |f| f.puts 'hd_integration_preview ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  [102,256,157,366,278,223,133,168,234,373].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all;actor.add_buff(2,3)
  # Own synthetic enemy and troop; preview contains no unknown boss assets or data.
  enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='Тестовый манекен';enemy.battler_name='';enemy.params=[10000,100,50,50,50,50,50,50]
  $data_enemies[5000]=enemy;troop=RPG::Troop.new;troop.id=79;member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=320;member.y=200;troop.members=[member];$data_troops[79]=troop
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  @scene.instance_variable_get(:@actor_command_window).openness=255
  @raw=HDTestKeys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
  hd=BS2Suite::HDDisplay;model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons
  model.acknowledge(actor,'N');model.acknowledge(actor,'V')
  check(hd.apply(hd::DEFAULT.merge('width'=>1280,'height'=>720)),'HD preset applies during a real native battle scene')
  Graphics.transition(0);Graphics.brightness=255
  10.times { frame }
  check(hd.error.nil?,'HUD serialises actor and battle commands without runtime error')
  rows=hd.lines(@scene).join
  check(!rows.include?('HP ') && rows.include?('Серия')==(actor.actions.size>1),'HD battle rail avoids duplicated resources and only shows a multi-action queue')
  check(!rows.include?('10000') && !rows.include?('сопротивление'),'HUD does not disclose unknown enemy parameters')
  before=Marshal.dump([actor,$game_party.instance_variable_get(:@weapons),$game_troop.members])
  srand(771);expected=rand;srand(771)
  10.times { hd.poll(true) }
  check(Marshal.dump([actor,$game_party.instance_variable_get(:@weapons),$game_troop.members])==before && rand==expected,'HD polling preserves live actors inventory enemies and RNG')
  capture_hd('battle_720p')
  monitor=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDMonitor',['P'],'I');raw=([0]*6).pack('l*');monitor.call(raw);m=raw.unpack('l*')
  if m[3]>=1940 && m[4]>=1120
    check(hd.apply(hd.resolution(1920,1080)),'Full HD output applies on available monitor')
    capture_hd('battle_1080p')
    check(hd.status[6,2]==[1920,1080],'Full HD GPU frame has actual 1920x1080 dimensions')
  end
  key(78);key(49);frame
  popup=BS2Suite::Palette.current(@scene);hd.poll(true)
  check(popup && popup.group==1 && !popup.visible,'native palette remains active but renders through HD pane')
  check(hd.lines(@scene).join.include?('Рекомендуемый арсенал'),'HD pane shows actual N1 entries and group purpose')
  state=hd.status;check(state[13]==state[6]-state[7]*4/3,'palette preserves the normal rail and world size')
  capture_hd('arsenal')
  row=popup.entries.find { |r| BS2Suite::WeaponFamilies.root(r[:id])==361 }
  count=actor.actions.size;key(48+row[:digit]);frame
  check(!BS2Suite::Palette.current(@scene) && actor.equips[0].id==366 && actor.actions.size==count,'HD palette keyboard selection equips without spending an action')
  check(hd.status[13]==state[13],'closing modal preserves the same world viewport')
  key(78);key(50);frame
  popup=BS2Suite::Palette.current(@scene);row=popup.entries.find { |r| BS2Suite::WeaponFamilies.root(r[:id])==123 }
  worn=actor.equips[0];key(48+row[:digit]);frame
  check(direct.selected(actor).id==133 && actor.equips[0]==worn,'HD N2 preserves delayed-selection semantics')
  object=$data_weapons[366];window=Window_BS2QReference.new(object,actor);@scene.instance_variable_set(:@bs2q_reference_window,window)
  @scene.instance_variable_set(:@bs2q_reference_origin,@scene.instance_variable_get(:@actor_command_window));hd.poll(true)
  check(!window.visible && !window.instance_variable_get(:@plate).visible,'HD reference hides both original text and original backing plate')
  check(hd.lines(@scene).join.include?(object.name),'HD reference reuses the existing knowledge-gated card')
  capture_hd('reference')
  BS2QoL::Reference.close(@scene);hd.poll(true)
  check(!BS2QoL::Reference.active?(@scene),'reference closes through existing input lifecycle')
  key(78);key(49);frame;popup=BS2Suite::Palette.current(@scene)
  check(!popup.visible,'source palette hidden while HD is active')
  check(hd.apply(hd.current.merge('sidebar'=>0)) && popup.visible,'disabling HD panel restores the source palette immediately')
  check(hd.apply(hd.current.merge('sidebar'=>1)) && !popup.visible,'re-enabling HD panel restores sidebar presentation')
  BS2Suite::Palette.close(@scene);hd.poll(true)
  @scene.terminate;$game_party.on_battle_end;@scene=nil
  settings=BS2Suite::DisplayCommands.new(0,0)
  list=settings.instance_variable_get(:@list)
  check(list.count { |entry| entry[:symbol]==:preset }==8,'resolution menu offers HD FullHD 1440p 4K and ultrawide presets')
  check([:custom,:fullscreen,:filter,:sidebar,:font,:classic].all? { |key| list.any? { |entry| entry[:symbol]==key } },'resolution menu includes custom dimensions filters text size and restore')
  settings.dispose
  check(hd.apply(hd::DEFAULT.merge('mode'=>1)),'native borderless preview applies')
  capture_hd('monitor')
  log('monitor_output='+hd.status[6,2].inspect)
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  @scene.terminate if @scene
  BS2Suite::HDDisplay.shutdown
  BS2Suite::SteamBridge.stop
  SuiteCapture.close
end
end
