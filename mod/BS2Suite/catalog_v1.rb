# encoding: UTF-8
# Generated factual catalog reader. No game action, formula evaluation or UI hook.
module BS2Suite
  module CatalogV1
    TYPES={'RPG::Skill'=>'skill','RPG::Item'=>'item','RPG::Weapon'=>'weapon','RPG::Armor'=>'armor','RPG::State'=>'state'}.freeze
    class << self
      def normalize(value,cache={})
        return cache[value.object_id] if cache.has_key?(value.object_id)
        case value
        when String
          result=value.dup.force_encoding('UTF-8')
          raise 'Invalid catalog text' unless result.valid_encoding?
        when Array
          result=[];cache[value.object_id]=result
          value.each { |item| result<<normalize(item,cache) }
        when Hash
          result={};cache[value.object_id]=result
          value.each { |key,item| result[normalize(key,cache)]=normalize(item,cache) }
        when Numeric,TrueClass,FalseClass,NilClass
          result=value
        else
          raise 'Non-primitive catalog value'
        end
        cache[value.object_id]=result.freeze
      end
      def load
        return @data if @data
        path=File.join(BS2Suite::ROOT,'catalog_v1.rvdata2')
        raise 'Catalog file is missing or excessive' unless File.file?(path) && File.size(path)<24*1024*1024
        data=File.open(path,'rb') { |file| Marshal.load(file) }
        raise 'Unsupported catalog schema' unless data.is_a?(Hash) && data['metadata'] && data['metadata']['schema_version']==1
        data=normalize(data)
        rows=data['entries']
        raise 'Invalid catalog entries' unless rows.is_a?(Array)
        index={}
        rows.each do |entry|
          uid=entry['uid']
          raise 'Invalid or duplicate catalog identity' unless uid.is_a?(String) && uid=~/\A(?:skill|item|weapon|armor|state):[1-9][0-9]*\z/ && !index.has_key?(uid)
          index[uid]=entry
        end
        expected=data['metadata']['counts'].values.inject(0) { |sum,n| sum+n }
        raise 'Incomplete catalog' unless expected==index.size
        @index=index.freeze;@data=data
      end
      def metadata;load['metadata'];end
      def uid(object)
        return object if object.is_a?(String)
        type=object && TYPES[object.class.to_s]
        type && type+':'+object.id.to_s
      end
      def entry(object)
        load;@index[uid(object)]
      end
      def entries;load['entries'];end
      def language(value);value.to_s=='en' ? 'en' : 'ru';end
      def display(object,locale=:ru)
        row=entry(object);row && row['display'][language(locale)]
      end
      def inline(object,locale=:ru)
        value=display(object,locale);value ? value['lines'].dup : []
      end
      def required_lines(object,locale=:ru)
        value=display(object,locale);value ? value['required_lines'].dup : []
      end
      def brief(object,locale=:ru)
        value=display(object,locale);value && value['brief']
      end
      def sections(object,locale=:ru)
        row=entry(object);row ? row['details'][language(locale)] : []
      end
      def normal_attack(object)
        row=entry(object);row && row['normal_attack']
      end
      # Pass the current Game_Action (or its item) for the actual selected
      # variant. A Weapon alone describes its neutral, intrinsic attack.
      def formula_panel(object,locale=:ru)
        object=object.item if defined?(Game_Action) && object.is_a?(Game_Action)
        row=entry(object)
        return nil unless row
        row=entry(row['normal_attack']['source_uid']) if row['kind']=='weapon' && row['normal_attack']
        damage=row && row['damage']
        return nil unless damage
        panel=damage['presentation'][language(locale)].dup
        panel['source_uid']=row['uid'];panel['raw']=damage['formula']['raw']
        panel['damage_type']=damage['formula']['type']
        panel['repeats']=damage['repeats'];panel['hit_type']=damage['hit_type']
        panel['variance']=damage['formula']['variance'];panel['critical']=damage['formula']['critical']
        panel.freeze
      end
      def relations;load['relations'];end
      def recipes;load['recipes'];end
    end
  end
end
