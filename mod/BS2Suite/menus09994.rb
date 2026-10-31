# encoding: UTF-8
module BS2Suite
  # Input-only scene state. A remembered menu never owns an action or a target,
  # pays a cost, or resumes while the native turn is executing.
  module BattleMenus
    def self.palette(window)
      {:type=>:palette,:prefix=>window.prefix,:group=>window.group,:page=>window.page,
       :object=>ActionContext.object_key(window.item),:entry=>window.entry && window.entry.dup,:index=>window.index,:top=>window.top_row}
    end
    def self.native(window,kind)
      {:type=>kind,:object=>ActionContext.object_key(window.item),:index=>window.index,:top=>window.top_row,
       :stype=>window.instance_variable_get(:@stype_id),:only=>window.instance_variable_get(:@bs2q_only),:all=>window.instance_variable_get(:@bs2q_all_types)}
    end
    def self.entry_key(row,page=0)
      row && [row[:prefix],row[:group],page,row[:digit],ActionContext.object_key(row[:object]),ActionContext.object_key(row[:source])]
    end
    def self.selection(window,record)
      if defined?(BS2Suite::PaletteWindow) && window.is_a?(BS2Suite::PaletteWindow) && record[:entry]
        key=entry_key(record[:entry],record[:page])
        index=window.entries.index { |row| entry_key(row,window.page)==key }
      else
        values=window.instance_variable_get(:@data)
        index=(values || []).index { |o| ActionContext.object_key(o)==record[:object] }
      end
      index=record[:object] ? -1 : [[record[:index].to_i,window.item_max-1].min,0].max if index.nil?
      window.select(window.item_max>0 ? index : -1)
      window.top_row=record[:top].to_i
      window.ensure_cursor_visible
      window.update_help if window.instance_variable_get(:@help_window)
    end
    def self.favorite_hint(window)
      obj=window && window.item;kind=BS2QoL::Model.kind(obj)
      return '' unless kind
      selected=BS2QoL::Preferences.favorite?(kind,obj.id)
      BS2Suite::Keys.token(:X)+' — '+(selected ? 'убрать из избранного' : 'в избранное')+' · '+BS2Suite::Keys.token(:Y)+' — фильтр избранного'
    end
    def self.cancel(scene,window)
      command=scene.instance_variable_get(:@actor_command_window)
      # The command window opens gradually after closing a palette. Its opening
      # animation must not swallow the second physical cancel press.
      ready=window.open? || (window.equal?(command) && window.openness>0)
      return false unless window.active && ready && Input.trigger?(:B)
      return false unless BS2Suite.enabled?('semantic_groups') || BS2Suite.enabled?('action_queue')
      actor=BattleManager.actor
      return false unless actor && actor.input && !BattleManager.in_turn?
      return false if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)
      palette=defined?(BS2Suite::Palette) && BS2Suite::Palette.current(scene)
      macro=scene.instance_variable_get(:@bs2s_macros)
      hd_menu=(window.equal?(palette) || window.equal?(macro)) && defined?(BS2Suite::HDDisplay) && BS2Suite::HDDisplay.active?
      return false unless window.visible || hd_menu
      native=[:@actor_command_window,:@skill_window,:@item_window,:@enemy_window,:@actor_window].any? { |k| scene.instance_variable_get(k).equal?(window) }
      return false unless native || window.equal?(palette) || window.equal?(macro)
      return true if scene.instance_variable_get(:@bs2s_cancel_frame)==Graphics.frame_count
      scene.instance_variable_set(:@bs2s_cancel_frame,Graphics.frame_count)
      now=BS2Suite::Performance.now;last=scene.instance_variable_get(:@bs2s_cancel_stamp)
      if last && last[0]==actor.id && ((now-last[1])&0xffffffff)<=550 && actor.actions.any? { |a| a.item }
        scene.bs2s_forget_menu(actor)
        BS2Suite::Palette.close(scene,false) if palette
        BS2Suite::Macros.close(scene,false) if macro && defined?(BS2Suite::Macros)
        scene.bs2s_hide_selection
        scene.instance_variable_set(:@bs2s_macro_targeting,false);scene.instance_variable_set(:@bs2s_macro_pending,nil)
        scene.instance_variable_set(:@bs2s_cancel_stamp,nil);scene.instance_variable_set(:@bs20999_cancel_time,nil)
        BS2Suite::QueueEdit.cancel(scene,actor)
      else
        scene.instance_variable_set(:@bs2s_cancel_stamp,[actor.id,now])
        if window.equal?(palette)
          BS2Suite::Palette.close(scene);::Sound.play_cancel
        else
          scene.instance_variable_set(:@bs20999_cancel_time,nil) if window.equal?(scene.instance_variable_get(:@actor_command_window))
          window.process_cancel
        end
      end
      BS2QoL::Keyboard.consume;true
    end
  end
end

class Scene_Battle
  def bs2s_remember_menu(record)
    actor=BattleManager.actor;return unless actor
    @bs2s_menu_memory ||= {};@bs2s_menu_memory[actor.id]=record
    @bs2s_cancel_stamp=nil
  end
  def bs2s_forget_menu(actor=BattleManager.actor)
    @bs2s_menu_memory.delete(actor.id) if actor && @bs2s_menu_memory
    @bs2s_support_boundary=nil if actor && @bs2s_support_boundary==actor.id
  end
  def bs2s_hide_selection
    [:@skill_window,:@item_window,:@enemy_window,:@actor_window].each do |key|
      window=instance_variable_get(key)
      if window
        window.hide if window.visible
        window.deactivate
      end
    end
    @help_window.hide if @help_window
  end
  def bs2s_restore_menu
    return if @bs2s_restoring_menu || @bs2s_menu_selecting.to_i>0 || scene_changing? || BattleManager.in_turn?
    actor=BattleManager.actor;record=actor && @bs2s_menu_memory && @bs2s_menu_memory[actor.id]
    return unless record && actor.alive? && actor.inputable? && actor.input && !actor.input.item
    return if $game_message.busy? || HZM_VXA::QuickSkill.quickSkill?
    return if [:@enemy_window,:@actor_window].any? { |k| w=instance_variable_get(k);w && w.active && w.visible }
    return if @bs2s_macros || (defined?(BS2Suite::Palette) && BS2Suite::Palette.current(self))
    return if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(self)
    @bs2s_restoring_menu=true
    bs2s_hide_selection
    if @bs2s_support_boundary==actor.id
      @bs2s_support_boundary=nil
      BS2Suite::BattleSupport.before_menu(self) if defined?(BS2Suite::BattleSupport)
      return if scene_changing? || BattleManager.in_turn? || BattleManager.actor!=actor || !actor.inputable? || !actor.input || actor.input.item
    end
    if record[:type]==:palette
      BS2Suite::Palette.open(self,@actor_command_window,actor,record[:prefix])
      window=BS2Suite::Palette.current(self)
      window.instance_variable_set(:@bs2s_repeat_entry,record[:entry])
      window.instance_variable_set(:@bs2s_repeat_index,record[:index])
      window.instance_variable_set(:@bs2s_repeat_context,[record[:prefix],record[:group],record[:page]])
      if record[:group]
        window.set_group(record[:group]);window.instance_variable_set(:@page,record[:page]);window.refresh
      end
      BS2Suite::BattleMenus.selection(window,record);BS2Suite::Palette.update_header(self)
    else
      window=record[:type]==:item ? @item_window : @skill_window
      if record[:type]==:skill
        window.actor=actor;window.stype_id=record[:stype]
      end
      window.instance_variable_set(:@bs2q_only,record[:only]);window.instance_variable_set(:@bs2q_all_types,record[:all])
      if record[:type]==:item
        item=record[:object] && $data_items[record[:object][1]]
        window.instance_variable_set(:@bs2s_repeat_item,item && {:object=>item,:index=>record[:index]})
      end
      window.instance_variable_set(:@bs2s_repeat_restoring,true)
      begin;window.refresh
      ensure;window.instance_variable_set(:@bs2s_repeat_restoring,false);end
      BS2Suite::BattleMenus.selection(window,record)
      @actor_command_window.deactivate;window.show.activate;@help_window.show
    end
    BS2QoL::Keyboard.consume
  ensure
    @bs2s_restoring_menu=false
  end
  alias bs209994_menu_ready start_actor_command_selection
  def start_actor_command_selection
    bs209994_menu_ready
    actor=BattleManager.actor
    unless defined?(BS2Suite::BattleSupport) && BS2Suite::BattleSupport.busy?
      @bs2s_support_boundary=actor && @bs2s_menu_memory && @bs2s_menu_memory[actor.id] && !@bs2s_target_cancelling ? actor.id : nil
    end
    bs2s_restore_menu
  end
  alias bs209994_menu_next next_command
  def next_command
    @bs2s_cancel_stamp=nil
    bs209994_menu_next
    bs2s_restore_menu
  end
  [:on_item_ok,:on_skill_ok].each do |name|
    alias_method ('bs209994_'+name.to_s).to_sym,name
    define_method(name) do
      if @bs2s_menu_selecting.to_i==0
        kind=name==:on_item_ok ? :item : :skill
        bs2s_remember_menu(BS2Suite::BattleMenus.native(kind==:item ? @item_window : @skill_window,kind))
      end
      send(('bs209994_'+name.to_s).to_sym);bs2s_restore_menu
    end
  end
  [:on_item_cancel,:on_skill_cancel].each do |name|
    alias_method ('bs209994_'+name.to_s).to_sym,name
    define_method(name) do
      bs2s_forget_menu if @bs2s_menu_selecting.to_i==0 && !@bs2s_target_cancelling
      send(('bs209994_'+name.to_s).to_sym)
    end
  end
  [:on_enemy_cancel,:on_actor_cancel].each do |name|
    alias_method ('bs209994_'+name.to_s).to_sym,name
    define_method(name) do
      @bs2s_target_cancelling=true
      begin;send(('bs209994_'+name.to_s).to_sym)
      ensure;@bs2s_target_cancelling=false;end
      bs2s_restore_menu
    end
  end
  alias bs209994_single_ally select_actor_selection
  def select_actor_selection
    bs209994_single_ally
    actor=BattleManager.actor;item=actor && actor.input && actor.input.item
    return unless item && @actor_window.active && @bs2s_menu_memory && @bs2s_menu_memory[actor.id]
    candidates=$game_party.battle_members.each_with_index.select { |b,i| item.for_dead_friend? ? b.dead? : b.alive? }
    if candidates.size==1;@actor_window.select(candidates[0][1]);@actor_window.deactivate;on_actor_ok;end
  end
  alias bs209994_menu_terminate terminate
  def terminate
    @bs2s_menu_memory=nil;@bs2s_cancel_stamp=nil;@bs2s_support_boundary=nil;bs209994_menu_terminate
  end
  alias bs209995_fresh_item_menu command_item
  def command_item
    @item_window.instance_variable_set(:@bs2s_repeat_item,nil)
    bs209995_fresh_item_menu
  end
end

class Window_BattleItem
  alias bs209995_repeat_item_list make_item_list
  def make_item_list
    record=@bs2s_repeat_item
    preserve=record && (@bs2s_repeat_restoring || item==record[:object])
    bs209995_repeat_item_list
    object=record && record[:object]
    if preserve && object && $game_party.item_number(object)==0 && !@data.include?(object)
      @data.insert([[record[:index].to_i,0].max,@data.size].min,object)
    end
  end
end

class Window_Selectable
  alias bs209994_battle_cancel process_handling
  def process_handling
    scene=SceneManager.scene
    return if scene.is_a?(Scene_Battle) && BS2Suite::BattleMenus.cancel(scene,self)
    bs209994_battle_cancel
  end
end
# Older leaf wrappers captured process_handling by alias before this module was
# loaded. Route physical cancel at those entry points as well as at the base.
[Window_ActorCommand,Window_ItemList,Window_SkillList,Window_BattleEnemy,Window_BattleActor].each do |type|
  type.class_eval do
    alias_method :bs209994_leaf_handling,:process_handling
    define_method(:process_handling) do
      scene=SceneManager.scene
      return if scene.is_a?(Scene_Battle) && BS2Suite::BattleMenus.cancel(scene,self)
      bs209994_leaf_handling
    end
  end
end

if defined?(BS2Suite::Palette)
class BS2Suite::PaletteWindow
  alias bs209994_repeat_commands make_command_list
  def make_command_list
    bs209994_repeat_commands
    row=@bs2s_repeat_entry
    return unless row && @group && !@assignment && @transition.empty?
    return unless @bs2s_repeat_context==[@prefix,@group,@page]
    return if @entries.any? { |r| BS2Suite::ActionContext.object_key(r[:object])==BS2Suite::ActionContext.object_key(row[:object]) }
    return if @entries.size>=10
    # Keep a depleted selection disabled instead of moving Enter to a different
    # consumable. This marker lasts only in the returned menu, not in the profile.
    row=row.dup;row[:present]=false;row[:usable]=false
    used=@entries.map { |r| r[:digit] }+[row[:digit]]
    @entries.each_with_index do |entry,i|
      next unless entry[:digit]==row[:digit]
      spare=(1..9).to_a.push(0).find { |n| !used.include?(n) };next unless spare
      entry[:digit]=spare;used<<spare
      entry[:address]=entry[:address].to_s.sub(/\A([VBMN][0-9])[0-9]/) { $1+spare.to_s }
      @list[i][:name]=@list[i][:name].sub(/\A[0-9]/,spare.to_s)
    end
    index=[@bs2s_repeat_index.to_i,@entries.size].min
    @list.reject! { |entry| entry[:symbol]==:empty } if @entries.empty?
    @entries.insert(index,row)
    @list.insert(index,{:name=>row[:digit].to_s+'  '+row[:object].name+' · недоступно',:symbol=>:entry,:enabled=>false,:ext=>row})
  end
end
module BS2Suite::Palette
  class << self
    alias bs209994_repeat_choose choose
    def choose(scene,row)
      window=current(scene)
      if scene.is_a?(Scene_Battle) && window && window.group && !window.assignment && window.transition.empty? && row && row[:object] && (!row[:present] || row[:usable]==false)
        ::Sound.play_buzzer;BS2QoL::Hotkeys.notice('Недоступно: '+row[:object].name)
        BS2QoL::Keyboard.consume;return
      end
      return bs209994_repeat_choose(scene,row) unless scene.is_a?(Scene_Battle) && window && window.group && !window.assignment && window.transition.empty? && row && row[:object] && row[:present] && row[:usable]!=false
      index=window.entries.index(row);window.select(index) if index
      scene.bs2s_remember_menu(BS2Suite::BattleMenus.palette(window))
      scene.instance_variable_set(:@bs2s_menu_selecting,scene.instance_variable_get(:@bs2s_menu_selecting).to_i+1)
      begin;bs209994_repeat_choose(scene,row)
      ensure
        scene.instance_variable_set(:@bs2s_menu_selecting,scene.instance_variable_get(:@bs2s_menu_selecting).to_i-1)
        scene.bs2s_restore_menu
      end
    end
    alias bs209994_repeat_close close
    def close(scene,restore=true)
      scene.bs2s_forget_menu if restore && scene.is_a?(Scene_Battle) && scene.instance_variable_get(:@bs2s_menu_selecting).to_i==0
      bs209994_repeat_close(scene,restore)
    end
    alias bs209994_macro_tab update
    def update(scene)
      window=current(scene)
      if scene.is_a?(Scene_Battle) && window && window.active && !window.assignment && defined?(BS2Suite::Macros) && BS2Suite::Keys.trigger?(:macros) && scene.instance_variable_get(:@bs2s_palette_opened)!=Graphics.frame_count && !(defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene))
        scene.bs2s_forget_menu;scene.instance_variable_set(:@bs2s_cancel_stamp,nil)
        close(scene,false);scene.bs2s_hide_selection
        return BS2Suite::Macros.open(scene,scene.instance_variable_get(:@actor_command_window))
      end
      bs209994_macro_tab(scene)
    end
  end
end
end
if defined?(BS2Suite::MacroCommands) && defined?(BS2Suite::Palette)
class BS2Suite::MacroCommands
  alias bs209994_palette_tab process_handling
  def process_handling
    scene=SceneManager.scene;prefix=BS2Suite::Palette.letter
    if scene.is_a?(Scene_Battle) && active && open? && prefix && scene.instance_variable_get(:@bs2s_macros_opened)!=Graphics.frame_count && !(defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene))
      scene.instance_variable_set(:@bs2s_cancel_stamp,nil);BS2Suite::Macros.close(scene,false)
      return BS2Suite::Palette.open(scene,scene.instance_variable_get(:@actor_command_window),BattleManager.actor,prefix)
    end
    bs209994_palette_tab
  end
end
end

module BS2QoL::ListControls
  alias bs209994_favorite_toggle bs2q_toggle
  def bs2q_toggle
    object=item;result=bs209994_favorite_toggle
    if result && object && (kind=BS2QoL::Model.kind(object))
      BS2QoL::Hotkeys.notice((BS2QoL::Preferences.favorite?(kind,object.id) ? 'В избранном: ' : 'Не в избранном: ')+object.name)
    end
    result
  end
end

class Window_BS2QKeyHints
  alias bs209994_native_favorite_hint display
  def display(scene,actor,context)
    bs209994_native_favorite_hint(scene,actor,context)
    return unless actor && visible && [:items,:skills].include?(context) && BS2Suite.enabled?('combat_shortcuts')
    window=scene.instance_variable_get(context==:items ? :@item_window : :@skill_window)
    text=BS2Suite::BattleMenus.favorite_hint(window)
    key=[contents.object_id,@bs2s_signature,text]
    return if @bs209994_favorite_hint==key
    @bs209994_favorite_hint=key
    contents.clear_rect(0,40,contents_width,18);contents.font.size=15;change_color(normal_color)
    draw_text(0,40,contents_width,18,text)
  end
end
if defined?(BS2Suite::HDDisplay)
module BS2Suite::HDDisplay
  class << self
    alias bs209994_native_favorite_rows battle_rows
    def battle_rows(scene)
      rows=bs209994_native_favorite_rows(scene)
      if BS2Suite.enabled?('combat_shortcuts')
        window=[:@item_window,:@skill_window].map { |k| scene.instance_variable_get(k) }.find { |w| w && w.visible && w.active }
        rows<<row('D',BS2Suite::BattleMenus.favorite_hint(window)) if window
      end
      rows
    end
  end
end
end
