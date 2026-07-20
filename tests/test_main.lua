package.path = "../Scripts/?.lua;" .. package.path

local callbacks = {}
local delayed = {}
local delivered = {}

local function object(fields)
    fields = fields or {}
    function fields:IsValid()
        return true
    end
    return fields
end

local zero_guid = { A = 0, B = 0, C = 0, D = 0 }
local uid_one = { A = 1, B = 2, C = 3, D = 4 }
local uid_two = { A = 5, B = 6, C = 7, D = 8 }

local player_one_state = object({ PlayerUId = uid_one })
function player_one_state:GetPlayerName()
    return "Alice"
end

local player_two_state = object({ PlayerUId = uid_two })
function player_two_state:GetPlayerName()
    return "Bob"
end

local player_one = object({ name = "BP_Player_C_1" })
local player_two = object({ name = "BP_Player_C_2" })
local player_two_pal = object({ name = "BP_PinkCat_C_3" })

local boss_parameter = object()
function boss_parameter:GetCharacterID()
    return "RaidBoss_Test"
end
function boss_parameter:GetSaveParameter()
    return { OwnerPlayerUId = zero_guid }
end

local boss_component = object()
function boss_component:IsBossPal_Database()
    return true
end
function boss_component:IsTowerBossPal()
    return false
end

local boss = object({
    name = "BP_RaidBoss_Test_C_9",
    StaticCharacterParameterComponent = boss_component,
})

for _, actor in ipairs({ player_one, player_two, player_two_pal, boss }) do
    function actor:GetName()
        return self.name
    end
    function actor:GetFullName()
        return "/Game/Test." .. self.name
    end
end

local world = object()
local utility = object()
function utility:GetPlayerState(actor)
    if actor == player_one then
        return player_one_state
    end
    if actor == player_two then
        return player_two_state
    end
    return nil
end
function utility:GetTrainerPlayer(actor)
    if actor == player_two_pal then
        return player_two
    end
    return nil
end
function utility:GetIndividualCharacterParameterByActor(actor)
    if actor == boss then
        return boss_parameter
    end
    return nil
end
function utility:GetDatabaseCharacterParameter()
    return nil
end
function utility:SendSystemToPlayerChat(_, message, receiver)
    delivered[#delivered + 1] = {
        message = message,
        receiver = receiver,
    }
end

function StaticFindObject(path)
    assert(path == "/Script/Pal.Default__PalUtility")
    return utility
end

function FindFirstOf(type_name)
    if type_name == "PalGameStateInGame" or type_name == "World" then
        return world
    end
    return nil
end

function FindAllOf(type_name)
    assert(type_name == "PalPlayerState")
    return { player_one_state, player_two_state }
end

function RegisterHook(path, callback)
    callbacks[path] = callback
end

function ExecuteWithDelay(delay, callback)
    delayed[#delayed + 1] = {
        delay = delay,
        callback = callback,
    }
end

dofile("../Scripts/main.lua")

local damage_hook = callbacks["/Script/Pal.PalEventNotify_Character:OnCharacterDamaged_ServerInternal"]
local death_hook = callbacks["/Script/Pal.PalEventNotify_Character:OnCharacterDead_ServerInternal"]
assert(damage_hook ~= nil, "damage hook was not registered")
assert(death_hook ~= nil, "death hook was not registered")

local function param(value)
    return {
        get = function()
            return value
        end,
    }
end

damage_hook(nil, param({
    Attacker = player_one,
    Defender = boss,
    ActualDamage = 600,
}))
damage_hook(nil, param({
    Attacker = player_two_pal,
    Defender = boss,
    ActualDamage = 400,
}))
death_hook(nil, param({
    SelfActor = boss,
    LastAttacker = player_two_pal,
    LastDamage = 400,
}))

local result_tasks = {}
for _, task in ipairs(delayed) do
    if task.delay < 5000 then
        result_tasks[#result_tasks + 1] = task
    end
end
table.sort(result_tasks, function(a, b)
    return a.delay < b.delay
end)
for _, task in ipairs(result_tasks) do
    task.callback()
end

local messages = {}
for _, item in ipairs(delivered) do
    messages[#messages + 1] = item.message
end
local joined = table.concat(messages, "\n")

assert(string.find(joined, "开始统计", 1, true) ~= nil, "start announcement missing")
assert(string.find(joined, "团队伤害 1,000", 1, true) ~= nil, "team total missing")
assert(string.find(joined, "Alice｜伤害 600｜60.0%%") ~= nil, "Alice result missing")
assert(string.find(joined, "Bob｜伤害 400｜40.0%%") ~= nil, "Pal owner attribution missing")
assert(#delivered == 8, "expected four messages for each of two players")

print("BossDPSBroadcast mock integration test passed")
