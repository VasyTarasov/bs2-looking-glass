# encoding: UTF-8
module BS2Suite
  # A read-only equipment projection. No change_equip, refresh, event, damage
  # application, action generation, random roll or global inventory mutation.
  module Projection
    def self.copy(battler)
      view=battler.dup
      battler.instance_variables.each do |key|
        value=battler.instance_variable_get(key)
        view.instance_variable_set(key,value.dup) if value.is_a?(Array) || value.is_a?(Hash)
      end
      view.instance_variable_set(:@bs2s_projection,true)
      view.instance_variable_set(:@bs2s_origin_actor,battler.instance_variable_get(:@bs2s_origin_actor) || battler) if battler.actor?
      # Native cool_time uses an inserting Hash default. Projections must never
      # register themselves in Game_Temp, including during usable? checks.
      local=battler.instance_variable_get(:@bs2s_cooldowns)
      unless local
        table=$game_temp && $game_temp.instance_variable_get(:@cool_time)
        local=table && table.has_key?(battler) ? table[battler] : {}
      end
      view.instance_variable_set(:@bs2s_cooldowns,Hash.new(0).merge(local))
      view
    end
    def self.weapon(actor,weapon)
      view=copy(actor)
      equips=actor.instance_variable_get(:@equips).map { |entry| entry.dup }
      equips[0].object=weapon
      view.instance_variable_set(:@equips,equips)
      # Native equip refresh removes resisted states and clamps resources.
      resisted=view.state_resist_set
      states=view.instance_variable_get(:@states).dup
      view.instance_variable_set(:@states,states.reject { |id| resisted.include?(id) })
      view.instance_variable_set(:@state_turns,view.instance_variable_get(:@state_turns).reject { |id,n| resisted.include?(id) })
      view.instance_variable_set(:@hp,[[actor.hp,0].max,view.mhp].min)
      view.instance_variable_set(:@mp,[[actor.mp,0].max,view.mmp].min)
      view
    end
  end
  module DirectWeapons
    class << self
      def selected_id(actor);actor && actor.instance_variable_get(:@bs2s_direct_weapon_id);end
      def resolve(actor,id)
        return nil unless actor && id
        root=WeaponFamilies.root(id)
        Semantic.owned(actor).select { |w| WeaponFamilies.root(w.id)==root }.sort_by { |w| [-WeaponFamilies.depth(w.id),w.id] }.first
      end
      def selected(actor);resolve(actor,selected_id(actor));end
      def select(actor,weapon)
        return false unless actor && weapon && Semantic.owned(actor).include?(weapon)
        actor.instance_variable_set(:@bs2s_direct_weapon_id,weapon.id)
        true
      end
      def clear(actor)
        return unless actor
        actor.instance_variable_set(:@bs2s_direct_weapon_id,nil)
        actor.instance_variable_set(:@bs2s_direct_final,nil)
      end
      def default_behavior(group);[2,3].include?(group) ? 'last' : 'now';end
      def behavior(actor,group)
        profile=Semantic.customs[Semantic.mode(actor)]
        # Version-1 custom N3+ meant last action. Preserve it until explicitly edited.
        return (profile['behaviors'] || {})['N'+group.to_s] || (group==1 ? 'now' : 'last') if profile
        layout=layout(actor)
        record=layout['groups'].find { |g| g['number']==group }
        record ? record['behavior'] : default_behavior(group)
      end
      def label(value);value=='last' ? 'Последнее действие' : 'Сменить сейчас';end
      def layout(actor)
        key=Semantic.layout_key(actor,'N');value=Semantic.state['layouts'][key]
        sync(actor) unless value && value['schema']==4
        Semantic.state['layouts'][key]
      end
      def stable(previous,ids)
        old=previous || [];(old.select { |id| ids.include?(id) }+ids.reject { |id| old.include?(id) }).uniq
      end
      def sync(actor,force=false)
        return unless actor
        return if Semantic.customs[Semantic.mode(actor)]
        key=Semantic.layout_key(actor,'N');previous=Semantic.state['layouts'][key]
        return previous if $game_party.in_battle && previous && previous['schema']==4 && !force
        owned=Semantic.owned(actor).map { |w| WeaponFamilies.root(w.id) }.uniq
        has=lambda { |id| owned.include?(id) }
        core=ArsenalCatalog::MAIN.select { |id| has.call(id) }
        early=ArsenalCatalog::EARLY.select { |id| has.call(id) }
        early.reject! { |id| ArsenalCatalog::REPLACED[id].any? { |other| has.call(other) } } if Semantic.mode(actor)=='advanced'
        main=(core+early).uniq.take(10)
        old_groups=previous && previous['groups'].is_a?(Array) ? previous['groups'] : []
        old_main=old_groups.find { |g| g['number']==1 }
        initial=(ArsenalCatalog::EARLY+ArsenalCatalog::MAIN).select { |id| main.include?(id) }
        main=stable(old_main && old_main['ids'],initial)
        final=[];notes={};chosen_notes={};roles=[]
        ArsenalCatalog::FINAL.each do |candidates,note|
          candidates.each { |id| notes[id]=[notes[id],note].compact.join(' / ') }
          available=candidates.select { |candidate| has.call(candidate) }
          metric=if candidates.include?(277);:agi
          elsif candidates.include?(123);:atk
          elsif candidates.include?(391);:mat
          elsif candidates.include?(427);:mrg
          end
          id=metric ? available.sort_by { |candidate| [-Projection.weapon(actor,resolve(actor,candidate)).send(metric),candidates.index(candidate)] }.first : available.first
          next unless id
          chosen_notes[id]=[chosen_notes[id],note].compact.join(' / ')
          roles<<{'weapon'=>id,'metric'=>metric && metric.to_s,'label'=>note}
          final<<id unless final.include?(id)
        end
        old_final=old_groups.find { |g| g['number']==2 }
        final=stable(old_final && old_final['ids'],final)
        expanded=ArsenalCatalog::EXPANDED.select { |id| has.call(id) && !final.include?(id) }.uniq.take(10)
        old_expanded=old_groups.find { |g| g['category']=='expanded' }
        expanded=stable(old_expanded && old_expanded['ids'],expanded)
        groups=[{'number'=>1,'name'=>'Рекомендуемый арсенал','behavior'=>'now','ids'=>main,'category'=>'main'},
          {'number'=>2,'name'=>'Основные роли исполнения','behavior'=>'last','ids'=>final,'category'=>'final'},
          {'number'=>3,'name'=>'Дополнительное исполнение','behavior'=>'last','ids'=>expanded,'category'=>'expanded'}]
        if owned.size<=10
          groups<<{'number'=>4,'name'=>'Весь арсенал','behavior'=>'now','ids'=>owned.sort,'category'=>'compact'} unless owned.empty?
        else
          remaining=owned.dup;manual=[]
          ArsenalCatalog::EXTRA.each do |category,name,ids|
            values=ids & remaining;next if values.empty?
            values=values.take(10);remaining-=values
            manual<<{'name'=>name,'behavior'=>'now','ids'=>values,'category'=>category}
          end
          # Merge compatible sparse categories before splitting the remainder into real tens.
          # No family is silently lost just because the last category reached ten entries.
          [['physical','survival','Сила и защита'],['magic','special','Магия и особые механики']].each do |left,right,name|
            break if manual.size+(remaining.size+9)/10<=7
            a=manual.find { |g| g['category']==left };b=manual.find { |g| g['category']==right }
            next unless a && b && a['ids'].size+b['ids'].size<=10
            a['ids']+=b['ids'];a['category']=left+'_'+right;a['name']=name;manual.delete(b)
          end
          remaining.sort.each_slice(10).with_index do |values,index|
            manual<<{'name'=>'Остальной арсенал'+(remaining.size>10 ? ' · '+(index+1).to_s : ''),'behavior'=>'now','ids'=>values,'category'=>'other'+index.to_s}
          end
          manual.take(7).each do |record|
            old=old_groups.find { |g| g['category']==record['category'] }
            record['ids']=stable(old && old['ids'],record['ids']);record['number']=groups.size+1;groups<<record
          end
        end
        groups.each { |g| g['keys']=g['ids'].map { |id| g['behavior']+':'+id.to_s } }
        signature=groups.map { |g| [g['name'],g['behavior'],g['ids']] }
        changed=previous && previous['signature']!=signature
        legacy=Semantic.state['layouts'].has_key?(actor.id.to_s+':N') && !previous
        moves=changed || legacy ? ['N1 сейчас · N2/N3 последнее · Q/E и ←/→ соседняя группа'] : []
        if changed
          old_groups.each do |old|
            old['ids'].each_with_index do |id,index|
              target=groups.find { |g| g['category']==old['category'] && g['ids'].include?(id) } || groups.find { |g| g['ids'].include?(id) }
              next unless target
              before=address(old['number'],index);after=address(target['number'],target['ids'].index(id))
              moves<<before+' → '+after+' · '+$data_weapons[id].name unless before==after && old['behavior']==target['behavior']
            end
          end
        end
        moves=previous['moves'] || [] if previous && !changed
        value={'schema'=>4,'groups'=>groups,'signature'=>signature,'moves'=>moves.take(8),'notes'=>notes,'chosen_notes'=>chosen_notes,'roles'=>roles}
        Semantic.state['layouts'][key]=value
      end
      def address(group,index)
        'N'+Semantic::DIGITS[group-1,1]+Semantic::DIGITS[index%10,1]+(index>=10 ? ' (стр. '+(index/10+1).to_s+')' : '')
      end
      def shelf(actor)
        profile=Semantic.customs[Semantic.mode(actor)]
        return profile['entries'].select { |e| e['prefix']=='N' } if profile
        value=layout(actor);rows=[]
        value['groups'].each do |g|
          g['ids'].each_with_index do |id,i|
            rows<<{'prefix'=>'N','group'=>g['number'],'digit'=>Semantic::DIGITS[i%10,1].to_i,
              'kind'=>'weapon','id'=>id,'source'=>0,'behavior'=>g['behavior'],'page'=>i/10,
              'hint'=>g['behavior']=='last' ? [(g['number']==2 ? value['chosen_notes'][id] : value['notes'][id]),ArsenalCatalog::NOTES[id]].compact.uniq.join(' · ') : ArsenalCatalog::NOTES[id]}
          end
        end
        rows
      end
      def groups(actor)
        profile=Semantic.customs[Semantic.mode(actor)]
        if profile
          numbers=(profile['entries'].select { |e| e['prefix']=='N' }.map { |e| e['group'] }+
            profile['groups'].keys.select { |k| k[0,1]=='N' }.map { |k| k[1,k.size].to_i }+[1,2]).uniq.sort
          return numbers.map { |n| {:number=>n,:name=>(profile['groups']['N'+n.to_s] || 'Моя группа')+' · '+label(behavior(actor,n))} }
        end
        layout(actor)['groups'].map { |g| {:number=>g['number'],:name=>g['name']+' · '+label(g['behavior'])} }
      end
      def rows(actor,group,page=0)
        shelf(actor).select { |e| e['group']==group && (e['page'] || 0)==page }.map do |e|
          weapon=resolve(actor,e['id'])
          {:prefix=>'N',:group=>group,:digit=>e['digit'],:kind=>:weapon,:id=>weapon ? weapon.id : e['id'],
           :object=>weapon || $data_weapons[e['id']],:source=>nil,:present=>!!weapon,:behavior=>behavior(actor,group),
           :hint=>e['hint'],:page=>page,:address=>'N'+Semantic::DIGITS[(group-1)%10,1]+e['digit'].to_s+(page>0 ? ' (стр. '+(page+1).to_s+')' : '')}
        end
      end
      def pages(actor,group)
        values=shelf(actor).select { |e| e['group']==group }
        [(values.map { |e| e['page'] || 0 }.max || 0)+1,1].max
      end
      def final_entries(actor);shelf(actor).select { |row| behavior(actor,row['group'])=='last' };end
      def arm(actor)
        return unless actor && actor.actor?
        last=actor.actions.reverse.find { |action| action && action.item }
        actor.instance_variable_set(:@bs2s_direct_final,last)
        last.instance_variable_set(:@bs2s_direct_count,actor.actions.size) if last
      end
      def quick?
        defined?(HZM_VXA::QuickSkill) && HZM_VXA::QuickSkill.quickSkill?
      end
      def before_action(action)
        actor=action.subject
        return unless actor && actor.actor? && !action.forcing && !quick? && !actor.confusion? && actor.movable?
        return unless actor.instance_variable_get(:@bs2s_direct_final).equal?(action)
        return unless actor.actions.last.equal?(action) && actor.current_action.equal?(action)
        return if action.instance_variable_get(:@bs2s_direct_applied)
        return if sole_source(actor,action.item,0,action)
        action.instance_variable_set(:@bs2s_direct_applied,true)
        return unless selected_id(actor)
        weapon=selected(actor)
        unless weapon
          BS2QoL::Hotkeys.notice('N: оружие недоступно; остаётся текущее')
          return
        end
        return if actor.equips[0]==weapon
        projected=Projection.weapon(actor,weapon)
        unless projected.usable?(action.item) && BS2QoL::Model.change_weapon(actor,weapon)
          BS2QoL::Hotkeys.notice('N: смена недоступна; действие по штатным правилам')
          return
        end
        # Deliberately keep the action's selected ID, targets and repeats.
        # Live equipment contributes stats/passives; no set_attack/set_skill here.
        BS2QoL::Hotkeys.notice('Последнее действие: '+weapon.name)
        scene=SceneManager.scene
        scene.refresh_status if scene.is_a?(Scene_Battle)
      end
    end
  end
end

class Game_Action
  alias bs2s_capture_attack set_attack
  def set_attack
    result=bs2s_capture_attack
    @bs2s_normal_attack=true
    @bs2s_normal_source=subject.actor? && subject.equips[0] ? subject.equips[0].id : nil
    result
  end
  alias bs2s_capture_skill set_skill
  def set_skill(id)
    @bs2s_normal_attack=false;@bs2s_normal_source=nil
    bs2s_capture_skill(id)
  end
  alias bs2s_capture_item set_item
  def set_item(id)
    @bs2s_normal_attack=false;@bs2s_normal_source=nil
    bs2s_capture_item(id)
  end
  alias bs2s_direct_prepare prepare
  def prepare
    bs2s_direct_prepare
    BS2Suite::DirectWeapons.before_action(self) unless subject.instance_variable_get(:@bs2s_projection)
  end
end
class Scene_Battle
  def bs2v2_cast(binding,context)
    actor=BattleManager.actor;skill=BS2QoL::Bindings.object(binding)
    weapon=actor && skill ? BS2Suite::Semantic.source_for(actor,skill.id,binding[2].to_i) : nil
    unless context==:commands && actor && actor.input && skill && weapon && !actor.skill_seal.include?(skill.id)
      BS2QoL::Hotkeys.notice('Нет доступного источника или слота действия');Sound.play_buzzer;return true
    end
    view=weapon.is_a?(RPG::Weapon) && weapon!=actor.equips[0] ? BS2Suite::Projection.weapon(actor,weapon) : actor
    unless view.skills.include?(skill) && view.usable?(skill)
      BS2QoL::Hotkeys.notice('Техника недоступна: цена, КД или ограничение');Sound.play_buzzer;return true
    end
    unless weapon.is_a?(RPG::Armor) || weapon==actor.equips[0] || BS2QoL::Model.change_weapon(actor,weapon)
      BS2QoL::Hotkeys.notice('Смена источника сейчас запрещена');Sound.play_buzzer;return true
    end
    @actor_command_window.refresh;refresh_status
    BS2QoL::Hotkeys.notice(weapon.name+' → '+skill.name)
    bs2q_apply_binding([:skill,skill.id],context)
  end
  alias bs2s_direct_turn_start turn_start
  def turn_start
    actor=BattleManager.actor
    actor=BattleManager.input_battler if !actor && BattleManager.respond_to?(:input_battler)
    BS2Suite::DirectWeapons.arm(actor) if actor && actor.actor?
    bs2s_direct_turn_start
  end
end
class Game_Battler
  alias bs2s_live_cool_time cool_time
  def cool_time
    return @bs2s_cooldowns if @bs2s_projection
    bs2s_live_cool_time
  end
  alias bs2s_direct_battle_end on_battle_end
  def on_battle_end
    BS2Suite::DirectWeapons.clear(self) if actor?
    bs2s_direct_battle_end
  end
end

module BS2Suite::Semantic
  class << self
    alias bs2082_sync sync
    def sync(actor)
      result=bs2082_sync(actor)
      BS2Suite::DirectWeapons.sync(actor) unless $game_party.in_battle
      result
    end
  end
end
module BattleManager
  class << self
    alias bs2082_arsenal_setup setup
    def setup(*args)
      $game_party.members.each { |actor| BS2Suite::DirectWeapons.sync(actor,true) }
      bs2082_arsenal_setup(*args)
    end
  end
end
