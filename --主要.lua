--主要
-- 在脚本开始处添加调试输出
print("Starting Aimbot UI initialization...")

--// Cache and API Check
local function CheckSupport()
    local supported = true
    local missing = {}
    
    if not mousemoverel and (not Input or not Input.MouseMove) then
        supported = false
        table.insert(missing, "MouseMove API")
    end
    
    if not Drawing then
        supported = false
        table.insert(missing, "Drawing API")
    end
    
    return supported, missing
end

local isSupported, missingFeatures = CheckSupport()
if not isSupported then
    local errorMsg = "Aimbot cannot run - Missing required features: " .. table.concat(missingFeatures, ", ")
    if game:GetService("StarterGui") then
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Aimbot Error",
            Text = errorMsg,
            Duration = 10
        })
    end
    warn(errorMsg)
    return
end

local select = select
local pcall, getgenv, next, Vector2, mathclamp, type, mousemoverel = select(1, pcall, getgenv, next, Vector2.new, math.clamp, type, mousemoverel or (Input and Input.MouseMove))

--// Preventing Multiple Processes

pcall(function()
	getgenv().Aimbot.Functions:Exit()
end)

--// Environment

getgenv().Aimbot = {}
local Environment = getgenv().Aimbot

--// Services

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--// Variables

local RequiredDistance, Typing, Running, Animation, ServiceConnections = 2000, false, false, nil, {}

--// Script Settings

Environment.Settings = {
	Enabled = true,
	TeamCheck = false,
	AimPart = "Head",  -- 默认瞄准头部
	ValidParts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "RightFoot", "LeftFoot"},  -- 有效的瞄准部位
	AliveCheck = true,
	WallCheck = false,
	Sensitivity = 0,
	ThirdPerson = false,
	ThirdPersonSensitivity = 3,
	TriggerKey = "MouseButton2",
	Toggle = false,
	Prediction = {
		Enabled = false,
		Velocity = 0
	}
}

Environment.FOVSettings = {
	Enabled = true,
	Visible = true,
	Amount = 90,
	Color = Color3.fromRGB(255, 255, 255),
	LockedColor = Color3.fromRGB(255, 70, 70),
	Transparency = 0.5,
	Sides = 60,
	Thickness = 1,
	Filled = false
}

Environment.FOVCircle = Drawing.new("Circle")

--// Functions

local function CancelLock()
	Environment.Locked = nil
	if Animation then Animation:Cancel() end
	Environment.FOVCircle.Color = Environment.FOVSettings.Color
	print("Aimbot lock cancelled")
end

local function GetClosestPlayerToCursor()
    local closestPlayer = nil
    local shortestDistance = Environment.FOVSettings.Amount
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer then
            -- 检查角色和目标部位是否存在
            if v.Character then
                local targetPart = v.Character:FindFirstChild(Environment.Settings.AimPart)
                if not targetPart then
                    -- 如果当前瞄准部位不存在，尝试使用HumanoidRootPart作为备选
                    targetPart = v.Character:FindFirstChild("HumanoidRootPart")
                end
                
                if targetPart then
                    -- Team Check
                    if not Environment.Settings.TeamCheck or v.Team ~= LocalPlayer.Team then
                        -- Alive Check
                        if not Environment.Settings.AliveCheck or (v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0) then
                            local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                            
                            if onScreen then
                                local magnitude = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                                
                                -- Wall Check
                                local canSee = true
                                if Environment.Settings.WallCheck then
                                    local ray = Ray.new(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * 2000)
                                    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, v.Character})
                                    canSee = not hit
                                end
                                
                                if magnitude < shortestDistance and canSee then
                                    closestPlayer = v
                                    shortestDistance = magnitude
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function AimAt(targetPart)
    local targetPos = camera:WorldToScreenPoint(targetPart.Position)
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    local movePos = Vector2.new((targetPos.X - mousePos.X) * Environment.Settings.Sensitivity, (targetPos.Y - mousePos.Y) * Environment.Settings.Sensitivity)
    mousemoverel(movePos.X, movePos.Y)
end

--// Typing Check

ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function()
	Typing = true
end)

ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function()
	Typing = false
end)

--// Main

local function Load()
	ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
		if Environment.FOVSettings.Enabled and Environment.Settings.Enabled then
			Environment.FOVCircle.Radius = Environment.FOVSettings.Amount
			Environment.FOVCircle.Thickness = Environment.FOVSettings.Thickness
			Environment.FOVCircle.Filled = Environment.FOVSettings.Filled
			Environment.FOVCircle.NumSides = Environment.FOVSettings.Sides
			Environment.FOVCircle.Color = Environment.FOVSettings.Color
			Environment.FOVCircle.Transparency = Environment.FOVSettings.Transparency
			Environment.FOVCircle.Visible = Environment.FOVSettings.Visible
			Environment.FOVCircle.Position = Vector2(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
		else
			Environment.FOVCircle.Visible = false
		end

		if Running and Environment.Settings.Enabled then
			local player = GetClosestPlayerToCursor()
			if player and player.Character and player.Character:FindFirstChild(Environment.Settings.AimPart) then
				AimAt(player.Character[Environment.Settings.AimPart])
			end
		end
	end)

	ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
		if not Typing then
			pcall(function()
				if Input.KeyCode == Enum.KeyCode[Environment.Settings.TriggerKey] then
					if Environment.Settings.Toggle then
						Running = not Running

						if not Running then
							CancelLock()
						end
					else
						Running = true
					end
				end
			end)

			pcall(function()
				if Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
					if Environment.Settings.Toggle then
						Running = not Running

						if not Running then
							CancelLock()
						end
					else
						Running = true
					end
				end
			end)
		end
	end)

	ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
		if not Typing then
			if not Environment.Settings.Toggle then
				pcall(function()
					if Input.KeyCode == Enum.KeyCode[Environment.Settings.TriggerKey] then
						Running = false; CancelLock()
					end
				end)

				pcall(function()
					if Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
						Running = false; CancelLock()
					end
				end)
			end
		end
	end)
end

--// Functions

Environment.Functions = {}

function Environment.Functions:Exit()
	for _, v in next, ServiceConnections do
		v:Disconnect()
	end

	if Environment.FOVCircle.Remove then Environment.FOVCircle:Remove() end

	getgenv().Aimbot.Functions = nil
	getgenv().Aimbot = nil
	
	Load = nil; GetClosestPlayerToCursor = nil; AimAt = nil
end

function Environment.Functions:Restart()
	for _, v in next, ServiceConnections do
		v:Disconnect()
	end

	Load()
end

function Environment.Functions:ResetSettings()
	Environment.Settings = {
		Enabled = true,
		TeamCheck = false,
		AimPart = "Head",  -- 默认瞄准头部
		ValidParts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "RightFoot", "LeftFoot"},  -- 有效的瞄准部位
		AliveCheck = true,
		WallCheck = false,
		Sensitivity = 0,
		ThirdPerson = false,
		ThirdPersonSensitivity = 3,
		TriggerKey = "MouseButton2",
		Toggle = false,
		Prediction = {
			Enabled = false,
			Velocity = 0
		}
	}

	Environment.FOVSettings = {
		Enabled = true,
		Visible = true,
		Amount = 90,
		Color = Color3.fromRGB(255, 255, 255),
		LockedColor = Color3.fromRGB(255, 70, 70),
		Transparency = 0.5,
		Sides = 60,
		Thickness = 1,
		Filled = false
	}
end

function Environment.Functions:SetAimPart(newPart)
    if table.find(Environment.Settings.ValidParts, newPart) then
        Environment.Settings.AimPart = newPart
        print("瞄准部位已切换到: " .. newPart)
        return true
    else
        warn("无效的瞄准部位: " .. newPart)
        return false
    end
end

--// Load

Load()

-- Create UI elements
local function CreateUI()
    local AimbotUI = Instance.new("ScreenGui")
    AimbotUI.Name = "AimbotUI"
    
    -- 创建一个小型的显示/隐藏按钮
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0, 40, 0, 40)
    ToggleButton.Position = UDim2.new(0, 20, 0, 20)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Text = "A"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 18
    ToggleButton.Font = Enum.Font.SourceSansBold
    ToggleButton.Parent = AimbotUI
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 20)
    ToggleCorner.Parent = ToggleButton
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 300, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false  -- 默认隐藏主界面
    
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "狗桂"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.SourceSansBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar
    
    -- 添加版本标签
    local VersionLabel = Instance.new("TextLabel")
    VersionLabel.Name = "VersionLabel"
    VersionLabel.Size = UDim2.new(0, 100, 1, 0)
    VersionLabel.Position = UDim2.new(1, -110, 0, 0)
    VersionLabel.BackgroundTransparency = 1
    VersionLabel.Text = "v1.0"
    VersionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    VersionLabel.TextSize = 14
    VersionLabel.Font = Enum.Font.SourceSans
    VersionLabel.TextXAlignment = Enum.TextXAlignment.Right
    VersionLabel.Parent = TitleBar
    
    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 40, 0, 40)
    CloseButton.Position = UDim2.new(1, -50, 1, -50)  -- 右下角位置
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
    CloseButton.Text = "×"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 24
    CloseButton.Font = Enum.Font.SourceSansBold
    CloseButton.Parent = MainFrame
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 20)
    CloseCorner.Parent = CloseButton
    
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, -20, 1, -60)
    Content.Position = UDim2.new(0, 10, 0, 50)
    Content.BackgroundTransparency = 1
    Content.Parent = MainFrame
    
    -- Add Aimbot Toggle
    local AimbotFrame = Instance.new("Frame")
    AimbotFrame.Name = "AimbotFrame"
    AimbotFrame.Size = UDim2.new(1, 0, 0, 30)
    AimbotFrame.BackgroundTransparency = 1
    AimbotFrame.Parent = Content
    
    local AimbotLabel = Instance.new("TextLabel")
    AimbotLabel.Name = "AimbotLabel"
    AimbotLabel.Size = UDim2.new(0.7, 0, 1, 0)
    AimbotLabel.BackgroundTransparency = 1
    AimbotLabel.Text = "Aimbot"
    AimbotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    AimbotLabel.TextSize = 14
    AimbotLabel.Font = Enum.Font.SourceSans
    AimbotLabel.TextXAlignment = Enum.TextXAlignment.Left
    AimbotLabel.Parent = AimbotFrame
    
    local AimbotButton = Instance.new("TextButton")
    AimbotButton.Name = "AimbotButton"
    AimbotButton.Size = UDim2.new(0.3, -10, 1, -10)
    AimbotButton.Position = UDim2.new(0.7, 0, 0, 5)
    AimbotButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
    AimbotButton.Text = "OFF"
    AimbotButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AimbotButton.TextSize = 14
    AimbotButton.Font = Enum.Font.SourceSansBold
    AimbotButton.Parent = AimbotFrame
    
    -- Add Team Check Toggle
    local TeamCheckFrame = Instance.new("Frame")
    TeamCheckFrame.Name = "TeamCheckFrame"
    TeamCheckFrame.Size = UDim2.new(1, 0, 0, 30)
    TeamCheckFrame.Position = UDim2.new(0, 0, 0, 40)
    TeamCheckFrame.BackgroundTransparency = 1
    TeamCheckFrame.Parent = Content
    
    local TeamCheckLabel = Instance.new("TextLabel")
    TeamCheckLabel.Name = "TeamCheckLabel"
    TeamCheckLabel.Size = UDim2.new(0.7, 0, 1, 0)
    TeamCheckLabel.BackgroundTransparency = 1
    TeamCheckLabel.Text = "Team Check"
    TeamCheckLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeamCheckLabel.TextSize = 14
    TeamCheckLabel.Font = Enum.Font.SourceSans
    TeamCheckLabel.TextXAlignment = Enum.TextXAlignment.Left
    TeamCheckLabel.Parent = TeamCheckFrame
    
    local TeamCheckButton = Instance.new("TextButton")
    TeamCheckButton.Name = "TeamCheckButton"
    TeamCheckButton.Size = UDim2.new(0.3, -10, 1, -10)
    TeamCheckButton.Position = UDim2.new(0.7, 0, 0, 5)
    TeamCheckButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
    TeamCheckButton.Text = "OFF"
    TeamCheckButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeamCheckButton.TextSize = 14
    TeamCheckButton.Font = Enum.Font.SourceSansBold
    TeamCheckButton.Parent = TeamCheckFrame
    
    -- Add ESP Toggle
    local ESPFrame = Instance.new("Frame")
    ESPFrame.Name = "ESPFrame"
    ESPFrame.Size = UDim2.new(1, 0, 0, 30)
    ESPFrame.Position = UDim2.new(0, 0, 0, 80)
    ESPFrame.BackgroundTransparency = 1
    ESPFrame.Parent = Content
    
    local ESPLabel = Instance.new("TextLabel")
    ESPLabel.Name = "ESPLabel"
    ESPLabel.Size = UDim2.new(0.7, 0, 1, 0)
    ESPLabel.BackgroundTransparency = 1
    ESPLabel.Text = "ESP"
    ESPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ESPLabel.TextSize = 14
    ESPLabel.Font = Enum.Font.SourceSans
    ESPLabel.TextXAlignment = Enum.TextXAlignment.Left
    ESPLabel.Parent = ESPFrame
    
    local ESPButton = Instance.new("TextButton")
    ESPButton.Name = "ESPButton"
    ESPButton.Size = UDim2.new(0.3, -10, 1, -10)
    ESPButton.Position = UDim2.new(0.7, 0, 0, 5)
    ESPButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
    ESPButton.Text = "OFF"
    ESPButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ESPButton.TextSize = 14
    ESPButton.Font = Enum.Font.SourceSansBold
    ESPButton.Parent = ESPFrame
    
    -- Add AimPart Toggle
    local AimPartFrame = Instance.new("Frame")
    AimPartFrame.Name = "AimPartFrame"
    AimPartFrame.Size = UDim2.new(1, 0, 0, 30)
    AimPartFrame.Position = UDim2.new(0, 0, 0, 120)  -- 放在ESP按钮下面
    AimPartFrame.BackgroundTransparency = 1
    AimPartFrame.Parent = Content
    
    local AimPartLabel = Instance.new("TextLabel")
    AimPartLabel.Name = "AimPartLabel"
    AimPartLabel.Size = UDim2.new(0.7, 0, 1, 0)
    AimPartLabel.BackgroundTransparency = 1
    AimPartLabel.Text = "瞄准部位"
    AimPartLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    AimPartLabel.TextSize = 14
    AimPartLabel.Font = Enum.Font.SourceSans
    AimPartLabel.TextXAlignment = Enum.TextXAlignment.Left
    AimPartLabel.Parent = AimPartFrame
    
    local AimPartButton = Instance.new("TextButton")
    AimPartButton.Name = "AimPartButton"
    AimPartButton.Size = UDim2.new(0.3, -10, 1, -10)
    AimPartButton.Position = UDim2.new(0.7, 0, 0, 5)
    AimPartButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
    AimPartButton.Text = "头"
    AimPartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AimPartButton.TextSize = 14
    AimPartButton.Font = Enum.Font.SourceSansBold
    AimPartButton.Parent = AimPartFrame
    
    -- 添加身体部位切换功能
    local aimParts = {"Head", "UpperTorso", "LowerTorso"}
    local aimPartNames = {Head = "头", UpperTorso = "身", LowerTorso = "脚"}
    local currentAimPartIndex = 1
    
    local function UpdateAimPartButton()
        local currentPart = aimParts[currentAimPartIndex]
        Environment.Functions:SetAimPart(currentPart)
        AimPartButton.Text = aimPartNames[currentPart]
    end
    
    AimPartButton.MouseButton1Click:Connect(function()
        currentAimPartIndex = (currentAimPartIndex % #aimParts) + 1
        UpdateAimPartButton()
    end)
    
    -- 让 ToggleButton 可拖动
    local toggleDragging
    local toggleDragInput
    local toggleDragStart
    local toggleStartPos
    
    local function updateTogglePosition(input)
        local delta = input.Position - toggleDragStart
        ToggleButton.Position = UDim2.new(toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X, toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y)
    end
    
    ToggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then  -- 右键拖动
            toggleDragging = true
            toggleDragStart = input.Position
            toggleStartPos = ToggleButton.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    toggleDragging = false
                end
            end)
        end
    end)
    
    ToggleButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            toggleDragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == toggleDragInput and toggleDragging then
            updateTogglePosition(input)
        end
    end)
    
    -- 添加显示/隐藏功能
    ToggleButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)
    
    -- 关闭按钮功能
    CloseButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)
    
    -- Add Aimbot Toggle Functionality
    local function UpdateAimbotButton()
        if Environment.Settings.Enabled then
            AimbotButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            AimbotButton.Text = "ON"
        else
            AimbotButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
            AimbotButton.Text = "OFF"
        end
    end
    
    AimbotButton.MouseButton1Click:Connect(function()
        Environment.Settings.Enabled = not Environment.Settings.Enabled
        UpdateAimbotButton()
    end)
    
    -- Add Team Check Toggle Functionality
    local function UpdateTeamCheckButton()
        if Environment.Settings.TeamCheck then
            TeamCheckButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            TeamCheckButton.Text = "ON"
        else
            TeamCheckButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
            TeamCheckButton.Text = "OFF"
        end
    end
    
    TeamCheckButton.MouseButton1Click:Connect(function()
        Environment.Settings.TeamCheck = not Environment.Settings.TeamCheck
        _G.TeamCheck = Environment.Settings.TeamCheck -- 同步ESP的团队检查设置
        UpdateTeamCheckButton()
    end)
    
    -- Add ESP Toggle Functionality
    local function UpdateESPButton()
        if _G.ESPVisible then
            ESPButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            ESPButton.Text = "ON"
        else
            ESPButton.BackgroundColor3 = Color3.fromRGB(255, 80, 10)
            ESPButton.Text = "OFF"
        end
    end
    
    ESPButton.MouseButton1Click:Connect(function()
        _G.ESPVisible = not _G.ESPVisible
        UpdateESPButton()
    end)
    
    -- Initialize button states
    UpdateAimbotButton()
    UpdateTeamCheckButton()
    UpdateESPButton()
    UpdateAimPartButton()
    
    -- Parent the UI
    pcall(function()
        AimbotUI.Parent = game:GetService("CoreGui")
        MainFrame.Parent = AimbotUI
    end)
end

-- Create the UI
CreateUI()

--// ESP Settings
_G.SendNotifications = true   
_G.DefaultSettings = false   
_G.TeamCheck = false   
_G.ESPVisible = true   
_G.TextColor = Color3.fromRGB(255, 80, 10)   
_G.TextSize = 14   
_G.Center = true   
_G.Outline = true   
_G.OutlineColor = Color3.fromRGB(0, 0, 0)   
_G.TextTransparency = 0.7   
_G.TextFont = Drawing.Fonts.UI   
_G.DisableKey = Enum.KeyCode.Q   

--// ESP Function
local function CreateESP()
    for _, v in next, Players:GetPlayers() do
        if v.Name ~= Players.LocalPlayer.Name then
            local ESP = Drawing.new("Text")

            RunService.RenderStepped:Connect(function()
                if workspace:FindFirstChild(v.Name) ~= nil and workspace[v.Name]:FindFirstChild("HumanoidRootPart") ~= nil then
                    local Vector, OnScreen = Camera:WorldToViewportPoint(workspace[v.Name]:WaitForChild("Head", math.huge).Position)

                    ESP.Size = _G.TextSize
                    ESP.Center = _G.Center
                    ESP.Outline = _G.Outline
                    ESP.OutlineColor = _G.OutlineColor
                    ESP.Color = _G.TextColor
                    ESP.Transparency = _G.TextTransparency
                    ESP.Font = _G.TextFont

                    if OnScreen == true then
                        local Part1 = workspace:WaitForChild(v.Name, math.huge):WaitForChild("HumanoidRootPart", math.huge).Position
                        local Part2 = workspace:WaitForChild(Players.LocalPlayer.Name, math.huge):WaitForChild("HumanoidRootPart", math.huge).Position or 0
                        local Dist = (Part1 - Part2).Magnitude
                        ESP.Position = Vector2.new(Vector.X, Vector.Y - 25)
                        ESP.Text = ("("..tostring(math.floor(tonumber(Dist)))..") "..v.Name.." ["..workspace[v.Name].Humanoid.Health.."]")
                        if _G.TeamCheck == true then 
                            if Players.LocalPlayer.Team ~= v.Team then
                                ESP.Visible = _G.ESPVisible
                            else
                                ESP.Visible = false
                            end
                        else
                            ESP.Visible = _G.ESPVisible
                        end
                    else
                        ESP.Visible = false
                    end
                else
                    ESP.Visible = false
                end
            end)

            Players.PlayerRemoving:Connect(function()
                ESP.Visible = false
            end)
        end
    end

    Players.PlayerAdded:Connect(function(Player)
        Player.CharacterAdded:Connect(function(v)
            if v.Name ~= Players.LocalPlayer.Name then 
                local ESP = Drawing.new("Text")
    
                RunService.RenderStepped:Connect(function()
                    if workspace:FindFirstChild(v.Name) ~= nil and workspace[v.Name]:FindFirstChild("HumanoidRootPart") ~= nil then
                        local Vector, OnScreen = Camera:WorldToViewportPoint(workspace[v.Name]:WaitForChild("Head", math.huge).Position)
    
                        ESP.Size = _G.TextSize
                        ESP.Center = _G.Center
                        ESP.Outline = _G.Outline
                        ESP.OutlineColor = _G.OutlineColor
                        ESP.Color = _G.TextColor
                        ESP.Transparency = _G.TextTransparency
    
                        if OnScreen == true then
                            local Part1 = workspace:WaitForChild(v.Name, math.huge):WaitForChild("HumanoidRootPart", math.huge).Position
                            local Part2 = workspace:WaitForChild(Players.LocalPlayer.Name, math.huge):WaitForChild("HumanoidRootPart", math.huge).Position or 0
                            local Dist = (Part1 - Part2).Magnitude
                            ESP.Position = Vector2.new(Vector.X, Vector.Y - 25)
                            ESP.Text = ("("..tostring(math.floor(tonumber(Dist)))..") "..v.Name.." ["..workspace[v.Name].Humanoid.Health.."]")
                            if _G.TeamCheck == true then 
                                if Players.LocalPlayer.Team ~= Player.Team then
                                    ESP.Visible = _G.ESPVisible
                                else
                                    ESP.Visible = false
                                end
                            else
                                ESP.Visible = _G.ESPVisible
                            end
                        else
                            ESP.Visible = false
                        end
                    else
                        ESP.Visible = false
                    end
                end)
    
                Players.PlayerRemoving:Connect(function()
                    ESP.Visible = false
                end)
            end
        end)
    end)
end

--// ESP Settings Handler
if _G.DefaultSettings == true then
    _G.TeamCheck = false
    _G.ESPVisible = true
    _G.TextColor = Color3.fromRGB(40, 90, 255)
    _G.TextSize = 14
    _G.Center = true
    _G.Outline = false
    _G.OutlineColor = Color3.fromRGB(0, 0, 0)
    _G.DisableKey = Enum.KeyCode.Q
    _G.TextTransparency = 0.75
end

--// ESP Toggle Handler
UserInputService.InputBegan:Connect(function(Input)
    if Input.KeyCode == _G.DisableKey and Typing == false then
        _G.ESPVisible = not _G.ESPVisible
        
        if _G.SendNotifications == true then
            game:GetService("StarterGui"):SetCore("SendNotification",{
                Title = "Exunys Developer";
                Text = "The ESP's visibility is now set to "..tostring(_G.ESPVisible)..".";
                Duration = 5;
            })
        end
    end
end)

--// Initialize ESP
local Success, Errored = pcall(function()
    CreateESP()
end)

if Success and not Errored then
    if _G.SendNotifications == true then
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title = "Exunys Developer";
            Text = "ESP script has successfully loaded.";
            Duration = 5;
        })
    end
elseif Errored and not Success then
    if _G.SendNotifications == true then
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title = "Exunys Developer";
            Text = "ESP script has errored while loading, please check the developer console! (F9)";
            Duration = 5;
        })
    end
    TestService:Message("The ESP script has errored, please notify Exunys with the following information :")
    warn(Errored)
    print("!! IF THE ERROR IS A FALSE POSITIVE (says that a player cannot be found) THEN DO NOT BOTHER !!")
end

--// GetClosestPlayer函数
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for i, v in pairs(game:GetService("Players"):GetPlayers()) do
        if v ~= game:GetService("Players").LocalPlayer then
            if v.Character and v.Character:FindFirstChild(Environment.Settings.AimPart) then
                if Environment.Settings.TeamCheck and v.TeamColor == game:GetService("Players").LocalPlayer.TeamColor then
                    -- 跳过队友
                else
                    local pos = camera:WorldToViewportPoint(v.Character[Environment.Settings.AimPart].Position)
                    local magnitude = (Vector2.new(pos.X, pos.Y) - Vector2.new(mouse.X, mouse.Y)).magnitude
                    
                    if magnitude < shortestDistance then
                        closestPlayer = v
                        shortestDistance = magnitude
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function GetClosestPlayer()
    if not Environment.Locked then
        RequiredDistance = (Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000)

        for _, v in next, Players:GetPlayers() do
            if v ~= LocalPlayer then
                if v.Character and v.Character:FindFirstChild(Environment.Settings.LockPart) and v.Character:FindFirstChildOfClass("Humanoid") then
                    if Environment.Settings.TeamCheck and v.Team == LocalPlayer.Team then continue end
                    if Environment.Settings.AliveCheck and v.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
                    if Environment.Settings.WallCheck and #(Camera:GetPartsObscuringTarget({v.Character[Environment.Settings.LockPart].Position}, v.Character:GetDescendants())) > 0 then continue end

                    local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[Environment.Settings.LockPart].Position)
                    local Distance = (Vector2(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2(Vector.X, Vector.Y)).Magnitude

                    if Distance < RequiredDistance and OnScreen then
                        RequiredDistance = Distance
                        Environment.Locked = v
                    end
                end
            end
        end
    elseif (Vector2(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2(Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position).X, Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position).Y)).Magnitude > RequiredDistance then
        CancelLock()
    end
end

UserInputService.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
        Running = true
    end
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
        Running = false
        CancelLock()
    end
end)

game:GetService("RunService").RenderStepped:Connect(function()
    if Environment.FOVSettings.Enabled then
        Environment.FOVCircle.Position = UserInputService:GetMouseLocation()
    end

    if Running and Environment.Settings.Enabled then
        GetClosestPlayer()

        if Environment.Locked then
            if Environment.Settings.ThirdPerson then
                Environment.Settings.ThirdPersonSensitivity = mathclamp(Environment.Settings.ThirdPersonSensitivity, 0.1, 5)

                local Vector = Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position)
                mousemoverel((Vector.X - UserInputService:GetMouseLocation().X) * Environment.Settings.ThirdPersonSensitivity, (Vector.Y - UserInputService:GetMouseLocation().Y) * Environment.Settings.ThirdPersonSensitivity)
            else
                if Environment.Settings.Sensitivity > 0 then
                    Animation = TweenService:Create(Camera, TweenInfo.new(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)})
                    Animation:Play()
                else
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)
                end
            end

            Environment.FOVCircle.Color = Environment.FOVSettings.LockedColor
        end
    end
end)

--// ESP
local ESPEnabled = false
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

function ESP(player)
    local esp = Drawing.new("Text")
    esp.Visible = false
    esp.Center = true
    esp.Outline = true
    esp.Font = 2
    esp.Size = 13
    esp.Color = Color3.new(1, 1, 1)
    esp.Text = "[ ]"

    local function UpdateESP()
        local character = player.Character
        if character and character:FindFirstChild(Environment.Settings.LockPart) and _G.ESPVisible then
            local targetPart = character[Environment.Settings.LockPart]
            local pos, vis = Camera:WorldToViewportPoint(targetPart.Position)
            
            if vis then
                esp.Position = Vector2.new(pos.X, pos.Y)
                if _G.TeamCheck and player.Team == LocalPlayer.Team then
                    esp.Visible = false
                else
                    esp.Visible = true
                    local distance = math.floor((targetPart.Position - Camera.CFrame.Position).Magnitude)
                    esp.Text = player.Name.." ["..tostring(distance).."]"
                end
            else
                esp.Visible = false
            end
        else
            esp.Visible = false
        end
    end

    RunService.RenderStepped:Connect(UpdateESP)
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        ESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    ESP(player)
end)
--请勿盗窃Lorain作品，谢谢😍