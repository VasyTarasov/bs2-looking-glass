# encoding: UTF-8
# Runs on the actual English RGSS database, with synthetic actors and saves only.
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;end
  def english(value,label)
    text=value.is_a?(Array) ? value.flatten.join(' ') : value.to_s
    check(text !~ /[А-Яа-яЁё]/,label+' contains Cyrillic: '+text)
    # Preserve the one native Japanese database separator name exactly; it is
    # original game data, not authored mod interface text.
    text=text.gsub($data_items[193].name,'') if $data_items && $data_items[193]
    check(text !~ /[\u3040-\u30ff\u3400-\u9fff]/,label+' contains untranslated technical text: '+text)
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'English localization native QA '+BS2Suite::VERSION }
    check(BS2Suite::Locale.current==:en,'English installation locale')
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(200,false);actor.recover_all
    $game_party.menu_actor=actor
    check($data_items[32].name=='Charcoal Pine Resin','native English archive database loaded')
    check(BS2QoL::Reference.language==:en,'English default reference language')
    helper=BS2Suite::CatalogUI;catalog=BS2Suite::CatalogV1
    tables={:skill=>$data_skills,:item=>$data_items,:weapon=>$data_weapons,:armor=>$data_armors,:state=>$data_states}
    original=Marshal.dump(tables.values.map { |xs| xs.compact.map { |o| [o.name,o.description,o.note] } })
    tables.each do |kind,objects|
      objects.compact.each do |object|
        next if object.id==0
        entry=catalog.entry(object)
        check(entry && entry['names']['en']==object.name,'canonical name '+kind.to_s+object.id.to_s)
        raw=entry['raw_mechanics']
        check(raw['params']==object.params,'exact native English flat stats '+object.id.to_s) if object.is_a?(RPG::EquipItem)
        if object.respond_to?(:features)
          check(raw['features'].map { |f| [f['code'],f['data_id'],f['value']] }==object.features.map { |f| [f.code,f.data_id,f.value] },'exact native traits')
          english(object.features.map { |f| BS2Modules::Effects.feature(f) },'H feature decoder '+object.id.to_s)
        end
        if object.is_a?(RPG::UsableItem)
          check(raw['damage']['formula']==object.damage.formula,'exact native formula')
          check(raw['effects'].map { |e| [e['code'],e['data_id'],e['value1'],e['value2']] }==object.effects.map { |e| [e.code,e.data_id,e.value1,e.value2] },'exact native effects and order')
        end
        english(catalog.sections(object,:en).map { |s| [s['title'],s['lines']] },'English factual sections')
        alias_row=BS2QoL::ReferenceData::EN[kind] && BS2QoL::ReferenceData::EN[kind][object.id]
        check(!alias_row || alias_row[0]==object.name,'reference alias matches native name')
        english(helper.description(object,actor,false,:en),'HUD '+kind.to_s+object.id.to_s)
        card=BS2QoL::PracticalCard.new(object,actor)
        english([card.title,card.section_names,card.sections],'default F7 '+kind.to_s+object.id.to_s)
        check(card.language==:en,'default F7 language')
      end
    end
    check(original==Marshal.dump(tables.values.map { |xs| xs.compact.map { |o| [o.name,o.description,o.note] } }),'rendering preserves native database text and tags')
    [$data_items[21],$data_items[49]].each do |object|
      check(helper.description(object)==['Crafting and upgrade material.'],'materials retain focused English help')
    end
    weapon_rows=helper.description($data_weapons[272])
    check(!weapon_rows.join.include?('Flat item bonuses:'),'flat native stats are shown once in the focused UI')
    check(weapon_rows.count { |s| s.start_with?('Accuracy') }==1,'accuracy appears once after grouped property rendering')
    english(BS2Suite::NAMES,'module names');english(BS2Suite::Keys::LABELS,'binding names');english(BS2Modules::PARAMS,'parameters')
    check(BS2Modules::PARAMS==$data_system.terms.params,'native English parameter labels distinguish DEF from Guard')
    [BS2Suite::SettingsCommands,BS2Suite::KeyCommands].each do |klass|
      window=klass.new(0,72);english(window.instance_variable_get(:@list).map { |r| r[:name] },klass.to_s);window.dispose
    end
    window=BS2Suite::ModuleCommands.new(BS2Suite::IDS);english(window.instance_variable_get(:@list).map { |r| r[:name] },'module menu');window.dispose
    english(BS2Modules::Effects.sources(actor).map { |r| [r[:name],r[:summary],r[:details]] },'H sources')
    $data_states.compact.each do |state|
      next if state.id==0
      actor.clear_states;actor.add_state(state.id)
      english(BS2Modules::Effects.active(actor).map { |r| [r[:name],r[:summary],r[:details]] },'H active state '+state.id.to_s)
    end
    actor.clear_states;actor.recover_all
    parents=BS2Suite::ArmorFamilies094.parents
    BS2Suite::ArmorFamilies094::GROUPS.each { |name,ids| check(ids[1..-1].all? { |id| parents[id] },'native English armor family '+name) }
    english(BS2Modules::Loadouts.lines(actor,nil),'empty loadout details')
    check(BS2Suite::CatalogV1.entries.size==2401,'complete factual catalog')
    # A transferred save retains automatic Russian group names. A new-game-only
    # check cannot detect this: exercise persisted layouts without rebuilding or
    # clearing their bindings, ordering, known entries or numeric assignments.
    locale=BS2Suite::Locale
    locale::SAVED_LABELS.each do |old,current|
      check(locale.saved_label(old)==current,'saved automatic label translation')
      check(locale.saved_label(old+' 2')==current+' 2','saved numbered group translation')
    end
    check(locale.saved_label('My personal group')=='My personal group','custom group name preserved')
    custom_name="\u041c\u043e\u044f \u043b\u0438\u0447\u043d\u0430\u044f \u0433\u0440\u0443\u043f\u043f\u0430"
    check(locale.saved_label(custom_name)==custom_name,'user-entered Cyrillic is not rewritten')
    %w(V B M).each do |prefix|
      BS2Suite::Semantic.sync(actor)
      layout=BS2Suite::Semantic.state['layouts'][BS2Suite::Semantic.layout_key(actor,prefix)]
      next if layout['groups'].empty?
      old="\u041f\u043e\u0434\u0433\u043e\u0442\u043e\u0432\u043a\u0430 2"
      layout['groups'][0]['name']=old
      before=Marshal.dump(layout)
      check(BS2Suite::Semantic.groups(actor,prefix)[0][:name]=='Preparation 2','transferred '+prefix+' menu is English')
      check(Marshal.dump(layout)==before,'localization preserves saved '+prefix+' layout')
    end
    weapon=catalog.entry($data_weapons[232])
    old='N12 → N11 '+weapon['names']['ru']
    check(locale.saved_notice(old)=='N12 → N11 '+weapon['names']['en'],'historical move notice uses native English name')
    log('result=PASS; assertions='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  end
end
