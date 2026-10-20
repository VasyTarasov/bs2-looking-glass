# encoding: UTF-8
# Read the CURRENT event page and its reachable conditions. Never start an
# interpreter, evaluate scripts, roll loot, reveal another page or mutate flags.
module BS2Suite::InteractionHighlight
  EMPTY=/\A(?:Вы не нашли ничего ценного\.|Здесь (?:ничего нет|пусто)[.!]?|Нечего (?:брать|забирать)[.!]?|You found nothing of value\.|Nothing (?:here|to take)[.!]?)\z/i
  def self.condition(p,event,env)
    case p[0]
    when 0;switch_value(env,p[1])==(p[2]==0)
    when 1
      a=variable(env,p[1]);b=p[2]==0 ? p[3] : variable(env,p[3]);return nil if a==:unknown || b==:unknown
      case p[4];when 0;a==b;when 1;a>=b;when 2;a<=b;when 3;a>b;when 4;a<b;when 5;a!=b;end
    when 2;(env[:self].has_key?(p[1]) ? env[:self][p[1]] : $game_self_switches[[$game_map.map_id,event.id,p[1]]])==(p[2]==0)
    when 3;$game_timer.working? && (p[2]==0 ? $game_timer.sec>=p[1] : $game_timer.sec<=p[1])
    when 4
      a=$game_actors.instance_variable_get(:@data)[p[1]];return p[2]==0 ? false : nil unless a
      case p[2]
      when 0;$game_party.members.include?(a)
      when 1;a.name==p[3]
      when 2;a.class_id==p[3]
      when 3;a.skill_learn?($data_skills[p[3]])
      when 4;a.weapons.include?($data_weapons[p[3]])
      when 5;a.armors.include?($data_armors[p[3]])
      when 6;a.state?(p[3])
      end
    when 6
      c=p[1]==-1 ? $game_player : p[1]==0 ? event : $game_map.events[p[1]]
      c && c.direction==p[2]
    when 7
      case p[2];when 0;$game_party.gold>=p[1];when 1;$game_party.gold<=p[1];when 2;$game_party.gold<p[1];end
    when 8;$game_party.has_item?($data_items[p[1]])
    when 9;$game_party.has_item?($data_weapons[p[1]],p[2])
    when 10;$game_party.has_item?($data_armors[p[1]],p[2])
    when 11;Input.press?(p[1])
    when 13;$game_player.vehicle==$game_map.vehicles[p[1]]
    else;nil
    end
  rescue StandardError
    nil
  end
  def self.variable(env,id)
    return env[:vars][id] if env[:vars].has_key?(id)
    range=(env[:var_ranges] || []).reverse.find { |a| id>=a[0] && id<=a[1] }
    range ? range[2] : $game_variables[id]
  end
  def self.switch_value(env,id)
    return env[:switches][id] if env[:switches].has_key?(id)
    range=(env[:switch_ranges] || []).reverse.find { |a| id>=a[0] && id<=a[1] }
    range ? range[2] : $game_switches[id]
  end
  def self.data_value(type,a,b,event)
    case type
    when 0,1,2;$game_party.item_number([$data_items,$data_weapons,$data_armors][type][a])
    when 3
      actor=$game_actors.instance_variable_get(:@data)[a];return :unknown unless actor
      case b;when 0;actor.level;when 1;actor.exp;when 2;actor.hp;when 3;actor.mp;when 4..11;actor.param(b-4);else;0;end
    when 5
      c=a==-1 ? $game_player : a==0 ? event : $game_map.events[a];return 0 unless c
      case b;when 0;c.x;when 1;c.y;when 2;c.direction;when 3;c.screen_x;when 4;c.screen_y;else;0;end
    when 6;$game_party.members[a] ? $game_party.members[a].id : 0
    when 7
      case a;when 0;$game_map.map_id;when 1;$game_party.members.size;when 2;$game_party.gold;when 3;$game_party.steps;when 4;Graphics.frame_count/Graphics.frame_rate;when 5;$game_timer.sec;when 6;$game_system.save_count;when 7;$game_system.battle_count;else;0;end
    else;:unknown
    end
  end
  def self.analyze(list,event,seen=[],budget=[800],env={:vars=>{},:switches=>{},:self=>{}})
    text=false;empty=false;result=false;branch={};i=0
    while i<list.size
      budget[0]-=1;return [false,:budget] if budget[0]<0
      c=list[i];p=c.parameters;indent=c.indent;code=c.code
      if code==111
        value=condition(p,event,env);return [result || text,:unknown_condition] if value.nil?
        branch[indent]=value
        unless value
          i+=1;i+=1 while i<list.size && !(list[i].indent==indent && [411,412].include?(list[i].code))
          next
        end
      elsif code==411 && branch[indent]
        i+=1;i+=1 while i<list.size && !(list[i].indent==indent && list[i].code==412)
        next
      elsif code==115
        break
      elsif code==117
        id=p[0];return [false,:common_cycle] if seen.include?(id) || seen.size>=8
        common=$data_common_events[id];return [false,:missing_common] unless common
        useful,why=analyze(common.list,event,seen+[id],budget,env)
        return [result,:interaction] if result && !useful
        return [false,why] if !useful && ![:empty,:no_effect].include?(why)
        if why==:empty && !useful;text=false;empty=true;end
        result ||= useful
      elsif code==102
        # Evaluate selectable outcomes, not their introductory corpse description.
        useful=false;unknown=nil;j=i+1
        while j<list.size && !(list[j].indent==indent && list[j].code==404)
          marker=list[j]
          if marker.indent==indent && [402,403].include?(marker.code)
            k=j+1;k+=1 while k<list.size && !(list[k].indent==indent && [402,403,404].include?(list[k].code))
            label=marker.parameters[1].to_s
            unless label =~ /\A(?:Уйти|Уход|Отмена|Назад|Leave|Cancel|Back)\z/i
              branch_env={:vars=>env[:vars].dup,:switches=>env[:switches].dup,:self=>env[:self].dup,:var_ranges=>(env[:var_ranges] || []).dup,:switch_ranges=>(env[:switch_ranges] || []).dup}
              yes,why=analyze(list[(j+1)...k],event,seen,budget,branch_env)
              useful ||= yes;unknown=why unless yes || [:empty,:no_effect].include?(why)
            end
            j=k
          else;j+=1;end
        end
        return [result,unknown] if unknown && !useful && !result
        result ||= useful;text=false;empty ||= !useful;i=j
      elsif code==121
        env[:switch_ranges] ||= [];env[:switch_ranges]<<[p[0],p[1],p[2]==0]
        env[:switches].delete_if { |id,v| id>=p[0] && id<=p[1] }
      elsif code==123;env[:self][p[0]]=p[1]==0
      elsif code==122
        value=p[3]==0 ? p[4] : p[3]==1 ? variable(env,p[4]) : p[3]==3 ? data_value(p[4],p[5],p[6],event) : :unknown
        if p[1]-p[0]>64
          env[:var_ranges] ||= [];env[:var_ranges]<<[p[0],p[1],p[2]==0 ? value : :unknown]
          env[:vars].delete_if { |id,v| id>=p[0] && id<=p[1] };i+=1;next
        end
        (p[0]..p[1]).each do |id|
          before=variable(env,id)
          env[:vars][id]=if value==:unknown || before==:unknown;:unknown
          else
            begin
              case p[2];when 0;value;when 1;before+value;when 2;before-value;when 3;before*value;when 4;before/value;when 5;before%value;else;:unknown;end
            rescue StandardError;:unknown;end
          end
        end
      elsif code==401 || code==405
        line=p[0].to_s.gsub(/\\[cC]\[\d+\]/,'').strip
        unless line.empty?;EMPTY.match(line) ? empty=true : text=true;end
      elsif [103,104,201,206,301,302,303,311,312,313,314,315,316,317,318,319,320,321,322,323,324,351,352,353,354].include?(code)
        result=true
      elsif [125,126,127,128].include?(code)
        # Zero quantities and impossible removals are not a useful interaction.
        at=code==125 ? 0 : 1
        amount=p[at+1]==0 ? p[at+2] : variable(env,p[at+2])
        if amount==:unknown;result=true
        elsif amount!=0
          stock=code==125 ? $game_party.gold : $game_party.item_number([$data_items,$data_weapons,$data_armors][code-126][p[0]])
          result=true if p[at]==0 || stock>0
        end
      elsif code==355
        # Script execution is not simulated. Never advertise its hidden result.
        return [false,:script] unless result || text
      elsif [112,113,119].include?(code)
        # Loops/jumps and temporary variable writes need a separate interpreter.
        # A visible choice already proves an interaction without executing it.
        return [false,:control_flow] unless result || text
      end
      i+=1
    end
    return [true,:interaction] if result || text
    [false,empty ? :empty : :no_effect]
  end
  def self.classify(event)
    page=event.instance_variable_get(:@page)
    return [false,:inactive] unless page && !event.instance_variable_get(:@erased)
    return [false,:automatic] unless [0,1,2].include?(page.trigger)
    return [false,:invisible] if event.transparent || event.opacity<=0 || event.character_name.empty? && event.tile_id==0
    analyze(page.list,event)
  rescue StandardError
    [false,:analysis_error]
  end
  def self.held?
    return false unless BS2Suite::Options.get('interaction_highlight')==1 && SceneManager.scene.is_a?(Scene_Map)
    return false if $game_message.busy? || $game_map.interpreter.running?
    return false unless BS2QoL::Keyboard.focused?
    return false if defined?(BS2Suite::SteamBridge) && BS2Suite::SteamBridge.active?
    down=BS2QoL::Keyboard.raw_down
    return false if (down & [91,92]).any?
    BS2Suite::Keys.held?(BS2Suite::Keys.token(:interact_highlight),down,true)
  end
  class Layer
    attr_reader :count
    def initialize(sprites,viewport)
      @characters=sprites;@viewport=viewport;@markers={};@cache={};@bitmaps={};@count=0;@last=-100
    end
    def bitmap(w,h)
      w=[[w,12].max,192].min;h=[[h,16].max,192].min
      @bitmaps[[w,h]] ||= begin
        b=Bitmap.new(w+6,h+6);color=Color.new(255,215,120,230);shadow=Color.new(20,12,4,210)
        [[0,0,1,1],[w+5,0,-1,1],[0,h+5,1,-1],[w+5,h+5,-1,-1]].each do |x,y,dx,dy|
          hx=dx>0 ? x : x-8;vy=dy>0 ? y : y-8
          b.fill_rect(hx,[y-1,0].max,9,3,shadow);b.fill_rect([x-1,0].max,vy,3,9,shadow)
          b.fill_rect(hx,y,9,1,color);b.fill_rect(x,vy,1,9,color)
        end
        b
      end
    end
    def update
      active=BS2Suite::InteractionHighlight.held?
      unless active
        @markers.each_value { |s| s.visible=false };@count=0;@was_held=false;return
      end
      frame=Graphics.frame_count
      if !@was_held || frame<@last || frame-@last>=8
        @cache.clear;@last=frame;counts=Hash.new(0);samples=[]
        @characters.each do |sprite|
          e=sprite.character;next unless e.is_a?(Game_Event)
          next unless sprite.visible && sprite.opacity>0 && sprite.x>=-64 && sprite.x<=Graphics.width+64 && sprite.y>=-64 && sprite.y<=Graphics.height+128
          result=BS2Suite::InteractionHighlight.classify(e);@cache[e.object_id]=result[0];counts[result[1]]+=1
          samples<<[e.id,result[1]] if !result[0] && ![:invisible,:empty,:no_effect,:inactive,:automatic].include?(result[1]) && samples.size<12
        end
        # At most once per hold; aggregate reasons, no event text or hidden pages.
        if !@was_held && defined?(BS2Suite::Debug)
          BS2Suite::Debug.emit('interaction_highlight',{:map=>$game_map.map_id,:reasons=>counts,:visible_exclusion_samples=>samples})
        end
      end
      @was_held=true;@count=0
      @characters.each do |source|
        e=source.character;next unless e.is_a?(Game_Event)
        useful=@cache[e.object_id] && !e.instance_variable_get(:@erased) && !e.transparent && e.opacity>0
        visible=useful && source.visible && source.opacity>0 && source.x>=-64 && source.x<=Graphics.width+64 && source.y>=-64 && source.y<=Graphics.height+128
        marker=@markers[e.object_id]
        if visible
          marker ||= @markers[e.object_id]=Sprite.new(@viewport)
          marker.bitmap=bitmap(source.src_rect.width,source.src_rect.height)
          marker.ox=marker.bitmap.width/2;marker.oy=marker.bitmap.height-3
          marker.x=source.x;marker.y=source.y;marker.z=source.z+1;marker.opacity=source.opacity;marker.visible=true;@count+=1
        elsif marker;marker.visible=false;end
      end
    rescue StandardError=>e
      @markers.each_value { |s| s.visible=false };@count=0
      BS2Suite::Debug.emit('interaction_highlight_error',{:class=>e.class.to_s}) if defined?(BS2Suite::Debug) && !@failed
      @failed=true
    end
    def dispose
      @markers.each_value { |s| s.dispose unless s.disposed? };@markers.clear
      @bitmaps.each_value { |b| b.dispose unless b.disposed? };@bitmaps.clear
    end
  end
end
class Spriteset_Map
  alias bs209992_highlight_characters create_characters
  def create_characters
    @bs209992_highlight.dispose if @bs209992_highlight
    @bs209992_highlight=nil
    bs209992_highlight_characters
  end
  alias bs209992_highlight_update update
  def update
    bs209992_highlight_update
    @bs209992_highlight ||= BS2Suite::InteractionHighlight::Layer.new(@character_sprites,@viewport1)
    @bs209992_highlight.update
  end
  alias bs209992_highlight_dispose dispose
  def dispose
    @bs209992_highlight.dispose if @bs209992_highlight
    bs209992_highlight_dispose
  end
end
