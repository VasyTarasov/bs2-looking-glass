# encoding: UTF-8
module BS2Suite
  module Performance
    attr_reader :revision
    def self.bump;@revision=(@revision || 0)+1;end
    def self.reset
      @cache={};@costs={};@pending=nil;@context=nil;@revision=(@revision || 0)+1
    end
    def self.now
      @clock ||= Win32API.new('kernel32','GetTickCount',[],'L');@clock.call
    end
    def self.context(actor)
      return nil unless actor
      [@revision,actor.id,actor.level,actor.class_id,actor.hp,actor.mp,actor.tp,actor.equips.map { |e| e && [e.class.to_s,e.id] },
       actor.instance_variable_get(:@states).hash,actor.instance_variable_get(:@state_turns).hash,actor.instance_variable_get(:@buffs).hash,actor.instance_variable_get(:@buff_turns).hash,
       actor.actions.map { |a| [a.item && a.item.class.to_s,a.item && a.item.id,a.target_index,a.forcing,a.instance_variable_get(:@bs2s_direct_count),a.instance_variable_get(:@bs2s_normal_attack)] },
       actor.instance_variable_get(:@action_input_index),defined?(BS2Suite::DirectWeapons) && BS2Suite::DirectWeapons.selected_id(actor),
       $game_party.gold,$game_troop.members.map { |e| [e.index,e.hp,e.mp,e.hidden?,e.instance_variable_get(:@states).hash,e.instance_variable_get(:@state_turns).hash,e.instance_variable_get(:@buffs).hash,e.instance_variable_get(:@buff_turns).hash] },
       Options.get('knowledge_threshold'),Options.get('palette_notes'),Options.get('weapon_notes')]
    end
    def self.mp_cost(actor,object,source=nil)
      @costs ||= {};key=[context(actor),object.id,source && source.id]
      return @costs[key] if @costs.has_key?(key)
      @costs.clear if @costs.size>128
      view=source.is_a?(RPG::Weapon) ? BS2Suite::Projection.weapon(actor,source) : actor
      @costs[key]=view.skill_mp_cost(object)
    end
    def self.deferred?;!!@deferred;end
    def self.defer
      previous=@deferred;@deferred=true
      begin;yield;ensure;@deferred=previous;end
    end
    def self.pending?;!!@pending;end
    def self.cancel_pending;@pending=nil if deferred?;end
    def self.forecast(key)
      @cache ||= {}
      return @cache[key] if @cache.has_key?(key)
      if deferred?
        now=now()
        if !@pending || @pending[0]!=key
          @pending=[key,now];return ['≈ …']
        end
        return ['≈ …'] if ((now-@pending[1])&0xffffffff)<120
        # Navigation keeps priority over a heavy, previously unseen forecast.
        navigation=[37,38,39,40,81,69]+BS2Suite::NavigationAliases.data.values.map { |k| BS2Suite::Keys::BASE[k] }
        return ['≈ …'] if (BS2QoL::Keyboard.raw_down & navigation).any?
      end
      value=yield
      @pending=nil if @pending && @pending[0]==key
      @cache.shift while @cache.size>=128
      @cache[key]=value
    end
  end
end
module DataManager
  class << self
    alias bs20991_loaded_context extract_save_contents
    def extract_save_contents(contents)
      value=bs20991_loaded_context(contents);BS2Suite::Performance.reset;value
    end
  end
end
class Game_BattlerBase
  alias bs20991_live_refresh refresh
  def refresh
    bs20991_live_refresh
    BS2Suite::Performance.bump unless instance_variable_get(:@bs2s_projection)
  end
end
class Game_Party
  alias bs20991_stock gain_item
  def gain_item(*args)
    value=bs20991_stock(*args);BS2Suite::Performance.bump;value
  end
end
[Game_Variables,Game_Switches].each do |type|
  type.class_eval do
    alias_method :bs20991_variable_set,:[]=
    define_method(:[]=) do |id,value|
      before=self[id];result=bs20991_variable_set(id,value)
      BS2Suite::Performance.bump if self[id]!=before
      result
    end
  end
end
module BattleManager
  class << self
    alias bs20991_performance_setup setup
    def setup(*args)
      BS2Suite::Performance.reset;bs20991_performance_setup(*args)
    end
  end
end
class BS2Modules::Header
  alias bs20991_cached_text text=
  def text=(lines)
    bindings=BS2Suite::Keys.data.hash
    key=[contents.object_id,contents.width,contents.height,bindings,lines]
    return if @bs20991_text==key
    @bs20991_text=[contents.object_id,contents.width,contents.height,bindings,lines.map { |s| s.to_s.dup }]
    bs20991_cached_text(lines)
  end
end
if defined?(BS2Suite::Palette)
module BS2Suite::Palette
  class << self
    alias bs20991_cached_header update_header
    def update_header(scene)
      window=current(scene);return unless window
      key=[window.object_id,window.index,window.group,window.prefix,window.transition.hash,scene.instance_variable_get(:@bs2s_pending),BS2Suite::Keys.data.hash,BS2Suite::Performance.context(window.actor)]
      return if scene.instance_variable_get(:@bs20991_header_key)==key
      scene.instance_variable_set(:@bs20991_header_key,key)
      bs20991_cached_header(scene)
    end
  end
end
end
if defined?(BS2Suite::QuickDamage)
module BS2Suite::QuickDamage
  class << self
    alias bs20991_cached_lines lines
    def lines(scene,object,actor,source=nil,target=nil,weapon=nil)
      unless object && actor && $game_party.in_battle && object.respond_to?(:damage) && object.damage.to_hp? && !object.damage.recover? && object.for_opponent?
        BS2Suite::Performance.cancel_pending;return []
      end
      key=[BS2Suite::Performance.context(actor),object.class.to_s,object.id,source && source.id,target && target.index,weapon && weapon.id]
      BS2Suite::Performance.forecast(key) { bs20991_cached_lines(scene,object,actor,source,target,weapon) }
    end
  end
end
end
if defined?(BS2Suite::HDDisplay)
module BS2Suite::HDDisplay
  class << self
    alias bs20991_cached_palette palette_rows
    def palette_rows(window)
      key=[window.object_id,window.prefix,window.group,window.index,window.transition.hash,window.assignment && window.assignment.id,BS2Suite::Performance.context(window.actor),status.values_at(6,7,5),BS2Suite::Performance.pending? ? BS2Suite::Performance.now/120 : 0]
      return @bs20991_palette_rows if @bs20991_palette_key==key
      @bs20991_palette_rows=BS2Suite::Performance.defer { bs20991_cached_palette(window) }
      @bs20991_palette_key=key
      @bs20991_palette_rows
    end
    alias bs20991_deferred_battle battle_rows
    def battle_rows(scene)
      BS2Suite::Performance.defer { bs20991_deferred_battle(scene) }
    end
  end
end
end
