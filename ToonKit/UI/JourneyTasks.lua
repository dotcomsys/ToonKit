local addonName, ns = ...
local U,M,J=ns.UI,ns.Main,ns.Journey
function J.FocusObjective(goal,skip)
    local view=J.View();local bundle=view.bundle
    if view.paused or view.approach or not bundle or not goal.id then return end
    local found=false
    for _,g in ipairs(bundle.members) do if g.id==goal.id and not J.GoalDone(g) then found=true;break end end
    if not found then return end
    if skip then view.goal=goal;J.Skip(view,false);return end
    J.focusGoal={route=ns.char.route,index=view.index,id=goal.id}
    J.GoalWaypoint(goal);ns.Emit("STATE_CHANGED")
end
-- One task header with interactive child counters, rather than separate tasks
-- or an opaque concatenated label. Child rows share the parent's frame pool.
function M.RenderTaskMembers(parent,bundle,width,offset)
    parent.taskRows=parent.taskRows or {}
    for _,row in ipairs(parent.taskRows) do row:Hide() end
    if not bundle then return 0 end
    local y=offset
    for n,goal in ipairs(bundle.members) do
        local row=parent.taskRows[n]
        if not row then
            row=CreateFrame("Button",nil,parent);parent.taskRows[n]=row
            row.label=U.Label(row,"",24,-3,width-60,"GameFontHighlight")
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",3,-4);row.icon:SetSize(14,14)
            row.skip=CreateFrame("Button",nil,row);row.skip:SetSize(22,22);row.skip:SetPoint("TOPRIGHT",0,0)
            row.skip:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");row.skip:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
            row.mark=row.skip:CreateTexture(nil,"OVERLAY");row.mark:SetAllPoints()
            row:SetScript("OnClick",function(self)
                if self.goal.id then J.FocusObjective(self.goal) else J.GoalWaypoint(self.goal) end
            end)
            row.skip:SetScript("OnClick",function() J.FocusObjective(row.goal,true) end)
        end
        row.goal=goal;local done,evidence=J.GoalDone(goal);local progress=not goal.nativeText and J.Progress(goal)
        local text=J.GoalText(goal)
        if progress and progress:match("%d+%s*/%s*%d+") then text=text:gsub(" x%d+$","") end
        row.label:SetWidth(width-68);row.label:SetHeight(0);row.label:SetText(text..(progress and "  "..progress or ""))
        row.label:SetTextColor(done and .52 or .92,done and .55 or .86,done and .49 or .71,1)
        row.icon:SetTexture(M.JourneyIcon(goal,done,evidence));row:SetSize(width-12,math.max(23,row.label:GetStringHeight()+7))
        row:ClearAllPoints();row:SetPoint("TOPLEFT",12,-y)
        row.mark:SetTexture(evidence=="skipped" and "Interface\\Buttons\\UI-GroupLoot-Pass-Up" or "Interface\\Buttons\\UI-CheckBox-Check");row.mark:SetShown(done==true)
        row.skip:SetShown(goal.id~=nil);row.skip:SetEnabled(not done and not ns.char.journeyPaused)
        local detail=J.ObjectiveDetail(goal)
        U.Tooltip(row,text,{detail.source or "",goal.note or "",done and (evidence=="skipped" and "Skipped manually; not completed." or "Completion recorded from quest evidence.") or "Click to follow this objective within the task. Other counters keep tracking."},detail.link)
        U.Tooltip(row.skip,"Skip this objective",{text,"Skips only this objective. Undo restores it; no quest completion is recorded."})
        row:Show();y=y+row:GetHeight()
    end
    return y-offset
end
