-- Vor Injector (Arceus X Neo compatible)
if _G.__VOR then pcall(function()_G.__VOR.g:Destroy()end) end
local L={} local function Log(m)
  local s="["..os.date("%H:%M:%S").."] "..tostring(m)
  table.insert(L,s) if #L>300 then table.remove(L,1) end
  pcall(print,s)
  if _G.__VOR and _G.__VOR.C then pcall(function()_G.__VOR.C.Text=table.concat(L,"\n")end) end
end

local S={}
-- sandbox game
S.game=setmetatable({
  GameId=1,PlaceId=1,
  HttpGet=function(_,u)
    Log("HttpGet:"..tostring(u))
    local ok,r=pcall(function() return game:HttpGet(u) end)
    if ok then Log("len="..#tostring(r)) return r else Log("err:"..tostring(r)) return "" end
  end
},{__index=function(_,k) Log("game."..tostring(k)) return nil end})

-- loadstring с дампом
local oL=loadstring
S.loadstring=function(c,n)
  Log("LS "..tostring(n).." len="..#tostring(c))
  if writefile then pcall(writefile,"vor_dump_"..os.time()..".lua",c) end
  if not oL then return nil,"no loadstring" end
  return oL(c,n)
end

S.print=function(...)
  local t={} for i=1,select("#",...) do t[#t+1]=tostring(select(i,...)) end
  Log("print:"..table.concat(t," "))
end
S.warn=S.print
for _,k in ipairs({"tostring","tonumber","type","pairs","ipairs","next","select","tick","time","Instance","Vector3","CFrame","UDim2","Color3","Enum","Ray","Region3"}) do S[k]=_G[k] end
S.table=table S.string=string S.math=math S.os=os S.task=task
S.wait=wait or task.wait S.spawn=spawn or task.spawn S.delay=delay or task.delay

-- хуки remote (вызываются по кнопке Hook, не на старте!)
local Hooked={}
local function HookRemote(r)
  if not r or not r.FireServer or Hooked[r] then return end
  Hooked[r]=true
  local orig=r.FireServer
  r.FireServer=function(self,...)
    local n="?" pcall(function() n=self:GetFullName() end)
    local a={} for i=1,select("#",...) do a[#a+1]=tostring(select(i,...)) end
    Log("FS "..n.."("..table.concat(a,",")..")")
    -- return orig(self,...) -- раскомментируй для реальной отправки
  end
end

-- GUI
local P=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui",10)
if not P then return end
local g=Instance.new("ScreenGui") g.ResetOnSpawn=false g.Name="Vor" g.Parent=P

local M=Instance.new("Frame")
M.Size=UDim2.new(0,320,0,420) M.Position=UDim2.new(0.5,-160,0.5,-210)
M.BackgroundColor3=Color3.fromRGB(25,25,30) M.BorderSizePixel=0 M.Active=true M.Parent=g
Instance.new("UICorner",M).CornerRadius=UDim.new(0,10)

local T=Instance.new("TextLabel")
T.Size=UDim2.new(1,0,0,30) T.BackgroundColor3=Color3.fromRGB(35,35,45)
T.BorderSizePixel=0 T.Text="Vor Injector" T.TextColor3=Color3.fromRGB(200,200,220)
T.Font=Enum.Font.GothamBold T.TextSize=14 T.Parent=M
Instance.new("UICorner",T).CornerRadius=UDim.new(0,10)

-- drag через тач (Arceus X Neo не поддерживает Draggable)
do
  local dragging,startPos,startInput
  T.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
      dragging=true startPos=M.Position startInput=i.Position
      i.Changed:Connect(function()
        if i.UserInputState==Enum.UserInputState.End then dragging=false end
      end)
    end
  end)
  game:GetService("UserInputService").InputChanged:Connect(function(i)
    if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
      local d=i.Position-startInput
      M.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
  end)
end

local TB=Instance.new("TextBox")
TB.Size=UDim2.new(1,-20,0,140) TB.Position=UDim2.new(0,10,0,38)
TB.BackgroundColor3=Color3.fromRGB(15,15,20) TB.BorderSizePixel=0
TB.Text="-- code\nprint('hi')" TB.TextColor3=Color3.fromRGB(180,220,180)
TB.PlaceholderText="Lua..." TB.Font=Enum.Font.Code T.TextSize=13
TB.TextXAlignment=Enum.TextXAlignment.Left TB.TextYAlignment=Enum.TextYAlignment.Top
TB.ClearTextOnFocus=false TB.MultiLine=true TB.Parent=M
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,6)
local TBp=Instance.new("UIPadding",TB)
TBp.PaddingLeft=UDim.new(0,6) TBp.PaddingRight=UDim.new(0,6) TBp.PaddingTop=UDim.new(0,6) TBp.PaddingBottom=UDim.new(0,6)
TB.TextSize=13

local CB=Instance.new("TextBox")
CB.Size=UDim2.new(1,-20,0,150) CB.Position=UDim2.new(0,10,0,186)
CB.BackgroundColor3=Color3.fromRGB(12,12,16) CB.BorderSizePixel=0
CB.Text="" CB.TextColor3=Color3.fromRGB(140,200,140) CB.Font=Enum.Font.Code
CB.TextSize=11 CB.TextXAlignment=Enum.TextXAlignment.Left CB.TextYAlignment=Enum.TextYAlignment.Top
CB.MultiLine=true CB.TextEditable=false CB.Parent=M
Instance.new("UICorner",CB).CornerRadius=UDim.new(0,6)
local CBp=Instance.new("UIPadding",CB)
CBp.PaddingLeft=UDim.new(0,6) CBp.PaddingRight=UDim.new(0,6) CBp.PaddingTop=UDim.new(0,6) CBp.PaddingBottom=UDim.new(0,6)

local B=Instance.new("TextButton")
B.Size=UDim2.new(1,-20,0,36) B.Position=UDim2.new(0,10,1,-46)
B.BackgroundColor3=Color3.fromRGB(80,140,220) B.BorderSizePixel=0
B.Text="INJECT" B.TextColor3=Color3.fromRGB(255,255,255)
B.Font=Enum.Font.GothamBold B.TextSize=14 B.Parent=M
Instance.new("UICorner",B).CornerRadius=UDim.new(0,8)

local HK=Instance.new("TextButton")
HK.Size=UDim2.new(1,-20,0,26) HK.Position=UDim2.new(0,10,1,-82)
HK.BackgroundColor3=Color3.fromRGB(90,90,110) HK.BorderSizePixel=0
HK.Text="HOOK REMOTES" HK.TextColor3=Color3.fromRGB(255,255,255)
HK.Font=Enum.Font.GothamBold HK.TextSize=12 HK.Parent=M
Instance.new("UICorner",HK).CornerRadius=UDim.new(0,6)

_G.__VOR={g=g,C=CB}
Log("Vor готов")

-- Hook по кнопке
HK.MouseButton1Click:Connect(function()
  Log("Сканирую Remote*...")
  task.spawn(function()
    local ok,d=pcall(function() return game:GetDescendants() end)
    if not ok then Log("desc err:"..tostring(d)) return end
    local n=0
    for _,o in ipairs(d) do
      if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then HookRemote(o) n=n+1 end
    end
    Log("Захучено remote: "..n)
  end)
end)

-- Inject
B.MouseButton1Click:Connect(function()
  local c=TB.Text
  if not c or c=="" then Log("пусто") return end
  Log("===INJECT===")
  local f,e=S.loadstring(c,"injected")
  if not f then Log("compile:"..tostring(e)) return end
  local ok,er=pcall(function()
    -- setfenv с fallback
    if setfenv then
      pcall(setfenv,f,S)
    elseif getfenv and debug and debug.setfenv then
      pcall(debug.setfenv,f,S)
    end
    f()
  end)
  if not ok then Log("run:"..tostring(er)) end
  Log("===END===")
end)

return _G.__VOR
