# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'map heat haze and diagnostic cost '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@scene,Scene_Map.new)
    BS2Suite::Debug.close if defined?(BS2Suite::Debug)
    if defined?(BS2Suite::HDDisplay)
      check(BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT.merge('width'=>2560,'height'=>1440,'mode'=>1)),'real 1440p HD mode applies in private test')
    end
    $game_map.setup(127);$game_player.moveto(18,18)
    x=$game_map.display_x;y=$game_map.display_y
    sprites=Spriteset_Map.new
    check([$game_map.display_x,$game_map.display_y]==[x,y],'heat-haze snapshots preserve the preexisting camera position')
    haze=sprites.instance_variable_get(:@heat_haze);crop=haze.instance_variable_get(:@bs20997_crop);full=$game_temp.heat_haze_bitmap
    check(crop && crop.width==656 && crop.height==486 && full.width>crop.width,'heat-wave processing uses a bounded visible-region bitmap with edge padding')
    sprite=haze.instance_variable_get(:@heat_haze_sprite)
    x=sprites.tilemap.ox.to_i;y=sprites.tilemap.oy.to_i
    equal=true
    (0...480).step(37) do |dy|
      (0...640).step(41) do |dx|
        next if x+dx>=full.width || y+dy>=full.height
        a=crop.get_pixel(dx+8,dy);b=full.get_pixel(x+dx,y+dy)
        equal &&= [a.red,a.green,a.blue,a.alpha]==[b.red,b.green,b.blue,b.alpha]
      end
    end
    check(equal,'visible cropped heat pixels match the original full-map source')
    check(sprite.ox==8 && sprite.oy==3,'cropped sprite retains visible coordinate offset')
    control=Sprite.new(sprite.viewport);control.bitmap=full;control.z=sprite.z;control.opacity=sprite.opacity
    control.wave_amp=sprite.wave_amp;control.wave_length=sprite.wave_length;control.wave_speed=sprite.wave_speed
    control.wave_phase=sprite.wave_phase-haze.instance_variable_get(:@bs20997_y_phase);control.ox=x;control.oy=y+3;control.visible=false
    cropped_image=Graphics.snap_to_bitmap
    sprite.visible=false;control.visible=true;original_image=Graphics.snap_to_bitmap
    differences=0
    (4...476).step(17) do |dy|
      (4...636).step(19) do |dx|
        a=cropped_image.get_pixel(dx,dy);b=original_image.get_pixel(dx,dy)
        differences+=1 if [a.red-b.red,a.green-b.green,a.blue-b.blue,a.alpha-b.alpha].any? { |v| v.abs>1 }
      end
    end
    control.dispose;sprite.visible=true;cropped_image.dispose;original_image.dispose
    check(differences==0,'rendered wave matches original full-map effect including phase and scrolling')
    clock=Win32API.new('kernel32','GetTickCount',[],'L')
    results=[]
    [false,true].each do |cropped|
      sprite.bitmap=cropped ? crop : full;sprite.ox=cropped ? 8 : x;sprite.oy=cropped ? 3 : y+3
      20.times { sprite.update;Graphics.update }
      before=clock.call
      180.times { sprite.update;Graphics.update }
      ms=(clock.call-before)&0xffffffff;results<<[cropped,ms,180000.0/ms]
    end
    File.open('performance.txt','w') { |f| results.each { |cropped,ms,fps| f.puts 'crop='+cropped.to_s+'; frames=180; ms='+ms.to_s+'; fps='+fps.round(2).to_s } }
    sprite.bitmap=crop
    sprites.dispose
    check(crop.disposed?,'owned crop buffer is disposed on map teardown')
    # Isolate the repeated map-event recording cost from GPU/vsync waits.
    if defined?(BS2Suite::Debug)
      timings=[];records=[]
      [false,true].each do |aggregate|
        BS2Suite::Debug.start;directory=BS2Suite::Debug.directory
        interpreter=Game_Interpreter.new
        list=[RPG::EventCommand.new(121,0,[1,1,1]),RPG::EventCommand.new(0,0,[])]
        interpreter.setup(list,99);initial=Graphics.frame_count
        before=clock.call
        120.times do |frame|
          Graphics.frame_count=initial+frame
          20.times do
            interpreter.instance_variable_set(:@index,0)
            if aggregate;interpreter.execute_command
            else
              BS2Suite::Debug.emit('event_command',{:map=>127,:event=>99,:index=>0,:code=>121,:indent=>0})
              interpreter.bs2suite_debug_command
            end
          end
        end
        timings<<((clock.call-before)&0xffffffff);Graphics.frame_count=initial
        BS2Suite::Debug.close
        lines=Dir.glob(File.join(directory,'events_*.jsonl')).map { |p| File.open(p,'rb') { |f| f.readlines } }.flatten
        records<<lines.count { |l| l.include?('"type":"event_command"') || l.include?('"type":"event_command_repeat"') }
      end
      check(records[1]<=4 && records[0]>=2400,'parallel no-op assignments use bounded records instead of per-frame writes')
      File.open('performance.txt','a') { |f| f.puts 'repeated_commands=2400; individual_ms='+timings[0].to_s+'; aggregate_ms='+timings[1].to_s+'; records='+records.join(',') }
    end
    # Exercise the new native capture fence in the real HD presenter.
    if defined?(BS2Suite::HDDisplay)
      BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT)
      3.times { Graphics.update };BS2Suite::SteamBridge.poll
      BS2Suite::MapCapture.pause(true);before=BS2Suite::SteamBridge.stats[2]
      5.times { Graphics.update };BS2Suite::SteamBridge.poll
      check(BS2Suite::SteamBridge.stats[2]==before,'temporary snapshot frames are excluded from HD presentation')
      BS2Suite::MapCapture.pause(false);5.times { Graphics.update };BS2Suite::SteamBridge.poll
      check(BS2Suite::SteamBridge.stats[2]>before,'regular HD presentation resumes after capture fence')
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::MapCapture.pause(false) if defined?(BS2Suite::MapCapture)
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
