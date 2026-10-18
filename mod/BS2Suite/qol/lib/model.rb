# encoding: UTF-8
module BS2QoL
  VERSION = '0.8.0-alpha'.freeze
  KINDS = [:weapon, :item, :skill].freeze
  MAX_FAVORITES = 64

  module Preferences
    @lists = nil
    @error = nil
    class << self
      attr_reader :error
      def path
        File.join(Dir.pwd, 'BS2QoL', 'preferences.ini')
      end
      def parse(text)
        result = {:weapon => [], :item => [], :skill => []}
        text.to_s.each_line do |line|
          match = /\A(weapon|item|skill)=([0-9,]*)\s*\z/.match(line.strip)
          next unless match
          ids = match[2].split(',').map { |n| n.to_i }.select { |n| n > 0 && n < 100000 }
          result[match[1].to_sym] = ids.uniq.take(MAX_FAVORITES)
        end
        result
      end
      def lists
        return @lists if @lists
        @lists = parse('')
        if File.file?(path) && File.size(path) <= 32768
          @lists = parse(File.open(path,'rb') { |f| f.read })
        end
        @lists
      rescue StandardError
        @error = :read_failed
        @lists ||= parse('')
      end
      def ids(kind)
        (lists[kind] || []).dup
      end
      def favorite?(kind, id)
        (lists[kind] || []).include?(id)
      end
      def toggle(kind, id)
        return false unless KINDS.include?(kind) && id.is_a?(Integer) && id > 0
        list = lists[kind]
        if list.include?(id)
          list.delete(id)
        else
          return false if list.size >= MAX_FAVORITES
          list << id
        end
        persist
        true
      end
      def persist
        directory = File.dirname(path)
        Dir.mkdir(directory) unless File.directory?(directory)
        content = "version=1\n" + KINDS.map { |k| k.to_s+'='+lists[k].join(',') }.join("\n") + "\n"
        temporary = path+'.tmp'
        backup = path+'.bak'
        File.open(temporary,'wb') { |f| f.write(content); f.flush }
        if File.file?(path)
          old = File.open(path,'rb') { |f| f.read }
          File.open(backup,'wb') { |f| f.write(old) }
        end
        File.rename(temporary,path)
        @error = nil
        true
      rescue StandardError
        # Preferences remain usable in memory. Original game saves are unrelated.
        @error = :write_failed
        false
      end
    end
  end

  module Model
    def self.kind(object)
      return :skill if object.is_a?(RPG::Skill)
      return :item if object.is_a?(RPG::Item)
      return :weapon if object.is_a?(RPG::Weapon)
      nil
    end
    def self.database(kind)
      {:weapon => $data_weapons, :item => $data_items, :skill => $data_skills}[kind] || []
    end
    def self.favorites(kind)
      Preferences.ids(kind).map { |id| database(kind)[id] }.compact
    end
    def self.ordered(objects, only = false, kind = nil)
      return objects.dup unless BS2Suite.enabled?('combat_shortcuts')
      result = objects.dup
      result += favorites(kind) if only && kind
      result = result.uniq
      result = result.select { |o| o && self.kind(o) && Preferences.favorite?(self.kind(o),o.id) } if only
      result.each_with_index.sort_by do |object, index|
        type = self.kind(object)
        rank = type && Preferences.ids(type).index(object.id)
        [rank.nil? ? 1 : 0, rank || index, index]
      end.map { |pair| pair[0] }
    end
    def self.collection(kind, actor)
      case kind
      when :weapon
        values = $game_party.weapons.dup
        values << actor.equips[0] if actor && actor.equips[0].is_a?(RPG::Weapon)
      when :skill
        values = actor ? actor.skills : []
      else
        values = $game_party.items.select { |i| [0,1].include?(i.occasion) }
      end
      ordered(values + favorites(kind),false,kind)
    end
    def self.weapon_enabled?(actor, weapon)
      return false unless actor && weapon && actor.equip_command_usable
      old_flag = $game_temp.battle_equip
      begin
        $game_temp.battle_equip = true
        actor.equip_slots[0] == weapon.etype_id && actor.equip_change_ok?(0) && actor.equippable?(weapon) &&
          ($game_party.item_number(weapon) > 0 || actor.equips[0] == weapon)
      ensure
        $game_temp.battle_equip = old_flag
      end
    end
    def self.change_weapon(actor, weapon)
      return false unless weapon_enabled?(actor,weapon)
      old_flag = $game_temp.battle_equip
      begin
        $game_temp.battle_equip = true
        actor.change_equip(0,weapon)
        actor.equips[0] == weapon
      ensure
        $game_temp.battle_equip = old_flag
      end
    end
    def self.learned_book?(item, actor)
      return false unless item && actor
      ids = item.effects.select { |e| e.code == 43 }.map { |e| e.data_id }
      !ids.empty? && ids.all? { |id| $data_skills[id] && actor.skill_learn?($data_skills[id]) }
    end
    def self.queue(actor)
      return [] unless actor
      actor.actions.each_with_index.map do |action,index|
        object = action && action.item
        {:slot => index, :name => object ? object.name : '—',
         :target => action && action.target_index,
         :current => index == actor.instance_variable_get(:@action_input_index)}
      end
    end
  end

  # Shared extension for the native lists. Selection still uses native handlers.
  module ListControls
    attr_accessor :bs2q_only
    attr_accessor :bs2q_all_types
    def bs2q_supported?
      if is_a?(Window_EquipItem)
        return @actor && @slot_id && @actor.equip_slots[@slot_id] == 0
      end
      if self.class == Window_ItemList && @category
        return [:item,:weapon].include?(@category)
      end
      is_a?(Window_BattleItem) || is_a?(Window_BattleSkill) ||
        self.class == Window_ItemList || self.class == Window_SkillList
    end
    def bs2q_toggle
      object = item
      kind = Model.kind(object)
      return false unless kind
      if Preferences.toggle(kind,object.id)
        Sound.play_ok
        bs2q_refresh_selection(object)
      else
        Sound.play_buzzer
      end
      true
    end
    def bs2q_filter
      object = item
      @bs2q_only = !@bs2q_only
      Sound.play_cursor
      bs2q_refresh_selection(object)
    end
    def bs2q_refresh_selection(object)
      refresh
      position = @data && @data.index(object)
      select(position || (item_max > 0 ? 0 : -1))
      update_help
    end
    def bs2q_inputs
      return false unless open? && active && bs2q_supported?
      return true if defined?(Hotkeys) && Hotkeys.handle(self)
      return false unless BS2Suite.enabled?('combat_shortcuts')
      return bs2q_toggle if Input.trigger?(:X)
      if Input.trigger?(:Y)
        bs2q_filter
        return true
      end
      false
    end
    def bs2q_mark(index)
      return unless BS2Suite.enabled?('combat_shortcuts')
      object = @data && @data[index]
      kind = Model.kind(object)
      return unless kind && Preferences.favorite?(kind,object.id)
      rect = item_rect(index)
      color = text_color(17)
      contents.fill_rect(rect.x,rect.y,2,line_height,color)
    end
  end
end
