# encoding: UTF-8
module SpeedQA
  class << self;attr_accessor :ctrl,:focused;end
  self.ctrl=false;self.focused=true
  def self.frames
    before=Graphics.frame_count;yield;Graphics.frame_count-before
  end
end
class SpeedKeysQA
  def down;[];end
  def focused?;SpeedQA.focused;end
end
module Input
  class << self
    def press?(key);key==:CTRL && SpeedQA.ctrl;end
    def trigger?(key);key==:C && $game_message && $game_message.busy?;end
    def repeat?(key);false;end
  end
end
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  def frame;Graphics.update;Input.update;end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Ctrl presentation regression '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    BS2QoL::Keyboard.backend=SpeedKeysQA.new
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    if defined?(BS2Suite::HDDisplay)
      BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT.merge('width'=>2560,'height'=>1440,'mode'=>1))
      5.times { frame }
      check(BS2Suite::HDDisplay.active?,'native speed checks also run with HD output')
    end
    check(BS2Suite::Options.get('instant_battle_ctrl')==1,'instant Ctrl has a registered enabled default')
    check(BS2Suite::Options.set('instant_battle_ctrl',0),'normal Ctrl option persists')
    BS2Suite::Options.instance_variable_set(:@data,nil)
    check(BS2Suite::Options.get('instant_battle_ctrl')==0,'normal option survives preferences reload')
    BS2Suite::Options.set('instant_battle_ctrl',1)
    BS2Suite::Options.instance_variable_set(:@data,nil)
    check(BS2Suite::Options.get('instant_battle_ctrl')==1,'instant option survives preferences reload')
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.recover_all
    $game_map.setup(42);$game_player.moveto(50,39)
    BattleManager.setup(3,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    normal=SpeedQA.frames { scene.wait(60) }
    check(normal>=20,'unheld Ctrl keeps native combat waits')
    SpeedQA.ctrl=true
    check(SpeedQA.frames { scene.wait(60);scene.abs_wait(60) }==0,'held Ctrl removes both battle wait types')
    BS2Suite::Options.set('instant_battle_ctrl',0)
    check(SpeedQA.frames { scene.wait(60) }==normal,'disabling the option restores original waits even with Ctrl held')
    BS2Suite::Options.set('instant_battle_ctrl',1);SpeedQA.focused=false;frame;BS2QoL::Keyboard.update
    check(!BS2Suite::BattleSpeed.active?,'unfocused game does not activate instant mode')
    SpeedQA.focused=true;frame;BS2QoL::Keyboard.update
    check(SpeedQA.frames { Graphics.fadeout(30);Graphics.fadein(30) }<=2,'native battle fades finish in at most one frame each')
    check(Graphics.brightness==255,'instant fade returns to full brightness')
    check(SpeedQA.frames { Graphics.freeze;Graphics.transition(35) }<=1,'native battle wipe unfreezes without a thirty-five-frame wait')
    check(SpeedQA.frames { Graphics.wait(30) }<=1,'explicit graphics battle waits are reduced to one frame')
    sprites=scene.instance_variable_get(:@spriteset).instance_variable_get(:@enemy_sprites)
    sprite=sprites[0];frame;sprite.update
    srand(994);expected=rand(1000000);srand(994);sprite.start_shake(3,30,15)
    check(rand(1000000)==expected,'cosmetic hit shake does not consume combat randomness')
    animation=$data_animations.compact.find { |a| a.frame_max>5 }
    SpeedQA.ctrl=false;sprite.start_animation(animation)
    check(sprite.animation?,'animation still starts normally without Ctrl')
    buffers=sprite.instance_variable_get(:@ani_sprites).dup
    SpeedQA.ctrl=true;sprite.update_animation
    check(!sprite.animation? && buffers.all? { |s| s.disposed? },'pressing Ctrl during animation releases all active animation sprites')
    sprite.start_animation(animation)
    check(!sprite.animation?,'new battle animations allocate no animation sprites while held')
    [:appear,:disappear,:whiten,:blink,:collapse,:boss_collapse,:instant_collapse].each do |effect|
      sprite.start_effect(effect);sprite.update_effect
      check(!sprite.effect? && sprite.effect_duration==0,'native effect reaches its final state immediately: '+effect.to_s)
      check(sprite.opacity==0,'completed collapse/disappearance is invisible: '+effect.to_s) if [:disappear,:collapse,:boss_collapse,:instant_collapse].include?(effect)
    end
    sprite.start_effect(:appear);sprite.update_effect
    check(sprite.opacity==255,'appear restores enemy visibility after instant effect')
    check(sprite.instance_variable_get(:@shake)==[0,0],'instant mode also clears the native sprite-shake offsets')
    SpeedQA.ctrl=false;sprite.damage([123],false)
    check(sprite.popup?,'native damage popup exists before acceleration')
    popup=sprite.instance_variable_get(:@_damage_sprites).map { |v| v[0] }
    SpeedQA.ctrl=true;sprite.update_damage_pop
    check(!sprite.popup? && popup.all? { |s| s.disposed? },'old damage popups are released on acceleration')
    sprite.damage([456],false)
    check(!sprite.popup?,'instant mode creates no lingering damage popup')
    w=Window_Base.new(0,0,120,80);w.openness=0;w.open;w.update
    check(w.open?,'battle window opening is immediate')
    w.close;w.update;check(w.close?,'battle window closing is immediate');w.dispose
    screen=$game_troop.screen
    screen.start_tone_change(Tone.new(50,25,10),120);screen.start_flash(Color.new(255,0,0,255),120);screen.start_shake(9,9,120)
    screen.update
    check(screen.tone.red==50 && screen.flash_color.alpha==0 && screen.shake==0,'battle tone flash and shake settle without leaving stale visuals')
    picture=screen.pictures[1];picture.show('',0,0,0,100,100,255,0);picture.move(0,200,150,80,80,100,0,120);picture.start_tone_change(Tone.new(10,20,30),120);picture.update
    check(picture.x==200 && picture.y==150 && picture.opacity==100 && picture.tone.green==20,'scripted battle picture moves and tones reach their intended endpoints')
    # Timed event waits retain one yield: scripted loops stay cooperative.
    yields=0;done=false
    f=Fiber.new { Game_Interpreter.new.wait(120);done=true }
    until done;f.resume;yields+=1 unless done;end
    check(yields==1,'battle event wait yields once rather than spinning through scripted loops')
    # Native AP/frame-state updates are never multiplied by cosmetic speed.
    actor.instance_variable_set(:@ap,10);enemy=$game_troop.members[0];enemy.instance_variable_set(:@ap,15)
    before=[actor.ap,enemy.ap,actor.instance_variable_get(:@state_frames).dup]
    scene.wait(90);scene.abs_wait(90);scene.show_animation([enemy],animation.id)
    check([actor.ap,enemy.ap,actor.instance_variable_get(:@state_frames)]==before,'skipping presentation does not advance AP or state-frame mechanics')
    actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.actions[0].set_attack
    actor.instance_variable_set(:@action_input_index,0);actor.instance_variable_set(:@ap,ATB::MAX_AP)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    scene.start_actor_command_selection
    3.times { scene.update_basic }
    check(scene.instance_variable_get(:@actor_command_window).active && actor.actions[0].attack?,'held Ctrl neither chooses a command nor overwrites the queued attack')
    scene.terminate;$game_party.on_battle_end
    # Map animation and menu windows remain normal; only battle entry/return
    # transitions get an explicit, exception-safe scope.
    map=Scene_Map.new;SceneManager.instance_variable_set(:@scene,map)
    check(!BS2Suite::BattleSpeed.active?,'held Ctrl does not activate presentation skipping on the map')
    w=Window_Base.new(0,0,120,80);w.openness=0;w.open;w.update
    check(!w.open?,'map/menu windows retain their native animation');w.dispose
    check(SpeedQA.frames { map.perform_battle_transition }<=1,'map-to-battle transition is instantaneous with Ctrl')
    check(!BS2Suite::BattleSpeed.active?,'battle transition scope is cleared after use')
    begin;BS2Suite::BattleSpeed.transition { raise 'controlled scope test' };rescue RuntimeError;end
    check(!BS2Suite::BattleSpeed.active?,'transition scope is also restored after an exception')
    map.start;Graphics.brightness=0;BS2Suite::BattleSpeed.returning=true
    check(SpeedQA.frames { map.perform_transition }<=2 && Graphics.brightness==255,'battle return restores the map brightness in at most two frames')
    check(!BS2Suite::BattleSpeed.returning && !BS2Suite::BattleSpeed.active?,'return-to-map marker is consumed once')
    map.terminate
    settings=BS2Suite::SettingsScene.new;SceneManager.instance_variable_set(:@scene,settings);settings.start
    commands=settings.instance_variable_get(:@commands);list=commands.instance_variable_get(:@list)
    index=list.index { |r| r[:symbol]==:instant_battle_ctrl };check(!!index,'shared mod settings expose the new Ctrl mode')
    commands.select(index);commands.process_ok
    check(BS2Suite::Options.get('instant_battle_ctrl')==0 && commands.active,'actual settings command toggles the mode and stays usable')
    settings.terminate
    log('timing_native_wait='+normal.to_s)
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
