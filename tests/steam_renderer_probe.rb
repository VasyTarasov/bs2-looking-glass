# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
begin
 File.open('test_result.txt','w') { |f| f.puts 'steam renderer probe080' }
 DataManager.init;DataManager.setup_new_game
 window=Win32API.new('user32','GetActiveWindow',[],'L').call
 boot=Win32API.new('./bs2_steam_bridge.dll','BS2_Boot',['L','L'],'I')
 stat=Win32API.new('./bs2_steam_bridge.dll','BS2_Stats',['P'],'I')
 stop=Win32API.new('./bs2_steam_bridge.dll','BS2_Stop',[],'I')
 raise 'Bridge boot failed' unless boot.call(window,1)==1
 sprite=Sprite.new;sprite.bitmap=Bitmap.new(640,480);sprite.bitmap.fill_rect(0,0,640,480,Color.new(15,30,50));sprite.bitmap.fill_rect(16,16,180,100,Color.new(255,0,0));sprite.bitmap.fill_rect(420,300,180,100,Color.new(0,255,0));sprite.bitmap.draw_text(0,180,640,50,'BS2 native OpenGL bridge',1)
 Graphics.transition(0)
 120.times { Graphics.update;Input.update }
 stats=[0]*22;packed=stats.pack('l*');stat.call(packed);stats=packed.unpack('l*')
 File.open('test_result.txt','a') { |f| f.puts 'stats='+stats.inspect }
 SuiteCapture.save('renderer080.bmp')
 stop.call
 sprite.bitmap.dispose;sprite.dispose
 raise 'No native frames captured' unless stats[2]>10
 raise 'OpenGL did not present frames' unless stats[3]>10 && stats[4]==1 && stats[5]==0
 File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks=3' }
rescue Exception=>e
 File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure
 stop.call if stop
 SuiteCapture.close
end
end
