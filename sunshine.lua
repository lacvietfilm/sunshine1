--[[
=====================================================================
                    AXIOM BUS ASSIST - FULL
                         SINGLE FILE
=====================================================================

Dùng cho Roblox Studio / game của bạn.

Đặt file dưới dạng LocalScript tại:
StarterPlayer
└── StarterPlayerScripts
    └── AxiomBusAssist.client.lua

Cấu trúc khuyến nghị:

Workspace
├── Buses
│   └── <Bus Model>
│       ├── VehicleSeat
│       ├── FrontDoor
│       │   └── HingeConstraint
│       ├── RearDoor
│       │   └── HingeConstraint
│       └── HeadLights
│           └── ... Light objects
│
└── BusStops
    ├── Stop01
    ├── Stop02
    └── ...

Mỗi BusStop có thể thêm Attribute:
StopName = "Tên trạm"

TÍNH NĂNG:
✓ UI kéo được
✓ Thu nhỏ UI
✓ RightShift ẩn/hiện UI
✓ Fix Lag
✓ Auto Park
✓ Auto mở cửa trước + sau
✓ Auto đóng cửa
✓ Auto Release P
✓ Fly
✓ Boost
✓ Cruise Control
✓ Head Lights
✓ Park / Release P thủ công
✓ Trạng thái Bus / Speed / Gear / Auto Park trên UI
=====================================================================
]]

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------

local CONFIG = {
	UIKey = Enum.KeyCode.RightShift,

	NormalSpeed = 60,
	BoostSpeed = 95,

	FlySpeed = 85,
	FlyVerticalSpeed = 65,
	FlyResponsiveness = 20,

	CruiseMinSpeed = 15,
	CruiseMaxSpeed = 75,

	AutoParkTriggerDistance = 22,
	AutoParkMaxSpeed = 40,
	ParkSpeedThreshold = 1.2,
	BrakeFactor = 0.88,

	StopDuration = 6,
	DoorCloseDelay = 1.4,

	DoorOpenAngle = 85,
	DoorClosedAngle = 0,
	DoorSpeed = 3,
	DoorTorque = 100000,

	StopCooldown = 5,
}

---------------------------------------------------------------------
-- FEATURE STATES
---------------------------------------------------------------------

local Features = {
	FixLag = false,
	AutoPark = true,
	AutoDoors = true,
	AutoReleasePark = true,
	Fly = false,
	Boost = false,
	Cruise = false,
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

local cruiseSpeed = 0

local frontDoorOpen = false
local rearDoorOpen = false

local lastStop = nil
local lastStopTime = 0

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

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
		warn("[AXIOM] Không tìm thấy HingeConstraint:", name)
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
		Features.Boost = false
		Features.Cruise = false
		cruiseSpeed = 0

		currentSeat.MaxSpeed = 0

		if currentSeat.AssemblyLinearVelocity.Magnitude <= 5 then
			currentSeat.AssemblyLinearVelocity = Vector3.zero
			currentSeat.AssemblyAngularVelocity = Vector3.zero
		end
	else
		currentSeat.MaxSpeed = CONFIG.NormalSpeed
	end
end

---------------------------------------------------------------------
-- LIGHT SYSTEM
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
-- FIX LAG SYSTEM
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
-- FLY SYSTEM
-- W/S: tiến-lùi | A/D: trái-phải | Space: lên | LeftCtrl: xuống
---------------------------------------------------------------------

local flyAttachment = nil
local flyVelocity = nil
local flyOrientation = nil

local function getFlyRoot()
    if not currentBus then return nil end
    if currentBus.PrimaryPart then return currentBus.PrimaryPart end
    if currentSeat and currentSeat:IsA("BasePart") then return currentSeat end
    return currentBus:FindFirstChildWhichIsA("BasePart", true)
end

local function destroyFlyObjects()
    if flyVelocity then flyVelocity:Destroy(); flyVelocity=nil end
    if flyOrientation then flyOrientation:Destroy(); flyOrientation=nil end
    if flyAttachment then flyAttachment:Destroy(); flyAttachment=nil end
end

local function enableFly()
    if not currentBus then Features.Fly=false; return end
    local root=getFlyRoot()
    if not root then Features.Fly=false; return end
    destroyFlyObjects()

    flyAttachment=Instance.new("Attachment")
    flyAttachment.Name="AxiomFlyAttachment"
    flyAttachment.Parent=root

    flyVelocity=Instance.new("LinearVelocity")
    flyVelocity.Name="AxiomFlyVelocity"
    flyVelocity.Attachment0=flyAttachment
    flyVelocity.RelativeTo=Enum.ActuatorRelativeTo.World
    flyVelocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    flyVelocity.VectorVelocity=Vector3.zero
    flyVelocity.MaxForce=math.huge
    flyVelocity.Parent=root

    flyOrientation=Instance.new("AlignOrientation")
    flyOrientation.Name="AxiomFlyOrientation"
    flyOrientation.Attachment0=flyAttachment
    flyOrientation.Mode=Enum.OrientationAlignmentMode.OneAttachment
    flyOrientation.MaxTorque=math.huge
    flyOrientation.MaxAngularVelocity=math.huge
    flyOrientation.Responsiveness=CONFIG.FlyResponsiveness
    flyOrientation.RigidityEnabled=false
    flyOrientation.Parent=root

    parked=false
    autoParking=false
    processingStop=false
    Features.Cruise=false
    Features.Boost=false
    cruiseSpeed=0
    if currentSeat then currentSeat.MaxSpeed=CONFIG.NormalSpeed end
    print("[AXIOM] Fly ON")
end

local function disableFly()
    destroyFlyObjects()
    print("[AXIOM] Fly OFF")
end

local function getFlyDirection()
    local cam=workspace.CurrentCamera
    if not cam then return Vector3.zero,0,Vector3.new(0,0,-1) end
    local forward=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
    local right=Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z)
    if forward.Magnitude>0 then forward=forward.Unit end
    if right.Magnitude>0 then right=right.Unit end

    local dir=Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir-=right end
    if dir.Magnitude>1 then dir=dir.Unit end

    local vertical=0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical+=1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical-=1 end
    return dir,vertical,forward
end

local function updateFly()
    if not Features.Fly or not currentBus then return end
    local root=getFlyRoot()
    if not root then return end
    if not flyVelocity or not flyVelocity.Parent or not flyOrientation or not flyOrientation.Parent then
        enableFly()
    end
    if not flyVelocity or not flyOrientation then return end
    local dir,vertical,forward=getFlyDirection()
    flyVelocity.VectorVelocity = dir*CONFIG.FlySpeed + Vector3.new(0,vertical*CONFIG.FlyVerticalSpeed,0)
    if forward.Magnitude>0 then
        local p=root.Position
        flyOrientation.CFrame=CFrame.lookAt(p,p+forward,Vector3.yAxis)
    end
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
			local distance = (currentSeat.Position - stop.Position).Magnitude

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

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------

local oldGui = playerGui:FindFirstChild("AxiomBusAssist")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "AxiomBusAssist"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(365, 520)
main.Position = UDim2.new(0, 25, 0.5, -260)
main.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
main.BorderSizePixel = 0
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
title.Text = "AXIOM BUS ASSIST"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(18, 33)
subtitle.Size = UDim2.new(1, -85, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.Text = "SYSTEM • ONLINE"
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
status.Size = UDim2.new(1, -36, 0, 84)
status.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
status.BorderSizePixel = 0
status.TextColor3 = Color3.fromRGB(195, 205, 215)
status.Font = Enum.Font.Code
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "BUS       : WAITING\nSPEED     : 0 KM/H\nGEAR      : -\nAUTO PARK : READY"
status.Parent = main

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 10)
statusCorner.Parent = status

---------------------------------------------------------------------
-- BUTTON AREA
---------------------------------------------------------------------

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(18, 162)
list.Size = UDim2.new(1, -36, 1, -180)
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

		elseif feature == "Fly" then
			if Features.Fly then enableFly() else disableFly() end

		elseif feature == "Lights" then
			updateLights()

		elseif feature == "Cruise" then
			if Features.Cruise then
				if not currentSeat or parked or processingStop then
					Features.Cruise = false
				else
					local speed = getBusSpeed()

					if speed >= CONFIG.CruiseMinSpeed then
						cruiseSpeed = math.clamp(
							speed,
							CONFIG.CruiseMinSpeed,
							CONFIG.CruiseMaxSpeed
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
-- TOGGLE BUTTONS
---------------------------------------------------------------------

createToggle("Fix Lag", "FixLag")
createToggle("Auto Park", "AutoPark")
createToggle("Auto Doors", "AutoDoors")
createToggle("Auto Release P", "AutoReleasePark")
createToggle("Fly", "Fly")
createToggle("Boost", "Boost")
createToggle("Cruise Control", "Cruise")
createToggle("Head Lights", "Lights")

---------------------------------------------------------------------
-- MANUAL FRONT DOOR
---------------------------------------------------------------------

local frontButton = Instance.new("TextButton")
styleButton(frontButton)
frontButton.BackgroundColor3 = Color3.fromRGB(35, 42, 57)
frontButton.Text = "CỬA TRƯỚC • MỞ / ĐÓNG"
frontButton.Parent = list

frontButton.MouseButton1Click:Connect(function()
	if not currentSeat or processingStop then
		return
	end

	if not parked then
		return
	end

	setDoor("FrontDoor", not frontDoorOpen)
end)

---------------------------------------------------------------------
-- MANUAL REAR DOOR
---------------------------------------------------------------------

local rearButton = Instance.new("TextButton")
styleButton(rearButton)
rearButton.BackgroundColor3 = Color3.fromRGB(35, 42, 57)
rearButton.Text = "CỬA SAU • MỞ / ĐÓNG"
rearButton.Parent = list

rearButton.MouseButton1Click:Connect(function()
	if not currentSeat or processingStop then
		return
	end

	if not parked then
		return
	end

	setDoor("RearDoor", not rearDoorOpen)
end)

---------------------------------------------------------------------
-- PARK BUTTON
---------------------------------------------------------------------

local parkButton = Instance.new("TextButton")
styleButton(parkButton)
parkButton.BackgroundColor3 = Color3.fromRGB(59, 47, 30)
parkButton.Text = "PARK / RELEASE P"
parkButton.Parent = list

parkButton.MouseButton1Click:Connect(function()
	if not currentSeat or processingStop then
		return
	end

	if parked then
		if frontDoorOpen or rearDoorOpen then
			closeDoors()
			task.wait(CONFIG.DoorCloseDelay)
		end

		setPark(false)

	else
		if getBusSpeed() <= 3 then
			setPark(true)
		end
	end

	refreshAllButtons()
end)

---------------------------------------------------------------------
-- AUTO STOP
---------------------------------------------------------------------

local function performAutoStop(stop)
	if processingStop or not currentSeat then
		return
	end

	if stop == lastStop and os.clock() - lastStopTime < CONFIG.StopCooldown then
		return
	end

	processingStop = true
	autoParking = true

	Features.Boost = false
	Features.Cruise = false
	cruiseSpeed = 0

	refreshAllButtons()

	-----------------------------------------------------------------
	-- AUTO BRAKE
	-----------------------------------------------------------------

	while currentSeat
		and currentSeat.Parent
		and currentSeat.AssemblyLinearVelocity.Magnitude
			> CONFIG.ParkSpeedThreshold
	do
		local velocity = currentSeat.AssemblyLinearVelocity

		currentSeat.AssemblyLinearVelocity =
			velocity * CONFIG.BrakeFactor

		task.wait(0.06)
	end

	if not currentSeat then
		autoParking = false
		processingStop = false
		return
	end

	currentSeat.AssemblyLinearVelocity = Vector3.zero
	currentSeat.AssemblyAngularVelocity = Vector3.zero

	-----------------------------------------------------------------
	-- P
	-----------------------------------------------------------------

	setPark(true)
	autoParking = false

	-----------------------------------------------------------------
	-- OPEN DOORS
	-----------------------------------------------------------------

	if Features.AutoDoors then
		task.wait(0.4)
		openDoors()
	end

	-----------------------------------------------------------------
	-- DWELL
	-----------------------------------------------------------------

	task.wait(CONFIG.StopDuration)

	if not currentSeat then
		processingStop = false
		return
	end

	-----------------------------------------------------------------
	-- CLOSE DOORS
	-----------------------------------------------------------------

	if Features.AutoDoors then
		closeDoors()
		task.wait(CONFIG.DoorCloseDelay)
	end

	-----------------------------------------------------------------
	-- RELEASE P
	-----------------------------------------------------------------

	if Features.AutoReleasePark then
		setPark(false)
	end

	lastStop = stop
	lastStopTime = os.clock()

	processingStop = false
end

---------------------------------------------------------------------
-- UI MINIMIZE
---------------------------------------------------------------------

local minimized = false

minimize.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then
		main.Size = UDim2.fromOffset(365, 58)
		status.Visible = false
		list.Visible = false
	else
		main.Size = UDim2.fromOffset(365, 520)
		status.Visible = true
		list.Visible = true
	end
end)

---------------------------------------------------------------------
-- DRAG UI
---------------------------------------------------------------------

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

UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
	then
		local delta = input.Position - dragStart

		main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		dragging = false
	end
end)

---------------------------------------------------------------------
-- UI SHOW / HIDE KEY
---------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == CONFIG.UIKey then
		gui.Enabled = not gui.Enabled
	end
end)

---------------------------------------------------------------------
-- VEHICLE CHANGE HANDLER
---------------------------------------------------------------------

local function onVehicleChanged(newSeat)
	if Features.Fly then
		disableFly()
	end

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
		currentSeat.MaxSpeed = CONFIG.NormalSpeed

		if Features.Fly then
			enableFly()
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
	-- DETECT VEHICLE
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
	-- KEEP NO COLLISION
	-----------------------------------------------------------------

	if Features.Fly then
		updateFly()
	end

	-----------------------------------------------------------------
	-- PARK / BOOST
	-----------------------------------------------------------------

	if Features.Fly then
		currentSeat.MaxSpeed = CONFIG.NormalSpeed

	elseif parked then
		currentSeat.MaxSpeed = 0

		if speed < 3 then
			currentSeat.AssemblyLinearVelocity = Vector3.zero
		end

	elseif frontDoorOpen or rearDoorOpen then
		-- Door interlock
		currentSeat.MaxSpeed = 0

	elseif Features.Boost then
		currentSeat.MaxSpeed = CONFIG.BoostSpeed

	else
		currentSeat.MaxSpeed = CONFIG.NormalSpeed
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

	refreshAllButtons()
end)

---------------------------------------------------------------------
-- INITIAL STATUS
---------------------------------------------------------------------

refreshAllButtons()

print("===================================================")
print("[AXIOM BUS ASSIST] ONLINE")
print("[AXIOM] RightShift = Show / Hide UI")
print("===================================================")
