# encoding: UTF-8
actor=$game_actors[1];scene=SceneManager.scene;model=BS2Suite::Semantic
BS2Suite::Options.set('adaptive_priority',1);BS2Suite::Options.set('tempo_hint',1)
original=BS2Suite::Options.data.dup
BS2Suite::Options.instance_variable_set(:@data,nil)
check(BS2Suite::Options.data==original,'every registered option survives a cold preference reload')
BS2Suite::Options.set('adaptive_priority',0);BS2Suite::Options.set('tempo_hint',0)
model.sync(actor)
groups=model.groups(actor,'B');rows=groups.map { |g| model.rows(actor,'B',g[:number]) }.flatten
check(rows.none? { |r| r[:object].is_a?(RPG::Item) && $game_party.item_number(r[:object])==0 },'B omits all zero-stock items')
clock=$data_items[19];stock=$game_party.item_number(clock)
$game_party.lose_item(clock,stock)
check(groups.map { |g| model.rows(actor,'B',g[:number]) }.flatten.none? { |r| r[:id]==19 },'last item disappearing removes it from an existing B layout')
$game_party.gain_item(clock,1)
check(groups.map { |g| model.rows(actor,'B',g[:number]) }.flatten.any? { |r| r[:id]==19 },'reacquiring an item restores its authored B group membership')
skill=$data_skills.find { |s| s && s.cool_time && actor.skills.include?(s) }
skill ||= $data_skills.find { |s| s && s.cool_time }
actor.learn_skill(skill.id);actor.cool_time[skill.id]=3
check(BS2Suite::Availability.cooldown(actor,skill)==3,'cooldown label uses the actual remaining native counter')
check(BS2Suite::ShortNotes.for_row({:object=>skill},'M').include?('КД 3'),'short note exposes cooldown instead of generic unavailability')
popup=BS2Suite::PaletteWindow.new(actor,'M');popup.instance_variable_set(:@transition,[])
group=model.groups(actor,'M').find { |g| model.rows(actor,'M',g[:number]).any? { |r| r[:id]==skill.id } }
if group
  popup.set_group(group[:number]);line=popup.instance_variable_get(:@list).find { |r| r[:ext] && r[:ext][:id]==skill.id }
  check(line && line[:name].include?('КД 3'),'classic palette row explicitly shows cooldown')
  if defined?(BS2Suite::HDDisplay)
    popup.select(popup.entries.index { |r| r[:id]==skill.id })
    check(BS2Suite::HDDisplay.palette_rows(popup).any? { |r| r.include?('КД 3') },'HD palette also exposes native cooldown')
  end
end
popup.dispose;actor.cool_time[skill.id]=0
progress=$game_variables[11];gold=$game_party.gold
$game_variables[11]=7;$game_party.gain_gold(1234)
header=DataManager.make_save_header
check(header[:bs2_progress]==7 && header[:bs2_souls]==gold+1234 && header[:bs2_party].include?('прогресс 7') && header[:bs2_party].include?('души '+(gold+1234).to_s),'new save header places accurate progression and souls beside hero level')
$game_variables[11]=progress;$game_party.lose_gold(1234)
interpreter=Game_Interpreter.new;event=$data_common_events[234]
interpreter.setup(event.list);params=event.list.find { |c| c.code==102 }.parameters
message=Window_Message.new
[0,1,2].each do |choice|
  $game_message.clear;interpreter.setup_choices(params);selected=nil;$game_message.choice_proc=lambda { |n| selected=n }
  window=Window_ChoiceList.new(message);window.start;window.openness=255
  check(window.instance_variable_get(:@list)[choice][:name].start_with?((choice+1).to_s+'  '),'gear choice visibly numbers option '+(choice+1).to_s)
  tick;tick([49+choice]);window.process_handling
  check(selected==choice,'gear digit invokes the original choice handler '+(choice+1).to_s)
  window.dispose
end
$game_message.clear
interpreter.setup(event.list.dup);interpreter.setup_choices(params)
check(!$game_message.bs20992_gear_choices,'other identical-looking dialogs are not assigned Gear digit controls')
$game_message.clear;message.dispose;tick
