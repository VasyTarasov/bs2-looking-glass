# encoding: UTF-8
# Independent content and cross-panel contracts, including native countdown oracle.
rgss_main do
  @checks=0;@failures=[]
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);@checks+=1;@failures<<s unless v;log((v ? 'PASS ' : 'FAIL ')+s);end
  def text(x,a=nil,lang=:ru);BS2QoL::PracticalCard.new(x,a,lang).sections.flatten.join(' ').gsub(/[\uE000-\uE002]/,'');end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Reference content, effect sources and countdown consistency' }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments;actor.recover_all
    check(text($data_armors[141]).include?('Окс Вард'),'story equipment keeps reviewed purpose')
    check(text($data_armors[152]).include?('язык'),'story equipment keeps language purpose')
    check(text($data_skills[120],actor).include?('автоскрытность'),'stealth explains automatic renewal')
    check((text($data_skills[340],actor).include?('бег') || text($data_skills[340],actor).include?('Бег')),'map speed explains dash distinction')
    english=text($data_skills[14],actor,:en)
    check(english.include?('Cost:') && !english.include?('Тип попадания:'),'English action card uses English mechanical text')
    english=text($data_armors[82],actor,:en)
    check(english.downcase.include?('physical') && !english.include?('Прибавки:'),'English equipment card uses English mechanical text')
    english_errors=[];english_count=0
    [$data_skills,$data_items,$data_weapons,$data_armors].each do |table|
      table.compact.each do |o|
        c=BS2QoL::PracticalCard.new(o,nil,:en);english_count+=1
        flat=c.sections.flatten.join(' ')
        english_errors<<[o.class.to_s,o.id] if c.sections.empty? || !flat.valid_encoding? || ['Тип попадания:','Базовая цена:','Свойства записи:','Прибавки:','Отложенно:'].any? { |label| flat.include?(label) }
      end
    end
    check(english_errors.empty?,'English mechanical catalogue has no Russian field labels; records='+english_count.to_s)
    books=$data_items.compact.select { |o| o.effects.any? { |e| e.code==43 } }
    books.each do |book|
      learned=book.effects.select { |e| e.code==43 }.map { |e| $data_skills[e.data_id] }.compact
      learned.each { |s| actor.forget_skill(s.id) }
      check(text(book,actor).include?('○ '),'unlearned book '+book.id.to_s)
      learned.each { |s| actor.learn_skill(s.id) }
      check(text(book,actor).include?('✓ '),'learned book '+book.id.to_s)
    end
    gained=0
    ($data_skills.compact+$data_items.compact).each do |o|
      next if o.tp_gain==0
      gained+=1;check(text(o).include?('TP +'+o.tp_gain.to_s+' × TCR'),'TP on-hit reward '+o.class.to_s+':'+o.id.to_s)
    end
    log('tp_gain_records='+gained.to_s)
    $data_armors.compact.select { |o| o.note.include?('<保存禁止>') }.each do |o|
      check(text(o).include?('хранилище'),'storage rule '+o.id.to_s)
    end
    # Equal display names must never turn actor/class sources into an item card.
    gear=$data_armors.compact.find { |o| o.etype_id==4 && actor.equippable?(o) }
    $game_party.gain_item(gear,1);actor.change_equip(actor.equip_slots.index(4),gear)
    native_actor=actor.actor;old_name=native_actor.name;old_features=native_actor.features
    native_actor.name=gear.name;native_actor.features=[RPG::BaseItem::Feature.new(21,2,1.7)]
    source=BS2Modules::Effects.sources(actor).find { |r| r[:summary]=='Персонаж' }
    check(source && source[:details].join.include?('1.7'),'source identity survives equipment/actor name collision')
    native_actor.name=old_name;native_actor.features=old_features
    actor.clear_equipments;actor.clear_states;actor.clear_buffs
    effects=BS2Modules::Effects
    [1,2].each do |timing|
      s=RPG::State.new;s.id=4900+timing;s.name='QA countdown '+timing.to_s;s.icon_index=1
      s.auto_removal_timing=timing;s.min_turns=s.max_turns=2;$data_states[s.id]=s
      actor.add_state(s.id)
      icon=BS2Suite::CombatEffects.icons(actor).find { |r| r[2]==s.name }
      suffix=timing==1 ? 'д' : ''
      check(icon && icon[1]=='2'+suffix,'H uses native state counter '+timing.to_s)
      check(effects.duration(actor,s).join.include?('2'),'effect details agree with H '+timing.to_s)
      actor.update_state_turns(timing);actor.remove_states_auto(timing)
      check(actor.state?(s.id),'native first boundary retains state '+timing.to_s)
      actor.update_state_turns(timing);actor.remove_states_auto(timing)
      check(!actor.state?(s.id),'native second boundary removes state '+timing.to_s)
    end
    actor.add_buff(2,5)
    icon=BS2Suite::CombatEffects.icons(actor).find { |r| r[2]==BS2Modules::PARAMS[2] }
    suffix=ATB::BUFF_TURN_COUNT==1 ? 'д' : ''
    check(icon && icon[1]=='5'+suffix,'H uses native parameter buff counter')
    actor.clear_states
    s=RPG::State.new;s.id=4903;s.name='QA permanent frame state';s.icon_index=1
    s.auto_removal_timing=0;s.min_turns=s.max_turns=1;s.note='<ターンフレーム=6>';$data_states[s.id]=s
    actor.add_state(s.id)
    icon=BS2Suite::CombatEffects.icons(actor).find { |r| r[2]==s.name }
    check(icon && icon[1]=='∞','frame regeneration without automatic removal is not shown as expiring')
    log('result='+(@failures.empty? ? 'PASS' : 'FAIL')+'; checks='+@checks.to_s+'; failures='+@failures.size.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
