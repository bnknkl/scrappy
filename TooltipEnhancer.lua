-- Fixed TooltipEnhancer.lua - with recursion protection and simplified Warbound detection

local Scrappy = _G["Scrappy"]
Scrappy.TooltipEnhancer = {}

-- Configuration
local SHOW_TOOLTIPS = true
local TOOLTIP_COLOR_SELL = {1, 0.42, 0.42}        -- Light red for "Will be sold"
local TOOLTIP_COLOR_KEEP = {0.32, 0.81, 0.4}      -- Light green for "Won't be sold"
local TOOLTIP_COLOR_PROTECTED = {0.31, 0.8, 0.77} -- Light blue for "Protected"
local TOOLTIP_COLOR_TOKEN = {1, 0.65, 0}          -- Orange for tokens
local TOOLTIP_COLOR_MATERIAL = {0.8, 0.4, 1}      -- Purple for materials
local TOOLTIP_COLOR_QUALITY = {0.9, 0.9, 0.4}     -- Yellow for quality filters
local TOOLTIP_COLOR_ILVL = {0.4, 0.8, 1}          -- Light blue for ilvl threshold

-- Cache for tooltip results
local tooltipCache = {}
local cacheExpiry = {}
local CACHE_DURATION = 5 -- seconds

-- Recursion protection
local isProcessingTooltip = false

-- Simplified Warbound detection (no recursive tooltip scanning)
local function IsWarboundUntilEquipped(bag, slot)
    if not bag or not slot then return false end
    
    -- Only use the modern API - avoid tooltip scanning to prevent recursion
    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if not itemLink then return false end
    
    -- Try the modern tooltip data API
    local success, tooltipData = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if success and tooltipData and tooltipData.lines then
        for _, line in ipairs(tooltipData.lines) do
            if line.leftText then
                local text = line.leftText:lower()
                if text:find("warbound until equipped") or text:find("warbound when equipped") then
                    return true
                end
            end
        end
    end
    
    return false
end

local function GetScrappyStatus(itemID, bag, slot)
    if not itemID or not ScrappyDB or isProcessingTooltip then
        return nil
    end
    
    -- Check cache first
    local cacheKey = itemID .. "_" .. (bag or 0) .. "_" .. (slot or 0)
    local currentTime = GetTime()
    
    if tooltipCache[cacheKey] and cacheExpiry[cacheKey] and currentTime < cacheExpiry[cacheKey] then
        return tooltipCache[cacheKey]
    end
    
    -- Set recursion protection
    isProcessingTooltip = true
    
    local itemInfo
    local status = "unknown"
    local reason = ""
    
    -- Use the same cache system as the test command
    if bag and slot then
        itemInfo = Scrappy.Cache.GetItemInfoFromSlot(bag, slot, true)
    end
    
    -- Fallback if cache system fails
    if not itemInfo then
        local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemID)
        if name then
            itemInfo = {
                itemID = itemID,
                name = name,
                quality = quality,
                ilvl = ilvl,
                hasNoValue = false,
                bag = bag,
                slot = slot
            }
        else
            isProcessingTooltip = false
            return nil
        end
    end
        
    -- Test if item would be sold
    if itemInfo then
        local wouldSell = Scrappy.Filters.IsItemSellable(itemInfo)        
        if wouldSell then
            status = "sell"
            reason = "Will be sold"
        else
            status = "keep"
            
            -- Get item details for protection analysis
            local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemID)
            local actualIlvl = tonumber(itemInfo.ilvl) or tonumber(ilvl) or 0
            local ilvlThreshold = (ScrappyDB and ScrappyDB.ilvlThreshold) or 0
            local lowerName = name and name:lower() or ""
                        
            -- Check ALL protection reasons in the same order as the main filter
            
            -- 1. Warbound protection
            if ScrappyDB.protectWarbound and itemInfo.bag and itemInfo.slot then
                local isWarbound = IsWarboundUntilEquipped(itemInfo.bag, itemInfo.slot)
                if isWarbound then
                    reason = "Protected (Warbound until equipped)"
                end
            end
            
            -- 2. Token protection (comprehensive)
            if reason == "" and ScrappyDB.protectTokens and name then
                local itemEquipLoc = select(9, GetItemInfo(itemID))
                local isEquippableGear = itemEquipLoc and itemEquipLoc ~= ""
                                
                if not isEquippableGear then
                    -- Check token patterns for non-equippable items
                    local tokenPatterns = {
                        ".*token", ".*insignia", ".*emblem", ".*badge", ".*seal",
                        ".*module", "mystic.*module", ".*tier.*module",
                        ".*catalyst", "revival.*catalyst", "creation.*catalyst",
                        ".*spark", "valorstone", ".*aspect",
                        "fragment of", "shard of", "tier.*fragment", "set.*fragment"
                    }
                    
                    for _, pattern in ipairs(tokenPatterns) do
                        if lowerName:find(pattern) then
                            reason = "Protected (Gear Token: " .. pattern:gsub("%.%*", "") .. ")"
                            break
                        end
                    end
                else
                    -- For equippable gear, only very specific patterns
                    if lowerName:find("tier.*token") or lowerName:find("set.*token") then
                        reason = "Protected (Gear Token)"
                    end
                end
            end
            
            -- 3. Consumable protection
            if reason == "" and (class == 0 or class == "Consumable") then
                local consumableQuality = quality or 0
                if consumableQuality == 0 then
                    -- Junk consumables should be sellable, if we're here something else is blocking
                else
                    reason = "Protected (Consumable)"
                end
            end
            
            -- 4. Profession equipment protection
            if reason == "" and (class == 7 or class == "Trade Goods") then
                if subclass == 12 or subclass == "Device" or subclass == "Devices" then
                    reason = "Protected (Profession Tool)"
                elseif subclass == 8 or subclass == "Food & Drink" then
                    reason = "Protected (Food/Drink)"
                end
            end
            
            -- 5. Name-based profession tool protection
            if reason == "" and name then
                local professionKeywords = {
                    "skinning knife", "mining pick", "herbalism", "blacksmith hammer",
                    "fishing pole", "fishing rod", "enchanting rod", "hammer", "tongs", 
                    "anvil", "forge", "crucible", "needle", "thread", "awl", "knife"
                }
                
                for _, keyword in ipairs(professionKeywords) do
                    if lowerName:find(keyword) then
                        reason = "Protected (Profession Tool: " .. keyword .. ")"
                        break
                    end
                end
            end
            
            -- 6. Quality filter check
            if reason == "" then
                local itemQuality = quality or 0
                local qualityAllowed = ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[itemQuality]
                if not qualityAllowed then
                    local qualityNames = {[0]="Junk", [1]="Common", [2]="Uncommon", [3]="Rare", [4]="Epic"}
                    local qualityName = qualityNames[itemQuality] or "Unknown"
                    reason = "Quality Filter (" .. qualityName .. " selling disabled)"
                end
            end
            
            -- 7. Explicit sell list (should override other protections)
            if reason == "" and ScrappyDB.sellList and ScrappyDB.sellList[itemID] then
                reason = "Will be sold (On explicit sell list)"
                status = "sell"
            end
            
            -- 8. Material protection
            if reason == "" then
                local materialInfo = Scrappy.Filters.GetMaterialInfo(itemInfo)
                if materialInfo and materialInfo.isProtected then
                    local expansionName = materialInfo.expansion and materialInfo.expansion:gsub("^%l", string.upper) or "Unknown"
                    reason = "Protected (" .. expansionName .. " Material)"
                end
            end
            
            -- 9. Item level threshold
            if reason == "" and ilvlThreshold > 0 and actualIlvl > 0 then
                if actualIlvl > ilvlThreshold then
                    reason = "Above iLvl Threshold (" .. actualIlvl .. " > " .. ilvlThreshold .. ")"
                end
            end
            
            -- 10. Check if item has no value
            if reason == "" and itemInfo.hasNoValue then
                reason = "Has No Value"
            end
            
            -- Generic fallback
            if reason == "" then
                reason = "Won't be sold (Check main filter for details)"
            end
        end
    end
    
    -- Clear recursion protection
    isProcessingTooltip = false
    
    -- Cache the result
    local result = {status = status, reason = reason}
    tooltipCache[cacheKey] = result
    cacheExpiry[cacheKey] = currentTime + CACHE_DURATION
    
    return result
end

-- Enhanced tooltip display with recursion protection
local function OnTooltipSetItem(tooltip)
    if not SHOW_TOOLTIPS or not ScrappyDB or isProcessingTooltip then 
        return 
    end
    
    local name, link = tooltip:GetItem()
    if not link then return end
    
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end
    
    -- Enhanced bag/slot detection
    local bag, slot = nil, nil
    
    if tooltip:GetOwner() then
        local owner = tooltip:GetOwner()
        if owner and owner:GetName() then
            local buttonName = owner:GetName()
            
            -- Parse various container frame patterns
            local containerFrame, itemSlot = buttonName:match("ContainerFrame(%d+)Item(%d+)")
            if containerFrame and itemSlot then
                bag = tonumber(containerFrame) - 1
                slot = tonumber(itemSlot)
            end
            
            -- Parse ElvUI patterns
            if not bag then
                local elvBag, elvSlot = buttonName:match("ElvUI_ContainerFrameBag(%d+)Slot(%d+)")
                if elvBag and elvSlot then
                    bag = tonumber(elvBag)
                    slot = tonumber(elvSlot)
                end
            end
            
            -- Parse other patterns
            if not bag then
                local genericBag, genericSlot = buttonName:match("Bag(%d+)Slot(%d+)")
                if genericBag and genericSlot then
                    bag = tonumber(genericBag)
                    slot = tonumber(genericSlot)
                end
            end
        end
    end
    
    -- Search bags if detection failed (but avoid triggering more tooltips)
    if not bag and itemID then
        for searchBag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
            local success, numSlots = pcall(C_Container.GetContainerNumSlots, searchBag)
            if success and numSlots then
                for searchSlot = 1, numSlots do
                    local containerItem = C_Container.GetContainerItemInfo(searchBag, searchSlot)
                    if containerItem and containerItem.itemID == itemID then
                        bag = searchBag
                        slot = searchSlot
                        break
                    end
                end
            end
            if bag then break end
        end
    end
    
    local statusInfo = GetScrappyStatus(itemID, bag, slot)
    if statusInfo then
        local color = TOOLTIP_COLOR_KEEP
        local prefix = "Scrappy: "
        
        -- Color coding based on protection type
        if statusInfo.status == "sell" then
            color = TOOLTIP_COLOR_SELL
        elseif statusInfo.reason:find("Token") or statusInfo.reason:find("Mystic") then
            color = TOOLTIP_COLOR_TOKEN
        elseif statusInfo.reason:find("Material") then
            color = TOOLTIP_COLOR_MATERIAL
        elseif statusInfo.reason:find("Quality Filter") then
            color = TOOLTIP_COLOR_QUALITY
        elseif statusInfo.reason:find("iLvl Threshold") or statusInfo.reason:find("Above") then
            color = TOOLTIP_COLOR_ILVL
        elseif statusInfo.reason:find("Protected") then
            color = TOOLTIP_COLOR_PROTECTED
        end
        
        -- Add the line to tooltip
        tooltip:AddLine(prefix .. statusInfo.reason, color[1], color[2], color[3])
    end
end

-- Public functions
function Scrappy.TooltipEnhancer.Enable()
    SHOW_TOOLTIPS = true
    tooltipCache = {}
    cacheExpiry = {}
    Scrappy.Print("Tooltip enhancements enabled")
end

function Scrappy.TooltipEnhancer.Disable()
    SHOW_TOOLTIPS = false
    Scrappy.Print("Tooltip enhancements disabled")
end

function Scrappy.TooltipEnhancer.Toggle()
    if SHOW_TOOLTIPS then
        Scrappy.TooltipEnhancer.Disable()
    else
        Scrappy.TooltipEnhancer.Enable()
    end
end

function Scrappy.TooltipEnhancer.IsEnabled()
    return SHOW_TOOLTIPS
end

-- Simplified tooltip hooking
local function HookTooltips()
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem)
    else
        -- Fallback method
        local originalSetBagItem = GameTooltip.SetBagItem
        GameTooltip.SetBagItem = function(self, bag, slot)
            local result = originalSetBagItem(self, bag, slot)
            OnTooltipSetItem(self)
            return result
        end
        
        local originalSetHyperlink = GameTooltip.SetHyperlink
        GameTooltip.SetHyperlink = function(self, link)
            local result = originalSetHyperlink(self, link)
            OnTooltipSetItem(self)
            return result
        end
    end
end

-- Initialize
local tooltipFrame = CreateFrame("Frame")
tooltipFrame:RegisterEvent("ADDON_LOADED")
tooltipFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Scrappy" then
        C_Timer.After(0.5, function()
            HookTooltips()
        end)
        
        tooltipFrame:RegisterEvent("BAG_UPDATE")
        tooltipFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        
        tooltipFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
                tooltipCache = {}
                cacheExpiry = {}
            end
        end)
    end
end)