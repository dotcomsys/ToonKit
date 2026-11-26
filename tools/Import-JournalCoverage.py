"""Import pinned MIT dungeon identities, floor IDs and loot facts, without art/prose."""
from pathlib import Path
import hashlib
import json
import runpy
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools/python'))
from luaparser import ast
from luaparser import astnodes as N

REVISION = '8ea08d1064e165de13f1dd7e1dbf46b4f7f10cc6'
REPO = 'Torchlite-bit/Aegis_Forever_Instance_Journal'

def main():
    ctx = runpy.run_path(str(ROOT / 'tools/Import-Content.py'))
    cache = ROOT / '.sources/content/AegisCoverage'
    cache.mkdir(parents=True, exist_ok=True)
    manifest_path = ROOT / 'ToonKit/SOURCE-MANIFEST.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    def fetch(path):
        target = cache / path
        url = 'https://raw.githubusercontent.com/' + REPO + '/' + REVISION + '/' + path
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'ToonKit-content-import'}), timeout=30).read())
        raw = target.read_bytes(); digest = hashlib.sha256(raw).hexdigest()
        relative = 'AegisCoverage/' + path
        prior = next((s for s in manifest['sources'] if s.get('localFile') == relative), None)
        if prior:
            assert prior['sha256'] == digest and prior['revision'] == REVISION, target
        else:
            manifest['sources'].append({'url':url,'localFile':relative,'revision':REVISION,'license':'MIT; factual subset only','sha256':digest})
        return raw.decode('utf-8-sig')
    tree_path = cache / 'tree.json'
    if not tree_path.exists():
        url='https://api.github.com/repos/'+REPO+'/git/trees/'+REVISION+'?recursive=1'
        tree_path.write_bytes(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'ToonKit-content-import'}),timeout=30).read())
    tree = json.loads(tree_path.read_text(encoding='utf-8'))
    assert tree['sha'] == REVISION and not tree.get('truncated')
    tree_digest=hashlib.sha256(tree_path.read_bytes()).hexdigest()
    previous_tree=next((s for s in manifest['sources'] if s.get('localFile')=='AegisCoverage/tree.json'),None)
    if previous_tree: assert previous_tree['sha256']==tree_digest and previous_tree['revision']==REVISION
    else: manifest['sources'].append({'url':'https://api.github.com/repos/'+REPO+'/git/trees/'+REVISION+'?recursive=1','localFile':'AegisCoverage/tree.json','revision':REVISION,'sha256':tree_digest,'notice':'Pinned input inventory for offline reproduction'})
    records=[]
    for path in sorted(e['path'] for e in tree['tree'] if e['path'].startswith('Data/Instances/') and e['path'].endswith('.lua')):
        reader=ctx['Reader'](fetch(path),{})
        for node in ast.walk(reader.tree):
            if not isinstance(node,N.Call) or not isinstance(node.func,N.Index) or getattr(node.func.idx,'id',None)!='AddInstance': continue
            raw=reader.value(node.args[0])
            if not isinstance(raw,dict): continue
            floors=[f['uiMapID'] for f in ctx['sequence'](raw.get('map',{}).get('floors',{})) if isinstance(f.get('uiMapID'),int)]
            bosses=[]
            for b in ctx['sequence'](raw.get('bosses',{})):
                loot=sorted(set(i['itemID'] for i in ctx['sequence'](b.get('loot',{})) if isinstance(i.get('itemID'),int) and i['itemID']>0))
                bosses.append({'name':b['name'],'npc':b.get('npcID'),'displayID':b.get('displayID'),'loot':loot})
            records.append({'key':raw['key'],'name':raw['name'],'instanceID':raw.get('instanceID'),'floors':floors,'bosses':bosses})
    license=fetch('LICENSE');fetch('README.md');fetch('CREDITS.md')
    (ROOT/'ToonKit/Licenses/AegisCoverage-MIT.txt').write_text(license,encoding='utf-8')
    ctx['write']('JournalCoverage.lua','ns.Data.journalCoverage',records,'Aegis MIT factual instance, floor, boss and item identities only; no art, prose or availability inferred. '+REVISION)
    manifest['counts']['journalCoverageInstances']=len(records)
    manifest['counts']['journalCoverageBosses']=sum(len(r['bosses']) for r in records)
    manifest['counts']['journalCoverageLoot']=sum(len(b['loot']) for r in records for b in r['bosses'])
    manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('Journal coverage:',len(records),'instances;',manifest['counts']['journalCoverageBosses'],'boss identities;',manifest['counts']['journalCoverageLoot'],'loot facts')

if __name__=='__main__':main()
