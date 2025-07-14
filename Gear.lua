-- Gear.lua - Gear analysis and auto-threshold system

--  Get reference to our addon namespace
local Scrappy = _G["Scrappy"]
Scrappy.Gear = {}

--  Equipment slot constants
local EQUIPMENT_SLOTS = {
    [1] = "HeadSlot",           -- Head
    [2] = "NeckSlot",           -- Neck  
    [3] = "ShoulderSlot",       -- Shoulder
    [5] = "ChestSlot",          -- Chest
    [6] = "WaistSlot",          -- Waist
    [7] = "LegsSlot",           -- Legs
    [8] = "FeetSlot",           -- Feet
    [9] = "WristSlot",          -- Wrist
    [10] = "HandsSlot",         -- Hands
    [11] = "Finger0Slot",       -- Ring 1
    [12] = "Finger1Slot",       -- Ring 2
    [13] = "Trinket0Slot",      -- Trinket 1
    [14] = "Trinket1Slot",      -- Trinket 2
    [15] = "BackSlot",          -- Back
    [16] = "MainHandSlot",      -- Main Hand
    [17] = "SecondaryHandSlot", -- Off Hand
    [18] = "RangedSlot",        -- Ranged
}

--  Get item level for equipped item in specific slot
local function GetEquippedItemLevel(slotId)
    local itemLink = GetInventoryItemLink("player", slotId)
    if not itemLink then return nil end
    
    --  Extract item level from tooltip (most reliable method)
    local itemLevel = GetDetailedItemLevelInfo(itemLink)
    if itemLevel and itemLevel > 0 then
        return itemLevel
    end
    
    --  Fallback to GetItemInfo if detailed info fails
    local _, _, _, ilvl = GetItemInfo(itemLink)
    return ilvl
end

--  Calculate average item level of equipped gear
function Scrappy.Gear.GetEquippedAverageItemLevel()
    local totalItemLevel = 0
    local itemCount = 0
    local gearBreakdown = {}
    
    for slotId, slotName in pairs(EQUIPMENT_SLOTS) do
        local ilvl = GetEquippedItemLevel(slotId)
        if ilvl and ilvl > 0 then
            totalItemLevel = totalItemLevel + ilvl
            itemCount = itemCount + 1
            
            --  Store breakdown for debugging
            table.insert(gearBreakdown, {
                slot = slotName,
                ilvl = ilvl
            })
        end
    end
    
    local averageIlvl = itemCount > 0 and (totalItemLevel / itemCount) or 0
    
    return averageIlvl, gearBreakdown, itemCount
end

--  Calculate what the auto-threshold should be
function Scrappy.Gear.CalculateAutoThreshold()
    if not ScrappyDB then return 0 end
    
    local averageIlvl = Scrappy.Gear.GetEquippedAverageItemLevel()
    local offset = ScrappyDB.autoThresholdOffset or -10
    
    --  Don't go below 0, and round to nearest 5 for cleaner numbers
    local threshold = math.max(0, averageIlvl + offset)
    threshold = math.floor(threshold / 5) * 5  -- Round to nearest 5
    
    return threshold
end

--  Update the item level threshold based on equipped gear
function Scrappy.Gear.UpdateAutoThreshold()
    if not ScrappyDB or not ScrappyDB.autoThreshold then return end
    
    local newThreshold = Scrappy.Gear.CalculateAutoThreshold()
    local oldThreshold = ScrappyDB.ilvlThreshold or 0
    
    if newThreshold ~= oldThreshold then
        ScrappyDB.ilvlThreshold = newThreshold
        Scrappy.QuietPrint("Auto-threshold updated: " .. oldThreshold .. " -> " .. newThreshold .. " (based on your equipped gear)")
        return true
    end
    
    return false
end

--  Enable auto-threshold system
function Scrappy.Gear.EnableAutoThreshold(offset)
    if not ScrappyDB then return end
    
    ScrappyDB.autoThreshold = true
    if offset then
        ScrappyDB.autoThresholdOffset = offset
    end
    
    --  Immediately update threshold
    Scrappy.Gear.UpdateAutoThreshold()
    
    local avgIlvl, _, itemCount = Scrappy.Gear.GetEquippedAverageItemLevel()
    Scrappy.QuietPrint("Auto-threshold enabled!")
    Scrappy.QuietPrint("Your average equipped ilvl: " .. string.format("%.1f", avgIlvl) .. " (" .. itemCount .. " items)")
    Scrappy.QuietPrint("Threshold offset: " .. (ScrappyDB.autoThresholdOffset or -10))
    Scrappy.QuietPrint("Current sell threshold: " .. (ScrappyDB.ilvlThreshold or 0))
end

--  Disable auto-threshold system
function Scrappy.Gear.DisableAutoThreshold()
    if not ScrappyDB then return end
    
    ScrappyDB.autoThreshold = false
    Scrappy.QuietPrint("Auto-threshold disabled. Manual ilvl threshold: " .. (ScrappyDB.ilvlThreshold or 0))
end

--  Show detailed gear analysis
function Scrappy.Gear.ShowGearAnalysis()
    local avgIlvl, gearBreakdown, itemCount = Scrappy.Gear.GetEquippedAverageItemLevel()
    
    if itemCount == 0 then
        Scrappy.Print("No equipped gear found for analysis.")
        return
    end
    
    Scrappy.Print("Gear Analysis:")
    Scrappy.Print("  Equipped items: " .. itemCount)
    Scrappy.Print("  Average item level: " .. string.format("%.1f", avgIlvl))
    
    if ScrappyDB.autoThreshold then
        local threshold = Scrappy.Gear.CalculateAutoThreshold()
        Scrappy.Print("  Auto-threshold: " .. threshold .. " (avg " .. (ScrappyDB.autoThresholdOffset or -10) .. ")")
        Scrappy.Print("  Status: Enabled")
    else
        Scrappy.Print("  Manual threshold: " .. (ScrappyDB.ilvlThreshold or 0))
        Scrappy.Print("  Status: Manual mode")
    end
    
    --  Show lowest and highest ilvl items for context
    table.sort(gearBreakdown, function(a, b) return a.ilvl < b.ilvl end)
    
    local lowest = gearBreakdown[1]
    local highest = gearBreakdown[#gearBreakdown]
    
    Scrappy.Print("  Lowest: " .. lowest.slot .. " (" .. lowest.ilvl .. ")")
    Scrappy.Print("  Highest: " .. highest.slot .. " (" .. highest.ilvl .. ")")
    
    --  Suggest threshold if not using auto
    if not ScrappyDB.autoThreshold then
        local suggestedThreshold = math.max(0, math.floor((avgIlvl - 10) / 5) * 5)
        Scrappy.Print("  Suggested threshold: " .. suggestedThreshold)
        Scrappy.Print("  Use '/scrappy autothreshold on' to enable automatic updates")
    end
end

--  Check if equipped gear has changed significantly
function Scrappy.Gear.CheckForGearChanges()
    if not ScrappyDB or not ScrappyDB.autoThreshold then return false end
    
    --  Store last known average for comparison
    ScrappyDB.lastKnownAvgIlvl = ScrappyDB.lastKnownAvgIlvl or 0
    
    local currentAvg = Scrappy.Gear.GetEquippedAverageItemLevel()
    local lastAvg = ScrappyDB.lastKnownAvgIlvl
    
    --  Consider it a significant change if avg ilvl changed by 5+ levels
    local significantChange = math.abs(currentAvg - lastAvg) >= 5
    
    if significantChange then
        ScrappyDB.lastKnownAvgIlvl = currentAvg
        return Scrappy.Gear.UpdateAutoThreshold()
    end
    
    return false
end

--  Event handler for gear changes
local gearFrame = CreateFrame("Frame")
gearFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
gearFrame:RegisterEvent("PLAYER_LOGIN")
gearFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        --  Update threshold on login if auto-threshold is enabled
        C_Timer.After(2, function()  -- Wait for gear to load
            if ScrappyDB and ScrappyDB.autoThreshold then
                Scrappy.Gear.UpdateAutoThreshold()
            end
        end)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        --  Check for gear changes when equipment changes
        C_Timer.After(0.5, function()  -- Small delay to let changes settle
            Scrappy.Gear.CheckForGearChanges()
        end)
    end
end)