# encoding: UTF-8
module BS2QoL::Bindings
  class << self
    def valid_scope?(scope)
      ['weapons','items','quick','cast'].include?(scope) || !!(/\Aweapon(?:0|[1-9][0-9]{0,4})\z/=~scope)
    end
    def valid?(scope,chord,kind,id)
      return false unless valid_scope?(scope) && id.is_a?(Integer) && id>0 && id<100000
      return kind==:weapon && !!(/\AS[0-9]\z/=~chord) if scope=='weapons'
      return kind==:skill && !!(/\ACS[0-9]\z/=~chord) if scope=='cast'
      return [:item,:skill].include?(kind) && !!(/\AC[0-9]\z/=~chord) if scope=='quick'
      kind==(scope=='items' ? :item : :skill) && !!(/\A[SC][0-9]\z/=~chord)
    end
    def parse(text)
      result={};text=text.to_s.force_encoding('UTF-8');return result unless text.valid_encoding?
      text.each_line do |line|
        if m=/\Ascope=([a-z0-9]+)\z/.match(line.strip)
          result[m[1]]||={} if valid_scope?(m[1]) && result.size<1024
        elsif m=/\Abind=([a-z0-9]+),((?:CS|S|C)[0-9]),(weapon|item|skill),([0-9]+)(?:,([0-9]+))?\z/.match(line.strip)
          scope,key,kind,id=m[1],m[2],m[3].to_sym,m[4].to_i
          next unless valid?(scope,key,kind,id) && (result.has_key?(scope) || result.size<1024)
          value=[kind,id];value<<m[5].to_i if scope=='cast' && m[5] && m[5].to_i>0 && m[5].to_i<100000
          (result[scope]||={})[key]=value
        end
      end
      result
    end
    def weapon_scope(actor)
      weapon=actor && actor.equips[0]
      'weapon'+BS2Suite::WeaponFamilies.root(weapon ? weapon.id : 0).to_s
    end
    alias bs2v2_old_ensure_scope ensure_scope
    def ensure_scope(scope,actor=nil)
      if scope=~/\Aweapon([0-9]+)\z/
        canonical='weapon'+BS2Suite::WeaponFamilies.root($1.to_i).to_s
        matching=data.keys.select { |k| k=~/\Aweapon([0-9]+)\z/ && 'weapon'+BS2Suite::WeaponFamilies.root($1.to_i).to_s==canonical }
        if !matching.empty?
          merged={};matching.sort_by { |k| k==canonical ? 1 : 0 }.each { |k| merged.merge!(data[k]) }
          matching.each { |k| data.delete(k) };data[canonical]=merged
        end
        scope=canonical
      end
      return data[scope] if data.has_key?(scope)
      return data[scope]={} if scope=='cast'
      bs2v2_old_ensure_scope(scope,actor)
    end
    def migrate_quick(actor)
      quick=ensure_scope('quick',actor)
      changed=false
      quick.keys.each do |key|
        value=quick[key];next unless value[0]==:skill
        skill=$data_skills[value[1]];next if !skill || (actor && actor.skill_learn?(skill))
        families=BS2Suite::WeaponFamilies.grants(skill.id).map { |w| BS2Suite::WeaponFamilies.root(w.id) }.uniq
        next if families.empty?
        families.each { |id| entries=ensure_scope('weapon'+id.to_s,actor);entries[key]||=value.dup }
        quick.delete(key);changed=true
      end
      persist if changed
    end
    def get(scope,chord,actor=nil)
      value=ensure_scope(scope,actor)[chord]
      if scope=='quick' && actor
        migrate_quick(actor)
        value=ensure_scope(weapon_scope(actor),actor)[chord] || ensure_scope('quick',actor)[chord]
      end
      if value && value[0]==:weapon
        resolved=BS2Suite::WeaponFamilies.resolve(value[1],actor)
        return [:weapon,resolved.id] if resolved
      end
      value
    end
    def skill_scope(actor,skill)
      weapon=actor && actor.equips[0]
      granted=weapon && weapon.features.any? { |f| f.code==43 && f.data_id==skill.id }
      granted && !actor.skill_learn?(skill) ? weapon_scope(actor) : 'quick'
    end
    def source_weapon(actor,skill)
      current=actor && actor.equips[0]
      return current if current && current.features.any? { |f| f.code==43 && f.data_id==skill.id }
      BS2Suite::WeaponFamilies.owned(actor).find { |w| w.features.any? { |f| f.code==43 && f.data_id==skill.id } }
    end
    def set(scope,chord,kind,id,weapon_id=nil)
      return false unless valid?(scope,chord,kind,id)
      scope='weapon'+BS2Suite::WeaponFamilies.root(scope.sub('weapon','').to_i).to_s if scope=~/\Aweapon[0-9]+\z/
      value=[kind,id];value<<weapon_id if scope=='cast' && weapon_id
      previous=ensure_scope(scope).dup;data[scope][chord]=value
      return true if persist
      data[scope]=previous;false
    end
    def label(chord)
      return '' unless chord
      (chord.start_with?('CS') ? 'Ctrl+Shift+' : chord[0,1]=='S' ? 'Shift+' : 'Ctrl+')+chord[-1,1]
    end
    def persist
      text="version=2\n"
      data.keys.sort.each do |scope|
        text+='scope='+scope+"\n"
        data[scope].keys.sort.each { |key| text+='bind='+([scope,key]+data[scope][key]).join(',')+"\n" }
      end
      ok=BS2Modules.write_text(path,text);@error=ok ? nil : :write_failed;ok
    end
  end
end
