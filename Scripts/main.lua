---@diagnostic disable: undefined-global

local config = require("./config")

local MOD = "[BossDPSBroadcast]"
local unpack_args = table.unpack or unpack
local sessions = {}
local hooks = {
    damage = false,
    death = false,
}

local function log(message)
    print(MOD .. " " .. tostring(message) .. "\n")
end

local function safe_call(object, method_name, ...)
    if object == nil then
        return false, nil
    end

    local args = { ... }
    return pcall(function()
        local method = object[method_name]
        if method == nil then
            return nil
        end
        return method(object, unpack_args(args))
    end)
end

local function unwrap(value)
    if value == nil then
        return nil
    end

    local ok, result = pcall(function()
        if value.get ~= nil then
            return value:get()
        end
        return value
    end)

    if ok and result ~= nil then
        return result
    end
    return value
end

local function is_valid(object)
    if object == nil then
        return false
    end

    local ok, result = safe_call(object, "IsValid")
    if ok and result ~= nil then
        return result == true
    end
    return true
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
    text = string.gsub(text, "^[%w_]+:%s*", "")
    return text
end

local function to_number(value)
    value = unwrap(value)
    if type(value) == "number" then
        return value
    end
    return tonumber(tostring(value or "")) or 0
end

local function actor_full_name(actor)
    local ok, name = safe_call(actor, "GetFullName")
    if ok and name ~= nil then
        return text_value(name)
    end
    return tostring(actor or "nil")
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

    return {
        A = a,
        B = b,
        C = c,
        D = d,
    }
end

local function guid_key(value)
    local guid = guid_parts(value)
    if guid == nil then
        return nil
    end
    return table.concat({ tostring(guid.A), tostring(guid.B), tostring(guid.C), tostring(guid.D) }, ":")
end

local function guid_is_zero(value)
    local guid = guid_parts(value)
    if guid == nil then
        return true
    end
    return to_number(guid.A) == 0
        and to_number(guid.B) == 0
        and to_number(guid.C) == 0
        and to_number(guid.D) == 0
end

local function find_world_context()
    local world = FindFirstOf("PalGameStateInGame")
    if is_valid(world) then
        return world
    end
    world = FindFirstOf("World")
    if is_valid(world) then
        return world
    end
    return nil
end

local function get_pal_utility()
    local utility = StaticFindObject("/Script/Pal.Default__PalUtility")
    if is_valid(utility) then
        return utility
    end
    return nil
end

local function all_player_states()
    local states = FindAllOf("PalPlayerState")
    if states == nil then
        return {}
    end
    return states
end

local function player_uid(player_state)
    if not is_valid(player_state) then
        return nil
    end
    local ok, value = pcall(function()
        return player_state.PlayerUId
    end)
    if not ok or guid_is_zero(value) then
        return nil
    end
    return value
end

local function player_name(player_state)
    local ok, name = safe_call(player_state, "GetPlayerName")
    name = ok and text_value(name) or ""
    if name == "" then
        local property_ok, property_name = pcall(function()
            return player_state.PlayerNamePrivate
        end)
        if property_ok then
            name = text_value(property_name)
        end
    end
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

local function find_player_state_by_uid(uid)
    local wanted = guid_key(uid)
    if wanted == nil then
        return nil
    end

    for _, state in pairs(all_player_states()) do
        local current = player_uid(state)
        if current ~= nil and guid_key(current) == wanted then
            return state
        end
    end
    return nil
end

local function character_parameter(actor, utility)
    local ok, parameter = safe_call(utility, "GetIndividualCharacterParameterByActor", actor)
    if ok and is_valid(parameter) then
        return parameter
    end
    return nil
end

local function parameter_owner_uid(parameter)
    if not is_valid(parameter) then
        return nil
    end

    local ok, save_parameter = safe_call(parameter, "GetSaveParameter")
    if not ok or save_parameter == nil then
        ok, save_parameter = pcall(function()
            return parameter.SaveParameter
        end)
    end
    save_parameter = unwrap(save_parameter)
    if not ok or save_parameter == nil then
        return nil
    end

    local owner_ok, owner_uid = pcall(function()
        return save_parameter.OwnerPlayerUId
    end)
    if not owner_ok or guid_is_zero(owner_uid) then
        return nil
    end
    return owner_uid
end

local function resolve_player_state(attacker, utility)
    if not is_valid(attacker) then
        return nil
    end

    local ok, state = safe_call(utility, "GetPlayerState", attacker)
    if ok and player_uid(state) ~= nil then
        return state
    end

    local trainer_ok, trainer = safe_call(utility, "GetTrainerPlayer", attacker)
    if trainer_ok and is_valid(trainer) then
        local state_ok, trainer_state = safe_call(utility, "GetPlayerState", trainer)
        if state_ok and player_uid(trainer_state) ~= nil then
            return trainer_state
        end
    end

    local owner_uid = parameter_owner_uid(character_parameter(attacker, utility))
    if owner_uid ~= nil then
        return find_player_state_by_uid(owner_uid)
    end

    return nil
end

local function character_id(parameter)
    local ok, value = safe_call(parameter, "GetCharacterID")
    if ok then
        return text_value(value)
    end
    return ""
end

local function character_is_owned(actor, utility)
    local trainer_ok, trainer = safe_call(utility, "GetTrainerPlayer", actor)
    if trainer_ok and is_valid(trainer) then
        return true
    end
    return parameter_owner_uid(character_parameter(actor, utility)) ~= nil
end

local function actor_name_matches_boss_pattern(actor)
    local lower_name = string.lower(actor_full_name(actor))
    for _, pattern in ipairs(config.BossNamePatterns or {}) do
        if string.find(lower_name, string.lower(tostring(pattern)), 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function get_boss_info(actor, utility)
    if not is_valid(actor) or character_is_owned(actor, utility) then
        return nil
    end

    local is_boss = false
    local component_ok, component = pcall(function()
        return actor.StaticCharacterParameterComponent
    end)
    if component_ok and is_valid(component) then
        local boss_ok, boss_result = safe_call(component, "IsBossPal_Database")
        local tower_ok, tower_result = safe_call(component, "IsTowerBossPal")
        is_boss = (boss_ok and boss_result == true) or (tower_ok and tower_result == true)
    end

    local parameter = character_parameter(actor, utility)
    local id = character_id(parameter)
    if not is_boss and id ~= "" then
        local database_ok, database = safe_call(utility, "GetDatabaseCharacterParameter", actor)
        if database_ok and is_valid(database) then
            local boss_ok, boss_result = safe_call(database, "GetIsBoss", id)
            local tower_ok, tower_result = safe_call(database, "GetIsTowerBoss", id)
            is_boss = (boss_ok and boss_result == true) or (tower_ok and tower_result == true)
        end
    end

    if not is_boss then
        is_boss = actor_name_matches_boss_pattern(actor)
    end
    if not is_boss then
        return nil
    end

    local display_name = config.BossNameOverrides and config.BossNameOverrides[id] or nil
    if display_name == nil or tostring(display_name) == "" then
        display_name = id ~= "" and id or actor_short_name(actor)
    end

    return {
        key = actor_full_name(actor),
        name = tostring(display_name),
        character_id = id,
    }
end

local function translate_guid(value)
    local guid = guid_parts(value)
    if guid == nil then
        return nil
    end
    return {
        A = guid.A,
        B = guid.B,
        C = guid.C,
        D = guid.D,
    }
end

local function send_to_all_players(message)
    local utility = get_pal_utility()
    local world = find_world_context()
    if utility == nil or world == nil then
        log("cannot broadcast; PalUtility or world context is unavailable")
        return
    end

    local delivered = 0
    for _, state in pairs(all_player_states()) do
        local uid = player_uid(state)
        local receiver = translate_guid(uid)
        if receiver ~= nil then
            local ok, err = safe_call(utility, "SendSystemToPlayerChat", world, tostring(message), receiver)
            if ok then
                delivered = delivered + 1
            else
                log("failed to send chat to " .. player_name(state) .. ": " .. tostring(err))
            end
        end
    end
    log("broadcast delivered=" .. tostring(delivered) .. " message=" .. tostring(message))
end

local function announce(message)
    send_to_all_players(tostring(config.MessagePrefix or "[BossDPS]") .. " " .. tostring(message))
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

local function queue_messages(messages)
    local interval = math.max(0, math.floor(to_number(config.MessageIntervalMilliseconds)))
    for index, message in ipairs(messages) do
        ExecuteWithDelay((index - 1) * interval, function()
            announce(message)
        end)
    end
end

local function finish_session(session, reason)
    if session == nil or session.finished == true then
        return
    end
    session.finished = true
    sessions[session.key] = nil

    local now = os.time()
    local duration = math.max(1, now - session.started_at)
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
            "#%d %s｜伤害 %s｜%.1f%%",
            index,
            row.name,
            format_integer(row.damage),
            percent
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
        tostring(reason),
        session.name,
        format_integer(session.total_damage),
        duration,
        #rows
    ))
    queue_messages(messages)
end

local function start_session(boss_info)
    local now = os.time()
    local session = {
        key = boss_info.key,
        name = boss_info.name,
        character_id = boss_info.character_id,
        started_at = now,
        last_damage_at = now,
        total_damage = 0,
        contributors = {},
        finished = false,
    }
    sessions[session.key] = session
    announce(string.format("开始统计：%s 已进入战斗", session.name))
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
        entry = {
            uid = translate_guid(uid),
            name = player_name(player_state),
            damage = 0,
            hits = 0,
        }
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
            session.name,
            entry.name,
            format_integer(damage),
            format_integer(entry.damage),
            format_integer(session.total_damage)
        ))
    end
end

local function handle_damage(damage_param)
    local result = unwrap(damage_param)
    if result == nil then
        return
    end

    local attacker = result.Attacker
    local defender = result.Defender
    local damage = to_number(result.ActualDamage)
    if damage <= 0 or not is_valid(attacker) or not is_valid(defender) then
        return
    end

    local utility = get_pal_utility()
    if utility == nil then
        return
    end

    local state = resolve_player_state(attacker, utility)
    if state == nil then
        return
    end

    local key = actor_full_name(defender)
    local session = sessions[key]
    if session == nil then
        local boss_info = get_boss_info(defender, utility)
        if boss_info == nil then
            return
        end
        session = start_session(boss_info)
    end

    record_damage(session, state, damage)
end

local function handle_death(dead_param)
    local dead_info = unwrap(dead_param)
    if dead_info == nil then
        return
    end

    local dead_actor = dead_info.SelfActor
    if not is_valid(dead_actor) then
        return
    end
    local session = sessions[actor_full_name(dead_actor)]
    if session ~= nil then
        finish_session(session, "defeated")
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
    ExecuteWithDelay(seconds * 1000, function()
        local ok, err = pcall(cleanup_sessions)
        if not ok then
            log("cleanup error: " .. tostring(err))
        end
        schedule_cleanup()
    end)
end

local function register_hooks()
    if not hooks.damage then
        local ok, err = pcall(function()
            RegisterHook("/Script/Pal.PalEventNotify_Character:OnCharacterDamaged_ServerInternal", function(_, damage_result)
                local handled, handle_err = pcall(handle_damage, damage_result)
                if not handled then
                    log("damage handler error: " .. tostring(handle_err))
                end
            end)
        end)
        hooks.damage = ok
        if not ok then
            log("damage hook registration failed: " .. tostring(err))
        end
    end

    if not hooks.death then
        local ok, err = pcall(function()
            RegisterHook("/Script/Pal.PalEventNotify_Character:OnCharacterDead_ServerInternal", function(_, dead_info)
                local handled, handle_err = pcall(handle_death, dead_info)
                if not handled then
                    log("death handler error: " .. tostring(handle_err))
                end
            end)
        end)
        hooks.death = ok
        if not ok then
            log("death hook registration failed: " .. tostring(err))
        end
    end

    if hooks.damage and hooks.death then
        log("loaded; damage and death hooks registered")
        return
    end

    ExecuteWithDelay(5000, register_hooks)
end

register_hooks()
schedule_cleanup()
