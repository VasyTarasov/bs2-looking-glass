# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
load 'BS2QA_exit_helpers.rb'
@checks=0
def check(value,label);raise label unless value;@checks+=1;ExitProbe.log('PASS '+label);end
begin
  File.open('test_result.txt','w') { |f| f.puts 'Adaptive priorities and native battle finish' }
  actor=setup_battle;p=BS2Suite::Priorities
  BS2Suite::Options.set('adaptive_priority',1);BS2Suite::Options.set('priority_window',20)
  p.instance_variable_set(:@history,[]);p.instance_variable_set(:@orders,{});p.instance_variable_set(:@messages,{});p.instance_variable_set(:@serial,1)
  original=[105,106,110].each_with_index.map { |id,i| {:id=>id,:digit=>i+1,:object=>$data_skills[id],:prefix=>'V',:group=>1} }
  base=actor.id.to_s+':';a=p.token('V',105);b=p.token('V',106);c=p.token('V',110)
  p.instance_variable_set(:@history,Array.new(3) { {base+a=>2,base+b=>2,base+c=>3} })
  p.reorder(actor,'V',1,original)
  check(p.apply(actor,'V',1,original).map { |r| r[:id] }==[110,105,106],'sustained usage still promotes within the original group')
  check(p.apply(actor,'V',1,original).map { |r| r[:digit] }==[1,2,3],'priority digits remain consecutive')
  check(!p.messages(actor,'V').empty?,'priority changes retain their notification')
  sorted=p.apply(actor,'V',1,original)
  p.instance_variable_set(:@history,Array.new(20) { {base+a=>5,base+b=>1,base+c=>1} })
  p.instance_variable_set(:@serial,2);p.reorder(actor,'V',1,sorted)
  check(p.apply(actor,'V',1,original).map { |r| r[:id] }==[110,105,106],'three-battle rest prevents immediate reversal')
  p.instance_variable_set(:@serial,4);p.reorder(actor,'V',1,sorted)
  check(p.apply(actor,'V',1,original).first[:id]==105,'a later sustained change can reorder again')
  order=p.apply(actor,'V',1,original).map { |r| r[:id] };p.persist
  p.instance_variable_set(:@history,nil);p.load
  check(p.apply(actor,'V',1,original).map { |r| r[:id] }==order,'priority order survives persistence')
  actor=setup_battle
  before=p.instance_variable_get(:@serial);history=p.instance_variable_get(:@history).size
  actor.learn_skill(932);actor.recover_all;$game_troop.members[0].hp=1
  actor.input.set_skill(932);actor.input.target_index=0;@scene.instance_variable_set(:@hzm_vxa_quickSkill_skill,$data_skills[932]);@scene.next_command;@scene.update
  check(ExitProbe.victories==1 && !$game_party.in_battle && SceneManager.scene.is_a?(Scene_Map),'native victory finalizes the battle once')
  check(p.instance_variable_get(:@serial)==before+1 && !p.instance_variable_get(:@open),'native battle end commits exactly one priority record')
  current=p.instance_variable_get(:@history).last
  check(current.values.any? { |n| n>0 },'native instant skill usage is retained after engine cleanup')
  p.instance_variable_set(:@history,nil);p.load
  check(p.instance_variable_get(:@serial)==before+1 && p.instance_variable_get(:@history).last==current,'completed-battle statistics survive reload')
  ExitProbe.log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  ExitProbe.log('result=FAIL; '+e.class.to_s+': '+e.message);ExitProbe.log(e.backtrace.join("\n"))
ensure
  @scene.terminate if @scene
  BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  SuiteCapture.close
end
end
