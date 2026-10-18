# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def check(v,t);raise t unless v;@checks+=1;File.open('test_result.txt','a') { |f| f.puts 'PASS '+t };end
begin
 File.open('test_result.txt','w') { |f| f.puts 'equipped upgrade edge cases080' }
 DataManager.init;DataManager.setup_new_game
 actor=$game_party.members[0];actor.change_class(1);actor.clear_equipments
 $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
 $game_party.gain_item($data_weapons[102],2);actor.change_equip(0,$data_weapons[102]);$game_party.gain_item($data_items[26],6)
 $game_system.w_rcp_sw[103]=true;$game_system.w_rcp_sw[104]=true
 list=Window_ItemSynthesisList.new(0,72,320);list.category=:weapon
 scene=Scene_ItemSynthesis.new;scene.instance_variable_set(:@list_window,list);scene.instance_variable_set(:@item,$data_weapons[103]);scene.instance_variable_set(:@gold_window,Struct.new(:value).new($game_party.gold))
 check(scene.max_buy==2,'one bag copy plus one equipped copy allow exactly two upgrades')
 check(scene.do_syntetic(2),'mixed batch upgrade succeeds')
 check(actor.equips[0].id==103 && $game_party.item_number($data_weapons[103])==1 && $game_party.item_number($data_weapons[102])==0,'mixed batch keeps one improved copy equipped and one in bag')
 check($game_party.item_number($data_items[26])==0,'mixed batch charges materials for both copies')
 $game_party.lose_item($data_weapons[103],999);$game_party.gain_item($data_items[26],5)
 action=Game_Action.new(actor);action.set_skill(105);actor.instance_variable_set(:@actions,[action])
 scene.instance_variable_set(:@item,$data_weapons[104])
 before=[actor.equips.dup,actor.hp,actor.mp,$game_party.item_number($data_items[26]),$game_party.gold]
 result=BS2Suite::EquippedUpgrade.craft(scene,1) { scene.bs2080_syntetic(1);raise 'injected post-grant failure' }
 check(!result && [actor.equips,actor.hp,actor.mp,$game_party.item_number($data_items[26]),$game_party.gold]==before,'failure after native result grant rolls back all observable state')
 check($game_party.item_number($data_weapons[104])==0 && actor.current_action.subject.equal?(actor),'rollback leaves no result copy and reconnects action owner')
 class << actor
  alias bs2080_test_change equip_change_ok?
  def equip_change_ok?(slot);false;end
 end
 check(!list.have_mat?(WD_itemsynthesis_ini::W_recipe[104]),'locked equipped copy is not offered as a crafting ingredient')
 class << actor
  alias equip_change_ok? bs2080_test_change
 end
 list.dispose
 File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks='+@checks.to_s }
rescue Exception=>e
 File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure
 SuiteCapture.close
end
end
