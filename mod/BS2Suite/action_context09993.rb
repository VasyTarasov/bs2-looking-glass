# encoding: UTF-8
module BS2Suite
  # Explicit execution metadata shared by inspection and cache identity. Never
  # copy arbitrary instance variables or a live support plan into a projection.
  module ActionContext
    FIELDS=[:@bs2s_macro_source,:@bs2s_macro_executor,:@bs2s_macro_target,:@bs2s_macro_token].freeze
    def self.object_key(object);object && [object.class.to_s,object.id];end
    def self.rows(rows)
      (rows || []).map { |r| r.values_at('kind','id','source','target') }
    end
    def self.signature(action)
      return nil unless action
      plan=action.instance_variable_get(:@bs2s_support_plan)
      [object_key(action.item),action.default_use_skill_id,action.target_index,action.forcing,
       action.instance_variable_get(:@bs2s_direct_count),action.instance_variable_get(:@bs2s_normal_attack),action.instance_variable_get(:@bs2s_normal_source),
       object_key(action.instance_variable_get(:@bs2s_macro_source)),action.instance_variable_get(:@bs2s_macro_executor),action.instance_variable_get(:@bs2s_macro_target),
       !!action.instance_variable_get(:@bs2s_macro_token),rows(action.instance_variable_get(:@bs2s_macro_before)),rows(action.instance_variable_get(:@bs2s_macro_after)),
       plan && [object_key(plan[:object]),object_key(plan[:source]),plan[:target] && plan[:target].index]]
    end
    def self.copy_selected(original,copy)
      FIELDS.each { |key| copy.instance_variable_set(key,original.instance_variable_get(key)) }
      [:@bs2s_macro_before,:@bs2s_macro_after].each do |key|
        rows=original.instance_variable_get(key)
        copy.instance_variable_set(key,rows && rows.map { |r| r.dup })
      end
      plan=original.instance_variable_get(:@bs2s_support_plan)
      copy.instance_variable_set(:@bs2s_support_plan,plan && {:source=>plan[:source]})
      copy
    end
    def self.selected?(actor,object)
      action=actor && actor.actions[actor.instance_variable_get(:@action_input_index).to_i]
      return false unless action && action.item==object
      scene=SceneManager.scene
      return true unless scene.is_a?(Scene_Battle)
      origin=scene.instance_variable_get(:@bs2q_reference_origin)
      return false if origin.is_a?(Window_SkillList) || origin.is_a?(Window_ItemList) || (defined?(BS2Suite::PaletteWindow) && origin.is_a?(BS2Suite::PaletteWindow))
      return false if defined?(BS2Suite::Palette) && BS2Suite::Palette.current(scene)
      ![:@skill_window,:@item_window].any? do |key|
        window=scene.instance_variable_get(key);window && window.visible && window.active
      end
    end
    def self.attachments(action,actor)
      return [] unless action && defined?(BS2Suite::Macros)
      [[:@bs2s_macro_before,'до: '],[:@bs2s_macro_after,'после: ']].map do |key,label|
        values=action.instance_variable_get(key) || []
        values.empty? ? nil : label+values.map { |r| BS2Suite::Macros.label(r,actor) }.join(', ')
      end.compact
    end
    def self.label(action,actor)
      name=action && action.item ? action.item.name : '—'
      extra=attachments(action,actor)
      extra.empty? ? name : name+' · мгн. '+extra.join(' · ')
    end
  end
end
