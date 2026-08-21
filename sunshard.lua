--[[

AXIOM SUNSHINE BUS ASSIST V3 - COMBINED SOURCE

IMPORTANT:
Roblox separates client and server execution.
This file is a convenient combined source reference only.

SECTION A must be placed as a LocalScript under:
StarterPlayer > StarterPlayerScripts

SECTION B must be placed as a Script under:
ServerScriptService

=====================================================================
SECTION A - CLIENT
=====================================================================
]]

--[[
=====================================================================
                 AXIOM BUS ASSIST V2 - FULL FILE
=====================================================================

Dành cho Roblox Studio / place của bạn.

Đặt dưới dạng LocalScript:
StarterPlayer
└── StarterPlayerScripts
    └── AxiomSunshineBusAssist.client.lua

KEY:
    SEPDEPTRAI

TỐC ĐỘ:
    - Tốc độ gốc: 75
    - Slider Bus Speed: 75 -> 300
    - Kéo slider lên để tăng giới hạn tốc độ

TÍNH NĂNG:
    - Key UI
    - Bus Speed slider
    - Noclip Bus
    - Player Noclip
    - Sun / Sunshards Manager
    - Boost
    - Cruise Control
    - Fly Bus
    - Fly Speed slider
    - Fix Lag
    - Auto Park
    - Auto Doors
    - Auto Release P
    - Head Lights
    - Front / Rear Door
    - Manual Park
    - RightShift: ẩn / hiện UI
=====================================================================
]]

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------

local CONFIG = {
	MasterKey = "SEPDEPTRAI",
	UIKey = Enum.KeyCode.RightShift,

	SunRemoteName = "AxiomSetSunCurrency",
	SunMin = 0,
	SunMax = 999999,

	-- Speed
	BaseSpeed = 75,
	BusSpeedMin = 75,
	BusSpeedMax = 300,
	BusSpeed = 75,
	BoostSpeed = 110,

	-- Fly
	FlySpeed = 85,
	FlySpeedMin = 20,
	FlySpeedMax = 250,
	FlyVerticalSpeed = 65,
	FlyTurnSpeed = 95,
	FlyResponsiveness = 20,

	-- Cruise
	CruiseMinSpeed = 15,

	-- Auto park
	AutoParkTriggerDistance = 22,
	AutoParkMaxSpeed = 40,
	ParkSpeedThreshold = 1.2,
	BrakeFactor = 0.88,
	StopDuration = 6,
	DoorCloseDelay = 1.4,
	StopCooldown = 5,

	-- Doors
	DoorOpenAngle = 85,
	DoorClosedAngle = 0,
	DoorSpeed = 3,
	DoorTorque = 100000,
}

---------------------------------------------------------------------
-- FEATURE STATES
---------------------------------------------------------------------

local Features = {
	FixLag = false,

	AutoPark = true,
	AutoDoors = true,
	AutoReleasePark = true,

	NoclipBus = false,
	PlayerNoclip = false,
	Boost = false,
	Cruise = false,
	Fly = false,
	Lights = false,
}

---------------------------------------------------------------------
-- VEHICLE STATE
---------------------------------------------------------------------

local currentBus = nil
local currentSeat = nil
local lastSeat = nil

local parked = false
local autoParking = false
local processingStop = false

local frontDoorOpen = false
local rearDoorOpen = false

local cruiseSpeed = 0

local lastStop = nil
local lastStopTime = 0

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 3,
		})
	end)
end

local function getPlayerVehicleSeat()
	local character = player.Character

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return nil
	end

	local seat = humanoid.SeatPart

	if seat and seat:IsA("VehicleSeat") then
		return seat
	end

	return nil
end

local function findBusFromSeat(seat)
	if not seat then
		return nil
	end

	local current = seat

	while current and current ~= workspace do
		if current:IsA("Model") then
			local foundSeat = current:FindFirstChildWhichIsA("VehicleSeat", true)

			if foundSeat == seat then
				return current
			end
		end

		current = current.Parent
	end

	return nil
end

local function getBusSpeed()
	if not currentSeat then
		return 0
	end

	return currentSeat.AssemblyLinearVelocity.Magnitude
end

local function studsPerSecondToKmh(speed)
	return math.floor(speed * 1.008 + 0.5)
end

local function getSelectedBusSpeed()
	return math.clamp(
		CONFIG.BusSpeed,
		CONFIG.BusSpeedMin,
		CONFIG.BusSpeedMax
	)
end

local function getCurrentSpeedLimit()
	if parked or frontDoorOpen or rearDoorOpen then
		return 0
	end

	if Features.Fly then
		return CONFIG.BaseSpeed
	end

	if Features.Boost then
		return math.max(CONFIG.BoostSpeed, getSelectedBusSpeed())
	end

	return getSelectedBusSpeed()
end

local function applySpeedLimit()
	if currentSeat then
		currentSeat.MaxSpeed = getCurrentSpeedLimit()
	end
end

---------------------------------------------------------------------
-- DOOR SYSTEM
---------------------------------------------------------------------

local function findDoorHinge(name)
	if not currentBus then
		return nil
	end

	local door = currentBus:FindFirstChild(name, true)

	if not door then
		return nil
	end

	return door:FindFirstChildWhichIsA("HingeConstraint", true)
end

local function setDoor(name, open)
	local hinge = findDoorHinge(name)

	if not hinge then
		warn("[AXIOM] Không tìm thấy cửa:", name)
		return false
	end

	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.ServoMaxTorque = CONFIG.DoorTorque
	hinge.AngularSpeed = CONFIG.DoorSpeed
	hinge.TargetAngle = open and CONFIG.DoorOpenAngle or CONFIG.DoorClosedAngle

	if name == "FrontDoor" then
		frontDoorOpen = open
	elseif name == "RearDoor" then
		rearDoorOpen = open
	end

	applySpeedLimit()
	return true
end

local function openDoors()
	setDoor("FrontDoor", true)
	setDoor("RearDoor", true)
end

local function closeDoors()
	setDoor("FrontDoor", false)
	setDoor("RearDoor", false)
end

---------------------------------------------------------------------
-- PARK SYSTEM
---------------------------------------------------------------------

local function setPark(enabled)
	if not currentSeat then
		return
	end

	parked = enabled

	if enabled then
		Features.Cruise = false
		cruiseSpeed = 0

		currentSeat.MaxSpeed = 0

		if currentSeat.AssemblyLinearVelocity.Magnitude <= 5 then
			currentSeat.AssemblyLinearVelocity = Vector3.zero
			currentSeat.AssemblyAngularVelocity = Vector3.zero
		end
	else
		applySpeedLimit()
	end
end

---------------------------------------------------------------------
-- LIGHTS
---------------------------------------------------------------------

local function updateLights()
	if not currentBus then
		return
	end

	local folder = currentBus:FindFirstChild("HeadLights", true)

	if not folder then
		warn("[AXIOM] Không tìm thấy HeadLights")
		return
	end

	for _, object in ipairs(folder:GetDescendants()) do
		if object:IsA("Light") then
			object.Enabled = Features.Lights
		end
	end
end

---------------------------------------------------------------------
-- FIX LAG
---------------------------------------------------------------------

local lagBackup = {
	GlobalShadows = nil,
	Effects = {},
	Parts = {},
}

local function enableFixLag()
	if lagBackup.GlobalShadows == nil then
		lagBackup.GlobalShadows = Lighting.GlobalShadows
	end

	Lighting.GlobalShadows = false

	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("ParticleEmitter")
			or object:IsA("Trail")
			or object:IsA("Smoke")
			or object:IsA("Fire")
			or object:IsA("Sparkles")
		then
			if lagBackup.Effects[object] == nil then
				lagBackup.Effects[object] = object.Enabled
			end

			object.Enabled = false

		elseif object:IsA("BasePart") then
			if lagBackup.Parts[object] == nil then
				lagBackup.Parts[object] = object.CastShadow
			end

			object.CastShadow = false
		end
	end
end

local function disableFixLag()
	if lagBackup.GlobalShadows ~= nil then
		Lighting.GlobalShadows = lagBackup.GlobalShadows
	end

	for object, oldValue in pairs(lagBackup.Effects) do
		if object and object.Parent then
			pcall(function()
				object.Enabled = oldValue
			end)
		end
	end

	for object, oldValue in pairs(lagBackup.Parts) do
		if object and object.Parent and object:IsA("BasePart") then
			object.CastShadow = oldValue
		end
	end

	table.clear(lagBackup.Effects)
	table.clear(lagBackup.Parts)

	lagBackup.GlobalShadows = nil
end

---------------------------------------------------------------------
-- BUS NOCLIP
---------------------------------------------------------------------

local collisionBackup = {}

local function backupCollision(part)
	if collisionBackup[part] == nil then
		collisionBackup[part] = {
			CanCollide = part.CanCollide,
			CanTouch = part.CanTouch,
			CanQuery = part.CanQuery,
		}
	end
end

local function applyBusNoclip()
	if not currentBus then
		return
	end

	for _, object in ipairs(currentBus:GetDescendants()) do
		if object:IsA("BasePart") then
			backupCollision(object)
			object.CanCollide = false
		end
	end
end

local function restoreBusCollision()
	for part, old in pairs(collisionBackup) do
		if part and part.Parent and part:IsA("BasePart") then
			part.CanCollide = old.CanCollide

			pcall(function()
				part.CanTouch = old.CanTouch
				part.CanQuery = old.CanQuery
			end)
		end
	end

	table.clear(collisionBackup)
end

local function setBusNoclip(enabled)
	Features.NoclipBus = enabled

	if enabled then
		applyBusNoclip()
	else
		restoreBusCollision()
	end
end


---------------------------------------------------------------------
-- PLAYER NOCLIP
---------------------------------------------------------------------

local playerCollisionBackup = {}

local function applyPlayerNoclip()
	local character = player.Character

	if not character then
		return
	end

	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart") then
			if playerCollisionBackup[object] == nil then
				playerCollisionBackup[object] = {
					CanCollide = object.CanCollide,
					CanTouch = object.CanTouch,
					CanQuery = object.CanQuery,
				}
			end

			object.CanCollide = false
		end
	end
end

local function restorePlayerCollision()
	for part, old in pairs(playerCollisionBackup) do
		if part and part.Parent and part:IsA("BasePart") then
			part.CanCollide = old.CanCollide

			pcall(function()
				part.CanTouch = old.CanTouch
				part.CanQuery = old.CanQuery
			end)
		end
	end

	table.clear(playerCollisionBackup)
end

local function setPlayerNoclip(enabled)
	Features.PlayerNoclip = enabled

	if enabled then
		applyPlayerNoclip()
	else
		restorePlayerCollision()
	end
end

-- Keep player noclip alive even while not seated in a bus.
RunService.Stepped:Connect(function()
	if Features.PlayerNoclip then
		applyPlayerNoclip()
	end
end)

---------------------------------------------------------------------
-- FLY SYSTEM
---------------------------------------------------------------------

local flyAttachment = nil
local flyVelocity = nil
local flyOrientation = nil
local flyYaw = 0

local function getFlyRoot()
	if not currentBus then
		return nil
	end

	if currentBus.PrimaryPart then
		return currentBus.PrimaryPart
	end

	if currentSeat and currentSeat:IsA("BasePart") then
		return currentSeat
	end

	return currentBus:FindFirstChildWhichIsA("BasePart", true)
end

local function destroyFlyObjects()
	if flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end

	if flyOrientation then
		flyOrientation:Destroy()
		flyOrientation = nil
	end

	if flyAttachment then
		flyAttachment:Destroy()
		flyAttachment = nil
	end
end

local function getYawFromCFrame(cf)
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function enableFly()
	if not currentBus then
		Features.Fly = false
		return
	end

	local root = getFlyRoot()

	if not root then
		Features.Fly = false
		return
	end

	destroyFlyObjects()

	flyYaw = getYawFromCFrame(root.CFrame)

	flyAttachment = Instance.new("Attachment")
	flyAttachment.Name = "AxiomFlyAttachment"
	flyAttachment.Parent = root

	flyVelocity = Instance.new("LinearVelocity")
	flyVelocity.Name = "AxiomFlyVelocity"
	flyVelocity.Attachment0 = flyAttachment
	flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	flyVelocity.VectorVelocity = Vector3.zero
	flyVelocity.MaxForce = math.huge
	flyVelocity.Parent = root

	flyOrientation = Instance.new("AlignOrientation")
	flyOrientation.Name = "AxiomFlyOrientation"
	flyOrientation.Attachment0 = flyAttachment
	flyOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flyOrientation.MaxTorque = math.huge
	flyOrientation.MaxAngularVelocity = math.huge
	flyOrientation.Responsiveness = CONFIG.FlyResponsiveness
	flyOrientation.RigidityEnabled = false
	flyOrientation.Parent = root

	parked = false
	autoParking = false
	processingStop = false
	Features.Cruise = false
	cruiseSpeed = 0

	applySpeedLimit()
end

local function disableFly()
	destroyFlyObjects()
	applySpeedLimit()
end

local function updateFly(dt)
	if not Features.Fly or not currentBus then
		return
	end

	local root = getFlyRoot()

	if not root then
		return
	end

	if not flyVelocity
		or not flyVelocity.Parent
		or not flyOrientation
		or not flyOrientation.Parent
	then
		enableFly()
	end

	if not flyVelocity or not flyOrientation then
		return
	end

	local turnInput = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		turnInput += 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		turnInput -= 1
	end

	flyYaw += math.rad(CONFIG.FlyTurnSpeed) * turnInput * dt

	local targetRotation = CFrame.Angles(0, flyYaw, 0)

	flyOrientation.CFrame = targetRotation

	local forwardInput = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		forwardInput += 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		forwardInput -= 1
	end

	local forward =
		targetRotation.LookVector
		* forwardInput
		* CONFIG.FlySpeed

	local verticalInput = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.T) then
		verticalInput += 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		verticalInput -= 1
	end

	local vertical =
		Vector3.new(
			0,
			verticalInput * CONFIG.FlyVerticalSpeed,
			0
		)

	flyVelocity.VectorVelocity = forward + vertical
end

---------------------------------------------------------------------
-- STOP SYSTEM
---------------------------------------------------------------------

local function getBusStopsFolder()
	return workspace:FindFirstChild("BusStops")
end

local function getNearestStop()
	if not currentSeat then
		return nil, math.huge
	end

	local folder = getBusStopsFolder()

	if not folder then
		return nil, math.huge
	end

	local nearest = nil
	local nearestDistance = math.huge

	for _, stop in ipairs(folder:GetChildren()) do
		if stop:IsA("BasePart") then
			local distance =
				(currentSeat.Position - stop.Position).Magnitude

			if distance < nearestDistance then
				nearest = stop
				nearestDistance = distance
			end
		end
	end

	return nearest, nearestDistance
end

local function getStopName(stop)
	if not stop then
		return "UNKNOWN"
	end

	return stop:GetAttribute("StopName") or stop.Name
end

local function performAutoStop(stop)
	if processingStop
		or autoParking
		or not currentSeat
		or not stop
	then
		return
	end

	processingStop = true
	autoParking = true

	local thisStop = stop

	while currentSeat
		and currentBus
		and thisStop.Parent
		and getBusSpeed() > CONFIG.ParkSpeedThreshold
	do
		currentSeat.AssemblyLinearVelocity *= CONFIG.BrakeFactor
		task.wait()
	end

	if not currentSeat then
		processingStop = false
		autoParking = false
		return
	end

	currentSeat.AssemblyLinearVelocity = Vector3.zero
	currentSeat.AssemblyAngularVelocity = Vector3.zero

	setPark(true)

	lastStop = thisStop
	lastStopTime = os.clock()
	autoParking = false

	if Features.AutoDoors then
		openDoors()
	end

	task.wait(CONFIG.StopDuration)

	if Features.AutoDoors then
		closeDoors()
		task.wait(CONFIG.DoorCloseDelay)
	end

	if Features.AutoReleasePark then
		setPark(false)
	end

	processingStop = false
end

---------------------------------------------------------------------
-- CLEAN OLD UI
---------------------------------------------------------------------

local oldGui = playerGui:FindFirstChild("AxiomBusAssistV2")

if oldGui then
	oldGui:Destroy()
end

---------------------------------------------------------------------
-- GUI ROOT
---------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "AxiomBusAssistV2"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

---------------------------------------------------------------------
-- MAIN WINDOW
---------------------------------------------------------------------

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(380, 560)
main.Position = UDim2.new(0, 25, 0.5, -280)
main.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
main.BorderSizePixel = 0
main.Visible = false
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(70, 75, 90)
mainStroke.Transparency = 0.2
mainStroke.Parent = main

---------------------------------------------------------------------
-- HEADER
---------------------------------------------------------------------

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 58)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = main

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(18, 9)
title.Size = UDim2.new(1, -85, 0, 24)
title.BackgroundTransparency = 1
title.Text = "AXIOM BUS ASSIST V2"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(18, 33)
subtitle.Size = UDim2.new(1, -85, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.Text = "BASE SPEED 75 • ONLINE"
subtitle.TextColor3 = Color3.fromRGB(90, 240, 145)
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local minimize = Instance.new("TextButton")
minimize.Position = UDim2.new(1, -50, 0, 11)
minimize.Size = UDim2.fromOffset(34, 34)
minimize.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
minimize.BorderSizePixel = 0
minimize.Text = "—"
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 18
minimize.Parent = header

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 9)
minimizeCorner.Parent = minimize

---------------------------------------------------------------------
-- STATUS PANEL
---------------------------------------------------------------------

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(18, 64)
status.Size = UDim2.new(1, -36, 0, 106)
status.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
status.BorderSizePixel = 0
status.TextColor3 = Color3.fromRGB(195, 205, 215)
status.Font = Enum.Font.Code
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "BUS       : WAITING\nSPEED     : 0 KM/H\nLIMIT     : 75\nGEAR      : -\nAUTO PARK : READY"
status.Parent = main

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 10)
statusCorner.Parent = status

---------------------------------------------------------------------
-- BUTTON AREA
---------------------------------------------------------------------

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(18, 184)
list.Size = UDim2.new(1, -36, 1, -202)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

---------------------------------------------------------------------
-- UI HELPERS
---------------------------------------------------------------------

local buttons = {}

local function styleButton(button)
	button.Size = UDim2.new(1, -5, 0, 40)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
end

local function refreshButton(feature)
	local data = buttons[feature]

	if not data then
		return
	end

	local enabled = Features[feature]

	data.Button.Text =
		data.Label
		.. "              "
		.. (enabled and "[ ON ]" or "[ OFF ]")

	data.Button.BackgroundColor3 =
		enabled
			and Color3.fromRGB(35, 75, 52)
			or Color3.fromRGB(28, 31, 40)
end

local function refreshAllButtons()
	for feature in pairs(buttons) do
		refreshButton(feature)
	end
end

local function createToggle(label, feature)
	local button = Instance.new("TextButton")
	styleButton(button)

	button.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
	button.Parent = list

	buttons[feature] = {
		Button = button,
		Label = label,
	}

	button.MouseButton1Click:Connect(function()
		Features[feature] = not Features[feature]

		if feature == "FixLag" then
			if Features.FixLag then
				enableFixLag()
			else
				disableFixLag()
			end

		elseif feature == "NoclipBus" then
			setBusNoclip(Features.NoclipBus)

		elseif feature == "PlayerNoclip" then
			setPlayerNoclip(Features.PlayerNoclip)

		elseif feature == "Fly" then
			if Features.Fly then
				enableFly()
			else
				disableFly()
			end

		elseif feature == "Lights" then
			updateLights()

		elseif feature == "Boost" then
			applySpeedLimit()

		elseif feature == "Cruise" then
			if Features.Cruise then
				if not currentSeat
					or parked
					or processingStop
				then
					Features.Cruise = false
				else
					local speed = getBusSpeed()

					if speed >= CONFIG.CruiseMinSpeed then
						cruiseSpeed = math.clamp(
							speed,
							CONFIG.CruiseMinSpeed,
							getSelectedBusSpeed()
						)
					else
						Features.Cruise = false
					end
				end
			else
				cruiseSpeed = 0
			end
		end

		refreshButton(feature)
	end)

	refreshButton(feature)
end

---------------------------------------------------------------------
-- TOGGLES
---------------------------------------------------------------------

createToggle("Fix Lag", "FixLag")
createToggle("Auto Park", "AutoPark")
createToggle("Auto Doors", "AutoDoors")
createToggle("Auto Release P", "AutoReleasePark")
createToggle("Bus Noclip", "NoclipBus")
createToggle("Player Noclip", "PlayerNoclip")
createToggle("Boost", "Boost")
createToggle("Cruise Control", "Cruise")
createToggle("Fly", "Fly")
createToggle("Head Lights", "Lights")

---------------------------------------------------------------------
-- GENERIC SLIDER FACTORY
---------------------------------------------------------------------

local function createSlider(name, label, minValue, maxValue, getValue, setValue, accent)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = UDim2.new(1, -5, 0, 62)
	holder.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
	holder.BorderSizePixel = 0
	holder.Parent = list

	local holderCorner = Instance.new("UICorner")
	holderCorner.CornerRadius = UDim.new(0, 10)
	holderCorner.Parent = holder

	local valueText = Instance.new("TextLabel")
	valueText.Position = UDim2.fromOffset(12, 5)
	valueText.Size = UDim2.new(1, -24, 0, 20)
	valueText.BackgroundTransparency = 1
	valueText.Font = Enum.Font.GothamMedium
	valueText.TextSize = 12
	valueText.TextColor3 = Color3.new(1, 1, 1)
	valueText.TextXAlignment = Enum.TextXAlignment.Left
	valueText.Parent = holder

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 12, 0, 38)
	track.Size = UDim2.new(1, -24, 0, 7)
	track.BackgroundColor3 = Color3.fromRGB(47, 52, 65)
	track.BorderSizePixel = 0
	track.Active = true
	track.Parent = holder

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.Size = UDim2.fromOffset(16, 16)
	knob.BackgroundColor3 = Color3.fromRGB(235, 240, 255)
	knob.BorderSizePixel = 0
	knob.Active = true
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local dragging = false

	local function refresh()
		local value = math.clamp(getValue(), minValue, maxValue)
		local alpha = (value - minValue) / (maxValue - minValue)

		valueText.Text =
			label
			.. ": "
			.. tostring(math.floor(value + 0.5))

		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
	end

	local function updateFromX(x)
		local width = math.max(track.AbsoluteSize.X, 1)
		local alpha = math.clamp(
			(x - track.AbsolutePosition.X) / width,
			0,
			1
		)

		local value =
			minValue
			+ ((maxValue - minValue) * alpha)

		setValue(value)
		refresh()
	end

	local function begin(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			updateFromX(input.Position.X)
		end
	end

	track.InputBegan:Connect(begin)
	knob.InputBegan:Connect(begin)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	refresh()

	return {
		Refresh = refresh,
	}
end

---------------------------------------------------------------------
-- BUS SPEED SLIDER: 75 -> 300
---------------------------------------------------------------------

local busSpeedSlider = createSlider(
	"BusSpeedSlider",
	"Bus Speed Limit",
	CONFIG.BusSpeedMin,
	CONFIG.BusSpeedMax,

	function()
		return CONFIG.BusSpeed
	end,

	function(value)
		CONFIG.BusSpeed = math.clamp(
			math.floor(value + 0.5),
			CONFIG.BusSpeedMin,
			CONFIG.BusSpeedMax
		)

		applySpeedLimit()

		if Features.Cruise and cruiseSpeed > CONFIG.BusSpeed then
			cruiseSpeed = CONFIG.BusSpeed
		end
	end,

	Color3.fromRGB(80, 150, 255)
)

---------------------------------------------------------------------
-- FLY SPEED SLIDER
---------------------------------------------------------------------

local flySpeedSlider = createSlider(
	"FlySpeedSlider",
	"Fly Speed",
	CONFIG.FlySpeedMin,
	CONFIG.FlySpeedMax,

	function()
		return CONFIG.FlySpeed
	end,

	function(value)
		CONFIG.FlySpeed = math.clamp(
			math.floor(value + 0.5),
			CONFIG.FlySpeedMin,
			CONFIG.FlySpeedMax
		)
	end,

	Color3.fromRGB(70, 210, 120)
)

---------------------------------------------------------------------
-- ACTION BUTTON FACTORY
---------------------------------------------------------------------

local function createActionButton(text, callback)
	local button = Instance.new("TextButton")
	styleButton(button)

	button.Text = text
	button.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
	button.Parent = list

	button.MouseButton1Click:Connect(callback)

	return button
end

createActionButton("Front Door", function()
	setDoor("FrontDoor", not frontDoorOpen)
end)

createActionButton("Rear Door", function()
	setDoor("RearDoor", not rearDoorOpen)
end)

createActionButton("Open Both Doors", function()
	openDoors()
end)

createActionButton("Close Both Doors", function()
	closeDoors()
end)

createActionButton("Park / Release P", function()
	setPark(not parked)
end)

createActionButton("Reset Speed To 75", function()
	CONFIG.BusSpeed = CONFIG.BaseSpeed
	Features.Boost = false
	Features.Cruise = false
	cruiseSpeed = 0

	busSpeedSlider.Refresh()
	refreshAllButtons()
	applySpeedLimit()

	notify(
		"Axiom Bus Assist",
		"Speed limit reset về 75."
	)
end)


---------------------------------------------------------------------
-- SUN / SUNSHARDS WINDOW
---------------------------------------------------------------------

local sunRemote = ReplicatedStorage:WaitForChild(CONFIG.SunRemoteName)

local sunWindow = Instance.new("Frame")
sunWindow.Name = "SunCurrencyWindow"
sunWindow.AnchorPoint = Vector2.new(0.5, 0.5)
sunWindow.Position = UDim2.fromScale(0.5, 0.5)
sunWindow.Size = UDim2.fromOffset(370, 286)
sunWindow.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
sunWindow.BorderSizePixel = 0
sunWindow.Visible = false
sunWindow.ZIndex = 100
sunWindow.Parent = gui

local sunWindowCorner = Instance.new("UICorner")
sunWindowCorner.CornerRadius = UDim.new(0, 16)
sunWindowCorner.Parent = sunWindow

local sunWindowStroke = Instance.new("UIStroke")
sunWindowStroke.Color = Color3.fromRGB(225, 177, 62)
sunWindowStroke.Transparency = 0.25
sunWindowStroke.Thickness = 1
sunWindowStroke.Parent = sunWindow

local sunTitle = Instance.new("TextLabel")
sunTitle.Position = UDim2.fromOffset(20, 16)
sunTitle.Size = UDim2.new(1, -75, 0, 28)
sunTitle.BackgroundTransparency = 1
sunTitle.Text = "SUN / SUNSHARDS"
sunTitle.TextColor3 = Color3.fromRGB(255, 226, 120)
sunTitle.Font = Enum.Font.GothamBold
sunTitle.TextSize = 19
sunTitle.TextXAlignment = Enum.TextXAlignment.Left
sunTitle.ZIndex = 101
sunTitle.Parent = sunWindow

local sunDesc = Instance.new("TextLabel")
sunDesc.Position = UDim2.fromOffset(20, 45)
sunDesc.Size = UDim2.new(1, -40, 0, 20)
sunDesc.BackgroundTransparency = 1
sunDesc.Text = "Nhập số Sun muốn có • tối đa 999999"
sunDesc.TextColor3 = Color3.fromRGB(145, 150, 165)
sunDesc.Font = Enum.Font.GothamMedium
sunDesc.TextSize = 11
sunDesc.TextXAlignment = Enum.TextXAlignment.Left
sunDesc.ZIndex = 101
sunDesc.Parent = sunWindow

local sunClose = Instance.new("TextButton")
sunClose.Position = UDim2.new(1, -48, 0, 13)
sunClose.Size = UDim2.fromOffset(34, 34)
sunClose.BackgroundColor3 = Color3.fromRGB(34, 37, 47)
sunClose.BorderSizePixel = 0
sunClose.Text = "×"
sunClose.TextColor3 = Color3.new(1, 1, 1)
sunClose.Font = Enum.Font.GothamBold
sunClose.TextSize = 20
sunClose.ZIndex = 102
sunClose.Parent = sunWindow

local sunCloseCorner = Instance.new("UICorner")
sunCloseCorner.CornerRadius = UDim.new(0, 9)
sunCloseCorner.Parent = sunClose

local sunInput = Instance.new("TextBox")
sunInput.Position = UDim2.fromOffset(20, 82)
sunInput.Size = UDim2.new(1, -40, 0, 52)
sunInput.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
sunInput.BorderSizePixel = 0
sunInput.Text = ""
sunInput.PlaceholderText = "Ví dụ: 999999"
sunInput.ClearTextOnFocus = false
sunInput.TextColor3 = Color3.fromRGB(255, 235, 160)
sunInput.PlaceholderColor3 = Color3.fromRGB(98, 103, 118)
sunInput.Font = Enum.Font.GothamBold
sunInput.TextSize = 18
sunInput.ZIndex = 101
sunInput.Parent = sunWindow

local sunInputCorner = Instance.new("UICorner")
sunInputCorner.CornerRadius = UDim.new(0, 10)
sunInputCorner.Parent = sunInput

sunInput:GetPropertyChangedSignal("Text"):Connect(function()
	local filtered = sunInput.Text:gsub("[^0-9]", "")

	if filtered ~= sunInput.Text then
		sunInput.Text = filtered
	end

	local number = tonumber(filtered)

	if number and number > CONFIG.SunMax then
		sunInput.Text = tostring(CONFIG.SunMax)
	end
end)

local quickHolder = Instance.new("Frame")
quickHolder.Position = UDim2.fromOffset(20, 147)
quickHolder.Size = UDim2.new(1, -40, 0, 34)
quickHolder.BackgroundTransparency = 1
quickHolder.ZIndex = 101
quickHolder.Parent = sunWindow

local quickLayout = Instance.new("UIListLayout")
quickLayout.FillDirection = Enum.FillDirection.Horizontal
quickLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
quickLayout.Padding = UDim.new(0, 7)
quickLayout.Parent = quickHolder

local function makeSunQuick(label, amount)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.25, -6, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(31, 35, 44)
	button.BorderSizePixel = 0
	button.Text = label
	button.TextColor3 = Color3.fromRGB(220, 224, 232)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 11
	button.ZIndex = 102
	button.Parent = quickHolder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		sunInput.Text = tostring(amount)
	end)
end

makeSunQuick("10K", 10000)
makeSunQuick("100K", 100000)
makeSunQuick("500K", 500000)
makeSunQuick("MAX", 999999)

local sunStatus = Instance.new("TextLabel")
sunStatus.Position = UDim2.fromOffset(20, 188)
sunStatus.Size = UDim2.new(1, -40, 0, 22)
sunStatus.BackgroundTransparency = 1
sunStatus.Text = "Currency alias: Sunshards / Sun"
sunStatus.TextColor3 = Color3.fromRGB(130, 136, 150)
sunStatus.Font = Enum.Font.GothamMedium
sunStatus.TextSize = 11
sunStatus.TextXAlignment = Enum.TextXAlignment.Left
sunStatus.ZIndex = 101
sunStatus.Parent = sunWindow

local sunApply = Instance.new("TextButton")
sunApply.Position = UDim2.fromOffset(20, 220)
sunApply.Size = UDim2.new(1, -40, 0, 44)
sunApply.BackgroundColor3 = Color3.fromRGB(198, 151, 43)
sunApply.BorderSizePixel = 0
sunApply.Text = "APPLY SUN"
sunApply.TextColor3 = Color3.fromRGB(15, 15, 18)
sunApply.Font = Enum.Font.GothamBold
sunApply.TextSize = 13
sunApply.ZIndex = 102
sunApply.Parent = sunWindow

local sunApplyCorner = Instance.new("UICorner")
sunApplyCorner.CornerRadius = UDim.new(0, 10)
sunApplyCorner.Parent = sunApply

local sunRequestBusy = false

local function requestSunAmount()
	if sunRequestBusy then
		return
	end

	local amount = tonumber(sunInput.Text)

	if not amount then
		sunStatus.Text = "Nhập số hợp lệ."
		sunStatus.TextColor3 = Color3.fromRGB(255, 105, 105)
		return
	end

	amount = math.clamp(
		math.floor(amount),
		CONFIG.SunMin,
		CONFIG.SunMax
	)

	sunInput.Text = tostring(amount)
	sunRequestBusy = true

	sunApply.Text = "ĐANG ÁP DỤNG..."
	sunApply.AutoButtonColor = false

	local ok, result = pcall(function()
		return sunRemote:InvokeServer(amount)
	end)

	if ok and type(result) == "table" and result.ok then
		local aliases = result.aliases or "Sun"
		local finalValue = result.value or amount

		sunStatus.Text =
			"✓ "
			.. aliases
			.. " = "
			.. tostring(finalValue)

		sunStatus.TextColor3 = Color3.fromRGB(92, 235, 145)
		sunApply.Text = "✓ ĐÃ ÁP DỤNG"
	else
		local message =
			type(result) == "table" and result.message
			or "Server không phản hồi."

		sunStatus.Text = "✕ " .. tostring(message)
		sunStatus.TextColor3 = Color3.fromRGB(255, 105, 105)
		sunApply.Text = "THỬ LẠI"
	end

	task.delay(0.9, function()
		if sunApply and sunApply.Parent then
			sunApply.Text = "APPLY SUN"
			sunApply.AutoButtonColor = true
		end

		sunRequestBusy = false
	end)
end

sunApply.MouseButton1Click:Connect(requestSunAmount)

sunInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		requestSunAmount()
	end
end)

sunClose.MouseButton1Click:Connect(function()
	sunWindow.Visible = false
end)

createActionButton("Sun / Sunshards Manager", function()
	sunWindow.Visible = true
	sunInput:CaptureFocus()
end)


---------------------------------------------------------------------
-- MINIMIZE
---------------------------------------------------------------------

local minimized = false
local fullSize = main.Size

minimize.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then
		list.Visible = false
		status.Visible = false
		main.Size = UDim2.fromOffset(380, 58)
		minimize.Text = "+"
	else
		list.Visible = true
		status.Visible = true
		main.Size = fullSize
		minimize.Text = "—"
	end
end)

---------------------------------------------------------------------
-- DRAG WINDOW
---------------------------------------------------------------------

do
	local dragging = false
	local dragStart = nil
	local startPosition = nil

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPosition = main.Position
		end
	end)

	header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging or not dragStart or not startPosition then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local delta = input.Position - dragStart

			main.Position =
				UDim2.new(
					startPosition.X.Scale,
					startPosition.X.Offset + delta.X,
					startPosition.Y.Scale,
					startPosition.Y.Offset + delta.Y
				)
		end
	end)
end

---------------------------------------------------------------------
-- KEY SYSTEM
---------------------------------------------------------------------

local keyFrame = Instance.new("Frame")
keyFrame.Name = "KeySystem"
keyFrame.AnchorPoint = Vector2.new(0.5, 0.5)
keyFrame.Position = UDim2.fromScale(0.5, 0.5)
keyFrame.Size = UDim2.fromOffset(350, 215)
keyFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
keyFrame.BorderSizePixel = 0
keyFrame.Parent = gui

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 16)
keyCorner.Parent = keyFrame

local keyStroke = Instance.new("UIStroke")
keyStroke.Color = Color3.fromRGB(70, 75, 90)
keyStroke.Transparency = 0.2
keyStroke.Parent = keyFrame

local keyTitle = Instance.new("TextLabel")
keyTitle.Position = UDim2.fromOffset(20, 18)
keyTitle.Size = UDim2.new(1, -40, 0, 30)
keyTitle.BackgroundTransparency = 1
keyTitle.Text = "AXIOM BUS ASSIST V2"
keyTitle.TextColor3 = Color3.new(1, 1, 1)
keyTitle.Font = Enum.Font.GothamBold
keyTitle.TextSize = 18
keyTitle.TextXAlignment = Enum.TextXAlignment.Left
keyTitle.Parent = keyFrame

local keySubtitle = Instance.new("TextLabel")
keySubtitle.Position = UDim2.fromOffset(20, 48)
keySubtitle.Size = UDim2.new(1, -40, 0, 20)
keySubtitle.BackgroundTransparency = 1
keySubtitle.Text = "Nhập key để mở bảng điều khiển"
keySubtitle.TextColor3 = Color3.fromRGB(125, 135, 155)
keySubtitle.Font = Enum.Font.GothamMedium
keySubtitle.TextSize = 11
keySubtitle.TextXAlignment = Enum.TextXAlignment.Left
keySubtitle.Parent = keyFrame

local keyInput = Instance.new("TextBox")
keyInput.Position = UDim2.fromOffset(20, 86)
keyInput.Size = UDim2.new(1, -40, 0, 43)
keyInput.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
keyInput.BorderSizePixel = 0
keyInput.PlaceholderText = "Key..."
keyInput.Text = ""
keyInput.ClearTextOnFocus = false
keyInput.TextColor3 = Color3.new(1, 1, 1)
keyInput.PlaceholderColor3 = Color3.fromRGB(100, 110, 130)
keyInput.Font = Enum.Font.GothamMedium
keyInput.TextSize = 13
keyInput.Parent = keyFrame

local keyInputCorner = Instance.new("UICorner")
keyInputCorner.CornerRadius = UDim.new(0, 9)
keyInputCorner.Parent = keyInput

local loginButton = Instance.new("TextButton")
loginButton.Position = UDim2.fromOffset(20, 143)
loginButton.Size = UDim2.new(1, -40, 0, 42)
loginButton.BackgroundColor3 = Color3.fromRGB(55, 105, 215)
loginButton.BorderSizePixel = 0
loginButton.Text = "UNLOCK"
loginButton.TextColor3 = Color3.new(1, 1, 1)
loginButton.Font = Enum.Font.GothamBold
loginButton.TextSize = 13
loginButton.Parent = keyFrame

local loginCorner = Instance.new("UICorner")
loginCorner.CornerRadius = UDim.new(0, 9)
loginCorner.Parent = loginButton

local authenticated = false

local function cleanKey(value)
	return string.upper(
		value:gsub("%s+", "")
	)
end

local function authenticate()
	if authenticated then
		return
	end

	local entered = cleanKey(keyInput.Text)

	if entered == CONFIG.MasterKey then
		authenticated = true

		loginButton.Text = "ACCESS GRANTED"
		loginButton.BackgroundColor3 = Color3.fromRGB(35, 130, 75)

		task.wait(0.15)

		keyFrame.Visible = false
		main.Visible = true

		notify(
			"Axiom Bus Assist",
			"Key accepted. Base speed = 75."
		)
	else
		keyInput.Text = ""
		keyInput.PlaceholderText = "KEY KHÔNG HỢP LỆ"

		local oldPosition = keyFrame.Position

		for _ = 1, 3 do
			keyFrame.Position = oldPosition + UDim2.fromOffset(6, 0)
			task.wait(0.035)

			keyFrame.Position = oldPosition - UDim2.fromOffset(6, 0)
			task.wait(0.035)
		end

		keyFrame.Position = oldPosition
	end
end

loginButton.MouseButton1Click:Connect(authenticate)

keyInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		authenticate()
	end
end)

---------------------------------------------------------------------
-- UI SHOW / HIDE
---------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == CONFIG.UIKey and authenticated then
		main.Visible = not main.Visible
	end
end)

---------------------------------------------------------------------
-- VEHICLE CHANGE HANDLER
---------------------------------------------------------------------

local function onVehicleChanged(newSeat)
	if Features.Fly then
		disableFly()
	end

	restoreBusCollision()

	currentSeat = newSeat
	currentBus = newSeat and findBusFromSeat(newSeat) or nil

	parked = false
	autoParking = false
	processingStop = false

	frontDoorOpen = false
	rearDoorOpen = false

	Features.Cruise = false
	cruiseSpeed = 0

	if currentSeat then
		applySpeedLimit()

		if Features.NoclipBus then
			applyBusNoclip()
		end

		if Features.Lights then
			updateLights()
		end
	end

	refreshAllButtons()
end

---------------------------------------------------------------------
-- MAIN LOOP
---------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	-----------------------------------------------------------------
	-- VEHICLE DETECTION
	-----------------------------------------------------------------

	local seat = getPlayerVehicleSeat()

	if seat ~= lastSeat then
		lastSeat = seat
		onVehicleChanged(seat)
	end

	-----------------------------------------------------------------
	-- NO BUS
	-----------------------------------------------------------------

	if not currentSeat or not currentBus then
		status.Text =
			"BUS       : WAITING"
			.. "\nSPEED     : 0 KM/H"
			.. "\nLIMIT     : "
			.. tostring(CONFIG.BusSpeed)
			.. "\nGEAR      : -"
			.. "\nAUTO PARK : READY"

		return
	end

	-----------------------------------------------------------------
	-- SPEED
	-----------------------------------------------------------------

	local velocity = currentSeat.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local kmh = studsPerSecondToKmh(speed)

	-----------------------------------------------------------------
	-- KEEP FEATURES ACTIVE
	-----------------------------------------------------------------

	if Features.NoclipBus then
		applyBusNoclip()
	end

	if Features.PlayerNoclip then
		applyPlayerNoclip()
	end

	if Features.Fly then
		updateFly(dt)
	end

	-----------------------------------------------------------------
	-- SPEED LIMIT CONTROLLER
	-----------------------------------------------------------------

	applySpeedLimit()

	if parked and speed < 3 then
		currentSeat.AssemblyLinearVelocity = Vector3.zero
	end

	-----------------------------------------------------------------
	-- CRUISE
	-----------------------------------------------------------------

	if Features.Cruise
		and not Features.Fly
		and cruiseSpeed > 0
		and not parked
		and not autoParking
		and not processingStop
		and not frontDoorOpen
		and not rearDoorOpen
	then
		if speed < cruiseSpeed then
			local direction = currentSeat.CFrame.LookVector
			local difference = cruiseSpeed - speed

			currentSeat.AssemblyLinearVelocity =
				velocity
				+ direction
				* difference
				* dt
				* 2
		end
	end

	-----------------------------------------------------------------
	-- AUTO PARK
	-----------------------------------------------------------------

	if Features.AutoPark
		and not Features.Fly
		and not parked
		and not processingStop
	then
		local stop, distance = getNearestStop()

		if stop
			and distance <= CONFIG.AutoParkTriggerDistance
			and speed <= CONFIG.AutoParkMaxSpeed
		then
			if stop ~= lastStop
				or os.clock() - lastStopTime >= CONFIG.StopCooldown
			then
				task.spawn(performAutoStop, stop)
			end
		end
	end

	-----------------------------------------------------------------
	-- STATUS
	-----------------------------------------------------------------

	local gear = parked and "P" or "D"

	local autoState = "READY"

	if autoParking then
		autoState = "BRAKING"
	elseif processingStop then
		autoState = "ACTIVE"
	elseif parked then
		autoState = "PARKED"
	end

	local doorState = "CLOSED"

	if frontDoorOpen and rearDoorOpen then
		doorState = "FRONT + REAR"
	elseif frontDoorOpen then
		doorState = "FRONT"
	elseif rearDoorOpen then
		doorState = "REAR"
	end

	status.Text =
		"BUS       : "
		.. currentBus.Name
		.. "\nSPEED     : "
		.. kmh
		.. " KM/H"
		.. "\nLIMIT     : "
		.. tostring(getCurrentSpeedLimit())
		.. "\nGEAR      : "
		.. gear
		.. "\nAUTO PARK : "
		.. autoState
		.. "\nDOORS     : "
		.. doorState
end)

---------------------------------------------------------------------
-- CHARACTER RESET
---------------------------------------------------------------------

player.CharacterAdded:Connect(function()
	if Features.Fly then
		disableFly()
	end

	restoreBusCollision()
	restorePlayerCollision()

	currentBus = nil
	currentSeat = nil
	lastSeat = nil

	parked = false
	autoParking = false
	processingStop = false

	frontDoorOpen = false
	rearDoorOpen = false

	Features.Cruise = false
	cruiseSpeed = 0
end)

---------------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------------

gui.Destroying:Connect(function()
	destroyFlyObjects()
	restoreBusCollision()
	restorePlayerCollision()

	if Features.FixLag then
		disableFixLag()
	end
end)

print("[AXIOM] Bus Assist V2 loaded.")


--[[

=====================================================================
SECTION B - SERVER
=====================================================================
]]

--[[
=====================================================================
        AXIOM SUN / SUNSHARDS MANAGER - SERVER
=====================================================================

Đặt file này tại:
ServerScriptService
└── AxiomSunCurrency.server.lua

Currency aliases:
    - Sunshards
    - Sun

Client RemoteFunction:
    ReplicatedStorage.AxiomSetSunCurrency

Mặc định tất cả người chơi đều được dùng ưu đãi.
Nếu game có cả Sunshards và Sun, script đồng bộ cả hai.
=====================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------

local CONFIG = {
	REMOTE_NAME = "AxiomSetSunCurrency",

	MIN_AMOUNT = 0,
	MAX_AMOUNT = 999999,

	-- true: nhập 100000 -> số dư trở thành đúng 100000
	-- false: nhập 100000 -> cộng thêm 100000
	SET_EXACT_AMOUNT = true,

	REQUEST_COOLDOWN = 0.35,

	CURRENCY_NAMES = {
		"Sunshards",
		"Sun",
	},
}

---------------------------------------------------------------------
-- REMOTE FUNCTION
---------------------------------------------------------------------

local oldRemote = ReplicatedStorage:FindFirstChild(CONFIG.REMOTE_NAME)

if oldRemote and not oldRemote:IsA("RemoteFunction") then
	oldRemote:Destroy()
	oldRemote = nil
end

local remote = oldRemote

if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = CONFIG.REMOTE_NAME
	remote.Parent = ReplicatedStorage
end

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function isCurrencyValue(object)
	return object
		and (
			object:IsA("IntValue")
			or object:IsA("NumberValue")
		)
end

local function normalizeName(value)
	return string.lower(
		tostring(value or "")
	)
end

local allowedNames = {}

for _, name in ipairs(CONFIG.CURRENCY_NAMES) do
	allowedNames[normalizeName(name)] = true
end

local function findCurrencyValues(player)
	local found = {}
	local seen = {}

	local function addIfCurrency(object)
		if not isCurrencyValue(object) then
			return
		end

		if not allowedNames[normalizeName(object.Name)] then
			return
		end

		if seen[object] then
			return
		end

		seen[object] = true
		table.insert(found, object)
	end

	-- Common player children / leaderstats.
	for _, child in ipairs(player:GetChildren()) do
		addIfCurrency(child)
	end

	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		for _, child in ipairs(leaderstats:GetChildren()) do
			addIfCurrency(child)
		end
	end

	-- Some games keep the currency in a data/stats folder.
	for _, folderName in ipairs({
		"Data",
		"Stats",
		"PlayerData",
		"Values",
		"Currencies",
		"Currency",
	}) do
		local folder = player:FindFirstChild(folderName)

		if folder then
			for _, object in ipairs(folder:GetDescendants()) do
				addIfCurrency(object)
			end
		end
	end

	return found
end

local function ensureFallbackCurrency(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local existing = leaderstats:FindFirstChild("Sunshards")
		or leaderstats:FindFirstChild("Sun")

	if isCurrencyValue(existing) then
		return existing
	end

	local value = Instance.new("IntValue")
	value.Name = "Sunshards"
	value.Value = 0
	value.Parent = leaderstats

	return value
end

local function getCurrencies(player)
	local currencies = findCurrencyValues(player)

	if #currencies == 0 then
		table.insert(
			currencies,
			ensureFallbackCurrency(player)
		)
	end

	return currencies
end

local function getAliasText(currencies)
	local names = {}
	local seen = {}

	for _, currency in ipairs(currencies) do
		if currency and currency.Parent then
			local name = currency.Name

			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end

	if #names == 0 then
		return "Sun"
	end

	return table.concat(names, " + ")
end

---------------------------------------------------------------------
-- RATE LIMIT
---------------------------------------------------------------------

local lastRequest = {}

---------------------------------------------------------------------
-- APPLY REQUEST
---------------------------------------------------------------------

remote.OnServerInvoke = function(player, requestedAmount)
	local now = os.clock()
	local previous = lastRequest[player]

	if previous
		and now - previous < CONFIG.REQUEST_COOLDOWN
	then
		return {
			ok = false,
			message = "Thao tác quá nhanh.",
		}
	end

	lastRequest[player] = now

	local amount = tonumber(requestedAmount)

	if not amount
		or amount ~= amount
		or amount == math.huge
		or amount == -math.huge
	then
		return {
			ok = false,
			message = "Giá trị không hợp lệ.",
		}
	end

	amount = math.clamp(
		math.floor(amount),
		CONFIG.MIN_AMOUNT,
		CONFIG.MAX_AMOUNT
	)

	local currencies = getCurrencies(player)

	if #currencies == 0 then
		return {
			ok = false,
			message = "Không tìm thấy Sun/Sunshards.",
		}
	end

	local finalValue = amount

	if not CONFIG.SET_EXACT_AMOUNT then
		local current = tonumber(currencies[1].Value) or 0

		finalValue = math.clamp(
			current + amount,
			CONFIG.MIN_AMOUNT,
			CONFIG.MAX_AMOUNT
		)
	end

	-- Sync every recognized alias that exists.
	for _, currency in ipairs(currencies) do
		if currency and currency.Parent then
			currency.Value = finalValue
		end
	end

	return {
		ok = true,
		value = finalValue,
		aliases = getAliasText(currencies),
	}
end

---------------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

print("[AXIOM] Sun/Sunshards server manager loaded.")
