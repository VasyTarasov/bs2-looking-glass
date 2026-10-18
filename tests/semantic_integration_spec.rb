# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
def check(value,name);raise name unless value;@checks+=1;log('PASS '+name);end
class SemanticIntegrationKeys
  attr_accessor :keys
  def initialize;@keys=[];end
  def down;@keys.dup;end
  def focused?;true;end
end
def frame(keys=[])
  @raw.keys=keys;Graphics.update;Input.update
  return unless @scene
  popup=BS2Suite::Palette.current(@scene)
  if popup;popup.update;BS2Suite::Palette.update(@scene)
  elsif BS2QoL::Reference.active?(@scene);BS2QoL::Reference.update(@scene)
  else;@scene.instance_variable_get(:@actor_command_window).update;end
end
def key(value);frame;frame([value]);end
def sequence(text);text.each_byte { |value| key(value) };end
def battle(actor)
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  @scene.instance_variable_get(:@actor_command_window).openness=255
end
def finish
  BS2Suite::Palette.close(@scene) if BS2Suite::Palette.current(@scene)
  BS2QoL::Reference.close(@scene) if BS2QoL::Reference.active?(@scene)
  @scene.terminate;$game_party.on_battle_end;@scene=nil
end
def capture(name)
  Graphics.transition(0);@raw.keys=[]
  12.times { @scene.update }
  SuiteCapture.save('BS2QA_070_'+name+'.bmp')
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'semantic_integration_070' }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  $game_party.items.each { |item| $game_party.lose_item(item,999) }
  actor.skills.each { |s| actor.forget_skill(s.id) }
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons
  model.instance_variable_set(:@customs,{})
  [102,256,157,362].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all;model.sync(actor)
  before=model.rows(actor,'V',1).map { |r| [r[:id],r[:digit]] }
  [277,178].each { |id| $game_party.gain_item($data_weapons[id],1) };model.sync(actor)
  check(model.groups(actor,'V').size==1 && model.rows(actor,'V',1).size==9,'nine techniques still occupy one compact group')
  $game_party.gain_item($data_weapons[145],1);model.sync(actor)
  check(model.rows(actor,'V',1).size==10,'tenth technique uses the remaining digit')
  $game_party.gain_item($data_weapons[211],1);model.sync(actor)
  groups=model.groups(actor,'V')
  check(groups.size==2,'twelve techniques split into two meaningful groups')
  rows=groups.map { |g| model.rows(actor,'V',g[:number]) }.flatten
  check(rows.size==12 && groups.all? { |g| model.rows(actor,'V',g[:number]).size<=10 },'split loses no technique and respects capacity')
  check(groups.all? { |g| r=model.rows(actor,'V',g[:number]);r.map { |e| e[:digit] }==BS2Suite::Semantic::DIGITS[0,r.size].chars.map { |d| d.to_i } },'inner digits are consecutive after the split')
  check(model.pending_moves(actor,'V').any?,'moved full addresses are recorded for the transition')
  @raw=SemanticIntegrationKeys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;frame
  BS2Suite::Options.set('knowledge_threshold',0)
  battle(actor)
  sequence('V')
  check(BS2Suite::Palette.current(@scene).transition.any?,'split explanation is shown before the changed palette')
  current_actions=actor.actions.map { |a| a.item && a.item.id }
  key(49);key(50)
  check(actor.actions.map { |a| a.item && a.item.id }==current_actions,'old memorised digits cannot execute during a transition')
  capture('split')
  key(13)
  check(BS2Suite::Palette.current(@scene).transition.empty?,'Enter opens the acknowledged layout')
  ap=$game_party.members.map { |a| a.instance_variable_get(:@ap) }
  @raw.keys=[];12.times { @scene.update }
  check($game_party.members.map { |a| a.instance_variable_get(:@ap) }==ap,'native battle update pauses while the palette is open')
  key(27)
  model.acknowledge(actor,'N');sequence('N2');capture('execution_weapons');key(27)
  sequence('V1');check(BS2Suite::Palette.current(@scene).group==1,'technique digits still enter a group after returning from N');capture('techniques');key(27)
  finish
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) };$game_party.gain_item($data_weapons[102],1)
  actor.change_equip(0,$data_weapons[102]);actor.recover_all;model.sync(actor)
  check(model.groups(actor,'V').size==2,'loss of sources does not collapse learned group structure')
  check(model.groups(actor,'V').map { |g| model.rows(actor,'V',g[:number]) }.flatten.any? { |r| !r[:present] },'missing known sources remain unavailable in their slots')
  # Binding failure must not equip the source first.
  $game_party.gain_item($data_weapons[157],1);battle(actor)
  actor.mp=0;old=actor.equips[0];old_states=actor.instance_variable_get(:@states).dup
  @scene.bs2v2_cast([:skill,110,157],:commands)
  check(actor.equips[0]==old && actor.instance_variable_get(:@states)==old_states,'unaffordable source cast leaves equipment and states unchanged')
  actor.recover_all;finish
  # Preserve previously configured controls when adding the new prefixes.
  BS2Suite::Store.write('keys',"X=V\n")
  BS2Suite::Keys.instance_variable_set(:@data,nil)
  check(BS2Suite::Keys.data[:X]=='V' && BS2Suite::Keys.data[:palette_v]!='V','new prefix defaults preserve existing user controls')
  BS2Suite::Store.write('keys','');BS2Suite::Keys.instance_variable_set(:@data,nil)
  # Real execution of both actions: the swap is not only a preparation flag.
  $game_party.gain_item($data_weapons[133],1);actor.learn_skill(14);battle(actor)
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  enemy=$game_troop.alive_members[0];enemy.add_param(0,500000);enemy.recover_all
  first=Game_Action.new(actor);first.set_skill(14);first.target_index=enemy.index
  last=Game_Action.new(actor);last.set_skill(14);last.target_index=enemy.index
  actor.instance_variable_set(:@actions,[first,last]);direct.select(actor,$data_weapons[133]);direct.arm(actor)
  $semantic_native_uses=[]
  class Game_Battler
    alias semantic_native_use_item use_item
    def use_item(item)
      $semantic_native_uses<<[equips[0].id,item.id] if actor?
      semantic_native_use_item(item)
    end
  end
  mp=actor.mp
  @scene.instance_variable_set(:@subject,actor)
  first.prepare;check(first.valid?,'first native action is usable');@scene.execute_action;actor.remove_current_action
  last.prepare;check(last.valid?,'last native action is usable');@scene.execute_action;actor.remove_current_action
  check($semantic_native_uses==[[102,14],[133,14]],'native use_item executes only the final action with the chosen weapon')
  check(actor.mp==mp-12 && actor.actions.empty?,'native execution pays two real costs and consumes exactly two slots')
  check(enemy.hp<enemy.mhp,'native execution actually affects the enemy')
  finish
  check(!direct.selected_id(actor),'execution intent is cleared at battle end')
  # Synthetic write failure preserves the previous in-memory definition.
  custom=model.clone_profile(actor);check(!!custom,'custom profile available for persistence failure check')
  old=model.customs[custom]['entries'].map { |e| e.dup }
  module BS2Suite::Store
    class << self
      alias semantic_real_write write
      def write(*args);false;end
    end
  end
  check(!model.assign(actor,'V',1,0,$data_skills[110],$data_weapons[157]),'failed settings write is reported')
  check(model.customs[custom]['entries']==old,'failed settings write preserves old bindings')
  module BS2Suite::Store;class << self;alias write semantic_real_write;end;end
  # Authentic native menu, editor and card screens.
  unless ENV['BS2_QA_NO_MENU']=='1'
  profile=BS2Suite::ProfileScene.new;SceneManager.instance_variable_set(:@scene,profile);profile.start
  Graphics.transition(0);3.times { Graphics.update };SuiteCapture.save('BS2QA_070_profiles.bmp');profile.terminate
  editor=BS2Suite::ProfileEditorScene.new;SceneManager.instance_variable_set(:@scene,editor);editor.start
  Graphics.transition(0);3.times { Graphics.update };SuiteCapture.save('BS2QA_070_editor.bmp');editor.terminate
  profile=nil;editor=nil
  SceneManager.exit
  Graphics.transition(0);Graphics.update
  GC.start;Graphics.update
  check(ObjectSpace.each_object(Window).all? { |window| window.disposed? },'native palette profile and editor windows are disposed after closing')
  end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SceneManager.exit
  Graphics.transition(0)
  SuiteCapture.close
  5.times { Graphics.update }
end
end
