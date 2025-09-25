local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local LOCK_TOGGLE_KEY = Enum.KeyCode.Q
local CLOSE_GUI_KEY = Enum.KeyCode.LeftControl
local SMOOTHNESS = 0.25
local MAX_VERTICAL_DIFF = 50

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AUTOV_GUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 60)
mainFrame.Position = UDim2.new(0, 20, 0, 200)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(0, 200, 255)
stroke.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AUTOV"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextScaled = true
titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0.5, 0)
statusLabel.Position = UDim2.new(0, 0, 0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Lock-On: OFF"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextScaled = true
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 80, 0, 40)
closeButton.Position = UDim2.new(0, 10, 1, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
closeButton.TextColor3 = Color3.fromRGB(0, 0, 0)
closeButton.Text = "CLOSE"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.Visible = GuiService:IsTenFootInterface() or UserInputService.TouchEnabled
closeButton.Parent = screenGui

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 80, 0, 40)
toggleButton.Position = UDim2.new(0, 100, 1, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
toggleButton.TextColor3 = Color3.fromRGB(0, 0, 0)
toggleButton.Text = "LOCK"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextScaled = true
toggleButton.Visible = closeButton.Visible
toggleButton.Parent = screenGui

local systemEnabled = false
local currentTarget = nil
local currentReticle = nil

local function createReticle(target)
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 50, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.Adornee = target
    billboard.Name = "LockOnReticle"
    billboard.Parent = Workspace
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.3
    frame.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 10)
    uiCorner.Parent = frame
    return billboard
end

local function getAimPart(character)
    return character:FindFirstChild("Head")
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
end

local function isVisible(part, char)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    local origin = player.Character.HumanoidRootPart.Position
    local direction = part.Position - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {player.Character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, direction, params)
    return result and result.Instance:IsDescendantOf(char)
end

local function getClosestTarget()
    local closest, shortest = nil, math.huge
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player
        and plr.Team ~= nil
        and player.Team ~= nil
        and plr.Team ~= player.Team
        and plr.Character
        and plr.Character:FindFirstChild("Humanoid")
        and plr.Character.Humanoid.Health > 0 then
            local aimPart = getAimPart(plr.Character)
            if aimPart and isVisible(aimPart, plr.Character) then
                local root = player.Character.HumanoidRootPart
                local dist = (aimPart.Position - root.Position).Magnitude
                local verticalDiff = math.abs(aimPart.Position.Y - root.Position.Y)
                if verticalDiff <= MAX_VERTICAL_DIFF and dist < shortest then
                    shortest, closest = dist, aimPart
                end
            end
        end
    end
    return closest
end

local function clearTarget()
    if currentReticle then currentReticle:Destroy() end
    currentTarget, currentReticle = nil, nil
end

local function updateTarget()
    if currentTarget then
        local char = currentTarget.Parent
        local humanoid = char and char:FindFirstChild("Humanoid")
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not char or not humanoid or humanoid.Health <= 0 or not root then
            clearTarget()
        elseif not isVisible(currentTarget, char) then
            clearTarget()
        end
    end
    if not currentTarget then
        local newTarget = getClosestTarget()
        if newTarget then
            currentTarget = newTarget
            currentReticle = createReticle(newTarget)
        end
    end
end

local function toggleSystem()
    systemEnabled = not systemEnabled
    statusLabel.Text = "Lock-On: " .. (systemEnabled and "ON" or "OFF")
    if not systemEnabled then
        clearTarget()
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and not UserInputService.TouchEnabled then
        if input.KeyCode == LOCK_TOGGLE_KEY then
            toggleSystem()
        elseif input.KeyCode == CLOSE_GUI_KEY then
            screenGui.Enabled = not screenGui.Enabled
        end
    end
end)

toggleButton.MouseButton1Click:Connect(function()
    toggleSystem()
end)

closeButton.MouseButton1Click:Connect(function()
    screenGui.Enabled = false
end)

RunService.RenderStepped:Connect(function()
    if systemEnabled then
        updateTarget()
        if currentTarget and currentTarget.Parent then
            local camPos = camera.CFrame.Position
            local desired = CFrame.lookAt(camPos, currentTarget.Position)
            camera.CFrame = camera.CFrame:Lerp(desired, SMOOTHNESS)
        end
    end
end)

local function addESP(plr)
    if plr.Character and not plr.Character:FindFirstChild("ESP_Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = Color3.fromRGB(0, 200, 255)
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0
        highlight.Parent = plr.Character
    end
end

local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            addESP(plr)
        end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(1)
        addESP(plr)
    end)
end)

RunService.Heartbeat:Connect(function()
    refreshESP()
end)
