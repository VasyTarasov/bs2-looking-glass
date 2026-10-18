# encoding: UTF-8
# Remove the map field shortcut; field skills remain in the normal menu.
BS2Suite::Keys::DEFAULT.delete(:field)
BS2Suite::Keys::LABELS.delete_at(15)

class Window_ActorCommand
  alias bs20991_actor_commands make_command_list
  def make_command_list
    bs20991_actor_commands
    @list.reject! { |row| row[:symbol]==:bs2092_journal }
  end
end

module BS2Suite
  # Cosmetic updates only. AP, state timers, troop events, costs and actions do
  # not run while a modal is open. Visual random draws use a separate stream.
  module VisualClock
    def self.modal?(scene)
      scene.is_a?(Scene_Battle) && [:@bs2s_palette,:@bs2q_reference_window,:@bs2080_effects,:@bs2092_journal,:@bs2092_enemy_chooser,:@bs2q_binding_window].any? { |k| scene.instance_variable_get(k) }
    end
    def self.active?;!!@inside;end
    def self.random;@random ||= Random.new(991);end
    def self.tick
      scene=SceneManager.scene
      return unless modal?(scene)
      return if scene.scene_changing?
      sprites=scene.instance_variable_get(:@spriteset)
      return unless sprites && !@inside
      @inside=true
      begin
        $game_troop.screen.update
        sprites.update
      ensure
        @inside=false
      end
    end
  end
end
module Kernel
  alias bs20991_game_rand rand
  def rand(*args)
    BS2Suite::VisualClock.active? ? BS2Suite::VisualClock.random.rand(*args) : bs20991_game_rand(*args)
  end
  private :rand
end
class Spriteset_Battle
  alias bs20991_sprites_update update
  def update
    return if @bs20991_drawing || @bs20991_frame==Graphics.frame_count
    @bs20991_frame=Graphics.frame_count;@bs20991_drawing=true
    begin;bs20991_sprites_update;ensure;@bs20991_drawing=false;end
  end
end
module Graphics
  class << self
    alias bs20991_visual_update update
    def update
      bs20991_visual_update
      BS2Suite::VisualClock.tick
    end
  end
end

if defined?(BS2Suite::QuickDamage)
module BS2Suite::QuickDamage
  class << self
    alias bs20991_area_calculate calculate
    def calculate(object,actor,source,targets,target,weapon)
      return bs20991_area_calculate(object,actor,source,targets,target,weapon) unless object.for_all? && targets.size>1
      view=source.is_a?(RPG::Weapon) ? BS2Suite::Projection.weapon(actor,source) : BS2Suite::Projection.copy(actor)
      index=actor.instance_variable_get(:@action_input_index).to_i
      action=Game_Action.new(actor)
      object.is_a?(RPG::Item) ? action.set_item(object.id) : action.set_skill(object.id)
      BS2Suite::DirectWeapons.copy_action_context(actor.actions[index],action,object)
      action.instance_variable_set(:@bs2s_normal_attack,true) if weapon
      actions=actor.actions.map { |a| a.dup };actions[index]=action;view.instance_variable_set(:@actions,actions)
      step=BS2Suite::SequenceForecast.new(view,BS2Suite::DirectWeapons.selected(actor)).steps[index]
      return ['~? · серия пока не рассчитана'] unless step && !step[:reason] && step[:rows].size==targets.size
      means=step[:rows].map { |r| r[:mean] }
      range=compact_means([means.min,means.max])
      [range+' по цели · Σ~'+means.inject(0.0) { |sum,n| sum+n }.round.to_s+' всего'+(step[:partial] ? ' · первое попадание' : '')]
    end
  end
end
end

module BS2Suite
  module NavigationAliases
    DEFAULT={'UP'=>'W','LEFT'=>'A','DOWN'=>'S','RIGHT'=>'Z'}.freeze
    def self.data
      return @data if @data
      @data=DEFAULT.dup
      Store.read('navigation',4096).each_line do |line|
        key,value=line.strip.split('=',2)
        @data[key]=value if DEFAULT.has_key?(key) && value.to_s=~/\A[A-Z]\z/ && @data.none? { |k,v| k!=key && v==value }
      end
      @data
    end
    def self.free?(key)
      BS2Suite::Keys.data.none? do |action,token|
        next false if [:X,:Y].include?(action) && token==BS2Suite::Keys::DEFAULT[action]
        token.split('+')[-1]==key
      end
    end
    def self.set(direction,key)
      return false unless DEFAULT.has_key?(direction) && key.to_s=~/\A[A-Z]\z/ && free?(key) && data.none? { |d,k| d!=direction && k==key }
      old=data.dup;data[direction]=key
      return true if Store.write('navigation',data.map { |k,v| k+'='+v }.join("\n")+"\n")
      @data=old;false
    end
    def self.context?
      return false unless BS2Suite.enabled?('controls') && Options.get('navigation_aliases')==1
      scene=SceneManager.scene
      return false unless scene.is_a?(Scene_Map) || scene.is_a?(Scene_Battle)
      if scene.is_a?(Scene_Map)
        return !$game_message.busy? && !$game_map.interpreter.running? && !scene.scene_changing?
      end
      popup=scene.instance_variable_get(:@bs2s_palette)
      return false if popup && (popup.prefix=='B' || popup.assignment)
      item=scene.instance_variable_get(:@item_window)
      !(item && item.active && item.open?)
    end
    def self.code(action)
      return nil unless context? && DEFAULT.has_key?(action.to_s)
      key=data[action.to_s];free?(key) ? BS2Suite::Keys::BASE[key] : nil
    end
    def self.sample
      @holds ||= {};return if @frame==Graphics.frame_count
      @frame=Graphics.frame_count
      DEFAULT.keys.each do |name|
        vk=code(name.to_sym)
        down=vk && BS2QoL::Keyboard.focused? && (BS2QoL::Keyboard.raw_down & [17,18,91,92]).empty? && BS2QoL::Keyboard.raw_down.include?(vk)
        @holds[name]=down ? @holds.fetch(name,0)+1 : 0
      end
    end
    def self.held(action)
      return 0 unless code(action)
      sample;(@holds || {})[action.to_s].to_i
    end
    def self.claimed?(action)
      return false unless [:X,:Y].include?(action) && context?
      vk=BS2Suite::Keys::BASE[BS2Suite::Keys.token(action)]
      DEFAULT.keys.any? { |dir| code(dir.to_sym)==vk }
    end
  end
end
module Input
  class << self
    alias bs20991_alias_trigger trigger?
    alias bs20991_alias_press press?
    alias bs20991_alias_repeat repeat?
    def trigger?(action)
      return false if BS2Suite::NavigationAliases.claimed?(action)
      code=BS2Suite::NavigationAliases.code(action)
      (code && BS2Suite::NavigationAliases.held(action)==1 && BS2QoL::Keyboard.raw_fresh.include?(code)) || bs20991_alias_trigger(action)
    end
    def press?(action)
      return false if BS2Suite::NavigationAliases.claimed?(action)
      BS2Suite::NavigationAliases.held(action)>0 || bs20991_alias_press(action)
    end
    def repeat?(action)
      return false if BS2Suite::NavigationAliases.claimed?(action)
      n=BS2Suite::NavigationAliases.held(action)
      trigger?(action) || (n>=24 && n%6==0) || bs20991_alias_repeat(action)
    end
  end
end

BS2Suite::Options::DEFAULTS.merge!('navigation_aliases'=>1,'adaptive_priority'=>0,'priority_window'=>20,'tempo_hint'=>0)
BS2Suite::Options::DEFAULTS.each { |key,value| BS2Suite::Options.data[key]=value unless BS2Suite::Options.data.has_key?(key) }
class BS2Suite::SettingsCommands
  alias bs20991_settings_commands make_command_list
  def make_command_list
    bs20991_settings_commands
    @list.insert(-2,{:name=>'Альтернатива W/A/S/Z: '+(BS2Suite::Options.get('navigation_aliases')==1 ? 'вкл' : 'выкл'),:symbol=>:navigation_aliases,:enabled=>true,:ext=>nil})
    @list.insert(-2,{:name=>'Клавиши альтернативной навигации…',:symbol=>:navigation_keys,:enabled=>true,:ext=>nil})
    if BS2Suite.enabled?('semantic_groups')
      @list.insert(-2,{:name=>'Приоритеты V/M/N (эксп.): '+(BS2Suite::Options.get('adaptive_priority')==1 ? 'вкл' : 'выкл'),:symbol=>:adaptive_priority,:enabled=>true,:ext=>nil})
      @list.insert(-2,{:name=>'История приоритетов: '+BS2Suite::Options.get('priority_window').to_s+' боёв',:symbol=>:priority_window,:enabled=>true,:ext=>nil})
    end
    @list.insert(-2,{:name=>'Подсказка темпа противников: '+(BS2Suite::Options.get('tempo_hint')==1 ? 'вкл' : 'выкл'),:symbol=>:tempo_hint,:enabled=>true,:ext=>nil})
  end
end
class BS2Suite::SettingsScene
  alias bs20991_settings_start start
  def start
    bs20991_settings_start
    %w(navigation_aliases adaptive_priority tempo_hint).each { |id| @commands.set_handler(id.to_sym,lambda { option(id,BS2Suite::Options.get(id)==1 ? 0 : 1) }) }
    @commands.set_handler(:priority_window,lambda {
      sizes=[5,10,20,30];i=sizes.index(BS2Suite::Options.get('priority_window')) || 2
      option('priority_window',sizes[(i+1)%sizes.size])
    })
    @commands.set_handler(:navigation_keys,lambda { SceneManager.call(BS2Suite::NavigationKeysScene) })
  end
end
class BS2Suite::NavigationKeyCommands < Window_Command
  def window_width;Graphics.width;end
  def make_command_list
    names={'UP'=>'Вверх','LEFT'=>'Влево','DOWN'=>'Вниз','RIGHT'=>'Вправо'}
    BS2Suite::NavigationAliases::DEFAULT.keys.each { |dir| add_command(names[dir]+': '+BS2Suite::NavigationAliases.data[dir],dir.to_sym) }
    add_command('Назад',:cancel)
  end
end
class BS2Suite::NavigationKeysScene < Scene_MenuBase
  def start
    super;@header=BS2Modules::Header.new;@header.text=['Альтернативная навигация','Карта и бой; предметные списки исключены. Enter изменить · Esc назад']
    @commands=BS2Suite::NavigationKeyCommands.new(0,72);BS2Modules.style(@commands)
    @commands.set_handler(:cancel,method(:return_scene))
    BS2Suite::NavigationAliases::DEFAULT.keys.each { |dir| @commands.set_handler(dir.to_sym,lambda { capture(dir) }) }
  end
  def capture(direction)
    @commands.deactivate
    begin
      loop do
        Graphics.update;Input.update
        break if Input.trigger?(:B)
        key=BS2Suite::Keys.capture;next unless key
        BS2Suite::NavigationAliases.set(direction,key) ? ::Sound.play_ok : ::Sound.play_buzzer
        break
      end
    ensure
      BS2QoL::Keyboard.consume;@commands.refresh;@commands.activate
    end
  end
end
