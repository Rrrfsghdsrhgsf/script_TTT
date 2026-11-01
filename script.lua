-- ============================================================
-- Vor Teleporter + Map Scanner
-- Arceus X Neo compatible
-- ============================================================
if _G.__VOR_TP then pcall(function() _G.__VOR_TP.g:Destroy() end) end

local L = {}
local function Log(m)
    local s = "[" .. os.date("%H:%M:%S") .. "] " .. tostring(m)
    table.insert(L, s)
    if #L > 400 then table.remove(L, 1) end
    pcall(print, s)
    if _G.__VOR_TP and _G.__VOR_TP.C then
        pcall(function() _G.__VOR_TP.C.Text = table.concat(L, "\n") end)
    end
end

-- ============================================================
-- Хранилище
-- ============================================================
local State = {
    -- Захваченные точки:
    -- { name="lobby"/"map", pos=Vector3, block="Part name", time=os.time() }
    LobbyPoints = {},
    MapPoints   = {},
    LastPos     = nil,
    LastJump    = 0,
    ScanThread  = nil,
    IsScanning  = false,
    -- Порог "скачка" — если дистанция > JUMP_THRESHOLD между кадрами, это телепорт
    JUMP_THRESHOLD = 80,   -- studs
    SAMPLE_RATE    = 0.15, -- сек
}

-- ============================================================
-- Сканер: определяет блок под игроком
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local function getGroundBlock()
    local char = lp.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end

    local origin = hrp.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, Vector3.new(0, -20, 0), params)
    if result and result.Instance then
        return result.Instance, origin
    end
    return nil, origin
end

-- ============================================================
-- Классификация: лобби или карта
-- ============================================================
-- Эвристики (настраиваются):
--   1. По имени места/игры — если "lobby"/"hub"/"spawn" в названии
--   2. По координатам — лобби обычно Y > 100 или изолировано
--   3. По блоку — если блок под игроком называется Spawn/Lobby/Baseplate
local function classify(pos, blockName)
    if blockName then
        local bn = string.lower(blockName)
        if bn:find("lobby") or bn:find("spawn") or bn:find("hub") or bn:find("baseplate") then
            return "lobby"
        end
    end
    -- если Y сильно выше 100 — вероятно лобби (висят на спавне)
    if pos and pos.Y > 150 then return "lobby" end
    return "map"
end

-- ============================================================
-- Сканер (главный цикл)
-- ============================================================
local function startScan()
    if State.IsScanning then Log("Сканер уже идёт") return end
    State.IsScanning = true
    Log("=== SCANNER START ===")

    State.ScanThread = task.spawn(function()
        while State.IsScanning do
            local ok, err = pcall(function()
                local block, pos = getGroundBlock()
                if not pos then return end

                local blockName = block and block.Name or nil

                -- Скачок?
                if State.LastPos then
                    local dist = (pos - State.LastPos).Magnitude
                    if dist > State.JUMP_THRESHOLD then
                        State.LastJump = tick()
                        local kind = classify(pos, blockName)
                        local entry = {
                            pos = pos,
                            block = blockName or "?",
                            kind = kind,
                            dist = dist,
                            time = os.time(),
                        }
                        if kind == "lobby" then
                            table.insert(State.LobbyPoints, entry)
                        else
                            table.insert(State.MapPoints, entry)
                        end
                        Log(string.format(
                            "JUMP %.1f studs → %s | block=%s | pos=(%.1f,%.1f,%.1f)",
                            dist, kind, tostring(blockName),
                            pos.X, pos.Y, pos.Z
                        ))
                    end
                end
                State.LastPos = pos

                -- Периодический лог текущей позиции (чтобы видеть что сканер жив)
                if tick() - State.LastJump > 3 then
                    pcall(function()
                        if _G.__VOR_TP and _G.__VOR_TP.Status then
                            _G.__VOR_TP.Status.Text = string.format(
                                "Pos: %.1f, %.1f, %.1f | Block: %s",
                                pos.X, pos.Y, pos.Z, tostring(blockName)
                            )
                        end
                    end)
                end
            end)
            if not ok then Log("scan err: " .. tostring(err)) end
            task.wait(State.SAMPLE_RATE)
        end
    end)
end

local function stopScan()
    State.IsScanning = false
    Log("=== SCANNER STOP ===")
end

-- ============================================================
-- Телепорт
-- ============================================================
local function teleportTo(pos)
    local char = lp.Character
    if not char then Log("нет персонажа") return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then Log("нет HRP") return end
    -- CFrame прямое — самый надёжный вариант в Arceus X Neo
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    Log("TP → " .. tostring(pos))
end

-- ============================================================
-- GUI
-- ============================================================
local P = lp:WaitForChild("PlayerGui", 10)
if not P then Log("нет PlayerGui") return end

local g = Instance.new("ScreenGui")
g.Name = "VorTeleporter"
g.ResetOnSpawn = false
g.Parent = P

local M = Instance.new("Frame")
M.Size = UDim2.new(0, 340, 0, 480)
M.Position = UDim2.new(0.5, -170, 0.5, -240)
M.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
M.BorderSizePixel = 0
M.Active = true
M.Parent = g
Instance.new("UICorner", M).CornerRadius = UDim.new(0, 10)

-- Заголовок + drag
local T = Instance.new("TextLabel")
T.Size = UDim2.new(1, 0, 0, 32)
T.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
T.BorderSizePixel = 0
T.Text = "Vor Teleporter"
T.TextColor3 = Color3.fromRGB(200, 200, 220)
T.Font = Enum.Font.GothamBold
T.TextSize = 14
T.Parent = M
Instance.new("UICorner", T).CornerRadius = UDim.new(0, 10)

do
    local dragging, startPos, startInput
    T.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = M.Position
            startInput = i.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            M.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Статус
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 22)
Status.Position = UDim2.new(0, 10, 0, 36)
Status.BackgroundTransparency = 1
Status.Text = "Pos: —"
Status.TextColor3 = Color3.fromRGB(160, 220, 160)
Status.Font = Enum.Font.Code
Status.TextSize = 11
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = M

-- Кнопки управления сканером
local ScanBtn = Instance.new("TextButton")
ScanBtn.Size = UDim2.new(0.5, -15, 0, 32)
ScanBtn.Position = UDim2.new(0, 10, 0, 62)
ScanBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
ScanBtn.BorderSizePixel = 0
ScanBtn.Text = "SCAN ON"
ScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.TextSize = 12
ScanBtn.Parent = M
Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 6)

local ScanOffBtn = Instance.new("TextButton")
ScanOffBtn.Size = UDim2.new(0.5, -15, 0, 32)
ScanOffBtn.Position = UDim2.new(0.5, 5, 0, 62)
ScanOffBtn.BackgroundColor3 = Color3.fromRGB(160, 80, 80)
ScanOffBtn.BorderSizePixel = 0
ScanOffBtn.Text = "SCAN OFF"
ScanOffBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanOffBtn.Font = Enum.Font.GothamBold
ScanOffBtn.TextSize = 12
ScanOffBtn.Parent = M
Instance.new("UICorner", ScanOffBtn).CornerRadius = UDim.new(0, 6)

-- Список захваченных точек (скролл)
local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(1, -20, 0, 200)
ListFrame.Position = UDim2.new(0, 10, 0, 102)
ListFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
ListFrame.BorderSizePixel = 0
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.ScrollBarThickness = 4
ListFrame.Parent = M
Instance.new("UICorner", ListFrame).CornerRadius = UDim.new(0, 6)
local ListLayout = Instance.new("UIListLayout", ListFrame)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 4)
local ListPad = Instance.new("UIPadding", ListFrame)
ListPad.PaddingLeft = UDim.new(0, 6)
ListPad.PaddingRight = UDim.new(0, 6)
ListPad.PaddingTop = UDim.new(0, 6)
ListPad.PaddingBottom = UDim.new(0, 6)

-- Кнопки телепорта
local TpLobby = Instance.new("TextButton")
TpLobby.Size = UDim2.new(1, -20, 0, 34)
TpLobby.Position = UDim2.new(0, 10, 0, 312)
TpLobby.BackgroundColor3 = Color3.fromRGB(90, 130, 200)
TpLobby.BorderSizePixel = 0
TpLobby.Text = "TP → LOBBY"
TpLobby.TextColor3 = Color3.fromRGB(255, 255, 255)
TpLobby.Font = Enum.Font.GothamBold
TpLobby.TextSize = 13
TpLobby.Parent = M
Instance.new("UICorner", TpLobby).CornerRadius = UDim.new(0, 6)

local TpMap = Instance.new("TextButton")
TpMap.Size = UDim2.new(1, -20, 0, 34)
TpMap.Position = UDim2.new(0, 10, 0, 352)
TpMap.BackgroundColor3 = Color3.fromRGB(200, 130, 90)
TpMap.BorderSizePixel = 0
TpMap.Text = "TP → MAP"
TpMap.TextColor3 = Color3.fromRGB(255, 255, 255)
TpMap.Font = Enum.Font.GothamBold
TpMap.TextSize = 13
TpMap.Parent = M
Instance.new("UICorner", TpMap).CornerRadius = UDim.new(0, 6)

-- Ручной ввод координат
local ManualX = Instance.new("TextBox")
ManualX.Size = UDim2.new(0.32, -8, 0, 26)
ManualX.Position = UDim2.new(0, 10, 0, 392)
ManualX.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ManualX.BorderSizePixel = 0
ManualX.Text = "X"
ManualX.TextColor3 = Color3.fromRGB(220, 220, 220)
ManualX.Font = Enum.Font.Code
ManualX.TextSize = 12
ManualX.Parent = M
Instance.new("UICorner", ManualX).CornerRadius = UDim.new(0, 4)

local ManualY = Instance.new("TextBox")
ManualY.Size = UDim2.new(0.32, -8, 0, 26)
ManualY.Position = UDim2.new(0.32, 5, 0, 392)
ManualY.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ManualY.BorderSizePixel = 0
ManualY.Text = "Y"
ManualY.TextColor3 = Color3.fromRGB(220, 220, 220)
ManualY.Font = Enum.Font.Code
ManualY.TextSize = 12
ManualY.Parent = M
Instance.new("UICorner", ManualY).CornerRadius = UDim.new(0, 4)

local ManualZ = Instance.new("TextBox")
ManualZ.Size = UDim2.new(0.32, -8, 0, 26)
ManualZ.Position = UDim2.new(0.64, 0, 0, 392)
ManualZ.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ManualZ.BorderSizePixel = 0
ManualZ.Text = "Z"
ManualZ.TextColor3 = Color3.fromRGB(220, 220, 220)
ManualZ.Font = Enum.Font.Code
ManualZ.TextSize = 12
ManualZ.Parent = M
Instance.new("UICorner", ManualZ).CornerRadius = UDim.new(0, 4)

local GoBtn = Instance.new("TextButton")
GoBtn.Size = UDim2.new(1, -20, 0, 28)
GoBtn.Position = UDim2.new(0, 10, 0, 424)
GoBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 200)
GoBtn.BorderSizePixel = 0
GoBtn.Text = "GO (manual)"
GoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GoBtn.Font = Enum.Font.GothamBold
GoBtn.TextSize = 12
GoBtn.Parent = M
Instance.new("UICorner", GoBtn).CornerRadius = UDim.new(0, 6)

-- Экспорт данных сканера
local ExportBtn = Instance.new("TextButton")
ExportBtn.Size = UDim2.new(1, -20, 0, 24)
ExportBtn.Position = UDim2.new(0, 10, 0, 456)
ExportBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
ExportBtn.BorderSizePixel = 0
ExportBtn.Text = "EXPORT scan → console"
ExportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ExportBtn.Font = Enum.Font.GothamBold
ExportBtn.TextSize = 11
ExportBtn.Parent = M
Instance.new("UICorner", ExportBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- Обновление списка точек
-- ============================================================
local function refreshList()
    for _, child in ipairs(ListFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local all = {}
    for i, e in ipairs(State.LobbyPoints) do
        all[#all + 1] = { kind = "lobby", idx = i, entry = e }
    end
    for i, e in ipairs(State.MapPoints) do
        all[#all + 1] = { kind = "map", idx = i, entry = e }
    end
    table.sort(all, function(a, b) return a.entry.time > b.entry.time end)

    for _, item in ipairs(all) do
        local e = item.entry
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 28)
        btn.BackgroundColor3 = item.kind == "lobby"
            and Color3.fromRGB(60, 90, 140)
            or Color3.fromRGB(140, 90, 60)
        btn.BorderSizePixel = 0
        btn.Text = string.format("[%s] %.0f,%.0f,%.0f | %s",
            item.kind, e.pos.X, e.pos.Y, e.pos.Z, e.block)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Code
        btn.TextSize = 10
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = ListFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            teleportTo(e.pos)
        end)
    end

    ListFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 12)
end

-- ============================================================
-- Обработчики
-- ============================================================
ScanBtn.MouseButton1Click:Connect(function()
    startScan()
    ScanBtn.BackgroundColor3 = Color3.fromRGB(140, 200, 140)
end)

ScanOffBtn.MouseButton1Click:Connect(function()
    stopScan()
    ScanBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
end)

TpLobby.MouseButton1Click:Connect(function()
    if #State.LobbyPoints == 0 then Log("нет lobby-точек — запусти SCAN и телепортнись вручную") return end
    teleportTo(State.LobbyPoints[#State.LobbyPoints].pos)
end)

TpMap.MouseButton1Click:Connect(function()
    if #State.MapPoints == 0 then Log("нет map-точек — запусти SCAN и телепортнись вручную") return end
    teleportTo(State.MapPoints[#State.MapPoints].pos)
end)

GoBtn.MouseButton1Click:Connect(function()
    local x = tonumber(ManualX.Text)
    local y = tonumber(ManualY.Text)
    local z = tonumber(ManualZ.Text)
    if not (x and y and z) then Log("введи координаты X/Y/Z") return end
    teleportTo(Vector3.new(x, y, z))
end)

ExportBtn.MouseButton1Click:Connect(function()
    print("=== VOR SCAN EXPORT ===")
    print("LOBBY_POINTS = {")
    for _, e in ipairs(State.LobbyPoints) do
        print(string.format("  {pos=Vector3.new(%.1f,%.1f,%.1f), block=%q},",
            e.pos.X, e.pos.Y, e.pos.Z, e.block))
    end
    print("}")
    print("MAP_POINTS = {")
    for _, e in ipairs(State.MapPoints) do
        print(string.format("  {pos=Vector3.new(%.1f,%.1f,%.1f), block=%q},",
            e.pos.X, e.pos.Y, e.pos.Z, e.block))
    end
    print("}")
    print("=== END EXPORT ===")
    Log("экспорт в консоль (открой консоль Arceus X Neo)")
end)

-- Периодическое обновление списка
task.spawn(function()
    while g.Parent do
        refreshList()
        task.wait(1)
    end
end)

_G.__VOR_TP = { g = g, C = ListFrame, Status = Status }
Log("Vor Teleporter готов")
return _G.__VOR_TP
