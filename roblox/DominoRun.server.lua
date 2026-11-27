-- Domino Run: tempel sebagai Script di ServerScriptService, lalu tekan Play dan jalan lurus ke depan.
-- Tiap baris domino roboh berurutan begitu karakter melewati awal barisnya.
--
-- Pakai model sendiri: buat Folder bernama "Domino" di ServerStorage, isi dengan Model/Part
-- yang namanya sama dengan `name` di ROWS. Model harus berdiri tegak dan menghadap arah jalan
-- (putar di Studio kalau miring). Baris tanpa model memakai papan warna polos.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

---------------------------------------------------------------- PENGATURAN
local TITLE = "Domino Warna"
local ROWS = {
	{ name = "Merah", count = 40, color = Color3.fromRGB(230, 60, 60) },
	{ name = "Biru", count = 40, color = Color3.fromRGB(50, 110, 240) },
	{ name = "Kuning", count = 40, color = Color3.fromRGB(250, 205, 50) },
	{ name = "Ungu", count = 40, color = Color3.fromRGB(150, 80, 220) },
	{ name = "Oranye", count = 40, color = Color3.fromRGB(245, 135, 40) },
	{ name = "Putih", count = 40, color = Color3.fromRGB(240, 240, 240) },
}
local LANE_GAP = 8 -- jarak antar baris (kiri/kanan jalur tengah)
local ROW_STAGGER = 25 -- tiap baris mulai sekian stud lebih jauh dari baris sebelumnya
local FALL_TIME = 0.35 -- detik satu domino roboh
local FALL_DELAY = 0.06 -- jeda antar domino dalam satu baris
local FALL_ANGLE = math.rad(72)
local SOUND_ID = "" -- contoh "rbxassetid://123456"; kosong = tanpa suara
----------------------------------------------------------------------------

local GROUND_TOP = 0.5
local FIRST_Z = -20

local world = Instance.new("Folder")
world.Name = "DominoRun"
world.Parent = workspace

local clickSound
if SOUND_ID ~= "" then
	clickSound = Instance.new("Sound")
	clickSound.SoundId = SOUND_ID
	clickSound.Parent = workspace
end

local function makePrototype(row)
	local model = Instance.new("Model")
	model.Name = row.name
	local folder = ServerStorage:FindFirstChild("Domino")
	local template = folder and folder:FindFirstChild(row.name)
	if template then
		template:Clone().Parent = model
	else
		local slab = Instance.new("Part")
		slab.Size = Vector3.new(3, 6, 0.8)
		slab.Color = row.color
		slab.Material = Enum.Material.SmoothPlastic
		slab.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy() -- model gratisan sering membawa script; jangan dijalankan
		end
	end
	return model
end

local farthestZ = FIRST_Z
for i, row in ROWS do
	local proto = makePrototype(row)
	local boxCFrame, size = proto:GetBoundingBox()
	-- posisi pivot relatif terhadap titik tengah alas, supaya domino berputar di kakinya
	row.rel = (boxCFrame * CFrame.new(0, -size.Y / 2, 0)):ToObjectSpace(proto:GetPivot())

	local spacing = row.spacing or math.max(size.Z * 1.5, size.Y * 0.5)
	local side = if i % 2 == 1 then -1 else 1
	local x = side * LANE_GAP * math.ceil(i / 2)
	row.startZ = FIRST_Z - (i - 1) * ROW_STAGGER
	row.dominoes = {}
	for n = 1, row.count do
		local base = CFrame.new(x, GROUND_TOP, row.startZ - (n - 1) * spacing)
		local model = proto:Clone()
		model:PivotTo(base * row.rel)
		model.Parent = world
		row.dominoes[n] = { model = model, base = base }
	end
	farthestZ = math.min(farthestZ, row.startZ - row.count * spacing)
	proto:Destroy()
end

local length = 40 - farthestZ
local ground = Instance.new("Part")
ground.Name = "Lantai"
ground.Anchored = true
ground.Size = Vector3.new(LANE_GAP * (#ROWS + 4), 1, length)
ground.Position = Vector3.new(0, GROUND_TOP - 0.5, 20 - length / 2)
ground.Color = Color3.fromRGB(75, 180, 60)
ground.Parent = world

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, GROUND_TOP, 5)
spawn.Transparency = 1
spawn.Parent = world

-- Judul + angka hitungan di atas layar
local fallen = 0
local countLabels = {}

local function makeLabel(text, y, height, parent)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, height, 0)
	label.Position = UDim2.new(0, 0, y, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

local function addGui(player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DominoGui"
	gui.ResetOnSpawn = false
	makeLabel(TITLE, 0.04, 0.06, gui)
	local count = makeLabel(tostring(fallen), 0.1, 0.09, gui)
	count.TextColor3 = Color3.fromRGB(255, 220, 60)
	countLabels[player] = count
	gui.Parent = player:WaitForChild("PlayerGui")
end

Players.PlayerAdded:Connect(addGui)
for _, player in Players:GetPlayers() do
	task.spawn(addGui, player)
end
Players.PlayerRemoving:Connect(function(player)
	countLabels[player] = nil
end)

local function fall(row, domino)
	local start = os.clock()
	while true do
		local t = math.min((os.clock() - start) / FALL_TIME, 1)
		domino.model:PivotTo(domino.base * CFrame.Angles(-FALL_ANGLE * t * t, 0, 0) * row.rel)
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

local function topple(row)
	for _, domino in row.dominoes do
		task.spawn(fall, row, domino)
		fallen += 1
		for _, label in countLabels do
			label.Text = tostring(fallen)
		end
		if clickSound then
			clickSound.PlaybackSpeed = 0.9 + math.random() * 0.2
			clickSound:Play()
		end
		task.wait(FALL_DELAY)
	end
end

RunService.Heartbeat:Connect(function()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, row in ROWS do
				if not row.triggered and root.Position.Z <= row.startZ + 2 then
					row.triggered = true
					task.spawn(topple, row)
				end
			end
		end
	end
end)
