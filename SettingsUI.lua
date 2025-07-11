-- SettingsUI.lua - Graphical settings interface with tabbed layout

-- WHY: Get reference to our addon namespace
local Scrappy = _G["Scrappy"]

-- WHY: Ensure SettingsUI module exists
if not Scrappy.SettingsUI then
    Scrappy.SettingsUI = {}
end

-- WHY: Local references to avoid dependency issues
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

-- WHY: Current maximum item level in the game
local CURRENT_MAX_ILVL = 717

-- WHY: Tab definitions
local TABS = {
    {id = "general", name = "General", icon = "Interface\\ICONS\\Trade_Engineering"},
    {id = "filters", name = "Filters", icon = "Interface\\ICONS\\INV_Misc_Gear_01"},
    {id = "protections", name = "Protections", icon = "Interface\\ICONS\\Spell_Holy_DivineProtection"}
}

-- WHY: Currently active tab
local activeTab = "general"

-- WHY: Create the main settings frame
local function CreateSettingsFrame()
    local frame = CreateFrame("Frame", "ScrappySettingsFrame", UIParent, "BackdropTemplate")
    frame.name = "Scrappy"
    frame:Hide()
    
    -- WHY: Make it larger to accommodate tabs
    frame:SetSize(700, 650)
    frame:SetPoint("CENTER")
    
    -- WHY: Add background using modern backdrop API
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    
    -- WHY: Make it movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- WHY: Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetText("Scrappy Settings")
    
    -- WHY: Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    return frame
end

-- WHY: Create tab buttons
local function CreateTabButtons(parent)
    local tabs = {}
    local tabWidth = 120
    local tabHeight = 32
    local startX = 50
    
    for i, tabInfo in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
        tab:SetSize(tabWidth, tabHeight)
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", startX + (i-1) * (tabWidth + 5), -50)
        
        -- WHY: Tab backdrop
        tab:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        
        -- WHY: Tab icon
        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", tab, "LEFT", 8, 0)
        icon:SetTexture(tabInfo.icon)
        
        -- WHY: Tab text
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        text:SetText(tabInfo.name)
        
        -- WHY: Tab click handler
        tab:SetScript("OnClick", function()
            Scrappy.SettingsUI.SwitchTab(tabInfo.id)
        end)
        
        -- WHY: Hover effects
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

-- WHY: Create content area for tab content
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

-- WHY: Helper functions for UI elements
local function CreateCheckbox(parent, name, tooltip, point, relativeFrame, relativePoint, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint(point, relativeFrame, relativePoint, x, y)
    checkbox.Text:SetText(name)
    
    if tooltip then
        checkbox.tooltipText = tooltip
        checkbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return checkbox
end

local function CreateSlider(parent, name, tooltip, minVal, maxVal, point, relativeFrame, relativePoint, x, y)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint(point, relativeFrame, relativePoint, x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    
    -- WHY: Title and value display
    slider.title = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slider.title:SetPoint("BOTTOM", slider, "TOP", 0, 5)
    slider.title:SetText(name)
    
    slider.valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slider.valueText:SetPoint("TOP", slider.title, "BOTTOM", 0, -5)
    
    -- WHY: Remove the default low/high labels
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
    local button = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    button:SetSize(width or 120, height or 25)
    button:SetPoint(point, relativeFrame, relativePoint, x, y)
    button:SetText(text)
    
    if tooltip then
        button.tooltipText = tooltip
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return button
end

-- WHY: Create General tab content
local function CreateGeneralTab(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()
    
    -- WHY: Auto-sell checkbox
    local autoSellCheck = CreateCheckbox(container, "Enable Auto-Sell", 
        "Automatically sell items when visiting a vendor", 
        "TOPLEFT", container, "TOPLEFT", 20, -20)
    
    autoSellCheck:SetScript("OnClick", function(self)
        ScrappyDB.autoSell = self:GetChecked()
        Scrappy.QuietPrint("Auto-sell " .. (ScrappyDB.autoSell and "enabled" or "disabled"))
    end)
    
    -- WHY: Quiet mode checkbox
    local quietModeCheck = CreateCheckbox(container, "Quiet Mode", 
        "Reduce chat messages when making changes in the UI", 
        "TOPLEFT", autoSellCheck, "BOTTOMLEFT", 0, -10)
    
    quietModeCheck:SetScript("OnClick", function(self)
        ScrappyDB.quietMode = self:GetChecked()
        Scrappy.Print("Quiet mode " .. (ScrappyDB.quietMode and "enabled - UI changes will be silent" or "disabled - UI changes will show messages"))
    end)
    
    -- WHY: Auto-confirm soulbound dialogs
    local autoConfirmCheck = CreateCheckbox(container, "Auto-Confirm Soulbound Dialogs", 
        "Automatically confirm 'item will become soulbound' dialogs during selling for smoother operation.", 
        "TOPLEFT", quietModeCheck, "BOTTOMLEFT", 0, -10)
    
    autoConfirmCheck:SetScript("OnClick", function(self)
        ScrappyDB.autoConfirmSoulbound = self:GetChecked()
        Scrappy.QuietPrint("Auto-confirm soulbound dialogs " .. (ScrappyDB.autoConfirmSoulbound and "enabled" or "disabled"))
    end)
    
    -- WHY: Auto-threshold section
    local thresholdTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    thresholdTitle:SetPoint("TOPLEFT", autoConfirmCheck, "BOTTOMLEFT", 0, -30)
    thresholdTitle:SetText("Item Level Thresholds")
    thresholdTitle:SetTextColor(1, 0.82, 0)
    
    -- WHY: Auto-threshold checkbox
    local autoThresholdCheck = CreateCheckbox(container, "Auto Item Level Threshold", 
        "Automatically set sell threshold based on your equipped gear", 
        "TOPLEFT", thresholdTitle, "BOTTOMLEFT", 0, -10)
    
    autoThresholdCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if Scrappy.Gear and Scrappy.Gear.EnableAutoThreshold then
                Scrappy.Gear.EnableAutoThreshold()
            else
                ScrappyDB.autoThreshold = true
                Scrappy.QuietPrint("Auto-threshold enabled (gear module not loaded)")
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
    
    -- WHY: Manual ilvl threshold slider
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
    
    -- WHY: Auto-threshold offset slider
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
    
    -- WHY: Action buttons
    local buttonY = -350
    local testButton = CreateButton(container, "Test Selling", 
        "Preview what items would be sold without actually selling them",
        "TOPLEFT", container, "TOPLEFT", 20, buttonY, 120, 25)
    testButton:SetScript("OnClick", function()
        if Scrappy.Config and Scrappy.Config.TestSelling then
            Scrappy.Config.TestSelling()
        else
            Scrappy.Print("Test function not available")
        end
    end)
    
    local gearButton = CreateButton(container, "Analyze Gear", 
        "Show detailed analysis of your equipped gear and thresholds",
        "LEFT", testButton, "RIGHT", 10, 0, 120, 25)
    gearButton:SetScript("OnClick", function()
        if Scrappy.Gear and Scrappy.Gear.ShowGearAnalysis then
            Scrappy.Gear.ShowGearAnalysis()
        else
            Scrappy.Print("Gear analysis not available")
        end
    end)
    
    local resetButton = CreateButton(container, "Reset to Defaults", 
        "Reset all settings to safe default values",
        "LEFT", gearButton, "RIGHT", 10, 0, 140, 25)
    resetButton:SetScript("OnClick", function()
        Scrappy.SettingsUI.ResetToDefaults()
    end)
    
    -- WHY: Store references for refreshing
    container.autoSellCheck = autoSellCheck
    container.quietModeCheck = quietModeCheck
    container.autoConfirmCheck = autoConfirmCheck
    container.autoThresholdCheck = autoThresholdCheck
    container.ilvlSlider = ilvlSlider
    container.offsetSlider = offsetSlider
    
    return container
end

-- WHY: Create Filters tab content
local function CreateFiltersTab(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()
    
    -- WHY: Quality filters section
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
        
        -- WHY: Color the text
        check.Text:SetTextColor(color.r, color.g, color.b)
        
        check:SetScript("OnClick", function(self)
            if not ScrappyDB.qualityFilter then
                ScrappyDB.protectWarbound = false  -- Default: don't protect Warbound items
    
    ScrappyDB.qualityFilter = {}
            end
            ScrappyDB.qualityFilter[quality] = self:GetChecked()
            Scrappy.QuietPrint("Quality " .. qualityName .. ": " .. (self:GetChecked() and "sell" or "keep"))
        end)
        
        qualityChecks[quality] = check
        yOffset = yOffset - 30
    end
    
    -- WHY: Future filter sections can be added here
    local futureTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    futureTitle:SetPoint("TOPLEFT", container, "TOPLEFT", 350, -20)
    futureTitle:SetText("Advanced Filters")
    futureTitle:SetTextColor(1, 0.82, 0)
    
    local futureDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    futureDesc:SetPoint("TOPLEFT", futureTitle, "BOTTOMLEFT", 0, -5)
    futureDesc:SetText("Additional filter options (coming soon):")
    futureDesc:SetTextColor(0.8, 0.8, 0.8)
    
    -- WHY: Placeholder for future filters
    local placeholderText = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    placeholderText:SetPoint("TOPLEFT", futureDesc, "BOTTOMLEFT", 0, -20)
    placeholderText:SetText("• Vendor Value Filters\n• Item Age Filters\n• Custom Name Patterns\n• Bind-on-Equip Filters")
    placeholderText:SetTextColor(0.6, 0.6, 0.6)
    
    -- WHY: Action buttons
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

-- WHY: Create Protections tab content
local function CreateProtectionsTab(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()
    
    -- WHY: Always-on protections section
    local alwaysTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    alwaysTitle:SetPoint("TOPLEFT", container, "TOPLEFT", 20, -20)
    alwaysTitle:SetText("Always Protected")
    alwaysTitle:SetTextColor(0.5, 1, 0.5)
    
    local alwaysDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    alwaysDesc:SetPoint("TOPLEFT", alwaysTitle, "BOTTOMLEFT", 0, -5)
    alwaysDesc:SetText("These items are always protected and cannot be sold:")
    alwaysDesc:SetTextColor(0.8, 0.8, 0.8)
    
    -- WHY: Consumable protection (always checked, disabled)
    local consumableCheck = CreateCheckbox(container, "Consumables (Flasks, Potions, Food)", 
        "Prevents selling flasks, potions, food, etc. This protection cannot be disabled for safety.", 
        "TOPLEFT", alwaysDesc, "BOTTOMLEFT", 0, -15)
    consumableCheck:SetChecked(true)
    consumableCheck:Disable()
    
    -- WHY: Profession equipment protection (always checked, disabled)
    local professionCheck = CreateCheckbox(container, "Profession Equipment (Tools, Mining Picks, etc.)", 
        "Prevents selling profession tools, mining picks, skinning knives, etc. This protection cannot be disabled for safety.", 
        "TOPLEFT", consumableCheck, "BOTTOMLEFT", 0, -10)
    professionCheck:SetChecked(true)
    professionCheck:Disable()
    
    -- WHY: Warbound until equipped protection (toggleable)
    local warboundCheck = CreateCheckbox(container, "Protect Warbound until Equipped Items", 
        "Prevents selling items marked 'Warbound until equipped' - valuable for gearing alts.", 
        "TOPLEFT", professionCheck, "BOTTOMLEFT", 0, -10)
    
    warboundCheck:SetScript("OnClick", function(self)
        ScrappyDB.protectWarbound = self:GetChecked()
        Scrappy.QuietPrint("Warbound protection " .. (ScrappyDB.protectWarbound and "enabled" or "disabled"))
    end)
    
    -- WHY: Material protections section
    local materialTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    materialTitle:SetPoint("TOPLEFT", warboundCheck, "BOTTOMLEFT", 0, -30)
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
    
    -- WHY: Create two columns for better space usage
    local leftColumn = {}
    local rightColumn = {}
    
    for i, expansion in ipairs(expansions) do
        if i <= math.ceil(#expansions / 2) then
            table.insert(leftColumn, expansion)
        else
            table.insert(rightColumn, expansion)
        end
    end
    
    -- WHY: Left column
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
    
    -- WHY: Right column
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
    
    -- WHY: Future protections section
    local futureTitle = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    futureTitle:SetPoint("TOPLEFT", container, "TOPLEFT", 20, -420)
    futureTitle:SetText("Additional Protections")
    futureTitle:SetTextColor(1, 0.82, 0)
    
    local futureDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    futureDesc:SetPoint("TOPLEFT", futureTitle, "BOTTOMLEFT", 0, -5)
    futureDesc:SetText("Future protection options (coming soon):")
    futureDesc:SetTextColor(0.8, 0.8, 0.8)
    
    local futurePlaceholder = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    futurePlaceholder:SetPoint("TOPLEFT", futureDesc, "BOTTOMLEFT", 0, -15)
    futurePlaceholder:SetText("• Custom Item Whitelist\n• Transmog Appearance Protection\n• Recently Acquired Item Protection\n• High-Value Item Warnings")
    futurePlaceholder:SetTextColor(0.6, 0.6, 0.6)
    
    container.materialChecks = materialChecks
    container.warboundCheck = warboundCheck
    return container
end

-- WHY: Switch between tabs
function Scrappy.SettingsUI.SwitchTab(tabId)
    local frame = _G["ScrappySettingsFrame"]
    if not frame then return end
    
    activeTab = tabId
    
    -- WHY: Update tab appearances
    for id, tab in pairs(frame.tabs) do
        if id == tabId then
            tab:SetBackdropColor(0.2, 0.4, 0.8, 1)
            tab.text:SetTextColor(1, 1, 1)
        else
            tab:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            tab.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end
    
    -- WHY: Hide all tab content
    if frame.generalTab then frame.generalTab:Hide() end
    if frame.filtersTab then frame.filtersTab:Hide() end
    if frame.protectionsTab then frame.protectionsTab:Hide() end
    
    -- WHY: Show active tab content
    if tabId == "general" and frame.generalTab then
        frame.generalTab:Show()
    elseif tabId == "filters" and frame.filtersTab then
        frame.filtersTab:Show()
    elseif tabId == "protections" and frame.protectionsTab then
        frame.protectionsTab:Show()
    end
    
    -- WHY: Refresh UI to update values
    Scrappy.SettingsUI.RefreshUI()
end

-- WHY: Create the complete tabbed UI
function Scrappy.SettingsUI.CreateUI()
    local frame = CreateSettingsFrame()
    
    -- WHY: Create tab buttons
    frame.tabs = CreateTabButtons(frame)
    
    -- WHY: Create content area
    frame.content = CreateContentArea(frame)
    
    -- WHY: Create tab content
    frame.generalTab = CreateGeneralTab(frame.content)
    frame.filtersTab = CreateFiltersTab(frame.content)
    frame.protectionsTab = CreateProtectionsTab(frame.content)
    
    -- WHY: Initially hide all tabs except general
    frame.filtersTab:Hide()
    frame.protectionsTab:Hide()
    
    -- WHY: Set initial active tab
    Scrappy.SettingsUI.SwitchTab("general")
    
    return frame
end

-- WHY: Refresh UI to match current settings
function Scrappy.SettingsUI.RefreshUI()
    local frame = _G["ScrappySettingsFrame"]
    if not frame or not ScrappyDB then return end
    
    -- WHY: Refresh General tab
    if frame.generalTab then
        frame.generalTab.autoSellCheck:SetChecked(ScrappyDB.autoSell or false)
        frame.generalTab.quietModeCheck:SetChecked(ScrappyDB.quietMode or false)
        frame.generalTab.autoConfirmCheck:SetChecked(ScrappyDB.autoConfirmSoulbound ~= false)
        frame.generalTab.autoThresholdCheck:SetChecked(ScrappyDB.autoThreshold or false)
        
        -- WHY: Update sliders
        frame.generalTab.ilvlSlider:SetValue(ScrappyDB.ilvlThreshold or 0)
        frame.generalTab.ilvlSlider:SetEnabled(not ScrappyDB.autoThreshold)
        frame.generalTab.ilvlSlider.title:SetTextColor(ScrappyDB.autoThreshold and 0.5 or 1, 
                                           ScrappyDB.autoThreshold and 0.5 or 1, 
                                           ScrappyDB.autoThreshold and 0.5 or 1)
        
        frame.generalTab.offsetSlider:SetValue(ScrappyDB.autoThresholdOffset or -10)
        frame.generalTab.offsetSlider:SetEnabled(ScrappyDB.autoThreshold or false)
        frame.generalTab.offsetSlider.title:SetTextColor(ScrappyDB.autoThreshold and 1 or 0.5, 
                                             ScrappyDB.autoThreshold and 1 or 0.5, 
                                             ScrappyDB.autoThreshold and 1 or 0.5)
    end
    
    -- WHY: Refresh Filters tab
    if frame.filtersTab and frame.filtersTab.qualityChecks then
        for quality = 0, 4 do
            if frame.filtersTab.qualityChecks[quality] then
                local enabled = ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[quality]
                frame.filtersTab.qualityChecks[quality]:SetChecked(enabled or false)
            end
        end
    end
    
    -- WHY: Refresh Protections tab
    if frame.protectionsTab and frame.protectionsTab.materialChecks then
        -- WHY: Update Warbound protection checkbox
        if frame.protectionsTab.warboundCheck then
            frame.protectionsTab.warboundCheck:SetChecked(ScrappyDB.protectWarbound or false)
        end
        
        -- WHY: Update material protection checkboxes
        for expansion, check in pairs(frame.protectionsTab.materialChecks) do
            local enabled = ScrappyDB.materialFilters and ScrappyDB.materialFilters[expansion]
            check:SetChecked(enabled or false)
        end
    end
end

-- WHY: Reset settings to safe defaults
function Scrappy.SettingsUI.ResetToDefaults()
    ScrappyDB.autoSell = false
    ScrappyDB.quietMode = false
    ScrappyDB.autoConfirmSoulbound = true
    ScrappyDB.autoThreshold = false
    ScrappyDB.ilvlThreshold = 0
    ScrappyDB.autoThresholdOffset = -10
    ScrappyDB.sellConsumables = false
    
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

-- WHY: Test function to verify module is working
function Scrappy.SettingsUI.Test()
    Scrappy.Print("SettingsUI.Test() called successfully!")
    return true
end

-- WHY: Show the settings UI
function Scrappy.SettingsUI.Show()
    local frame = _G["ScrappySettingsFrame"]
    if not frame then
        frame = Scrappy.SettingsUI.CreateUI()
    end
    
    Scrappy.SettingsUI.RefreshUI()
    frame:Show()
end

-- WHY: Hide the settings UI
function Scrappy.SettingsUI.Hide()
    local frame = _G["ScrappySettingsFrame"]
    if frame then
        frame:Hide()
    end
end