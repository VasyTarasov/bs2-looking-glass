# encoding: UTF-8
actor=$game_actors[1];scene=SceneManager.scene;tempo=BS2Suite::TempoHint
BS2Suite::Options.set('tempo_hint',1);BS2Suite::Options.set('knowledge_threshold',0)
enemies=$game_troop.alive_members
actor.clear_states;actor.clear_buffs
actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
enemies.each { |e| e.clear_states;e.clear_buffs;e.ap=0 }
enemies[0].ap=ATB::MAX_AP-1
before=Marshal.dump([actor,enemies]);srand(77);expected=rand;srand(77)
r=tempo.calculate(actor)
check(r[0]==:first && before==Marshal.dump([actor,enemies]) && rand==expected,'ready enemy is starred without state or RNG changes')
check(tempo.lines(scene).empty?,'tempo adds no persistent sidebar or classic text panel')
unit=tempo.copy(enemies[1]);unit.ap=0
check(tempo.ticks(unit)==(ATB::MAX_AP/(unit.ap_gain_point*ATB::REFRESH_FRAME).to_f).ceil,'ordinary readiness follows exact native gain quantum')
# Controlled speed fixtures allow comparisons against native frame_update.
slow=RPG::State.new;slow.id=4990;slow.name='QA slow';slow.auto_removal_timing=3;slow.min_turns=slow.max_turns=1
slow.features=[RPG::BaseItem::Feature.new(21,6,0.1)];slow.note='<ターンフレーム=6>';$data_states[slow.id]=slow
stun=RPG::State.new;stun.id=4991;stun.name='QA stun';stun.restriction=4;stun.auto_removal_timing=1;stun.min_turns=stun.max_turns=2;$data_states[stun.id]=stun
haste=RPG::State.new;haste.id=4992;haste.name='QA haste';haste.auto_removal_timing=1;haste.min_turns=haste.max_turns=4
haste.features=[RPG::BaseItem::Feature.new(21,6,10.0)];$data_states[haste.id]=haste
unit=tempo.copy(enemies[1]);unit.ap=0;unit.add_state(slow.id)
ticks=tempo.ticks(unit);elapsed=0
# The native frame updater is safe only on a local copy; it can refresh sprites
# at expiry, but no original battler is applied or consumed.
while unit.ap<ATB::MAX_AP && elapsed<1000;unit.frame_update;elapsed+=1;end
check(ticks==elapsed,'frame-based slow expires during readiness, matching native frames')
unit=tempo.copy(enemies[0]);unit.ap=ATB::MAX_AP;unit.add_state(stun.id)
cycle=(ATB::MAX_AP/(unit.ap_gain_point*ATB::REFRESH_FRAME).to_f).ceil
check(tempo.ticks(unit)==cycle*2,'two disabled owner turns are skipped, then recovery gets a real turn')
stun.note='<次の行動前に解除>';unit.instance_variable_get(:@state_turns)[stun.id]=1
check(tempo.ticks(unit)==0,'native before-action release permits an immediate real turn')
stun.note='';unit.instance_variable_get(:@state_turns)[stun.id]=2
stun.auto_removal_timing=0;stun.instance_variable_set(:@atb_auto_removal_timing,nil)
check(tempo.ticks(unit)==tempo::INF,'permanent current restriction cannot produce a false star')
stun.auto_removal_timing=1;stun.instance_variable_set(:@atb_auto_removal_timing,nil)
probe=RPG::Skill.new;probe.id=4993;probe.name='QA tempo';probe.scope=11;probe.hit_type=0;probe.success_rate=100;probe.occasion=1
probe.effects=[RPG::UsableItem::Effect.new(21,haste.id,1.0,0)];$data_skills[probe.id]=probe;actor.learn_skill(probe.id)
base=tempo.calculate(actor);hover=tempo.calculate(actor,[probe,nil])
check(hover.values.none? { |s| s==:unknown },'hovered self haste has a calculable outcome')
view,actions=tempo.plan(actor,[probe,nil]);check(actions[0].item==probe && actor.input.item.nil?,'hover changes only the copied input slot')
actor.input.set_skill(probe.id)
check(tempo.calculate(actor)==hover,'queued and hovered haste share the same post-series forecast')
actor.input.clear
snapshot=Marshal.dump([actor,enemies,$game_party,$game_variables,$game_switches])
srand(992);expected=rand;srand(992)
10.times { tempo.calculate(actor,[probe,nil]) }
check(snapshot==Marshal.dump([actor,enemies,$game_party,$game_variables,$game_switches]) && rand==expected,'repeated effect forecasts preserve all live battlers, stock, globals and combat RNG')
attack=RPG::Skill.new;attack.id=4994;attack.name='QA plain';attack.scope=1;attack.hit_type=0;attack.occasion=1;$data_skills[attack.id]=attack;actor.learn_skill(attack.id)
actor.instance_variable_set(:@actions,[Game_Action.new(actor),Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,1)
actor.actions[0].set_skill(probe.id);actor.actions[1].set_skill(attack.id);actor.actions[1].target_index=0
fast_view=tempo.copy(actor);fast_view.instance_variable_get(:@states)<<haste.id
fast_view.instance_variable_get(:@state_turns)[haste.id]=4
delay=(tempo.ticks(actor,0)+tempo.ticks(fast_view,0))/2
enemies.each { |e| e.ap=0 };enemies[0].ap=[[ATB::MAX_AP-delay*enemies[0].ap_gain_point*ATB::REFRESH_FRAME,0].max,ATB::MAX_AP-1].min
boosted=tempo.calculate(actor)
actor.actions[0].clear;unboosted=tempo.calculate(actor)
check(boosted[0]==:none && [:first,:before].include?(unboosted[0]),'previous selected haste changes the forecast for a later action in the queue '+[boosted,unboosted,delay].inspect)
actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
enemies[0].ap=ATB::MAX_AP-1;base=tempo.calculate(actor)
probe.effects=[RPG::UsableItem::Effect.new(21,stun.id,1.0,0)];probe.scope=1
check(tempo.calculate(actor,[probe,nil])==base,'even guaranteed proposed stun is deliberately ignored')
probe.effects=[];probe.note='<行動後ＡＰ=100>'
# Use the actual parser cache-independent syntax from native next_ap.
probe.define_singleton_method(:next_ap) { [100,0] }
check(tempo.calculate(actor,[probe,nil]).values.all? { |s| s==:none },'hovered full retained AP lets hero win ordinary readiness ties')
probe.define_singleton_method(:next_ap) { [0,100] }
check(tempo.calculate(actor,[probe,nil]).values.any? { |s| s==:possible },'uncertain retained AP is marked possible rather than guaranteed')
probe.define_singleton_method(:next_ap) { [0,0] }
enemies[0].add_state(stun.id);enemies[0].instance_variable_get(:@state_turns)[stun.id]=20
check(tempo.calculate(actor)[0]==:none,'a current stun lasting beyond next hero turn suppresses enemy star')
enemies[0].remove_state(stun.id)
BS2Suite::Options.set('knowledge_threshold',100)
check(tempo.calculate(actor).values.all? { |s| s==:unknown },'unknown enemy data gets question marks, not a false hero-next implication')
BS2Suite::Options.set('knowledge_threshold',0)
# Exercise real gauge anchoring, both star bitmap styles and disposal.
source_sprite=scene.instance_variable_get(:@spriteset).instance_variable_get(:@enemy_sprites).find { |s| s.battler.equal?(enemies[0]) }
gauge=Sprite_Enemy_Gauge.new(source_sprite,3)
gauge.update_rect(200,200,50);marker=gauge.instance_variable_get(:@bs20992_marker)
check(marker && marker.visible && marker.x==gauge.x+enemies[0].gauge_width(3)+3,'tempo star is anchored beside actual enemy AP gauge')
gauge.bs20992_draw_marker(:first);solid=marker.bitmap.get_pixel(7,7).red
gauge.bs20992_draw_marker(:before);hollow=marker.bitmap.get_pixel(7,7).red
check(solid>hollow,'first and following enemies have visually distinct filled and hollow stars')
gauge.bs20992_draw_marker(:unknown)
gauge.dispose;check(marker.disposed?,'gauge disposal also releases its marker')
BS2Suite::Options.set('tempo_hint',0);check(tempo.result(scene).empty?,'disabled optional hint produces no markers')
# Remapping frees only the conflicting letters, not the whole list at once.
nav=BS2Suite::NavigationAliases;item=scene.instance_variable_get(:@item_window);item.show.activate;item.openness=255
saved=BS2Suite::Keys.data.dup
BS2Suite::Keys.data[:X]='K';BS2Suite::Keys.data[:Y]='L'
tick;tick([65]);check(Input.press?(:LEFT),'remapping favorites frees A in native item list')
tick;tick([83]);check(Input.press?(:DOWN),'remapping filter frees S in native item list')
BS2Suite::Keys.data[:Z]='O';check(nav.set('RIGHT','D'),'D is configurable for navigation once its assignment is moved')
tick;tick([68]);check(Input.press?(:RIGHT) && !Input.trigger?(:Z),'custom WASD navigation works without triggering reassigned D action')
BS2Suite::Keys.instance_variable_set(:@data,saved);nav.set('RIGHT','Z');item.hide.deactivate;tick
actor.clear_states;actor.clear_buffs
