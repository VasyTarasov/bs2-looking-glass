# encoding: UTF-8
# Synthetic process only. Retain disposed sprites to test resource ownership
# independently of Ruby's native-memory-blind GC; bound the baseline to 8 loops.
rgss_main do
  checks=0;held=[];samples=[]
  log=lambda { |s| File.open('test_result.txt','a') { |f| f.puts s } }
  check=lambda { |v,s| raise s unless v;checks+=1;log.call('PASS '+s) }
  stats=lambda do
    handle=Win32API.new('kernel32','GetCurrentProcess',[],'L').call
    bytes=([44]+[0]*10).pack('L*')
    ok=Win32API.new('psapi','GetProcessMemoryInfo',['L','P','L'],'I').call(handle,bytes,bytes.bytesize)
    counters=bytes.unpack('L*')
    live=0;pixels=0
    ObjectSpace.each_object(Bitmap) { |b| unless b.disposed?;live+=1;pixels+=b.width*b.height;end }
    {:private_bytes=>ok!=0 ? counters[10] : nil,:working_set=>counters[3],:gdi=>Win32API.new('user32','GetGuiResources',['L','L'],'L').call(handle,0),:live_bitmaps=>live,:pixels=>pixels}
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'resource ownership regression '+BS2Suite::VERSION }
    baseline=File.file?('resource-baseline.txt')
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.recover_all
    $game_map.setup(42);$game_player.moveto(50,39)
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    if defined?(BS2Suite::HDDisplay)
      BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT.merge('width'=>2560,'height'=>1440,'mode'=>1))
      15.times { Graphics.update;Input.update }
      check.call(BS2Suite::HDDisplay.active? && BS2Suite::HDDisplay.status[6,2]==[2560,1440],'resource soak uses actual 1440p HD output')
    end
    loops=baseline ? 8 : 40
    loops.times do |i|
      $game_party.on_battle_end if $game_party.in_battle
      SceneManager.instance_variable_set(:@scene,Scene_Map.new)
      BattleManager.setup(i.even? ? 93 : 97,true,true)
      $game_party.on_battle_start;BattleManager.make_battlers_ap
      scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
      sprites=scene.instance_variable_get(:@spriteset).instance_variable_get(:@enemy_sprites)
      gauges=sprites.map { |s| s.instance_variable_get(:@gauge_sprite).instance_variable_get(:@sprites) }.flatten
      bitmaps=gauges.map { |g| g.bitmap }
      if !baseline && i==0
        gauges.each_with_index do |g,n|
          small=g.bitmap;g.refresh
          expected=[]
          small.width.times do |x|
            6.times do |y|
              c=small.get_pixel(x,y);expected<<[c.red,c.green,c.blue,c.alpha]
            end
          end
          full=Bitmap.new(Graphics.width,Graphics.height)
          begin
            g.bitmap=full;g.refresh;actual=[]
            small.width.times do |x|
              6.times do |y|
                c=full.get_pixel(x,y);actual<<[c.red,c.green,c.blue,c.alpha]
              end
            end
            check.call(small.height==6 && actual==expected,'compact native strip preserves every displayed gauge pixel '+n.to_s)
          ensure
            g.bitmap=small;full.dispose
          end
        end
      end
      scene.terminate
      held+=bitmaps
      unless baseline
        check.call(bitmaps.all? { |b| b.disposed? },'every private enemy-gauge bitmap is explicitly released after battle '+i.to_s)
      end
      samples<<stats.call.merge(:cycle=>i)
      raise 'bounded baseline resource budget reached' if samples[-1][:private_bytes].to_i>650*1024*1024
    end
    undisposed=held.reject { |b| b.disposed? }
    pixels=undisposed.inject(0) { |n,b| n+b.width*b.height }
    if baseline
      check.call(!undisposed.empty? && pixels>=8*640*480,'negative control reproduces undisposed full-screen gauge resources')
    else
      check.call(undisposed.empty?,'no retained gauge backing resources after repeated real battle teardown')
      tail=samples.last(30).map { |s| s[:private_bytes].to_i }
      check.call(tail.max-tail.min<16*1024*1024,'warmed forty-battle private memory stays within a bounded sixteen-MiB range')
      check.call(samples.last(30).map { |s| s[:gdi] }.max-samples.last(30).map { |s| s[:gdi] }.min<30,'warmed graphics handle count does not grow per battle')
      check.call(BS2Suite::ResourceStats.sample[:private_bytes].to_i>0,'diagnostics can sample this process without reading its memory contents')
    end
    File.open('resource_samples.txt','w') { |f| samples.each { |s| f.puts s.inspect };f.puts 'retained_gauge_pixels='+pixels.to_s }
    undisposed.each { |b| b.dispose }
    GC.start;samples<<stats.call.merge(:after_cleanup=>true)
    File.open('resource_samples.txt','a') { |f| f.puts samples[-1].inspect }
    log.call('result=PASS; checks='+checks.to_s)
  rescue Exception=>e
    log.call('result=FAIL; '+e.class.to_s+': '+e.message);log.call(e.backtrace.join("\n"))
  ensure
    held.each { |b| b.dispose unless b.disposed? }
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
