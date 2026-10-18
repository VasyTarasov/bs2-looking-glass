# encoding: UTF-8
# Only events observed in the current fight. No inspection of enemy action lists.
module BS2Suite
  module CombatJournal
    LIMIT=400
    class << self
      def entries;@entries ||= [];end
      def reset;@entries=[];end
      def append(user,item,target=nil,result=nil)
        return unless $game_party && $game_party.in_battle && item
        row={:turn=>$game_troop.turn_count,:user=>BattleRecord.label(user),:target=>target && BattleRecord.label(target),
          :kind=>item.is_a?(RPG::Skill) ? :skill : :item,:id=>item.id,:name=>item.name,:hit=>item.respond_to?(:hit_type) ? item.hit_type : 0}
        if result
          row[:hp]=result.hp_damage;row[:mp]=result.mp_damage
          row[:miss]=result.missed || result.evaded;row[:critical]=result.critical
          row[:states]=result.added_states.map { |id| $data_states[id] && $data_states[id].name }.compact
        end
        entries<<row;entries.shift while entries.size>LIMIT
      end
      def object(row);return nil unless row;row[:kind]==:skill ? $data_skills[row[:id]] : $data_items[row[:id]];end
      def summary(row)
        type=['Особое попадание','Физ. попадание','Маг. попадание'][row[:hit]] || 'Особое попадание'
        details=if row[:miss];'промах / уклонение'
        elsif row.has_key?(:hp)
          values=[];values<<'HP '+(-row[:hp]).to_s if row[:hp]!=0;values<<'MP '+(-row[:mp]).to_s if row[:mp]!=0
          values<<'крит' if row[:critical];values+=(row[:states] || []);values.empty? ? 'без изменения HP/MP' : values.join(' · ')
        else;'применено';end
        [row[:user]+' → '+(row[:target] || 'применение')+' · '+row[:name],type+' · '+details]
      end
      def open(scene,origin)
        return false unless origin && !origin.disposed?
        origin.deactivate
        window=JournalWindow.new
        header=BS2Modules::Header.new;header.z=475;header.text=['Журнал боя','↑/↓ записи · Enter / F7 атака · F5 / Esc назад']
        scene.instance_variable_set(:@bs2092_journal_header,header)
        window.set_handler(:cancel,lambda { close(scene) })
        scene.instance_variable_set(:@bs2092_journal,window)
        scene.instance_variable_set(:@bs2092_journal_origin,origin)
        BS2QoL::Keyboard.consume;true
      end
      def close(scene,restore=true)
        window=scene.instance_variable_get(:@bs2092_journal);window.dispose if window && !window.disposed?
        header=scene.instance_variable_get(:@bs2092_journal_header);header.dispose if header && !header.disposed?
        scene.instance_variable_set(:@bs2092_journal_header,nil)
        origin=scene.instance_variable_get(:@bs2092_journal_origin)
        origin.activate if restore && origin && !origin.disposed?
        scene.instance_variable_set(:@bs2092_journal,nil)
        BS2QoL::Keyboard.consume;Input.update
      end
      def details(scene)
        window=scene.instance_variable_get(:@bs2092_journal);object=window && window.item
        return ::Sound.play_buzzer unless object && BS2Suite.enabled?('reference_cards')
        # No actor projection: historical enemy formulas must not be presented as the hero's forecast.
        reference=Window_BS2QReference.new(object,nil)
        window.deactivate
        scene.instance_variable_set(:@bs2q_reference_window,reference)
        scene.instance_variable_set(:@bs2q_reference_origin,window)
        BS2QoL::Keyboard.consume
      end
    end
  end
  class JournalWindow < Window_Selectable
    attr_reader :rows
    def initialize
      @rows=CombatJournal.entries.reverse.dup
      super(8,64,Graphics.width-16,Graphics.height-72)
      self.z=470;BS2Modules.style(self);refresh;select(0);activate
    end
    def item_max;[@rows.size,1].max;end
    def item_height;52;end
    def item;CombatJournal.object(@rows[index]);end
    def refresh;create_contents;BS2Modules.style(self);draw_all_items;end
    def draw_item(index)
      rect=item_rect_for_text(index);row=@rows[index]
      unless row;draw_text(rect,'Журнал пуст · F5 / Esc закрыть');return;end
      lines=CombatJournal.summary(row);contents.font.size=17
      draw_text(rect.x,rect.y,rect.width,24,BS2Modules.fit(self,lines[0],rect.width))
      change_color(system_color);contents.font.size=15
      draw_text(rect.x,rect.y+24,rect.width,24,BS2Modules.fit(self,lines[1],rect.width));change_color(normal_color)
    end
    def process_handling
      return unless open? && active
      if Input.trigger?(:B);process_cancel
      elsif BS2QoL::Keyboard.first=='F7' || Input.trigger?(:C);CombatJournal.details(SceneManager.scene)
      end
    end
  end
end
module BattleManager
  class << self
    alias bs2092_journal_setup setup
    def setup(*args);BS2Suite::CombatJournal.reset;bs2092_journal_setup(*args);end
  end
end
class Game_Battler
  alias bs2092_journal_apply item_apply
  def item_apply(user,item)
    result=bs2092_journal_apply(user,item)
    BS2Suite::CombatJournal.append(user,item,self,self.result)
    result
  end
end
class Scene_Battle
  alias bs2092_journal_update update
  def update
    if @bs2092_journal
      Graphics.update;Input.update
      if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(self)
        BS2QoL::Reference.update(self)
      elsif BS2Suite::Keys.trigger?(:stats) || Input.trigger?(:B)
        BS2Suite::CombatJournal.close(self)
      else;@bs2092_journal.update;end
      return
    end
    bs2092_journal_update
  end
  alias bs2092_journal_terminate terminate
  def terminate
    if @bs2092_journal
      BS2QoL::Reference.close(self,false) if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(self)
      BS2Suite::CombatJournal.close(self,false)
    end
    bs2092_journal_terminate
  end
end
module BS2QoL::Hotkeys
  class << self
    alias bs2092_journal_handle handle
    def handle(window)
      scene=SceneManager.scene
      if scene.is_a?(Scene_Battle)
        return true if scene.instance_variable_get(:@bs2092_journal)
        if BS2Suite::Keys.trigger?(:stats) && !scene.instance_variable_get(:@bs2s_palette) && !scene.instance_variable_get(:@bs2080_effects) && !(defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)) && !$game_message.busy?
          return BS2Suite::CombatJournal.open(scene,window)
        end
      end
      bs2092_journal_handle(window)
    end
  end
end
class Window_ActorCommand
  alias bs2092_journal_commands make_command_list
  def make_command_list
    bs2092_journal_commands
    add_command([BS2Suite::Keys.token(:stats)+' Журнал',125],:bs2092_journal) if @actor
  end
end
class Scene_Battle
  alias bs2092_journal_actor_window create_actor_command_window
  def create_actor_command_window
    bs2092_journal_actor_window
    @actor_command_window.set_handler(:bs2092_journal,lambda { BS2Suite::CombatJournal.open(self,@actor_command_window) })
  end
end

# Opening the journal during window updates must also stop the rest of that same native frame.
class Scene_Battle
  alias bs2092_journal_process_action process_action
  def process_action
    return if @bs2092_journal
    bs2092_journal_process_action
  end
  alias bs2092_journal_process_event process_event
  def process_event
    return if @bs2092_journal
    bs2092_journal_process_event
  end
end
