--[[
=====================================================================
                    AXIOM BUS SIMULATOR SYSTEM
                          SINGLE FILE
=====================================================================

ĐẶT FILE:
StarterPlayer
└── StarterPlayerScripts
    └── BusSystem.client.lua

WORKSPACE:

Workspace
├── Buses
│   └── CityBus
│       ├── VehicleSeat
│       ├── FrontDoor
│       │   └── HingeConstraint
│       ├── RearDoor
│       │   └── HingeConstraint
│       ├── HeadLights
│       │   ├── Left
│       │   │   └── SpotLight
│       │   └── Right
│       │       └── SpotLight
│       ├── Horn
│       │   └── Sound
│       └── RouteDisplay
│           └── SurfaceGui
│               └── TextLabel
│
└── BusStops
    ├── Stop01
    ├── Stop02
    ├── Stop03
    └── ...

MỖI BUS STOP:
Attribute:
    StopName = "Ga Trung Tâm"

PHÍM:
W/S     Ga / phanh
A/D     Lái
P       Park
SHIFT   Boost
C       Cruise Control
Z       Cửa trước
X       Cửa sau
L       Đèn
H       Còi
N       Tuyến tiếp
M       Tuyến trước

AUTO STOP:
Đi vào đúng trạm
→ Auto brake
→ P
→ Mở cửa trước/sau
→ Chờ
→ Đóng cửa
→ Nhả P
→ Trạm tiếp theo
=====================================================================
]]

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------

local CONFIG = {

	Vehicle = {

		NormalSpeed = 65,

		BoostSpeed = 95,

		CruiseMinSpeed = 15,

		CruiseMaxSpeed = 75,

		DoorOpenAngle = 85,

		DoorClosedAngle = 0,

		DoorAngularSpeed = 3,

		DoorTorque = 100000,

		HornCooldown = 0.4,

	},

	Stop = {

		Enabled = true,

		MaxArrivalSpeed = 35,

		ParkSpeedThreshold = 1.5,

		DwellTime = 7,

		DoorCloseDelay = 1.5,

		StopCooldown = 10,

		OpenFrontDoor = true,

		OpenRearDoor = true,

		AutoReleasePark = true,

		BrakeStrength = 0.88,

	},

	Controls = {

		Boost = Enum.KeyCode.LeftShift,

		Cruise = Enum.KeyCode.C,

		Park = Enum.KeyCode.P,

		FrontDoor = Enum.KeyCode.Z,

		RearDoor = Enum.KeyCode.X,

		Lights = Enum.KeyCode.L,

		Horn = Enum.KeyCode.H,

		NextRoute = Enum.KeyCode.N,

		PreviousRoute = Enum.KeyCode.M,

	},

	Routes = {

		{

			Name = "Tuyến 01",

			Destination = "Bến Trung Tâm",

			Stops = {

				"Ga Trung Tâm",

				"Quảng Trường",

				"Bệnh Viện",

				"Đại Lộ",

				"Bến Trung Tâm",

			},

		},

		{

			Name = "Tuyến 02",

			Destination = "Bến Biển",

			Stops = {

				"Ga Trung Tâm",

				"Công Viên",

				"Khu Thương Mại",

				"Bãi Biển",

				"Bến Biển",

			},

		},

		{

			Name = "Tuyến 03",

			Destination = "Sân Bay",

			Stops = {

				"Ga Trung Tâm",

				"Đường Cao Tốc",

				"Khu Công Nghiệp",

				"Sân Bay",

			},

		},

	},

}

---------------------------------------------------------------------
-- REFERENCES
---------------------------------------------------------------------

local busesFolder =
	workspace:WaitForChild("Buses")

local stopsFolder =
	workspace:WaitForChild("BusStops")

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------

local currentBus = nil

local currentSeat = nil

local routeIndex = 1

local stopIndex = 1

local parked = false

local autoParking = false

local stopSequenceRunning = false

local boosting = false

local cruiseEnabled = false

local cruiseSpeed = 0

local frontDoorOpen = false

local rearDoorOpen = false

local lightsOn = false

local lastHorn = 0

local stopCooldowns = {}

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------

local gui =
	Instance.new("ScreenGui")

gui.Name =
	"AxiomBusHUD"

gui.ResetOnSpawn =
	false

gui.IgnoreGuiInset =
	true

gui.Enabled =
	false

gui.Parent =
	player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- MAIN DASHBOARD
---------------------------------------------------------------------

local dashboard =
	Instance.new("Frame")

dashboard.AnchorPoint =
	Vector2.new(
		0.5,
		1
	)

dashboard.Position =
	UDim2.new(
		0.5,
		0,
		1,
		-25
	)

dashboard.Size =
	UDim2.fromOffset(
		590,
		180
	)

dashboard.BackgroundColor3 =
	Color3.fromRGB(
		14,
		16,
		21
	)

dashboard.BackgroundTransparency =
	0.04

dashboard.Parent =
	gui

local dashboardCorner =
	Instance.new("UICorner")

dashboardCorner.CornerRadius =
	UDim.new(
		0,
		20
	)

dashboardCorner.Parent =
	dashboard

local dashboardStroke =
	Instance.new("UIStroke")

dashboardStroke.Thickness =
	1

dashboardStroke.Transparency =
	0.45

dashboardStroke.Color =
	Color3.fromRGB(
		90,
		95,
		110
	)

dashboardStroke.Parent =
	dashboard

---------------------------------------------------------------------
-- SPEED
---------------------------------------------------------------------

local speedLabel =
	Instance.new("TextLabel")

speedLabel.Position =
	UDim2.fromOffset(
		20,
		18
	)

speedLabel.Size =
	UDim2.fromOffset(
		135,
		58
	)

speedLabel.BackgroundTransparency =
	1

speedLabel.Text =
	"0"

speedLabel.Font =
	Enum.Font.GothamBlack

speedLabel.TextSize =
	46

speedLabel.TextColor3 =
	Color3.new(
		1,
		1,
		1
	)

speedLabel.Parent =
	dashboard

local speedUnit =
	Instance.new("TextLabel")

speedUnit.Position =
	UDim2.fromOffset(
		75,
		71
	)

speedUnit.Size =
	UDim2.fromOffset(
		70,
		22
	)

speedUnit.BackgroundTransparency =
	1

speedUnit.Text =
	"KM/H"

speedUnit.Font =
	Enum.Font.GothamMedium

speedUnit.TextSize =
	12

speedUnit.TextColor3 =
	Color3.fromRGB(
		160,
		165,
		180
	)

speedUnit.Parent =
	dashboard

---------------------------------------------------------------------
-- GEAR
---------------------------------------------------------------------

local gearLabel =
	Instance.new("TextLabel")

gearLabel.Position =
	UDim2.fromOffset(
		22,
		105
	)

gearLabel.Size =
	UDim2.fromOffset(
		120,
		48
	)

gearLabel.BackgroundTransparency =
	1

gearLabel.Text =
	"D"

gearLabel.Font =
	Enum.Font.GothamBlack

gearLabel.TextSize =
	40

gearLabel.TextColor3 =
	Color3.fromRGB(
		80,
		255,
		145
	)

gearLabel.Parent =
	dashboard

---------------------------------------------------------------------
-- ROUTE
---------------------------------------------------------------------

local routeLabel =
	Instance.new("TextLabel")

routeLabel.Position =
	UDim2.fromOffset(
		175,
		18
	)

routeLabel.Size =
	UDim2.fromOffset(
		390,
		32
	)

routeLabel.BackgroundTransparency =
	1

routeLabel.Text =
	"Chưa chọn tuyến"

routeLabel.Font =
	Enum.Font.GothamBold

routeLabel.TextSize =
	19

routeLabel.TextXAlignment =
	Enum.TextXAlignment.Left

routeLabel.TextColor3 =
	Color3.new(
		1,
		1,
		1
	)

routeLabel.Parent =
	dashboard

local destinationLabel =
	Instance.new("TextLabel")

destinationLabel.Position =
	UDim2.fromOffset(
		175,
		52
	)

destinationLabel.Size =
	UDim2.fromOffset(
		390,
		25
	)

destinationLabel.BackgroundTransparency =
	1

destinationLabel.Text =
	"Điểm đến: ---"

destinationLabel.Font =
	Enum.Font.Gotham

destinationLabel.TextSize =
	14

destinationLabel.TextXAlignment =
	Enum.TextXAlignment.Left

destinationLabel.TextColor3 =
	Color3.fromRGB(
		180,
		185,
		200
	)

destinationLabel.Parent =
	dashboard

---------------------------------------------------------------------
-- NEXT STOP
---------------------------------------------------------------------

local stopLabel =
	Instance.new("TextLabel")

stopLabel.Position =
	UDim2.fromOffset(
		175,
		80
	)

stopLabel.Size =
	UDim2.fromOffset(
		390,
		23
	)

stopLabel.BackgroundTransparency =
	1

stopLabel.Text =
	"Trạm tiếp theo: ---"

stopLabel.Font =
	Enum.Font.GothamMedium

stopLabel.TextSize =
	13

stopLabel.TextXAlignment =
	Enum.TextXAlignment.Left

stopLabel.TextColor3 =
	Color3.fromRGB(
		205,
		205,
		215
	)

stopLabel.Parent =
	dashboard

---------------------------------------------------------------------
-- STATUS
---------------------------------------------------------------------

local statusLabel =
	Instance.new("TextLabel")

statusLabel.Position =
	UDim2.fromOffset(
		175,
		111
	)

statusLabel.Size =
	UDim2.fromOffset(
		390,
		48
	)

statusLabel.BackgroundTransparency =
	1

statusLabel.Text =
	"XE SẴN SÀNG"

statusLabel.Font =
	Enum.Font.GothamBold

statusLabel.TextSize =
	13

statusLabel.TextWrapped =
	true

statusLabel.TextXAlignment =
	Enum.TextXAlignment.Left

statusLabel.TextYAlignment =
	Enum.TextYAlignment.Top

statusLabel.TextColor3 =
	Color3.fromRGB(
		160,
		235,
		185
	)

statusLabel.Parent =
	dashboard

---------------------------------------------------------------------
-- CONTROL HELP
---------------------------------------------------------------------

local controlsLabel =
	Instance.new("TextLabel")

controlsLabel.AnchorPoint =
	Vector2.new(
		0,
		1
	)

controlsLabel.Position =
	UDim2.new(
		0,
		18,
		1,
		-20
	)

controlsLabel.Size =
	UDim2.fromOffset(
		230,
		220
	)

controlsLabel.BackgroundColor3 =
	Color3.fromRGB(
		14,
		16,
		20
	)

controlsLabel.BackgroundTransparency =
	0.1

controlsLabel.Text =
	[[
  ĐIỀU KHIỂN

  P       Park
  SHIFT   Boost
  C       Cruise

  Z       Cửa trước
  X       Cửa sau

  L       Đèn
  H       Còi

  N       Tuyến tiếp
  M       Tuyến trước
]]

controlsLabel.TextColor3 =
	Color3.fromRGB(
		220,
		220,
		225
	)

controlsLabel.TextSize =
	13

controlsLabel.Font =
	Enum.Font.Code

controlsLabel.TextXAlignment =
	Enum.TextXAlignment.Left

controlsLabel.TextYAlignment =
	Enum.TextYAlignment.Top

controlsLabel.Parent =
	gui

local controlsCorner =
	Instance.new("UICorner")

controlsCorner.CornerRadius =
	UDim.new(
		0,
		14
	)

controlsCorner.Parent =
	controlsLabel

---------------------------------------------------------------------
-- NOTIFICATION
---------------------------------------------------------------------

local notificationCounter = 0

local function showNotification(
	text,
	duration
)

	notificationCounter += 1

	local id =
		notificationCounter

	local box =
		Instance.new("TextLabel")

	box.Name =
		"Notification_"
		.. id

	box.AnchorPoint =
		Vector2.new(
			0.5,
			0
		)

	box.Position =
		UDim2.new(
			0.5,
			0,
			0,
			-90
		)

	box.Size =
		UDim2.fromOffset(
			470,
			62
		)

	box.BackgroundColor3 =
		Color3.fromRGB(
			16,
			18,
			23
		)

	box.BackgroundTransparency =
		0.03

	box.Text =
		text

	box.TextColor3 =
		Color3.new(
			1,
			1,
			1
		)

	box.TextSize =
		17

	box.Font =
		Enum.Font.GothamBold

	box.Parent =
		gui

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			0,
			15
		)

	corner.Parent =
		box

	TweenService:Create(
		box,

		TweenInfo.new(
			0.35,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),

		{
			Position =
				UDim2.new(
					0.5,
					0,
					0,
					35
				)
		}

	):Play()

	task.delay(
		duration or 3,

		function()

			if not box.Parent then
				return
			end

			TweenService:Create(
				box,

				TweenInfo.new(
					0.3
				),

				{
					Position =
						UDim2.new(
							0.5,
							0,
							0,
							-90
						),

					TextTransparency =
						1,

					BackgroundTransparency =
						1
				}

			):Play()

			task.wait(
				0.35
			)

			if box then
				box:Destroy()
			end

		end
	)

end

---------------------------------------------------------------------
-- VEHICLE UTILITIES
---------------------------------------------------------------------

local function getPlayerSeat()

	local character =
		player.Character

	if not character then
		return nil
	end

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)

	if not humanoid then
		return nil
	end

	local seat =
		humanoid.SeatPart

	if seat
		and seat:IsA(
			"VehicleSeat"
		)
	then

		return seat

	end

	return nil

end

local function findBusFromSeat(
	seat
)

	if not seat then
		return nil
	end

	local current =
		seat

	while current
		and current ~= workspace
	do

		if current:IsA("Model")
			and current.Parent == busesFolder
		then

			return current

		end

		current =
			current.Parent

	end

	return nil

end

---------------------------------------------------------------------
-- ROUTE DISPLAY
---------------------------------------------------------------------

local function updateRoute()

	local route =
		CONFIG.Routes[
			routeIndex
		]

	if not route then
		return
	end

	routeLabel.Text =
		route.Name

	destinationLabel.Text =
		"Điểm đến: "
		.. route.Destination

	local nextStop =
		route.Stops[
			stopIndex
		]

	stopLabel.Text =
		"Trạm tiếp theo: "
		.. tostring(
			nextStop
			or "---"
		)

	if currentBus then

		local display =
			currentBus:FindFirstChild(
				"RouteDisplay",
				true
			)

		if display then

			local text =
				display:FindFirstChildWhichIsA(
					"TextLabel",
					true
				)

			if text then

				text.Text =
					route.Name
					.. "\n"
					.. route.Destination

			end

		end

	end

end

---------------------------------------------------------------------
-- DOOR
---------------------------------------------------------------------

local function getDoorHinge(
	name
)

	if not currentBus then
		return nil
	end

	local door =
		currentBus:FindFirstChild(
			name,
			true
		)

	if not door then
		return nil
	end

	return door:FindFirstChildWhichIsA(
		"HingeConstraint",
		true
	)

end

local function setDoor(
	name,
	open
)

	local hinge =
		getDoorHinge(
			name
		)

	if not hinge then

		warn(
			"[AxiomBus] Không tìm thấy HingeConstraint:",
			name
		)

		return

	end

	hinge.ActuatorType =
		Enum.ActuatorType.Servo

	hinge.ServoMaxTorque =
		CONFIG.Vehicle.DoorTorque

	hinge.AngularSpeed =
		CONFIG.Vehicle.DoorAngularSpeed

	hinge.TargetAngle =
		open
		and CONFIG.Vehicle.DoorOpenAngle
		or CONFIG.Vehicle.DoorClosedAngle

	if name ==
		"FrontDoor"
	then

		frontDoorOpen =
			open

	elseif name ==
		"RearDoor"
	then

		rearDoorOpen =
			open

	end

end

local function openDoors()

	if CONFIG.Stop.OpenFrontDoor then

		setDoor(
			"FrontDoor",
			true
		)

	end

	if CONFIG.Stop.OpenRearDoor then

		setDoor(
			"RearDoor",
			true
		)

	end

end

local function closeDoors()

	setDoor(
		"FrontDoor",
		false
	)

	setDoor(
		"RearDoor",
		false
	)

end

---------------------------------------------------------------------
-- PARK
---------------------------------------------------------------------

local function setPark(
	enabled
)

	if not currentSeat then
		return
	end

	parked =
		enabled

	if enabled then

		boosting =
			false

		cruiseEnabled =
			false

		cruiseSpeed =
			0

		currentSeat.MaxSpeed =
			0

		currentSeat.ThrottleFloat =
			0

		if currentSeat.AssemblyLinearVelocity.Magnitude < 5 then

			currentSeat.AssemblyLinearVelocity =
				Vector3.zero

			currentSeat.AssemblyAngularVelocity =
				Vector3.zero

		end

		gearLabel.Text =
			"P"

		gearLabel.TextColor3 =
			Color3.fromRGB(
				255,
				80,
				80
			)

	else

		currentSeat.MaxSpeed =
			CONFIG.Vehicle.NormalSpeed

		gearLabel.Text =
			"D"

		gearLabel.TextColor3 =
			Color3.fromRGB(
				80,
				255,
				145
			)

	end

end

---------------------------------------------------------------------
-- LIGHTS
---------------------------------------------------------------------

local function setLights(
	enabled
)

	if not currentBus then
		return
	end

	local folder =
		currentBus:FindFirstChild(
			"HeadLights",
			true
		)

	if not folder then
		return
	end

	lightsOn =
		enabled

	for _, object in ipairs(
		folder:GetDescendants()
	) do

		if object:IsA("Light") then

			object.Enabled =
				enabled

		end

	end

end

---------------------------------------------------------------------
-- HORN
---------------------------------------------------------------------

local function horn()

	if not currentBus then
		return
	end

	if os.clock() - lastHorn
		< CONFIG.Vehicle.HornCooldown
	then

		return

	end

	lastHorn =
		os.clock()

	local hornObject =
		currentBus:FindFirstChild(
			"Horn",
			true
		)

	if not hornObject then
		return
	end

	local sound =
		hornObject:FindFirstChildWhichIsA(
			"Sound",
			true
		)

	if sound then
		sound:Play()
	end

end

---------------------------------------------------------------------
-- CRUISE
---------------------------------------------------------------------

local function toggleCruise()

	if not currentSeat then
		return
	end

	if parked
		or frontDoorOpen
		or rearDoorOpen
		or stopSequenceRunning
	then

		return

	end

	if cruiseEnabled then

		cruiseEnabled =
			false

		cruiseSpeed =
			0

		showNotification(
			"CRUISE OFF",
			1.5
		)

		return

	end

	local speed =
		currentSeat.AssemblyLinearVelocity.Magnitude

	if speed <
		CONFIG.Vehicle.CruiseMinSpeed
	then

		showNotification(
			"TỐC ĐỘ QUÁ THẤP ĐỂ CRUISE",
			2
		)

		return

	end

	cruiseEnabled =
		true

	cruiseSpeed =
		math.clamp(
			speed,
			CONFIG.Vehicle.CruiseMinSpeed,
			CONFIG.Vehicle.CruiseMaxSpeed
		)

	showNotification(
		"CRUISE • "
		.. math.floor(
			cruiseSpeed
		),
		2
	)

end

---------------------------------------------------------------------
-- STOP MATCH
---------------------------------------------------------------------

local function getStopName(
	stop
)

	return stop:GetAttribute(
		"StopName"
	)
		or stop.Name

end

local function isCorrectStop(
	stop
)

	local route =
		CONFIG.Routes[
			routeIndex
		]

	if not route then
		return false
	end

	local expected =
		route.Stops[
			stopIndex
		]

	return expected ==
		getStopName(
			stop
		)

end

---------------------------------------------------------------------
-- AUTO STOP
---------------------------------------------------------------------

local function autoStop(
	stop
)

	if stopSequenceRunning
		or not currentSeat
		or not currentBus
	then

		return

	end

	if not isCorrectStop(
		stop
	)
	then

		return

	end

	local last =
		stopCooldowns[
			stop
		]

	if last
		and os.clock() - last
			< CONFIG.Stop.StopCooldown
	then

		return

	end

	local speed =
		currentSeat.AssemblyLinearVelocity.Magnitude

	if speed >
		CONFIG.Stop.MaxArrivalSpeed
	then

		return

	end

	stopCooldowns[
		stop
	] = os.clock()

	stopSequenceRunning =
		true

	autoParking =
		true

	boosting =
		false

	cruiseEnabled =
		false

	cruiseSpeed =
		0

	local stopName =
		getStopName(
			stop
		)

	showNotification(
		"SẮP ĐẾN • "
		.. stopName,
		3
	)

	statusLabel.Text =
		"AUTO PARK • ĐANG PHANH"

	-----------------------------------------------------------------
	-- AUTO BRAKE
	-----------------------------------------------------------------

	while
		currentSeat
		and currentSeat.Parent
		and currentSeat.AssemblyLinearVelocity.Magnitude
			> CONFIG.Stop.ParkSpeedThreshold
	do

		currentSeat.ThrottleFloat =
			0

		local velocity =
			currentSeat.AssemblyLinearVelocity

		local reduced =
			velocity
			* CONFIG.Stop.BrakeStrength

		if reduced.Magnitude <
			0.3
		then

			reduced =
				Vector3.zero

		end

		currentSeat.AssemblyLinearVelocity =
			reduced

		task.wait(
			0.07
		)

	end

	if not currentSeat then

		stopSequenceRunning =
			false

		autoParking =
			false

		return

	end

	-----------------------------------------------------------------
	-- P
	-----------------------------------------------------------------

	currentSeat.AssemblyLinearVelocity =
		Vector3.zero

	currentSeat.AssemblyAngularVelocity =
		Vector3.zero

	setPark(
		true
	)

	autoParking =
		false

	statusLabel.Text =
		"P • ĐÃ ĐỖ TẠI TRẠM"

	showNotification(
		"ĐÃ ĐẾN • "
		.. stopName,
		3
	)

	-----------------------------------------------------------------
	-- OPEN DOORS
	-----------------------------------------------------------------

	task.wait(
		0.5
	)

	openDoors()

	statusLabel.Text =
		"P • CỬA MỞ • ĐÓN/TRẢ KHÁCH"

	-----------------------------------------------------------------
	-- DWELL COUNTDOWN
	-----------------------------------------------------------------

	for seconds =
		CONFIG.Stop.DwellTime,
		1,
		-1
	do

		if not currentSeat then
			break
		end

		statusLabel.Text =
			"P • ĐÓN/TRẢ KHÁCH • "
			.. seconds
			.. "s"

		task.wait(
			1
		)

	end

	if not currentSeat then

		stopSequenceRunning =
			false

		return

	end

	-----------------------------------------------------------------
	-- CLOSE DOORS
	-----------------------------------------------------------------

	statusLabel.Text =
		"P • ĐANG ĐÓNG CỬA"

	showNotification(
		"ĐANG ĐÓNG CỬA",
		2
	)

	closeDoors()

	task.wait(
		CONFIG.Stop.DoorCloseDelay
	)

	-----------------------------------------------------------------
	-- NEXT STOP
	-----------------------------------------------------------------

	local route =
		CONFIG.Routes[
			routeIndex
		]

	if route then

		stopIndex += 1

		if stopIndex >
			#route.Stops
		then

			stopIndex =
				1

		end

	end

	updateRoute()

	-----------------------------------------------------------------
	-- RELEASE P
	-----------------------------------------------------------------

	if CONFIG.Stop.AutoReleasePark then

		setPark(
			false
		)

	end

	statusLabel.Text =
		"SẴN SÀNG KHỞI HÀNH"

	showNotification(
		"ĐÃ NHẢ P • CÓ THỂ KHỞI HÀNH",
		3
	)

	stopSequenceRunning =
		false

end

---------------------------------------------------------------------
-- STOP ZONES
---------------------------------------------------------------------

local configuredStops =
	{}

local function configureStop(
	stop
)

	if not stop:IsA(
		"BasePart"
	)
	then

		return

	end

	if configuredStops[
		stop
	]
	then

		return

	end

	configuredStops[
		stop
	] = true

	stop.CanTouch =
		true

	stop.Touched:Connect(
		function(hit)

			if not CONFIG.Stop.Enabled then
				return
			end

			if not currentBus
				or not currentSeat
			then

				return

			end

			if stopSequenceRunning then
				return
			end

			if not hit:IsDescendantOf(
				currentBus
			)
			then

				return

			end

			task.spawn(
				autoStop,
				stop
			)

		end
	)

end

for _, stop in ipairs(
	stopsFolder:GetChildren()
) do

	configureStop(
		stop
	)

end

stopsFolder.ChildAdded:Connect(
	configureStop
)

---------------------------------------------------------------------
-- ROUTE CHANGE
---------------------------------------------------------------------

local function nextRoute()

	if stopSequenceRunning then
		return
	end

	routeIndex += 1

	if routeIndex >
		#CONFIG.Routes
	then

		routeIndex =
			1

	end

	stopIndex =
		1

	updateRoute()

	showNotification(
		CONFIG.Routes[
			routeIndex
		].Name,
		2
	)

end

local function previousRoute()

	if stopSequenceRunning then
		return
	end

	routeIndex -= 1

	if routeIndex <
		1
	then

		routeIndex =
			#CONFIG.Routes

	end

	stopIndex =
		1

	updateRoute()

	showNotification(
		CONFIG.Routes[
			routeIndex
		].Name,
		2
	)

end

---------------------------------------------------------------------
-- MANUAL PARK
---------------------------------------------------------------------

local function togglePark()

	if stopSequenceRunning
		or not currentSeat
	then

		return

	end

	if parked then

		if frontDoorOpen
			or rearDoorOpen
		then

			showNotification(
				"ĐÓNG CỬA TRƯỚC KHI NHẢ P",
				2
			)

			return

		end

		setPark(
			false
		)

	else

		if currentSeat.AssemblyLinearVelocity.Magnitude >
			3
		then

			showNotification(
				"XE CHƯA DỪNG",
				2
			)

			return

		end

		setPark(
			true
		)

	end

end

---------------------------------------------------------------------
-- INPUT
---------------------------------------------------------------------

UserInputService.InputBegan:Connect(
	function(
		input,
		processed
	)

		if processed
			or not currentSeat
		then

			return

		end

		local key =
			input.KeyCode

		if key ==
			CONFIG.Controls.Boost
		then

			if not parked
				and not stopSequenceRunning
				and not frontDoorOpen
				and not rearDoorOpen
			then

				boosting =
					true

			end

		elseif key ==
			CONFIG.Controls.Cruise
		then

			toggleCruise()

		elseif key ==
			CONFIG.Controls.Park
		then

			togglePark()

		elseif key ==
			CONFIG.Controls.FrontDoor
		then

			if parked
				and not stopSequenceRunning
			then

				setDoor(
					"FrontDoor",
					not frontDoorOpen
				)

			end

		elseif key ==
			CONFIG.Controls.RearDoor
		then

			if parked
				and not stopSequenceRunning
			then

				setDoor(
					"RearDoor",
					not rearDoorOpen
				)

			end

		elseif key ==
			CONFIG.Controls.Lights
		then

			setLights(
				not lightsOn
			)

		elseif key ==
			CONFIG.Controls.Horn
		then

			horn()

		elseif key ==
			CONFIG.Controls.NextRoute
		then

			nextRoute()

		elseif key ==
			CONFIG.Controls.PreviousRoute
		then

			previousRoute()

		end

	end
)

UserInputService.InputEnded:Connect(
	function(input)

		if input.KeyCode ==
			CONFIG.Controls.Boost
		then

			boosting =
				false

		end

	end
)

---------------------------------------------------------------------
-- VEHICLE DETECTION
---------------------------------------------------------------------

local function enterBus(
	seat
)

	local bus =
		findBusFromSeat(
			seat
		)

	if not bus then
		return
	end

	currentSeat =
		seat

	currentBus =
		bus

	gui.Enabled =
		true

	routeIndex =
		1

	stopIndex =
		1

	parked =
		false

	autoParking =
		false

	stopSequenceRunning =
		false

	boosting =
		false

	cruiseEnabled =
		false

	cruiseSpeed =
		0

	frontDoorOpen =
		false

	rearDoorOpen =
		false

	currentSeat.MaxSpeed =
		CONFIG.Vehicle.NormalSpeed

	updateRoute()

	showNotification(
		"BUS SYSTEM ONLINE",
		2
	)

end

local function leaveBus()

	currentBus =
		nil

	currentSeat =
		nil

	boosting =
		false

	cruiseEnabled =
		false

	cruiseSpeed =
		0

	autoParking =
		false

	stopSequenceRunning =
		false

	gui.Enabled =
		false

end

---------------------------------------------------------------------
-- MAIN LOOP
---------------------------------------------------------------------

local lastSeat =
	nil

RunService.RenderStepped:Connect(
	function(deltaTime)

		local seat =
			getPlayerSeat()

		if seat ~= lastSeat then

			lastSeat =
				seat

			if seat then

				enterBus(
					seat
				)

			else

				leaveBus()

			end

		end

		if not currentSeat
			or not currentBus
		then

			return

		end

		-------------------------------------------------------------
		-- SPEED
		-------------------------------------------------------------

		local velocity =
			currentSeat.AssemblyLinearVelocity

		local speed =
			velocity.Magnitude

		-- Roblox stud/s → approximate km/h
		local kmh =
			math.floor(
				speed
				* 1.008
			)

		speedLabel.Text =
			tostring(
				kmh
			)

		-------------------------------------------------------------
		-- PARK LOCK
		-------------------------------------------------------------

		if parked then

			currentSeat.MaxSpeed =
				0

			if speed <
				3
			then

				currentSeat.AssemblyLinearVelocity =
					Vector3.zero

				currentSeat.AssemblyAngularVelocity =
					Vector3.zero

			end

		-------------------------------------------------------------
		-- DOOR INTERLOCK
		-------------------------------------------------------------

		elseif frontDoorOpen
			or rearDoorOpen
		then

			currentSeat.MaxSpeed =
				0

		-------------------------------------------------------------
		-- BOOST
		-------------------------------------------------------------

		elseif boosting then

			currentSeat.MaxSpeed =
				CONFIG.Vehicle.BoostSpeed

		else

			currentSeat.MaxSpeed =
				CONFIG.Vehicle.NormalSpeed

		end

		-------------------------------------------------------------
		-- CRUISE
		-------------------------------------------------------------

		if cruiseEnabled
			and not parked
			and not autoParking
			and not stopSequenceRunning
			and not frontDoorOpen
			and not rearDoorOpen
		then

			local target =
				cruiseSpeed

			if speed <
				target
			then

				local direction =
					currentSeat.CFrame.LookVector

				local difference =
					target
					- speed

				currentSeat.AssemblyLinearVelocity =
					velocity
					+ (
						direction
						* difference
						* deltaTime
						* 2
					)

			end

		end

		-------------------------------------------------------------
		-- STATUS
		-------------------------------------------------------------

		if not stopSequenceRunning then

			local states =
				{}

			if parked then

				table.insert(
					states,
					"PARK • P"
				)

			end

			if cruiseEnabled then

				table.insert(
					states,
					"CRUISE"
				)

			end

			if boosting then

				table.insert(
					states,
					"BOOST"
				)

			end

			if frontDoorOpen then

				table.insert(
					states,
					"CỬA TRƯỚC"
				)

			end

			if rearDoorOpen then

				table.insert(
					states,
					"CỬA SAU"
				)

			end

			if lightsOn then

				table.insert(
					states,
					"ĐÈN"
				)

			end

			if #states == 0 then

				statusLabel.Text =
					"XE SẴN SÀNG"

			else

				statusLabel.Text =
					table.concat(
						states,
						" • "
					)

			end

		end

	end
)

---------------------------------------------------------------------
-- CHARACTER RESET
---------------------------------------------------------------------

player.CharacterAdded:Connect(
	function()

		lastSeat =
			nil

		currentBus =
			nil

		currentSeat =
			nil

		gui.Enabled =
			false

	end
)

---------------------------------------------------------------------
-- INITIAL ROUTE
---------------------------------------------------------------------

updateRoute()

print(
	"[Axiom Bus System] Loaded successfully."
)
