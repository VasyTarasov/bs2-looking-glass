# encoding: UTF-8
begin
 File.open('test_result.txt','w'){|f|f.puts 'unmodified engine reader for candidate save'}
 DataManager.init;DataManager.setup_new_game
 class << DataManager;def make_filename(i);'BS2QA_restart.rvdata2';end;end
 raise 'original engine load failed' unless DataManager.load_game(0)
 raise 'saved state lost' unless $game_variables[750]==98765 && $game_party.members[0].name=='Перезапуск'
 raise 'custom class dependency' if defined?(BS2Suite)
 $game_system.on_after_load
 File.open('test_result.txt','a'){|f|f.puts 'result=PASS; checks=4'}
rescue Exception=>e;File.open('test_result.txt','a'){|f|f.puts 'result=FAIL; '+e.message};ensure;exit;end
