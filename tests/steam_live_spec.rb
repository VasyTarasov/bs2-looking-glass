# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
begin
 File.open('test_result.txt','w') { |f| f.puts 'steam_live080; synthetic image; no achievements or saves' }
 DataManager.init;DataManager.setup_new_game
 init=Win32API.new('./steam_api.dll','SteamAPI_Init',[],'I')
 shutdown=Win32API.new('./steam_api.dll','SteamAPI_Shutdown',[],'V')
 callbacks=Win32API.new('./steam_api.dll','SteamAPI_RunCallbacks',[],'V')
 initialized=(init.call&255)!=0
 File.open('test_result.txt','a') { |f| f.puts 'steam_initialized='+initialized.to_s }
 raise 'Steam initialization unavailable' unless initialized
 window=Win32API.new('user32','GetActiveWindow',[],'L').call
 boot=Win32API.new('./bs2_steam_bridge.dll','BS2_Boot',['L','L'],'I')
 stat=Win32API.new('./bs2_steam_bridge.dll','BS2_Stats',['P'],'I')
 stop=Win32API.new('./bs2_steam_bridge.dll','BS2_Stop',[],'I')
 shot=Win32API.new('./bs2_steam_bridge.dll','BS2_Screenshot',[],'I')
 raise 'Bridge boot failed' unless boot.call(window,3)==1
 sprite=Sprite.new;sprite.bitmap=Bitmap.new(640,480);sprite.bitmap.fill_rect(0,0,640,480,Color.new(15,30,50));sprite.bitmap.fill_rect(16,16,180,100,Color.new(255,0,0));sprite.bitmap.fill_rect(420,300,180,100,Color.new(0,255,0));sprite.bitmap.draw_text(0,180,640,50,'BS2 Steam integration test',1)
 Graphics.transition(0)
 90.times { Graphics.update;Input.update;callbacks.call }
 raise 'Screenshot interface unavailable' unless shot.call==1
 stats=[]
 600.times do
  Graphics.update;Input.update;callbacks.call
  packed=([0]*22).pack('l*');stat.call(packed);stats=packed.unpack('l*')
  break if stats[18]>0
 end
 File.open('test_result.txt','a') { |f| f.puts 'stats='+stats.inspect }
 overlay_loaded=Win32API.new('kernel32','GetModuleHandleA',['P'],'L').call('GameOverlayRenderer.dll')!=0
 overlay_enabled=false
 [10,9,8].each do |v|
  begin
   get=Win32API.new('./steam_api.dll','SteamAPI_SteamUtils_v'+('%03d'%v),[],'L')
   ptr=get.call
   enabled=Win32API.new('./steam_api.dll','SteamAPI_ISteamUtils_IsOverlayEnabled',['L'],'I')
   overlay_enabled=ptr!=0 && (enabled.call(ptr)&255)!=0
   break
  rescue RuntimeError
  end
 end
 File.open('test_result.txt','a') { |f| f.puts 'overlay_module_loaded='+overlay_loaded.to_s;f.puts 'overlay_enabled='+overlay_enabled.to_s }
 if overlay_enabled
  friends=nil
  [17,16,15].each do |v|
   begin
    get=Win32API.new('./steam_api.dll','SteamAPI_SteamFriends_v'+('%03d'%v),[],'L');friends=get.call;break
   rescue RuntimeError
   end
  end
  if friends && friends!=0
   activate=Win32API.new('./steam_api.dll','SteamAPI_ISteamFriends_ActivateGameOverlay',['L','P'],'V')
   activate.call(friends,'achievements')
   180.times { Graphics.update;Input.update;callbacks.call }
   SuiteCapture.save('steam_overlay080.bmp')
  end
 end

 raise 'ScreenshotReady not successful' unless stats[17]>0 && stats[18]==1
 raise 'GL frame failure' unless stats[3]>30 && stats[5]==0
 stop.call;shutdown.call;initialized=false
 sprite.bitmap.dispose;sprite.dispose
 File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks=4' }
rescue Exception=>e
 File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure
 stop.call if stop
 shutdown.call if shutdown && initialized
 SuiteCapture.close
end
end
