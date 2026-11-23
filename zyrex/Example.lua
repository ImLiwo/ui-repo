--[[
    Zyrex UI - Example.lua
    Rebuilds the Zyrex reference (Combat > Legit) 1:1 and fills the other tabs
    so every control is on show:
        Combat    Legit / Silent / Aimbot / Trigger
        Visuals   Players / World           (ESP preview)
        Skins     (no sub tabs: full width page, searchable dropdown)
        Movement  Speed / Fly, keybinds in every mode
        Misc      notifications, watermark, keybind list, buttons, paragraphs
        Scripts   textbox + run
        Settings  (gear on the right) General / Configs

    Loading:
      Library.lua is read from your executor's workspace folder (LIBRARY_PATH below).
      Put the file at <executor>/workspace/Zyrex/Library.lua, or change the path.
]]

local LIBRARY_PATH = "Zyrex/Library.lua" -- relative to your executor's workspace folder

local function LoadLibrary()
    assert(type(readfile) == "function" and type(isfile) == "function", "Zyrex: your executor has no readfile/isfile, so it can't load a local Library.lua")
    assert(isfile(LIBRARY_PATH), "Zyrex: " .. LIBRARY_PATH .. " was not found in your executor's workspace folder")
    local source = readfile(LIBRARY_PATH)
    local chunk, err = loadstring(source, "=" .. LIBRARY_PATH)
    assert(chunk, "Zyrex: failed to compile " .. LIBRARY_PATH .. ": " .. tostring(err))
    return chunk()
end

local Library = LoadLibrary()
local Options = Library.Options
local Flags = Library.Flags

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Zyrex",
    Keybind = "Insert",
    ConfigFolder = "Zyrex",
    Size = Vector2.new(760, 554),
})

--------------------------------------------------------------------------------
-- Combat (the reference screenshot)
--------------------------------------------------------------------------------
local Combat = Window:AddTab({ Name = "Combat", Icon = "move" })
local Legit = Combat:AddSubTab({ Name = "Legit", Icon = "circle-check" })
local Silent = Combat:AddSubTab({ Name = "Silent", Icon = "mouse" })
local Aimbot = Combat:AddSubTab({ Name = "Aimbot", Icon = "mouse-pointer-2" })
local Trigger = Combat:AddSubTab({ Name = "Trigger", Icon = "clock" })

-- Legit: header switch + checkboxes
local LegitMain = Legit:AddSection({
    Name = "Legit",
    Side = "Left",
    Toggle = true,
    Flag = "LegitEnabled",
    Default = true,
})
LegitMain:AddToggle("PredictAim", { Text = "Predict aim", Default = true, Tooltip = "Leads moving targets" })
LegitMain:AddToggle("AutoGroup", { Text = "Auto group", Default = false })
LegitMain:AddToggle("VisibleCheck", { Text = "Visible check", Default = true })
LegitMain:AddToggle("FlashCheck", { Text = "Flash check", Default = false })
LegitMain:AddToggle("ScopeCheck", { Text = "Scope check", Default = false })
LegitMain:AddToggle("HumanizedSmooth", { Text = "Humanized smooth", Default = false })
LegitMain:AddToggle("HitChanceEnabled", { Text = "Hit chance", Default = false })

-- an untitled card holding the two sliders
local LegitTune = Legit:AddSection({ Side = "Left" })
LegitTune:AddSlider("HumanizedSmoothness", { Text = "Humanized Smoothness", Min = 0, Max = 100, Default = 30, Suffix = "%" })
LegitTune:AddSlider("HitChance", { Text = "Hit chance", Min = 0, Max = 100, Default = 70, Suffix = "%" })

-- Draw FOV: header switch, captioned dividers, colour swatches
local DrawFov = Legit:AddSection({
    Name = "Draw FOV",
    Side = "Right",
    Toggle = true,
    Flag = "DrawFov",
    Default = false,
})
DrawFov:AddDivider("Render")
DrawFov:AddToggle("DrawCircleOutlines", { Text = "Draw circle outlines", Default = false })
DrawFov:AddToggle("DrawCircleFilled", { Text = "Draw circle filled", Default = false })
DrawFov:AddToggle("DrawCenterTracer", { Text = "Draw center tracer", Default = false })
DrawFov:AddToggle("DrawRecoilCircle", { Text = "Draw recoil circle", Default = false })
DrawFov:AddDivider("Colors")
DrawFov:AddLabel("Circle outlines"):AddColorPicker("CircleOutlinesColor", { Default = Color3.fromRGB(0, 0, 255) })
DrawFov:AddLabel("Circle filled"):AddColorPicker("CircleFilledColor", { Default = Color3.fromRGB(96, 84, 232), Transparency = 0.25 })
DrawFov:AddLabel("Center tracer"):AddColorPicker("CenterTracerColor", { Default = Color3.fromRGB(0, 255, 0) })
DrawFov:AddLabel("Recoil circle"):AddColorPicker("RecoilCircleColor", { Default = Color3.fromRGB(242, 51, 51), Transparency = 0.1 })
DrawFov:AddDivider("Configs")
DrawFov:AddSlider("LineThickness", { Text = "Line thickness", Min = 0, Max = 5, Default = 1, Increment = 0.1, Suffix = "px" })

-- Silent
local SilentMain = Silent:AddSection({ Name = "Silent aim", Side = "Left", Toggle = true, Flag = "SilentEnabled", Default = false })
SilentMain:AddDropdown("SilentHitbox", { Text = "Hitbox", Values = { "Head", "Neck", "Torso", "Closest" }, Default = "Head" })
SilentMain:AddDropdown("SilentMethod", { Text = "Method", Values = { "Raycast", "FindPartOnRay", "Mouse.Hit", "Namecall" }, Default = "Raycast" })
SilentMain:AddToggle("SilentWallCheck", { Text = "Wall check", Default = true, DependsOn = "SilentEnabled" })
SilentMain:AddToggle("SilentTeamCheck", { Text = "Team check", Default = true, DependsOn = "SilentEnabled" })

local SilentTune = Silent:AddSection({ Side = "Right" })
SilentTune:AddSlider("SilentFov", { Text = "Field of view", Min = 10, Max = 500, Default = 120, Suffix = "px" })
SilentTune:AddSlider("SilentHitChance", { Text = "Hit chance", Min = 0, Max = 100, Default = 85, Suffix = "%" })
SilentTune:AddSlider("SilentPrediction", { Text = "Prediction", Min = 0, Max = 1, Default = 0.13, Increment = 0.01 })

-- Aimbot
local AimMain = Aimbot:AddSection({ Name = "Aimbot", Side = "Left", Toggle = true, Flag = "AimEnabled", Default = true })
AimMain:AddLabel("Aim key"):AddKeybind("AimKey", {
    Text = "Aimbot",
    Default = "MB2", -- Roblox cannot read mouse buttons 4/5
    Mode = "Hold",
})
AimMain:AddDropdown("AimPart", { Text = "Target part", Values = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" }, Default = "Head" })
AimMain:AddDropdown("AimPriority", { Text = "Priority", Inline = true, Values = { "Crosshair", "Distance", "Health" }, Default = "Crosshair" })
AimMain:AddToggle("AimSticky", { Text = "Sticky target", Default = false, DependsOn = "AimEnabled" })

local AimTune = Aimbot:AddSection({ Name = "Smoothing", Side = "Right" })
AimTune:AddSlider("AimSmoothness", { Text = "Smoothness", Min = 1, Max = 20, Default = 6, Increment = 0.5, Suffix = "x" })
AimTune:AddSlider("AimFov", { Text = "Field of view", Min = 10, Max = 500, Default = 150, Suffix = "px" })
AimTune:AddSlider("AimDistance", { Text = "Max distance", Min = 50, Max = 2000, Default = 800, Suffix = " studs" })
AimTune:AddSlider("AimReaction", { Text = "Reaction time", Min = 0, Max = 500, Default = { 40, 120 }, Suffix = "ms" })

-- Trigger
local TriggerMain = Trigger:AddSection({ Name = "Triggerbot", Side = "Left" })
TriggerMain:AddToggle("TriggerEnabled", { Text = "Enabled", Default = false })
    :AddKeybind("TriggerKey", { Text = "Triggerbot", Default = "MB3", Mode = "Hold" })
TriggerMain:AddToggle("TriggerHead", { Text = "Head only", Default = false, DependsOn = "TriggerEnabled" })
TriggerMain:AddDropdown("TriggerHitboxes", {
    Text = "Hitboxes",
    Multi = true,
    Values = { "Head", "Torso", "Arms", "Legs" },
    Default = { "Head", "Torso" },
    DependsOn = "TriggerEnabled",
})
local TriggerTune = Trigger:AddSection({ Side = "Right" })
TriggerTune:AddSlider("TriggerDelay", { Text = "Delay", Min = 0, Max = 300, Default = 45, Suffix = "ms", DependsOn = "TriggerEnabled" })
TriggerTune:AddSlider("TriggerHold", { Text = "Hold time", Min = 0, Max = 500, Default = 80, Suffix = "ms", DependsOn = "TriggerEnabled" })

--------------------------------------------------------------------------------
-- Visuals
--------------------------------------------------------------------------------
local Visuals = Window:AddTab({ Name = "Visuals", Icon = "eye" })
local VisPlayers = Visuals:AddSubTab({ Name = "Players", Icon = "users" })
local VisWorld = Visuals:AddSubTab({ Name = "World", Icon = "globe" })

local Esp = VisPlayers:AddSection({ Name = "ESP", Side = "Left", Toggle = true, Flag = "EspEnabled", Default = true })
Esp:AddDivider("Elements")
Esp:AddToggle("EspBox", { Text = "Box", Default = true, DependsOn = "EspEnabled" })
    :AddColorPicker("EspBoxColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Box color" })
Esp:AddToggle("EspName", { Text = "Name", Default = true, DependsOn = "EspEnabled" })
    :AddColorPicker("EspNameColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Name color" })
Esp:AddToggle("EspHealth", { Text = "Health bar", Default = true, DependsOn = "EspEnabled" })
Esp:AddToggle("EspArmor", { Text = "Armor bar", Default = false, DependsOn = "EspEnabled" })
Esp:AddToggle("EspWeapon", { Text = "Weapon", Default = true, DependsOn = "EspEnabled" })
Esp:AddToggle("EspDistance", { Text = "Distance", Default = true, DependsOn = "EspEnabled" })
Esp:AddToggle("EspFlags", { Text = "Flags", Default = false, DependsOn = "EspEnabled" })
Esp:AddDivider("Style")
Esp:AddDropdown("EspBoxStyle", { Text = "Box style", Inline = true, Values = { "Corners", "Full" }, Default = "Corners" })
Esp:AddSlider("EspTextSize", { Text = "Text size", Min = 8, Max = 20, Default = 13, Suffix = "px" })

local PreviewSection = VisPlayers:AddSection({ Name = "Preview", Side = "Right" })
local Preview = PreviewSection:AddESPPreview({ Weapon = "AK-47", Distance = "24 studs" })
Preview:Bind("Enabled", Options.EspEnabled)
Preview:Bind("Box", Options.EspBox)
Preview:Bind("BoxStyle", Options.EspBoxStyle)
Preview:Bind("Name", Options.EspName)
Preview:Bind("Health", Options.EspHealth)
Preview:Bind("Armor", Options.EspArmor)
Preview:Bind("Weapon", Options.EspWeapon)
Preview:Bind("Distance", Options.EspDistance)
Preview:Bind("Flags", Options.EspFlags)
Preview:BindColor("Box", Options.EspBoxColor)
Preview:BindColor("Name", Options.EspNameColor)

local Lighting = VisWorld:AddSection({ Name = "Lighting", Side = "Left" })
Lighting:AddToggle("Fullbright", { Text = "Fullbright", Default = false })
Lighting:AddToggle("NoFog", { Text = "Remove fog", Default = true })
Lighting:AddSlider("ClockTime", { Text = "Time of day", Min = 0, Max = 24, Default = 14, Increment = 0.5, Suffix = "h" })
Lighting:AddLabel("Ambient"):AddColorPicker("AmbientColor", { Default = Color3.fromRGB(120, 130, 160) })

local Camera = VisWorld:AddSection({ Name = "Camera", Side = "Right" })
Camera:AddToggle("ThirdPerson", { Text = "Third person", Default = false })
    :AddKeybind("ThirdPersonKey", { Text = "Third person", Default = "V", Mode = "Toggle" })
Camera:AddSlider("CameraFov", { Text = "Field of view", Min = 70, Max = 120, Default = 90, Suffix = "°" })
Camera:AddSlider("CameraDistance", { Text = "Distance", Min = 5, Max = 40, Default = 12, Suffix = " studs", DependsOn = "ThirdPerson" })

--------------------------------------------------------------------------------
-- Skins (no sub tabs: the page spans the whole body)
--------------------------------------------------------------------------------
local Skins = Window:AddTab({ Name = "Skins", Icon = "palette" })
local Knives = {
    "Default", "Bayonet", "Butterfly", "Karambit", "M9 Bayonet", "Huntsman", "Falchion", "Bowie",
    "Shadow Daggers", "Gut", "Flip", "Navaja", "Stiletto", "Talon", "Ursus", "Classic", "Skeleton",
}
local KnifeSection = Skins:AddSection({ Name = "Knife", Side = "Left" })
KnifeSection:AddDropdown("KnifeModel", { Text = "Model", Values = Knives, Default = "Karambit", Tooltip = "Long lists get a search bar" })
KnifeSection:AddDropdown("KnifeFinish", { Text = "Finish", Values = { "Fade", "Doppler", "Tiger Tooth", "Marble Fade", "Slaughter" }, Default = "Fade" })
KnifeSection:AddSlider("KnifeWear", { Text = "Wear", Min = 0, Max = 1, Default = 0.01, Increment = 0.01 })
KnifeSection:AddTextbox("KnifeNameTag", { Text = "Name tag", Placeholder = "Leave empty for none", Default = "" })

local GloveSection = Skins:AddSection({ Name = "Gloves", Side = "Right", Toggle = true, Flag = "GlovesEnabled", Default = false })
GloveSection:AddDropdown("GloveModel", { Text = "Model", Values = { "Sport", "Driver", "Hand Wraps", "Moto", "Specialist" }, Default = "Sport" })
GloveSection:AddLabel("Tint"):AddColorPicker("GloveTint", { Default = Color3.fromRGB(87, 190, 234), Transparency = 0 })
GloveSection:AddButton({
    Text = "Apply skins",
    Style = "Primary",
    Callback = function()
        Library:Notify({ Title = "Skins", Content = Flags.KnifeModel .. " | " .. Flags.KnifeFinish .. " applied", Type = "Success", Duration = 3 })
    end,
})

--------------------------------------------------------------------------------
-- Movement
--------------------------------------------------------------------------------
local Movement = Window:AddTab({ Name = "Movement", Icon = "footprints" })
local MoveSpeed = Movement:AddSubTab({ Name = "Speed", Icon = "zap" })
local MoveFly = Movement:AddSubTab({ Name = "Fly", Icon = "wind" })

local Speed = MoveSpeed:AddSection({ Name = "Walk speed", Side = "Left", Toggle = true, Flag = "SpeedEnabled", Default = false })
Speed:AddSlider("WalkSpeed", { Text = "Speed", Min = 16, Max = 200, Default = 32, Suffix = " studs" })
Speed:AddDropdown("SpeedMethod", { Text = "Method", Inline = true, Values = { "Humanoid", "CFrame", "Velocity" }, Default = "CFrame" })
local Jump = MoveSpeed:AddSection({ Name = "Jumping", Side = "Right" })
Jump:AddToggle("BunnyHop", { Text = "Bunny hop", Default = false })
    :AddKeybind("BunnyHopKey", { Text = "Bunny hop", Default = "Space", Mode = "Hold" })
Jump:AddToggle("InfiniteJump", { Text = "Infinite jump", Default = false })
Jump:AddSlider("JumpPower", { Text = "Jump power", Min = 50, Max = 300, Default = 50 })

local Fly = MoveFly:AddSection({ Name = "Fly", Side = "Left" })
Fly:AddToggle("FlyEnabled", { Text = "Enabled", Default = false })
    :AddKeybind("FlyKey", { Text = "Fly", Default = "F", Mode = "Toggle" })
Fly:AddSlider("FlySpeed", { Text = "Fly speed", Min = 10, Max = 300, Default = 80, Suffix = " studs", DependsOn = "FlyEnabled" })
Fly:AddToggle("Noclip", { Text = "Noclip", Default = false })
    :AddKeybind("NoclipKey", { Text = "Noclip", Default = "N", Mode = "Toggle" })
local FlyInfo = MoveFly:AddSection({ Name = "Info", Side = "Right" })
FlyInfo:AddParagraph({ Title = "Keybind modes", Content = "Right click a key chip to switch between Toggle, Hold and Always. Backspace or Escape clears a bind." })

--------------------------------------------------------------------------------
-- Misc
--------------------------------------------------------------------------------
local Misc = Window:AddTab({ Name = "Misc", Icon = "sliders-vertical" })

local Hud = Misc:AddSection({ Name = "Interface", Side = "Left" })
Hud:AddToggle("MiscWatermark", { Text = "Watermark", Default = true, IgnorePanic = true })
Hud:AddToggle("MiscKeybindList", { Text = "Keybind list", Default = true, IgnorePanic = true })
Hud:AddDropdown("NotifySide", {
    Text = "Notifications",
    Inline = true,
    Values = { "BottomRight", "TopRight" },
    Default = "BottomRight",
    Callback = function(side)
        Library:SetNotifyPosition(side)
    end,
})
Hud:AddLabel("Panic key"):AddKeybind("PanicKey", { Text = "Panic", Default = "End", IsPanicKey = true })

local Toasts = Misc:AddSection({ Name = "Notifications", Side = "Right" })
local status = Toasts:AddParagraph({ Title = "Status", Content = "Press a button to send a toast." })
local sent = 0
local function toast(kind)
    return function()
        sent = sent + 1
        Library:Notify({ Title = kind, Content = "This is a " .. string.lower(kind) .. " notification.", Type = kind, Duration = 4 })
        status:SetText(sent .. " notification(s) sent, last: " .. kind)
    end
end
Toasts:AddButton({ Text = "Success", Callback = toast("Success") }):AddButton({ Text = "Info", Callback = toast("Info") })
Toasts:AddButton({ Text = "Warning", Callback = toast("Warning") }):AddButton({ Text = "Error", Callback = toast("Error") })
Toasts:AddDivider()
Toasts:AddButton({
    Text = "Rejoin server",
    Style = "Danger",
    DoubleClick = true,
    ConfirmText = "Click again to rejoin",
    Tooltip = "Needs a double click",
    Callback = function()
        Library:Notify({ Title = "Rejoin", Content = "Teleporting... (demo)", Duration = 3 })
    end,
})

--------------------------------------------------------------------------------
-- Scripts
--------------------------------------------------------------------------------
local Scripts = Window:AddTab({ Name = "Scripts", Icon = "code-xml" })
local Runner = Scripts:AddSection({ Name = "Execute", Side = "Left" })
local source = Runner:AddTextbox("ScriptSource", {
    Text = "Source",
    Placeholder = "print(\"hello from Zyrex\")",
    ClearTextOnFocus = false,
    NoSave = true,
})
local output = Runner:AddParagraph({ Title = "Output", Content = "Nothing run yet." })
Runner:AddButton({
    Text = "Run",
    Style = "Primary",
    Callback = function()
        local code = source:Get()
        if code == "" then
            output:SetText("Type some Lua first.")
            return
        end
        local fn, err = loadstring(code)
        if not fn then
            output:SetText("Syntax error: " .. tostring(err))
            return
        end
        local ok, res = pcall(fn)
        output:SetText(ok and ("Ran OK" .. (res ~= nil and (": " .. tostring(res)) or "")) or ("Error: " .. tostring(res)))
    end,
}):AddButton({
    Text = "Clear",
    Callback = function()
        source:Set("")
        output:SetText("Nothing run yet.")
    end,
})
local Saved = Scripts:AddSection({ Name = "Quick scripts", Side = "Right" })
Saved:AddDropdown("QuickScript", { Text = "Script", Values = { "Infinite Yield", "Dex Explorer", "Remote Spy" }, Default = "Infinite Yield", NoSave = true })
Saved:AddParagraph({ Content = "Examples only. Wire the button up to whatever you load." })

--------------------------------------------------------------------------------
-- Settings (gear on the right of the tab bar, with a Configs sub tab)
--------------------------------------------------------------------------------
Window:AddSettingsTab({ Watermark = true, KeybindList = true })

-- the Misc toggles mirror the Settings ones
local function Mirror(a, b)
    Options[a]:OnChanged(function(v)
        Options[b]:Set(v)
    end)
    Options[b]:OnChanged(function(v)
        Options[a]:Set(v)
    end)
end
Mirror("MiscKeybindList", "Zyrex_KeybindList")
Mirror("MiscWatermark", "Zyrex_Watermark")

--------------------------------------------------------------------------------
-- Live callbacks so you can see the API in action
--------------------------------------------------------------------------------
Options.LegitEnabled:OnChanged(function(state)
    Library:Notify({
        Title = state and "Legit enabled" or "Legit disabled",
        Content = state and "Assist is active" or "Assist is paused",
        Type = state and "Success" or "Warning",
        Duration = 2.5,
    })
end)

Options.AimKey:OnChanged(function(key, mode)
    Library:Notify({ Title = "Aimbot key", Content = Library.KeyName(key) .. " (" .. mode .. ")", Duration = 2, Icon = "keyboard" })
end)

Library:OnUnload(function()
    print("[Zyrex] unloaded")
end)

Library:SetWatermark({ Text = "default" })
Library:LoadAutoload()

Library:Notify({
    Title = "Zyrex loaded",
    Content = "Press " .. Library.KeyName(Library.MenuKey) .. " to toggle the menu",
    Type = "Success",
    Duration = 5,
})

return Library
