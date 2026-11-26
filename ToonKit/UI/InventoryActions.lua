local addonName, ns = ...
local U,A=ns.UI,ns.InventoryActions
local V={};ns.InventoryActionView=V
local titles={sell="Review matching sales",deposit="Deposit matching carried items",withdraw="Withdraw matching bank items"}
function V.Render()
    local plan=V.plan;local f=V.frame;if not plan or not f or not f:IsShown() then return end
    U.Release(f.body);local width=880;local y=0
    local function line(text,font)
        local label=U.Label(f.body,text,0,y,width,font or "GameFontHighlightSmall");y=y-label:GetStringHeight()-9;return label
    end
    line(titles[plan.action],"GameFontNormalLarge")
    local scope={}
    if plan.bag~=nil then scope[#scope+1]="Bag "..plan.bag end
    if plan.group and plan.group~="All" then scope[#scope+1]=ns.InventoryRules.Name(plan.group) end
    if plan.query~="" then scope[#scope+1]="Search "..plan.query end
    line((#scope>0 and table.concat(scope," · ") or "All bags in this view").." · "..#plan.skipped.." stacks excluded")
    local selected,units,value=0,0,0
    for index,row in ipairs(plan.items) do if not plan.excluded[index] then selected=selected+1;units=units+row.count;value=value+(row.info.sellPrice or 0)*row.count end end
    line(selected.." stacks / "..units.." items"..(plan.action=="sell" and " · Verified vendor value "..ns.Gold.Format(value) or ""),"GameFontNormal")
    local choices={}
    for index,row in ipairs(plan.items) do
        choices[#choices+1]={value=index,label=(plan.excluded[index] and "Excluded: " or "")..row.info.name.." x"..row.count.." - bag "..row.bag..", slot "..row.slot}
    end
    V.selected=math.max(1,math.min(V.selected or 1,#choices))
    local roster=U.Roster(f.body,choices,V.selected,width,155,function(index) V.selected=index;V.Render() end,"reviewedItemAction")
    roster:SetPoint("TOPLEFT",0,y);y=y-roster:GetHeight()-10
    local row=plan.items[V.selected]
    if row then
        local item=U.Item(f.body,row.id,0,y,32,row.link)
        local inspect=U.Label(f.body,row.link.." x"..row.count,44,y-3,width-260,"GameFontHighlight");inspect:SetWordWrap(true)
        local exclude=U.Button(f.body,plan.excluded[V.selected] and "Include stack" or "Exclude stack",180,function()
            if plan.status~="review" then return end
            plan.excluded[V.selected]=not plan.excluded[V.selected];V.Render()
        end);exclude:SetPoint("TOPRIGHT",0,y);exclude:SetEnabled(plan.status=="review")
        y=y-math.max(36,inspect:GetStringHeight()+10)
        U.Tooltip(item,row.info.name,{"This exact stack is rechecked before the action. Native item clicks and drag behavior remain on their normal controls."},row.link)
    end
    local reasons={}
    for _,skip in ipairs(plan.skipped) do
        local label=(skip.name or "Item")..": "..(skip.reason or "Unavailable")
        reasons[#reasons+1]={value=#reasons+1,label=label}
    end
    if #reasons>0 then
        local skipped=U.Cycle(f.body,reasons,V.skip or 1,width,function(index) V.skip=index;V.Render() end,"Not included: ")
        skipped:SetPoint("TOPLEFT",0,y);y=y-skipped:GetHeight()-9
    end
    line(plan.action=="sell" and "Confirm to sell the selected poor-quality stacks. Items with unknown data or protected uses stay out of the selection." or
        "Transfers use the selected native bank type. Refund-protected account deposits stay on Blizzard's normal confirmation path. Closing this review, combat or a changed interaction stops the queue.")
    line("Status: "..plan.status.." | Confirmed stacks: "..plan.completed.." / "..(plan.selected or selected)..(plan.message and " | "..plan.message or ""),"GameFontNormal")
    local start=U.Button(f.body,plan.action=="sell" and "Sell reviewed selection" or "Transfer reviewed selection",270,function()
        local ok,reason=A.Start(plan);if not ok then ns.Message(reason) end;V.Render()
    end);start:SetPoint("TOPLEFT",0,y);start:SetEnabled(plan.status=="review" and selected>0)
    local cancel=U.Button(f.body,A.running==plan and "Stop queue" or "Back",180,function()
        if A.running==plan then A.Cancel() else f:Hide() end
    end);cancel:SetPoint("TOPLEFT",290,y)
    f.body:SetHeight(math.max(1,-y+40))
    f:SetHeight(math.max(420,-y+115))
end
function V.Show(action,options)
    local plan,reason=A.Preview(action,options)
    if not plan then ns.Message(reason);return false end
    if not V.frame then
        local f=U.Window(930,570,"Item actions","inventoryActions");f:SetFrameStrata("DIALOG");V.frame=f
        f.body=CreateFrame("Frame",nil,f);f.body._managed=true;f.body:SetPoint("TOPLEFT",24,-60);f.body:SetSize(880,500)
        f:HookScript("OnHide",function() if A.running==V.plan then A.Cancel("The review was closed.") end end)
    end
    V.plan=plan;V.selected=1;V.skip=1;V.frame:Show();V.Render();return true
end
ns.Listen("INVENTORY_ACTION_CHANGED",function() if V.frame and V.frame:IsShown() then ns.After("itemActionView",V.Render) end end)
