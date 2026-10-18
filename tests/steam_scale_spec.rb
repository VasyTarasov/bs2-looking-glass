# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
begin
 File.open('test_result.txt','w') { |f| f.puts 'steam scale080' }
 DataManager.init;DataManager.setup_new_game
 bridge=BS2Suite::SteamBridge
 raise bridge.error.to_s if bridge.error
 sprite=Sprite.new;sprite.bitmap=Bitmap.new(640,480);sprite.bitmap.fill_rect(0,0,640,480,Color.new(10,20,35));sprite.bitmap.fill_rect(16,16,180,100,Color.new(255,0,0));sprite.bitmap.fill_rect(420,300,180,100,Color.new(0,255,0));sprite.bitmap.draw_text(0,180,640,50,'OpenGL scale test',1)
 Graphics.transition(0);30.times { Graphics.update;Input.update }
 first=bridge.stats[3]
 scale_available=BS2Suite::Scaling.apply(2)
 File.open('test_result.txt','a') { |f| f.puts 'scale_two_fits_private_monitor='+scale_available.to_s }
 unless scale_available
  # The private desktop may expose a small virtual monitor. Resize only this
  # synthetic process's window off-screen to verify the GL resize path anyway.
  hwnd=Win32API.new('user32','GetActiveWindow',[],'L').call
  get=Win32API.new('user32','GetWindowLongW',['L','I'],'L')
  rect=[0,0,1280,960].pack('l4');Win32API.new('user32','AdjustWindowRectEx',['P','L','I','L'],'I').call(rect,get.call(hwnd,-16),0,get.call(hwnd,-20))
  r=rect.unpack('l4')
  raise 'Private resize failed' if Win32API.new('user32','SetWindowPos',['L','L','I','I','I','I','L'],'I').call(hwnd,0,0,0,r[2]-r[0],r[3]-r[1],0x14)==0
 end
 raise 'GDI scaling overlay covers GL' if BS2Suite::Scaling.instance_variable_get(:@overlay)
 start=Win32API.new('kernel32','GetTickCount',[],'L').call
 120.times { Graphics.update;Input.update }
 elapsed=Win32API.new('kernel32','GetTickCount',[],'L').call-start
 stats=bridge.stats
 raise 'Scaled GL stopped producing frames' unless stats[3]>first+60 && stats[6,2]==[640,480] && stats[5]==0
 SuiteCapture.save('BS2QA_steam_scale080.bmp',nil,1280,960)
 raise 'Scale 1 failed' unless BS2Suite::Scaling.apply(1)
 20.times { Graphics.update;Input.update }
 raise 'GL failed after returning to original scale' unless bridge.stats[3]>stats[3] && bridge.stats[5]==0
 bridge.stop
 10.times { Graphics.update;Input.update }
 sprite.bitmap.dispose;sprite.dispose
 File.open('test_result.txt','a') { |f| f.puts 'frames120_elapsed_ms='+elapsed.to_s;f.puts 'stats='+stats.inspect;f.puts 'result=PASS; checks=6' }
rescue Exception=>e
 File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure
 BS2Suite::SteamBridge.stop
 SuiteCapture.close
end
end
