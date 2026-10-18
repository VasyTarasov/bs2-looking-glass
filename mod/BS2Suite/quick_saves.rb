# encoding: UTF-8
module BS2Suite::QuickSaves
  FIRST=100
  COUNT=5
  def self.reason(scene)
    return 'только на карте' unless scene.is_a?(Scene_Map)
    return 'сохранение запрещено игрой' if $game_system.save_disabled
    return 'дождитесь завершения события' if $game_map.interpreter.running? || $game_message.busy? || $game_message.visible || $game_temp.common_event_reserved?
    return 'дождитесь остановки или перехода' if $game_player.moving? || $game_player.transfer? || $game_player.move_route_forcing || scene.scene_changing?
    return 'идёт бой' if $game_party.in_battle
    nil
  end
  def self.next_slot
    ids=(FIRST...FIRST+COUNT).to_a
    empty=ids.find { |i| !File.file?(DataManager.make_filename(i)) };return empty if empty
    cursor=BS2Suite::Store.read('quick_cursor').strip.to_i
    ids.sort_by { |i| [DataManager.savefile_time_stamp(i).to_f,(i-cursor)%COUNT] }.first
  end
  def self.save(scene)
    issue=reason(scene)
    if issue
      BS2QoL::Hotkeys.notice('Быстрое сохранение: '+issue);::Sound.play_buzzer;return false
    end
    index=next_slot
    if DataManager.save_game(index)
      BS2Suite::Store.write('quick_cursor',((index-FIRST+1)%COUNT+FIRST).to_s)
      BS2QoL::Hotkeys.notice('Быстрое сохранение '+(index-FIRST+1).to_s+'/5 записано');::Sound.play_save;true
    else
      BS2QoL::Hotkeys.notice('Сохранение не записано; прежний файл сохранён');::Sound.play_buzzer;false
    end
  end
end
module BS2Suite::Saves
  remove_const(:LIMIT)
  LIMIT=105
end
class BS2Suite::Saves::List
  alias bs2v2_save_draw draw_item
  def draw_item(index)
    bs2v2_save_draw(index)
    row=@rows[index];return unless row && row[:id]>=BS2Suite::QuickSaves::FIRST
    r=item_rect_for_text(index);contents.clear_rect(r.x,r.y,r.width,24)
    change_color(text_color(17));contents.font.size=20
    draw_text(r.x,r.y,r.width,24,'Быстрое '+(row[:id]-99).to_s+'/5 · '+BS2Suite::Saves.label(row[:id]))
  end
end
class Scene_File
  alias bs2v2_save_ok bs2suite_file_ok
  def bs2suite_file_ok
    if is_a?(Scene_Save) && @bs2_files.selected_row[:id]>=BS2Suite::QuickSaves::FIRST
      Sound.play_buzzer;@bs2_files.activate;return
    end
    bs2v2_save_ok
  end
end
class Scene_Save
  alias bs2v2_manual_first first_savefile_index
  def first_savefile_index
    index=bs2v2_manual_first
    return index if index<BS2Suite::QuickSaves::FIRST
    row=BS2Suite::Saves.rows(1).find { |r| r[:id]<BS2Suite::QuickSaves::FIRST }
    row ? row[:id] : 0
  end
end
class Scene_Map
  alias bs2v2_quick_update update
  def update
    bs2v2_quick_update
    BS2Suite::QuickSaves.save(self) if BS2Suite::Keys.trigger?(:quicksave)
  end
end
class Window_BS2SuiteNotice < Window_Base
  def initialize
    super(8,Graphics.height-64,Graphics.width-16,56);self.z=650;hide;@text=nil
  end
  def display(text)
    return if disposed?
    return hide unless text
    if @text!=text
      @text=text;contents.clear;contents.font.size=18
      draw_text(0,0,contents_width,line_height,BS2Modules.fit(self,text,contents_width))
    end
    show
  end
end
class Scene_Map
  alias bs2v3_notice_map_start start
  def start
    # SceneManager keeps this Scene_Map on its stack, then starts the same
    # instance again after a menu. Scene_Base already disposed its old windows.
    @bs2v2_notice=nil if @bs2v2_notice && @bs2v2_notice.disposed?
    bs2v3_notice_map_start
  end
  alias bs2v3_notice_map_terminate terminate
  def terminate
    bs2v3_notice_map_terminate
    @bs2v2_notice=nil
  end
  alias bs2v2_notice_map_update update
  def update
    bs2v2_notice_map_update
    return if scene_changing?
    @bs2v2_notice=nil if @bs2v2_notice && @bs2v2_notice.disposed?
    @bs2v2_notice ||= Window_BS2SuiteNotice.new if BS2QoL::Hotkeys.current_notice
    @bs2v2_notice.display(BS2QoL::Hotkeys.current_notice) if @bs2v2_notice
  end
end
