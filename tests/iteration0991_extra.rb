# encoding: UTF-8
# Executed inside the synthetic battle by iteration0991_spec.rb.
actor=$game_actors[1];scene=SceneManager.scene
nav=BS2Suite::NavigationAliases
check(BS2Suite::Options::DEFAULTS['adaptive_priority']==1 && BS2Suite::Options::DEFAULTS['tempo_hint']==1 && BS2Suite::Options::DEFAULTS['priority_window']==20,'priorities and tempo default on with twenty-battle history')
check(BS2Suite::Keys.token(:gear)=='G','Gear of Madness defaults to plain G')
commands=scene.instance_variable_get(:@actor_command_window)
check(!commands.instance_variable_get(:@list).any? { |r| r[:symbol]==:bs2092_journal },'F5 journal command is absent from battle command list')
BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;tick
[[87,:UP],[65,:LEFT],[83,:DOWN],[90,:RIGHT]].each do |vk,dir|
  tick;tick([vk]);check(Input.trigger?(dir) && Input.press?(dir),'WASZ duplicates '+dir.to_s)
end
tick;tick([65]);check(!Input.trigger?(:X),'battle A navigates without toggling favorites')
tick;tick([83]);check(!Input.trigger?(:Y),'battle S navigates without filtering favorites')
context_item=scene.instance_variable_get(:@item_window);context_item.show.activate;context_item.openness=255
check(!Input.press?(:DOWN),'opening a supported item list reserves its S filter immediately')
context_item.hide.deactivate
tick;tick([68]);check(Input.trigger?(:Z) && !Input.press?(:RIGHT),'D retains equipment/support meaning')
item=scene.instance_variable_get(:@item_window);item.show.activate;item.openness=255
tick;tick([65]);check(!Input.press?(:LEFT) && Input.trigger?(:X),'item list keeps A favorites and disables alternative arrows')
item.hide.deactivate;tick
BS2Suite::Options.set('navigation_aliases',0);tick([87]);check(!Input.press?(:UP),'alternative movement can be disabled');BS2Suite::Options.set('navigation_aliases',1);tick
check(!nav.set('RIGHT','D'),'alternative key editor refuses existing D assignment')
check(nav.set('RIGHT','L') && nav.data['RIGHT']=='L','alternative direction can be rebound independently');nav.set('RIGHT','Z')
# Cosmetic animation advances with battle state and RNG held still.
BS2Suite::CombatEffects.open(scene,commands)
sprites=scene.instance_variable_get(:@spriteset)
sprites.instance_variable_get(:@enemy_sprites).first.instance_variable_set(:@use_tmbsprex,true)
sprite=sprites.instance_variable_get(:@enemy_sprites).first
sprite.instance_variable_set(:@zoom_max,180);sprite.instance_variable_set(:@zoom_count,0)
mist=sprites.instance_variable_get(:@mist_sprites)
mist.first.z=599 if mist && mist.first
before=Marshal.dump([actor,$game_troop.members]);ap=$game_troop.members.map { |e| e.ap };turns=$game_troop.turn_count
srand(991);expected_random=rand;srand(991)
20.times { Graphics.update;Input.update }
check(sprite.instance_variable_get(:@zoom_count)>0,'enemy breathing continues under modal H')
check(ap==$game_troop.members.map { |e| e.ap } && turns==$game_troop.turn_count && before==Marshal.dump([actor,$game_troop.members]),'visual updates do not advance gauges, states, actions or resources')
check(rand==expected_random,'modal animation uses a separate visual RNG stream')
BS2Suite::CombatEffects.close(scene)
# Hysteresis operates on fixed group membership, outside active choices only.
p=BS2Suite::Priorities
BS2Suite::Options.set('adaptive_priority',1);BS2Suite::Options.set('priority_window',20)
p.instance_variable_set(:@history,[]);p.instance_variable_set(:@orders,{});p.instance_variable_set(:@messages,{});p.instance_variable_set(:@serial,1)
original=[105,106,110].each_with_index.map { |id,i| {:id=>id,:digit=>i+1,:object=>$data_skills[id],:prefix=>'V',:group=>1} }
base=actor.id.to_s+':';a=p.token('V',105);b=p.token('V',106);c=p.token('V',110)
history=Array.new(3) { {base+a=>2,base+b=>2,base+c=>3} }
p.instance_variable_set(:@history,history);p.reorder(actor,'V',1,original)
check(p.apply(actor,'V',1,original).map { |r| r[:id] }==[110,105,106],'clear 50 percent lead over several battles promotes within original group')
check(p.apply(actor,'V',1,original).map { |r| r[:digit] }==[1,2,3],'promoted group keeps consecutive working digits')
check(!p.messages(actor,'V').empty?,'reordered bindings produce a pending notification')
sorted=p.apply(actor,'V',1,original)
p.instance_variable_set(:@history,Array.new(20) { {base+a=>5,base+b=>1,base+c=>1} })
p.instance_variable_set(:@serial,2);p.reorder(actor,'V',1,sorted)
check(p.apply(actor,'V',1,original).map { |r| r[:id] }==[110,105,106],'three-battle rest suppresses immediate reversal')
p.instance_variable_set(:@serial,4);p.reorder(actor,'V',1,sorted)
check(p.apply(actor,'V',1,original).first[:id]==105,'sustained opposite demand can reorder after rest period')
p.acknowledge(actor,'V');check(p.messages(actor,'V').empty?,'acknowledgment clears priority notification persistently')
order=p.apply(actor,'V',1,original).map { |r| r[:id] };p.persist
p.instance_variable_set(:@history,nil);p.load
check(p.apply(actor,'V',1,original).map { |r| r[:id] }==order,'history and bounded order survive preference reload')
p.instance_variable_set(:@orders,{});p.instance_variable_set(:@history,Array.new(20) { {base+a=>4,base+b=>4,base+c=>5} })
p.instance_variable_set(:@serial,50);p.reorder(actor,'V',1,original)
check(p.apply(actor,'V',1,original).map { |r| r[:id] }==[105,106,110],'small usage lead does not reshuffle group')
history=Array.new(15) { {base+a=>5} }+Array.new(5) { {base+c=>5} }
p.instance_variable_set(:@history,history);p.instance_variable_set(:@orders,{})
BS2Suite::Options.set('priority_window',5);p.reorder(actor,'V',1,original)
check(p.apply(actor,'V',1,original).first[:id]==110,'five-battle window responds to recent sustained demand')
p.instance_variable_set(:@orders,{});BS2Suite::Options.set('priority_window',30);p.reorder(actor,'V',1,original)
check(p.apply(actor,'V',1,original).first[:id]==105,'longer window retains older sustained usage')
check(p.apply(actor,'B',1,original).equal?(original),'item groups are never ranked')
probe=RPG::Skill.new;probe.id=4994;probe.name='QA usage';probe.scope=0
p.begin_battle
8.times { actor.use_item(probe) }
counts=p.instance_variable_get(:@current)
check(counts[base+'s4994']==5,'actual native skill use is tracked and capped per battle')
stock=counts.dup;actor.use_item($data_items[19])
check(counts==stock,'item use does not contribute to adaptive priorities')
p.finish
check(p.instance_variable_get(:@history).size<=30 && !p.instance_variable_get(:@open),'completed battle commits bounded rolling history exactly once')
size=p.instance_variable_get(:@history).size;p.finish
check(p.instance_variable_get(:@history).size==size,'duplicate battle finish cannot append duplicate history')
BS2Suite::Options.set('adaptive_priority',0)
check(p.apply(actor,'V',1,original).equal?(original),'disabling priorities restores author order')
load 'tempo0992_extra.rb'
load 'followup0992_extra.rb'
if defined?(BS2Suite::QuickDamage)
  q=BS2Suite::QuickDamage;BS2Suite::Performance.reset
  actor.learn_skill(14);magic=$data_skills[14]
  count=[0]
  q.singleton_class.class_eval { alias bs20991_count_lines bs20991_cached_lines }
  q.define_singleton_method(:bs20991_cached_lines) { |*args| count[0]+=1;bs20991_count_lines(*args) }
  first=q.lines(scene,magic,actor);3.times { q.lines(scene,magic,actor) }
  check(count[0]==1,'unchanged mean is computed once then reused')
  actor.add_buff(4,3);q.lines(scene,magic,actor)
  check(count[0]==2,'live effect change invalidates cached forecast')
  BS2Suite::Performance.reset
  deferred=BS2Suite::Performance.defer { q.lines(scene,magic,actor) }
  check(deferred==['≈ …'],'new sidebar selection defers heavy estimate without blocking cursor')
  # An explicit reference/model request remains immediate and can satisfy the cache.
  immediate=q.lines(scene,magic,actor)
  check(!immediate.join.include?('…'),'direct model request calculates immediately')
  q.singleton_class.class_eval { alias bs20991_cached_lines bs20991_count_lines }
end
