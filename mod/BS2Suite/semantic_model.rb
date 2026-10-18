# encoding: UTF-8
module BS2Suite
  # All mutable profile data is primitive Hash/Array/String/Integer data.
  # User definitions use bounded plain text; never eval/Marshal-load a profile file.
  module Semantic
    DIGITS='1234567890'
    PREFIXES=%w(V B M N).freeze
    class << self
      attr_reader :error
      def state
        return @temporary ||= {'active'=>{},'layouts'=>{}} unless $game_system
        value=$game_system.instance_variable_get(:@bs2s_profiles)
        unless value.is_a?(Hash)
          value={'active'=>{},'layouts'=>{}}
          $game_system.instance_variable_set(:@bs2s_profiles,value)
        end
        value
      end
      def customs
        return @customs if @customs
        @customs={}
        Store.read('profiles',524288).each_line do |line|
          a=line.strip.split('|',9)
          if a[0]=='profile' && a.size==3 && a[1]=~/\Au[0-9]{1,4}\z/ && @customs.size<24
            @customs[a[1]]={'name'=>a[2][0,40],'groups'=>{},'entries'=>[]}
          elsif a[0]=='group' && a.size==5 && @customs[a[1]] && PREFIXES.include?(a[2]) && a[3]=~/\A(?:[1-9]|10)\z/
            n=a[3].to_i;next unless (1..10).include?(n)
            @customs[a[1]]['groups'][a[2]+n.to_s]=a[4][0,40]
          elsif a[0]=='behavior' && a.size==4 && @customs[a[1]] && a[2]=~/\AN(?:[1-9]|10)\z/ && %w(now last).include?(a[3])
            (@customs[a[1]]['behaviors'] ||= {})[a[2]]=a[3]
          elsif a[0]=='entry' && a.size==9 && @customs[a[1]] && PREFIXES.include?(a[2]) && %w(skill item weapon).include?(a[5])
            next unless a.values_at(3,4,6,7).all? { |v| v=~/\A[0-9]{1,5}\z/ }
            g,d,id,src=a.values_at(3,4,6,7).map { |v| v.to_i };page=a[2]=='N' ? a[8].to_i-1 : 0
            next unless (0..31).include?(page)
            next unless (1..10).include?(g) && (0..9).include?(d) && id>0 && id<10000
            entries=@customs[a[1]]['entries'];next if entries.size>=400
            entries.reject! { |e| e['prefix']==a[2] && e['group']==g && e['digit']==d && (e['page'] || 0)==page }
            entries<<{'prefix'=>a[2],'group'=>g,'digit'=>d,'kind'=>a[5],'id'=>id,'source'=>src,'page'=>page}
          end
        end
        @customs
      end
      def clean_name(text)
        text.to_s.gsub(/[|\r\n]/,' ').strip[0,40]
      end
      def persist
        lines=['version|3']
        customs.keys.sort.each do |id|
          profile=customs[id];lines<<['profile',id,clean_name(profile['name'])].join('|')
          profile['groups'].keys.sort.each do |key|
            lines<<['group',id,key[0,1],key[1,key.size],clean_name(profile['groups'][key])].join('|')
          end
          (profile['behaviors'] || {}).keys.sort.each { |key| lines<<['behavior',id,key,profile['behaviors'][key]].join('|') }
          profile['entries'].each do |e|
            lines<<['entry',id,e['prefix'],e['group'],e['digit'],e['kind'],e['id'],e['source'],(e['page'] || 0)+1].join('|')
          end
        end
        success=Store.write('profiles',lines.join("\n")+"\n")
        @error=success ? nil : :write_failed
        success
      end
      def mode(actor)
        id=state['active'][actor.id.to_s] || 'progression'
        %w(progression advanced).include?(id) || customs[id] ? id : 'progression'
      end
      def title(actor)
        id=mode(actor)
        return 'С прогрессией' if id=='progression'
        return 'Продвинутый' if id=='advanced'
        customs[id]['name']
      end
      def set_mode(actor,id)
        return false if $game_party.in_battle
        return false unless %w(progression advanced).include?(id) || customs[id]
        state['active'][actor.id.to_s]=id;sync(actor);true
      end
      def layout_key(actor,prefix)
        actor.id.to_s+':'+mode(actor)+':'+prefix
      end
      def owned(actor)
        owner=actor.instance_variable_get(:@bs2s_origin_actor) || actor
        WeaponFamilies.owned(owner).select { |w| actor.equippable?(w) }
      end
      def source_for(actor,skill_id,anchor=0)
        worn=actor.equips.compact.select { |e| e.is_a?(RPG::Armor) && e.features.any? { |f| f.code==43 && f.data_id==skill_id } }
        return worn.first if anchor.to_i<=0 && !worn.empty?
        values=owned(actor).select { |w| w.features.any? { |f| f.code==43 && f.data_id==skill_id } }
        values.select! { |w| WeaponFamilies.root(w.id)==WeaponFamilies.root(anchor) } if anchor.to_i>0
        values.sort_by { |w| [-WeaponFamilies.depth(w.id),w.id] }.first
      end
      def variant(actor,record)
        ids=mode(actor)=='advanced' ? record[:advanced_variants] : record[:variants]
        ids.each do |id|
          object=record[:kind]=='item' ? $data_items[id] : $data_skills[id]
          next unless object
          if record[:prefix]=='B'
            return [id,nil] if $game_party.item_number(object)>0
          elsif record[:prefix]=='M'
            return [id,nil] if actor.skill_learn?(object)
          else
            source=source_for(actor,id);return [id,source] if source
          end
        end
        nil
      end
      def all_roles(prefix)
        SemanticCatalog::RECORDS.select { |r| r[:prefix]==prefix }.map { |r| r[:section] }.uniq
      end
      def partition(keys,prefix)
        return [{'name'=>prefix=='V' ? 'Оружейные приёмы' : prefix=='M' ? 'Изученные приёмы' : 'Предметы',
                 'roles'=>all_roles(prefix),'keys'=>keys.dup}] if keys.size<=10
        left_roles= prefix=='V' ? %w(prep control resource) : prefix=='M' ? %w(prep defense restore) : %w(hp mp cleanse buff resin special)
        sides=[keys.select { |k| SemanticCatalog.record(k)[:side]=='self' },keys.reject { |k| SemanticCatalog.record(k)[:side]=='self' }]
        groups=[]
        sides.each_with_index do |side,n|
          next if side.empty?
          roles=side.map { |k| SemanticCatalog.record(k)[:section] }.uniq
          if side.size<=10
            groups<<{'name'=>n==0 ? 'На себя и союзников' : 'По противнику','roles'=>roles,'side'=>n==0 ? 'self' : 'enemy','keys'=>side}
          else
            # Refine only the overflowing side; do not expose every future leaf.
            side.map { |k| SemanticCatalog.record(k)[:section] }.uniq.each do |role|
              subset=side.select { |k| SemanticCatalog.record(k)[:section]==role }
              subset.each_slice(10).with_index do |slice,index|
                name=SemanticCatalog::LABELS[role.to_sym] || 'Другие приёмы'
                name+=' '+(index+1).to_s if subset.size>10
                groups<<{'name'=>name,'roles'=>[role],'side'=>n==0 ? 'self' : 'enemy','keys'=>slice}
              end
            end
          end
        end
        while groups.size>10
          pairs=[]
          groups.each_with_index do |a,i|
            groups.each_with_index do |b,j|
              next unless j>i && a['keys'].size+b['keys'].size<=10
              rank=(a['roles'] & b['roles']).any? ? 0 : a['side']==b['side'] ? 1 : 2
              pairs<<[rank,(i-j).abs,i,j]
            end
          end
          break if pairs.empty?
          pair=pairs.sort.first;i=pair[2];j=pair[3];a=groups[i];b=groups[j]
          roles=(a['roles']+b['roles']).uniq
          a['name']=roles.map { |role| SemanticCatalog::LABELS[role.to_sym] || role }.join(' / ')
          a['roles']=roles;a['keys']+=b['keys'];a.delete('side') if a['side']!=b['side']
          groups.delete_at(j)
        end
        groups
      end
      def sync(actor)
        return unless actor
        return if customs[mode(actor)]
        %w(V M B).each do |prefix|
          key=layout_key(actor,prefix)
          layout=state['layouts'][key] ||= {'groups'=>[],'known'=>{},'revision'=>0}
          old_positions={}
          layout['groups'].each_with_index do |g,gi|
            g['keys'].each_with_index { |k,i| old_positions[k]=[gi+1,(g['digits'] || {})[k] || DIGITS[i,1].to_i] }
          end
          records=SemanticCatalog::RECORDS.select { |r| r[:prefix]==prefix }
          records.each do |r|
            value=variant(actor,r);layout['known'][r[:key]]=value[0] if value
          end
          keys=layout['groups'].map { |g| g['keys'] }.flatten
          fresh=records.map { |r| r[:key] }.select { |k| layout['known'][k] && !keys.include?(k) }
          if fresh.empty?
            layout['groups'].each { |g| g['digits']={};g['keys'].each_with_index { |k,i| g['digits'][k]=DIGITS[i,1].to_i } }
            next
          end
          all=(keys+fresh).uniq
          if layout['groups'].size==1 && all.size<=10
            layout['groups'][0]['keys']=all
          elsif layout['groups'].empty?
            layout['groups']=partition(all,prefix)
          else
            fits=true
            candidate=Marshal.load(Marshal.dump(layout['groups']))
            fresh.each do |k|
              role=SemanticCatalog.record(k)[:section]
              side=SemanticCatalog.record(k)[:side]
              group=candidate.find { |g| g['roles'].include?(role) && (!g['side'] || g['side']==side) && g['keys'].size<10 }
              if group;group['keys']<<k;else;fits=false;break;end
            end
            if fits;layout['groups']=candidate
            else
              old=layout['groups'].map { |g| g['keys'].dup }
              layout['groups']=partition(all,prefix)
              layout['moved']=old!=layout['groups'].map { |g| g['keys'] }
            end
          end
          layout['groups'].each do |g|
            g['digits']={}
            g['keys'].each_with_index { |k,i| g['digits'][k]=DIGITS[i,1].to_i }
          end
          moves=[]
          layout['groups'].each_with_index do |g,gi|
            g['keys'].each do |k|
              old=old_positions[k];current=[gi+1,g['digits'][k]]
              next unless old && old!=current
              object=prefix=='B' ? $data_items[layout['known'][k]] : $data_skills[layout['known'][k]]
              moves<<prefix+DIGITS[old[0]-1,1]+old[1].to_s+' → '+prefix+DIGITS[current[0]-1,1]+current[1].to_s+' '+(object ? object.name : '')
            end
          end
          layout['moves']=moves if moves.any?
          layout['revision']+=1
        end
      end
      def pending_moves(actor,prefix)
        return [] if customs[mode(actor)]
        layout=state['layouts'][layout_key(actor,prefix)]
        layout ? (layout['moves'] || []) : []
      end
      def acknowledge(actor,prefix)
        layout=state['layouts'][layout_key(actor,prefix)];layout['moves']=[] if layout
      end
      def groups(actor,prefix)
        if customs[mode(actor)]
          p=customs[mode(actor)]
          numbers=p['entries'].select { |e| e['prefix']==prefix }.map { |e| e['group'] }
          numbers+=p['groups'].keys.select { |k| k[0,1]==prefix }.map { |k| k[1,k.size].to_i }
          return (numbers+[1]).uniq.sort.map { |n| {:number=>n,:name=>p['groups'][prefix+n.to_s] || 'Группа '+n.to_s} }
        end
        sync(actor) unless $game_party.in_battle
        layout=state['layouts'][layout_key(actor,prefix)]
        return [] unless layout
        layout['groups'].each_with_index.map { |g,i| {:number=>i+1,:name=>g['name']} }
      end
      def object_row(actor,prefix,group,digit,kind,id,anchor=0)
        kind=kind.to_sym
        object=BS2QoL::Model.database(kind)[id]
        source=prefix=='V' && kind==:skill ? source_for(actor,id,anchor) : nil
        if kind==:weapon
          object=WeaponFamilies.resolve(id,actor)
        end
        present=if !object;false
        elsif kind==:item;$game_party.item_number(object)>0
        elsif kind==:weapon;owned(actor).include?(object)
        elsif prefix=='V';!!source
        else;actor.skill_learn?(object)
        end
        row={:prefix=>prefix,:group=>group,:digit=>digit,:kind=>kind,:id=>object ? object.id : id,
         :object=>object,:source=>source,:present=>present,
         :address=>prefix+DIGITS[(group-1)%10,1]+digit.to_s}
        view=source.is_a?(RPG::Weapon) && source!=actor.equips[0] ? Projection.weapon(actor,source) : actor
        row[:usable]=present && (kind==:weapon || (view.usable?(object) && (kind!=:skill || !view.skill_seal.include?(id))))
        row
      end
      def rows(actor,prefix,group)
        if customs[mode(actor)]
          entries=customs[mode(actor)]['entries'].select { |e| e['prefix']==prefix && e['group']==group }
          return entries.map { |e| object_row(actor,prefix,group,e['digit'],e['kind'],e['id'],e['source']) }.sort_by { |r| DIGITS.index(r[:digit].to_s) }
        end
        layout=state['layouts'][layout_key(actor,prefix)];g=layout && layout['groups'][group-1]
        return [] unless g
        g['keys'].each_with_index.map do |key,i|
          r=SemanticCatalog.record(key);id=layout['known'][key]
          digit=(g['digits'] || {})[key] || DIGITS[i,1].to_i
          object_row(actor,prefix,group,digit,r[:kind],id)
        end.sort_by { |row| DIGITS.index(row[:digit].to_s) }
      end
      def clone_profile(actor,empty=false)
        return nil if customs.size>=24
        id=(1..9999).map { |i| 'u'+i.to_s }.find { |key| !customs[key] }
        return nil unless id
        profile={'name'=>empty ? 'Новый профиль' : 'Копия: '+title(actor),'groups'=>{},'entries'=>[],'behaviors'=>Hash[(1..10).map { |n| ['N'+n.to_s,DirectWeapons.default_behavior(n)] }]}
        unless empty
          %w(V M B).each do |prefix|
            groups(actor,prefix).each do |g|
              profile['groups'][prefix+g[:number].to_s]=g[:name]
              rows(actor,prefix,g[:number]).each do |r|
                profile['entries']<<{'prefix'=>prefix,'group'=>g[:number],'digit'=>r[:digit],'kind'=>r[:kind].to_s,'id'=>r[:id],'source'=>r[:source].is_a?(RPG::Weapon) ? r[:source].id : 0}
              end
            end
          end
          if defined?(DirectWeapons)
            DirectWeapons.groups(actor).each do |g|
              profile['groups']['N'+g[:number].to_s]=g[:name].sub(/ · (?:Сменить сейчас|Последнее действие)\z/,'')
              profile['behaviors']['N'+g[:number].to_s]=DirectWeapons.behavior(actor,g[:number])
              (0...DirectWeapons.pages(actor,g[:number])).each do |page|
              DirectWeapons.rows(actor,g[:number],page).each do |r|
                profile['entries']<<{'prefix'=>'N','group'=>g[:number],'digit'=>r[:digit],'kind'=>'weapon','id'=>r[:id],'source'=>0,'page'=>page}
              end
              end
            end
          end
        end
        customs[id]=profile
        unless persist;customs.delete(id);return nil;end
        state['active'][actor.id.to_s]=id
        id
      end
      def assign(actor,prefix,group,digit,object,source=nil,page=0)
        return false unless PREFIXES.include?(prefix) && (1..10).include?(group) && (0..9).include?(digit)
        return false unless (0..31).include?(page) && (prefix=='N' || page==0)
        kind=BS2QoL::Model.kind(object)
        return false unless (prefix=='B' && kind==:item) || (prefix=='M' && kind==:skill && actor.skill_learn?(object)) ||
          (prefix=='V' && kind==:skill && (source || source_for(actor,object.id))) || (prefix=='N' && kind==:weapon)
        unless customs[mode(actor)]
          return false unless clone_profile(actor)
        end
        p=customs[mode(actor)];backup=Marshal.load(Marshal.dump(p))
        p['entries'].reject! { |e| e['prefix']==prefix && e['group']==group && e['digit']==digit && (e['page'] || 0)==page }
        source ||= source_for(actor,object.id) if prefix=='V'
        p['entries']<<{'prefix'=>prefix,'group'=>group,'digit'=>digit,'kind'=>kind.to_s,'id'=>object.id,'source'=>source.is_a?(RPG::Weapon) ? source.id : 0,'page'=>page}
        p['groups'][prefix+group.to_s] ||= prefix=='N' ? DirectWeapons.label(DirectWeapons.behavior(actor,group)) : 'Моя группа '+group.to_s
        return true if persist
        customs[mode(actor)]=backup;false
      end
      def set_behavior(actor,group,value)
        return false unless %w(now last).include?(value) && (1..10).include?(group)
        p=customs[mode(actor)];return false unless p
        old=Marshal.load(Marshal.dump(p));(p['behaviors'] ||= {})['N'+group.to_s]=value
        return true if persist
        customs[mode(actor)]=old;false
      end
      def remove(actor,prefix,group,digit,page=0)
        return false unless customs[mode(actor)]
        p=customs[mode(actor)];old=p['entries'].dup
        p['entries'].reject! { |e| e['prefix']==prefix && e['group']==group && e['digit']==digit && (e['page'] || 0)==page }
        return true if persist
        p['entries']=old;false
      end
      def renamed(actor,name)
        p=customs[mode(actor)];return false unless p
        old=p['name'];p['name']=clean_name(name)
        return true if persist
        p['name']=old;false
      end
    end
  end
end
