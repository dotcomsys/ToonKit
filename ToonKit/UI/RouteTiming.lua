local addonName, ns = ...
local M,U,R=ns.Main,ns.UI,ns.RouteTiming
local journey=M.Journey
function M.Journey()
    if M.journeyPage~="Timing" then return journey() end
    M.Action("Back to my current action",function() M.journeyPage="Now";M.Render() end,240)
    M.Heading("Route timings")
    M.Line("Time spent following guide actions, including travel and idle time. Pauses, loading screens and offline time are excluded. These are your measurements, not optimal-route estimates.")
    local toggle=U.Check(M.body,"Record route timings",ns.db.settings.routeTiming,function(v) ns.SetSetting("routeTiming",v);M.Render() end)
    toggle:SetPoint("TOPLEFT",12,M.y);M.y=M.y-34
    local rows=R.Summary();local selected
    local choices={}
    for _,row in ipairs(rows) do
        choices[#choices+1]={value=row.key,label="Level "..row.level.." | "..row.name.." | "..(row.class or "Unknown").." tree "..(row.spec or "unresolved").." | "..(row.role or "unknown").." | "..(row.journeyGoal=="speedrun" and "Speedrun" or "Casual")}
        if M.timingSelection==row.key then selected=row end
    end
    selected=selected or rows[1]
    if selected then
        local choose=U.Cycle(M.body,choices,selected.key,M.width-16,function(v) M.timingSelection=v;M.Render() end)
        choose:SetPoint("TOPLEFT",8,M.y);M.y=M.y-choose:GetHeight()-12
        M.Line(string.format("Recorded time: %d min %02d sec",math.floor(selected.seconds/60),selected.seconds%60),"GameFontNormal")
        M.Line(selected.actions.." action intervals | "..selected.completed.." completed | "..selected.skipped.." skipped | "..selected.deaths.." deaths")
        local details={}
        for _,row in ipairs(ns.char.routeTimings or {}) do
            if row.route..":"..(row.class or "unknown")..":"..(row.spec or "unresolved")..":"..(row.role or "unknown")..":"..row.level..":"..(row.journeyGoal or "casual")==selected.key then details[#details+1]=row end
        end
        local index=M.Choose(details,"timingAction","Choose an action",function(row) return row.title.." - "..row.seconds.." sec ("..row.reason..")" end)
        local row=index and details[index]
        if row then M.Line("Step "..row.index..": "..row.title);M.Line(row.seconds.." seconds | "..row.reason.." | "..row.deaths.." deaths") end
    else M.Line("Timing records appear as you finish or leave guide actions. The most recent 400 intervals are retained.") end
end
