local addonName, ns = ...
-- Only current authored Forever records enter the live dungeon/collection catalog.
local live=ns.Data.liveForever
if live then
    ns.Data.journals=live.journals
    ns.Data.dungeons=live.dungeons
    local books={}
    for _,record in ipairs(ns.Data.collections or {}) do
        local quest=live.bookQuests[record.item]
        if quest and live.donationQuests[quest] then
            record.quest=quest;record.foreverLive=true;record.referenceOnly=false
            record.source="Library Guide Forever + ATT Forever (MIT)"
            if record.item==210177 then record.x=nil;record.y=nil;record.locations={};record.detail="Pickup coordinates disputed; no precise destination offered." end
            books[#books+1]=record
        end
    end
    ns.Data.collections=books
end
-- Old trees, effects and Legacy facts cannot masquerade as current native data.
-- Original licensed snapshots remain in corresponding-source inputs for reproduction.
ns.Data.talents={}
ns.Data.talentSpells={}
ns.Data.talentEffects={}
ns.Data.effects={}
ns.Data.referenceBuilds={}
ns.Data.referenceTalents={}

ns.Data.gearProfiles=nil
ns.Data.firstTalentLevel=10

ns.Data.effectCoverage={}

-- Forever Theramore contacts move between quest phases. Keep objective and
-- return locations separate from the next pickup.
local inn={map=1445,x=66.2,y=45.1,place="Sully McCleary, inside the Theramore inn"}
local graveyard={map=1445,x=63.4,y=42.4,place="Sully McCleary, at the graveyard west of Theramore"}
ns.Data.alcazContacts={
    [95194]={complete=inn,turnin=inn},
    [95196]={accept=inn,complete=graveyard,turnin=graveyard},
    [95198]={complete={map=1445}},
    [95262]={accept=graveyard},
    [96381]={accept=graveyard,turnin=graveyard},
}
for _,dungeon in ipairs(ns.Data.dungeons or {}) do if dungeon.slug=="alcaz-prison" then
    for _,quest in ipairs(dungeon) do
        local contact=ns.Data.alcazContacts[quest.id]
        if contact then
            quest.startAt=contact.accept or quest.startAt
            quest.turnInAt=contact.turnin or quest.turnInAt
            quest.objectiveAt=contact.complete
        end
    end
    break
end end

-- Forever player-reported quest reward, corroborated by the pinned
-- Forever quest comparison export. Preserve it as an association only.
local support=ns.Data.questSupport
if support and support.quests and not support.quests[94435] then
    support.quests[94435]={name="A Lesson in Divinity",items={},rewards={6866},
        source="https://guide.wow4ever.se/en/quests/94435"}
end
