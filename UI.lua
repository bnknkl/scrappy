-- UI.lua - User interface components

--  Get reference to our addon namespace
local Scrappy = _G["Scrappy"]

--  This function creates the sell button on the merchant frame
function Scrappy.UI.CreateScrappyButton()
    --  Prevent creating multiple buttons
    if _G["ScrappySellButton"] then return end
    
    --  Validate that MerchantFrame exists
    if not MerchantFrame then
        Scrappy.Print("Error: Could not create sell button - MerchantFrame not found")
        return
    end

    --  Create the sell button
    local button = CreateFrame("Button", "ScrappySellButton", MerchantFrame, "UIPanelButtonTemplate")
    if not button then
        Scrappy.Print("Error: Could not create sell button")
        return
    end
    
    button:SetSize(32, 32)
    
    --  Protected positioning in case MerchantFrameTab2 doesn't exist
    if MerchantFrameTab2 then
        button:SetPoint("LEFT", MerchantFrameTab2, "RIGHT", 10, 0)
    else
        button:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -10, 10)
    end

    --  Add an icon to make the button's purpose clear
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\ICONS\\INV_Misc_Coin_01")

    --  Set up the click handler with error protection
    button:SetScript("OnClick", function()
        local success, errorMsg = pcall(Scrappy.Core.SellItems)
        if not success then
            Scrappy.Print("Error during selling: " .. (errorMsg or "Unknown error"))
        end
    end)

    --  Show detailed tooltip on hover
    button:SetScript("OnEnter", function(self)
        local success, errorMsg = pcall(Scrappy.UI.ShowSellTooltip, self)
        if not success then
            --  Fallback tooltip if detailed one fails
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Sell with Scrappy")
            GameTooltip:AddLine("Error loading item preview", 1, 0, 0)
            GameTooltip:Show()
        end
    end)

    --  Hide tooltip when mouse leaves
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    --  Create settings button
    local settingsButton = CreateFrame("Button", "ScrappySettingsButton", MerchantFrame, "UIPanelButtonTemplate")
    settingsButton:SetSize(32, 32)
    settingsButton:SetPoint("LEFT", button, "RIGHT", 5, 0)
    
    --  Settings icon
    local settingsIcon = settingsButton:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetAllPoints()
    settingsIcon:SetTexture("Interface\\ICONS\\Trade_Engineering")
    
    --  Settings button functionality
    settingsButton:SetScript("OnClick", function()
        Scrappy.SettingsUI.Show()
    end)
    
    settingsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Scrappy Settings")
        GameTooltip:AddLine("Click to open the settings panel", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    settingsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

--  Separate function for tooltip logic makes it easier to maintain
function Scrappy.UI.ShowSellTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sell with Scrappy")

    local items = Scrappy.Core.GetItemsToSell()
    local cacheInfo = items._cacheInfo
    
    --  Remove metadata before processing items
    items._cacheInfo = nil

    if #items == 0 then
        GameTooltip:AddLine("Nothing to sell.", 1, 1, 1)
        if cacheInfo and cacheInfo.pendingItems > 0 then
            GameTooltip:AddLine("(" .. cacheInfo.pendingItems .. " items still loading)", 0.7, 0.7, 0.7)
        end
        
        --  Show threshold info even when no items to sell
        if ScrappyDB.autoThreshold then
            local avgIlvl = Scrappy.Gear.GetEquippedAverageItemLevel()
            GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
            GameTooltip:AddLine("Auto-threshold: " .. (ScrappyDB.ilvlThreshold or 0), 0.7, 0.7, 1)
            GameTooltip:AddLine("(Based on avg ilvl " .. string.format("%.0f", avgIlvl) .. ")", 0.5, 0.5, 0.8)
        elseif ScrappyDB.ilvlThreshold and ScrappyDB.ilvlThreshold > 0 then
            GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
            GameTooltip:AddLine("Manual threshold: " .. ScrappyDB.ilvlThreshold, 0.7, 0.7, 1)
        end
        
        --  Show consumable protection status
        GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
        if ScrappyDB.sellConsumables then
            GameTooltip:AddLine("Consumables: CAN BE SOLD", 1, 0.5, 0.5)
        else
            GameTooltip:AddLine("Consumables: PROTECTED", 0.5, 1, 0.5)
        end
        GameTooltip:AddLine("Profession Tools: PROTECTED", 0.5, 1, 0.5)
    else
        --  Show selling status if operation is in progress
        local sellStatus = Scrappy.Recovery.GetSellStatus()
        if sellStatus.inProgress then
            GameTooltip:AddLine("Selling in progress...", 1, 1, 0)
            GameTooltip:AddLine(sellStatus.queuedItems .. " items remaining", 0.7, 0.7, 0.7)
        end
        
        --  Group items by quality for better organization
        local groups = {}
        for _, item in ipairs(items) do
            local quality = item.quality or 0
            groups[quality] = groups[quality] or {}
            table.insert(groups[quality], item)
        end

        --  Show items organized by quality, sorted by item level
        for quality = 0, 4 do
            local group = groups[quality]
            if group then
                --  Sort by item level within each quality group
                table.sort(group, function(a, b)
                    return (tonumber(a.ilvl) or 0) < (tonumber(b.ilvl) or 0)
                end)

                local qualityName = Scrappy.QUALITY_NAMES[quality] or ("Quality " .. quality)
                local color = Scrappy.QUALITY_COLORS[quality] or {r=1, g=1, b=1}
                GameTooltip:AddLine(qualityName .. ":", color.r, color.g, color.b)

                for _, item in ipairs(group) do
                    local ilvl = tonumber(item.ilvl) or "?"
                    local itemName = item.name or ("ItemID " .. item.itemID)
                    GameTooltip:AddLine("  ilvl " .. ilvl .. " - " .. itemName, 1, 1, 1)
                end
            end
        end
        
        --  Show cache status if there are pending items
        if cacheInfo and cacheInfo.pendingItems > 0 then
            GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
            GameTooltip:AddLine("(" .. cacheInfo.pendingItems .. " items still loading)", 0.7, 0.7, 0.7)
        end
        
        --  Show failed items if any
        if sellStatus.failedItems > 0 then
            GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
            GameTooltip:AddLine(sellStatus.failedItems .. " items failed to sell", 1, 0.5, 0.5)
            GameTooltip:AddLine("Type /scrappy retry to try again", 0.7, 0.7, 0.7)
        end
    end

    GameTooltip:Show()
end