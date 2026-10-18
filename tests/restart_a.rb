# encoding: UTF-8
begin
 File.open('test_result.txt','w'){|f|f.puts 'cross-process persistence writer'}
 DataManager.init;DataManager.setup_new_game
 a=$game_party.members[0];a.change_class(1);a.change_level(30,false);a.name='Перезапуск';a.clear_equipments
 raise 'options failed' unless BS2Suite::Options.set('bgm',37) && BS2Suite::Options.set('run_mode',1)
 raise 'keys failed' unless BS2Suite::Keys.set(:reference,'CTRL+H')
 raise 'labels failed' unless BS2Suite::Saves.rename(0,'Проверка перезапуска')
 $game_party.gain_item($data_armors[217],1);a.change_equip(1,$data_armors[217]);raise 'loadout failed' unless BS2Modules::Loadouts.save(a,2,'Защита перезапуска')
 BS2QoL::Preferences.instance_variable_set(:@lists,{:weapon=>[101],:item=>[1],:skill=>[]});raise 'favorites failed' unless BS2QoL::Preferences.persist
 BS2QoL::Bindings.instance_variable_set(:@data,{});raise 'bindings failed' unless BS2QoL::Bindings.set('quick','C9',:item,1)
 class << DataManager;def make_filename(i);'BS2QA_restart.rvdata2';end;end
 $game_variables[750]=98765;raise 'save failed' unless DataManager.save_game(0)
 File.open('test_result.txt','a'){|f|f.puts 'result=PASS; checks=7'}
rescue Exception=>e;File.open('test_result.txt','a'){|f|f.puts 'result=FAIL; '+e.message};ensure;exit;end
