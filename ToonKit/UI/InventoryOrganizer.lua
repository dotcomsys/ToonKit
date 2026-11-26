local addonName, ns = ...
local O={page="Groups",index=1};ns.InventoryOrganizer=O
local U,I=ns.UI,ns.InventoryRules
local bagFlags={{"ClassEquipment","Equipment"},{"ClassConsumables","Consumables"},{"ClassProfessionGoods","Trade goods"},{"ClassJunk","Junk"},{"ClassQuestItems","Quest items"},{"ClassReagents","Reagents"},{"DisableAutoSort","Exclude from cleanup"},{"ExcludeJunkSell","Exclude from selling junk"}}
function O.BagFlag(bag,key,value)
    if not ns.Inventory.IsPlayerBag(bag) then return nil,"Not a player bag." end
    local api=C_Container;local flag=Enum and Enum.BagSlotFlags and Enum.BagSlotFlags[key]
    local get,set
    if bag==0 then
        if key=="DisableAutoSort" then get="GetBackpackAutosortDisabled";set="SetBackpackAutosortDisabled"
        elseif key=="ExcludeJunkSell" then get="GetBackpackSellJunkDisabled";set="SetBackpackSellJunkDisabled"
        else return nil,"Backpack destinations are managed by the client." end
    else
        if key~="DisableAutoSort" and key~="ExcludeJunkSell" then
            -- Match the native filter menu: specialized/reagent bags cannot select destinations.
            if type(ContainerFrame_CanContainerUseFilterMenu)~="function" or not ContainerFrame_CanContainerUseFilterMenu(bag) then return nil,"This bag does not support native destination filters." end
        end
        if type(flag)~="number" then return nil,"This filter is unavailable in this client." end
        get="GetBagSlotFlag";set="SetBagSlotFlag"
    end
    if not api or type(api[get])~="function" or type(api[set])~="function" then return nil,"Native bag preferences are unavailable." end
    local current
    if bag==0 then current=ns.Safe(ns.API.Call("C_Container",get)) else current=ns.Safe(ns.API.Call("C_Container",get,bag,flag)) end
    if type(current)~="boolean" then return nil,"The client did not return a readable bag preference." end
    if value~=nil then
        if InCombatLockdown() then return nil,"Change bag preferences after combat." end
        if type(value)~="boolean" then return nil,"Invalid preference." end
        if bag==0 then api[set](value) else api[set](bag,flag,value) end
        -- Native UI caches filter flags separately; let its normal update event invalidate that cache.
        return value
    end
    return current
end
function O.BagPreferences(bag)
    if not O.bagFrame then
        local f=U.Window(540,500,"Bag destinations","bagDestinations");O.bagFrame=f
        f.body=CreateFrame("Frame",nil,f);f.body:SetPoint("TOPLEFT",20,-48);f.body:SetSize(500,425);f.body._managed=true
    end
    local f=O.bagFrame;U.Release(f.body);O.bag=bag or O.bag or 0
    local choices={};for _,id in ipairs(ns.API.Bags()) do if id==0 or ((ns.State.bagSlots or {})[id] or 0)>0 then choices[#choices+1]={value=id,label=id==0 and "Backpack" or "Bag "..id} end end
    local pick=U.Cycle(f.body,choices,O.bag,465,function(v) O.BagPreferences(v) end);pick:SetPoint("TOPLEFT",0,0)
    U.Label(f.body,"Choose destinations for Blizzard's cleanup. Preferences are saved by the client. Specialized bags keep their native restrictions.",0,-38,490,"GameFontHighlightSmall")
    for index,record in ipairs(bagFlags) do local key=record[1];local selected,reason=O.BagFlag(O.bag,key)
        local check=U.Check(f.body,record[2],selected==true,function(selfValue)
            local result,why=O.BagFlag(O.bag,key,selfValue);if result==nil then ns.Message(why) end;O.BagPreferences(O.bag)
        end);check:SetPoint("TOPLEFT",0,-82-(index-1)*32);check.text:SetWidth(430);check:SetEnabled(selected~=nil and not InCombatLockdown())
        if reason then U.Tooltip(check,record[2],{reason}) end
    end
    U.Label(f.body,"Categories organize the display independently. Use Assign categories to place individual item types in your own groups.",0,-345,490,"GameFontHighlightSmall")
    local tidy=U.Button(f.body,"Apply cleanup",170,function() if InCombatLockdown() then ns.Message("Clean up after combat.") else ns.API.Call("C_Container","SortBags") end end);tidy:SetPoint("TOPLEFT",0,-395)
    local categories=U.Button(f.body,"Assign categories",170,function() f:Hide();ns.Inventory.assignMode=true;ns.Inventory.Show() end);categories:SetPoint("TOPLEFT",190,-395)
    f:Show()
end
local function label(text,y) return U.Label(O.body,text,10,y,690,"GameFontHighlight") end
local function button(text,x,y,width,callback)
    local b=U.Button(O.body,text,width,callback);b:SetPoint("TOPLEFT",x,y);return b
end
local function groups()
    local rows={};for _,g in ipairs(I.Groups()) do if g.id~="Reagent bag" then rows[#rows+1]={value=g.id,label=g.name} end end;return rows
end
local sorts={{value="category",label="Name"},{value="quality",label="Quality"},{value="new",label="New first"},{value="level",label="Item level"},{value="value",label="Sell value"},{value="bag",label="Bag / slot"}}
local kinds={{value="search",label="Search expression"},{value="item",label="Item ID"},{value="name",label="Name contains"},{value="quality",label="Quality (0-8)"},{value="class",label="Item class ID"},{value="required",label="Required level at most"},{value="equipment",label="Equipment"},{value="quest",label="Quest items"},{value="reagent",label="Crafting materials"},{value="unusable",label="Unusable equipment"},{value="new",label="New items"},{value="tracked",label="Tracked acquisitions"}}
function O.Select(rows,key,parent,width,x,y,name)
    if #rows==0 then O[key]=nil;return nil end
    local choices={};for i,row in ipairs(rows) do choices[#choices+1]={value=i,label=name(row,i)} end
    local selected=math.max(1,math.min(O[key] or 1,#rows));O[key]=selected
    local pick=U.Cycle(parent,choices,selected,width,function(value) O[key]=value;O.Refresh() end);pick:SetPoint("TOPLEFT",x,y)
    return selected
end
function O.Refresh()
    if not O.frame or not O.frame:IsShown() then return end
    U.Release(O.body)
    if O.page=="Groups" then
        O.GroupsView()
    elseif O.page=="Rules" then
        label("Rules run in order; the first match wins. Manual item assignments take priority.",-4)
        O.ruleGroup=I.Exists(O.ruleGroup) and O.ruleGroup or "Equipment";O.kind=O.kind or "item"
        local g=U.Cycle(O.body,groups,O.ruleGroup,225,function(v) O.ruleGroup=v end);g:SetPoint("TOPLEFT",10,-36)
        local k=U.Cycle(O.body,kinds,O.kind,225,function(v) O.kind=v end);k:SetPoint("TOPLEFT",245,-36)
        local value=U.Edit(O.body,100,"");value:SetPoint("TOPLEFT",485,-36);value:SetMaxLetters(100)
        button("Add",600,-36,75,function() local ok,why=I.AddRule(O.ruleGroup,O.kind,value:GetText());if not ok then ns.Message(why) else O.Refresh();if ns.Inventory then ns.Inventory.Render() end end end)
        label("Enter a value for ID, name, quality, item class or required level; other rules need none.",-72)
        local rules=ns.db.settings.bagRules;local selected=O.Select(rules,"selectedRule",O.body,650,10,-106,function(r,i) return i..". "..I.Name(r.group).." / "..r.kind end)
        for n=selected or 1,selected or 0 do
            local index=n;local r=rules[n];local y=-152
            local description=label(n..". "..I.Name(r.group).." / "..r.kind..(r.value and tostring(r.value)~="" and ": "..tostring(r.value) or ""),y)
            local actionY=y-description:GetStringHeight()-8
            button(r.enabled==false and "Enable" or "Disable",10,actionY,90,function() r.enabled=r.enabled==false;ns.Emit("STATE_CHANGED");O.Refresh() end)
            button("Earlier",110,actionY,90,function() if index>1 then rules[index],rules[index-1]=rules[index-1],rules[index];ns.Emit("STATE_CHANGED");O.Refresh() end end)
            button("Later",210,actionY,90,function() if index<#rules then rules[index],rules[index+1]=rules[index+1],rules[index];ns.Emit("STATE_CHANGED");O.Refresh() end end)
            button("Remove",310,actionY,90,function() table.remove(rules,index);ns.Emit("STATE_CHANGED");O.Refresh() end)
        end
    elseif O.page=="History" then
        local choices={};for key,character in pairs(ns.db.characters) do if character.bagSnapshot then choices[#choices+1]={value=key,label=character.identity and ((character.identity.name or "Character").." - "..(character.identity.realm or "Realm").." ("..tostring(character.identity.level or "?").." "..(character.identity.class or "")..")") or tostring(key)} end end
        table.sort(choices,function(a,b) return a.label<b.label end)
        O.character=O.character or (choices[1] and choices[1].value)
        local choose=U.Cycle(O.body,choices,O.character,300,function(v) O.character=v;O.index=1;O.Refresh() end);choose:SetPoint("TOPLEFT",10,-4)
        local search=U.Edit(O.body,320,O.query or "",function(v) O.query=v:lower();O.index=1;O.Refresh() end);search:SetPoint("TOPLEFT",330,-4);search:SetMaxLetters(100)
        local character=ns.db.characters[O.character];local snapshot=character and character.bagSnapshot
        if not snapshot then label("Log into a character once to record its normal bags.",-50);return end
        local when=snapshot.recorded and snapshot.recorded>0 and type(date)=="function" and date("%Y-%m-%d %H:%M",snapshot.recorded) or "unknown time"
        label("Read-only bag snapshot: "..when..". "..(snapshot.free or 0).." free / "..snapshot.capacity.." slots.",-44)
        local items={};for _,item in pairs(snapshot.items) do if (item.name or tostring(item.id)):lower():find(O.query or "",1,true) then items[#items+1]=item end end
        table.sort(items,function(a,b) return (a.name or tostring(a.id))<(b.name or tostring(b.id)) end)
        local selected=O.Select(items,"historyItem",O.body,650,10,-86,function(item) return (item.name or "Item #"..item.id).." x"..item.count end)
        for n=selected or 1,selected or 0 do local item=items[n];local y=-128
            local row=button((item.name or "Item #"..item.id).."  x"..item.count,10,y,650,function() if HandleModifiedItemClick then HandleModifiedItemClick(item.link or "item:"..item.id) end end)
            U.Tooltip(row,item.name,nil,item.link or "item:"..item.id)
        end
    elseif O.page=="Supplies" then O.SuppliesView()
    else
        label("Search uses names or IDs. Spaces or & mean AND; | means OR; ! or ~ excludes. Parentheses group expressions.",-4)
        label('Quotes keep words together: "healing potion"   |   group:"quest items"',-48)
        label("Fields: id:123  q:rare  level:10-20  ilvl:>=30  bag:0  type:cloth  slot:head",-92)
        label("Flags: keep  new  tracked  upgrade  bound  boe  junk  equipment  quest. Example: q:rare !bound | tracked",-136)
        label("Compare equipment with Blizzard tooltips; automatic upgrade classification is disabled.",-180)
        local mode=U.Cycle(O.body,{{value="filter",label="Hide nonmatches"},{value="dim",label="Dim nonmatches"}},ns.db.settings.bagSearchMode,270,function(v) ns.SetSetting("bagSearchMode",v) end);mode:SetPoint("TOPLEFT",10,-226)
        label("History search matches recorded item names and IDs. Snapshots refresh when that character logs in.",-280)
    end
end
function O.Show(page)
    if not O.frame then
        O.frame=U.Window(750,550,ns.Brand.shortName.." - Bag organizer","organizer")
        for i,name in ipairs({"Groups","Rules","Supplies","History","Search"}) do local choice=name;local b=U.Button(O.frame,name,110,function() O.Show(choice) end);b:SetPoint("TOPLEFT",20+(i-1)*116,-48) end
        O.body=CreateFrame("Frame",nil,O.frame);O.body:SetPoint("TOPLEFT",20,-90);O.body:SetSize(710,430);O.body._managed=true
    end
    O.page=page or O.page;O.index=1;O.frame:Show();O.Refresh()
end
function O.Assign(item)
    if ns.Inventory and ns.Inventory.assignMode then ns.Inventory.inlineAssignment=item;ns.Inventory.Render();return end

    if not O.assignFrame then
        local f=U.Window(420,310,"Assign item group","assignGroup");O.assignFrame=f
        f.body=CreateFrame("Frame",nil,f);f.body:SetPoint("TOPLEFT",20,-48);f.body:SetSize(380,245);f.body._managed=true
    end
    local f=O.assignFrame;U.Release(f.body)
    U.Label(f.body,item.info and item.info.name or "Item #"..item.id,0,0,370)
    local selected=(ns.char.itemGroups or {})[item.id] or "automatic"
    local rows={{value="automatic",label="Automatic rules"}};for _,row in ipairs(groups()) do rows[#rows+1]=row end
    local choose=U.Cycle(f.body,rows,selected,360,function(v) selected=v end);choose:SetPoint("TOPLEFT",0,-32)
    local apply=U.Button(f.body,"Apply to this item ID",200,function() ns.char.itemGroups=ns.char.itemGroups or {};ns.char.itemGroups[item.id]=selected~="automatic" and selected or nil;ns.Emit("STATE_CHANGED");f:Hide() end);apply:SetPoint("TOPLEFT",0,-78)
    if item.info and ns.Data.equipSlots[item.info.equip] then
        local compare=U.Button(f.body,"Compare",130,function() ns.ItemCompare.Show({id=item.id,info=item.info,link=item.link,source="In your bags",required=item.info.required,actionable=ns.API.ItemEligibility(item.id,item.info)==true},ns.Data.equipSlots[item.info.equip][1]) end);compare:SetPoint("TOPLEFT",225,-78)
    end
    local create=U.Edit(f.body,220,"");create:SetPoint("TOPLEFT",0,-126);create:SetMaxLetters(40);U.Placeholder(create,"New category name")
    local add=U.Button(f.body,"Create & assign",130,function()
        local id,why=I.CreateGroup(create:GetText());if not id then ns.Message(why);return end
        ns.char.itemGroups=ns.char.itemGroups or {};ns.char.itemGroups[item.id]=id;ns.Emit("STATE_CHANGED");f:Hide()
    end);add:SetPoint("TOPLEFT",230,-126)
    U.Label(f.body,"Applies to every copy of this item ID. Physical bag slots stay under Blizzard's item interactions and cleanup preferences.",0,-170,365,"GameFontHighlightSmall")
    f:Show()
end


function O.GroupsView()
    local all=I.Groups();O.group=I.Exists(O.group) and O.group or all[1].id
    local left=U.Panel(O.body,230,418,0,0,"categoryList")
    local pick=U.Cycle(left,groups,O.group,202,function(id) O.group=id;O.Refresh() end);pick:SetPoint("TOPLEFT",12,-12)
    U.Label(left,"Select a category to edit its name, matching rules and ordering.",12,-65,202,"GameFontHighlight")
    U.Label(left,#all.." categories",12,-150,202,"GameFontNormal")
    local right=U.Panel(O.body,468,418,242,0,"categoryEditor")
    U.Label(right,I.Name(O.group),12,-12,440,"GameFontNormalLarge")
    local custom,index
    for i,g in ipairs(ns.db.settings.bagGroups) do if g.id==O.group then custom=g;index=i end end
    local name=U.Edit(right,285,custom and custom.name or "");name:SetPoint("TOPLEFT",14,-46);name:SetMaxLetters(40);U.Placeholder(name,"New category name")
    local action=U.Button(right,custom and "Rename" or "Create",130,function()
        if custom then
            local value=name:GetText():match("^%s*(.-)%s*$");if value=="" then ns.Message("Enter a category name.");return end
            for _,g in ipairs(I.Groups()) do if g.id~=O.group and g.name:lower()==value:lower() then ns.Message("That category name is already in use.");return end end
            custom.name=value;ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED");O.Refresh()
        else local id,why=I.CreateGroup(name:GetText());if id then O.group=id;O.Refresh() else ns.Message(why) end end
    end);action:SetPoint("TOPLEFT",315,-46)
    local rule
    for _,r in ipairs(ns.db.settings.bagRules) do if r.group==O.group and r.kind=="search" then rule=r;break end end
    U.Label(right,"Match items using search",14,-86,430,"GameFontNormal")
    local expression=U.Edit(right,285,rule and rule.value or "",function(v) O.preview=v;O.previewGroup=O.group;O.previewPage=1;O.Refresh() end);expression:SetPoint("TOPLEFT",14,-112);expression:SetMaxLetters(200);U.Placeholder(expression,"boe | tracked   or   type:cloth")
    local apply=U.Button(right,"Save search",130,function()
        local value=expression:GetText():match("^%s*(.-)%s*$")
        if value=="" then
            for i=#ns.db.settings.bagRules,1,-1 do local r=ns.db.settings.bagRules[i];if r.group==O.group and r.kind=="search" then table.remove(ns.db.settings.bagRules,i) end end
        elseif rule then rule.value=value;rule.enabled=true
        else local ok,why=I.AddRule(O.group,"search",value);if not ok then ns.Message(why);return end end
        O.preview=nil;ns.Emit("STATE_CHANGED");O.Refresh()
    end);apply:SetPoint("TOPLEFT",315,-112)
    U.Label(right,"First matching rule wins. Manual item assignments take priority. BoE requires readable native binding data. Enter previews; Save applies.",14,-148,435,"GameFontHighlightSmall")
    local sort=U.Cycle(right,sorts,ns.db.settings.bagGroupSort[O.group] or ns.db.settings.bagSort,285,function(v) ns.db.settings.bagGroupSort[O.group]=v;ns.Emit("STATE_CHANGED") end,"Sort: ");sort:SetPoint("TOPLEFT",14,-212)
    local hidden=U.Check(right,"Hidden",ns.db.settings.bagHiddenGroups[O.group],function(v) ns.db.settings.bagHiddenGroups[O.group]=v or nil;ns.Emit("STATE_CHANGED") end);hidden:SetPoint("TOPLEFT",315,-212);hidden.text:SetWidth(100)
    U.Tooltip(hidden,"Hide this category",{"Hidden categories remain searchable. Tools can reveal all hidden categories; explicit category filters also reveal them."})
    local query=O.previewGroup==O.group and O.preview or nil
    if query~=nil then expression:SetText(query) end
    local items={}
    for _,item in ipairs(ns.State.bags) do if item.id and (query~=nil and I.Search(item,query,I.Basic(item)) or query==nil and I.Category(item)==O.group) then items[#items+1]=item end end
    local selected=O.Select(items,"previewItem",right,430,14,-276,function(item) return item.info and item.info.name or "Item #"..item.id end)
    U.Label(right,(query~=nil and "Search preview: " or "Currently assigned: ")..#items.." items",14,-250,430,"GameFontNormalSmall")
    if selected then local item=items[selected];local icon=U.Item(right,item.id,14,-316,32,item.link);icon:SetScript("OnClick",function() O.Assign(item) end) end
    local rules=U.Button(right,"Ordered rules",130,function() O.ruleGroup=O.group;O.Show("Rules") end);rules:SetPoint("TOPLEFT",315,-322)
    if not custom then
        local earlier=U.Button(right,"Earlier",100,function() I.MoveGroup(O.group,-1);O.Refresh() end);earlier:SetPoint("TOPLEFT",14,-371)
        local later=U.Button(right,"Later",100,function() I.MoveGroup(O.group,1);O.Refresh() end);later:SetPoint("TOPLEFT",126,-371)
    end
    if custom then
        local earlier=U.Button(right,"Earlier",100,function() I.MoveGroup(O.group,-1);O.Refresh() end);earlier:SetPoint("TOPLEFT",14,-371)
        local later=U.Button(right,"Later",100,function() I.MoveGroup(O.group,1);O.Refresh() end);later:SetPoint("TOPLEFT",126,-371)
        local delete=U.Button(right,"Delete category",150,function() local id=O.group;U.Confirm("Delete category?","Delete "..I.Name(id).." and its rules and manual assignments? Items return to automatic categories.",function() I.DeleteGroup(id);O.group=nil;O.Refresh() end) end);delete:SetPoint("TOPLEFT",294,-371)
    end
end
function O.SuppliesView()
    local Q=ns.QuestSupplies;local data=ns.Data.questSupport
    label("Quest supplies: active quests, the guide and quests you choose to plan ahead.",-4)
    local search=U.Edit(O.body,450,O.supplySearch or "",function(v) O.supplySearch=v:lower();O.supplySelection=nil;O.supplyPage=1;O.Refresh() end);search:SetPoint("TOPLEFT",10,-34);U.Placeholder(search,"Search quest name or ID, then Enter")
    local choices={}
    for id,q in pairs(data.quests) do if next(q.items or {}) and (Q.Name(id).." "..id):lower():find(O.supplySearch or "",1,true) then choices[#choices+1]={value=id,label=Q.Name(id).." #"..id} end end
    table.sort(choices,function(a,b) return a.label<b.label end)
    O.supplySelection=O.supplySelection or choices[1] and choices[1].value
    local choose=U.Cycle(O.body,choices,O.supplySelection,450,function(v) O.supplySelection=v;O.supplyPage=1;O.Refresh() end);choose:SetPoint("TOPLEFT",10,-72)
    local id=O.supplySelection;if not id then label("No sourced supply records match this search.",-120);return end
    local pin=U.Check(O.body,"Plan ahead for this quest",(ns.char.questKeep or {})[id],function(v) Q.Pin(id,v);O.Refresh() end);pin:SetPoint("TOPLEFT",10,-110);pin.text:SetWidth(600)
    label("Listed item requirements are source references. Actual completion removes keep advice.",-150)
    local needs=Q.Plan(id,"Preview");local selected=O.Select(needs,"supplyItem",O.body,650,10,-184,function(item) local info=ns.API.Item(item.id);return (info and info.name or "Item #"..item.id).." | Have "..item.have end)
    for i=selected or 1,selected or 0 do local item=needs[i];local y=-230;local info=ns.API.Item(item.id)
        U.Item(O.body,item.id,12,y,32,info and info.link)
        U.Label(O.body,(info and info.name or "Item #"..item.id).."  |  "..(item.count and "Keep "..item.count or "Quantity not supplied").."  |  Have "..item.have,55,y-2,625,"GameFontNormal")
        U.Label(O.body,item.via and "Through "..Q.Name(item.via).." for "..Q.Name(id) or "For "..Q.Name(id),55,y-22,625,"GameFontHighlightSmall")
    end
    button("Advice on / off",480,-375,190,function() ns.SetSetting("questKeepAdvice",not ns.db.settings.questKeepAdvice);O.Refresh() end)
end
