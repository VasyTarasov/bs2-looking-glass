"""Compile a small, spoiler-separated runtime view of the supplied reference database."""
from pathlib import Path
import argparse,json,hashlib,re,sys,csv,collections
sys.dont_write_bytecode=True
from install import dump
P=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--reference',type=Path,required=True);parser.add_argument('--game',type=Path,required=True)
args=parser.parse_args();data=json.loads((args.reference/'reference.json').read_text(encoding='utf8'))
assert data['schema_version']==1
es={e['uid']:e for e in data['entities']}
incoming=collections.defaultdict(list)
for relation in data['relations']:incoming[relation['target']].append(relation)
checks=0
allowed={'Skills.rvdata2','Items.rvdata2','Weapons.rvdata2','Armors.rvdata2','States.rvdata2','System.rvdata2','CommonEvents.rvdata2'}
sources=[]
for src in data['source_manifest']['sources']:
 name=src['file'].replace('\\','/').split('/')[-1]
 if name not in allowed:continue
 actual=hashlib.sha256((args.game/'Data'/name).read_bytes()).hexdigest()
 assert actual==src['sha256'],f'Stale database: {name}'
 checks+=1;sources.append({'file':'Data/'+name,'sha256':actual})
assert len(sources)==7
PARAMS=['МаксHP','МаксMP','АТК','ЗАЩ','МАГ','МЗЩ','СКР','УДЧ']
event_briefs={3:'Возврат к последнему костру',18:'Возврат душ последней смерти',31:'Скрытность на карте: 150 шагов',36:'Возврат в Сон о Библиотеке; теряете души',48:'Сокращение КД группы на 5',218:'Сокращение КД группы на 99',220:'МаксHP +300, МаксMP +150, прочие +30; SEN +100',221:'МаксHP +10, МаксMP +5, прочие +1; SEN −10',222:'МаксHP +30, МаксMP +15, прочие +3; SEN −30',231:'SEN +30',232:'SEN −10',233:'Уровень +5 до предела',234:'Выбор SEN: 0 или 100',17:'Что-то Белое и Липкое ×10',288:'Возврат из Подземелья Хаоса',299:'Пропуск уровня Подземелья Хаоса (с условиями)',58:'Переход из обычного коридора в малый',59:'Переход из малого коридора в обычный'}
for id,p in enumerate([0,1,2,3,6,4,5,7],223):event_briefs[id]=PARAMS[p]+' +'+str(20 if p==0 else 10 if p==1 else 2)
currency={}
for e in es.values():
 if e['kind']!='event':continue
 commands=[c for c in e['raw'].get('list',[]) if c['code']!=0]
 if len(commands)==1 and commands[0]['code']==125 and commands[0]['parameters'][:2]==[0,0]:
  amount=commands[0]['parameters'][2]
  if isinstance(amount,int) and amount>0:currency[e['id']]=amount;event_briefs[e['id']]='Души +'+str(amount)
def sections(e,title):return [l for s in e['sections'] if s['title']==title for l in s['lines']]
def clean(s):return re.sub(r'\\[A-Za-z]+\[[^\]]*\]','',s).replace('\n',' ').strip()
def state_brief(id):
 if id==1:return 'смерть'
 e=es.get('state:'+str(id))
 if not e:return '?'
 props=sections(e,'Свойства')
 restriction=e['raw'].get('restriction',0)
 if restriction==4:
  rates={p['id']:p['value'] for p in e['mechanics']['features_aggregated'] if p['code']==23}
  if rates.get(6)==rates.get(7) and rates.get(6,1)>1:return clean(e['name'])+' (физ./маг. урон ×%g)'%rates[6]
  return clean(e['name'])+' (не может действовать)'
 useful=[p for p in props if re.match(r'(АТК|ЗАЩ|МАГ|МЗЩ|СКР|Крит|Реген\.|Получаемый|Доп\. действие|Физ\. уклонение)',p)]
 if useful:return clean(e['name'])+' ('+', '.join(useful[:2])+')'
 return clean(e['name'])
def effect_brief(e):
 code=e['code'];v=e.get('value1',0);id=e['data_id'];pct=lambda n:('%g'%(n*100))+'%'
 if code in [11,12]:
  values=[]
  if v:values.append(pct(v)+' макс.')
  if e.get('value2',0):values.append('%g'%e['value2'])
  return ('HP' if code==11 else 'MP')+' +'+('+'.join(values))
 if code==13:return 'TP %+g'%v
 if code in [21,22] and id:
  text=es.get('state:'+str(id),{}).get('name','?') if code==22 else state_brief(id)
  return ('снять ' if code==22 else '')+text+((' '+pct(v)+' баз.') if v<1 else '')
 if code in [31,32]:return PARAMS[id]+('↑' if code==31 else '↓')
 if code in [33,34]:return 'снять '+('усиление ' if code==33 else 'ослабление ')+PARAMS[id]
 if code==41:return 'побег'
 if code==42:return PARAMS[id]+' %+g'%v
 if code==43:return 'изучение: '+es['skill:'+str(id)]['name']
 return ''
def short(e):
 r=e['raw'];kind=e['kind'];parts=[]
 if kind in ['weapon','armor']:
  props=sections(e,'Свойства');special=sections(e,'Особенности')
  important=[s for s in props if not s.startswith(('Элемент обычной атаки: Физический','Открывает навык','Добавляет тип навыков'))]
  important.sort(key=lambda s:0 if any(z in s for z in ['Расход MP','действие','МАГ ×','СКР ×','АТК ×','Физ. урон','маг. урон','Реген.']) else 1)
  parts=important[:2]
  normal=next((s for s in special if s.startswith('Обычная атака заменяется')),None)
  if normal:
   sid=re.search(r'<攻撃ID変更[:：](\d+)>',r.get('note',''))
   a=es.get('skill:'+sid[1]) if sid else None
   if a:
    ar=a['raw'];shape=('случайные цели ×'+str(ar['scope']-2)) if ar['scope'] in range(3,7) else ('все враги' if ar['scope']==2 else 'одна цель')
    rep=ar['repeats'];parts.insert(0,'Атака: '+shape+(' ×'+str(rep) if rep>1 else ''))
   else:parts.insert(0,normal.replace('Обычная атака заменяется на ','Атака: '))
  if not parts or (len(parts)<3 and r.get('params')):
   stats=[PARAMS[i]+' %+g'%v for i,v in enumerate(r.get('params',[])) if v and i not in [0,1]]
   parts+=stats[:max(0,3-len(parts))]
  if not parts:parts=special[:2] or sections(e,'Кратко')[:1]
  parts=[('Новая очередь: '+s if s.startswith('Доп. действие') else s) for s in parts]
  return '; '.join(parts[:3]) or 'Особые условия применения · F7'
 d=r.get('damage',{});typ=d.get('type',0)
 if typ:
  label={1:'Урон HP',2:'Урон MP',3:'Лечение HP',4:'Лечение MP',5:'Поглощение HP',6:'Поглощение MP'}[typ]
  element=d.get('element_id',0)
  if element>0:label+=' · '+es['element:'+str(element)]['name']
  deps=re.findall(r'\ba\.(atk|mat|agi|def|mdf|mhp|hp|mp|mmp|luk)\b',d.get('formula',''))
  words={'atk':'АТК','mat':'МАГ','agi':'СКР','def':'ЗАЩ','mdf':'МЗЩ','mhp':'максHP','hp':'HP','mp':'MP','mmp':'максMP','luk':'УДЧ'}
  if deps:label+=' от '+'+'.join(dict.fromkeys(words[z] for z in deps))
  parts.append(label)
 effects=[effect_brief(z) for z in r.get('effects',[])];effects=[s for s in effects if s]
 removes=[z for z in r.get('effects',[]) if z['code']==22]
 if len(removes)>2:
  effects=[s for s in effects if not s.startswith('снять ')]+['снять '+str(len(removes))+' состояний']
 buffs=[z for z in r.get('effects',[]) if z['code'] in [31,32]]
 if len(buffs)>3:
  effects=[s for s in effects if s not in [PARAMS[z['data_id']]+('↑' if z['code']==31 else '↓') for z in buffs]]+['параметры '+('↑' if buffs[0]['code']==31 else '↓')+' ×'+str(len(buffs))]
 parts+=effects[:3 if not typ else 2]
 scope=r.get('scope',0)
 prefix={2:'Всем врагам: ',3:'Случайная цель: ',4:'Случайные цели ×2: ',5:'Случайные цели ×3: ',6:'Случайные цели ×4: ',7:'Союзнику: ',8:'Союзникам: ',9:'Павшему: ',10:'Павшим: ',11:'Себе: '}.get(scope,'')
 if r.get('repeats',1)>1:parts.insert(0,str(r['repeats'])+' повтор./цель')
 # These are derived from actual tags, never from misleading original prose.
 note=r.get('note','')
 if not re.search(r'\bb\.(def|mdf)\b',d.get('formula','')) and typ in [1,2,5,6]:
  if 'a.atk' in d.get('formula',''):parts.append('без вычета ЗАЩ')
 if re.search(r'<使用後追加行動[:：]',note):parts.append('доп. атака')
 if re.search(r'<(?:行動後)?遅延発動[:：]',note):parts.append('отложенный эффект')
 if re.search(r'<ステート変化[:：]',note):parts.append('вариант по состоянию')
 # Non-damage mechanics must not be reduced to an opaque internal state name.
 overrides={32:'КД всей группы −99',120:'Скрытность на карте: 150 шагов',308:'Себе: АТК ×1,5, крит +50 п.п.; самоурон и кровотечение',340:'Выбор скорости ходьбы',838:'Урон от МАГ; сильнее при малом остатке MP после оплаты',836:'Призыв союзника — мясного щита',100:'АТК ×5 без вычитания ЗАЩ; обход Guard 100%'}
 if kind=='skill' and e['id'] in overrides:return overrides[e['id']]
 events=[z['data_id'] for z in r.get('effects',[]) if z['code']==44]
 parts+=[event_briefs[id] for id in events if id in event_briefs]
 if not parts:
  if r.get('occasion')==3:
   rels=incoming[e['uid']]
   if any(z['relation']=='recipe_material' for z in rels):return 'Материал улучшения снаряжения'
   if any(z['relation']=='compose_material' for z in rels):return 'Материал синтеза'
   if kind=='item' and 'Ключ' in e['name']:return 'Ключ для сценарных замков; не применяется из меню'
   return 'Сценарный предмет; не применяется из меню'
  if any(z['code']==44 for z in r.get('effects',[])):return 'Особое действие · F7'
  return clean(sections(e,'Кратко')[0]) if sections(e,'Кратко') else 'Нет прямого урона или эффектов в записи'
 return prefix+'; '.join(dict.fromkeys(parts))
rows=[];audit=[];counts=collections.Counter()
for e in es.values():
 if e['kind'] not in ['skill','item','weapon','armor','state']:continue
 r=e['raw'];sec=[]
 for s in e['sections']:
  if s['title'] in ['Описание игры (оригинал)','Заточка / создание']:continue
  lines=[]
  for line in s['lines']:
   # "Оборона" means the guard state, not the DEF parameter.
   line=line.replace('Обход обороны:', 'Обход Guard на')
   line=line.replace('уменьшается в конце хода пользователя','уменьшается при общем завершении боевого хода')
   line=line.replace('возможен крит ×3','возможен крит; множитель определяется настройкой сложности')
   if e['uid']=='skill:100' and s['title']=='Кратко':line='АТК ×5 без вычитания ЗАЩ цели; отдельно обходит Guard на 100%.'
   if e['uid']=='skill:14' and s['title']=='Кратко':line='Световая магия по одному врагу; сила от МАГ. Текущая цена указана ниже.'
   if e['uid']=='skill:838':line=line.replace('после оплаты 1 MP','после оплаты навыка')
   lines.append(line)
  sec.append([s['title'],lines])
 if e['kind'] in ['skill','item']:
  for ef in r.get('effects',[]):
   if ef['code']==44 and ef['data_id'] in currency:
    sec.append(['Эффекты',['Получение душ: '+str(currency[ef['data_id']])+' за предмет.']])
 brief=short(e) if e['kind']!='state' else '; '.join(sections(e,'Свойства')[:3])
 if len(brief)>125:
  pieces=brief.split('; ');kept=[]
  for piece in pieces:
   if len('; '.join(kept+[piece]))>115:break
   kept.append(piece)
  brief='; '.join(kept)+'; … F7' if kept else re.sub(r'\s*\([^)]*\)','',brief)
 # Public UI payload excludes encounter lists, drop tables, map/event commands and acquisition locations.
 rows.append([e['uid'].encode(),e['name'].encode(),brief.encode(),[[str(a).encode(),str(b).encode()] for a,b in e['facts']],[[t.encode(),[l.encode() for l in ls]] for t,ls in sec],[s.encode() for s in e['issues']]])
 if not e['blank_name']:audit.append([e['uid'],e['name'],brief]);counts[e['kind']]+=1
 checks+=1
out=P/'mod/BS2Suite/reference098.rvdata2';out.write_bytes(b'\x04\x08'+dump([1,rows]))
v=P/'validation/0.9.8';v.mkdir(parents=True,exist_ok=True)
with (v/'short_descriptions.tsv').open('w',encoding='utf8',newline='') as f:
 w=csv.writer(f,delimiter='\t');w.writerow(['id','name','brief']);w.writerows(audit)
report={'result':'PASS','checks':checks,'source_schema':data['schema_version'],'source_game_version':data['source_manifest']['game_version'],'source_mod_version':data['source_manifest']['installed']['version'],'named_coverage':dict(counts),'runtime_entries':len(rows),'runtime_bytes':out.stat().st_size,'source_database_sha256':hashlib.sha256((args.reference/'reference.json').read_bytes()).hexdigest(),'source_files':sources,'excluded':'enemy AI, acquisition, loot, map events, raw descriptions'}
(v/'reference_build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(report,ensure_ascii=False))
