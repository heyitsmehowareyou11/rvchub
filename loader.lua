local UI_URL = "https://raw.githubusercontent.com/heyitsmehowareyou11/rvchub/main/ui/dist/ui.lua"
local LOADER_URL = "https://raw.githubusercontent.com/heyitsmehowareyou11/rvchub/refs/heads/main/loader.lua"
local SERVICE = "hub"
local IDENTIFIER = "1229300"
local DISCORD_INVITE = "https://discord.gg/rvchub"


local GAMES = {
    [99409088950210] = { name = "Survive a Million Monkeys", script = "93f9d39d8cf724e8129bf71c3449021c0724529c819980c28e952a2af1ca435c", reentrant = true },
    [115317125060158] = { name = "Survive a Million Monkeys", script = "93f9d39d8cf724e8129bf71c3449021c0724529c819980c28e952a2af1ca435c", reentrant = true },
    [114326934417838] = { name = "Break and Steal an Egg", script = "49ac5024022356e2a4ea2b08240427e520ceb7178bfbb6f3dac3db1136a57d72" },
    [120219252362013] = { name = "Throw Food For Animals", script = "661edaaddd0fd5b0550793fff39204754036497aec8391613aff31afe18609b2", reentrant = true },
}

local UNIVERSES = {
    [10771421858] = { name = "DONT SPLASH", script = "6be94740b6db447ff633009ba429be2ab1ea34377d13fb1ac36e4f3d379d4b71", reentrant = true },
    [9098570654] = { name = "Survive an Apocalypse", script = "808c37cfc10bd339ba8289b11996b944381fe4660706e9f40f18fee8485e80d3", reentrant = true },
}


local function notify(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "RVC Hub",
            Text = message,
            Duration = 7,
        })
    end)
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local entry = GAMES[game.PlaceId] or UNIVERSES[game.GameId]
if not entry then
    notify("This game isn't supported.")
    return
end

if type(entry.script) ~= "string" or entry.script:match("^TOKEN_") then
    notify("This game isn't available yet.")
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
if status == "loading" or status == "running" or (status == "done" and not entry.reentrant) then
    return
end
loader.status[statusKey] = "loading"

local function abort(message)
    loader.status[statusKey] = nil
    notify(message)
end

local queueTeleport = queue_on_teleport or queueonteleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

if queueTeleport and not env.__VibecodersQueued then
    local ok = pcall(queueTeleport, 'loadstring(game:HttpGet("' .. LOADER_URL .. '"))()')
    if ok then
        env.__VibecodersQueued = true
    end
end

if type(loadstring) ~= "function" then
    abort("This executor doesn't support loading scripts.")
    return
end

local httpRequest = (syn and syn.request) or request or http_request or (fluxus and fluxus.request)

local function fetch(url)
    if type(httpRequest) == "function" then
        local ok, response = pcall(httpRequest, { Url = url, Method = "GET" })
        if ok and type(response) == "table" and response.Success ~= false then
            local code = response.StatusCode
            if (type(code) ~= "number" or (code >= 200 and code < 300))
                and type(response.Body) == "string" and #response.Body > 0 then
                return response.Body
            end
        end
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end
end

local source = fetch(UI_URL)
if not source or source:match("^%s*404: Not Found") then
    abort("Could not download the RVC Hub interface.")
    return
end

local chunk = loadstring(source)
if not chunk then
    abort("Could not load the RVC Hub interface.")
    return
end

local loaded, Library = pcall(chunk)
if not loaded or type(Library) ~= "table" then
    abort("Could not start the RVC Hub interface.")
    return
end

local made, provider = pcall(function()
    return Library.Providers.Jnkie({
        Service = SERVICE,
        Identifier = IDENTIFIER,
        ScriptId = entry.script,
    })
end)

if not made or type(provider) ~= "table"
    or type(provider.Validate) ~= "function" or type(provider.LoadScript) ~= "function" then
    abort("Could not connect to the RVC Hub key system.")
    return
end

local opened, gate = pcall(Library.CreateKeyGate, Library, {
    Title = "RVC Hub",
    Icon = "https://github.com/destoryher/RobloxUI/blob/main/imageui.png?raw=true",
    Subtitle = entry.name,
    Provider = provider,
    Links = {
        { Name = "Get key", Url = DISCORD_INVITE },
    },
    OnSuccess = function(key)
        loader.status[statusKey] = "running"
        local ok, result = pcall(provider.LoadScript, key)
        if ok and result ~= false then
            loader.status[statusKey] = "done"
        else
            loader.status[statusKey] = nil
            notify("Could not load " .. entry.name .. ". Run RVC Hub again to retry.")
        end
    end,
    OnClose = function()
        if loader.status[statusKey] == "loading" then
            loader.status[statusKey] = nil
        end
    end,
})

if not opened or type(gate) ~= "table" then
    abort("Could not open the RVC Hub key window.")
end
