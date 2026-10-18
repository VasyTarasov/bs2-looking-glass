# encoding: UTF-8
module Stress
 @pass=0;@fail=0
 def self.log(s);File.open('test_result.txt','a'){|f|f.puts s};end
 def self.test(name)
  begin;raise 'assertion false' unless yield;@pass+=1;log('PASS '+name)
  rescue StandardError=>e;@fail+=1;log('FAIL '+name+' | '+e.class.to_s+': '+e.message);end
 end
 def self.finish;log('result='+(@fail==0 ? 'PASS' : 'FAIL')+'; checks='+(@pass+@fail).to_s+'; passed='+@pass.to_s+'; failed='+@fail.to_s);end
end
begin
 File.open('test_result.txt','w'){|f|f.puts 'extended native stress and fault injection'}
 DataManager.init;DataManager.setup_new_game;Window_MenuCommand.init_command_position
 SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
 class << DataManager;def make_filename(i);'StressSave'+i.to_s+'.rvdata2';end;end
 100.times do |i|
  Stress.test('SLOT '+(i+1).to_s+' write/load/label') do
   $game_variables[702]=i;BS2Suite::Saves.rename(i,'Слот '+(i+1).to_s)
   DataManager.save_game(i) && DataManager.load_game(i) && $game_variables[702]==i && BS2Suite::Saves.label(i)=='Слот '+(i+1).to_s
  end
 end
 Stress.test('ALL slots stable across each of three sort modes') do
  (0..2).all?{|mode|BS2Suite::Saves.rows(mode).map{|r|r[:id]}.sort==(0...105).to_a}
 end
 Stress.test('NEWEST valid header but truncated body is skipped') do
  File.open(DataManager.make_filename(10),'wb'){|f|Marshal.dump(DataManager.make_save_header,f);f.write('bad body')}
  File.utime(Time.now+100,Time.now+100,DataManager.make_filename(10));DataManager.latest_savefile_index!=10
 end
 Stress.test('HEADER invalid UTF8 map cannot crash list') do
  head=DataManager.make_save_header;head[:bs2_map]="\xff".force_encoding('UTF-8')
  File.open(DataManager.make_filename(11),'wb'){|f|Marshal.dump(head,f);Marshal.dump(DataManager.make_save_contents,f)}
  w=BS2Suite::Saves::List.new;w.set_rows(BS2Suite::Saves.rows(0),11);w.dispose;true
 end
 Stress.test('LOAD type-corrupt world rejected without mutation') do
  head=DataManager.make_save_header;body=DataManager.make_save_contents;body[:party]=nil
  File.open(DataManager.make_filename(12),'wb'){|f|Marshal.dump(head,f);Marshal.dump(body,f)}
  before=Marshal.dump(DataManager.make_save_contents);!DataManager.load_game(12) && Marshal.dump(DataManager.make_save_contents)==before
 end
 Stress.test('LOAD injected partial extraction failure restores identities and frame') do
  DataManager.save_game(13);before=DataManager.make_save_contents;frame=Graphics.frame_count
  class << DataManager
   alias stress_extract extract_save_contents
   def extract_save_contents(contents)
    if @stress_fail
     @stress_fail=false;$game_party=contents[:party];raise IOError,'injected partial extraction failure'
    end
    stress_extract(contents)
   end
  end
  DataManager.instance_variable_set(:@stress_fail,true)
  result=!DataManager.load_game(13) && DataManager.make_save_contents==before && Graphics.frame_count==frame
  class << DataManager;alias extract_save_contents stress_extract;end
  result
 end
 Stress.test('SAVE fsync failure keeps previous bytes and count') do
  DataManager.save_game(14);path=DataManager.make_filename(14);before=File.open(path,'rb'){|f|f.read};count=$game_system.save_count
  class File
   alias stress_fsync fsync
   def fsync;raise IOError,'injected flush failure' if path && path.end_with?('.bs2suite.tmp');stress_fsync;end
  end
  result=!DataManager.save_game(14) && File.open(path,'rb'){|f|f.read}==before && $game_system.save_count==count
  class File;alias fsync stress_fsync;end
  result
 end
 Stress.test('SETTINGS real Windows lock retains old bytes and memory option') do
  BS2Suite::Options.set('bgm',90);path=File.expand_path(BS2Suite::Store.path('options'));before=File.open(path,'rb'){|f|f.read}
  wide=(path+"\0").encode('UTF-16LE');handle=Win32API.new('kernel32','CreateFileW',['P','L','L','L','L','L','L'],'L').call(wide,0x80000000,0,0,3,0,0)
  raise 'Could not acquire fixture lock' if handle==0xffffffff
  result=!BS2Suite::Options.set('bgm',20) && BS2Suite::Options.get('bgm')==90
  Win32API.new('kernel32','CloseHandle',['L'],'I').call(handle)
  result && File.open(path,'rb'){|f|f.read}==before
 end
 Stress.test('DIAGNOSTIC recovery clears stale I/O error') do
  BS2Suite::Debug.close
  class << File
   alias stress_open open
   def open(path,*args,&block)
    if @stress_fail && path.to_s.end_with?('.jsonl');@stress_fail=false;raise Errno::EACCES,'injected log failure';end
    stress_open(path,*args,&block)
   end
  end
  File.instance_variable_set(:@stress_fail,true);BS2Suite::Debug.start
  failed=!!BS2Suite::Debug.error
  class << File;alias open stress_open;end
  BS2Suite::Debug.start
  success=BS2Suite::Debug.emit('stress_recovery',{:ok=>true}) && BS2Suite::Debug.error.nil?
  BS2Suite::Debug.close;failed && success
 end
 Stress.test('DIAGNOSTIC cyclic values, invalid text and nonfinite numbers serialize safely') do
  a=[];a<<a;text="\xff\x00".force_encoding('UTF-8')
  out=BS2Suite::Debug.json({:cycle=>a,:text=>text,:nan=>0.0/0.0,:inf=>1.0/0.0})
  File.open('stress_json.txt','wb'){|f|f.write(out)};out.valid_encoding? && out.include?('null')
 end
 Stress.test('UI 150 screen lifecycles keep live windows stable') do
  GC.start;before=ObjectSpace.each_object(Window).count{|w|!w.disposed?}
  50.times do
   [BS2Suite::SettingsScene,BS2Suite::KeysScene,BS2Suite::ModuleScene].each do |klass|
    scene=klass.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.terminate
   end
  end
  GC.start;after=ObjectSpace.each_object(Window).count{|w|!w.disposed?};Stress.log('live_windows_before='+before.to_s+' after='+after.to_s);after==before
 end
 Stress.test('DIAGNOSTIC chunk rotation preserves all prior parts') do
  BS2Suite::Debug.start;directory=BS2Suite::Debug.directory;payload='a'*100000
  100.times{BS2Suite::Debug.emit('rotation_test',{:payload=>payload})}
  BS2Suite::Debug.close;parts=Dir.glob(File.join(directory,'*.jsonl'));parts.size>=2 && parts.all?{|p|File.size(p)>0}
 end
 Stress.test('DURATION 3600 native frames preserve world without live windows growth') do
  before=Marshal.dump(DataManager.make_save_contents);GC.start;count=ObjectSpace.each_object(Window).count{|w|!w.disposed?}
  3600.times{Graphics.update;Input.update}
  GC.start;Marshal.dump(DataManager.make_save_contents)==before && count==ObjectSpace.each_object(Window).count{|w|!w.disposed?}
 end
 Stress.finish
rescue Exception=>e
 Stress.log('FATAL '+e.class.to_s+': '+e.message+"\n"+e.backtrace.join("\n"));Stress.finish
ensure;exit;end
