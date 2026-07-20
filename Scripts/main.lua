---@diagnostic disable: undefined-global

local config = require("./config")
local battle_commentary = require("./commentary")

local MOD = "[BossDPSBroadcast]"
local unpack_args = table.unpack or unpack
local sessions = {}
local session_addresses = {}
local hooks = { damage = false, death = false, captured = false }

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

    local ok, result = safe_call(value, "GetDisplayString")
    if ok and result ~= nil then
        value = result
    end

    ok, result = safe_call(value, "ToString")
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

local function actor_address(actor)
    local ok, address = safe_call(actor, "GetAddress")
    address = ok and to_number(address) or 0
    if address <= 0 then
        return nil
    end
    return tostring(address)
end

local function actor_short_name(actor)
    local full_name = actor_full_name(actor)
    local text = string.match(full_name, "%.([^%.%s:]+)$") or ""
    if text == "" then
        local ok, name = safe_call(actor, "GetName")
        text = ok and text_value(name) or full_name
    end
    text = string.gsub(text, "_C_%d+$", "")
    text = string.gsub(text, "_C$", "")
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

local function copy_guid(value)
    local guid = guid_parts(value)
    if guid == nil then
        return nil
    end
    return {
        A = to_number(guid.A),
        B = to_number(guid.B),
        C = to_number(guid.C),
        D = to_number(guid.D),
    }
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

local function state_from_player_actor(actor, utility)
    local state = state_from_actor_property(actor)
    if state ~= nil then
        return state
    end
    local state_ok, utility_state = safe_call(utility, "GetPlayerState", actor)
    return state_ok and player_uid(utility_state) ~= nil and utility_state or nil
end

local function trainer_state(actor, utility)
    local trainer_ok, trainer = safe_call(utility, "GetTrainerPlayer", actor)
    if not trainer_ok or not is_valid(trainer) then
        return nil
    end
    return state_from_player_actor(trainer, utility)
end

local function resolve_source_actor(candidate, utility, depth, seen)
    if depth > 3 or not is_valid(candidate) then
        return nil, nil, nil
    end
    local identity = actor_address(candidate) or actor_full_name(candidate)
    if identity ~= "" and seen[identity] then
        return nil, nil, nil
    end
    if identity ~= "" then
        seen[identity] = true
    end

    -- A real Pal character exposes CharacterParameterComponent. Checking this
    -- before generic player lookup prevents a mounted Pal from becoming a
    -- player row when a helper API resolves its trainer.
    local component_ok, component = safe_property(candidate, "CharacterParameterComponent")
    if component_ok and is_valid(component) then
        local state = trainer_state(candidate, utility)
        if state ~= nil then
            return state, "pal", candidate
        end
    end

    local state = state_from_player_actor(candidate, utility)
    if state ~= nil then
        return state, "player", candidate
    end

    -- Skill projectiles and unique ride weapons commonly keep the true source
    -- in one of these ownership fields. Follow a small bounded chain only.
    for _, property_name in ipairs({ "Owner", "Instigator", "InstigatorController", "OverrideNetworkOwner" }) do
        local nested_ok, nested = safe_property(candidate, property_name)
        if nested_ok and is_valid(nested) then
            local nested_state, nested_kind, nested_source =
                resolve_source_actor(nested, utility, depth + 1, seen)
            if nested_state ~= nil then
                return nested_state, nested_kind, nested_source
            end
        end
    end

    local fallback_state = trainer_state(candidate, utility)
    if fallback_state ~= nil then
        return fallback_state, "pal", candidate
    end
    return nil, nil, nil
end

local function resolve_damage_owner(event, utility)
    local candidates = {}
    for _, field_name in ipairs({
        "damage_causer", "override_network_owner", "info_attacker", "attacker",
    }) do
        local candidate = event[field_name]
        if candidate ~= nil then
            candidates[#candidates + 1] = candidate
        end
    end
    local seen = {}
    for _, candidate in ipairs(candidates) do
        if candidate ~= nil then
            local state, source_kind, source_actor =
                resolve_source_actor(candidate, utility, 0, seen)
            if state ~= nil then
                return state, source_kind, source_actor
            end
        end
    end
    return nil, nil, nil
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

local function normalized_boss_id(value)
    local text = text_value(value)
    text = string.match(text, "%.([^%.%s:]+)$") or text
    text = string.gsub(text, "_C_%d+$", "")
    text = string.gsub(text, "_C$", "")
    text = string.gsub(text, "^BP_", "")
    text = string.gsub(text, "^BOSS_", "")
    return text
end

local function boss_display_name(actor, utility, short_name)
    local character_id
    local id_ok, id_value = safe_call(utility, "GetCharacterIDFromCharacter", actor)
    if id_ok then
        character_id = normalized_boss_id(id_value)
    end

    local overrides = config.BossNameOverrides or {}
    local candidates = { character_id, normalized_boss_id(short_name), short_name }
    for _, candidate in ipairs(candidates) do
        if candidate ~= nil and candidate ~= "" then
            local override = overrides[candidate]
            if override ~= nil and tostring(override) ~= "" then
                return tostring(override)
            end
            local without_suffix = string.gsub(candidate, "_BOSS$", "")
            override = overrides[without_suffix]
            if override ~= nil and tostring(override) ~= "" then
                return tostring(override)
            end
        end
    end

    -- This lookup runs once, on the game thread, when a session starts. The
    -- out-table matches UE4SS handling for FString/FText out parameters.
    if character_id ~= nil and character_id ~= "" then
        local world = find_world_context()
        local database_ok, database = false, nil
        if world ~= nil then
            database_ok, database = safe_call(utility, "GetDatabaseCharacterParameter", world)
        end
        if database_ok and is_valid(database) then
            local out_text = {}
            local localized_ok = safe_call(database, "GetLocalizedCharacterName", id_value, out_text)
            if localized_ok then
                local localized = text_value(out_text.OutText)
                if localized ~= "" and string.find(localized, "/Game/", 1, true) == nil then
                    return localized
                end
            end
        end
    end

    -- A short internal id is preferable to leaking the full UObject path if
    -- this Pal has no localized name on the dedicated server.
    return normalized_boss_id(short_name)
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
    local display_name = boss_display_name(actor, utility, short_name)
    return {
        key = full_name,
        address = actor_address(actor),
        name = tostring(display_name),
    }
end

local function clean_label(value, fallback)
    local label = text_value(value)
    label = string.gsub(label, "[\r\n]+", " ")
    if label == "" then
        label = tostring(fallback or "")
    end
    if #label > 48 then
        label = string.sub(label, 1, 48)
    end
    return label
end

local function localized_character_name(character_id, utility, fallback)
    local normalized = normalized_boss_id(character_id)
    local override = (config.PalNameOverrides or {})[normalized]
    if override ~= nil and tostring(override) ~= "" then
        return clean_label(override, fallback)
    end

    local world = find_world_context()
    if world ~= nil then
        local database_ok, database = safe_call(utility, "GetDatabaseCharacterParameter", world)
        if database_ok and is_valid(database) then
            local out_text = {}
            local localized_ok = safe_call(database, "GetLocalizedCharacterName", character_id, out_text)
            if localized_ok then
                local localized = text_value(
                    out_text.OutText or out_text.outText or out_text.ReturnValue
                )
                if localized ~= "" and string.find(localized, "/Game/", 1, true) == nil then
                    return clean_label(localized, fallback)
                end
            end
        end
    end
    return clean_label(normalized, fallback)
end

local function pal_source_info(actor, utility)
    local component_ok, component = safe_property(actor, "CharacterParameterComponent")
    local individual_ok, individual = false, nil
    if component_ok and is_valid(component) then
        individual_ok, individual = safe_property(component, "IndividualParameter")
    end

    local source_key = actor_address(actor) or actor_full_name(actor)
    local character_id = actor_short_name(actor)
    local nickname = ""
    if individual_ok and is_valid(individual) then
        source_key = actor_address(individual) or source_key
        local id_ok, id_value = safe_call(individual, "GetCharacterID")
        if id_ok and text_value(id_value) ~= "" then
            character_id = id_value
        end
        local out_name = {}
        local nickname_ok = safe_call(individual, "GetNickname", out_name)
        if nickname_ok then
            nickname = clean_label(
                out_name.outName or out_name.OutName or out_name.OutText or out_name.ReturnValue,
                ""
            )
        end
    end

    local species = localized_character_name(character_id, utility, actor_short_name(actor))
    local display = species
    if nickname ~= "" and nickname ~= species then
        display = string.format("%s（%s）", nickname, species)
    end
    return tostring(source_key or display), display, species, nickname
end

local function player_team_info(player_state, uid, fallback_name)
    local guild_ok, guild = safe_property(player_state, "GuildBelongTo")
    if guild_ok and is_valid(guild) then
        local guild_key = actor_address(guild)
        local name_ok, guild_name = safe_property(guild, "GuildName")
        guild_name = name_ok and clean_label(guild_name, "") or ""
        if guild_name == "" then
            local call_ok, call_name = safe_call(guild, "GetGuildName")
            guild_name = call_ok and clean_label(call_name, "") or ""
        end
        if guild_key ~= nil then
            return "guild:" .. guild_key, guild_name ~= "" and guild_name or "未命名公会"
        end
    end
    return "solo:" .. tostring(guid_key(uid)), tostring(fallback_name) .. "的小队"
end

local function send_participant_message(message, recipients)
    local utility = get_pal_utility()
    local world = find_world_context()
    if utility == nil or world == nil then
        log("participant message skipped: PalUtility or PalGameStateInGame unavailable")
        return false
    end

    local sent = 0
    for _, receiver_uid in ipairs(recipients or {}) do
        local ok, result = safe_call(
            utility, "SendSystemToPlayerChat", world, tostring(message), receiver_uid
        )
        if ok then
            sent = sent + 1
        else
            log("participant message failed: " .. tostring(result))
        end
    end
    return sent > 0
end

local function announce(message, recipients)
    local text = tostring(config.MessagePrefix or "[BossDPS]") .. " " .. tostring(message)
    if send_participant_message(text, recipients) then
        log(string.format("participant message recipients=%d: %s", #(recipients or {}), text))
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
            if a.hits ~= b.hits then
                return a.hits > b.hits
            end
            return a.name < b.name
        end
        return a.damage > b.damage
    end)
    return rows
end

local function ranked_damage_entries(entries)
    local rows = {}
    for _, entry in pairs(entries or {}) do
        if entry.damage > 0 then
            rows[#rows + 1] = entry
        end
    end
    table.sort(rows, function(a, b)
        if a.damage == b.damage then
            if (a.hits or 0) ~= (b.hits or 0) then
                return (a.hits or 0) > (b.hits or 0)
            end
            return tostring(a.name) < tostring(b.name)
        end
        return a.damage > b.damage
    end)
    return rows
end

local function session_recipients(session)
    local recipients = {}
    for _, entry in pairs(session.contributors) do
        local uid = copy_guid(entry.uid)
        if uid ~= nil then
            recipients[#recipients + 1] = uid
        end
    end
    return recipients
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
    local sent, send_err = pcall(announce, message.text, message.recipients)
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

local function queue_messages(messages, recipients)
    if #(recipients or {}) == 0 then
        return
    end
    for _, message in ipairs(messages) do
        message_tail = message_tail + 1
        pending_messages[message_tail] = {
            text = tostring(message),
            recipients = recipients,
        }
    end
    if not message_pump_running and message_head <= message_tail then
        message_pump_running = true
        schedule_message_pump(0)
    end
end

local function team_recipients(session, team_key)
    local recipients = {}
    for _, entry in pairs(session.contributors) do
        if entry.team_key == team_key then
            local uid = copy_guid(entry.uid)
            if uid ~= nil then
                recipients[#recipients + 1] = uid
            end
        end
    end
    return recipients
end

local function queue_team_details(session, duration)
    local max_rows = math.max(1, math.floor(to_number(config.TeamDetailMaxRows)))
    for team_key, team in pairs(session.teams) do
        local sources = {}
        for _, entry in pairs(session.contributors) do
            if entry.team_key == team_key and entry.direct_damage > 0 then
                sources[#sources + 1] = {
                    name = entry.name .. "（玩家角色）",
                    damage = entry.direct_damage,
                    hits = entry.direct_hits,
                }
            end
        end
        for _, pal in pairs(session.pal_sources) do
            if pal.team_key == team_key and pal.damage > 0 then
                sources[#sources + 1] = {
                    name = pal.name .. "［" .. pal.owner_name .. "］",
                    damage = pal.damage,
                    hits = pal.hits,
                }
            end
        end
        sources = ranked_damage_entries(sources)

        local messages = {
            string.format(
                "队内私报：%s｜伤害 %s｜DPS %s｜来源 %d个",
                team.name,
                format_integer(team.damage),
                format_integer(team.damage / duration),
                #sources
            ),
        }
        for index = 1, math.min(max_rows, #sources) do
            local source = sources[index]
            local percent = team.damage > 0 and source.damage * 100 / team.damage or 0
            messages[#messages + 1] = string.format(
                "队内 #%d %s｜伤害 %s｜%.1f%%｜DPS %s",
                index,
                source.name,
                format_integer(source.damage),
                percent,
                format_integer(source.damage / duration)
            )
        end
        if #sources > max_rows then
            messages[#messages + 1] = string.format("其余 %d 个伤害来源未展开", #sources - max_rows)
        end
        queue_messages(messages, team_recipients(session, team_key))
    end
end

local function finish_session(session, reason)
    if session == nil or session.finished == true then
        return
    end
    session.finished = true
    sessions[session.key] = nil
    if session.address ~= nil then
        session_addresses[session.address] = nil
    end

    local duration = math.max(1, os.time() - session.started_at)
    local rows = ranked_contributors(session)
    local teams = ranked_damage_entries(session.teams)
    local pals = ranked_damage_entries(session.pal_sources)
    local recipients = session_recipients(session)
    local messages = {}
    local reason_text
    if reason == "defeated" then
        reason_text = "已击败"
    elseif reason == "captured" then
        reason_text = "已捕捉"
    else
        reason_text = "挑战中断（长时间无伤害）"
    end
    local team_prefix = #teams == 1 and (teams[1].name .. "｜") or ""
    messages[#messages + 1] = string.format(
        "%s%s %s！团队伤害 %s｜团队DPS %s｜用时 %d秒｜%d人",
        team_prefix,
        session.name,
        reason_text,
        format_integer(session.total_damage),
        format_integer(session.total_damage / duration),
        duration,
        #rows
    )

    if config.EnableFunComments ~= false then
        local top_share = #rows > 0 and rows[1].damage * 100 / session.total_damage or 0
        local second_share = #rows > 1 and rows[2].damage * 100 / session.total_damage or 0
        local comment = battle_commentary.final({
            key = session.key,
            reason = reason,
            total = session.total_damage,
            duration = duration,
            team_dps = session.total_damage / duration,
            top_share = top_share,
            second_share = second_share,
        })
        messages[#messages + 1] = "战斗点评：" .. tostring(comment)
    end

    if #teams > 1 then
        local team = teams[1]
        local team_percent = session.total_damage > 0 and team.damage * 100 / session.total_damage or 0
        messages[#messages + 1] = string.format(
            "最高伤害队伍：%s｜伤害 %s｜%.1f%%｜DPS %s",
            team.name,
            format_integer(team.damage),
            team_percent,
            format_integer(team.damage / duration)
        )
    end


    local direct_players = {}
    for _, row in ipairs(rows) do
        if row.direct_damage > 0 then
            direct_players[#direct_players + 1] = {
                name = row.name,
                damage = row.direct_damage,
                hits = row.direct_hits,
            }
        end
    end
    direct_players = ranked_damage_entries(direct_players)
    if #direct_players > 0 then
        local direct = direct_players[1]
        messages[#messages + 1] = string.format(
            "最高伤害玩家角色：%s｜伤害 %s｜DPS %s",
            direct.name,
            format_integer(direct.damage),
            format_integer(direct.damage / duration)
        )
    end

    if #pals > 0 then
        local pal = pals[1]
        messages[#messages + 1] = string.format(
            "最高伤害帕鲁：%s｜训练家 %s｜伤害 %s｜DPS %s",
            pal.name,
            pal.owner_name,
            format_integer(pal.damage),
            format_integer(pal.damage / duration)
        )
    end

    local max_rows = math.max(1, math.floor(to_number(config.MaxResultRows)))
    for index = 1, math.min(max_rows, #rows) do
        local row = rows[index]
        local percent = session.total_damage > 0 and row.damage * 100 / session.total_damage or 0
        local line = string.format(
            "#%d %s｜伤害 %s｜%.1f%%",
            index, row.name, format_integer(row.damage), percent
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
    queue_messages(messages, recipients)
    queue_team_details(session, duration)
end

local function start_session(boss_info)
    local now = os.time()
    local session = {
        key = boss_info.key,
        address = boss_info.address,
        name = boss_info.name,
        started_at = now,
        last_damage_at = now,
        last_progress_at = now,
        total_damage = 0,
        progress_damage = 0,
        previous_progress_dps = 0,
        progress_index = 0,
        contributors = {},
        teams = {},
        pal_sources = {},
        start_announced = false,
        finished = false,
    }
    sessions[session.key] = session
    if session.address ~= nil then
        session_addresses[session.address] = session
    end
    log("session started boss=" .. session.name .. " key=" .. session.key)
    return session
end

local function record_damage(session, player_state, damage, source_kind, source_actor, utility)
    local uid = player_uid(player_state)
    local key = guid_key(uid)
    if key == nil then
        return
    end

    local entry = session.contributors[key]
    if entry == nil then
        entry = {
            uid = copy_guid(uid),
            name = player_name(player_state),
            damage = 0,
            progress_damage = 0,
            hits = 0,
            direct_damage = 0,
            direct_hits = 0,
        }
        entry.team_key, entry.team_name = player_team_info(player_state, uid, entry.name)
        session.contributors[key] = entry
    else
        entry.name = player_name(player_state)
    end
    entry.damage = entry.damage + damage
    entry.progress_damage = entry.progress_damage + damage
    entry.hits = entry.hits + 1
    session.total_damage = session.total_damage + damage
    session.progress_damage = session.progress_damage + damage
    session.last_damage_at = os.time()

    local team = session.teams[entry.team_key]
    if team == nil then
        team = { name = entry.team_name, damage = 0, hits = 0 }
        session.teams[entry.team_key] = team
    end
    team.name = entry.team_name
    team.damage = team.damage + damage
    team.hits = team.hits + 1

    if source_kind == "pal" then
        local source_key, display_name = pal_source_info(source_actor, utility)
        local pal = session.pal_sources[source_key]
        if pal == nil then
            pal = {
                name = display_name,
                owner_name = entry.name,
                owner_uid_key = key,
                team_key = entry.team_key,
                damage = 0,
                hits = 0,
            }
            session.pal_sources[source_key] = pal
        end
        pal.name = display_name
        pal.owner_name = entry.name
        pal.team_key = entry.team_key
        pal.damage = pal.damage + damage
        pal.hits = pal.hits + 1
    else
        entry.direct_damage = entry.direct_damage + damage
        entry.direct_hits = entry.direct_hits + 1
    end

    if session.start_announced ~= true then
        session.start_announced = true
        if config.BroadcastStart ~= false then
            queue_messages(
                { string.format("开始统计：%s 已进入战斗", session.name) },
                session_recipients(session)
            )
        end
    end

    if config.TraceDamage == true then
        log(string.format(
            "damage boss=%s player=%s actual=%s player_total=%s team_total=%s",
            session.name, entry.name, format_integer(damage),
            format_integer(entry.damage), format_integer(session.total_damage)
        ))
    end
end

local function publish_progress()
    local interval_setting = math.max(0, math.floor(to_number(config.ProgressIntervalSeconds)))
    if interval_setting <= 0 then
        return
    end

    local now = os.time()
    for _, session in pairs(sessions) do
        if session.finished ~= true and session.total_damage > 0
            and now - session.last_progress_at >= interval_setting then
            local window = math.max(1, now - session.last_progress_at)
            local rows = ranked_contributors(session)
            local teams = ranked_damage_entries(session.teams)
            local recipients = session_recipients(session)
            local current_dps = session.progress_damage / window
            local team_prefix = #teams == 1 and (teams[1].name .. "｜") or ""
            local messages = {
                string.format(
                    "%s实时战况：%s｜总伤害 %s｜当前DPS %s",
                    team_prefix,
                    session.name,
                    format_integer(session.total_damage),
                    format_integer(current_dps)
                ),
            }

            local max_rows = math.max(1, math.floor(to_number(config.ProgressMaxRows)))
            local compact = {}
            for index = 1, math.min(max_rows, #rows) do
                local row = rows[index]
                local percent = session.total_damage > 0 and row.damage * 100 / session.total_damage or 0
                compact[#compact + 1] = string.format(
                    "#%d %s %s(%.1f%%/%sDPS)",
                    index,
                    row.name,
                    format_integer(row.damage),
                    percent,
                    format_integer(row.progress_damage / window)
                )
            end
            if #rows > max_rows then
                compact[#compact + 1] = string.format("另有%d人", #rows - max_rows)
            end
            if #compact > 0 then
                messages[#messages + 1] = "输出：" .. table.concat(compact, "｜")
            end

            session.progress_index = session.progress_index + 1
            if config.EnableFunComments ~= false and session.progress_damage > 0 then
                local top_share = #rows > 0 and rows[1].damage * 100 / session.total_damage or 0
                local comment = battle_commentary.progress({
                    key = session.key,
                    total = session.total_damage,
                    previous_total = session.total_damage - session.progress_damage,
                    window_damage = session.progress_damage,
                    current_dps = current_dps,
                    previous_dps = session.previous_progress_dps,
                    top_share = top_share,
                    window_index = session.progress_index,
                })
                if comment ~= nil then
                    messages[#messages + 1] = "战况点评：" .. tostring(comment)
                end
            end

            if session.progress_damage > 0 then
                queue_messages(messages, recipients)
            end
            session.previous_progress_dps = current_dps
            session.last_progress_at = now
            session.progress_damage = 0
            for _, row in ipairs(rows) do
                row.progress_damage = 0
            end
        end
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
    local state, source_kind, source_actor = resolve_damage_owner(event, utility)
    if state == nil then
        return
    end

    local address = actor_address(event.defender)
    local key = actor_full_name(event.defender)
    if key == "" then
        metrics.invalid = metrics.invalid + 1
        return
    end
    local session = address ~= nil and session_addresses[address] or sessions[key]
    if session == nil then
        local boss_info = get_boss_info(event.defender, utility)
        if boss_info == nil then
            return
        end
        session = start_session(boss_info)
    end
    record_damage(session, state, event.damage, source_kind, source_actor or event.attacker, utility)
end

local function process_finish_event(event)
    -- GetAddress is a UE4SS wrapper operation and does not dereference the
    -- UObject. It can still identify a session if capture invalidated the actor.
    local address = actor_address(event.actor)
    local session = address ~= nil and session_addresses[address] or nil
    if session == nil and is_valid(event.actor) then
        local key = actor_full_name(event.actor)
        session = key ~= "" and sessions[key] or nil
    end
    if session ~= nil then
        finish_session(session, event.reason)
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
            ok, err = pcall(process_finish_event, event)
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
    local function copied_field(container, field_name)
        if container == nil then
            return nil
        end
        local field_ok, value = pcall(function()
            return container[field_name]
        end)
        return field_ok and value or nil
    end

    local damage_info = copied_field(result, "DamageInfo")
        or copied_field(result, "CharacterDamageInfo")
        or copied_field(result, "damageInfo")
    local damage_causer = copied_field(result, "DamageCauser")
        or copied_field(result, "damageCauser")
        or copied_field(damage_info, "DamageCauser")
    local override_network_owner = copied_field(result, "OverrideNetworkOwner")
        or copied_field(damage_info, "OverrideNetworkOwner")
    local info_attacker = copied_field(damage_info, "Attacker")

    enqueue_event({
        kind = "damage",
        attacker = attacker,
        defender = defender,
        damage = damage,
        damage_causer = damage_causer,
        override_network_owner = override_network_owner,
        info_attacker = info_attacker,
    })
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
        enqueue_event({ kind = "finish", reason = "defeated", actor = actor })
    end
end

local function capture_captured(character_param)
    local actor = unwrap(character_param)
    if actor ~= nil then
        enqueue_event({ kind = "finish", reason = "captured", actor = actor })
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

local function schedule_progress()
    local seconds = math.max(0, math.floor(to_number(config.ProgressIntervalSeconds)))
    if seconds <= 0 then
        return
    end
    local ok, err = pcall(function()
        LoopInGameThreadWithDelay(seconds * 1000, function()
            local published, publish_err = pcall(publish_progress)
            if not published then
                metrics.errors = metrics.errors + 1
                log("progress publishing error: " .. tostring(publish_err))
            end
        end)
    end)
    if not ok then
        metrics.errors = metrics.errors + 1
        log("progress scheduling failed: " .. tostring(err))
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

    local capture_candidates = {
        "/Script/Pal.PalCharacter:OnCaptured",
        "/Script/Pal.PalCaptureJudgeObject:OnCaptureSuccess",
    }
    local capture_errors = {}
    for _, capture_path in ipairs(capture_candidates) do
        local captured_ok, captured_err = pcall(function()
            RegisterHook(capture_path, function(_, captured_character, _capture_result)
                local ok, err = pcall(capture_captured, captured_character)
                if not ok then
                    metrics.errors = metrics.errors + 1
                    log("capture completion error: " .. tostring(err))
                end
            end)
        end)
        if captured_ok then
            hooks.captured = true
            log("capture completion hook=" .. capture_path)
            break
        end
        capture_errors[#capture_errors + 1] = capture_path .. ": " .. tostring(captured_err)
    end
    if not hooks.captured then
        log("capture hook registration failed: " .. table.concat(capture_errors, " | "))
    end

    if hooks.damage and hooks.death then
        log(string.format(
            "loaded v2.2; hooks capture only, UObject work deferred to game thread; captured_hook=%s",
            tostring(hooks.captured)
        ))
    else
        log("disabled: one or more required hooks could not be registered")
    end
end

register_hooks()
if hooks.damage and hooks.death then
    schedule_cleanup()
    schedule_progress()
end

if rawget(_G, "__BOSS_DPS_TEST") == true then
    _G.BossDPSBroadcastTestApi = {
        metrics = metrics,
        sessions = sessions,
        queue_size = queue_size,
        drain_events = drain_events,
        cleanup_sessions = cleanup_sessions,
        publish_progress = publish_progress,
    }
end
