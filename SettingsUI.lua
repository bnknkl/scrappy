-- SettingsUI.lua - Settings interface with tabs

local Scrappy = _G["Scrappy"]

if not Scrappy.SettingsUI then
    Scrappy.SettingsUI = {}
end

local QUALITY_NAMES = {
    [0] = "Junk",
    [1] = "Common", 
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic"
}

local QUALITY_COLORS = {
    [0] = {r=0.62, g=0.62, b=0.62},
    [1] = {r=1, g=1, b=1},
    [2] = {r=0.12, g=1, b=0},
    [3] = {r=0, g=0.44, b=0.87},
    [4] = {r=0.64, g=0.21, b=0.93}
}

local CURRENT_MAX_ILVL = 717

local TABS = {
    {id = "general", name = "General", icon = "Interface\\ICONS\\Trade_Engineering"},
    {id = "filters", name = "Filters", icon = "Interface\\ICONS\\INV_Misc_Gear_01"},
    {id = "protections", name = "Protections", icon = "Interface\\ICONS\\Spell_Holy_DivineProtection"}
}

local activeTab = "general"

-- Create main settings frame
local function CreateSettingsFrame()
    local frame = CreateFrame("Frame", "ScrappySettingsFrame", UIParent, "BackdropTemplate")
    frame.name = "Scrappy"
    frame:Hide()
    
    frame:SetSize(700, 650)
    frame:SetPoint("CENTER")
    
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    
    -- Make it draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetText("Scrappy Settings")
    
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    return frame
end

-- Create tab buttons
local function CreateTabButtons(parent)
    local tabs = {}
    local tabWidth = 120
    local tabHeight = 32
    local totalWidth = (#TABS * tabWidth) + ((#TABS - 1) * 5)
    local startX = (700 - totalWidth) / 2
    
    for i, tabInfo in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
        tab:SetSize(tabWidth, tabHeight)
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", startX + (i-1) * (tabWidth + 5), -50)
        
        tab:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        
        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", tab, "LEFT", 8, 0)
        icon:SetTexture(tabInfo.icon)
        
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        text:SetText(tabInfo.name)
        
        tab:SetScript("OnClick", function()
            Scrappy.SettingsUI.SwitchTab(tabInfo.id)
        end)
        
        tab:SetScript("OnEnter", function(self)
            if activeTab ~= tabInfo.id then
                self:SetBackdropColor(0.3, 0.3, 0.3, 0.8)
            end
        end)
        
        tab:SetScript("OnLeave", function(self)
            if activeTab ~= tabInfo.id then
                self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            end
        end)
        
        tab.id = tabInfo.id
        tab.text = text
        tabs[tabInfo.id] = tab
    end
    
    return tabs
end

-- Create content area for tab content
local function CreateContentArea(parent)
    local content = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    content:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -90)
    content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 60)
    
    content:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    content:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    content:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    return content
end

local function CreateCheckbox(parent, name, tooltip, point, relativeFrame, relativePoint, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint(point, relativeFrame, relativePoint, x, y)
    cb.Text:SetText(name)
    
    if tooltip then
        cb.tooltipText = tooltip
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return cb
end

local function CreateSlider(parent, name, tooltip, minVal, maxVal, point, relativeFrame, relativePoint, x, y)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint(point, relativeFrame, relativePoint, x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    
    slider.title = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slider.title:SetPoint("BOTTOM", slider, "TOP", 0, 5)
    slider.title:SetText(name)
    
    slider.valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slider.valueText:SetPoint("TOP", slider.title, "BOTTOM", 0, -5)
    
    -- Hide default labels  
    if slider.Low then slider.Low:Hide() end
    if slider.High then slider.High:Hide() end
    
    if tooltip then
        slider.tooltipText = tooltip
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return slider
end

local function CreateButton(parent, text, tooltip, point, relativeFrame, relativePoint, x, y, width, height)
    local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    btn:SetSize(width or 120, height or 25)
    btn:SetPoint(point, relativeFrame, relativePoint, x, y)
    btn:SetText(text)
    
    if tooltip then
        btn.tooltipText = tooltip
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return btn
end

local function CreateDropdown(parent, name, tooltip, point, relativeFrame, relativePoint, x, y)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint(point, relativeFrame, relativePoint, x, y)
    
    dd.title = dd:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dd.title:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 16, 3)
    dd.title:SetText(name)
    
    if tooltip then
        dd.tooltipText = tooltip
        dd:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end)
        dd:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return dd
end

--  Create General tab content
local function CreateGeneralTab(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()
    
    --  Auto-sell checkbox
    local autoSellCheck = CreateCheckbox(container, "Enable Auto-Sell", 
        "Automatically sell items when visiting a vendor", 
        "TOPLEFT", container, "TOPLEFT", 20, -20)
    
    autoSellCheck:SetScript("OnClick", function(self)
        ScrappyDB.autoSell = self:GetChecked()
        Scrappy.QuietPrint("Auto-sell " .. (ScrappyDB.autoSell and "enabled" or "disabled"))
    end)
    
    --  Quiet mode checkbox
    local quietModeCheck = CreateCheckbox(container, "Quiet Mode", 
        "Reduce chat messages when making changes in the UI", 
        "TOPLEFT", autoSellCheck, "BOTTOMLEFT", 0, -10)
    
    quietModeCheck:SetScript("OnClick", function(self)
        ScrappyDB.quietMode = self:GetChecked()
        Scrappy.Print("Quiet mode " .. (ScrappyDB.quietMode and "enabled - UI changes will be silent" or "disabled - UI changes will show messages"))
    end)
    
    --  Auto-confirm soulbound dialogs
    local autoConfirmCheck = CreateCheckbox(container, "Auto-Confirm Soulbound Dialogs", 
        "Automatically confirm 'item will become soulbound' dialogs during selling for smoother operation.", 
        "TOPLEFT", quietModeCheck, "BOTTOMLEFT", 0, -10)
    
    autoConfirmCheck:SetScript("OnClick", function(self)
        ScrappyDB.autoConfirmSoulbound = self:GetChecked()
        Scrappy.QuietPrint("Auto-confirm soulbound dialogs " .. (ScrappyDB.autoConfirmSoulbound and "enabled" or "disabled"))
    end)
    
    --  Auto-threshold section
    local thresholdTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    thresholdTitle:SetPoint("TOPLEFT", autoConfirmCheck, "BOTTOMLEFT", 0, -30)
    thresholdTitle:SetText("Item Level Thresholds")
    thresholdTitle:SetTextColor(1, 0.82, 0)
    
    --  Auto-threshold checkbox
    local autoThresholdCheck = CreateCheckbox(container, "Auto Item Level Threshold", 
        "Automatically set sell threshold based on your equipped gear", 
        "TOPLEFT", thresholdTitle, "BOTTOMLEFT", 0, -10)
    
    --  Manual ilvl threshold slider
    local ilvlSlider = CreateSlider(container, "Manual Item Level Threshold", 
        "Sell items with item level at or below this value (0 = disabled)", 
        0, CURRENT_MAX_ILVL, "TOPLEFT", autoThresholdCheck, "BOTTOMLEFT", 0, -50)
    
    ilvlSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.valueText:SetText(value == 0 and "Disabled" or value)
        if not ScrappyDB.autoThreshold then
            ScrappyDB.ilvlThreshold = value
        end
    end)
    
    --  Set up auto-threshold checkbox script after slider is created
    autoThresholdCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if Scrappy.Gear and Scrappy.Gear.EnableAutoThreshold then
                Scrappy.Gear.EnableAutoThreshold()
            else
                ScrappyDB.autoThreshold = true
                Scrappy.QuietPrint("Auto-threshold enabled (gear module not loaded)")
            end
            
            --  Update slider to show current equipped average when auto-threshold is enabled
            if Scrappy.Gear and Scrappy.Gear.GetEquippedAverageItemLevel then
                local avgIlvl = Scrappy.Gear.GetEquippedAverageItemLevel()
                ilvlSlider:SetValue(math.floor(avgIlvl))
            end
        else
            if Scrappy.Gear and Scrappy.Gear.DisableAutoThreshold then
                Scrappy.Gear.DisableAutoThreshold()
            else
                ScrappyDB.autoThreshold = false
                Scrappy.QuietPrint("Auto-threshold disabled")
            end
        end
        Scrappy.SettingsUI.RefreshUI()
    end)
    
    --  Auto-threshold offset slider
    local offsetSlider = CreateSlider(container, "Auto-Threshold Offset", 
        "How many item levels below your average equipped ilvl to set the threshold", 
        -50, 0, "TOPLEFT", ilvlSlider, "BOTTOMLEFT", 0, -70)
    
    offsetSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.valueText:SetText(value)
        ScrappyDB.autoThresholdOffset = value
        if ScrappyDB.autoThreshold and Scrappy.Gear and Scrappy.Gear.UpdateAutoThreshold then
            Scrappy.Gear.UpdateAutoThreshold()
        end
    end)
    
    --  Selling order section
    local orderTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    orderTitle:SetPoint("TOPLEFT", offsetSlider, "BOTTOMLEFT", 0, -50)
    orderTitle:SetTextColor(1, 0.82, 0)
    
    --  Selling order dropdown
    local orderDropdown = CreateDropdown(container, "Selling Order", 
        "Order in which items are sold - affects buyback window priority",
        "TOPLEFT", autoSellCheck, "TOPRIGHT", 200, -5)
    
    --  Initialize dropdown
    UIDropDownMenu_SetWidth(orderDropdown, 200)
    UIDropDownMenu_SetText(orderDropdown, "Default Order")
    
    UIDropDownMenu_Initialize(orderDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- Default order option
        info.text = "Default Order"
        info.value = "default"
        info.func = function()
            ScrappyDB.sellOrder = "default"
            UIDropDownMenu_SetText(orderDropdown, "Default Order")
            Scrappy.QuietPrint("Selling order: Default (bag order)")
        end
        info.checked = (ScrappyDB.sellOrder == "default" or not ScrappyDB.sellOrder)
        UIDropDownMenu_AddButton(info)
        
        -- Value order option
        info.text = "Low to High Value"
        info.value = "value"
        info.func = function()
            ScrappyDB.sellOrder = "value"
            UIDropDownMenu_SetText(orderDropdown, "Low to High Value")
            Scrappy.QuietPrint("Selling order: Low to High Value (cheapest items first)")
        end
        info.checked = (ScrappyDB.sellOrder == "value")
        UIDropDownMenu_AddButton(info)
        
        -- Quality order option
        info.text = "Junk to Epic Quality"
        info.value = "quality"
        info.func = function()
            ScrappyDB.sellOrder = "quality"
            UIDropDownMenu_SetText(orderDropdown, "Junk to Epic Quality")
            Scrappy.QuietPrint("Selling order: Junk to Epic Quality (lowest quality first)")
        end
        info.checked = (ScrappyDB.sellOrder == "quality")
        UIDropDownMenu_AddButton(info)
    end)
    
    --  Action buttons
    local buttonY = -350  -- Restored to original position since selling order moved to right column
    -- Buttons moved to main frame - see CreateUI function
    
    --  Store references for refreshing
    container.autoSellCheck = autoSellCheck
    container.quietModeCheck = quietModeCheck
    container.autoConfirmCheck = autoConfirmCheck
    container.autoThresholdCheck = autoThresholdCheck
    container.ilvlSlider = ilvlSlider
    container.offsetSlider = offsetSlider
    container.orderDropdown = orderDropdown
    
    return container
end

--  Create Filters tab content
local function CreateFiltersTab(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()
    
    --  Quality filters section
    local qualityTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    qualityTitle:SetPoint("TOPLEFT", container, "TOPLEFT", 20, -20)
    qualityTitle:SetText("Quality Filters")
    qualityTitle:SetTextColor(1, 0.82, 0)
    
    local qualityDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qualityDesc:SetPoint("TOPLEFT", qualityTitle, "BOTTOMLEFT", 0, -5)
    qualityDesc:SetText("Check quality levels that should be sold:")
    qualityDesc:SetTextColor(0.8, 0.8, 0.8)
    
    local qualityChecks = {}
    local yOffset = -60
    
    for quality = 0, 4 do
        local qualityName = QUALITY_NAMES[quality]
        local color = QUALITY_COLORS[quality]
        
        local check = CreateCheckbox(container, qualityName, 
            "Allow selling " .. qualityName .. " quality items",
            "TOPLEFT", container, "TOPLEFT", 40, yOffset)
        
        --  Color the text
        check.Text:SetTextColor(color.r, color.g, color.b)
        
        check:SetScript("OnClick", function(self)
            if not ScrappyDB.qualityFilter then
                ScrappyDB.qualityFilter = {}
            end
            ScrappyDB.qualityFilter[quality] = self:GetChecked()
            Scrappy.QuietPrint("Quality " .. qualityName .. ": " .. (self:GetChecked() and "sell" or "keep"))
        end)
        
        qualityChecks[quality] = check
        yOffset = yOffset - 30
    end
    
    --  Action buttons
    local scanButton = CreateButton(container, "Scan Materials", 
        "Scan your bags to see what crafting materials you have",
        "BOTTOMLEFT", container, "BOTTOMLEFT", 20, 20, 140, 25)
    scanButton:SetScript("OnClick", function()
        if Scrappy.Config and Scrappy.Config.ScanMaterials then
            Scrappy.Config.ScanMaterials()
        else
            Scrappy.Print("Scan function not available")
        end
    end)
    
    local quickScanButton = CreateButton(container, "Quick Scan", 
        "Quick scan of cached items only",
        "LEFT", scanButton, "RIGHT", 10, 0, 120, 25)
    quickScanButton:SetScript("OnClick", function()
        if Scrappy.Config and Scrappy.Config.QuickScanMaterials then
            Scrappy.Config.QuickScanMaterials()
        else
            Scrappy.Print("Quick scan not available")
        end
    end)
    
    container.qualityChecks = qualityChecks
    return container
end

--  Create Protections tab content
local function CreateProtectionsTab(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()
    
    --  Always-on protections section
    local alwaysTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    alwaysTitle:SetPoint("TOPLEFT", container, "TOPLEFT", 20, -20)
    alwaysTitle:SetText("Always Protected")
    alwaysTitle:SetTextColor(0.5, 1, 0.5)
    
    local alwaysDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    alwaysDesc:SetPoint("TOPLEFT", alwaysTitle, "BOTTOMLEFT", 0, -5)
    alwaysDesc:SetText("These items are always protected and cannot be sold:")
    alwaysDesc:SetTextColor(0.8, 0.8, 0.8)
    
    --  Consumable protection (always checked, disabled)
    local consumableCheck = CreateCheckbox(container, "Consumables (Flasks, Potions, Food)", 
        "Prevents selling flasks, potions, food, etc. This protection cannot be disabled for safety.", 
        "TOPLEFT", alwaysDesc, "BOTTOMLEFT", 0, -15)
    consumableCheck:SetChecked(true)
    consumableCheck:Disable()
    
    --  Profession equipment protection (always checked, disabled)
    local professionCheck = CreateCheckbox(container, "Profession Equipment (Tools, Mining Picks, etc.)", 
        "Prevents selling profession tools, mining picks, skinning knives, etc. This protection cannot be disabled for safety.", 
        "TOPLEFT", consumableCheck, "BOTTOMLEFT", 0, -10)
    professionCheck:SetChecked(true)
    professionCheck:Disable()
    
    --  Optional protections section
    local optionalTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    optionalTitle:SetPoint("TOPLEFT", professionCheck, "BOTTOMLEFT", 0, -30)
    optionalTitle:SetText("Optional Protections")
    optionalTitle:SetTextColor(1, 0.82, 0)
    
    local optionalDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    optionalDesc:SetPoint("TOPLEFT", optionalTitle, "BOTTOMLEFT", 0, -5)
    optionalDesc:SetText("These protections can be toggled on or off:")
    optionalDesc:SetTextColor(0.8, 0.8, 0.8)
    
    --  Warbound until equipped protection (toggleable)
    local warboundCheck = CreateCheckbox(container, "Protect Warbound until Equipped Items", 
        "Prevents selling items marked 'Warbound until equipped' - valuable for gearing alts.", 
        "TOPLEFT", optionalDesc, "BOTTOMLEFT", 0, -15)
    
    warboundCheck:SetScript("OnClick", function(self)
        ScrappyDB.protectWarbound = self:GetChecked()
        Scrappy.QuietPrint("Warbound protection " .. (ScrappyDB.protectWarbound and "enabled" or "disabled"))
    end)
    
    --  Token protection (toggleable)
    local tokenCheck = CreateCheckbox(container, "Protect Gear Tokens and Set Pieces", 
        "Prevents selling tier tokens, set piece tokens, and other gear upgrade items.", 
        "TOPLEFT", warboundCheck, "BOTTOMLEFT", 0, -10)
    
    tokenCheck:SetScript("OnClick", function(self)
        ScrappyDB.protectTokens = self:GetChecked()
        Scrappy.QuietPrint("Token protection " .. (ScrappyDB.protectTokens and "enabled" or "disabled"))
    end)
    
    --  Material protections section
    local materialTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    materialTitle:SetPoint("TOPLEFT", tokenCheck, "BOTTOMLEFT", 0, -30)
    materialTitle:SetText("Crafting Material Protection")
    materialTitle:SetTextColor(1, 0.82, 0)
    
    local materialDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    materialDesc:SetPoint("TOPLEFT", materialTitle, "BOTTOMLEFT", 0, -5)
    materialDesc:SetText("Protect crafting materials from specific expansions:")
    materialDesc:SetTextColor(0.8, 0.8, 0.8)
    
    local materialChecks = {}
    local yOffset = -15
    
    local expansions = {
        {key = "tww", name = "The War Within"},
        {key = "dragonflight", name = "Dragonflight"},
        {key = "shadowlands", name = "Shadowlands"},
        {key = "bfa", name = "Battle for Azeroth"},
        {key = "legion", name = "Legion"},
        {key = "wod", name = "Warlords of Draenor"},
        {key = "mop", name = "Mists of Pandaria"},
        {key = "cata", name = "Cataclysm"},
        {key = "wotlk", name = "Wrath of the Lich King"},
        {key = "tbc", name = "The Burning Crusade"},
        {key = "classic", name = "Classic"}
    }
    
    --  Create two columns for better space usage
    local leftColumn = {}
    local rightColumn = {}
    
    for i, expansion in ipairs(expansions) do
        if i <= math.ceil(#expansions / 2) then
            table.insert(leftColumn, expansion)
        else
            table.insert(rightColumn, expansion)
        end
    end
    
    --  Left column
    local currentY = yOffset
    for i, expansion in ipairs(leftColumn) do
        local check = CreateCheckbox(container, expansion.name, 
            "Protect " .. expansion.name .. " crafting materials from being sold",
            "TOPLEFT", materialDesc, "BOTTOMLEFT", 20, currentY)
        
        check:SetScript("OnClick", function(self)
            ScrappyDB.materialFilters[expansion.key] = self:GetChecked()
            Scrappy.QuietPrint(expansion.name .. " materials: " .. (self:GetChecked() and "protected" or "not protected"))
        end)
        
        materialChecks[expansion.key] = check
        currentY = currentY - 25
    end
    
    --  Right column
    currentY = yOffset
    for i, expansion in ipairs(rightColumn) do
        local check = CreateCheckbox(container, expansion.name, 
            "Protect " .. expansion.name .. " crafting materials from being sold",
            "TOPLEFT", materialDesc, "BOTTOMLEFT", 320, currentY)
        
        check:SetScript("OnClick", function(self)
            ScrappyDB.materialFilters[expansion.key] = self:GetChecked()
            Scrappy.QuietPrint(expansion.name .. " materials: " .. (self:GetChecked() and "protected" or "not protected"))
        end)
        
        materialChecks[expansion.key] = check
        currentY = currentY - 25
    end
    
    container.materialChecks = materialChecks
    container.warboundCheck = warboundCheck
    container.tokenCheck = tokenCheck
    return container
end

--  Switch between tabs
function Scrappy.SettingsUI.SwitchTab(tabId)
    local frame = _G["ScrappySettingsFrame"]
    if not frame then return end
    
    activeTab = tabId
    
    --  Update tab appearances
    for id, tab in pairs(frame.tabs) do
        if id == tabId then
            tab:SetBackdropColor(0.2, 0.4, 0.8, 1)
            tab.text:SetTextColor(1, 1, 1)
        else
            tab:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            tab.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end
    
    --  Hide all tab content
    if frame.generalTab then frame.generalTab:Hide() end
    if frame.filtersTab then frame.filtersTab:Hide() end
    if frame.protectionsTab then frame.protectionsTab:Hide() end
    
    --  Show active tab content
    if tabId == "general" and frame.generalTab then
        frame.generalTab:Show()
    elseif tabId == "filters" and frame.filtersTab then
        frame.filtersTab:Show()
    elseif tabId == "protections" and frame.protectionsTab then
        frame.protectionsTab:Show()
    end
    
    --  Refresh UI to update values
    Scrappy.SettingsUI.RefreshUI()
end

--  Create the complete tabbed UI
function Scrappy.SettingsUI.CreateUI()
    local frame = CreateSettingsFrame()
    
    --  Create tab buttons
    frame.tabs = CreateTabButtons(frame)
    
    --  Create content area
    frame.content = CreateContentArea(frame)
    
    --  Create tab content
    frame.generalTab = CreateGeneralTab(frame.content)
    frame.filtersTab = CreateFiltersTab(frame.content)
    frame.protectionsTab = CreateProtectionsTab(frame.content)
    
    --  Create action buttons outside of tabs (always visible and centered)
    local buttonWidths = {120, 120, 140}  -- Test Selling, Analyze Gear, Reset to Defaults
    local buttonSpacing = 10
    local totalButtonWidth = buttonWidths[1] + buttonWidths[2] + buttonWidths[3] + (buttonSpacing * 2)
    local startButtonX = (700 - totalButtonWidth) / 2  -- Center the buttons in the 700px wide frame
    
    local testButton = CreateButton(frame, "Test Selling", 
        "Preview what items would be sold without actually selling them",
        "BOTTOMLEFT", frame, "BOTTOMLEFT", startButtonX, 30, buttonWidths[1], 25)
    testButton:SetScript("OnClick", function()
        if Scrappy.Config and Scrappy.Config.TestSelling then
            Scrappy.Config.TestSelling()
        else
            Scrappy.Print("Test function not available")
        end
    end)
    
    local gearButton = CreateButton(frame, "Analyze Gear", 
        "Show detailed analysis of your equipped gear and thresholds",
        "LEFT", testButton, "RIGHT", buttonSpacing, 0, buttonWidths[2], 25)
    gearButton:SetScript("OnClick", function()
        if Scrappy.Gear and Scrappy.Gear.ShowGearAnalysis then
            Scrappy.Gear.ShowGearAnalysis()
        else
            Scrappy.Print("Gear analysis not available")
        end
    end)
    
    local resetButton = CreateButton(frame, "Reset to Defaults", 
        "Reset all settings to safe default values",
        "LEFT", gearButton, "RIGHT", buttonSpacing, 0, buttonWidths[3], 25)
    resetButton:SetScript("OnClick", function()
        Scrappy.SettingsUI.ResetToDefaults()
    end)
    
    --  Initially hide all tabs except general
    frame.filtersTab:Hide()
    frame.protectionsTab:Hide()
    
    --  Set initial active tab
    Scrappy.SettingsUI.SwitchTab("general")
    
    return frame
end

--  Refresh UI to match current settings
function Scrappy.SettingsUI.RefreshUI()
    local frame = _G["ScrappySettingsFrame"]
    if not frame or not ScrappyDB then return end
    
    --  Refresh General tab
    if frame.generalTab then
        frame.generalTab.autoSellCheck:SetChecked(ScrappyDB.autoSell or false)
        frame.generalTab.quietModeCheck:SetChecked(ScrappyDB.quietMode or false)
        frame.generalTab.autoConfirmCheck:SetChecked(ScrappyDB.autoConfirmSoulbound ~= false)
        frame.generalTab.autoThresholdCheck:SetChecked(ScrappyDB.autoThreshold or false)
        
        --  Update sliders
        if ScrappyDB.autoThreshold then
            --  When auto-threshold is on, show the current equipped average
            if Scrappy.Gear and Scrappy.Gear.GetEquippedAverageItemLevel then
                local avgIlvl = Scrappy.Gear.GetEquippedAverageItemLevel()
                frame.generalTab.ilvlSlider:SetValue(math.floor(avgIlvl))
            else
                frame.generalTab.ilvlSlider:SetValue(ScrappyDB.ilvlThreshold or 0)
            end
        else
            --  When auto-threshold is off, show the manual setting
            frame.generalTab.ilvlSlider:SetValue(ScrappyDB.ilvlThreshold or 0)
        end
        
        frame.generalTab.ilvlSlider:SetEnabled(not ScrappyDB.autoThreshold)
        frame.generalTab.ilvlSlider.title:SetTextColor(ScrappyDB.autoThreshold and 0.5 or 1, 
                                           ScrappyDB.autoThreshold and 0.5 or 1, 
                                           ScrappyDB.autoThreshold and 0.5 or 1)
        
        frame.generalTab.offsetSlider:SetValue(ScrappyDB.autoThresholdOffset or -10)
        frame.generalTab.offsetSlider:SetEnabled(ScrappyDB.autoThreshold or false)
        frame.generalTab.offsetSlider.title:SetTextColor(ScrappyDB.autoThreshold and 1 or 0.5, 
                                             ScrappyDB.autoThreshold and 1 or 0.5, 
                                             ScrappyDB.autoThreshold and 1 or 0.5)
        
        --  Update selling order dropdown
        if frame.generalTab.orderDropdown then
            local orderText = "Default Order"
            if ScrappyDB.sellOrder == "value" then
                orderText = "Low to High Value"
            elseif ScrappyDB.sellOrder == "quality" then
                orderText = "Junk to Epic Quality"
            end
            UIDropDownMenu_SetText(frame.generalTab.orderDropdown, orderText)
        end
    end
    
    --  Refresh Filters tab
    if frame.filtersTab and frame.filtersTab.qualityChecks then
        for quality = 0, 4 do
            if frame.filtersTab.qualityChecks[quality] then
                local enabled = ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[quality]
                frame.filtersTab.qualityChecks[quality]:SetChecked(enabled or false)
            end
        end
    end
    
    --  Refresh Protections tab
    if frame.protectionsTab then
        --  Update Warbound and Token protection checkboxes
        if frame.protectionsTab.warboundCheck then
            frame.protectionsTab.warboundCheck:SetChecked(ScrappyDB.protectWarbound or false)
        end
        if frame.protectionsTab.tokenCheck then
            frame.protectionsTab.tokenCheck:SetChecked(ScrappyDB.protectTokens or false)
        end
        
        --  Update material protection checkboxes
        if frame.protectionsTab.materialChecks then
            for expansion, check in pairs(frame.protectionsTab.materialChecks) do
                local enabled = ScrappyDB.materialFilters and ScrappyDB.materialFilters[expansion]
                check:SetChecked(enabled or false)
            end
        end
    end
end

--  Reset settings to safe defaults
function Scrappy.SettingsUI.ResetToDefaults()
    ScrappyDB.autoSell = false
    ScrappyDB.quietMode = false
    ScrappyDB.autoConfirmSoulbound = true
    ScrappyDB.autoThreshold = false
    ScrappyDB.ilvlThreshold = 0
    ScrappyDB.autoThresholdOffset = -10
    ScrappyDB.sellConsumables = false
    ScrappyDB.protectWarbound = false  -- Default: don't protect Warbound items
    ScrappyDB.protectTokens = true     -- Default: protect gear tokens (they're valuable)
    ScrappyDB.sellOrder = "default"    -- Default: sell in bag order
    
    ScrappyDB.qualityFilter = {
        [0] = true,  -- Junk
        [1] = true,  -- Common
        [2] = true,  -- Uncommon
        [3] = false, -- Rare
        [4] = false  -- Epic
    }
    
    ScrappyDB.materialFilters = {
        classic = false, tbc = false, wotlk = false, cata = false, mop = false,
        wod = false, legion = false, bfa = false, shadowlands = false, 
        dragonflight = false, tww = false
    }
    
    Scrappy.Print("Settings reset to defaults")
    Scrappy.SettingsUI.RefreshUI()
end

--  Test function to verify module is working
function Scrappy.SettingsUI.Test()
    Scrappy.Print("SettingsUI.Test() called successfully!")
    return true
end

--  Show the settings UI
function Scrappy.SettingsUI.Show()
    local frame = _G["ScrappySettingsFrame"]
    if not frame then
        frame = Scrappy.SettingsUI.CreateUI()
    end
    
    Scrappy.SettingsUI.RefreshUI()
    frame:Show()
end

--  Hide the settings UI
function Scrappy.SettingsUI.Hide()
    local frame = _G["ScrappySettingsFrame"]
    if frame then
        frame:Hide()
    end
end