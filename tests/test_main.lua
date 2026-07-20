package.path = "../Scripts/?.lua;" .. package.path

local phase = "bootstrap"
local callbacks = {}
local game_tasks = {}
local delayed_tasks = {}
local loop_tasks = {}
local delivered = {}
local delivered_by_uid = {}
local object_accesses = 0
local fake_time = 1000

local original_os_time = os.time
os.time = function()
    return fake_time
end

local function require_game_thread(operation)
    assert(phase == "game", operation .. " executed outside the game thread (phase=" .. phase .. ")")
    object_accesses = object_accesses + 1
end

local function object(fields, methods)
    local storage = fields or {}
    local valid = true
    methods = methods or {}

    methods.IsValid = function()
        return valid
    end
    methods.__invalidate = function()
        valid = false
    end

    return setmetatable({}, {
        __index = function(_, key)
            require_game_thread("UObject member " .. tostring(key))
            if methods[key] ~= nil then
                return methods[key]
            end
            return storage[key]
        end,
    })
end

local zero_guid = { A = 0, B = 0, C = 0, D = 0 }
local uid_one = { A = 1, B = 2, C = 3, D = 4 }
local uid_two = { A = 5, B = 6, C = 7, D = 8 }
local uid_spectator = { A = 9, B = 10, C = 11, D = 12 }

local function test_guid_key(uid)
    return table.concat({ uid.A, uid.B, uid.C, uid.D }, ":")
end

delivered_by_uid[test_guid_key(uid_one)] = delivered
delivered_by_uid[test_guid_key(uid_two)] = {}
delivered_by_uid[test_guid_key(uid_spectator)] = {}

local guild_one = object({ GuildName = "红队" }, { GetAddress = function() return 9001 end })
local guild_two = object({ GuildName = "蓝队" }, { GetAddress = function() return 9002 end })
local player_one_state = object({
    PlayerUId = uid_one,
    PlayerNamePrivate = "Alice",
    GuildBelongTo = guild_one,
})
local player_two_state = object({
    PlayerUId = uid_two,
    PlayerNamePrivate = "Bob",
    GuildBelongTo = guild_two,
})

local next_actor_address = 10000

local function actor(name, fields)
    fields = fields or {}
    next_actor_address = next_actor_address + 1
    local address = next_actor_address
    return object(fields, {
        GetAddress = function()
            return address
        end,
        GetName = function()
            return name
        end,
        GetFullName = function()
            return "/Game/Test." .. name
        end,
    })
end

local player_one = actor("BP_Player_C_1", { PlayerState = player_one_state })
local player_two = actor("BP_Player_C_2", { PlayerState = player_two_state })
local player_two_pal_parameter = object({}, {
    GetAddress = function()
        return 9102
    end,
    GetCharacterID = function()
        return "PinkCat"
    end,
    GetNickname = function(_, out_name)
        out_name.outName = "棉花糖"
    end,
})
local player_two_pal_component = object({
    IndividualParameter = player_two_pal_parameter,
})
local player_two_pal = actor("BP_PinkCat_C_3", {
    CharacterParameterComponent = player_two_pal_component,
})

local function boss_actor(name)
    local component = object({
        IsBoss_Database = true,
        IsTowerBoss_Database = false,
    })
    return actor(name, { StaticCharacterParameterComponent = component })
end

local boss = boss_actor("BP_RaidBoss_Test_C_9")
local normal_target = actor("BP_Sheep_C_4", {
    StaticCharacterParameterComponent = object({
        IsBoss_Database = false,
        IsTowerBoss_Database = false,
    }),
})
local world = object()

local trainer_by_actor = {}
trainer_by_actor[player_two_pal] = player_two

local character_database = object({}, {
    GetLocalizedCharacterName = function(_, character_id, out_text)
        local id = tostring(character_id)
        if string.find(id, "Suzaku", 1, true) ~= nil then
            out_text.OutText = "朱雀"
        elseif string.find(id, "DarkScorpion", 1, true) ~= nil then
            out_text.OutText = "冥铠蝎"
        elseif string.find(id, "PinkCat", 1, true) ~= nil then
            out_text.OutText = "捣蛋猫"
        end
    end,
})

local utility = object({}, {
    GetPlayerState = function(_, candidate)
        if candidate == player_one then
            return player_one_state
        elseif candidate == player_two then
            return player_two_state
        end
        return nil
    end,
    GetTrainerPlayer = function(_, candidate)
        return trainer_by_actor[candidate]
    end,
    GetCharacterIDFromCharacter = function(_, candidate)
        return candidate:GetName()
    end,
    GetDatabaseCharacterParameter = function(_, context)
        assert(context == world, "unexpected localization world context")
        return character_database
    end,
    SendSystemToPlayerChat = function(_, context, message, receiver_uid)
        assert(context == world, "unexpected world context")
        assert(utf8.len(message) ~= nil, "invalid UTF-8 reached SendSystemToPlayerChat")
        local inbox = delivered_by_uid[test_guid_key(receiver_uid)]
        assert(inbox ~= nil, "message sent to unknown receiver")
        inbox[#inbox + 1] = message
    end,
})

function StaticFindObject(path)
    require_game_thread("StaticFindObject")
    assert(path == "/Script/Pal.Default__PalUtility")
    return utility
end

function FindFirstOf(type_name)
    require_game_thread("FindFirstOf")
    assert(type_name == "PalGameStateInGame")
    return world
end

function RegisterHook(path, callback)
    assert(phase == "bootstrap", "RegisterHook must run during bootstrap")
    local allowed = {
        ["/Script/Pal.PalEventNotify_Character:OnCharacterDamaged_ServerInternal"] = true,
        ["/Script/Pal.PalEventNotify_Character:OnCharacterDead_ServerInternal"] = true,
        ["/Script/Pal.PalEventNotify_Character:OnCaptured_ServerInternal"] = true,
    }
    if not allowed[path] then
        error("simulated Palworld 1.0: UFunction not found")
    end
    callbacks[path] = callback
end

EGameThreadMethod = { EngineTick = 1, ProcessEvent = 2 }
EngineTickAvailable = true

function ExecuteInGameThread(callback, method)
    assert(phase == "hook" or phase == "game", "unexpected game-thread scheduling phase")
    assert(method == nil or method == EGameThreadMethod.EngineTick)
    game_tasks[#game_tasks + 1] = callback
end

function ExecuteInGameThreadWithDelay(delay, callback)
    assert(phase == "game", "delayed action was not scheduled from the game thread")
    delayed_tasks[#delayed_tasks + 1] = { delay = delay, callback = callback }
    return #delayed_tasks
end

function LoopInGameThreadWithDelay(delay, callback)
    assert(phase == "bootstrap" or phase == "game")
    loop_tasks[#loop_tasks + 1] = { delay = delay, callback = callback }
    return #loop_tasks
end

function ExecuteWithDelay()
    error("deprecated asynchronous ExecuteWithDelay must never be used")
end

local function run_game_tasks(max_tasks)
    local ran = 0
    while #game_tasks > 0 and (max_tasks == nil or ran < max_tasks) do
        local callback = table.remove(game_tasks, 1)
        phase = "game"
        callback()
        phase = "idle"
        ran = ran + 1
    end
    return ran
end

local function run_delayed_tasks()
    table.sort(delayed_tasks, function(a, b)
        return a.delay < b.delay
    end)
    while #delayed_tasks > 0 do
        local task = table.remove(delayed_tasks, 1)
        phase = "game"
        task.callback()
        phase = "idle"
    end
end

local function hook_param(value)
    return {
        get = function()
            assert(phase == "hook", "temporary hook parameter escaped its callback")
            return value
        end,
    }
end

local function damage(attacker, defender, amount, extra_fields)
    local payload = {
        Attacker = attacker,
        Defender = defender,
        ActualDamage = amount,
    }
    for key, value in pairs(extra_fields or {}) do
        payload[key] = value
    end
    phase = "hook"
    callbacks["/Script/Pal.PalEventNotify_Character:OnCharacterDamaged_ServerInternal"](nil, hook_param(payload))
    phase = "idle"
end

local function death(dead_actor)
    phase = "hook"
    callbacks["/Script/Pal.PalEventNotify_Character:OnCharacterDead_ServerInternal"](nil, hook_param({
        SelfActor = dead_actor,
    }))
    phase = "idle"
end

local function captured(captured_actor, attacker)
    phase = "hook"
    callbacks["/Script/Pal.PalEventNotify_Character:OnCaptured_ServerInternal"](
        nil,
        hook_param(attacker),
        hook_param(captured_actor)
    )
    phase = "idle"
end

_G.__BOSS_DPS_TEST = true
dofile("../Scripts/main.lua")

local commentary = require("commentary")
local commentary_base = {
    key = "template-test",
    guild = "测试公会",
    player = "测试玩家",
    runnerup = "追榜玩家",
    pal = "测试帕鲁",
    boss = "测试Boss",
    total = 50000,
    previous_total = 40000,
    window_damage = 10000,
    current_dps = 1000,
    previous_dps = 1000,
    top_share = 50,
    second_share = 40,
    team_dps = 1000,
    duration = 10,
    window_index = 1,
    reason = "defeated",
}
local function commentary_case(overrides, final)
    local stats = {}
    for key, value in pairs(commentary_base) do
        stats[key] = value
    end
    for key, value in pairs(overrides) do
        stats[key] = value
    end
    local result = final and commentary.final(stats) or commentary.progress(stats)
    assert(result ~= nil, "commentary branch did not produce text")
    assert(string.find(result, "{", 1, true) == nil, "unrendered commentary placeholder")
    assert(string.find(result, "测试公会", 1, true) ~= nil
        or string.find(result, "测试玩家", 1, true) ~= nil,
        "commentary did not use live guild/player data")
end

commentary_case({ current_dps = 1000000 }, false)
commentary_case({ total = 1000000, previous_total = 900000 }, false)
commentary_case({ current_dps = 100000 }, false)
commentary_case({ current_dps = 20000, previous_dps = 5000 }, false)
commentary_case({ total = 20000, top_share = 90 }, false)
commentary_case({ reason = "timeout" }, true)
commentary_case({ reason = "captured" }, true)
commentary_case({ duration = 2 }, true)
commentary_case({ total = 1000000 }, true)
commentary_case({ team_dps = 100000 }, true)
commentary_case({ top_share = 51, second_share = 49 }, true)
commentary_case({ total = 20000, top_share = 90, second_share = 0 }, true)
commentary_case({}, true)

local damage_hook = callbacks["/Script/Pal.PalEventNotify_Character:OnCharacterDamaged_ServerInternal"]
local death_hook = callbacks["/Script/Pal.PalEventNotify_Character:OnCharacterDead_ServerInternal"]
local captured_hook = callbacks["/Script/Pal.PalEventNotify_Character:OnCaptured_ServerInternal"]
assert(damage_hook ~= nil, "damage hook was not registered")
assert(death_hook ~= nil, "death hook was not registered")
assert(captured_hook ~= nil, "capture hook was not registered")
assert(#loop_tasks == 2, "cleanup and progress loops were not configured")
local loop_delays = { [loop_tasks[1].delay] = true, [loop_tasks[2].delay] = true }
assert(loop_delays[10000] and loop_delays[30000], "unexpected loop delays")

-- Thread-affinity and event-struct lifetime: hook phase may only copy fields.
local accesses_before_hook = object_accesses
damage(player_one, boss, 600)
assert(object_accesses == accesses_before_hook, "damage hook touched a UObject")
assert(#game_tasks == 1, "damage drain was not coalesced")
assert(#delivered == 0, "damage hook broadcast synchronously")
assert(BossDPSBroadcastTestApi.queue_size() == 1)

damage(player_two_pal, boss, 400)
damage(player_one, normal_target, 999)
damage(player_one, boss, -12)
damage(player_one, boss, 0 / 0)
death(boss)
assert(#game_tasks == 1, "multiple hits should share one scheduled drain")
run_game_tasks()
assert(BossDPSBroadcastTestApi.queue_size() == 0)
assert(#delivered == 0, "participant messages must use the delayed message pump")
run_delayed_tasks()

local joined = table.concat(delivered, "\n")
assert(string.find(joined, "开始统计", 1, true) ~= nil, "start announcement missing")
assert(string.find(joined, "团队伤害 1,000", 1, true) ~= nil, "team total missing")
assert(string.find(joined, "Alice｜伤害 600｜60.0%", 1, true) ~= nil, "Alice result missing")
assert(string.find(joined, "Bob｜伤害 400｜40.0%", 1, true) ~= nil, "Pal owner attribution missing")
assert(string.find(joined, "最高伤害队伍：红队｜伤害 600", 1, true) ~= nil, "team MVP missing")
assert(string.find(joined, "最高伤害玩家角色：Alice｜伤害 600", 1, true) ~= nil, "player MVP missing")
assert(string.find(joined, "最高伤害帕鲁：棉花糖（捣蛋猫）｜训练家 Bob｜伤害 400", 1, true) ~= nil, "Pal MVP or nickname priority missing")
assert(string.find(joined, "战斗点评：", 1, true) ~= nil, "mandatory final comment missing")
assert(string.find(joined, "队内私报：红队｜伤害 600", 1, true) ~= nil, "red team private detail missing")
assert(string.find(joined, "Alice（玩家角色）｜伤害 600｜100.0%", 1, true) ~= nil)
local bob_first_joined = table.concat(delivered_by_uid[test_guid_key(uid_two)], "\n")
assert(string.find(bob_first_joined, "开始统计", 1, true) == nil, "late participant received the start line")
assert(string.find(bob_first_joined, "队内私报：蓝队｜伤害 400", 1, true) ~= nil)
assert(string.find(bob_first_joined, "棉花糖（捣蛋猫）［Bob］｜伤害 400｜100.0%", 1, true) ~= nil)
assert(#delivered_by_uid[test_guid_key(uid_spectator)] == 0, "spectator received a battle message")

-- Duplicate deaths must be idempotent.
local delivered_before_duplicate = #delivered
death(boss)
run_game_tasks()
run_delayed_tasks()
assert(#delivered == delivered_before_duplicate, "duplicate death published another result")

-- Capture is a completion path distinct from death. The captured actor may
-- become invalid before the queued finish event reaches the game thread.
local captured_boss = boss_actor("BP_Suzaku_BOSS_C_10")
damage(player_one, captured_boss, 700)
damage(player_two_pal, captured_boss, 300)
run_game_tasks()
local accesses_before_capture = object_accesses
captured(captured_boss, player_one)
assert(object_accesses == accesses_before_capture, "capture hook touched a UObject")
phase = "game"
captured_boss:__invalidate()
phase = "idle"
run_game_tasks()
run_delayed_tasks()
joined = table.concat(delivered, "\n")
assert(string.find(joined, "朱雀 已捕捉！团队伤害 1,000", 1, true) ~= nil, "capture result missing")
assert(string.find(joined, "Alice｜伤害 700｜70.0%", 1, true) ~= nil)
assert(string.find(joined, "Bob｜伤害 300｜30.0%", 1, true) ~= nil)

-- Live reports use a rolling 10-second window while totals and percentages
-- remain encounter-wide. Only contributors receive either line.
local progress_boss = boss_actor("BP_DarkScorpion_BOSS_C_17")
local alice_before_progress = #delivered
local bob_inbox = delivered_by_uid[test_guid_key(uid_two)]
local bob_before_progress = #bob_inbox
damage(player_one, progress_boss, 600)
damage(player_two_pal, progress_boss, 400)
run_game_tasks()
run_delayed_tasks()
fake_time = fake_time + 10
phase = "game"
BossDPSBroadcastTestApi.publish_progress()
phase = "idle"
run_delayed_tasks()
local progress_messages = {}
for index = alice_before_progress + 1, #delivered do
    progress_messages[#progress_messages + 1] = delivered[index]
end
local progress_joined = table.concat(progress_messages, "\n")
assert(string.find(progress_joined, "实时战况：冥铠蝎｜总伤害 1,000｜当前DPS 100", 1, true) ~= nil)
assert(string.find(progress_joined, "Alice 600(60.0%/60DPS)", 1, true) ~= nil)
assert(string.find(progress_joined, "Bob 400(40.0%/40DPS)", 1, true) ~= nil)
assert(#bob_inbox > bob_before_progress, "participant Bob did not receive live progress")
assert(#delivered_by_uid[test_guid_key(uid_spectator)] == 0, "spectator received live progress")

local alice_before_second_window = #delivered
damage(player_two_pal, progress_boss, 500)
run_game_tasks()
fake_time = fake_time + 10
phase = "game"
BossDPSBroadcastTestApi.publish_progress()
phase = "idle"
run_delayed_tasks()
local second_window = {}
for index = alice_before_second_window + 1, #delivered do
    second_window[#second_window + 1] = delivered[index]
end
local second_joined = table.concat(second_window, "\n")
assert(string.find(second_joined, "总伤害 1,500｜当前DPS 50", 1, true) ~= nil)
assert(string.find(second_joined, "Bob 900(60.0%/50DPS)", 1, true) ~= nil)
assert(string.find(second_joined, "Alice 600(40.0%/0DPS)", 1, true) ~= nil)
death(progress_boss)
run_game_tasks()
run_delayed_tasks()

-- Mounted Pal skills can report the player as Attacker. DamageCauser ownership
-- must recover the concrete Pal, while a player-owned weapon stays direct.
local mounted_boss = boss_actor("BP_RaidBoss_Mounted_C_18")
local pal_skill_projectile = actor("BP_PalSkillProjectile_C_19", { Owner = player_two_pal })
local player_weapon = actor("BP_PlayerWeapon_C_20", { Owner = player_two })
local mounted_before = #bob_inbox
damage(player_two, mounted_boss, 500, { DamageCauser = pal_skill_projectile })
damage(player_two, mounted_boss, 200, { DamageCauser = player_weapon })
death(mounted_boss)
run_game_tasks()
run_delayed_tasks()
local mounted_messages = {}
for index = mounted_before + 1, #bob_inbox do
    mounted_messages[#mounted_messages + 1] = bob_inbox[index]
end
local mounted_joined = table.concat(mounted_messages, "\n")
assert(string.find(mounted_joined, "最高伤害帕鲁：棉花糖（捣蛋猫）｜训练家 Bob｜伤害 500", 1, true) ~= nil, "mounted Pal skill was attributed to player")
assert(string.find(mounted_joined, "最高伤害玩家角色：Bob｜伤害 200", 1, true) ~= nil, "mounted player weapon was attributed to Pal")
assert(string.find(mounted_joined, "棉花糖（捣蛋猫）［Bob］｜伤害 500｜71.4%", 1, true) ~= nil)
assert(string.find(mounted_joined, "Bob（玩家角色）｜伤害 200｜28.6%", 1, true) ~= nil)
assert(string.find(mounted_joined, "最高伤害队伍", 1, true) == nil, "single-team fight printed a redundant team winner")
assert(string.find(mounted_joined, "击杀播报：Bob 击败了 RaidBoss_Mounted", 1, true) ~= nil, "player final blow announcement missing")

-- Regression for the real 1.0 failure: byte-based truncation could split a
-- Chinese Pal nickname and make SendSystemToPlayerChat raise "bad conversion".
local long_pal_parameter = object({}, {
    GetAddress = function()
        return 9103
    end,
    GetCharacterID = function()
        return "PinkCat"
    end,
    GetNickname = function(_, out_name)
        out_name.outName = "思冬拳思如泉涌!念冬剑念念不忘!浩冬掌生生世世!"
    end,
})
local long_pal = actor("BP_PinkCat_C_22", {
    CharacterParameterComponent = object({ IndividualParameter = long_pal_parameter }),
})
trainer_by_actor[long_pal] = player_two
local encoding_boss = boss_actor("BP_RaidBoss_Encoding_C_23")
local encoding_before = #bob_inbox
damage(long_pal, encoding_boss, 2865)
death(encoding_boss)
run_game_tasks()
run_delayed_tasks()
local encoding_messages = {}
for index = encoding_before + 1, #bob_inbox do
    encoding_messages[#encoding_messages + 1] = bob_inbox[index]
    assert(utf8.len(bob_inbox[index]) ~= nil, "delivered message contains invalid UTF-8")
end
local encoding_joined = table.concat(encoding_messages, "\n")
assert(string.find(encoding_joined, "最高伤害帕鲁：思冬拳思如泉涌!念冬剑念念不忘!浩冬掌生生世世!（捣蛋猫）", 1, true) ~= nil, "long Pal name swallowed MVP row")
assert(string.find(encoding_joined, "队内 #1 思冬拳思如泉涌!念冬剑念念不忘!浩冬掌生生世世!（捣蛋猫）", 1, true) ~= nil, "long Pal name swallowed private row")
assert(string.find(encoding_joined, "击杀播报：Bob 的 思冬拳思如泉涌!念冬剑念念不忘!浩冬掌生生世世!（捣蛋猫） 击败了 RaidBoss_Encoding", 1, true) ~= nil, "Pal final blow announcement missing")

-- A high-output 10-second window gets an optional triggered comment.
local comment_boss = boss_actor("BP_RaidBoss_Comment_C_21")
local comment_before = #delivered
damage(player_one, comment_boss, 1200000)
run_game_tasks()
run_delayed_tasks()
fake_time = fake_time + 10
phase = "game"
BossDPSBroadcastTestApi.publish_progress()
phase = "idle"
run_delayed_tasks()
local comment_messages = {}
for index = comment_before + 1, #delivered do
    comment_messages[#comment_messages + 1] = delivered[index]
end
local comment_joined = table.concat(comment_messages, "\n")
assert(string.find(comment_joined, "实时战况", 1, true) ~= nil)
assert(string.find(comment_joined, "战况点评：", 1, true) ~= nil, "triggered progress comment missing")
assert(string.find(comment_joined, "红队", 1, true) ~= nil or string.find(comment_joined, "Alice", 1, true) ~= nil, "progress comment did not render live names")
assert(string.find(comment_joined, "{guild}", 1, true) == nil, "comment template was not rendered")
death(comment_boss)
run_game_tasks()
run_delayed_tasks()

-- UObject can disappear between hook capture and the next game-thread drain.
local stale_boss = boss_actor("BP_RaidBoss_Stale_C_16")
local invalid_before = BossDPSBroadcastTestApi.metrics.invalid
damage(player_one, stale_boss, 100)
phase = "game"
stale_boss:__invalidate()
phase = "idle"
run_game_tasks()
assert(BossDPSBroadcastTestApi.metrics.invalid == invalid_before + 1, "stale actor was not rejected")

-- Timeout produces a partial ranking and closes the session.
local timeout_boss = boss_actor("BP_RaidBoss_Timeout_C_11")
damage(player_one, timeout_boss, 250)
run_game_tasks()
fake_time = fake_time + 301
phase = "game"
BossDPSBroadcastTestApi.cleanup_sessions()
phase = "idle"
run_delayed_tasks()
joined = table.concat(delivered, "\n")
assert(string.find(joined, "挑战中断（长时间无伤害）", 1, true) ~= nil, "timeout result missing")
assert(string.find(joined, "团队伤害 250", 1, true) ~= nil, "timeout damage missing")
assert(string.find(joined, "战斗点评：", 1, true) ~= nil, "failure comment missing")

-- Simultaneous bosses must keep independent totals and rankings.
local multi_a = boss_actor("BP_RaidBoss_MultiA_C_12")
local multi_b = boss_actor("BP_RaidBoss_MultiB_C_13")
local delivered_before_multi = #delivered
damage(player_one, multi_a, 100)
damage(player_two_pal, multi_b, 300)
damage(player_one, multi_b, 50)
death(multi_b)
death(multi_a)
run_game_tasks()
run_delayed_tasks()
local multi_messages = {}
for index = delivered_before_multi + 1, #delivered do
    multi_messages[#multi_messages + 1] = delivered[index]
end
local multi_joined = table.concat(multi_messages, "\n")
assert(string.find(multi_joined, "击败了 RaidBoss_MultiA｜用时 1秒｜团队DPS 100｜团队伤害 100", 1, true) ~= nil, "boss A total mixed")
assert(string.find(multi_joined, "击败了 RaidBoss_MultiB｜用时 1秒｜团队DPS 350｜团队伤害 350", 1, true) ~= nil, "boss B total mixed")

-- A captured/owned boss variant must not start a PvE boss session.
local owned_boss = boss_actor("BP_RaidBoss_Owned_C_14")
trainer_by_actor[owned_boss] = player_one
local delivered_before_owned = #delivered
damage(player_two, owned_boss, 500)
run_game_tasks()
run_delayed_tasks()
assert(#delivered == delivered_before_owned, "player-owned Pal was treated as a world boss")

-- Back-pressure: a 10k-hit burst must cap memory. A death event is retained
-- beyond the damage cap so an already-running boss session can still close.
local stress_boss = boss_actor("BP_RaidBoss_Stress_C_15")
damage(player_one, stress_boss, 1)
run_game_tasks()
local accepted_before = BossDPSBroadcastTestApi.metrics.accepted
local dropped_before = BossDPSBroadcastTestApi.metrics.dropped
accesses_before_hook = object_accesses
for _ = 1, 10000 do
    damage(player_one, normal_target, 1)
end
death(stress_boss)
assert(object_accesses == accesses_before_hook, "stress hooks touched UObjects")
assert(BossDPSBroadcastTestApi.queue_size() == 8193, "damage cap or retained death event is incorrect")
assert(BossDPSBroadcastTestApi.metrics.accepted - accepted_before == 8193)
assert(BossDPSBroadcastTestApi.metrics.dropped - dropped_before == 1808)
assert(#game_tasks == 1, "stress burst scheduled more than one initial drain")
local drain_count = run_game_tasks()
assert(drain_count == 33, "8192 damage events plus death should drain in 33 batches")
assert(BossDPSBroadcastTestApi.queue_size() == 0, "stress queue did not fully drain")
run_delayed_tasks()
joined = table.concat(delivered, "\n")
assert(string.find(joined, "击败了 RaidBoss_Stress｜用时 1秒｜团队DPS 1｜团队伤害 1", 1, true) ~= nil, "death was lost behind burst traffic")
assert(BossDPSBroadcastTestApi.metrics.errors == 0, "unexpected processing errors")
assert(#delivered_by_uid[test_guid_key(uid_spectator)] == 0, "spectator received any participant-only report")

assert(#BossDPSBroadcastTestApi.sessions == 0, "sessions table must be map-like")
assert(original_os_time ~= nil)
print("BossDPSBroadcast v2 integration/thread/lifetime/stress tests passed")
