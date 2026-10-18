# encoding: UTF-8
module BS2Suite::DirectWeapons
  class << self
    # Count the original queue, not the one remaining action after earlier slots
    # have executed. Equipment-granted IDs identify techniques without relying on
    # names, element, hit type or the database's shared stype_id.
    def sole_source(actor,item,index=nil,action=nil)
      return nil unless actor && item.is_a?(RPG::Skill)
      index=actor.instance_variable_get(:@action_input_index).to_i if index.nil?
      action ||= actor.actions[index]
      return nil if action && action.forcing
      count=action && action.instance_variable_get(:@bs2s_direct_count)
      count ||= actor.actions.size
      return nil unless count==1
      return nil if action && action.item==item && action.instance_variable_get(:@bs2s_normal_attack)
      worn=actor.equips[0]
      if worn.is_a?(RPG::Weapon) && worn.features.any? { |f| f.code==43 && f.data_id==item.id }
        return worn
      end
      provider=BS2Suite::Semantic.source_for(actor,item.id)
      provider.is_a?(RPG::Weapon) ? provider : nil
    end
    def execution_weapon(actor,item,index=nil,action=nil)
      sole_source(actor,item,index,action) || selected(actor)
    end
  end
end
