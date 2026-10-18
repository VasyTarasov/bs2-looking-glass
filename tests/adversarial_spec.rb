# encoding: UTF-8
module Audit
 @passed=0;@failed=0
 def self.log(s);File.open('test_result.txt','a'){|f|f.puts s};end
 def self.test(name)
  begin
   value=yield
   raise 'assertion false' unless value
   @passed+=1;log('PASS '+name)
  rescue StandardError=>e
   @failed+=1;log('FAIL '+name+' | '+e.class.to_s+': '+e.message)
  end
 end
 def self.finish;log('result='+(@failed==0 ? 'PASS' : 'FAIL')+'; checks='+(@passed+@failed).to_s+'; passed='+@passed.to_s+'; failed='+@failed.to_s);end
end
begin
 File.open('test_result.txt','w'){|f|f.puts 'adversarial native scenarios'}
 DataManager.init;DataManager.setup_new_game;Window_MenuCommand.init_command_position
 SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
 actor=$game_party.members[0];actor.change_class(1);actor.change_level(30,false);actor.clear_equipments
 [14,120].each{|id|actor.learn_skill(id)};actor.skill_seal.push(14,120)
 BS2QoL::Preferences.instance_variable_set(:@lists,{:weapon=>[],:item=>[],:skill=>[14,120]})
 Audit.test('HIDDEN combined combat list excludes hidden skill') do
  $game_party.on_battle_start
  w=Window_SkillList.new(0,0,640,300);w.actor=actor;w.bs2q_all_types=true;w.refresh
  result=!w.instance_variable_get(:@data).include?($data_skills[14]);w.dispose;$game_party.on_battle_end;result
 end
 Audit.test('HIDDEN favorites list excludes hidden skill') do
  w=Window_SkillList.new(0,0,640,300);w.actor=actor;w.bs2q_only=true;w.refresh
  result=!w.instance_variable_get(:@data).include?($data_skills[14]);w.dispose;result
 end
 Audit.test('HIDDEN field list excludes hidden skill') do
  w=BS2Suite::FieldList.new(0,0,640,300);w.actor=actor;w.refresh
  result=!w.instance_variable_get(:@data).include?($data_skills[120]);w.dispose;result
 end
 Audit.test('HIDDEN storage category retains hidden skill') do
  w=Window_SkillList.new(0,0,640,300);w.actor=actor;w.stype_id=AB_SSS2::STI;w.refresh
  result=w.instance_variable_get(:@data).include?($data_skills[14]);w.dispose;result
 end
 actor.skill_seal.clear
 [:options,:keys,:save_labels].each do |name|
  Audit.test('CONFIG invalid UTF8 '+name.to_s+' falls back safely') do
   path=BS2Suite::Store.path(name.to_s);File.open(path,'wb'){|f|f.write("\xff\xfe\n".force_encoding('ASCII-8BIT'))}
   case name
   when :options;BS2Suite::Options.instance_variable_set(:@data,nil);BS2Suite::Options.get('run_mode')==0
   when :keys;BS2Suite::Keys.instance_variable_set(:@data,nil);BS2Suite::Keys.token(:C)=='ENTER'
   else;BS2Suite::Saves.instance_variable_set(:@labels,nil);BS2Suite::Saves.labels=={}
   end
  end
  BS2Suite::Store.write(name.to_s,'')
 end
 BS2Suite::Options.instance_variable_set(:@data,nil);BS2Suite::Keys.instance_variable_set(:@data,nil);BS2Suite::Saves.instance_variable_set(:@labels,nil)
 Audit.test('CONFIG invalid UTF8 loadouts does not alter current gear') do
  raw=BS2Modules::Loadouts.parse("\xff\xfe".force_encoding('UTF-8'));raw=={}
 end
 Audit.test('CONFIG invalid shortcut records are ignored') do
  b=BS2QoL::Bindings.parse("bind=quick,C0,skill,14\nbind=quick,C1,skill,0\nbind=other,C1,item,1\nbind=quick,C2,skill,14\n")
  b=={'quick'=>{'C0'=>[:skill,14],'C2'=>[:skill,14]}}
 end
 Audit.test('CONFIG option public setter rejects invalid values') do
  before=BS2Suite::Options.get('run_mode');!BS2Suite::Options.set('run_mode',99) && BS2Suite::Options.get('run_mode')==before
 end
 BS2Suite::Options.instance_variable_set(:@data,nil);BS2Suite::Store.write('options','')
 class << DataManager;def make_filename(i);'NightAuditSave'+i.to_s+'.rvdata2';end;end
 [0,1,98,99].each do |i|
  Audit.test('SAVE boundary slot '+(i+1).to_s+' roundtrip') do
   $game_variables[701]=i;DataManager.save_game(i) && DataManager.load_game(i) && $game_variables[701]==i
  end
 end
 [-1,105,'1',nil].each{|i|Audit.test('SAVE rejects invalid index '+i.inspect){!DataManager.save_game(i)}}
 Audit.test('SAVE unicode label length and controls') do
  BS2Suite::Saves.rename(99,"\x00"+'Я'*60+"\n");BS2Suite::Saves.label(99)=='Я'*40
 end
 [42,'header',[],true].each_with_index do |head,n|
  Audit.test('SAVE malformed header '+n.to_s+' cannot crash list') do
   File.open(DataManager.make_filename(50),'wb'){|f|Marshal.dump(head,f);Marshal.dump({},f)}
   rows=BS2Suite::Saves.rows(0);w=BS2Suite::Saves::List.new;w.set_rows(rows,50);w.dispose;rows[50][:header].nil?
  end
 end
 File.delete(DataManager.make_filename(50))
 Audit.test('SAVE empty body rejected without replacing live world') do
  before=[$game_party,$game_system,$game_map,$game_actors]
  File.open(DataManager.make_filename(51),'wb'){|f|Marshal.dump(DataManager.make_save_header,f);Marshal.dump({},f)}
  ok=DataManager.load_game(51)
  !ok && before==[$game_party,$game_system,$game_map,$game_actors]
 end
 DataManager.setup_new_game;actor=$game_party.members[0];actor.change_class(1);actor.change_level(30,false)
 Audit.test('SAVE truncated body rejected without state change') do
  before=Marshal.dump(DataManager.make_save_contents)
  File.open(DataManager.make_filename(52),'wb'){|f|Marshal.dump(DataManager.make_save_header,f);f.write('broken')}
  !DataManager.load_game(52) && Marshal.dump(DataManager.make_save_contents)==before
 end
 Audit.test('SAVE replacement failure preserves previous file and counter') do
  DataManager.save_game(53);path=DataManager.make_filename(53);before=File.open(path,'rb'){|f|f.read};count=$game_system.save_count
  class << BS2Suite::Saves;alias audit_replace replace;def replace(*a);raise IOError,'injected replacement failure';end;end
  result=!DataManager.save_game(53) && File.open(path,'rb'){|f|f.read}==before && $game_system.save_count==count
  class << BS2Suite::Saves;alias replace audit_replace;end
  result
 end
 Audit.test('SAVE successful retry clears old error') do
  DataManager.save_game(53) && BS2Suite::Saves.error.nil?
 end
 Audit.test('SAVE temporary cleanup failure never escapes write') do
  class << File
   alias audit_delete delete
   def delete(p);raise Errno::EACCES,'injected cleanup lock' if p.to_s.end_with?('.bs2suite.tmp');audit_delete(p);end
  end
  class << BS2Suite::Saves;alias audit_replace2 replace;def replace(*a);raise IOError,'injected replace lock';end;end
  result=!DataManager.save_game(53)
  class << BS2Suite::Saves;alias replace audit_replace2;end
  class << File;alias delete audit_delete;end
  result
 end
 class << BS2Suite::Saves;alias replace audit_replace2 if method_defined?(:audit_replace2);end
 class << File;alias delete audit_delete if method_defined?(:audit_delete);end
 Audit.test('SAVE newest readable choice ignores corrupt slot') do
  File.open(DataManager.make_filename(54),'wb'){|f|f.write('corrupt')}
  File.utime(Time.now+100,Time.now+100,DataManager.make_filename(54))
  DataManager.latest_savefile_index!=54
 end
 Audit.test('LOADOUT missing copies refuses without gear or inventory mutation') do
  actor.clear_equipments;ring=actor.equip_slots.index(4);$game_party.gain_item($data_armors[137],1);actor.change_equip(ring,$data_armors[137]);BS2Modules::Loadouts.save(actor,1)
  set=BS2Modules.clone(BS2Modules::Loadouts.get(actor,1));other=actor.equip_slots.each_index.find{|i|i!=ring && actor.equip_slots[i]==4};set[:slots][other]=[4,137]
  before=Marshal.dump([actor,$game_party]);srand(441);r=rand;srand(441);v=BS2Modules::Loadouts.apply(actor,set)
  !v[:ok] && before==Marshal.dump([actor,$game_party]) && rand==r
 end
 Audit.test('LOADOUT preview repeated preserves RNG and all state') do
  set=BS2Modules::Loadouts.get(actor,1);before=Marshal.dump([actor,$game_party]);srand(123);r=rand;srand(123)
  30.times{BS2Modules::Loadouts.preview(actor,set)};rand==r && before==Marshal.dump([actor,$game_party])
 end
 Audit.test('BOOK temporary grant is still new, permanent mixed book partial') do
  item=RPG::Item.new;item.effects=[RPG::UsableItem::Effect.new(43,14,0,0),RPG::UsableItem::Effect.new(43,120,0,0)]
  actor.forget_skill(14);actor.forget_skill(120);before=BS2Suite::Books.status(item,actor);actor.learn_skill(14)
  before==:new && BS2Suite::Books.status(item,actor)==:partial
 end
 Audit.test('QUEUE twelve slots all represented by model without state or RNG changes') do
  actor.instance_variable_set(:@actions,Array.new(12){Game_Action.new(actor)});actor.actions.each_with_index{|a,i|a.set_skill(i.even? ? 14 : 2)}
  before=Marshal.dump(actor);srand(121);r=rand;srand(121);rows=BS2QoL::Model.queue(actor)
  rows.size==12 && Marshal.dump(actor)==before && rand==r
 end
 Audit.test('RUN restrictions remain active for forced movement and map dash ban') do
  BS2Suite::Options.set('run_mode',2);actor=$game_player
  actor.instance_variable_set(:@move_route_forcing,true);v=!actor.dash?;actor.instance_variable_set(:@move_route_forcing,false);v
 end
 Audit.test('SOUND all channels preserve gain limits and mute') do
  %w(bgm bgs me se).all?{|ch|[0,30,100].all?{|v|BS2Suite::Options.set(ch,v);BS2Suite::Sound.volume(ch,80)==(80*v/100.0).round}}
 end
 Audit.test('UI repeated 30 menu lifecycles do not leak live windows') do
  before=ObjectSpace.each_object(Window).count{|w|!w.disposed?}
  10.times do
   [BS2Suite::SettingsScene,BS2Suite::KeysScene,BS2Suite::ModuleScene].each do |klass|
    s=klass.new;SceneManager.instance_variable_set(:@scene,s);s.start;s.terminate
   end
  end
  ObjectSpace.each_object(Window).count{|w|!w.disposed?}==before
 end
 Audit.finish
rescue Exception=>e
 Audit.log('FATAL '+e.class.to_s+': '+e.message+"\n"+e.backtrace.join("\n"));Audit.finish
ensure;exit;end
