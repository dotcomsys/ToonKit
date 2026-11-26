local addonName, ns = ...
-- Change displayName to rebrand every window and message. Installation IDs stay stable.
ns.Brand = {
    displayName = "ToonKit",
    description = "An all-in-one character and adventure companion for WoW Forever.",
    version = "0.11-alpha",
    author = "ToonKit contributors",
    icon = "Interface\\AddOns\\ToonKit\\Media\\ToonKit",
    aliases = { "/toonkit", "/tk" },
}
ns.Brand.shortName = ns.Brand.displayName
ns.Identity = { savedVariable = "AdventureCompanionDB", characterVariable = "AdventureCompanionCharacterDB", legacy = { "ToonKitDB" }, schema = 1 }
ns.Data = { routes = {}, collections = {}, gear = {}, builds = {}, effects = {} }
