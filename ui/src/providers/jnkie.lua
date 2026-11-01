local Validate = require("util/validate")
local Env = require("util/env")

local Jnkie = {}

local SDK_URL = "https://jnkie.com/sdk/library.lua"

local MESSAGES = {
	KEY_INVALID = "That key is not valid.",
	KEY_EXPIRED = "This key has expired. Get a new one from the Discord server.",
	KEY_INVALIDATED = "This key has been disabled. Contact the script owner.",
	ALREADY_USED = "This key has already been used.",
	HWID_MISMATCH = "This key is locked to another device. Reset it from the key panel in Discord.",
	HWID_BANNED = "This device has been banned.",
	SERVICE_MISMATCH = "This key belongs to a different service.",
	SERVICE_NOT_FOUND = "The key service is not available.",
	PREMIUM_REQUIRED = "This script needs a Premium key.",
}

local UNREACHABLE = "Could not reach the key service. Check your connection."
local RATE_LIMITED = "Too many requests. Wait a moment and try again."

local function transient(message)
	return false, message, { Transient = true }
end

function Jnkie.new(opts)
	Validate.check("Providers.Jnkie", opts, {
		Service = "string|number!",
		Identifier = "string|number!",
		Provider = "string|number",
		ScriptId = "string",
		SdkUrl = "string",
		Messages = "table",
	})

	local provider = {}
	local sdk

	local function load()
		if not sdk then
			local library = loadstring(game:HttpGet(opts.SdkUrl or SDK_URL))()
			library.service = opts.Service
			library.identifier = tostring(opts.Identifier)
			library.provider = opts.Provider
			library.script_id = opts.ScriptId
			sdk = library
		end
		return sdk
	end

	function provider.Validate(key)
		local ok, result = pcall(function()
			return load().check_key(key)
		end)
		if not ok or type(result) ~= "table" then
			return transient(UNREACHABLE)
		end
		if result.valid == true then
			local message = result.is_keyless and "Keyless access granted." or "Key accepted."
			return true, message, {
				Premium = result.is_premium == true,
				Keyless = result.is_keyless == true,
				Tier = result.JD_TIER,
				TierName = result.JD_TIER_NAME,
			}
		end
		local code = tostring(result.error or "ERROR")
		local custom = opts.Messages and opts.Messages[code]
		if custom then
			return false, custom, { Code = code }
		end
		if code == "http 429" then
			return transient(RATE_LIMITED)
		end
		if code == "ERROR" or string.sub(code, 1, 5) == "http " then
			return transient(UNREACHABLE)
		end
		return false, MESSAGES[code] or "That key was not accepted.", { Code = code }
	end

	function provider.LoadScript(key)
		if type(opts.ScriptId) ~= "string" or opts.ScriptId == "" then
			error("[UI] Providers.Jnkie: ScriptId is required to load a script", 0)
		end
		if type(key) == "string" then
			Env().SCRIPT_KEY = key
		end
		return load().load_script()
	end

	return provider
end

return Jnkie
