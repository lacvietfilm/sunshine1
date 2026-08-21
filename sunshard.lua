---------------------------------------------------------------------
-- SUNSHARDS UI
---------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sunshardsRemote =
	ReplicatedStorage:WaitForChild(
		"AxiomSetSunshards"
	)

---------------------------------------------------------------------
-- OPEN BUTTON
---------------------------------------------------------------------

local sunButton = Instance.new("TextButton")

sunButton.Name = "SunshardsButton"

sunButton.Size =
	UDim2.new(
		1,
		-5,
		0,
		40
	)

sunButton.BackgroundColor3 =
	Color3.fromRGB(
		45,
		55,
		32
	)

sunButton.BorderSizePixel = 0

sunButton.Text =
	"☀ Sunshards"

sunButton.TextColor3 =
	Color3.fromRGB(
		255,
		230,
		120
	)

sunButton.Font =
	Enum.Font.GothamBold

sunButton.TextSize = 13

sunButton.Parent = list

local sunButtonCorner =
	Instance.new("UICorner")

sunButtonCorner.CornerRadius =
	UDim.new(0, 10)

sunButtonCorner.Parent =
	sunButton

---------------------------------------------------------------------
-- WINDOW
---------------------------------------------------------------------

local sunWindow =
	Instance.new("Frame")

sunWindow.Name =
	"SunshardsWindow"

sunWindow.AnchorPoint =
	Vector2.new(
		0.5,
		0.5
	)

sunWindow.Position =
	UDim2.fromScale(
		0.5,
		0.5
	)

sunWindow.Size =
	UDim2.fromOffset(
		360,
		270
	)

sunWindow.BackgroundColor3 =
	Color3.fromRGB(
		15,
		17,
		22
	)

sunWindow.BorderSizePixel = 0

sunWindow.Visible = false

sunWindow.ZIndex = 50

sunWindow.Parent = gui

local sunCorner =
	Instance.new("UICorner")

sunCorner.CornerRadius =
	UDim.new(0, 16)

sunCorner.Parent =
	sunWindow

local sunStroke =
	Instance.new("UIStroke")

sunStroke.Color =
	Color3.fromRGB(
		230,
		185,
		70
	)

sunStroke.Transparency = 0.35
sunStroke.Thickness = 1

sunStroke.Parent =
	sunWindow

---------------------------------------------------------------------
-- TITLE
---------------------------------------------------------------------

local sunTitle =
	Instance.new("TextLabel")

sunTitle.Position =
	UDim2.fromOffset(
		20,
		18
	)

sunTitle.Size =
	UDim2.new(
		1,
		-75,
		0,
		30
	)

sunTitle.BackgroundTransparency = 1

sunTitle.Text =
	"SUNSHARDS"

sunTitle.TextColor3 =
	Color3.fromRGB(
		255,
		225,
		120
	)

sunTitle.Font =
	Enum.Font.GothamBold

sunTitle.TextSize = 20

sunTitle.TextXAlignment =
	Enum.TextXAlignment.Left

sunTitle.ZIndex = 51

sunTitle.Parent =
	sunWindow

---------------------------------------------------------------------
-- SUBTITLE
---------------------------------------------------------------------

local sunSubtitle =
	Instance.new("TextLabel")

sunSubtitle.Position =
	UDim2.fromOffset(
		20,
		50
	)

sunSubtitle.Size =
	UDim2.new(
		1,
		-40,
		0,
		30
	)

sunSubtitle.BackgroundTransparency = 1

sunSubtitle.Text =
	"Nhập số Sunshards muốn nhận"

sunSubtitle.TextColor3 =
	Color3.fromRGB(
		145,
		150,
		165
	)

sunSubtitle.Font =
	Enum.Font.GothamMedium

sunSubtitle.TextSize = 12

sunSubtitle.TextXAlignment =
	Enum.TextXAlignment.Left

sunSubtitle.ZIndex = 51

sunSubtitle.Parent =
	sunWindow

---------------------------------------------------------------------
-- CLOSE
---------------------------------------------------------------------

local sunClose =
	Instance.new("TextButton")

sunClose.Position =
	UDim2.new(
		1,
		-48,
		0,
		14
	)

sunClose.Size =
	UDim2.fromOffset(
		34,
		34
	)

sunClose.BackgroundColor3 =
	Color3.fromRGB(
		35,
		38,
		48
	)

sunClose.BorderSizePixel = 0

sunClose.Text = "×"

sunClose.TextColor3 =
	Color3.new(
		1,
		1,
		1
	)

sunClose.Font =
	Enum.Font.GothamBold

sunClose.TextSize = 20

sunClose.ZIndex = 52

sunClose.Parent =
	sunWindow

local sunCloseCorner =
	Instance.new("UICorner")

sunCloseCorner.CornerRadius =
	UDim.new(0, 9)

sunCloseCorner.Parent =
	sunClose

---------------------------------------------------------------------
-- INPUT
---------------------------------------------------------------------

local sunInput =
	Instance.new("TextBox")

sunInput.Position =
	UDim2.fromOffset(
		20,
		95
	)

sunInput.Size =
	UDim2.new(
		1,
		-40,
		0,
		52
	)

sunInput.BackgroundColor3 =
	Color3.fromRGB(
		24,
		27,
		35
	)

sunInput.BorderSizePixel = 0

sunInput.Text = ""

sunInput.PlaceholderText =
	"Ví dụ: 999999"

sunInput.ClearTextOnFocus =
	false

sunInput.TextColor3 =
	Color3.fromRGB(
		255,
		235,
		160
	)

sunInput.PlaceholderColor3 =
	Color3.fromRGB(
		95,
		100,
		115
	)

sunInput.Font =
	Enum.Font.GothamBold

sunInput.TextSize = 18

sunInput.ZIndex = 51

sunInput.Parent =
	sunWindow

local inputCorner =
	Instance.new("UICorner")

inputCorner.CornerRadius =
	UDim.new(0, 10)

inputCorner.Parent =
	sunInput

---------------------------------------------------------------------
-- ONLY NUMBERS
---------------------------------------------------------------------

sunInput:GetPropertyChangedSignal("Text"):Connect(function()
	local filtered =
		sunInput.Text:gsub(
			"[^0-9]",
			""
		)

	if sunInput.Text ~= filtered then
		sunInput.Text = filtered
	end
end)

---------------------------------------------------------------------
-- QUICK VALUES
---------------------------------------------------------------------

local quickContainer =
	Instance.new("Frame")

quickContainer.Position =
	UDim2.fromOffset(
		20,
		158
	)

quickContainer.Size =
	UDim2.new(
		1,
		-40,
		0,
		34
	)

quickContainer.BackgroundTransparency = 1

quickContainer.ZIndex = 51

quickContainer.Parent =
	sunWindow

local quickLayout =
	Instance.new("UIListLayout")

quickLayout.FillDirection =
	Enum.FillDirection.Horizontal

quickLayout.HorizontalAlignment =
	Enum.HorizontalAlignment.Center

quickLayout.Padding =
	UDim.new(
		0,
		7
	)

quickLayout.Parent =
	quickContainer

local function createQuickAmount(amount)
	local button =
		Instance.new("TextButton")

	button.Size =
		UDim2.new(
			0.25,
			-6,
			1,
			0
		)

	button.BackgroundColor3 =
		Color3.fromRGB(
			31,
			35,
			44
		)

	button.BorderSizePixel = 0

	button.Text =
		tostring(amount)

	button.TextColor3 =
		Color3.fromRGB(
			210,
			215,
			225
		)

	button.Font =
		Enum.Font.GothamMedium

	button.TextSize = 11

	button.ZIndex = 52

	button.Parent =
		quickContainer

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(0, 8)

	corner.Parent =
		button

	button.MouseButton1Click:Connect(function()
		sunInput.Text =
			tostring(amount)
	end)
end

createQuickAmount(10000)
createQuickAmount(100000)
createQuickAmount(500000)
createQuickAmount(999999)

---------------------------------------------------------------------
-- APPLY BUTTON
---------------------------------------------------------------------

local applySun =
	Instance.new("TextButton")

applySun.Position =
	UDim2.fromOffset(
		20,
		207
	)

applySun.Size =
	UDim2.new(
		1,
		-40,
		0,
		43
	)

applySun.BackgroundColor3 =
	Color3.fromRGB(
		190,
		145,
		40
	)

applySun.BorderSizePixel = 0

applySun.Text =
	"NHẬN SUNSHARDS"

applySun.TextColor3 =
	Color3.fromRGB(
		15,
		15,
		18
	)

applySun.Font =
	Enum.Font.GothamBold

applySun.TextSize = 13

applySun.ZIndex = 52

applySun.Parent =
	sunWindow

local applyCorner =
	Instance.new("UICorner")

applyCorner.CornerRadius =
	UDim.new(0, 10)

applyCorner.Parent =
	applySun

---------------------------------------------------------------------
-- OPEN / CLOSE
---------------------------------------------------------------------

sunButton.MouseButton1Click:Connect(function()
	sunWindow.Visible = true
end)

sunClose.MouseButton1Click:Connect(function()
	sunWindow.Visible = false
end)

---------------------------------------------------------------------
-- APPLY
---------------------------------------------------------------------

local sending = false

local function requestSunshards()
	if sending then
		return
	end

	local amount =
		tonumber(
			sunInput.Text
		)

	if not amount then
		sunInput.Text = ""
		sunInput.PlaceholderText =
			"NHẬP SỐ HỢP LỆ"

		return
	end

	amount =
		math.clamp(
			math.floor(amount),
			0,
			999999
		)

	sending = true

	applySun.Text =
		"ĐANG ÁP DỤNG..."

	sunshardsRemote:FireServer(
		amount
	)

	task.wait(0.3)

	applySun.Text =
		"✓ ĐÃ NHẬN "
		.. tostring(amount)

	task.wait(0.8)

	applySun.Text =
		"NHẬN SUNSHARDS"

	sending = false
end

applySun.MouseButton1Click:Connect(
	requestSunshards
)

sunInput.FocusLost:Connect(function(
	enterPressed
)
	if enterPressed then
		requestSunshards()
	end
end)
