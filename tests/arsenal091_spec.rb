# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
def roots(actor,group)
  BS2Suite::DirectWeapons.shelf(actor).select { |e| e['group']==group }.map { |e| BS2Suite::WeaponFamilies.root(e['id']) }
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'native expanded arsenal091' }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons;families=BS2Suite::WeaponFamilies
  [102,157,223,278,362].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);model.sync(actor)
  %w(progression advanced).each do |mode|
    model.set_mode(actor,mode)
    check(roots(actor,2).include?(277),'Knuckles are an available early speed executor in '+mode)
    check(direct.behavior(actor,3)=='last','expanded N3 is a delayed executor in '+mode)
    check(roots(actor,3).include?(156) && !roots(actor,2).include?(222),'extended finishing alternatives stay distinct from technique-only Saw in '+mode)
  end
  BattleManager.setup(79,true,false);$game_party.on_battle_start
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.add_param(6,100)
  actor.recover_all;before=[actor.agi,actor.ap_gain_point]
  action=Game_Action.new(actor);action.set_attack;id=action.item.id
  actor.instance_variable_set(:@actions,[action]);direct.select(actor,$data_weapons[278]);direct.arm(actor);action.prepare
  log('speed_before='+before.inspect+' speed_after='+[actor.agi,actor.ap_gain_point].inspect+' weapon='+actor.equips[0].id.to_s)
  check(actor.equips[0].id==278 && actor.agi>before[0] && actor.ap_gain_point>before[1],'ending with Knuckles raises live agility and native ATB gauge gain')
  check(action.item.id==id && actor.actions.size==1 && !action.attack?,'speed finishing preserves the selected attack ID and does not invent a Knuckle double hit')
  $game_party.on_battle_end;model.set_mode(actor,'progression')
  ids=(BS2Suite::ArsenalCatalog::EXTRA.map { |r| r[2] }.flatten+BS2Suite::ArsenalCatalog::MAIN+BS2Suite::ArsenalCatalog::EXPANDED+[255,211,288,403]).uniq
  ids.each { |i| $game_party.gain_item($data_weapons[i],1) };model.sync(actor)
  check(direct.pages(actor,3)>1,'expanded executors paginate instead of dropping alternatives')
  owned=model.owned(actor).map { |w| families.root(w.id) }.uniq.sort
  browser=direct.shelf(actor).select { |e| e['group']>=4 }.map { |e| e['id'] }.sort
  check(browser==owned,'N4 and later expose every owned equippable family exactly once')
  check(direct.groups(actor).size<=10,'all manual categories fit available group digits')
  direct.groups(actor).each do |g|
    (0...direct.pages(actor,g[:number])).each do |page|
      rows=direct.rows(actor,g[:number],page)
      check(rows.size<=10 && rows.map { |r| r[:digit] }==model::DIGITS[0,rows.size].chars.map { |d| d.to_i },'dense digits on group '+g[:number].to_s+' page '+(page+1).to_s)
    end
  end
  rows=direct.shelf(actor).map { |e| [e['group'],e['page'] || 0,e['digit'],families.root(e['id'])] }.sort
  profile=model.clone_profile(actor)
  check(profile && direct.shelf(actor).map { |e| [e['group'],e['page'] || 0,e['digit'],families.root(e['id'])] }.sort==rows,'copying an automatic profile retains all weapon pages')
  check(model.persist,'paged custom profile writes bounded text')
  model.instance_variable_set(:@customs,nil)
  check(direct.shelf(actor).map { |e| [e['group'],e['page'] || 0,e['digit'],families.root(e['id'])] }.sort==rows,'all custom pages survive reload without overwriting equal digits on another page')
  first=direct.rows(actor,3,0).map { |r| [r[:digit],r[:id]] }
  check(model.assign(actor,'N',3,2,$data_weapons[255],nil,1),'player can replace a position on second custom weapon page')
  check(direct.rows(actor,3,0).map { |r| [r[:digit],r[:id]] }==first && direct.rows(actor,3,1).any? { |r| r[:digit]==2 && r[:id]==255 },'editing page 2 leaves page 1 unchanged')
  check(model.remove(actor,'N',3,2,1) && direct.rows(actor,3,0).map { |r| [r[:digit],r[:id]] }==first,'removing a paged binding affects only its own page')
  check(model.set_behavior(actor,3,'now') && direct.behavior(actor,3)=='now','custom N3 retains an explicitly chosen immediate action')
  model.persist;model.instance_variable_set(:@customs,nil)
  check(direct.behavior(actor,3)=='now','explicit custom action survives page-aware text round trip')
  model.set_mode(actor,'progression')
  old=Marshal.load(Marshal.dump(direct.layout(actor)));old['schema']=2;old['groups']=old['groups'].reject { |g| g['number']==3 }
  old['groups'].each { |g| g['number']-=1 if g['number']>3 };old['signature']=[]
  model.state['layouts'][model.layout_key(actor,'N')]=old
  direct.sync(actor)
  check(direct.behavior(actor,3)=='last' && model.pending_moves(actor,'N').any?,'old automatic N3+ layout migrates with a visible change notice')
  popup=BS2Suite::PaletteWindow.new(actor,'N');popup.acknowledge;popup.set_group(3);popup.cycle_page(1)
  check(popup.page==1 && popup.entries==direct.rows(actor,3,1) && popup.banner.include?('стр. 2'),'N3 actual palette exposes its next page and page indicator')
  popup.dispose
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
