--[[
    Raven UI Library
    A 1:1 Luau recreation of the "Raven.cc" interface for Roblox executors.

    Quick start
        local Library = loadstring(game:HttpGet(URL))()
        local Window  = Library:CreateWindow({ Title = "Raven", Suffix = ".cc", Keybind = "Insert" })
        local Aimbot  = Window:AddTab({ Name = "Aimbot", Icon = "crosshair" })
        local General = Aimbot:AddSubTab({ Name = "General", Icon = "home" })
        local Main    = General:AddSection({ Name = "Main", Icon = "crosshair", Side = "Left" })
        Main:AddToggle("AimEnabled", { Text = "Enabled", Default = true })
            :AddKeybind("AimKey", { Default = "MB2", Mode = "Hold" })
        Main:AddSlider("AimFov", { Text = "Field of view", Min = 0, Max = 180, Default = 90, Suffix = "°" })
        Main:AddDropdown("AimHitbox", { Text = "Hitbox", Values = { "Head", "Chest" }, Default = "Head" })

    Every control returns a controller with :Get(), :Set(), :SetVisible() and :OnChanged().
    Values live in Library.Flags[Flag], controllers in Library.Options[Flag].
    Call Library:Unload() to disconnect everything and destroy every instance.
]]

local cloneref = cloneref or function(o)
    return o
end

local function Service(name)
    return cloneref(game:GetService(name))
end

local Players = Service("Players")
local UserInputService = Service("UserInputService")
local TweenService = Service("TweenService")
local RunService = Service("RunService")
local HttpService = Service("HttpService")
local TextService = Service("TextService")
local Stats = Service("Stats")

local LocalPlayer = Players.LocalPlayer
local unpack = table.unpack or unpack

local Library = {
    Version = "1.0.0",
    Flags = {},
    Options = {},
    Theme = {},
    Registry = setmetatable({}, { __mode = "k" }),
    Refreshers = {},
    Keybinds = {},
    Windows = {},
    Searchables = {},
    Unloaded = false,
    Animations = true,
    ShowNotifications = true,
    ConfigFolder = "Raven",
    ActiveConfig = nil,
    MenuKey = "Insert",
    ColorClipboard = nil,
    RainbowHue = 0,
    OnUnloadCallbacks = {},
    NotifySide = "BottomRight",
}
Library.__index = Library

--------------------------------------------------------------------------------
-- Theme tokens (measured from the Raven.cc reference)
--------------------------------------------------------------------------------
local DefaultTheme = {
    Accent = Color3.fromRGB(226, 226, 226),
    AccentText = Color3.fromRGB(22, 22, 22),
    Background = Color3.fromRGB(26, 26, 26),
    Sidebar = Color3.fromRGB(19, 19, 19),
    Card = Color3.fromRGB(30, 30, 30),
    CardStroke = Color3.fromRGB(44, 44, 44),
    Element = Color3.fromRGB(38, 38, 38),
    ElementHover = Color3.fromRGB(46, 46, 46),
    ElementStroke = Color3.fromRGB(50, 50, 50),
    Field = Color3.fromRGB(22, 22, 22),
    Checkbox = Color3.fromRGB(40, 40, 40),
    Track = Color3.fromRGB(50, 50, 50),
    Knob = Color3.fromRGB(112, 112, 112),
    Outline = Color3.fromRGB(255, 255, 255),
    Divider = Color3.fromRGB(40, 40, 40),
    Text = Color3.fromRGB(236, 236, 236),
    TextMuted = Color3.fromRGB(142, 142, 142),
    TextDim = Color3.fromRGB(112, 112, 112),
    TextFaint = Color3.fromRGB(78, 78, 78),
    Popup = Color3.fromRGB(24, 24, 24),
    Widget = Color3.fromRGB(21, 21, 21),
    Danger = Color3.fromRGB(240, 96, 96),
    Success = Color3.fromRGB(96, 214, 128),
    Warning = Color3.fromRGB(240, 196, 64),
    Info = Color3.fromRGB(96, 156, 240),
    Shadow = Color3.fromRGB(0, 0, 0),
    FontFamily = "rbxasset://fonts/families/GothamSSm.json",
}
for k, v in pairs(DefaultTheme) do
    Library.Theme[k] = v
end
Library.DefaultTheme = DefaultTheme

--------------------------------------------------------------------------------
-- Maid (lifecycle tracking)
--------------------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(item)
    if item ~= nil then
        table.insert(self._tasks, item)
    end
    return item
end

function Maid:Clean()
    local tasks = self._tasks
    self._tasks = {}
    for i = #tasks, 1, -1 do
        local t = tasks[i]
        local kind = typeof(t)
        if kind == "RBXScriptConnection" then
            pcall(function()
                t:Disconnect()
            end)
        elseif kind == "Instance" then
            pcall(function()
                if t:IsA("Tween") then
                    t:Cancel()
                end
                t:Destroy()
            end)
        elseif kind == "function" then
            pcall(t)
        elseif kind == "thread" then
            pcall(task.cancel, t)
        elseif type(t) == "table" then
            if t.Disconnect then
                pcall(t.Disconnect, t)
            elseif t.Destroy then
                pcall(t.Destroy, t)
            elseif t.Clean then
                pcall(t.Clean, t)
            end
        end
    end
end
Maid.Destroy = Maid.Clean

Library.Maid = Maid.new()
Library.MaidClass = Maid
Library.ActiveTweens = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------
local Weights = {
    Regular = Enum.FontWeight.Regular,
    Medium = Enum.FontWeight.Medium,
    SemiBold = Enum.FontWeight.SemiBold,
    Bold = Enum.FontWeight.Bold,
}

local function Font_(weight)
    local ok, f = pcall(Font.new, Library.Theme.FontFamily, Weights[weight or "Regular"] or Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    if ok and f then
        return f
    end
    return Font.fromEnum(Enum.Font.Gotham)
end

local function New(class, props, children)
    local inst = Instance.new(class)
    local parent
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then
                parent = v
            else
                inst[k] = v
            end
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function Corner(radius, parent)
    return New("UICorner", {
        CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 4),
        Parent = parent,
    })
end

local function Stroke(parent, color, transparency, thickness)
    return New("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Padding(parent, t, r, b, l)
    return New("UIPadding", {
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or t or 0),
        PaddingBottom = UDim.new(0, b or t or 0),
        PaddingLeft = UDim.new(0, l or r or t or 0),
        Parent = parent,
    })
end

local function List(parent, padding, direction, halign, valign)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = valign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

local function Clamp(x, a, b)
    if x < a then
        return a
    end
    if x > b then
        return b
    end
    return x
end

local function Find(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end
    return nil
end

local function ClearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function Decimals(increment)
    local s = tostring(increment or 1)
    if string.find(s, "e") then
        return math.max(0, math.floor(-math.log10(increment) + 0.5))
    end
    local dot = string.find(s, "%.")
    if dot then
        return #s - dot
    end
    return 0
end

local function Round(value, increment)
    increment = increment or 1
    if increment <= 0 then
        return value
    end
    local r = math.floor(value / increment + 0.5) * increment
    local decimals = Decimals(increment)
    if decimals > 0 then
        r = tonumber(string.format("%." .. decimals .. "f", r))
    end
    return r
end

local function MouseLocation()
    return UserInputService:GetMouseLocation()
end

local function IsInside(gui, point)
    if not gui or not gui.Parent then
        return false
    end
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y
end

local function ColorToHex(c)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function HexToColor(hex)
    if type(hex) ~= "string" then
        return nil
    end
    hex = string.gsub(string.gsub(hex, "#", ""), "%s", "")
    if #hex == 3 then
        hex = string.rep(string.sub(hex, 1, 1), 2) .. string.rep(string.sub(hex, 2, 2), 2) .. string.rep(string.sub(hex, 3, 3), 2)
    end
    if #hex ~= 6 or string.find(hex, "[^%x]") then
        return nil
    end
    return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end

local function Mix(c1, c2, t)
    return c1:Lerp(c2, t)
end

local function SameColor(a, b)
    if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then
        return false
    end
    return math.abs(a.R - b.R) < 0.003 and math.abs(a.G - b.G) < 0.003 and math.abs(a.B - b.B) < 0.003
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[Raven] callback error: " .. tostring(err))
    end
end

local function CopyList(t)
    local out = {}
    for i, v in ipairs(t or {}) do
        out[i] = v
    end
    return out
end

local function NS(points)
    local kps = {}
    for _, p in ipairs(points) do
        table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
    end
    return NumberSequence.new(kps)
end

local function CS(points)
    local kps = {}
    for _, p in ipairs(points) do
        table.insert(kps, ColorSequenceKeypoint.new(p[1], p[2]))
    end
    return ColorSequence.new(kps)
end

-- Sets ZIndex on a GuiObject and all GuiObject descendants (icons are built from many frames).
local function DeepZ(root, z)
    if root:IsA("GuiObject") then
        root.ZIndex = z
    end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("GuiObject") then
            d.ZIndex = z
        end
    end
end

Library.Utility = {
    New = New, Corner = Corner, Stroke = Stroke, Padding = Padding, List = List, Round = Round,
    ColorToHex = ColorToHex, HexToColor = HexToColor, Font = Font_, Clamp = Clamp, Find = Find,
}

--------------------------------------------------------------------------------
-- Theme registry: Library:Bind(inst, { Prop = "ThemeKey" }) keeps an instance in sync
--------------------------------------------------------------------------------
function Library:Bind(inst, props)
    local map = self.Registry[inst] or {}
    for prop, role in pairs(props) do
        map[prop] = role
        local value = self.Theme[role]
        if value ~= nil then
            inst[prop] = value
        end
    end
    self.Registry[inst] = map
    return inst
end

function Library:AddRefresher(fn)
    table.insert(self.Refreshers, fn)
    return fn
end

function Library:ApplyTheme()
    for inst, map in pairs(self.Registry) do
        if inst.Parent then
            for prop, role in pairs(map) do
                local value = self.Theme[role]
                if value ~= nil then
                    pcall(function()
                        inst[prop] = value
                    end)
                end
            end
        end
    end
    for _, fn in ipairs(self.Refreshers) do
        SafeCall(fn)
    end
end

function Library:SetTheme(partial)
    for k, v in pairs(partial or {}) do
        self.Theme[k] = v
    end
    self:ApplyTheme()
end

-- Picks a readable foreground for an accent colour automatically.
function Library:SetAccent(color)
    if typeof(color) ~= "Color3" then
        return
    end
    local luminance = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
    self:SetTheme({
        Accent = color,
        AccentText = luminance > 0.6 and Color3.fromRGB(22, 22, 22) or Color3.fromRGB(250, 250, 250),
    })
end

function Library:ResetTheme()
    self:SetTheme(DefaultTheme)
end

function Library:SetFont(family)
    self.Theme.FontFamily = family
    if self.ScreenGui then
        for _, d in ipairs(self.ScreenGui:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local weight = d.FontFace.Weight
                pcall(function()
                    d.FontFace = Font.new(family, weight, Enum.FontStyle.Normal)
                end)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Tweening
--------------------------------------------------------------------------------
function Library:Tween(inst, props, duration, style, direction)
    if not inst or self.Unloaded then
        return nil
    end
    duration = duration or 0.18
    if not self.Animations then
        duration = 0
    end
    if duration <= 0 then
        for k, v in pairs(props) do
            inst[k] = v
        end
        return nil
    end
    local tween = TweenService:Create(inst, TweenInfo.new(duration, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out), props)
    self.ActiveTweens[tween] = true
    local conn
    conn = tween.Completed:Connect(function()
        self.ActiveTweens[tween] = nil
        if conn then
            conn:Disconnect()
        end
    end)
    tween:Play()
    return tween
end

function Library:Connect(signal, fn)
    return self.Maid:Give(signal:Connect(fn))
end

--------------------------------------------------------------------------------
-- Icon kit: Lucide icons when they load, otherwise these frame-drawn fallbacks.
-- Icons.Register(name, function(d) ... end) adds your own; any "rbxassetid://" string works too.
--------------------------------------------------------------------------------
local Icons = {}
Library.Icons = Icons
local IconShapes = {}
Library.CustomIcons = {}

-- Every shape draws in a 16x16 design space.
IconShapes.shield = function(d)
    d.poly({ { 8, 1.3 }, { 13.6, 3.4 }, { 13.6, 7.6 } }, 1.4)
    d.poly({ { 8, 1.3 }, { 2.4, 3.4 }, { 2.4, 7.6 } }, 1.4)
    d.poly({ { 13.6, 7.6 }, { 12.6, 10.8 }, { 10.4, 13.2 }, { 8, 14.7 } }, 1.4)
    d.poly({ { 2.4, 7.6 }, { 3.4, 10.8 }, { 5.6, 13.2 }, { 8, 14.7 } }, 1.4)
end
IconShapes.crosshair = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.line(8, 1.4, 8, 4.4, 1.3)
    d.line(8, 11.6, 8, 14.6, 1.3)
    d.line(1.4, 8, 4.4, 8, 1.3)
    d.line(11.6, 8, 14.6, 8, 1.3)
end
IconShapes.eye = function(d)
    d.ellipse(8, 8, 14.2, 8.6, 1.3)
    d.ring(8, 8, 2.4, 1.3)
end
IconShapes["eye-off"] = function(d)
    d.ellipse(8, 8, 14.2, 8.6, 1.3)
    d.ring(8, 8, 2.4, 1.3)
    d.line(2, 2, 14, 14, 1.4)
end
IconShapes.globe = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.ellipse(8, 8, 6, 13.2, 1.2)
    d.line(1.6, 8, 14.4, 8, 1.2)
end
IconShapes.dots = function(d)
    d.dot(3.2, 8, 1.15)
    d.dot(8, 8, 1.15)
    d.dot(12.8, 8, 1.15)
end
IconShapes.folder = function(d)
    d.rect(1.2, 4, 13.6, 10, 1.3, 1.8)
    d.poly({ { 1.8, 4.4 }, { 1.8, 2.4 }, { 6, 2.4 }, { 7.6, 4.2 } }, 1.3)
end
IconShapes["folder-open"] = function(d)
    d.poly({ { 1.4, 13.4 }, { 1.4, 2.6 }, { 6, 2.6 }, { 7.6, 4.4 }, { 13, 4.4 }, { 13, 6.6 } }, 1.3)
    d.poly({ { 1.4, 13.4 }, { 4, 7 }, { 15, 7 }, { 12.4, 13.4 }, { 1.4, 13.4 } }, 1.3)
end
IconShapes.settings = function(d)
    d.ring(8, 8, 4.6, 1.3)
    d.ring(8, 8, 1.8, 1.3)
    for i = 0, 7 do
        local a = math.rad(i * 45 + 22.5)
        d.line(8 + math.cos(a) * 5.3, 8 + math.sin(a) * 5.3, 8 + math.cos(a) * 7, 8 + math.sin(a) * 7, 2)
    end
end
IconShapes.search = function(d)
    d.ring(7, 7, 5, 1.3)
    d.line(10.7, 10.7, 14.4, 14.4, 1.4)
end
IconShapes.home = function(d)
    d.poly({ { 1.8, 7.2 }, { 8, 1.8 }, { 14.2, 7.2 } }, 1.3)
    d.poly({ { 3.2, 6.2 }, { 3.2, 14.2 }, { 12.8, 14.2 }, { 12.8, 6.2 } }, 1.3)
    d.poly({ { 6.4, 14.2 }, { 6.4, 9.6 }, { 9.6, 9.6 }, { 9.6, 14.2 } }, 1.2)
end
IconShapes.sword = function(d)
    d.line(4.6, 11.4, 13.8, 2.2, 1.4)
    d.poly({ { 13.8, 2.2 }, { 14.2, 1.8 }, { 14.2, 4.6 } }, 1.2)
    d.line(2.8, 9.4, 6.6, 13.2, 1.4)
    d.line(4, 12, 1.8, 14.2, 1.6)
end
IconShapes.zap = function(d)
    d.poly({ { 9.2, 1 }, { 3, 9.2 }, { 8, 9.2 }, { 6.8, 15 }, { 13, 6.8 }, { 8, 6.8 }, { 9.2, 1 } }, 1.3)
end
IconShapes.move = function(d)
    d.line(8, 1.4, 8, 14.6, 1.3)
    d.line(1.4, 8, 14.6, 8, 1.3)
    d.poly({ { 6, 3.4 }, { 8, 1.4 }, { 10, 3.4 } }, 1.3)
    d.poly({ { 6, 12.6 }, { 8, 14.6 }, { 10, 12.6 } }, 1.3)
    d.poly({ { 3.4, 6 }, { 1.4, 8 }, { 3.4, 10 } }, 1.3)
    d.poly({ { 12.6, 6 }, { 14.6, 8 }, { 12.6, 10 } }, 1.3)
end
IconShapes.history = function(d)
    d.arc(8, 8, 6.4, 1.3, 135, 0.86)
    d.poly({ { 1.6, 2.6 }, { 1.6, 5.8 }, { 4.8, 5.8 } }, 1.3)
    d.poly({ { 8, 4.6 }, { 8, 8.2 }, { 10.4, 9.6 } }, 1.3)
end
IconShapes.target = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.ring(8, 8, 4, 1.3)
    d.dot(8, 8, 1.3)
end
IconShapes.sliders = function(d)
    d.line(1.6, 4, 14.4, 4, 1.3)
    d.line(1.6, 8, 14.4, 8, 1.3)
    d.line(1.6, 12, 14.4, 12, 1.3)
    d.dot(5, 4, 1.7)
    d.dot(11, 8, 1.7)
    d.dot(6.6, 12, 1.7)
end
IconShapes.scan = function(d)
    d.poly({ { 1.6, 5 }, { 1.6, 1.6 }, { 5, 1.6 } }, 1.3)
    d.poly({ { 11, 1.6 }, { 14.4, 1.6 }, { 14.4, 5 } }, 1.3)
    d.poly({ { 14.4, 11 }, { 14.4, 14.4 }, { 11, 14.4 } }, 1.3)
    d.poly({ { 5, 14.4 }, { 1.6, 14.4 }, { 1.6, 11 } }, 1.3)
end
IconShapes.users = function(d)
    d.ring(6, 5.2, 2.8, 1.3)
    d.arc(6, 15.2, 5.4, 1.3, 90, 0.5)
    d.arc(11.6, 5.4, 2.6, 1.2, 180, 0.55)
    d.line(13, 10, 15, 13.6, 1.2)
end
IconShapes.user = function(d)
    d.ring(8, 5.2, 3.2, 1.3)
    d.arc(8, 15.4, 6, 1.3, 90, 0.5)
end
IconShapes.sparkles = function(d)
    d.poly({ { 6.4, 2 }, { 7.6, 6 }, { 11.4, 7.2 }, { 7.6, 8.4 }, { 6.4, 12.4 }, { 5.2, 8.4 }, { 1.4, 7.2 }, { 5.2, 6 }, { 6.4, 2 } }, 1.2)
    d.line(12.6, 1.2, 12.6, 4.8, 1.2)
    d.line(10.8, 3, 14.4, 3, 1.2)
    d.dot(12.6, 12.6, 1.1)
end
IconShapes.sparkle = function(d)
    d.poly({ { 8, 1.2 }, { 9.6, 6.4 }, { 14.8, 8 }, { 9.6, 9.6 }, { 8, 14.8 }, { 6.4, 9.6 }, { 1.2, 8 }, { 6.4, 6.4 }, { 8, 1.2 } }, 1.2)
end
IconShapes.sun = function(d)
    d.ring(8, 8, 3, 1.3)
    for i = 0, 7 do
        local a = math.rad(i * 45)
        d.line(8 + math.cos(a) * 5, 8 + math.sin(a) * 5, 8 + math.cos(a) * 6.8, 8 + math.sin(a) * 6.8, 1.3)
    end
end
IconShapes.monitor = function(d)
    d.rect(1.2, 2, 13.6, 9.4, 1.3, 1.6)
    d.line(8, 11.4, 8, 14, 1.3)
    d.line(5, 14.2, 11, 14.2, 1.3)
end
IconShapes.radar = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.arc(8, 8, 3.8, 1.2, 0, 0.75)
    d.line(8, 8, 12.8, 3.2, 1.3)
    d.dot(8, 8, 1.1)
end
IconShapes.layers = function(d)
    d.poly({ { 8, 1.6 }, { 14.6, 5 }, { 8, 8.4 }, { 1.4, 5 }, { 8, 1.6 } }, 1.2)
    d.poly({ { 1.4, 8.2 }, { 8, 11.6 }, { 14.6, 8.2 } }, 1.2)
    d.poly({ { 1.4, 11.2 }, { 8, 14.6 }, { 14.6, 11.2 } }, 1.2)
end
IconShapes.list = function(d)
    d.line(5.4, 4, 14.4, 4, 1.3)
    d.line(5.4, 8, 14.4, 8, 1.3)
    d.line(5.4, 12, 14.4, 12, 1.3)
    d.dot(2.2, 4, 0.9)
    d.dot(2.2, 8, 0.9)
    d.dot(2.2, 12, 0.9)
end
IconShapes.person = function(d)
    d.ring(8, 2.8, 1.7, 1.2)
    d.line(3, 6, 13, 6, 1.3)
    d.line(8, 6, 8, 10, 1.3)
    d.line(8, 10, 5, 14.6, 1.3)
    d.line(8, 10, 11, 14.6, 1.3)
end
IconShapes.snowflake = function(d)
    for i = 0, 2 do
        local a = math.rad(i * 60 + 90)
        d.line(8 - math.cos(a) * 6.8, 8 - math.sin(a) * 6.8, 8 + math.cos(a) * 6.8, 8 + math.sin(a) * 6.8, 1.3)
    end
end
IconShapes.box = function(d)
    d.poly({ { 8, 1.4 }, { 14, 4.6 }, { 14, 11.4 }, { 8, 14.6 }, { 2, 11.4 }, { 2, 4.6 }, { 8, 1.4 } }, 1.2)
    d.poly({ { 2.2, 4.8 }, { 8, 8 }, { 13.8, 4.8 } }, 1.2)
    d.line(8, 8, 8, 14.4, 1.2)
end
IconShapes.footprints = function(d)
    d.ellipse(4.6, 6, 3.6, 6.6, 1.2)
    d.ellipse(11.4, 4.6, 3.6, 6.6, 1.2)
    d.line(3.4, 11.6, 6, 11.6, 1.2)
    d.line(10.2, 10.2, 12.8, 10.2, 1.2)
end
IconShapes.info = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.line(8, 7.2, 8, 11.4, 1.4)
    d.dot(8, 4.9, 0.85)
end
IconShapes.bell = function(d)
    d.poly({ { 3.4, 11.4 }, { 3.6, 6.6 }, { 5, 3.6 }, { 8, 2.4 }, { 11, 3.6 }, { 12.4, 6.6 }, { 12.6, 11.4 } }, 1.3)
    d.line(2, 11.6, 14, 11.6, 1.3)
    d.line(6.6, 14.2, 9.4, 14.2, 1.3)
end
IconShapes.power = function(d)
    d.arc(8, 8.8, 5.8, 1.3, 90, 0.8)
    d.line(8, 1.4, 8, 7.6, 1.3)
end
IconShapes.save = function(d)
    d.rect(1.8, 1.8, 12.4, 12.4, 1.3, 2)
    d.rect(4.6, 9, 6.8, 5.2, 1.2, 0.8)
    d.poly({ { 4.6, 2 }, { 4.6, 5.2 }, { 10, 5.2 } }, 1.2)
end
IconShapes.download = function(d)
    d.line(8, 1.6, 8, 10.2, 1.3)
    d.poly({ { 4.8, 7 }, { 8, 10.2 }, { 11.2, 7 } }, 1.3)
    d.poly({ { 1.8, 10.8 }, { 1.8, 14.2 }, { 14.2, 14.2 }, { 14.2, 10.8 } }, 1.3)
end
IconShapes.trash = function(d)
    d.line(1.8, 4, 14.2, 4, 1.3)
    d.poly({ { 5.8, 4 }, { 5.8, 1.8 }, { 10.2, 1.8 }, { 10.2, 4 } }, 1.2)
    d.rect(3.4, 4, 9.2, 10.6, 1.3, 1.6)
end
IconShapes.refresh = function(d)
    d.arc(8, 8, 5.8, 1.3, -45, 0.4)
    d.arc(8, 8, 5.8, 1.3, 135, 0.4)
    d.poly({ { 13.6, 1.8 }, { 13.6, 5 }, { 10.4, 5 } }, 1.3)
    d.poly({ { 2.4, 14.2 }, { 2.4, 11 }, { 5.6, 11 } }, 1.3)
end
IconShapes.palette = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.dot(5, 6, 1)
    d.dot(8, 4.4, 1)
    d.dot(11, 6, 1)
    d.dot(5.6, 9.6, 1)
end
IconShapes.check = function(d)
    d.poly({ { 3.4, 8.4 }, { 6.6, 11.6 }, { 12.8, 4.6 } }, 2)
end
IconShapes["chevron-down"] = function(d)
    d.poly({ { 4.4, 6.2 }, { 8, 9.8 }, { 11.6, 6.2 } }, 1.3)
end
IconShapes["chevron-right"] = function(d)
    d.poly({ { 6.2, 4.4 }, { 9.8, 8 }, { 6.2, 11.6 } }, 1.3)
end
IconShapes.x = function(d)
    d.line(4, 4, 12, 12, 1.4)
    d.line(12, 4, 4, 12, 1.4)
end
IconShapes.alert = function(d)
    d.poly({ { 8, 1.6 }, { 14.8, 14 }, { 1.2, 14 }, { 8, 1.6 } }, 1.3)
    d.line(8, 6.2, 8, 9.6, 1.4)
    d.dot(8, 11.8, 0.85)
end
IconShapes["check-circle"] = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.poly({ { 5.2, 8.2 }, { 7.2, 10.2 }, { 10.9, 6.2 } }, 1.3)
end
IconShapes["x-circle"] = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.line(5.6, 5.6, 10.4, 10.4, 1.3)
    d.line(10.4, 5.6, 5.6, 10.4, 1.3)
end
IconShapes.copy = function(d)
    d.rect(5, 5, 9.6, 9.6, 1.2, 2)
    d.poly({ { 2, 11 }, { 2, 2 }, { 11, 2 } }, 1.2)
end
IconShapes.clipboard = function(d)
    d.rect(2.6, 3, 10.8, 12, 1.2, 2)
    d.rect(5.4, 1.4, 5.2, 3.2, 1.2, 1)
end
IconShapes.keyboard = function(d)
    d.rect(1, 3.4, 14, 9.2, 1.2, 2)
    d.dot(4.2, 6.6, 0.75)
    d.dot(6.8, 6.6, 0.75)
    d.dot(9.4, 6.6, 0.75)
    d.dot(12, 6.6, 0.75)
    d.line(5, 9.8, 11, 9.8, 1.2)
end
IconShapes.gauge = function(d)
    d.arc(8, 9, 6.4, 1.3, 90, 0.68)
    d.line(8, 9, 11.4, 5.4, 1.3)
    d.dot(8, 9, 1.1)
end
IconShapes.wifi = function(d)
    d.arc(8, 13, 9, 1.3, 90, 0.26)
    d.arc(8, 13, 5.6, 1.3, 90, 0.3)
    d.dot(8, 12.6, 1.1)
end
IconShapes.clock = function(d)
    d.ring(8, 8, 6.6, 1.3)
    d.poly({ { 8, 4.4 }, { 8, 8.2 }, { 10.6, 9.6 } }, 1.3)
end

--------------------------------------------------------------------------------
-- Lucide icons (https://lucide.dev). Loaded once from the lucide-roblox-direct
-- sprite sheets; any Lucide name works, e.g. Icon = "skull". If the download
-- fails (no HttpGet, offline) the built-in drawn icons are used instead.
--------------------------------------------------------------------------------
Library.LucideURL = "https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua"

-- The library's short names mapped to their Lucide names.
local LucideAliases = {
    dots = "ellipsis",
    home = "house",
    sliders = "sliders-horizontal",
    person = "person-standing",
    trash = "trash",
    refresh = "refresh-cw",
    history = "rotate-ccw",
    alert = "triangle-alert",
    ["check-circle"] = "circle-check",
    ["x-circle"] = "circle-x",
}
Icons.LucideAliases = LucideAliases

function Library:LoadLucide(force)
    if self.Lucide ~= nil and not force then
        return self.Lucide or nil
    end
    self.Lucide = false
    local env = type(getgenv) == "function" and getgenv() or nil
    local module = env and env.RavenLucide
    if type(module) ~= "table" then
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(self.LucideURL))()
        end)
        module = ok and type(result) == "table" and result or nil
        if module and env then
            env.RavenLucide = module -- reuse on re-execute instead of downloading again
        end
    end
    if module and type(module.GetAsset) == "function" then
        self.Lucide = module
    end
    return self.Lucide or nil
end

-- Returns { Url, ImageRectSize, ImageRectOffset } for a name, or nil.
function Icons.Lucide(name)
    if type(name) ~= "string" or Library.UseLucide == false then
        return nil
    end
    local lucide = Library:LoadLucide()
    if not lucide then
        return nil
    end
    name = string.gsub(name, "^lucide%-", "")
    local ok, asset = pcall(lucide.GetAsset, LucideAliases[name] or name)
    if ok and type(asset) == "table" and asset.Url then
        return asset
    end
    return nil
end

function Icons.Exists(name)
    return IconShapes[name] ~= nil or Icons.Lucide(name) ~= nil
end

-- A registered shape always wins over the Lucide icon of the same name.
function Icons.Register(name, drawFn)
    IconShapes[name] = drawFn
    Library.CustomIcons[name] = true
end

-- Creates an icon. Returns { Frame, SetColor(color), SetTransparency(t), Destroy() }
function Icons.Create(name, size, color, parent)
    size = size or 16
    local holder = New("Frame", {
        Name = "Icon_" .. tostring(name),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Parent = parent,
    })
    local fills, strokes = {}, {}
    local obj = { Frame = holder, Color = color or Color3.new(1, 1, 1), Transparency = 0 }

    if type(name) == "string" and (string.find(name, "rbxassetid://") or string.find(name, "rbxasset://") or string.find(name, "^%d+$")) then
        local image = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = string.find(name, "^%d+$") and ("rbxassetid://" .. name) or name,
            ImageColor3 = obj.Color,
            ScaleType = Enum.ScaleType.Fit,
            Parent = holder,
        })
        function obj.SetColor(c)
            obj.Color = c
            image.ImageColor3 = c
        end
        function obj.SetTransparency(t)
            obj.Transparency = t
            image.ImageTransparency = t
        end
        function obj.Destroy()
            holder:Destroy()
        end
        return obj
    end

    local lucide = not Library.CustomIcons[name] and Icons.Lucide(name)
    if lucide then
        local image = New("ImageLabel", {
            Name = "Lucide_" .. tostring(lucide.IconName or LucideAliases[name] or name),
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = lucide.Url,
            ImageRectSize = lucide.ImageRectSize,
            ImageRectOffset = lucide.ImageRectOffset,
            ImageColor3 = obj.Color,
            Parent = holder,
        })
        obj.Lucide = true
        function obj.SetColor(c)
            obj.Color = c
            image.ImageColor3 = c
        end
        function obj.SetTransparency(t)
            obj.Transparency = t
            image.ImageTransparency = t
        end
        function obj.Destroy()
            holder:Destroy()
        end
        return obj
    end

    local k = size / 16
    local d = {}

    function d.line(x1, y1, x2, y2, th)
        th = (th or 1.3) * k
        local dx, dy = (x2 - x1) * k, (y2 - y1) * k
        local len = math.sqrt(dx * dx + dy * dy) + th * 0.6
        local f = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((x1 + x2) / 2 * k, (y1 + y2) / 2 * k),
            Size = UDim2.fromOffset(len, th),
            Rotation = math.deg(math.atan2(dy, dx)),
            BorderSizePixel = 0,
            BackgroundColor3 = obj.Color,
            Parent = holder,
        })
        Corner(UDim.new(1, 0), f)
        table.insert(fills, f)
        return f
    end

    function d.poly(points, th)
        for i = 1, #points - 1 do
            d.line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2], th)
        end
    end

    function d.ellipse(cx, cy, w, h, th)
        th = th or 1.3
        local f = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(cx * k, cy * k),
            Size = UDim2.fromOffset((w - th) * k, (h - th) * k),
            BackgroundTransparency = 1,
            Parent = holder,
        })
        Corner(UDim.new(1, 0), f)
        local s = New("UIStroke", { Thickness = th * k, Color = obj.Color, Parent = f })
        table.insert(strokes, s)
        return f, s
    end

    function d.ring(cx, cy, r, th)
        return d.ellipse(cx, cy, r * 2, r * 2, th)
    end

    -- Ring with a gap: `gapAngle` rotates it, `keep` is the visible fraction of the gradient.
    function d.arc(cx, cy, r, th, gapAngle, keep)
        local _, s = d.ring(cx, cy, r, th)
        New("UIGradient", {
            Rotation = gapAngle or 0,
            Transparency = NS({ { 0, 0 }, { math.max(0.01, keep - 0.02), 0 }, { keep, 1 }, { 1, 1 } }),
            Parent = s,
        })
    end

    function d.rect(x, y, w, h, th, radius)
        th = th or 1.3
        local f = New("Frame", {
            Position = UDim2.fromOffset((x + th / 2) * k, (y + th / 2) * k),
            Size = UDim2.fromOffset((w - th) * k, (h - th) * k),
            BackgroundTransparency = 1,
            Parent = holder,
        })
        Corner(math.max(0, (radius or 2) * k), f)
        local s = New("UIStroke", { Thickness = th * k, Color = obj.Color, Parent = f })
        table.insert(strokes, s)
        return f
    end

    function d.dot(cx, cy, r)
        local f = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(cx * k, cy * k),
            Size = UDim2.fromOffset(r * 2 * k, r * 2 * k),
            BorderSizePixel = 0,
            BackgroundColor3 = obj.Color,
            Parent = holder,
        })
        Corner(UDim.new(1, 0), f)
        table.insert(fills, f)
        return f
    end

    local shape = IconShapes[name] or IconShapes.info
    shape(d)

    function obj.SetColor(c)
        obj.Color = c
        for _, f in ipairs(fills) do
            f.BackgroundColor3 = c
        end
        for _, s in ipairs(strokes) do
            s.Color = c
        end
    end

    function obj.SetTransparency(t)
        obj.Transparency = t
        for _, f in ipairs(fills) do
            f.BackgroundTransparency = t
        end
        for _, s in ipairs(strokes) do
            s.Transparency = t
        end
    end

    function obj.Destroy()
        holder:Destroy()
    end

    return obj
end

-- Icon tied to a theme role and recoloured on theme changes.
function Library:ThemedIcon(name, size, role, parent)
    local icon = Icons.Create(name, size, self.Theme[role] or Color3.new(1, 1, 1), parent)
    icon.Role = role
    self:AddRefresher(function()
        if icon.Role and icon.Frame.Parent then
            icon.SetColor(self.Theme[icon.Role])
        end
    end)
    return icon
end

function Library:Label(parent, text, size, weight, role, props)
    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextSize = size or 12,
        FontFace = Font_(weight or "Regular"),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextColor3 = self.Theme[role or "Text"],
        Size = UDim2.new(1, 0, 1, 0),
        Parent = parent,
    })
    if props then
        for k, v in pairs(props) do
            label[k] = v
        end
    end
    if role then
        self:Bind(label, { TextColor3 = role })
    end
    return label
end

--------------------------------------------------------------------------------
-- GUI mounting & layers: gethui() -> cloneref(CoreGui) -> PlayerGui
--------------------------------------------------------------------------------
local function ProtectedParent(gui)
    if syn and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    elseif type(protectgui) == "function" then
        pcall(protectgui, gui)
    end
    local ok = false
    if type(gethui) == "function" then
        ok = pcall(function()
            gui.Parent = gethui()
        end)
    end
    if not ok or not gui.Parent then
        ok = pcall(function()
            gui.Parent = cloneref(game:GetService("CoreGui"))
        end)
    end
    if not ok or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

function Library:_mount()
    if self.ScreenGui then
        return
    end
    local gui = New("ScreenGui", {
        Name = "Raven_" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })
    ProtectedParent(gui)
    self.ScreenGui = gui
    self.Maid:Give(gui)

    self.MainLayer = New("Frame", { Name = "Main", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
    self.WidgetLayer = New("Frame", { Name = "Widgets", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = gui })
    self.NotifyLayer = New("Frame", {
        Name = "Notifications",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.new(0, 290, 1, -36),
        ZIndex = 3,
        Parent = gui,
    })
    self.NotifyList = List(self.NotifyLayer, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
    -- Overlay portal: every popup lives here so nothing is clipped by scrolling frames.
    self.Overlay = New("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = gui })

    self:_buildTooltip()
    self:_startLoops()
end

--------------------------------------------------------------------------------
-- Fade helper: remembers base transparencies so a group can fade in and out
--------------------------------------------------------------------------------
local FadeProps = {
    Frame = { "BackgroundTransparency" },
    TextLabel = { "BackgroundTransparency", "TextTransparency" },
    TextButton = { "BackgroundTransparency", "TextTransparency" },
    TextBox = { "BackgroundTransparency", "TextTransparency" },
    ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
    ImageButton = { "BackgroundTransparency", "ImageTransparency" },
    UIStroke = { "Transparency" },
    ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
}

local function CaptureFade(root)
    local entries = {}
    local function add(inst)
        local props = FadeProps[inst.ClassName]
        if props then
            for _, prop in ipairs(props) do
                table.insert(entries, { inst, prop, inst[prop] })
            end
        end
    end
    add(root)
    for _, d in ipairs(root:GetDescendants()) do
        add(d)
    end
    return entries
end

function Library:Fade(entries, alpha, duration)
    for _, e in ipairs(entries) do
        local inst, prop, base = e[1], e[2], e[3]
        self:Tween(inst, { [prop] = base + (1 - base) * alpha }, duration or 0.2)
    end
end

local function SetFade(entries, alpha)
    for _, e in ipairs(entries) do
        e[1][e[2]] = e[3] + (1 - e[3]) * alpha
    end
end

--------------------------------------------------------------------------------
-- Tooltips (delayed fade-in, follows the cursor)
--------------------------------------------------------------------------------
function Library:_buildTooltip()
    local tip = New("Frame", {
        Name = "Tooltip",
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0),
        Visible = false,
        ZIndex = 400,
        Parent = self.Overlay,
    })
    self:Bind(tip, { BackgroundColor3 = "Popup" })
    Corner(4, tip)
    self:Bind(Stroke(tip), { Color = "CardStroke" })
    Padding(tip, 6, 9, 6, 9)
    local label = self:Label(tip, "", 11, "Regular", "Text", {
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 401,
    })
    New("UISizeConstraint", { MaxSize = Vector2.new(260, 400), Parent = label })
    self.TooltipFrame = tip
    self.TooltipLabel = label
    self.TooltipFade = CaptureFade(tip)
end

function Library:AttachTooltip(gui, text)
    if not gui or text == nil then
        return
    end
    local token = 0
    local function show()
        token = token + 1
        local my = token
        task.delay(0.4, function()
            if my ~= token or self.Unloaded or not self.TooltipFrame then
                return
            end
            local value = type(text) == "function" and text() or text
            if not value or value == "" then
                return
            end
            self.TooltipLabel.TextWrapped = string.len(tostring(value)) > 42
            self.TooltipLabel.Text = tostring(value)
            self.TooltipTarget = gui
            self:_positionTooltip()
            SetFade(self.TooltipFade, 1)
            self.TooltipFrame.Visible = true
            self:Fade(self.TooltipFade, 0, 0.15)
        end)
    end
    local function hide()
        token = token + 1
        if self.TooltipTarget == gui then
            self.TooltipTarget = nil
            self.TooltipFrame.Visible = false
        end
    end
    self.Maid:Give(gui.MouseEnter:Connect(show))
    self.Maid:Give(gui.MouseLeave:Connect(hide))
    self.Maid:Give(gui.AncestryChanged:Connect(function()
        if not gui:IsDescendantOf(game) then
            hide()
        end
    end))
end

function Library:_positionTooltip()
    local gui = self.TooltipTarget
    if not gui then
        return
    end
    local tip = self.TooltipFrame
    if not gui.Parent or not gui.Visible then
        tip.Visible = false
        self.TooltipTarget = nil
        return
    end
    local screen = self.ScreenGui.AbsoluteSize
    local m = MouseLocation()
    local x, y = m.X + 14, m.Y + 18
    if x + tip.AbsoluteSize.X > screen.X - 8 then
        x = m.X - tip.AbsoluteSize.X - 10
    end
    if y + tip.AbsoluteSize.Y > screen.Y - 8 then
        y = m.Y - tip.AbsoluteSize.Y - 10
    end
    tip.Position = UDim2.fromOffset(x, y)
end

function Library:HideTooltip()
    if self.TooltipTarget then
        self.TooltipTarget = nil
        self.TooltipFrame.Visible = false
    end
end

--------------------------------------------------------------------------------
-- Popups (dropdown menus, colour pickers, keybind mode menus). They stack so a
-- dropdown can open inside another popup; outside clicks close from the top down.
--------------------------------------------------------------------------------
Library.PopupStack = {}

function Library:OpenPopup(frame, anchor, onClose, reposition, persist)
    local stack = self.PopupStack
    while #stack > 0 do
        local top = stack[#stack]
        if anchor and top.Frame and anchor:IsDescendantOf(top.Frame) then
            break
        end
        self:ClosePopup(true)
    end
    local popup = { Frame = frame, Anchor = anchor, OnClose = onClose, Reposition = reposition, Maid = Maid.new() }
    if not persist then
        popup.Maid:Give(frame)
    end
    table.insert(stack, popup)
    if reposition then
        reposition()
    end
    return popup
end

function Library:ClosePopup(instant)
    local popup = table.remove(self.PopupStack)
    if not popup then
        return
    end
    SafeCall(popup.OnClose, instant)
    popup.Maid:Clean()
end

function Library:CloseAllPopups(instant)
    while #self.PopupStack > 0 do
        self:ClosePopup(instant)
    end
end

function Library:IsPopupOpen(frame)
    for _, p in ipairs(self.PopupStack) do
        if p.Frame == frame then
            return true
        end
    end
    return false
end

function Library:ClosePopupFrame(frame)
    while self:IsPopupOpen(frame) do
        self:ClosePopup()
    end
end

-- Places a popup under (or above) its anchor, right aligned by default, kept on screen.
function Library:PlacePopup(frame, anchor, width, height, offsetY, alignLeft)
    local screen = self.ScreenGui.AbsoluteSize
    local p, s = anchor.AbsolutePosition, anchor.AbsoluteSize
    local x = alignLeft and p.X or (p.X + s.X - width)
    local y = p.Y + s.Y + (offsetY or 4)
    if y + height > screen.Y - 10 then
        y = p.Y - height - (offsetY or 4)
    end
    x = Clamp(x, 8, math.max(8, screen.X - width - 8))
    y = Clamp(y, 8, math.max(8, screen.Y - height - 8))
    frame.Position = UDim2.fromOffset(x, y)
end

--------------------------------------------------------------------------------
-- Dragging (delta interpolated, no deprecated .Draggable)
--------------------------------------------------------------------------------
Library.Draggables = {}

function Library:MakeDraggable(handle, target, ignoreFn)
    local drag = { Target = target, Goal = nil, Active = false }
    table.insert(self.Draggables, drag)
    self.Maid:Give(handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if ignoreFn and ignoreFn(input) then
            return
        end
        drag.Active = true
        drag.StartMouse = Vector2.new(input.Position.X, input.Position.Y)
        drag.StartPos = target.Position
        drag.Goal = target.Position
    end))
    return drag
end

--------------------------------------------------------------------------------
-- Key helpers
--------------------------------------------------------------------------------
local KeyDisplay = {
    LeftAlt = "LAlt", RightAlt = "RAlt", LeftShift = "LShift", RightShift = "RShift",
    LeftControl = "LCtrl", RightControl = "RCtrl", LeftSuper = "LWin", RightSuper = "RWin",
    MB1 = "M1", MB2 = "M2", MB3 = "M3", MB4 = "M4", MB5 = "M5",
    Return = "Enter", Backspace = "Back", CapsLock = "Caps", PageUp = "PgUp", PageDown = "PgDn",
    Delete = "Del", Escape = "Esc",
    One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
    Minus = "-", Equals = "=", LeftBracket = "[", RightBracket = "]", Semicolon = ";", Quote = "'",
    Comma = ",", Period = ".", Slash = "/", BackSlash = "\\", Backquote = "`",
}

local function KeyName(key)
    if not key or key == "None" or key == "" then
        return "None"
    end
    return KeyDisplay[key] or key
end
Library.KeyName = KeyName

local function KeyFromInput(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Unknown then
            return nil
        end
        return input.KeyCode.Name
    elseif t == Enum.UserInputType.MouseButton1 then
        return "MB1"
    elseif t == Enum.UserInputType.MouseButton2 then
        return "MB2"
    elseif t == Enum.UserInputType.MouseButton3 then
        return "MB3"
    end
    return nil
end

local KeyAliases = {
    M1 = "MB1", M2 = "MB2", M3 = "MB3", M4 = "MB4", M5 = "MB5",
    MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
    LAlt = "LeftAlt", RAlt = "RightAlt", LShift = "LeftShift", RShift = "RightShift",
    LCtrl = "LeftControl", RCtrl = "RightControl",
}

local function NormalizeKey(key)
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.UserInputType then
            if key == Enum.UserInputType.MouseButton1 then
                return "MB1"
            elseif key == Enum.UserInputType.MouseButton2 then
                return "MB2"
            elseif key == Enum.UserInputType.MouseButton3 then
                return "MB3"
            end
            return "None"
        end
        return key.Name
    end
    if type(key) ~= "string" or key == "" then
        return "None"
    end
    return KeyAliases[key] or key
end

--------------------------------------------------------------------------------
-- Global loops & input
--------------------------------------------------------------------------------
function Library:_startLoops()
    local fpsFrames, fpsClock = 0, 0
    self.FPS = 60
    self.Ping = 0

    self:Connect(RunService.RenderStepped, function(dt)
        if self.Unloaded then
            return
        end
        -- dragging
        for _, drag in ipairs(self.Draggables) do
            if drag.Active and drag.StartMouse then
                if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not drag.Touch then
                    drag.Active = false
                end
                local m = MouseLocation()
                local delta = m - drag.StartMouse
                drag.Goal = UDim2.new(drag.StartPos.X.Scale, drag.StartPos.X.Offset + delta.X, drag.StartPos.Y.Scale, drag.StartPos.Y.Offset + delta.Y)
            end
            if drag.Goal and drag.Target.Parent then
                local alpha = self.Animations and Clamp(dt * 22, 0, 1) or 1
                drag.Target.Position = drag.Target.Position:Lerp(drag.Goal, alpha)
                if not drag.Active then
                    local cur, goal = drag.Target.Position, drag.Goal
                    if math.abs(cur.X.Offset - goal.X.Offset) < 0.5 and math.abs(cur.Y.Offset - goal.Y.Offset) < 0.5 then
                        drag.Target.Position = goal
                        drag.Goal = nil
                    end
                end
            end
        end

        if self.TooltipTarget then
            self:_positionTooltip()
        end

        -- popups follow their anchor and close when it disappears
        for i = #self.PopupStack, 1, -1 do
            local popup = self.PopupStack[i]
            if popup then
                if popup.Anchor and (not popup.Anchor.Parent or not popup.Anchor.Visible) then
                    while #self.PopupStack >= i do
                        self:ClosePopup(true)
                    end
                elseif popup.Reposition then
                    popup.Reposition()
                end
            end
        end

        -- rainbow colour pickers
        self.RainbowHue = (self.RainbowHue + dt * 0.12) % 1
        for _, picker in ipairs(self.RainbowPickers) do
            if picker.Rainbow then
                picker:_setHSV(self.RainbowHue, math.max(picker.S, 0.5), math.max(picker.V, 0.6))
            end
        end

        -- telemetry
        fpsFrames = fpsFrames + 1
        fpsClock = fpsClock + dt
        if fpsClock >= 0.5 then
            self.FPS = math.floor(fpsFrames / fpsClock + 0.5)
            fpsFrames, fpsClock = 0, 0
            local ok, ping = pcall(function()
                return LocalPlayer:GetNetworkPing() * 1000
            end)
            if not ok or not ping or ping <= 0 then
                ok, ping = pcall(function()
                    return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                end)
            end
            self.Ping = (ok and ping) and math.floor(ping + 0.5) or 0
            if self.Watermark then
                self:_updateWatermark()
            end
        end
    end)

    self:Connect(UserInputService.InputBegan, function(input, gameProcessed)
        if self.Unloaded then
            return
        end
        local t = input.UserInputType
        local isClick = t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch

        if t == Enum.UserInputType.Touch then
            for _, drag in ipairs(self.Draggables) do
                if drag.Active then
                    drag.Touch = true
                end
            end
        end

        -- keybind capture (Backspace / Escape clear the bind)
        if self.CapturingPicker then
            local key = KeyFromInput(input)
            if key then
                local picker = self.CapturingPicker
                if os.clock() - (picker._captureStart or 0) > 0.05 then
                    self.CapturingPicker = nil
                    picker._capturing = false
                    if key == "Escape" or key == "Backspace" then
                        picker:SetKey("None")
                    else
                        picker:SetKey(key)
                    end
                    picker:_refresh()
                    return
                end
            end
        end

        -- close popups on outside click, top of the stack first
        if isClick and #self.PopupStack > 0 then
            local pos = Vector2.new(input.Position.X, input.Position.Y)
            while #self.PopupStack > 0 do
                local popup = self.PopupStack[#self.PopupStack]
                if IsInside(popup.Frame, pos) or (popup.Anchor and IsInside(popup.Anchor, pos)) then
                    break
                end
                self:ClosePopup()
            end
        end

        local key = KeyFromInput(input)
        if not key then
            return
        end
        if t == Enum.UserInputType.Keyboard and UserInputService:GetFocusedTextBox() ~= nil then
            return
        end
        local isMouse = t ~= Enum.UserInputType.Keyboard
        if isMouse and gameProcessed then
            return
        end

        if key == self.MenuKey and not isMouse then
            for _, window in ipairs(self.Windows) do
                window:Toggle()
            end
        end
        if self.PanicKey and key == self.PanicKey and not isMouse then
            self:Panic()
            return
        end
        for _, picker in ipairs(self.Keybinds) do
            if picker.Key == key then
                picker:_onInput(true)
            end
        end
    end)

    self:Connect(UserInputService.InputChanged, function(input)
        local drag = self.ActiveDrag
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            SafeCall(drag.Update, Vector2.new(input.Position.X, input.Position.Y))
        end
    end)

    self:Connect(UserInputService.InputEnded, function(input)
        if self.Unloaded then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            for _, drag in ipairs(self.Draggables) do
                drag.Active = false
                drag.Touch = nil
            end
            if self.ActiveDrag then
                local drag = self.ActiveDrag
                self.ActiveDrag = nil
                SafeCall(drag.End)
            end
        end
        local key = KeyFromInput(input)
        if not key then
            return
        end
        for _, picker in ipairs(self.Keybinds) do
            if picker.Key == key then
                picker:_onInput(false)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Notifications: toast cards with accent bar, icon, countdown and slide/fade
--------------------------------------------------------------------------------
local NotifyIcons = { Success = "check-circle", Info = "info", Warning = "alert", Error = "x-circle" }
local NotifyRoles = { Success = "Success", Info = "Accent", Warning = "Warning", Error = "Danger" }

function Library:Notify(opts, maybeDuration)
    if type(opts) == "string" then
        opts = { Title = opts, Content = "", Duration = maybeDuration }
    end
    opts = opts or {}
    if not self.ShowNotifications or self.Unloaded then
        return nil
    end
    self:_mount()
    local duration = opts.Duration or 5
    local kind = opts.Type or "Info"
    local role = opts.Role or NotifyRoles[kind] or "Accent"
    local hasBody = opts.Content ~= nil and opts.Content ~= ""
    local fromLeft = false
    local slideX = fromLeft and -60 or 60

    local slot = New("Frame", {
        Name = "Toast",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, hasBody and 58 or 40),
        Parent = self.NotifyLayer,
    })
    local card = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(slideX, 0),
        Parent = slot,
    })
    self:Bind(card, { BackgroundColor3 = "Widget" })
    Corner(5, card)
    self:Bind(Stroke(card), { Color = "CardStroke" })

    local accent = New("Frame", {
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(0, 2, 1, -16),
        BorderSizePixel = 0,
        Parent = card,
    })
    self:Bind(accent, { BackgroundColor3 = role })
    Corner(UDim.new(1, 0), accent)

    local icon = self:ThemedIcon(opts.Icon or NotifyIcons[kind] or "info", 14, role, card)
    icon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Frame.Position = UDim2.new(0, 22, 0, hasBody and 20 or 20)

    local title = self:Label(card, opts.Title or "Notification", 12, "Medium", "Text", {
        Position = UDim2.fromOffset(38, hasBody and 11 or 12),
        Size = UDim2.new(1, -50, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local body
    if hasBody then
        body = self:Label(card, opts.Content, 11, "Regular", "TextMuted", {
            Position = UDim2.fromOffset(38, 29),
            Size = UDim2.new(1, -50, 0, 15),
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end

    local track = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -4),
        Size = UDim2.new(1, -20, 0, 2),
        BorderSizePixel = 0,
        Parent = card,
    })
    self:Bind(track, { BackgroundColor3 = "Track" })
    Corner(UDim.new(1, 0), track)
    local bar = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = track })
    self:Bind(bar, { BackgroundColor3 = role })
    Corner(UDim.new(1, 0), bar)

    local fade = CaptureFade(card)
    SetFade(fade, 1)
    self:Tween(card, { Position = UDim2.fromOffset(0, 0) }, 0.35, Enum.EasingStyle.Quint)
    self:Fade(fade, 0, 0.3)

    local closed = false
    local toast = { Frame = slot }
    function toast:Close()
        if closed then
            return
        end
        closed = true
        Library:Tween(card, { Position = UDim2.fromOffset(slideX, 0) }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Library:Fade(fade, 1, 0.25)
        task.delay(Library.Animations and 0.3 or 0, function()
            Library:Tween(slot, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
            task.delay(Library.Animations and 0.22 or 0, function()
                slot:Destroy()
            end)
        end)
    end
    function toast:SetText(newTitle, content)
        if newTitle then
            title.Text = newTitle
        end
        if content and body then
            body.Text = content
        end
    end

    if duration and duration > 0 then
        local barTween = TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
        barTween:Play()
        self.Maid:Give(barTween)
        task.delay(duration, function()
            toast:Close()
        end)
    end

    local closeButton = New("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
    closeButton.MouseButton1Click:Connect(function()
        toast:Close()
    end)
    return toast
end

-- "BottomRight" (default) or "TopRight"
function Library:SetNotifyPosition(position)
    self:_mount()
    self.NotifySide = position
    local layer = self.NotifyLayer
    if position == "TopRight" then
        layer.AnchorPoint = Vector2.new(1, 0)
        layer.Position = UDim2.new(1, -18, 0, 52)
        self.NotifyList.VerticalAlignment = Enum.VerticalAlignment.Top
    else
        layer.AnchorPoint = Vector2.new(1, 1)
        layer.Position = UDim2.new(1, -18, 1, -18)
        self.NotifyList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    end
end

--------------------------------------------------------------------------------
-- Floating keybind list (draggable)
--------------------------------------------------------------------------------
function Library:_buildKeybindList()
    if self.KeybindList then
        return
    end
    local frame = New("Frame", {
        Name = "KeybindList",
        Position = UDim2.fromOffset(18, 320),
        Size = UDim2.fromOffset(200, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = self.WidgetLayer,
    })
    self:Bind(frame, { BackgroundColor3 = "Widget" })
    Corner(5, frame)
    self:Bind(Stroke(frame), { Color = "CardStroke" })
    List(frame, 0)

    local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Parent = frame })
    local icon = self:ThemedIcon("keyboard", 13, "TextMuted", header)
    icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
    icon.Frame.Position = UDim2.new(0, 11, 0.5, 0)
    self:Label(header, "KEYBINDS", 10, "Medium", "TextMuted", { Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -40, 1, 0) })
    local divider = New("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 1, Parent = frame })
    self:Bind(divider, { BackgroundColor3 = "CardStroke" })

    local rows = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = frame })
    List(rows, 0)
    Padding(rows, 4, 11, 5, 11)

    self.KeybindList = frame
    self.KeybindRows = rows
    self.KeybindRowCache = {}
    self:MakeDraggable(header, frame)
    self:AddRefresher(function()
        self:_refreshKeybindList()
    end)
    self:_refreshKeybindList()
end

function Library:_refreshKeybindList()
    if not self.KeybindRows or self.Unloaded then
        return
    end
    for _, row in ipairs(self.KeybindRowCache) do
        row:Destroy()
    end
    self.KeybindRowCache = {}
    local th = self.Theme
    local count = 0
    for _, picker in ipairs(self.Keybinds) do
        if picker.ShowInList ~= false and picker.Key ~= "None" and picker.Visible ~= false then
            count = count + 1
            local active = picker:GetState()
            local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = count, Parent = self.KeybindRows })
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -90, 1, 0),
                Text = picker:GetDisplayName(),
                TextSize = 11,
                FontFace = Font_("Regular"),
                TextColor3 = active and th.Text or th.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 90, 1, 0),
                Text = "[" .. picker.Mode .. "] " .. KeyName(picker.Key),
                TextSize = 10,
                FontFace = Font_("Medium"),
                TextColor3 = active and th.Accent or th.TextFaint,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = row,
            })
            table.insert(self.KeybindRowCache, row)
        end
    end
    if count == 0 then
        local empty = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            Text = "No keybinds",
            TextSize = 11,
            FontFace = Font_("Regular"),
            TextColor3 = th.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = self.KeybindRows,
        })
        table.insert(self.KeybindRowCache, empty)
    end
end

function Library:SetKeybindListVisible(state)
    self:_mount()
    self:_buildKeybindList()
    self.KeybindList.Visible = state and true or false
end

--------------------------------------------------------------------------------
-- Watermark / telemetry bar (draggable): brand | config | fps | ping | time
--------------------------------------------------------------------------------
function Library:_buildWatermark()
    if self.Watermark then
        return
    end
    local frame = New("Frame", {
        Name = "Watermark",
        Position = UDim2.fromOffset(18, 18),
        Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        Visible = false,
        Parent = self.WidgetLayer,
    })
    self:Bind(frame, { BackgroundColor3 = "Widget" })
    Corner(5, frame)
    self:Bind(Stroke(frame), { Color = "CardStroke" })
    Padding(frame, 0, 11, 0, 10)
    List(frame, 9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local order = 0
    local function nextOrder()
        order = order + 1
        return order
    end
    local function seg(str, role, weight)
        return self:Label(frame, str, 11, weight or "Regular", role, {
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = nextOrder(),
        })
    end
    local function divider()
        local d = New("Frame", { BorderSizePixel = 0, Size = UDim2.fromOffset(1, 12), LayoutOrder = nextOrder(), Parent = frame })
        self:Bind(d, { BackgroundColor3 = "CardStroke" })
        return d
    end

    local brand = New("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = nextOrder(), Parent = frame })
    List(brand, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    local logo = self:ThemedIcon(self.LogoIcon or "shield", 13, "Text", brand)
    logo.Frame.LayoutOrder = 1
    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        RichText = true,
        Text = "",
        TextSize = 11,
        FontFace = Font_("SemiBold"),
        LayoutOrder = 2,
        Parent = brand,
    })
    self:Bind(title, { TextColor3 = "Text" })

    divider()
    local config = seg("default", "TextMuted")
    divider()
    local fps = seg("60 fps", "TextMuted")
    local pingDivider = divider()
    local ping = seg("0 ms", "TextMuted")
    divider()
    local clock = seg(os.date("%H:%M"), "TextMuted")

    self.Watermark = {
        Frame = frame, Title = title, Config = config, Fps = fps, Ping = ping, PingDivider = pingDivider, Clock = clock,
        DefaultText = "default", ShowPing = true,
    }
    self:MakeDraggable(frame, frame)
    self:AddRefresher(function()
        self:_updateWatermark()
    end)
    self:_updateWatermark()
end

local function BrandRich(title, suffix, mutedColor)
    local hex = ColorToHex(mutedColor)
    return title .. (suffix and suffix ~= "" and ('<font color="' .. hex .. '">' .. suffix .. "</font>") or "")
end

function Library:_updateWatermark()
    local w = self.Watermark
    if not w then
        return
    end
    w.Title.Text = BrandRich(self.Title or "Raven", self.TitleSuffix, self.Theme.TextDim)
    w.Fps.Text = tostring(self.FPS or 60) .. " fps"
    w.Ping.Text = tostring(self.Ping or 0) .. " ms"
    w.Ping.Visible = w.ShowPing
    w.PingDivider.Visible = w.ShowPing
    w.Clock.Text = os.date("%H:%M")
    w.Config.Text = self.ActiveConfig or w.DefaultText
end

function Library:SetWatermark(opts)
    self:_mount()
    self:_buildWatermark()
    opts = opts or {}
    if opts.Title then
        self.Title = opts.Title
    end
    if opts.Suffix then
        self.TitleSuffix = opts.Suffix
    end
    if opts.Text then
        self.Watermark.DefaultText = opts.Text
    end
    if opts.ShowPing ~= nil then
        self.Watermark.ShowPing = opts.ShowPing
    end
    self:_updateWatermark()
end

function Library:SetWatermarkVisible(state)
    self:_mount()
    self:_buildWatermark()
    self.Watermark.Frame.Visible = state and true or false
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local SubTab = {}
SubTab.__index = SubTab
local Container = {}
Container.__index = Container

local SHADOW_IMAGE = "rbxassetid://6015897843"
local SIDEBAR_WIDTH = 195
local TOPBAR_HEIGHT = 59
local SUBTAB_HEIGHT = 62
local PAGE_TOP = TOPBAR_HEIGHT + SUBTAB_HEIGHT
local TAB_TOP = 118
local TAB_HEIGHT = 40
local PAGE_PAD = 17
local COLUMN_GAP = 16

local function Shadow(parent, spread, transparency)
    spread = spread or 40
    return New("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 6),
        Size = UDim2.new(1, spread, 1, spread),
        Image = SHADOW_IMAGE,
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = transparency or 0.4,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = parent,
    })
end

-- Soft blob: stacked ellipses fake a radial gradient (used for the smoke texture).
local function SoftBlob(parent, x, y, w, h, strength, rotation, color)
    local holder = New("Frame", {
        Name = "Blob",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, y),
        Size = UDim2.fromScale(w, h),
        Rotation = rotation or 0,
        ZIndex = 1,
        Parent = parent,
    })
    local rings = 7
    local per = 1 - (1 - strength) ^ (1 / rings)
    for i = 1, rings do
        local k = 1 - (i - 1) / rings * 0.86
        local ring = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(k, k),
            BackgroundColor3 = color or Color3.new(1, 1, 1),
            BackgroundTransparency = 1 - per,
            BorderSizePixel = 0,
            ZIndex = 1,
            Parent = holder,
        })
        Corner(UDim.new(1, 0), ring)
    end
    return holder
end

-- The smoky backdrop behind the content area.
local function BuildTexture(parent)
    local layer = New("Frame", { Name = "Texture", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = parent })
    local wisps = {
        { 0.30, 0.12, 0.34, 0.55, 0.085, -12 },
        { 0.44, 0.40, 0.20, 0.95, 0.075, 8 },
        { 0.58, 0.30, 0.30, 0.70, 0.07, 20 },
        { 0.80, 0.08, 0.60, 0.42, 0.1, 0 },
        { 0.92, 0.55, 0.36, 0.95, 0.09, -6 },
        { 0.70, 0.88, 0.50, 0.40, 0.06, 0 },
        { 0.18, 0.70, 0.25, 0.70, 0.035, 15 },
        { 0.52, 0.66, 0.14, 0.60, 0.05, -18 },
    }
    for _, w in ipairs(wisps) do
        SoftBlob(layer, w[1], w[2], w[3], w[4], w[5], w[6])
    end
    -- darker band on the left edge, like the reference
    local shade = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(0.35, 1), ZIndex = 1, Parent = layer })
    New("UIGradient", { Transparency = NS({ { 0, 0.7 }, { 1, 1 } }), Parent = shade })
    return layer
end

local function IconButton(lib, parent, icon, tooltip, size)
    local button = New("TextButton", {
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromOffset(size or 30, size or 30),
        BackgroundTransparency = 0.25,
        Parent = parent,
    })
    lib:Bind(button, { BackgroundColor3 = "Element" })
    Corner(UDim.new(1, 0), button)
    local stroke = Stroke(button)
    lib:Bind(stroke, { Color = "CardStroke" })
    local ic = lib:ThemedIcon(icon, 14, "TextMuted", button)
    ic.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.Frame.Position = UDim2.fromScale(0.5, 0.5)
    button.MouseEnter:Connect(function()
        lib:Tween(button, { BackgroundTransparency = 0 }, 0.15)
        ic.Role = "Text"
        ic.SetColor(lib.Theme.Text)
    end)
    button.MouseLeave:Connect(function()
        lib:Tween(button, { BackgroundTransparency = 0.25 }, 0.15)
        ic.Role = "TextMuted"
        ic.SetColor(lib.Theme.TextMuted)
    end)
    if tooltip then
        lib:AttachTooltip(button, tooltip)
    end
    return button, ic
end

function Library:CreateWindow(opts)
    opts = opts or {}
    self:_mount()

    self.Title = opts.Title or "Raven"
    self.TitleSuffix = opts.Suffix or ".cc"
    self.LogoIcon = opts.Logo or "shield"
    self.ConfigFolder = opts.ConfigFolder or (self.Title .. self.TitleSuffix)
    self.MenuKey = NormalizeKey(opts.Keybind or opts.ToggleKey or "Insert")

    local size = opts.Size or Vector2.new(880, 560)
    if typeof(size) == "UDim2" then
        size = Vector2.new(size.X.Offset, size.Y.Offset)
    end

    local window = setmetatable({
        Library = self,
        Tabs = {},
        Opened = true,
        Minimized = false,
        Size = size,
        MinSize = opts.MinSize or Vector2.new(760, 440),
        Resizable = opts.Resizable ~= false,
        TextureEnabled = opts.Texture ~= false,
    }, Window)
    table.insert(self.Windows, window)

    local holder = New("Frame", {
        Name = "Raven",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(size.X, size.Y),
        Parent = self.MainLayer,
    })
    window.Holder = holder
    window.Scale = New("UIScale", { Scale = 1, Parent = holder })
    window.UserScale = 1
    window.FitScale = 1

    -- unlocks the mouse while the menu is open
    window.ModalButton = New("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.fromOffset(0, 0),
        Modal = true,
        Parent = holder,
    })

    local shadow = Shadow(holder, 60, 0.3)
    -- A plain clipping Frame, not a CanvasGroup: CanvasGroups render to a capped
    -- texture, which cuts content off and blurs text on high-DPI screens and phones.
    local canvas = New("Frame", {
        Name = "Canvas",
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = holder,
    })
    self:Bind(canvas, { BackgroundColor3 = "Background" })
    Corner(9, canvas)
    local outline = New("Frame", { Name = "Outline", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = holder })
    Corner(9, outline)
    local outlineStroke = Stroke(outline, Color3.fromRGB(58, 58, 58), 0.2)
    window.Canvas, window.Outline = canvas, outline
    window.Fades = {
        { outlineStroke, "Transparency", 0.2 },
        { shadow, "ImageTransparency", 0.3 },
    }

    ----------------------------------------------------------------------------
    -- Content area (right side): texture, top bar, sub tab bar, pages
    ----------------------------------------------------------------------------
    local content = New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0),
        Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0),
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = canvas,
    })
    local tint = New("Frame", { Name = "Tint", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = content })
    self:Bind(tint, { BackgroundColor3 = "Background" })
    Corner(9, tint) -- keeps the window's right corners round without a CanvasGroup
    New("UIGradient", {
        Rotation = 35,
        Color = CS({ { 0, Color3.fromRGB(205, 205, 205) }, { 1, Color3.fromRGB(255, 255, 255) } }),
        Parent = tint,
    })
    window.Content = content
    window.Texture = BuildTexture(content)
    window.Texture.Visible = window.TextureEnabled

    -- top bar
    local topbar = New("Frame", { Name = "TopBar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT), ZIndex = 3, Parent = content })
    window.TopBar = topbar
    local search = New("Frame", {
        Name = "Search",
        Position = UDim2.fromOffset(PAGE_PAD, 14),
        Size = UDim2.fromOffset(opts.SearchWidth or 298, 32),
        BackgroundTransparency = 0.35,
        ZIndex = 3,
        Parent = topbar,
    })
    self:Bind(search, { BackgroundColor3 = "Field" })
    Corner(5, search)
    local searchStroke = Stroke(search)
    self:Bind(searchStroke, { Color = "CardStroke" })
    local searchIcon = self:ThemedIcon("search", 12, "TextDim", search)
    searchIcon.Frame.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.Frame.Position = UDim2.new(0, 11, 0.5, 0)
    local searchBox = New("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(33, 0),
        Size = UDim2.new(1, -60, 1, 0),
        Text = "",
        PlaceholderText = "Search for 0 functions...",
        TextSize = 11,
        FontFace = Font_("Regular"),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 4,
        Parent = search,
    })
    self:Bind(searchBox, { TextColor3 = "Text", PlaceholderColor3 = "TextDim" })
    local clear = New("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Text = "",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        Visible = false,
        ZIndex = 4,
        Parent = search,
    })
    local clearIcon = self:ThemedIcon("x", 11, "TextDim", clear)
    clearIcon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    clearIcon.Frame.Position = UDim2.fromScale(0.5, 0.5)
    window.SearchBox = searchBox
    searchBox.Focused:Connect(function()
        self:Tween(searchStroke, { Color = Mix(self.Theme.CardStroke, self.Theme.Accent, 0.35) }, 0.15)
    end)
    searchBox.FocusLost:Connect(function()
        self:Tween(searchStroke, { Color = self.Theme.CardStroke }, 0.15)
    end)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        clear.Visible = searchBox.Text ~= ""
        window:_runSearch(searchBox.Text)
    end)
    clear.MouseButton1Click:Connect(function()
        searchBox.Text = ""
    end)

    local gear = IconButton(self, topbar, "settings", "Settings")
    gear.AnchorPoint = Vector2.new(1, 0.5)
    gear.Position = UDim2.new(1, -PAGE_PAD, 0, 30)
    gear.ZIndex = 3
    gear.MouseButton1Click:Connect(function()
        if window.SettingsTab then
            window.SettingsTab:Select()
        elseif opts.OnSettings then
            SafeCall(opts.OnSettings)
        end
    end)
    window.GearButton = gear

    local topDivider = New("Frame", {
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, TOPBAR_HEIGHT - 1),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
        Parent = content,
    })
    self:Bind(topDivider, { BackgroundColor3 = "Divider" })
    self:MakeDraggable(topbar, holder, function()
        local m = MouseLocation()
        return IsInside(search, m) or IsInside(gear, m)
    end)

    -- sub tab bar
    local subBar = New("Frame", {
        Name = "SubTabs",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, TOPBAR_HEIGHT),
        Size = UDim2.new(1, 0, 0, SUBTAB_HEIGHT),
        ZIndex = 3,
        Parent = content,
    })
    window.SubBar = subBar

    -- pages
    window.PageHolder = New("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, PAGE_TOP),
        Size = UDim2.new(1, 0, 1, -PAGE_TOP),
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = content,
    })

    ----------------------------------------------------------------------------
    -- Sidebar
    ----------------------------------------------------------------------------
    local sidebar = New("Frame", {
        Name = "Sidebar",
        BorderSizePixel = 0,
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
        ZIndex = 3,
        Parent = canvas,
    })
    self:Bind(sidebar, { BackgroundColor3 = "Sidebar" })
    Corner(9, sidebar) -- round left corners; the patch squares off the right side
    local sidebarPatch = New("Frame", {
        Name = "Patch",
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 12, 1, 0),
        ZIndex = 3,
        Parent = sidebar,
    })
    self:Bind(sidebarPatch, { BackgroundColor3 = "Sidebar" })
    local edge = New("Frame", {
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundTransparency = 0.4,
        ZIndex = 4,
        Parent = sidebar,
    })
    self:Bind(edge, { BackgroundColor3 = "Divider" })
    window.Sidebar = sidebar

    local brand = New("TextButton", {
        Name = "Brand",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.new(1, 0, 0, 100),
        ZIndex = 4,
        Parent = sidebar,
    })
    local logo = self:ThemedIcon(self.LogoIcon, 18, "Text", brand)
    logo.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Frame.Position = UDim2.new(0.5, 0, 0, 38)
    DeepZ(logo.Frame, 4)
    local brandTitle = New("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 71),
        Size = UDim2.new(1, -20, 0, 18),
        RichText = true,
        Text = "",
        TextSize = 14,
        FontFace = Font_("SemiBold"),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
        Parent = brand,
    })
    self:Bind(brandTitle, { TextColor3 = "Text" })
    window.BrandTitle = brandTitle
    self:AddRefresher(function()
        brandTitle.Text = BrandRich(self.Title, self.TitleSuffix, self.Theme.TextDim)
    end)
    brandTitle.Text = BrandRich(self.Title, self.TitleSuffix, self.Theme.TextDim)
    self:AttachTooltip(brand, "Double click to minimize")
    local lastClick = 0
    brand.MouseButton1Click:Connect(function()
        if os.clock() - lastClick < 0.35 then
            window:SetMinimized(not window.Minimized)
            lastClick = 0
        else
            lastClick = os.clock()
        end
    end)
    self:MakeDraggable(brand, holder)

    local sideDivider = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 102),
        Size = UDim2.fromOffset(147, 1),
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = sidebar,
    })
    self:Bind(sideDivider, { BackgroundColor3 = "Divider" })
    New("UIGradient", { Transparency = NS({ { 0, 1 }, { 0.2, 0 }, { 0.8, 0 }, { 1, 1 } }), Parent = sideDivider })

    window.TabHolder = New("ScrollingFrame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, TAB_TOP),
        Size = UDim2.new(1, 0, 1, -TAB_TOP - 8),
        CanvasSize = UDim2.fromScale(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ZIndex = 4,
        Parent = sidebar,
    })
    List(window.TabHolder, 0)

    -- resize grip
    if window.Resizable then
        local grip = New("TextButton", {
            Name = "Resize",
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Text = "",
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.fromScale(1, 1),
            Size = UDim2.fromOffset(18, 18),
            ZIndex = 31,
            Parent = holder,
        })
        local g1 = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -7, 1, -7), Size = UDim2.fromOffset(9, 1), Rotation = -45, BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 31, Parent = grip })
        local g2 = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -5, 1, -5), Size = UDim2.fromOffset(4, 1), Rotation = -45, BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 31, Parent = grip })
        self:Bind(g1, { BackgroundColor3 = "TextDim" })
        self:Bind(g2, { BackgroundColor3 = "TextDim" })
        grip.MouseEnter:Connect(function()
            self:Tween(g1, { BackgroundTransparency = 0.2 }, 0.15)
            self:Tween(g2, { BackgroundTransparency = 0.2 }, 0.15)
        end)
        grip.MouseLeave:Connect(function()
            self:Tween(g1, { BackgroundTransparency = 1 }, 0.15)
            self:Tween(g2, { BackgroundTransparency = 1 }, 0.15)
        end)
        grip.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local startMouse = MouseLocation()
            local startSize = window.Size
            local startPos = holder.Position
            self.ActiveDrag = {
                Update = function(pos)
                    local delta = (pos - startMouse) / window.Scale.Scale
                    local newSize = window:SetSize(Vector2.new(startSize.X + delta.X, startSize.Y + delta.Y))
                    -- keep the top-left corner pinned (the holder is centre anchored)
                    local grow = (newSize - startSize) * window.Scale.Scale / 2
                    holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + grow.X, startPos.Y.Scale, startPos.Y.Offset + grow.Y)
                end,
            }
        end)
    end

    -- search results page
    window:_buildSearchPage()

    -- widgets
    self:_buildKeybindList()
    self:_buildWatermark()
    if opts.ShowWatermark then
        self:SetWatermarkVisible(true)
    end
    if opts.ShowKeybinds then
        self:SetKeybindListVisible(true)
    end

    -- open animation
    window.Scale.Scale = 0.96
    for _, f in ipairs(window.Fades) do
        f[1][f[2]] = 1
    end
    -- Shrink the window to fit small screens (phones, tablets, small windows).
    local function fit()
        local gui = self.ScreenGui
        local ok, screen = pcall(function()
            return gui.AbsoluteSize
        end)
        if not ok or not screen or screen.X <= 0 or screen.Y <= 0 then
            return
        end
        local margin = 24
        local scale = math.min(1, (screen.X - margin) / window.Size.X, (screen.Y - margin) / window.Size.Y)
        window.FitScale = math.max(0.35, scale)
        if window.Opened then
            window.Scale.Scale = window.UserScale * window.FitScale
        end
    end
    window._fit = fit
    fit()
    pcall(function()
        self.Maid:Give(self.ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    end)
    task.defer(function()
        window:Toggle(true)
    end)
    return window
end

function Window:SetSize(v)
    local lib = self.Library
    v = Vector2.new(math.max(self.MinSize.X, math.floor(v.X)), math.max(self.MinSize.Y, math.floor(v.Y)))
    self.Size = v
    if self._fit then
        self._fit()
    end
    if not self.Minimized then
        self.Holder.Size = UDim2.fromOffset(v.X, v.Y)
    else
        self.Holder.Size = UDim2.fromOffset(v.X, 100)
    end
    lib:CloseAllPopups(true)
    return v
end

function Window:SetScale(scale)
    self.UserScale = scale
    self.Library:Tween(self.Scale, { Scale = scale * (self.FitScale or 1) }, 0.25)
end

function Window:Toggle(state)
    local lib = self.Library
    if state == nil then
        state = not self.Opened
    end
    self.Opened = state
    lib:CloseAllPopups(true)
    lib:HideTooltip()
    self.ModalButton.Modal = state
    self._toggleToken = (self._toggleToken or 0) + 1
    local token = self._toggleToken
    if state then
        self.Holder.Visible = true
        lib:Tween(self.Scale, { Scale = self.UserScale * self.FitScale }, 0.3, Enum.EasingStyle.Quint)
        for _, f in ipairs(self.Fades) do
            lib:Tween(f[1], { [f[2]] = f[3] }, 0.22)
        end
    else
        lib:Tween(self.Scale, { Scale = self.UserScale * self.FitScale * 0.96 }, 0.22, Enum.EasingStyle.Quint)
        for _, f in ipairs(self.Fades) do
            lib:Tween(f[1], { [f[2]] = 1 }, 0.2)
        end
        task.delay(lib.Animations and 0.22 or 0, function()
            if self._toggleToken == token and not self.Opened then
                self.Holder.Visible = false
            end
        end)
    end
end

function Window:SetMinimized(state)
    local lib = self.Library
    self.Minimized = state and true or false
    lib:CloseAllPopups(true)
    local height = self.Minimized and 100 or self.Size.Y
    lib:Tween(self.Holder, { Size = UDim2.fromOffset(self.Size.X, height) }, 0.3, Enum.EasingStyle.Quint)
end

function Window:SetTexture(state)
    self.TextureEnabled = state and true or false
    self.Texture.Visible = self.TextureEnabled
end

function Window:SetTitle(title, suffix)
    local lib = self.Library
    lib.Title = title or lib.Title
    if suffix ~= nil then
        lib.TitleSuffix = suffix
    end
    self.BrandTitle.Text = BrandRich(lib.Title, lib.TitleSuffix, lib.Theme.TextDim)
    lib:_updateWatermark()
end

function Window:Destroy()
    self.Holder:Destroy()
end

--------------------------------------------------------------------------------
-- Search ("Search for N functions...")
--------------------------------------------------------------------------------
function Window:_buildSearchPage()
    local lib = self.Library
    local scroll = New("ScrollingFrame", {
        Name = "SearchResults",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.fromScale(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageTransparency = 0.5,
        Visible = false,
        ZIndex = 3,
        Parent = self.PageHolder,
    })
    lib:Bind(scroll, { ScrollBarImageColor3 = "CardStroke" })
    Padding(scroll, 13, PAGE_PAD, 16, PAGE_PAD)
    List(scroll, 6)
    self.SearchPage = scroll
end

function Window:_updateSearchCount()
    local count = 0
    for _, entry in ipairs(self.Library.Searchables) do
        if entry.Window == self and entry.Element.Row and entry.Element.Row.Parent then
            count = count + 1
        end
    end
    self.SearchBox.PlaceholderText = "Search for " .. count .. " functions..."
end

function Window:_queueSearchCount()
    if self._countQueued then
        return
    end
    self._countQueued = true
    task.defer(function()
        self._countQueued = false
        if not self.Library.Unloaded then
            self:_updateSearchCount()
        end
    end)
end

function Window:_runSearch(query)
    local lib = self.Library
    local page = self.SearchPage
    for _, child in ipairs(page:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    query = string.lower(query or "")
    query = string.gsub(query, "^%s+", "")
    query = string.gsub(query, "%s+$", "")
    if query == "" then
        page.Visible = false
        self.SubBar.Visible = true
        if self.ActivePage then
            self.ActivePage.Scroll.Visible = true
        end
        return
    end
    page.Visible = true
    self.SubBar.Visible = false
    if self.ActivePage then
        self.ActivePage.Scroll.Visible = false
    end
    lib:CloseAllPopups(true)

    local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = page })
    -- element names first; if nothing matches, fall back to "Tab › Sub › Section" paths
    local results, pathResults = {}, {}
    for _, entry in ipairs(lib.Searchables) do
        local el = entry.Element
        if entry.Window == self and el.Row and el.Row.Parent then
            if string.find(string.lower(el.Text or ""), query, 1, true) then
                table.insert(results, entry)
            elseif string.find(string.lower(entry.Path or ""), query, 1, true) then
                table.insert(pathResults, entry)
            end
        end
    end
    if #results == 0 then
        results = pathResults
    end
    lib:Label(header, #results .. (#results == 1 and " RESULT" or " RESULTS"), 11, "Medium", "TextMuted", { Position = UDim2.fromOffset(2, 0) })

    for i, entry in ipairs(results) do
        if i > 60 then
            break
        end
        local row = New("TextButton", {
            AutoButtonColor = false,
            Text = "",
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 0.15,
            LayoutOrder = i,
            ZIndex = 3,
            Parent = page,
        })
        lib:Bind(row, { BackgroundColor3 = "Card" })
        Corner(4, row)
        lib:Bind(Stroke(row), { Color = "CardStroke" })
        lib:Label(row, entry.Element.Text, 12, "Regular", "Text", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.5, -14, 1, 0), ZIndex = 4 })
        lib:Label(row, entry.Path, 11, "Regular", "TextDim", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -36, 0, 0),
            Size = UDim2.new(0.5, -20, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 4,
        })
        local chev = lib:ThemedIcon("chevron-right", 12, "TextDim", row)
        chev.Frame.AnchorPoint = Vector2.new(1, 0.5)
        chev.Frame.Position = UDim2.new(1, -14, 0.5, 0)
        DeepZ(chev.Frame, 4)
        row.MouseEnter:Connect(function()
            lib:Tween(row, { BackgroundColor3 = lib.Theme.ElementHover }, 0.12)
        end)
        row.MouseLeave:Connect(function()
            lib:Tween(row, { BackgroundColor3 = lib.Theme.Card }, 0.12)
        end)
        row.MouseButton1Click:Connect(function()
            self:Reveal(entry.Element)
        end)
    end
    if #results == 0 then
        local empty = New("Frame", { BackgroundTransparency = 0.15, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1, Parent = page })
        lib:Bind(empty, { BackgroundColor3 = "Card" })
        Corner(4, empty)
        lib:Bind(Stroke(empty), { Color = "CardStroke" })
        lib:Label(empty, "No functions match \"" .. query .. "\".", 11, "Regular", "TextDim", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0) })
    end
end

-- Jumps to an element: clears the search, opens its tab and sub tab, scrolls to it and flashes it.
function Window:Reveal(element)
    local lib = self.Library
    local entry
    for _, e in ipairs(lib.Searchables) do
        if e.Element == element then
            entry = e
        end
    end
    if not entry then
        return
    end
    self.SearchBox.Text = ""
    entry.SubTab.Tab:Select()
    entry.SubTab:Select()
    task.defer(function()
        local row = element.Row
        local scroll = entry.SubTab.Page.Scroll
        if not row or not row.Parent then
            return
        end
        local offset = row.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 60
        scroll.CanvasPosition = Vector2.new(0, math.max(0, offset))
        local flash = New("Frame", {
            BackgroundColor3 = lib.Theme.Accent,
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(-8, 0),
            Size = UDim2.new(1, 16, 1, 0),
            ZIndex = 1,
            Parent = row,
        })
        Corner(4, flash)
        lib:Tween(flash, { BackgroundTransparency = 1 }, 1.4, Enum.EasingStyle.Sine)
        task.delay(1.5, function()
            flash:Destroy()
        end)
    end)
end

--------------------------------------------------------------------------------
-- Tabs (sidebar) and sub tabs (centred bar under the search)
--------------------------------------------------------------------------------
local function NewPage(window)
    local lib = window.Library
    local scroll = New("ScrollingFrame", {
        Name = "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.fromScale(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        ZIndex = 3,
        Parent = window.PageHolder,
    })
    lib:Bind(scroll, { ScrollBarImageColor3 = "CardStroke" })
    Padding(scroll, 13, PAGE_PAD, 16, PAGE_PAD)
    local inner = New("Frame", {
        Name = "Inner",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = scroll,
    })
    local half = COLUMN_GAP / 2
    local left = New("Frame", {
        Name = "Left",
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -half, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = inner,
    })
    List(left, 15)
    local right = New("Frame", {
        Name = "Right",
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, half, 0, 0),
        Size = UDim2.new(0.5, -half, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = inner,
    })
    List(right, 15)
    return { Scroll = scroll, Inner = inner, Left = left, Right = right, Window = window, Count = 0 }
end

local function ShowPage(window, page)
    local lib = window.Library
    if window.ActivePage == page then
        return
    end
    lib:CloseAllPopups(true)
    if window.ActivePage then
        window.ActivePage.Scroll.Visible = false
    end
    window.ActivePage = page
    if page then
        page.Scroll.Visible = not window.SearchPage.Visible
        page.Inner.Position = UDim2.fromOffset(0, 8)
        lib:Tween(page.Inner, { Position = UDim2.fromOffset(0, 0) }, 0.3, Enum.EasingStyle.Quint)
    end
end

function Window:AddTab(opts)
    opts = opts or {}
    if type(opts) == "string" then
        opts = { Name = opts }
    end
    local lib = self.Library
    local tab = setmetatable({
        Window = self,
        Name = opts.Name or ("Tab " .. (#self.Tabs + 1)),
        Icon = opts.Icon or "dots",
        SubTabs = {},
    }, Tab)
    table.insert(self.Tabs, tab)

    local button = New("TextButton", {
        Name = "Tab_" .. tab.Name,
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
        BackgroundTransparency = 1,
        LayoutOrder = #self.Tabs,
        ZIndex = 4,
        Parent = self.TabHolder,
    })
    lib:Bind(button, { BackgroundColor3 = "Outline" })
    local bar = New("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = button,
    })
    lib:Bind(bar, { BackgroundColor3 = "Accent" })
    local icon = Icons.Create(tab.Icon, 15, lib.Theme.TextMuted, button)
    icon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Frame.Position = UDim2.new(0, 30, 0.5, 0)
    DeepZ(icon.Frame, 5)
    local label = lib:Label(button, tab.Name, 12, "Regular", nil, {
        Position = UDim2.fromOffset(47, 0),
        Size = UDim2.new(1, -55, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = lib.Theme.TextMuted,
        ZIndex = 5,
    })
    tab.Button, tab.Bar, tab.IconObj, tab.Label = button, bar, icon, label

    button.MouseEnter:Connect(function()
        tab.Hover = true
        tab:_refreshButton()
    end)
    button.MouseLeave:Connect(function()
        tab.Hover = false
        tab:_refreshButton()
    end)
    button.MouseButton1Click:Connect(function()
        if self.SearchBox.Text ~= "" then
            self.SearchBox.Text = ""
        end
        tab:Select()
    end)
    lib:AddRefresher(function()
        tab:_refreshButton()
    end)

    -- this tab's group of items in the sub tab bar
    local group = New("Frame", {
        Name = "Group_" .. tab.Name,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Visible = false,
        ZIndex = 3,
        Parent = self.SubBar,
    })
    List(group, 0, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    tab.Group = group

    tab:_refreshButton()
    if not self.ActiveTab then
        tab:Select()
    end
    return tab
end

function Tab:_refreshButton()
    local lib = self.Window.Library
    local th = lib.Theme
    local active = self.Window.ActiveTab == self
    lib:Tween(self.Button, { BackgroundTransparency = active and 0.965 or (self.Hover and 0.985 or 1) }, 0.18)
    lib:Tween(self.Bar, { BackgroundTransparency = active and 0 or 1 }, 0.18)
    local color = active and th.Text or (self.Hover and Mix(th.TextMuted, th.Text, 0.5) or th.TextMuted)
    lib:Tween(self.Label, { TextColor3 = color }, 0.18)
    self.IconObj.SetColor(color)
end

function Tab:Select()
    local window = self.Window
    window.ActiveTab = self
    for _, t in ipairs(window.Tabs) do
        t:_refreshButton()
        t.Group.Visible = t == self
    end
    local sub = self.ActiveSubTab or self.SubTabs[1]
    if sub then
        sub:Select()
    else
        ShowPage(window, nil)
    end
end

-- Tabs without sub tabs still show one centred item (like "World" or "Configs").
function Tab:_implicitSubTab()
    if #self.SubTabs == 0 then
        local sub = self:AddSubTab({ Name = self.Name, Icon = self.Icon })
        sub.Implicit = true
    end
    return self.SubTabs[1]
end

function Tab:AddSubTab(opts)
    opts = opts or {}
    if type(opts) == "string" then
        opts = { Name = opts }
    end
    local window = self.Window
    local lib = window.Library
    local sub = setmetatable({ Tab = self, Window = window, Name = opts.Name or "Sub", Icon = opts.Icon or "dots" }, SubTab)
    sub.Page = NewPage(window)
    sub.Page.SubTab = sub
    table.insert(self.SubTabs, sub)

    local button = New("TextButton", {
        Name = "Sub_" .. sub.Name,
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(opts.Width or 92, SUBTAB_HEIGHT),
        LayoutOrder = #self.SubTabs,
        ZIndex = 3,
        Parent = self.Group,
    })
    local icon = Icons.Create(sub.Icon, 14, lib.Theme.TextDim, button)
    icon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Frame.Position = UDim2.new(0.5, 0, 0, 24)
    DeepZ(icon.Frame, 4)
    local label = lib:Label(button, sub.Name, 11, "Regular", nil, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 45),
        Size = UDim2.new(1, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = lib.Theme.TextDim,
        ZIndex = 4,
    })
    local underline = New("Frame", {
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -1),
        Size = UDim2.new(0, 0, 0, 2),
        ZIndex = 4,
        Parent = button,
    })
    lib:Bind(underline, { BackgroundColor3 = "Accent" })
    sub.Button, sub.IconObj, sub.Label, sub.Underline = button, icon, label, underline
    if lib:_textWidth(sub.Name, 11) + 28 > button.Size.X.Offset then
        button.Size = UDim2.fromOffset(lib:_textWidth(sub.Name, 11) + 28, SUBTAB_HEIGHT)
    end

    button.MouseEnter:Connect(function()
        sub.Hover = true
        sub:_refreshButton()
    end)
    button.MouseLeave:Connect(function()
        sub.Hover = false
        sub:_refreshButton()
    end)
    button.MouseButton1Click:Connect(function()
        sub:Select()
    end)
    lib:AddRefresher(function()
        sub:_refreshButton()
    end)

    if not self.ActiveSubTab then
        self.ActiveSubTab = sub
    end
    sub:_refreshButton()
    if window.ActiveTab == self and self.ActiveSubTab == sub then
        ShowPage(window, sub.Page)
    end
    return sub
end

function Library:_textWidth(text, size)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, Enum.Font.Gotham, Vector2.new(10000, 100))
    end)
    if ok and bounds then
        return bounds.X
    end
    return string.len(text) * size * 0.55
end

function SubTab:_refreshButton()
    local lib = self.Window.Library
    local th = lib.Theme
    local active = self.Tab.ActiveSubTab == self
    local color = active and th.Text or (self.Hover and th.TextMuted or th.TextDim)
    lib:Tween(self.Label, { TextColor3 = color }, 0.18)
    self.IconObj.SetColor(color)
    lib:Tween(self.Underline, { Size = active and UDim2.new(1, 0, 0, 2) or UDim2.new(0, 0, 0, 2) }, 0.25, Enum.EasingStyle.Quint)
end

function SubTab:Select()
    local tab = self.Tab
    tab.ActiveSubTab = self
    for _, s in ipairs(tab.SubTabs) do
        s:_refreshButton()
    end
    if self.Window.ActiveTab == tab then
        ShowPage(self.Window, self.Page)
    end
end

-- Section: uppercase header with an icon, then a bordered card holding the rows.
local function PageAddSection(page, opts)
    if type(opts) == "string" then
        opts = { Name = opts }
    end
    opts = opts or {}
    local window = page.Window
    local lib = window.Library
    local side = opts.Side
    if side == nil then
        page.Count = page.Count + 1
        side = (page.Count % 2 == 1) and "Left" or "Right"
    end
    local column = (side == "Right" or side == 2) and page.Right or page.Left

    local frame = New("Frame", {
        Name = "Section_" .. tostring(opts.Name),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #column:GetChildren(),
        ZIndex = 3,
        Parent = column,
    })
    List(frame, 8)

    local header = New("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 1, ZIndex = 3, Parent = frame })
    local icon = lib:ThemedIcon(opts.Icon or "dots", 13, "TextDim", header)
    icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
    icon.Frame.Position = UDim2.new(0, 3, 0.5, 0)
    DeepZ(icon.Frame, 3)
    local title = lib:Label(header, string.upper(opts.Name or "Section"), 11, "Medium", "TextMuted", {
        Position = UDim2.fromOffset(26, 0),
        Size = UDim2.new(1, -26, 1, 0),
        ZIndex = 3,
    })

    local card = New("Frame", {
        Name = "Card",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 0.12,
        LayoutOrder = 2,
        ZIndex = 3,
        Parent = frame,
    })
    lib:Bind(card, { BackgroundColor3 = "Card" })
    Corner(4, card)
    lib:Bind(Stroke(card), { Color = "CardStroke" })
    Padding(card, opts.PaddingTop or 5, 14, opts.PaddingBottom or 5, 14)
    List(card, 0)

    local section = Container.new(window, card, opts.Name)
    section.Section = frame
    section.TitleLabel = title
    section.Page = page
    section.SubTab = page.SubTab

    function section:SetTitle(text)
        title.Text = string.upper(text)
    end
    function section:SetVisible(state)
        frame.Visible = state and true or false
    end
    return section
end

function SubTab:AddSection(opts)
    return PageAddSection(self.Page, opts)
end
SubTab.AddGroupbox = SubTab.AddSection
function SubTab:AddLeftGroupbox(name, icon)
    return PageAddSection(self.Page, { Name = name, Icon = icon, Side = "Left" })
end
function SubTab:AddRightGroupbox(name, icon)
    return PageAddSection(self.Page, { Name = name, Icon = icon, Side = "Right" })
end

function Tab:AddSection(opts)
    local sub = self.SubTabs[1] or self:_implicitSubTab()
    return sub:AddSection(opts)
end
Tab.AddGroupbox = Tab.AddSection
function Tab:AddLeftGroupbox(name, icon)
    return self:AddSection({ Name = name, Icon = icon, Side = "Left" })
end
function Tab:AddRightGroupbox(name, icon)
    return self:AddSection({ Name = name, Icon = icon, Side = "Right" })
end

--------------------------------------------------------------------------------
-- Container (sections and popovers share every element builder)
--------------------------------------------------------------------------------
function Container.new(window, frame, name)
    return setmetatable({
        Window = window,
        Library = window.Library,
        Frame = frame,
        Name = name or "Container",
        Order = 1,
        Elements = {},
        LastKind = nil,
    }, Container)
end

function Container:_row(height, kind)
    self.Order = self.Order + 1
    local row = New("Frame", {
        Name = kind or "Row",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 32),
        LayoutOrder = self.Order,
        ZIndex = 3,
        Parent = self.Frame,
    })
    self.LastKind = kind
    return row
end

-- Right aligned holder for keybinds, colour swatches and the checkbox.
function Container:_addonHolder(row)
    local holder = New("Frame", {
        Name = "Addons",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 4,
        Parent = row,
    })
    List(holder, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    return holder
end

function Container:SetVisible(state)
    if self.Section then
        self.Section.Visible = state and true or false
    else
        self.Frame.Visible = state and true or false
    end
end

--------------------------------------------------------------------------------
-- Element base
--------------------------------------------------------------------------------
local Element = {}
Element.__index = Element

local function Class()
    local c = setmetatable({}, { __index = Element })
    c.__index = c
    return c
end

Library.RainbowPickers = {}
local AutoFlagCount = {}

-- Supports ("Flag", { ... }), ({ Flag = "...", ... }) and ("Text", callback).
local function FlagOpts(a, b)
    if type(a) == "table" then
        return a
    end
    if type(a) == "string" and type(b) == "table" then
        b.Flag = b.Flag or a
        return b
    end
    if type(a) == "string" then
        return { Text = a, Callback = type(b) == "function" and b or nil }
    end
    return {}
end

local function TextOpts(a, b)
    if type(a) == "table" then
        return a
    end
    local opts = type(b) == "table" and b or {}
    if type(b) == "function" then
        opts.Callback = b
    end
    opts.Text = opts.Text or a
    return opts
end

function Element:_init(container, kind, opts)
    self.Library = Library
    self.Container = container
    self.Window = container.Window
    self.Kind = kind
    self.Options = opts
    self._listeners = {}
    self.Locked = opts.Disabled == true
    self.Dimmed = self.Locked
    self.Visible = true
    self.Text = opts.Text or opts.Name or opts.Title or ""
    self.Callback = opts.Callback
    self.NoSave = opts.NoSave
    table.insert(container.Elements, self)
end

function Element:_register()
    local flag = self.Options.Flag or self.Options.Idx
    if not flag then
        local base = tostring(self.Container.Name or "") .. "/" .. (self.Text ~= "" and self.Text or self.Kind)
        local n = (AutoFlagCount[base] or 0) + 1
        AutoFlagCount[base] = n
        flag = n == 1 and base or (base .. "#" .. n)
    end
    self.Flag = flag
    Library.Options[flag] = self
    Library.Flags[flag] = self:_flagValue()
end

function Element:_flagValue()
    return self.Value
end

function Element:Get()
    return self.Value
end

function Element:_emit()
    if Library.Unloaded then
        return
    end
    if self.Flag then
        Library.Flags[self.Flag] = self:_flagValue()
    end
    local args = { self:Get() }
    local n = select("#", self:Get())
    SafeCall(self.Callback, unpack(args, 1, n))
    for _, fn in ipairs(self._listeners) do
        SafeCall(fn, unpack(args, 1, n))
    end
end

function Element:OnChanged(fn)
    table.insert(self._listeners, fn)
    local listeners = self._listeners
    return {
        Disconnect = function()
            for i, f in ipairs(listeners) do
                if f == fn then
                    table.remove(listeners, i)
                    break
                end
            end
        end,
    }
end

function Element:SetVisible(state)
    self.Visible = state and true or false
    if self.Row then
        self.Row.Visible = self.Visible
    end
end

function Element:SetDimmed(state)
    self.Dimmed = (state and true or false) or self.Locked
    self:_refresh()
end

function Element:SetDisabled(state)
    self.Locked = state and true or false
    self.Dimmed = self.Locked
    self:_refresh()
end

function Element:SetText(text)
    self.Text = tostring(text)
    if self.Label then
        self.Label.Text = self.Text
    end
end

function Element:SetTooltip(text)
    if self.Row then
        Library:AttachTooltip(self.Row, text)
    end
end

function Element:_refresh() end

-- DependsOn = "Flag" | controller | { ... }: dims the element while any dependency is off.
function Element:_bindDepends(dep)
    local deps = (type(dep) == "table" and dep.Get == nil) and dep or { dep }
    local function resolve(d)
        if type(d) == "string" then
            return Library.Options[d]
        end
        return d
    end
    local function update()
        local ok = true
        for _, d in ipairs(deps) do
            local c = resolve(d)
            if c and not c:Get() then
                ok = false
            end
        end
        self.Dimmed = (not ok) or self.Locked
        self:_refresh()
    end
    for _, d in ipairs(deps) do
        local c = resolve(d)
        if c then
            c:OnChanged(update)
        end
    end
    update()
end

function Element:_searchable()
    local container = self.Container
    local sub = container.SubTab
    if not sub or self.Options.Searchable == false or self.Text == "" then
        return
    end
    local path = sub.Tab.Name
    if not sub.Implicit then
        path = path .. " › " .. sub.Name
    end
    path = path .. " › " .. tostring(container.Name)
    table.insert(Library.Searchables, { Element = self, Window = self.Window, SubTab = sub, Path = path })
    self.Window:_queueSearchCount()
end

function Element:_finish(register)
    if register then
        self:_register()
    end
    Library:AddRefresher(function()
        if self.Row and self.Row.Parent then
            self:_refresh()
        end
    end)
    if self.Options.Tooltip and self.Row then
        Library:AttachTooltip(self.Row, self.Options.Tooltip)
    end
    if self.Options.DependsOn then
        self:_bindDepends(self.Options.DependsOn)
    end
    if self.Options.Visible == false then
        self:SetVisible(false)
    end
    self:_searchable()
    self:_refresh()
    return self
end

function Element:_serialize()
    return self:_flagValue()
end

function Element:_deserialize(v)
    self:Set(v)
end

function Element:Destroy()
    if self.Row then
        self.Row:Destroy()
    end
    if self.Flag then
        Library.Options[self.Flag] = nil
        Library.Flags[self.Flag] = nil
    end
    if self.Window then
        self.Window:_queueSearchCount()
    end
end

local function NextAddonOrder(holder)
    local n = (holder:GetAttribute("Count") or 0) + 1
    holder:SetAttribute("Count", n)
    return n
end

local function Checker(parent, width, height, cell, zindex)
    local holder = New("Frame", {
        Name = "Checker",
        BackgroundColor3 = Color3.fromRGB(220, 220, 220),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
        ZIndex = zindex or 1,
        Parent = parent,
    })
    for y = 0, math.ceil(height / cell) - 1 do
        for x = 0, math.ceil(width / cell) - 1 do
            if (x + y) % 2 == 0 then
                New("Frame", {
                    BackgroundColor3 = Color3.fromRGB(150, 150, 150),
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(x * cell, y * cell),
                    Size = UDim2.fromOffset(cell, cell),
                    ZIndex = zindex or 1,
                    Parent = holder,
                })
            end
        end
    end
    return holder
end

--------------------------------------------------------------------------------
-- Keybind picker (Toggle / Hold / Always, MB1-MB3, Backspace or Escape clears)
--------------------------------------------------------------------------------
local KeyPicker = Class()

local function BuildKeyPicker(container, holder, opts, parent)
    local p = setmetatable({}, KeyPicker)
    p:_init(container, "Keybind", opts)
    p.Text = opts.Text or (parent and parent.Text) or "Keybind"
    p.Key = NormalizeKey(opts.Default or opts.Key or "None")
    p.Mode = opts.Mode or "Toggle"
    p.Modes = opts.Modes or { "Toggle", "Hold", "Always" }
    p.Parent = parent
    p.IsMenuKey = opts.IsMenuKey == true
    p.IsPanicKey = opts.IsPanicKey == true
    p.ShowInList = opts.ShowInList ~= false and not p.IsMenuKey and not p.IsPanicKey
    p.Active = false
    p.Pressed = opts.Pressed or opts.Clicked
    p.ChangedCallback = opts.ChangedCallback

    -- chips attached to a toggle stay quiet until hovered; standalone ones keep a faint box
    local restT = parent and 0.85 or 0.35
    local chip = New("TextButton", {
        Name = "Keybind",
        AutoButtonColor = false,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 22),
        BackgroundTransparency = restT,
        Text = KeyName(p.Key),
        TextSize = 11,
        FontFace = Font_("Medium"),
        LayoutOrder = opts.LayoutOrder or NextAddonOrder(holder),
        ZIndex = 5,
        Parent = holder,
    })
    Library:Bind(chip, { BackgroundColor3 = "Field" })
    Corner(4, chip)
    Padding(chip, 0, 8, 0, 8)
    New("UISizeConstraint", { MinSize = Vector2.new(opts.MinWidth or 30, 22), Parent = chip })
    p.Chip = chip
    p.Row = parent and parent.Row or holder

    chip.MouseButton1Click:Connect(function()
        if p.Locked then
            return
        end
        if Library.CapturingPicker and Library.CapturingPicker ~= p then
            local other = Library.CapturingPicker
            other._capturing = false
            other:_refresh()
        end
        p._capturing = true
        p._captureStart = os.clock()
        Library.CapturingPicker = p
        p:_refresh()
    end)
    chip.MouseButton2Click:Connect(function()
        if p.Locked or p.IsMenuKey or p.IsPanicKey or #p.Modes < 2 then
            return
        end
        p:OpenModeMenu()
    end)
    chip.MouseEnter:Connect(function()
        Library:Tween(chip, { BackgroundTransparency = 0 }, 0.12)
    end)
    chip.MouseLeave:Connect(function()
        Library:Tween(chip, { BackgroundTransparency = restT }, 0.12)
    end)
    if not p.IsMenuKey and not p.IsPanicKey and opts.Tooltip == nil then
        Library:AttachTooltip(chip, function()
            return "Click to rebind, right click for mode (" .. p.Mode .. ")"
        end)
    end

    table.insert(Library.Keybinds, p)
    if p.IsMenuKey then
        Library.MenuKey = p.Key
    end
    if p.IsPanicKey then
        Library.PanicKey = p.Key ~= "None" and p.Key or nil
    end
    if p.Mode == "Always" then
        p.Active = true
    end
    p:_finish(true)
    Library:_refreshKeybindList()
    return p
end

function KeyPicker:_flagValue()
    return { Key = self.Key, Mode = self.Mode }
end

function KeyPicker:Get()
    return self.Key, self.Mode
end

function KeyPicker:GetDisplayName()
    return self.Text
end

-- Whether the bound feature is currently active (respects the mode and the parent toggle).
function KeyPicker:GetState()
    local parentOn = (not self.Parent) or self.Parent.Value
    if self.Mode == "Always" then
        return parentOn and true or false
    elseif self.Mode == "Hold" then
        return (self.Active and parentOn) and true or false
    end
    if self.Parent then
        return self.Parent.Value and true or false
    end
    return self.Active
end

function KeyPicker:_emitBind()
    if self.Flag then
        Library.Flags[self.Flag] = self:_flagValue()
    end
    SafeCall(self.ChangedCallback, self.Key, self.Mode)
    for _, fn in ipairs(self._listeners) do
        SafeCall(fn, self.Key, self.Mode)
    end
end

function KeyPicker:_stateChanged()
    SafeCall(self.Callback, self:GetState())
    Library:_refreshKeybindList()
end

function KeyPicker:SetKey(key)
    self.Key = NormalizeKey(key)
    if self.IsMenuKey then
        Library.MenuKey = self.Key
    end
    if self.IsPanicKey then
        Library.PanicKey = self.Key ~= "None" and self.Key or nil
    end
    self:_refresh()
    self:_emitBind()
    Library:_refreshKeybindList()
end

function KeyPicker:SetMode(mode)
    if not Find(self.Modes, mode) then
        return
    end
    self.Mode = mode
    self.Active = mode == "Always"
    self:_refresh()
    self:_emitBind()
    self:_stateChanged()
end

function KeyPicker:Set(key, mode)
    if type(key) == "table" then
        key, mode = key.Key or key[1], key.Mode or key[2]
    end
    if mode and Find(self.Modes, mode) then
        self.Mode = mode
        self.Active = mode == "Always"
    end
    self:SetKey(key or self.Key)
end

function KeyPicker:_deserialize(v)
    if type(v) == "table" then
        self:Set(v.Key, v.Mode)
    elseif type(v) == "string" then
        self:SetKey(v)
    end
end

function KeyPicker:SetVisible(state)
    self.Visible = state and true or false
    self.Chip.Visible = self.Visible
    Library:_refreshKeybindList()
end

function KeyPicker:_onInput(down)
    if self.IsMenuKey or self.IsPanicKey or self.Locked then
        return
    end
    if down then
        SafeCall(self.Pressed)
    end
    if self.Mode == "Toggle" then
        if down then
            if self.Parent then
                self.Parent:Set(not self.Parent.Value)
            else
                self.Active = not self.Active
            end
            self:_stateChanged()
        end
    elseif self.Mode == "Hold" then
        if self.Active ~= down then
            self.Active = down
            self:_stateChanged()
        end
    end
end

function KeyPicker:_refresh()
    local th = Library.Theme
    self.Chip.Text = self._capturing and "..." or KeyName(self.Key)
    local color = th.Text
    if self.Dimmed then
        color = th.TextFaint
    elseif self._capturing then
        color = th.Accent
    elseif self.Parent and not self.Parent.Value then
        color = th.TextMuted
    end
    self.Chip.TextColor3 = color
    if self.Label then
        self.Label.TextColor3 = self.Dimmed and th.TextFaint or th.Text
    end
end

function KeyPicker:OpenModeMenu()
    local th = Library.Theme
    local width, itemH = 100, 26
    local height = #self.Modes * itemH + 8
    local z = 120 + #Library.PopupStack * 10
    local frame = New("Frame", {
        Name = "KeybindModes",
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = th.Popup,
        ZIndex = z,
        Parent = Library.Overlay,
    })
    Corner(5, frame)
    Stroke(frame, th.CardStroke)
    Padding(frame, 4, 4, 4, 4)
    List(frame, 0)
    for i, mode in ipairs(self.Modes) do
        local item = New("TextButton", {
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, itemH),
            BackgroundColor3 = th.Outline,
            BackgroundTransparency = 1,
            Text = mode,
            TextSize = 11,
            FontFace = Font_(mode == self.Mode and "Medium" or "Regular"),
            TextColor3 = mode == self.Mode and th.Text or th.TextMuted,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = i,
            ZIndex = z + 1,
            Parent = frame,
        })
        Corner(4, item)
        Padding(item, 0, 8, 0, 8)
        item.MouseEnter:Connect(function()
            item.BackgroundTransparency = 0.95
        end)
        item.MouseLeave:Connect(function()
            item.BackgroundTransparency = 1
        end)
        item.MouseButton1Click:Connect(function()
            self:SetMode(mode)
            Library:ClosePopupFrame(frame)
        end)
    end
    Library:OpenPopup(frame, self.Chip, nil, function()
        Library:PlacePopup(frame, self.Chip, width, height, 4)
    end)
end

--------------------------------------------------------------------------------
-- Colour picker (SV canvas, hue, alpha, hex / RGB, rainbow, copy / paste)
--------------------------------------------------------------------------------
local ColorPicker = Class()

local RainbowSequence = CS({
    { 0, Color3.fromHSV(0, 1, 1) },
    { 1 / 6, Color3.fromHSV(1 / 6, 1, 1) },
    { 2 / 6, Color3.fromHSV(2 / 6, 1, 1) },
    { 3 / 6, Color3.fromHSV(3 / 6, 1, 1) },
    { 4 / 6, Color3.fromHSV(4 / 6, 1, 1) },
    { 5 / 6, Color3.fromHSV(5 / 6, 1, 1) },
    { 1, Color3.fromHSV(1, 1, 1) },
})

local function BuildColorPicker(container, holder, opts, parent)
    local c = setmetatable({}, ColorPicker)
    c:_init(container, "ColorPicker", opts)
    c.Text = opts.Title or opts.Text or (parent and parent.Text) or "Color"
    local color = opts.Default or Color3.new(1, 1, 1)
    if type(color) == "string" then
        color = HexToColor(color) or Color3.new(1, 1, 1)
    end
    c.H, c.S, c.V = color:ToHSV()
    c.Value = color
    c.Transparency = opts.Transparency or 0
    c.HasAlpha = opts.Transparency ~= nil
    c.Rainbow = opts.Rainbow == true
    c.Parent = parent

    local swatch = New("TextButton", {
        Name = "Swatch",
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromOffset(opts.Width or 16, 16),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = opts.LayoutOrder or NextAddonOrder(holder),
        ZIndex = 5,
        Parent = holder,
    })
    Corner(3, swatch)
    local checker = Checker(swatch, opts.Width or 16, 16, 4, 5)
    Corner(3, checker)
    local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 6, Parent = swatch })
    Corner(3, fill)
    c.FillStroke = Stroke(fill, Color3.new(1, 1, 1), 0.88)
    c.Swatch, c.Fill = swatch, fill
    c.Row = parent and parent.Row or holder

    swatch.MouseButton1Click:Connect(function()
        if c.Locked then
            return
        end
        c:Open()
    end)
    if opts.Tooltip == nil then
        Library:AttachTooltip(swatch, function()
            return ColorToHex(c.Value) .. (c.HasAlpha and (" · " .. math.floor((1 - c.Transparency) * 100 + 0.5) .. "%") or "")
        end)
    end

    table.insert(Library.RainbowPickers, c)
    c:_finish(true)
    return c
end

function ColorPicker:Get()
    return self.Value, self.Transparency
end

function ColorPicker:_flagValue()
    return self.Value
end

function ColorPicker:_serialize()
    return { Hex = ColorToHex(self.Value), Transparency = self.Transparency, Rainbow = self.Rainbow }
end

function ColorPicker:_deserialize(v)
    if type(v) == "table" then
        self.Rainbow = v.Rainbow == true
        self:Set(HexToColor(v.Hex) or self.Value, v.Transparency)
    elseif type(v) == "string" then
        self:Set(HexToColor(v) or self.Value)
    end
end

function ColorPicker:_setHSV(h, s, v)
    self.H, self.S, self.V = h, s, v
    self.Value = Color3.fromHSV(h, s, v)
    self:_refresh()
    self:_updatePopup()
    self:_emit()
end

function ColorPicker:Set(color, transparency)
    if type(color) == "string" then
        color = HexToColor(color)
    end
    if typeof(color) == "Color3" then
        local h, s, v = color:ToHSV()
        if s == 0 or v == 0 then
            h = self.H
        end
        if v == 0 then
            s = self.S
        end
        if transparency ~= nil then
            self.Transparency = Clamp(transparency, 0, 1)
        end
        self:_setHSV(h, s, v)
    elseif transparency ~= nil then
        self:SetTransparency(transparency)
    end
end
ColorPicker.SetValueRGB = ColorPicker.Set

function ColorPicker:SetTransparency(t)
    self.Transparency = Clamp(t or 0, 0, 1)
    self:_refresh()
    self:_updatePopup()
    self:_emit()
end

function ColorPicker:SetRainbow(state)
    self.Rainbow = state and true or false
    self:_updatePopup()
end

function ColorPicker:_refresh()
    self.Fill.BackgroundColor3 = self.Value
    local t = self.Transparency
    if self.Dimmed then
        t = math.max(t, 0.6)
    end
    self.Fill.BackgroundTransparency = t
    if self.Label then
        self.Label.TextColor3 = self.Dimmed and Library.Theme.TextFaint or Library.Theme.Text
    end
end

function ColorPicker:_updatePopup()
    local ui = self.UI
    if not ui or not ui.Frame.Parent then
        return
    end
    local th = Library.Theme
    ui.SV.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
    ui.Cursor.Position = UDim2.fromScale(self.S, 1 - self.V)
    ui.HueKnob.Position = UDim2.new(self.H, 0, 0.5, 0)
    ui.Preview.BackgroundColor3 = self.Value
    ui.Preview.BackgroundTransparency = self.Transparency
    if ui.AlphaFill then
        ui.AlphaFill.BackgroundColor3 = self.Value
        ui.AlphaKnob.Position = UDim2.new(self.Transparency, 0, 0.5, 0)
    end
    if not ui.Hex:IsFocused() then
        ui.Hex.Text = ColorToHex(self.Value)
    end
    local rgb = { self.Value.R, self.Value.G, self.Value.B }
    for i, box in ipairs(ui.RGB) do
        if not box:IsFocused() then
            box.Text = tostring(math.floor(rgb[i] * 255 + 0.5))
        end
    end
    ui.RainbowBox.BackgroundColor3 = self.Rainbow and th.Accent or th.Checkbox
    ui.RainbowCheck.SetTransparency(self.Rainbow and 0 or 1)
    ui.RainbowCheck.SetColor(th.AccentText)
    ui.RainbowLabel.TextColor3 = self.Rainbow and th.Text or th.TextMuted
end

function ColorPicker:Open()
    if self.UI and self.UI.Frame.Parent and Library:IsPopupOpen(self.UI.Frame) then
        Library:ClosePopupFrame(self.UI.Frame)
        return
    end
    local th = Library.Theme
    local width, pad = 232, 12
    local inner = width - pad * 2
    local z = 120 + #Library.PopupStack * 10
    local frame = New("Frame", {
        Name = "ColorPicker",
        Size = UDim2.fromOffset(width, 10),
        BackgroundColor3 = th.Popup,
        ZIndex = z,
        Parent = Library.Overlay,
    })
    Corner(6, frame)
    Stroke(frame, th.CardStroke)
    local ui = { Frame = frame }

    Library:Label(frame, self.Text, 12, "Medium", nil, {
        Position = UDim2.fromOffset(pad, 9),
        Size = UDim2.new(1, -pad * 2 - 24, 0, 16),
        TextColor3 = th.Text,
        ZIndex = z + 1,
    })
    local preview = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -pad, 0, 9),
        Size = UDim2.fromOffset(16, 16),
        BorderSizePixel = 0,
        ZIndex = z + 2,
        Parent = frame,
    })
    Corner(3, preview)
    Stroke(preview, Color3.new(1, 1, 1), 0.85)
    ui.Preview = preview
    local y = 34

    local sv = New("TextButton", {
        AutoButtonColor = false,
        Text = "",
        Position = UDim2.fromOffset(pad, y),
        Size = UDim2.fromOffset(inner, 128),
        BackgroundColor3 = Color3.fromHSV(self.H, 1, 1),
        ZIndex = z + 1,
        Parent = frame,
    })
    Corner(4, sv)
    local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = z + 2, Parent = sv })
    Corner(4, white)
    New("UIGradient", { Transparency = NS({ { 0, 0 }, { 1, 1 } }), Parent = white })
    local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = z + 3, Parent = sv })
    Corner(4, black)
    New("UIGradient", { Rotation = 90, Transparency = NS({ { 0, 1 }, { 1, 0 } }), Parent = black })
    local cursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        ZIndex = z + 4,
        Parent = sv,
    })
    Corner(UDim.new(1, 0), cursor)
    New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = cursor })
    ui.SV, ui.Cursor = sv, cursor
    y = y + 128 + 10

    local hue = New("TextButton", {
        AutoButtonColor = false,
        Text = "",
        Position = UDim2.fromOffset(pad, y),
        Size = UDim2.fromOffset(inner, 8),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = z + 1,
        Parent = frame,
    })
    Corner(UDim.new(1, 0), hue)
    New("UIGradient", { Color = RainbowSequence, Parent = hue })
    local hueKnob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = z + 3,
        Parent = hue,
    })
    Corner(UDim.new(1, 0), hueKnob)
    Stroke(hueKnob, Color3.new(0, 0, 0), 0.6)
    ui.HueKnob = hueKnob
    y = y + 8 + 10

    local alpha
    if self.HasAlpha then
        alpha = New("TextButton", {
            AutoButtonColor = false,
            Text = "",
            Position = UDim2.fromOffset(pad, y),
            Size = UDim2.fromOffset(inner, 8),
            BackgroundTransparency = 1,
            ZIndex = z + 1,
            Parent = frame,
        })
        local clip = New("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z + 1, Parent = alpha })
        Corner(UDim.new(1, 0), clip)
        Checker(clip, inner, 8, 4, z + 1)
        local alphaFill = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = self.Value, ZIndex = z + 2, Parent = clip })
        New("UIGradient", { Transparency = NS({ { 0, 0 }, { 1, 1 } }), Parent = alphaFill })
        local alphaKnob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(12, 12),
            BackgroundColor3 = Color3.new(1, 1, 1),
            ZIndex = z + 3,
            Parent = alpha,
        })
        Corner(UDim.new(1, 0), alphaKnob)
        Stroke(alphaKnob, Color3.new(0, 0, 0), 0.6)
        ui.AlphaFill, ui.AlphaKnob = alphaFill, alphaKnob
        y = y + 8 + 10
    end

    local function box(x, w, placeholder)
        local b = New("TextBox", {
            Position = UDim2.fromOffset(pad + x, y),
            Size = UDim2.fromOffset(w, 24),
            BackgroundColor3 = th.Element,
            Text = "",
            PlaceholderText = placeholder,
            PlaceholderColor3 = th.TextFaint,
            TextColor3 = th.Text,
            TextSize = 11,
            FontFace = Font_("Regular"),
            ClearTextOnFocus = false,
            ZIndex = z + 1,
            Parent = frame,
        })
        Corner(4, b)
        Stroke(b, th.ElementStroke)
        return b
    end
    local third = math.floor((inner - 78 - 12) / 3)
    ui.Hex = box(0, 72, "#FFFFFF")
    ui.RGB = { box(78, third, "R"), box(78 + third + 6, third, "G"), box(78 + (third + 6) * 2, third, "B") }
    y = y + 24 + 8

    local rainbow = New("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(pad, y),
        Size = UDim2.fromOffset(100, 24),
        ZIndex = z + 1,
        Parent = frame,
    })
    local rbox = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BorderSizePixel = 0,
        ZIndex = z + 2,
        Parent = rainbow,
    })
    Corner(3, rbox)
    local rcheck = Icons.Create("check", 12, th.AccentText, rbox)
    rcheck.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    rcheck.Frame.Position = UDim2.fromScale(0.5, 0.5)
    DeepZ(rcheck.Frame, z + 3)
    ui.RainbowBox, ui.RainbowCheck = rbox, rcheck
    ui.RainbowLabel = Library:Label(rainbow, "Rainbow", 11, "Regular", nil, {
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -24, 1, 0),
        ZIndex = z + 2,
    })

    local function smallButton(x, iconName, tip)
        local b = New("TextButton", {
            AutoButtonColor = false,
            Text = "",
            Position = UDim2.fromOffset(pad + x, y),
            Size = UDim2.fromOffset(24, 24),
            BackgroundColor3 = th.Element,
            ZIndex = z + 1,
            Parent = frame,
        })
        Corner(4, b)
        Stroke(b, th.ElementStroke)
        local ic = Icons.Create(iconName, 12, th.TextMuted, b)
        ic.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Frame.Position = UDim2.fromScale(0.5, 0.5)
        DeepZ(ic.Frame, z + 2)
        b.MouseEnter:Connect(function()
            ic.SetColor(Library.Theme.Text)
        end)
        b.MouseLeave:Connect(function()
            ic.SetColor(Library.Theme.TextMuted)
        end)
        Library:AttachTooltip(b, tip)
        return b
    end
    local copyButton = smallButton(inner - 54, "copy", "Copy colour")
    local pasteButton = smallButton(inner - 24, "clipboard", "Paste colour")
    y = y + 24 + 12
    frame.Size = UDim2.fromOffset(width, y)

    self.UI = ui
    self:_updatePopup()

    local function dragSV(pos)
        local p, s = sv.AbsolutePosition, sv.AbsoluteSize
        self.Rainbow = false
        self:_setHSV(self.H, Clamp((pos.X - p.X) / math.max(s.X, 1), 0, 1), 1 - Clamp((pos.Y - p.Y) / math.max(s.Y, 1), 0, 1))
    end
    local function dragHue(pos)
        local p, s = hue.AbsolutePosition, hue.AbsoluteSize
        self.Rainbow = false
        self:_setHSV(Clamp((pos.X - p.X) / math.max(s.X, 1), 0, 0.999), self.S, self.V)
    end
    local function dragAlpha(pos)
        local p, s = alpha.AbsolutePosition, alpha.AbsoluteSize
        self:SetTransparency(Clamp((pos.X - p.X) / math.max(s.X, 1), 0, 1))
    end
    local function bindDrag(gui, fn)
        gui.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                fn(Vector2.new(input.Position.X, input.Position.Y))
                Library.ActiveDrag = { Update = fn }
            end
        end)
    end
    bindDrag(sv, dragSV)
    bindDrag(hue, dragHue)
    if alpha then
        bindDrag(alpha, dragAlpha)
    end

    ui.Hex.FocusLost:Connect(function()
        local col = HexToColor(ui.Hex.Text)
        if col then
            self.Rainbow = false
            self:Set(col)
        else
            self:_updatePopup()
        end
    end)
    for i, b in ipairs(ui.RGB) do
        b.FocusLost:Connect(function()
            local n = tonumber(b.Text)
            if n then
                local rgb = { self.Value.R * 255, self.Value.G * 255, self.Value.B * 255 }
                rgb[i] = Clamp(math.floor(n + 0.5), 0, 255)
                self.Rainbow = false
                self:Set(Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
            else
                self:_updatePopup()
            end
        end)
    end
    rainbow.MouseButton1Click:Connect(function()
        self:SetRainbow(not self.Rainbow)
    end)
    copyButton.MouseButton1Click:Connect(function()
        Library.ColorClipboard = { Color = self.Value, Transparency = self.Transparency }
        if type(setclipboard) == "function" then
            pcall(setclipboard, ColorToHex(self.Value))
        end
        Library:Notify({ Title = "Colour copied", Content = ColorToHex(self.Value), Duration = 2, Icon = "copy" })
    end)
    pasteButton.MouseButton1Click:Connect(function()
        local clip = Library.ColorClipboard
        if clip then
            self.Rainbow = false
            self:Set(clip.Color, self.HasAlpha and clip.Transparency or nil)
        end
    end)

    Library:OpenPopup(frame, self.Swatch, function()
        self.UI = nil
        Library.ActiveDrag = nil
    end, function()
        Library:PlacePopup(frame, self.Swatch, width, y, 6)
    end)
end

--------------------------------------------------------------------------------
-- Toggle: label left, addons (keybind, colour) then the checkbox on the right.
-- The label is bright while on and muted while off, like the reference.
--------------------------------------------------------------------------------
local Toggle = Class()

function Container:AddToggle(a, b)
    local opts = FlagOpts(a, b)
    local t = setmetatable({}, Toggle)
    t:_init(self, "Toggle", opts)
    t.Value = opts.Default == true
    t.Keybinds, t.ColorPickers = {}, {}

    local row = self:_row(32, "Toggle")
    t.Row = row
    local click = New("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = row })
    t.ClickArea = click
    t.Label = Library:Label(row, t.Text, 12, "Regular", nil, {
        Size = UDim2.new(1, -110, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })

    local addons = self:_addonHolder(row)
    t.Addons = addons
    local box = New("TextButton", {
        Name = "Checkbox",
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromOffset(16, 16),
        LayoutOrder = 100000,
        ZIndex = 5,
        Parent = addons,
    })
    Corner(3, box)
    t.BoxStroke = Stroke(box, Library.Theme.ElementStroke, 0)
    local check = Icons.Create("check", 12, Library.Theme.AccentText, box)
    check.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    check.Frame.Position = UDim2.fromScale(0.5, 0.5)
    DeepZ(check.Frame, 6)
    t.Box, t.Check = box, check

    local function flip()
        if not t.Locked then
            t:Set(not t.Value)
        end
    end
    click.MouseButton1Click:Connect(flip)
    box.MouseButton1Click:Connect(flip)
    click.MouseEnter:Connect(function()
        t.Hover = true
        t:_refresh()
    end)
    click.MouseLeave:Connect(function()
        t.Hover = false
        t:_refresh()
    end)

    return t:_finish(true)
end
Container.AddCheckbox = Container.AddToggle

function Toggle:Set(value)
    value = value and true or false
    local changed = value ~= self.Value
    self.Value = value
    self:_refresh()
    if changed then
        self:_emit()
        for _, kb in ipairs(self.Keybinds) do
            kb:_refresh()
            SafeCall(kb.Callback, kb:GetState())
        end
        if #self.Keybinds > 0 then
            Library:_refreshKeybindList()
        end
    end
end

function Toggle:_deserialize(v)
    self:Set(v == true)
end

function Toggle:_refresh()
    local th = Library.Theme
    local on, dim = self.Value, self.Dimmed
    local labelColor
    if dim then
        labelColor = th.TextFaint
    elseif on then
        labelColor = th.Text
    else
        labelColor = self.Hover and Mix(th.TextMuted, th.Text, 0.45) or th.TextMuted
    end
    Library:Tween(self.Label, { TextColor3 = labelColor }, 0.15)
    local boxColor = on and th.Accent or th.Checkbox
    if dim then
        boxColor = on and Mix(th.Accent, th.Card, 0.62) or Mix(th.Checkbox, th.Card, 0.4)
    end
    Library:Tween(self.Box, { BackgroundColor3 = boxColor }, 0.15)
    Library:Tween(self.BoxStroke, { Transparency = on and 1 or (dim and 0.6 or 0), Color = th.ElementStroke }, 0.15)
    self.Check.SetColor(dim and Mix(th.AccentText, th.Card, 0.3) or th.AccentText)
    self.Check.SetTransparency(on and 0 or 1)
    for _, kb in ipairs(self.Keybinds or {}) do
        kb.Dimmed = dim
        kb:_refresh()
    end
end

function Toggle:AddKeybind(a, b)
    local opts = FlagOpts(a, b)
    if not opts.Flag and self.Flag then
        opts.Flag = self.Flag .. "_Keybind"
    end
    opts.Searchable = false
    local picker = BuildKeyPicker(self.Container, self.Addons, opts, self)
    table.insert(self.Keybinds, picker)
    self.Keybind = picker
    picker:_refresh()
    return self
end
Toggle.AddKeyPicker = Toggle.AddKeybind

function Toggle:AddColorPicker(a, b)
    local opts = FlagOpts(a, b)
    if not opts.Flag and self.Flag then
        opts.Flag = self.Flag .. "_Color" .. (#self.ColorPickers > 0 and tostring(#self.ColorPickers + 1) or "")
    end
    opts.Searchable = false
    local picker = BuildColorPicker(self.Container, self.Addons, opts, self)
    table.insert(self.ColorPickers, picker)
    self.ColorPicker = picker
    return self
end

--------------------------------------------------------------------------------
-- Label (with optional keybind / colour picker on the right)
--------------------------------------------------------------------------------
local Label = Class()

function Container:AddLabel(a, b)
    local opts = TextOpts(a, b)
    local l = setmetatable({}, Label)
    l:_init(self, "Label", opts)
    l.Value = l.Text
    l.Muted = opts.Muted == true
    local row = self:_row(opts.Height or 32, "Label")
    l.Row = row
    l.Label = Library:Label(row, l.Text, 12, "Regular", nil, {
        Size = UDim2.new(1, -110, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    l.Addons = self:_addonHolder(row)
    return l:_finish(false)
end

function Label:Set(text)
    self.Value = tostring(text)
    self:SetText(self.Value)
end

function Label:_refresh()
    local th = Library.Theme
    self.Label.TextColor3 = self.Dimmed and th.TextFaint or (self.Muted and th.TextMuted or th.Text)
end

function Label:AddKeybind(a, b)
    local opts = FlagOpts(a, b)
    opts.Text = opts.Text or self.Text
    opts.Searchable = false
    local picker = BuildKeyPicker(self.Container, self.Addons, opts, nil)
    picker.Row = self.Row
    self.Keybind = picker
    return self
end
Label.AddKeyPicker = Label.AddKeybind

function Label:AddColorPicker(a, b)
    local opts = FlagOpts(a, b)
    opts.Text = opts.Text or self.Text
    opts.Searchable = false
    local picker = BuildColorPicker(self.Container, self.Addons, opts, nil)
    picker.Row = self.Row
    self.ColorPicker = picker
    return self
end

--------------------------------------------------------------------------------
-- Paragraph / status text (:SetText)
--------------------------------------------------------------------------------
local Paragraph = Class()

function Container:AddParagraph(a, b)
    local opts = TextOpts(a, b)
    local p = setmetatable({}, Paragraph)
    p:_init(self, "Paragraph", opts)
    p.Title = opts.Title
    p.Value = opts.Content or opts.Text or ""
    p.Text = p.Title or ""
    local row = self:_row(0, "Paragraph")
    row.AutomaticSize = Enum.AutomaticSize.Y
    p.Row = row
    List(row, 2)
    Padding(row, opts.Title and 6 or 0, 0, opts.PaddingBottom or 8, 0)
    if p.Title and p.Title ~= "" then
        p.TitleLabel = Library:Label(row, p.Title, 12, "Regular", "Text", {
            Size = UDim2.new(1, 0, 0, 18),
            LayoutOrder = 1,
            ZIndex = 4,
        })
    end
    p.Label = Library:Label(row, p.Value, opts.TextSize or 11, "Regular", nil, {
        Size = UDim2.new(1, 0, 0, 14),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        RichText = opts.RichText == true,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        ZIndex = 4,
    })
    return p:_finish(false)
end

function Container:AddDescription(text)
    return self:AddParagraph({ Content = text })
end

function Paragraph:Set(text, title)
    self.Value = tostring(text)
    self.Label.Text = self.Value
    if title and self.TitleLabel then
        self.TitleLabel.Text = title
    end
end
Paragraph.SetText = Paragraph.Set

function Paragraph:_refresh()
    self.Label.TextColor3 = self.Dimmed and Library.Theme.TextFaint or Library.Theme.TextDim
end

--------------------------------------------------------------------------------
-- Divider
--------------------------------------------------------------------------------
local Divider = Class()

function Container:AddDivider(opts)
    opts = opts or {}
    local d = setmetatable({}, Divider)
    d:_init(self, "Divider", opts)
    local row = self:_row(opts.Height or 13, "Divider")
    d.Row = row
    local line = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = row,
    })
    Library:Bind(line, { BackgroundColor3 = "CardStroke" })
    return d:_finish(false)
end

function Divider:Set() end

function Container:AddSpacer(height)
    return self:_row(height or 8, "Spacer")
end

--------------------------------------------------------------------------------
-- Slider: "Label • value" header, thin track, round knob(s). Supports ranges,
-- suffixes, increments (1 / 0.1 / 0.01) and click-to-type on the value.
--------------------------------------------------------------------------------
local Slider = Class()

local function FormatNumber(v, increment, suffix)
    local dec = Decimals(increment)
    return string.format("%." .. dec .. "f", v) .. (suffix or "")
end

function Container:AddSlider(a, b)
    local opts = FlagOpts(a, b)
    local s = setmetatable({}, Slider)
    s:_init(self, "Slider", opts)
    s.Min = opts.Min or 0
    s.Max = opts.Max or 100
    local inc = opts.Increment
    if not inc and type(opts.Rounding) == "number" then
        -- Rounding >= 1 means decimal places, a fraction means step size
        if opts.Rounding >= 1 or opts.Rounding == 0 then
            inc = 10 ^ -math.floor(opts.Rounding)
        else
            inc = opts.Rounding
        end
    end
    s.Increment = inc or 1
    s.Suffix = opts.Suffix or ""
    s.Separator = opts.Separator or " – "
    s.Range = opts.Range == true or type(opts.Default) == "table"
    if s.Range then
        local d = opts.Default or { s.Min, s.Max }
        s.Value = { Clamp(Round(d[1], s.Increment), s.Min, s.Max), Clamp(Round(d[2], s.Increment), s.Min, s.Max) }
    else
        s.Value = Clamp(Round(opts.Default or s.Min, s.Increment), s.Min, s.Max)
    end

    local row = self:_row(46, "Slider")
    s.Row = row
    local head = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 16), ZIndex = 4, Parent = row })
    List(head, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    s.Label = Library:Label(head, s.Text, 12, "Regular", nil, {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 1,
        ZIndex = 4,
    })
    s.Dot = New("Frame", { Size = UDim2.fromOffset(3, 3), BorderSizePixel = 0, LayoutOrder = 2, ZIndex = 4, Parent = head })
    Corner(UDim.new(1, 0), s.Dot)
    local valueButton = New("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        Text = "",
        TextSize = 11,
        FontFace = Font_("Regular"),
        LayoutOrder = 3,
        ZIndex = 5,
        Parent = head,
    })
    local valueBox = New("TextBox", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 90, 1, 0),
        Text = "",
        TextSize = 11,
        FontFace = Font_("Medium"),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Visible = false,
        LayoutOrder = 4,
        ZIndex = 5,
        Parent = head,
    })
    s.ValueButton, s.ValueBox = valueButton, valueBox
    Library:AttachTooltip(valueButton, "Click to type a value")

    local track = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0, 34),
        Size = UDim2.new(1, -9, 0, 3),
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = row,
    })
    Corner(UDim.new(1, 0), track)
    local fill = New("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 5, Parent = track })
    Corner(UDim.new(1, 0), fill)
    s.Track, s.Fill = track, fill

    local function knob()
        local k = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromScale(0, 0.5),
            ZIndex = 6,
            Parent = track,
        })
        Corner(UDim.new(1, 0), k)
        local st = Stroke(k, Color3.new(1, 1, 1), 0.85)
        return k, st
    end
    s.Knobs, s.KnobStrokes = {}, {}
    s.Knobs[1], s.KnobStrokes[1] = knob()
    if s.Range then
        s.Knobs[2], s.KnobStrokes[2] = knob()
    end

    local hit = New("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, 0, 0, 22),
        ZIndex = 7,
        Parent = row,
    })
    hit.MouseEnter:Connect(function()
        s.Hover = true
        for _, k in ipairs(s.Knobs) do
            Library:Tween(k, { Size = UDim2.fromOffset(14, 14) }, 0.12)
        end
    end)
    hit.MouseLeave:Connect(function()
        s.Hover = false
        if not s.Dragging then
            for _, k in ipairs(s.Knobs) do
                Library:Tween(k, { Size = UDim2.fromOffset(12, 12) }, 0.12)
            end
        end
    end)

    local function valueFromX(x)
        local p, sz = track.AbsolutePosition.X, track.AbsoluteSize.X
        local alpha = Clamp((x - p) / math.max(sz, 1), 0, 1)
        return Clamp(Round(s.Min + alpha * (s.Max - s.Min), s.Increment), s.Min, s.Max)
    end

    hit.InputBegan:Connect(function(input)
        if s.Locked then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local which = 1
        if s.Range then
            local v = valueFromX(input.Position.X)
            which = math.abs(v - s.Value[1]) <= math.abs(v - s.Value[2]) and 1 or 2
            if s.Value[1] == s.Value[2] then
                which = v < s.Value[1] and 1 or 2
            end
        end
        local function update(pos)
            local v = valueFromX(pos.X)
            if s.Range then
                if which == 1 then
                    s:Set(math.min(v, s.Value[2]), s.Value[2])
                else
                    s:Set(s.Value[1], math.max(v, s.Value[1]))
                end
            else
                s:Set(v)
            end
        end
        s.Dragging = true
        update(Vector2.new(input.Position.X, input.Position.Y))
        Library.ActiveDrag = {
            Update = update,
            End = function()
                s.Dragging = false
                if not s.Hover then
                    for _, k in ipairs(s.Knobs) do
                        Library:Tween(k, { Size = UDim2.fromOffset(12, 12) }, 0.12)
                    end
                end
            end,
        }
    end)

    valueButton.MouseButton1Click:Connect(function()
        if s.Locked then
            return
        end
        valueButton.Visible = false
        valueBox.Visible = true
        if s.Range then
            valueBox.Text = FormatNumber(s.Value[1], s.Increment) .. "-" .. FormatNumber(s.Value[2], s.Increment)
        else
            valueBox.Text = FormatNumber(s.Value, s.Increment)
        end
        valueBox:CaptureFocus()
    end)
    valueBox.FocusLost:Connect(function()
        local text = valueBox.Text
        valueBox.Visible = false
        valueButton.Visible = true
        if s.Range then
            local lo, hi = string.match(text, "(%-?[%d%.]+)%s*[^%d%.]+%s*(%-?[%d%.]+)")
            lo, hi = tonumber(lo), tonumber(hi)
            if lo and hi then
                s:Set(math.min(lo, hi), math.max(lo, hi))
            end
        else
            local n = tonumber(string.match(text, "%-?[%d%.]+"))
            if n then
                s:Set(n)
            end
        end
        s:_refresh()
    end)

    return s:_finish(true)
end

function Slider:Get()
    if self.Range then
        return self.Value[1], self.Value[2]
    end
    return self.Value
end

function Slider:_flagValue()
    if self.Range then
        return { self.Value[1], self.Value[2] }
    end
    return self.Value
end

function Slider:Set(a, b)
    if self.Range then
        if type(a) == "table" then
            a, b = a[1], a[2]
        end
        local lo = Clamp(Round(tonumber(a) or self.Value[1], self.Increment), self.Min, self.Max)
        local hi = Clamp(Round(tonumber(b) or self.Value[2], self.Increment), self.Min, self.Max)
        if lo > hi then
            lo, hi = hi, lo
        end
        if lo == self.Value[1] and hi == self.Value[2] then
            return
        end
        self.Value = { lo, hi }
    else
        local v = Clamp(Round(tonumber(a) or self.Value, self.Increment), self.Min, self.Max)
        if v == self.Value then
            return
        end
        self.Value = v
    end
    self:_refresh()
    self:_emit()
end
Slider.SetValue = Slider.Set

function Slider:SetMin(v)
    self.Min = v
    self:Set(self:_flagValue())
    self:_refresh()
end

function Slider:SetMax(v)
    self.Max = v
    self:Set(self:_flagValue())
    self:_refresh()
end

function Slider:_refresh()
    local th = Library.Theme
    local dim = self.Dimmed
    local range = math.max(self.Max - self.Min, 1e-9)
    local a1, a2
    if self.Range then
        a1 = (self.Value[1] - self.Min) / range
        a2 = (self.Value[2] - self.Min) / range
        self.ValueButton.Text = FormatNumber(self.Value[1], self.Increment, self.Suffix) .. self.Separator .. FormatNumber(self.Value[2], self.Increment, self.Suffix)
    else
        a1, a2 = 0, (self.Value - self.Min) / range
        self.ValueButton.Text = FormatNumber(self.Value, self.Increment, self.Suffix)
    end
    local speed = self.Dragging and 0.05 or 0.18
    Library:Tween(self.Fill, { Position = UDim2.fromScale(a1, 0), Size = UDim2.fromScale(a2 - a1, 1) }, speed)
    if self.Range then
        Library:Tween(self.Knobs[1], { Position = UDim2.fromScale(a1, 0.5) }, speed)
        Library:Tween(self.Knobs[2], { Position = UDim2.fromScale(a2, 0.5) }, speed)
    else
        Library:Tween(self.Knobs[1], { Position = UDim2.fromScale(a2, 0.5) }, speed)
    end
    self.Track.BackgroundColor3 = th.Track
    self.Fill.BackgroundColor3 = dim and Mix(th.Accent, th.Card, 0.65) or Mix(th.Accent, th.Card, 0.08)
    for _, k in ipairs(self.Knobs) do
        k.BackgroundColor3 = dim and Mix(th.Knob, th.Card, 0.5) or th.Knob
    end
    self.Label.TextColor3 = dim and th.TextFaint or th.Text
    self.Dot.BackgroundColor3 = dim and th.TextFaint or th.Text
    self.ValueButton.TextColor3 = dim and th.TextFaint or th.TextDim
    self.ValueBox.TextColor3 = th.Text
end

--------------------------------------------------------------------------------
-- Dropdown: stacked (CAPTION above a full width box) or Inline (label left,
-- box right). Single / multi select, search filter, :Refresh(newList).
--------------------------------------------------------------------------------
local Dropdown = Class()

function Container:AddDropdown(a, b)
    local opts = FlagOpts(a, b)
    local d = setmetatable({}, Dropdown)
    d:_init(self, "Dropdown", opts)
    d.Values = CopyList(opts.Values)
    d.Multi = opts.Multi == true
    d.AllowNull = opts.AllowNull == true
    d.Searchable = opts.Searchable
    if d.Searchable == nil then
        d.Searchable = #d.Values > 6
    end
    d.MaxVisible = opts.MaxVisible or 7
    d.Inline = opts.Inline == true

    if d.Multi then
        d.Value = {}
        local def = opts.Default
        if type(def) == "string" then
            d.Value[def] = true
        elseif type(def) == "table" then
            for k, v in pairs(def) do
                if type(k) == "number" then
                    d.Value[v] = true
                elseif v then
                    d.Value[k] = true
                end
            end
        end
    else
        local def = opts.Default
        if type(def) == "number" then
            def = d.Values[def]
        end
        d.Value = def or ((not d.AllowNull) and d.Values[1] or nil)
    end

    local row, boxY
    if d.Inline then
        row = self:_row(32, "Dropdown")
        d.Label = Library:Label(row, d.Text, 12, "Regular", nil, {
            Size = UDim2.new(1, -(opts.Width or 120) - 10, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 4,
        })
    else
        row = self:_row(d.Text ~= "" and 58 or 34, "Dropdown")
        if d.Text ~= "" then
            d.Label = Library:Label(row, string.upper(d.Text), 9, "Medium", nil, {
                Position = UDim2.fromOffset(0, 3),
                Size = UDim2.new(1, 0, 0, 16),
                ZIndex = 4,
            })
            boxY = 24
        else
            boxY = 3
        end
    end
    d.Row = row

    local button = New("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 0.15,
        ZIndex = 4,
        Parent = row,
    })
    if d.Inline then
        button.AnchorPoint = Vector2.new(1, 0.5)
        button.Position = UDim2.new(1, 0, 0.5, 0)
        button.Size = UDim2.fromOffset(opts.Width or 120, 28)
    else
        button.Position = UDim2.fromOffset(0, boxY)
        button.Size = UDim2.new(1, 0, 0, 28)
    end
    Library:Bind(button, { BackgroundColor3 = "Element" })
    Corner(4, button)
    d.ButtonStroke = Stroke(button, Library.Theme.ElementStroke, 1)
    d.Button = button
    d.Display = Library:Label(button, "", 12, "Regular", nil, {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
    })
    local chevron = Library:ThemedIcon("chevron-down", 12, "TextDim", button)
    chevron.Frame.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Frame.Position = UDim2.new(1, -9, 0.5, 0)
    DeepZ(chevron.Frame, 5)
    d.Chevron = chevron

    button.MouseEnter:Connect(function()
        Library:Tween(button, { BackgroundTransparency = 0 }, 0.12)
    end)
    button.MouseLeave:Connect(function()
        Library:Tween(button, { BackgroundTransparency = 0.15 }, 0.12)
    end)
    button.MouseButton1Click:Connect(function()
        if d.Locked then
            return
        end
        if d.Menu and d.Menu.Parent and Library:IsPopupOpen(d.Menu) then
            Library:ClosePopupFrame(d.Menu)
        else
            d:Open()
        end
    end)

    return d:_finish(true)
end

function Dropdown:Get()
    if self.Multi then
        local out = {}
        for _, v in ipairs(self.Values) do
            if self.Value[v] then
                table.insert(out, v)
            end
        end
        for k, on in pairs(self.Value) do
            if on and not Find(self.Values, k) then
                table.insert(out, k)
            end
        end
        return out
    end
    return self.Value
end

function Dropdown:_flagValue()
    return self:Get()
end

function Dropdown:GetDisplay()
    if self.Multi then
        local list = self:Get()
        return #list > 0 and table.concat(list, ", ") or "None"
    end
    return self.Value ~= nil and tostring(self.Value) or "None"
end

function Dropdown:Set(value)
    if self.Multi then
        local new = {}
        if type(value) == "string" then
            new[value] = true
        elseif type(value) == "table" then
            for k, v in pairs(value) do
                if type(k) == "number" then
                    new[v] = true
                elseif v then
                    new[k] = true
                end
            end
        end
        self.Value = new
    else
        if type(value) == "number" and self.Values[value] ~= nil and not Find(self.Values, value) then
            value = self.Values[value]
        end
        if value == nil and not self.AllowNull then
            value = self.Values[1]
        end
        self.Value = value
    end
    self:_refresh()
    self:_rebuildItems()
    self:_emit()
end
Dropdown.SetValue = Dropdown.Set

function Dropdown:Refresh(values, keepSelection)
    self.Values = CopyList(values)
    if not keepSelection then
        if self.Multi then
            for k in pairs(self.Value) do
                if not Find(self.Values, k) then
                    self.Value[k] = nil
                end
            end
        elseif self.Value ~= nil and not Find(self.Values, self.Value) then
            self.Value = (not self.AllowNull) and self.Values[1] or nil
        end
    end
    self:_refresh()
    self:_rebuildItems()
    self:_emit()
end
Dropdown.SetValues = Dropdown.Refresh

function Dropdown:_refresh()
    local th = Library.Theme
    local hasValue = self.Multi and #self:Get() > 0 or (not self.Multi and self.Value ~= nil)
    self.Display.Text = self:GetDisplay()
    self.Display.TextColor3 = self.Dimmed and th.TextFaint or (hasValue and th.Text or th.TextDim)
    self.ButtonStroke.Color = th.ElementStroke
    if self.Label then
        if self.Inline then
            self.Label.TextColor3 = self.Dimmed and th.TextFaint or th.Text
        else
            self.Label.TextColor3 = self.Dimmed and Mix(th.TextFaint, th.Card, 0.4) or th.TextFaint
        end
    end
end

function Dropdown:_select(value)
    if self.Multi then
        if self.Value[value] then
            self.Value[value] = nil
        else
            self.Value[value] = true
        end
    else
        if self.Value == value and self.AllowNull then
            self.Value = nil
        else
            self.Value = value
        end
    end
    self:_refresh()
    self:_rebuildItems()
    self:_emit()
    if not self.Multi and self.Menu then
        Library:ClosePopupFrame(self.Menu)
    end
end

function Dropdown:_isSelected(value)
    if self.Multi then
        return self.Value[value] == true
    end
    return self.Value == value
end

function Dropdown:_rebuildItems()
    local list = self.MenuList
    if not list or not list.Parent then
        return
    end
    local th = Library.Theme
    local z = self.Menu.ZIndex + 1
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local filter = self.SearchBox and string.lower(self.SearchBox.Text) or ""
    local count = 0
    for i, value in ipairs(self.Values) do
        local text = tostring(value)
        if filter == "" or string.find(string.lower(text), filter, 1, true) then
            count = count + 1
            local selected = self:_isSelected(value)
            local item = New("TextButton", {
                AutoButtonColor = false,
                Text = "",
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = th.Outline,
                BackgroundTransparency = selected and 0.96 or 1,
                LayoutOrder = i,
                ZIndex = z,
                Parent = list,
            })
            Corner(4, item)
            local x = 10
            if self.Multi then
                local box = New("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 8, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14),
                    BackgroundColor3 = selected and th.Accent or th.Checkbox,
                    ZIndex = z + 1,
                    Parent = item,
                })
                Corner(3, box)
                if not selected then
                    Stroke(box, th.ElementStroke)
                else
                    local check = Icons.Create("check", 10, th.AccentText, box)
                    check.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
                    check.Frame.Position = UDim2.fromScale(0.5, 0.5)
                    DeepZ(check.Frame, z + 2)
                end
                x = 30
            end
            Library:Label(item, text, 12, "Regular", nil, {
                Position = UDim2.fromOffset(x, 0),
                Size = UDim2.new(1, -x - 26, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextColor3 = selected and th.Text or th.TextMuted,
                ZIndex = z + 1,
            })
            if selected and not self.Multi then
                local check = Icons.Create("check", 11, th.Text, item)
                check.Frame.AnchorPoint = Vector2.new(1, 0.5)
                check.Frame.Position = UDim2.new(1, -9, 0.5, 0)
                DeepZ(check.Frame, z + 1)
            end
            item.MouseEnter:Connect(function()
                item.BackgroundTransparency = 0.94
            end)
            item.MouseLeave:Connect(function()
                item.BackgroundTransparency = self:_isSelected(value) and 0.96 or 1
            end)
            item.MouseButton1Click:Connect(function()
                self:_select(value)
            end)
        end
    end
    if count == 0 then
        Library:Label(list, "No results", 11, "Regular", nil, {
            Size = UDim2.new(1, 0, 0, 26),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextColor3 = th.TextDim,
            ZIndex = z,
        })
        count = 1
    end
    local top = self.SearchBox and 36 or 4
    local height = top + math.min(count, self.MaxVisible) * 27 + 4
    self.MenuHeight = height
    Library:Tween(self.Menu, { Size = UDim2.fromOffset(self.MenuWidth, height) }, 0.18, Enum.EasingStyle.Quint)
end

function Dropdown:Open()
    local th = Library.Theme
    local width = math.max(self.Button.AbsoluteSize.X, self.Options.MenuWidth or 140)
    local z = 120 + #Library.PopupStack * 10
    local menu = New("Frame", {
        Name = "DropdownMenu",
        Size = UDim2.fromOffset(width, 0),
        BackgroundColor3 = th.Popup,
        ClipsDescendants = true,
        ZIndex = z,
        Parent = Library.Overlay,
    })
    Corner(4, menu)
    Stroke(menu, th.CardStroke)
    self.Menu, self.MenuWidth = menu, width

    local top = 4
    self.SearchBox = nil
    if self.Searchable then
        local searchFrame = New("Frame", {
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.new(1, -8, 0, 28),
            BackgroundColor3 = th.Field,
            ZIndex = z + 1,
            Parent = menu,
        })
        Corner(4, searchFrame)
        Stroke(searchFrame, th.CardStroke)
        local icon = Icons.Create("search", 11, th.TextDim, searchFrame)
        icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
        icon.Frame.Position = UDim2.new(0, 9, 0.5, 0)
        DeepZ(icon.Frame, z + 2)
        local box = New("TextBox", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(27, 0),
            Size = UDim2.new(1, -32, 1, 0),
            Text = "",
            PlaceholderText = "Search...",
            PlaceholderColor3 = th.TextDim,
            TextColor3 = th.Text,
            TextSize = 11,
            FontFace = Font_("Regular"),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = z + 2,
            Parent = searchFrame,
        })
        self.SearchBox = box
        box:GetPropertyChangedSignal("Text"):Connect(function()
            self:_rebuildItems()
        end)
        top = 36
    end

    local list = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 1, -top),
        CanvasSize = UDim2.fromScale(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = th.CardStroke,
        ZIndex = z + 1,
        Parent = menu,
    })
    Padding(list, 0, 4, 4, 4)
    List(list, 1)
    self.MenuList = list
    self:_rebuildItems()
    Library:Tween(self.Chevron.Frame, { Rotation = 180 }, 0.18)
    Library:Tween(self.ButtonStroke, { Transparency = 0 }, 0.15)

    Library:OpenPopup(menu, self.Button, function()
        self.MenuList = nil
        self.SearchBox = nil
        if self.Chevron.Frame.Parent then
            Library:Tween(self.Chevron.Frame, { Rotation = 0 }, 0.18)
            Library:Tween(self.ButtonStroke, { Transparency = 1 }, 0.15)
        end
    end, function()
        Library:PlacePopup(menu, self.Button, width, self.MenuHeight or 100, 4)
    end)
end

--------------------------------------------------------------------------------
-- Textbox (placeholder, icon, focus highlight, ClearTextOnFocus, Numeric, Finished)
--------------------------------------------------------------------------------
local Textbox = Class()

function Container:AddTextbox(a, b)
    local opts = FlagOpts(a, b)
    local t = setmetatable({}, Textbox)
    t:_init(self, "Textbox", opts)
    t.Value = tostring(opts.Default or "")
    t.Numeric = opts.Numeric == true
    local hasLabel = t.Text ~= "" and opts.HideLabel ~= true
    local top = hasLabel and 24 or 5
    local row = self:_row(top + 34, "Textbox")
    t.Row = row
    if hasLabel then
        t.Label = Library:Label(row, string.upper(t.Text), 9, "Medium", nil, {
            Position = UDim2.fromOffset(0, 3),
            Size = UDim2.new(1, 0, 0, 16),
            ZIndex = 4,
        })
    end
    local frame = New("Frame", {
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 0.15,
        ZIndex = 4,
        Parent = row,
    })
    Library:Bind(frame, { BackgroundColor3 = "Element" })
    Corner(4, frame)
    t.Stroke = Stroke(frame, Library.Theme.ElementStroke, 0.4)
    local x = 10
    if opts.Icon then
        local icon = Library:ThemedIcon(opts.Icon, 12, "TextDim", frame)
        icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
        icon.Frame.Position = UDim2.new(0, 10, 0.5, 0)
        DeepZ(icon.Frame, 5)
        x = 32
    end
    local box = New("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, 0),
        Size = UDim2.new(1, -x - 10, 1, 0),
        Text = t.Value,
        PlaceholderText = opts.Placeholder or "",
        TextSize = 12,
        FontFace = Font_("Regular"),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = opts.ClearTextOnFocus == true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = frame,
    })
    Library:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "TextDim" })
    t.Box = box

    box.Focused:Connect(function()
        if t.Locked then
            box:ReleaseFocus()
            return
        end
        Library:Tween(t.Stroke, { Color = Mix(Library.Theme.ElementStroke, Library.Theme.Accent, 0.5), Transparency = 0 }, 0.15)
    end)
    box.FocusLost:Connect(function(enter)
        Library:Tween(t.Stroke, { Color = Library.Theme.ElementStroke, Transparency = 0.4 }, 0.15)
        if opts.Finished ~= true or enter then
            t:Set(box.Text)
        end
    end)
    if opts.Live then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if box:IsFocused() then
                t:Set(box.Text, true)
            end
        end)
    end
    if opts.MaxLength then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if string.len(box.Text) > opts.MaxLength then
                box.Text = string.sub(box.Text, 1, opts.MaxLength)
            end
        end)
    end

    return t:_finish(true)
end
Container.AddInput = Container.AddTextbox

function Textbox:Set(text, keepCursor)
    text = tostring(text or "")
    if self.Numeric and text ~= "" and not tonumber(text) then
        text = self.Value
    end
    local changed = text ~= self.Value
    self.Value = text
    if not keepCursor then
        self.Box.Text = text
    end
    if changed then
        self:_emit()
    end
end

function Textbox:SetClearTextOnFocus(state)
    self.Box.ClearTextOnFocus = state and true or false
end

function Textbox:_refresh()
    if self.Label then
        self.Label.TextColor3 = self.Dimmed and Mix(Library.Theme.TextFaint, Library.Theme.Card, 0.4) or Library.Theme.TextFaint
    end
    self.Box.TextEditable = not self.Locked
end

--------------------------------------------------------------------------------
-- Button: Primary / Secondary / Danger, icon, ripple + hover luminance,
-- split rows via Button:AddButton, optional double-click confirmation.
--------------------------------------------------------------------------------
local Button = Class()

local function ButtonColors(style, disabled)
    local th = Library.Theme
    if disabled then
        return th.Element, 0.55, th.TextFaint
    end
    if style == "Primary" then
        return th.Accent, 0, th.AccentText
    elseif style == "Danger" then
        return th.Element, 0.3, th.Danger
    end
    return th.Element, 0.15, th.Text
end

local function BuildButton(container, holder, opts)
    local btn = setmetatable({}, Button)
    btn:_init(container, "Button", opts)
    btn.Style = opts.Style or "Secondary"
    btn.Value = btn.Text
    btn.Disabled = opts.Disabled == true
    btn.Locked = false
    btn.Dimmed = false

    local frame = New("TextButton", {
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
        ZIndex = 4,
        Parent = holder,
    })
    Corner(4, frame)
    local content = New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 6,
        Parent = frame,
    })
    List(content, 7, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    if opts.Icon then
        btn.Icon = Icons.Create(opts.Icon, 12, Color3.new(1, 1, 1), content)
        btn.Icon.Frame.LayoutOrder = 1
        DeepZ(btn.Icon.Frame, 6)
    end
    btn.Label = Library:Label(content, btn.Text, 12, "Regular", nil, {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 6,
    })
    btn.Frame = frame

    frame.MouseEnter:Connect(function()
        btn.Hover = true
        btn:_refresh()
    end)
    frame.MouseLeave:Connect(function()
        btn.Hover = false
        btn:_refresh()
    end)
    frame.MouseButton1Click:Connect(function()
        if btn.Disabled or btn.Locked then
            return
        end
        btn:_ripple()
        if opts.DoubleClick then
            if not btn.Armed then
                btn.Armed = true
                btn.Label.Text = opts.ConfirmText or "Click again to confirm"
                task.delay(2.5, function()
                    if btn.Armed then
                        btn.Armed = false
                        btn.Label.Text = btn.Text
                    end
                end)
                return
            end
            btn.Armed = false
            btn.Label.Text = btn.Text
        end
        SafeCall(btn.Callback)
        for _, fn in ipairs(btn._listeners) do
            SafeCall(fn)
        end
    end)
    if opts.Tooltip then
        Library:AttachTooltip(frame, opts.Tooltip)
    end
    Library:AddRefresher(function()
        if frame.Parent then
            btn:_refresh()
        end
    end)
    btn:_refresh()
    return btn
end

function Button:_ripple()
    if not Library.Animations then
        return
    end
    local frame = self.Frame
    local m = MouseLocation()
    local p = frame.AbsolutePosition
    local size = math.max(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) * 2.2
    local _, _, textColor = ButtonColors(self.Style, false)
    local ripple = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(m.X - p.X, m.Y - p.Y),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = textColor,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = frame,
    })
    Corner(UDim.new(1, 0), ripple)
    Library:Tween(ripple, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, 0.5, Enum.EasingStyle.Quad)
    task.delay(0.55, function()
        ripple:Destroy()
    end)
end

local function LayoutButtonRow(holder)
    local buttons = {}
    for _, child in ipairs(holder:GetChildren()) do
        if child:IsA("TextButton") and child.Visible then
            table.insert(buttons, child)
        end
    end
    local n = #buttons
    for _, b in ipairs(buttons) do
        b.Size = UDim2.new(1 / n, -(10 * (n - 1)) / n, 1, 0)
    end
end

function Container:AddButton(a, b)
    local opts = TextOpts(a, b)
    local last = self.LastKind
    local margin = opts.Margin or ((last == nil and 4) or (last == "Textbox" and 4) or (last == "Button" and 12) or 8)
    local height = opts.Height or 30
    local row = self:_row(height + margin + (opts.MarginBottom or 4), "Button")
    local holder = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, margin),
        Size = UDim2.new(1, 0, 0, height),
        ZIndex = 4,
        Parent = row,
    })
    List(holder, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    local btn = BuildButton(self, holder, opts)
    btn.Row = row
    btn.Holder = holder
    LayoutButtonRow(holder)
    if opts.Visible == false then
        btn:SetVisible(false)
    end
    btn:_searchable()
    return btn
end

function Button:AddButton(a, b)
    local opts = TextOpts(a, b)
    local btn = BuildButton(self.Container, self.Holder, opts)
    btn.Row = self.Row
    btn.Holder = self.Holder
    btn.Frame.LayoutOrder = #self.Holder:GetChildren()
    LayoutButtonRow(self.Holder)
    btn:_searchable()
    return btn
end

function Button:Get()
    return self.Text
end

function Button:Set(text)
    self.Text = tostring(text)
    self.Value = self.Text
    self.Label.Text = self.Text
end
Button.SetText = Button.Set

function Button:SetDisabled(state)
    self.Disabled = state and true or false
    self:_refresh()
end

function Button:SetStyle(style)
    self.Style = style
    self:_refresh()
end

function Button:SetVisible(state)
    self.Visible = state and true or false
    self.Frame.Visible = self.Visible
    local anyVisible = false
    for _, child in ipairs(self.Holder:GetChildren()) do
        if child:IsA("TextButton") and child.Visible then
            anyVisible = true
        end
    end
    self.Row.Visible = anyVisible
    LayoutButtonRow(self.Holder)
end

function Button:_refresh()
    local bg, transparency, text = ButtonColors(self.Style, self.Disabled)
    if self.Hover and not self.Disabled then
        if self.Style == "Primary" then
            bg = Mix(bg, Color3.new(1, 1, 1), 0.25)
        elseif self.Style == "Danger" then
            bg = Mix(bg, Library.Theme.Danger, 0.12)
            transparency = 0
        else
            bg = Library.Theme.ElementHover
            transparency = 0
        end
    end
    Library:Tween(self.Frame, { BackgroundColor3 = bg, BackgroundTransparency = transparency }, 0.15)
    self.Label.TextColor3 = text
    if self.Icon then
        self.Icon.SetColor(text)
    end
end

--------------------------------------------------------------------------------
-- Colour swatches (accent presets)
--------------------------------------------------------------------------------
local Swatches = Class()

Library.AccentPresets = {
    Color3.fromRGB(226, 226, 226), Color3.fromRGB(96, 156, 240), Color3.fromRGB(52, 196, 140),
    Color3.fromRGB(240, 104, 104), Color3.fromRGB(242, 190, 44), Color3.fromRGB(156, 128, 240),
}

function Container:AddSwatches(a, b)
    local opts = FlagOpts(a, b)
    local s = setmetatable({}, Swatches)
    s:_init(self, "Swatches", opts)
    s.Colors = opts.Colors or Library.AccentPresets
    local def = opts.Default or 1
    s.Value = type(def) == "number" and s.Colors[def] or def

    local row = self:_row(32, "Swatches")
    s.Row = row
    local holder = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-1, 0), Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = row })
    List(holder, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    s.Dots = {}
    for i, color in ipairs(s.Colors) do
        local button = New("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(20, 20),
            LayoutOrder = i,
            ZIndex = 4,
            Parent = holder,
        })
        Corner(UDim.new(1, 0), button)
        local ring = Stroke(button, Color3.new(1, 1, 1), 1, 1.5)
        local dot = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = color,
            ZIndex = 5,
            Parent = button,
        })
        Corner(UDim.new(1, 0), dot)
        s.Dots[i] = { Button = button, Ring = ring, Dot = dot, Color = color }
        button.MouseButton1Click:Connect(function()
            if not s.Locked then
                s:Set(color)
            end
        end)
        Library:AttachTooltip(button, ColorToHex(color))
    end
    return s:_finish(true)
end

function Swatches:Set(color)
    if type(color) == "string" then
        color = HexToColor(color)
    elseif type(color) == "number" then
        color = self.Colors[color]
    end
    if typeof(color) ~= "Color3" then
        return
    end
    local changed = not SameColor(color, self.Value)
    self.Value = color
    self:_refresh()
    if changed then
        self:_emit()
    end
end

function Swatches:_serialize()
    return ColorToHex(self.Value)
end

function Swatches:_refresh()
    for _, d in ipairs(self.Dots) do
        local selected = SameColor(d.Color, self.Value)
        Library:Tween(d.Ring, { Transparency = selected and 0.15 or 1, Color = Mix(d.Color, Color3.new(1, 1, 1), 0.3) }, 0.15)
        Library:Tween(d.Dot, { Size = selected and UDim2.fromOffset(14, 14) or UDim2.fromOffset(16, 16) }, 0.15)
        d.Dot.BackgroundTransparency = self.Dimmed and 0.5 or 0
    end
end

--------------------------------------------------------------------------------
-- Selectable list (config list)
--------------------------------------------------------------------------------
local ListBox = Class()

function Container:AddList(a, b)
    local opts = FlagOpts(a, b)
    local l = setmetatable({}, ListBox)
    l:_init(self, "List", opts)
    l.Values = CopyList(opts.Values)
    l.Value = opts.Default
    l.EmptyText = opts.EmptyText or "Nothing here yet."
    local row = self:_row(0, "List")
    row.AutomaticSize = Enum.AutomaticSize.Y
    l.Row = row
    l.Holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 4, Parent = row })
    List(l.Holder, 2)
    l:_rebuild()
    return l:_finish(true)
end

function ListBox:_rebuild()
    local th = Library.Theme
    for _, child in ipairs(self.Holder:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    if #self.Values == 0 then
        Library:Label(self.Holder, self.EmptyText, 11, "Regular", "TextMuted", {
            Size = UDim2.new(1, 0, 0, 22),
            ZIndex = 4,
        })
        return
    end
    for i, value in ipairs(self.Values) do
        local selected = value == self.Value
        local item = New("TextButton", {
            AutoButtonColor = false,
            Text = "",
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = th.Element,
            BackgroundTransparency = selected and 0 or 1,
            LayoutOrder = i,
            ZIndex = 4,
            Parent = self.Holder,
        })
        Corner(4, item)
        local icon = Icons.Create("folder", 12, selected and th.Text or th.TextDim, item)
        icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
        icon.Frame.Position = UDim2.new(0, 8, 0.5, 0)
        DeepZ(icon.Frame, 5)
        Library:Label(item, tostring(value), 12, "Regular", nil, {
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -60, 1, 0),
            TextColor3 = selected and th.Text or th.TextMuted,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
        })
        if Library.ActiveConfig == value then
            Library:Label(item, "active", 10, "Regular", nil, {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -9, 0, 0),
                Size = UDim2.new(0, 50, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextColor3 = th.TextDim,
                ZIndex = 5,
            })
        end
        item.MouseEnter:Connect(function()
            if self.Value ~= value then
                item.BackgroundTransparency = 0.5
            end
        end)
        item.MouseLeave:Connect(function()
            item.BackgroundTransparency = self.Value == value and 0 or 1
        end)
        item.MouseButton1Click:Connect(function()
            if not self.Locked then
                self:Set(self.Value == value and nil or value)
            end
        end)
    end
end

function ListBox:Set(value)
    local changed = value ~= self.Value
    self.Value = value
    self:_rebuild()
    if changed then
        self:_emit()
    end
end

function ListBox:Refresh(values)
    self.Values = CopyList(values)
    if self.Value ~= nil and not Find(self.Values, self.Value) then
        self:Set(nil)
    else
        self:_rebuild()
    end
end
ListBox.SetValues = ListBox.Refresh

--------------------------------------------------------------------------------
-- Standalone keybind / colour picker rows
--------------------------------------------------------------------------------
function Container:AddKeybind(a, b)
    local opts = FlagOpts(a, b)
    local row = self:_row(32, "Keybind")
    local label = Library:Label(row, opts.Text or "Keybind", 12, "Regular", nil, {
        Size = UDim2.new(1, -110, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    local holder = self:_addonHolder(row)
    local picker = BuildKeyPicker(self, holder, opts, nil)
    picker.Row = row
    picker.Label = label
    picker:_refresh()
    if opts.Tooltip then
        Library:AttachTooltip(row, opts.Tooltip)
    end
    return picker
end
Container.AddKeyPicker = Container.AddKeybind

function Container:AddColorPicker(a, b)
    local opts = FlagOpts(a, b)
    local row = self:_row(32, "ColorPicker")
    local label = Library:Label(row, opts.Text or "Color", 12, "Regular", nil, {
        Size = UDim2.new(1, -110, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })
    local holder = self:_addonHolder(row)
    local picker = BuildColorPicker(self, holder, opts, nil)
    picker.Row = row
    picker.Label = label
    picker:_refresh()
    return picker
end

--------------------------------------------------------------------------------
-- ESP preview: a stylised operator with a box, health / armour bars, name,
-- weapon, distance and flags. Bind toggles / colour pickers to drive it live.
--------------------------------------------------------------------------------
local ESPPreview = Class()

local PreviewElements = { "Box", "Name", "Health", "Armor", "Weapon", "Distance", "Flags" }

local function Figure(stage)
    local parts = {}
    local function part(name, x, y, w, h, color, radius, rotation)
        local f = New("Frame", {
            Name = name,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, x, 0, y),
            Size = UDim2.fromOffset(w, h),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Rotation = rotation or 0,
            ZIndex = 5,
            Parent = stage,
        })
        Corner(radius or 4, f)
        New("UIGradient", {
            Rotation = 0,
            Color = CS({ { 0, Color3.fromRGB(150, 150, 150) }, { 0.45, Color3.fromRGB(255, 255, 255) }, { 1, Color3.fromRGB(120, 120, 120) } }),
            Parent = f,
        })
        table.insert(parts, f)
        return f
    end
    local uniform = Color3.fromRGB(78, 86, 100)
    local dark = Color3.fromRGB(40, 43, 48)
    local vest = Color3.fromRGB(94, 96, 70)
    local pad = Color3.fromRGB(118, 120, 126)
    -- legs
    part("LegL", -12, 136, 19, 104, uniform, 6, 2)
    part("LegR", 12, 136, 19, 104, uniform, 6, -2)
    part("KneeL", -13, 182, 17, 16, pad, 5)
    part("KneeR", 13, 182, 17, 16, pad, 5)
    part("BootL", -14, 234, 21, 16, dark, 4)
    part("BootR", 14, 234, 21, 16, dark, 4)
    -- arms
    part("ArmL", -33, 44, 14, 84, uniform, 6, 7)
    part("ArmR", 33, 44, 14, 84, uniform, 6, -7)
    part("HandL", -38, 124, 12, 14, dark, 5)
    part("HandR", 38, 124, 12, 14, dark, 5)
    -- torso
    part("Torso", 0, 38, 50, 104, uniform, 8)
    part("Vest", 0, 46, 44, 62, vest, 6)
    part("PouchL", -11, 82, 12, 22, Mix(vest, dark, 0.3), 3)
    part("PouchR", 11, 82, 12, 22, Mix(vest, dark, 0.3), 3)
    part("Belt", 0, 128, 48, 8, dark, 2)
    -- head
    part("Neck", 0, 30, 14, 12, dark, 4)
    part("Head", 0, 6, 26, 28, Color3.fromRGB(58, 60, 64), 12)
    part("Mask", 0, 16, 20, 15, dark, 7)
    part("Lens", -5, 14, 7, 7, Color3.fromRGB(150, 160, 170), 4)
    part("Lens2", 5, 14, 7, 7, Color3.fromRGB(150, 160, 170), 4)
    part("Filter", 0, 26, 9, 9, Color3.fromRGB(70, 110, 140), 4)
    return parts
end

function Container:AddESPPreview(opts)
    opts = opts or {}
    local p = setmetatable({}, ESPPreview)
    p:_init(self, "ESPPreview", opts)
    Library.Previews = Library.Previews or {}
    table.insert(Library.Previews, p)
    p.Text = opts.Text or "ESP Preview"
    p.State = {}
    p.Colors = {}
    for _, name in ipairs(PreviewElements) do
        p.State[name] = true
    end
    p.Master = true
    p.BoxStyle = opts.BoxStyle or "Corners"
    p.Health = opts.Health or 0.82
    p.Armor = opts.Armor or 0.62
    p.FlagItems = opts.Flags or {
        { Text = "SCOPED" },
        { Text = "RELOAD", Color = Library.Theme.Warning },
    }

    local height = opts.Height or 372
    local row = self:_row(height, "ESPPreview")
    p.Row = row
    local stage = New("Frame", {
        Name = "Stage",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 20),
        Size = UDim2.fromOffset(opts.Image == nil and opts.Avatar ~= false and 116 or 96, 272),
        ZIndex = 4,
        Parent = row,
    })
    p.Stage = stage

    -- the drawn figure is the fallback; the player's avatar sits on top of it
    -- and hides it once the thumbnail has loaded
    local body = New("Frame", { Name = "Figure", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 1, -12), ZIndex = 5, Parent = stage })
    Figure(body)
    p.Figure = body
    p.Avatar = New("ImageLabel", {
        Name = "Avatar",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(300, 300),
        Image = "",
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 5,
        Parent = stage,
    })
    p._avatarMaid = Maid.new()
    Library.Maid:Give(p._avatarMaid)
    if opts.Image then
        p:SetImage(opts.Image)
    elseif opts.Avatar ~= false then
        local id = type(opts.Avatar) == "number" and opts.Avatar or (LocalPlayer and LocalPlayer.UserId)
        if id and id > 0 then
            p:SetAvatar(id)
        end
    end

    -- box (corner and full styles)
    local boxColor = Library.Theme.Text
    p.BoxLines = { Corners = {}, Full = {} }
    local function line(group, x, y, w, h, ax, ay)
        local l = New("Frame", {
            AnchorPoint = Vector2.new(ax or 0, ay or 0),
            Position = UDim2.new(x[1], x[2], y[1], y[2]),
            Size = UDim2.fromOffset(w, h),
            BackgroundColor3 = boxColor,
            BorderSizePixel = 0,
            ZIndex = 7,
            Parent = stage,
        })
        Stroke(l, Color3.new(0, 0, 0), 0.6)
        table.insert(p.BoxLines[group], l)
        return l
    end
    local len = 18
    line("Corners", { 0, 0 }, { 0, 0 }, len, 2)
    line("Corners", { 0, 0 }, { 0, 0 }, 2, len)
    line("Corners", { 1, 0 }, { 0, 0 }, len, 2, 1, 0)
    line("Corners", { 1, 0 }, { 0, 0 }, 2, len, 1, 0)
    line("Corners", { 0, 0 }, { 1, 0 }, len, 2, 0, 1)
    line("Corners", { 0, 0 }, { 1, 0 }, 2, len, 0, 1)
    line("Corners", { 1, 0 }, { 1, 0 }, len, 2, 1, 1)
    line("Corners", { 1, 0 }, { 1, 0 }, 2, len, 1, 1)
    local top = line("Full", { 0, 0 }, { 0, 0 }, 0, 1)
    top.Size = UDim2.new(1, 0, 0, 1)
    local bottom = line("Full", { 0, 0 }, { 1, 0 }, 0, 1, 0, 1)
    bottom.Size = UDim2.new(1, 0, 0, 1)
    local left = line("Full", { 0, 0 }, { 0, 0 }, 1, 0)
    left.Size = UDim2.new(0, 1, 1, 0)
    local right = line("Full", { 1, 0 }, { 0, 0 }, 1, 0, 1, 0)
    right.Size = UDim2.new(0, 1, 1, 0)

    -- health (left, vertical) and armour (bottom, horizontal)
    local healthTrack = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(0, -4, 0, 0),
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = stage,
    })
    local healthFill = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, p.Health, 0),
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = healthTrack,
    })
    local armorTrack = New("Frame", {
        Position = UDim2.new(0, 0, 1, 4),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = stage,
    })
    local armorFill = New("Frame", { Size = UDim2.new(p.Armor, 0, 1, 0), BorderSizePixel = 0, ZIndex = 8, Parent = armorTrack })
    p.HealthTrack, p.HealthFill, p.ArmorTrack, p.ArmorFill = healthTrack, healthFill, armorTrack, armorFill

    local function text(str, size, y, anchorY, weight)
        return Library:Label(stage, str, size, weight or "Medium", nil, {
            AnchorPoint = Vector2.new(0.5, anchorY),
            Position = UDim2.new(0.5, 0, y[1], y[2]),
            Size = UDim2.fromOffset(160, size + 4),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextStrokeTransparency = 0.6,
            ZIndex = 8,
        })
    end
    p.NameLabel = text(opts.Name or (LocalPlayer and LocalPlayer.DisplayName) or "operator", 11, { 0, -4 }, 1)
    p.WeaponLabel = text(opts.Weapon or "AK-47", 11, { 1, 10 }, 0)
    p.DistanceLabel = text(opts.Distance or "24 m", 10, { 1, 24 }, 0, "Regular")

    local flags = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, 6, 0, 0),
        Size = UDim2.fromOffset(80, 60),
        ZIndex = 8,
        Parent = stage,
    })
    List(flags, 1)
    p.FlagFrame = flags
    p.FlagLabels = {}
    for i, f in ipairs(p.FlagItems) do
        local l = Library:Label(flags, f.Text, 9, "Medium", nil, {
            Size = UDim2.new(1, 0, 0, 12),
            TextStrokeTransparency = 0.6,
            LayoutOrder = i,
            ZIndex = 8,
        })
        p.FlagLabels[i] = { Label = l, Color = f.Color }
    end

    -- Manage elements
    local manage = New("TextButton", {
        AutoButtonColor = false,
        Text = "",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, -4),
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 0.3,
        ZIndex = 5,
        Parent = row,
    })
    Library:Bind(manage, { BackgroundColor3 = "Element" })
    Corner(4, manage)
    local manageContent = New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 6,
        Parent = manage,
    })
    List(manageContent, 7, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    local mi = Library:ThemedIcon("sliders", 12, "TextMuted", manageContent)
    mi.Frame.LayoutOrder = 1
    DeepZ(mi.Frame, 6)
    Library:Label(manageContent, opts.ManageText or "Manage elements", 12, "Regular", "TextMuted", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2,
        ZIndex = 6,
    })
    manage.MouseEnter:Connect(function()
        Library:Tween(manage, { BackgroundTransparency = 0 }, 0.12)
    end)
    manage.MouseLeave:Connect(function()
        Library:Tween(manage, { BackgroundTransparency = 0.3 }, 0.12)
    end)
    manage.MouseButton1Click:Connect(function()
        p:OpenManager()
    end)
    p.ManageButton = manage
    p.Binds = {}

    p:_finish(false)
    return p
end

-- Shows any image in place of the drawn figure ("" brings the figure back).
function ESPPreview:SetImage(image)
    local avatar, figure = self.Avatar, self.Figure
    self._avatarMaid:Clean()
    avatar.Image = image or ""
    if avatar.Image == "" then
        figure.Visible = true
        return
    end
    local function check()
        local ok, loaded = pcall(function()
            return avatar.IsLoaded
        end)
        figure.Visible = not (ok and loaded)
    end
    local ok, signal = pcall(function()
        return avatar:GetPropertyChangedSignal("IsLoaded")
    end)
    if ok and signal then
        self._avatarMaid:Give(signal:Connect(check))
        check()
    else
        figure.Visible = false
    end
end

-- Shows a Roblox user's full-body avatar (defaults to the local player).
function ESPPreview:SetAvatar(userId)
    userId = userId or (LocalPlayer and LocalPlayer.UserId)
    if not userId or userId <= 0 then
        return self:SetImage("")
    end
    self:SetImage(string.format("rbxthumb://type=Avatar&id=%d&w=420&h=420", userId))
end

function ESPPreview:Get()
    return self.State
end

function ESPPreview:Set(name, state)
    self:SetElement(name, state)
end

function ESPPreview:SetElement(name, state)
    if name == "Enabled" then
        self.Master = state and true or false
    else
        self.State[name] = state and true or false
    end
    self:_refresh()
end

function ESPPreview:SetColor(name, color)
    self.Colors[name] = color
    self:_refresh()
end

function ESPPreview:SetBoxStyle(style)
    self.BoxStyle = style == "Full" and "Full" or "Corners"
    self:_refresh()
end

function ESPPreview:SetHealth(health, armor)
    self.Health = Clamp(health or self.Health, 0, 1)
    self.Armor = Clamp(armor or self.Armor, 0, 1)
    self:_refresh()
end

function ESPPreview:SetInfo(info)
    info = info or {}
    if info.Name then
        self.NameLabel.Text = info.Name
    end
    if info.Weapon then
        self.WeaponLabel.Text = info.Weapon
    end
    if info.Distance then
        self.DistanceLabel.Text = info.Distance
    end
end

-- Bind("Box", toggleController) / Bind("Enabled", masterToggle) / Bind("BoxStyle", dropdown)
function ESPPreview:Bind(name, controller)
    if type(controller) == "string" then
        controller = Library.Options[controller]
    end
    if not controller then
        return self
    end
    self.Binds[name] = controller
    local function apply()
        if name == "BoxStyle" then
            self:SetBoxStyle(controller:Get())
        else
            self:SetElement(name, controller:Get())
        end
    end
    controller:OnChanged(apply)
    apply()
    if controller.ColorPicker then
        self:BindColor(name, controller.ColorPicker)
    end
    return self
end

function ESPPreview:BindColor(name, picker)
    if type(picker) == "string" then
        picker = Library.Options[picker]
    end
    if not picker then
        return self
    end
    local function apply()
        self:SetColor(name, picker.Value)
    end
    picker:OnChanged(apply)
    apply()
    return self
end

function ESPPreview:_refresh()
    local th = Library.Theme
    local on = self.Master
    local function vis(name)
        return on and self.State[name]
    end
    local boxColor = self.Colors.Box or th.Text
    for style, lines in pairs(self.BoxLines) do
        for _, l in ipairs(lines) do
            l.Visible = vis("Box") and style == self.BoxStyle
            l.BackgroundColor3 = boxColor
        end
    end
    self.HealthTrack.Visible = vis("Health")
    self.HealthFill.Size = UDim2.new(1, 0, self.Health, 0)
    self.HealthFill.BackgroundColor3 = self.Colors.Health or Mix(th.Danger, th.Success, self.Health)
    self.ArmorTrack.Visible = vis("Armor")
    self.ArmorFill.Size = UDim2.new(self.Armor, 0, 1, 0)
    self.ArmorFill.BackgroundColor3 = self.Colors.Armor or Color3.fromRGB(225, 225, 225)
    self.NameLabel.Visible = vis("Name")
    self.NameLabel.TextColor3 = self.Colors.Name or th.Text
    self.WeaponLabel.Visible = vis("Weapon")
    self.WeaponLabel.TextColor3 = self.Colors.Weapon or th.Text
    self.DistanceLabel.Visible = vis("Distance")
    self.DistanceLabel.TextColor3 = self.Colors.Distance or th.TextMuted
    self.FlagFrame.Visible = vis("Flags")
    for _, f in ipairs(self.FlagLabels) do
        f.Label.TextColor3 = f.Color or self.Colors.Flags or th.Text
    end
    -- the distance label moves up when the weapon is hidden
    self.DistanceLabel.Position = UDim2.new(0.5, 0, 1, self.WeaponLabel.Visible and 24 or 10)
end

function ESPPreview:OpenManager()
    local th = Library.Theme
    local width, itemH = 190, 28
    local height = #PreviewElements * itemH + 12
    local z = 120 + #Library.PopupStack * 10
    local frame = New("Frame", {
        Name = "ESPElements",
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = th.Popup,
        ZIndex = z,
        Parent = Library.Overlay,
    })
    Corner(5, frame)
    Stroke(frame, th.CardStroke)
    Padding(frame, 6, 10, 6, 10)
    List(frame, 0)
    local labels = { Health = "Health bar", Armor = "Armor bar" }
    for i, name in ipairs(PreviewElements) do
        local item = New("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, itemH),
            LayoutOrder = i,
            ZIndex = z + 1,
            Parent = frame,
        })
        local label = Library:Label(item, labels[name] or name, 12, "Regular", nil, { Size = UDim2.new(1, -24, 1, 0), ZIndex = z + 1 })
        local box = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            ZIndex = z + 1,
            Parent = item,
        })
        Corner(3, box)
        local stroke = Stroke(box, th.ElementStroke)
        local check = Icons.Create("check", 12, th.AccentText, box)
        check.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
        check.Frame.Position = UDim2.fromScale(0.5, 0.5)
        DeepZ(check.Frame, z + 2)
        local function paint()
            local onState = self.State[name]
            box.BackgroundColor3 = onState and th.Accent or th.Checkbox
            stroke.Transparency = onState and 1 or 0
            check.SetTransparency(onState and 0 or 1)
            label.TextColor3 = onState and th.Text or th.TextMuted
        end
        paint()
        item.MouseButton1Click:Connect(function()
            local new = not self.State[name]
            local bound = self.Binds[name]
            if bound and bound.Set then
                bound:Set(new)
            else
                self:SetElement(name, new)
            end
            self.State[name] = new
            self:_refresh()
            paint()
        end)
    end
    Library:OpenPopup(frame, self.ManageButton, nil, function()
        Library:PlacePopup(frame, self.ManageButton, width, height, 4)
    end)
end

--------------------------------------------------------------------------------
-- Config system (JSON via HttpService + executor file API)
--------------------------------------------------------------------------------
local function FileApi()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function SanitizeName(name)
    name = string.gsub(tostring(name or ""), "[^%w%s%-%_%.]", "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return name
end

function Library:GetConfigFolder()
    return self.ConfigFolder .. "/configs"
end

function Library:_ensureFolders()
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
        return FileApi()
    end
    local path = ""
    for part in string.gmatch(self:GetConfigFolder(), "[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then
            pcall(makefolder, path)
        end
    end
    return true
end

function Library:SerializeConfig()
    local data = { Version = self.Version, Flags = {} }
    for flag, option in pairs(self.Options) do
        if not option.NoSave and option._serialize then
            local ok, value = pcall(option._serialize, option)
            if ok then
                data.Flags[flag] = value
            end
        end
    end
    return HttpService:JSONEncode(data)
end

function Library:DeserializeConfig(json)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    if not ok or type(data) ~= "table" or type(data.Flags) ~= "table" then
        return false, "Config is corrupted"
    end
    for flag, value in pairs(data.Flags) do
        local option = self.Options[flag]
        if option and not option.NoSave and option._deserialize then
            local success, err = pcall(option._deserialize, option, value)
            if not success then
                warn("[Raven] failed to load flag " .. tostring(flag) .. ": " .. tostring(err))
            end
        end
    end
    return true
end

function Library:SaveConfig(name)
    name = SanitizeName(name)
    if name == "" then
        return false, "Enter a config name"
    end
    if not FileApi() then
        return false, "Your executor has no file functions"
    end
    self:_ensureFolders()
    local ok, err = pcall(writefile, self:GetConfigFolder() .. "/" .. name .. ".json", self:SerializeConfig())
    if not ok then
        return false, tostring(err)
    end
    self.ActiveConfig = name
    self:_updateWatermark()
    return true
end

function Library:LoadConfig(name)
    name = SanitizeName(name)
    if name == "" then
        return false, "Select a config"
    end
    if not FileApi() then
        return false, "Your executor has no file functions"
    end
    local path = self:GetConfigFolder() .. "/" .. name .. ".json"
    if type(isfile) == "function" and not isfile(path) then
        return false, "Config does not exist"
    end
    local ok, content = pcall(readfile, path)
    if not ok then
        return false, "Could not read config"
    end
    local success, err = self:DeserializeConfig(content)
    if not success then
        return false, err
    end
    self.ActiveConfig = name
    self:_updateWatermark()
    return true
end

function Library:DeleteConfig(name)
    name = SanitizeName(name)
    if name == "" then
        return false, "Select a config"
    end
    if type(delfile) ~= "function" then
        return false, "Your executor has no delfile"
    end
    local ok, err = pcall(delfile, self:GetConfigFolder() .. "/" .. name .. ".json")
    if not ok then
        return false, tostring(err)
    end
    if self.ActiveConfig == name then
        self.ActiveConfig = nil
        self:_updateWatermark()
    end
    return true
end

function Library:ListConfigs()
    local out = {}
    if type(listfiles) ~= "function" then
        return out
    end
    self:_ensureFolders()
    local ok, files = pcall(listfiles, self:GetConfigFolder())
    if not ok or type(files) ~= "table" then
        return out
    end
    for _, file in ipairs(files) do
        local name = string.match(file, "([^/\\]+)%.json$")
        if name then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

function Library:SetAutoload(name)
    if not FileApi() then
        return false, "Your executor has no file functions"
    end
    self:_ensureFolders()
    return (pcall(writefile, self.ConfigFolder .. "/autoload.txt", SanitizeName(name)))
end

function Library:LoadAutoload()
    if not FileApi() then
        return false
    end
    local path = self.ConfigFolder .. "/autoload.txt"
    if type(isfile) == "function" and not isfile(path) then
        return false
    end
    local ok, name = pcall(readfile, path)
    if ok and name and name ~= "" then
        return self:LoadConfig(name)
    end
    return false
end

--------------------------------------------------------------------------------
-- Ready-made pages matching the reference: Configs and Settings
--------------------------------------------------------------------------------
function Window:AddConfigsTab(opts)
    opts = opts or {}
    local lib = self.Library
    local tab = self:AddTab({ Name = opts.Name or "Configs", Icon = opts.Icon or "folder" })
    local listSection = tab:AddSection({ Name = "Configs", Icon = "folder", Side = "Left", PaddingTop = 8, PaddingBottom = 8 })
    local manage = tab:AddSection({ Name = "Manage", Icon = "save", Side = "Right", PaddingTop = 8, PaddingBottom = 10 })

    local list = listSection:AddList("Raven_ConfigList", {
        Text = "Saved configs",
        EmptyText = "No configs saved yet.",
        Values = lib:ListConfigs(),
        NoSave = true,
        Searchable = false,
    })
    local nameBox = manage:AddTextbox("Raven_ConfigName", {
        Text = "Config name",
        HideLabel = true,
        Placeholder = "Config name",
        Icon = "save",
        NoSave = true,
    })
    local saveButton = manage:AddButton({ Text = "Save", Style = "Primary", Icon = "save", Margin = 4 })
    local loadButton = manage:AddButton({ Text = "Load", Icon = "download", Disabled = true })
    local deleteButton = loadButton:AddButton({ Text = "Delete", Icon = "trash", Disabled = true, DoubleClick = true, ConfirmText = "Confirm" })
    local refreshButton = manage:AddButton({ Text = "Refresh", Icon = "refresh" })
    local folderButton = refreshButton:AddButton({ Text = "Open folder", Icon = "folder-open" })

    local function selected()
        return list.Value
    end
    local function sync()
        local has = selected() ~= nil
        loadButton:SetDisabled(not has)
        deleteButton:SetDisabled(not has)
    end
    local function refresh()
        list:Refresh(lib:ListConfigs())
        sync()
    end
    list:OnChanged(function(value)
        if value then
            nameBox:Set(value)
        end
        sync()
    end)

    saveButton:OnChanged(function()
        local name = nameBox.Value ~= "" and nameBox.Value or selected()
        local ok, err = lib:SaveConfig(name or "")
        if ok then
            refresh()
            list:Set(SanitizeName(name))
            lib:Notify({ Title = "Config saved", Content = "Saved as \"" .. SanitizeName(name) .. "\"", Type = "Success", Duration = 3, Icon = "save" })
        else
            lib:Notify({ Title = "Save failed", Content = err, Type = "Error", Duration = 4 })
        end
    end)
    loadButton:OnChanged(function()
        local name = selected()
        local ok, err = lib:LoadConfig(name or "")
        if ok then
            list:_rebuild()
            lib:Notify({ Title = "Config loaded", Content = "Loaded \"" .. tostring(name) .. "\"", Type = "Success", Duration = 3, Icon = "download" })
        else
            lib:Notify({ Title = "Load failed", Content = err, Type = "Error", Duration = 4 })
        end
    end)
    deleteButton:OnChanged(function()
        local name = selected()
        local ok, err = lib:DeleteConfig(name or "")
        if ok then
            refresh()
            lib:Notify({ Title = "Config deleted", Content = "Removed \"" .. tostring(name) .. "\"", Type = "Warning", Duration = 3, Icon = "trash" })
        else
            lib:Notify({ Title = "Delete failed", Content = err, Type = "Error", Duration = 4 })
        end
    end)
    refreshButton:OnChanged(function()
        refresh()
        lib:Notify({ Title = "Configs refreshed", Content = #list.Values .. " config(s) found", Duration = 2, Icon = "refresh" })
    end)
    folderButton:OnChanged(function()
        lib:_ensureFolders()
        local path = lib:GetConfigFolder()
        if type(setclipboard) == "function" then
            pcall(setclipboard, path)
        end
        lib:Notify({ Title = "Config folder", Content = "workspace/" .. path .. " (copied)", Duration = 4, Icon = "folder-open" })
    end)

    sync()
    self.ConfigsTab = tab
    self.ConfigList = list
    return tab
end

function Window:AddSettingsTab(opts)
    opts = opts or {}
    local lib = self.Library
    local window = self
    local tab = self:AddTab({ Name = opts.Name or "Settings", Icon = opts.Icon or "settings" })
    local interface = tab:AddSection({ Name = "Interface", Icon = "monitor", Side = "Left" })
    local accent = tab:AddSection({ Name = "Accent", Icon = "palette", Side = "Right", PaddingBottom = 8 })
    local about = tab:AddSection({ Name = "About", Icon = "info", Side = "Right", PaddingTop = 8, PaddingBottom = 4 })

    interface:AddLabel({ Text = "Menu key" }):AddKeybind("Raven_MenuKey", {
        Text = "Menu key",
        Default = lib.MenuKey,
        IsMenuKey = true,
    })
    interface:AddDropdown("Raven_UIScale", {
        Text = "UI scale",
        Inline = true,
        Values = { "75%", "90%", "100%", "110%", "125%", "150%" },
        Default = "100%",
        Callback = function(value)
            local n = tonumber(string.match(tostring(value), "%d+"))
            if n then
                window:SetScale(n / 100)
            end
        end,
    })
    interface:AddToggle("Raven_Animations", {
        Text = "Animations",
        Default = lib.Animations,
        IgnorePanic = true,
        Callback = function(v)
            lib.Animations = v
        end,
    })
    interface:AddToggle("Raven_Texture", {
        Text = "Background texture",
        Default = window.TextureEnabled,
        IgnorePanic = true,
        Callback = function(v)
            window:SetTexture(v)
        end,
    })
    interface:AddToggle("Raven_Watermark", {
        Text = "Watermark",
        Default = opts.Watermark == true,
        IgnorePanic = true,
        Callback = function(v)
            lib:SetWatermarkVisible(v)
        end,
    })
    interface:AddToggle("Raven_KeybindList", {
        Text = "Keybind list",
        Default = opts.KeybindList == true,
        IgnorePanic = true,
        Callback = function(v)
            lib:SetKeybindListVisible(v)
        end,
    })
    interface:AddToggle("Raven_Notifications", {
        Text = "Notifications",
        Default = lib.ShowNotifications,
        IgnorePanic = true,
        Callback = function(v)
            lib.ShowNotifications = v
        end,
    })

    local accentLabel = accent:AddLabel({ Text = "Accent color" })
    accentLabel:AddColorPicker("Raven_Accent", {
        Title = "Accent color",
        Default = lib.Theme.Accent,
        Callback = function(color)
            lib:SetAccent(color)
        end,
    })
    local picker = accentLabel.ColorPicker
    local swatches = accent:AddSwatches("Raven_AccentPreset", {
        Colors = opts.AccentPresets or lib.AccentPresets,
        Default = 1,
        NoSave = true,
        Callback = function(color)
            if not SameColor(picker.Value, color) then
                picker.Rainbow = false
                picker:Set(color)
            end
        end,
    })
    picker:OnChanged(function(color)
        if not SameColor(swatches.Value, color) then
            swatches.Value = color
            swatches:_refresh()
        end
    end)

    about:AddButton({
        Text = "Unload",
        Icon = "power",
        Style = "Danger",
        Margin = 4,
        MarginBottom = 4,
        Tooltip = "Disconnects everything and removes the UI",
        Callback = function()
            lib:Unload()
        end,
    })

    -- panel visibility follows the toggles initially
    lib:SetWatermarkVisible(opts.Watermark == true)
    lib:SetKeybindListVisible(opts.KeybindList == true)

    self.SettingsTab = tab
    return tab
end

--------------------------------------------------------------------------------
-- Global helpers
--------------------------------------------------------------------------------
function Library:Toggle(state)
    for _, window in ipairs(self.Windows) do
        window:Toggle(state)
    end
end

function Library:SetScale(scale)
    for _, window in ipairs(self.Windows) do
        window:SetScale(scale)
    end
end

function Library:SetAnimations(state)
    self.Animations = state and true or false
end

function Library:SetNotifications(state)
    self.ShowNotifications = state and true or false
end

function Library:SetMenuKey(key)
    self.MenuKey = NormalizeKey(key)
end

function Library:SetPanicKey(key)
    local k = NormalizeKey(key)
    self.PanicKey = k ~= "None" and k or nil
end

-- Turns every toggle off (except ones created with IgnorePanic = true) and hides the menu.
function Library:Panic()
    for _, option in pairs(self.Options) do
        if option.Kind == "Toggle" and option.Value and not option.Options.IgnorePanic then
            option:Set(false)
        end
    end
    self:Toggle(false)
    self:Notify({ Title = "Panic", Content = "Every feature was turned off.", Type = "Warning", Duration = 3, Icon = "power" })
end

function Library:OnUnload(fn)
    table.insert(self.OnUnloadCallbacks, fn)
end

function Library:Unload()
    if self.Unloaded then
        return
    end
    for _, fn in ipairs(self.OnUnloadCallbacks) do
        SafeCall(fn)
    end
    self:CloseAllPopups(true)
    self.Unloaded = true
    for tween in pairs(self.ActiveTweens) do
        pcall(function()
            tween:Cancel()
        end)
    end
    self.Maid:Clean()
    self.ScreenGui = nil
    self.Watermark = nil
    self.KeybindList = nil
    self.KeybindRows = nil
    self.TooltipFrame = nil
    self.TooltipTarget = nil
    self.CapturingPicker = nil
    self.ActiveDrag = nil
    self.Windows = {}
    self.Keybinds = {}
    self.Refreshers = {}
    self.Draggables = {}
    self.RainbowPickers = {}
    self.PopupStack = {}
    self.Searchables = {}
    ClearTable(self.Options)
    ClearTable(self.Flags)
    ClearTable(AutoFlagCount)
    local env = type(getgenv) == "function" and getgenv() or nil
    if env and env.RavenLibrary == self then
        env.RavenLibrary = nil
    end
end

-- Only one copy of the library at a time when re-executed.
do
    local env = type(getgenv) == "function" and getgenv() or nil
    if env then
        if env.RavenLibrary and env.RavenLibrary ~= Library and type(env.RavenLibrary.Unload) == "function" then
            pcall(env.RavenLibrary.Unload, env.RavenLibrary)
        end
        env.RavenLibrary = Library
    end
end

Library.Window = Window
Library.Tab = Tab
Library.SubTab = SubTab
Library.Container = Container
Library.Element = Element

return Library
