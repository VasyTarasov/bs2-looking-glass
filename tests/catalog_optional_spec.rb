# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Catalog optional module combinations '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.recover_all
    check(BS2Suite::CatalogV1.entries.size==2401,'complete catalog preloaded independently of field controls')
    check(defined?(BS2Suite::CatalogUI),'focused reference UI loads independently of field controls')
    w=Window_Help.new;w.set_item($data_armors[148])
    check(w.instance_variable_get(:@text)==$data_armors[148].description && w.height==w.fitting_height(2),'original help in optional profile')
    w.dispose
    if BS2Suite.enabled?('reference_cards')
      card=BS2QoL::PracticalCard.new($data_skills[95],actor,:ru)
      check(BS2Suite::CatalogUI.plain(card.sections.flatten.join).include?('ATK × 4'),'readable formula without requiring semantic forecast')
      state=BS2QoL::PracticalCard.new($data_states[28],nil,:en)
      check(state.sections.any? && state.sections.flatten.join !~ /[А-Яа-яЁё]/,'English state facts in optional profile')
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
