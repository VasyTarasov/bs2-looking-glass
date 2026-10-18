# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
def clear_weapons(actor)
  actor.clear_equipments;$game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'native family_inventory091' }
  DataManager.init;DataManager.setup_new_game
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);clear_weapons(actor)
  f=BS2Suite::FamilyInventory
  BS2QoL::Preferences.toggle(:weapon,104);BS2QoL::Preferences.toggle(:weapon,157)
  $game_party.gain_item($data_weapons[111],1);actor.change_equip(0,$data_weapons[111])
  $game_party.gain_item($data_weapons[104],1);f.normalize
  check(actor.equips[0].id==111 && $game_party.item_number($data_weapons[104])==0,'Knight King Sword equipped: picked Knight Sword+3 is removed')
  check($game_party.item_number($data_weapons[111])==0,'cleanup does not duplicate the equipped highest weapon')
  check(BS2QoL::Preferences.ids(:weapon)==[111,157],'favorite follows the upgraded family while keeping unrelated favorites and their order')
  clear_weapons(actor)
  $game_party.gain_item($data_weapons[102],1);actor.change_equip(0,$data_weapons[102])
  $game_party.gain_item($data_weapons[104],1);f.normalize
  check(actor.equips[0].id==104 && $game_party.item_number($data_weapons[102])==0 && $game_party.item_number($data_weapons[104])==0,'higher pickup replaces unlocked equipped ancestor without duplication')
  $game_party.gain_item($data_weapons[104],2);f.normalize
  check($game_party.item_number($data_weapons[104])==1,'same-tier spare copies are capped at one')
  $game_party.gain_item($data_weapons[157],1);f.normalize
  check($game_party.item_number($data_weapons[157])==1,'unrelated weapon family is never consumed')
  actor.change_equip(0,$data_weapons[157]);f.normalize
  check(actor.equips[0].id==157 && $game_party.item_number($data_weapons[104])==1,'native equipment trade completes before cleanup and caps spare duplicates')
  clear_weapons(actor)
  f.suspend do
    $game_party.gain_item($data_weapons[101],1);$game_party.gain_item($data_weapons[104],1)
    check($game_party.item_number($data_weapons[101])==1,'transient recipe material is preserved inside a transaction')
  end
  f.normalize
  check($game_party.item_number($data_weapons[101])==0 && $game_party.item_number($data_weapons[104])==1,'completed transaction keeps only its highest distinct variant')
  clear_weapons(actor)
  $game_party.gain_item($data_weapons[102],1);actor.change_equip(0,$data_weapons[102])
  Game_Actor.class_eval { alias bs2091_test_lock equip_change_ok?;def equip_change_ok?(slot);@bs2091_test_locked && slot==0 ? false : bs2091_test_lock(slot);end };actor.instance_variable_set(:@bs2091_test_locked,true)
  $game_party.gain_item($data_weapons[104],1);f.normalize
  check(actor.equips[0].id==102 && $game_party.item_number($data_weapons[104])==1,'locked equipped ancestor is retained until a valid replacement can be made')
  actor.instance_variable_set(:@bs2091_test_locked,false)
  f.normalize
  check(actor.equips[0].id==104 && $game_party.item_number($data_weapons[102])==0,'unlocking permits safe replacement on next normalization')
  clear_weapons(actor)
  $game_party.gain_item($data_weapons[104],1)
  $game_party.instance_variable_set(:@in_battle,true)
  $game_party.gain_item($data_weapons[102],1);f.normalize
  check($game_party.item_number($data_weapons[102])==1 && f.pending?,'mid-battle cleanup is deferred without changing equipment or inventory')
  $game_party.instance_variable_set(:@in_battle,false);f.normalize
  check($game_party.item_number($data_weapons[102])==0,'deferred battle loot is normalized afterwards')
  # Inject a failure after an attempted real equip operation; all inventory and actor data roll back.
  clear_weapons(actor)
  $game_party.gain_item($data_weapons[102],1);actor.change_equip(0,$data_weapons[102]);$game_party.gain_item($data_weapons[104],1)
  Game_Actor.class_eval { alias bs2091_test_equip change_equip;def change_equip(slot,item);bs2091_test_equip(slot,item);raise 'synthetic equip failure' if @bs2091_test_failure;end };actor.instance_variable_set(:@bs2091_test_failure,true)
  before=Marshal.dump([actor.equips.map { |w| w && w.id },actor.hp,actor.mp,$game_party.instance_variable_get(:@weapons)])
  check(f.normalize==false,'failed normalization reports rollback instead of escaping to the engine')
  check(!f.pending?,'failed cleanup does not retry every frame or keep its notice alive forever')
  check(Marshal.dump([actor.equips.map { |w| w && w.id },actor.hp,actor.mp,$game_party.instance_variable_get(:@weapons)])==before,'failure restores exact equipment resources and inventory counts')
  actor.instance_variable_set(:@bs2091_test_failure,false)
  f.normalize
  check(actor.equips[0].id==104,'normalization can safely retry after failure')
  # Persistence migration happens in memory; no personal or synthetic save file is overwritten.
  clear_weapons(actor)
  f.suspend { $game_party.gain_item($data_weapons[111],1);$game_party.gain_item($data_weapons[104],1) }
  contents=Marshal.load(Marshal.dump(DataManager.make_save_contents))
  DataManager.extract_save_contents(contents)
  check($game_party.item_number($data_weapons[111])==1 && $game_party.item_number($data_weapons[104])==0,'loading old primitive contents removes a pre-existing lower variant in memory')
  check(!Dir.glob('Save*.rvdata2').any?,'cleanup never writes a game save by itself')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
