"""Import literal MIT Forever vendor/rare/outdoor source relationships.

No upstream Lua execution, inferred drops, crafting recipes or invented pins.
Run with tools/python on PYTHONPATH. The normal content importer calls build.
"""
from pathlib import Path
import json
import re
import runpy
from collections import Counter
from luaparser import ast
from luaparser import astnodes as N


def build(ctx):
    text = ctx.source('ATTWoWAddon/AllTheThings', ctx.ATT, '.contrib/.db/forever/.config/constants/maps.lua')
    maps = {k: int(v) for k, v in re.findall(r'\b([A-Z][A-Z0-9_]*)\s*=\s*(\d+)', text)}
    tree = json.loads((ctx.ROOT / '.sources/AllTheThings-tree.json').read_text())
    paths = sorted(x['path'] for x in tree['tree'] if x['path'].startswith('.contrib/.db/forever/zones/') and x['path'].endswith('.lua'))

    class Reader(ctx.Reader):
        def value(self, node):
            if isinstance(node, N.Call) and isinstance(node.func, N.Name):
                kind = node.func.id
                if kind in ('maproot', 'f', 'bubbleDown', 'bubbleDownSelf', 'sharedData'):
                    args = [self.value(x) for x in node.args]
                    if not args or not isinstance(args[-1], dict):
                        return None
                    if kind == 'maproot':
                        return dict(args[-1], _kind='m', _id=args[-2])
                    if kind in ('bubbleDown', 'bubbleDownSelf', 'sharedData'):
                        return dict(args[0] if isinstance(args[0], dict) else {}, groups=args[-1])
                    return dict(groups=args[-1])
            return super().value(node)

    records, seen, counts = [], set(), Counter()
    for path in paths:
        reader = Reader(ctx.source('ATTWoWAddon/AllTheThings', ctx.ATT, path), maps)

        def visit(node, inherited):
            if not isinstance(node, dict) or ctx.forbidden(node):
                return
            state = dict(inherited)
            kind, ident = node.get('_kind'), node.get('_id')
            if kind in ('q', 'objective', 'o'):
                return
            if kind == 'm' and isinstance(ident, int):
                state['map'] = ident
            for field in ('races', 'classes', 'c', 'lvl', 'minReputation', 'requireSkill'):
                if field in node:
                    state[field] = node[field]
            if kind == 'n' and ident in ('VENDORS', 'RARES', 'ZONE_DROPS'):
                state['sourceKind'] = {'VENDORS': 'vendor', 'RARES': 'rare', 'ZONE_DROPS': 'world'}[ident]
            if kind == 'n' and isinstance(ident, int):
                state['npc'] = ident
                state['npcName'] = node.get('_name') or 'NPC #' + str(ident)
            if isinstance(node.get('coord'), dict):
                state['coord'] = node['coord']
            if isinstance(node.get('coords'), dict):
                state['coords'] = node['coords']
            if kind == 'i' and isinstance(ident, int) and state.get('sourceKind'):
                source_kind = state['sourceKind']
                npc = state.get('npc')
                if source_kind in ('vendor', 'rare') and not npc:
                    return
                point = node.get('coord') or (ctx.sequence(node.get('coords', {})) or [None])[0]
                if not point and source_kind in ('vendor', 'rare'):
                    point = state.get('coord') or (ctx.sequence(state.get('coords', {})) or [None])[0]
                location = point.get(3) if isinstance(point, dict) else state.get('map')
                key = ident, source_kind, npc, location
                if key in seen:
                    return
                seen.add(key)
                record = {'id': ident, 'sourceKind': source_kind, 'name': node.get('_name'), 'sourceNPC': npc,
                          'source': (state.get('npcName', 'Outdoor drop') + ' - ' + source_kind.title() + ' (' + re.sub(r'^\d+\s*-\s*', '', Path(path).stem).title() + ')'),
                          'availability': 'source-listed', 'provenance': path, 'map': location}
                if isinstance(point, dict) and all(isinstance(point.get(k), (int, float)) for k in (1, 2, 3)) and 0 <= point[1] <= 100 and 0 <= point[2] <= 100:
                    record.update(map=point[3], x=point[1] / 100, y=point[2] / 100)
                locations = []
                for location in ctx.sequence(node.get('coords', state.get('coords', {}) if source_kind in ('vendor', 'rare') else {})):
                    if isinstance(location, dict) and all(isinstance(location.get(k), (int, float)) for k in (1, 2, 3)) and 0 <= location[1] <= 100 and 0 <= location[2] <= 100:
                        locations.append({'map': location[3], 'x': location[1] / 100, 'y': location[2] / 100})
                if locations:
                    record['locations'] = locations
                races = state.get('races')
                if races in ('ALLIANCE_ONLY', 'HORDE_ONLY'):
                    record['faction'] = 'Alliance' if races == 'ALLIANCE_ONLY' else 'Horde'
                if isinstance(races, dict):
                    record['races'] = ctx.sequence(races)
                classes = state.get('classes') or state.get('c')
                if isinstance(classes, dict):
                    record['classes'] = ctx.sequence(classes)
                if isinstance(state.get('lvl'), int):
                    record['required'] = state['lvl']
                if state.get('minReputation') is not None or state.get('requireSkill') is not None:
                    record['requirements'] = 'Source lists a profession or reputation requirement; inspect native requirements.'
                if node.get('isLimited'):
                    record['requirements'] = 'Source-listed limited vendor stock. Current stock is unconfirmed.'
                records.append(record)
                counts[source_kind] += 1
                return
            # Resolve only the explicit select-item form, not arbitrary ATT queries.
            if state.get('sourceKind') == 'vendor' and state.get('npc'):
                for query in ctx.sequence(node.get('sym', {})):
                    values = ctx.sequence(query)
                    if values[:2] == ['select', 'itemID']:
                        for item in values[2:]:
                            if isinstance(item, int):
                                visit({'_kind': 'i', '_id': item}, state)
            for child in ctx.children(node):
                visit(child, state)

        for call in ast.walk(reader.tree):
            if isinstance(call, N.Call) and isinstance(call.func, N.Name) and call.func.id == 'maproot':
                visit(reader.value(call), {})
    records.sort(key=lambda r: (r['id'], r['sourceKind'], r.get('sourceNPC') or 0, r.get('map') or 0))
    ctx.write('GearSources.lua', 'ns.Data.gearSources', records,
              'AllTheThings Forever, MIT. Literal vendor/rare/outdoor references; not live availability. No inferred locations or drop rates.')
    ctx.manifest['counts']['outdoorGearSourceRecords'] = len(records)
    ctx.manifest['counts']['outdoorGearSourcesByKind'] = dict(counts)
    print('Outdoor source relationships:', len(records), dict(counts))


if __name__ == '__main__':
    import types
    root = Path(__file__).resolve().parent.parent
    namespace = runpy.run_path(str(root / 'tools/Import-Content.py'))
    ctx = types.SimpleNamespace(**namespace)
    ctx.manifest = json.loads((root / 'ToonKit/SOURCE-MANIFEST.json').read_text())
    build(ctx)
    ctx.manifest["sources"].extend(namespace["manifest"]["sources"])
    unique = {(r.get('repository'), r.get('revision'), r.get('file', r.get('localFile'))): r for r in ctx.manifest['sources']}
    ctx.manifest['sources'] = list(unique.values())
    (root / 'ToonKit/SOURCE-MANIFEST.json').write_text(json.dumps(ctx.manifest, indent=2) + '\n', encoding='utf-8')
