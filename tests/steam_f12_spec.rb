# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
begin
 File.open('test_result.txt','w') { |f| f.puts 'RGSS F12 guard: native import, held key, passthrough, restoration' }
 install=Win32API.new('./input_qa.dll','QA_Install',[],'I')
 pressed=Win32API.new('./input_qa.dll','QA_Pressed',['I'],'I')
 read=Win32API.new('./input_qa.dll','QA_Read',['I'],'I')
 restore=Win32API.new('./input_qa.dll','QA_Restore',[],'I')
 message=Win32API.new('./input_qa.dll','QA_Message',[],'I')
 window_restored=Win32API.new('./input_qa.dll','QA_WindowRestored',[],'I')
 code=install.call;raise 'QA import unavailable: '+code.to_s unless code==1
 File.open('test_result.txt','a') { |f| f.puts 'stage=qa_import_installed' }
 checks=0
 path='Mods/BS2Suite/native/bs2_steam_bridge.dll'
 boot=Win32API.new(path,'BS2_Boot',['L','L'],'I')
 stop=Win32API.new(path,'BS2_Stop',[],'I')
 status=Win32API.new(path,'BS2_InputStatus',['P'],'I')
 focus_status=Win32API.new(path,'BS2_FocusStatus',['P'],'I')
 overlay_tick=Win32API.new(path,'BS2_OverlayTick',[],'I')
 restart_status=Win32API.new(path,'BS2_RestartStatus',['P'],'I')
 restart=Win32API.new(path,'BS2_Restart',[],'I')
 window=Win32API.new('user32','GetActiveWindow',[],'L').call
 sprite=Sprite.new;sprite.bitmap=Bitmap.new(640,480);sprite.bitmap.fill_rect(0,0,640,480,Color.new(24,40,65))
 Graphics.transition(0)
 2.times do
  raise 'Boot failed' unless boot.call(window,1)==1;checks+=1
  5.times { Graphics.update;Input.update }
  File.open('test_result.txt','a') { |f| f.puts 'stage=guard_booted' }
  pressed.call(1)
  raise 'F12 leaks to engine' unless read.call(123)==0;checks+=1
  raise 'Unrelated key changed' unless read.call(254)==0x2345;checks+=1
  raw=([0]*4).pack('l*');raise 'Focus ABI wrong' unless focus_status.call(raw)==4;checks+=1
  raise 'Inactive overlay drew frames' unless overlay_tick.call==0;checks+=1
  90.times { raise 'F12 window message leaked' unless message.call==1;Graphics.update;Input.update };checks+=1
  raw=([0]*4).pack('l*');raise 'Input ABI wrong' unless status.call(raw)==4;checks+=1
  data=raw.unpack('l*');File.open('test_result.txt','a') { |f| f.puts 'input_status='+data.inspect }
  raise 'No intercepted F12 events' unless data[1]==1 && data[2]>30;checks+=1
  raw=([0]*4).pack('l*');raise 'Restart ABI wrong' unless restart_status.call(raw)==4;checks+=1
  raise 'F12 no longer requests reset' unless raw.unpack('l*')[1]==1;checks+=1
  raise 'QA recursively launched itself' unless restart.call==0;checks+=1
  raw=([0]*4).pack('l*');restart_status.call(raw)
  raise 'QA restart did not refuse safely' unless raw.unpack('l*')[1,3]==[0,0,50];checks+=1
  pressed.call(3);message.call
  raw=([0]*4).pack('l*');restart_status.call(raw)
  raise 'Modified F12 requests reset' unless raw.unpack('l*')[1]==0;checks+=1
  pressed.call(0)
  raise 'Stop failed' unless stop.call==1;checks+=1
  raw=([0]*4).pack('l*');status.call(raw);raise 'Guard not removed' unless raw.unpack('l*')[1]==0;checks+=1
  raise 'Passthrough not restored' unless read.call(254)==0x2345;checks+=1
  raise 'Window callback not restored' unless window_restored.call==1;checks+=1
 end
 raise 'QA restoration failed' unless restore.call==1;checks+=1
 sprite.bitmap.dispose;sprite.dispose
 File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks='+checks.to_s }
rescue Exception=>e
 File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure
 pressed.call(0) if pressed
 stop.call if stop
 SuiteCapture.close
end
end
