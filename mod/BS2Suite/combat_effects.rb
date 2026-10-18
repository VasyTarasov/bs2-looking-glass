# encoding: UTF-8
module BS2Suite
  module CombatEffects
    def self.participants
      $game_party.battle_members+$game_troop.members.select { |e| !e.hidden? }
    end
    def self.icons(unit)
      rows=[]
      unit.states.each do |s|
        next unless s.icon_index>0
        turns=(unit.instance_variable_get(:@state_turns) || {})[s.id]
        label=s.auto_removal_timing==0 ? '∞' : turns.nil? ? '?' : (turns.to_i+1).to_s+(s.auto_removal_timing==1 ? 'д' : s.auto_removal_timing==3 ? 'т' : '')
        rows<<[s.icon_index,label,s.name]
      end
      (unit.instance_variable_get(:@buffs) || []).each_with_index do |level,id|
        next if level==0
        turns=(unit.instance_variable_get(:@buff_turns) || {})[id]
        rows<<[unit.buff_icon_index(level,id),turns.nil? ? '?' : (turns.to_i+1).to_s+(defined?(ATB::BUFF_TURN_COUNT) && ATB::BUFF_TURN_COUNT==1 ? 'д' : ''),BS2Modules::PARAMS[id]]
      end
      rows
    end
    def self.open(scene,origin)
      return false unless origin && !origin.disposed?
      window=CombatEffectsWindow.new
      origin.deactivate
      scene.instance_variable_set(:@bs2080_effects,window)
      scene.instance_variable_set(:@bs2080_effects_origin,origin)
      window.set_handler(:cancel,lambda { close(scene) })
      BS2QoL::Keyboard.consume;true
    end
    def self.close(scene)
      window=scene.instance_variable_get(:@bs2080_effects);window.dispose if window && !window.disposed?
      origin=scene.instance_variable_get(:@bs2080_effects_origin);origin.activate if origin && !origin.disposed?
      scene.instance_variable_set(:@bs2080_effects,nil)
      BS2QoL::Keyboard.consume;Input.update
    end
    def self.details(scene)
      window=scene.instance_variable_get(:@bs2080_effects);unit=window && window.item
      return false unless unit && BS2Suite.enabled?('reference_cards')
      if unit.actor?
        EquipmentDetails.open(scene,window,unit,nil,unit.name.to_s.empty? ? 'Герой' : unit.name)
      else
        BS2QoL::Reference.open(scene,window)
      end
    end
  end
  class CombatEffectsWindow < Window_Selectable
    attr_reader :rows
    def initialize
      @rows=[]
      per=[(Graphics.width-210)/32,1].max
      CombatEffects.participants.each do |unit|
        icons=CombatEffects.icons(unit)
        icons=[nil] if icons.empty?
        icons.each_slice(per).with_index { |slice,i| @rows<<[i==0 ? (unit.name.to_s.empty? ? (unit.actor? ? 'Герой' : 'Противник') : unit.name) : '',slice,unit] }
      end
      height=[(@rows.size+1)*40+24,Graphics.height-32].min
      super(16,16,Graphics.width-32,height);self.z=480;BS2Modules.style(self);activate;select(0);refresh
    end
    def item_max;@rows.size+1;end
    def item;@rows[index] && @rows[index][2];end
    def process_handling
      return unless open? && active
      return process_cancel if Input.trigger?(:B)
      if Input.trigger?(:C) || BS2QoL::Keyboard.first=='F7'
        BS2Suite::CombatEffects.details(SceneManager.scene) || ::Sound.play_buzzer
      end
    end
    def refresh;create_contents;draw_all_items;end
    def item_height;40;end
    def draw_item(index)
      rect=item_rect(index)
      if index==@rows.size
        contents.font.size=14
        draw_text(rect.x,rect.y,contents_width,20,'Enter / F7 сведения · H / Esc закрыть · ↑/↓ прокрутка')
        draw_text(rect.x,rect.y+18,contents_width,20,'∞ без отсчёта · д действия · т такты · без буквы ходы')
        return
      end
      label,icons=@rows[index]
      contents.font.size=17;draw_text(rect.x,rect.y,170,32,label)
      draw_text(rect.x+174,rect.y,contents_width-174,32,'—') if icons==[nil]
      icons.each_with_index do |entry,i|
        next unless entry
        icon,count,name=entry;x=rect.x+174+i*32
        draw_icon(icon,x,rect.y+4)
        contents.font.size=14;contents.font.bold=true
        draw_text(x,rect.y+15,29,20,count,2)
        contents.font.bold=false
      end
      contents.font.size=17
    end
  end
end
module BS2QoL::Hotkeys
  class << self
    alias bs2080_effects_handle handle
    def handle(window)
      scene=SceneManager.scene
      if scene.is_a?(Scene_Battle)
        return true if scene.instance_variable_get(:@bs2080_effects) && !window.is_a?(BS2Suite::CombatEffectsWindow)
        if window.visible && BS2Suite::Keys.trigger?(:combat_effects) && !scene.instance_variable_get(:@bs2s_palette) && !(defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)) && !$game_message.busy?
          return BS2Suite::ContextEffects.route(scene,window) if defined?(BS2Suite::ContextEffects)
          return BS2Suite::CombatEffects.open(scene,window)
        end
      end
      bs2080_effects_handle(window)
    end
  end
end
class Scene_Battle
  alias bs2080_effects_update update
  def update
    if @bs2080_effects
      Graphics.update;Input.update
      if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(self)
        BS2QoL::Reference.update(self)
      elsif BS2Suite::Keys.trigger?(:combat_effects) || Input.trigger?(:B)
        if BS2Suite::Keys.trigger?(:combat_effects) && defined?(BS2Suite::ContextEffects)
          BS2Suite::ContextEffects.route(self)
        else;BS2Suite::CombatEffects.close(self);end
      else;@bs2080_effects.update;end
      return
    end
    bs2080_effects_update
  end
  alias bs2080_effects_terminate terminate
  def terminate
    BS2QoL::Reference.close(self,false) if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(self) && @bs2080_effects
    BS2Suite::CombatEffects.close(self) if @bs2080_effects
    bs2080_effects_terminate
  end
end
