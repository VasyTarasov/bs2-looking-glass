# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'bounded live-performance diagnostics '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@scene,Scene_Map.new)
    trace=BS2Suite::PerfTrace
    BS2Suite::Debug.start;directory=BS2Suite::Debug.directory
    check(trace.enabled?,'performance tracing follows the active diagnostic session')
    first=trace.now;second=trace.now
    check(first && second>=first,'monotonic high-resolution native clock is available')
    value=trace.measure(:qa_value) { 123 }
    check(value==123,'profile wrapper returns the original value')
    caught=false
    begin;trace.measure(:qa_error) { raise ArgumentError,'QA controlled failure' }
    rescue ArgumentError;caught=true;end
    check(caught,'profile wrapper preserves original exceptions')
    world=Marshal.dump(DataManager.make_save_contents);srand(995);expected=rand(1000000);srand(995)
    2000.times { trace.measure(:qa_scope) { 1+1 } }
    trace.counters
    check(Marshal.dump(DataManager.make_save_contents)==world && rand(1000000)==expected,'profiling and counters do not alter game state or combat RNG')
    check(BS2Suite::Options.set('performance_trace',0),'trace can be disabled without disabling other diagnostics')
    BS2Suite::Options.instance_variable_set(:@data,nil)
    check(!trace.enabled?,'disabled trace preference survives a reload')
    count=trace.instance_variable_get(:@phases)[:qa_scope][0]
    check(trace.measure(:qa_scope) { :off }==:off && trace.instance_variable_get(:@phases)[:qa_scope][0]==count,'disabled profiling does no timing accumulation')
    before=trace.now;5000.times { trace.measure(:qa_noop) { nil } };off_ms=trace.now-before
    BS2Suite::Options.set('performance_trace',1);trace.reset_clock
    before=trace.now;5000.times { trace.measure(:qa_noop) { nil } };on_ms=trace.now-before
    log('profile_cost; off_5000_ms='+off_ms.to_s+'; on_5000_ms='+on_ms.to_s+'; extra_ms_per_scope='+((on_ms-off_ms)/5000.0).to_s)
    # Real Graphics calls, with a deliberate native frame-counter jump similar
    # to loading a save. Our frame intervals use call timestamps, not that ID.
    12.times { Graphics.update;Input.update }
    old=Graphics.frame_count;Graphics.frame_count=old+1000000
    12.times { Graphics.update;Input.update }
    groups=trace.instance_variable_get(:@frames).values
    check(groups.inject(0) { |n,row| n+row[0] }==23,'actual frame calls remain counted across a loaded frame-counter jump')
    check(groups.all? { |row| row[1]>0 && 1000.0*row[0]/row[1]<200 },'frame-counter jump cannot produce a fictitious enormous FPS')
    Graphics.frame_count=old+24
    check(trace.publish,'partial performance window can be emitted')
    check(trace.instance_variable_get(:@frames).empty? && trace.instance_variable_get(:@phases).empty?,'published accumulators are released instead of retaining history')
    trace.reset_clock
    3.times { Graphics.update;Input.update }
    Graphics.freeze;Graphics.transition(1)
    2.times { Graphics.update;Input.update }
    groups=trace.instance_variable_get(:@frames).values
    check(groups.inject(0) { |n,row| n+row[0] }==3,'known transition wait is separated from ordinary frame FPS')
    check(trace.instance_variable_get(:@phases).has_key?(:graphics_transition),'blocking transition time remains visible in its own phase')
    # Modal/focus metadata are part of the key, not mixed into gameplay FPS.
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene)
    scene.instance_variable_set(:@bs2080_effects,true)
    check(trace.context[2]=='@bs2080_effects','modal effects context is explicitly labelled')
    scene.instance_variable_set(:@bs2080_effects,nil)
    check(!trace.context[2],'closing modal returns to plain battle context')
    SceneManager.instance_variable_set(:@scene,Scene_Map.new)
    trace.reset_clock
    original_map=$game_map.map_id
    24.times do |id|
      $game_map.instance_variable_set(:@map_id,id)
      2.times { Graphics.update;Input.update }
    end
    $game_map.instance_variable_set(:@map_id,original_map)
    check(trace.instance_variable_get(:@frames).size<=16,'frame-context table has a fixed sixteen-group limit')
    100.times { |i| trace.record(('qa_phase_'+i.to_s).to_sym,100.0+i) }
    check(trace.instance_variable_get(:@phases).size<=32,'phase table has a fixed thirty-two-entry limit')
    check(trace.instance_variable_get(:@slow).size<=8,'slow-call examples have a fixed eight-entry limit')
    check(trace.percentile(Array.new(255,0)+[5],5,0.95)=='>=127.5','overflow timing bucket is reported as a lower bound instead of a false exact percentile')
    check(trace.counters[:native_resources][:private_bytes].to_i>0,'self-process numeric resource counters are recorded')
    # Real engine phases, no simulated frame sleep and no live-player window.
    scene=Scene_Base.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    trace.reset_clock
    330.times { scene.update_basic }
    check(trace.instance_variable_get(:@phases).has_key?(:windows),'native window update phase is observed')
    scene.terminate
    settings=BS2Suite::SettingsScene.new;SceneManager.instance_variable_set(:@scene,settings);settings.start
    commands=settings.instance_variable_get(:@commands)
    index=commands.instance_variable_get(:@list).index { |row| row[:symbol]==:performance_trace }
    check(!!index,'diagnostic settings expose the tracing switch')
    settings.terminate
    BS2Suite::Debug.close
    check(!trace.enabled?,'closing diagnostics also disables profiler accumulation')
    text=Dir.glob(File.join(directory,'events_*.jsonl')).map { |p| File.open(p,'rb') { |f| f.read } }.join
    check(text.include?('"type":"performance"'),'five-second and final partial performance records reach the existing local session')
    check(text.include?('"frame_groups"') && text.include?('"p95_upper_ms"') && text.include?('"mean_logic_ms"'),'frame distribution and between-frame logic timings are present')
    check(text.include?('"diagnostic_log"') && text.include?('"windows"'),'diagnostic overhead is measured alongside engine phases')
    check(!trace.instance_variable_get(:@failed),'diagnostic observer completed without disabling itself')
    File.open('profile_session.txt','w') { |f| f.puts directory }
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::Debug.close if defined?(BS2Suite::Debug)
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
