-- Danh sách các loại Egg
local eggTypes = {
    "Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg",
    "Mythical Egg", "Bug Egg", "Night Egg"
}

-- Map tên -> index để gọi server
local eggIndexByName = {}
for i, name in ipairs(eggTypes) do
    eggIndexByName[name] = i
end

-- Load dữ liệu đã lưu
local selectedEggs = ConfigSystem.CurrentConfig.SelectedEggs or {}
getgenv().AutoBuyEggs = ConfigSystem.CurrentConfig.AutoBuyEggsEnabled or false

-- Dropdown chọn egg
EggShopSection:AddDropdown("EggDropdownMulti", {
    Title = "Chọn loại Egg",
    Values = eggTypes,
    Multi = true,
    Default = selectedEggs,
    Callback = function(values)
        selectedEggs = values
        ConfigSystem.CurrentConfig.SelectedEggs = values
        ConfigSystem.SaveConfig()
    end
})

-- Toggle Auto Mua
EggShopSection:AddToggle("AutoBuyEggToggle", {
    Title = "Auto Mua Egg",
    Default = getgenv().AutoBuyEggs,
    Callback = function(value)
        getgenv().AutoBuyEggs = value
        ConfigSystem.CurrentConfig.AutoBuyEggsEnabled = value
        ConfigSystem.SaveConfig()
    end
})

-- Hàm kiểm tra egg có tồn tại trong game hay không
local function isEggAvailable(eggName)
    local eggFolder = workspace:FindFirstChild("NPCS")
    if not eggFolder then return false end

    local petStand = eggFolder:FindFirstChild("Pet Stand")
    if not petStand then return false end

    local eggLocations = petStand:FindFirstChild("EggLocations")
    if not eggLocations then return false end

    return eggLocations:FindFirstChild(eggName) ~= nil
end

-- Hàm mua egg 1 lần
local function buySelectedEggsOnce()
    for _, name in ipairs(selectedEggs) do
        local index = eggIndexByName[name]
        if index and isEggAvailable(name) then
            pcall(function()
                game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg:FireServer(index)
            end)
            task.wait(0.3)
        else
            warn("Không tìm thấy egg: " .. name)
        end
    end
end

-- Nút mua 1 lần
EggShopSection:AddButton({
    Title = "Mua Egg 1 lần",
    Description = "Mua mỗi loại egg đã chọn (nếu có trong map)",
    Callback = function()
        buySelectedEggsOnce()
    end
})

-- Vòng lặp auto mua egg
task.spawn(function()
    while true do
        if getgenv().AutoBuyEggs and selectedEggs then
            for _, name in ipairs(selectedEggs) do
                local index = eggIndexByName[name]
                if index and isEggAvailable(name) then
                    pcall(function()
                        game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg:FireServer(index)
                    end)
                    task.wait(0.5)
                end
            end
        end
        task.wait(0.5)
    end
end)
