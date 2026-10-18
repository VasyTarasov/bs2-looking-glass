# encoding: UTF-8
module BS2Suite
  module ItemAutomation
    def self.route(window)
      return false unless defined?(BattleSupport) && Input.trigger?(:Z) && window.active && window.open? && window.visible
      scene=SceneManager.scene
      return true if scene.instance_variable_get(:@bs2094_d_frame)==Graphics.frame_count
      return false if (defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)) || scene.instance_variable_get(:@bs2080_effects)
      object=window.respond_to?(:item) && window.item
      item=object.is_a?(RPG::Item) && window.is_a?(Window_ItemList)
      gun=BattleSupport.gunbreak?(object) && window.is_a?(Window_SkillList)
      return false unless item || gun
      scene.instance_variable_set(:@bs2094_d_frame,Graphics.frame_count)
      actor=$game_party.in_battle ? BattleManager.actor : $game_party.menu_actor || $game_party.leader
      ok=BattleSupport.toggle_object(actor,object)
      ok ? ::Sound.play_ok : ::Sound.play_buzzer
      BS2QoL::Hotkeys.notice(ok ? 'Авто '+(BattleSupport.configured?(actor,object) ? 'включено: ' : 'выключено: ')+object.name : 'Авто недоступно: лечение, очищение и обычные предметы остаются ручными')
      BS2QoL::Keyboard.consume;true
    end
  end
end
class Window_Selectable
  alias bs2094_context_handling process_handling
  def process_handling
    return if defined?(BS2Suite::ContextEffects) && active && open? && visible && BS2Suite::ContextEffects.route(SceneManager.scene,self)
    return if BS2Suite::ItemAutomation.route(self)
    bs2094_context_handling
  end
end
# Several original scripts alias an inherited handler directly into a subclass;
# wrap those entry points too. The per-frame claim prevents double dispatch.
[Window_ItemList,Window_SkillList,Window_BattleEnemy,Window_BattleActor].each do |type|
  type.class_eval do
    alias_method :bs2094_list_handling, :process_handling
    define_method(:process_handling) do
      if active && open? && visible && defined?(BS2Suite::ContextEffects) && BS2Suite::ContextEffects.route(SceneManager.scene,self)
        return
      end
      return if BS2Suite::ItemAutomation.route(self)
      bs2094_list_handling
    end
  end
end
if BS2Suite.enabled?('semantic_groups')
class Scene_Battle
  alias bs2094_armed_start start
  def start
    bs2094_armed_start
    support=BS2Suite::BattleSupport
    actor=support.hero
    support.instance_variable_set(:@master,actor && !support.expand(actor).empty?)
  end
end
end
class BS2Suite::SettingsCommands
  alias bs2094_settings_list make_command_list
  def make_command_list
    bs2094_settings_list
    if BS2Suite.enabled?('semantic_groups')
      @list.insert(-2,{:name=>'Автопредметы: '+(BS2Suite::Options.get('experimental_support')==1 ? 'эксперимент · запас по темпу' : 'простое поддержание'),:symbol=>:experimental_support,:enabled=>true,:ext=>nil})
    end
  end
end
class BS2Suite::SettingsScene
  alias bs2094_settings_start start
  def start
    bs2094_settings_start
    @commands.set_handler(:experimental_support,lambda { option('experimental_support',BS2Suite::Options.get('experimental_support')==1 ? 0 : 1) })
  end
end

if defined?(BS2Suite::CombatEffects)
module BS2Suite
  module ContextEffects
    KEYS=[:@bs2q_reference_window,:@bs2q_reference_origin,:@bs2s_palette,:@bs2s_palette_header,:@bs2092_journal,:@bs2092_journal_header]
    def self.route(scene,origin=nil)
      return false unless scene.is_a?(Scene_Battle) && !scene.scene_changing? && Keys.trigger?(:combat_effects) && !$game_message.busy?
      return true if scene.instance_variable_get(:@bs2094_h_frame)==Graphics.frame_count
      scene.instance_variable_set(:@bs2094_h_frame,Graphics.frame_count)
      if scene.instance_variable_get(:@bs2080_effects)
        BS2QoL::Reference.close(scene,false) if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)
        CombatEffects.close(scene)
      else
        origin ||= scene.instance_variable_get(:@bs2q_reference_origin) || scene.instance_variable_get(:@actor_command_window)
        return false unless origin && !origin.disposed?
        saved={};windows=[]
        KEYS.each do |key|
          value=scene.instance_variable_get(key);saved[key]=value
          if value && value.respond_to?(:visible)
            windows<<value
            plate=value.instance_variable_get(:@plate);windows<<plate if plate
          end
          scene.instance_variable_set(key,nil)
        end
        states=windows.uniq.map { |w| [w,w.visible,w.respond_to?(:active) ? w.active : nil] }
        origin_active=origin.active
        states.each { |w,visible,active| w.visible=false;w.deactivate if w.respond_to?(:deactivate) }
        scene.instance_variable_set(:@bs2094_effects_frame,[saved,states,origin,origin_active])
        unless CombatEffects.open(scene,origin)
          restore(scene);return false
        end
      end
      BS2QoL::Keyboard.consume;true
    end
    def self.restore(scene)
      frame=scene.instance_variable_get(:@bs2094_effects_frame);return unless frame
      saved,states,origin,active=frame
      saved.each { |key,value| scene.instance_variable_set(key,value) }
      states.each do |window,visible,enabled|
        next if window.disposed?
        window.visible=visible;window.active=enabled unless enabled.nil?
      end
      origin.active=active unless origin.disposed?
      scene.instance_variable_set(:@bs2094_effects_frame,nil)
    end
  end
end
module BS2Suite::CombatEffects
  class << self
    alias bs2094_effects_close close
    def close(scene)
      bs2094_effects_close(scene)
      BS2Suite::ContextEffects.restore(scene)
    end
  end
end
class Scene_Battle
  alias bs2094_effects_wait update_for_wait
  def update_for_wait
    bs2094_effects_wait
    return unless BS2Suite::ContextEffects.route(self,@actor_command_window)
    while @bs2080_effects && !scene_changing?
      Graphics.update;Input.update
      if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(self)
        BS2QoL::Reference.update(self)
      elsif BS2Suite::Keys.trigger?(:combat_effects)
        BS2Suite::ContextEffects.route(self)
      elsif Input.trigger?(:B)
        BS2Suite::CombatEffects.close(self)
      else;@bs2080_effects.update;end
    end
  end
end
if defined?(BS2Suite::Palette)
module BS2Suite::Palette
  class << self
    alias bs2094_effects_palette update
    def update(scene)
      popup=current(scene)
      return if popup && BS2Suite::ContextEffects.route(scene,popup)
      bs2094_effects_palette(scene)
      update_header(scene) if current(scene) && !(defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene))
    end
  end
end
end
if defined?(BS2QoL::Reference)
module BS2QoL::Reference
  class << self
    alias bs2094_effects_reference update
    def update(scene)
      return if active?(scene) && BS2Suite::ContextEffects.route(scene)
      bs2094_effects_reference(scene)
    end
  end
end
end
if defined?(BS2Suite::JournalWindow)
class BS2Suite::JournalWindow
  alias bs2094_journal_handling process_handling
  def process_handling
    return if active && BS2Suite::ContextEffects.route(SceneManager.scene,self)
    bs2094_journal_handling
  end
end
end
end

if defined?(BS2Suite::HDDisplay)
module BS2Suite::HDDisplay
  class << self
    alias bs2094_hd_data data
    def data
      return @data if @data
      value=bs2094_hd_data
      if BS2Suite::Store.read('hd_display',4096).empty? && @monitor
        buffer=([0]*6).pack('l*')
        if @monitor.call(buffer)==6
          monitor=buffer.unpack('l*')
          @data=value.merge('width'=>monitor[1],'height'=>monitor[2],'mode'=>1,'filter'=>0)
        end
      end
      @data
    end
    def crisp_start
      return false if $bs2s_private_qa || BS2Suite::Options.get('crisp_hd')!=1 || dpi[7]!=1
      # Only the title, before any save is loaded. No registry or global display changes.
      return false unless SceneManager.scene.is_a?(Scene_Title)
      return false if @crisp_attempted || ENV['BS2_CRISP_RETRY']=='1'
      @crisp_attempted=true
      ENV['BS2_CRISP_RETRY']='1'
      restart_dpi
    end
    alias bs2094_context_source source_mode
    def source_mode(scene)
      bs2094_context_source(scene)
      frame=scene && scene.instance_variable_get(:@bs2094_effects_frame)
      frame[1].each { |window,visible,enabled| window.visible=false unless window.disposed? } if frame
    end
  end
end
class Scene_Title
  alias bs2094_crisp_title start
  def start
    bs2094_crisp_title
    BS2Suite::HDDisplay.crisp_start
  end
end
class BS2Suite::DisplayScene
  alias bs2094_fullscreen_start start
  def start
    bs2094_fullscreen_start
    @commands.set_handler(:fullscreen,lambda {
      hd=BS2Suite::HDDisplay;buffer=([0]*6).pack('l*');hd.instance_variable_get(:@monitor).call(buffer);m=buffer.unpack('l*')
      trial(hd.data.merge('width'=>m[1],'height'=>m[2],'mode'=>1))
    })
  end
end
end
