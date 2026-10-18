# encoding: UTF-8
# Skip presentation delays while Ctrl is held; never call process_action or
# battlers_frame_update extra times, and never synthesize a confirmation key.
module BS2Suite::BattleSpeed
  def self.held?
    BS2Suite::Options.get('instant_battle_ctrl')==1 && Input.press?(:CTRL) &&
      BS2QoL::Keyboard.focused?
  end
  def self.active?
    held? && (SceneManager.scene.is_a?(Scene_Battle) || @transition)
  end
  def self.transition
    old=@transition;@transition=true
    begin;yield;ensure;@transition=old;end
  end
  def self.returning;!!@returning;end
  def self.returning=(value);@returning=value;end
end

# Native hit-shake draws random offsets when a blink/collapse starts. Skipped
# visual frames can coalesce these effects; keep those draws off combat RNG
# in BOTH presentation modes, using the already separate visual stream.
module BS2Suite::VisualClock
  def self.cosmetic
    old=@inside;@inside=true
    begin;yield;ensure;@inside=old;end
  end
end

class Scene_Battle
  alias bs20994_wait wait
  def wait(duration)
    return if BS2Suite::BattleSpeed.active?
    bs20994_wait(duration)
  end
  alias bs20994_abs_wait abs_wait
  def abs_wait(duration)
    return if BS2Suite::BattleSpeed.active?
    bs20994_abs_wait(duration)
  end
  alias bs20994_show_animation show_animation
  def show_animation(targets,animation_id)
    return if BS2Suite::BattleSpeed.active?
    bs20994_show_animation(targets,animation_id)
  end
  alias bs20994_pre_terminate pre_terminate
  def pre_terminate
    BS2Suite::BattleSpeed.returning=SceneManager.scene_is?(Scene_Map)
    BS2Suite::BattleSpeed.transition { bs20994_pre_terminate }
  end
end

class Scene_Map
  alias bs20994_battle_transition perform_battle_transition
  def perform_battle_transition
    BS2Suite::BattleSpeed.transition { bs20994_battle_transition }
  end
  alias bs20994_map_transition perform_transition
  def perform_transition
    if BS2Suite::BattleSpeed.returning
      begin
        BS2Suite::BattleSpeed.transition { bs20994_map_transition }
      ensure
        BS2Suite::BattleSpeed.returning=false
      end
    else;bs20994_map_transition;end
  end
  alias bs20994_fade_loop fade_loop
  def fade_loop(duration,&block)
    bs20994_fade_loop(BS2Suite::BattleSpeed.active? ? 1 : duration,&block)
  end
end

module Graphics
  class << self
    alias bs20994_transition transition
    def transition(duration=10,filename='',vague=40)
      # Keep the native unfreeze even when the wipe has no visible frames.
      bs20994_transition(BS2Suite::BattleSpeed.active? ? 0 : duration,filename,vague)
    end
    alias bs20994_fadeout fadeout
    def fadeout(duration)
      bs20994_fadeout(BS2Suite::BattleSpeed.active? ? 1 : duration)
    end
    alias bs20994_fadein fadein
    def fadein(duration)
      bs20994_fadein(BS2Suite::BattleSpeed.active? ? 1 : duration)
    end
    alias bs20994_graphics_wait wait
    def wait(duration)
      bs20994_graphics_wait(BS2Suite::BattleSpeed.active? ? 1 : duration)
    end
  end
end

class Sprite_Battler
  alias bs20994_start_shake start_shake
  def start_shake(*args)
    if BS2Suite::BattleSpeed.active?;initialize_shake
    else;BS2Suite::VisualClock.cosmetic { bs20994_start_shake(*args) };end
  end
  alias bs20994_start_animation start_animation
  def start_animation(animation,mirror=false)
    return if BS2Suite::BattleSpeed.active?
    bs20994_start_animation(animation,mirror)
  end
  alias bs20994_update_animation update_animation
  def update_animation
    if BS2Suite::BattleSpeed.active? && animation?
      end_animation;@ani_duration=0
      flash(nil,0);viewport.flash(nil,0) if viewport
    else;bs20994_update_animation;end
  end
  alias bs20994_update_effect update_effect
  def update_effect
    if BS2Suite::BattleSpeed.active?
      @effect_duration=1 if @effect_duration.to_i>0
      initialize_shake if @shake_duration.any? { |n| n>0 } || @shake.any? { |n| n!=0 }
    end
    bs20994_update_effect
  end
  alias bs20994_damage damage
  def damage(value,critical=false)
    return if BS2Suite::BattleSpeed.active?
    bs20994_damage(value,critical)
  end
  alias bs20994_update_damage_pop update_damage_pop
  def update_damage_pop
    if BS2Suite::BattleSpeed.active?;dispose_damage
    else;bs20994_update_damage_pop;end
  end
end

class Window_Base
  alias bs20994_update_open update_open
  def update_open
    self.openness=255 if @opening && BS2Suite::BattleSpeed.active?
    bs20994_update_open
  end
  alias bs20994_update_close update_close
  def update_close
    self.openness=0 if @closing && BS2Suite::BattleSpeed.active?
    bs20994_update_close
  end
end

class Window_Message
  alias bs20994_message_wait wait
  def wait(duration)
    return if BS2Suite::BattleSpeed.active?
    bs20994_message_wait(duration)
  end
end

class Game_Screen
  alias bs20994_screen_update update
  def update
    if BS2Suite::BattleSpeed.active? && $game_troop && equal?($game_troop.screen)
      [:@fadeout_duration,:@fadein_duration,:@tone_duration,:@flash_duration,:@weather_duration].each do |key|
        instance_variable_set(key,1) if instance_variable_get(key).to_i>0
      end
      clear_shake
    end
    bs20994_screen_update
  end
end

class Game_Picture
  alias bs20994_picture_move update_move
  def update_move
    @duration=1 if @duration.to_i>0 && BS2Suite::BattleSpeed.active?
    bs20994_picture_move
  end
  alias bs20994_picture_tone update_tone_change
  def update_tone_change
    @tone_duration=1 if @tone_duration.to_i>0 && BS2Suite::BattleSpeed.active?
    bs20994_picture_tone
  end
end

class Game_Interpreter
  alias bs20994_event_wait wait
  def wait(duration)
    # Preserve a yield for scripted loops and input polling. Choice, forced-
    # action and other condition-based waits use their own native pipeline.
    bs20994_event_wait(BS2Suite::BattleSpeed.active? ? [duration,1].min : duration)
  end
end

class BS2Suite::SettingsCommands
  alias bs20994_speed_commands make_command_list
  def make_command_list
    bs20994_speed_commands
    row=@list.pop
    add_command('Ctrl в бою: '+(BS2Suite::Options.get('instant_battle_ctrl')==1 ? 'мгновенные анимации' : 'обычное ускорение'),:instant_battle_ctrl)
    @list << row
  end
end
class BS2Suite::SettingsScene
  alias bs20994_speed_settings start
  def start
    bs20994_speed_settings
    @commands.set_handler(:instant_battle_ctrl,lambda { option('instant_battle_ctrl',BS2Suite::Options.get('instant_battle_ctrl')==1 ? 0 : 1) })
  end
end
