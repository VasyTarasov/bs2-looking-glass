# encoding: UTF-8
module BS2Suite
  # Deliberately bounded, authored maintenance actions. No heals, cleanses,
  # extra-action engines, equipment optimiser or enemy-plan/resistance inspection.
  module BattleSupport
    GUNBREAK=[17,18,19,20,875,877].freeze
    SKILLS=GUNBREAK
    ITEMS=[22,56,57,58,59,60,61,100,101,104,33,34,97,105,24,31,46,50,52].freeze
    class << self
      def hero; $game_party && $game_party.members.find { |a| a.id==1 };end
      def definitions
        return @definitions if @definitions
        @definitions=[]
        Store.read('battle_support',131072).each_line do |line|
          a=line.strip.split('|')
          if a.size==4 && a[0]=='a' && a[1]=~/\A[1-9][0-9]{0,3}\z/ && %w(skill item).include?(a[2]) && a[3]=~/\A[1-9][0-9]{0,3}\z/
            @definitions<<{'actor'=>a[1].to_i,'kind'=>a[2],'id'=>a[3].to_i}
          elsif a.size==5 && a[0]=='g' && a[1]=~/\A[1-9][0-9]{0,3}\z/ && %w(V B M).include?(a[2]) && a[3]=~/\A(?:progression|advanced|u[0-9]{1,4})\z/ && a[4]=~/\A(?:[1-9]|10)\z/
            @definitions<<{'actor'=>a[1].to_i,'prefix'=>a[2],'profile'=>a[3],'group'=>a[4].to_i}
          end
          break if @definitions.size>=128
        end
        @definitions.uniq!
        @definitions
      end
      def persist
        text=definitions.map do |r|
          r['kind'] ? ['a',r['actor'],r['kind'],r['id']].join('|') : ['g',r['actor'],r['prefix'],r['profile'],r['group']].join('|')
        end.join("\n")
        Store.write('battle_support',text+"\n")
      end
      def reset
        @master=false;@busy=false;@epoch=0;@actions_ref=nil;@clocks={};@last_clocks={};@history={};@attempts={};@pending=nil;@next_frame=0;@reason=nil
        @expanded_key=nil;@expanded_values=nil
      end
      def active?;!!@master && $game_party && $game_party.in_battle;end
      def busy?;!!@busy;end
      def pending;@pending;end
      def object(kind,id);kind.to_s=='item' ? $data_items[id] : $data_skills[id];end
      def key(obj);[obj.is_a?(RPG::Item) ? 'item' : 'skill',obj.id];end
      def tracked(obj)
        return [] unless obj
        obj.effects.select { |e| [31,32].include?(e.code) || (e.code==21 && e.data_id>0 && e.value1>0) }.map do |e|
          if e.code==21
            next if obj.is_a?(RPG::Item) && obj.id==31 && e.value1<0.1 # incidental special event state is not a maintenance objective
            [:state,e.data_id,1]
          else
            [e.code==31 ? :buff : :debuff,e.data_id,e.value1.to_i]
          end
        end.compact.uniq
      end
      def gunbreak?(obj);obj.is_a?(RPG::Skill) && GUNBREAK.include?(obj.id);end
      def eligible?(obj)
        return false unless obj && (obj.is_a?(RPG::Item) ? ITEMS : SKILLS).include?(obj.id)
        return false if obj.is_a?(RPG::Item) && (!quick?(obj) || obj.damage.type!=0)
        return false unless obj.occasion==0 || obj.occasion==1
        return false if obj.effects.any? { |e| [11,12,22,34,44].include?(e.code) }
        return false if obj.note =~ /消費最大ＨＰ|使用後追加行動|使用者効果|ステート変化|行動後遅延/
        return false unless [1,2,7,8,11].include?(obj.scope)
        return false if obj.for_friend? && obj.damage.type!=0
        tracked(obj).all? do |type,id,duration|
          next true unless type==:state
          s=$data_states[id]
          s && [0,1,2].include?(s.auto_removal_timing) && !(obj.for_friend? && s.features.any? { |f| f.code==14 })
        end && !tracked(obj).empty?
      end
      def source(actor,obj)
        return nil unless obj.is_a?(RPG::Skill) && !actor.skill_learn?(obj)
        Semantic.source_for(actor,obj.id)
      end
      def available?(actor,obj)
        return false unless actor && actor.alive? && actor.movable? && eligible?(obj)
        # Preserve native scopes: do not cast a party-wide buff onto companions.
        return false if obj.for_friend? && obj.for_all? && $game_party.alive_members.any? { |member| member!=actor }
        if obj.is_a?(RPG::Item)
          return $game_party.item_number(obj)>0 && actor.usable?(obj)
        end
        provider=source(actor,obj)
        return false unless actor.skill_learn?(obj) || provider
        view=provider.is_a?(RPG::Weapon) ? Projection.weapon(actor,provider) : actor
        view.usable?(obj) && !view.skill_seal.include?(obj.id)
      end
      def expand(actor)
        mode=Semantic.mode(actor);profile=Semantic.customs[mode]
        cache_key=[actor.id,mode,definitions.hash,profile && profile.hash]
        return @expanded_values if $game_party.in_battle && @expanded_key==cache_key && @expanded_values
        values=[]
        definitions.each do |r|
          next unless r['actor']==actor.id
          if r['kind']
            obj=object(r['kind'],r['id']);values<<obj if eligible?(obj)

          end
        end
        values=values.uniq { |o| key(o) }
        if $game_party.in_battle;@expanded_key=cache_key;@expanded_values=values;end
        values
      end
      def configured?(actor,obj)
        expand(actor).any? { |x| key(x)==key(obj) }
      end
      def group_definition(actor,prefix,number)
        {'actor'=>actor.id,'prefix'=>prefix,'profile'=>Semantic.mode(actor),'group'=>number}
      end
      def toggle_definition(actor,definition)
        return false unless actor && hero && actor.id==hero.id
        before=definitions.dup
        if definitions.include?(definition);definitions.delete(definition)
        else
          return false if definitions.size>=128
          definitions<<definition
        end
        unless persist;@definitions=before;return false;end
        cancel_pending
        @master=!expand(actor).empty? if $game_party.in_battle
        @next_frame=Graphics.frame_count+1;@reason=nil
        true
      end
      def toggle_object(actor,obj)
        return false unless eligible?(obj)
        kind,id=key(obj);toggle_definition(actor,{'actor'=>actor.id,'kind'=>kind,'id'=>id})
      end
      def toggle_group(actor,prefix,number)
        return false unless %w(V B M).include?(prefix)
        return false unless Semantic.rows(actor,prefix,number).any? { |r| eligible?(r[:object]) }
        toggle_definition(actor,group_definition(actor,prefix,number))
      end
      def toggle_master
        @master=!@master;@reason=nil
        cancel_pending unless @master
        @next_frame=Graphics.frame_count+1
        BS2QoL::Hotkeys.notice(@master ? 'Боевая поддержка включена: только ГГ и противники' : 'Боевая поддержка приостановлена')
      end
      def clock(target,domain)
        @clocks ||= {};(@clocks[target.object_id] ||= Hash.new(0))[domain]
      end
      def tick_clock(target,domain)
        return unless $game_party && $game_party.in_battle
        @clocks ||= {};(@clocks[target.object_id] ||= Hash.new(0))[domain]+=1
      end
      def new_epoch(actor)
        return if @actions_ref.equal?(actor.actions)
        @actions_ref=actor.actions;@epoch=(@epoch || 0)+1;@attempts={};@pending=nil
        ([actor]+$game_troop.alive_members).each do |target|
          [:buff,1,2].each do |domain|
            k=[target.object_id,domain];now=clock(target,domain)
            if @last_clocks && @last_clocks.has_key?(k)
              delta=now-@last_clocks[k]
              @history ||= {};values=(@history[k] ||= []);values<<delta if delta>=0;values.shift while values.size>3
            end
            @last_clocks ||= {};@last_clocks[k]=now
          end
        end
      end
      def reserve(target,domain)
        return 1 unless Options.get('experimental_support')==1
        values=@history && @history[[target.object_id,domain]]
        # No action_plus roll, action list, boss script, resistance or future skill is inspected.
        observed=values && !values.empty? ? values.max : (target.actor? ? 0 : 1)
        [[observed+1,1].max,32].min
      end
      def due_component?(target,type,id,fresh)
        if type==:state
          return true unless target.state?(id)
          state=$data_states[id];return false if state.auto_removal_timing==0
          remaining=target.instance_variable_get(:@state_turns)[id].to_i
          threshold=[reserve(target,state.auto_removal_timing),[state.min_turns-1,1].max].min
          # Recasting an active state re-rolls its duration. Never roll again while
          # its remaining duration already reaches the minimum fresh duration.
          remaining<state.min_turns && remaining<=threshold
        else
          level=target.instance_variable_get(:@buffs)[id].to_i
          return true if type==:buff ? level<2 : level>-2
          remaining=target.instance_variable_get(:@buff_turns)[id].to_i
          remaining<fresh && remaining<=reserve(target,:buff)
        end
      end
      def due?(obj,target)
        return false unless target && target.alive?
        # Native add_buff erases an opposing negative parameter level. Leave
        # that tactical cleansing decision to the player, even for a pure buff.
        return false if obj.for_friend? && tracked(obj).any? { |type,id,fresh| type==:buff && target.instance_variable_get(:@buffs)[id]<0 }
        tracked(obj).any? { |type,id,fresh| due_component?(target,type,id,fresh) }
      end
      def fingerprint(obj,target)
        tracked(obj).map do |type,id,fresh|
          if type==:state;[type,id,target.state?(id),target.instance_variable_get(:@state_turns)[id]]
          else;[type,id,target.instance_variable_get(:@buffs)[id],target.instance_variable_get(:@buff_turns)[id]];end
        end
      end
      def target_key(obj,target);[key(obj),target.object_id];end
      def next_plan(actor)
        expand(actor).each do |obj|
          next unless available?(actor,obj)
          targets=obj.for_friend? ? [actor] : $game_troop.alive_members.select { |e| !e.hidden? }
          targets.each do |target|
            next unless due?(obj,target)
            token=target_key(obj,target);attempt=(@attempts || {})[token]
            next if attempt && (attempt[:count]>=4 || attempt[:failed] || attempt[:refreshed])
            affected=obj.for_all? ? targets : [target]
            snapshots=affected.map do |who|
              {:target=>who,:token=>target_key(obj,who),:before=>fingerprint(obj,who),
                :was_max=>tracked(obj).all? { |t,i,d| t==:state ? who.state?(i) : (t==:buff ? who.instance_variable_get(:@buffs)[i]>=2 : who.instance_variable_get(:@buffs)[i]<=-2) }}
            end
            return {:actor=>actor,:object=>obj,:target=>target,:source=>source(actor,obj),:snapshots=>snapshots}
          end
        end
        nil
      end
      def record(plan)
        @attempts ||= {}
        plan[:snapshots].each do |row|
          entry=@attempts[row[:token]] ||= {:count=>0};entry[:count]+=1
          entry[:failed]=fingerprint(plan[:object],row[:target])==row[:before]
          entry[:refreshed]=row[:was_max]
        end
      end
      def cancel_pending
        if @pending
          actor=@pending[:actor];action=@pending[:action]
          action.clear if actor.input.equal?(action) && action.instance_variable_get(:@bs2s_support_plan).equal?(@pending)
        end
        @pending=nil
      end
      def quick?(obj);!!obj.hzm_vxa_note_match(HZM_VXA::QuickSkill::QUICK_KEYS);end
      def prepare_plan(plan,action)
        actor=plan[:actor];obj=plan[:object];target=plan[:target]
        if obj.for_opponent? && obj.for_all?
          target=$game_troop.alive_members.find { |enemy| !enemy.hidden? && due?(obj,enemy) }
          plan[:target]=target
        end
        return false unless target && target.alive? && available?(actor,obj) && due?(obj,target)
        affected=obj.for_all? && obj.for_opponent? ? $game_troop.alive_members.reject { |enemy| enemy.hidden? } : [target]
        plan[:snapshots]=affected.map do |who|
          {:target=>who,:token=>target_key(obj,who),:before=>fingerprint(obj,who),
            :was_max=>tracked(obj).all? { |t,i,d| t==:state ? who.state?(i) : (t==:buff ? who.instance_variable_get(:@buffs)[i]>=2 : who.instance_variable_get(:@buffs)[i]<=-2) }}
        end
        provider=plan[:source]
        return false if provider.is_a?(RPG::Weapon) && actor.equips[0]!=provider && !BS2QoL::Model.change_weapon(actor,provider)
        @setting=true
        obj.is_a?(RPG::Item) ? action.set_item(obj.id) : action.set_skill(obj.id)
        action.target_index=obj.for_friend? ? $game_party.battle_members.index(actor) : target.index
        action.instance_variable_set(:@bs2s_support_plan,plan)
        true
      ensure
        @setting=false
      end
      def setting?;!!@setting;end
      def quick_run(scene,plan)
        actor=plan[:actor];old=actor.input;index=actor.actions.index(old);return unless index
        weapon=actor.equips[0];action=Game_Action.new(actor)
        return unless prepare_plan(plan,action)
        actor.actions[index]=action
        scene.instance_variable_set(:@hzm_vxa_quickSkill_skill,plan[:object])
        scene.hzm_vxa_quickSkill_run
        record(plan)
      ensure
        if actor && index && actor.actions[index].equal?(action);actor.actions[index]=old;end
        if actor && weapon && weapon!=plan[:source] && plan[:source].is_a?(RPG::Weapon) && actor.equips[0]==plan[:source] && actor.alive?
          BS2QoL::Model.change_weapon(actor,weapon)
        end
        scene.instance_variable_set(:@hzm_vxa_quickSkill_skill,nil)
      end
      def propose(scene,plan)
        actor=plan[:actor];action=actor.input;return unless action && !action.item
        # Planning never equips. The source is applied only when this real slot executes.
        @setting=true
        obj=plan[:object];obj.is_a?(RPG::Item) ? action.set_item(obj.id) : action.set_skill(obj.id)
        action.target_index=obj.for_friend? ? $game_party.battle_members.index(actor) : plan[:target].index
        plan[:action]=action;action.instance_variable_set(:@bs2s_support_plan,plan);@pending=plan
        window=scene.instance_variable_get(:@actor_command_window)
        window.set_handler(:bs2_support,lambda { scene.bs2s_support_accept })
        window.refresh;i=window.instance_variable_get(:@list).index { |r| r[:symbol]==:bs2_support };window.select(i) if i
        BS2QoL::Hotkeys.notice('Поддержка: '+obj.name+' → '+plan[:target].name+' · Enter занять действие · другая команда заменить')
      ensure
        @setting=false
      end
      def label
        return 'Автопредметы: выкл' unless active?
        count=hero ? expand(hero).size : 0
        'Авто: '+count.to_s+' · D на предмете / Gun Break'+(@reason ? ' · '+@reason : '')
      end
      def tick(scene)
        entered=false
        return if busy? || !active? || Graphics.frame_count<(@next_frame || 0)
        return if Palette.current(scene) || (defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene))
        return if [:@skill_window,:@item_window,:@enemy_window,:@actor_window].any? { |key| w=scene.instance_variable_get(key);w && w.active && w.visible }
        actor=BattleManager.actor;return unless actor && hero && actor.id==hero.id && actor.alive? && actor.inputable?
        window=scene.instance_variable_get(:@actor_command_window)
        return unless window && window.active && window.open? && actor.input
        return if scene.scene_changing? || $game_message.busy? || BattleManager.action_forced? || HZM_VXA::QuickSkill.quickSkill?
        return unless BS2QoL::Keyboard.focused?
        return if BS2QoL::Keyboard.raw_fresh.any?
        @next_frame=Graphics.frame_count+8;@busy=true;entered=true
        new_epoch(actor)
        if @pending && (!actor.input.equal?(@pending[:action]) || !actor.input.instance_variable_get(:@bs2s_support_plan).equal?(@pending))
          @pending[:snapshots].each { |row| @attempts[row[:token]]={:count=>0,:failed=>true} }
          @pending=nil;window.refresh
        end
        return if actor.input.item
        plan=next_plan(actor);return unless plan
        quick?(plan[:object]) ? quick_run(scene,plan) : propose(scene,plan)
      rescue StandardError=>e
        @master=false;@reason='ошибка поддержки'
        BS2QoL::Hotkeys.notice('Поддержка остановлена: '+e.class.to_s)
        BS2Suite::Debug.emit('support_error',{:class=>e.class.to_s,:message=>e.message,:backtrace=>e.backtrace}) if defined?(BS2Suite::Debug)
      ensure
        @busy=false if entered
      end
    end
    reset
  end
end

# Track real elapsed countdown events, not frames, guessed rounds or hidden action plans.
class Game_Battler
  alias bs2093_support_buff_tick update_buff_turns
  def update_buff_turns
    bs2093_support_buff_tick
    BS2Suite::BattleSupport.tick_clock(self,:buff)
  end
  alias bs2093_support_state_tick update_state_turns
  def update_state_turns(timing)
    bs2093_support_state_tick(timing)
    BS2Suite::BattleSupport.tick_clock(self,timing)
  end
end
class Game_Action
  alias bs2093_support_clear clear
  def clear
    @bs2s_support_plan=nil
    bs2093_support_clear
  end
  alias bs2093_support_set_skill set_skill
  def set_skill(id)
    @bs2s_support_plan=nil unless BS2Suite::BattleSupport.setting?
    bs2093_support_set_skill(id)
  end
  alias bs2093_support_set_item set_item
  def set_item(id)
    @bs2s_support_plan=nil unless BS2Suite::BattleSupport.setting?
    bs2093_support_set_item(id)
  end
  alias bs2093_support_prepare prepare
  def prepare
    plan=@bs2s_support_plan
    if plan && !BS2Suite::BattleSupport.quick?(plan[:object])
      plan[:restore_weapon]=subject.equips[0]
      unless BS2Suite::BattleSupport.prepare_plan(plan,self)
        clear;BS2QoL::Hotkeys.notice('Поддержка: действие стало недоступно');return
      end
    end
    bs2093_support_prepare
  end
end
class Window_ActorCommand
  alias bs2093_support_commands make_command_list
  def make_command_list
    bs2093_support_commands
    plan=BS2Suite::BattleSupport.pending
    if plan && @actor && plan[:actor]==@actor && @actor.input.equal?(plan[:action]) && @actor.input.instance_variable_get(:@bs2s_support_plan).equal?(plan)
      add_command('Поддержка: '+plan[:object].name+' → '+plan[:target].name,:bs2_support,true)
    end
  end
end
class Scene_Battle
  alias bs2093_support_start start
  def start
    BS2Suite::BattleSupport.reset
    bs2093_support_start
  end
  alias bs2093_support_ready start_actor_command_selection
  def start_actor_command_selection
    bs2093_support_ready
    actor=BattleManager.actor
    BS2Suite::BattleSupport.new_epoch(actor) if actor && actor==BS2Suite::BattleSupport.hero
  end
  def bs2s_support_accept
    plan=BS2Suite::BattleSupport.pending;actor=BattleManager.actor
    return unless plan && actor && actor.input.equal?(plan[:action])
    @actor_command_window.deactivate
    @hzm_vxa_quickSkill_skill=nil
    BS2Suite::BattleSupport.instance_variable_set(:@pending,nil)
    next_command
  end
  alias bs2093_support_use use_item
  def use_item
    action=@subject && @subject.current_action
    plan=action && action.instance_variable_get(:@bs2s_support_plan)
    result=bs2093_support_use
    BS2Suite::BattleSupport.record(plan) if plan && !BS2Suite::BattleSupport.quick?(plan[:object])
    if plan && !BS2Suite::BattleSupport.quick?(plan[:object])
      old=plan[:restore_weapon];provider=plan[:source];actor=plan[:actor]
      nominated=action.instance_variable_get(:@bs2s_direct_applied) && BS2Suite::DirectWeapons.selected(actor)
      if !nominated && old && old!=provider && provider.is_a?(RPG::Weapon) && actor.equips[0]==provider && actor.alive?
        BS2QoL::Model.change_weapon(actor,old)
      end
    end
    result
  end
  alias bs2093_support_update update_basic
  def update_basic
    bs2093_support_update
    BS2Suite::BattleSupport.tick(self)
  end
end
class Game_Party
  alias bs2093_support_battle_end on_battle_end
  def on_battle_end
    BS2Suite::BattleSupport.reset
    bs2093_support_battle_end
  end
end

module BS2Suite::Palette
  class << self
    alias bs2093_palette_update update
    def update(scene)
      popup=current(scene)
      if popup && !popup.assignment && popup.transition.empty? && popup.group && (popup.prefix=='N' || popup.prefix=='B' || (popup.prefix=='V' && BS2Suite::BattleSupport.gunbreak?(popup.item))) && Input.trigger?(:Z) && BS2QoL::Keyboard.focused? && !(defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene))
        return if scene.instance_variable_get(:@bs2094_d_frame)==Graphics.frame_count
        scene.instance_variable_set(:@bs2094_d_frame,Graphics.frame_count)
        actor=popup.actor
        if popup.prefix=='N' && popup.group && popup.item.is_a?(RPG::Weapon)
          weapon=popup.item
          if BS2Suite::DirectWeapons.selected(actor)==weapon
            BS2Suite::DirectWeapons.clear(actor);BS2QoL::Hotkeys.notice('Исполняющее оружие снято')
          elsif BS2Suite::DirectWeapons.select(actor,weapon)
            BS2QoL::Hotkeys.notice('Последнее действие: '+weapon.name+' · N N снять')
          end
          Sound.play_ok
        elsif popup.prefix!='N'
          ok=BS2Suite::BattleSupport.toggle_object(actor,popup.item)
          if ok;Sound.play_ok;BS2QoL::Hotkeys.notice('Автоприменение переключено для выбранной строки')
          else;Sound.play_buzzer;BS2QoL::Hotkeys.notice('Авто: только разрешённые баффы/дебаффы, без лечения и очищения');end
        end
        command=scene.instance_variable_get(:@actor_command_window)
        command.refresh if command
        popup.refresh;update_header(scene);BS2QoL::Keyboard.consume;return
      end
      bs2093_palette_update(scene)
    end
  end
end
class Window_BS2QKeyHints
  alias bs2093_support_display display
  def display(scene,actor,context)
    bs2093_support_display(scene,actor,context)
    return unless actor && visible
    text='Профиль: '+BS2Suite::Semantic.title(actor)+' · '+BS2Suite::BattleSupport.label
    return if @bs2093_support_hint==text && @bs2093_support_context==@bs2s_signature
    @bs2093_support_hint=text;@bs2093_support_context=@bs2s_signature
    contents.clear_rect(0,20,contents_width,18);contents.font.size=14;change_color(normal_color)
    draw_text(0,20,contents_width,18,text)
  end
end
