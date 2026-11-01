"""Compile reviewed English Ruby string literals; fail on missing translations.

Russian source remains the canonical implementation. Generated English files have
the same control flow except for the explicitly listed locale/data adaptations.
No translation service or drawn-text substitution is used at runtime.
"""
from pathlib import Path
import argparse, hashlib, json, re
ROOT=Path(__file__).resolve().parents[1]
QUOTED=re.compile(r'''(?P<q>['"])(?P<text>(?:\\.|(?!(?P=q))[^\\\r\n])*)(?P=q)''')
CYR=re.compile('[А-Яа-яЁё]')

def compile_source(relative,text,mapping):
    if relative=='notes093.rb':
        # These obsolete handwritten summaries are superseded by CatalogUI in
        # every supported semantic configuration. Keep only the shared UI hook.
        text=re.sub(r'^  (SKILLS093|ITEMS093|WEAPONS093)=.*$',r'  \1={}.freeze',text,flags=re.M)
    def replace(m):
        value=m['text']
        if not CYR.search(value):return m[0]
        if value not in mapping:raise ValueError('Untranslated literal in '+relative+': '+value)
        translated=mapping[value]
        if CYR.search(translated):raise ValueError('Cyrillic in English translation')
        translated=re.sub(r'(?<!\\)'+re.escape(m['q']),lambda _: '\\'+m['q'],translated)
        return m['q']+translated+m['q']
    text=QUOTED.sub(replace,text)
    if relative=='modules/common.rb':
        # Native parameter labels and Guard share a Russian word, but have
        # different meanings. Use the exact English System terms here.
        text=re.sub(r'^  PARAMS = .*$',"  PARAMS = ['MaxHP','MaxMP','ATK','DEF','MAG','MDF','SPD','LCK']",text,flags=re.M)
        # The original English System table still has Japanese technical type
        # labels. Render those IDs without changing any game database values.
        groups={
          'element_name':['None','Physical','Absorb','Fire','Ice','Lightning','','','Vs sleep','Light','Dark','Double bleeding','Helbreath','Vs beasts','Vs Jabberwock','Double stun','Vs vulnerability','Falling','Vs poison','Vs rapiers'],
          'weapon_type':['','Axe','Claws','Spear','Sword','Katana','Bow','Dagger','Hammer','Staff','Gun'],
          'armor_type':['','General armor','Magic armor','Light armor','Heavy armor','Small shield','Large shield']}
        text+='\nmodule BS2Modules\n'
        for method,labels in groups.items():
            text+='  def self.'+method+'(id);names='+json.dumps(labels)+';value=id>=0 && names[id];value && !value.empty? ? value : "Type #"+id.to_s;end\n'
        text+='end\n'
        labels=json.loads((ROOT/'localization/saved-labels.json').read_text(encoding='utf8'))
        if any(key not in mapping or mapping[key]!=value or CYR.search(value) for key,value in labels.items()):
            raise ValueError('Unreviewed saved-label translation')
        pairs=[json.dumps(k,ensure_ascii=True)+'=>'+json.dumps(v,ensure_ascii=True) for k,v in sorted(labels.items())]
        text+='\nmodule BS2Suite::Locale\n  SAVED_LABELS={'+','.join(pairs)+'}.freeze\n'
        text+='''  def self.saved_label(value)
    return value unless value.is_a?(String)
    return SAVED_LABELS[value] if SAVED_LABELS.has_key?(value)
    numbered=/\\A(.+?)( [0-9]+)\\z/.match(value)
    return SAVED_LABELS[numbered[1]]+numbered[2] if numbered && SAVED_LABELS.has_key?(numbered[1])
    value.split(' / ').map { |part| SAVED_LABELS[part] || part }.join(' / ')
  end
  def self.saved_notice(value)
    text=saved_label(value)
    return text if text!=value || !defined?(BS2Suite::CatalogV1)
    move=/\\A([VBMN][0-9]{2} → [VBMN][0-9]{2}(?: ·)? )(.*)\\z/.match(text)
    return text unless move
    @saved_object_names ||= Hash[BS2Suite::CatalogV1.entries.map { |row| [row['names']['ru'],row['names']['en']] }]
    name=@saved_object_names[move[2]]
    name ? move[1]+name : text
  end
end
'''
    if relative=='modules/effects.rb':
        text=text.replace('$data_system.elements[id]', 'BS2Modules.element_name(id)')
        text=text.replace('$data_system.weapon_types[id]', 'BS2Modules.weapon_type(id)')
        text=text.replace('$data_system.armor_types[id]', 'BS2Modules.armor_type(id)')
    if relative=='input.rb':text=text.replace("'Skills'","'Techniques'")
    text=text.replace('%w(HP MP TP души)','%w(HP MP TP souls)')
    text=text.replace('language=:ru','language=:en').replace('locale=:ru','locale=:en')
    if relative=='equipment_details.rb':text=text.replace(':ru',':en')
    if relative=='qol/lib/reference.rb':
        text=text.replace('@language=:ru','@language=:en')
        # This is the English game variant; F8 must not introduce a mixed locale.
        text=text.replace('@language=value==:en ? :en : :ru','@language=:en')
    if relative=='catalog_ui099992.rb':
        text=text.replace("'Direct bonuses:'","'Flat item bonuses:'")
        text=text.replace(' : :ru;end',' : :en;end')
        # Classification uses the factual Russian field, not a translated UI key.
        text=text.replace("CatalogV1.inline(object,:ru).any? { |s| s.start_with?('Upgrade/crafting material') }", "CatalogV1.inline(object,:en).any? { |s| s.start_with?('Equipment upgrade/crafting material') }")
    if relative=='catalog_v1.rb':text=text.replace("'catalog_v1.rvdata2'","'catalog_v1.en.rvdata2'")
    if relative=='catalog_repair099994.rb':text=text.replace('|Physical evasion|','|Accuracy|Physical evasion|')
    if relative=='qol/lib/reference_window.rb':
        text=text.replace("BS2Suite::Keys.token(:language)+' RU / EN · '+",'')
    if relative=='reference098.rb':
        text=text.replace('value.to_s.empty? && row ? row[1] : value', "value.to_s.empty? ? @object.class.to_s.sub('RPG::','')+' #'+@object.id.to_s : value")
        text=text.replace('PracticalCard.new(object,actor,:ru)','PracticalCard.new(object,actor,:en)')
        text=text.replace('def brief(object);row=get(object);row && row[2];end',
                          'def brief(object);BS2Suite::CatalogV1.brief(object,:en);end')
        # The old static snapshot is Russian. Use the live translated decoder for
        # active effects, preserving action restrictions, timers and provenance.
        text=text.replace('rows=bs2098_verified_active(actor)', 'return bs2098_verified_active(actor)')
    if relative=='notes093.rb':
        text=text.replace(r'/ · \[последнее действие\]\z/',r'/ · \[final action\]\z/')
    if relative=='armor_families094.rb':
        text=text.replace('a.name==name+',"a.name.gsub(/\\s*\\+\\s*/,'+')==name+")
    return '# Generated by tools/build_localization.py; edit localization/en.json.\n'+text

def build(check=False):
    source=ROOT/'mod/BS2Suite';out=source/'en'
    mapping=json.loads((ROOT/'localization/en.json').read_text(encoding='utf8'))
    files={}
    for p in sorted(source.rglob('*.rb')):
        if out in p.parents or p.name=='main.rb':continue
        relative=p.relative_to(source).as_posix()
        result=compile_source(relative,p.read_text(encoding='utf8'),mapping).encode('utf8')
        # Include all files, including arithmetic-only files, so completeness is
        # deterministic and an English install never silently loads stale code.
        target=out/relative
        if check:
            if not target.is_file() or target.read_bytes()!=result:raise ValueError('Stale English source: '+relative)
        else:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(result)
        files[relative]={'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'en_sha256':hashlib.sha256(result).hexdigest()}
    manifest={'format':1,'locale':'en','files':files,'translations_sha256':hashlib.sha256((ROOT/'localization/en.json').read_bytes()).hexdigest()}
    path=ROOT/'localization/compiled.json';data=(json.dumps(manifest,indent=2)+'\n').encode('utf8')
    if check:
        if path.read_bytes()!=data:raise ValueError('Stale localization manifest')
    else:path.write_bytes(data)
    return {'result':'PASS','files':len(files),'checked':check}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();print(json.dumps(build(a.check)))
