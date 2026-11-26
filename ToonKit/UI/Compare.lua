local addonName, ns = ...
local C={};ns.ItemCompare=C
-- Item links and equipment comparison belong to Blizzard's item tooltips.
function C.Show(record)
    local link=type(record)=="string" and record or type(record)=="number" and "item:"..record or type(record)=="table" and (record.link or record.id and "item:"..record.id)
    if link and type(SetItemRef)=="function" then
        SetItemRef(link,link,"LeftButton")
        if ItemRefTooltip and ItemRefTooltip:IsShown() and type(GameTooltip_ShowCompareItem)=="function" then GameTooltip_ShowCompareItem(ItemRefTooltip) end
    end
end
