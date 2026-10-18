# encoding: UTF-8
module BS2Suite
  module Availability
    def self.cooldown(actor,item)
      return 0 unless actor && item.is_a?(RPG::Skill) && item.cool_time
      local=actor.instance_variable_get(:@bs2s_cooldowns)
      owner=actor.instance_variable_get(:@bs2s_origin_actor) || actor
      table=$game_temp.instance_variable_get(:@cool_time)
      local ||= table && table.has_key?(owner) ? table[owner] : {}
      [local.fetch(item.id,0),0].max
    end
  end
end
if BS2Suite.enabled?('semantic_groups')
module BS2Suite::Semantic
  class << self
    alias bs20992_stock_rows rows
    def rows(actor,prefix,group)
      rows=bs20992_stock_rows(actor,prefix,group)
      return rows unless prefix=='B'
      available=rows.reject { |r| r[:object].is_a?(RPG::Item) && $game_party.item_number(r[:object])<=0 }
      return available if customs[mode(actor)]
      available.each_with_index.map do |row,i|
        row=row.dup;row[:digit]=DIGITS[i,1].to_i;row[:address]='B'+DIGITS[group-1,1]+row[:digit].to_s;row
      end
    end
  end
end
class BS2Suite::PaletteWindow
  alias bs20992_cooldown_commands make_command_list
  def make_command_list
    bs20992_cooldown_commands
    @list.each do |line|
      row=line[:ext];next unless row
      count=BS2Suite::Availability.cooldown(@actor,row[:object])
      line[:name]+=' · КД '+count.to_s if count>0
    end
  end
end
module BS2Suite::ShortNotes
  class << self
    alias bs20992_cooldown_note for_row
    def for_row(row,prefix)
      text=bs20992_cooldown_note(row,prefix)
      scene=SceneManager.scene
      actor=scene.is_a?(Scene_Battle) ? BattleManager.actor : nil
      count=BS2Suite::Availability.cooldown(actor,row[:object])
      count>0 ? [text,'КД '+count.to_s].reject { |s| s.empty? }.join(' · ') : text
    end
  end
end
end
if BS2Suite.enabled?('saves')
module DataManager
  class << self
    alias bs20992_progress_header make_save_header
    def make_save_header
      head=bs20992_progress_header
      head[:bs2_progress]=$game_variables[11];head[:bs2_souls]=$game_party.gold
      parts=$game_party.members.map do |a|
        text=a.name+' ур. '+a.level.to_s
        text+=' · прогресс '+head[:bs2_progress].to_s+' · души '+head[:bs2_souls].to_s if a==$game_party.leader
        text
      end
      head[:bs2_party]=parts.join(' · ');head
    end
  end
end
end
# Only the original Gear of Madness common-event choices receive digit input.
# It uses the original choice handler, including cancel, and never selects SEN
# from the shortcut itself. Other game dialogues retain their native behavior.
class Game_Message
  attr_accessor :bs20992_gear_choices
  alias bs20992_gear_clear clear
  def clear
    bs20992_gear_clear;@bs20992_gear_choices=false
  end
end
class Game_Interpreter
  alias bs20992_gear_choices setup_choices
  def setup_choices(params)
    event=$data_common_events && $data_common_events[234]
    $game_message.bs20992_gear_choices=!!(event && @list.equal?(event.list))
    bs20992_gear_choices(params)
  end
end
class Window_ChoiceList
  alias bs20992_gear_choice_width max_choice_width
  def max_choice_width
    bs20992_gear_choice_width+($game_message.bs20992_gear_choices ? text_size('3  ').width : 0)
  end
  alias bs20992_gear_commands make_command_list
  def make_command_list
    bs20992_gear_commands
    @list.each_with_index { |line,i| line[:name]=(i+1).to_s+'  '+line[:name] } if $game_message.bs20992_gear_choices
  end
  alias bs20992_gear_handling process_handling
  def process_handling
    if active && open? && $game_message.bs20992_gear_choices && BS2QoL::Keyboard.focused? && (BS2QoL::Keyboard.raw_down & [16,17,18,91,92]).empty?
      key=BS2QoL::Keyboard.raw_fresh.find { |vk| (49..51).include?(vk) }
      if key && key-49<item_max
        select(key-49);BS2QoL::Keyboard.consume;process_ok;return
      end
    end
    bs20992_gear_handling
  end
end
class BS2Suite::SettingsScene
  alias bs20992_tempo_legend option
  def option(id,value)
    bs20992_tempo_legend(id,value)
    if id=='tempo_hint' && value==1
      @header.text=['Темп: полная звезда — первый враг; контур — также до ГГ',
        '? — возможен / не подтверждён; нет меток — ГГ. Союзники не учитываются.']
    end
  end
end
