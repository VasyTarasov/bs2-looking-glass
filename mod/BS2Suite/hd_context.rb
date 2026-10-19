# encoding: UTF-8
module BS2Suite::HDDisplay
  class << self
    def active?
      state=status
      state[1]==1 && state[4]==1 && state[14]==0 && BS2Suite::SteamBridge.stats[4]==1
    end
    def geometry
      state=status;return nil unless state.size==16 && state[1]==1 && state[4]==1
      @layout_api ||= Win32API.new(File.join(BS2Suite::ROOT,'native','bs2_steam_bridge.dll'),'BS2_HDLayout',['I','I','P'],'I')
      buffer=([0]*12).pack('l*');return nil unless @layout_api.call(state[6],state[7],buffer)==12
      buffer.unpack('l*')
    end
    def text_width
      g=geometry;return 0 unless g
      [[g[8],(480.0*g[10]/22).round].min-[12,g[10]*3/4].max*2-12,80].max
    end
    def font_size;g=geometry;g ? g[10] : 18;end
    def capacity
      g=geometry;return 12 unless g
      pad=[12,g[10]*3/4].max
      [[((g[9]-4*pad).to_f/(g[10]+8)).floor-6,6].max,80].min
    end
    def measure(text)
      @measure_api ||= Win32API.new(File.join(BS2Suite::ROOT,'native','bs2_steam_bridge.dll'),'BS2_HDMeasure',['P','I','I'],'I')
      @widths ||= {};@widths.clear if @widths.size>2048
      key=[font_size,text];return @widths[key] if @widths.has_key?(key)
      raw=text.encode('UTF-8');value=@measure_api.call(raw,raw.bytesize,font_size)
      raise 'Не удалось измерить HD-текст' if value<0
      @widths[key]=value
    end
    def wrap_lines(lines)
      width=text_width;output=[]
      lines.each do |text|
        text.to_s.split("\n",-1).each do |paragraph|
          paragraph=paragraph.gsub(/\\[A-Za-z]+\[[^\]]*\]/,'').gsub(/[\x00-\x1f]/,' ')
          line=''
          paragraph.split(/\s+/).each do |word|
            candidate=line.empty? ? word : line+' '+word
            if measure(candidate)<=width;line=candidate;next;end
            unless line.empty?;output<<line;line='';end
            if measure(word)<=width;line=word;next;end
            word.each_char do |char|
              if !line.empty? && measure(line+char)>width;output<<line;line='';end
              line+=char
            end
          end
          output<<line
        end
      end
      output
    end
    def icon_row(icon,count,name)
      @icons_sent ||= {}
      unless @icons_sent[icon]
        @icon_api ||= Win32API.new(File.join(BS2Suite::ROOT,'native','bs2_steam_bridge.dll'),'BS2_HDIcon',['I','P','I'],'I')
        bitmap=Cache.system('Iconset');pixels=[];x=(icon%16)*24;y=(icon/16)*24
        return row('S',name+' · '+count) if x+24>bitmap.width || y+24>bitmap.height
        24.times do |dy|
          24.times do |dx|
            color=bitmap.get_pixel(x+dx,y+dy);pixels+=[color.blue.to_i,color.green.to_i,color.red.to_i,color.alpha.to_i]
          end
        end
        bytes=pixels.pack('C*');@icons_sent[icon]=@icon_api.call(icon,bytes,bytes.bytesize)==1
      end
      @icons_sent[icon] ? row('I',icon.to_s+'|'+name+' · '+count) : row('S',name+' · '+count)
    end
    def reference_rows(window)
      token=[geometry && geometry.values_at(8,9,10),window.card.object_id]
      if window.instance_variable_get(:@bs2092_hd_geometry)!=token
        window.instance_variable_set(:@bs2092_hd_geometry,token)
        window.instance_variable_set(:@wrapped,{})
        window.refresh
      end
      [row('T',window.card.title),row('H',window.card.section_names[window.section])]+
        window.lines[window.offset,window.page_size].to_a.map { |text| row('S',text) }+
        [row('D',(window.offset+1).to_s+'–'+[window.offset+window.page_size,window.lines.size].min.to_s+' / '+window.lines.size.to_s),
         row('D','←/→ раздел · ↑/↓ текст · Q/E страница'),row('D','F7 / Esc назад')]
    end
    def palette_rows(window)
      rows=[]
      if window.actor.actions.size>1 && BS2Suite.enabled?('action_queue') && $game_party.in_battle
        rows<<row('T','Серия')
        window.actor.actions.take(6).each_with_index do |a,i|
          next unless a.item
          rows<<row('D',(i+1).to_s+'. '+a.item.name+(defined?(BS2Suite::QueueEdit) ? BS2Suite::QueueEdit.mp(window.actor,i) : ''))
        end
      end
      if defined?(BS2Suite::DirectWeapons) && (weapon=BS2Suite::DirectWeapons.selected(window.actor))
        rows<<row('D','Назначено N: '+weapon.name)
      end
      rows<<row('T',window.banner)
      if window.transition.any?
        return rows+commands(window,10)+[row('D','Enter продолжить · Esc выйти')]
      end
      # Exactly ten entries; the selected item's note is separate and never truncates its name.
      limit=[[(capacity-8)/1.5,5].max.to_i,10].min
      first=[[window.index-limit/2,0].max,[window.entries.size-limit,0].max].min
      window.entries[first,limit].to_a.each_with_index do |entry,index|
        label=entry[:name] || (entry[:object] && entry[:object].name) || '—'
        object=entry[:object]
        if object.is_a?(RPG::Skill)
          label+=' · '+BS2Suite::Performance.mp_cost(window.actor,object,entry[:source]).to_s+' MP'
          cooldown=BS2Suite::Availability.cooldown(window.actor,object)
          label+=' · КД '+cooldown.to_s if cooldown>0
        elsif object.is_a?(RPG::Item)
          label+=' ×'+$game_party.item_number(object).to_s
        end
        label+=' · недоступно' if entry[:present]==false || entry[:usable]==false
        rows<<row(window.index==first+index ? 'K' : 'P',entry[:digit].to_s+'  '+label)
      end
      selected=window.entry
      note=selected && BS2Suite::ShortNotes.for_row(selected,window.prefix)
      unless note.to_s.empty?
        rows<<row('H',selected[:object] ? selected[:object].name : 'Назначение');rows+=wrap_lines([note]).take(3).map { |t| row('S',t) }
      end
      rows<<row('D','↑/↓ список · цифры 1–9/0 выбирают') if limit<window.entries.size
      rows<<row('D',window.group ? 'Q/E или ←/→ соседняя группа' : 'Цифра — открыть группу')
      rows<<row('D',window.prefix=='N' ? 'N N снять привязку · Esc выйти' : window.prefix+' назад · Esc выйти')
      rows<<row('D','F7 — подробности') if selected && selected[:object]
      rows
    end
    def actor_for(scene)
      scene.instance_variable_get(:@actor) || ($game_party && ($game_party.in_battle ? BattleManager.actor || scene.instance_variable_get(:@bs2q_queue_actor) : $game_party.menu_actor || $game_party.leader))
    end
    def battle_rows(scene)
      actor=actor_for(scene);rows=[]
      if actor && actor.actions.size>1 && BS2Suite.enabled?('action_queue')
        rows<<row('T','Серия · '+actor.actions.size.to_s+' действия')
        actor.actions.take(6).each_with_index do |action,i|
          rows<<row(actor.input.equal?(action) ? 'A' : 'S',(i+1).to_s+'. '+(action.item ? action.item.name : 'выбор действия')+(defined?(BS2Suite::QueueEdit) ? BS2Suite::QueueEdit.mp(actor,i) : ''))
        end
        rows<<row('D','Ещё '+(actor.actions.size-6).to_s+' действий') if actor.actions.size>6
        rows<<row('D','Esc, Esc — сбросить неисполненную серию')
      end
      if actor && defined?(BS2Suite::DirectWeapons)
        current=actor.equips[0];selected=BS2Suite::DirectWeapons.selected(actor)
        rows<<row('H','Оружие сейчас');rows<<row('S',current ? current.name : 'Без оружия')
        if selected
          rows<<row('H','Назначено N');rows<<row('S',selected.name)
          note=BS2Suite::ShortNotes.respond_to?(:describe_final) ? BS2Suite::ShortNotes.describe_final(selected) : BS2Suite::ShortNotes.describe(selected)
          rows+=wrap_lines([note]).take(2).map { |t| row('D',t) } if BS2Suite::Options.get('weapon_notes')==1
          rows<<row('D','N N — снять привязку')
        end
      end
      target=scene.instance_variable_get(:@enemy_window)
      ally=scene.instance_variable_get(:@actor_window)
      if (target && target.active) || (ally && ally.active)
        window=target && target.active ? target : ally
        indices=window.equal?(target) ? (0...$game_troop.alive_members.size).to_a : BS2Suite::TargetDigits.actor_indices
        units=window.equal?(target) ? $game_troop.alive_members : indices.map { |i| $game_party.battle_members[i] }
        rows<<row('H',window.equal?(target) ? 'Выберите противника' : 'Выберите союзника')
        units.take(10).each_with_index { |unit,i| rows<<row(window.index==indices[i] ? 'A' : 'S',(i==9 ? '0' : (i+1).to_s)+'  '+unit.name) }
        rows<<row('D','Цифра — выбрать · Esc назад')
      else
        rows<<row('H','Быстрый выбор')
        rows<<row('S',BS2Suite::Keys.token(:palette_v)+' техники · '+BS2Suite::Keys.token(:palette_b)+' предметы') if BS2Suite.enabled?('semantic_groups')
        rows<<row('S',BS2Suite::Keys.token(:palette_m)+' магия · '+BS2Suite::Keys.token(:palette_n)+' оружие') if BS2Suite.enabled?('semantic_groups')
        rows<<row('D',BS2Suite::Keys.token(:combat_effects)+' эффекты · '+BS2Suite::Keys.token(:enemy_info)+' противники')
        rows<<row('D',BS2Suite::Keys.token(:stats)+' журнал · F7 справка') if BS2Suite.enabled?('battle_stats')
      end
      notice=BS2QoL::Hotkeys.current_notice
      rows<<row('H',notice) if notice
      rows
    end
    def selected_window(scene)
      # Explicit contexts, no mirroring of arbitrary active command windows.
      keys=[:@buy_window,:@sell_window,:@number_window,:@list_window,:@item_window,:@skill_window]
      keys.map { |key| scene.instance_variable_get(key) }.find do |window|
        window.is_a?(Window_Selectable) && !window.disposed? && window.active && window.open?
      end
    end
    def equip_projection(actor,item,scene)
      return nil unless actor && item.is_a?(RPG::EquipItem) && actor.equippable?(item)
      slots=actor.equip_slots;slot=scene.instance_variable_get(:@slot_window)
      index=slot && slots[slot.index]==item.etype_id ? slot.index : slots.index(item.etype_id)
      return nil unless index
      view=actor.dup;equips=actor.instance_variable_get(:@equips).map { |entry| entry.dup };equips[index].object=item
      view.instance_variable_set(:@equips,equips)
      view.instance_variable_set(:@bs2092_slot_index,index)
      resisted=view.state_resist_set
      view.instance_variable_set(:@states,actor.instance_variable_get(:@states).reject { |id| resisted.include?(id) })
      view
    end
    def comparison(actor,view)
      return [] unless actor && view && defined?(BS2Suite::EquipmentDetails)
      BS2Suite::EquipmentDetails.lines(actor,view).select { |line| line.include?(' → ') }.take(12)
    end
    def menu_rows(scene)
      actor=actor_for(scene)
      if defined?(BS2Modules::LoadoutsScene) && scene.is_a?(BS2Modules::LoadoutsScene)
        set=scene.set
        return [row('T','Комплекты'),row('D','Выберите сохранённый комплект')] unless set
        view=BS2Suite::EquipmentDetails.view(actor,set) if defined?(BS2Suite::EquipmentDetails)
        return [row('T',set[:name]),row('H','Сейчас → комплект')]+comparison(actor,view).map { |t| row('S',t) }+[row('D','Текущие состояния учтены · F7 все свойства')]
      end
      window=selected_window(scene)
      object=window && defined?(BS2QoL::Reference) && BS2QoL::Reference.object_for(window)
      if object && object.respond_to?(:description)
        rows=[row('T',object.name)]
        rows+=wrap_lines([BS2Suite::ShortNotes.describe(object)]).take(5).map { |t| row('S',t) }
        if object.is_a?(RPG::EquipItem)
          view=equip_projection(actor,object,scene)
          if view
            index=view.instance_variable_get(:@bs2092_slot_index);type=actor.equip_slots[index]
            label=Vocab.etype(type).to_s
            label+=' '+actor.equip_slots[0..index].count(type).to_s if actor.equip_slots.count(type)>1
            rows<<row('H','Сейчас → выбранное');rows<<row('D','Слот: '+label)
          end
          rows+=comparison(actor,view).map { |t| row('S',t) }
        end
        rows<<row('D','F7 — полные свойства и расчёт') if BS2Suite.enabled?('reference_cards')
        return rows
      end
      return [] unless scene.is_a?(Scene_Menu) || scene.is_a?(Scene_Equip)
      return [] unless actor
      if scene.is_a?(Scene_Equip)
        rows=[row('T','Особые свойства комплекта')]
        [['Расход MP',:mcr],['Физ. урон',:pdr],['Маг. урон',:mdr],['Шанс крита',:cri],['Контратака',:cnt],['Реген HP',:hrg],['Реген MP',:mrg]].each do |label,key|
          rows<<row('S',label+': '+BS2Modules.pct(actor.send(key)))
        end
        immune=actor.state_resist_set.map { |id| $data_states[id] && $data_states[id].name }.compact
        rows<<row('H','Иммунитеты') unless immune.empty?
        rows+=wrap_lines([immune.join(', ')]).take(4).map { |text| row('S',text) } unless immune.empty?
        rows<<row('D','Текущие состояния учтены · F7 все свойства')
        return rows
      end
      rows=[row('T',actor.name),row('H','Текущая экипировка')]
      actor.equips.compact.each { |item| rows<<row('S',item.name) }
      if defined?(BS2Suite::Semantic);rows<<row('H','Боевой профиль');rows<<row('S',BS2Suite::Semantic.title(actor));end
      rows<<row('D','Комплекты: именованные наборы снаряжения') if BS2Suite.enabled?('loadouts')
      rows<<row('D','F7 — итоговые свойства') if scene.is_a?(Scene_Equip) && BS2Suite.enabled?('reference_cards')
      rows
    end
    alias bs2092_menu_uncached menu_rows
    def menu_rows(scene)
      actor=actor_for(scene);window=selected_window(scene)
      item=window && defined?(BS2QoL::Reference) && BS2QoL::Reference.object_for(window)
      set=scene.set if defined?(BS2Modules::LoadoutsScene) && scene.is_a?(BS2Modules::LoadoutsScene)
      key=[scene.object_id,window && window.object_id,window && window.index,item && item.object_id,set && set.hash]
      key+=[actor.id,actor.hp,actor.mp,(0..7).map { |i| actor.param(i) },actor.equips.map { |e| e && e.id },actor.states.map { |s| s.id },(actor.instance_variable_get(:@buffs) || []).dup] if actor
      return @menu_rows if @menu_key==key
      @menu_key=key;@menu_rows=bs2092_menu_uncached(scene)
    end
    def lines(scene)
      if @trial
        return [row('T','Проверка режима'),row('H','Оставить этот режим?'),row('S','Enter — сохранить'),row('S','Esc — вернуть прежний'),row('H','Автовозврат через '+remaining.to_s+' с')]
      end
      return [] unless scene
      reference=scene.instance_variable_get(:@bs2q_reference_window)
      return reference_rows(reference) if reference && !reference.disposed?
      palette=scene.instance_variable_get(:@bs2s_palette)
      return palette_rows(palette) if palette && !palette.disposed?
      effects=scene.instance_variable_get(:@bs2080_effects)
      if effects && !effects.disposed?
        first=[effects.index-2,0].max;rows=[row('T','Участники и эффекты')]
        effects.rows[first,5].to_a.each_with_index do |entry,i|
          label,icons,unit=entry;rows<<row(effects.index==first+i ? 'A' : 'H',label.to_s.empty? ? unit.name : label)
          if icons.compact.empty?;rows<<row('S','—')
          else
            icons.compact.each { |icon,count,name| icon_row(icon,count,name) }
            icons.compact.each_slice(8) { |slice| rows<<row('G',slice.map { |icon,count,name| icon.to_s+'|'+count }.join(';')) }
          end
        end
        return rows+[row('D','↑/↓ участники · Enter / F7 сведения'),row('D','H / Esc назад · д действия · т такты')]
      end
      chooser=scene.instance_variable_get(:@bs2092_enemy_chooser)
      if chooser && !chooser.disposed?
        return [row('T','Противники')]+commands(chooser,10)+[row('D','Enter / F7 сведения · H эффекты · Esc назад')]
      end
      journal=scene.instance_variable_get(:@bs2092_journal)
      if journal && !journal.disposed?
        rows=[row('T','Журнал боя'),row('D','Физ./маг. — тип попадания; стихия отдельно')]
        first=[journal.index-2,0].max
        journal.rows[first,5].to_a.each_with_index do |entry,i|
          title,detail=BS2Suite::CombatJournal.summary(entry)
          rows<<row(journal.index==first+i ? 'A' : 'H',title)
          rows+=wrap_lines([detail]).take(3).map { |t| row('S',t) }
        end
        rows<<row('S','Пока нет совершённых атак') if journal.rows.empty?
        return rows+[row('D','↑/↓ записи · Enter / F7 атака'),row('D','Q/E страница · F5 / Esc назад')]
      end
      if scene.is_a?(Scene_Map)
        # Dialogue keeps the entire reserve quiet. Mod notices have a wall-clock lifetime.
        notice=BS2QoL::Hotkeys.current_notice
        return [] if !notice || ($game_message && $game_message.busy?)
        return [row('H','Уведомление')]+wrap_lines([notice]).map { |t| row('S',t) }
      end
      return battle_rows(scene) if scene.is_a?(Scene_Battle)
      scene.is_a?(Scene_MenuBase) ? menu_rows(scene) : []
    end
    def source_mode(scene)
      wanted=[]
      if active? && @panel_accepted && scene
        keys=[:@bs2q_reference_window,:@bs2s_palette,:@bs2s_palette_header,:@bs2080_effects,:@bs2092_journal,:@bs2092_journal_header,:@bs2092_enemy_chooser,:@bs2q_footer,:@bs2q_plan,:@bs2v2_notice]
        keys.each do |key|
          window=scene.instance_variable_get(key);next unless window && !window.disposed?
          wanted<<window
          plate=window.instance_variable_get(:@plate);wanted<<plate if plate && !plate.disposed?
        end
      end
      if !active? && scene && (reference=scene.instance_variable_get(:@bs2q_reference_window)) && reference.instance_variable_get(:@bs2092_hd_geometry)
        reference.instance_variable_set(:@bs2092_hd_geometry,nil);reference.instance_variable_set(:@wrapped,{});reference.refresh
      end
      previous=@hidden || [];keep=[]
      previous.each do |window,visible|
        if wanted.include?(window);keep<<[window,visible]
        else;window.visible=visible unless window.disposed?;end
      end
      wanted.each do |window|
        keep<<[window,window.visible] unless keep.any? { |entry| entry[0].equal?(window) }
        window.visible=false
      end
      @hidden=keep
      # Native geometry is now stable in all reading contexts.
      @presentation.call(0) if @presentation
    end
    def poll(force=false)
      return unless @text
      scene=SceneManager.scene
      now=@tick.call
      modal=scene && [:@bs2q_reference_window,:@bs2s_palette,:@bs2080_effects,:@bs2092_journal].any? { |key| scene.instance_variable_get(key) }
      force=force || modal || (scene && scene.is_a?(Scene_MenuBase)) || @trial
      if !force && @last_tick && ((now-@last_tick)&0xffffffff)<100
        source_mode(scene);return
      end
      @last_tick=now;rollback if @trial && remaining<=0
      if active?
        value=lines(scene).take(100).join("\n").encode('UTF-8')
        if value!=@last_text
          @panel_accepted=@text.call(value,value.bytesize)==1
          if @panel_accepted;@last_text=value;@error=nil
          else;@error='HD-панель не приняла текст';end
        end
      else;@panel_accepted=false;end
      source_mode(scene)
    rescue StandardError=>e
      @panel_accepted=false;restore_source
      @presentation.call(0) if @presentation
      @error='HD-панель: '+e.message
    end
  end
end
if BS2Suite.enabled?('reference_cards')
  class Window_BS2QReference
    alias bs2092_classic_wrap wrap
    def wrap(text)
      BS2Suite::HDDisplay.active? ? BS2Suite::HDDisplay.wrap_lines([text]) : bs2092_classic_wrap(text)
    end
    alias bs2092_classic_page_size page_size
    def page_size
      BS2Suite::HDDisplay.active? ? BS2Suite::HDDisplay.capacity : bs2092_classic_page_size
    end
  end
end
