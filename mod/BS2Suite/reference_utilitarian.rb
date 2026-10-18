# encoding: UTF-8
module BS2QoL
  class PracticalCard < ReferenceCard
    attr_reader :section_names
    def initialize(object,actor=nil,language=:ru)
      @object=object;@resolved=object;@actor=actor;@language=language;@sections=[];@section_names=[]
      if object.is_a?(Game_Enemy)
        enemy_card;return
      end
      if object.is_a?(RPG::EquipItem)
        equipment_card;return
      end
      @resolved=$data_skills[object.skill_change_state(actor,object.id)] || object if actor && object.is_a?(RPG::Skill)
      add(t('Применение','Use'),practical_use)
      detail=practical_effects
      add(t('Эффекты','Effects'),detail) unless detail.empty?
      numeric=@resolved.damage.type!=0 || @resolved.effects.any? { |e| [11,12,13].include?(e.code) || (@resolved.for_opponent? && [21,32].include?(e.code)) }
      if numeric
        add(t('По целям','Targets'),compact_forecast)
        add(t('Расчёт','Calculation'),practical_formula) unless @resolved.damage.none?
      end
      extra=note_rules(@resolved)
      add(t('Особенности','Special'),extra) unless extra.empty?
    end
    def add(label,lines)
      values=lines.compact.map { |s| s.to_s.strip }.reject { |s| s.empty? }.uniq
      return if values.empty?
      @section_names<<label;@sections<<values
    end
    def tagged(object);name(object);end
    def name(object)
      return '?' unless object
      if object.is_a?(Game_Enemy)
        en=ReferenceData::EN[:enemy] && ReferenceData::EN[:enemy][object.enemy_id]
        return language==:en && en ? en[0] : object.name
      end
      super
    end
    def title;name(@object);end
    def readable_description
      en=ReferenceData::EN[kind(@object)] && ReferenceData::EN[kind(@object)][@object.id]
      text=language==:en && en ? en[1] : @object.description
      text.to_s.gsub(/\\[A-Za-z]+\[[^\]]*\]/,'').split(/\r?\n/)
    end
    def practical_cost
      x=@resolved;return [] unless x.is_a?(RPG::Skill)
      values=actor ? [['HP',actor.skill_hp_cost(x)],['MP',actor.skill_mp_cost(x)],['TP',actor.skill_tp_cost(x)],[t('душ','souls'),actor.skill_gold_cost(x)]] : [['MP',x.mp_cost],['TP',x.tp_cost]]
      parts=values.select { |label,value| value!=0 }.map { |label,value| n(value)+' '+label }
      unless actor
        parts<<n(x.hp_cost)+' HP' if x.hp_cost>0
        [['mhp_cost_rate','% max HP'],['hp_cost_rate','% HP'],['mmp_cost_rate','% max MP'],['mp_cost_rate','% MP'],['tp_cost_rate','% TP'],['gold_cost_rate',t('% душ','% souls')]].each do |method,label|
          next if method=='hp_cost_rate' && x.mhp_cost_rate>0
          next if method=='mp_cost_rate' && x.mmp_cost_rate>0
          value=x.send(method);parts<<n(value)+label if value>0
        end
        parts<<n(x.gold_cost)+' '+t('душ','souls') if x.gold_cost>0
      end
      parts<<name($data_items[x.item_cost])+' ×1' if $data_items[x.item_cost]
      [t(actor ? 'Цена: ' : 'Базовая цена: ',actor ? 'Cost: ' : 'Base cost: ')+(parts.empty? ? t('без затрат','free') : parts.join(', '))]
    end
    def editorial
      return nil unless @object.is_a?(RPG::Skill)
      case @object.id
      when 340
        [t('Открывает выбор обычной или быстрой скорости ходьбы. Ускоряет передвижение по карте; это не боевой приём.','Choose normal or fast map movement. This changes walking speed, not battle speed.'),t('Выбранный режим задаётся событием игры; обычный бег с удержанием Shift продолжает работать по своим правилам.','The game event sets the selected mode; the ordinary hold-to-dash mechanic remains separate.')]
      when 120
        [t('Враги на карте перестают реагировать на персонажа на 150 пройденных шагов. Это не неуязвимость и не снятие всех сюжетных проверок.','Map enemy symbols stop reacting for 150 steps. This does not grant invulnerability or bypass all scripted checks.'),t('В полевых навыках: '+BS2Suite::Keys.token(:Z)+' включает/выключает автоматическое повторение после окончания. Каждый раз оплачивается действительная цена MP.','In Field skills, '+BS2Suite::Keys.token(:Z)+' toggles automatic renewal after expiry. Every cast pays the actual MP cost.')]
      when 13,16
        heavy=@object.id==16
        [t('Приём для срыва вражеской подготовки. Успех зависит от того, допускает ли цель прерывание сейчас; это не гарантированная остановка любого босса.','Interrupt an enemy preparation. Success depends on whether the target permits Break now; this does not stop every boss automatically.'),t('При успехе: цель не может действовать, физический и магический получаемый урон ×','On success: target cannot act, physical and magical damage taken x')+(heavy ? '3' : '2')+t(', обычное уклонение резко снижено. Текущая восприимчивость — в окне противников. Посмотрите прогноз для шанса конкретного приёма.','; normal evasion is greatly reduced. Inspect enemies for current susceptibility, and use the skill forecast for the actual chance.')]
      when 838
        [t('Мощность растёт при уменьшении ваших MP. Формула использует MP ПОСЛЕ оплаты навыка, а не число до нажатия.','Power rises as your MP falls. The formula uses MP AFTER paying the skill cost, not the value before selection.'),t('Множитель = min(100 × макс. MP / оставшиеся MP, 1000) / 100. Максимум ×10; деление целых чисел даёт ступени.','Multiplier = min(100 x max MP / remaining MP, 1000) / 100. Capped at x10; integer division makes it stepwise.'),t('Если после оплаты MP = 0, деление на ноль в штатной формуле даёт 0 урона. Оставьте хотя бы 1 MP после оплаты. Числа по текущим врагам — во вкладке «По целям».','If paying leaves 0 MP, division by zero in the stock formula yields 0 damage. Keep at least 1 MP after paying. See Targets for current enemies.')]
      when 308
        [t('Ранит самого пользователя, затем пытается наложить Кровотечение и Самобичевание. Урон зависит от текущих ATK и DEF; это не фиксированная плата HP.','Damages the user, then attempts to apply Bleeding and Self-Flagellation. Self-damage uses current ATK and DEF; it is not a fixed HP cost.'),t('Самобичевание: ATK ×1,5 и шанс крита +50 процентных пунктов. Кровотечение отдельно отнимает HP. Условия и сроки — в эффектах.','Self-Flagellation: ATK x1.5 and critical chance +50 percentage points. Bleeding drains HP separately. See Effects for conditions and duration.')]
      when 110
        [t('Повышает шанс критического удара на 30 процентных пунктов. Это состояние на пользователе, а не усиление только следующего удара дубиной.','Raises critical chance by 30 percentage points. This is a state on the user, not a bonus limited to the next club strike.')]
      end
    end
    def practical_use
      x=@resolved;lines=editorial || readable_description
      lines+=practical_cost
      if x.is_a?(RPG::Skill) && actor
        sources=actor.equips.compact.select { |w| w.features.any? { |f| f.code==43 && f.data_id==@object.id } }
        lines<<t('Доступ от: ','Granted by: ')+sources.map { |w| name(w) }.join(', ') unless sources.empty?
      elsif x.is_a?(RPG::Item)
        lines<<t('В сумке: ','In inventory: ')+$game_party.item_number(x).to_s if $game_party
      end
      labels=t(['Нет цели','Один враг','Все враги','Случайный враг','Случайные враги ×2','Случайные враги ×3','Случайные враги ×4','Один союзник','Все союзники','Павший союзник','Все павшие союзники','На себя'],['No target','One enemy','All enemies','Random enemy','Random enemies x2','Random enemies x3','Random enemies x4','One ally','All allies','One fallen ally','All fallen allies','Self'])
      lines<<t('Цель: ','Target: ')+labels[x.scope].to_s unless x.scope==0
      lines<<t('Повторов на каждую цель: ','Repeats per target: ')+x.repeats.to_s if x.repeats>1
      lines<<t('Предмет не расходуется при применении.','The item is not consumed on use.') if x.is_a?(RPG::Item) && !x.consumable
      if [0,1].include?(x.occasion)
        q=quick_info(x)
        lines<<(q ? t('Мгновенное применение; лимит ','Instant use; limit ')+q[0].to_s+(actor ? t(', использовано ',', used ')+q[1].to_s : '') : t('Занимает обычное действие.','Uses a normal action.'))
      end
      if x.is_a?(RPG::Skill) && (m=/<クールタイム:(\d+)>/.match(x.note))
        lines<<t('КД: ','Cooldown: ')+(actor ? read_cooldown(x).to_s+t(' сейчас; ',' now; ') : '')+t('после применения счётчик ','counter after use ')+(m[1].to_i+1).to_s+t(', уменьшается в конце хода.','; decreases at turn end.')
      end
      prefixes=t(['Ограничения сейчас:','Действующий вариант:','Цена выбора исходного навыка:','Требуемые типы оружия (любой):'],['Current restrictions:','Current variant:','Original skill selection cost:','Required weapon types (either):'])
      lines+=overview.select { |s| prefixes.any? { |prefix| s.start_with?(prefix) } }
      lines
    end
    def practical_effects
      x=@resolved;lines=[]
      x.effects.each do |e|
        case e.code
        when 11,12
          resource=e.code==11 ? 'HP' : 'MP'
          parts=[];parts<<pct(e.value1)+t(' от максимума цели',' of target maximum') if e.value1!=0
          parts<<n(e.value2) if e.value2!=0
          lines<<t('Восстановление ','Restore ')+resource+': '+parts.join(' + ')+t('; учитывает REC цели','; affected by target REC')+(x.is_a?(RPG::Item) ? t(' и PHA пользователя.',' and user PHA.') : '.')
        when 21
          if e.data_id>0 && $data_states[e.data_id]
            state=$data_states[e.data_id]
            lines<<t('Накладывает: ','Applies: ')+name(state)+t('; исходный шанс ','; base chance ')+pct(e.value1)+'.'
            lines+=state_lines(state)
          else
            lines<<t('Накладывает состояния текущей обычной атаки.','Applies current normal-attack states.')
          end
        when 22
          lines<<t('Снимает: ','Removes: ')+name($data_states[e.data_id])+t('; шанс ','; chance ')+pct(e.value1)+'.'
        when 44
          next if [31,43].include?(e.data_id) && [120,340].include?(@object.id)
          summary=event_summary(e.data_id)
          lines<<(summary ? t(summary[0],summary[1]) : t('Запускает особое событие игры. Результат зависит от места и прогресса; полный разбор пока не выполнен.','Runs a special game event. Outcome depends on location and progress; a complete explanation is not available yet.'))
        else
          # Reuse the verified per-effect decoder, without universal footnotes.
          proxy=x.dup;proxy.effects=[e];lines+=effect_lines(proxy,false)
        end
      end
      lines
    end
    def compact_forecast
      rows=forecast_lines
      rows.reject { |line| line.start_with?(t('Расчёт на сейчас','Calculated for the current situation'),t('Диапазон учитывает','Ranges include'),t('Дополнительные/отложенные','Follow-up/delayed')) }
    end
    def practical_formula
      x=@resolved;d=x.damage
      lines=[t('За одно попадание:','Per hit:'),d.formula]
      lines<<t('a — пользователь; b — цель. Цена списывается до расчёта.','a = user; b = target. Cost is paid before calculation.')
      used=d.formula.scan(/\b([ab])\.(atk|def|mat|mdf|mhp|mmp|hp|mp|agi|luk)\b/).uniq
      if actor && used.any? { |side,key| side=='a' }
        lines<<t('Сейчас у пользователя: ','Current user: ')+used.select { |side,key| side=='a' }.map { |side,key| key.upcase+' '+actor.send(key).to_s }.join(', ')
      end
      lines<<t('Тип: ','Type: ')+t(['гарантированный','физический','магический'],['certain','physical','magical'])[x.hit_type]+t('; элемент: ','; element: ')+(d.element_id<0 ? t('элементы обычной атаки','normal-attack elements') : element(d.element_id))+'.'
      lines<<t('Разброс: ±','Variance: ±')+d.variance.to_s+'%'+(d.critical ? t('; возможен крит.','; can critical.') : '.')
      lines<<t('Защиты и текущие эффекты цели учитываются во вкладке «По целям».','Target defences and current states are included under Targets.')
      lines
    end
    def equipment_card
      x=@object;primary=readable_description
      if x.is_a?(RPG::Armor) && x.id==232
        primary=[t('В начале боя накладывает состояние: DEF и MDF ×9 (+800%), регенерация HP +100%, без регенерации MP. Счётчик длительности: 2; подробности в особенностях.','Starts battle with DEF and MDF x9 (+800%) and +100% HP regeneration, without MP regeneration. Duration counter: 2; see Special for details.')]
      elsif x.is_a?(RPG::Armor) && x.id==82
        primary=[t('Уменьшает физический тип урона и физический элемент отдельно: ×0,8 каждый. Если у удара совпадают оба признака, вместе ×0,64 (на 36% меньше). Другие сочетания проверяются отдельно.','Reduces physical hit-type damage and the Physical element separately: x0.8 each. When a hit has both, the combined multiplier is x0.64 (36% less). Other combinations must be considered separately.')]
      end
      values=x.params.each_with_index.select { |value,id| value!=0 }.map { |value,id| param(id)+' '+(value>0 ? '+' : '')+value.to_s }
      primary<<t('Прибавки вещи: ','Item bonuses: ')+values.join(' · ') unless values.empty?
      primary<<t('Это прибавки предмета; итог персонажа дополнительно зависит от множителей других вещей и состояний.','These are item bonuses; final actor stats also depend on other gear and state multipliers.') unless values.empty?
      add(t('Снаряжение','Equipment'),primary)
      features=compact_features(x.features).reject { |f| [22,33,34].include?(f.code) && f.value==0 }.map { |f| feature_line(f) }
      add(t('Свойства','Properties'),features)
      special=note_rules(x)+equipment_notes(x)
      if x.is_a?(RPG::Weapon)
        skills=x.features.select { |f| f.code==43 }.map { |f| $data_skills[f.data_id] }.compact
        special+=skills.map { |s| name(s)+': '+(ReferenceData::EN[:skill][s.id] && language==:en ? ReferenceData::EN[:skill][s.id][1] : s.description).to_s.gsub(/\r?\n/,' ') }
        family=BS2Suite::WeaponFamilies.root(x.id)
        special<<t('Быстрый слот следует настоящей цепочке заточки этой вещи.','Quick bindings follow this item actual upgrade recipe chain.') if family!=x.id || BS2Suite::WeaponFamilies.parents.values.include?(x.id)
      end
      add(t('Особенности','Special'),special)
      add(t('Снаряжение','Equipment'),[t('В этой записи нет описания или разобранных свойств. Сюжетные проверки могут находиться в событиях карты.','This entry has no description or decoded properties. Story checks may reside in map events.')]) if @sections.empty?
    end
    def compact_features(features)
      result=[];grouped={}
      features.each do |feature|
        unless [11,12,13,21,22,23,33,34].include?(feature.code)
          result<<feature;next
        end
        key=[feature.code,feature.data_id]
        if grouped[key]
          prior=grouped[key]
          prior.value=[22,33,34].include?(feature.code) ? prior.value+feature.value : prior.value*feature.value
        else
          copy=feature.dup;grouped[key]=copy;result<<copy
        end
      end
      result
    end
    def state_lines(state)
      copy=state.dup;copy.features=compact_features(state.features);super(copy)
    end
    def equipment_notes(x)
      lines=[]
      if x.is_a?(RPG::Armor)
        case x.id
        when 141
          lines<<t('Сюжетное кольцо. По описанию игры позволяет пройти ворота Университета Окс Вард; это не прибавка боевых характеристик.','Story ring. The game description says it permits passage through the Ox Ward University gates; this is not a combat stat bonus.')
        when 152
          lines<<t('Сюжетное кольцо. По описанию игры позволяет понимать язык дорогой девочки; это не боевой эффект.','Story ring. The game description says it lets you understand the dear girl language; this is not a combat effect.')
        when 232
          lines<<t('Описание неточно: начальное состояние даёт DEF и MDF ×9 (+800%), а не ×10. Есть регенерация HP +100%; регенерации MP в этом состоянии нет.','The description is inaccurate: the starting state gives DEF and MDF x9 (+800%), not x10. It has +100% HP regeneration; this state has no MP regeneration.')
        end
      end
      x.note.scan(/<戦闘前ステート付与[:：](\d+)(?:,(\d+))?>/).each do |id,chance|
        state=$data_states[id.to_i];next unless state
        lines<<t('В начале боя: попытка наложить ','At battle start: attempts to apply ')+name(state)+' ('+(chance || '100')+'%).'
        lines+=state_lines(state)
      end
      x.note.scan(/<戦闘前強化付与[:：](\d+),(\d+)(?:,(\d+))?>/).each do |id,turns,chance|
        lines<<t('В начале боя: ','At battle start: ')+param(id.to_i)+t(' +1 уровень усиления (+25% за уровень, максимум +50%); счётчик ',' +1 buff level (+25% per level, capped at +50%); counter ')+turns+'; '+(chance || '100')+'%.'
      end
      x.note.scan(/<自動蘇生[:：]([^,>]+),(\d+)(?:,([^>]+))?>/).each do |hp,animation,chance|
        lines<<t('Автовоскрешение при смертельном воздействии в бою: шанс ','Auto-revival after a lethal battle effect: chance ')+(chance || '100')+t('%; если выбран этот источник, HP устанавливаются в ','%; if this source is selected, HP is set to ')+hp+t(' (не выше максимума HP).',' (capped at max HP).')
      end
      x.note.scan(/<自動蘇生破損[:：]([^>]+)>/).each { |match| lines<<t('После срабатывания этого воскрешения: ','After this revival triggers: ')+match[0]+t('% шанс уничтожения экипированного кольца.','% chance to destroy the equipped ring.') }
      lines<<t('Нельзя сдать эту вещь в хранилище. Это не запрет сохранения игры.','Cannot deposit this item in storage. This does not prevent saving the game.') if x.note.include?('<保存禁止>')
      lines
    end
    def enemy_card
      enemy=@object;snapshot=Forecast::Snapshot.new(enemy)
      add(t('Противник','Enemy'),[title,'HP '+enemy.hp.to_s+' / '+enemy.mhp.to_s+' · MP '+enemy.mp.to_s+' / '+enemy.mmp.to_s,
        (2..7).map { |id| param(id)+' '+enemy.param(id).to_s }.join(' · '),
        t('Показано текущее состояние этой цели. После смены фазы откройте окно заново.','Current state of this enemy. Reopen after a phase change.')])
      elements=[1,2,3,4,5,9,10]
      elements+=enemy.feature_objects.map { |o| o.features.select { |f| f.code==11 }.map { |f| f.data_id } }.flatten
      lines=[t('Множитель урона: больше ×1 — слабость; меньше ×1 — сопротивление; ×0 — невосприимчивость.','Damage multiplier: above x1 = weakness; below x1 = resistance; x0 = immune.')]
      elements.uniq.sort.each { |id| lines<<element(id)+': ×'+n(snapshot.element(id)) }
      lines<<t('Физический тип ×','Physical hit type x')+n(snapshot.values['pdr'])+t('; магический тип ×','; magical hit type x')+n(snapshot.values['mdr'])
      lines<<t('Тип попадания и элемент — отдельные множители. Точный результат выбранного навыка — в его прогнозе.','Hit type and element are separate multipliers. See the selected skill forecast for the result.')
      add(t('Урон / стихии','Damage / elements'),lines)
      ids=([1,2,3,4,5,6,7,8,13,26,32,39]+$data_states.compact.select { |s| s.priority>0 && s.icon_index>0 && (s.restriction>0 || s.features.any? { |f| (f.code==21 && f.value<1) || (f.code==22 && f.data_id==7 && f.value<0) }) }.map { |s| s.id }).uniq.sort
      ids=(ids+enemy.feature_objects.map { |o| o.features.select { |f| [13,14].include?(f.code) }.map { |f| f.data_id } }.flatten).uniq.sort
      states=[t('Это восприимчивость к состоянию, а не готовый шанс любого навыка. Учитываются текущие состояния противника.','These are state susceptibility multipliers, not the final chance of every skill. Current enemy states are included.')]
      ids.each do |id|
        state=$data_states[id];next unless state
        value=snapshot.state_rate(id)
        states<<name(state)+': '+(snapshot.immune_state?(id) ? t('иммунитет','immune') : '×'+n(value))
      end
      states<<t('Итоговый шанс зависит от самого приёма, попадания, удачи и особых условий. Сюжетная реакция может обрабатываться отдельно.','Final chance depends on the action, hit, luck and special conditions. Scripted reactions can be handled separately.')
      add(t('Состояния','States'),states)
      @sections=@sections[1,2]+[@sections[0]]
      @section_names=@section_names[1,2]+[@section_names[0]]
    end
  end
end
module BS2QoL::Reference
  class << self
    def supported?(object);object.is_a?(RPG::UsableItem) || object.is_a?(RPG::EquipItem) || object.is_a?(Game_Enemy);end
    def object_for(window)
      return window.enemy if window.is_a?(Window_BattleEnemy)
      window.item if window.respond_to?(:item)
    end
    def eligible?(scene,window)
      !scene.instance_variable_get(:@bs2q_binding_window) && !($game_message && ($game_message.busy? || $game_message.visible)) && supported?(object_for(window))
    end
    def open(scene,window)
      return false unless eligible?(scene,window)
      actor=scene.is_a?(Scene_Battle) ? BattleManager.actor : scene.is_a?(Scene_ItemBase) ? scene.user : BS2QoL::Hotkeys.actor_for(window)
      popup=Window_BS2QReference.new(object_for(window),actor)
      window.deactivate;scene.instance_variable_set(:@bs2q_reference_window,popup);scene.instance_variable_set(:@bs2q_reference_origin,window)
      Sound.play_ok;true
    end
  end
end
class Window_BS2QReference
  def rebuild
    @card=BS2QoL::PracticalCard.new(@object,@actor,BS2QoL::Reference.language)
    @section=[@section,@card.sections.size-1].min;@wrapped={};@offset=0;refresh
  end
end
class BS2Suite::EnemyInfoList < Window_Command
  def window_width;Graphics.width-48;end
  def visible_line_number;[item_max,8].min;end
  def make_command_list
    $game_troop.alive_members.each { |enemy| add_command(enemy.name+' · HP '+enemy.hp.to_s,:enemy,true,enemy) }
  end
  def item;current_ext;end
end
module BS2Suite::EnemyInfo
  def self.open(scene)
    origin=scene.instance_variable_get(:@actor_command_window);origin.deactivate
    chooser=BS2Suite::EnemyInfoList.new(24,72);chooser.z=450;done=false
    scene.instance_variable_set(:@bs2092_enemy_chooser,chooser)
    chooser.set_handler(:cancel,lambda { done=true })
    chooser.set_handler(:enemy,lambda { BS2QoL::Reference.open(scene,chooser) })
    begin
      until done
        Graphics.update;Input.update
        if defined?(BS2Suite::CombatEffects) && scene.instance_variable_get(:@bs2080_effects)
          BS2Suite::CombatEffects.update_modal(scene)
        elsif BS2QoL::Reference.active?(scene)
          BS2QoL::Reference.update(scene)
        else
          chooser.update
        end
      end
    ensure
      BS2QoL::Reference.close(scene,false) if BS2QoL::Reference.active?(scene)
      BS2Suite::CombatEffects.close(scene) if defined?(BS2Suite::CombatEffects) && scene.instance_variable_get(:@bs2080_effects)
      # Closing H may restore an older F7 frame belonging to this chooser.
      BS2QoL::Reference.close(scene,false) if BS2QoL::Reference.active?(scene)
      chooser.dispose;scene.instance_variable_set(:@bs2092_enemy_chooser,nil)
      Input.update;origin.activate unless origin.disposed?
    end
  end
end
class Window_ActorCommand
  alias bs2v2_enemy_commands make_command_list
  def make_command_list
    bs2v2_enemy_commands
    add_command(BS2Suite::Keys.token(:enemy_info)+' Сопротивления',:bs2_enemy_info) if @actor
  end
end
class Scene_Battle
  alias bs2v2_enemy_command_window create_actor_command_window
  def create_actor_command_window
    bs2v2_enemy_command_window
    @actor_command_window.set_handler(:bs2_enemy_info,lambda { BS2Suite::EnemyInfo.open(self) })
  end
  alias bs2v2_reference_pause_update update
  def update
    if BS2QoL::Reference.active?(self)
      Graphics.update;Input.update;BS2QoL::Reference.update(self);return
    end
    bs2v2_reference_pause_update
    if BS2Suite::Keys.trigger?(:enemy_info) && @actor_command_window.active && !scene_changing?
      BS2Suite::EnemyInfo.open(self)
    end
  end
end
