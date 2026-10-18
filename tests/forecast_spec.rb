# encoding: UTF-8
@checks=0;@samples=0;@critical_samples=0
def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
def check(value,label);raise 'Assertion: '+label unless value;@checks+=1;log('PASS '+label);end
def clone_object(object);Marshal.load(Marshal.dump(object));end
def state(id,features=[],note='')
  object=RPG::State.new;object.id=id;object.name='QA';object.features=features;object.note=note
  object.auto_removal_timing=0;$data_states[id]=object;object
end
def feature(code,id,value);RPG::BaseItem::Feature.new(code,id,value);end
def skill(formula='1000',type=1,hit=1,element=1,variance=20,note='')
  object=RPG::Skill.new;object.id=14;object.name='QA forecast';object.scope=1;object.occasion=0;object.hit_type=hit
  object.mp_cost=0;object.tp_cost=0;object.effects=[];object.note=note;object.success_rate=100
  object.damage.type=type;object.damage.formula=formula;object.damage.variance=variance;object.damage.element_id=element;object.damage.critical=true
  object
end
def snapshot
  temp=$game_temp.instance_variables.sort.map { |key| [key,$game_temp.instance_variable_get(key).inspect] }
  Marshal.dump([$game_party,$game_actors,temp,$game_variables,$game_switches])
end
def verify_samples(user,target,item,seeds=24)
  prediction=BS2QoL::Forecast::Prediction.new(user,target,item)
  raise 'Unavailable prediction: '+prediction.error.to_s if prediction.error
  seeds.times do |seed|
    a=clone_object(user);b=target==user ? a : clone_object(target)
    a.pay_skill_cost(item) if item.is_a?(RPG::Skill)
    hp=b.hp;mp=b.mp;srand(57313+seed)
    b.item_apply(a,item)
    if b.result.hit? && !b.result.cancel
      prediction.rows.each do |row|
        next if prediction.rows.size>1 || row[:conditional]
        expected=b.result.critical && row[:formula] ? row[:critical][:loss] : row[:normal][:loss]
        actual=row[:resource]=='HP' ? hp-b.hp : mp-b.mp
        raise 'Mismatch '+item.damage.formula+' seed '+seed.to_s+': '+actual.to_s+' outside '+expected.inspect unless actual.between?(*expected)
        @samples+=1
        @critical_samples+=1 if b.result.critical
      end
    end
  end
  prediction
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'forecast_suite; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(40,false);actor.clear_equipments
  [14,95,350].each { |id| actor.learn_skill(id) };actor.recover_all
  target=Game_Enemy.new(0,3);target.recover_all
  check(BS2QoL::VERSION=='0.7.1-alpha','forecast release loads through native bootstrap')
  formulas=($data_skills+$data_items).compact.map { |o| o.damage.formula }.uniq
  formula_checks=0
  [[1,1,1],[2,2,2],[3,0,3],[0,0,0]].each do |hp_mode,mp_mode,state_mode|
    a=clone_object(actor);b=clone_object(target)
    a.hp=hp_mode==0 ? a.mhp : [a.mhp/hp_mode,1].max;a.mp=mp_mode==0 ? 0 : [a.mmp/mp_mode,1].max
    b.hp=hp_mode==0 ? b.mhp : [b.mhp/hp_mode,1].max
    b.add_state(29) if state_mode==2;b.add_state(26) if state_mode==3
    sa=BS2QoL::Forecast::Snapshot.new(a);sb=BS2QoL::Forecast::Snapshot.new(b)
    formulas.each do |formula|
      oracle=skill(formula)
      begin
        raw=BS2QoL::Forecast.expression(formula,sa,sb);actual=[raw,0].max
      rescue ZeroDivisionError;actual=0
      end
      native=oracle.damage.eval(a,b,$game_variables)
      raise 'Expression mismatch '+formula+': '+actual.to_s+' != '+native.to_s unless actual==native
      formula_checks+=1
    end
  end
  check(formula_checks==formulas.size*4,'every database formula matches native eval in four HP MP and state contexts: '+formula_checks.to_s)
  covered=0
  $data_enemies.compact.each do |record|
    next if record.name.strip.empty?
    enemy=Game_Enemy.new(0,record.id)
    [skill('a.atk * 4 - b.def * 2',1,1,1),skill('a.mat * 5 - b.mdf * 2',1,2,9)].each do |item|
      prediction=BS2QoL::Forecast::Prediction.new(actor,enemy,item)
      raise 'Enemy coverage '+record.id.to_s+': '+prediction.error.to_s if prediction.error
      covered+=1
    end
  end
  check(covered==1048,'physical and magical forecasts build for all 524 enemy records')
  sa=BS2QoL::Forecast::Snapshot.new(actor);sb=BS2QoL::Forecast::Snapshot.new(target)
  rejected=0
  ["Kernel.rand(3)","a.hp=0","a.send(:hp)","File.read('anything')","$game_party.lose_gold(1)","1;2","2**10000"].each do |source|
    begin;BS2QoL::Forecast.expression(source,sa,sb)
    rescue BS2QoL::Forecast::Unsupported;rejected+=1
    end
  end
  check(rejected==7,'arbitrary Ruby calls assignments globals and power syntax are rejected')
  check(BS2QoL::Forecast.expression('1 ? 7 : 1/0',sa,sb)==7,'conditional parser does not evaluate an unchosen branch')
  check(BS2QoL::Forecast.expression('5-8/3',sa,sb)==3,'integer division and operator precedence match Ruby')

  # Real engine outcomes, not a second call to the predictor implementation.
  [1,0,2].each do |hit|
    [1,3,9,10,-1].each do |element|
      item=skill('a.atk * 4 + a.mat * 2 - b.def * 0.5',1,hit,element)
      prediction=verify_samples(actor,target,item)
      raise 'Missing damage row' unless prediction.rows.size==1
    end
  end
  check(true,'native item_apply outcomes stay inside target-specific ranges across 15 hit-type and element combinations')
  state(260,[feature(11,1,0.8),feature(23,6,0.8),feature(23,7,0.35)])
  target.add_state(260)
  p=verify_samples(actor,target,skill('1000',1,1,1,0))
  check(p.rows[0][:normal][:raw]==[640,640],'independent physical element and PDR rates multiply to 640')
  p=verify_samples(actor,target,skill('1000',1,0,1,0))
  check(p.rows[0][:normal][:raw]==[800,800],'certain hit ignores PDR but not element resistance')
  p=verify_samples(actor,target,skill('1000',1,2,9,0))
  log('magic fixture: raw='+p.rows[0][:normal][:raw].inspect+' rate='+p.rate.to_s+' element='+p.element.to_s)
  check(p.rows[0][:normal][:raw]==[420,420],'native light weakness 1.2 and MDR 0.35 combine to 420')
  p=verify_samples(actor,target,skill('1000',1,1,1,0,'<ダメージ率貫通:1,100>'))
  check(p.rows[0][:normal][:raw]==[640,640],'passive tag on skill remains inactive in both preview and engine')
  p=verify_samples(actor,target,skill('1000',1,1,1,0,'<ダメージ率貫通追加:50>'))
  check(p.rows[0][:normal][:raw]==[720,720],'item penetration acts on the reduced portion of PDR')
  state(261,[],'<ダメージ率貫通:1,100>');actor.add_state(261)
  p=verify_samples(actor,target,skill('1000',1,1,1,0))
  check(p.rows[0][:normal][:raw]==[800,800],'actual passive feature penetration applies to native user traits')
  actor.remove_state(261);target.remove_state(260)
  state(268,[feature(62,1,0)]);target.add_state(268)
  p=verify_samples(actor,target,skill('1000',1,1,1,0,'<防御状態無視率:50>'),100)
  log('guard fixture: raw='+p.rows[0][:normal][:raw].inspect+' bypass='+p.bypass.to_s+' guard='+p.target.guard?.to_s+' grd='+p.target.values['grd'].to_s)
  check(p.rows[0][:normal][:raw]==[(1000/(2*target.grd)).to_i,1000] && p.bypass==0.5,'Guard and its probabilistic bypass produce both legal damage branches')
  target.remove_state(268)
  # Native Guts and resource caps, including overkill and mana damage.
  target.hp=[target.mhp,100].min;target.add_state(59)
  p=verify_samples(actor,target,skill('1000',1,0,0,0))
  check(p.rows[0][:normal][:loss]==[99,99],'Guts leaves exactly one HP in a lethal native hit')
  target.hp=1;p=verify_samples(actor,target,skill('1000',1,0,0,0))
  check(p.rows[0][:normal][:loss]==[1,1],'Guts no longer protects a target already at one HP')
  target.remove_state(59);target.hp=[target.mhp,100].min
  p=verify_samples(actor,target,skill('10000',1,0,0,0))
  check(p.rows[0][:normal][:loss]==[100,100] && p.rows[0][:normal][:raw]==[10000,10000],'actual HP loss is distinguished from overkill popup damage')
  target.mp=[target.mmp,10].min
  p=verify_samples(actor,target,skill('1000',2,0,0,0))
  check(p.rows[0][:normal][:loss]==[target.mp,target.mp],'MP damage is capped to actual target MP')

  # Price precedes formulas, including ratios near zero.
  actor.mp=[actor.mmp,80].min
  item=skill('a.mp * 10',1,0,0,0);item.mp_cost=30
  p=verify_samples(actor,target,item)
  check(p.base==(actor.mp-actor.skill_mp_cost(item))*10,'MP cost is deducted before evaluating a current-MP formula')
  actor.recover_all
  item=skill('a.hp * 0.1',1,0,0,0,'<消費最大ＨＰ 10%>')
  p=verify_samples(actor,target,item)
  check(p.base==(actor.hp-actor.skill_hp_cost(item))*0.1,'HP percentage cost is deducted before evaluating current HP scaling')

  # Recovery, inversion, immunity and actual resource headroom.
  actor.hp=1;target.recover_all;target.hp=1
  heal=RPG::Item.new;heal.id=1;heal.name='QA heal';heal.scope=7;heal.occasion=0;heal.hit_type=0;heal.effects=[RPG::UsableItem::Effect.new(11,0,0.5,0)]
  p=verify_samples(actor,target,heal)
  check(p.rows[0][:normal][:raw][0]<0,'item recovery includes the effective REC and PHA multipliers')
  state(262,[],'<HP回復反転:100>');target.add_state(262)
  p=verify_samples(actor,target,heal)
  check(p.rows[0][:normal][:raw][0]>0,'native recovery inversion becomes predicted HP loss')
  target.hp=[target.mhp,100].min;target.add_state(59);target.add_state(268)
  p=verify_samples(actor,target,skill('200',3,0,0,20))
  check(p.rows[0][:normal][:loss]==[99,99],'formula healing inversion happens after Guard and is then limited by native Guts')
  target.remove_state(59);target.remove_state(268);target.hp=1
  state(263,[],'<HP回復無効:100>');target.add_state(263)
  p=verify_samples(actor,target,heal)
  check(p.rows[0][:normal][:loss]==[0,0],'recovery immunity takes priority over inversion')
  target.remove_state(262);target.remove_state(263)
  p=verify_samples(actor,target,skill('200',3,0,0,20))
  check(p.rows[0][:normal][:loss][1]<=0,'formula recovery uses negative HP loss with real variance')

  # Deterministic hit rules, skill cancellation and bodyguard selection.
  state(264,[feature(22,1,1.0)],'<全絶対回避>');target.add_state(264)
  p=BS2QoL::Forecast::Prediction.new(actor,target,skill())
  check(p.chance==0,'absolute evasion gives a zero chance')
  state(265,[],'<物理絶対命中>');actor.add_state(265)
  p=BS2QoL::Forecast::Prediction.new(actor,target,skill())
  check(p.chance==1,'this build prioritizes user absolute hit over absolute evasion')
  actor.remove_state(265);target.remove_state(264)
  state(266,[],'<スキル無効:14>');target.add_state(266)
  p=verify_samples(actor,target,skill())
  check(p.chance==0 && p.cancel==1,'specific-skill immunity cancels a normally damaging skill')
  target.remove_state(266)

  # The complete card may read every living enemy but may not mutate any state/RNG.
  actor.recover_all;actor.learn_skill(14)
  BattleManager.setup(5,true,false);$game_party.on_battle_start
  second=Game_Enemy.new(1,3);$game_troop.members<<second;second.add_state(260)
  before=snapshot;srand(90211);expected=Array.new(16) { rand };srand(90211)
  ru=BS2QoL::ReferenceCard.new($data_skills[14],actor,:ru)
  en=BS2QoL::ReferenceCard.new($data_skills[14],actor,:en)
  check(ru.sections.size==5 && en.sections.size==5 && en.sections[2].join.include?('First hit.'),'a bilingual forecast tab is generated before the formula')
  check(ru.sections[2].count { |s| s.start_with?('— ') }==2,'each current enemy gets a separate forecast')
  check(snapshot==before,'cards leave live resources queues targets states variables and temporary flags byte-identical')
  check(Array.new(16) { rand }==expected,'cards consume no random numbers')
  # A low-HP selected enemy is protected by an actual substitute feature.
  state(267,[feature(62,2,0)])
  second.add_state(267);first=$game_troop.members[0];first.hp=1
  p=BS2QoL::Forecast::Prediction.new(actor,first,skill('1000',1,1,0,0))
  check(p.target.source==second && !p.stable,'native substitution redirects forecast and prevents a false repeated-hit total')
  # Disable dangerous battle methods: the numerical preview must still work.
  class Game_Battler
    def make_damage_value(*args);raise 'Forecast called live damage calculation';end
    def item_apply(*args);raise 'Forecast applied an item';end
    def use_item(*args);raise 'Forecast used an item';end
    def apply_variance(*args);raise 'Forecast rolled damage variance';end
    def guard?;raise 'Forecast called probabilistic native guard?';end
  end
  class RPG::UsableItem::Damage
    def eval(*args);raise 'Forecast called arbitrary native formula eval';end
  end
  safe=BS2QoL::ReferenceCard.new($data_skills[14],actor,:en)
  check(safe.sections[2].join.include?('First hit.'),'preview remains functional with live damage eval item application and random guard disabled')
  check(@critical_samples>0,'native outcome samples include actual critical hits')
  log('formula_comparisons='+formula_checks.to_s+'; native_landed_hit_samples='+@samples.to_s+'; critical_hit_samples='+@critical_samples.to_s)
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure;exit
end
