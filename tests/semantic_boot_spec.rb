# encoding: UTF-8
begin
  File.open('test_result.txt','w') { |f| f.puts 'feature_selection_boot_070' }
  DataManager.init;DataManager.setup_new_game
  Window_MenuCommand.init_command_position
  raise 'Version mismatch' unless BS2Suite::VERSION=='0.7.1-alpha'
  raise 'Names mismatch' unless BS2Suite::IDS.size==BS2Suite::NAMES.size
  raise 'Semantic module selection mismatch' unless !!defined?(BS2Suite::Semantic)==BS2Suite.enabled?('semantic_groups')
  if BS2Suite.enabled?('semantic_groups')
    actor=$game_party.members[0]
    BS2Suite::Semantic.sync(actor)
    raise 'Reference should remain optional' if BS2Suite.enabled?('reference_cards')!=!!defined?(BS2Suite::SequenceCard)
    list=Window_MenuCommand.new
    has_favorites=list.instance_variable_get(:@list).any? { |r| r[:symbol]==:bs2q_favorites }
    raise 'Favorites flag ignored' if has_favorites!=BS2Suite.enabled?('combat_shortcuts')
    list.dispose
  end
  File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks=5; selected='+BS2Suite::IDS.select { |id| BS2Suite.enabled?(id) }.join(',') }
rescue Exception=>e
  File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure;exit;end
