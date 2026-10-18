# encoding: UTF-8
module BS2Suite
  # Bounded, read-only readiness worlds. No AI, damage application, game
  # callbacks or random draws. Pending stun/interrupt effects are excluded.
  module TempoHint
    INF=1.0/0.0
    class Unsupported < StandardError;end
    def self.copy(unit)
      return Projection.copy(unit) if defined?(Projection)
      view=unit.dup
      unit.instance_variables.each do |key|
        value=unit.instance_variable_get(key)
        view.instance_variable_set(key,value.dup) if value.is_a?(Array) || value.is_a?(Hash)
      end
      view.instance_variable_set(:@bs2s_projection,true);view
    end
    def self.erase(unit,id)
      unit.instance_variable_get(:@states).delete(id)
      [:@state_turns,:@state_frames].each { |key| unit.instance_variable_get(key).delete(id) }
    end
    def self.expire(unit,timing)
      unit.states.dup.each do |state|
        next unless state.auto_removal_timing==timing
        turns=unit.instance_variable_get(:@state_turns)
        turns[state.id]-=1 if turns[state.id].to_i>0
        erase(unit,state.id) if turns[state.id].to_i<=0
      end
      return unless ATB::BUFF_TURN_COUNT==timing
      unit.instance_variable_get(:@buffs).each_index do |id|
        turns=unit.instance_variable_get(:@buff_turns)
        turns[id]-=1 if turns[id].to_i>0
        unit.instance_variable_get(:@buffs)[id]=0 if turns[id].to_i<=0
      end
    end
    def self.before(unit)
      unit.states.dup.each do |s|
        erase(unit,s.id) if [1,2].include?(s.auto_removal_timing) && unit.instance_variable_get(:@state_turns)[s.id]==1 && s.note.include?('<次の行動前に解除>')
      end
    end
    def self.frame_advance(unit,n)
      unit.states.dup.each do |s|
        next unless s.auto_removal_timing==3
        frames=unit.instance_variable_get(:@state_frames);turns=unit.instance_variable_get(:@state_turns)
        frames[s.id]=(frames[s.id] || s.turn_frame)-n*ATB::REFRESH_FRAME
        if frames[s.id]<=0 && turns[s.id].to_i>0
          # Native frame regeneration may kill a unit or trigger an event. It
          # cannot be replaced by a speed-only promise about its next turn.
          raise Unsupported if s.frame_regenerate
          turns[s.id]-=1 if s.auto_remove?
          frames[s.id]+=s.turn_frame
          erase(unit,s.id) if turns[s.id]<=0 && s.auto_remove?
        end
      end
    end
    # AP grows before frame timers. A disabled owner spends empty native turns;
    # it may recover before the hero, so a present stun alone cannot hide a star.
    def self.readiness(unit,ap=nil)
      view=copy(unit);view.ap=ap unless ap.nil?
      limit=view.chanting? ? view.instance_variable_get(:@max_chant_count) : ATB::MAX_AP
      current=view.chanting? ? view.instance_variable_get(:@chant_count) : view.ap
      current=limit if current==limit-1
      elapsed=0
      128.times do
        if current>=limit
          before(view) unless view.chanting?
          return [elapsed,!!view.chanting?] if view.movable?
          raise Unsupported if view.states.any? { |s| s.restriction>=4 && s.auto_removal_timing==2 }
          expire(view,1);current=0;limit=ATB::MAX_AP
          raise Unsupported if view.chanting?
          return [INF,false] if !view.movable? && view.states.any? { |s| s.restriction>=4 && s.auto_removal_timing==0 }
        end
        gain=view.ap_gain_point*ATB::REFRESH_FRAME
        wait=gain>0 ? [((limit-current)/gain.to_f).ceil,1].max : INF
        expiry=view.states.select { |s| s.auto_removal_timing==3 && view.instance_variable_get(:@state_turns)[s.id].to_i>0 }.map do |s|
          [((view.instance_variable_get(:@state_frames)[s.id] || s.turn_frame).to_f/ATB::REFRESH_FRAME).ceil,1].max
        end.min || INF
        n=[wait,expiry].min;return [INF,false] if n==INF
        current+=gain*n;elapsed+=n;frame_advance(view,n)
      end
      raise Unsupported
    end
    def self.ticks(unit,ap=nil);readiness(unit,ap)[0];end
    def self.control?(s);s.restriction>0 || s.chant_cancel || s.ap_control || s.chant_control;end
    def self.relevant?(s)
      s.features.any? { |f| (f.code==21 && f.data_id==6) || f.code==43 || f.code==54 } || !!(s.note =~ /フレーム速度|ＡＰ敏捷|詠唱敏捷|詠唱ステート/)
    end
    def self.clone_world(w)
      {:user=>copy(w[:user]),:targets=>Hash[w[:targets].map { |k,v| [k,copy(v)] }],:last=>w[:last]}
    end
    def self.unit(w,id);id==:self ? w[:user] : w[:targets][id];end
    def self.fork(worlds,chance)
      result=[]
      worlds.each do |w|
        p=[[chance.call(w).to_f,0].max,1].min;result<<w if p<1
        if p>0;value=clone_world(w);yield value;result<<value;end
      end
      raise Unsupported if result.size>32
      result
    end
    def self.state_chance(user,target,item,effect,id)
      return 0 if target.state_resist?(id) || target.state_restrict?(id)
      ignored=item.note.include?('<強制付与>');p=effect.value1
      p*=user.atk_states_rate(id) if effect.data_id==0
      if effect.data_id==0 || user.actor?!=target.actor?
        p*=target.state_rate(id) unless ignored || item.note.include?('<有効度無視ステート付与>')
        p*=target.luk_effect_rate(user) unless ignored || item.note.include?('<運無視ステート付与>')
      end
      p
    end
    def self.effects(worlds,id,item)
      raise Unsupported if item.effects.any? { |e| e.code==44 }
      return worlds if item.effects.none? do |e|
        if [31,32,33,34].include?(e.code);e.data_id==6
        elsif [21,22].include?(e.code)
          ids=e.data_id==0 ? worlds[0][:user].atk_states : [e.data_id]
          ids.any? do |sid|
            s=$data_states[sid];s && !(e.code==21 && control?(s)) && (relevant?(s) || (e.code==22 && s.restriction>=4))
          end
        else;false;end
      end
      hit=[];miss=[]
      worlds.each do |w|
        t=unit(w,id);u=w[:user]
        raise Unsupported if id!=:self && (t.item_cnt(u,item)>0 || t.item_mrf(u,item)>0)
        p=[[t.item_hit(u,item),0].max,1].min*(1-[[t.item_eva(u,item),0].max,1].min)
        miss<<w if p<1;hit<<clone_world(w) if p>0
      end
      item.effects.each do |e|
        case e.code
        when 21,22
          ids=e.data_id==0 ? worlds[0][:user].atk_states : [e.data_id]
          ids.each do |sid|
            s=$data_states[sid];next unless s
            next if e.code==21 && control?(s)
            next unless relevant?(s) || (e.code==22 && s.restriction>=4)
            hit=fork(hit,lambda { |w| e.code==22 ? e.value1 : state_chance(w[:user],unit(w,id),item,e,sid) }) do |w|
              t=unit(w,id)
              if e.code==22;erase(t,sid)
              else
                t.instance_variable_get(:@states)<<sid unless t.state?(sid)
                t.instance_variable_get(:@state_turns)[sid]=s.min_turns
                t.instance_variable_get(:@state_frames)[sid]=s.turn_frame
              end
            end
            if e.code==21 && s.max_turns!=s.min_turns
              hit=fork(hit,lambda { |w| 0.5 }) { |w| unit(w,id).instance_variable_get(:@state_turns)[sid]=s.max_turns if unit(w,id).state?(sid) }
            end
          end
        when 31,32,33,34
          next unless e.data_id==6
          hit=fork(hit,lambda do |w|
            t=unit(w,id);ignored=item.note.include?('<強制付与>')
            e.code!=32 ? 1.0 : (ignored || item.note.include?('<有効度無視弱体付与>') ? 1.0 : t.debuff_rate(6))*(ignored || item.note.include?('<運無視弱体付与>') ? 1.0 : t.luk_effect_rate(w[:user]))
          end) do |w|
            t=unit(w,id);buffs=t.instance_variable_get(:@buffs);turns=t.instance_variable_get(:@buff_turns)
            case e.code
            when 31;buffs[6]=[buffs[6]+1,2].min;turns[6]=[turns[6],e.value1].max
            when 32;buffs[6]=[buffs[6]-1,-2].max;turns[6]=[turns[6],e.value1].max
            when 33;buffs[6]=0 if buffs[6]>0
            when 34;buffs[6]=0 if buffs[6]<0
            end
          end
        when 44;raise Unsupported
        end
      end
      raise Unsupported if hit.size+miss.size>32
      hit+miss
    end
    def self.hover(scene,actor)
      ref=scene.instance_variable_get(:@bs2q_reference_window)
      if ref
        owner=ref.instance_variable_get(:@actor);object=ref.instance_variable_get(:@object)
        valid=object.is_a?(RPG::UsableItem) || object.is_a?(RPG::Weapon)
        return valid && owner && owner.actor? && owner.id==actor.id ? [object,owner.equips[0]] : nil
      end
      popup=scene.instance_variable_get(:@bs2s_palette)
      if popup && !popup.assignment && popup.group && popup.transition.empty?
        row=popup.entry;return row && [row[:object],row[:source]]
      end
      [:@item_window,:@skill_window].each do |key|
        w=scene.instance_variable_get(key);return [w.item,nil] if w && w.active && w.open?
      end
      nil
    end
    def self.plan(actor,candidate=nil,target=nil)
      view=copy(actor);actions=actor.actions.map { |a| a.dup };i=actor.instance_variable_get(:@action_input_index).to_i
      if candidate && candidate[0].is_a?(RPG::Weapon)
        view=Projection.weapon(view,candidate[0]) if defined?(Projection)
      elsif candidate && candidate[0].is_a?(RPG::UsableItem) && actions[i]
        item,source=candidate
        view=Projection.weapon(view,source) if defined?(Projection) && source.is_a?(RPG::Weapon)
        a=Game_Action.new(actor);item.is_a?(RPG::Item) ? a.set_item(item.id) : a.set_skill(item.id)
        DirectWeapons.copy_action_context(actions[i],a,item) if defined?(DirectWeapons)
        a.target_index=target.nil? ? -1 : target;actions[i]=a
      end
      actions[i].target_index=target if !target.nil? && actions[i] && actions[i].item
      view.instance_variable_set(:@actions,actions);[view,actions]
    end
    def self.calculate(actor,candidate=nil,target=nil)
      enemies=$game_troop.alive_members.reject { |e| e.hidden? };unknown=Hash[enemies.map { |e| [e.index,:unknown] }]
      return unknown unless defined?(Knowledge) && enemies.all? { |e| Knowledge.allowed?(e) }
      view,actions=plan(actor,candidate,target)
      stock=Hash[$game_party.items.map { |item| [item.id,$game_party.item_number(item)] }]
      gold=$game_party.gold
      worlds=[{:user=>view,:targets=>Hash[enemies.map { |e| [e.index,copy(e)] }],:last=>nil}]
      actions.each_with_index do |a,i|
        item=a.item;next unless item
        raise Unsupported if a.forcing || item.chant || item.note =~ /使用後追加行動|行動後遅延発動|ステート変化|変換攻撃|付与時/
        consumed=item.is_a?(RPG::Item) && item.consumable ? item : item.is_a?(RPG::Skill) && item.item_cost>0 ? $data_items[item.item_cost] : nil
        if consumed
          raise Unsupported if stock.fetch(consumed.id,0)<=0
          stock[consumed.id]-=1
        end
        if item.is_a?(RPG::Skill)
          fee=item.gold_cost+(item.gold_cost_rate>0 ? [gold*item.gold_cost_rate/100,1].max : 0)
          raise Unsupported if gold<fee
          gold-=fee
        end
        worlds.each do |w|
          user=w[:user]
          if defined?(DirectWeapons)
            weapon=DirectWeapons.sole_source(view,item,i,a)
            weapon=DirectWeapons.eligible_final(user,item,DirectWeapons.selected(actor),i,a) || weapon if i==actions.size-1
            user=Projection.weapon(user,weapon) if weapon
          end
          raise Unsupported unless user.usable?(item)
          if item.is_a?(RPG::Skill)
            hp=user.skill_hp_cost(item);mp=user.skill_mp_cost(item);tp=user.skill_tp_cost(item)
            user.instance_variable_set(:@mp,user.mp-mp);user.instance_variable_set(:@tp,user.tp-tp);user.instance_variable_set(:@hp,user.hp-hp)
            user.cool_time[item.id]=item.cool_time if item.cool_time
          end
          w[:user]=user;w[:last]=item.next_ap unless defined?(BattleSupport) && BattleSupport.quick?(item)
        end
        ids=if item.for_user?;[:self]
        elsif item.for_opponent?;item.for_all? ? enemies.map { |e| e.index } : [a.target_index]
        elsif item.for_friend?;item.for_all? || a.target_index==actor.index || $game_party.alive_members.size==1 ? [:self] : []
        else;[];end
        if item.for_random?
          raise Unsupported if item.effects.any? { |e| [21,22,31,32,33,34].include?(e.code) }
          ids=[]
        end
        if item.damage.to_hp? && !item.damage.recover? && worlds.any? { |w| w[:targets].values.any? { |t| t.states.any? { |s| (s.restriction>=4 || relevant?(s)) && s.remove_by_damage && s.chance_by_damage>0 } } }
          raise Unsupported
        end
        repeats=worlds.map do |w|
          normal=item.is_a?(RPG::Skill) && item.id==w[:user].attack_skill_id
          item.repeats+(normal ? w[:user].atk_times_add.to_i : 0)
        end.uniq
        raise Unsupported unless repeats.size==1 && (1..16).include?(repeats[0])
        if ids==[-1] && item.for_one? && item.for_opponent?
          worlds=enemies.map do |e|
            branch=worlds.map { |w| clone_world(w) }
            repeats[0].times { branch=effects(branch,e.index,item) }
            branch
          end.flatten
        else
          repeats[0].times do
            ids.each { |id| worlds=effects(worlds,id,item) if id==:self || worlds[0][:targets].has_key?(id) }
          end
        end
        if item.note =~ /<使用者効果\s*(\d+)\s*>/
          extra=$data_skills[$1.to_i];raise Unsupported unless extra && !(extra.note =~ /使用者効果/)
          worlds=effects(worlds,:self,extra)
        end
        raise Unsupported if worlds.size>32
      end
      outcomes=[]
      worlds.each do |w|
        expire(w[:user],1)
        ([w[:user]]+w[:targets].values).each { |u| expire(u,2) }
        # Later global-turn expirations depend on every participant, including
        # omitted ally turns. Do not infer that those effects persist forever.
        raise Unsupported if ([w[:user]]+w[:targets].values).any? do |u|
          u.states.any? { |s| s.auto_removal_timing==2 && (relevant?(s) || s.restriction>=4) }
        end
        range=w[:last] || [0,0]
        [range[0],range[0]+range[1]].uniq.each do |percent|
          hero=readiness(w[:user],ATB::MAX_AP*[[percent,0].max,100].min/100)
          ready=w[:targets].map { |id,e| [id,readiness(e)] }
          earlier=ready.select { |id,r| r[0]<hero[0] || (r[0]==hero[0] && r[1] && !hero[1]) }
          first=earlier.sort_by { |id,r| [r[0],r[1] ? 0 : 1,id] }.first
          outcomes<<Hash[ready.map { |id,r| [id,earlier.any? { |j,v| j==id } ? (first[0]==id ? :first : :before) : :none] }]
        end
      end
      Hash[enemies.map do |e|
        states=outcomes.map { |o| o[e.index] }.uniq
        [e.index,states==[:first] ? :first : states==[:none] ? :none : !states.include?(:none) ? :before : :possible]
      end]
    rescue Unsupported, StandardError
      unknown || {}
    end
    def self.result(scene)
      return {} unless Options.get('tempo_hint')==1 && $game_party && $game_party.in_battle
      actor=BattleManager.actor || scene.instance_variable_get(:@bs2q_queue_actor)
      return {} unless actor && actor.actor? && actor.input
      candidate=hover(scene,actor);window=scene.instance_variable_get(:@enemy_window)
      target=window && window.active && window.enemy ? window.enemy.index : nil
      ally=scene.instance_variable_get(:@actor_window)
      target=ally.index if ally && ally.active
      key=[defined?(Performance) && Performance.context(actor),actor.ap,candidate && candidate.map { |x| x && [x.class.to_s,x.id] },target,actor.instance_variable_get(:@state_frames).hash,
        $game_troop.members.map { |e| [e.ap,e.instance_variable_get(:@state_frames).hash,e.instance_variable_get(:@chant_count),e.instance_variable_get(:@max_chant_count)] }]
      @cache ||= {}
      return @cache[key] if @cache.has_key?(key)
      if candidate && defined?(Performance)
        now=Performance.now
        if !@pending || @pending[0]!=key;@pending=[key,now];end
        navigation=[37,38,39,40,81,69]+NavigationAliases.data.values.map { |letter| Keys::BASE[letter] }
        if ((now-@pending[1])&0xffffffff)<100 || (BS2QoL::Keyboard.raw_down & navigation).any?
          return Hash[$game_troop.alive_members.map { |e| [e.index,:unknown] }]
        end
      end
      @pending=nil;@cache.shift while @cache.size>=32
      @cache[key]=calculate(actor,candidate,target)
    rescue StandardError=>error
      @error=error.class.to_s+': '+error.message
      @pending=nil
      Hash[$game_troop.alive_members.map { |e| [e.index,:unknown] }]
    end
    def self.status(enemy)
      scene=SceneManager.scene;scene.is_a?(Scene_Battle) ? result(scene)[enemy.index] : nil
    end
    def self.lines(scene);[];end
    def self.tick;end
  end
end

# Pixel stars avoid font-dependent missing glyphs. The marker is owned and
# disposed with its AP gauge, and follows that gauge's visibility and position.
class Sprite_Enemy_Gauge
  alias bs20992_tempo_initialize initialize
  def initialize(*args)
    bs20992_tempo_initialize(*args)
    if @gauge_number==3
      @bs20992_marker=Sprite.new(viewport);@bs20992_marker.bitmap=Bitmap.new(15,15);@bs20992_marker.visible=false
    end
  end
  def bs20992_draw_marker(status)
    b=@bs20992_marker.bitmap;b.clear
    if [:unknown,:possible].include?(status)
      b.font.size=15;b.font.bold=true;b.font.color=Color.new(217,186,121);b.draw_text(0,-1,15,16,'?',1);return
    end
    pixels=[]
    (-6..6).each do |y|
      radius=(1+5*(1-y.abs/6.0)**3).round
      (-radius..radius).each { |x| pixels<<[x+7,y+7] }
    end
    pixels.each { |x,y| b.fill_rect(x-1,y-1,3,3,Color.new(27,23,32)) }
    pixels.each do |x,y|
      edge=[[x-1,y],[x+1,y],[x,y-1],[x,y+1]].any? { |p| !pixels.include?(p) }
      b.set_pixel(x,y,Color.new(239,211,148)) if status==:first || edge
    end
  end
  alias bs20992_tempo_position update_rect
  def update_rect(*args)
    bs20992_tempo_position(*args);m=@bs20992_marker;return unless m
    status=BS2Suite::TempoHint.status(@battler)
    m.visible=!!(self.visible && @battler.draw_gauge?(3) && !@battler.hidden? && status && status!=:none)
    if m.visible
      if @bs20992_status!=status;bs20992_draw_marker(status);@bs20992_status=status;end
      m.x=[[self.x+@gauge_width+3,0].max,Graphics.width-15].min;m.y=self.y-5;m.z=self.z+1;m.opacity=self.opacity
    end
  end
  alias bs20992_tempo_dispose dispose
  def dispose
    if @bs20992_marker;@bs20992_marker.bitmap.dispose;@bs20992_marker.dispose;@bs20992_marker=nil;end
    bs20992_tempo_dispose
  end
end
