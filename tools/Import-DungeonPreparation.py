"""Decode pickup and return points from pinned EverythingQuests Forever tables."""
import hashlib
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent.parent
REVISION = "c720150fe0b73db7d703457824571841c83aafe6"
CATEGORY_PATH = "everythingquests-route-metadata/76000b2ab05ed1684f465b61bfdd07eb30dff1e3/QuestCategory_Forever.lua"
QUEST_ROW = re.compile(r"\s*\[(\d+)\]\s*=\s*\{(.*)\},?\s*")
MAP_ROW = re.compile(r"\s*\[(\d+)\]\s*=\s*\{([\d,\s]*)\}\s*(?:,|$)")


def read_pinned(manifest, name, relative=None):
    if relative:
        record = next(record for record in manifest["sources"] if record.get("localFile") == relative)
    else:
        records = [record for record in manifest["sources"]
                   if record.get("repository") == "wheelbarrel00/EverythingQuests" and record.get("file") == "Data/" + name]
        record = next((record for record in records if record.get("revision") == REVISION), records[0])
        relative = Path("EverythingQuests/Data") / name
    candidates = [ROOT / ".sources/content" / relative]
    candidates += [ROOT / ".sources/content/.by-sha256" / record["sha256"] / relative]
    candidates += [directory / relative for directory in sorted((ROOT / ".sources").glob("recovered-*"))]
    for path in candidates:
        try:
            content = path.read_bytes()
        except OSError:
            continue
        if hashlib.sha256(content).hexdigest() == record["sha256"]:
            return content.decode("utf-8-sig")
    raise ValueError(f"Missing pinned EverythingQuests input {name} at {record.get('revision')}")


def decode_table(source, key):
    header = re.search(rf"^\s*{re.escape(key)}\s*=\s*\{{\s*$", source, re.MULTILINE)
    if not header:
        raise ValueError(f"Missing {key} location table")
    rows = {}
    for line in source[header.end():].splitlines():
        line = line.strip()
        if line in ("}", "},"):
            return rows
        if not line or line.startswith("--"):
            continue
        quest = QUEST_ROW.fullmatch(line)
        if not quest:
            raise ValueError(f"Unexpected {key} quest row: {line}")
        body = quest.group(2)
        points = []
        while body:
            match = MAP_ROW.match(body)
            if not match:
                raise ValueError(f"Unexpected map data for quest {quest.group(1)}: {body}")
            body = body[match.end():].strip()
            for value in match.group(2).split(","):
                if not value.strip():
                    continue
                packed = int(value)
                provider, remainder = divmod(packed, 10**9)
                kind, coordinates = divmod(remainder, 10**8)
                x, y = divmod(coordinates, 10**4)
                points.append(dict(map=int(match.group(1)), x=x / 10**4, y=y / 10**4,
                                   provider=provider, kind=kind))
        rows[int(quest.group(1))] = sorted(points, key=lambda point: point["map"])
    raise ValueError(f"Unterminated {key} location table")


def encode(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + encode(key) + "]=" + encode(child) for key, child in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(encode, value)) + "}"
    if isinstance(value, str):
        return json.dumps(value)
    return str(value)


manifest = json.loads((ROOT / "ToonKit/SOURCE-MANIFEST.json").read_text(encoding="utf-8-sig"))
pickup = decode_table(read_pinned(manifest, "QuestAvailable_Forever.lua"), "start")
turnin = decode_table(read_pinned(manifest, "QuestTurnIn_Forever.lua"), "ns.CLASSIC_QUEST_TURNIN")
category = read_pinned(manifest, "QuestCategory_Forever.lua", CATEGORY_PATH)
flags = {int(quest): int(mask) for quest, mask in re.findall(r"^\s*\[(\d+)\]=(\d+),\s*$", category, re.MULTILINE)}
if not flags or len(flags) != category.count("]="):
    raise ValueError("Unexpected EverythingQuests Forever category format")
data = {quest: dict(pickup=pickup.get(quest, []), turnin=turnin.get(quest, []))
        for quest in sorted(pickup.keys() | turnin.keys())}
output = ROOT / "ToonKit/Data/DungeonPreparation.lua"
output.write_text("local addonName, ns = ...\n"
                  "-- EverythingQuests Forever MIT; kinds 5/6 mark entrances, not NPC positions.\n"
                  "ns.Data.dungeonPreparation = " + encode(data) + "\n"
                  "ns.Data.foreverQuestCategories = " + encode(flags) + "\n", encoding="utf-8", newline="\n")
print(f"Forever quest locations: {len(data)} quests; {len(pickup)} pickups; {len(turnin)} turn-ins")
