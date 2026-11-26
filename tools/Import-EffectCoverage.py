"""Build original numeric effect coverage from pinned Wago client-table facts.

No ratings, guessed proc rates, simulator code or hypothetical equipment are imported.
The compact input snapshot is sufficient to regenerate the runtime data offline.
"""
from pathlib import Path
import collections
import csv
import hashlib
import json
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
TABLES = ('ItemSparse','ItemEffect','ItemXItemEffect','SpellEffect','SpellMisc',
          'SpellDuration','SpellAuraOptions','SpellProcsPerMinute','SpellCooldowns','ItemSetSpell')
ATTR = {0:'ITEM_MOD_STRENGTH_SHORT',1:'ITEM_MOD_AGILITY_SHORT',2:'ITEM_MOD_STAMINA_SHORT',
        3:'ITEM_MOD_INTELLECT_SHORT',4:'ITEM_MOD_SPIRIT_SHORT'}

def num(row,key): return float(row.get(key) or 0)
def integer(row,key): return int(num(row,key))
def lua(v):
    if v is None:return 'nil'
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,(int,float)):return str(v)
    if isinstance(v,str):return json.dumps(v,ensure_ascii=True)
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'

def snapshot(build, seed_items=None):
    path=ROOT/'.sources/content'/('effect-facts-'+build+'.json')
    if path.exists():
        existing=json.loads(path.read_text(encoding='utf-8'))
        if not seed_items and existing.get('schema')==3:return path,existing
        if seed_items and existing.get('schema')==4 and existing.get('seedItems')==sorted(seed_items):return path,existing
    cache=ROOT/'.sources/research'/('client-'+build.split('.')[-1]);cache.mkdir(parents=True,exist_ok=True)
    tables={};sources=[]
    for name in TABLES:
        p=cache/(name+'.csv');url='https://wago.tools/db2/'+name+'/csv?build='+build
        if not p.exists():
            p.write_bytes(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'ToonKit-source-research'}),timeout=120).read())
        sources.append({'url':url,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        with p.open(encoding='utf-8-sig',newline='') as f:tables[name]=list(csv.DictReader(f))
    items={integer(r,'ID'):r for r in tables['ItemSparse'] if integer(r,'InventoryType') not in (0,4,18,19,24,27,28) and 0<=integer(r,'RequiredLevel')<=60}
    if seed_items:
        for iid in seed_items:
            if iid not in items:items[iid]={'ID':str(iid),'ItemSet':'0','AllowableClass':'0','RequiredLevel':'-1'}
    links=[r for r in tables['ItemXItemEffect'] if integer(r,'ItemID') in items]
    effectids={integer(r,'ItemEffectID') for r in links}
    effects=[r for r in tables['ItemEffect'] if integer(r,'ID') in effectids]
    sets={integer(r,'ItemSet') for r in items.values()}-{0}
    setspells=[r for r in tables['ItemSetSpell'] if integer(r,'ItemSetID') in sets]
    spells={integer(r,'SpellID') for r in effects+setspells}
    for _ in range(8):
        children={integer(r,'EffectTriggerSpell') for r in tables['SpellEffect'] if integer(r,'SpellID') in spells}-{0}
        if children<=spells:break
        spells|=children
    selected={'ItemSparse':[{k:r[k] for k in ('ID','ItemSet','AllowableClass','RequiredLevel')} for r in items.values()],'ItemXItemEffect':links,'ItemEffect':effects,'ItemSetSpell':setspells}
    for name in ('SpellEffect','SpellMisc','SpellAuraOptions','SpellCooldowns'):
        selected[name]=[r for r in tables[name] if integer(r,'SpellID') in spells and integer(r,'DifficultyID')==0]
    for name in ('SpellDuration','SpellProcsPerMinute'):selected[name]=tables[name]
    data={'schema':4 if seed_items else 3,'build':build,'sources':sources,'tables':selected}
    if seed_items:data['seedItems']=sorted(seed_items)
    path.write_text(json.dumps(data,separators=(',',':')),encoding='utf-8');return path,data

def compile(data):
    t=data['tables'];build=data['build'];effects=collections.defaultdict(list)
    for r in t['SpellEffect']:effects[integer(r,'SpellID')].append(r)
    misc={integer(r,'SpellID'):r for r in t['SpellMisc']}
    opts={integer(r,'SpellID'):r for r in t['SpellAuraOptions']}
    cds={integer(r,'SpellID'):r for r in t['SpellCooldowns']}
    durations={integer(r,'ID'):num(r,'Duration')/1000 for r in t['SpellDuration']}
    ppms={integer(r,'ID'):num(r,'BaseProcRate') for r in t['SpellProcsPerMinute'] if integer(r,'Flags')==0}
    ies={integer(r,'ID'):r for r in t['ItemEffect']};links=collections.defaultdict(list)
    for r in t['ItemXItemEffect']:links[integer(r,'ItemID')].append(ies[integer(r,'ItemEffectID')])
    source='Client '+build+' numeric ItemEffect/SpellEffect tables (wago.tools)'
    def spell(sid,depth=0):
        models=[];unknown=[]
        if depth>5 or sid not in misc:return [],['Spell #'+str(sid)+' is missing or recursively scripted']
        duration=durations.get(integer(misc[sid],'DurationIndex'),0)
        if integer(opts.get(sid,{}),'CumulativeAura')>1:
            return [],['Stacking aura #'+str(sid)+' requires a stack/refresh model']
        for r in sorted(effects[sid],key=lambda r:integer(r,'EffectIndex')):
            effect,aura=integer(r,'Effect'),integer(r,'EffectAura');amount=num(r,'EffectBasePointsF')
            model={'amount':amount,'source':source,'spell':sid,'school':integer(misc[sid],'SchoolMask')}
            if num(misc[sid],'LaunchDelay'):model['launchDelay']=num(misc[sid],'LaunchDelay')
            if num(misc[sid],'Speed'):model['projectileSpeed']=num(misc[sid],'Speed')
            target=integer(r,'ImplicitTarget_0')
            # Per-level/resource/curve scaling requires an explicit model, not a guessed base value.
            if any(num(r,k)!=0 for k in ('EffectRealPointsPerLevel','EffectPointsPerResource','ScalingClass','Coefficient','ResourceCoefficient')):
                unknown.append('Spell #'+str(sid)+' has level/resource/curve scaling');continue
            if integer(r,'EffectChainTargets')>1 or integer(r,'EffectRadiusIndex_0') or integer(r,'EffectRadiusIndex_1'):
                unknown.append('Spell #'+str(sid)+' needs a target-count/area model');continue
            if effect in (64,142) and integer(r,'EffectTriggerSpell'):
                child,why=spell(integer(r,'EffectTriggerSpell'),depth+1);models+=child;unknown+=why;continue
            if effect in (2,9,10,30):
                if effect in (2,9) and target not in (6,25):
                    unknown.append('Damage target/self-damage #'+str(sid)+' needs explicit handling');continue
                if effect in (10,30) and target not in (1,21,25):
                    unknown.append('Healing/resource target #'+str(sid)+' needs explicit handling');continue
                if effect==30 and integer(r,'EffectMiscValue_0')!=0:
                    unknown.append('Non-mana resource effect #'+str(sid));continue
                model['kind']='damage' if effect in (2,9) else 'healing' if effect==10 else 'mana'
                model['spellCoefficient']=num(r,'EffectBonusCoefficient');model['apCoefficient']=num(r,'BonusCoefficientFromAP')
                if effect==9:unknown.append('Leech healing component #'+str(sid)+' needs effective-healing context')
                models.append(model);continue
            if effect==6 and aura in (3,8,24):
                if aura==3 and target not in (6,25) or aura in (8,24) and target not in (1,21,25):
                    unknown.append('Periodic target #'+str(sid)+' needs explicit handling');continue
                period=num(r,'EffectAuraPeriod')/1000
                if duration<=0 or period<=0:unknown.append('Unknown periodic timing #'+str(sid));continue
                if aura==24 and integer(r,'EffectMiscValue_0')!=0:unknown.append('Non-mana periodic resource #'+str(sid));continue
                model.update(kind={3:'damage',8:'healing',24:'mana'}[aura],period=period,duration=duration,
                             spellCoefficient=num(r,'EffectBonusCoefficient'),apCoefficient=num(r,'BonusCoefficientFromAP'))
                models.append(model);continue
            stat=None
            if effect==6 and aura==29:stat=ATTR.get(integer(r,'EffectMiscValue_0'))
            if effect==6 and aura==29 and integer(r,'EffectMiscValue_0')==-1:
                if target!=1:unknown.append('Non-self all-stat target #'+str(sid));continue
                for value in ATTR.values():models.append(dict(model,kind='stat',stat=value,duration=max(0,duration)))
                continue
            if effect==6 and aura==99:stat='ITEM_MOD_ATTACK_POWER_SHORT'
            if effect==6 and aura==13 and integer(r,'EffectMiscValue_0') & 126==126:stat='ITEM_MOD_SPELL_POWER_SHORT'
            if effect==6 and aura==13 and integer(r,'EffectMiscValue_0') & 126 and integer(r,'EffectMiscValue_0') & 126!=126:
                if target!=1:unknown.append('Non-self school damage #'+str(sid));continue
                model.update(kind='schoolDamage',mask=integer(r,'EffectMiscValue_0'),duration=max(0,duration));models.append(model);continue
            if stat:
                if target!=1:unknown.append('Non-self stat target #'+str(sid));continue
                model.update(kind='stat',stat=stat,duration=max(0,duration));models.append(model);continue
            if effect==0:continue
            unknown.append('Spell #'+str(sid)+' effect '+str(effect)+'/aura '+str(aura)+' needs a specific model')
        if not effects[sid]:unknown.append('No numeric effects for spell #'+str(sid))
        return models,unknown
    def trigger(sid,ie):
        kind=integer(ie,'TriggerType');opt=opts.get(sid,{})
        observed=(data.get('foreverObservedRates') or {}).get(str(integer(ie,'ID')))
        if integer(ie,'PlayerConditionID') or integer(ie,'ChrSpecializationID'):
            return [],['Item effect has a client condition/spec restriction']
        proc=[r for r in effects[sid] if integer(r,'EffectAura')==42 and integer(r,'EffectTriggerSpell')]
        if proc:
            if len(proc)!=len([r for r in effects[sid] if integer(r,'Effect')!=0]):return [],['Compound proc wrapper #'+str(sid)]
            models=[];why=[]
            for r in proc:
                child,w=spell(integer(r,'EffectTriggerSpell'));models+=child;why+=w
            probability=num(opt,'ProcChance')/100;ppm=observed['ppm'] if observed else ppms.get(integer(opt,'SpellProcsPerMinuteID'),0)
            # A nominal 100/101% often dispatches a server script; never reinterpret as guaranteed.
            if ppm<=0 and not 0<probability<1:return [],why+['Server proc rate is not specified for #'+str(sid)]
            mask=integer(opt,'ProcTypeMask_0');supported=0x4|0x10|0x8|0x20|0x40|0x100|0x1000|0x10000|0x40000
            if mask==0 or mask & ~supported or integer(opt,'ProcTypeMask_1'):return [],why+['Unsupported proc event mask #'+str(sid)]
            event='struck' if mask & (0x8|0x20) else 'spell' if mask & (0x1000|0x10000|0x40000) else 'ranged' if mask & (0x40|0x100) else 'melee'
            families=sum(bool(mask & family) for family in (0x8|0x20,0x1000|0x10000|0x40000,0x40|0x100,0x4|0x10))
            if families!=1:return [],why+['Mixed proc event families #'+str(sid)+' require a combined event model']
            for m in models:
                m.update(trigger='proc',icd=num(opt,'ProcCategoryRecovery')/1000,event=event,activation=sid)
                if mask & (0x8|0x20) and mask & ~(0x8|0x20):
                    why.append('Mixed incoming/outgoing proc events #'+str(sid));m['unsupported']=True
                if observed:m.update(rateSource=observed['source'],rateConfidence=observed['confidence'],rateExcludeFeral=True,rateCondition=observed.get('condition'))
                if ppm>0:m['ppm']=ppm
                else:m['chance']=probability
                if m.get('period') and (not ppm or 0<num(opt,'ProcCategoryRecovery')/1000<m.get('duration',0)):why.append('Periodic proc refresh/stacking #'+str(sid)+' needs explicit modeling');m['unsupported']=True
            return [m for m in models if not m.get('unsupported')],why
        models,why=spell(sid)
        if kind==2:
            rate=(data.get('foreverObservedRates') or {}).get(str(integer(ie,'ID')))
            if not rate:return [],why+['Chance-on-hit rate is not specified for #'+str(sid)]
            for m in models:m.update(trigger='proc',ppm=rate['ppm'],icd=rate.get('icd',0),event=rate['event'],activation=sid,rateSource=rate['source'],rateConfidence=rate['confidence'],rateExcludeFeral=True,rateCondition=rate.get('condition'))
            return models,why
        if kind not in (0,1):return [],why+['Unsupported item trigger '+str(kind)]
        for m in models:
            m['activation']=sid
            m['trigger']='use' if kind==0 else 'passive'
            if kind==0:
                if integer(ie,'Charges')!=0:
                    m['unsupported']=True;why.append('Charged/consumable use #'+str(sid)+' requires a charge budget')
                cd=max(num(ie,'CoolDownMSec'),num(cds.get(sid,{}),'RecoveryTime'))/1000
                shared=num(ie,'CategoryCoolDownMSec')/1000
                if cd<=0:m['unsupported']=True;why.append('Use cooldown not specified for #'+str(sid))
                else:m['cooldown']=cd
                if shared>0 and integer(ie,'SpellCategoryID'):
                    m.update(group='client-category:'+str(integer(ie,'SpellCategoryID')),sharedCooldown=shared)
            elif m['kind'] not in ('stat','schoolDamage'):
                m['unsupported']=True;why.append('Passive output effect requires its event/target context #'+str(sid))
        return [m for m in models if not m.get('unsupported')],why
    items={}
    for r in t['ItemSparse']:
        iid=integer(r,'ID');models=[];why=[]
        for ie in links[iid]:
            new,w=trigger(integer(ie,'SpellID'),ie);models+=new;why+=w
        if links[iid]:items[iid]={'models':models,'unknown':sorted(set(why)),'set':integer(r,'ItemSet'),'classMask':integer(r,'AllowableClass'),'required':integer(r,'RequiredLevel')}
    sets={}
    for r in t['ItemSetSpell']:
        sid=integer(r,'SpellID');models,why=spell(sid)
        for m in models:
            m['trigger']='passive'
            if m['kind'] not in ('stat','schoolDamage'):m['unsupported']=True;why.append('Set effect requires specific trigger #'+str(sid))
        if integer(r,'ChrSpecID') or integer(r,'TraitSubTreeID'):why.append('Set bonus has a specialization condition');models=[]
        sets.setdefault(integer(r,'ItemSetID'),[]).append({'threshold':integer(r,'Threshold'),'models':[m for m in models if not m.get('unsupported')],'unknown':sorted(set(why)),'spell':sid})
    return {'build':build.split('.')[-1],'items':items,'sets':sets}

def main():
    manifest=ROOT/'ToonKit/SOURCE-MANIFEST.json';data=json.loads(manifest.read_text(encoding='utf-8'));snapshots={}
    for build in ('1.60.1.70170','1.60.1.70450'):
        path,facts=snapshot(build);snapshots[build.split('.')[-1]]=compile(facts)
        entry={'url':'https://wago.tools/db2','localFile':path.name,'generated':'2026-10-21','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        data['sources']=[v for v in data['sources'] if v.get('localFile')!=path.name]+[entry]
        compiled=snapshots[build.split('.')[-1]]
        print(build,len(compiled['items']),'items;',sum(bool(v['models']) for v in compiled['items'].values()),'with modeled effects;',len(compiled['sets']),'sets')
    (ROOT/'ToonKit/Data/EffectCoverage.lua').write_text('local addonName, ns = ...\n-- Generated numeric client facts; availability is NOT inferred from this file.\nns.Data.effectCoverage='+lua(snapshots)+'\n',encoding='utf-8')
    manifest.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
