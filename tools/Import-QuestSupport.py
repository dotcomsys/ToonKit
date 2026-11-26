"""Pinned MIT quest facts for supply advice; no upstream addon code is executed."""
from pathlib import Path
import hashlib, json, re, urllib.request
from concurrent.futures import ThreadPoolExecutor
from luaparser import ast
from luaparser import astnodes as N

EQ = "76000b2ab05ed1684f465b61bfdd07eb30dff1e3"
def build(ctx):
    tree=json.loads((ctx.ROOT/'.sources/AllTheThings-tree.json').read_text())
    paths=sorted(x['path'] for x in tree['tree'] if x['path'].startswith('.contrib/.db/forever/zones/') and x['path'].endswith('.lua'))
    with ThreadPoolExecutor(max_workers=6) as pool:
        texts=list(pool.map(lambda p:ctx.source('ATTWoWAddon/AllTheThings',ctx.ATT,p),paths))
    quests={}
    objective_items={}
    cost_items={}
    referenced_items={}
    for text,path in zip(texts,paths):
        # This authored helper expands literal calls into quest definitions.
        # Its body uses argument names, which are not quest IDs.
        if path.lower().endswith('/eastern plaguelands.lua'):
            for match in re.finditer(
                r'CRAFTSMANS_WRIT_QUEST\((\d+),\s*\d+,\s*\{\s*"i",\s*(\d+),\s*(\d+)\s*\}\),\s*--\s*([^\r\n]+)', text
            ):
                ident,item,count=map(int,match.groups()[:3])
                cost_items[ident]={item:count}
                quests[ident]={'name':match[4].strip(),'items':{item:count},
                    'rewards':[22524,22523],'repeatable':True,'source':path}
        reader=ctx.Reader(text,{})
        for call in ast.walk(reader.tree):
            if not isinstance(call,N.Call) or not isinstance(call.func,N.Name) or call.func.id!='q':continue
            q=reader.value(call)
            if not isinstance(q,dict) or not isinstance(q.get('_id'),int) or q['_id']<=0 or ctx.forbidden(q):continue
            requirements={}
            for cost in ctx.sequence(q.get('cost',{})):
                if isinstance(cost,dict) and cost.get(1)=='i' and isinstance(cost.get(2),int) and isinstance(cost.get(3),int):
                    requirements[cost[2]]=cost[3]
                    cost_items.setdefault(q['_id'],{})[cost[2]]=cost[3]
            # Item objective identities are explicit; absent counts stay unknown.
            for objective in ctx.children(q):
                if not isinstance(objective,dict) or objective.get('_kind')!='objective':continue
                raw=objective.get('providers',{})
                providers=[raw] if isinstance(raw,dict) and isinstance(raw.get(1),str) else ctx.sequence(raw)
                if objective.get('provider'):providers.append(objective['provider'])
                items=[]
                for provider in providers:
                    if isinstance(provider,dict) and provider.get(1)=='i' and isinstance(provider.get(2),int):
                        target=objective.get('questID',q['_id'])
                        if target==q['_id']:requirements.setdefault(provider[2],0)
                        else:referenced_items.setdefault(target,set()).add(provider[2])
                        items.append(provider[2])
                if items and isinstance(objective.get('_id'),int):
                    target=objective.get('questID',q['_id'])
                    existing=objective_items.setdefault(target,{}).get(objective['_id'],[])
                    objective_items[target][objective['_id']]=sorted(set(existing+items))
            rewards=[v['_id'] for v in ctx.children(q) if isinstance(v,dict) and v.get('_kind')=='i' and isinstance(v.get('_id'),int) and not ctx.forbidden(v)]
            if requirements or rewards:
                quests[q['_id']]={'name':q.get('_name'),'items':requirements,'rewards':rewards,'repeatable':q.get('repeatable') is True,'source':path}
    def fetch(path):
        local=ctx.CACHE/'EverythingQuests'/path
        if not local.exists():
            local.parent.mkdir(parents=True,exist_ok=True)
            local.write_bytes(urllib.request.urlopen('https://raw.githubusercontent.com/wheelbarrel00/EverythingQuests/'+EQ+'/'+path).read())
        raw=local.read_bytes();ctx.manifest['sources'].append({'repository':'wheelbarrel00/EverythingQuests','revision':EQ,'file':path,'sha256':hashlib.sha256(raw).hexdigest(),'license':'MIT'})
        return raw.decode('utf-8-sig')
    data=fetch('Data/QuestAvailable_Forever.lua');reader=ctx.Reader(data,{})
    fetch('Data/QuestTurnIn_Forever.lua')
    table=None
    for statement in reader.tree.body.body:
        if isinstance(statement,N.Assign) and isinstance(statement.targets[0],N.Index) and statement.targets[0].idx.id=='CLASSIC_QUEST_AVAILABLE':table=reader.value(statement.values[0]);break
    assert table and table.get('names')
    meta={}
    for ident,name in table['names'].items():
        gate=table.get('gates',{}).get(ident,0)
        minimum=gate//100000000000;level=(gate//1000000000)%100
        if minimum>60 or level>60:continue
        start=table.get('start',{}).get(ident,{})
        meta[ident]={'name':name,'min':minimum,'level':level,'races':(gate//10000)%10000,'classes':gate%10000,
            'pre':ctx.sequence(table.get('pre',{}).get(ident,{})),'preAll':ctx.sequence(table.get('preAll',{}).get(ident,{})),
            'excl':ctx.sequence(table.get('excl',{}).get(ident,{})),'chain':table.get('chain',{}).get(ident),
            'parent':table.get('parent',{}).get(ident),'skill':table.get('skill',{}).get(ident),
            'minRep':table.get('minRep',{}).get(ident),'maxRep':table.get('maxRep',{}).get(ident),
            'maps':sorted(k for k in start if isinstance(k,int))}
    for ident,items in referenced_items.items():
        q=quests.setdefault(ident,{'name':meta.get(ident,{}).get('name'),'items':{},'rewards':[],'repeatable':False,'source':'Explicit ATT objective questID reference'})
        for item in items:q['items'].setdefault(item,0)
    (ctx.DEST/'Licenses/EverythingQuests-MIT.txt').write_text(fetch('LICENSE'),encoding='utf-8')
    ctx.write('QuestSupport.lua','ns.Data.questSupport',{'quests':quests,'meta':meta,'objectiveItems':objective_items,'costItems':cost_items},'AllTheThings Forever + EverythingQuests Forever, MIT. Source-listed item requirements; zero means quantity not supplied. Classic-derived records are references, not observed completion.')
    ctx.manifest['counts']['questSupplyRecords']=len(quests)
    ctx.manifest['counts']['questSupplyItemLinks']=sum(len(q['items']) for q in quests.values())
    ctx.manifest['counts']['foreverQuestMetadata']=len(meta)
