"""Build and audit isolated solo leveling routes from pinned GPL Polestar data.

Development tool only. No game installation, publication or upstream runtime.
Run with tools/python on PYTHONPATH. Existing casual route inputs stay intact.
"""
from pathlib import Path
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import re
import runpy
import urllib.request
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
REVISION = "b753c783be39ccf9c91a94b1bfcb67ce01932d52"
CACHE = ROOT / ".sources/content/polestar-solo" / REVISION
RESEARCH = ROOT / ".sources/research/polestar-current" / REVISION
DEST = ROOT / "ToonKit"
REPORT = ROOT / ".sources/reports/solo-leveling.json"
ctx = runpy.run_path(str(ROOT / "tools/Import-Content.py"))
lua, plain = ctx["lua"], ctx["python_table"]
inputs = []


def fetch(name):
    path = CACHE / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        research = RESEARCH / name
        if research.exists():
            raw = research.read_bytes()
        else:
            url = "https://raw.githubusercontent.com/fitzforge/polestar/" + REVISION + "/" + name
            request = urllib.request.Request(url, headers={"User-Agent": "ToonKit-solo-route-import"})
            raw = urllib.request.urlopen(request, timeout=45).read()
        path.write_bytes(raw)
    return path.read_text(encoding="utf-8-sig")


def pin(name):
    path = CACHE / name
    return {"url": "https://github.com/fitzforge/polestar/blob/" + REVISION + "/" + name,
            "revision": REVISION, "localFile": path.relative_to(ROOT / ".sources/content").as_posix(),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "license": "GPL-3.0-only",
            "component": "solo-leveling"}


runtime = LuaRuntime(unpack_returned_tuples=True)
runtime.execute('captured={}; sandbox={}; sandbox.Polestar={RegisterGuide=function(g) captured[#captured+1]=g end,RetireGuides=function() end,RegisterExperimental=function() end}; function read(s) local f=assert(loadstring(s));setfenv(f,sandbox);f() end')
compiled = ["addon/Polestar_Guides/Guides.lua"] + ["addon/Polestar_Guides_" + side + "/Guides.lua" for side in ("Alliance", "Horde")]
for name in compiled:
    runtime.globals().read(fetch(name))
    inputs.append(pin(name))
guides = [plain(g) for _, g in runtime.globals().captured.items() if g["category"] == "Leveling"]
assert len({g["id"] for g in guides}) == len(guides)
originals = ["guides/" + g["id"] + ".guide" for g in guides]
with ThreadPoolExecutor(max_workers=5) as pool:
    list(pool.map(fetch, originals))
inputs.extend(pin(name) for name in originals)
for name, output in [("LICENSE", "Polestar-solo-GPL-3.0.txt"),
                     ("LICENSE-EXCEPTION.md", "Polestar-solo-guide-exception.md"),
                     ("addon/Polestar_Guides/LICENSE-DATA.txt", "Polestar-solo-guide-data.txt")]:
    (DEST / "Licenses" / output).write_text(fetch(name), encoding="utf-8")
    inputs.append(pin(name))

# Load only our existing data modules to corroborate dungeon identities and
# requirements. Never run an upstream addon or expose IO to its data chunk.
data = LuaRuntime(unpack_returned_tuples=True)
data.execute("ns={Data={}}")
load = data.eval("function(s)return assert(loadstring(s))end")
for name in ("QuestSupport", "Dungeons"):
    load((DEST / "Data" / (name + ".lua")).read_text(encoding="utf-8-sig"))("ToonKit", data.globals().ns)
support = plain(data.globals().ns.Data.questSupport)
meta = support["meta"]
dungeons = plain(data.globals().ns.Data.dungeons)
dungeon_ids = {q["id"] for d in dungeons for k, q in d.items() if isinstance(k, int) and isinstance(q, dict) and "id" in q}

excluded = {q: "dungeon quest" for q in dungeon_ids}
# Catalogs also list outdoor lead-ins and exterior collection. The pinned
# guides place every action of these quests outside an instance. Retain their
# useful on-route XP without accepting the actual dungeon follow-ups.
for q in (17, 704, 709, 3380, 2864, 4324, 6562):
    excluded.pop(q, None)
# Reviewed against the pinned .guide text. These group objectives/approaches
# lack machine-readable group flags in parts of the compiled snapshot.
for q in (6021, 211, 5781, 5165, 5202, 2478, 6563):
    excluded[q] = "source-text group objective or dungeon approach"
step_exclusions = {}
all_quests = {}
for guide in guides:
    for index, step in enumerate(guide["steps"], 1):
        reason = None
        if guide["id"] == "forever/horde/05-stonetalon-mountains" and any(g.get("quest")==211 for g in step["goals"]):
            reason = "Offering of Blood: group-only summon and approach"
        if guide["id"] == "forever/horde/07-ashenvale" and any(g.get("quest")==6563 for g in step["goals"]):
            reason = "Blackfathom dungeon approach"
        raw_note = step.get("note", "")
        if all(g["t"] == "note" for g in step["goals"]) and re.search(r"instead of grinding|Class guide.*group|group.*Class guide", raw_note, re.I):
            reason = "optional dungeon or group detour instruction"
        for condition in step.get("when", []):
            if condition["k"] == "group" and not condition.get("neg"):
                excluded[condition["q"]] = "source-listed group quest"
                reason = "source-listed group branch"
            elif condition["k"] == "dungeon":
                reason = "dungeon-only branch"
            elif condition["k"] == "skill":
                reason = "elective profession or weapon-skill branch"
        if reason:
            step_exclusions[(guide["id"], index)] = reason
        for goal in step["goals"]:
            q = goal.get("quest")
            if q:
                all_quests.setdefault(q, []).append(goal)
                if goal.get("group"):
                    excluded[q] = "source-listed group quest"
                if reason:
                    excluded.setdefault(q, reason)
                if meta.get(q, {}).get("skill"):
                    excluded[q] = "profession-gated quest"

# A removed quest cannot leave an impossible mandatory follow-up in the plan.
# Both source and existing metadata distinguish any/all prerequisites.
changed = True
while changed:
    changed = False
    for q, goals in all_quests.items():
        if q in excluded:
            continue
        m = meta.get(q, {})
        all_pre = list(m.get("preAll", []))
        any_pre = list(m.get("pre", []))
        source_all = set(p for g in goals for p in g.get("preAll", []))
        source_any = [g["pre"] for g in goals if g.get("pre")]
        if any(p in excluded for p in all_pre) or (any_pre and all(p in excluded for p in any_pre)) or any(p in excluded for p in source_all) or any(all(p in excluded for p in alternatives) for alternatives in source_any):
            excluded[q] = "depends on an excluded solo branch"
            changed = True

known_types = {"accept", "turnin", "collect", "kill", "goto", "train", "fly", "complete", "note", "level", "use", "getfp", "interact", "sethome", "talk", "vendor", "buy", "die", "enter", "task", "money", "abandon"}
known_conditions = {"onquest", "has", "money", "zone", "level", "turnedin", "complete", "bound", "available", "knows", "taxi", "done"}
starters = {}
for guide in guides:
    for step in guide["steps"]:
        for goal in step["goals"]:
            item = goal.get("item") or goal.get("startItem")
            if goal["t"] == "accept" and item:
                starters.setdefault(item, set()).add(goal["quest"])
stats = Counter()
routes, reviews = [], []


def clean_text(text, names):
    if not isinstance(text, str):
        return text
    text = re.sub(r"\{([a-z]+:\d+)\}", lambda m: names.get(m[1], m[1].replace(":", " #")), text)
    # Remove the alternative dungeon instruction, retaining the solo grind and
    # safety warnings about dungeon exteriors / outdoor elite patrols.
    text = re.sub(r"\s*Or, with a group, run .*?(?:instead\.|dungeon[^.]*\.)", "", text, flags=re.I)
    return text


for guide in guides:
    names = guide.get("names", {})
    resolve = lambda text: clean_text(text, names)
    route_id = "solo:" + guide["id"]
    route = dict(id=route_id, name=resolve(guide["title"]) + " (solo " + str(guide["minLevel"]) + "-" + str(guide["maxLevel"]) + ")",
                 min=guide["minLevel"], max=guide["maxLevel"], faction=guide.get("faction"), races=guide.get("races"),
                 category="Leveling", zone=guide["zone"], zoneName=guide["zoneName"], soloSpeedrun=True,
                 next="solo:" + guide["next"] if guide.get("next") else None,
                 source="Polestar GPL-3.0; adapted Forever solo leveling plan", revision=REVISION,
                 availability="source-listed", steps=[])
    review = dict(id=route_id, min=route["min"], max=route["max"], exclusions=[], backgroundMoves=[], questOrderCandidates=[])
    for index, source_step in enumerate(guide["steps"], 1):
        step = dict(id=route_id + ":" + str(index), text=resolve(source_step.get("title", "Continue the route")),
                    detail=resolve(source_step.get("note")), only=source_step.get("only"), goals=[], soloSpeedrun=True,label=source_step.get("label"))
        route["steps"].append(step)
        reason = step_exclusions.get((guide["id"], index))
        conditions = []
        for condition in source_step.get("when", []):
            if condition["k"] == "group" and condition.get("neg"):
                continue  # Solo fallback: the player is not taking this branch.
            if reason:
                break
            assert condition["k"] in known_conditions, condition
            conditions.append(condition)
        if conditions:
            step["soloWhen"] = conditions
        for gi, source_goal in enumerate(source_step["goals"], 1):
            assert source_goal["t"] in known_types, source_goal["t"]
            omit = reason or excluded.get(source_goal.get("quest"))
            if not source_goal.get("quest") and source_goal["t"] in ("collect", "buy", "use") and source_goal.get("item") in starters:
                if all(q in excluded for q in starters[source_goal["item"]]):
                    omit = omit or "item starter used only by an excluded branch"
            quest_meta = meta.get(source_goal.get("quest"), {})
            if guide["id"] == "forever/alliance/gnome/01-dun-morogh" and quest_meta.get("races") == 4 and quest_meta.get("classes") == 64:
                omit = "Dwarf-only shaman quest in Gnome source guide; source quest racial gate"
            if source_goal.get("profLine") or source_goal.get("skillLine"):
                omit = omit or "elective profession or weapon training"
            if omit:
                review["exclusions"].append(dict(step=index, goal=gi, quest=source_goal.get("quest"), reason=omit))
                stats["excludedGoals"] += 1
                continue
            goal = {k: resolve(v) if isinstance(v, str) else v for k, v in source_goal.items()
                    if k not in {"spotsPacked", "spots", "smartTarget", "preTitles", "candidates", "z", "f", "fromNpcs", "group", "closedBy"}}
            goal.update(id=route_id + ":" + str(index) + ":" + str(gi), soloSpeedrun=True)
            if conditions:
                goal["soloWhen"] = conditions
            if source_goal.get("startItem"):
                goal.setdefault("item", source_goal["startItem"])
            for coord in ("x", "y"):
                if coord in goal:
                    goal[coord] /= 100
                    assert 0 <= goal[coord] <= 1, (guide["id"], index, goal)
            if source_goal.get("candidates"):
                candidates = source_goal["candidates"]
                zone = source_goal.get("zone") or source_goal.get("map")
                local_candidates = [candidate for candidate in candidates if candidate.get("map") == zone]
                if local_candidates:
                    stats["distantTrainerCandidatesRemoved"] += len(candidates) - len(local_candidates)
                    candidates = local_candidates
                goal["locations"] = [{k: v / 100 if k in {"x", "y"} else resolve(v) if isinstance(v, str) else v
                                      for k, v in candidate.items() if k in {"map", "x", "y", "name", "npc", "npcName"}}
                                     | {"only": {"classes": candidate["classes"]} if candidate.get("classes") else candidate.get("only")}
                                     for candidate in candidates]
            if goal["t"] == "enter":
                goal["t"] = "goto"
            if goal["t"] == "die":
                goal["t"] = "goto"
                goal["text"] = "Travel to " + goal.get("location", "the next stop")
                goal["note"] = "Travel on foot to the marked destination. Follow roads and terrain."
                step["text"], step["detail"] = goal["text"], goal["note"]
                stats["deathSkipsReplaced"] += 1
            step["goals"].append(goal)
        if not step["goals"]:
            step["superseded"] = True
    # Source 'along' objectives belong to the intervening outdoor loop, not a
    # stationary blocking stop. Move their final check immediately before the
    # authored hand-in deadline. Keep the original stable goal ID.
    for index, source_step in enumerate(guide["steps"]):
        along = source_step.get("along")
        step = route["steps"][index]
        if not along or not step["goals"]:
            continue
        match = re.fullmatch(r"q(\d+)", along)
        if match:
            deadline = int(match[1])
            target = next((s for s in route["steps"][index + 1:] if any(g.get("quest") == deadline and g["t"] == "turnin" for g in s["goals"])), None)
        else:
            destination = next((i for i,s in enumerate(guide["steps"]) if i>index and s.get("label")==along), None)
            target = route["steps"][destination] if destination is not None else None
        assert target, (route_id, along)
        moved = step["goals"]
        for goal in moved:
            goal["note"] = ((goal.get("note") or step.get("detail") or "") + " Collect these while following the outdoor loop; finish before this hand-in.").strip()
        target["goals"] = moved + target["goals"]
        step["goals"] = []
        step["superseded"] = True
        review["backgroundMoves"].append(dict(source=step["id"], deadline=target["id"], goals=[g["id"] for g in moved]))
        stats["backgroundObjectivesBatched"] += len(moved)
    # Keep the source's explicit solo XP gates. Native XP, including fractional
    # levels, decides when these stop; no dungeon XP or invented quest XP.
    for step in route["steps"]:
        for goal in step["goals"]:
            if goal["t"] == "level" and goal.get("grind"):
                stats["soloGrindGates"] += 1
    routes.append(route)
    reviews.append(review)

ids = {r["id"] for r in routes}
assert all(not r.get("next") or r["next"] in ids for r in routes), "Missing next-route link"
assert not any(g.get("quest") in excluded for r in routes for s in r["steps"] for g in s["goals"])
assert not any(g["t"] == "die" or g.get("group") for r in routes for s in r["steps"] for g in s["goals"])
assert not any(re.search(r"\{[a-z]+:\d+\}", text) for r in routes for s in r["steps"] for text in [s["text"], s.get("detail") or ""])
text = "local addonName, ns = ...\n-- Generated by tools/Import-SoloRoutes.py. Polestar GPL-3.0-only, pinned " + REVISION + ".\n-- Literal factories defer inactive-faction and other-race table allocation.\nns.Data.soloRouteFactories = {\n"
text += ",\n".join("{faction=" + lua(r["faction"]) + ",races=" + lua(r.get("races")) + ",build=function() return " + lua(r) + " end}" for r in routes) + "\n}\n"
(DEST / "Data/SoloRoutes.lua").write_text(text, encoding="utf-8")
manifest_path = DEST / "SOURCE-MANIFEST.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["sources"] = [r for r in manifest["sources"] if r.get("component") != "solo-leveling"] + inputs
manifest["counts"]["soloLevelingRoutes"] = len(routes)
manifest["counts"]["soloLevelingSteps"] = sum(len(r["steps"]) for r in routes)
manifest["counts"]["soloLevelingGoals"] = sum(len(s["goals"]) for r in routes for s in r["steps"])
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(dict(revision=REVISION, stats=dict(stats), routes=reviews,
                                excludedQuests=excluded, limits="Structural/source review; no client timings or measured XP/hr proof."), indent=2) + "\n", encoding="utf-8")
print(json.dumps(dict(routes=len(routes), steps=manifest["counts"]["soloLevelingSteps"], goals=manifest["counts"]["soloLevelingGoals"], **stats), indent=2))
