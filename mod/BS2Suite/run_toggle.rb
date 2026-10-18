# encoding: UTF-8
module BS2Suite::Run
  def self.active?;!!@active;end
  def self.toggle;@active=!@active;end
end
class Scene_Map
  alias bs2suite_run_update update
  def update
    bs2suite_run_update
    if BS2Suite::Options.get('run_mode')==1 && BS2Suite::Keys.trigger?(:run) && !$game_map.interpreter.running? && !$game_message.busy? && !scene_changing?
      BS2Suite::Run.toggle
    end
  end
end
class Game_Player
  alias bs2suite_original_dash dash?
  def dash?
    mode=BS2Suite::Options.get('run_mode')
    return bs2suite_original_dash if mode==0
    return false if @move_route_forcing || $game_map.disable_dash? || vehicle
    return false if $game_switches[MOVE_CONTROL::DASH_SEAL]
    mode==2 ? !Input.press?(:A) : BS2Suite::Run.active?
  end
end
