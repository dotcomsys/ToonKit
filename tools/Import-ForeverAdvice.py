"""Generate exact-build Forever effect facts; does not run tests or touch releases."""
from pathlib import Path
import hashlib
import importlib.util
import json
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('effect_import',ROOT/'tools/Import-EffectCoverage.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
BUILD='1.60.1.70959'
rate_path=ROOT/'.sources/content/forever-proc-rates-20261118.json'
rate_data=json.loads(rate_path.read_text(encoding='utf-8'))
path,facts=module.snapshot(BUILD,rate_data['seedItemIDs'])
# Overlay measured rates on matching native item effects only; client amounts remain native.
overrides={};effects={int(v['ID']):v for v in facts['tables']['ItemEffect']}
for link in facts['tables']['ItemXItemEffect']:
    observation=rate_data['rates'].get(str(link['ItemID']))
    effect=effects.get(int(link['ItemEffectID']))
    if observation and effect and int(effect['SpellID'])==observation['spell']:
        overrides[str(effect['ID'])]={**observation,'source':rate_data['source']}
facts['foreverObservedRates']=overrides
compiled=module.compile(facts)
compiled['observedRatesJoined']=len(overrides)
output=ROOT/'ToonKit/Data/ForeverAdviceFacts.lua'
output.write_text('local addonName, ns = ...\n-- Exact Forever client build; no cross-build or Classic fallback.\nns.Data.foreverAdviceFacts='+module.lua({compiled['build']:compiled})+'\n',encoding='utf-8')
manifest=ROOT/'ToonKit/SOURCE-MANIFEST.json';data=json.loads(manifest.read_text(encoding='utf-8'))
entry={'url':'https://wago.tools/db2','localFile':path.name,'generated':'2026-11-18','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'purpose':'Exact-build Forever item effects for automatic item advice'}
rate_entry={'repository':rate_data['repository'],'revision':rate_data['revision'],'file':rate_data['evidenceFile'],'localFile':rate_path.name,'generated':'2026-11-18','license':'MIT','sha256':hashlib.sha256(rate_path.read_bytes()).hexdigest()}
data['sources']=[v for v in data['sources'] if v.get('localFile') not in (path.name,rate_path.name)]+[entry,rate_entry]
manifest.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
print('Imported Forever '+BUILD+': '+str(len(compiled['items']))+' effect-bearing items; '+str(len(compiled['sets']))+' sets.')

print('Joined '+str(len(overrides))+' exact item-effect rate observations.')
print('Numeric models with post-launch rate provenance: '+str(sum(1 for item in compiled['items'].values() for model in item['models'] if model.get('rateSource'))))
