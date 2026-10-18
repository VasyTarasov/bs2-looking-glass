# encoding: UTF-8
class Window_MenuCommand < Window_Command
  alias bs2modules_original_commands add_original_commands
  def add_original_commands
    bs2modules_original_commands
    add_command('Эффекты',:bs2modules_effects,main_commands_enabled) if BS2Modules.enabled?('effects')
    add_command('Комплекты',:bs2modules_loadouts,main_commands_enabled) if BS2Modules.enabled?('loadouts')
  end
end
class Scene_Menu < Scene_MenuBase
  alias bs2modules_create_commands create_command_window
  def create_command_window
    bs2modules_create_commands
    @command_window.set_handler(:bs2modules_effects,method(:bs2modules_effects)) if BS2Modules.enabled?('effects')
    @command_window.set_handler(:bs2modules_loadouts,method(:bs2modules_loadouts)) if BS2Modules.enabled?('loadouts')
  end
  def bs2modules_effects;SceneManager.call(BS2Modules::EffectsScene);end
  def bs2modules_loadouts;SceneManager.call(BS2Modules::LoadoutsScene);end
end
if BS2Modules.enabled?('effects')
  class Window_ActorCommand < Window_Command
    alias bs2modules_make_commands make_command_list
    def make_command_list
      bs2modules_make_commands
      add_command('Эффекты',:bs2modules_effects) if @actor
    end
  end
  class Scene_Battle < Scene_Base
    alias bs2modules_create_actor_commands create_actor_command_window
    def create_actor_command_window
      bs2modules_create_actor_commands
      @actor_command_window.set_handler(:bs2modules_effects,method(:bs2modules_effects))
    end
    def bs2modules_effects
      actor=BattleManager.actor
      return @actor_command_window.activate unless actor
      panel=BS2Modules::EffectsPanel.new(actor)
      # A modal input loop deliberately excludes all Scene_Battle updates.
      # Closing resumes the same command, queue, actor and target context.
      begin
        until panel.closed
          Graphics.update
          Input.update
          panel.update
        end
      ensure
        panel.dispose
        Input.update
        @actor_command_window.activate
      end
    end
  end
end
