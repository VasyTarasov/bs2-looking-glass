# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  def plan(actor,ids,index=0)
    actions=ids.map { |id| a=Game_Action.new(actor);a.set_skill(id);a.target_index=0;a }
    actor.instance_variable_set(:@actions,actions);actor.instance_variable_set(:@action_input_index,index)
    actor.cool_time.clear;BS2Suite::DirectWeapons.clear(actor);BS2Suite::Performance.bump
  end
  def feature(c,i,v);RPG::BaseItem::Feature.new(c,i,v);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'forecast presentation and diagnostic evidence '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(100,false);actor.clear_equipments;actor.recover_all
    BS2Suite::Options.data['knowledge_threshold']=0
    record=RPG::Enemy.new;record.id=5950;record.name='QA left';record.params=[1000000,20000,20,20,20,20,20,20]
    record.features=[feature(22,6,1)];$data_enemies[5950]=record
    second=Marshal.load(Marshal.dump(record));second.id=5951;second.name='QA right';$data_enemies[5951]=second
    troop=RPG::Troop.new;troop.id=5950
    troop.members=[5950,5951].map { |id| m=RPG::Troop::Member.new;m.enemy_id=id;m }
    $data_troops[troop.id]=troop;BattleManager.setup(troop.id,true,false);$game_party.on_battle_start
    target=$game_troop.members[0]
    s=RPG::Skill.new;s.id=5952;s.name='QA repeated percent';s.scope=1;s.occasion=1;s.hit_type=1;s.success_rate=100;s.repeats=3
    s.damage.type=1;s.damage.formula='100';s.damage.variance=0;s.effects=[RPG::UsableItem::Effect.new(11,0,-0.03,0)]
    $data_skills[s.id]=s;actor.learn_skill(s.id);plan(actor,[s.id])
    report=BS2Suite::SequenceForecast.new(actor)
    check(report.steps[0][:reason] && report.steps[0][:rows].empty?,'counter between repeats still refuses an unverified complete total')
    first=BS2Suite::ForecastContext.step(s,actor,nil,target,nil,true,true)
    expected=100+(target.mhp*0.03*target.rec).to_i
    check(first && !first[:reason] && first[:snapshot_only] && first[:rows][0][:max]==expected,'current-state fallback computes exactly one hit including percentage effect')
    if defined?(BS2Suite::QuickDamage)
      text=BS2Suite::QuickDamage.lines(SceneManager.scene,s,actor,nil,target).join(' ')
      check(text.include?('сейчас, первое попадание; серия ?') && text.include?(expected.to_s),'compact fallback labels the first hit instead of presenting it as the full action')
    end
    card=BS2QoL::PracticalCard.new(s,actor,:ru);text=card.compact_forecast.join(' ')
    check(text.include?('1-е попадание сейчас') && text.include?('Продолжение не рассчитано'),'F7 separately labels the fallback and excluded queue prefix')
    effect_text=card.practical_effects.join(' ')
    check(BS2Suite::CatalogUI.plain(effect_text).include?('Урон HP: 3% MaxHP × REC') && !effect_text.include?('Восстановление HP: -'),'negative recovery is explained as resource loss and separate from formula resistance')
    heal=RPG::Item.new;heal.id=5954;heal.name='QA healing';heal.effects=[RPG::UsableItem::Effect.new(11,0,0.1,0)]
    check(BS2QoL::PracticalCard.new(heal,actor,:ru).practical_effects.join.include?('Восстановление HP: 10%'),'positive healing keeps its recovery description')
    original_losses=($data_skills+$data_items).compact.select { |x| x.id<1000 && x.effects.any? { |e| [11,12].include?(e.code) && (e.value1<0 || e.value2<0) } }
    check(original_losses.size==89,'real compiled-card loss catalog has all 89 records')
    original_losses.each do |original|
      actual=BS2QoL::PracticalCard.new(original,nil,:ru).practical_effects.join(' ')
      resources=original.effects.select { |e| [11,12].include?(e.code) && (e.value1<0 || e.value2<0) }.map { |e| e.code==11 ? 'HP' : 'MP' }.uniq
      check(resources.all? { |r| actual.include?('Урон '+r+':') } && !(actual =~ /Восстановление (?:HP|MP): -/),'real RU compiled effect card uses loss wording '+original.class.to_s+' '+original.id.to_s)
    end
    # A prefix with an event cannot be assumed to have run in a current-state view.
    prep=RPG::Skill.new;prep.id=5953;prep.name='QA event';prep.scope=11;prep.occasion=1;prep.effects=[RPG::UsableItem::Effect.new(44,1,0,0)]
    $data_skills[prep.id]=prep;actor.learn_skill(prep.id);plan(actor,[prep.id,s.id],1)
    check(BS2Suite::ForecastContext.step(s,actor,nil,target)[:reason],'unmodelled prefix still blocks the selected sequence result')
    first=BS2Suite::ForecastContext.step(s,actor,nil,target,nil,true,true)
    check(first && first[:snapshot_only] && first[:rows][0][:max]==expected,'first-hit fallback does not invent effects from the unmodelled prefix')
    # Pure negative recovery effects need a compact preview even without formula damage.
    record.features=[];second.features=[];s.repeats=1;s.damage.type=0;plan(actor,[s.id])
    if defined?(BS2Suite::QuickDamage)
      lines=BS2Suite::QuickDamage.lines(SceneManager.scene,s,actor)
      log('pure_percentage_lines='+lines.inspect)
      check(lines.size==2 && lines[0].include?('QA left') && lines[1].include?('QA right'),'separate targets are named and pure percentage damage is visible')
      s.damage.type=1;s.damage.formula='10';s.effects<<RPG::UsableItem::Effect.new(12,0,-0.02,0)
      BS2Suite::Performance.bump
      lines=BS2Suite::QuickDamage.lines(SceneManager.scene,s,actor,nil,target).join(' ')
      check(lines.include?((10+(target.mhp*0.03*target.rec).to_i).to_s),'compact HP number excludes the separate MP effect')
      BS2Suite::Options.data['knowledge_threshold']=999999
      hidden=BS2Suite::QuickDamage.lines(SceneManager.scene,s,actor,nil,target).join(' ')
      check(hidden.include?('закрыты') && !hidden.include?(target.mhp.to_s),'fallback obeys the knowledge gate')
      BS2Suite::Options.data['knowledge_threshold']=0
    end
    # Low HP and changing maxima after death must not produce a confident total.
    s.damage.type=1;s.damage.formula='1000000000';plan(actor,[s.id])
    step=BS2Suite::SequenceForecast.new(actor).steps[0]
    check(step[:reason] && step[:rows].empty?,'resource effects after possible formula death refuse unknown post-death maxima')
    s.damage.formula='0';s.repeats=3;target.hp=1;plan(actor,[s.id])
    step=BS2Suite::SequenceForecast.new(actor).steps[0]
    check(step[:reason] && step[:rows].empty?,'percentage death cannot silently multiply later hits on the corpse')
    target.recover_all;s.repeats=1;s.effects=[RPG::UsableItem::Effect.new(11,0,-0.03,0)];plan(actor,[s.id])
    before=Marshal.dump([actor,$game_party,$game_troop]);srand(74513);expected_rng=rand;srand(74513)
    BS2Suite::ForecastContext.step(s,actor,nil,target,nil,true,true)
    check(before==Marshal.dump([actor,$game_party,$game_troop]) && rand==expected_rng,'fallback preserves resources, queue, targets and native RNG')
    if defined?(BS2Suite::Debug)
      # Intercept only synthetic forecast records from this own QA process.
      $qa_forecasts=[]
      BS2Suite::Debug.singleton_class.class_eval do
        alias qa_original_emit emit
        def emit(type,fields={});$qa_forecasts<<fields if type=='forecast_result';qa_original_emit(type,fields);end
      end
      BS2Suite::Debug.start
      BS2Suite::ForecastTrace.instance_variable_set(:@seen,{})
      BS2Suite::ForecastTrace.instance_variable_set(:@pending,[])
      BS2Suite::ForecastTrace.instance_variable_set(:@written,nil)
      report=BS2Suite::SequenceForecast.new(actor)
      fields=$qa_forecasts.last
      check(fields && fields[:schema]==2 && fields[:numeric_rows][0][1][0][4]==(target.mhp*0.03).to_i,'trace records the actual numeric forecast row')
      check(fields[:known_target_contexts][0][1]==target.enemy_id && fields[:known_target_contexts][0][2][0]==target.mhp,'trace records known live enemy identity and parameters')
      check(fields[:level]==actor.level && fields[:learned_skills].include?(s.id) && fields[:action_contexts][0],'trace preserves actor and selected-action execution context')
      count=$qa_forecasts.size;20.times { BS2Suite::ForecastTrace.record(actor,report) }
      check($qa_forecasts.size==count,'unchanged contexts remain deduplicated')
      target.hp-=1;BS2Suite::ForecastTrace.instance_variable_set(:@written,nil);BS2Suite::ForecastTrace.record(actor,report)
      check($qa_forecasts.size==count+1,'changing target HP bypasses diagnostic deduplication')
      record.params[0]+=1000;BS2Suite::ForecastTrace.instance_variable_set(:@written,nil);BS2Suite::ForecastTrace.record(actor,report)
      check($qa_forecasts.size==count+2,'changing target maximum bypasses diagnostic deduplication')
      s.damage.formula='v[712]';$game_variables[712]='QA_PRIVATE_STRING_CANARY'
      BS2Suite::ForecastTrace.instance_variable_set(:@written,nil);BS2Suite::ForecastTrace.record(actor,report)
      check(!BS2Suite::Debug.json($qa_forecasts.last).include?('QA_PRIVATE_STRING_CANARY'),'forecast evidence never serializes string variable contents')
      s.damage.formula='0'
      BS2Suite::Debug.singleton_class.class_eval { alias emit qa_original_emit;remove_method :qa_original_emit }
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
