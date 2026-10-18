# encoding: UTF-8
# Reference metadata; numerical forecasts use a separate bounded arithmetic parser.
module BS2QoL
  module Reference
    class << self
      attr_reader :error
      def path; File.join(Dir.pwd,'BS2QoL','reference.ini'); end
      def language
        return @language if @language
        @language=:ru
        if File.file?(path) && File.size(path)<128
          text=File.open(path,'rb') { |f| f.read }
          @language=:en if text.strip=='language=en'
        end
        @language
      rescue StandardError
        @error=:read_failed;@language=:ru
      end
      def language=(value)
        @language=value==:en ? :en : :ru
        Dir.mkdir(File.dirname(path)) unless File.directory?(File.dirname(path))
        File.open(path+'.tmp','wb') { |f| f.write('language='+@language.to_s+"\n");f.flush }
        File.rename(path+'.tmp',path)
        @error=nil
      rescue StandardError
        @error=:write_failed
      end
      def supported?(object); object.is_a?(RPG::Skill) || object.is_a?(RPG::Item); end
    end
  end
  class ReferenceCard
    attr_reader :object,:resolved,:actor,:language,:sections
    def initialize(object,actor=nil,language=:ru)
      raise ArgumentError,'Usable item required' unless Reference.supported?(object)
      @object=object;@actor=actor;@language=language;@resolved=object
      if actor && object.is_a?(RPG::Skill)
        @resolved=$data_skills[object.skill_change_state(actor,object.id)] || object
      end
      @sections=[overview,effects,damage,rules]
    end
    def t(ru,en);@language==:en ? en : ru;end
    def n(value);value.to_f==value.to_i ? value.to_i.to_s : ('%.4f'%value).sub(/0+\z/,'');end
    def pct(value);n(value*100)+'%';end
    def kind(object)
      return :skill if object.is_a?(RPG::Skill)
      return :item if object.is_a?(RPG::Item)
      return :weapon if object.is_a?(RPG::Weapon)
      return :armor if object.is_a?(RPG::Armor)
      :state
    end
    def name(object)
      return '?' unless object
      data=ReferenceData::EN[kind(object)][object.id] if @language==:en && ReferenceData::EN[kind(object)]
      data ? data[0] : object.name
    end
    def tagged(object);name(object)+' [#'+object.id.to_s+']';end
    def title;tagged(@object);end
    def param(id)
      t(['Макс. ОЗ','Макс. ОМ','АТК','ЗАЩ','МАГ','МЗЩ','СКР','УДЧ'],['Max HP','Max MP','ATK','DEF','MAT','MDF','AGI','LUK'])[id] || '?'
    end
    def element(id)
      names=t(['Нет','Физический','Поглощение','Огонь','Лёд','Молния','','','Против сна','Свет','Тьма','Двойное кровотечение','Хельвздох','Против зверей','Против Бармаглота','Двойное оглушение','Против уязвимости','Падение','Против яда','Против рапир'],
      ['None','Physical','Absorb','Fire','Ice','Lightning','','','Vs sleep','Light','Dark','Double bleeding','Helbreath','Vs beasts','Vs Jabberwock','Double stun','Vs vulnerability','Falling','Vs poison','Vs rapiers'])
      (names[id] && names[id]!='' ? names[id] : t('Элемент','Element')+' #'+id.to_s)
    end
    def section_names;t(['Обзор','Эффекты','Урон','Правила'],['Overview','Effects','Damage','Rules']);end
    def read_cooldown(skill)
      return 0 unless actor && $game_temp
      local=actor.instance_variable_get(:@bs2s_cooldowns)
      return [local.fetch(skill.id,0),0].max if local
      hash=$game_temp.instance_variable_get(:@cool_time)
      hash && hash.has_key?(actor) && hash[actor].has_key?(skill.id) ? [hash[actor][skill.id],0].max : 0
    end
    def costs(skill)
      unless actor
        parts=['MP '+skill.mp_cost.to_s,'TP '+skill.tp_cost.to_s]
        parts << 'HP '+skill.hp_cost.to_s if skill.hp_cost>0
        parts << 'HP '+skill.mhp_cost_rate.to_s+'% MaxHP' if skill.mhp_cost_rate>0
        parts << 'HP '+skill.hp_cost_rate.to_s+'% HP' if skill.mhp_cost_rate==0 && skill.hp_cost_rate>0
        parts << 'MP '+skill.mmp_cost_rate.to_s+'% MaxMP' if skill.mmp_cost_rate>0
        parts << 'MP '+skill.mp_cost_rate.to_s+'% MP' if skill.mmp_cost_rate==0 && skill.mp_cost_rate>0
        parts << 'TP '+skill.tp_cost_rate.to_s+'% TP' if skill.tp_cost_rate>0
        parts << t('Души ','Souls ')+skill.gold_cost.to_s if skill.gold_cost>0
        parts << t('Души ','Souls ')+skill.gold_cost_rate.to_s+'%' if skill.gold_cost_rate>0
        parts << tagged($data_items[skill.item_cost])+' x1' if $data_items[skill.item_cost]
        return parts.join(' / ')+t(' (база; цена персонажа меняется)',' (base; actor cost varies)')
      end
      values=[['HP',actor.skill_hp_cost(skill)],['MP',actor.skill_mp_cost(skill)],['TP',actor.skill_tp_cost(skill)],
        [t('Души','Souls'),actor.skill_gold_cost(skill)]]
      text=values.map { |label,value| label+' '+n(value) }.join(' / ')
      item=$data_items[skill.item_cost];text+=' + '+tagged(item)+' x1' if item
      text
    end
    def quick_info(item)
      match=/\[hzm\](?:ターン消費無し|即発動|QuickSkill)\s*[:：]\s*(\d+)/.match(item.note)
      return nil unless match
      limit=[match[1].to_i,1].max
      owner=item.is_a?(RPG::Item) ? $game_party : actor
      key=item.is_a?(RPG::Item) ? :@hzm_vxa_quickSkill_can_use_item : :@hzm_vxa_quickSkill_can_use_skill
      counts=owner && owner.instance_variable_get(key)
      [limit,counts ? counts.count(item.id) : 0]
    end
    def overview
      x=@resolved;lines=[]
      lines << t('Пользователь: ','User: ')+actor.name if actor
      lines << t('Действующий вариант: ','Current variant: ')+tagged(x) if x!=@object
      lines << (actor ? t('Цена сейчас: ','Current cost: ') : t('Базовая цена: ','Base cost: '))+costs(x) if x.is_a?(RPG::Skill)
      lines << t('Цена выбора исходного навыка: ','Original skill selection cost: ')+costs(@object) if x!=@object
      if x.is_a?(RPG::Item)
        lines << t('В наличии: ','Owned: ')+(actor && $game_party ? $game_party.item_number(x).to_s : t('зависит от сохранения','depends on save'))+t(' | Расходуется: ',' | Consumable: ')+(x.consumable ? t('да','yes') : t('нет','no'))
        lines << t('Базовая цена: ','Database price: ')+x.price.to_s+t(' душ; это не цена продажи.',' souls; not the selling price.')
      end
      scopes=t(['Без цели','Один враг','Все враги','1 случайный враг','2 случайных врага','3 случайных врага','4 случайных врага','Один живой союзник','Все живые союзники','Один павший союзник','Все павшие союзники','Пользователь'],
        ['No target','One enemy','All enemies','1 random enemy','2 random enemies','3 random enemies','4 random enemies','One living ally','All living allies','One fallen ally','All fallen allies','User'])
      lines << t('Цель: ','Target: ')+(scopes[x.scope] || '?')+t(' | Повторов на цель: ',' | Repeats per target: ')+x.repeats.to_s
      if actor && x.is_a?(RPG::Skill) && x.id==actor.attack_skill_id && x.for_one? && x.for_opponent? && !x.for_random?
        lines << t('Это текущая обычная атака: множитель повторов цели ×','This is the current normal attack: target repeats x')+(1+actor.atk_times_add.to_i).to_s+'.'
      end
      lines << t('Применение: ','Use: ')+t(['Бой и поле','Только бой','Только поле','Не используется напрямую'],['Battle and field','Battle only','Field only','Cannot be used directly'])[x.occasion]
      if (q=quick_info(x))
        lines << t('Мгновенно, без расхода слота действия.','Instant; does not consume an action slot.')
        lines << t('Лимит на ход: ','Uses per turn: ')+q[0].to_s+(actor ? t('; использовано: ','; used: ')+q[1].to_s : '')+(x.is_a?(RPG::Item) ? t(' (вся группа)',' (whole party)') : t(' (этот персонаж)',' (this actor)'))
      else
        lines << t('Обычное действие: занимает слот очереди.','Regular action: takes an action slot.') if x.battle_ok?
      end
      if actor && x.is_a?(RPG::Item)
        reasons=[]
        reasons << t('нет в инвентаре','not in inventory') if $game_party.item_number(x)==0
        reasons << t('пользователь не может действовать','user cannot act') unless actor.movable?
        reasons << t('не то место применения','wrong battle/field context') unless actor.occasion_ok?(x)
        reasons << t('команда предметов запечатана','item command sealed') if $game_party.in_battle && actor.item_command_seal?
        reasons << t('мгновенный лимит исчерпан','instant-use limit reached') if q && q[1]>=q[0]
        lines << t('Ограничения сейчас: ','Current restrictions: ')+reasons.join('; ')+'.' unless reasons.empty?
      end
      if x.is_a?(RPG::Skill)
        if (m=/<クールタイム:(\d+)>/.match(x.note))
          lines << t('КД: начальный счётчик ','Cooldown: initial counter ')+(m[1].to_i+1).to_s+(actor ? t('; осталось сейчас ','; remaining now ')+read_cooldown(x).to_s : '')+'.'
          lines << t('Счётчик уменьшается на 1 в конце хода. Это не число будущих пропущенных ходов.','Counter falls by 1 at turn end. It is not the number of future skipped turns.')
        else
          lines << t('КД: нет.','Cooldown: none.')
        end
        required=[x.required_wtype_id1,x.required_wtype_id2].reject { |id| id==0 }
        lines << t('Требуемые типы оружия (любой): ','Required weapon types (either): ')+required.map { |id| weapon_type(id) }.join(' / ') unless required.empty?
        if actor
          lines << (actor.skill_learn?(@object) ? t('Навык изучен постоянно.','Permanently learned.') : t('Навык не изучен постоянно.','Not permanently learned.'))
          sources=actor.equips.compact.select { |eq| eq.features.any? { |f| f.code==43 && f.data_id==@object.id } }
          lines << t('Доступ от экипировки: ','Granted by equipment: ')+sources.map { |eq| name(eq) }.join(', ') unless sources.empty?
          reasons=[]
          reasons << t('нет доступа к навыку','skill not granted') unless actor.skills.include?(@object)
          reasons << t('нельзя действовать','cannot act') unless actor.movable?
          reasons << t('не подходит оружие','wrong weapon type') unless actor.skill_wtype_ok?(@object)
          reasons << t('навык или тип запечатан','skill or skill type sealed') if actor.skill_sealed?(@object.id) || actor.skill_type_sealed?(@object.stype_id)
          reasons << t('не хватает ресурсов','insufficient resources') unless actor.skill_cost_payable?(@object)
          reasons << t('действует КД','on cooldown') if read_cooldown(@object)>0
          reasons << t('не то место применения','wrong battle/field context') unless actor.occasion_ok?(@object)
          reasons << t('мгновенный лимит исчерпан','instant-use limit reached') if q && q[1]>=q[0]
          lines << t('Ограничения сейчас: ','Current restrictions: ')+reasons.join('; ')+'.' unless reasons.empty?
          lines << t('При замене условия выбора проверяются по исходному навыку, цена исполнения — по варианту.','For a variant, selection requirements use the original skill; execution costs use the variant.') if x!=@object
        end
      end
      lines << t('Модификатор скорости: ','Action speed modifier: ')+x.speed.to_s+t(' (не готовый порядок ходов).',' (not the final action order).')
      data=ReferenceData::EN[kind(@object)][@object.id] if @language==:en
      description=data ? data[1] : @object.description
      lines << t('Текст игры (может быть неточен):','Original game description (may be imprecise):')
      lines += description.split(/\r?\n/)
      lines
    end
    def weapon_type(id)
      labels=t(['','Топор','Когти','Копьё','Меч','Катана','Лук','Кинжал','Молот','Посох','Огнестрел'],['','Axe','Claws','Spear','Sword','Katana','Bow','Dagger','Hammer','Staff','Gun'])
      (labels[id] || '?')+' [#'+id.to_s+']'
    end
    def effect_lines(item,expanded=true)
      lines=[]
      item.effects.each do |e|
        id=e.data_id;v=e.value1;w=e.value2
        case e.code
        when 11,12
          resource=e.code==11 ? 'HP' : 'MP'
          base=(e.code==11 ? 'MaxHP' : 'MaxMP')+' * '+n(v)+' + '+n(w)
          multiplier='REC'+(item.is_a?(RPG::Item) ? ' * PHA' : '')
          lines << t('Восстановление ','Recovery of ')+resource+': trunc(('+base+') * '+multiplier+').'
          lines << t('REC — восстановление цели; PHA — эффективность предметов пользователя. Отрицательное число наносит урон.','REC is the target recovery rate; PHA is the user item effectiveness. Negative values cause damage.')
          lines << t('Запрет или инверсия лечения у цели может отменить или обратить восстановление.','Target recovery immunity or reversal can cancel or invert healing.')
        when 13
          lines << t('Цели: TP +','Target: TP +')+v.to_i.to_s+'.'
        when 21
          if id==0
            lines << t('Наложение состояний обычной атаки: база ','Apply normal attack states: base ')+pct(v)+t(' × шанс оружия/состояния × сопротивление цели × удача.',' × attack-state rate × target state rate × luck.')
            if actor
              actor.atk_states.each { |sid| lines << '  '+tagged($data_states[sid])+': '+pct(actor.atk_states_rate(sid)) }
            end
          else
            chance=pct(v)
            chance+=t(' × сопротивление состояния',' × target state rate') unless item.note.include?('<有効度無視ステート付与>') || item.note.include?('<強制付与>')
            chance+=t(' × удача',' × luck') unless item.note.include?('<運無視ステート付与>') || item.note.include?('<強制付与>')
            lines << t('Наложить ','Apply ')+tagged($data_states[id])+': '+chance+'.'
            lines << t('Множители сопротивления и удачи для обычного эффекта действуют только на противника. Иммунитет состояния проверяется отдельно.','For ordinary state effects, state-rate and luck multipliers apply only to opponents. State immunity is checked separately.')
            lines += state_lines($data_states[id]) if expanded && $data_states[id]
          end
        when 22
          lines << t('Снять ','Remove ')+tagged($data_states[id])+': '+pct(v)+'.'
        when 31,32
          lines << (e.code==31 ? t('Усиление ','Buff ') : t('Ослабление ','Debuff '))+param(id)+': '+v.to_i.to_s+t(' ход.; шаг 25%, максимум 2 ступени.',' turns; 25% per stack, up to 2 stacks.')
          if e.code==32
            lines << t('Шанс: сопротивление ослаблению','Chance: target debuff rate')+((item.note.include?('<運無視弱体付与>') || item.note.include?('<強制付与>')) ? '.' : t(' × удача.',' × luck.'))
          end
        when 33,34
          lines << (e.code==33 ? t('Снять усиление ','Remove buff ') : t('Снять ослабление ','Remove debuff '))+param(id)+'.'
        when 41
          lines << t('Цель покидает бой (побег).','Target leaves battle (escape).')
        when 42
          lines << t('Постоянная прибавка к базовой характеристике: ','Permanent base stat increase: ')+param(id)+' +'+v.to_i.to_s+'.'
        when 43
          lines << t('Изучить навык: ','Learn skill: ')+tagged($data_skills[id])+'.'
          lines << (actor && actor.skill_learn?($data_skills[id]) ? t('Уже изучен этим персонажем.','Already learned by this actor.') : t('Выдача навыка экипировкой не равна изучению.','An equipment-granted skill is not permanent learning.'))
        when 44
          lines += event_lines(id)
        else
          lines << t('Дополнительный эффект требует разбора: ','Additional effect needs review: ')+[e.code,id,v,w].join(', ')
        end
      end
      lines
    end
    def state_lines(state)
      lines=[]
      restrictions=t(['Нет ограничения действий','Атакует противника','Атакует случайную сторону','Атакует союзника','Не может действовать'],['No action restriction','Attacks enemies','Attacks either side','Attacks allies','Cannot act'])
      lines << '  '+(restrictions[state.restriction] || '?')+'.' if state.restriction>0
      if state.auto_removal_timing>0
        lines << '  '+t('Срок счётчика: ','Duration counter: ')+state.min_turns.to_s+'..'+state.max_turns.to_s+
          (state.auto_removal_timing==1 ? t('; удаление после действия.','; removal after action.') : t('; удаление в конце хода.','; removal at turn end.'))
        lines << '  '+t('ATB может уменьшать длительность перед действием; это не обещание N собственных ходов.','ATB may decrease duration before an action; this does not promise N player turns.')
      end
      lines << '  '+t('Снимается в конце боя.','Removed at battle end.') if state.remove_at_battle_end
      lines << '  '+t('Шанс снятия при уроне: ','Removal chance on damage: ')+state.chance_by_damage.to_s+'%.' if state.remove_by_damage
      lines << '  '+t('Снятие при движении: ','Walking removal after ')+state.steps_to_remove.to_s+t(' шагов.',' steps.') if state.remove_by_walking
      state.features.each { |f| lines << '  '+feature_line(f) }
      lines += note_rules(state).map { |line| '  '+line }
      state.note.scan(/<反撃スキル\s*(\d+)\s*>/).each { |m| lines << '  '+t('Контратака заменяется на ','Counterattack replaced by ')+tagged($data_skills[m[0].to_i]) }
      state.note.scan(/<強制自然解除時ステート[:：]([^>]+)>/).each do |m|
        lines << '  '+t('При естественном истечении добавляет: ','On natural expiry adds: ')+m[0].split(',').map { |s| tagged($data_states[s.to_i]) }.join(', ')+t(' (кроме очистки в конце боя).',' (except battle-end cleanup).')
      end
      state.note.scan(/<全回避時スキル[:：](\d+)(?:,([^>]+))?>/).each { |id,chance| lines << '  '+t('После уклонения от врага: ','After evading an opponent: ')+tagged($data_skills[id.to_i])+'; '+(chance || '100')+t('%, если доступно; расходует цену.','% if usable; pays its cost.') }
      lines << '  '+t('Запрещает команду предметов.','Seals the item command.') if state.note.include?('<アイテム封印>')
      lines
    end
    def feature_line(f)
      id=f.data_id;v=f.value
      case f.code
      when 11;t('Множитель урона элемента ','Element damage rate ')+element(id)+' x'+n(v)
      when 12;t('Вероятность ослабления ','Debuff rate ')+param(id)+' x'+n(v)
      when 13;t('Вероятность состояния ','State rate ')+tagged($data_states[id])+' x'+n(v)
      when 14;t('Иммунитет: ','Immune: ')+tagged($data_states[id])
      when 21;param(id)+' x'+n(v)
      when 22
        labels=t(['Попадание','Уклонение','Шанс крита','Защита от крита','Маг. уклонение','Отражение магии','Контратака','Регенерация HP','Регенерация MP','Регенерация TP'],['Hit','Evasion','Critical chance','Critical evasion','Magic evasion','Magic reflection','Counterattack','HP regeneration','MP regeneration','TP regeneration'])
        (labels[id] || '?')+' '+(v>=0 ? '+' : '')+pct(v)
      when 23
        labels=t(['Вероятность стать целью TGR','Усиление обороны GRD','Восстановление REC','Эффективность предметов PHA','Расход MP MCR','Набор TP TCR','Физический урон PDR','Магический урон MDR','Урон пола FDR','Опыт EXR'],['Target rate TGR','Guard strength GRD','Recovery REC','Item effectiveness PHA','MP cost MCR','TP charge TCR','Physical damage PDR','Magic damage MDR','Floor damage FDR','Experience EXR'])
        (labels[id] || '?')+' x'+n(v)
      when 31;t('Элемент обычной атаки: ','Normal attack element: ')+element(id)
      when 32;t('Состояние обычной атаки: ','Normal attack state: ')+tagged($data_states[id])+' '+pct(v)
      when 33;t('Скорость обычной атаки +','Normal attack speed +')+n(v)
      when 34;t('Дополнительные повторения обычной атаки: ','Extra normal attack repeats: ')+n(v)
      when 41;t('Открывает тип навыков #','Grants skill type #')+id.to_s
      when 42;t('Запрещает тип навыков #','Seals skill type #')+id.to_s
      when 43;t('Даёт навык: ','Grants skill: ')+tagged($data_skills[id])
      when 44;t('Запрещает навык: ','Seals skill: ')+tagged($data_skills[id])
      when 51;t('Разрешает тип оружия #','Allows weapon type #')+id.to_s
      when 52;t('Разрешает тип брони #','Allows armor type #')+id.to_s
      when 53;t('Фиксирует слот экипировки #','Locks equipment type #')+id.to_s
      when 54;t('Запрещает слот экипировки #','Seals equipment type #')+id.to_s
      when 55;t('Тип слотов: ','Slot type: ')+id.to_s
      when 61;t('Отдельный шанс ещё одного действия: ','Independent extra-action chance: ')+pct(v)
      when 62;t(['Автобой','Оборона (Guard)','Прикрывает союзника','Сохранение TP'],['Auto battle','Guard','Substitute','Preserve TP'])[id] || '?'
      when 63;t('Тип исчезновения #','Collapse type #')+id.to_s
      when 64;t('Способность группы #','Party ability #')+id.to_s
      else;t('Не разобран признак: ','Unmapped feature: ')+[f.code,id,v].join(', ')
      end
    end
    def effects
      x=@resolved;lines=effect_lines(x)
      lines << t('Прямых эффектов из списка нет. См. урон и правила.','No direct listed effects. See damage and rules.') if lines.empty?
      lines << t('Эффекты применяются по порядку после попадания, отдельно для каждого повторения. Событие запускается один раз при использовании.','Effects apply in order after a hit, for each repeat. A common event is reserved once on use.')
      lines << t('Пользователю за попадание: TP +','User gains on each hit: TP +')+x.tp_gain.to_s+' * TCR.' if x.tp_gain!=0
      lines << t('Удача: max(1 + (УДЧ пользователя - УДЧ цели) * 0.001, 0).','Luck: max(1 + (user LUK - target LUK) * 0.001, 0).')
      lines
    end
    def damage
      x=@resolved;d=x.damage;lines=[]
      types=t(['Нет отдельного урона формулой','Урон HP','Урон MP','Восстановление HP','Восстановление MP','Поглощение HP','Поглощение MP'],['No separate formula damage','HP damage','MP damage','HP recovery','MP recovery','HP drain','MP drain'])
      lines << (types[d.type] || '?')+'.'
      if d.type!=0
        lines << t('Базовая формула за одно попадание:','Base formula per hit:')
        lines << d.formula
        readable=d.formula.gsub(/\b([ab])\.(mhp|mmp|atk|def|mat|mdf|agi|luk)\b/) do
          side=$1;stat=$2;id={'mhp'=>0,'mmp'=>1,'atk'=>2,'def'=>3,'mat'=>4,'mdf'=>5,'agi'=>6,'luk'=>7}[stat]
          param(id)+t(side=='a' ? ' пользователя' : ' цели',side=='a' ? ' of user' : ' of target')
        end
        lines << readable if readable!=d.formula
        lines << t('a — пользователь; b — цель; v[n] — переменная игры. max(формула, 0); для лечения знак меняется.','a = user; b = target; v[n] = game variable. max(formula, 0); recovery reverses the sign.')
        stats={'mhp'=>0,'mmp'=>1,'atk'=>2,'def'=>3,'mat'=>4,'mdf'=>5,'agi'=>6,'luk'=>7}
        d.formula.scan(/\b([ab])\.([a-z_]+)\b/).uniq.each do |side,stat|
          next if stat=='state'
          labels={'hp'=>t('текущие ОЗ','current HP'),'mp'=>t('текущие ОМ','current MP'),'tp'=>t('текущие TP','current TP'),'level'=>t('уровень','level')}
          label=stats.has_key?(stat) ? param(stats[stat]) : (labels[stat] || stat.upcase)
          value=actor && side=='a' && (stats.has_key?(stat) || ['hp','mp','tp','level'].include?(stat)) ? ' = '+n(actor.send(stat)) : ''
          lines << side+'.'+stat+': '+t(side=='a' ? 'пользователь, ' : 'цель, ',side=='a' ? 'user, ' : 'target, ')+label+value
        end
        d.formula.scan(/([ab])\.state\?\((\d+)\)\s*\?\s*(\d+)\s*:\s*(\d+)/).each do |side,id,yes,no|
          lines << t('Условный множитель: если ','Conditional multiplier: if ')+t(side=='a' ? 'у пользователя ' : 'у цели ',side=='a' ? 'user has ' : 'target has ')+tagged($data_states[id.to_i])+' -> x'+yes+t(', иначе x',', otherwise x')+no+'.'
        end
        lines << t('[выражение, предел].min выбирает меньшее число: это верхнее ограничение множителя.','[expression, cap].min takes the smaller value: an upper cap on the multiplier.') if d.formula.include?('].min')
        lines << t('Целочисленное деление Ruby округляет вниз на каждом таком шаге. Числа по целям — во вкладке «Прогноз», без исполнения произвольного Ruby-кода.','Ruby integer division rounds down at each integer division. Target numbers are in Forecast, without executing arbitrary Ruby code.')
        lines << t('Элемент: ','Element: ')+(d.element_id<0 ? t('элементы обычной атаки, лучший множитель цели.','normal attack elements; uses the highest target rate.') : element(d.element_id)+'.')
        lines << t('Элементы пользователя сейчас: ','Current user attack elements: ')+actor.atk_elements.map { |id| element(id) }.join(', ')+'.' if d.element_id<0 && actor
        lines << t('Порядок: формула → элемент → PDR/MDR → REC для лечения → крит → разброс → Guard → целое.','Order: formula > element > PDR/MDR > REC for recovery > critical > variance > Guard > integer.')
        lines << t('PDR только при физическом типе попадания; MDR только при магическом. Элемент — отдельный множитель.','PDR applies only to physical hit type; MDR only to magical hit type. Element is a separate multiplier.')
        crit=Hi_ru_Difficulty::DIFFICULTY_SETTING[11][$game_variables[Hi_ru_Difficulty::VARIABLES]]
        lines << (d.critical ? t('Крит разрешён: шанс CRI пользователя × (1 - CEV цели); урон ×','Can crit: chance = user CRI * (1 - target CEV); damage x')+n(crit)+'.' : t('Крит невозможен для этой записи.','This record cannot crit.'))
        lines << t('Разброс: ±','Variance: +/-')+d.variance.to_s+t('% с треугольным распределением (сумма двух бросков).','% with a triangular distribution (sum of two rolls).')
        lines << t('Оборона цели: деление положительного урона на 2 × GRD, если не сработал обход Guard.','Target Guard divides positive damage by 2 * GRD unless Guard bypass succeeds.')
      end
      lines << t('Тип попадания: ','Hit type: ')+t(['Гарантированный базовый','Физический','Магический'],['Base certain hit','Physical','Magical'])[x.hit_type]+'.'
      hit=n(x.success_rate)+'%'+(x.physical? ? ' * HIT' : '')
      lines << t('Проверка успеха: ','Success check: ')+hit+t('; затем ','; then ')+(x.physical? ? t('EVA цели.','target EVA.') : (x.magical? ? t('MEV цели.','target MEV.') : t('обычного уклонения нет.','no ordinary evasion.')))
      lines << t('Абсолютное попадание/уклонение от состояний может заменить эти проверки; в этой сборке приоритет у попадания.','Absolute-hit/evasion traits can override these checks; this build prioritizes absolute hit.')
      lines << t('Техника может быть полностью отменена защитой от конкретного ID; это отдельная проверка перед попаданием.','A skill may be cancelled by immunity to its specific ID, checked before hit rolls.') if x.is_a?(RPG::Skill)
      counter=x.note.include?('<反撃不可>') ? false : (x.note.include?('<反撃可能>') || x.physical?)
      lines << (counter ? t('Противник может контратаковать по CNT.','An opponent may counter using CNT.') : t('Обычная контратака не вызывается.','Does not trigger normal counterattacks.'))
      lines << t('Магия может отражаться по MRF цели.','Magic may be reflected using target MRF.') if x.magical?
      lines << t('Точного урона без цели нет: её защита, состояния и сопротивления участвуют в расчёте.','No exact damage without a target: its defenses, states and resistances affect the result.') unless d.type==0
      lines
    end
    def note_rules(x)
      note=x.note;lines=[]
      note.scan(/<防御状態無視率[:：]([^>]+)>/).each { |m| lines << t('Обход именно Guard: порог ','Guard bypass threshold: ')+m[0]+t('% + пассивные источники пользователя. Этот тег управляет Guard отдельно от ЗАЩ в формуле.','% + user passive sources. This tag controls Guard separately from DEF in the formula.') }
      note.scan(/<ダメージ率貫通追加[:：]([^>]+)>/).each { |m| lines << t('Проникновение через PDR/MDR: дополнительно ','Additional PDR/MDR penetration: ')+m[0]+'%.' }
      note.scan(/<ダメージ率貫通[:：](\d+),([^>]+)>/).each do |type,value|
        if x.is_a?(RPG::UsableItem)
          lines << t('Записан пассивный тег проникновения ','Passive penetration tag: ')+type+', '+value+t('%. У навыка/предмета сам по себе не применяется: этот тег читается только у источников признаков персонажа.','%. On a skill/item it has no standalone effect: this tag is read only from the user feature objects.')
        else
          lines << t('Проникновение через ','Penetration through ')+(type=='1' ? 'PDR ' : 'MDR ')+value+'%.'
        end
      end
      note.scan(/<(?:全|必中|物理|魔法)絶対(?:命中|回避)>|<絶対命中>/).each do |tag|
        labels={'全'=>t('все типы','all types'),'必中'=>t('базовый гарантированный','base certain'),'物理'=>t('физический','physical'),'魔法'=>t('магический','magical')}
        label=labels.find { |key,val| tag.include?(key) }
        lines << (tag.include?('回避') ? t('Абсолютное уклонение: ','Absolute evasion: ') : t('Абсолютное попадание: ','Absolute hit: '))+(label ? label[1] : t('этот приём','this action'))+'.'
      end
      note.scan(/<スキル無効[:：](\d+)(?:,([^>]+))?>/).each { |sid,chance| lines << t('Отмена входящего навыка ','Cancels incoming skill ')+tagged($data_skills[sid.to_i])+t('; порог ','; threshold ')+(chance || '100')+'%.' }
      ['HP','MP','TP'].each do |resource|
        note.scan(/<#{resource}変換攻撃[:：]([^>]+)>/).each { |m| lines << t('Возврат пользователю ','User conversion to ')+resource+': '+m[0]+t(' (процент урона HP, шанс). Требуется проверка конверсии приёма.',' (percent of HP damage, chance). Requires the action conversion roll.') }
      end
      note.scan(/<変換攻撃判定[:：]([^>]+)>/).each { |m| lines << t('Шанс запуска конверсии урона: ','Damage conversion trigger chance: ')+m[0]+'%.' }
      ['HP','MP'].each do |resource|
        [['回復無効',t('запрет восстановления','recovery immunity')],['回復反転',t('инверсия восстановления','recovery reversal')]].each do |tag,label|
          note.scan(/<#{resource}#{tag}[:：]([^>]+)>/).each { |m| lines << resource+': '+label+' '+m[0]+'%.' }
        end
      end
      lines
    end
    def rules
      x=@resolved;lines=note_rules(x)
      x.note.scan(/<使用者効果\s*(\d+)\s*>/).each do |m|
        linked=$data_skills[m[0].to_i];next unless linked
        lines << t('После применения в бою на пользователя отдельно: ','After battle use, separately applies to the user: ')+tagged(linked)
        lines += effect_lines(linked,false).map { |s| '  '+s }
        lines << '  '+t('Также формула: ','Also formula: ')+linked.damage.formula unless linked.damage.none?
      end
      @object.note.scan(/<ステート変化:(\d+),(\d+)>/).each do |sid,state|
        lines << t('При состоянии ','With state ')+tagged($data_states[state.to_i])+t(' выбирается ',' select ')+tagged($data_skills[sid.to_i])+'.'
      end
      lines << t('Если условий несколько, побеждает последнее подходящее в этом списке. Вариант фиксируется при выборе команды.','If multiple conditions match, the last match wins. The variant is fixed when the command is selected.') if @object.note.include?('<ステート変化:')
      x.note.scan(/<使用後追加行動[:：]([^>]+)>/).each do |m|
        parts=m[0].split(',');sid=parts[0];target=parts[1];threshold=parts[2] || '100'
        linked=/\A\d+\z/ =~ sid ? $data_skills[sid.to_i] : nil
        chance=/\A-?\d+(?:\.\d+)?\z/ =~ threshold ? [[threshold.to_f.floor+1,0].max,100].min.to_s+'%' : t('выражение ','expression ')+threshold
        lines << t('Дополнительное действие после применения: ','Follow-up action after use: ')+(linked ? tagged(linked) : sid)+t('; шанс ','; chance ')+chance+'.'
        lines << t('Цель: ','Target: ')+(target=='-2' ? t('последняя выбранная.','last selected target.') : (target=='-1' ? t('случайная.','random.') : t('индекс ','index ')+target.to_s+'.'))
        lines << t('Вставляется в очередь, только если пользователь способен действовать; имеет собственные условия и цену.','Inserted into the queue only if the user can act; has its own requirements and costs.')
        if linked
          lines << '  '+t('Формула: ','Formula: ')+linked.damage.formula unless linked.damage.none?
          lines += effect_lines(linked,false).map { |s| '  '+s }
        end
        lines << t('Особенность скрипта: порог 50 даёт 51%, порог 0 — 1% (бросок 0..99 включительно).','Script detail: threshold 50 gives 51%; threshold 0 gives 1% (inclusive roll 0..99).') if threshold!='100'
      end
      x.note.scan(/<(行動後遅延発動|遅延発動)[:：]([^>]+)>/).each do |tag,value|
        parts=value.split(',').map { |s| s.to_i };linked=x.is_a?(RPG::Skill) ? $data_skills[parts[1]] : $data_items[parts[1]]
        lines << t('Отложенное применение: ','Delayed use: ')+tagged(linked)+t('; счётчик ','; counter ')+parts[2].to_s+'..'+(parts[2]+(parts[3] || 0)).to_s+t('; шанс ','; chance ')+(parts[4] || 100).to_s+'%.'
        lines << (tag=='行動後遅延発動' ? t('Счётчик проверяется после действий цели.','Counter checked after the target actions.') : t('Счётчик проверяется в конце хода.','Counter checked at turn end.'))+t(' Сначала проверка <= 0, затем уменьшение: исходное N срабатывает на N+1-й проверке.',' Checks <= 0 before decreasing: initial N triggers on check N+1.')
        lines << t('Не применяется, если цель погибла или исчезла.','Does not fire if the target died or disappeared.')
      end
      lines << t('Нельзя положить в хранилище (это не запрет сохранения игры).','Cannot be put in storage (this does not prevent saving the game).') if x.note.include?('<保存禁止>')
      x.note.scan(/ステルス:(\d+)/).each { |m| lines << t('Скрытность от противников на карте: ','Stealth against map enemies: ')+m[0]+t(' шагов.',' steps.') }
      if actor
        sources=actor.feature_objects
        penetration=sources.map { |f| f.note.scan(/<ダメージ率貫通[:：]#{x.hit_type},([^>]+)>/).flatten }.flatten
        lines << t('Проникновение PDR/MDR от текущих признаков: ','PDR/MDR penetration from current traits: ')+penetration.join(' + ')+'%.' unless penetration.empty? || x.hit_type==0
        guard=sources.map { |f| f.note.scan(/<パッシブ防御状態無視率[:：]([^>]+)>/).flatten }.flatten
        guard+=actor.skills.map { |f| f.note.scan(/<パッシブ防御状態無視率[:：]([^>]+)>/).flatten }.flatten
        lines << t('Пассивный обход Guard сейчас: ','Current passive Guard bypass: ')+guard.join(' + ')+'%.' unless guard.empty?
      end
      lines << t('Не все ограничения событий сводятся к боевым числам; условные эффекты помечены отдельно.','Event-dependent restrictions cannot all be reduced to combat numbers; conditional effects are marked separately.') if x.effects.any? { |e| e.code==44 }
      lines << t('Пробой сопротивления: при PDR/MDR < 1 используется 1 - (1 - исходный множитель) × (100 - пробой) / 100, с ограничением 0..1.','Penetration: when PDR/MDR < 1, use 1 - (1 - original rate) * (100 - penetration) / 100, clamped to 0..1.') unless x.damage.none?
      lines << t('Справка ничего не применяет, не бросает случайные числа и не рассчитывает порядок действий.','The reference applies nothing, rolls no random numbers and does not calculate action order.')
      lines
    end
    def event_lines(id)
      event=$data_common_events[id]
      return [t('Событие не найдено #','Missing event #')+id.to_s] unless event
      meaningful=event.list.reject { |c| [0,101,401,250,230].include?(c.code) }
      if meaningful.size==1 && meaningful[0].code==125 && meaningful[0].parameters[1]==0
        p=meaningful[0].parameters
        return [t('Получить души: ','Gain souls: ')+(p[0]==0 ? '+' : '-')+p[2].to_s+'.']
      end
      pair=event_summary(id)
      [t('Событие #','Event #')+id.to_s+': '+(pair ? t(pair[0],pair[1]) : t('Зависит от карты/сюжета/встречи; полный результат ещё не расшифрован.','Depends on map/story/encounter; the full outcome has not yet been decoded.'))]
    end
    def event_summary(id)
      case id
      when 3;['Возврат к костру; запреты и особые точки определяются прогрессом и картой.','Return to bonfire; restrictions and special destinations depend on progress and map.']
      when 13;['Запрашивает призыв товарищей через боевое событие. Состав зависит от встречи.','Requests ally summoning via battle events. Allies depend on the encounter.']
      when 17;['Добавляет предмет #57 в количестве 10.','Adds 10 copies of item #57.']
      when 18;['Если есть потерянные при смерти души, возвращает их сохранённое количество и снимает отметку потери. Иначе возвращает потраченную карту.','If lost souls exist, restores their stored amount and clears the lost-souls marker. Otherwise refunds the card.']
      when 31;['Включает скрытность и сбрасывает шаги. Срок задан конкретным предметом/навыком.','Enables stealth and resets steps. Duration comes from the specific item/skill.']
      when 36;['Теряет все удерживаемые души и переносит в Сон о Библиотеке. Сюжетные запреты могут остановить событие; переход также сбрасывает полевые флаги.','Loses all held souls and transfers to Library Dream. Story restrictions can stop the event; the transfer also resets field flags.']
      when 37;['Включает флаги подготовки и прерываемой зарядки. Реакция зависит от боевого события.','Enables charge and interruptible-charge flags. Reactions depend on battle events.']
      when 38;['Снимает флаг прерываемой зарядки.','Clears the interruptible-charge flag.']
      when 41;['Меню включения/отключения отображения советов.','Opens the show/hide advice menu.']
      when 43;['Выбор обычной или повышенной скорости движения.','Selects normal or fast movement speed.']
      when 44;['Добавляет всем врагам состояние #44.','Adds state #44 to all enemies.']
      when 47;['SEN -30.','SEN -30.']
      when 48;['У всех союзников счётчики КД уменьшаются на 5.','Reduces all ally cooldown counters by 5.']
      when 58;['На карте #54 переносит на карту #136; в других местах перехода нет.','Transfers from map #54 to map #136; no transfer elsewhere.']
      when 59;['На карте #136 переносит на карту #54; в других местах перехода нет.','Transfers from map #136 to map #54; no transfer elsewhere.']
      when 60;['Включает боевой флаг маскировки; конкретная реакция задана встречей.','Enables the battle disguise flag; the encounter defines the response.']
      when 61;['Включает флаг прекращения маскировки; реакция задана встречей.','Sets the end-disguise flag; the encounter defines the response.']
      when 62,63;['Выводит из строя врага в слоте '+(id==62 ? '2' : '3')+'.','Incapacitates the enemy in slot '+(id==62 ? '2' : '3')+'.']
      when 64,66;['Выводит из строя врага в слоте '+(id==64 ? '4' : '1')+'.','Incapacitates the enemy in slot '+(id==64 ? '4' : '1')+'.']
      when 65;['Снимает флаг зарядки, накладывает состояние #37 всем врагам и восстанавливает врага в слоте 1.','Clears the charge flag, applies state #37 to all enemies and fully recovers enemy slot 1.']
      when 72;['Отнимает 10000 HP у всех врагов, допускает смерть.','Subtracts 10000 HP from all enemies, allowing death.']
      when 210;['Добавляет врагу в слоте 1 состояние #29.','Adds state #29 to enemy slot 1.']
      when 218;['Уменьшает счётчики КД всех союзников на 99. Не является безусловным обнулением любого возможного счётчика.','Reduces all ally cooldown counters by 99. This is not unconditional clearing of every possible counter.']
      when 220;['За штуку: базовые макс. HP +300, MP +150, остальные параметры +30; SEN +100. Выбор количества и подтверждение.','Per item: base max HP +300, MP +150, other stats +30; SEN +100. Quantity choice and confirmation.']
      when 221;['За штуку: базовые макс. HP +10, MP +5, остальные параметры +1; SEN -10. Выбор количества и подтверждение.','Per item: base max HP +10, MP +5, other stats +1; SEN -10. Quantity choice and confirmation.']
      when 222;['За штуку: базовые макс. HP +30, MP +15, остальные параметры +3; SEN -30. Выбор количества и подтверждение.','Per item: base max HP +30, MP +15, other stats +3; SEN -30. Quantity choice and confirmation.']
      when 223..230
        index=[0,1,2,3,6,4,5,7][id-223];amount=index==0 ? 20 : (index==1 ? 10 : 2)
        ['За штуку: базовый '+param(index)+' +'+amount.to_s+'. Повышает базовую прибавку, итог учитывает множители. Выбор количества.','Per item: base '+param(index)+' +'+amount.to_s+'. Increases the base bonus; final stats include multipliers. Quantity choice.']
      when 231;['SEN +30 за штуку. Выбор количества и подтверждение.','SEN +30 per item. Quantity choice and confirmation.']
      when 232;['SEN -10 за штуку. Выбор количества и подтверждение.','SEN -10 per item. Quantity choice and confirmation.']
      when 233;['Уровень +5 за штуку до максимума персонажа. Выбор количества; последняя штука может дать меньше 5 уровней.','+5 levels per item, capped at actor maximum. Quantity choice; the last item may grant fewer than 5 levels.']
      when 234;['Меню: установить SEN в 100 или 0; можно отменить.','Menu: set SEN to 100 or 0; can cancel.']
      when 288;['Возврат Старого Короля: особый переход, восстановление и изменение прогресса по условиям события. Полный переход здесь не симулируется.','Old King return: special transfer, recovery and progress changes controlled by event conditions. The transition is not simulated here.']
      when 292;['Снимает у актёров 1..11 экипировку слотов 1..7; оружие в слоте 0 сохраняется.','Removes equipment in slots 1..7 from actors 1..11; weapon slot 0 is retained.']
      when 293;['Включает флаг #31 для обработки текущей встречей. Итог зависит от боевого события.','Sets flag #31 for the current encounter to process. The battle event determines the outcome.']
      when 299;['Переход через событие #276; при специальном сюжетном запрете предмет возвращается.','Transfer via event #276; a special story restriction refunds the item.']
      when 344;['Устанавливает SEN в 100.','Sets SEN to 100.']
      when 345;['Призыв Стены Плоти: проверяет наличие призыва и ограничение события; добавляет союзника #111 с состоянием #167. Дополнительные состояния зависят от сюжетных флагов.','Flesh Wall summon: checks existing summon and event limit; adds ally #111 with state #167. Additional states depend on story flags.']
      when 350;['Снимает у актёров 1..11 экипировку слота 3 (тело).','Removes body-slot equipment (slot 3) from actors 1..11.']
      else;nil
      end
    end
  end
end
