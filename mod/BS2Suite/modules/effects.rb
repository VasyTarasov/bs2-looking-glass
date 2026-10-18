# encoding: UTF-8
module BS2Modules
  module Effects
    class << self
      def hash_of(owner,key)
        value=owner && owner.instance_variable_get(key)
        value.is_a?(Hash) ? value : {}
      end
      def named(data,id,fallback)
        BS2Modules.label(data[id],fallback)
      end
      def feature(f)
        id=f.data_id;v=f.value
        param=PARAMS[id] || id.to_s
        case f.code
        when 11 then 'Получаемый урон: '+($data_system.elements[id].to_s.empty? ? 'элемент '+id.to_s : $data_system.elements[id])+' ×'+BS2Modules.num(v)
        when 12 then 'Шанс ослабления '+param+' ×'+BS2Modules.num(v)
        when 13 then 'Вероятность состояния «'+named($data_states,id,'Состояние')+'» ×'+BS2Modules.num(v)
        when 14 then 'Иммунитет: '+named($data_states,id,'Состояние')
        when 21 then param+' ×'+BS2Modules.num(v)
        when 22
          label=['Меткость','Уклонение','Критический удар','Защита от крита','Маг. уклонение','Отражение магии','Контратака','Регенерация ОЗ','Регенерация ОМ','Регенерация ОТ'][id] || 'Доп. параметр'
          label+': '+(v>=0 ? '+' : '')+BS2Modules.pct(v)+' (вклад)'
        when 23
          label=['Вероятность выбора целью','Эффективность защиты','Получаемое лечение','Сила лекарств','Расход ОМ','Прирост ОТ','Получаемый физ. урон','Получаемый маг. урон','Урон от пола','Получаемый опыт'][id] || 'Спец. параметр'
          label+' ×'+BS2Modules.num(v)
        when 31 then 'Элемент атаки: '+$data_system.elements[id].to_s
        when 32 then 'Атака накладывает: '+named($data_states,id,'Состояние')+'; вклад '+BS2Modules.pct(v)
        when 33 then 'Скорость атаки: '+BS2Modules.num(v)
        when 34 then 'Дополнительных ударов: '+BS2Modules.num(v)
        when 41 then 'Открыт тип навыков: '+$data_system.skill_types[id].to_s
        when 42 then 'Запрещён тип навыков: '+$data_system.skill_types[id].to_s
        when 43 then 'Доступен навык: '+named($data_skills,id,'Навык')
        when 44 then 'Запрещён навык: '+named($data_skills,id,'Навык')
        when 51 then 'Разрешено оружие: '+$data_system.weapon_types[id].to_s
        when 52 then 'Разрешена броня: '+$data_system.armor_types[id].to_s
        when 53 then 'Нельзя снять: '+Vocab.etype(id).to_s
        when 54 then 'Запрещён слот: '+Vocab.etype(id).to_s
        when 55 then 'Тип слотов: '+(id==1 ? 'два оружия' : 'обычный')
        when 61 then 'Дополнительное действие: отдельный шанс '+BS2Modules.pct(v)
        when 62 then ['Автоматический бой','Защитная стойка','Подмена союзника','Сохранение ОТ'][id] || 'Особый флаг '+id.to_s
        when 63 then 'Тип исчезновения: '+id.to_s
        when 64 then ['Реже случайные встречи','Нет случайных встреч','Нет внезапных атак','Чаще упреждающая атака','Удвоение душ','Удвоение добычи'][id] || 'Свойство группы '+id.to_s
        else 'Дополнительное свойство '+f.code.to_s+' / '+id.to_s+': '+BS2Modules.num(v)
        end
      end
      def special(object)
        note=object.note.to_s;lines=[]
        lines << 'Использование предметов запрещено.' if note.include?('<アイテム封印>')
        lines << 'Полное восстановление не снимает это состояние.' if note.include?('[全回復無効ステート]')
        lines << 'Физические атаки игнорируют обычную проверку попадания.' if note.include?('<物理絶対命中>')
        lines << 'Магические атаки игнорируют обычную проверку попадания.' if note.include?('<魔法絶対命中>')
        note.scan(/<(HP|MP)回復(無効|反転):(\d+)>/) do |m|
          label=m[0]=='HP' ? 'ОЗ' : 'ОМ'
          lines << 'Шанс '+(m[1]=='無効' ? 'отмены' : 'обращения в урон')+' лечения '+label+': '+m[2]+'%.'
          lines << 'Относится к прямому лечению навыком или предметом.'
        end
        note.scan(/<反撃スキル\s+(\d+)>/) { |m| lines << 'Навык контратаки: '+named($data_skills,m[0].to_i,'Навык') }
        note.scan(/<全回避時スキル:(\d+)>/) { |m| lines << 'При полном уклонении: '+named($data_skills,m[0].to_i,'Навык') }
        note.scan(/<スキル無効:(\d+)(?:,(\d+))?>/) { |m| lines << 'Не действует навык: '+named($data_skills,m[0].to_i,'Навык')+'; шанс '+(m[1] || '100')+'%.' }
        note.scan(/<強制自然解除時ステート:(\d+)>/) { |m| lines << 'При естественном окончании: '+named($data_states,m[0].to_i,'Состояние') }
        lines << 'Снимается перед следующим действием при счётчике 1.' if note.include?('<次の行動前に解除>')
        note.scan(/<フレーム再生=(-?\d+),(-?\d+),(-?\d+)>/) do |m|
          lines << 'На такте состояния: ОЗ '+m[0]+'%, ОМ '+m[1]+'%, ОТ '+m[2]+'%.'
        end
        # A note may include arbitrary event/script logic. Do not claim a complete
        # semantic explanation of it; every active state is still listed.
        lines << 'Особые правила скриптов могут дополнять свойства ниже.' unless note.strip.empty?
        lines
      end
      def duration(actor,state)
        turns=hash_of(actor,:@state_turns)[state.id]
        timing=state.auto_removal_timing
        lines=[]
        case timing
        when 1 then lines << 'Осталось завершений действия: '+(turns.nil? ? '?' : turns.to_s)
        when 2 then lines << 'Осталось завершений хода: '+(turns.nil? ? '?' : turns.to_s)
        when 3
          frames=hash_of(actor,:@state_frames)[state.id]
          lines << (state.auto_remove? ? 'Осталось тактов: '+turns.to_s : 'Такты без автоматического снятия.')
          lines << 'До следующего такта: '+frames.to_s+' внутренних кадров.' unless frames.nil?
          lines << 'Интервал такта: '+state.turn_frame.to_s+' внутренних кадров; это не секунды.'
        else lines << 'Автоматического отсчёта нет.'
        end
        lines << 'Снимается в конце боя.' if state.remove_at_battle_end
        lines << 'Шанс снятия при получении урона: '+state.chance_by_damage.to_s+'%.' if state.remove_by_damage
        if state.remove_by_walking
          steps=hash_of(actor,:@state_steps)[state.id]
          lines << 'Осталось шагов: '+(steps.nil? ? '?' : steps.to_s)
        end
        lines << 'Снимается при ограничении действий.' if state.remove_by_restriction
        lines
      end
      def active(actor)
        rows=[]
        actor.states.each do |state|
          details=duration(actor,state)
          r=['Действия разрешены.','Атака врага без выбора.','Атака случайной стороны.','Атака союзника без выбора.','Действия запрещены.'][state.restriction]
          details << r if state.restriction>0 && r
          details += special(state)+state.features.map { |f| feature(f) }
          details << 'Источник наложения не сохранён игрой; не определяется по названию.'
          summary=details[0].sub('Осталось завершений действия: ','Действий: ').sub('Осталось завершений хода: ','Ходов: ').sub('Автоматического отсчёта нет.','Без отсчёта')
          rows << {:name=>BS2Modules.label(state,'Состояние'),:summary=>summary,:details=>details,:kind=>:state,:id=>state.id}
        end
        buffs=actor.instance_variable_get(:@buffs) || []
        buffs.each_with_index do |level,id|
          next if level==0
          turns=hash_of(actor,:@buff_turns)[id]
          timing=defined?(ATB::BUFF_TURN_COUNT) && ATB::BUFF_TURN_COUNT==1 ? 'завершений действия' : 'завершений хода'
          value=level*25
          rows << {:name=>PARAMS[id]+(level>0 ? ' +' : ' ')+value.to_s+'%',:summary=>'Уровень '+level.to_s+'; осталось '+turns.to_s,
            :details=>['Изменение параметра: '+value.to_s+'%.','Уровень: '+level.to_s,'Осталось '+timing+': '+turns.to_s,'Источник наложения не сохранён игрой.'],:kind=>:buff,:id=>id}
        end
        cooldowns=hash_of($game_temp,:@cool_time)
        counts=cooldowns.has_key?(actor) ? cooldowns[actor] : {}
        counts.keys.sort.each do |id|
          count=counts[id];next unless count>0
          rows << {:name=>named($data_skills,id,'Навык'),:summary=>'Откат: '+count.to_s,:details=>['Откат: '+count.to_s,'Счётчик уменьшается в конце хода.','Число обозначает текущий счётчик, а не будущие пропущенные ходы.'],:kind=>:cooldown,:id=>id}
        end
        [ [actor,:@hzm_vxa_quickSkill_can_use_skill,$data_skills,'Мгновенный навык'],
          [defined?(HZM_VXA::QuickSkill::ITEM_COUNT_PARTY) && HZM_VXA::QuickSkill::ITEM_COUNT_PARTY ? $game_party : actor,:@hzm_vxa_quickSkill_can_use_item,$data_items,'Мгновенный предмет'] ].each do |owner,key,data,kind|
          list=owner.instance_variable_get(key)
          next unless list.is_a?(Array)
          list.uniq.each do |id|
            object=data[id];next unless object
            m=/\[hzm\](?:ターン消費無し|即発動|QuickSkill)\s*[:：]\s*(\d+)/.match(object.note)
            next unless m
            count=list.count(id);limit=[m[1].to_i,1].max
            rows << {:name=>BS2Modules.label(object),:summary=>'Мгновенно: '+count.to_s+'/'+limit.to_s,
              :details=>[kind,'Использовано в этом ходу: '+count.to_s+' из '+limit.to_s,owner==$game_party ? 'Лимит общий для группы.' : 'Лимит этого персонажа.'],:kind=>:quick,:id=>id}
          end
        end
        rows
      end
      def sources(actor)
        rows=[]
        objects=[['Персонаж',actor.actor],['Класс',actor.class]]
        actor.equips.each_with_index { |object,i| objects << [Vocab.etype(actor.equip_slots[i]).to_s,object] if object }
        # States have their own active entries. Other feature providers remain
        # visible even when a future compatible script adds a provider.
        actor.feature_objects.each do |object|
          next if objects.any? { |x| x[1].equal?(object) } || object.is_a?(RPG::State)
          objects << ['Дополнительный источник',object]
        end
        objects.each do |label,object|
          next unless object
          details=[]
          if object.is_a?(RPG::EquipItem)
            object.params.each_with_index { |v,i| details << PARAMS[i]+': '+(v>0 ? '+' : '')+v.to_s if v!=0 }
            details << object.description.to_s unless object.description.to_s.empty?
          end
          details += object.features.map { |f| feature(f) }+special(object)
          details << 'Дополнительных свойств нет.' if details.empty?
          rows << {:name=>BS2Modules.label(object),:summary=>label,:details=>details,:kind=>:source}
        end
        rows
      end
    end
  end

  # This panel owns its windows explicitly so battle can update only these
  # windows, leaving ATB, messages, queues and all combat RNG completely paused.
  class EffectsPanel
    attr_reader :closed,:list,:detail,:actor,:tab
    def initialize(actor)
      @actor=actor;@tab=0;@closed=false
      @header=Header.new
      @list=List.new(0,72,228,Graphics.height-72)
      @detail=Lines.new(228,72,Graphics.width-228,Graphics.height-72)
      @list.set_handler(:ok,method(:focus_detail))
      @list.set_handler(:cancel,method(:close))
      @detail.set_handler(:cancel,method(:focus_list))
      @list.activate
      rebuild
    end
    def rebuild
      @rows=@tab==0 ? Effects.active(@actor) : Effects.sources(@actor)
      @rows=[{:name=>'Нет активных эффектов',:summary=>'',:details=>['Состояния, изменения параметров и откаты отсутствуют.']}] if @rows.empty?
      @header.text=['Эффекты — '+@actor.name+' | '+(@tab==0 ? 'Действующие' : 'Источники')+' ('+@rows.size.to_s+')',
        '←/→ раздел  ·  Q/E персонаж  ·  Enter подробности  ·  Esc назад']
      @list.set_rows(@rows);@last=-1
      update_detail
    end
    def update_detail
      return if @last==@list.index
      @last=@list.index
      row=@rows[@last]
      @detail.set_lines([row[:name],'']+row[:details])
    end
    def focus_detail;@detail.activate;end
    def focus_list;@detail.deactivate;@list.activate;end
    def close;@closed=true;end
    def update
      return if @closed
      if @list.active
        if Input.trigger?(:LEFT) || Input.trigger?(:RIGHT)
          @tab=1-@tab;Sound.play_cursor;rebuild
        elsif Input.trigger?(:L) || Input.trigger?(:R)
          party=$game_party.members
          index=party.index(@actor) || 0
          @actor=party[(index+(Input.trigger?(:R) ? 1 : -1))%party.size]
          Sound.play_cursor;rebuild
        end
      end
      @list.update;@detail.update;update_detail
    end
    def dispose
      [@header,@list,@detail].each { |w| w.dispose unless w.disposed? }
    end
  end

  class EffectsScene < Scene_MenuBase
    def start
      super
      @panel=EffectsPanel.new($game_party.menu_actor || $game_party.members[0])
    end
    def update
      super
      @panel.update
      return_scene if @panel.closed
    end
    def terminate
      @panel.dispose if @panel
      super
    end
  end
end
