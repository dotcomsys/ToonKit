local addonName, ns = ...
local A={};ns.StorageActions=A
function A.Read(name,...)
    A.readHidden=false
    A.readFailed=false
    if type(_G[name])~="function" then A.readFailed=true;return end
    local values={pcall(_G[name],...)};if not values[1] then A.readFailed=true;return end
    for index=2,17 do
        if type(issecretvalue)=="function" and issecretvalue(values[index]) then A.readHidden=true end
        values[index-1]=ns.Safe(values[index])
    end
    return unpack(values,1,16)
end
function A.Ready(kind)
    if kind~="bank" then return false,"Unsupported storage interaction." end
    if type(InCombatLockdown)=="function" and InCombatLockdown() then return false,"Finish combat first." end
    if not ns.Storage.bankOpen then return false,"Visit a bank first." end
    return true
end
function A.BankContext(kind)
    local ready,reason=A.Ready("bank");if not ready then return false,reason end
    if ns.Safe(ns.API.Call("C_Bank","CanUseBank",kind))~=true then return false,"This bank is not currently accessible." end
    return true
end
function A.BankMoney(kind,amount,withdraw)
    local ready,reason=A.BankContext(kind);if not ready then return false,reason end
    amount=tonumber(amount)
    if not amount or amount~=amount or amount<=0 or amount==math.huge or amount~=math.floor(amount) then return false,"Enter a positive money amount." end
    local permission=withdraw and "CanWithdrawMoney" or "CanDepositMoney"
    if ns.Safe(ns.API.Call("C_Bank",permission,kind))~=true then return false,"This bank does not allow that money transfer." end
    local available
    if withdraw then available=ns.Safe(ns.API.Call("C_Bank","FetchDepositedMoney",kind))
    else available=A.Read("GetMoney") end
    if type(available)~="number" then return false,"The balance for this transfer is unavailable." end
    if available<amount then return false,"Not enough money." end
    local method=withdraw and "WithdrawMoney" or "DepositMoney"
    if not C_Bank or type(C_Bank[method])~="function" then return false,"This bank action is unavailable." end
    C_Bank[method](kind,amount);return true
end
