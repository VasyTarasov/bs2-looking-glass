# encoding: UTF-8
module BS2Suite
  module Arsenal093
    # Editorially selected EQUIPPED uses. Technique-only sources stay available in V/customs.
    CATEGORIES=[
      ['Серии и особые атаки',[361,277,112,463,415,469,421,373,355,233]],
      ['Сила, крит и точность',[123,433,299,266,145,178,156]],
      ['Магия, мана и очередь',[167,391,427,397,439,475,379]],
      ['Защита и восстановление',[101,200,367,134,457]],
      ['Стихии и особые условия',[222,189,385,311,409,445,451,476]]
    ].freeze
    TREE=['root','Рекомендуемый арсенал',
      ['offense','Атаки, сила и особые условия',0,['physical','Сила и особые условия',1,4]],
      ['utility','Магия и поддержка',2,3]]
    def self.partition(owned,opened,node=TREE)
      if node.is_a?(Integer)
        title,ids=CATEGORIES[node];return ids.any? { |id| owned.include?(id) } ? [{'category'=>'c'+node.to_s,'name'=>title,'ids'=>ids & owned}] : []
      end
      key,title,left,right=node
      parts=partition(owned,{},left)+partition(owned,{},right)
      ids=parts.map { |g| g['ids'] }.flatten
      return [] if ids.empty?
      if ids.size<=10 && !opened[key]
        return [{'category'=>key,'name'=>title,'ids'=>ids}]
      end
      opened[key]=true
      partition(owned,opened,left)+partition(owned,opened,right)
    end
  end
  module DirectWeapons
    class << self
      def default_behavior(group);'now';end
      def behavior(actor,group);'now';end
      def layout(actor)
        key=Semantic.layout_key(actor,'N');value=Semantic.state['layouts'][key]
        sync(actor) unless value && value['schema']==5
        Semantic.state['layouts'][key]
      end
      def sync(actor,force=false)
        return unless actor
        return if Semantic.customs[Semantic.mode(actor)]
        key=Semantic.layout_key(actor,'N');previous=Semantic.state['layouts'][key]
        return previous if $game_party.in_battle && previous && previous['schema']==5 && !force
        owned=Semantic.owned(actor).map { |w| WeaponFamilies.root(w.id) }.uniq
        opened=previous && previous['schema']==5 ? (previous['opened'] || {}).dup : {}
        records=Arsenal093.partition(owned,opened)
        old=previous ? previous['groups'] : []
        records.each_with_index do |record,i|
          before=old.find { |g| g['category']==record['category'] }
          record['ids']=stable(before && before['ids'],record['ids'])
          record['number']=i+1;record['behavior']='now'
          record['keys']=record['ids'].map { |id| 'now:'+id.to_s }
        end
        signature=records.map { |g| [g['name'],g['ids']] }
        changed=previous && (previous['schema']!=5 || previous['signature']!=signature)
        moves=changed ? ['N: цифра надеть сейчас · D назначить последним · N N снять'] : previous ? (previous['moves'] || []) : []
        if changed
          positions={}
          records.each { |g| g['ids'].each_with_index { |id,i| positions[id]='N'+Semantic::DIGITS[g['number']-1,1]+Semantic::DIGITS[i,1] } }
          seen=[]
          old.each do |g|
            g['ids'].each_with_index do |id,i|
              next if seen.include?(id);seen<<id
              from='N'+Semantic::DIGITS[(g['number']-1)%10,1]+Semantic::DIGITS[i%10,1]
              to=positions[id]
              moves<<from+' → '+to+' '+$data_weapons[id].name if to && to!=from && moves.size<17
            end
          end
        end
        Semantic.state['layouts'][key]={'schema'=>5,'groups'=>records,'opened'=>opened,'signature'=>signature,'moves'=>moves,'roles'=>[]}
      end
      # Every recommended/custom row can now be nominated independently of its group.
      def final_entries(actor);shelf(actor);end
    end
  end
  module Palette
    class << self
      alias bs2093_palette_header update_header
      def update_header(scene)
        bs2093_palette_header(scene)
        popup=current(scene);return unless popup && !popup.assignment && popup.transition.empty?
        key=Keys.token(:Z)
        hint=if popup.prefix=='N'
          popup.group ? 'Цифра надеть · '+key+' последнее · N N снять · Q/E группы · F7' : 'Оружейные группы · N N снять исполнителя · Esc выйти'
        else
          popup.group ? 'Цифра применить · буква назад · F7'+(((popup.prefix=='B' && BS2Suite::BattleSupport.eligible?(popup.item)) || (popup.prefix=='V' && BS2Suite::BattleSupport.gunbreak?(popup.item))) ? ' · '+key+' авто строки' : '') : 'Цифра открыть · Esc выйти'
        end
        scene.instance_variable_get(:@bs2s_palette_header).text=[popup.banner,hint]
      end
    end
  end
end
