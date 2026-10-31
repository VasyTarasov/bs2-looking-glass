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
  class StatsScene < LinesScene
    def start;super;present('Последний бой',BattleRecord.lines);end
  end
end
module BattleManager
  class << self
    alias bs2suite_record_start battle_start
    def battle_start
      BS2Suite::BattleRecord.start
      bs2suite_record_start
    end
    alias bs2suite_record_end battle_end
    def battle_end(result)
      BS2Suite::BattleRecord.finish(result)
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
