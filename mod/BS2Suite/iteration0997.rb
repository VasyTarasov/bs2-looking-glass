# encoding: UTF-8
if BS2Suite.enabled?('semantic_groups')
class Scene_Battle
  alias bs20997_next_command next_command
  def next_command
    actor=BattleManager.actor;action=actor && actor.input;item=action && action.item
    if item && BS2Suite::BattleSupport.quick?(item)
      index=actor.instance_variable_get(:@action_input_index)
      @hzm_vxa_quickSkill_skill=item
      hzm_vxa_quickSkill_run
      # QuickSkill executes by temporarily swapping this slot with slot zero.
      # Keep the already chosen actions and resume this exact unspent slot.
      action.clear if actor.actions.include?(action)
      actor.instance_variable_set(:@action_input_index,[index,actor.actions.size-1].min)
      @hzm_vxa_quickSkill_skill=nil
      BS2Suite::Performance.bump
      return start_actor_command_selection unless scene_changing? || !actor.inputable?
    end
    bs20997_next_command
  end
end
module BS2Suite::DirectWeapons
  class << self
    def arm(actor)
      return unless actor && actor.actor?
      paid=actor.actions.select { |a| a && a.item && !BS2Suite::BattleSupport.quick?(a.item) }
      actor.instance_variable_set(:@bs2s_direct_final,paid.last)
      paid.each { |a| a.instance_variable_set(:@bs2s_direct_count,paid.size) }
    end
  end
end
module BattleManager
  class << self
    alias bs20997_arm_turn turn_start
    def turn_start
      # actor has already been cleared by next_command on the last input slot.
      $game_party.battle_members.each { |a| BS2Suite::DirectWeapons.arm(a) }
      bs20997_arm_turn
    end
  end
end
module BS2Suite::Palette
  class << self
    alias bs20997_digit digit
    def digit
      popup=current(SceneManager.scene)
      if popup && popup.prefix=='N' && popup.group && !popup.assignment && Input.press?(:A) && (BS2QoL::Keyboard.raw_down & [17,18,91,92]).empty?
        raw=BS2QoL::Keyboard.raw_fresh.find { |k| (48..57).include?(k) }
        return raw-48 if raw
      end
      bs20997_digit
    end
    alias bs20997_weapon_choose choose
    def choose(scene,row)
      popup=current(scene)
      if popup && popup.prefix=='N' && popup.group && !popup.assignment && popup.transition.empty? && row && row[:present] && Input.press?(:A)
        weapon=row[:object];actor=popup.actor
        unless weapon && (actor.equips[0]==weapon || BS2QoL::Model.change_weapon(actor,weapon))
          ::Sound.play_buzzer;return
        end
        close(scene);commands(scene)
        scene.instance_variable_get(:@actor_command_window).refresh;scene.refresh_status
        scene.command_attack
        BS2QoL::Keyboard.consume;return
      end
      bs20997_weapon_choose(scene,row)
    end
    alias bs20997_weapon_header update_header
    def update_header(scene)
      bs20997_weapon_header(scene);popup=current(scene)
      return unless popup && popup.prefix=='N' && popup.group && !popup.assignment && popup.transition.empty?
      scene.instance_variable_get(:@bs2s_palette_header).text=[popup.banner,'Цифра надеть · Shift+цифра / Enter атака · D последнее · N N снять · F7']
    end
  end
end
end

if defined?(BS2Suite::HDDisplay) && BS2Suite.enabled?('semantic_groups')
module BS2Suite::HDDisplay
  class << self
    alias bs20997_attack_palette_rows palette_rows
    def palette_rows(window)
      rows=bs20997_attack_palette_rows(window)
      rows<<row('D','Shift+Enter / Shift+цифра — обычная атака') if window.prefix=='N' && window.group && !window.assignment
      rows
    end
  end
end
end

# The heat-haze script moves the camera across the entire map to take tileset
# snapshots. Never expose these intermediate frames through the HD presenter.
if defined?(Heat_Haze)
module BS2Suite::MapCapture
  def self.pause(value)
    return unless defined?(BS2Suite::SteamBridge) && BS2Suite::SteamBridge.rendering?
    @pause ||= Win32API.new(File.join(BS2Suite::ROOT,'native','bs2_steam_bridge.dll'),'BS2_CapturePause',['I'],'I')
    @pause.call(value ? 1 : 0)
  end
end
class Heat_Haze
  alias bs20997_haze_create create_heat_haze
  def create_heat_haze
    x=$game_map.display_x;y=$game_map.display_y;brightness=Graphics.brightness
    BS2Suite::MapCapture.pause(true)
    begin
      bs20997_haze_create
    ensure
      $game_map.set_display_pos(x,y)
      @owner.tilemap.ox=x*32;@owner.tilemap.oy=y*32
      Graphics.brightness=brightness
      BS2Suite::MapCapture.pause(false)
    end
    # Wave processing only needs visible pixels. The original full-map bitmap
    # remains the source; the sprite owns this bounded viewport-sized buffer.
    @bs20997_crop=Bitmap.new(Graphics.width+16,Graphics.height+6)
    @heat_haze_sprite.bitmap=@bs20997_crop
    @bs20997_position=nil
    bs20997_crop
  end
  def bs20997_crop
    return unless @bs20997_crop && @heat_haze_sprite
    x=@owner.tilemap.ox;y=@owner.tilemap.oy
    if @bs20997_position!=[x,y]
      @bs20997_crop.clear
      @bs20997_crop.blt(0,0,$game_temp.heat_haze_bitmap,Rect.new(x-8,y,Graphics.width+16,Graphics.height+6))
      @bs20997_position=[x,y]
    end
    phase=@heat_haze_sprite.wave_phase-(@bs20997_y_phase || 0)
    @bs20997_y_phase=y*360.0/@heat_haze_sprite.wave_length
    @heat_haze_sprite.wave_phase=phase+@bs20997_y_phase
    @heat_haze_sprite.ox=8;@heat_haze_sprite.oy=3
  end
  alias bs20997_haze_update update
  def update
    bs20997_haze_update
    bs20997_crop
  end
  alias bs20997_haze_dispose dispose
  def dispose
    @heat_haze_sprite.wave_phase-=(@bs20997_y_phase || 0) if @heat_haze_sprite
    @bs20997_y_phase=0
    bs20997_haze_dispose
  ensure
    @bs20997_crop.dispose if @bs20997_crop && !@bs20997_crop.disposed?
    @bs20997_crop=nil
  end
end
end
