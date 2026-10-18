# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'ring inventory preservation '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.clear_equipments
    family=BS2Suite::FamilyInventory;family.normalize
    rings=$data_armors.compact.select { |a| a.etype_id==4 }
    rings.each { |ring| $game_party.gain_item(ring,4) }
    check(!family.pending?,'ring pickup does not schedule destructive equipment normalization')
    before=$game_party.instance_variable_get(:@armors).dup
    family.normalize
    rings.each { |ring| check($game_party.item_number(ring)==before[ring.id], 'all copies and upgrade tiers retained for ring ID '+ring.id.to_s) }
    slots=actor.equip_slots.each_index.select { |i| actor.equip_slots[i]==4 }
    check(slots.size>=2,'real actor has multiple ring slots')
    slots.take(2).each { |i| actor.change_equip(i,$data_armors[82]) }
    stock=$game_party.item_number($data_armors[82]);family.normalize
    check($game_party.item_number($data_armors[82])==stock && slots.take(2).all? { |i| actor.equips[i]==$data_armors[82] },'identical equipped rings and all remaining spare copies survive normalization')
    $game_party.gain_item($data_armors[189],3);family.normalize
    check($game_party.item_number($data_armors[82])==stock && $game_party.item_number($data_armors[189])==7,'base and plus-three rings coexist after obtaining a higher tier')
    $game_party.gain_item($data_armors[9],4);family.normalize
    check($game_party.item_number($data_armors[9])==1,'non-ring body armor still follows requested duplicate cleanup')
    $game_party.gain_item($data_weapons[101],4);family.normalize
    check($game_party.item_number($data_weapons[101])<=1,'weapon duplicate cleanup still works')
    expected=$game_party.instance_variable_get(:@armors).dup
    class << DataManager
      def make_filename(index);'BS2QA_Rings'+index.to_s+'.rvdata2';end
    end
    check(DataManager.save_game(0),'synthetic native save with repeated rings writes successfully')
    $game_party.lose_item($data_armors[86],1)
    check(DataManager.load_game(0),'synthetic native save with repeated rings loads successfully')
    check($game_party.instance_variable_get(:@armors)==expected,'load-time normalization preserves every saved ring count')
    $game_system.on_after_load
    check($game_party.instance_variable_get(:@armors)==expected,'native after-load path also leaves ring quantities intact')
    File.open('synthetic_ring_save.txt','w') { |f| f.puts File.expand_path(DataManager.make_filename(0)) }
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
