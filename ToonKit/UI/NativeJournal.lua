local addonName, ns = ...
local M,U,D=ns.Main,ns.UI,ns.Journal
function M.NativeEncounter(d,boss)
    local native=D.NativeDetails(d,boss)
    if not native then return false end
    local controls=U.Options(M.body,{{value="native",label="Native journal"},{value="recorded",label="Recorded spells"}},M.encounterSource or "native",M.width-16,function(v) M.encounterSource=v;M.Render() end,2)
    controls:SetPoint("TOPLEFT",8,M.y);M.y=M.y-controls:GetHeight()-10
    if M.encounterSource=="recorded" then return false end
    M.Action("Choose native difficulty",function()
        local choices,reason=D.NativeDifficulties(d)
        if not choices then ns.Message(reason);return end
        M.nativeDifficulties={slug=d.slug,choices=choices};M.Render()
    end,240)
    if M.nativeDifficulties and M.nativeDifficulties.slug==d.slug then
        local choose=U.Cycle(M.body,M.nativeDifficulties.choices,native.difficulty,M.width-16,function(value)
            local choices,reason=D.NativeDifficulties(d,value);if not choices then ns.Message(reason) end
            M.nativeSection=nil;M.Render()
        end,"Difficulty: ")
        choose:SetPoint("TOPLEFT",8,M.y);M.y=M.y-choose:GetHeight()-10
        M.Line("Your selection also changes Blizzard's journal difficulty. It does not change your group's instance difficulty.","GameFontHighlightSmall")
    end
    M.Line("Client journal #"..native.id..(native.difficulty and " | Native difficulty #"..native.difficulty or ""),"GameFontHighlightSmall")
    if native.description and native.description~="" then M.Line(native.description) end
    local rows={};for _,section in ipairs(native.sections) do rows[#rows+1]={value=section.id,label=section.path} end
    local selected=native.sections[1]
    for _,section in ipairs(native.sections) do if section.id==M.nativeSection then selected=section end end
    if selected then
        local choose=U.Cycle(M.body,rows,selected.id,M.width-16,function(v) M.nativeSection=v;M.Render() end,"Section: ")
        choose:SetPoint("TOPLEFT",8,M.y);M.y=M.y-choose:GetHeight()-10
        M.Heading((selected.icon and "|T"..selected.icon..":20|t " or "")..selected.title)
        for _,flag in ipairs(selected.flags or {}) do
            local title=ns.Safe(_G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag])
            local description=ns.Safe(_G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag])
            if type(title)=="string" then M.Line(title..(type(description)=="string" and ": "..description or ""),"GameFontNormalSmall") end
        end
        if selected.description and selected.description~="" then M.Line(selected.description) end
        if selected.spell then
            local description=ns.Safe(ns.API.Call("C_Spell","GetSpellDescription",selected.spell))
            if description and description~=selected.description then M.Line(description) end
        end
    else M.Line("The client has not supplied encounter sections for this difficulty.") end
    local note=D.Note(d,boss);if note then M.Heading("Your notes");M.Line(note) end
    M.Action("Edit personal notes",function() M.EncounterNotes(d,boss) end,200)
    return true
end
for _,event in ipairs({"EJ_DIFFICULTY_UPDATE","EJ_LOOT_DATA_RECIEVED"}) do ns.On(event,function()
    if ns.UI.main and ns.UI.main:IsShown() and M.tab=="Adventure" and M.sub=="Dungeons" then ns.After("nativeJournalRender",M.Render) end
end) end
local map=M.DungeonMap
function M.DungeonMap(d,height)
    local floors=D.NativeMaps(d)
    if #floors==0 then return map(d,height) end
    local choices={{value="entrance",label="Entrance area"}}
    for _,id in ipairs(floors) do
        local info=ns.API.Call("C_Map","GetMapInfo",id)
        choices[#choices+1]={value=tostring(id),label=info and ns.Safe(info.name) or "Floor map #"..id}
    end
    M.dungeonFloors=M.dungeonFloors or {};local current=M.dungeonFloors[d.slug] or "entrance"
    local choose=U.Cycle(M.body,choices,current,M.width-16,function(v) M.dungeonFloors[d.slug]=v;M.Render() end,"Map: ")
    choose:SetPoint("TOPLEFT",8,M.y);M.y=M.y-choose:GetHeight()-10
    if current=="entrance" then return map(d,height-40) end
    local id=tonumber(current);local panel=U.LocationMap(M.body,id,M.width-16,math.max(200,height-100))
    panel:SetPoint("TOPLEFT",8,M.y);M.y=M.y-panel:GetHeight()-8
    if panel.mapArea then
        local area=panel.mapArea
        for _,record in ipairs(D.NativeMapEncounters(id)) do
            local pin=U.IconButton(panel,"Interface\\TargetingFrame\\UI-TargetingFrame-Skull",record.name,function()
                for index,boss in ipairs(d.encounters or {}) do if boss.name==record.name then M.dungeonPage="Abilities";M.SelectBoss(index);return end end
            end,22)
            pin:SetPoint("CENTER",panel,"TOPLEFT",area.x+record.x*area.width,-area.y-record.y*area.height)
            U.Tooltip(pin,record.name,{"Native client encounter position."})
        end
    end
    M.Line("Native floor artwork and encounter positions. Missing client data remains unavailable.","GameFontHighlightSmall")
end
