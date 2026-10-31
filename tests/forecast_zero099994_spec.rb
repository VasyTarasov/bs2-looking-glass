# encoding: UTF-8
class HUDZeroDefEnemy < Game_Enemy
  def param(id);[3,5].include?(id) ? 0 : super;end
end
rgss_main do
  checks=0
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Zero defence native parity' }
    DataManager.init;DataManager.setup_new_game;actor=$game_party.leader;actor.change_class(1);actor.change_level(200,false);actor.recover_all
    target=HUDZeroDefEnemy.new(0,562);target.recover_all
    [81,109,193,95].each do |id|
      skill=$data_skills[id];p=BS2QoL::Forecast::Prediction.new(actor,target,skill)
      raise 'zero defence prediction rejected' if p.error
      native=skill.damage.eval(actor,target,$game_variables)
      raise 'zero defence native mismatch' unless p.base==native
      checks+=1
      [0,1,2,3].each do |seed|
        a=BS2Suite::Projection.copy(actor);b=BS2Suite::Projection.copy(target);a.pay_skill_cost(skill);srand(994700+seed);b.item_apply(a,skill)
        ranges=p.rows.select { |r| r[:formula] }.map { |r| b.result.critical ? r[:critical][:loss] : r[:normal][:loss] }
        raise 'zero defence damage outside native interval' unless b.result.missed || b.result.evaded || ranges.any? { |lo,hi| b.result.hp_damage.between?(lo,hi) }
        checks+=1
      end
    end
    File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks='+checks.to_s }
  rescue Exception=>e
    File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace.join("\n") }
  ensure;BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge);end
end
