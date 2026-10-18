# encoding: UTF-8
load 'BS2QA_native_capture.rb'
def shot(name,scene)
  SceneManager.instance_variable_set(:@scene,scene);scene.start
  yield(scene) if block_given?
  Graphics.transition(0);3.times { Graphics.update }
  SuiteCapture.save('BS2QA_'+name+'.bmp')
  scene.terminate
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'native_presentation_suite' }
  DataManager.init;DataManager.setup_new_game;Window_MenuCommand.init_command_position
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(20,false);actor.clear_equipments;actor.name='Гримм'
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  shot('modules',BS2Suite::ModuleScene.new) { |s| s.instance_variable_get(:@commands).select(15) }
  shot('controls',BS2Suite::KeysScene.new) { |s| s.instance_variable_get(:@commands).select(20) }
  actor.skills.each { |skill| actor.forget_skill(skill.id) }
  [120,340,341].each { |id| actor.learn_skill(id) }
  shot('field',BS2Suite::FieldScene.new)
  [316,317].each { |id| $game_party.gain_item($data_items[id],1) }
  BS2Suite::Books.skills($data_items[316]).each { |skill| actor.learn_skill(skill.id) }
  shot('books',Scene_Item.new) do |s|
    item=s.instance_variable_get(:@item_window);category=s.instance_variable_get(:@category_window)
    type=$data_items[316].itype_id==2 ? :key_item : :item
    row=category.instance_variable_get(:@list).index { |r| r[:symbol]==type }
    category.select(row);category.deactivate;item.category=type;item.refresh;item.select(0);item.activate
  end
  class << DataManager;def make_filename(i);'BS2QA_preview_save'+i.to_s+'.rvdata2';end;end
  [0,3,99].each { |i| DataManager.save_game(i) }
  BS2Suite::Saves.rename(0,'Перед исследованием');BS2Suite::Saves.rename(3,'Перед битвой');BS2Suite::Saves.rename(99,'Запасной слот')
  shot('saves',Scene_Load.new) do |s|
    s.instance_variable_set(:@bs2_mode,1)
    s.instance_variable_get(:@bs2_files).set_rows(BS2Suite::Saves.rows(1),3)
    s.bs2suite_file_header
  end
  File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks=5; authentic_native_screens=true' }
rescue Exception=>e
  File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure;exit;end
