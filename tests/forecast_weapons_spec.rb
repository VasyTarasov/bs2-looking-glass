# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'weapon context catalogue '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(100,false);actor.clear_equipments;actor.recover_all
    BattleManager.setup(79,true,false);$game_party.on_battle_start
    enemy=$game_troop.members[0];enemy.recover_all
    executors=[101,123,277,343,391,420].map { |id| $data_weapons[id] }
    count=unknown=0;source_ids=[]
    $data_weapons.compact.each do |weapon|
      source=BS2Suite::Projection.weapon(actor,weapon)
      original=Game_Action.new(source);original.set_attack
      item=original.item;source_ids<<item.id
      ([weapon]+executors).uniq.each do |executor|
        view=BS2Suite::Projection.weapon(actor,executor)
        a=Game_Action.new(view);a.set_skill(item.id);a.target_index=0
        prediction=BS2QoL::Forecast::Prediction.new(view,enemy,a.item)
        if prediction.error;unknown+=1;next;end
        native=a.make_targets.compact.size*a.item.repeats
        recipients=if a.item.for_random?;a.item.number_of_targets
        elsif a.item.for_all?;a.item.for_opponent? ? $game_troop.alive_members.size : $game_party.alive_members.size
        elsif a.item.scope==0;0
        else;1;end
        expected=prediction.repeats*recipients
        raise 'Normal repeat mismatch source='+weapon.id.to_s+' executor='+executor.id.to_s+' ID='+item.id.to_s+' native='+native.to_s+' forecast='+expected.to_s unless expected==native
        count+=1
      end
    end
    File.open('forecast_weapons_counts.txt','w') { |f| f.puts 'weapon_records='+$data_weapons.compact.size.to_s;f.puts 'contexts='+count.to_s;f.puts 'unknown='+unknown.to_s;f.puts 'normal_ids='+source_ids.uniq.size.to_s }
    check($data_weapons.compact.size==500,'all 500 weapon records enter native normal-attack source/executor audit')
    check(count+unknown==3494,'each source is tested with itself and six representative execution platforms')
    check(count>3000,'over three thousand supported normal-attack repeat contexts agree with native targeting')
    check(source_ids.uniq.size>5,'audit covers special normal IDs as well as ordinary Attack')
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
