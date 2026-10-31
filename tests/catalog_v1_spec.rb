# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;end
begin
  File.open('test_result.txt','w') { |f| f.puts 'Catalog v1 native integration' }
  DataManager.init;DataManager.setup_new_game
  log('mod_version='+BS2Suite::VERSION)
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  BS2Suite.load_part('catalog_v1')
  catalog=BS2Suite::CatalogV1
  actor=$game_actors[1];actor.change_class(1);actor.clear_equipments;actor.clear_states;actor.recover_all
  before=Marshal.dump([actor.hp,actor.mp,actor.tp,actor.equips,actor.actions,$game_party.gold])
  started=Win32API.new('kernel32','GetTickCount',[],'L').call
  check(catalog.entries.size==2401,'complete native load')
  elapsed=(Win32API.new('kernel32','GetTickCount',[],'L').call-started)&0xffffffff
  log('cold_load_ms='+elapsed.to_s)
  [[:skill,$data_skills],[:item,$data_items],[:weapon,$data_weapons],[:armor,$data_armors],[:state,$data_states]].each do |kind,objects|
    count=0
    objects.compact.each do |object|
      next if object.id==0
      entry=catalog.entry(object);check(entry && entry['uid']==kind.to_s+':'+object.id.to_s,'native identity')
      check(entry.frozen?,'read-only record')
      raw=entry['raw_mechanics']
      if object.respond_to?(:features)
        source=object.features.map { |f| [f.code,f.data_id,f.value] }
        copy=raw['features'].map { |f| [f['code'],f['data_id'],f['value']] }
        check(source==copy,'all original feature values preserved')
      end
      check(object.params==raw['params'],'all flat stats preserved') if object.is_a?(RPG::EquipItem)
      if object.is_a?(RPG::UsableItem)
        check(object.damage.formula==raw['damage']['formula'],'raw formula preserved')
        check(object.effects.map { |e| [e.code,e.data_id,e.value1,e.value2] }==raw['effects'].map { |e| [e['code'],e['data_id'],e['value1'],e['value2']] },'all effects preserved in order')
        panel=catalog.formula_panel(object)
        check(panel && panel['source_uid']==entry['uid'] && panel['raw']==object.damage.formula,'formula panel source matches actual action')
        check(panel.frozen? && panel['formula_scope']=='PER_HIT','formula panel is read-only and per hit')
      end
      [:ru,:en].each do |locale|
        lines=catalog.inline(object,locale);required=catalog.required_lines(object,locale)
        check(!lines.empty? && lines.all? { |s| s.valid_encoding? && !s.empty? },'valid inline text')
        check((required-lines).empty?,'critical facts are visible in inline payload')
      end
      if object.is_a?(RPG::Weapon)
        view=BS2Suite::Projection.weapon(actor,object);action=Game_Action.new(view);action.set_attack
        normal=catalog.normal_attack(object)
        check(normal['source_uid']=='skill:'+action.item.id.to_s && normal['base_repeats']==action.item.repeats,'normal attack source and repeats match native')
      end
      unless kind==:state
        [:ru,:en].each do |language|
          check(BS2QoL::PracticalCard.new(object,nil,language).sections.any?,'full legacy RU/EN card compatibility')
        end
      end
      count+=1
    end
    log('verified '+kind.to_s+'='+count.to_s)
  end
  ring=catalog.inline($data_armors[148]).join(' ')
  check(ring.include?('ЗАЩ ×2') && ring.include?('блокируется') && ring.include?('регенерация HP продолжает'),'God Fish complete description')
  check(catalog.inline($data_armors[169]).join.include?('блокируется'),'cloak drawback is not dropped')
  check(catalog.inline($data_weapons[177]).join.include?('Цена MP ×0'),'Creation zero cost')
  check(catalog.normal_attack($data_weapons[366])['copies_for_single_target']==12,'Hans +5 actual count')
  check(catalog.inline($data_skills[152]).join.include?('25% текущих HP'),'Hammer target current HP')
  check(catalog.entry('skill:493')['damage']['channels'].any? { |c| c['kind']=='HP_RECOVERY_EFFECT' && c['percent_of_target_max']==-0.1 },'Soul Break separate percent channel')
  check(catalog.formula_panel($data_skills[95])['text']=='ATK × 4 + MAT × 3 − DEF × 2 − MDF × 2','readable mixed formula')
  check(catalog.formula_panel($data_skills[493])['supplemental_lines'].join.include?('−10% MaxHP цели × REC цели'),'percent effect visible above prediction')
  action=Game_Action.new(actor);action.set_skill(859)
  check(catalog.formula_panel(action)['source_uid']=='skill:859' && catalog.formula_panel(action)['repeats']==8,'selected variant rather than neutral weapon attack')
  check(catalog.formula_panel($data_weapons[366])['source_uid']=='skill:549','weapon base formula resolution')
  check(BS2Suite::Reference098.lines($data_armors[148],'Кратко').join.include?('блокируется'),'legacy F7 payload first section contains drawback')
  check(BS2Suite::Reference098.brief($data_armors[148]).include?('блокируется'),'legacy short payload contains drawback')
  after=Marshal.dump([actor.hp,actor.mp,actor.tp,actor.equips,actor.actions,$game_party.gold])
  check(before==after,'catalog inspection preserves live actor and queue')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
