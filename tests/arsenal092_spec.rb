# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
def roots(actor,g);BS2Suite::DirectWeapons.rows(actor,g).map { |r| BS2Suite::WeaponFamilies.root(r[:id]) };end
begin
  File.open('test_result.txt','w') { |f| f.puts 'arsenal092 dynamics' }
  DataManager.init;DataManager.setup_new_game
  actor=$game_party.leader;actor.change_class(1);actor.change_level(1,false);actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  direct=BS2Suite::DirectWeapons;model=BS2Suite::Semantic;families=BS2Suite::WeaponFamilies
  [102,113,278,157,362].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  actor.instance_variable_get(:@param_plus)[6]=10-actor.param_base(6)
  model.sync(actor)
  check(roots(actor,2).include?(112) && roots(actor,3).include?(277),'low base agility selects flat-speed Thief for N2 and retains Knuckles in N3')
  gear=actor.equips.dup;counts=$game_party.instance_variable_get(:@weapons).dup
  actor.instance_variable_get(:@param_plus)[6]=1000-actor.param_base(6);model.sync(actor)
  check(roots(actor,2).include?(277) && roots(actor,3).include?(112),'high base agility selects multiplicative Knuckles and retains flat-speed alternative')
  check(actor.equips==gear && $game_party.instance_variable_get(:@weapons)==counts,'candidate ranking never equips or trades weapons')
  BattleManager.setup(79,true,false);$game_party.on_battle_start
  frozen=direct.shelf(actor).map { |r| [r['group'],r['digit'],r['id']] }
  actor.instance_variable_get(:@param_plus)[6]=10-actor.param_base(6);direct.sync(actor)
  check(direct.shelf(actor).map { |r| [r['group'],r['digit'],r['id']] }==frozen,'stat changes during battle do not move frozen binds')
  $game_party.on_battle_end;model.sync(actor)
  check(roots(actor,2).include?(112),'next out-of-battle sync can update the speed recommendation')
  [391,397].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.instance_variable_get(:@param_plus)[4]=1-actor.param_base(4);model.sync(actor)
  magic=direct.layout(actor)['roles'].find { |r| r['metric']=='mat' }
  check(magic['weapon']==397,'low base magic chooses flat MAT over a weaker multiplicative platform')
  actor.instance_variable_get(:@param_plus)[4]=1000-actor.param_base(4);model.sync(actor)
  magic=direct.layout(actor)['roles'].find { |r| r['metric']=='mat' }
  check(magic['weapon']==391,'high base magic chooses the multiplicative platform rather than a fixed author priority')
  $game_party.gain_item($data_weapons[475],1);actor.instance_variable_get(:@param_plus)[4]=1-actor.param_base(4);model.sync(actor)
  roles=direct.layout(actor)['roles']
  check(roles.select { |r| ['agi','mat'].include?(r['metric']) }.all? { |r| r['weapon']==475 } && roots(actor,2).count(475)==1,'one owned weapon can cover speed and magic roles without duplicate binds')
  # Every valid database family: count and report capacity, no per-group overflow.
  $data_weapons.compact.select { |w| !w.name.to_s.empty? && w.id>0 && actor.equippable?(w) }.each { |w| $game_party.gain_item(w,1) }
  model.sync(actor)
  all=model.owned(actor).map { |w| families.root(w.id) }.uniq
  log('all_owned_families='+all.size.to_s)
  manual=direct.shelf(actor).select { |r| r['group']>=4 }.map { |r| r['id'] }
  check(manual.sort==all.sort,'all actual database families fit manual groups without hidden pages or dropped weapons')
  direct.groups(actor).each do |g|
    rows=direct.rows(actor,g[:number])
    check(rows.size<=10 && direct.pages(actor,g[:number])==1,'one bounded ten-entry group N'+g[:number].to_s)
    check(rows.map { |r| r[:digit] }==model::DIGITS[0,rows.size].chars.map { |v| v.to_i },'dense displayed digits N'+g[:number].to_s)
  end
  check((roots(actor,2)&roots(actor,3)).empty?,'N3 complements N2 without copying its current choices')
  popup=BS2Suite::PaletteWindow.new(actor,'N');popup.acknowledge;popup.set_group(10);popup.cycle_group(1)
  check(popup.group==1,'next group wraps from digit 0 to digit 1')
  popup.cycle_group(-1);check(popup.group==10,'previous group wraps from digit 1 to digit 0');popup.dispose
  # Previous custom page moves into a spare real group with behavior intact.
  model.customs['u99']={'name'=>'Old pages','groups'=>{'N3'=>'Моё исполнение'},'behaviors'=>{'N3'=>'last'},'entries'=>[
    {'prefix'=>'N','group'=>3,'digit'=>1,'kind'=>'weapon','id'=>278,'source'=>0,'page'=>0},
    {'prefix'=>'N','group'=>3,'digit'=>1,'kind'=>'weapon','id'=>362,'source'=>0,'page'=>1}]}
  model.persist;model.migrate_weapon_pages
  profile=model.customs['u99'];rows=profile['entries']
  check(rows.size==2 && rows.all? { |r| (r['page'] || 0)==0 } && rows.map { |r| r['group'] }.uniq.size==2,'custom page migration preserves both equal-digit bindings in separate groups')
  check(profile['behaviors']['N1']=='last','migrated page preserves delayed execution behavior')
  check(!BS2Suite::Store.read('profiles_before_092').empty?,'original paged profile is backed up before migration')
  model.set_mode(actor,'u99')
  check(!model.assign(actor,'N',3,2,$data_weapons[278],nil,1),'new assignments cannot hide a second page inside one group')
  model.persist;model.instance_variable_set(:@customs,nil)
  check(model.customs['u99']['entries'].size==2,'migrated assignments survive text reload')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
