# encoding: UTF-8
module ExitProbe
  class << self;attr_accessor :victories,:ends,:late_next,:quick_steps,:inject_priority;end
  self.victories=0;self.ends=0;self.late_next=0;self.quick_steps=[]
  class << self;attr_accessor :ctrl;end
  self.ctrl=false
  def self.log(text);File.open('test_result.txt','a') { |f| f.puts text;f.flush };end
end
module BattleManager
  class << self
    alias qa_exit_victory process_victory
    def process_victory
      ExitProbe.victories+=1;ExitProbe.log('victory_enter phase='+@phase.inspect)
      qa_exit_victory
    end
    alias qa_exit_end battle_end
    def battle_end(result)
      ExitProbe.ends+=1;ExitProbe.log('battle_end_enter phase='+@phase.inspect)
      value=qa_exit_end(result);ExitProbe.log('battle_end_exit phase='+@phase.inspect);value
    end
  end
end
class Scene_Battle
  def wait_for_message;$game_message.clear;end
  if method_defined?(:bs20997_next_command)
    alias qa_exit_old_next bs20997_next_command
    def bs20997_next_command
      ExitProbe.late_next+=1 if scene_changing? || !$game_party.in_battle
      qa_exit_old_next
    end
  end
  if method_defined?(:bs2s_macro_quick)
    alias qa_exit_quick bs2s_macro_quick
    def bs2s_macro_quick(actor,row,target)
      ExitProbe.quick_steps<<[row['id'],$game_party.in_battle,scene_changing?]
      qa_exit_quick(actor,row,target)
    end
  end
end
module BS2Suite::Priorities
  class << self
    alias qa_exit_finish finish
    def finish
      if ExitProbe.inject_priority
        ExitProbe.inject_priority=false;@open=false
        raise 'injected priority bookkeeping failure'
      end
      qa_exit_finish
    end
  end
end
module Input
  class << self
    alias qa_exit_ctrl_press press?
    def press?(key);key==:CTRL ? ExitProbe.ctrl : qa_exit_ctrl_press(key);end
  end
end
class ExitRawKeys
  def focused?;true;end
  def down;ExitProbe.ctrl ? [17] : [];end
end
def setup_battle
  @scene.terminate if @scene
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  [101,277].each { |id| $game_party.gain_item($data_weapons[id],1) };actor.change_equip(0,$data_weapons[101]);actor.recover_all
  enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA last enemy';enemy.battler_name='';enemy.params=[10,100,1,1,1,1,1,1];enemy.exp=17;enemy.gold=23
  $data_enemies[5000]=enemy
  troop=RPG::Troop.new;troop.id=79;member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
  BattleManager.setup(79,true,false);$game_party.on_battle_start;$game_troop.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP)
  actor.instance_variable_set(:@actions,Array.new(2) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,1)
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);SceneManager.instance_variable_set(:@stack,[Scene_Map.new]);@scene.start
  # The silent test prelude has no playing map track; provide the normal
  # background-audio objects so victory replay follows a valid game context.
  BattleManager.instance_variable_set(:@map_bgm,RPG::BGM.new)
  BattleManager.instance_variable_set(:@map_bgs,RPG::BGS.new)
  @scene.start_actor_command_selection
  BS2QoL::Keyboard.backend=ExitRawKeys.new;BS2QoL::Keyboard.reset;Input.update
  quick=RPG::Item.new;quick.id=5002;quick.name='QA lethal instant';quick.scope=1;quick.occasion=0;quick.hit_type=0;quick.success_rate=100;quick.note='[hzm]ターン消費無し:99';quick.damage.type=1;quick.damage.formula='99999';quick.damage.variance=0
  $data_items[5002]=quick;$game_party.gain_item(quick,5)
  buff=RPG::Item.new;buff.id=5003;buff.name='QA following instant';buff.scope=11;buff.occasion=0;buff.note='[hzm]ターン消費無し:99';buff.effects=[RPG::UsableItem::Effect.new(31,2,5,0)]
  $data_items[5003]=buff;$game_party.gain_item(buff,5)
  paid=RPG::Skill.new;paid.id=5004;paid.name='QA paid damage';paid.scope=1;paid.stype_id=1;paid.hit_type=0;paid.success_rate=100;paid.damage.type=1;paid.damage.formula='1';paid.damage.variance=0;$data_skills[5004]=paid;actor.learn_skill(5004)
  ExitProbe.victories=0;ExitProbe.ends=0;ExitProbe.late_next=0;ExitProbe.quick_steps=[]
  actor
end
def row(kind,id);{'kind'=>kind,'id'=>id,'source'=>0,'target'=>0};end
