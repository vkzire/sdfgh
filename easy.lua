local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerDataRemote = ReplicatedStorage.Remotes.Gameplay.GetCurrentPlayerData

local updated, data = false, nil
local function getData()
    if not updated then
        return PlayerDataRemote:InvokeServer()
    end
    return data
end

ReplicatedStorage.Remotes.Gameplay.PlayerDataChanged.OnClientEvent:Connect(function(...)
    updated = true
    data = table.unpack({...})
end)

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isElite()
    return ReplicatedStorage.Remotes.Extras.AmElite:InvokeServer()
end

local function isAlive()
    local data = getData()
    local plrData = data[LocalPlayer.Name]
    return plrData and not plrData.Dead and not plrData.Killed
end

local function getMaxCoins()
    return isElite() and 50 or 40
end

local function isntFullBag()
    local data = getData()
    local plrData = data[LocalPlayer.Name]
    return plrData and plrData.Coins < getMaxCoins()
end

local function getMap()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("CoinContainer") and obj:FindFirstChild("Spawns") then
            return obj
        end
    end
    return nil
end

local function getMurderer()
    for _, i in ipairs(game.Players:GetPlayers()) do
        if i.Backpack:FindFirstChild("Knife") or (i.Character and i.Character:FindFirstChild("Knife")) then
            return i
        end
    end
    return nil
end

-- Create a floating part for movement
local floatPart = Instance.new("Part")
floatPart.Parent = workspace
floatPart.Size = Vector3.new(5, 0.1, 5)
floatPart.CanCollide = true
floatPart.Anchored = true
floatPart.Transparency = 1

-- Disable collision for character parts
local connection
connection = RunService.RenderStepped:Connect(function()
    local rootPart = getRootPart()
    if rootPart then
        rootPart.CFrame = CFrame.new(floatPart.Position + Vector3.new(0, 3.5, 0))
        for _, child in pairs(getCharacter():GetDescendants()) do
            if child:IsA("BasePart") and child.CanCollide then
                child.CanCollide = false
            end
        end
    end
end)

-- Coin aura function to collect coins within 10 studs simultaneously
local function collectCoinsInRange(coinContainer, rootPart)
    if not (isAlive() and isntFullBag()) then return end
    local coins = {}
    for _, coin in ipairs(coinContainer:GetChildren()) do
        if coin:IsA("BasePart") and coin:GetAttribute("CoinID") == "BeachBall" then
            local coinVisual = coin:FindFirstChild("CoinVisual")
            local mainCoin = coinVisual and coinVisual:FindFirstChild("MainCoin")
            local isCollected = coin:GetAttribute("Collected")
            local isInvisible = mainCoin and mainCoin:IsA("BasePart") and mainCoin.Transparency > 0 or false
            if not isCollected and not isInvisible then
                local distance = (rootPart.Position - coin.Position).Magnitude
                if distance <= 12 then
                    table.insert(coins, coin)
                end
            end
        end
    end
    -- Collect coins simultaneously
    for _, coin in ipairs(coins) do
        task.spawn(function()
            if coin and coin.Parent and isAlive() and isntFullBag() then
                local coinVisual = coin:FindFirstChild("CoinVisual")
                local mainCoin = coinVisual and coinVisual:FindFirstChild("MainCoin")
                local isCollected = coin:GetAttribute("Collected")
                local isInvisible = mainCoin and mainCoin:IsA("BasePart") and mainCoin.Transparency > 0 or false
                if not isCollected and not isInvisible then
                    firetouchinterest(rootPart, coin, 1)
                    task.wait(0.05)
                    firetouchinterest(rootPart, coin, 0)
                    task.wait(0.05)
                    isCollected = coin:GetAttribute("Collected")
                    isInvisible = mainCoin and mainCoin:IsA("BasePart") and mainCoin.Transparency > 0 or false
                    if isCollected or isInvisible then
                        coin:Destroy()
                    end
                end
            end
        end)
    end
end

-- Find the nearest coin outside the aura range
local function findNearestCoin(coinContainer, rootPart)
    local coins = {}
    for _, coin in ipairs(coinContainer:GetChildren()) do
        if coin:IsA("BasePart") and coin:GetAttribute("CoinID") == "BeachBall" then
            local coinVisual = coin:FindFirstChild("CoinVisual")
            local mainCoin = coinVisual and coinVisual:FindFirstChild("MainCoin")
            local isCollected = coin:GetAttribute("Collected")
            local isInvisible = mainCoin and mainCoin:IsA("BasePart") and mainCoin.Transparency > 0 or false
            if not isCollected and not isInvisible then
                local distance = (rootPart.Position - coin.Position).Magnitude
                if distance > 12 then
                    table.insert(coins, {coin = coin, distance = distance})
                end
            end
        end
    end
    table.sort(coins, function(a, b) return a.distance < b.distance end)
    return coins[1] and coins[1].coin, coins[1] and coins[1].distance
end

task.spawn(function()
    while true do 
        local map = getMap()
        local rootPart = getRootPart()
        if map and map:FindFirstChild("CoinContainer") and rootPart and isAlive() and isntFullBag() then
            collectCoinsInRange(map.CoinContainer, rootPart)
        else
            break -- Stop loop if not alive or bag is full
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        local map = getMap()
        local rootPart = getRootPart()
        if isAlive() and not isntFullBag() then
            if getMurderer() ~= LocalPlayer then
                getCharacter():FindFirstChild("Humanoid").Health = 0 
            end
            break -- Stop loop if bag is full
        end
        if map and map:FindFirstChild("CoinContainer") and rootPart and isAlive() and isntFullBag() then
            local coin, distance = findNearestCoin(map.CoinContainer, rootPart)
            if coin then
                local targetPosition = coin.Position - Vector3.new(0, 5, 0)
                if distance >= 250 then
                    floatPart.CFrame = CFrame.new(targetPosition)
                else
                    local speed = distance / 28.5
                    local tween = TweenService:Create(floatPart, TweenInfo.new(speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPosition)})
                    tween:Play()
                    tween.Completed:Wait()
                end
            else
                -- Move to map center if no coins outside aura range
                floatPart.CFrame = CFrame.new(map.WorldPivot.Position + Vector3.new(0, 30, 0))
            end
        else
            floatPart.CFrame = CFrame.new(100, 0, 100) -- Default position if no map or conditions not met
            if not isAlive() or not isntFullBag() then
                break -- Stop loop if not alive or bag is full
            end
        end
        task.wait(0.1) -- Smooth update rate
    end
end)
