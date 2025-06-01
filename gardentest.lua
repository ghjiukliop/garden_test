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

ConfigSystem.DefaultConfig = {
    -- Các cài đặt mặc định
    UITheme = "Amethyst",
    LogsEnabled = true,
    WarningsEnabled = true,
    SelectedPlants = {}, -- Danh sách cây đã chọn
    AutoFarmEnabled = false -- Trạng thái auto farm
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
-- Thêm tab Shop
local ShopTab = Window:AddTab({
    Title = "Shop",
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

-- Thêm section vào tab Play
-- Auto Farm Fruit - Giao diện Fluent thay cho GUI cũ (giữ nguyên chức năng) + Sửa thu thập + Bật tìm kiếm rõ ràng
-- Section Auto Farm Fruit trong tab Play
local AutoFarmSection = PlayTab:AddSection("Auto Farm Fruit")
print("Đã tạo section Auto Farm Fruit trong tab Play")

-- Danh sách tên cây cố định
local allPlantNames = {
    "Apple", "Avocado", "Banana", "Beanstalk", "Blood Banana", "Blueberry", "Cacao", "Cactus", "Candy Blossom",
    "Celestiberry", "Cherry Blossom", "Cherry OLD", "Coconut", "Corn", "Cranberry", "Crimson Vine", "Cursed Fruit",
    "Dragon Fruit", "Durian", "Easter Egg", "Eggplant", "Ember Lily", "Foxglove", "Glowshroom", "Grape", "Hive Fruit",
    "Lemon", "Lilac", "Lotus", "Mango", "Mint", "Moon Blossom", "Moon Mango", "Moon Melon", "Moonflower", "Moonglow",
    "Nectarine", "Papaya", "Passionfruit", "Peach", "Pear", "Pepper", "Pineapple", "Pink Lily", "Purple Cabbage",
    "Purple Dahlia", "Raspberry", "Rose", "Soul Fruit", "Starfruit", "Strawberry", "Succulent", "Sunflower",
    "Tomato", "Venus Fly Trap"
}

-- Khởi tạo biến
local selectedPlantNames = ConfigSystem.CurrentConfig.SelectedPlants or {}
local collecting = ConfigSystem.CurrentConfig.AutoFarmEnabled or false
local playerFarm
local plantObjects

-- Tìm farm của người chơi
local farms = safeGetPath(workspace, {"Farm"}, 1)
if farms then
    print("Đã tìm thấy thư mục Farm trong workspace")
    for _, farm in ipairs(farms:GetChildren()) do
        local owner = safeGetPath(farm, {"Important", "Data", "Owner"}, 0.5)
        if owner and owner.Value == playerName then
            playerFarm = farm
            print("Đã tìm thấy farm của người chơi: " .. playerName)
            break
        end
    end
else
    warn("❌ Không tìm thấy thư mục Farm trong workspace")
end

if not playerFarm then
    warn("❌ Không tìm thấy farm của người chơi.")
    AutoFarmSection:AddParagraph({
        Title = "Lỗi",
        Content = "Không tìm thấy farm của bạn. Vui lòng đảm bảo bạn đang ở trong farm của mình."
    })
else
    plantObjects = safeGetPath(playerFarm, {"Important", "Plants_Physical"}, 0.5)
    if not plantObjects then
        warn("❌ Không tìm thấy Plants_Physical.")
        AutoFarmSection:AddParagraph({
            Title = "Lỗi",
            Content = "Không tìm thấy dữ liệu cây trồng. Vui lòng kiểm tra farm của bạn."
        })
    else
        print("Đã tìm thấy Plants_Physical, khởi tạo UI Auto Farm")
        -- Dropdown chọn cây
        AutoFarmSection:AddDropdown("PlantDropdown", {
            Title = "Chọn loại cây",
            Description = "Chọn các loại cây để tự động thu thập",
            Values = allPlantNames,
            Multi = true,
            Default = selectedPlantNames,
            Callback = function(values)
                selectedPlantNames = values
                ConfigSystem.CurrentConfig.SelectedPlants = values
                ConfigSystem.SaveConfig()
                print("Đã chọn các cây: " .. table.concat(values, ", "))
            end
        })

        -- Ô tìm kiếm
        AutoFarmSection:AddInput("PlantSearch", {
            Title = "Tìm kiếm cây",
            Placeholder = "🔍 Nhập tên cây...",
            Callback = function(keyword)
                local dropdown = AutoFarmSection._components and AutoFarmSection._components.PlantDropdown
                if dropdown then
                    local filtered = {}
                    for _, name in ipairs(allPlantNames) do
                        if keyword == "" or name:lower():find(keyword:lower()) then
                            table.insert(filtered, name)
                        end
                    end
                    dropdown:SetValues(filtered)
                    print("Lọc cây với từ khóa: " .. keyword)
                else
                    warn("Không tìm thấy PlantDropdown để lọc")
                end
            end
        })

        -- Toggle Auto Farm
        AutoFarmSection:AddToggle("AutoFarmToggle", {
            Title = "Tự động thu thập",
            Description = "Bật/tắt tự động thu thập trái cây",
            Default = collecting,
            Callback = function(value)
                collecting = value
                ConfigSystem.CurrentConfig.AutoFarmEnabled = value
                ConfigSystem.SaveConfig()
                print("Tự động thu thập: " .. (value and "Bật" or "Tắt"))
            end
        })

        -- Hàm thu thập trái cây
        local function collectFruit(fruit)
            if not fruit:IsA("Model") then return end
            local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then 
                fireproximityprompt(prompt) 
                print("Thu thập qua ProximityPrompt: " .. fruit.Name)
                return 
            end
            local click = fruit:FindFirstChildWhichIsA("ClickDetector", true)
            if click then 
                fireclickdetector(click) 
                print("Thu thập qua ClickDetector: " .. fruit.Name)
                return 
            end
        end

        -- Vòng lặp tự động thu thập
        task.spawn(function()
            while true do
                if collecting and #selectedPlantNames > 0 and plantObjects then
                    for _, plant in ipairs(plantObjects:GetChildren()) do
                        if table.find(selectedPlantNames, plant.Name) then
                            local fruits = plant:FindFirstChild("Fruits")
                            if fruits then
                                for _, fruit in ipairs(fruits:GetChildren()) do
                                    collectFruit(fruit)
                                    task.wait(0.05)
                                end
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end)
    end
end
--end
--shop 
-- SHOP SECTION: Mua Pet Egg



-- Tạo section trong Shop tab
local EggShopSection = ShopTab:AddSection("Egg Shop")
---- Danh sách các loại Egg
local eggTypes = {
    "Common Egg",      -- index 1
    "Uncommon Egg",    -- index 2
    "Rare Egg",        -- index 3
    "Legendary Egg",   -- index 4
    "Mythical Egg",    -- index 5
    "Bug Egg",         -- index 6
    "Night Egg"        -- index 7
}

-- Mapping index để xác định lại sau từ tên
local eggIndexByName = {}
for i, name in ipairs(eggTypes) do
    eggIndexByName[name] = i
end

-- Danh sách egg được chọn từ dropdown
local selectedEggNames = {}

EggShopSection:AddDropdown("EggDropdown", {
    Title = "Chọn loại Egg",
    Values = eggTypes,
    Multi = true,
    Default = {},
    Callback = function(values)
        selectedEggNames = values
    end
})

-- Nút Mua 1 lần
EggShopSection:AddButton({
    Title = "Mua 1 lần",
    Description = "Mua mỗi loại egg bạn đã chọn một lần",
    Callback = function()
        for _, name in ipairs(selectedEggNames) do
            local index = eggIndexByName[name]
            if index then
                game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg:FireServer(index)
            end
        end
    end
})

-- Toggle tự động mua
getgenv().AutoBuyEggs = false

EggShopSection:AddToggle("AutoBuyEggs", {
    Title = "Auto Mua",
    Default = false,
    Callback = function(value)
        getgenv().AutoBuyEggs = value
    end
})

-- Vòng lặp tự động mua egg
task.spawn(function()
    while true do
        if getgenv().AutoBuyEggs then
            for _, name in ipairs(selectedEggNames) do
                local index = eggIndexByName[name]
                if index then
                    game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg:FireServer(index)
                    task.wait(0.5)
                end
            end
        end
        task.wait(0.5)
    end
end)


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
