# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(value,text);raise text unless value;@checks+=1;log('PASS '+text);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Basic conveniences and independent book-marker settings' }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader
    check(BS2Suite.enabled?('basic_qol') && !BS2Suite.enabled?('semantic_groups'),'only the basic convenience group is selected')
    check(defined?(BS2Suite::Books) && defined?(BS2Suite::Sound),'book and sound services belong to the basic choice')
    item=$data_items.compact.find { |object| !BS2Suite::Books.skills(object).empty? }
    check(!!item,'native database contains a learnable book')
    initial=BS2Suite::Books.status(item,actor);check(!initial.nil?,'book status is visible by default')
    check(BS2Suite::Options.set('learned_book_marks',0),'book markers can be disabled independently')
    check(BS2Suite::Books.status(item,actor).nil? && BS2Suite::Books.description(item,actor).empty?,'disabled markers and help text are absent')
    BS2Suite::Options.instance_variable_set(:@data,nil)
    check(BS2Suite::Options.get('learned_book_marks')==0,'book-marker preference survives reload')
    check(BS2Suite.enabled?('controls') && BS2Suite.enabled?('sound') && BS2Suite.enabled?('run_toggle'),'other basic services remain available')
    check(BS2Suite::Options.set('learned_book_marks',1) && BS2Suite::Books.status(item,actor)==initial,'markers can be restored without changing learned skills')
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  end
end
