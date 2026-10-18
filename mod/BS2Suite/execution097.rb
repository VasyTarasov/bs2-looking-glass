# encoding: UTF-8
module BS2Suite::DirectWeapons
  class << self
    # Same constraints as Model.change_weapon, but ownership includes a weapon
    # temporarily put away in a read-only projection. No inventory trade occurs.
    def can_switch?(actor,weapon)
      return false unless actor && weapon
      return true if actor.equips[0]==weapon
      return false unless actor.equip_command_usable
      flag=$game_temp.battle_equip
      begin
        $game_temp.battle_equip=true
        actor.equip_slots[0]==weapon.etype_id && actor.equip_change_ok?(0) && actor.equippable?(weapon) &&
          BS2Suite::Semantic.owned(actor).include?(weapon)
      ensure
        $game_temp.battle_equip=flag
      end
    end
    def eligible_final(actor,item,weapon,index=nil,action=nil)
      return nil unless actor && weapon && item && actor.movable? && !actor.confusion?
      index=actor.instance_variable_get(:@action_input_index).to_i if index.nil?
      action ||= actor.actions[index]
      return nil if action && action.forcing
      return nil if BS2Suite::BattleSupport.quick?(item) || sole_source(actor,item,index,action)
      return nil unless can_switch?(actor,weapon)
      view=actor.equips[0]==weapon ? BS2Suite::Projection.copy(actor) : BS2Suite::Projection.weapon(actor,weapon)
      view.usable?(item) ? weapon : nil
    end
    def execution_weapon(actor,item,index=nil,action=nil)
      sole_source(actor,item,index,action) || eligible_final(actor,item,selected(actor),index,action)
    end
    def copy_action_context(original,copy,object)
      return copy unless original
      copy.instance_variable_set(:@bs2s_direct_count,original.instance_variable_get(:@bs2s_direct_count))
      copy.instance_variable_set(:@forcing,original.forcing)
      if original.item==object && original.instance_variable_get(:@bs2s_normal_attack)
        copy.instance_variable_set(:@bs2s_normal_attack,true)
        copy.instance_variable_set(:@bs2s_normal_source,original.instance_variable_get(:@bs2s_normal_source))
      end
      copy
    end
    def before_action(action)
      actor=action.subject
      return unless actor && actor.actor? && !action.forcing && !quick? && !actor.confusion? && actor.movable?
      return unless actor.instance_variable_get(:@bs2s_direct_final).equal?(action)
      return unless actor.actions.last.equal?(action) && actor.current_action.equal?(action)
      return if action.instance_variable_get(:@bs2s_direct_applied) || sole_source(actor,action.item,0,action)
      return unless selected_id(actor)
      weapon=selected(actor)
      unless weapon
        BS2QoL::Hotkeys.notice('N: оружие недоступно; остаётся текущее');return
      end
      unless eligible_final(actor,action.item,weapon,0,action)
        BS2QoL::Hotkeys.notice('N: смена недоступна; действие с текущим оружием');return
      end
      unless actor.equips[0]==weapon || BS2QoL::Model.change_weapon(actor,weapon)
        BS2QoL::Hotkeys.notice('N: смена недоступна; действие с текущим оружием');return
      end
      action.instance_variable_set(:@bs2s_direct_applied,true)
      BS2QoL::Hotkeys.notice('Последнее действие: '+weapon.name)
      scene=SceneManager.scene;scene.refresh_status if scene.is_a?(Scene_Battle)
    end
  end
end
module BS2Suite::DirectWeapons
  class << self
    def variable_signature(actor,item,targets)
      objects=actor.feature_objects+targets.map { |t| t.feature_objects }.flatten
      texts=objects.map { |o| o.note.to_s }
      texts+=([item]+actor.actions.map { |a| a.item }).compact.map { |o| o.respond_to?(:damage) ? o.damage.formula.to_s : '' }
      ids=[];dynamic=false
      texts.each do |text|
        constants=text.scan(/\bv\s*\[\s*(\d+)\s*\]/).flatten.map { |v| v.to_i }
        dynamic=true if text.scan(/\bv\s*\[/).size!=constants.size
        ids+=constants
      end
      dynamic ? $game_variables.instance_variable_get(:@data).dup : ids.uniq.sort.map { |id| [id,$game_variables[id]] }
    end
  end
end
