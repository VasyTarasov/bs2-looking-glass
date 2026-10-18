# encoding: UTF-8
# Static evidence and live forecasts deliberately remain separate. No AI/drop/map
# tables are shipped in this UI database. Loading does not execute game formulas.
module BS2Suite
  module Reference098
    class << self
      def utf8(value)
        value.force_encoding('UTF-8') if value.is_a?(String)
        value.each { |v| utf8(v) } if value.is_a?(Array)
      end
      def load
        return if @rows
        data=File.open(File.join(BS2Suite::ROOT,'reference098.rvdata2'),'rb') { |f| Marshal.load(f) }
        raise 'Unsupported reference view' unless data[0]==1
        utf8(data);@rows={}
        data[1].each { |r| @rows[r[0]]=r }
      end
      def kind(object)
        {RPG::Skill=>:skill,RPG::Item=>:item,RPG::Weapon=>:weapon,RPG::Armor=>:armor,RPG::State=>:state}[object.class]
      end
      def get(object)
        k=kind(object);k && @rows[k.to_s+':'+object.id.to_s]
      end
      def by_id(kind,id);@rows[kind.to_s+':'+id.to_s];end
      def lines(object,title)
        row=get(object);return [] unless row
        row[4].select { |s| s[0]==title }.map { |s| s[1] }.flatten
      end
      def facts(object);row=get(object);row ? row[3] : [];end
      def brief(object);row=get(object);row && row[2];end
      def size;@rows.size;end
    end
    load
  end
end
module BS2Suite::ShortNotes
  class << self
    alias bs2098_old_describe describe
    def describe(object)
      BS2Suite::Reference098.brief(object) || bs2098_old_describe(object)
    end
    # Final nomination changes the platform, not the item's intrinsic properties.
    def describe_final(object);describe(object);end
  end
end
class Window_Help
  alias bs2098_verified_help set_item
  def set_item(item)
    bs2098_verified_help(item)
    brief=item && BS2Suite::Reference098.brief(item)
    return unless brief && !brief.empty?
    raw=item.description.to_s;text=@text.to_s
    # Preserve existing F7, book status and contextual control hints.
    text=raw.empty? ? text+brief : text.gsub(raw,brief)
    lines=[]
    text.split("\n").each do |line|
      current=''
      line.split(/\s+/).each do |word|
        next_text=current.empty? ? word : current+' '+word
        if text_size(next_text).width>contents.width && !current.empty?
          lines<<current;current=word
        else;current=next_text;end
      end
      lines<<current
    end
    limit=[contents.height/line_height,1].max
    if lines.size>limit
      lines=lines.take(limit);last=lines[-1]
      last=last[0,last.size-1] while !last.empty? && text_size(last+'…').width>contents.width
      lines[-1]=last+'…'
    end
    set_text(lines.join("\n"))
  end
end
class Window_BS2QCollection
  alias bs2098_verified_collection_help update_help
  def update_help
    if @help_window && item && BS2Suite::Reference098.get(item)
      @help_window.set_item(item)
    else;bs2098_verified_collection_help;end
  end
end
if defined?(BS2Suite::FieldHelp)
class BS2Suite::FieldHelp
  alias bs2098_verified_field_help set_item
  def set_item(item)
    bs2098_verified_field_help(item)
    if item && !item.description.to_s.empty? && BS2Suite::Reference098.brief(item)
      set_text(@text.to_s.gsub(item.description,BS2Suite::Reference098.brief(item)))
    end
  end
end
end
if defined?(BS2Modules::Effects) && BS2Suite.enabled?('reference_cards')
module BS2Modules::Effects
  class << self
    alias bs2098_verified_sources sources
    def sources(actor)
      rows=bs2098_verified_sources(actor)
      rows.each do |row|
        object=actor.equips.compact.find { |o| BS2Modules.label(o)==row[:name] }
        next unless object && BS2Suite::Reference098.get(object)
        card=BS2QoL::PracticalCard.new(object,actor,:ru)
        row[:details]=card.section_names.zip(card.sections).reject { |label,lines| label=='Оружие N' }.map { |label,lines| lines }.flatten
      end
      rows
    end
    alias bs2098_verified_active active
    def active(actor)
      rows=bs2098_verified_active(actor)
      rows.each do |row|
        next unless row[:kind]==:state
        state=$data_states[row[:id]];next unless state && BS2Suite::Reference098.get(state)
        db=BS2Suite::Reference098
        row[:details]=duration(actor,state)+db.facts(state).select { |a,b| a=='Действия' }.map { |a,b| b }+db.lines(state,'Свойства')+db.lines(state,'Особенности')
      end
      rows
    end
  end
end
end
if BS2Suite.enabled?('reference_cards')
class BS2QoL::PracticalCard
  alias bs2098_reference_title title
  def title
    value=bs2098_reference_title
    row=BS2Suite::Reference098.get(@object)
    value.to_s.empty? && row ? row[1] : value
  end
  alias bs2098_card_initialize initialize
  def initialize(object,actor=nil,language=:ru)
    bs2098_card_initialize(object,actor,language)
    # A journal entry has an observed action ID, not a frozen combatant snapshot.
    if !actor && object.is_a?(RPG::UsableItem)
      i=@section_names.index(t('По целям','Targets'))
      if i;@section_names.delete_at(i);@sections.delete_at(i);end
    end
  end
  def reference098;BS2Suite::Reference098;end
  def ref_lines(object,title);reference098.lines(object,title);end
  def ref_facts(object);reference098.facts(object);end
  alias bs2098_old_use practical_use
  def practical_use
    return bs2098_old_use unless reference098.get(@resolved)
    x=@resolved
    lead=ref_lines(x,'Кратко')
    lead=[reference098.brief(x)] if lead.empty? && x.damage.none?
    rows=lead+practical_cost
    info=ref_facts(x)
    kind=info.find { |a,b| a=='Урон / элемент' };hit=info.find { |a,b| a=='Тип попадания' }
    if kind
      damage,element=kind[1].split(' · ',2)
      rows<<damage+(element ? ' · стихия: '+element : '')
    end
    rows<<'Тип попадания: '+hit[1] if hit
    info.each do |label,value|
      next unless ['Цель','Применение','Расходуется'].include?(label)
      next if x.occasion==3 && ['Цель','Расходуется'].include?(label)
      rows<<label+': '+value
    end
    rows<<'Повторов на каждую цель: '+x.repeats.to_s if x.repeats>1
    rows<<'Базовый успех: '+x.success_rate.to_s+'%; это не итоговый шанс по цели.' if x.success_rate!=100
    if x.is_a?(RPG::Item)
      rows<<'В сумке: '+$game_party.item_number(x).to_s if $game_party
    elsif actor
      sources=actor.equips.compact.select { |w| w.features.any? { |f| f.code==43 && f.data_id==@object.id } }
      rows<<'Доступ от: '+sources.map { |w| name(w) }.join(', ') unless sources.empty?
    end
    if [0,1].include?(x.occasion)
      q=quick_info(x)
      if q
        # The database distinguishes party-wide and per-user limits.
        line=ref_lines(x,'Особенности').find { |s| s.start_with?('Мгновенно,') }
        rows<<(line || 'Мгновенно, без слота действия; лимит '+q[0].to_s)+(actor ? '; использовано '+q[1].to_s : '')
      else;rows<<'Занимает обычное действие.';end
    end
    prefixes=['Ограничения сейчас:','Действующий вариант:','Цена выбора исходного навыка:','Требуемые типы оружия (любой):',
      'Current restrictions:','Current variant:','Original skill selection cost:','Required weapon types (either):']
    rows+=overview.select { |s| prefixes.any? { |p| s.start_with?(p) } }
    if @bs2095_execution_weapon
      rows<<(@bs2096_sole_source ? 'Источник единственной техники: ' : 'Исполнение последнего действия: ')+@bs2095_execution_weapon.name
    end
    if defined?(BS2Suite::BattleSupport) && BS2Suite::BattleSupport.gunbreak?(@object)
      rows<<BS2Suite::Keys.token(:Z)+' — авто Gun Break при выделении в «Техники» или V.'
    end
    rows
  end
  alias bs2098_old_effects practical_effects
  def practical_effects
    return bs2098_old_effects unless reference098.get(@resolved)
    x=@resolved;rows=ref_lines(x,'Эффекты').reject { |s| s.start_with?('Вызывает событие:') }
    properties=ref_lines(x,'Свойства')
    rows+=['Свойства записи:']+properties unless properties.empty?
    # Expand states from their own verified cards; not their often inaccurate names.
    x.effects.select { |e| e.code==21 && e.data_id>0 }.each do |effect|
      state=$data_states[effect.data_id];next unless state
      rows<<name(state)+':';rows+=state_lines(state)
    end
    x.effects.select { |e| e.code==44 }.each do |effect|
      next if rows.any? { |s| s.start_with?('Получение душ:') }
      summary=event_summary(effect.data_id)
      rows<<(summary ? t(summary[0],summary[1]) : 'Особое событие игры: исход зависит от его условий; численно не моделируется.')
    end
    rows
  end
  alias bs2098_old_state_lines state_lines
  def state_lines(state)
    return bs2098_old_state_lines(state) unless reference098.get(state)
    rows=ref_facts(state).reject { |a,b| a=='После боя' }.map { |a,b| '  '+a+': '+b }
    rows+=ref_lines(state,'Свойства').map { |s| '  '+s }
    rows+=ref_lines(state,'Особенности').map { |s| '  '+s }
    if state.auto_removal_timing>0
      rows<<'  Длительность — внутренний счётчик: ATB может уменьшить его до действия; это не обещание N полных ходов.'
    end
    rows
  end
  alias bs2098_old_formula practical_formula
  def practical_formula
    return bs2098_old_formula unless reference098.get(@resolved)
    x=@resolved;rows=['За одно попадание:',x.damage.formula.to_s.strip]+ref_lines(x,'Расчёт')
    used=x.damage.formula.scan(/\ba\.(atk|def|mat|mdf|mhp|mmp|hp|mp|agi|luk)\b/).flatten.uniq
    if x.damage.critical && defined?(Hi_ru_Difficulty)
      factor=Hi_ru_Difficulty::DIFFICULTY_SETTING[11][$game_variables[Hi_ru_Difficulty::VARIABLES]]
      rows.map! { |s| s.sub('возможен крит; множитель определяется настройкой сложности','крит ×'+n(factor)+' сейчас') }
    end
    rows<<'Сейчас у пользователя: '+used.map { |key| key.upcase+' '+actor.send(key).to_s }.join(', ') if actor && !used.empty?
    rows<<'Повторы на цель: '+x.repeats.to_s if x.repeats>1
    rows
  end
  alias bs2098_old_rules note_rules
  def note_rules(x)
    return bs2098_old_rules(x) unless reference098.get(x)
    rows=ref_lines(x,'Особенности').reject { |s| s.start_with?('Мгновенно,') }
    # The source decoder records the initial delay, while execution checks zero
    # before decrementing. State the actual check number, not N promised actions.
    if x.is_a?(RPG::UsableItem)
      rows.reject! { |s| s.start_with?('Отложенный эффект:') }
      x.note.scan(/<(行動後遅延発動|遅延発動)[:：]([^>]+)>/).each do |tag,value|
        parts=value.split(',').map { |v| v.to_i };linked=x.is_a?(RPG::Skill) ? $data_skills[parts[1]] : $data_items[parts[1]]
        rows<<'Отложенно: '+name(linked)+'; проверка №'+(parts[2]+1).to_s+'–'+(parts[2]+(parts[3] || 0)+1).to_s+
          (tag=='行動後遅延発動' ? ' после действий цели' : ' в конце хода')+'; шанс '+(parts[4] || 100).to_s+'%. При смерти/исчезновении цели не срабатывает.'
      end
      if actor && x.is_a?(RPG::Skill) && /<クールタイム:(\d+)>/.match(x.note)
        rows<<'КД сейчас: '+read_cooldown(x).to_s+'.'
      end
      # Do not pretend that a dormant action tag ignores PDR/MDR.
      row=reference098.get(x)
      if row[5].any? { |s| s.start_with?('Тег проникновения PDR/MDR') }
        rows<<'Сам приём не игнорирует сопротивление физическому/магическому типу. Проникновение может дать отдельный пассивный источник.'
      end
      x.note.scan(/<使用者効果\s*(\d+)\s*>/).each do |sid|
        linked=$data_skills[sid[0].to_i];next unless linked
        rows+=ref_lines(linked,'Эффекты').map { |s| '  На пользователя: '+s }
        linked.effects.select { |e| e.code==21 && e.data_id>0 }.each do |e|
          rows+=state_lines($data_states[e.data_id]) if $data_states[e.data_id]
        end
        rows<<'  Формула на пользователя: '+linked.damage.formula.to_s.strip unless linked.damage.none?
      end
      links=x.note.scan(/<使用後追加行動[:：](\d+),[^>]+>/).flatten.map { |sid| $data_skills[sid.to_i] }
      x.note.scan(/<(?:行動後遅延発動|遅延発動)[:：]([^>]+)>/).each do |value|
        sid=value[0].split(',')[1].to_i;links<<(x.is_a?(RPG::Skill) ? $data_skills[sid] : $data_items[sid])
      end
      links.compact.uniq.each do |linked|
        rows<<'  '+name(linked)+': '+reference098.brief(linked).to_s
        rows<<'  За попадание: '+linked.damage.formula.to_s.strip unless linked.damage.none?
      end
      rows<<'Дополнительные действия имеют собственные условия, цену и цель. Прогноз всей цепочки может быть частичным.' unless links.compact.empty?
      if x.note.include?('<ステート変化:')
        rows<<'Если подходят несколько вариантов, выбирается последний подходящий в порядке тегов.'
      end
    end
    rows
  end
  alias bs2098_old_equipment equipment_card
  def equipment_card
    x=@object;return bs2098_old_equipment unless reference098.get(x)
    rows=ref_lines(x,'Кратко')
    rows=[reference098.brief(x)] if rows.empty?
    rows+=ref_facts(x).select { |a,b| a=='Прибавки' }.map { |a,b| a+': '+b }
    add(t('Снаряжение','Equipment'),rows)
    add(t('Свойства','Properties'),ref_lines(x,'Свойства'))
    special=note_rules(x)
    if x.features.any? { |f| f.code==61 }
      special<<'Дополнительные слоты определяются при создании очереди. Смена оружия не добавляет их в уже сформированный ход.'
    end
    if x.features.any? { |f| f.code==34 && f.value>0 }
      special<<'Доп. повторы обычной атаки требуют совпадения выбранного ID с обычной атакой текущего оружия. Чужой приём не превращается в серию.'
    end
    x.note.scan(/<戦闘前ステート付与[:：](\d+)(?:,(\d+))?>/).each do |id,chance|
      state=$data_states[id.to_i];next unless state
      special<<'Начальное состояние '+name(state)+':';special+=state_lines(state)
    end
    # Special normal attacks have their own formulas/repeats. The complete action
    # definition belongs here even when it is never learnable as a player skill.
    ids=x.features.select { |f| f.code==43 }.map { |f| f.data_id }
    x.note.scan(/<攻撃ID変更[:：](\d+)>/).each { |m| ids<<m[0].to_i }
    actions=[]
    ids.uniq.each do |id|
      skill=$data_skills[id];next unless skill
      actions<<name(skill)+': '+reference098.brief(skill).to_s
      actions<<'  За попадание: '+skill.damage.formula.to_s.strip unless skill.damage.none?
      actions+=note_rules(skill).map { |s| '  '+s }
    end
    add(t('Особенности','Special'),special)
    add(t('Приёмы / атака','Skills / attack'),actions)
    if x.is_a?(RPG::Weapon) && BS2Suite.enabled?('semantic_groups')
      add(t('Оружие N','Weapon shelves'),['Цифра в N — надеть сейчас. D на строке N — последнее действие; N N снимает назначение.',
        'D в выборе оружия экипировки или в «Предметы → Оружие» — отдельное стартовое оружие.',
        'Выбранный ID атаки сохраняется при смене оружия; характеристики, цена и дополнительные выстрелы зависят от текущей платформы.'])
    end
  end
end
end
if defined?(BS2Suite::CombatJournal)
module BS2Suite::CombatJournal
  class << self
    alias bs2098_journal_summary summary
    def summary(row)
      if row[:name].to_s.empty?
        record=BS2Suite::Reference098.get(object(row))
        row=row.merge(:name=>record[1]) if record
      end
      bs2098_journal_summary(row)
    end
  end
end
end
