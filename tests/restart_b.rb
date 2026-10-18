# encoding: UTF-8
begin
 File.open('test_result.txt','w'){|f|f.puts 'cross-process persistence reader changed module set'}
 DataManager.init;DataManager.setup_new_game
 raise 'options lost' unless BS2Suite::Options.get('bgm')==37 && BS2Suite::Options.get('run_mode')==1
 raise 'keys lost' unless BS2Suite::Keys.token(:reference)=='CTRL+H'
 raise 'label lost' unless BS2Suite::Saves.label(0)=='Проверка перезапуска'
 raise 'profile lost' unless BS2Modules::Loadouts.get($game_party.members[0],2)[:name]=='Защита перезапуска'
 raise 'favorite lost' unless BS2QoL::Preferences.ids(:weapon)==[101]
 raise 'binding lost' unless BS2QoL::Bindings.data['quick']['C9']==[:item,1]
 raise 'disabled reference still loaded' if defined?(BS2QoL::ReferenceCard)
 class << DataManager;def make_filename(i);'BS2QA_restart.rvdata2';end;end
 raise 'save lost' unless DataManager.load_game(0) && $game_variables[750]==98765
 File.open('test_result.txt','a'){|f|f.puts 'result=PASS; checks=8'}
rescue Exception=>e;File.open('test_result.txt','a'){|f|f.puts 'result=FAIL; '+e.message};ensure;exit;end
