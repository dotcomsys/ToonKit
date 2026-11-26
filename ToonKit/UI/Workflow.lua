local addonName, ns = ...
local U,M=ns.UI,ns.Main
local journey=M.Journey
-- Preparation shares the current-action workspace instead of replacing it.
function M.Journey()
    if M.preparationOpen~=true or ns.Journey.Speedrunning() or (ns.db.settings.simpleUI and M.preparationOpen~=true) or M.preparationOpen==false or M.routePicker or M.journeyPage=="Review" or M.journeyPage=="History" or not ns.db.settings.modules.journey then return journey() end
    if M.journeyPage=="Planning" then M.journeyPage="Now" end
    local parent,width,top=M.body,M.width,M.y
    local leftWidth=math.floor(width*.58);local rightWidth=width-leftWidth-30
    local height=math.max(320,M.scroll:GetHeight()+top-20)
    local left=U.Panel(parent,leftWidth,height,8,top,"journeyCurrent")
    local right=U.Panel(parent,rightWidth,height,leftWidth+20,top,"journeyPreparation")
    local function render(panel,w,fn)
        if not panel.content then panel.content=CreateFrame("Frame",nil,panel);panel.content._managed=true;panel.content:SetPoint("TOPLEFT",12,-12) end
        U.Release(panel.content);panel.content:SetWidth(w-24)
        M.body=panel.content;M.width=w-24;M.y=0
        local ok,err=pcall(fn);local h=math.max(height,-M.y+24)
        panel.content:SetHeight(h-24);panel:SetHeight(h)
        M.body=parent;M.width=width;M.y=top
        if not ok then error(err) end
        return h
    end
    local current=render(left,leftWidth,journey)
    local preparation=render(right,rightWidth,M.RoutePlanning)
    local h=math.max(current,preparation);left:SetHeight(h);right:SetHeight(h);M.y=top-h-8
end
