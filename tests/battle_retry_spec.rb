# encoding: UTF-8
load 'BS2QA_native_capture.rb'
module RetryQA
  @checks=0;@attempt=0;@flasks=0;@frames=0
  class << self
    attr_reader :attempt,:flasks
    def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
    def check(v,s);raise 'Assertion: '+s unless v;@checks+=1;log('PASS '+s);end
    def active(scene,name)
      w=scene.instance_variable_get(name);w && w.active && w.open? ? w : nil
    end
    def move(w,index)
      return :C if w.index==index
      return :DOWN if w.index/w.col_max<index/w.col_max
      return :UP if w.index/w.col_max>index/w.col_max
      w.index%w.col_max<index%w.col_max ? :RIGHT : :LEFT
    end
    def choose(w,symbol)
      index=w.instance_variable_get(:@list).index { |r| r[:symbol]==symbol }
      raise 'Command missing '+symbol.to_s unless index
      move(w,index)
    end
    def key
      @frames+=1;raise 'Native retry frame budget exceeded' if @frames>4500
      if Graphics.frame_count%300==0
        scene=SceneManager.scene
        windows=scene.instance_variables.map { |n| [n,scene.instance_variable_get(n)] }.select { |n,w| w.is_a?(Window_Selectable) && w.active }.map { |n,w| [n,w.index,w.openness] }
        log('progress '+[Graphics.frame_count,@attempt,@flasks,scene.class,windows,$game_party.members.map { |a| [a.hp,a.agi] },$game_troop.members.map { |e| [e.hp,e.agi] }].inspect)
      end
      return nil if Graphics.frame_count.odd?
      return :C if $game_message && ($game_message.busy? || $game_message.visible)
      scene=SceneManager.scene
      if scene.is_a?(Scene_Gameover)
        w=active(scene,:@bs2_defeat);return choose(w,:retry) if w
      elsif scene.is_a?(Scene_Battle)
        [:@enemy_window,:@actor_window].each { |name| w=active(scene,name);return :C if w }
        w=active(scene,:@item_window)
        if w
          index=w.instance_variable_get(:@data).index($data_items[1]);return move(w,index)
        end
        w=active(scene,:@actor_command_window)
        return choose(w,@attempt==1 ? (@flasks==0 ? :item : :guard) : :attack) if w
        w=active(scene,:@party_command_window);return choose(w,:fight) if w
      end
      nil
    end
    def started
      @attempt+=1
      if @attempt==2
        a=$game_party.members[0]
        check(a.hp==1 && a.mp==@initial_mp,'retry restores pre-fight HP and MP')
        check($game_party.item_number($data_items[1])==3,'retry restores genuinely spent flask')
        check($game_variables[201]==77 && $game_switches[201],'retry restores world variables and switches')
        check($game_map.interpreter.instance_variable_get(:@index)==1,'restored event waits after command 301')
      end
    end
    def used(item);@flasks+=1 if @attempt==1 && item==$data_items[1];end
    def initial_mp=(value);@initial_mp=value;end
    def finish;log('result=PASS; checks='+@checks.to_s);end
  end
end
module Input
  class << self
    alias retryqa_update update
    def update
      retryqa_update
      if @retryqa_frame==Graphics.frame_count
        @retryqa_key=nil
      else
        @retryqa_frame=Graphics.frame_count;@retryqa_key=RetryQA.key
      end
    end
    def trigger?(key);@retryqa_key==key;end
    def repeat?(key);@retryqa_key==key;end
    def press?(key);@retryqa_key==key;end
  end
end
module BattleManager
  class << self
    alias retryqa_start battle_start
    def battle_start;RetryQA.started;retryqa_start;end
  end
end
class Game_Actor
  alias retryqa_use use_item
  def use_item(item);RetryQA.used(item);retryqa_use(item);end
end
class Scene_Gameover
  alias retryqa_post_start post_start
  def post_start
    retryqa_post_start
    SuiteCapture.save('BS2QA_defeat.bmp') if RetryQA.attempt==1
  end
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'native_scene_retry_suite' }
  DataManager.init;DataManager.setup_new_game;Window_MenuCommand.init_command_position
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(30,false);actor.clear_equipments;actor.clear_states
  actor.name='Гримм';actor.hp=1;actor.mp=actor.mmp;RetryQA.initial_mp=actor.mp
  $game_party.gain_item($data_items[1],3-$game_party.item_number($data_items[1]))
  $game_variables[201]=77;$game_switches[201]=true
  # All fixture edits are in-memory database objects in the isolated process.
  enemy=Marshal.load(Marshal.dump($data_enemies[3]));enemy.params=[100,100,99999,1,1,1,1,1]
  lethal=Marshal.load(Marshal.dump($data_skills[14]));lethal.hit_type=0;lethal.mp_cost=0;lethal.animation_id=0
  lethal.damage.formula='999999';lethal.damage.variance=0;lethal.damage.critical=false;lethal.damage.element_id=0
  $data_skills[14]=lethal
  enemy.features=[RPG::BaseItem::Feature.new(22,0,1.0)];enemy.note='';enemy.actions=[RPG::Enemy::Action.new];enemy.actions[0].skill_id=14;enemy.actions[0].rating=9
  $data_enemies[3]=enemy
  troop=Marshal.load(Marshal.dump($data_troops[1]));troop.members=troop.members.take(1);troop.members[0].enemy_id=3;troop.pages=[];$data_troops[1]=troop
  event=[RPG::EventCommand.new(301,0,[0,1,false,false]),RPG::EventCommand.new(601,0,[]),RPG::EventCommand.new(122,1,[200,200,0,0,42]),RPG::EventCommand.new(604,0,[]),RPG::EventCommand.new(0,0,[])]
  $game_map.interpreter.setup(event,0)
  SceneManager.goto(Scene_Map);$game_map.interpreter.update
  RetryQA.check(SceneManager.scene.is_a?(Scene_Battle),'real map event launches battle')
  SceneManager.scene.main
  RetryQA.check(SceneManager.scene.is_a?(Scene_Gameover),'native full battle reaches defeat screen')
  RetryQA.check(RetryQA.flasks==1,'first attempt really consumes a native flask')
  RetryQA.check(BS2Suite::Retry.ready?,'ordinary map-event battle has retry checkpoint')
  RetryQA.check(BS2Suite::BattleRecord.last[:result]==2 && BS2Suite::BattleRecord.last[:members].values.any? { |r| r[:damage]>0 },'statistics record real lethal damage and defeat')
  RetryQA.check(BS2Suite::BattleRecord.death.to_s.include?($data_skills[14].name),'death explanation names observed lethal action')
  previous=SceneManager.scene;stats=BS2Suite::StatsScene.new;SceneManager.instance_variable_set(:@scene,stats)
  stats.start;Graphics.transition(0);3.times { Graphics.update };SuiteCapture.save('BS2QA_statistics.bmp')
  stats.terminate;SceneManager.instance_variable_set(:@scene,previous)
  $game_variables[201]=999;$game_switches[201]=false
  SceneManager.scene.main
  RetryQA.check(SceneManager.scene.is_a?(Scene_Battle),'native defeat-window retry command starts a new fight')
  SceneManager.scene.main
  RetryQA.check(SceneManager.scene.is_a?(Scene_Map),'retried fight wins and returns to map')
  $game_map.interpreter.update
  RetryQA.log('event_after_retry='+[$game_variables[200],$game_map.interpreter.instance_variable_get(:@index),$game_map.interpreter.instance_variable_get(:@branch),$game_map.interpreter.running?].inspect)
  $game_map.interpreter.update # Native interpreter yields once at end before clearing its fiber.
  RetryQA.check($game_variables[200]==42 && !$game_map.interpreter.running?,'victory branch resumes correctly exactly once')
  RetryQA.check(BS2Suite::BattleRecord.last[:result]==0 && !BS2Suite::Retry.ready?,'victory stats replace defeat and stale retry cleared')
  RetryQA.check(BS2Suite::Retry.interpreter.nil?,'suspended launch interpreter is not retained as future battle context')
  BattleManager.setup(3,false,false);$game_party.on_battle_start;BS2Suite::BattleRecord.start
  actor=$game_party.members[0];actor.recover_all
  price=actor.skill_mp_cost($data_skills[95]);actor.use_item($data_skills[95])
  row=BS2Suite::BattleRecord.record[:members]['actor:'+actor.id.to_s]
  RetryQA.check(row[:costs][1]==price && row[:mp]==0,'native MP payment is recorded separately from target damage')
  regeneration=RPG::State.new;regeneration.id=267;regeneration.features=[RPG::BaseItem::Feature.new(22,7,0.1)]
  $data_states[267]=regeneration;actor.add_new_state(267);actor.hp=actor.mhp/2
  before=actor.hp;healing=row[:healing];actor.regenerate_hp
  RetryQA.check(actor.hp>before && row[:healing]-healing==actor.hp-before,'ordinary native regeneration enters actual healing totals')
  actor.remove_state(267)
  srand(613);expected=rand;srand(613);BS2Suite::BattleRecord.lines
  RetryQA.check(rand==expected,'statistics presentation consumes no combat RNG')
  $game_party.on_battle_end;BS2Suite::BattleRecord.finish(0)
  BS2Suite::Retry.finished(2)
  RetryQA.check(BS2Suite::Retry.ready?,'next ordinary map battle can prepare a fresh checkpoint')
  before=Marshal.dump(DataManager.make_save_contents);world=$game_map;party=$game_party
  class << BattleManager
    alias qa_retry_setup bs2suite_record_setup
    def bs2suite_record_setup(*args);qa_retry_setup(*args);raise IOError,'QA setup failure';end
  end
  RetryQA.check(!BS2Suite::Retry.restore,'checkpoint restoration failure is reported')
  class << BattleManager;alias bs2suite_record_setup qa_retry_setup;end
  RetryQA.check($game_map.equal?(world) && $game_party.equal?(party) && Marshal.dump(DataManager.make_save_contents)==before,'failed retry restores previous live objects and world bytes')
  # Refuse known non-restartable contexts without touching their state.
  child=Game_Interpreter.new(1);BS2Suite::Retry.interpreter=child
  before=Marshal.dump([$game_party,$game_variables])
  BS2Suite::Retry.prepare(1,false,false)
  RetryQA.check(!BS2Suite::Retry.ready? && BS2Suite::Retry.reason.include?('Вложенное'),'nested event retry explicitly refused')
  RetryQA.check(Marshal.dump([$game_party,$game_variables])==before,'refused checkpoint leaves live game state unchanged')
  BS2Suite::Retry.interpreter=nil;BS2Suite::Retry.prepare(1,false,true)
  RetryQA.check(!BS2Suite::Retry.ready?,'allowed story defeat never gets retry checkpoint')
  RetryQA.finish
rescue Exception=>e
  RetryQA.log('result=FAIL; '+e.class.to_s+': '+e.message);RetryQA.log(e.backtrace.join("\n"))
ensure;exit;end
