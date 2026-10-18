# encoding: UTF-8
@checks=0
def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
def check(value,label);raise 'Assertion: '+label unless value;@checks+=1;log('PASS '+label);end
def queued(actor,id,target)
  action=Game_Action.new(actor);action.set_skill(id);action.target_index=target.index;action
end
def ordinary(id)
  item=RPG::Skill.new;item.id=id;item.name='QA sequence';item.scope=1;item.occasion=0
  item.hit_type=0;item.success_rate=100;item.tp_gain=0;item.mp_cost=0;item.tp_cost=0
  item.damage.type=1;item.damage.formula='100';item.damage.element_id=0;item.damage.variance=0;item.damage.critical=false
  $data_skills[id]=item;item
end
def cooldown_snapshot
  table=$game_temp.instance_variable_get(:@cool_time)
  table.map { |owner,values| [owner.object_id,values.to_a.sort] }.sort
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'semantic_forecast_070; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments;actor.recover_all
  BattleManager.setup(79,true,false);$game_party.on_battle_start
  enemy=$game_troop.alive_members[0];enemy.clear_states;enemy.recover_all
  BS2Suite::Options.set('knowledge_threshold',0)
  item=ordinary(14);actor.learn_skill(14);actor.learn_skill(15)
  actor.instance_variable_set(:@actions,[queued(actor,14,enemy),queued(actor,14,enemy)])
  report=BS2Suite::SequenceForecast.new(actor)
  check(report.complete && report.steps.all? { |s| s[:rows].any? },'ordinary two-action sequence has a complete forecast')
  item.note='<クールタイム:2>';item.instance_variable_set(:@cool_time,nil)
  before=cooldown_snapshot;resources=[actor.hp,actor.mp,actor.tp,$game_party.gold]
  srand(7291);expected=rand;srand(7291)
  report=BS2Suite::SequenceForecast.new(actor)
  check(!report.complete && report.steps[0][:rows].any? && report.steps[1][:rows].empty?,'a queued cooldown blocks the second use without a fabricated result')
  check(report.steps[1][:reason].include?('КД'),'cooldown unavailability has an explicit explanation')
  check(cooldown_snapshot==before && resources==[actor.hp,actor.mp,actor.tp,$game_party.gold] && rand==expected,'availability and queued cooldown simulation do not mutate live state or RNG')
  actor.cool_time[14]=2;before=cooldown_snapshot
  view=BS2Suite::Projection.copy(actor)
  check(view.cool_time[14]==2 && !view.usable?(item),'equipment projection inherits the live cooldown')
  card=BS2QoL::PracticalCard.new(item,view,:ru)
  check(card.read_cooldown(item)==2 && cooldown_snapshot==before,'projected reference reads the cooldown without registering copies')
  actor.cool_time[14]=0
  item=ordinary(14);item.mp_cost=6;actor.mp=10
  report=BS2Suite::SequenceForecast.new(actor)
  check(!report.complete && report.steps[1][:rows].empty?,'later actions respect MP spent by earlier actions')
  actor.recover_all;item=ordinary(14)
  actor.instance_variable_set(:@actions,[Game_Action.new(actor),queued(actor,14,enemy)])
  report=BS2Suite::SequenceForecast.new(actor)
  check(!report.complete && report.steps[1][:rows].empty?,'an unfilled preceding slot stops numerical continuation')
  actor.instance_variable_set(:@actions,[queued(actor,14,enemy)])
  item.note='<強制付与>'
  (900..906).each do |id|
    state=RPG::State.new;state.id=id;state.name='QA branch';state.auto_removal_timing=0;$data_states[id]=state
    item.effects<<RPG::UsableItem::Effect.new(21,id,0.5,0)
  end
  report=BS2Suite::SequenceForecast.new(actor)
  check(!report.complete && report.steps[0][:rows].empty? && report.steps[0][:cost].nil?,'branch overflow hides incomplete means and resource ranges')
  check(report.steps[0][:reason].include?('64'),'branch overflow is explained at the bounded limit')
  item=ordinary(14);item.damage.type=0;item.note='<強制付与>'
  state=$data_states[900];state.features=[RPG::BaseItem::Feature.new(21,3,0.5)]
  item.effects=[RPG::UsableItem::Effect.new(21,900,0.5,0)]
  hit=ordinary(15);hit.damage.formula='b.def * 10'
  actor.instance_variable_set(:@actions,[queued(actor,14,enemy),queued(actor,15,enemy)])
  report=BS2Suite::SequenceForecast.new(actor)
  row=report.steps[1][:rows][0]
  check(report.complete && row && row[:min]<row[:max] && row[:mean]>row[:min] && row[:mean]<row[:max],'a probabilistic weakness changes the following damage range and weighted mean')
  check(!enemy.state?(900),'branch state effects do not reach the actual enemy')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>error
  log('result=FAIL; '+error.class.to_s+': '+error.message);log(error.backtrace.join("\n"))
ensure
  SceneManager.exit;Graphics.transition(0);exit
end
