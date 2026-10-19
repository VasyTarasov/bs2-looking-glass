# encoding: UTF-8
module BS2QoL
  module Forecast
    def self.probability(value);[[value.to_f,0.0].max,1.0].min;end
    def self.integer_chance(value);probability(value.to_f.ceil/100.0);end
    class Snapshot
      attr_reader :source,:values,:states,:notes,:state_objects
      def initialize(source)
        @source=source;@values={}
        Expression::STATS.each do |key|
          next if ['hp_rate','mp_rate','pdr','mdr'].include?(key)
          @values[key]=source.respond_to?(key) ? source.send(key) : 0
        end
        # Avoid contextual pdr/mdr/guard? wrappers that belong to a running attack.
        @values['pdr']=source.sparam(6);@values['mdr']=source.sparam(7)
        @states=source.states.map { |state| state.id }
        @state_objects=source.states.dup
        @notes=source.feature_objects.map { |object| object.note.to_s.dup }
        @guard=source.special_flag(Game_BattlerBase::FLAG_ID_GUARD) && source.movable?
        ratios
      end
      def ratios
        @values['hp_rate']=@values['hp'].to_f/@values['mhp']
        @values['mp_rate']=@values['mmp']==0 ? 0.0 : @values['mp'].to_f/@values['mmp']
      end
      def after_cost(item)
        return self unless item.is_a?(RPG::Skill)
        @values['mp']=[@values['mp']-source.skill_mp_cost(item),0].max
        @values['tp']=[@values['tp']-source.skill_tp_cost(item),0].max
        @values['hp']=[@values['hp']-source.skill_hp_cost(item),0].max
        ratios;self
      end
      def guard?;@guard;end
      def element(id);source.features_pi(Game_BattlerBase::FEATURE_ELEMENT_RATE,id);end
      def state_rate(id);source.features_pi(Game_BattlerBase::FEATURE_STATE_RATE,id);end
      def debuff_rate(id);source.features_pi(Game_BattlerBase::FEATURE_DEBUFF_RATE,id);end
      def immune_state?(id);source.state_resist?(id);end
      def actor?;source.actor?;end
      def certain?(hit,type)
        words=hit ? CertaintyHit::Words1 : CertaintyHit::Words2
        [words[type],words[3]].any? { |word| @notes.any? { |note| note.include?('<'+word+'>') } }
      end
      def rate_sum(word)
        @notes.inject(0) { |sum,note| m=/<#{word}[:：](\S+)>/.match(note);sum+(m ? m[1].to_i : 0) }
      end
    end

    class Prediction
      attr_reader :item,:user,:target,:selected,:rows,:chance,:crit_chance,:counter,:reflection,:cancel,:element,:rate,:bypass,:repeats,:stable,:base,:error
      def initialize(user,target,item,paid=false)
        @item=item;@selected=target;@rows=[]
        @user=Snapshot.new(user)
        @user.after_cost(item) unless paid
        # Counter and reflection are tested on the selected target, before substitution.
        original=target==user ? @user : Snapshot.new(target)
        opposite=original.actor? != @user.actor?
        counterable=!item.note.include?('<反撃不可>') && (item.physical? || item.note.include?('<反撃可能>'))
        @counter=opposite && counterable ? Forecast.probability(original.values['cnt']) : 0.0
        @reflection=item.magical? && target!=user ? Forecast.probability(original.values['mrf']) : 0.0
        recipient=target
        if target.hp<target.mhp/4 && !item.certain?
          substitute=target.friends_unit.substitute_battler
          recipient=substitute if substitute && substitute!=target
        end
        @target=recipient==user ? @user : Snapshot.new(recipient)
        @cancel=cancellation
        @chance=(1.0-@counter)*(1.0-@reflection)*(1.0-@cancel)*hit_chance
        # Native eligibility test is read-only (no damage, speed or target roll).
        @chance=0 unless recipient.item_test(user,item)
        @crit_chance=!item.damage.none? && item.damage.critical ? Forecast.probability(@user.values['cri']*(1.0-@target.values['cev'])) : 0.0
        @element=element_rate
        @rate=damage_rate
        @bypass=guard_bypass
        @repeats=item.repeats
        @repeats*=1+user.atk_times_add.to_i if item.is_a?(RPG::Skill) && item.id==user.attack_skill_id && item.for_one? && item.for_opponent? && !item.for_random?
        @stable=stable_repeats?
        formula_damage unless item.damage.none?
        recovery_effects
      rescue Unsupported=>e
        @error=e.message
      rescue StandardError=>e
        @error='unverified calculation: '+e.class.to_s
      end
      def expression(source);Forecast.expression(source,@user,@target);end
      def hit_chance
        absolute_hit=item.note.include?('<絶対命中>') || @user.certain?(true,item.hit_type)
        absolute_evasion=!(item.for_friend? && !item.for_opponent? && @user.actor? == @target.actor?) && @target.certain?(false,item.hit_type)
        case CertaintyHit::Type
        when 0;return 1.0 if absolute_hit;return 0.0 if absolute_evasion
        when 1;return 0.0 if absolute_evasion;return 1.0 if absolute_hit
        when 2
          return 1.0 if absolute_hit && !absolute_evasion
          return 0.0 if absolute_evasion && !absolute_hit
        else;raise Unsupported,'unverified certainty priority'
        end
        hit=item.success_rate*0.01
        hit*=@user.values['hit'] if item.physical?
        evade=item.physical? ? @target.values['eva'] : (item.magical? ? @target.values['mev'] : 0)
        Forecast.probability(hit)*(1.0-Forecast.probability(evade))
      end
      def cancellation
        return 0.0 unless item.is_a?(RPG::Skill)
        value=@target.notes.inject(0) do |sum,note|
          # The native parser retains the LAST value for an ID within each object.
          matches=note.scan(/<スキル無効[:：](\S+)>/).map { |m| m[0].split(',') }.select { |a| a[0].to_i==item.id }
          sum+(matches.empty? ? 0 : expression(matches[-1][1] || '100'))
        end
        Forecast.integer_chance(value)
      end
      def element_rate
        id=item.damage.element_id
        return @target.element(id) if id>=0
        elements=@user.source.atk_elements
        elements.empty? ? 1.0 : ([0.0]+elements.map { |element| @target.element(element) }).max
      end
      def damage_rate
        return 1.0 if item.certain?
        value=@target.values[item.physical? ? 'pdr' : 'mdr']
        return value unless value<1.0
        penetration=@user.notes.inject(0) do |sum,note|
          match=/<ダメージ率貫通[:：]#{item.hit_type},(\S+)>/.match(note)
          sum+(match ? expression(match[1]) : 0)
        end
        match=/<ダメージ率貫通追加[:：](\S+)>/.match(item.note)
        penetration+=expression(match[1]) if match
        [[1.0-(1.0-value)*(100-penetration)/100,0.0].max,1.0].min
      end
      def guard_bypass
        return 0.0 unless @target.guard?
        sources=@user.notes.dup
        sources+=@user.source.skills.map { |skill| skill.note } if @user.actor? && V_GUARD::S_VAL
        value=sources.inject(0) { |sum,note| m=/<パッシブ防御状態無視率[:：](\S+)>/.match(note);sum+(m ? expression(m[1]) : 0) }
        match=/<防御状態無視率[:：](\S+)>/.match(item.note)
        value+=expression(match[1]) if match
        Forecast.integer_chance(value)
      end
      def recover_modes(resource)
        void=Forecast.integer_chance(@target.rate_sum(resource+'回復無効'))
        reverse=Forecast.integer_chance(@target.rate_sum(resource+'回復反転'))
        result=[];result<<:void if void>0;result<<:reverse if void<1 && reverse>0
        result<<:normal if void<1 && reverse<1;result
      end
      def formula_damage
        begin
          @base=expression(item.damage.formula)
          raise Unsupported,'formula did not return a number' unless @base.is_a?(Numeric)
          @base=[@base,0].max*(item.damage.recover? ? -1 : 1)
        rescue ZeroDivisionError
          # Native RPG::UsableItem::Damage#eval rescues arithmetic errors to zero.
          @base=0
        end
        resource=item.damage.to_hp? ? 'HP' : 'MP'
        normal=formula_range(false,resource)
        critical=item.damage.critical ? formula_range(true,resource) : normal
        @crit_chance=0.0 if normal[:raw]==[0,0] && critical[:raw]==[0,0]
        @rows<<{:resource=>resource,:normal=>normal,:critical=>critical,:formula=>true}
      end
      def formula_range(critical,resource)
        value=@base*@element
        value*=@rate unless item.certain?
        value*=@target.values['rec'] if item.damage.recover?
        value*=Hi_ru_Difficulty::DIFFICULTY_SETTING[11][$game_variables[Hi_ru_Difficulty::VARIABLES]] if critical
        amplitude=[value.abs*item.damage.variance/100,0].max.to_i
        values=[]
        [value-amplitude,value+amplitude].uniq.each do |endpoint|
          branches=[]
          if endpoint>0 && @target.guard?
            branches<<endpoint/(2*@target.values['grd']) if @bypass<1
            branches<<endpoint if @bypass>0
          else
            branches<<endpoint
          end
          branches.each do |raw|
            raw=raw.to_i
            raw=[@target.values['mp'],raw].min if resource=='MP'
            modes=raw<0 ? recover_modes(resource) : [:normal]
            modes.each do |mode|
              damage=mode==:void ? 0 : (mode==:reverse ? -raw : raw)
              damage=guts(damage) if resource=='HP'
              values<<damage
            end
          end
        end
        range(values,resource)
      end
      def guts(damage)
        return damage unless @target.states.include?(Nana::STATE_KONJO)
        hp=@target.values['hp'];mhp=@target.values['mhp']
        check=Nana::KONJO_DAMAGE_PER==1 ? damage/mhp*100 : damage
        retained=Nana::KONJO_HP_PER ? mhp*Nana::KONJO_HP/100 : Nana::KONJO_HP
        if check<=Nana::KONJO_DAMAGE && hp<=damage && !(Nana::KONJO_MODE && hp<=retained)
          hp-retained
        else;damage
        end
      end
      def range(values,resource)
        key=resource.downcase;current=@target.values[key];maximum=@target.values['m'+key]
        # Distinguish visible overkill numbers from HP/MP that can actually change.
        losses=values.map { |value| current-[[current-value,0].max,maximum].min }
        {:raw=>[values.min,values.max],:loss=>[losses.min,losses.max]}
      end
      def recovery_effects
        item.effects.each_with_index do |effect,index|
          next unless [11,12].include?(effect.code)
          resource=effect.code==11 ? 'HP' : 'MP';maximum=@target.values[resource=='HP' ? 'mhp' : 'mmp']
          amount=maximum*effect.value1+effect.value2
          modes=amount.to_i>0 ? recover_modes(resource) : [:normal]
          values=modes.map do |mode|
            value=mode==:void ? 0 : (mode==:reverse ? -amount.to_i : amount)
            value*=@target.values['rec'];value*=@user.values['pha'] if item.is_a?(RPG::Item)
            -value.to_i
          end
          # These are individual effect components, not a sum with formula damage.
          @rows<<{:resource=>resource,:normal=>range(values,resource),:critical=>range(values,resource),:formula=>false,
            :conditional=>index>0 || !item.damage.none?}
        end
      end
      def stable_repeats?
        return false if !item.certain? && @selected.friends_unit.members.any? { |member| member!=@selected && member.substitute? }
        return false if @target.states.include?(Nana::STATE_KONJO)
        return false if @target.state_objects.any? { |s| s.remove_by_damage && s.chance_by_damage>0 }
        return false if item.effects.any? { |e| [21,22,31,32,33,34,44].include?(e.code) }
        return false if item.damage.formula =~ /b\.(?:hp|mp)\b|state\?/
        return false if @target.source==@user.source && item.damage.formula =~ /a\.(?:hp|mp)\b/
        return false if item.damage.formula =~ /a\.(?:hp|mp)\b/ && (item.damage.drain? || (@user.notes+[item.note]).any? { |note| note =~ /変換攻撃/ })
        true
      end
      def state_chances
        rows=[]
        item.effects.select { |effect| effect.code==21 }.each do |effect|
          ids=effect.data_id==0 ? @user.source.atk_states : [effect.data_id]
          ids.each do |id|
            chance=effect.value1;ignored=item.note.include?('<強制付与>')
            chance*=@user.source.atk_states_rate(id) if effect.data_id==0
            if effect.data_id==0 || @user.actor? != @target.actor?
              chance*=@target.state_rate(id) unless ignored || item.note.include?('<有効度無視ステート付与>')
              chance*=[1.0+(@user.values['luk']-@target.values['luk'])*0.001,0.0].max unless ignored || item.note.include?('<運無視ステート付与>')
            end
            chance=0 if @target.immune_state?(id)
            rows<<[id,Forecast.probability(chance)]
          end
        end
        rows
      end
      def mutable_hp_cap?
        @target.state_objects.any? { |s| s.remove_by_damage && s.chance_by_damage>0 && s.features.any? { |f| f.code==21 && [0,1].include?(f.data_id) } }
      end
    end
  end
end
