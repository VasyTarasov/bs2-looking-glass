# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
def check(value,label);raise 'Assertion: '+label unless value;@checks+=1;log('PASS '+label);end
def conditional_replay
  interpreter=Game_Interpreter.new
  list=[]
  10.times do
    list<<RPG::EventCommand.new(111,0,[0,1,0])
    list<<RPG::EventCommand.new(412,0,[])
  end
  list<<RPG::EventCommand.new(0,0,[])
  interpreter.setup(list,8);interpreter.instance_variable_set(:@map_id,85)
  started=Time.now.to_f;frame=Graphics.frame_count
  100.times do |n|
    Graphics.frame_count=frame+n
    5.times do
      10.times do |index|
        interpreter.instance_variable_set(:@index,index*2);interpreter.execute_command
      end
    end
  end
  elapsed=(Time.now.to_f-started)*1000;Graphics.frame_count=frame
  elapsed
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'native diagnostics conditional replay; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  $game_switches[1]=false
  BS2Suite::Debug.close
  before=Marshal.dump(DataManager.make_save_contents)
  srand(65213);expected=rand;srand(65213)
  off=conditional_replay
  BS2Suite::Debug.start;directory=BS2Suite::Debug.directory
  enabled=conditional_replay
  BS2Suite::Debug.emit('bookmark',{:qa=>true});BS2Suite::Debug.close
  rows=Dir.glob(File.join(directory,'events_*.jsonl')).map { |p| File.open(p,'rb') { |f| f.readlines } }.flatten
  initial=rows.count { |line| line.include?('"type":"event_command"') }
  repeats=rows.select { |line| line.include?('"type":"event_command_repeat"') }
  repeated=repeats.inject(0) { |sum,line| sum+line[/"count":([0-9]+)/,1].to_i }
  check(initial+repeated==5000,'all 5000 conditional executions remain accounted for')
  check(Marshal.dump(DataManager.make_save_contents)==before && rand==expected,'logging preserves native world state and RNG')
  if defined?(BS2Suite::Debug::WATCHED_COMMANDS)
    check(initial<=20 && repeats.size<=20,'repeated conditions use bounded aggregate records')
    check(repeats.all? { |line| line.include?('"first_frame"') && line.include?('"last_frame"') },'aggregate records preserve their frame range')
    BS2Suite::Debug.start
    fields={:map=>85,:event=>8,:index=>0,:code=>111,:indent=>0}
    4.times { BS2Suite::Debug.condition_command(fields) }
    BS2Suite::Debug.emit('exception',{:class=>'QA synthetic exception'})
    dir=BS2Suite::Debug.directory;BS2Suite::Debug.close
    text=Dir.glob(File.join(dir,'events_*.jsonl')).map { |p| File.open(p,'rb') { |f| f.read } }.join
    check(text.index('"type":"event_command_repeat"')<text.index('"type":"exception"'),'pending repeats are flushed before an exception')
    BS2Suite::Debug.start;dir=BS2Suite::Debug.directory
    seq=BS2Suite::Debug.instance_variable_get(:@seq)
    100.times { $game_party.gain_item(nil,1);$game_party.gain_gold(0) }
    check(BS2Suite::Debug.instance_variable_get(:@seq)==seq,'no-op inventory and gold operations do not write noise')
    gold=$game_party.gold;$game_party.gain_gold(1);$game_party.lose_gold(1)
    check($game_party.gold==gold && BS2Suite::Debug.instance_variable_get(:@seq)==seq+2,'actual gold changes remain immediately logged')
    BS2Suite::Debug.tick(SceneManager.scene)
    original=Graphics.frame_count;Graphics.frame_count=original+600
    BS2Suite::Debug.tick(SceneManager.scene);Graphics.frame_count=original
    BS2Suite::Debug.close
    text=Dir.glob(File.join(dir,'events_*.jsonl')).map { |p| File.open(p,'rb') { |f| f.read } }.join
    check(text.include?('"observed_fps"') && text.include?('"max_update_gap_ms"') && text.include?('"focused"'),'heartbeat provides timing and focus evidence for future lag reports')
  end
  log('performance; logging_off_ms='+off.round.to_s+'; logging_on_ms='+enabled.round.to_s+'; command_records='+initial.to_s+'; aggregate_records='+repeats.size.to_s)
  File.open('performance_result.txt','w') { |f| f.puts [off,enabled,initial,repeats.size].join(',') }
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>error
  log('result=FAIL; '+error.class.to_s+': '+error.message);log(error.backtrace.join("\n"))
ensure
  BS2Suite::Debug.close if defined?(BS2Suite::Debug)
  SceneManager.exit;Graphics.transition(0);SuiteCapture.close;5.times { Graphics.update }
end
end
