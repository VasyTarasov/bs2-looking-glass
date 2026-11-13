# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
load 'BS2QA_exit_helpers.rb'
@checks=0
def check(value,label);raise label unless value;@checks+=1;ExitProbe.log('PASS '+label);end
begin
  File.open('test_result.txt','w') { |f| f.puts 'Battle exit lifecycle edges' }
  actor=setup_battle
  # Unexpected errors from native execution must reach normal error handling,
  # rather than being returned as a harmless macro-validation rejection.
  @scene.singleton_class.class_eval do
    alias qa_edge_execute bs20997_macro_execute
    def bs20997_macro_execute;raise 'controlled native execution error';end
  end
  original_actions=actor.actions;observed=nil
  set={'name'=>'QA engine fault','key'=>1,'rows'=>[row('item',5003)]}
  begin;BS2Suite::Macros.commit(@scene,actor,set,0);rescue RuntimeError=>e;observed=e.message;end
  check(observed=='controlled native execution error','engine exception is not hidden by macro validation')
  check(actor.actions.equal?(original_actions) && !HZM_VXA::QuickSkill.quickSkill?,'engine exception restores active-battle action context')
  check($game_party.item_number($data_items[5003])==5,'pre-execution failure does not consume an item')
  @scene.singleton_class.class_eval { alias bs20997_macro_execute qa_edge_execute }
  actor=setup_battle
  # A native common event aborts a battle while still inside an instant action.
  event=RPG::CommonEvent.new;event.id=5000;event.list=[RPG::EventCommand.new(355,0,['BattleManager.abort']),RPG::EventCommand.new(0,0,[])];$data_common_events[5000]=event
  item=$data_items[5003];item.effects=[RPG::UsableItem::Effect.new(44,5000,0,0)]
  actor.input.set_item(item.id);actor.input.target_index=actor.index;@scene.instance_variable_set(:@hzm_vxa_quickSkill_skill,item)
  @scene.next_command;@scene.update
  check(ExitProbe.victories==0 && ExitProbe.ends==1 && SceneManager.scene.is_a?(Scene_Map),'instant common-event abort returns once without victory')
  check(actor.actions.empty? && !HZM_VXA::QuickSkill.quickSkill?,'abort leaves no actions or QuickSkill latch')
  actor=setup_battle
  # Controlled event callback: preserve a new generation's queue. Do not run
  # BattleManager.setup from a native interpreter command: the engine clears
  # that interpreter's running list, which is unsupported by the base game.
  @scene.singleton_class.class_eval do
    alias qa_edge_event bs2flow_process_event
    def bs2flow_process_event
      BattleManager.setup(79,true,false)
      actor=$game_party.leader;actor.instance_variable_set(:@actions,[Game_Action.new(actor)])
      actor.actions[0].set_skill(5004);SceneManager.goto(Scene_Battle)
    end
  end
  item=$data_items[5003]
  before=BS2Suite::BattleFlow.generation
  actor.input.set_item(item.id);actor.input.target_index=actor.index;@scene.instance_variable_set(:@hzm_vxa_quickSkill_skill,item)
  @scene.next_command
  check(BS2Suite::BattleFlow.generation==before+1 && SceneManager.scene.is_a?(Scene_Battle) && !SceneManager.scene.equal?(@scene),'common event transfers to a new battle generation')
  check(actor.actions.size==1 && actor.actions[0].item.id==5004 && !HZM_VXA::QuickSkill.quickSkill?,'new battle queue survives old quick-action cleanup')
  @scene.singleton_class.class_eval { alias bs2flow_process_event qa_edge_event }
  actor=setup_battle
  # Normal nonlethal instant use still resumes exactly the same free slot.
  first=actor.actions[0];slot=actor.input
  actor.input.set_item(5003);actor.input.target_index=actor.index;@scene.instance_variable_set(:@hzm_vxa_quickSkill_skill,$data_items[5003])
  @scene.next_command
  check(actor.actions.size==2 && actor.actions[0].equal?(first) && actor.input.equal?(slot) && slot.item.nil?,'nonlethal instant use preserves the queued paid action and selected slot')
  check($game_party.in_battle && !$game_troop.all_dead? && !@scene.scene_changing? && !HZM_VXA::QuickSkill.quickSkill?,'nonlethal instant action stays in the live battle')
  if defined?(BS2Suite::HDDisplay)
    # This fixture calls next_command directly; finish opening the command
    # window before asserting the same visibility as a live input screen.
    @scene.instance_variable_get(:@actor_command_window).openness=255
    hd=BS2Suite::HDDisplay
    check(hd.start_trial(hd.resolution(1280,720)) && hd.confirm,'HD window starts for legacy-visibility regression')
    10.times { Graphics.update;Input.update };hd.poll(true)
    check(hd.legacy_hidden?,'HD panel has accepted its replacement battle content')
    @scene.update_basic
    plan=@scene.instance_variable_get(:@bs2q_plan);footer=@scene.instance_variable_get(:@bs2q_footer)
    check(plan && !plan.visible && footer && !footer.visible,'update_basic does not re-show legacy plan or footer after HD polling')
    plan.display(actor,true,nil);footer.display(@scene,actor,:commands)
    check(!plan.visible && !footer.visible,'direct legacy display calls cannot flash over accepted HD output')
    check(hd.toggle,'F10 switches to classic output during battle')
    @scene.update_basic;check(plan.visible && footer.visible,'classic mode keeps the legacy plan and footer readable')
    check(hd.toggle,'F10 restores HD output during battle')
    hd.poll(true);@scene.update_basic;check(!plan.visible && !footer.visible,'returning to HD hides legacy output again')
    check(hd.apply(hd.data.merge('sidebar'=>0)),'HD sidebar can be disabled')
    @scene.update_basic
    check(plan.visible && footer.visible,'legacy information remains available without an HD sidebar')
    check(hd.apply(hd.data.merge('sidebar'=>1)),'HD sidebar can be restored')
    hd.instance_variable_set(:@panel_accepted,false);plan.display(actor,true,nil)
    check(plan.visible,'unaccepted HD text leaves the legacy fallback readable')
    hd.instance_variable_set(:@last_text,nil);hd.poll(true);@scene.update_basic
    check(!plan.visible,'legacy panel is hidden after HD accepts text again')
    SceneManager.instance_variable_set(:@scene,Scene_Map.new)
    @scene.pre_terminate
    check(!plan.visible && !footer.visible,'battle fade-out cannot expose the old plan or footer')
  end
  ExitProbe.log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  ExitProbe.log('result=FAIL; '+e.class.to_s+': '+e.message);ExitProbe.log(e.backtrace.join("\n"))
ensure
  @scene.terminate if @scene
  BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  SuiteCapture.close
end
end
