DeriveGamemode("sandbox")

GM.Name = "Found Footage"
GM.Author = ""
GM.Email = ""
GM.Website = ""

-- The gamemode intentionally suppresses transient notifications, chat notices,
-- and debug-only console output. Gameplay errors still use normal error paths.
function FF_DiscardNotification(...) end
function FF_DiscardOutput(...) end

if SERVER then
    AddCSLuaFile("configuration.lua")
end

include("configuration.lua")

player_manager.AddValidModel("Async Researcher", FF_CONFIG.Player.Model)
player_manager.AddValidHands(
    "Async Researcher",
    FF_CONFIG.Player.HandsModel,
    FF_CONFIG.Player.Skin or 0,
    FF_CONFIG.Player.BodyGroups or "00000000"
)
list.Set("PlayerOptionsModel", "Async Researcher", FF_CONFIG.Player.Model)
