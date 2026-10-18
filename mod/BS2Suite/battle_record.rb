# encoding: UTF-8
module BS2Suite
  module BattleRecord
    class << self
      attr_reader :record,:last,:death
      def start
        @record={:troop=>$game_troop.troop.id,:started=>Time.now,:turns=>0,:uses=>{},:members=>{},:hits=>0,:misses=>0,:critical=>0}
        @death=nil;@stack=[]
      end
      def active?;@record && $game_party && $game_party.in_battle;end
      def key(b);b.actor? ? 'actor:'+b.id.to_s : 'enemy:'+b.index.to_s;end
      def label(b)
        name=b.name.to_s.strip
        name.empty? ? (b.actor? ? 'Герой #'+b.id.to_s : 'Враг #'+(b.index+1).to_s) : name
      end
      def capture
        ($game_party.battle_members+$game_troop.members).map { |b| [b,b.hp,b.mp,b.tp,b.states.map { |s| s.id }] }
      end
      def before(user,item,phase=:effect)
        return nil unless active?
        frame={:before=>capture,:children=>{},:user=>user,:item=>item,:phase=>phase}
        (@stack ||= []) << frame;frame
      end
      def after(frame,target)
        return unless frame
        @stack.pop
        frame[:before].each do |b,hp,mp,tp,states|
          delta=[hp-b.hp,mp-b.mp,tp-b.tp]
          child=frame[:children][key(b)] || [0,0,0]
          own=delta.each_with_index.map { |n,i| n-child[i] }
          row=@record[:members][key(b)] ||= {:name=>label(b),:damage=>0,:healing=>0,:mp=>0,:tp=>0,:costs=>[0,0,0]}
          if frame[:phase]==:cost
            3.times { |i| row[:costs][i]+=[own[i],0].max }
          else
            row[:damage]+=[own[0],0].max;row[:healing]+=[-own[0],0].max;row[:mp]+=own[1];row[:tp]+=own[2]
          end
          if @stack[-1]
            values=@stack[-1][:children][key(b)] ||= [0,0,0]
            3.times { |i| values[i]+=delta[i] }
          end
        end
        return unless frame[:item]
        result=target.result
        @record[:hits]+=1 if result.used && !result.missed && !result.evaded
        @record[:misses]+=1 if result.missed || result.evaded
        @record[:critical]+=1 if result.critical
      end
      def used(user,item)
        return unless active?
        id=key(user)+' '+(item.is_a?(RPG::Skill) ? 'skill:' : 'item:')+item.id.to_s
        row=@record[:uses][id] ||= {:name=>label(user)+' — '+item.name,:count=>0}
        row[:count]+=1
      end
      def died(battler)
        return unless active? && battler.actor?
        context=(@stack || [])[-1]
        @death= if context && context[:item]
          label(battler)+': последнее воздействие — '+label(context[:user])+', '+context[:item].name+'.'
        elsif @periodic
          label(battler)+': ОЗ исчерпаны во время периодического изменения ОЗ.'
        elsif context && context[:phase]==:cost
          label(battler)+': ОЗ исчерпаны при оплате действия.'
        else
          label(battler)+': потеря всех ОЗ или эффект смерти; источник игра не сохранила.'
        end
      end
      def periodic=(value);@periodic=value;end
      def finish(result)
        return unless @record
        @record[:result]=result;@record[:seconds]=(Time.now-@record[:started]).round
        @record[:turns]=$game_troop.turn_count;@record[:death]=@death
        @last=@record;@record=nil
      end
      def lines
        r=@record || @last;return ['Пока нет данных боя.'] unless r
        labels=['Победа','Бегство','Поражение']
        turns=r[:result] ? r[:turns] : $game_troop.turn_count
        lines=[r[:result] ? labels[r[:result]] || 'Бой завершён' : 'Текущий бой','Время: '+(r[:seconds] || (Time.now-r[:started]).round).to_s+' с · счётчик ходов: '+turns.to_s,'Применений к цели: '+r[:hits].to_s+' · промахов/уклонений: '+r[:misses].to_s+' · критических: '+r[:critical].to_s]
        lines << r[:death] if r[:death]
        lines+=['','Фактические изменения ОЗ по действиям:']
        r[:members].values.each do |row|
          lines << row[:name]+': потеря ОЗ '+row[:damage].to_s+' · лечение '+row[:healing].to_s+' · изменение ОМ '+(-row[:mp]).to_s
          lines << 'Затраты действий: ОЗ '+row[:costs][0].to_s+' · ОМ '+row[:costs][1].to_s+' · TP '+row[:costs][2].to_s if row[:costs].any? { |n| n!=0 }
        end
        lines+=['','Применённые действия (включая мгновенные):']
        r[:uses].values.each { |row| lines << row[:name]+' ×'+row[:count].to_s }
        lines+=['','Числа отражают изменения после ограничений ОЗ и ОМ, включая обычную регенерацию и её обращение. Прямые изменения из событий вне этих обработчиков не суммируются. Время включает ожидание ввода.']
        lines
      end
      def panel
        header=BS2Modules::Header.new;header.text=['Статистика боя','↑/↓ прокрутка · Esc назад']
        body=BS2Modules::Lines.new(0,72,Graphics.width,Graphics.height-72);body.set_lines(lines);body.activate
        done=false;body.set_handler(:cancel,lambda { done=true })
        begin
          until done;Graphics.update;Input.update;body.update;end
        ensure;body.dispose;header.dispose;Input.update;end
      end
    end
  end
  module Retry
    class << self
      attr_accessor :interpreter,:serializing
      attr_reader :reason
      def prepare(troop,escape,lose)
        return if @restoring
        @snapshot=nil;@options=[troop,escape,lose];@reason=nil
        return unless BS2Suite.enabled?('retry')
        if lose
          @reason='Сюжетный бой с разрешённым поражением';return
        end
        if $game_party.in_battle || !$game_map || $game_map.map_id==0
          @reason='Бой запущен вне карты';return
        end
        if @interpreter && @interpreter!=$game_map.interpreter
          @reason='Вложенное или параллельное событие';return
        end
        if !@interpreter && $game_map.interpreter.running?
          @reason='Неизвестный способ запуска боя';return
        end
        # Running parallel fibers are not restartable from their Ruby stack.
        parallel=$game_map.events.values.any? do |e|
          i=e.instance_variable_get(:@interpreter);i && i.running?
        end
        parallel ||= ($game_map.instance_variable_get(:@common_events) || []).any? do |e|
          i=e.instance_variable_get(:@interpreter);i && i.running?
        end
        if parallel;@reason='Активно параллельное событие карты';return;end
        temp={}
        $game_temp.instance_variables.each do |key|
          value=$game_temp.instance_variable_get(key)
          # Native cooldown storage has a Proc default and cannot be Marshalled.
          # Preserve its entries and references, recreate its native default later.
          value=Hash[value.map { |b,counts| [b,Hash[counts.to_a]] }] if key.to_s=='@cool_time'
          temp[key]=value
        end
        @serializing=true
        @snapshot=Marshal.dump([DataManager.make_save_contents,temp,@interpreter,Graphics.frame_count])
      rescue StandardError=>e
        @snapshot=nil;@reason='Контрольная точка недоступна: '+e.class.to_s
      ensure;@serializing=false;end
      def ready?
        !!@snapshot && @last_defeat && !@options[2]
      end
      def battle_started
        @last_defeat=false
        @conditions=[BattleManager.instance_variable_get(:@preemptive),BattleManager.instance_variable_get(:@surprise)]
        @interpreter=nil # The suspended event fiber must not become a future launch context.
      end
      def finished(result)
        @last_defeat=result==2
        @snapshot=nil unless @last_defeat
      end
      def restore
        return false unless ready?
        values=Marshal.load(@snapshot) # Owned in-memory checkpoint, never an external profile.
        previous=[DataManager.make_save_contents,$game_temp,Graphics.frame_count,SceneManager.scene,SceneManager.instance_variable_get(:@stack).dup]
        previous_battle=Hash[BattleManager.instance_variables.map { |key| [key,BattleManager.instance_variable_get(key)] }]
        @restoring=true
        DataManager.extract_save_contents(values[0]);$game_temp=Game_Temp.new
        values[1].each do |key,value|
          if key.to_s=='@cool_time'
            value.each { |b,counts| $game_temp.cool_time[b]=Hash.new(0).merge(counts) }
          else
            $game_temp.instance_variable_set(key,value)
          end
        end
        $game_message.clear
        owner=values[2];frame=values[3]
        BattleManager.setup(*@options)
        if owner
          indent=owner.instance_variable_get(:@list)[owner.instance_variable_get(:@index)-1].indent
          BattleManager.event_proc=Proc.new { |n| owner.instance_variable_get(:@branch)[indent]=n }
        end
        BattleManager.instance_variable_set(:@preemptive,@conditions[0]);BattleManager.instance_variable_set(:@surprise,@conditions[1])
        BattleManager.save_bgm_and_bgs;BattleManager.play_battle_bgm
        Graphics.frame_count=frame
        SceneManager.clear;SceneManager.goto(Scene_Map);SceneManager.call(Scene_Battle)
        @last_defeat=false;true
      rescue StandardError=>e
        if previous
          DataManager.extract_save_contents(previous[0]);$game_temp=previous[1];Graphics.frame_count=previous[2]
          SceneManager.instance_variable_set(:@scene,previous[3]);SceneManager.instance_variable_set(:@stack,previous[4])
          BattleManager.instance_variables.each { |key| BattleManager.send(:remove_instance_variable,key) }
          previous_battle.each { |key,value| BattleManager.instance_variable_set(key,value) }
        end
        @snapshot=nil;@reason='Не удалось восстановить: '+e.class.to_s;false
      ensure;@restoring=false;end
      def clear;@snapshot=nil;@last_defeat=false;@interpreter=nil;@reason=nil;end
    end
  end
  class StatsScene < LinesScene
    def start;super;present('Последний бой',BattleRecord.lines);end
  end
  class DefeatCommands < Window_Command
    def window_width;320;end
    def make_command_list
      add_command('Повторить бой',:retry,Retry.ready?) if BS2Suite.enabled?('retry')
      add_command('Загрузить последний сейв',:last,DataManager.save_file_exists?)
      add_command('Выбрать сохранение',:load,DataManager.save_file_exists?)
      add_command('Статистика боя',:stats) if BS2Suite.enabled?('battle_stats')
      add_command('В главное меню',:title)
    end
  end
end
module DataManager
  class << self
    alias bs2suite_retry_load load_game
    def load_game(index)
      result=bs2suite_retry_load(index)
      BS2Suite::Retry.clear if result
      result
    end
    alias bs2suite_retry_new setup_new_game
    def setup_new_game
      BS2Suite::Retry.clear;bs2suite_retry_new
    end
  end
end
class Game_Interpreter
  alias bs2suite_battle_command command_301
  def command_301
    previous=BS2Suite::Retry.interpreter;BS2Suite::Retry.interpreter=self
    bs2suite_battle_command
  ensure;BS2Suite::Retry.interpreter=previous;end
  alias bs2suite_interpreter_dump marshal_dump
  def marshal_dump
    result=bs2suite_interpreter_dump
    if BS2Suite::Retry.serializing && self!=BS2Suite::Retry.interpreter
      result[4]=@index
    end
    result
  end
end
module BattleManager
  class << self
    alias bs2suite_record_setup setup
    def setup(troop,escape=true,lose=false)
      BS2Suite::Retry.prepare(troop,escape,lose)
      bs2suite_record_setup(troop,escape,lose)
    end
    alias bs2suite_record_start battle_start
    def battle_start
      BS2Suite::BattleRecord.start;BS2Suite::Retry.battle_started
      bs2suite_record_start
    end
    alias bs2suite_record_end battle_end
    def battle_end(result)
      BS2Suite::BattleRecord.finish(result);BS2Suite::Retry.finished(result)
      bs2suite_record_end(result)
    end
  end
end
class Game_Battler
  alias bs2suite_record_apply item_apply
  def item_apply(user,item)
    frame=BS2Suite::BattleRecord.before(user,item)
    bs2suite_record_apply(user,item)
  ensure;BS2Suite::BattleRecord.after(frame,self) if frame;end
  alias bs2suite_record_use use_item
  def use_item(item)
    BS2Suite::BattleRecord.used(self,item)
    frame=BS2Suite::BattleRecord.before(self,nil,:cost)
    bs2suite_record_use(item)
  ensure;BS2Suite::BattleRecord.after(frame,self) if frame;end
  alias bs2suite_record_die die
  def die;BS2Suite::BattleRecord.died(self);bs2suite_record_die;end
  alias bs2suite_record_regen regenerate_hp
  def regenerate_hp
    BS2Suite::BattleRecord.periodic=true
    frame=BS2Suite::BattleRecord.before(self,nil,:periodic)
    bs2suite_record_regen
  ensure
    BS2Suite::BattleRecord.after(frame,self) if frame
    BS2Suite::BattleRecord.periodic=false
  end
end
if BS2Suite.enabled?('defeat') || BS2Suite.enabled?('retry')
  class Scene_Gameover
    alias bs2suite_defeat_start start
    def start
      bs2suite_defeat_start
      @bs2_defeat=BS2Suite::DefeatCommands.new(160,230)
      BS2Modules.style(@bs2_defeat)
      @bs2_defeat.set_handler(:retry,method(:bs2suite_retry))
      @bs2_defeat.set_handler(:last,method(:bs2suite_last_save))
      @bs2_defeat.set_handler(:load,lambda { SceneManager.call(Scene_Load) })
      @bs2_defeat.set_handler(:title,method(:goto_title))
      @bs2_defeat.set_handler(:stats,lambda { BS2Suite::BattleRecord.panel;@bs2_defeat.activate })
      @bs2_info=BS2Modules::Lines.new(20,20,600,190)
      lines=['Вы пали.',BS2Suite::BattleRecord.death || 'Причина не зафиксирована.']
      lines << 'Повтор недоступен: '+BS2Suite::Retry.reason.to_s if BS2Suite.enabled?('retry') && !BS2Suite::Retry.ready?
      @bs2_info.set_lines(lines);@bs2_info.deactivate
    end
    def update;super;end
    def bs2suite_retry
      unless BS2Suite::Retry.restore;Sound.play_buzzer;@bs2_defeat.activate;end
    end
    def bs2suite_last_save
      if DataManager.load_game(DataManager.latest_savefile_index)
        BS2Suite::Retry.clear;Sound.play_load;fadeout_all
        $game_system.on_after_load;SceneManager.clear;SceneManager.goto(Scene_Map)
      else
        Sound.play_buzzer;@bs2_defeat.activate
      end
    end
  end
end
