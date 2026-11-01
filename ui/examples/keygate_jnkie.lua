local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/v0.10.0/dist/ui.lua"))()

local jnkie = Library.Providers.Jnkie({
	Service = "RVC Hub",
	Identifier = "YOUR_JUNKIE_USER_ID",
	ScriptId = "YOUR_SCRIPT_PUBLIC_TOKEN",
})

Library:CreateKeyGate({
	Title = "RVC Hub",
	Subtitle = "Get a key in our Discord, then paste it here",
	Provider = jnkie,
	Links = {
		{ Name = "Get key", Url = "https://discord.gg/YOUR_INVITE" },
	},
	OnSuccess = function(key)
		jnkie.LoadScript(key)
	end,
})
