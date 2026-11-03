--[[
    Raven UI - Example.lua
    Rebuilds every page of the Raven.cc reference:
        Aimbot   (General / Weapons / Other)
        Visuals  (Players / Chams / Other)
        World, Miscellaneous, Configs, Settings
    plus the watermark, keybind list, tooltips, notifications, search and the ESP preview.

    Loading order:
      1. If Raven/Library.lua exists in your executor workspace it is used (handy while editing).
      2. Otherwise the library is downloaded from LIBRARY_URL. Point it at wherever you host Library.lua.
]]

local LIBRARY_URL = "https://raw.githubusercontent.com/ImLiwo/ui-repo/main/raven/Library.lua"

local function LoadLibrary()
    if type(isfile) == "function" and type(readfile) == "function" and isfile("Raven/Library.lua") then
        return loadstring(readfile("Raven/Library.lua"))()
    end
    return loadstring(game:HttpGet(LIBRARY_URL))()
end

local Library = LoadLibrary()
local Options = Library.Options
local Flags = Library.Flags

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Raven",
    Suffix = ".cc",
    Logo = "shield",
    Keybind = "Insert",
    ConfigFolder = "Raven.cc",
    Size = Vector2.new(880, 560),
})

--------------------------------------------------------------------------------
-- Aimbot
--------------------------------------------------------------------------------
local Aimbot = Window:AddTab({ Name = "Aimbot", Icon = "crosshair" })
local AimGeneral = Aimbot:AddSubTab({ Name = "General", Icon = "home" })
local AimWeapons = Aimbot:AddSubTab({ Name = "Weapons", Icon = "sword" })
local AimOther = Aimbot:AddSubTab({ Name = "Other", Icon = "dots" })

-- General
local Main = AimGeneral:AddSection({ Name = "Main", Icon = "crosshair", Side = "Left" })
Main:AddToggle("AimEnabled", {
    Text = "Enabled",
    Default = true,
    Tooltip = "Master switch for the aimbot",
}):AddKeybind("AimKey", {
    Text = "Aimbot",
    Default = "MB2", -- the reference shows M5; Roblox cannot detect mouse buttons 4/5
    Mode = "Hold",
})
Main:AddToggle("SilentAim", { Text = "Silent aim", Default = false, DependsOn = "AimEnabled" })
Main:AddToggle("VisibleOnly", { Text = "Visible only", Default = true, DependsOn = "AimEnabled" })
Main:AddToggle("IgnoreTeammates", { Text = "Ignore teammates", Default = true, DependsOn = "AimEnabled" })
Main:AddSlider("AimFov", { Text = "Field of view", Min = 0, Max = 180, Default = 90, Suffix = "°", DependsOn = "AimEnabled" })
Main:AddDropdown("AimHitbox", {
    Text = "Hitbox",
    Values = { "Head", "Neck", "Chest", "Stomach", "Closest" },
    Default = "Head",
    DependsOn = "AimEnabled",
})

local Targeting = AimGeneral:AddSection({ Name = "Targeting", Icon = "target", Side = "Left" })
Targeting:AddDropdown("AimPriority", { Text = "Priority", Inline = true, Values = { "Crosshair", "Distance", "Health" }, Default = "Crosshair" })
Targeting:AddSlider("AimMaxDistance", { Text = "Max distance", Min = 0, Max = 1000, Default = 250, Suffix = " m" })
Targeting:AddToggle("AimPrediction", { Text = "Prediction", Default = true, Tooltip = "Leads moving targets" })
Targeting:AddSlider("AimPredictionScale", { Text = "Prediction scale", Min = 0, Max = 2, Default = 1, Increment = 0.05, Suffix = "x", DependsOn = "AimPrediction" })

local Smoothing = AimGeneral:AddSection({ Name = "Smoothing", Icon = "sliders", Side = "Right" })
Smoothing:AddSlider("AimSmoothness", { Text = "Smoothness", Min = 0, Max = 100, Default = 35, Suffix = "%" })
Smoothing:AddDropdown("AimCurve", { Text = "Curve", Values = { "Linear", "Ease in", "Ease out", "Ease in-out" }, Default = "Ease out" })
Smoothing:AddSlider("AimHitChance", { Text = "Hit chance", Min = 0, Max = 100, Default = { 40, 85 }, Suffix = "%" })

local FovSection = AimGeneral:AddSection({ Name = "Field of view", Icon = "scan", Side = "Right" })
FovSection:AddToggle("DrawFov", { Text = "Draw circle", Default = true })
    :AddColorPicker("DrawFovColor", { Default = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Title = "Circle color" })
FovSection:AddToggle("DynamicFov", { Text = "Dynamic size", Default = false, DependsOn = "DrawFov" })

-- Weapons
local WeaponGroup = AimWeapons:AddSection({ Name = "Weapon group", Icon = "sword", Side = "Left" })
WeaponGroup:AddDropdown("WeaponGroup", { Text = "Group", Values = { "Rifles", "SMGs", "Pistols", "Snipers", "Shotguns" }, Default = "Rifles" })
WeaponGroup:AddToggle("WeaponOverride", { Text = "Override general", Default = false })
WeaponGroup:AddSlider("WeaponFov", { Text = "Field of view", Min = 0, Max = 180, Default = 60, Suffix = "°" })
WeaponGroup:AddSlider("WeaponSmoothness", { Text = "Smoothness", Min = 0, Max = 100, Default = 40, Suffix = "%" })
WeaponGroup:AddDropdown("WeaponHitbox", { Text = "Hitbox", Inline = true, Values = { "Head", "Neck", "Chest", "Closest" }, Default = "Head" })

local Accuracy = AimWeapons:AddSection({ Name = "Accuracy", Icon = "target", Side = "Right" })
Accuracy:AddDropdown("WeaponHitboxes", {
    Text = "Hitboxes",
    Multi = true,
    Values = { "Head", "Neck", "Chest", "Stomach", "Arms", "Legs" },
    Default = { "Head", "Chest" },
})
Accuracy:AddSlider("MinDamage", { Text = "Minimum damage", Min = 0, Max = 100, Default = 25, Suffix = " hp" })
Accuracy:AddSlider("FirstShotDelay", { Text = "First shot delay", Min = 0, Max = 500, Default = 0, Suffix = " ms" })
Accuracy:AddToggle("AutoScope", { Text = "Auto scope", Default = false })
Accuracy:AddToggle("AutoStop", { Text = "Auto stop", Default = false })

-- Other
local Triggerbot = AimOther:AddSection({ Name = "Triggerbot", Icon = "zap", Side = "Left" })
Triggerbot:AddToggle("TriggerEnabled", { Text = "Enabled", Default = false })
    :AddKeybind("TriggerKey", { Text = "Triggerbot", Default = "LeftAlt", Mode = "Hold" })
Triggerbot:AddToggle("TriggerScoped", { Text = "Only when scoped", Default = true, DependsOn = "TriggerEnabled" })
Triggerbot:AddToggle("TriggerBurst", { Text = "Burst fire", Default = false, DependsOn = "TriggerEnabled" })
Triggerbot:AddSlider("TriggerDelay", { Text = "Reaction delay", Min = 0, Max = 300, Default = { 30, 90 }, Suffix = " ms", DependsOn = "TriggerEnabled" })
Triggerbot:AddSlider("TriggerHitChance", { Text = "Hit chance", Min = 0, Max = 100, Default = 70, Suffix = "%", DependsOn = "TriggerEnabled" })

local Recoil = AimOther:AddSection({ Name = "Recoil", Icon = "move", Side = "Right" })
Recoil:AddToggle("RecoilControl", { Text = "Recoil control", Default = true })
Recoil:AddSlider("RecoilHorizontal", { Text = "Horizontal", Min = 0, Max = 100, Default = 70, Suffix = "%", DependsOn = "RecoilControl" })
Recoil:AddSlider("RecoilVertical", { Text = "Vertical", Min = 0, Max = 100, Default = 55, Suffix = "%", DependsOn = "RecoilControl" })

local Backtrack = AimOther:AddSection({ Name = "Backtrack", Icon = "history", Side = "Right" })
Backtrack:AddToggle("BacktrackEnabled", { Text = "Enabled", Default = false })
Backtrack:AddSlider("BacktrackTime", { Text = "Time", Min = 0, Max = 200, Default = 120, Suffix = " ms", DependsOn = "BacktrackEnabled" })

--------------------------------------------------------------------------------
-- Visuals
--------------------------------------------------------------------------------
local Visuals = Window:AddTab({ Name = "Visuals", Icon = "eye" })
local VisPlayers = Visuals:AddSubTab({ Name = "Players", Icon = "users" })
local VisChams = Visuals:AddSubTab({ Name = "Chams", Icon = "sparkles" })
local VisOther = Visuals:AddSubTab({ Name = "Other", Icon = "dots" })

-- Players
local EspMain = VisPlayers:AddSection({ Name = "Main", Icon = "eye", Side = "Left" })
EspMain:AddToggle("EspEnabled", { Text = "Enabled", Default = true })
EspMain:AddToggle("EspBox", { Text = "Bounding box", Default = true, DependsOn = "EspEnabled" })
    :AddColorPicker("EspBoxColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Box color" })
EspMain:AddDropdown("EspBoxStyle", { Text = "Box style", Inline = true, Values = { "Corners", "Full" }, Default = "Corners", DependsOn = "EspEnabled" })

local EspInfo = VisPlayers:AddSection({ Name = "Information", Icon = "layers", Side = "Left" })
EspInfo:AddToggle("EspName", { Text = "Name", Default = true, DependsOn = "EspEnabled" })
    :AddColorPicker("EspNameColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Name color" })
EspInfo:AddToggle("EspHealth", { Text = "Health", Default = true, DependsOn = "EspEnabled" })
EspInfo:AddToggle("EspArmor", { Text = "Armor", Default = true, DependsOn = "EspEnabled" })
EspInfo:AddToggle("EspWeapon", { Text = "Weapon", Default = true, DependsOn = "EspEnabled" })
EspInfo:AddToggle("EspAmmo", { Text = "Ammo", Default = false, DependsOn = "EspEnabled" })
EspInfo:AddToggle("EspDistance", { Text = "Distance", Default = true, DependsOn = "EspEnabled" })

local EspFlags = VisPlayers:AddSection({ Name = "Flags", Icon = "list", Side = "Left" })
EspFlags:AddToggle("EspFlags", { Text = "Show flags", Default = true, DependsOn = "EspEnabled" })
EspFlags:AddDropdown("EspFlagList", {
    Text = "Flags",
    Multi = true,
    Values = { "Scoped", "Reloading", "Flashed", "Defusing", "Has bomb" },
    Default = { "Scoped", "Reloading" },
    DependsOn = "EspFlags",
})

local PreviewSection = VisPlayers:AddSection({ Name = "ESP preview", Icon = "person", Side = "Right" })
local Preview = PreviewSection:AddESPPreview({
    -- shows your own avatar and display name; pass Avatar = <userId> for someone else
    Weapon = "AK-47",
    Distance = "24 m",
    Health = 0.82,
    Armor = 0.62,
    Flags = {
        { Text = "SCOPED" },
        { Text = "RELOAD", Color = Color3.fromRGB(240, 196, 64) },
    },
})
Preview:Bind("Enabled", Options.EspEnabled)
Preview:Bind("Box", Options.EspBox)
Preview:Bind("BoxStyle", Options.EspBoxStyle)
Preview:Bind("Name", Options.EspName)
Preview:Bind("Health", Options.EspHealth)
Preview:Bind("Armor", Options.EspArmor)
Preview:Bind("Weapon", Options.EspWeapon)
Preview:Bind("Distance", Options.EspDistance)
Preview:Bind("Flags", Options.EspFlags)

-- Chams
local ChamsPlayers = VisChams:AddSection({ Name = "Players", Icon = "users", Side = "Left" })
ChamsPlayers:AddToggle("ChamsEnabled", { Text = "Enabled", Default = false })
ChamsPlayers:AddDropdown("ChamsMaterial", { Text = "Material", Values = { "Regular", "Flat", "Glow", "Metallic", "Wireframe" }, Default = "Regular" })
ChamsPlayers:AddColorPicker("ChamsVisible", { Text = "Visible", Default = Color3.fromRGB(140, 140, 140), Transparency = 0 })
ChamsPlayers:AddColorPicker("ChamsOccluded", { Text = "Occluded", Default = Color3.fromRGB(176, 106, 116), Transparency = 0 })

local Glow = VisChams:AddSection({ Name = "Glow", Icon = "sun", Side = "Left" })
Glow:AddToggle("GlowEnabled", { Text = "Enabled", Default = false })
    :AddColorPicker("GlowColor", { Default = Color3.fromRGB(255, 255, 255), Transparency = 0.6, Title = "Glow color" })
Glow:AddSlider("GlowAmount", { Text = "Amount", Min = 0, Max = 1, Default = 0.6, Increment = 0.01 })

local ChamsLocal = VisChams:AddSection({ Name = "Local", Icon = "user", Side = "Right" })
ChamsLocal:AddToggle("ChamsHands", { Text = "Hands", Default = false })
    :AddColorPicker("ChamsHandsColor", { Default = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Title = "Hands color" })
ChamsLocal:AddToggle("ChamsWeapon", { Text = "Weapon", Default = false })
    :AddColorPicker("ChamsWeaponColor", { Default = Color3.fromRGB(220, 220, 220), Transparency = 0.3, Title = "Weapon color" })
ChamsLocal:AddDropdown("ChamsLocalMaterial", { Text = "Material", Inline = true, Values = { "Flat", "Regular", "Glow", "Metallic" }, Default = "Flat" })

-- Other
local Crosshair = VisOther:AddSection({ Name = "Crosshair", Icon = "crosshair", Side = "Left" })
Crosshair:AddToggle("RecoilCrosshair", { Text = "Recoil crosshair", Default = true })
Crosshair:AddToggle("SniperCrosshair", { Text = "Sniper crosshair", Default = true })
Crosshair:AddToggle("SpreadCircle", { Text = "Spread circle", Default = false })

local Indicators = VisOther:AddSection({ Name = "Indicators", Icon = "radar", Side = "Left" })
Indicators:AddToggle("OffscreenArrows", { Text = "Out of view arrows", Default = true })
    :AddColorPicker("OffscreenArrowsColor", { Default = Color3.fromRGB(235, 235, 235), Title = "Arrow color" })
Indicators:AddSlider("ArrowSize", { Text = "Size", Min = 4, Max = 40, Default = 14, Suffix = " px", DependsOn = "OffscreenArrows" })
Indicators:AddSlider("ArrowDistance", { Text = "Distance", Min = 0, Max = 100, Default = 60, Suffix = "%", DependsOn = "OffscreenArrows" })

local Camera = VisOther:AddSection({ Name = "Camera", Icon = "monitor", Side = "Right" })
Camera:AddToggle("ThirdPerson", { Text = "Third person", Default = false })
    :AddKeybind("ThirdPersonKey", { Text = "Third person", Default = "V", Mode = "Toggle" })
Camera:AddSlider("CameraDistance", { Text = "Camera distance", Min = 50, Max = 300, Default = 120, DependsOn = "ThirdPerson" })
Camera:AddSlider("CameraFov", { Text = "Field of view", Min = 60, Max = 120, Default = 90, Suffix = "°" })
Camera:AddSlider("ViewmodelFov", { Text = "Viewmodel FOV", Min = 40, Max = 120, Default = 68, Suffix = "°" })

--------------------------------------------------------------------------------
-- World
--------------------------------------------------------------------------------
local World = Window:AddTab({ Name = "World", Icon = "globe" })

local Lighting = World:AddSection({ Name = "Lighting", Icon = "sun", Side = "Left" })
Lighting:AddSlider("NightMode", { Text = "Night mode", Min = 0, Max = 100, Default = 0, Suffix = "%" })
Lighting:AddSlider("Brightness", { Text = "Brightness", Min = 0, Max = 100, Default = 50, Suffix = "%" })
Lighting:AddToggle("Fullbright", { Text = "Fullbright", Default = false })
Lighting:AddToggle("CustomSky", { Text = "Custom sky", Default = false })
    :AddColorPicker("CustomSkyColor", { Default = Color3.fromRGB(112, 92, 176), Title = "Sky color" })

local Removals = World:AddSection({ Name = "Removals", Icon = "eye-off", Side = "Left" })
Removals:AddToggle("NoFog", { Text = "Fog", Default = true })
Removals:AddToggle("NoFlash", { Text = "Flashbang", Default = true })
Removals:AddToggle("NoSmoke", { Text = "Smoke", Default = false })
Removals:AddToggle("NoScope", { Text = "Scope overlay", Default = false })

local Weather = World:AddSection({ Name = "Weather", Icon = "snowflake", Side = "Right" })
Weather:AddToggle("WeatherEnabled", { Text = "Enabled", Default = false })
Weather:AddDropdown("WeatherType", { Text = "Type", Inline = true, Values = { "Rain", "Snow", "Fog", "Ash" }, Default = "Rain", DependsOn = "WeatherEnabled" })

local Items = World:AddSection({ Name = "Items", Icon = "box", Side = "Right" })
Items:AddToggle("ItemEsp", { Text = "Item ESP", Default = true })
Items:AddDropdown("ItemEspShow", {
    Text = "Show",
    Multi = true,
    Values = { "Weapons", "Grenades", "Armor", "Utility", "Bomb" },
    Default = { "Weapons", "Grenades" },
    DependsOn = "ItemEsp",
})
Items:AddSlider("ItemEspDistance", { Text = "Max distance", Min = 0, Max = 200, Default = 60, Suffix = " m", DependsOn = "ItemEsp" })

local Effects = World:AddSection({ Name = "Effects", Icon = "sparkle", Side = "Right" })
Effects:AddToggle("BulletTracers", { Text = "Bullet tracers", Default = true })
    :AddColorPicker("BulletTracersColor", { Default = Color3.fromRGB(230, 230, 230), Title = "Tracer color" })
Effects:AddToggle("BulletImpacts", { Text = "Bullet impacts", Default = false })
    :AddColorPicker("BulletImpactsColor", { Default = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Title = "Impact color" })
Effects:AddSlider("TracerLifetime", { Text = "Tracer lifetime", Min = 0.1, Max = 5, Default = 1.5, Increment = 0.1, Suffix = "s", DependsOn = "BulletTracers" })

--------------------------------------------------------------------------------
-- Miscellaneous
--------------------------------------------------------------------------------
local Misc = Window:AddTab({ Name = "Miscellaneous", Icon = "dots" })

local Movement = Misc:AddSection({ Name = "Movement", Icon = "footprints", Side = "Left" })
Movement:AddToggle("BunnyHop", { Text = "Bunny hop", Default = true })
    :AddKeybind("BunnyHopKey", { Text = "Bunny hop", Default = "Space", Mode = "Hold" })
Movement:AddToggle("AutoStrafe", { Text = "Auto strafe", Default = false })
Movement:AddDropdown("StrafeMode", { Text = "Strafe mode", Inline = true, Values = { "Legit", "Rage", "Directional" }, Default = "Legit", DependsOn = "AutoStrafe" })
Movement:AddToggle("EdgeJump", { Text = "Edge jump", Default = false })
    :AddKeybind("EdgeJumpKey", { Text = "Edge jump", Default = "C", Mode = "Hold" })

local Feedback = Misc:AddSection({ Name = "Feedback", Icon = "bell", Side = "Left" })
Feedback:AddToggle("HitSound", { Text = "Hit sound", Default = true })
Feedback:AddDropdown("HitSoundType", { Text = "Sound", Inline = true, Values = { "Click", "Bell", "Pop", "Bubble", "Skeet" }, Default = "Click", DependsOn = "HitSound" })
Feedback:AddSlider("HitSoundVolume", { Text = "Volume", Min = 0, Max = 100, Default = 60, Suffix = "%", DependsOn = "HitSound" })
Feedback:AddToggle("HitMarker", { Text = "Hit marker", Default = true })

local InfoSection = Misc:AddSection({ Name = "Information", Icon = "info", Side = "Right" })
InfoSection:AddToggle("SpectatorList", { Text = "Spectator list", Default = true })
InfoSection:AddToggle("BombTimer", { Text = "Bomb timer", Default = true })
InfoSection:AddToggle("MiscKeybindList", { Text = "Keybind list", Default = false, IgnorePanic = true })
InfoSection:AddToggle("MiscWatermark", { Text = "Watermark", Default = false, IgnorePanic = true })

local Panic = Misc:AddSection({ Name = "Panic", Icon = "power", Side = "Right", PaddingBottom = 2 })
Panic:AddLabel({ Text = "Panic key" }):AddKeybind("PanicKey", { Text = "Panic key", Default = "End", IsPanicKey = true })
Panic:AddParagraph({ Content = "Closes the menu and turns every feature off." })

--------------------------------------------------------------------------------
-- Configs & Settings (ready-made pages from the library)
--------------------------------------------------------------------------------
Window:AddConfigsTab()
Window:AddSettingsTab({ Watermark = false, KeybindList = false })

-- The Misc "Keybind list" / "Watermark" toggles mirror the Settings ones.
local function Mirror(a, b)
    Options[a]:OnChanged(function(v)
        Options[b]:Set(v)
    end)
    Options[b]:OnChanged(function(v)
        Options[a]:Set(v)
    end)
end
Mirror("MiscKeybindList", "Raven_KeybindList")
Mirror("MiscWatermark", "Raven_Watermark")

--------------------------------------------------------------------------------
-- Showcase hooks: a few live callbacks so you can see the API in action
--------------------------------------------------------------------------------
Options.AimKey:OnChanged(function(key, mode)
    Library:Notify({ Title = "Aimbot key", Content = Library.KeyName(key) .. " (" .. mode .. ")", Duration = 2, Icon = "keyboard" })
end)

Options.AimEnabled:OnChanged(function(state)
    Library:Notify({
        Title = state and "Aimbot enabled" or "Aimbot disabled",
        Content = state and "Hold your aim key to lock on" or "Targeting is paused",
        Type = state and "Success" or "Warning",
        Duration = 2.5,
    })
end)

Options.WeaponGroup:OnChanged(function(group)
    -- each weapon group could store its own values; here we just show the API
    Options.WeaponFov:Set(group == "Snipers" and 25 or 60)
end)

Library:OnUnload(function()
    print("[Raven] unloaded")
end)

Library:SetWatermark({ Text = "default" })
Library:LoadAutoload()

Library:Notify({
    Title = "Raven.cc loaded",
    Content = "Press " .. Library.KeyName(Library.MenuKey) .. " to toggle the menu",
    Type = "Success",
    Duration = 5,
})

return Library
