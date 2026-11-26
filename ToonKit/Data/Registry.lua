local addonName, ns = ...
local R={}; ns.Registry=R
-- Content extensions load after this file and before Bootstrap. Never infer
-- availability from item level, cache presence, dates, or a Classic record.
function R.Add(kind,record)
    if kind~="routes" and kind~="collections" and kind~="gear" then return false,"Unknown content kind" end
    if type(record)~="table" or not record.id or not record.source then return false,"An ID and provenance source are required" end
    if record.availability=="confirmed" and not record.verifiedBuild then return false,"Confirmed content must identify its verified client build" end
    if record.map and (not record.x or not record.y or record.x<0 or record.x>1 or record.y<0 or record.y>1) then return false,"Coordinates must be normalized" end
    if kind=="routes" and type(record.steps)~="table" then return false,"Routes require steps" end
    if kind=="collections" and not record.name then return false,"Collections require a title" end
    table.insert(ns.Data[kind],ns.Copy(record)); return true
end
