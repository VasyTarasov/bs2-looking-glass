# encoding: UTF-8
load 'BS2QA_native_capture.rb'
module ExitLoop
  class << self;attr_accessor :victories,:map_returned,:gold,:issued,:completed,:samples;end
  self.victories=0;self.map_returned=false;self.issued=false
  self.completed=0;self.samples=[]
  def self.cycles;File.file?('battle_exit_cycles.txt') ? [[File.read('battle_exit_cycles.txt').to_i,1].max,100].min : 1;end
  def self.fast?;cycles>1;end
  def self.log(text);File.open('test_result.txt','a') { |f| f.puts text;f.flush };end
end
class ExitLoopMap < Scene_Base
  def start
    super
    if @visited
      ExitLoop.map_returned=true
      ExitLoop.completed+=1
      if ExitLoop.completed==1 || ExitLoop.completed%10==0
        sample=BS2Suite::ResourceStats.sample;ExitLoop.samples<<sample;ExitLoop.log('resource_sample cycle='+ExitLoop.completed.to_s+' '+sample.inspect)
      end
      ExitLoop.log('map_returned=true; cycle='+ExitLoop.completed.to_s)
      if ExitLoop.completed>=ExitLoop.cycles
        SceneManager.exit
        return
      end
      ExitLoop.issued=false;$game_party.leader.recover_all
      BattleManager.setup(79,true,false)
      BattleManager.instance_variable_set(:@map_bgm,RPG::BGM.new);BattleManager.instance_variable_set(:@map_bgs,RPG::BGS.new)
      SceneManager.call(Scene_Battle)
      return
    end
    @visited=true
    DataManager.setup_new_game
    BS2Suite::Options.set('instant_battle_ctrl',1)
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
    $game_party.gain_item($data_weapons[101],1);actor.change_equip(0,$data_weapons[101]);actor.learn_skill(932);actor.recover_all
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA final enemy';enemy.battler_name='';enemy.params=[1,100,1,1,1,1,1,1];enemy.gold=23;enemy.exp=17;$data_enemies[5000]=enemy
    troop=RPG::Troop.new;troop.id=79;member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false)
    BattleManager.instance_variable_set(:@map_bgm,RPG::BGM.new);BattleManager.instance_variable_set(:@map_bgs,RPG::BGS.new)
    ExitLoop.gold=$game_party.gold
    SceneManager.call(Scene_Battle)
  end
end
module Input
  class << self
    alias exit_loop_ctrl press?
    def press?(key);key==:CTRL ? ExitLoop.fast? : exit_loop_ctrl(key);end
  end
end
class ExitLoopKeys
  def focused?;true;end
  def down;ExitLoop.fast? ? [17] : [];end
end
module SceneManager
  def self.first_scene_class;ExitLoopMap;end
end
module BattleManager
  class << self
    alias exit_loop_victory process_victory
    def process_victory
      ExitLoop.victories+=1;ExitLoop.log('victory='+ExitLoop.victories.to_s)
      exit_loop_victory
    end
  end
end
class Scene_Battle
  def wait_for_message;$game_message.clear;end
  alias exit_loop_update update
  def update
    unless ExitLoop.issued
      ExitLoop.issued=true
      BS2QoL::Keyboard.backend=ExitLoopKeys.new;BS2QoL::Keyboard.reset;Input.update
      actor=$game_party.leader;actor.instance_variable_set(:@ap,ATB::MAX_AP)
      actor.instance_variable_set(:@actions,Array.new(2) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,1)
      BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
      start_actor_command_selection
      raise 'Native quick skill is not usable' unless actor.usable?($data_skills[932])
      actor.input.set_skill(932);actor.input.target_index=0
      @hzm_vxa_quickSkill_skill=$data_skills[932]
      next_command
    end
    exit_loop_update
  end
end
rgss_main do
  begin
    File.open('test_result.txt','w') { |f| f.puts 'real SceneManager.run; real instant skill 932; no injected exception; cycles='+ExitLoop.cycles.to_s }
    SceneManager.run
    ExitLoop.log('main_loop_returned '+{:victories=>ExitLoop.victories,:gold_delta=>$game_party.gold-ExitLoop.gold,:map_returned=>ExitLoop.map_returned,:scene=>SceneManager.scene}.inspect)
    raise 'Battle ended the game instead of returning to its previous scene' unless ExitLoop.map_returned
    raise 'Victory was processed more than once' unless ExitLoop.victories==ExitLoop.cycles && $game_party.gold-ExitLoop.gold==23*ExitLoop.cycles
    raise 'A previous battle scope is still retained' if defined?(BS2Suite::BattleFlow) && BS2Suite::BattleFlow.instance_variable_get(:@scope)
    if ExitLoop.cycles>1
      first=ExitLoop.samples.first;last=ExitLoop.samples.last
      raise 'Battle cleanup accumulates GDI handles' unless last[:gdi_objects]<=first[:gdi_objects]+20
      raise 'Battle cleanup accumulates USER handles' unless last[:user_objects]<=first[:user_objects]+20
      raise 'Battle cleanup accumulates private memory' unless last[:private_bytes]<=first[:private_bytes]+32*1024*1024
    end
    ExitLoop.log('result=PASS; checks='+(ExitLoop.cycles>1 ? '6' : '3'))
  rescue Exception=>e
    ExitLoop.log('result=FAIL; '+e.class.to_s+': '+e.message);ExitLoop.log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
    SuiteCapture.close
  end
end
