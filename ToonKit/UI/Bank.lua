local addonName, ns = ...
local B={};ns.Bank=B
ns.Defaults.bankWindow=false
-- Blizzard owns the bank session, tabs, item interactions and money controls.
-- Retain the command entry point without creating a second bank workspace.
function B.Show()
    if not ns.Storage or not ns.Storage.bankOpen then ns.Message("Visit a banker to open your bank.");return end
    if type(InCombatLockdown)=="function" and InCombatLockdown() then return end
    if BankFrame and not BankFrame:IsShown() and type(ShowUIPanel)=="function" then ShowUIPanel(BankFrame) end
end
