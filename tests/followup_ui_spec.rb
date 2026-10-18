# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
class FollowupUIKeys
 attr_accessor :keys
 def initialize;@keys=[];end
 def down;@keys;end
 def focused?;true;end
end
def press(code);@raw.keys=[];Graphics.update;Input.update;@raw.keys=[code];Graphics.update;Input.update;end
def capture(path);Graphics.transition(0);3.times { Graphics.update };SuiteCapture.save(path);end
begin
 File.open('test_result.txt','w') { |f| f.puts 'followup UI080' }
 DataManager.init;DataManager.setup_new_game
 SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
 actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false)
 @raw=FollowupUIKeys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
 item=Scene_Item.new;SceneManager.instance_variable_set(:@scene,item);item.start
 category=item.instance_variable_get(:@category_window)
 check(category.col_max>=category.item_max,'all item-category commands fit on one visible row')
 item.bs2080_soul_dialog
 menu=item.instance_variable_get(:@bs2080_soul_menu)
 check(menu.item_max==4 && menu.active,'soul dialog exposes ordinary, black, currency and cancel modes')
 capture('BS2QA_souls080.bmp')
 item.bs2080_confirm_souls(:black)
 confirm=item.instance_variable_get(:@bs2080_soul_confirm)
 check(confirm.index==1,'mass use confirmation defaults to cancel')
 confirm.process_cancel
 check(menu.active,'cancel confirmation returns to soul choices')
 item.bs2080_close_souls
 check(category.active && category.index==0,'closing souls restores the ordinary item category')
 item.terminate
 $game_party.gain_item($data_armors[82],1);actor.change_equip(4,$data_armors[82])
 BS2Modules::Loadouts.save(actor,1,'Сравнение');actor.change_equip(4,nil)
 sets=BS2Modules::LoadoutsScene.new;SceneManager.instance_variable_set(:@scene,sets);sets.start
 list=sets.instance_variable_get(:@list);list.openness=255;list.select(0);press(118)
 check(BS2QoL::Hotkeys.handle(list) && BS2QoL::Reference.active?(sets),'F7 opens selected loadout comparison from its actual screen')
 window=sets.instance_variable_get(:@bs2q_reference_window)
 check(window.card.sections[0].join.include?('→'),'loadout screen comparison includes changed calculated coefficients')
 window.scroll(9);capture('BS2QA_loadout080.bmp')
 BS2QoL::Reference.close(sets);sets.terminate
 BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
 actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
 BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
 scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
 commands=scene.instance_variable_get(:@actor_command_window)
 row=commands.instance_variable_get(:@list).find { |r| r[:symbol]==:bs2_enemy_info }
 check(row.nil?,'F4 shortcut remains available without an extra battle command row')
 target=scene.instance_variable_get(:@enemy_window);target.show.activate;target.openness=255;commands.deactivate;target.select(0);press(118)
 check(BS2QoL::Hotkeys.handle(target) && BS2QoL::Reference.active?(scene),'F7 directly opens a selected battle enemy')
 BS2QoL::Reference.close(scene);target.hide.deactivate;commands.activate
 BS2Suite::CombatEffects.open(scene,commands);capture('BS2QA_all_effects080.bmp');BS2Suite::CombatEffects.close(scene)
 scene.terminate;$game_party.on_battle_end
 log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
 log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
 SuiteCapture.close
end
end
