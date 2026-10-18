# encoding: UTF-8
module BS2Suite
  module Priorities
    WINDOWS=[5,10,20,30].freeze
    def self.enabled?;BS2Suite.enabled?('semantic_groups') && Options.get('adaptive_priority')==1;end
    def self.window;WINDOWS.include?(Options.get('priority_window')) ? Options.get('priority_window') : 20;end
    def self.load
      return if @history
      @history=[];@orders={};@messages={};@serial=0
      Store.read('priorities',262144).each_line do |line|
        parts=line.strip.split('|',5)
        if parts[0]=='battle' && parts[1].to_s=~/\A\d{1,9}\z/
          counts={}
          parts[2].to_s.split(',').take(512).each do |pair|
            match=/\A(\d{1,5}:[a-z]\d{1,5})=(\d)\z/.match(pair)
            counts[match[1]]=match[2].to_i if match
          end
          @serial=[@serial,parts[1].to_i].max;@history<<counts
        elsif parts[0]=='order' && parts[1].to_s=~/\A\d{1,5}:[a-z0-9]+:[VMN]:[a-z0-9,]+\z/ && parts[2].to_s=~/\A\d{1,9}\z/
          tokens=parts[3].to_s.split(',');next unless tokens.size<=10 && tokens.all? { |t| t=~/\A[a-z]\d{1,5}\z/ }
          @orders[parts[1]]=[tokens,parts[2].to_i]
        elsif parts[0]=='notice' && parts[1].to_s=~/\A\d{1,5}:[VMN]\z/
          (@messages[parts[1]] ||= [])<<parts[2].to_s[0,180]
        end
      end
      @history=@history.last(30)
    end
    def self.persist
      load;lines=@history.each_with_index.map { |counts,i| 'battle|'+(@serial-@history.size+i+1).to_s+'|'+counts.map { |k,v| k+'='+v.to_s }.join(',') }
      @orders.to_a.last(128).each { |key,value| lines<<'order|'+key+'|'+value[1].to_s+'|'+value[0].join(',') }
      @messages.each { |key,rows| rows.take(16).each { |text| lines<<'notice|'+key+'|'+text.gsub(/[|\r\n]/,' ') } }
      Store.write('priorities',lines.join("\n")+"\n")
    end
    def self.begin_battle
      load;@current={};@open=enabled?
    end
    def self.token(prefix,id)
      return 'w'+BS2Suite::WeaponFamilies.root(id).to_s if prefix=='N'
      @roles ||= {}
      key=[prefix,id]
      @roles[key] ||= begin
        record=BS2Suite::SemanticCatalog::RECORDS.find { |r| r[:prefix]==prefix && (r[:variants]+r[:advanced_variants]).include?(id) }
        's'+(record ? record[:variants].first : id).to_s
      end
    end
    def self.used(actor,item)
      return unless @open && enabled? && actor.actor? && item.is_a?(RPG::Skill)
      values=%w(V M).map { |p| token(p,item.id) }.uniq
      weapon=actor.equips[0]
      values<<token('N',weapon.id) if weapon && !(defined?(BattleSupport) && BattleSupport.quick?(item))
      values.each do |value|
        key=actor.id.to_s+':'+value
        next if !@current.has_key?(key) && @current.size>=160
        @current[key]=[@current.fetch(key,0)+1,5].min
      end
    end
    def self.signature(actor,prefix,rows)
      actor.id.to_s+':'+Semantic.mode(actor)+':'+prefix+':'+rows.map { |r| token(prefix,r[:id]) }.uniq.sort.join(',')
    end
    def self.apply(actor,prefix,group,rows)
      return rows unless enabled? && %w(V M N).include?(prefix) && !Semantic.customs[Semantic.mode(actor)]
      load;record=@orders[signature(actor,prefix,rows)];return rows unless record
      return rows unless record[0].sort==rows.map { |r| token(prefix,r[:id]) }.sort
      order=record[0];sorted=rows.sort_by { |r| order.index(token(prefix,r[:id])) || 99 }
      sorted.each_with_index.map do |row,i|
        value=row.dup;value[:digit]=Semantic::DIGITS[i,1].to_i;value[:address]=prefix+Semantic::DIGITS[group-1,1]+value[:digit].to_s;value
      end
    end
    # A challenger needs >=50% more capped uses, >=3 extra uses and coverage in
    # several battles. A group then rests for three completed battles.
    def self.reorder(actor,prefix,group,rows)
      return if rows.size<2 || Semantic.customs[Semantic.mode(actor)]
      key=signature(actor,prefix,rows);previous=@orders[key]
      return if previous && @serial-previous[1]<3
      history=@history.last(window);return if history.size<3
      score={};coverage={}
      rows.each do |row|
        t=token(prefix,row[:id]);stat=actor.id.to_s+':'+t
        score[t]=history.inject(0) { |sum,battle| sum+battle.fetch(stat,0) }
        coverage[t]=history.count { |battle| battle.fetch(stat,0)>0 }
      end
      original=rows.map { |r| token(prefix,r[:id]) };order=original.dup
      order.dup.each do |candidate|
        next if coverage[candidate]<(window==5 ? 2 : 3)
        index=order.index(candidate)
        while index>0
          other=order[index-1]
          break unless score[candidate]>=score[other]*1.5 && score[candidate]>=score[other]+3
          order[index-1],order[index]=order[index],order[index-1];index-=1
        end
      end
      return if order==original
      @orders[key]=[order,@serial]
      notice_key=actor.id.to_s+':'+prefix
      messages=@messages[notice_key] ||= []
      order.each_with_index do |token,i|
        old=original.index(token);next if old==i
        row=rows[old];name=row[:object] && row[:object].name
        messages<<prefix+group.to_s+Semantic::DIGITS[old,1]+' → '+prefix+group.to_s+Semantic::DIGITS[i,1]+' '+name.to_s
      end
      @messages[notice_key]=messages.last(16)
    end
    def self.finish
      return unless @open
      @open=false;return unless enabled?
      @history<<@current.dup;@history=@history.last(30);@serial+=1
      $game_party.battle_members.each do |actor|
        %w(V M N).each do |prefix|
          groups=prefix=='N' ? DirectWeapons.groups(actor) : Semantic.groups(actor,prefix)
          groups.each do |g|
            rows=prefix=='N' ? DirectWeapons.rows(actor,g[:number]) : Semantic.rows(actor,prefix,g[:number])
            reorder(actor,prefix,g[:number],rows)
          end
        end
      end
      persist
    end
    def self.messages(actor,prefix)
      return [] unless enabled?
      load;(@messages[actor.id.to_s+':'+prefix] || []).dup
    end
    def self.acknowledge(actor,prefix)
      load;key=actor.id.to_s+':'+prefix
      return unless @messages.delete(key)
      persist
    end
  end
end
if BS2Suite.enabled?('semantic_groups')
module BS2Suite::Semantic
  class << self
    alias bs20991_priority_rows rows
    def rows(actor,prefix,group)
      BS2Suite::Priorities.apply(actor,prefix,group,bs20991_priority_rows(actor,prefix,group))
    end
    alias bs20991_priority_moves pending_moves
    def pending_moves(actor,prefix)
      bs20991_priority_moves(actor,prefix)+BS2Suite::Priorities.messages(actor,prefix)
    end
    alias bs20991_priority_acknowledge acknowledge
    def acknowledge(actor,prefix)
      bs20991_priority_acknowledge(actor,prefix);BS2Suite::Priorities.acknowledge(actor,prefix)
    end
  end
end
module BS2Suite::DirectWeapons
  class << self
    alias bs20991_priority_weapon_rows rows
    def rows(actor,group,page=0)
      BS2Suite::Priorities.apply(actor,'N',group,bs20991_priority_weapon_rows(actor,group,page))
    end
  end
end
end
module BattleManager
  class << self
    alias bs20991_priority_setup setup
    def setup(*args)
      BS2Suite::Priorities.begin_battle;bs20991_priority_setup(*args)
    end
    alias bs20991_priority_end battle_end
    def battle_end(*args)
      BS2Suite::Priorities.finish;bs20991_priority_end(*args)
    end
  end
end
class Game_Battler
  alias bs20991_priority_use use_item
  def use_item(item)
    value=bs20991_priority_use(item)
    BS2Suite::Priorities.used(self,item);value
  end
end
