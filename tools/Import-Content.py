"""Reproduce pinned licensed content imports. Development only; not an addon dependency.

Run with tools/python on PYTHONPATH (lupa and luaparser). This does not install
anything in WoW or execute upstream addon code in the game.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from luaparser import ast
from luaparser import astnodes as N
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "ToonKit"
CACHE = ROOT / ".sources/content"
ATT = "8a1d2ce546c75abc48eaf3666e5f8419be23b895"
LIBRARY = "0c8d2eab0f6fe5bf0174e9fbd1647fff00efe203"
LIBRARIAN = "7ff8295be0ee278ba9acbce4c608e3d51ce0ee85"
SPYGLASS = "c786e9960c9ad7464e57f8f7754e319b1b9f1649"
AEGIS = "ec156b0a051611dc627e568c4f0adbe42960d256"
manifest = {"retrieved": "2026-10-18", "sources": [], "counts": {}}

def source(repo, revision, path):
    target = CACHE / repo.split("/")[-1] / path
    url = "https://raw.githubusercontent.com/" + repo + "/" + revision + "/" + urllib.parse.quote(path, safe="/")
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ToonKit-content-import"})).read())
    raw = target.read_bytes()
    manifest["sources"].append({"repository": repo, "revision": revision, "file": path, "sha256": hashlib.sha256(raw).hexdigest()})
    return raw.decode("utf-8-sig")

def lua(value):
    if value is None: return "nil"
    if value is True: return "true"
    if value is False: return "false"
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + '"'
    if isinstance(value, list): return "{" + ",".join(lua(v) for v in value) + "}"
    return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items() if v is not None) + "}"

def write(name, target, records, notice):
    text = "local addonName, ns = ...\n-- " + notice + "\n" + target + " = "
    text += lua(records) + "\n" if isinstance(records, dict) else "{\n" + ",\n".join(lua(record) for record in records) + "\n}\n"
    (DEST / "Data" / name).write_text(text, encoding="utf-8")

def talent_identities():
    path = CACHE / "talentsforever-data.json"
    if not path.exists():
        path.write_bytes((ROOT / ".sources/talents.json").read_bytes())
    raw = path.read_bytes(); data = json.loads(raw)
    assert data["license"] == "CC-BY-4.0"
    names = {c + "|" + t["name"] for c, value in data["talents"].items() for tree in value["trees"] for t in tree["talents"]}
    links = {}
    for key, value in data["spell_desc"].items():
        identity = "|".join(key.split("|")[:2])
        if identity in names and value.get("s") == "beta" and type(value.get("id")) is int:
            class_name, name = identity.split("|", 1)
            links.setdefault(class_name.upper(), {}).setdefault(name, set()).add(value["id"])
    links = {c: {name: sorted(ids) for name, ids in rows.items()} for c, rows in links.items()}
    write("TalentIdentities.lua", "ns.Data.talentSpells", links, "Talents Forever CC BY 4.0, beta spell identities only. No Classic/demo ID substitution.")
    effects = {}
    attributes = {"Strength": "ITEM_MOD_STRENGTH_SHORT", "Agility": "ITEM_MOD_AGILITY_SHORT", "Stamina": "ITEM_MOD_STAMINA_SHORT", "Intellect": "ITEM_MOD_INTELLECT_SHORT", "Spirit": "ITEM_MOD_SPIRIT_SHORT"}
    for class_name, value in data["talents"].items():
        for ti, tree in enumerate(value["trees"], 1):
            for index, talent in enumerate(tree["talents"], 1):
                patterns = [(r"^Increases your (?:total )?" + name + r" by (\d+)%", stat, "multiply") for name, stat in attributes.items()]
                patterns += [(r"^Increases your armor value from items by (\d+)%", "RESISTANCE0_NAME", "multiply"), (r"^Increases your Armor by an amount equal to (\d+)% of your Intellect", "ITEM_MOD_INTELLECT_SHORT", "intellectArmor")]
                for pattern, stat, kind in patterns:
                    amounts = [re.match(pattern, text) for text in talent["desc"]]
                    if len(amounts) == talent["max"] and all(amounts) and talent.get("src") == "beta":
                        effects.setdefault(class_name.upper(), []).append({"key": str(ti) + ":" + str(index), "name": talent["name"], "stat": stat, "kind": kind, "percent": [int(m[1]) for m in amounts], "descriptions": talent["desc"], "source": "Talents Forever CC BY 4.0; " + data["generated"]})
    write("TalentEffects.lua", "ns.Data.talentEffects", effects, "Source-derived unconditional attribute and item-armor effects only. Conditional form/proc bonuses are not inferred.")
    manifest["sources"].append({"url": "https://talentsforever.com/data.json", "localFile": path.name, "generated": data["generated"], "sha256": hashlib.sha256(raw).hexdigest()})
    manifest["counts"]["talentsWithSpellIdentities"] = sum(len(rows) for rows in links.values())
    manifest["counts"]["modeledTalentEffects"] = sum(len(rows) for rows in effects.values())

def python_table(value):
    if hasattr(value, "items"):
        pairs = dict(value.items())
        if pairs and all(isinstance(k, int) for k in pairs) and set(pairs) == set(range(1, len(pairs) + 1)):
            return [python_table(pairs[i]) for i in range(1, len(pairs) + 1)]
        return {k: python_table(v) for k, v in pairs.items()}
    return value

def sequence(data):
    if isinstance(data, dict): return [v for k, v in data.items() if isinstance(k, int)]
    return []

def children(data):
    return sequence(data) + sequence(data.get("groups", {})) + sequence(data.get("g", {})) if isinstance(data, dict) else []

def forbidden(node):
    if node.get("u") is not None or node.get("unobtainable") is not None: return True
    if isinstance(node.get("awp"), (int,float)) and node["awp"]>16001: return True
    if isinstance(node.get("rwp"), (int,float)) and node["rwp"]<=16001: return True
    values = list((node.get("timeline") or {}).values())
    return any("REMOVED_1_60" in str(v) or "REMOVED_1_15" in str(v) for v in values)

def dungeons():
    maps_text = source("ATTWoWAddon/AllTheThings", ATT, ".contrib/.db/forever/.config/constants/maps.lua")
    maps = {k: int(v) for k, v in re.findall(r"\b([A-Z][A-Z0-9_]*)\s*=\s*(\d+)", maps_text)}
    tree = json.loads((ROOT / ".sources/AllTheThings-tree.json").read_text())
    paths = [x["path"] for x in tree["tree"] if x["path"].startswith(".contrib/.db/forever/dungeons & raids/") and x["path"].endswith(".lua")]
    name_hints={}
    for x in tree["tree"]:
        p=x["path"]
        if p.startswith(".contrib/.db/forever/zzOLD/01 - Dungeons Raids/01 - Classic/") and p.endswith(".lua") and any(k in p.lower() for k in ("uldaman","sunken","temple of atal","farrak","stratholme")):
            hint_text=source("ATTWoWAddon/AllTheThings",ATT,p)
            for kind,number,name in re.findall(r"\b(instanceroot|inst|e|n|i|q|o)\(\s*(\d+)[^\n]*?--\s*([^\n]+)",hint_text):name_hints[(kind,int(number))]=name.strip()
    paths.append("db/Camelot/Categories/Instances.lua")
    out, exclusions = [], Counter()
    for path in paths:
        text = source("ATTWoWAddon/AllTheThings", ATT, path)
        reader = Reader(text, maps)
        reader.names.update(name_hints)
        for call in ast.walk(reader.tree):
            if not isinstance(call, N.Call) or not isinstance(call.func, N.Name) or call.func.id not in ("inst", "instanceroot"): continue
            instance = reader.value(call)
            if not instance or forbidden(instance): continue
            if path.startswith("db/") and any(x["id"]==instance["_id"] for x in out): continue
            encounters = []
            def visit(node, context=None):
                if not isinstance(node, dict): return
                if forbidden(node): exclusions["unavailableNodes"] += 1; return
                kind, ident = node.get("_kind"), node.get("_id")
                if kind in ("q", "o", "objective"): return
                if kind == "n" and isinstance(ident, str) and ident in ("QUESTS", "VENDORS", "ZONE_DROPS", "FACTIONS", "CRAFTING"): return
                if kind == "n" and isinstance(ident, str): context = ident
                direct = children(node)
                if kind == "e" or kind == "n" and isinstance(ident, (int, float)):
                    loot = []
                    def items(child):
                        if not isinstance(child, dict): return
                        if forbidden(child): exclusions["unavailableItems"] += 1; return
                        if child.get("_kind") == "i":
                            if isinstance(child.get("_id"), (int, float)):
                                loot.append({"id": child["_id"], "name": child.get("_name"), "classes": list((child.get("classes") or child.get("c") or {}).values()), "sourceAvailability": "Forever catalog", "timeline": list((child.get("timeline") or {}).values())})
                            return
                        if child.get("_kind") in ("q", "o", "objective", "n", "e"): return
                        for v in children(child): items(v)
                    for child in direct: items(child)
                    if loot:
                        encounters.append({"id": ("encounter:" if kind == "e" else "npc:") + str(ident), "npc": node.get("creatureID") or (ident if kind == "n" else None), "name": node.get("_name") or "Encounter #" + str(ident), "description": node.get("description"), "wing": context, "rare": context == "RARES" or "Rare Creature" in (node.get("description") or ""), "loot": list({x["id"]: x for x in loot}.values())})
                        return
                for child in direct: visit(child, context)
            for child in children(instance): visit(child)
            coord = instance.get("coord") or {}
            if not coord and instance.get("coords"):
                for map_id,points in instance["coords"].items():
                    if isinstance(map_id,int) and isinstance(points,dict) and isinstance(points.get(1),dict):
                        coord={1:points[1].get(1),2:points[1].get(2),3:map_id};break
            entrance = {"map": coord.get(3), "x": coord.get(1) / 100, "y": coord.get(2) / 100} if isinstance(coord.get(3), (int, float)) and coord.get(1) is not None else None
            if encounters:
                out.append({"id": instance["_id"], "name": instance.get("_name") or Path(path).stem.title(), "required": instance.get("lvl"), "map": instance.get("mapID"), "entrance": entrance, "encounters": encounters, "source": "AllTheThings Forever catalog (MIT)", "sourceFile": path, "revision": ATT, "availability": "source-listed"})
    out = merge_spyglass(out)
    write("BossLoot.lua", "ns.Data.journals", out, "Adapted AllTheThings Forever + Spyglass datasets, MIT. Source-listed drops, no invented rates. See Licenses/.")
    (DEST / "Licenses/AllTheThings-MIT.txt").write_text(source("ATTWoWAddon/AllTheThings", ATT, "LICENSE"), encoding="utf-8")
    manifest["counts"].update(lootInstances=len(out), lootEncounters=sum(len(d["encounters"]) for d in out), bossDropLinks=sum(len(e["loot"]) for d in out for e in d["encounters"]), lootExclusions=dict(exclusions))
    manifest["counts"]["bossDisplayIdentities"] = sum(bool(e.get("displayID")) for d in out for e in d["encounters"])
    manifest["counts"]["nativeBossPortraitPaths"] = sum(bool(e.get("portrait")) for d in out for e in d["encounters"])
    return maps

def merge_spyglass(att):
    tree = json.loads((CACHE / "Spyglass-tree.json").read_text())
    def norm(name): return re.sub(r"[^a-z0-9]", "", name.lower().removeprefix("the ").replace("stormwind stockade", "stockade").replace("temple of atal'hakkar", "sunken temple"))
    paths = [x["path"] for x in tree["tree"] if x["path"].startswith(".contribute/data/dungeons/") and x["path"].endswith(".json")]
    out, used = [], set()
    for path in paths:
        d = json.loads(source("Karl-HeinzSchneider/WoW-Spyglass", SPYGLASS, path))
        split_wing=any(Path(path).stem.startswith(p) for p in ("dire_maul_","scarlet_monastery_","blackrock_spire_"))
        base = d["name"].split(":")[0] if split_wing else d["name"]
        matches = [a for a in att if norm(a["name"]) == norm(base)]
        encounters = []
        wing = d["name"].split(":")[-1].strip().upper() if split_wing else None
        expected = {"EAST": "WARPWOOD", "NORTH": "GORDOK", "WEST": "CAPITAL"}.get(wing, wing)
        att_encounters = []
        for a in matches:
            used.add(a["id"])
            for e in a["encounters"]:
                context = str(e.get("wing") or "").upper()
                if expected and context and expected not in context: continue
                att_encounters.append(e)
        matched_att=set()
        for e in d["encounters"]:
            counterpart = next((x for x in att_encounters if x.get("npc") and x.get("npc") == e.get("npc") or norm(x["name"].split(" <")[0]) == norm(e["name"])), None)
            own = {x["item"]: {"id": x["item"], "name": x.get("name"), "sourceAvailability": "Spyglass Forever catalog"} for x in e.get("loot", [])}
            if counterpart:
                matched_att.add(counterpart["id"])
                for item in counterpart["loot"]:
                    item = dict(item)
                    if item["id"] in own: item["corroborated"] = True
                    own[item["id"]] = item
            npc=e.get("npc") or (counterpart and counterpart.get("npc"))
            encounters.append({"id": "npc:" + str(npc) if npc else "encounter:" + str(e.get("id")), "npc": npc, "displayID": e.get("displayID"), "portrait": e.get("portrait") if str(e.get("portrait", "")).startswith("Interface\\") and "\\AddOns\\" not in e.get("portrait", "") else None, "name": e["name"], "level": e.get("level"), "description": counterpart and counterpart.get("description"), "rare": e.get("rare") or (counterpart and counterpart.get("rare")) or False, "loot": list(own.values())})
        seen = {x.get("npc") for x in encounters if x.get("npc")}
        for e in att_encounters:
            if e["id"] not in matched_att and (not e.get("npc") or e["npc"] not in seen): encounters.append(e)
        entrance = d.get("entrance")
        point = {"map": entrance[0], "x": entrance[1] / 100, "y": entrance[2] / 100} if entrance and len(entrance) == 3 else None
        key = Path(path).stem
        out.append({"id": "spyglass:" + key, "key": key.replace("_", "-"), "name": d["name"], "min": d.get("minLevel"), "max": d.get("maxLevel"), "required": d.get("requiredLevel") or d.get("minLevel"), "zoneMap": d.get("zone"), "entrance": point, "encounters": encounters, "source": "Spyglass + AllTheThings Forever catalogs (MIT)" if matches else "Spyglass Forever catalog (MIT)", "sourceFile": path, "revision": SPYGLASS, "availability": "source-listed", "betaListed": any(x["path"] == "Spyglass/db/generated/loot/" + key + ".lua" for x in tree["tree"])})
    for a in att:
        if a["id"] not in used:
            a["key"] = re.sub(r"[^a-z0-9]+", "-", a["name"].lower()).strip("-")
            a["min"] = a.get("required") or 60; a["max"] = 60; a["betaListed"] = False
            out.append(a)
    (DEST / "Licenses/Spyglass-MIT.txt").write_text(source("Karl-HeinzSchneider/WoW-Spyglass", SPYGLASS, "LICENSE"), encoding="utf-8")
    manifest["counts"]["corroboratedBossDrops"] = sum(bool(i.get("corroborated")) for d in out for e in d["encounters"] for i in e["loot"])
    manifest["counts"]["instancesWithLoot"] = sum(any(e["loot"] for e in d["encounters"]) for d in out)
    return out

def encounter_abilities():
    repo = "Torchlite-bit/Aegis_Forever_Instance_Journal"
    text = source(repo, AEGIS, "Data/Generated/Abilities.lua")
    source(repo, AEGIS, "README.md")
    source(repo, AEGIS, "CREDITS.md")
    reader = Reader(text, {})
    tables = [reader.value(node.args[0]) for node in ast.walk(reader.tree)
              if isinstance(node, N.Call) and isinstance(node.func, N.Index)
              and isinstance(node.func.idx, N.Name) and node.func.idx.id == "SetAbilities"]
    assert len(tables) == 1
    # Only this generated recording dataset is imported. Authored guide prose and all artwork are excluded.
    recorded = tables[0]
    authored_reader = Reader(source(repo, AEGIS, "Data/Authored/Abilities.lua"), {})
    authored = {}
    for node in ast.walk(authored_reader.tree):
        if isinstance(node, N.Call) and isinstance(node.func, N.Index) and isinstance(node.func.idx, N.Name) and node.func.idx.id == "AmendInstance":
            authored[authored_reader.value(node.args[0])] = authored_reader.value(node.args[1])["bosses"]
    output = {}
    native_maps = []
    def array(value): return [array(v) for v in sequence(value)] if isinstance(value, dict) else value
    for dungeon in sorted(set(recorded) | set(authored)):
        instance_reader = Reader(source(repo, AEGIS, "Data/Instances/" + dungeon + ".lua"), {})
        instances = [instance_reader.value(node.args[0]) for node in ast.walk(instance_reader.tree)
                     if isinstance(node, N.Call) and isinstance(node.func, N.Index)
                     and isinstance(node.func.idx, N.Name) and node.func.idx.id == "AddInstance"]
        assert len(instances) == 1
        instance = instances[0]
        floors = [floor["uiMapID"] for floor in sequence(instance.get("map", {}).get("floors", {})) if isinstance(floor.get("uiMapID"), int)]
        native_maps.append({"name": instance["name"], "instanceID": instance.get("instanceID"), "floors": floors})
        boss_ids = {b["name"]: b.get("npcID") for b in sequence(instance.get("bosses", {}))}
        records = []
        for name in sorted(set(recorded.get(dungeon, {})) | set(authored.get(dungeon, {}))):
            observation = recorded.get(dungeon, {}).get(name, {})
            boss = authored.get(dungeon, {}).get(name, {})
            record = {"name": name, "npc": boss_ids.get(name), "instanceID": instance.get("instanceID"), "encounterID": observation.get("encounterID"), "abilities": []}
            spells = {}
            # Import identities and role flags only; authored guide prose and artwork are excluded.
            for ability in sequence(boss.get("abilities", {})):
                if isinstance(ability.get("spellID"), int):
                    spells[ability["spellID"]] = {k: ability[k] for k in ("spellID", "name") if k in ability}
                    if ability.get("flags"): spells[ability["spellID"]]["flags"] = array(ability["flags"])
            for ability in sequence(observation.get("abilities", {})):
                if not isinstance(ability.get("spellID"), int): continue
                entry = spells.setdefault(ability["spellID"], {})
                entry.update({k: ability[k] for k in ("spellID", "name", "school", "firstCast") if k in ability})
                entry["recorded"] = True
                for k in ("hit", "every"):
                    if ability.get(k): entry[k] = array(ability[k])
            record["abilities"] = [spells[k] for k in sorted(spells)]
            if record["abilities"] or record["encounterID"]: records.append(record)
        output[dungeon] = records
    write("EncounterAbilities.lua", "ns.Data.encounterAbilities", output,
          "Aegis MIT spell identities/role flags and recorded observations, " + AEGIS + "; no authored guide prose or artwork imported.")
    (DEST / "Licenses/Aegis-MIT.txt").write_text(source(repo, AEGIS, "LICENSE"), encoding="utf-8")
    write("NativeJournalMaps.lua", "ns.Data.nativeJournalMaps", native_maps,
          "Aegis MIT instance/floor identities only; no artwork or encounter prose imported. " + AEGIS)
    manifest["counts"]["nativeJournalMapGroups"] = len(native_maps)
    manifest["counts"]["recordedEncounterGroups"] = len(recorded)
    manifest["counts"]["recordedEncounters"] = sum(len(rows) for rows in recorded.values())
    manifest["counts"]["recordedBossSpells"] = sum(len(sequence(r.get("abilities", {}))) for rows in recorded.values() for r in rows.values())
    manifest["counts"]["abilityInstanceGroups"] = len(output)
    manifest["counts"]["abilityEncounters"] = sum(len(rows) for rows in output.values())
    manifest["counts"]["bossAbilityLinks"] = sum(len(r["abilities"]) for rows in output.values() for r in rows)


def books(maps):
    path = CACHE / "sixty-books.json"
    if not path.exists():
        path.write_bytes(urllib.request.urlopen(urllib.request.Request("https://sixtyforever.com/data/books.json", headers={"User-Agent": "Mozilla/5.0"})).read())
    raw = path.read_bytes(); data = json.loads(raw)
    assert data["license"] == "CC BY 4.0"
    manifest["sources"].append({"url": "https://sixtyforever.com/data/books.json", "updated": data["updated"], "sha256": hashlib.sha256(raw).hexdigest()})
    lib = source("coffeelover1010/library-guide-forever", LIBRARY, "Books.lua")
    # Books.lua is a literal catalog followed by table indexing. Only the initial assignment is read.
    tree = ast.parse(lib)
    reader = Reader("", maps)
    rows = {}
    for assignment in tree.body.body:
        if isinstance(assignment, N.Assign) and isinstance(assignment.values[0], N.Table):
            value = reader.value(assignment.values[0])
            if value and isinstance(value.get(1), dict):
                rows = {v[1]: v for v in value.values()}; break
    out = []
    donation_reader=Reader(source("ATTWoWAddon/AllTheThings",ATT,".contrib/.db/forever/expansion features/library books.lua"),maps)
    librarian = ast.parse(source("thoriphes/Librarian", LIBRARIAN, "Data/Books.lua"))
    supplements = {}
    for assignment in librarian.body.body:
        if isinstance(assignment, N.Assign) and isinstance(assignment.values[0], N.Table):
            value = reader.value(assignment.values[0])
            if value and isinstance(value.get(1), dict) and value[1].get("item"):
                supplements = {v["item"]: v for v in value.values()}; break
    source("thoriphes/Librarian", LIBRARIAN, "README.md")
    (DEST / "Licenses/Librarian-MIT.txt").write_text(source("thoriphes/Librarian", LIBRARIAN, "LICENSE"), encoding="utf-8")
    donations={}
    for call in ast.walk(donation_reader.tree):
        if isinstance(call,N.Call) and isinstance(call.func,N.Name) and call.func.id=="q":
            q=donation_reader.value(call);p=q.get("provider") or {}
            if p.get(1)=="i":donations[p[2]]=(q["_id"],q.get("races"))
    for b in data["books"]:
        ident = int(b["itemId"]); newer = rows.get(ident)
        map_key = b["zone"].upper().replace(" ", "_").replace("'", "")
        map_id = maps.get(map_key)
        coords = re.match(r"^(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)$", b.get("coords", ""))
        record = {"id": "library:" + str(ident), "item": ident, "quest": int(b["questId"]) if b.get("questId") else None, "name": b["name"], "zone": b["zone"], "map": map_id, "set": b["set"], "detail": b.get("directions"), "caution": b.get("note"), "sourceStatus": b["status"], "source": "Sixty Forever CC BY 4.0; Library Guide Forever MIT", "locations": []}
        if coords and map_id and b["status"] not in ("unknown", "not-in-forever"):
            record["locations"].append({"map": map_id, "x": float(coords[1]) / 100, "y": float(coords[2]) / 100, "zone": b["zone"], "label": b.get("subzone"), "confidence": b["status"]})
        for alt in b.get("alt", []):
            point = re.match(r"^(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)$", alt.get("coords", ""))
            m = maps.get(alt["zone"].upper().replace(" ", "_"))
            if point and m: record["locations"].append({"map": m, "x": float(point[1]) / 100, "y": float(point[2]) / 100, "zone": alt["zone"], "label": alt.get("subzone"), "confidence": "wowhead"})
        if newer:
            record["detail"] = newer.get(8) or record["detail"]
            record["caution"] = newer.get("caution") or newer.get("factionCaution") or record["caution"]
            record["donationFaction"] = newer.get("faction")
            record["evidence"] = newer.get("evidence")
            # A false newer quest ID means that the original SoD ID is not confirmed for Forever.
            record["quest"] = newer.get(2) if type(newer.get(2)) is int else None
            if newer.get(5) and newer.get(6) is not None:
                record["locations"] = [{"map": newer[5], "x": newer[6] / 100, "y": newer[7] / 100, "zone": newer[4], "confidence": "community report", "label": "Cave entrance" if ident == 209846 else None}]
                alt = newer.get("alt")
                if alt: record["locations"].append({"map": alt[1], "x": alt[2] / 100, "y": alt[3] / 100, "zone": alt[4], "confidence": "community report"})
            elif b["status"] in ("unknown", "not-in-forever"):
                record["locations"] = []
        if ident in (210177, 220349, 220347, 228133):
            supplement = supplements[ident]
            record["source"] += "; Librarian MIT"
            record["evidence"] = "Librarian " + LIBRARIAN + " Data/Books.lua"
            if ident == 210177:
                point = supplement["spots"][1]
                record["locations"] = [{"map": point["map"], "x": point["x"] / 100, "y": point["y"] / 100, "zone": b["zone"], "label": point["container"], "confidence": "community report"}]
                record["detail"] = point["note"]
                record["caution"] = "Restored by newer Librarian player reports; older reports disputed this pickup."
                record["sourceStatus"] = "community report"
            elif ident in (220349, 228133):
                # The upstream zone pin marks the mountain, explicitly not the interior pickup.
                record["detail"] = supplement["spots"][1]["note"]
                record["caution"] = "Interior directions only. No verified UiMapID for the cited Blackrock Mountain coordinates; no pickup pin."
                point = supplement["spots"][1]
                record["accessPoints"] = [{"map": point["map"], "x": point["x"] / 100, "y": point["y"] / 100,
                                           "label": "Mountain reference point, not the book position", "source": "Librarian MIT"}]
            else:
                record["caution"] = supplement["notInForever"]
        record["referenceOnly"] = b["status"] in ("unknown", "not-in-forever") and not record["locations"]
        if not record["quest"] and ident in donations:
            record["quest"]=donations[ident][0];record["questEvidence"]="AllTheThings explicit Forever library quest"
            if donations[ident][1] in ("HORDE_ONLY","ALLIANCE_ONLY"):record["donationFaction"]="Horde" if donations[ident][1]=="HORDE_ONLY" else "Alliance"
        # Book turn-in level is not a pickup requirement. Never infer a cap gate from set name.
        record["availability"] = "source-listed" if not record["referenceOnly"] else "unverified"
        if record["locations"]:
            first = record["locations"][0]
            record.update({k: first[k] for k in ("map", "x", "y")})
        out.append(record)
    write("Books.lua", "ns.Data.collections", out, "Sixty Forever CC BY 4.0 + Library Guide Forever MIT; merged/normalized 2026-10-17. Unknown locations remain unpinned.")
    goal_reader=Reader(source("thoriphes/Librarian", LIBRARIAN, "Data/Books.lua"),maps)
    for assignment in goal_reader.tree.body.body:
        if isinstance(assignment,N.Assign) and isinstance(assignment.targets[0],N.Index) and getattr(assignment.targets[0].idx,"id",None)=="Goals":
            goals=sequence(goal_reader.value(assignment.values[0]))
            write("LibraryGoals.lua","ns.Data.libraryGoals",goals,"Librarian MIT, pinned source-listed library milestones. Reward choices and restrictions are preserved, not inferred.")
            manifest["counts"]["libraryMilestones"]=len(goals)
            break
    (DEST / "Licenses/LibraryGuide-MIT.txt").write_text(source("coffeelover1010/library-guide-forever", LIBRARY, "LICENSE"), encoding="utf-8")
    (DEST / "Licenses/SixtyForever-CC-BY-4.0.txt").write_text("Library data: Sixty Forever, https://sixtyforever.com/data/books.json\nLicense: CC BY 4.0 https://creativecommons.org/licenses/by/4.0/\nLicense statement: https://sixtyforever.com/about/\n" + data["attribution"] + "\nSource updated: " + data["updated"] + "\nChanges: merged with Library Guide Forever MIT data, normalized to Lua; older/unconfirmed donation IDs are not substituted for confirmed Forever IDs. No game artwork redistributed.\nAdditional requested attribution: https://talentsforever.com\n", encoding="utf-8")
    manifest["counts"].update(libraryBooks=len(out), locatedBooks=sum(bool(b["locations"]) for b in out), libraryLocations=sum(len(b["locations"]) for b in out), knownDonationQuests=sum(bool(b["quest"]) for b in out))

def catalog_support():
    path = CACHE / "blizzard-announced-dungeons.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    manifest["sources"].append({"url":data["source"],"localFile":"blizzard-announced-dungeons.json","sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"notice":data["notice"]})
    write("DungeonCatalog.lua", "ns.Data.announcedDungeons", data["records"], "Factual names announced by Blizzard; no article prose or media. Unspecified details remain unknown.")
    for name in ("Data.lua","Art.lua","LICENSE"):
        path = CACHE / "ForeverDungeons" / name
        manifest["sources"].append({"url":"https://www.curseforge.com/wow/addons/foreverdungeons/files/9218799","localFile":"ForeverDungeons/"+name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"license":"MIT","version":"0.11.0-forever"})
    (DEST / "Licenses/ForeverDungeons-MIT.txt").write_bytes((CACHE/"ForeverDungeons/LICENSE").read_bytes())
    manifest["counts"]["announcedDungeonNames"] = len(data["records"])

if __name__ == "__main__":
    previous = json.loads((DEST / "SOURCE-MANIFEST.json").read_text(encoding="utf-8-sig"))
    manifest["sources"].extend(record for record in previous["sources"]
                               if (record.get("localFile") or "").startswith("everythingquests-route-metadata/"))
    talent_identities()
    maps = dungeons()
    books(maps)
    encounter_abilities()
    catalog_support()
    import runpy, sys
    runpy.run_path(str(ROOT/"tools/Import-QuestSupport.py"))["build"](sys.modules[__name__])
    runpy.run_path(str(ROOT/"tools/Import-GearSources.py"))["build"](sys.modules[__name__])
    manifest["sources"].sort(key=lambda s:(s.get("repository",s.get("url","")),s.get("file","")))
    (DEST / "SOURCE-MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    runpy.run_path(str(ROOT/"tools/Import-DungeonPreparation.py"))
    runpy.run_path(str(ROOT/"tools/Import-JournalCoverage.py"))["main"]()
    print(json.dumps(manifest["counts"], indent=2))
