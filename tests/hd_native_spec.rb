# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
begin
  File.open('test_result.txt','w') { |f| f.puts 'hd_native_preview; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  hd=BS2Suite::HDDisplay;bridge=BS2Suite::SteamBridge
  check(hd.ready?,'new HD ABI bound without requiring Steam')
  dpi=hd.dpi
  check(dpi.size==8 && dpi[1]>0 && dpi[7]==0,'DPI-aware child avoids logical-resolution virtualization')
  log('dpi_geometry='+dpi.inspect)
  restart_dpi=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDRestartDPI',[],'I')
  check(restart_dpi.call==0,'DPI restart cannot recursively launch a private QA fixture')
  path='Mods/BS2Suite/native/bs2_steam_bridge.dll'
  layout=Win32API.new(path,'BS2_HDLayout',['I','I','P'],'I')
  write=Win32API.new(path,'BS2_HDText',['P','I'],'I')
  read=Win32API.new(path,'BS2_HDReadback',['P','I'],'I')
  monitor=Win32API.new(path,'BS2_HDMonitor',['P'],'I')
  snapshot=Marshal.dump([$game_party,$game_actors,$game_system])
  sprite=Sprite.new;sprite.bitmap=Bitmap.new(640,480);sprite.bitmap.fill_rect(0,0,640,480,Color.new(35,53,75))
  sprite.bitmap.font.name='Segoe UI';sprite.bitmap.font.size=30
  sprite.bitmap.draw_text(24,160,592,70,'BLACK SOULS II — HD-прототип',1)
  sprite.bitmap.font.size=22;sprite.bitmap.draw_text(24,230,592,36,'Игровая сцена сохраняет пропорции',1)
  Graphics.transition(0);Graphics.brightness=255
  check(hd.apply(hd::DEFAULT.merge('width'=>800,'height'=>600)),'small HD window applies inside private desktop')
  10.times { Graphics.update;Input.update }
  log('native_stats='+bridge.stats.inspect+' hd='+hd.status.inspect)
  check(hd.status[1]==1 && hd.status[6,2]==[800,600],'actual client size matches requested output')
  check(bridge.stats[4]==1 && bridge.stats[5]==0,'OpenGL compositor draws without error')
  check(Graphics.width==640 && Graphics.height==480,'world and RGSS layout remain at original logical size')
  hd::PRESETS.each do |label,width,height|
    raw=([0]*12).pack('l*');check(layout.call(width,height,raw)==12,'layout ABI '+label+' '+width.to_s)
    v=raw.unpack('l*')
    check(v[4]*3==v[5]*4,'world aspect preserved '+width.to_s)
    check(v[2]>=0 && v[3]>=0 && v[2]+v[4]<=v[6] && v[3]+v[5]<=height && v[6]+v[8]==width,'world and panel fit output '+width.to_s)
    check(v[8]>0 && v[10]>=15,'independent HD text area exists '+width.to_s)
  end
  presentation=Win32API.new(path,'BS2_HDPresentation',['I'],'I')
  hd::PRESETS.each do |label,width,height|
    a=([0]*12).pack('l*');b=([0]*12).pack('l*')
    presentation.call(0);layout.call(width,height,a);presentation.call(1);layout.call(width,height,b)
    check(a==b,'reference presentation preserves all world/panel geometry '+width.to_s+'x'+height.to_s)
  end
  presentation.call(0)
  measure=Win32API.new(path,'BS2_HDMeasure',['P','I','I'],'I')
  value='Кириллический текст';check(measure.call(value,value.bytesize,22)>0 && measure.call('',0,22)==0,'exact HD text metric API measures Unicode and empty lines')
  before=hd.status
  check(!hd.apply(hd::DEFAULT.merge('width'=>9999)) && hd.status==before,'out-of-range configuration leaves the window unchanged')
  check(!hd.apply(hd::DEFAULT.merge('width'=>7680,'height'=>4320)) && hd.status[6,2]==[800,600],'oversized window fails without changing current size')
  text="T\tПроверка чёткого текста\nH\tСвой интерфейс\nS\tКириллица: АБВГД — 1440p / 4K\nA\tВыбранная строка\nS\tHP 1234 / 5678\nS\tMP 90 / 100"
  check(write.call(text,text.bytesize)==1,'native panel accepts UTF-8 Cyrillic')
  check(write.call("\xff",1)==0,'invalid UTF-8 rejected without rendering garbage')
  check(read.call('',0)==1,'composite readback request accepted')
  3.times { Graphics.update;Input.update }
  w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT')
  check(read.call(pixels,pixels.bytesize)==pixels.bytesize,'actual GPU composite readback includes HD panel')
  check(pixels.bytes.to_a.uniq.size>24,'composite contains rendered scene and antialiased text')
  header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
  File.open('BS2QA_HD_native.bmp','wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
  check(hd.start_trial(hd::DEFAULT.merge('width'=>960,'height'=>720,'filter'=>1)),'reversible display trial starts')
  check(!hd.start_trial(hd::DEFAULT),'nested trials rejected')
  check(hd.rollback && hd.status[6,2]==[800,600] && !hd.trial,'cancel restores previous mode')
  check(hd.start_trial(hd::DEFAULT.merge('width'=>960,'height'=>720,'filter'=>2)),'integer scaling trial starts')
  hd.trial['started']=(Win32API.new('kernel32','GetTickCount',[],'L').call-16000)&0xffffffff;hd.poll(true)
  check(!hd.trial && hd.status[6,2]==[800,600],'15-second timeout restores mode without input')
  check(hd.start_trial(hd::DEFAULT.merge('width'=>960,'height'=>720)) && hd.confirm,'explicit confirmation saves mode')
  hd.instance_variable_set(:@data,nil)
  check(hd.data['width']==960 && hd.data['height']==720,'display settings persist in bounded own configuration')
  raw=([0]*6).pack('l*');check(monitor.call(raw)==6,'own monitor metadata available');m=raw.unpack('l*')
  check(hd.resolution(m[1],m[2])['mode']==1,'native-size preset selects borderless mode')
  check(hd.apply(hd.data.merge('mode'=>1)),'borderless mode applies on own monitor')
  3.times { Graphics.update;Input.update }
  check(hd.status[6,2]==m[1,2],'borderless uses monitor size without changing display mode')
  check(hd.status[6,2]==dpi[3,2],'borderless dimensions match physical monitor pixels')
  check(Marshal.dump([$game_party,$game_actors,$game_system])==snapshot,'resolution and HD polling do not mutate gameplay state')
  check(hd.apply(hd::DEFAULT.merge('mode'=>2)) && hd.status[1]==0,'original window placement can be restored')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  sprite.bitmap.dispose if sprite && sprite.bitmap;sprite.dispose if sprite
  BS2Suite::SteamBridge.stop
  SuiteCapture.close
end
end
