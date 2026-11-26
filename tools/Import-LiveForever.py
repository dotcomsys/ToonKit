"""Promote pinned licensed Forever facts. This is an importer, not a test runner."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import re
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / '.sources/content/forever-live-20261117'
SPY = 'e0752c03d792d6824cc1e28856a555104b4d5500'
ATT = 'aba13ac25c384edf481b2b2f0c6c827bbda618f5'
LIB = '1e2c39ce436068fc730b93784947429d63735f12'
ROSTER = [
 ('ragefire-chasm','Ragefire Chasm','ragefire_chasm'),
 ('hall-of-thanes','Hall of Thanes','the_hall_of_thanes'),
 ('ruins-of-lordaeron','Ruins of Lordaeron','ruins_of_lordaeron'),
 ('the-deadmines','The Deadmines','deadmines'),
 ('wailing-caverns','Wailing Caverns','wailing_caverns'),
 ('shadowfang-keep','Shadowfang Keep','shadowfang_keep'),
 ('blackfathom-deeps','Blackfathom Deeps','blackfathom_deeps'),
 ('the-stockade','Stormwind Stockade','stormwind_stockade'),
 ('razorfen-kraul','Razorfen Kraul','razorfen_kraul'),
 ('gnomeregan','Gnomeregan','gnomeregan'),
 ('excavation-site','Excavation Site: Wetlands','excavation_site_wetlands'),
 ('dalaran','City of Dalaran','city_of_dalaran'),
 ('scarlet-monastery','Scarlet Monastery','scarlet_monastery_graveyard scarlet_monastery_library scarlet_monastery_armory scarlet_monastery_cathedral'),
 ('razorfen-downs','Razorfen Downs','razorfen_downs'),
 ('the-drowned-city','The Drowned City','the_drowned_city'),
 ('uldaman','Uldaman','uldaman'),
 ('krol-dok-stronghold',"Krol'dok Stronghold",'krol_dok_stronghold'),
 ('maraudon','Maraudon','maraudon'),
 ('zul-farrak',"Zul'Farrak",'zulfarrak'),
 ('the-temple-of-atal-hakkar','Sunken Temple','sunken_temple'),
 ('alcaz-prison','Alcaz Prison','alcaz_prison'),
 ('blackrock-depths','Blackrock Depths','blackrock_depths'),
 ('blackrock-spire','Blackrock Spire','blackrock_spire_lower blackrock_spire_upper'),
 ('dire-maul','Dire Maul','dire_maul_east dire_maul_north dire_maul_west'),
 ('blackmaw-hold','Blackmaw Hold','blackmaw_hold'),
 ('stratholme','Stratholme','stratholme'),
 ('scholomance','Scholomance','scholomance'),
 ('the-shaper-s-terrace',"Shaper's Terrace",'the_shaper_s_terrace'),
]
records = []

def fetch(repo, revision, path):
    dest = INPUT / repo / revision / path
    if dest.exists():
        blob = dest.read_bytes()
    else:
        url = 'https://raw.githubusercontent.com/' + repo + '/' + revision + '/' + urllib.parse.quote(path)
        blob = urllib.request.urlopen(url, timeout=30).read()
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(blob)
    records.append(dict(repository=repo, revision=revision, file=path, sha256=hashlib.sha256(blob).hexdigest()))
    return blob.decode('utf-8')

def lua(value):
    if value is None: return 'nil'
    if value is True: return 'true'
    if value is False: return 'false'
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, list): return '{' + ','.join(lua(x) for x in value) + '}'
    return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k,v in value.items() if v is not None) + '}'

repo = 'Karl-HeinzSchneider/WoW-Spyglass'
tree_path=INPUT/repo/SPY/'tree.json'
if tree_path.exists():
    tree=json.loads(tree_path.read_text(encoding='utf-8'))
else:
    tree=json.load(urllib.request.urlopen('https://api.github.com/repos/' + repo + '/git/trees/' + SPY + '?recursive=1'))
    tree_path.parent.mkdir(parents=True,exist_ok=True)
    tree_path.write_text(json.dumps(tree,indent=2),encoding='utf-8')
paths = {x['path'] for x in tree['tree'] if x['type'] == 'blob'}
jobs = []
for _, _, stems in ROSTER:
    for stem in stems.split():
        for directory in ('dungeons/', 'quests/dungeons/'):
            path = '.contribute/data/' + directory + stem + '.json'
            if path in paths: jobs.append(path)
def read(path): return path, json.loads(fetch(repo, SPY, path))
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    data = dict(pool.map(read, jobs))
fetch(repo, SPY, 'LICENSE')
fetch('ATTWoWAddon/AllTheThings', ATT, 'LICENSE')
library = fetch('coffeelover1010/library-guide-forever', LIB, 'Books.lua')
fetch('coffeelover1010/library-guide-forever', LIB, 'LICENSE')
fetch('coffeelover1010/library-guide-forever', LIB, 'docs/data-sources-2026-11-08.md')
attbooks = fetch('ATTWoWAddon/AllTheThings', ATT, '.contrib/.db/forever/expansion features/library books.lua')
donations = set(int(x) for x in re.findall(r'^\s*(\d+),', attbooks.split('local allBookSourceQuests = {',1)[1].split('};',1)[0], re.M))
books = {int(i): (int(q) if q != 'false' else None) for i,q in re.findall(r'^\s*\{(\d+),(\d+|false),"', library, re.M)}
journals, quests = [], []
for slug, name, stems in ROSTER:
    d = dict(key=slug, slug=slug, name=name, encounters=[], maps=[], source='Spyglass Forever MIT', revision=SPY, availability='source-listed', foreverLive=True)
    qlist = dict(slug=slug, name=name, source='Spyglass Forever MIT', revision=SPY, foreverLive=True, alliance=[], horde=[])
    qseen = set()
    for stem in stems.split():
        source = data.get('.contribute/data/dungeons/' + stem + '.json', {})
        minimum, maximum = source.get('minLevel'), source.get('maxLevel')
        if minimum: d['min'] = min(d.get('min',minimum),minimum)
        if maximum: d['max'] = max(d.get('max',maximum),maximum)
        d.setdefault('background', source.get('background'))
        d.setdefault('backgroundCoords', source.get('backgroundCoords'))
        # Source map is a GameMap/instance ID, not a UIMap ID.
        d.setdefault('instanceID', source.get('map'))
        if source.get('map') and not any(m['instanceID']==source['map'] and m['name']==(source.get('name') or name) for m in d['maps']):
            d['maps'].append(dict(instanceID=source['map'],name=source.get('name') or name))
        d.setdefault('zoneMap', source.get('zone'))
        point = source.get('entrance')
        if isinstance(point,list) and len(point)>=3:
            d.setdefault('entrance',dict(map=point[0],x=point[1]/100,y=point[2]/100))
        for encounter in source.get('encounters',[]):
            e = {k: encounter[k] for k in ('id','name','npc','displayID','level') if k in encounter}
            e['wing'] = source.get('name')
            e['instanceID'] = source.get('map')
            e['loot'] = [dict(id=x['item'],name=x.get('name'),sourceKnown=True,foreverLive=True,provenance='Spyglass Forever MIT '+SPY) for x in encounter.get('loot',[]) if isinstance(x,dict) and x.get('item')]
            d['encounters'].append(e)
        qsource = data.get('.contribute/data/quests/dungeons/' + stem + '.json', {})
        for q in qsource.get('quests',[]):
            if q.get('id') in qseen: continue
            qseen.add(q.get('id'))
            r = dict(id=q.get('id'),title=q.get('name'),req=q.get('requiredLevel'),level=q.get('level') or q.get('requiredLevel'),side=q.get('side','both').lower(),goal=q.get('objective'),note=q.get('description'),foreverLive=True,source='Spyglass Forever MIT',revision=SPY)
            if q.get('class'): r['class']=str(q['class']).upper()
            if q.get('classes'): r['classes']=q['classes']
            r['rewardLayoutUnknown']=True
            needs=q.get('requires')
            if needs: r['prerequisites']=needs; r['needsId']=needs[0]
            for field,target,label in [('start','startAt','from'),('turnIn','turnInAt','turnIn')]:
                p=q.get(field) or {};r[label]=p.get('npc')
                loc=p.get('location')
                if isinstance(loc,list) and len(loc)>=3:r[target]=dict(map=loc[0],x=loc[1],y=loc[2],place=p.get('description') or p.get('npc'))
                elif p.get('description'):r[target]=dict(place=p['description'])
            # Author's prose contradicts its structured pickup. Do not produce a precise pickup pin.
            if r['id']==96772:r.pop('startAt',None);r['from']=None;r['note']='Pickup source is conflicting; use native quest evidence.'
            r['choice']=[dict(id=x['item'],name=x.get('name')) for x in q.get('items',[]) if isinstance(x,dict) and x.get('item')]
            qlist[len([k for k in qlist if isinstance(k,int)])+1]=r
    d['levelsUnknown']=not d.get('min') or not d.get('max')
    d['min']=d.get('min',1);d['max']=d.get('max',60);d['required']=d['min']
    qlist['min']=d['min'];qlist['max']=d['max'];qlist['zone']=None
    journals.append(d);quests.append(qlist)
output='local addonName, ns = ...\n-- Pinned current Forever authored facts, MIT. Reproduce with tools/Import-LiveForever.py.\n'
output+='ns.Data.liveForever = '+lua(dict(revision='forever-live-20261117',sourceBuild=70959,journals=journals,dungeons=quests,bookQuests=books,donationQuests={q:True for q in donations}))+'\n'
(ROOT/'ToonKit/Data/LiveForever.lua').write_text(output,encoding='utf-8')
collections=[]
quoted=r'"(?:\\.|[^"\\])*"'
pattern=r'^\s*\{(\d+),(\d+|false),('+quoted+r'),('+quoted+r'),(\d+|nil),([\d.]+|nil),([\d.]+|nil),('+quoted+r')'
for match in re.finditer(pattern,library,re.M):
    item,quest,name,zone,map_id,x,y,detail=match.groups()
    if quest=='false' or int(quest) not in donations: continue
    record=dict(id='library:'+item,item=int(item),quest=int(quest),name=json.loads(name),zone=json.loads(zone),detail=json.loads(detail),source='Library Guide Forever + ATT Forever MIT',foreverLive=True,availability='source-listed',locations=[])
    if map_id!='nil' and x!='nil' and y!='nil' and item!='210177':
        record.update(map=int(map_id),x=float(x)/100,y=float(y)/100)
        record['locations']=[dict(map=record['map'],x=record['x'],y=record['y'],confidence='community report')]
    if item in ('203754','208860','203755'): record['donationFaction']='Alliance'
    if item in ('208185','207972','210177'): record['donationFaction']='Horde'
    if item=='210177':record['detail']='Pickup coordinates disputed; no precise route offered.'
    if int(item) in (228132,228133,228134,228135,228136,228138,228140,228141):record['lateHandIn']=True
    collections.append(record)
(ROOT/'ToonKit/Data/Books.lua').write_text('local addonName, ns = ...\n-- Current pinned MIT donation identities; pickup confidence remains explicit.\nns.Data.collections = '+lua(collections)+'\n',encoding='utf-8')
manifest_path=ROOT/'ToonKit/SOURCE-MANIFEST.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
existing={(x.get('repository'),x.get('revision'),x.get('file')) for x in manifest['sources']}
for r in records:
    if (r['repository'],r['revision'],r['file']) not in existing:manifest['sources'].append(r)
manifest['liveIntegration']={'revision':'forever-live-20261117','sourceBuild':70959,'dungeonFamilies':28,'scope':'Current authored Forever dungeon/quest facts and library donation identity reconciliation; not witnessed live drops'}
manifest['counts'].update(lootInstances=len(journals),instancesWithLoot=sum(any(e['loot'] for e in d['encounters']) for d in journals),lootEncounters=sum(len(d['encounters']) for d in journals),bossDropLinks=sum(len(e['loot']) for d in journals for e in d['encounters']),corroboratedBossDrops=0,foreverDungeonQuestRecords=sum(sum(isinstance(k,int) for k in q) for q in quests),libraryBooks=len(collections),locatedBooks=sum('map' in r for r in collections),libraryLocations=sum(len(r['locations']) for r in collections),knownDonationQuests=len(collections))
manifest['counts'].update(talentsWithSpellIdentities=0,modeledTalentEffects=0,gearProfiles=0,gearProfileClasses=0,gearProfileBands=0,announcedDungeonNames=0,advisoryRoles=5)
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
for repository, revision, label in [(repo,SPY,'Spyglass-Live'),('ATTWoWAddon/AllTheThings',ATT,'ATT-Library-Live'),('coffeelover1010/library-guide-forever',LIB,'LibraryGuide-Live')]:
    blob=(INPUT/repository/revision/'LICENSE').read_text(encoding='utf-8')
    (ROOT/'ToonKit/Licenses'/ (label+'.txt')).write_text(repository+'\nRevision: '+revision+'\n\n'+blob,encoding='utf-8')
print('Promoted pinned licensed Forever authored facts; no test or packaging commands invoked.')
