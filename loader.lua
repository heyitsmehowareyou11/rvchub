local UI_URL = "https://raw.githubusercontent.com/heyitsmehowareyou11/rvchub/main/ui/dist/ui.lua"
local LOADER_URL = "https://raw.githubusercontent.com/heyitsmehowareyou11/rvchub/refs/heads/main/loader.lua"
local SERVICE = "hub"
local IDENTIFIER = "1229300"
local DISCORD_INVITE = "https://discord.gg/rvchub"

local GAMES = {
    [99409088950210] = { name = "Survive a Million Monkeys", script = "TOKEN_MONKEYS", reentrant = true },
    [115317125060158] = { name = "Survive a Million Monkeys", script = "TOKEN_MONKEYS", reentrant = true },
    [114326934417838] = { name = "Break and Steal an Egg", script = "TOKEN_BREAKANDSTEAL" },
    [74023858073178] = { name = "Bike For Egg", script = "TOKEN_BIKEFOREGG" },
    [107535308163741] = { name = "Huss Valley", script = "TOKEN_HUSSVALLEY" },
    [893973440] = { name = "Flee the Facility", script = "TOKEN_FLEEFACILITY" },
    [120219252362013] = { name = "Throw Food For Animals", script = "TOKEN_THROWFOOD", reentrant = true },
}

local UNIVERSES = {
    [10771421858] = { name = "DONT SPLASH", script = "TOKEN_DONTSPLASH", reentrant = true },
    [9098570654] = { name = "Survive an Apocalypse", script = "TOKEN_APOCALYPSE", reentrant = true },
}

local function report(msg)
    warn("[Vibecoders] " .. msg)
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local entry = GAMES[game.PlaceId] or UNIVERSES[game.GameId]
if not entry then
    report(string.format("Unsupported place (PlaceId %.0f, GameId %.0f).", game.PlaceId, game.GameId))
    return
end

local queueTeleport = queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

local qenv = (getgenv and getgenv()) or _G
if queueTeleport and not qenv.__VibecodersQueued then
    qenv.__VibecodersQueued = true
    pcall(queueTeleport, 'loadstring(game:HttpGet("' .. LOADER_URL .. '"))()')
end

local httpRequest = (syn and syn.request) or request or http_request or (fluxus and fluxus.request)
local hasHttpGet = false
do
    local ok, fn = pcall(function()
        return game.HttpGet
    end)
    hasHttpGet = ok and type(fn) == "function"
end

if not (httpRequest or hasHttpGet) then
    report("No HTTP function available.")
    return
end
if type(loadstring) ~= "function" then
    report("loadstring is not available.")
    return
end

local env = (getgenv and getgenv()) or _G
local loader = env.VibecodersLoader
if type(loader) ~= "table" or type(loader.status) ~= "table" then
    loader = { status = {} }
    env.VibecodersLoader = loader
end

local statusKey = entry.script .. "@" .. tostring(game.JobId)
local status = loader.status[statusKey]
if status == "loading" or (status and not entry.reentrant) then
    report(entry.name .. " is already loaded or loading in this server.")
    return
end
loader.status[statusKey] = "loading"

local function fetch(url)
    if httpRequest then
        local ok, res = pcall(httpRequest, { Url = url, Method = "GET" })
        if ok and type(res) == "table" then
            local code = res.StatusCode
            if type(code) == "number" and (code < 200 or code >= 300) then
                return nil, "HTTP " .. code
            end
            if res.Success == false then
                return nil, "request failed"
            end
            if type(res.Body) ~= "string" or res.Body == "" then
                return nil, "empty response"
            end
            return res.Body
        end
        if not hasHttpGet then
            return nil, ok and "unexpected response" or tostring(res)
        end
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        return nil, tostring(body)
    end
    if type(body) ~= "string" or body == "" then
        return nil, "empty response"
    end
    return body
end

local function abort(msg)
    loader.status[statusKey] = nil
    report(msg)
end

local source, err = fetch(UI_URL)
if not source or source:match("^%s*404: Not Found") then
    abort("Download failed for " .. UI_URL .. ": " .. (source and "file not found" or tostring(err)))
    return
end

local chunk, compileErr = loadstring(source)
if not chunk then
    abort("Could not compile the interface library: " .. tostring(compileErr))
    return
end

local loaded, Library = pcall(chunk)
if not loaded or type(Library) ~= "table" then
    abort("Interface library errored: " .. tostring(Library))
    return
end

local made, provider = pcall(Library.Providers.Jnkie, {
    Service = SERVICE,
    Identifier = IDENTIFIER,
    ScriptId = entry.script,
})
if not made then
    abort("Key provider errored: " .. tostring(provider))
    return
end

local opened, gateErr = pcall(Library.CreateKeyGate, Library, {
    Title = "RVC Hub",
    Subtitle = entry.name,
    Provider = provider,
    Links = {
        { Name = "Get key", Url = DISCORD_INVITE },
    },
    OnSuccess = function(key)
        loader.status[statusKey] = "running"
        local ok, runErr = xpcall(provider.LoadScript, function(e)
            return debug.traceback(tostring(e), 2)
        end, key)
        loader.status[statusKey] = "done"
        if not ok then
            report(entry.name .. " errored: " .. tostring(runErr))
        end
    end,
    OnClose = function()
        if loader.status[statusKey] == "loading" then
            loader.status[statusKey] = nil
        end
    end,
})
if not opened then
    abort("Key window errored: " .. tostring(gateErr))
end
