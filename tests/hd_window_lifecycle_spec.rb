# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
def check(value,text);raise text unless value;@checks+=1;log('PASS '+text);end
def title
  @scene.terminate if @scene
  @scene=Scene_Title.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
end
def frames(count=45)
  count.times { Graphics.update;Input.update }
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'HD window clipping and title lifecycle' }
  DataManager.init;DataManager.setup_new_game
  hd=BS2Suite::HDDisplay;bridge=BS2Suite::SteamBridge
  BS2Suite::Store.write('hd_display','');hd.instance_variable_set(:@data,nil);hd.instance_variable_set(:@desired,nil)
  title;Graphics.transition(0);Graphics.brightness=255;frames
  check(hd.status[1]==0 && hd.data['launch']==0,'fresh process respects unchecked full-screen launch preference')
  snapshot=Marshal.dump([$game_party,$game_actors,$game_system])
  get_style=Win32API.new('user32','GetWindowLongW',['L','I'],'L')
  window=bridge.stats[14];canvas=bridge.stats[15]
  check(canvas.to_i!=0 && (get_style.call(window,-16)&0x02000000)!=0,'GDI parent excludes the OpenGL child from its paint region')
  check((get_style.call(canvas,-16)&0x06000000)==0x06000000,'OpenGL child clips siblings and child windows')
  [[800,600],[1280,720],[1920,1080]].each do |w,h|
    value=hd.resolution(w,h)
    check(hd.start_trial(value) && hd.confirm,'confirm window '+w.to_s+'x'+h.to_s)
    frames(90)
    check(hd.status[6,2]==[w,h] && bridge.stats[4]==1 && bridge.stats[5]==0,'window and renderer remain ready '+w.to_s)
    chosen=hd.current.dup
    title;frames
    check(hd.current==chosen && hd.status[6,2]==[w,h] && hd.status[1]==1,'return to title preserves active window '+w.to_s)
    check((get_style.call(window,-16)&0x02000000)!=0,'parent clipping survives title '+w.to_s)
  end
  chosen=hd.current.dup
  check(!hd.apply(chosen.merge('width'=>9999)),'invalid output rejected')
  title;frames
  check(hd.current==chosen,'failed display choice does not replace live title preference')
  check(hd.toggle && hd.status[1]==0,'F10 returns to classic output')
  check((get_style.call(window,-16)&0x02000000)!=0,'classic placement keeps compositor clipping while bridge is active')
  title;frames
  check(hd.status[1]==0,'return to title respects deliberate classic-mode toggle')
  check(hd.toggle && hd.status[6,2]==[1920,1080],'F10 restores the last chosen HD size')
  value=hd.resolution(*hd.monitor_size)
  check(hd.apply(value),'native full-screen applies')
  title;frames
  check(hd.status[6,2]==hd.monitor_size && hd.status[2]==1,'return to title preserves full-screen mode independently of launch checkbox')
  check(hd.apply(hd.data.merge('mode'=>2)),'classic placement restored again')
  frames
  check((get_style.call(window,-16)&0x02000000)!=0,'repeated full-screen/classic cycle retains GDI clipping')
  check(Marshal.dump([$game_party,$game_actors,$game_system])==snapshot,'display lifecycle leaves gameplay and save state unchanged')
  title
  # Simulate a fresh process's first title using the persisted launch preference.
  hd.instance_variable_set(:@desired,nil);hd.startup
  check(hd.status[1]==0,'new process launch setting remains separate from current-session title behavior')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  @scene.terminate if @scene
  BS2Suite::SteamBridge.stop
  SuiteCapture.close
end
end
