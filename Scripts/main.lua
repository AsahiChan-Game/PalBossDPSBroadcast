---@diagnostic disable: undefined-global

local config = require("./config")

local MOD = "[BossDPSBroadcast]"
local unpack_args = table.unpack or unpack
local sessions = {}
local hooks = { damage = false, death = false }

-- Native damage hooks may run in the middle of an Unreal call. They must not
-- call UFunctions or retain references to the temporary event struct. The
-- hook copies only actor wrappers and primitive values into this bounded FIFO.
local pending_events = {}
local pending_head = 1
local pending_tail = 0
local drain_scheduled = false
local pending_messages = {}
local message_head = 1
local message_tail = 0
local message_pump_running = false
local metrics = {
    accepted = 0,
    dropped = 0,
    processed = 0,
    invalid = 0,
    errors = 0,
}

local function log(message)
    print(MOD .. " " .. tostring(message) .. "\n")
end

local function safe_call(object, method_name, ...)
    if object == nil then
        return false, nil
    end

    local args = { ... }
    local method_found = false
    local ok, result = pcall(function()
        local method = object[method_name]
        if method == nil then
            return nil
        end
        method_found = true
        return method(object, unpack_args(args))
    end)
    if not ok then
        return false, result
    end
    if not method_found then
        return false, "method unavailable: " .. tostring(method_name)
    end
    return true, result
end

local function safe_property(object, property_name)
    if object == nil then
        return false, nil
    end
    return pcall(function()
        return object[property_name]
    end)
end

local function unwrap(value)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type ~= "table" and value_type ~= "userdata" then
        return value
    end

    local ok, result = pcall(function()
        if value.get ~= nil then
            return value:get()
        end
        return value
    end)
    if ok then
        return result
    end
    return value
end

local function to_number(value)
    value = unwrap(value)
    if type(value) == "number" then
        return value
    end
    return tonumber(tostring(value or "")) or 0
end

local function finite_positive_number(value)
    local number = to_number(value)
    if number ~= number or number == math.huge or number == -math.huge or number <= 0 then
        return nil
    end
    return number
end

local function bool_value(value)
    value = unwrap(value)
    return value == true or value == 1 or tostring(value) == "true"
end

local function is_valid(object)
    if object == nil then
        return false
    end
    local ok, result = safe_call(object, "IsValid")
    return ok and result == true
end

local function text_value(value)
    value = unwrap(value)
    if value == nil then
        return ""
    end

    local ok, result = safe_call(value, "ToString")
    if ok and result ~= nil then
        value = result
    end

    local text = tostring(value or "")
    if text == "nil" or text == "None" or text == "Invalid" then
        return ""
    end
    return string.gsub(text, "^[%w_]+:%s*", "")
end

local function actor_full_name(actor)
    local ok, name = safe_call(actor, "GetFullName")
    if ok and name ~= nil then
        return text_value(name)
    end
    return ""
end

local function actor_short_name(actor)
    local ok, name = safe_call(actor, "GetName")
    local text = ok and text_value(name) or actor_full_name(actor)
    text = string.gsub(text, "_C_%d+$", "")
    text = string.gsub(text, "^BP_", "")
    return text ~= "" and text or "Boss"
end

local function guid_parts(value)
    value = unwrap(value)
    if value == nil then
        return nil
    end
    local ok, a, b, c, d = pcall(function()
        return value.A, value.B, value.C, value.D
    end)
    if not ok or a == nil or b == nil or c == nil or d == nil then
        return nil
    end
    return { A = a, B = b, C = c, D = d }
end

local function guid_key(value)
    local guid = guid_parts(value)
    if guid == nil then
        return nil
    end
    if to_number(guid.A) == 0 and to_number(guid.B) == 0
        and to_number(guid.C) == 0 and to_number(guid.D) == 0 then
        return nil
    end
    return table.concat({ tostring(guid.A), tostring(guid.B), tostring(guid.C), tostring(guid.D) }, ":")
end

local function get_pal_utility()
    local utility = StaticFindObject("/Script/Pal.Default__PalUtility")
    return is_valid(utility) and utility or nil
end

local function find_world_context()
    local world = FindFirstOf("PalGameStateInGame")
    return is_valid(world) and world or nil
end

local function player_uid(player_state)
    if not is_valid(player_state) then
        return nil
    end
    local ok, uid = safe_property(player_state, "PlayerUId")
    return ok and guid_key(uid) ~= nil and uid or nil
end

local function player_name(player_state)
    local ok, name = safe_property(player_state, "PlayerNamePrivate")
    name = ok and text_value(name) or ""
    if name == "" then
        local object_ok, object_name = safe_call(player_state, "GetName")
        name = object_ok and text_value(object_name) or "Unknown Player"
    end
    name = string.gsub(name, "[\r\n]+", " ")
    if #name > 40 then
        name = string.sub(name, 1, 40)
    end
    return name
end

local function state_from_actor_property(actor)
    local ok, state = safe_property(actor, "PlayerState")
    if ok and player_uid(state) ~= nil then
        return state
    end
    return nil
end

local function resolve_player_state(attacker, utility)
    if not is_valid(attacker) then
        return nil
    end

    local state = state_from_actor_property(attacker)
    if state ~= nil then
        return state
    end

    local state_ok, utility_state = safe_call(utility, "GetPlayerState", attacker)
    if state_ok and player_uid(utility_state) ~= nil then
        return utility_state
    end

    local trainer_ok, trainer = safe_call(utility, "GetTrainerPlayer", attacker)
    if not trainer_ok or not is_valid(trainer) then
        return nil
    end

    state = state_from_actor_property(trainer)
    if state ~= nil then
        return state
    end

    state_ok, utility_state = safe_call(utility, "GetPlayerState", trainer)
    if state_ok and player_uid(utility_state) ~= nil then
        return utility_state
    end
    return nil
end

local function actor_name_matches_boss_pattern(actor)
    local lower_name = string.lower(actor_full_name(actor))
    if lower_name == "" then
        return false
    end
    for _, pattern in ipairs(config.BossNamePatterns or {}) do
        if string.find(lower_name, string.lower(tostring(pattern)), 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function actor_is_player_owned(actor, utility)
    local ok, trainer = safe_call(utility, "GetTrainerPlayer", actor)
    return ok and is_valid(trainer)
end

local function get_boss_info(actor, utility)
    if not is_valid(actor) or actor_is_player_owned(actor, utility) then
        return nil
    end

    -- These are reflected bool properties on UPalStaticCharacterParameterComponent.
    -- Reading them avoids the crashing IsBossPal_Database/IsTowerBossPal UFunctions.
    local component_ok, component = safe_property(actor, "StaticCharacterParameterComponent")
    local is_boss = false
    if component_ok and is_valid(component) then
        local boss_ok, boss_value = safe_property(component, "IsBoss_Database")
        local tower_ok, tower_value = safe_property(component, "IsTowerBoss_Database")
        is_boss = (boss_ok and bool_value(boss_value)) or (tower_ok and bool_value(tower_value))
    end

    if not is_boss and config.UseBossNameFallback == true then
        is_boss = actor_name_matches_boss_pattern(actor)
    end
    if not is_boss then
        return nil
    end

    local full_name = actor_full_name(actor)
    if full_name == "" then
        return nil
    end
    local short_name = actor_short_name(actor)
    local display_name = config.BossNameOverrides and config.BossNameOverrides[short_name] or nil
    if display_name == nil or tostring(display_name) == "" then
        display_name = short_name
    end
    return { key = full_name, name = tostring(display_name) }
end

local function send_public_message(message)
    local utility = get_pal_utility()
    local world = find_world_context()
    if utility == nil or world == nil then
        log("broadcast skipped: PalUtility or PalGameStateInGame unavailable")
        return false
    end

    -- One server-wide announce is safer than one ProcessEvent call per player.
    local ok, result = safe_call(utility, "SendSystemAnnounce", world, tostring(message))
    if not ok then
        log("broadcast failed: " .. tostring(result))
        return false
    end
    return true
end

local function announce(message)
    local text = tostring(config.MessagePrefix or "[BossDPS]") .. " " .. tostring(message)
    if send_public_message(text) then
        log("broadcast: " .. text)
    end
end

local function format_integer(value)
    local number = math.floor(math.max(0, to_number(value)) + 0.5)
    local text = tostring(number)
    local sign, digits = string.match(text, "^([%-]?)(%d+)$")
    if digits == nil then
        return text
    end
    local formatted = string.reverse(digits):gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (sign or "") .. formatted
end

local function ranked_contributors(session)
    local rows = {}
    for _, entry in pairs(session.contributors) do
        rows[#rows + 1] = entry
    end
    table.sort(rows, function(a, b)
        if a.damage == b.damage then
            return a.name < b.name
        end
        return a.damage > b.damage
    end)
    return rows
end

local run_message_pump

local function schedule_message_pump(delay)
    local ok, err = pcall(function()
        ExecuteInGameThreadWithDelay(delay, run_message_pump)
    end)
    if not ok then
        message_pump_running = false
        metrics.errors = metrics.errors + 1
        log("failed to schedule broadcast pump: " .. tostring(err))
    end
end

run_message_pump = function()
    if message_head > message_tail then
        message_head = 1
        message_tail = 0
        message_pump_running = false
        return
    end

    local message = pending_messages[message_head]
    pending_messages[message_head] = nil
    message_head = message_head + 1
    local sent, send_err = pcall(announce, message)
    if not sent then
        metrics.errors = metrics.errors + 1
        log("delayed broadcast error: " .. tostring(send_err))
    end

    if message_head <= message_tail then
        local interval = math.max(0, math.floor(to_number(config.MessageIntervalMilliseconds)))
        schedule_message_pump(interval)
    else
        message_head = 1
        message_tail = 0
        message_pump_running = false
    end
end

local function queue_messages(messages)
    for _, message in ipairs(messages) do
        message_tail = message_tail + 1
        pending_messages[message_tail] = message
    end
    if not message_pump_running and message_head <= message_tail then
        message_pump_running = true
        schedule_message_pump(0)
    end
end

local function finish_session(session, reason)
    if session == nil or session.finished == true then
        return
    end
    session.finished = true
    sessions[session.key] = nil

    local duration = math.max(1, os.time() - session.started_at)
    local rows = ranked_contributors(session)
    local messages = {}
    local reason_text = reason == "defeated" and "已击败" or "统计结束（长时间无伤害）"
    messages[#messages + 1] = string.format(
        "%s %s！团队伤害 %s，用时 %d 秒，参与者 %d 人",
        session.name,
        reason_text,
        format_integer(session.total_damage),
        duration,
        #rows
    )

    local max_rows = math.max(1, math.floor(to_number(config.MaxResultRows)))
    for index = 1, math.min(max_rows, #rows) do
        local row = rows[index]
        local percent = session.total_damage > 0 and row.damage * 100 / session.total_damage or 0
        local line = string.format(
            "#%d %s｜%s｜伤害 %s｜%.1f%%",
            index, session.name, row.name, format_integer(row.damage), percent
        )
        if config.ShowDPS == true then
            line = line .. string.format("｜DPS %s", format_integer(row.damage / duration))
        end
        messages[#messages + 1] = line
    end
    if #rows > max_rows then
        messages[#messages + 1] = string.format("其余 %d 名参与者未展开显示", #rows - max_rows)
    end

    log(string.format(
        "session finished reason=%s boss=%s damage=%s duration=%d contributors=%d",
        tostring(reason), session.name, format_integer(session.total_damage), duration, #rows
    ))
    queue_messages(messages)
end

local function start_session(boss_info)
    local now = os.time()
    local session = {
        key = boss_info.key,
        name = boss_info.name,
        started_at = now,
        last_damage_at = now,
        total_damage = 0,
        contributors = {},
        finished = false,
    }
    sessions[session.key] = session
    if config.BroadcastStart ~= false then
        announce(string.format("开始统计：%s 已进入战斗", session.name))
    end
    log("session started boss=" .. session.name .. " key=" .. session.key)
    return session
end

local function record_damage(session, player_state, damage)
    local uid = player_uid(player_state)
    local key = guid_key(uid)
    if key == nil then
        return
    end

    local entry = session.contributors[key]
    if entry == nil then
        entry = { name = player_name(player_state), damage = 0, hits = 0 }
        session.contributors[key] = entry
    else
        entry.name = player_name(player_state)
    end
    entry.damage = entry.damage + damage
    entry.hits = entry.hits + 1
    session.total_damage = session.total_damage + damage
    session.last_damage_at = os.time()

    if config.TraceDamage == true then
        log(string.format(
            "damage boss=%s player=%s actual=%s player_total=%s team_total=%s",
            session.name, entry.name, format_integer(damage),
            format_integer(entry.damage), format_integer(session.total_damage)
        ))
    end
end

local function process_damage_event(event)
    if not is_valid(event.attacker) or not is_valid(event.defender) then
        metrics.invalid = metrics.invalid + 1
        return
    end

    local utility = get_pal_utility()
    if utility == nil then
        metrics.invalid = metrics.invalid + 1
        return
    end
    local state = resolve_player_state(event.attacker, utility)
    if state == nil then
        return
    end

    local key = actor_full_name(event.defender)
    if key == "" then
        metrics.invalid = metrics.invalid + 1
        return
    end
    local session = sessions[key]
    if session == nil then
        local boss_info = get_boss_info(event.defender, utility)
        if boss_info == nil then
            return
        end
        session = start_session(boss_info)
    end
    record_damage(session, state, event.damage)
end

local function process_death_event(event)
    if not is_valid(event.actor) then
        metrics.invalid = metrics.invalid + 1
        return
    end
    local key = actor_full_name(event.actor)
    local session = key ~= "" and sessions[key] or nil
    if session ~= nil then
        finish_session(session, "defeated")
    end
end

local schedule_drain

local function queue_size()
    return pending_tail >= pending_head and (pending_tail - pending_head + 1) or 0
end

local function pop_event()
    if pending_tail < pending_head then
        return nil
    end
    local event = pending_events[pending_head]
    pending_events[pending_head] = nil
    pending_head = pending_head + 1
    if pending_head > pending_tail then
        pending_head = 1
        pending_tail = 0
    end
    return event
end

local function drain_events()
    drain_scheduled = false
    local limit = math.max(1, math.floor(to_number(config.MaxEventsPerDrain)))
    local count = 0
    while count < limit do
        local event = pop_event()
        if event == nil then
            break
        end
        count = count + 1
        metrics.processed = metrics.processed + 1
        local ok, err
        if event.kind == "damage" then
            ok, err = pcall(process_damage_event, event)
        else
            ok, err = pcall(process_death_event, event)
        end
        if not ok then
            metrics.errors = metrics.errors + 1
            log("event processing error: " .. tostring(err))
        end
    end
    if queue_size() > 0 then
        schedule_drain()
    end
end

schedule_drain = function()
    if drain_scheduled then
        return
    end
    drain_scheduled = true
    local ok, err = pcall(function()
        if EngineTickAvailable == true and EGameThreadMethod ~= nil then
            ExecuteInGameThread(drain_events, EGameThreadMethod.EngineTick)
        else
            ExecuteInGameThread(drain_events)
        end
    end)
    if not ok then
        drain_scheduled = false
        metrics.errors = metrics.errors + 1
        log("failed to schedule game-thread drain: " .. tostring(err))
    end
end

local function enqueue_event(event)
    local max_pending = math.max(64, math.floor(to_number(config.MaxPendingEvents)))
    if event.kind == "damage" and queue_size() >= max_pending then
        metrics.dropped = metrics.dropped + 1
        return
    end
    pending_tail = pending_tail + 1
    pending_events[pending_tail] = event
    metrics.accepted = metrics.accepted + 1
    schedule_drain()
end

local function capture_damage(damage_param)
    -- Only unwrap the temporary hook parameter and copy its fields here.
    -- Do not call IsValid, Find*, StaticFindObject, or any UFunction.
    local result = unwrap(damage_param)
    if result == nil then
        return
    end
    local ok, attacker, defender, damage = pcall(function()
        return result.Attacker, result.Defender, finite_positive_number(result.ActualDamage)
    end)
    if not ok or attacker == nil or defender == nil or damage == nil then
        return
    end
    enqueue_event({ kind = "damage", attacker = attacker, defender = defender, damage = damage })
end

local function capture_death(dead_param)
    local result = unwrap(dead_param)
    if result == nil then
        return
    end
    local ok, actor = pcall(function()
        return result.SelfActor
    end)
    if ok and actor ~= nil then
        enqueue_event({ kind = "death", actor = actor })
    end
end

local function cleanup_sessions()
    local timeout = math.max(0, math.floor(to_number(config.InactivityTimeoutSeconds)))
    if timeout <= 0 then
        return
    end
    local now = os.time()
    local expired = {}
    for _, session in pairs(sessions) do
        if session.finished ~= true and now - session.last_damage_at >= timeout then
            expired[#expired + 1] = session
        end
    end
    for _, session in ipairs(expired) do
        finish_session(session, "timeout")
    end
end

local function schedule_cleanup()
    local seconds = math.max(5, math.floor(to_number(config.CleanupIntervalSeconds)))
    local ok, err = pcall(function()
        LoopInGameThreadWithDelay(seconds * 1000, function()
            local cleaned, cleanup_err = pcall(cleanup_sessions)
            if not cleaned then
                metrics.errors = metrics.errors + 1
                log("cleanup error: " .. tostring(cleanup_err))
            end
        end)
    end)
    if not ok then
        metrics.errors = metrics.errors + 1
        log("cleanup scheduling failed: " .. tostring(err))
    end
end

local function register_hooks()
    local damage_ok, damage_err = pcall(function()
        RegisterHook("/Script/Pal.PalEventNotify_Character:OnCharacterDamaged_ServerInternal", function(_, damage_result)
            local ok, err = pcall(capture_damage, damage_result)
            if not ok then
                metrics.errors = metrics.errors + 1
                log("damage capture error: " .. tostring(err))
            end
        end)
    end)
    hooks.damage = damage_ok
    if not damage_ok then
        log("damage hook registration failed: " .. tostring(damage_err))
    end

    local death_ok, death_err = pcall(function()
        RegisterHook("/Script/Pal.PalEventNotify_Character:OnCharacterDead_ServerInternal", function(_, dead_info)
            local ok, err = pcall(capture_death, dead_info)
            if not ok then
                metrics.errors = metrics.errors + 1
                log("death capture error: " .. tostring(err))
            end
        end)
    end)
    hooks.death = death_ok
    if not death_ok then
        log("death hook registration failed: " .. tostring(death_err))
    end

    if hooks.damage and hooks.death then
        log("loaded v2; hooks capture only, UObject work deferred to game thread")
    else
        log("disabled: one or more required hooks could not be registered")
    end
end

register_hooks()
if hooks.damage and hooks.death then
    schedule_cleanup()
end

if rawget(_G, "__BOSS_DPS_TEST") == true then
    _G.BossDPSBroadcastTestApi = {
        metrics = metrics,
        sessions = sessions,
        queue_size = queue_size,
        drain_events = drain_events,
        cleanup_sessions = cleanup_sessions,
    }
end
