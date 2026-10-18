# encoding: UTF-8
module BS2Suite
  module ListNavigation
    def self.pageable?(window)
      classes=[Window_ItemList,Window_SkillList,Window_EquipItem,Window_ShopBuy,Window_ItemSynthesisList,Window_BS2QCollection]
      classes<<BS2Suite::EditorCommands if defined?(BS2Suite::EditorCommands)
      classes.any? { |type| window.is_a?(type) } && !window.horizontal? && window.col_max==1 &&
        window.item_max>window.page_item_max && window.page_item_max>0 &&
        window.method(:cursor_right).owner==Window_Selectable && window.method(:cursor_left).owner==Window_Selectable
    end
    def self.move(window,delta)
      return false unless pageable?(window) && window.cursor_movable?
      return true if window.instance_variable_get(:@bs2091_page_frame)==Graphics.frame_count
      window.instance_variable_set(:@bs2091_page_frame,Graphics.frame_count)
      previous=window.index
      window.select([[previous+delta*window.page_item_max,0].max,window.item_max-1].min)
      ::Sound.play_cursor if previous!=window.index
      true
    end
  end
  module TargetDigits
    def self.actor_indices
      members=$game_party.battle_members;self_index=members.index(BattleManager.actor)
      self_index ? [self_index]+(0...members.size).to_a.reject { |i| i==self_index } : (0...members.size).to_a
    end
    def self.handle(window)
      return false unless window.open? && window.active && window.visible
      return false if window.instance_variable_get(:@bs2091_target_opened)==Graphics.frame_count
      scene=SceneManager.scene
      return false if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)
      return false unless (BS2QoL::Keyboard.raw_down & [16,17,18,91,92]).empty?
      key=BS2QoL::Keyboard.raw_fresh.find { |n| (48..57).include?(n) }
      return false unless key
      index=key==48 ? 9 : key-49
      BS2QoL::Keyboard.consume
      index=actor_indices[index] if window.is_a?(Window_BattleActor)
      if index && index<window.item_max
        object=BattleManager.actor && BattleManager.actor.input && BattleManager.actor.input.item
        member=window.is_a?(Window_BattleActor) && $game_party.battle_members[index]
        if member && object && (object.for_dead_friend? ? !member.dead? : member.dead?)
          ::Sound.play_buzzer;return true
        end
        window.select(index);window.process_ok
      else
        ::Sound.play_buzzer
      end
      true
    end
  end
end
class Window_Selectable
  alias bs2091_page_cursor process_cursor_move
  def process_cursor_move
    return if Input.repeat?(:RIGHT) && BS2Suite::ListNavigation.move(self,1)
    return if Input.repeat?(:LEFT) && BS2Suite::ListNavigation.move(self,-1)
    bs2091_page_cursor
  end
end
if BS2Suite.enabled?('reference_cards')
  module BS2QoL::Reference
    class << self
      alias bs2091_reference_object object_for
      def object_for(window)
        object=bs2091_reference_object(window)
        return object if supported?(object) || object.is_a?(Game_Actor)
        data=window.instance_variable_get(:@data)
        object=data[window.index] if data.is_a?(Array) && window.index>=0
        return object if supported?(object)
        object=window.instance_variable_get(:@item)
        return object if supported?(object)
        ext=window.current_ext if window.respond_to?(:current_ext)
        ext=ext[:object] || ext[:item] if ext.is_a?(Hash)
        supported?(ext) ? ext : nil
      end
      alias bs2091_eligible eligible?
      def eligible?(scene,window)
        return false if active?(scene) || scene.instance_variable_get(:@bs2q_binding_window)
        # An event can retain a pending message while its exclusive shop/craft scene is open.
        # It must not disable the active list in that separate menu.
        return supported?(object_for(window)) || object_for(window).is_a?(Game_Actor) if scene.is_a?(Scene_MenuBase)
        return true if object_for(window).is_a?(Game_Actor) && !($game_message && ($game_message.busy? || $game_message.visible))
        bs2091_eligible(scene,window)
      end
      alias bs2091_reference_open open
      def open(scene,window)
        object=object_for(window)
        return BS2Suite::EquipmentDetails.open(scene,window,object) if object.is_a?(Game_Actor) && eligible?(scene,window)
        bs2091_reference_open(scene,window)
      end
      def route(scene)
        return false unless BS2QoL::Keyboard.first=='F7' && !active?(scene)
        return false if scene.instance_variable_get(:@bs2092_journal) || scene.instance_variable_get(:@bs2080_effects) || scene.instance_variable_get(:@bs2q_binding_window)
        window=scene.instance_variables.map { |key| scene.instance_variable_get(key) }.find do |value|
          value.is_a?(Window_Selectable) && !value.disposed? && value.active && value.visible && value.open? && eligible?(scene,value) &&
            !(scene.is_a?(Scene_Equip) && !value.is_a?(Window_EquipItem))
        end
        return false unless window
        BS2QoL::Keyboard.consume
        open(scene,window)
      end
    end
  end
  class Scene_Base
    alias bs2091_reference_windows update_all_windows
    def update_all_windows
      BS2QoL::Reference.route(self)
      bs2091_reference_windows
    end
  end
end
class Scene_Battle
  alias bs2091_target_enemy select_enemy_selection
  def select_enemy_selection
    bs2091_target_enemy
    @enemy_window.instance_variable_set(:@bs2091_target_opened,Graphics.frame_count) if @enemy_window.active
  end
  alias bs2091_target_actor select_actor_selection
  def select_actor_selection
    bs2091_target_actor
    @actor_window.instance_variable_set(:@bs2091_target_opened,Graphics.frame_count) if @actor_window.active
  end
end
class Window_BattleEnemy
  alias bs2091_target_handling process_handling
  def process_handling
    return if BS2Suite::TargetDigits.handle(self)
    bs2091_target_handling
  end
  def draw_item(index)
    change_color(normal_color)
    enemy=$game_troop.alive_members[index];return unless enemy
    label=index<10 ? (index==9 ? '0' : (index+1).to_s)+'  ' : ''
    draw_text(item_rect_for_text(index),label+enemy.name)
  end
end
class Window_BattleActor
  alias bs2091_actor_target_handling process_handling
  def process_handling
    return if BS2Suite::TargetDigits.handle(self)
    bs2091_actor_target_handling
  end
  alias bs2091_actor_target_draw draw_item
  def draw_item(index)
    bs2091_actor_target_draw(index)
    return if index>=10
    rect=item_rect_for_text(index)
    digit=BS2Suite::TargetDigits.actor_indices.index(index);return unless digit && digit<10
    draw_text(rect.x+rect.width-22,rect.y,22,line_height,digit==9 ? '0' : (digit+1).to_s,2)
  end
end
