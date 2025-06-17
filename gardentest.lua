-- Anime Saga Script

-- Hệ thống kiểm soát logs
local LogSystem = {
    Enabled = true, -- Mặc định bật logs
    WarningsEnabled = true -- Mặc định bật cả warnings
}

-- Ghi đè hàm print để kiểm soát logs
local originalPrint = print
print = function(...)
    if LogSystem.Enabled then
        originalPrint(...)
    end
end

-- Ghi đè hàm warn để kiểm soát warnings
local originalWarn = warn
warn = function(...)
    if LogSystem.WarningsEnabled then
        originalWarn(...)
    end
end

-- Tải thư viện Fluent
local success, err = pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)

if not success then
    warn("Lỗi khi tải thư viện Fluent: " .. tostring(err))
    -- Thử tải từ URL dự phòng
    pcall(function()
        Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Fluent.lua"))()
        SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
        InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
    end)
end

if not Fluent then
    error("Không thể tải thư viện Fluent. Vui lòng kiểm tra kết nối internet hoặc executor.")
    return
end

-- Utility function để kiểm tra và lấy service/object một cách an toàn
local function safeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    return success and service or nil
end

-- Utility function để kiểm tra và lấy child một cách an toàn
local function safeGetChild(parent, childName, waitTime)
    if not parent then return nil end
    
    local child = parent:FindFirstChild(childName)
    
    -- Chỉ sử dụng WaitForChild nếu thực sự cần thiết
    if not child and waitTime and waitTime > 0 then
        local success, result = pcall(function()
            return parent:WaitForChild(childName, waitTime)
        end)
        if success then child = result end
    end
    
    return child
end

-- Utility function để lấy đường dẫn đầy đủ một cách an toàn
local function safeGetPath(startPoint, path, waitTime)
    if not startPoint then return nil end
    waitTime = waitTime or 0.5 -- Giảm thời gian chờ mặc định xuống 0.5 giây
    
    local current = startPoint
    for _, name in ipairs(path) do
        if not current then return nil end
        current = safeGetChild(current, name, waitTime)
    end
    
    return current
end

-- Hệ thống lưu trữ cấu hình
local ConfigSystem = {}
ConfigSystem.FileName = "GAGConfig_" .. game:GetService("Players").LocalPlayer.Name .. ".json"

ConfigSystem.DefaultConfig = {
    -- Các cài đặt mặc định chung
    UITheme = "Amethyst",
    
    -- Cài đặt log
    LogsEnabled = true,
    WarningsEnabled = true,
    -- Cài đặt cho Auto Buy Seed
    SeedAutoBuyEnabled = false,
    SeedSelectedList   = {},
  -- Cài đặt cho Auto Craft Seed
    AutoCraftSeedEnabled = false,
    AutoCraftSeedItem = "Suncoil",
    -- Cài đặt cho Auto Buy Gear
    GearAutoBuyEnabled = false,
    GearSelectedList = {}, -- Mảng các gear đã chọn

    -- Cài đặt cho Auto Buy Egg
    EggAutoBuyEnabled = false,
    EggSelectedList = {}, -- Mảng các egg đã chọn để auto mua
    
    -- Các cài đặt khác sẽ được thêm vào sau
}

ConfigSystem.CurrentConfig = {}

-- Cache cho ConfigSystem để giảm lượng I/O
ConfigSystem.LastSaveTime = 0
ConfigSystem.SaveCooldown = 2 -- 2 giây giữa các lần lưu
ConfigSystem.PendingSave = false

-- Hàm để lưu cấu hình
ConfigSystem.SaveConfig = function()
    -- Kiểm tra thời gian từ lần lưu cuối
    local currentTime = os.time()
    if currentTime - ConfigSystem.LastSaveTime < ConfigSystem.SaveCooldown then
        -- Đã lưu gần đây, đánh dấu để lưu sau
        ConfigSystem.PendingSave = true
        return
    end
    
    local success, err = pcall(function()
        local HttpService = game:GetService("HttpService")
        writefile(ConfigSystem.FileName, HttpService:JSONEncode(ConfigSystem.CurrentConfig))
    end)
    
    if success then
        ConfigSystem.LastSaveTime = currentTime
        ConfigSystem.PendingSave = false
    else
        warn("Lưu cấu hình thất bại:", err)
    end
end

-- Hàm để tải cấu hình
ConfigSystem.LoadConfig = function()
    local success, content = pcall(function()
        if isfile(ConfigSystem.FileName) then
            return readfile(ConfigSystem.FileName)
        end
        return nil
    end)
    
    if success and content then
        local success2, data = pcall(function()
            local HttpService = game:GetService("HttpService")
            return HttpService:JSONDecode(content)
        end)
        
        if success2 and data then
            -- Merge with default config to ensure all settings exist
            for key, value in pairs(ConfigSystem.DefaultConfig) do
                if data[key] == nil then
                    data[key] = value
                end
            end
            
        ConfigSystem.CurrentConfig = data
        
        -- Cập nhật cài đặt log
        if data.LogsEnabled ~= nil then
            LogSystem.Enabled = data.LogsEnabled
        end
        
        if data.WarningsEnabled ~= nil then
            LogSystem.WarningsEnabled = data.WarningsEnabled
        end
        
        return true
        end
    end
    
    -- Nếu tải thất bại, sử dụng cấu hình mặc định
        ConfigSystem.CurrentConfig = table.clone(ConfigSystem.DefaultConfig)
        ConfigSystem.SaveConfig()
        return false
    end

-- Thiết lập timer để lưu định kỳ nếu có thay đổi chưa lưu
spawn(function()
    while wait(5) do
        if ConfigSystem.PendingSave then
            ConfigSystem.SaveConfig()
        end
    end
end)

-- Tải cấu hình khi khởi động
ConfigSystem.LoadConfig()

-- Thông tin người chơi
local playerName = game:GetService("Players").LocalPlayer.Name

-- Tạo Window
local Window = Fluent:CreateWindow({
    Title = "HT Hub | Grow a Garden",
    SubTitle = "",
    TabWidth = 140,
    Size = UDim2.fromOffset(450, 350),
    Acrylic = true,
    Theme = ConfigSystem.CurrentConfig.UITheme or "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Tạo tab Info
local InfoTab = Window:AddTab({
    Title = "Info",
    Icon = "rbxassetid://7733964719"
})

-- Thêm tab Play
local PlayTab = Window:AddTab({
    Title = "Play",
    Icon = "rbxassetid://7734053495" -- Bạn có thể thay icon khác nếu muốn
})

local EventTab = Window:AddTab({
    Title = "Event",
    Icon = "rbxassetid://12290495271" -- Bạn có thể đổi sang icon phù hợp khác
})

-- Thêm tab Shop
local ShopTab = Window:AddTab({
    Title = "2Shop",
    Icon = "rbxassetid://7734068321" -- Bạn có thể đổi icon nếu muốn
})


-- Thêm hỗ trợ Logo khi minimize
repeat task.wait(0.25) until game:IsLoaded()
getgenv().Image = "rbxassetid://90319448802378" -- ID tài nguyên hình ảnh logo
getgenv().ToggleUI = "LeftControl" -- Phím để bật/tắt giao diện

-- Tạo logo để mở lại UI khi đã minimize
task.spawn(function()
    local success, errorMsg = pcall(function()
        if not getgenv().LoadedMobileUI == true then 
            getgenv().LoadedMobileUI = true
            local OpenUI = Instance.new("ScreenGui")
            local ImageButton = Instance.new("ImageButton")
            local UICorner = Instance.new("UICorner")
            
            -- Kiểm tra môi trường
            if syn and syn.protect_gui then
                syn.protect_gui(OpenUI)
                OpenUI.Parent = game:GetService("CoreGui")
            elseif gethui then
                OpenUI.Parent = gethui()
            else
                OpenUI.Parent = game:GetService("CoreGui")
            end
            
            OpenUI.Name = "OpenUI"
            OpenUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            
            ImageButton.Parent = OpenUI
            ImageButton.BackgroundColor3 = Color3.fromRGB(105,105,105)
            ImageButton.BackgroundTransparency = 0.8
            ImageButton.Position = UDim2.new(0.9,0,0.1,0)
            ImageButton.Size = UDim2.new(0,50,0,50)
            ImageButton.Image = getgenv().Image
            ImageButton.Draggable = true
            ImageButton.Transparency = 0.2
            
            UICorner.CornerRadius = UDim.new(0,200)
            UICorner.Parent = ImageButton
            
            -- Khi click vào logo sẽ mở lại UI
            ImageButton.MouseButton1Click:Connect(function()
                game:GetService("VirtualInputManager"):SendKeyEvent(true,getgenv().ToggleUI,false,game)
            end)
        end
    end)
    
    if not success then
        warn("Lỗi khi tạo nút Logo UI: " .. tostring(errorMsg))
    end
end)

-- Tự động chọn tab Info khi khởi động
Window:SelectTab(1) -- Chọn tab đầu tiên (Info)

-- Thêm section thông tin trong tab Info
local InfoSection = InfoTab:AddSection("Thông tin")

InfoSection:AddParagraph({
    Title = "Grow a Garden",
    Content = "Phiên bản: 1.0 Beta\nTrạng thái: Hoạt động"
})

InfoSection:AddParagraph({
    Title = "Người phát triển",
    Content = "Script được phát triển bởi Dương Tuấn và ghjiukliop"
})

-- Thêm section thiết lập trong tab Settings
local SettingsTab = Window:AddTab({
    Title = "Settings",
    Icon = "rbxassetid://6031280882"
})

local SettingsSection = SettingsTab:AddSection("Thiết lập")

-- Dropdown chọn theme
SettingsSection:AddDropdown("ThemeDropdown", {
    Title = "Chọn Theme",
    Values = {"Dark", "Light", "Darker", "Aqua", "Amethyst"},
    Multi = false,
    Default = ConfigSystem.CurrentConfig.UITheme or "Dark",
    Callback = function(Value)
        ConfigSystem.CurrentConfig.UITheme = Value
        ConfigSystem.SaveConfig()
        print("Đã chọn theme: " .. Value)
    end
})

-- Auto Save Config
local function AutoSaveConfig()
    spawn(function()
        while wait(5) do -- Lưu mỗi 5 giây
            pcall(function()
                ConfigSystem.SaveConfig()
            end)
        end
    end)
end

-- Thêm event listener để lưu ngay khi thay đổi giá trị
local function setupSaveEvents()
    for _, tab in pairs({InfoTab, SettingsTab}) do
        if tab and tab._components then
            for _, element in pairs(tab._components) do
                if element and element.OnChanged then
                    element.OnChanged:Connect(function()
                        pcall(function()
                            ConfigSystem.SaveConfig()
                        end)
                    end)
                end
            end
        end
    end
end



-- ...existing code...
--// Dịch vụ
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

--// Biến chung
local allPlantNames = {
    "Apple", "Avocado", "Bamboo", "Banana", "Beanstalk", "Blood Banana", "Blueberry", "Cacao", "Cactus", "Candy Blossom",
    "Celestiberry", "Cherry Blossom", "Cherry OLD", "Coconut", "Corn", "Cranberry", "Crimson Vine", "Cursed Fruit",
    "Dragon Fruit", "Durian", "Easter Egg", "Eggplant", "Ember Lily", "Foxglove", "Glowshroom", "Grape", "Hive Fruit",
    "Lemon", "Lilac", "Lotus", "Mango", "Mint", "Moon Blossom", "Moon Mango", "Moon Melon", "Moonflower", "Moonglow",
    "Nectarine", "Papaya", "Passionfruit", "Peach", "Pear", "Pepper", "Pineapple", "Pink Lily", "Purple Cabbage",
    "Purple Dahlia", "Raspberry", "Rose", "Soul Fruit", "Starfruit", "Strawberry", "Succulent", "Sunflower",
    "Tomato", "Venus Fly Trap"
}

local selectedPlantsToFarm = {}
local autoFarmEnabled = false   

--// Tìm farm của người chơi
local farms = workspace:FindFirstChild("Farm")
local playerFarm

if farms then
    for _, farm in ipairs(farms:GetChildren()) do
        local owner = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Data") and farm.Important.Data:FindFirstChild("Owner")
        if owner and owner.Value == player.Name then
            playerFarm = farm
            break
        end
    end
end

if not playerFarm then
    warn("❌ Không tìm thấy farm của bạn.")
    return
end

local plantsFolder = playerFarm.Important:FindFirstChild("Plants_Physical")
if not plantsFolder then
    warn("❌ Không tìm thấy thư mục cây trồng trong farm.")
    return
end

--// Dropdown Fluent UI
PlayTab:AddSection("Auto Farm"):AddDropdown("AutoFruitDropdown", {
    Title = "1 Chọn cây muốn auto thu thập trái",
    Values = allPlantNames,
    Multi = true,
    Default = {},
    Callback = function(selected)
        -- Reset danh sách đã chọn
        selectedPlantsToFarm = {}
        for plantName, isSelected in pairs(selected) do
            if isSelected then
                table.insert(selectedPlantsToFarm, plantName)
            end
        end

        if #selectedPlantsToFarm == 0 then
            print("🔴 Bạn chưa chọn cây nào.")
        else
            print("✅ Cây được chọn để auto:", table.concat(selectedPlantsToFarm, ", "))
        end
    end
})

--// Toggle button bật/tắt auto farm
PlayTab:AddToggle("AutoFruitToggle", {
    Title = "🚜 Auto Farm Fruit",
    Default = false,
    Callback = function(value)
        autoFarmEnabled = value
        print(value and "✅ Auto Fruit đã BẬT" or "⛔ Auto Fruit đã TẮT")
    end
})


--// Hàm thu thập trái
local function collectFruit(fruit)
    if not fruit:IsA("Model") then return end

    local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        fireproximityprompt(prompt)
        return
    end

    local click = fruit:FindFirstChildWhichIsA("ClickDetector", true)
    if click then
        fireclickdetector(click)
        return
    end
end

--// Vòng lặp Auto Farm Fruit
-- Vòng lặp Auto Farm Fruit
task.spawn(function()
    while true do
        if autoFarmEnabled and #selectedPlantsToFarm > 0 then
            for _, plant in ipairs(plantsFolder:GetChildren()) do
                if table.find(selectedPlantsToFarm, plant.Name) then
                    local fruits = plant:FindFirstChild("Fruits")

                    if fruits then
                        -- Nếu cây có thư mục "Fruits", tiến hành thu thập trái
                        for _, fruit in ipairs(fruits:GetChildren()) do
                            collectFruit(fruit)
                            task.wait(0.05)
                        end
                    else
                        -- Nếu cây không có "Fruits", thu thập chính cây đó
                        warn("❌ Cây '" .. plant.Name .. "' không có trái! Đang thu thập chính cây...")

                        -- Kích hoạt ProximityPrompt hoặc ClickDetector trên cây
                        local prompt = plant:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt then
                            fireproximityprompt(prompt)
                        else
                            local click = plant:FindFirstChildWhichIsA("ClickDetector", true)
                            if click then
                                fireclickdetector(click)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)
-- PLANTING FRUIT 
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

local plantEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Plant_RE")

assert(PlayTab, "[AutoPlant] PlayTab chưa được tạo!")
local PlantSection = PlayTab:AddSection("🌱2 Auto Plant Seed")

local function vKey(v3)
    return tostring(math.floor(v3.X)) .. "," .. tostring(math.floor(v3.Y)) .. "," .. tostring(math.floor(v3.Z))
end

local function iterateRegion(region, spacing)
    local center = region.Position
    local size = region.Size / 2

    local topLeft = center + Vector3.new(-size.X, 0, -size.Z)
    local topRight = center + Vector3.new(size.X, 0, -size.Z)
    local bottomRight = center + Vector3.new(size.X, 0, size.Z)

    local z = topLeft.Z
    while z <= bottomRight.Z do
        local x = topLeft.X
        while x <= topRight.X do
            coroutine.yield(Vector3.new(x, center.Y, z))
            x = x + spacing
        end
        z = z + spacing
    end
end

local function getMyFarm()
    local farm = workspace:FindFirstChild("Farm")
    if not farm then return nil end

    for _, farmInstance in ipairs(farm:GetChildren()) do
        local owner = farmInstance:FindFirstChild("Important") and farmInstance.Important:FindFirstChild("Data") and farmInstance.Important.Data:FindFirstChild("Owner")
        if owner and owner.Value == player.Name then
            local regions = farmInstance.Important:FindFirstChild("Plant_Locations")
            local plantsFolder = farmInstance.Important:FindFirstChild("Plants_Physical")
            return farmInstance, regions, plantsFolder
        end
    end
    return nil
end

local function buildOccupied(plantsFolder)
    local occupied = {}
    if not plantsFolder then return occupied end

    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local part = plant:IsA("BasePart") and plant or plant:FindFirstChildWhichIsA("BasePart")
        if part then
            occupied[vKey(part.Position)] = true
        end
    end
    return occupied
end

-- Danh sách seed có thể chọn
local ALL_SEEDS = {
    "Apple", "Avocado", "Bamboo", "Banana", "Beanstalk", "Blood Banana", "Blue Lollipop",
    "Blueberry", "Cacao", "Cactus", "Candy Blossom", "Candy Sunflower", "Carrot", "Celestiberry",
    "Cherry Blossom", "Chocolate Carrot", "Coconut", "Corn", "Cranberry", "Crimson Vine", "Crocus",
    "Cursed Fruit", "Daffodil", "Dandelion", "Dragon Fruit", "Durian", "Easter Egg", "Eggplant",
    "Ember Lily", "Foxglove", "Glowshroom", "Grape", "Hive Fruit", "Lemon", "Lilac", "Lotus", "Mango",
    "Mega Mushroom", "Mint", "Moon Blossom", "Moon Mango", "Moon Melon", "Moonflower", "Moonglow",
    "Mushroom", "Nectarine", "Nightshade", "Orange Tulip", "Papaya", "Passionfruit", "Peach", "Pear",
    "Pepper", "Pineapple", "Pink Lily", "Pink Tulip", "Pumpkin", "Purple Cabbage", "Purple Dahlia",
    "Raspberry", "Red Lollipop", "Rose", "Soul Fruit", "Starfruit", "Strawberry", "Succulent",
    "Sunflower", "Super", "Tomato", "Venus Fly Trap", "Watermelon"
}

local selectedSeedsToPlant = ConfigSystem.CurrentConfig.SelectedSeeds or {}
local autoPlantEnabled = ConfigSystem.CurrentConfig.AutoPlantEnabled or false

-- Dropdown chọn seed
local seedDropdown = PlantSection:AddDropdown("SelectSeedsToPlant", {
    Title = "Chọn các loại Seed để Auto Plant",
    Values = ALL_SEEDS,
    Multi = true,
    Default = (function()
        local dict = {}
        for _, v in ipairs(selectedSeedsToPlant) do dict[v] = true end
        return dict
    end)()
})

seedDropdown:OnChanged(function(dictValues)
    selectedSeedsToPlant = {}
    for seedName, picked in pairs(dictValues) do
        if picked then
            table.insert(selectedSeedsToPlant, seedName)
        end
    end
    ConfigSystem.CurrentConfig.SelectedSeeds = selectedSeedsToPlant
    ConfigSystem.SaveConfig()
end)

-- Toggle
local toggle = PlantSection:AddToggle("ToggleAutoPlanting", {
    Title = "Bật Auto Planting",
    Default = autoPlantEnabled
})

toggle:OnChanged(function(value)
    autoPlantEnabled = value
    ConfigSystem.CurrentConfig.AutoPlantEnabled = value
    ConfigSystem.SaveConfig()
    print(value and "🟢 Auto Planting đã BẬT" or "🔴 Auto Planting đã TẮT")
end)

-- Vòng lặp Auto Plant
task.spawn(function()
    while true do
        if autoPlantEnabled and selectedSeedsToPlant and #selectedSeedsToPlant > 0 then
            local myFarm, plantRegions, plantsFolder = getMyFarm()
            if myFarm and plantRegions then
                local occupied = buildOccupied(plantsFolder)

                for _, seedName in ipairs(selectedSeedsToPlant) do
                    if not autoPlantEnabled then break end

                    -- Tìm Tool
                    local tool = nil
                    for _, t in ipairs(player.Backpack:GetChildren()) do
                        if t:IsA("Tool") and t:GetAttribute("Seed") == seedName then
                            tool = t
                            break
                        end
                    end

                    if tool then
                        player.Character.Humanoid:EquipTool(tool)
                        task.wait(0.15)

                        local qty = tool:GetAttribute("Quantity") or math.huge

                        for _, region in ipairs(plantRegions:GetChildren()) do
                            if not autoPlantEnabled or qty <= 0 then break end
                            if region:IsA("BasePart") and region.Name:match("Can_Plant") then
                                for pos in coroutine.wrap(iterateRegion), region, 1 do
                                    if not autoPlantEnabled or qty <= 0 then break end
                                    if not occupied[vKey(pos)] then
                                        player.Character:PivotTo(CFrame.new(pos + Vector3.new(0, 2, 0)))
                                        task.wait(0.1)
                                        plantEvent:FireServer(pos, seedName)

                                        occupied[vKey(pos)] = true
                                        qty = (tool.Parent and tool:GetAttribute("Quantity")) or (qty - 1)

                                        task.wait(0.25)
                                    end
                                end
                            end
                        end
                        print(("✅ Đã trồng xong hoặc hết seed: %s"):format(seedName))
                    else
                        print("❌ Không tìm thấy tool seed:", seedName)
                    end
                end
            else
                warn("⚠ Không xác định được farm hoặc Plant_Locations.")
            end
        end
        task.wait(1)
    end
end)




--  -- TAB EVENT 

-- Giả sử bạn đã có EventTab rồi:
-- Đảm bảo EventTab đã được tạo trước đó như bạn viết

-- Tạo section bên trong EventTab
local HoneySection = EventTab:AddSection("🍯8 Honey Event")

-- Biến bật/tắt thu thập
local collectPollinated = false
HoneySection:AddToggle("AutoCollectPollinated", {
	Title = "Auto Collect Pollinated Fruit",
	Default = false,
	Tooltip = "Chỉ thu thập các loại fruit có thuộc tính Pollinated",
}):OnChanged(function(state)
	collectPollinated = state
	Fluent:Notify({
		Title = "Honey Event",
		Content = state and "🟢 Đang tự động thu thập fruit có 'Pollinated'" or "🔴 Đã dừng thu thập",
		Duration = 4
	})
end)

-- Vòng lặp tự động tìm và thu thập fruit có Pollinated
task.spawn(function()
	while true do
		if collectPollinated then
			local player = game:GetService("Players").LocalPlayer
			local farms = workspace:FindFirstChild("Farm")

			if farms and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				for _, farm in ipairs(farms:GetChildren()) do
					local owner = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Data") and farm.Important.Data:FindFirstChild("Owner")
					if owner and owner.Value == player.Name then
						local plants = farm.Important:FindFirstChild("Plants_Physical")
						if plants then
							for _, plant in ipairs(plants:GetChildren()) do
								local fruits = plant:FindFirstChild("Fruits")
								if fruits then
									for _, fruit in ipairs(fruits:GetChildren()) do
										if fruit:GetAttribute("Pollinated") == true then
											local fruitPos = fruit:FindFirstChild("PrimaryPart") or fruit:FindFirstChild("Main") or fruit:FindFirstChildWhichIsA("BasePart")
											if fruitPos then
												player.Character:MoveTo(fruitPos.Position)
												task.wait(0.2)
											end

											local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt", true)
											if prompt then
												fireproximityprompt(prompt)
											else
												local click = fruit:FindFirstChildWhichIsA("ClickDetector", true)
												if click then
													fireclickdetector(click)
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
		task.wait(0.5)
	end
end)

-- Giả sử bạn đã có:
local collectAndUsePollinated = false

HoneySection:AddToggle("CollectAndUsePollinated", {
    Title = "Auto Use Pollinated Fruit",
    Default = false,
    Tooltip = "Tự động cầm fruit có Pollinated và sử dụng máy liên tục",
}):OnChanged(function(state)
    collectAndUsePollinated = state
    Fluent:Notify({
        Title = "Honey Event",
        Content = state and "🟢 Đang tự động sử dụng fruit có 'Pollinated'" or "🔴 Đã dừng sử dụng",
        Duration = 4
    })
end)

task.spawn(function()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local myPlayer = Players.LocalPlayer
    local backpack = myPlayer:WaitForChild("Backpack")
    local honeyMachineEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("HoneyMachineService_RE")

    local function isItemStillHeld(itemName)
        local character = myPlayer.Character
        if not character then return false end
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and item.Name == itemName then
                return true
            end
        end
        return false
    end

    while true do
        if collectAndUsePollinated then
            local foundItem = nil
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and string.find(tool.Name, "Pollinated") then
                    foundItem = tool
                    break
                end
            end

            if foundItem then
                local itemName = foundItem.Name
                local character = myPlayer.Character
                if character then
                    -- Cầm item lên
                    foundItem.Parent = character
                    print("👐 Đã cầm fruit:", itemName)

                    -- Liên tục sử dụng cho tới khi fruit biến mất khỏi tay
                    while isItemStillHeld(itemName) and collectAndUsePollinated do
                        honeyMachineEvent:FireServer("MachineInteract")
                        print("⚙️ Đã gửi MachineInteract cho", itemName)
                        task.wait(1.5)  -- Chờ 1.5 giây giữa các lần sử dụng
                    end

                    print("✅ Fruit đã được sử dụng hết hoặc bị biến mất:", itemName)
                end
            else
                print("🔍 Không còn fruit có 'Pollinated' trong Backpack, đợi 5 giây...")
                task.wait(5)
            end
        else
            task.wait(0.5)
        end
    end
end)


-- Danh sách item cần mua
local honeyItemsList = {
    "Flower Seed Pack", "Lavender","Nectarshade", "Nectarine", "Hive Fruit", "Honey Sprinkler",
    "Bee Egg", "Bee Crate", "Honey Comb", "Bee Chair",
    "Honey Torch", "Honey Walkway"
}

-- Lưu item đã chọn
local selectedHoneyItems = {}

-- Dropdown chọn item cần mua
HoneySection:AddDropdown("HoneyItemDropdown", {
    Title = "🛒 Chọn item muốn auto mua",
    Values = honeyItemsList,
    Multi = true,
    Default = {},
    Callback = function(selected)
        selectedHoneyItems = {}  -- Reset danh sách
        for itemName, isSelected in pairs(selected) do
            if isSelected then
                table.insert(selectedHoneyItems, itemName)
            end
        end

        if #selectedHoneyItems == 0 then
            print("🔴 Bạn chưa chọn item nào.")
        else
            print("✅ Item đã chọn:", table.concat(selectedHoneyItems, ", "))
        end
    end
})

-- Biến bật/tắt Auto Buy
local autoBuyEnabled = false

HoneySection:AddToggle("AutoBuyHoneyItems", {
    Title = "⚡ Auto Buy Honey Items",
    Default = false,
    Tooltip = "Tự động mua các item đã chọn",
}):OnChanged(function(state)
    autoBuyEnabled = state

    Fluent:Notify({
        Title = "Honey Event",
        Content = state and "🟢 Đang tự động mua item" or "🔴 Đã dừng auto buy",
        Duration = 4
    })
end)



-- Vòng lặp auto mua item
task.spawn(function()
    while true do
        if autoBuyEnabled then
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local buyEvent = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("BuyEventShopStock")

            if buyEvent then
                for _, itemName in ipairs(selectedHoneyItems) do
                    local args = { [1] = itemName }
                    buyEvent:FireServer(unpack(args))
                    print("🛒 Đã mua:", itemName)
                    task.wait(0.5) -- Chờ giữa các lần mua để tránh spam
                end
            else
                warn("❌ Không tìm thấy sự kiện mua hàng!")
            end
        end
        task.wait(1) -- Lặp kiểm tra mỗi giây
    end
end)

-- Seed crafting event 
-- 📦 Auto Craft System for SeedEventWorkbench

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")

local CraftingRemote = ReplicatedStorage.GameEvents:WaitForChild("CraftingGlobalObjectService")
local Workbench = workspace.Interaction.UpdateItems.NewCrafting:WaitForChild("SeedEventCraftingWorkBench")
local WorkbenchID = "SeedEventWorkbench"

-- 🌱 Tạo giao diện Seed Crafting trong EventTab
local SeedCraftingSection = EventTab:AddSection("🌾 Seed Crafting")

local CraftableItems = {
    "Crafters Seed Pack", "Manuka Flower", "Dandelion", "Lumira",
    "Honeysuckle", "Bee Balm", "Nectar Thorn", "Suncoil"
}

local selectedItem = ConfigSystem.CurrentConfig.AutoCraftSeedItem
local autoCraftEnabled = ConfigSystem.CurrentConfig.AutoCraftSeedEnabled

-- 🔽 Dropdown chọn item để craft
SeedCraftingSection:AddDropdown("CraftItemSelector", {
    Title = "Chọn item cần craft",
    Values = CraftableItems,
    Default = selectedItem,
}):OnChanged(function(v)
    selectedItem = v
    ConfigSystem.CurrentConfig.AutoCraftSeedItem = v
    ConfigSystem.SaveConfig()
end)

-- 🔘 Toggle bật/tắt Auto Craft
SeedCraftingSection:AddToggle("AutoCraftToggle", {
    Title = "Tự động craft item",
    Default = autoCraftEnabled,
    Tooltip = "Sẽ đợi hết thời gian, sau đó craft lại liên tục",
}):OnChanged(function(val)
    autoCraftEnabled = val
    ConfigSystem.CurrentConfig.AutoCraftSeedEnabled = val
    ConfigSystem.SaveConfig()
    print(val and ("🟢 Đã bật Auto Craft: " .. selectedItem) or "🔴 Đã tắt Auto Craft")
end)

-- 🔎 Tìm tool trong backpack hoặc character theo tên bắt đầu
local function findToolByName(name)
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name == name or tool.Name:match("^" .. name)) then
            return tool
        end
    end
    for _, tool in ipairs(player.Character:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name == name or tool.Name:match("^" .. name)) then
            return tool
        end
    end
    return nil
end

-- 🧠 Thực hiện craft item
local function craftItem(itemName)
    local Recipes = {
        ["Crafters Seed Pack"] = {"Flower Seed Pack"},
        ["Manuka Flower"] = {"Daffodil Seed", "Orange Tulip Seed"},
        ["Dandelion"] = {"Bamboo", "Bamboo", "Manuka Flower Seed"},
        ["Lumira"] = {"Pumpkin", "Pumpkin", "Dandelion Seed", "Flower Seed Pack"},
        ["Honeysuckle"] = {"Pink Lily Seed", "Purple Dahlia Seed"},
        ["Bee Balm"] = {"Crocus", "Lavender"},
        ["Nectar Thorn"] = {"Cactus", "Cactus", "Cactus Seed", "Nectarshade Seed"},
        ["Suncoil"] = {"Crocus", "Daffodil", "Dandelion", "Pink Lily"},
    }

    local recipe = Recipes[itemName]
    if not recipe then
        warn("Không tìm thấy công thức cho:", itemName)
        return
    end

    print("📦 Kiểm tra nguyên liệu cho:", itemName)

    -- B1: SetRecipe
    CraftingRemote:FireServer("SetRecipe", Workbench, WorkbenchID, itemName)
    task.wait(0.25)

    -- B2: Input nguyên liệu theo thứ tự
    for slot, materialName in ipairs(recipe) do
        local tool = findToolByName(materialName)
        if tool then
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
                task.wait(0.15)

                CraftingRemote:FireServer("InputItem", Workbench, WorkbenchID, slot, {
                    ItemType = "Seed Pack",
                    ItemData = {} -- Không cần UUID nữa
                })

                task.wait(0.2)
            else
                warn("⚠ Không tìm thấy Humanoid để trang bị tool: ", materialName)
            end
        else
            warn("❌ Thiếu nguyên liệu:", materialName)
        end
    end

    -- B3: Gửi Craft
    CraftingRemote:FireServer("Craft", Workbench, WorkbenchID)
    print("🛠️ Đã gửi lệnh craft:", itemName)
end

-- 🔁 Vòng lặp tự động craft
RunService.Heartbeat:Connect(function()
    if autoCraftEnabled and selectedItem ~= "" then
        local BenchTable = Workbench.SeedEventCraftingWorkBench.Model:FindFirstChild("BenchTable")
        local TimerLabel = BenchTable and BenchTable:FindFirstChild("CraftingBillboardGui") and BenchTable.CraftingBillboardGui:FindFirstChild("Timer")

        if TimerLabel and TimerLabel.Text and TimerLabel.Text ~= "" and TimerLabel.Text ~= "00:00" then
            local mins, secs = string.match(TimerLabel.Text, "(%d+):(%d+)")
            local duration = tonumber(mins) * 60 + tonumber(secs)
            task.wait(duration + 0.5)
        end

        CraftingRemote:FireServer("Claim", Workbench, WorkbenchID, 1)
        task.wait(0.2)

        craftItem(selectedItem)
    end
end)



--end
-- SEED SHOP 
-- =========================
-- 🌱  SEED  SHOP  SECTION
-- =========================

-- 1️⃣  Tạo section trong tab Shop
local SeedShopSection = ShopTab:AddSection("Seed Shop")

-- 2️⃣  Danh sách seed có thể mua
local seedList = {
    "Carrot", "Strawberry", "Blueberry", "Orange Tulip", "Tomato", "Daffodil",
    "Corn", "Watermelon", "Pumpkin", "Apple", "Bamboo", "Coconut",
    "Cactus", "Dragon Fruit", "Mango", "Mushroom", "Grape", "Pepper",
    "Cacao", "Beanstalk", "Ember Lily","Sugar Apple"
}

-- 3️⃣  Biến lưu & load từ ConfigSystem
local selectedSeeds      = ConfigSystem.CurrentConfig.SeedSelectedList      or {}
local autoBuySeedEnabled = ConfigSystem.CurrentConfig.SeedAutoBuyEnabled    or false

-- 4️⃣  Dropdown chọn seed
local seedDropdown = SeedShopSection:AddDropdown("SeedSelector", {
    Title   = "🛒 Chọn seed để auto mua",
    Values  = seedList,
    Multi   = true,
    Default = (function()
        local dict = {}
        for _, v in ipairs(selectedSeeds) do dict[v] = true end
        return dict
    end)()
})

seedDropdown:OnChanged(function(dict)
    selectedSeeds = {}
    for name, picked in pairs(dict) do
        if picked then table.insert(selectedSeeds, name) end
    end
    ConfigSystem.CurrentConfig.SeedSelectedList = selectedSeeds
    ConfigSystem.SaveConfig()

    if #selectedSeeds == 0 then
        print("🔴 Chưa chọn seed nào.")
    else
        print("✅ Seed đã chọn:", table.concat(selectedSeeds, ", "))
    end
end)

-- 5️⃣  Toggle bật / tắt auto buy
SeedShopSection:AddToggle("AutoBuySeedToggle", {
    Title   = "⚡ Auto Buy Seed",
    Default = autoBuySeedEnabled,
    Tooltip = "Tự động mua các seed đã chọn"
}):OnChanged(function(state)
    autoBuySeedEnabled = state
    ConfigSystem.CurrentConfig.SeedAutoBuyEnabled = state
    ConfigSystem.SaveConfig()

    Fluent:Notify({
        Title    = "Seed AutoBuy",
        Content  = state and "🟢 Đang tự động mua seed" or "🔴 Đã tắt auto buy",
        Duration = 4
    })
end)

-- 6️⃣  Vòng lặp auto mua seed
task.spawn(function()
    local RS        = game:GetService("ReplicatedStorage")
    local seedEvent = RS:WaitForChild("GameEvents"):WaitForChild("BuySeedStock")

    while true do
        if autoBuySeedEnabled and #selectedSeeds > 0 then
            for _, seedName in ipairs(selectedSeeds) do
                seedEvent:FireServer(seedName)
                print("🌱 Đã mua:", seedName)
                task.wait(0.5) -- giảm spam remote
            end
        end
        task.wait(1) -- kiểm tra mỗi giây
    end
end)


-- GEEAR SHOP 

-- ⚙️ GEAR SHOP SECTION
local GearShopSection = ShopTab:AddSection("Gear Shop")

-- 🎒 Danh sách Gear có thể mua
local gearList = {
    "Basic Sprinkler",
    "Advanced Sprinkler",
    "Godly Sprinkler",
    "Master Sprinkler",
    "Trowel",
    "Friendship Pot",
    "Harvest Tool",
    "Favorite Tool",
    "Recall Wrench",
    "Watering Can"
}

-- 📦 Biến lưu item được chọn
local selectedGears = ConfigSystem.CurrentConfig.GearSelectedList or {}
local autoBuyGearEnabled = ConfigSystem.CurrentConfig.GearAutoBuyEnabled or false

-- 🔽 Dropdown chọn gear
local gearDropdown = GearShopSection:AddDropdown("GearSelector", {
    Title = "🛒 Chọn gear để auto mua",
    Values = gearList,
    Multi = true,
    Default = (function()
        local dict = {}
        for _, v in ipairs(selectedGears) do dict[v] = true end
        return dict
    end)()
})

gearDropdown:OnChanged(function(dict)
    selectedGears = {}
    for name, picked in pairs(dict) do
        if picked then table.insert(selectedGears, name) end
    end
    ConfigSystem.CurrentConfig.GearSelectedList = selectedGears
    ConfigSystem.SaveConfig()

    if #selectedGears == 0 then
        print("🔴 Chưa chọn gear nào.")
    else
        print("✅ Gear đã chọn:", table.concat(selectedGears, ", "))
    end
end)

-- 🔘 Toggle bật auto mua gear
GearShopSection:AddToggle("AutoBuyGearToggle", {
    Title = "⚡ Auto Buy Gear",
    Default = autoBuyGearEnabled,
    Tooltip = "Tự động mua các gear đã chọn"
}):OnChanged(function(val)
    autoBuyGearEnabled = val
    ConfigSystem.CurrentConfig.GearAutoBuyEnabled = val
    ConfigSystem.SaveConfig()

    Fluent:Notify({
        Title = "Gear AutoBuy",
        Content = val and "🟢 Đang tự động mua gear" or "🔴 Đã tắt auto buy",
        Duration = 4
    })
end)

-- 🔁 Vòng lặp auto mua gear
task.spawn(function()
    while true do
        if autoBuyGearEnabled and #selectedGears > 0 then
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local gearEvent = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("BuyGearStock")

            if gearEvent then
                for _, gearName in ipairs(selectedGears) do
                    gearEvent:FireServer(gearName)
                    print("🛒 Đã mua:", gearName)
                    task.wait(0.5) -- tránh spam
                end
            else
                warn("❌ Không tìm thấy sự kiện BuyGearStock")
            end
        end
        task.wait(1)
    end
end)

-- SHOP SECTION: Mua Pet Egg

-- Tạo section "Egg Shop"

local EggShopSection = ShopTab:AddSection("Egg Shop")

local eggEvent = game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg

local ALL_EGGS = {
    "Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg", "Bug Egg", "Mythic Egg"
}

local selectedEggs = ConfigSystem.CurrentConfig.EggSelectedList or {}
local autoBuyEnabled = ConfigSystem.CurrentConfig.EggAutoBuyEnabled or false

-- Dropdown chọn egg để mua
local eggDropdown = EggShopSection:AddDropdown("EggSelector", {
    Title = "Chọn loại Egg để Auto Mua",
    Values = ALL_EGGS,
    Multi = true,
    Default = (function()
        local dict = {}
        for _, v in ipairs(selectedEggs) do dict[v] = true end
        return dict
    end)()
})

eggDropdown:OnChanged(function(dictValues)
    selectedEggs = {}
    for name, picked in pairs(dictValues) do
        if picked then table.insert(selectedEggs, name) end
    end
    ConfigSystem.CurrentConfig.EggSelectedList = selectedEggs
    ConfigSystem.SaveConfig()
end)

-- Toggle bật auto buy egg
local eggToggle = EggShopSection:AddToggle("AutoBuyEggToggle", {
    Title = "Tự động mua Egg",
    Default = autoBuyEnabled
})

eggToggle:OnChanged(function(val)
    autoBuyEnabled = val
    ConfigSystem.CurrentConfig.EggAutoBuyEnabled = val
    ConfigSystem.SaveConfig()
    print(val and "🟢 Auto Buy Egg đã bật" or "🔴 Auto Buy Egg đã tắt")
end)

-- Danh sách vị trí egg trong shop
local eggSlots = {
    workspace.NPCS["Pet Stand"].EggLocations.Location,               -- Slot 1
    workspace.NPCS["Pet Stand"].EggLocations:GetChildren()[3],       -- Slot 2
    workspace.NPCS["Pet Stand"].EggLocations:GetChildren()[2],       -- Slot 3
}

local slotNames = { "Slot 1", "Slot 2", "Slot 3" }

-- Vòng lặp auto buy egg
task.spawn(function()
    while true do
        if autoBuyEnabled and eggEvent and #selectedEggs > 0 then
            for idx, slot in ipairs(eggSlots) do
                local label = slot:FindFirstChild("PetInfo")
                    and slot.PetInfo:FindFirstChild("SurfaceGui")
                    and slot.PetInfo.SurfaceGui:FindFirstChild("EggNameTextLabel")

                local eggName = label and label.Text
                print(("🔍 [%s] Egg hiện tại: %s"):format(slotNames[idx], eggName or "Không tìm thấy label"))

                if eggName and table.find(selectedEggs, eggName) then
                    print(("🛒 Mua %s tại %s (index %d)"):format(eggName, slotNames[idx], idx))
                    eggEvent:FireServer(idx)
                    task.wait(0.5)
                end
            end
        end
        task.wait(1)
    end
end)

--end
-- Tích hợp với SaveManager
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Thay đổi cách lưu cấu hình để sử dụng tên người chơi
InterfaceManager:SetFolder("HTHubAS")
SaveManager:SetFolder("HTHubAS/" .. playerName)

-- Thêm thông tin vào tab Settings
SettingsTab:AddParagraph({
    Title = "Cấu hình tự động",
    Content = "Cấu hình của bạn đang được tự động lưu theo tên nhân vật: " .. playerName
})

SettingsTab:AddParagraph({
    Title = "Phím tắt",
    Content = "Nhấn LeftControl để ẩn/hiện giao diện"
})

-- Thực thi tự động lưu cấu hình
AutoSaveConfig()

-- Thiết lập events
setupSaveEvents()

print("HT Hub | Anime Saga đã được tải thành công!")
