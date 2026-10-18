# encoding: UTF-8
rgss_main do
  checks=0
  begin
    expected=File.file?('preferences-pass.txt') ? [0,0,30,1] : [1,1,10,0]
    keys=%w(tempo_hint adaptive_priority priority_window navigation_aliases)
    raise 'bootstrap dropped saved option values' unless keys.map { |k| BS2Suite::Options.get(k) }==expected
    checks+=4
    next_values=expected[0]==1 ? [0,0,30,1] : [1,1,20,1]
    keys.zip(next_values).each { |k,v| raise 'option write failed' unless BS2Suite::Options.set(k,v);checks+=1 }
    BS2Suite::Options.instance_variable_set(:@data,nil)
    raise 'cold option reload changed values' unless keys.map { |k| BS2Suite::Options.get(k) }==next_values
    checks+=4
    DataManager.init;DataManager.setup_new_game
    BattleManager.setup(1,true,false)
    raise 'battle setup changed preferences' unless keys.map { |k| BS2Suite::Options.get(k) }==next_values
    checks+=4
    File.open('preferences-pass.txt','w') { |f| f.puts 'second process expects persisted values' }
    File.open('test_result.txt','w') { |f| f.puts 'result=PASS; checks='+checks.to_s }
  rescue Exception=>e
    File.open('test_result.txt','w') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
