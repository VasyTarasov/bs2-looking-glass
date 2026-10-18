# encoding: UTF-8
# Modal controllers must keep updating their topmost child, including F4's
# synchronous chooser. Rendering a child in the sidebar is not input dispatch.
if defined?(BS2Suite::EnemyInfoList)
class BS2Suite::EnemyInfoList
  alias bs2092dev_chooser_handling process_handling
  def process_handling
    return unless active && open?
    scene=SceneManager.scene
    return if defined?(BS2Suite::ContextEffects) && BS2Suite::ContextEffects.route(scene,self)
    if BS2Suite::Keys.trigger?(:enemy_info)
      process_cancel;return
    end
    bs2092dev_chooser_handling
  end
end
end
if defined?(BS2Suite::CombatEffects)
module BS2Suite::CombatEffects
  def self.update_modal(scene)
    window=scene.instance_variable_get(:@bs2080_effects)
    return false unless window && !window.disposed?
    if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)
      BS2QoL::Reference.update(scene)
    elsif BS2Suite::Keys.trigger?(:combat_effects)
      BS2Suite::ContextEffects.route(scene)
    elsif Input.trigger?(:B)
      close(scene)
    else
      window.update
    end
    true
  end
end
end

if defined?(BS2Suite::QuickDamage)
module BS2Suite::QuickDamage
  class << self
    # Candidate targets are alternatives, not simultaneous hits. Keep the same
    # action/weapon policy as execution and never mark a technique as Attack.
    def candidate_mean(object,actor,source,unit,weapon=nil)
      view=source.is_a?(RPG::Weapon) ? BS2Suite::Projection.weapon(actor,source) : BS2Suite::Projection.copy(actor)
      index=actor.instance_variable_get(:@action_input_index).to_i
      return nil unless actor.actions[index]
      action=Game_Action.new(actor)
      object.is_a?(RPG::Item) ? action.set_item(object.id) : action.set_skill(object.id)
      action.target_index=unit.index
      BS2Suite::DirectWeapons.copy_action_context(actor.actions[index],action,object)
      action.instance_variable_set(:@bs2s_normal_attack,true) if weapon
      actions=actor.actions.map { |a| a.dup };actions[index]=action
      view.instance_variable_set(:@actions,actions)
      step=BS2Suite::SequenceForecast.new(view,BS2Suite::DirectWeapons.selected(actor)).steps[index]
      return nil unless step && !step[:reason]
      row=step[:rows].find { |r| r[:target_index]==unit.index }
      row && [row[:mean],step[:partial]]
    end
    alias bs2092dev_damage_calculate calculate
    def calculate(object,actor,source,targets,target,weapon)
      if !target && targets.size>1 && object.for_one? && !object.for_random?
        values=targets.map { |unit| candidate_mean(object,actor,source,unit,weapon) }
        return ['~? · серия пока не рассчитана'] if values.any? { |v| !v }
        return [compact_means(values.map { |v| v[0] })+' урона'+(values.any? { |v| v[1] } ? ' · первое попадание' : '')]
      end
      # AoE remains a sum over actual targets. Random targeting retains its
      # probability-weighted distribution, rather than a sum of alternatives.
      bs2092dev_damage_calculate(object,actor,source,targets,target,weapon)
    end
  end
end
end

# Map-only, manual use. Reserve the original common event; its own SEN choice
# remains intact. No item effect, event, selection or resource is simulated here.
module BS2Suite::MadnessGear
  def self.available?(scene)
    return false if (BS2QoL::Keyboard.raw_down & [18,91,92]).any?
    return false unless scene.is_a?(Scene_Map) && !scene.scene_changing?
    return false unless $game_party && !$game_party.in_battle && $game_party.leader && !$game_party.leader.dead?
    return false if $game_system.menu_disabled || $game_message.busy? || $game_message.visible
    return false if $game_map.interpreter.running? || $game_player.moving? || $game_player.transfer?
    return false if $game_temp.common_event_reserved?
    item=$data_items[88]
    item && $game_party.has_item?(item) && $game_party.leader.usable?(item)
  end
  def self.use(scene)
    return false unless available?(scene)
    item=$data_items[88];actor=$game_party.leader
    # Follow Scene_ItemBase's global event path; do not apply to a battler.
    actor.use_item(item)
    Sound.play_use_item
    BS2QoL::Keyboard.consume
    true
  end
end
class Scene_Map
  alias bs2092dev_gear_update update
  def update
    bs2092dev_gear_update
    BS2Suite::MadnessGear.use(self) if BS2Suite::Keys.trigger?(:gear)
  end
end
