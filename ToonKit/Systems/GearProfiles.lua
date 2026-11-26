local addonName, ns = ...
local G=ns.Gear

function G.ScoringKey(profile)
    return G.ProfileKey(profile)..':level:'..tostring(profile and profile.level or ns.State.level)
end
