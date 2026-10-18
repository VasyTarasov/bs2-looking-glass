# encoding: UTF-8
@checks=0
def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
def check(v,s);raise 'Assertion: '+s unless v;@checks+=1;log('PASS '+s);end
class SuiteRaw
  attr_accessor :keys,:focus
  def initialize;@keys=[];@focus=true;end
  def focused?;@focus;end
  def down;@keys.dup;end
end
def step(keys=[])
  @raw.keys=keys;Graphics.update;Input.update
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'modular_suite; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game;Window_MenuCommand.init_command_position
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(20,false);actor.clear_equipments
  actor.name='QA';actor.recover_all
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  check(BS2Suite::VERSION=='0.996-dev','suite loads on native Ruby 1.9')
  check(BS2Suite::IDS.size==22,'twenty-two independently selected features')
  defs={'effects'=>'BS2Modules::Effects','loadouts'=>'BS2Modules::Loadouts','reference_cards'=>'BS2QoL::ReferenceCard','learned_books'=>'BS2Suite::Books','field_skills'=>'BS2Suite::FieldScene','saves'=>'BS2Suite::Saves','scaling'=>'BS2Suite::Scaling','sound'=>'BS2Suite::Sound','debug'=>'BS2Suite::Debug'}
  defs.each { |id,name| check(!!eval('defined?('+name+')')==BS2Suite.enabled?(id),'disabled feature code absent: '+id) }
  menu=Window_MenuCommand.new
  symbols=menu.instance_variable_get(:@list).map { |r| r[:symbol] }
  check(symbols.include?(:bs2q_favorites)==BS2Suite.enabled?('combat_shortcuts'),'favorites menu optional')
  check(symbols.include?(:bs2modules_effects)==BS2Suite.enabled?('effects'),'effects menu optional')
  check(symbols.include?(:bs2modules_loadouts)==BS2Suite.enabled?('loadouts'),'loadouts menu optional')
  check(menu.height<=Graphics.height-72,'long combined menu fits screen and scrolls');menu.dispose
  BS2QoL::Keyboard.backend=@raw=SuiteRaw.new;BS2QoL::Keyboard.reset;step
  step([0x76]);check(BS2QoL::Keyboard.first=='F7','default reference raw key works')
  step([0x76]);check(!BS2QoL::Keyboard.first,'held mod key does not retrigger')
  @raw.focus=false;step([0x76]);@raw.focus=true;step([0x76])
  check(!BS2QoL::Keyboard.first,'refocus held key suppressed');step
  if BS2Suite.enabled?('controls')
    keys=BS2Suite::Keys
    check(keys.set(:reference,'CTRL+H'),'mod key can be rebound')
    step([0x76]);check(!BS2QoL::Keyboard.first,'old key disabled after remap');step
    step([17,72]);check(BS2QoL::Keyboard.first=='F7','new chord enters real reference handler namespace');step
    check(!keys.set(:reference,'F6'),'duplicate global key rejected')
    check(!keys.set(:reference,'CTRL+1') && !keys.set(:reference,'CTRL'),'quick slots and bare modifiers cannot steal mod actions')
    check(keys.set(:C,'T'),'confirm can be rebound')
    step([84]);check(Input.trigger?(:C) && Input.press?(:C),'logical confirm reads remapped physical key')
    step([84]);check(!Input.trigger?(:C),'confirm hold only triggers once');step
    step([38,39]);check(Input.dir8==9,'remapped input preserves diagonal movement');step
    check(BS2Suite::Store.write('keys',''),'reset keyboard settings written');keys.instance_variable_set(:@data,nil)
    BS2Suite::Store.write('keys',"reference=ENTER\n")
    keys.instance_variable_set(:@data,nil)
    check(keys.token(:reference)=='F7','conflicting manually edited configuration falls back to usable defaults')
    BS2Suite::Store.write('keys','');keys.instance_variable_set(:@data,nil)
    scene=BS2Suite::KeysScene.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    check(scene.instance_variable_get(:@commands).item_max==BS2Suite::Keys::DEFAULT.size+1,'control screen includes every configurable action and reset');scene.terminate
  end
  if BS2Suite.enabled?('learned_books')
    book=$data_items.compact.find { |i| !BS2Suite::Books.skills(i).empty? }
    check(!!book,'real book exists in active database')
    skills=BS2Suite::Books.skills(book);skills.each { |s| actor.forget_skill(s.id) }
    check(BS2Suite::Books.status(book,actor)==:new,'unlearned book marked new')
    granted=RPG::State.new;granted.id=267;granted.features=[RPG::BaseItem::Feature.new(43,skills[0].id,0)];$data_states[267]=granted
    actor.add_new_state(267)
    check(actor.skills.include?(skills[0]) && BS2Suite::Books.status(book,actor)==:new,'temporary granted skill does not mark a book learned')
    actor.remove_state(267)
    skills.each { |s| actor.learn_skill(s.id) }
    check(BS2Suite::Books.status(book,actor)==:learned,'permanently learned book marked complete')
    check(BS2Suite::Books.status($data_items[1],actor).nil?,'ordinary flask is not a learned book')
    w=Window_ItemList.new(0,0,640,400);$game_party.gain_item(book,1);w.category=:item;w.refresh
    check(w.instance_variable_get(:@data).include?(book),'book marker preserves ordinary inventory');w.dispose
  end
  if BS2Suite.enabled?('field_skills')
    learned=$data_skills.compact.select { |s| [0,2].include?(s.occasion) && !s.name.empty? }.take(20)
    learned.each { |s| actor.learn_skill(s.id) }
    w=BS2Suite::FieldList.new(0,0,640,400);w.actor=actor;w.refresh
    expected=actor.skills.select { |s| [0,2].include?(s.occasion) }
    check(w.instance_variable_get(:@data).sort_by { |s| s.id }==expected.sort_by { |s| s.id },'field list uses real occasion and owned skills')
    if BS2Suite.enabled?('combat_shortcuts')
      BS2QoL::Preferences.instance_variable_set(:@lists,{:weapon=>[],:item=>[],:skill=>[14,120]})
      w.bs2q_only=true;w.refresh
      check(w.instance_variable_get(:@data).all? { |s| [0,2].include?(s.occasion) && actor.skills.include?(s) },'field favorites cannot reintroduce battle-only or missing skills')
    end
    w.dispose
    scene=BS2Suite::FieldScene.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    check(scene.instance_variable_get(:@item_window).active && !scene.instance_variable_get(:@command_window).active,'field screen opens directly to usable skills')
    actor.learn_skill(120);actor.mp=actor.mmp
    list=scene.instance_variable_get(:@item_window);list.refresh
    list.select(list.instance_variable_get(:@data).index($data_skills[120]))
    before=actor.mp;list.process_ok
    target=scene.instance_variable_get(:@actor_window);target.process_ok if target.active
    check(actor.mp==before-actor.skill_mp_cost($data_skills[120]),'field skill pays real native MP cost exactly once')
    check($game_temp.common_event_reserved? && SceneManager.scene.is_a?(Scene_Map),'field skill preserves native common-event handoff')
    $game_temp.clear_common_event
    scene.terminate
  end
  if BS2Suite.enabled?('saves')
    # QA directory only. None of these filenames are the user's saves.
    BS2Suite::Saves.instance_variable_set(:@labels,{})
    check(DataManager.savefile_max==105,'one hundred manual and five reserved quick slots')
    check(BS2Suite::Saves.rename(0,'Проверка / QA'),'Cyrillic save label persists')
    check(DataManager.save_game(0),'native-format save writes atomically')
    original=File.open(DataManager.make_filename(0),'rb') { |f| f.read }
    count=$game_system.save_count
    class << BS2Suite::Saves
      alias qa_replace replace
      def replace(*args);raise IOError,'simulated disk failure';end
    end
    check(!DataManager.save_game(0),'simulated replacement failure is reported')
    check(File.open(DataManager.make_filename(0),'rb') { |f| f.read }==original,'failed save preserves previous bytes')
    check($game_system.save_count==count,'failed save restores native save counter')
    class << BS2Suite::Saves;alias replace qa_replace;end
    $game_variables[200]=1234
    check(DataManager.save_game(99),'slot one hundred writes')
    check(DataManager.load_game(0) && $game_variables[200]!=1234,'native load restores earlier complete save')
    rows=BS2Suite::Saves.rows(1)
    check(rows.take(2).all? { |r| [0,99].include?(r[:id]) },'time sorting places existing saves first')
    check(BS2Suite::Saves.rows(2)[0][:id]==0,'description sorting uses labels')
    scene=Scene_Save.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    check(scene.instance_variable_get(:@bs2_files).item_max==105,'save UI contains manual and quick history slots');scene.terminate
    edit=BS2Suite::TextEdit.new(Struct.new(:name).new('Подпись'),40)
    check(edit.width<=640 && edit.contents_width>=480,'forty-character description editor fits');edit.dispose
    File.rename(DataManager.make_filename(0),'BS2QA_suite_save.rvdata2')
    File.rename(DataManager.make_filename(99),'BS2QA_suite_save100.rvdata2')
  end
  if BS2Suite.enabled?('scaling')
    Graphics.update
    check(BS2Suite::Scaling.window!=0,'scaler identifies only owned test window')
    check(BS2Suite::Scaling.apply(1),'native owned window resize succeeds')
    handle=BS2Suite::Scaling.window;rect=[0,0,0,0].pack('l4')
    Win32API.new('user32','GetClientRect',['L','P'],'I').call(handle,rect)
    check(rect.unpack('l4')[2,2]==[640,480],'one-times client area is exact without changing game canvas')
    check(Graphics.width==640 && Graphics.height==480,'logical game resolution unchanged')
    if BS2Suite::Scaling.apply(2)
      image=Bitmap.new(640,480);colors=[[200,30,40],[20,180,40],[180,120,20],[30,50,200]]
      colors.each_with_index { |c,i| image.fill_rect((i%2)*320,(i/2)*240,320,240,Color.new(*c)) }
      sprite=Sprite.new;sprite.bitmap=image;sprite.z=9999
      Graphics.transition(0) # Earlier manually terminated scene fixtures froze the screen.
      3.times { Graphics.update }
      output=BS2Suite::Scaling.output_window
      dc=Win32API.new('user32','GetDC',['L'],'L').call(output)
      actual=4.times.map do |i|
        packed=Win32API.new('gdi32','GetPixel',['L','I','I'],'L').call(dc,(i%2)*640+320,(i/2)*480+240)
        [packed&255,(packed>>8)&255,(packed>>16)&255]
      end
      Win32API.new('user32','ReleaseDC',['L','L'],'I').call(output,dc)
      Win32API.new('user32','GetClientRect',['L','P'],'I').call(output,rect)
      log('scaling_pixels='+actual.inspect+' client='+rect.unpack('l4').inspect)
      check(actual==colors,'two-times scaling stretches real rendered content across entire client area')
      check(Win32API.new('user32','GetActiveWindow',[],'L').call==handle,'scaled view never takes focus from the native game window')
      point=[960,720].pack('l2');Win32API.new('user32','ClientToScreen',['L','P'],'I').call(handle,point)
      xy=point.unpack('l2');under=Win32API.new('user32','WindowFromPoint',['I','I'],'L').call(*xy)
      check(under==handle,'mouse hit testing passes through enlarged view to the same game window')
      sprite.dispose;image.dispose;BS2Suite::Scaling.apply(1)
    end
  end
  if BS2Suite.enabled?('run_toggle')
    check(BS2Suite::Options.set('run_mode',1),'toggle run option persists')
    before=BS2Suite::Run.active?;BS2Suite::Run.toggle
    check(BS2Suite::Run.active?!=before,'run latch toggles without game save fields')
    BS2Suite::Options.set('run_mode',0)
  end
  if BS2Suite.enabled?('sound')
    BS2Suite::Options.set('se',30)
    check(BS2Suite::Sound.volume('se',80)==24,'volume scales actual requested gain')
    BS2Suite::Options.set('se',0);check(BS2Suite::Sound.volume('se',80)==0,'mute maps to zero gain')
    BS2Suite::Options.set('se',100)
  end
  if BS2Suite.enabled?('debug')
    BS2Suite::Debug.start
    $game_switches[199]=true;$game_variables[199]=456
    step;step([0x78]);step
    BS2Suite::Debug.emit('user_note',{:text=>'Проверка «журнала»\nстрока',:float=>1.5})
    directory=BS2Suite::Debug.directory;BS2Suite::Debug.close
    check(File.file?(File.join(directory,'session.closed')),'clean debug session closes marker')
    data=Dir.glob(File.join(directory,'*.jsonl')).map { |p| File.open(p,'rb') { |f| f.read } }.join
    check(data.include?('variable') && data.include?('user_note'),'debug captures actual state setters and notes')
    check(data.include?('bookmark') && data.include?('keys'),'debug bookmark uses real raw input even without scene updates')
    BS2Suite::Debug.start;other=BS2Suite::Debug.directory;BS2Suite::Debug.close
    check(other!=directory && File.directory?(directory),'new debug sessions preserve prior history')
    class << SceneManager
      alias qa_debug_real_run bs2suite_debug_run
      def bs2suite_debug_run;raise 'QA intentional exception';end
    end
    caught=false
    begin;SceneManager.run;rescue RuntimeError=>e;caught=e.message=='QA intentional exception';end
    error_dir=BS2Suite::Debug.directory
    class << SceneManager;alias bs2suite_debug_run qa_debug_real_run;end
    check(caught && File.file?(File.join(error_dir,'session.failed')),'uncaught error is journaled then propagated without replacing native failure')
    data=Dir.glob(File.join(error_dir,'*.jsonl')).map { |p| File.open(p,'rb') { |f| f.read } }.join
    check(data.include?('QA intentional exception') && data.include?('backtrace'),'exception report contains message and native call stack')
    dirs=[]
    24.times { BS2Suite::Debug.start;dirs << BS2Suite::Debug.directory;BS2Suite::Debug.close }
    check(dirs.uniq.size==24 && File.directory?(directory),'many sessions accumulate without eviction or trial limit')
    %w(BS2QA_boot BS2QA_boot/Mods BS2QA_boot/Mods/BS2Suite BS2QA_boot/BS2Suite).each { |p| Dir.mkdir(p) unless File.directory?(p) }
    File.open('BS2QA_boot/Mods/BS2Suite/main.rb','wb') { |f| f.write("raise 'QA bootstrap failure'\n") }
    File.open('BS2QA_boot/BS2Suite/modules.ini','wb') { |f| f.write("debug=1\n") }
    original=Dir.pwd;caught=false
    begin
      Dir.chdir('BS2QA_boot')
      load File.join(original,'BS2QA_bootstrap.rb')
    rescue RuntimeError=>e;caught=e.message=='QA bootstrap failure'
    ensure;Dir.chdir(original);end
    check(caught && File.file?('BS2QA_boot/BS2Suite/debug/bootstrap.log'),'bootstrap failure is logged before normal diagnostic module can load')
  end
  BattleManager.setup(3,true,false);$game_party.on_battle_start
  actor=$game_party.members[0];actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
  scene.start_actor_command_selection
  check(!!scene.instance_variable_get(:@bs2q_plan)==BS2Suite.enabled?('action_queue'),'battle queue window exists only when selected')
  check(!!scene.instance_variable_get(:@bs2q_footer)==(BS2Suite.enabled?('combat_shortcuts') || BS2Suite.enabled?('semantic_groups') || BS2Suite.enabled?('legacy_shortcuts')),'battle shortcut footer follows the selected input modules')
  commands=scene.instance_variable_get(:@actor_command_window)
  index=commands.instance_variable_get(:@list).index { |r| r[:symbol]==:skill }
  if index
    commands.select(index);scene.command_skill
    check(scene.instance_variable_get(:@skill_window).active,'native skill command works without optional sibling modules')
  end
  scene.terminate;$game_party.on_battle_end
  scene=BS2Suite::SettingsScene.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
  check(scene.instance_variable_get(:@commands).item_max>1,'shared settings work for selected combination');scene.terminate
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure;exit;end
