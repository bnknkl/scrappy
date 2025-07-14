-- WHY: Debug module loading
        if msg == "modules" then
            Scrappy.Config.DebugModules()
            return
        end-- Config.lua - Settings management and slash commands

-- WHY: Get reference to our addon namespace
local Scrappy = _G["Scrappy"]

-- WHY: Main slash command handler
function Scrappy.Config.HandleSlashCommand(msg)
    -- WHY: Validate database exists
    if not ScrappyDB then
        Scrappy.Print("Error: Settings not loaded yet. Try again in a moment.")
        return
    end
    
    -- WHY: Protect against nil input
    msg = (msg or ""):lower()
    
    -- WHY: Wrap command parsing in protected call
    local success, errorMsg = pcall(function()
        -- WHY: Parse quality commands (e.g., "/scrappy quality rare sell")
        local qualityInput, toggle = msg:match("^quality%s+(%w+)%s+(%w+)$")
        if qualityInput and toggle then
            Scrappy.Config.HandleQualityCommand(qualityInput, toggle)
            return
        end
        
        -- WHY: Parse material filter commands (e.g., "/scrappy materials legion protect")
        local expansion, materialToggle = msg:match("^materials%s+(%w+)%s+(%w+)$")
        if expansion and materialToggle then
            Scrappy.Config.HandleMaterialCommand(expansion, materialToggle)
            return
        end
        
        -- WHY: Add item to classification override
        local overrideMatch = msg:match("^override%s+(%d+)%s+(%w+)%s+(%w+)$")
        if overrideMatch then
            local itemID, expansion, materialType = overrideMatch:match("(%d+)%s+(%w+)%s+(%w+)")
            Scrappy.Config.HandleOverrideCommand(tonumber(itemID), expansion, materialType)
            return
        end
        
        -- WHY: Parse simple on/off commands
        if msg == "auto on" then
            ScrappyDB.autoSell = true
            Scrappy.Print("Auto-sell enabled.")
            return
        elseif msg == "auto off" then
            ScrappyDB.autoSell = false
            Scrappy.Print("Auto-sell disabled.")
            return
        end
        
        -- WHY: Parse consumable selling commands
        if msg == "consumables on" then
            ScrappyDB.sellConsumables = true
            Scrappy.Print("Consumable selling enabled. |cffff0000WARNING:|r Flasks, potions, and food can now be sold!")
            Scrappy.Print("Use '/scrappy consumables off' to re-enable protection.")
            return
        elseif msg == "consumables off" then
            ScrappyDB.sellConsumables = false
            Scrappy.Print("Consumable selling disabled. All consumables are now protected.")
            return
        end
        
        if msg == "warbound on" then
            ScrappyDB.protectWarbound = true
            Scrappy.Print("Warbound protection enabled. Items marked 'Warbound until equipped' will not be sold.")
            return
        elseif msg == "warbound off" then
            ScrappyDB.protectWarbound = false
            Scrappy.Print("Warbound protection disabled. Items marked 'Warbound until equipped' can be sold.")
            return
        end

        -- WHY: Parse token protection commands
        if msg == "tokens on" then
            ScrappyDB.protectTokens = true
            Scrappy.Print("Token protection enabled. Gear tokens and set pieces will not be sold.")
            return
        elseif msg == "tokens off" then
            ScrappyDB.protectTokens = false
            Scrappy.Print("Token protection disabled. Gear tokens and set pieces can be sold.")
            return
        end

        -- WHY: Parse selling order commands
        if msg == "order default" then
            ScrappyDB.sellOrder = "default"
            Scrappy.Print("Selling order set to: Default (bag order)")
            return
        elseif msg == "order value" then
            ScrappyDB.sellOrder = "value"
            Scrappy.Print("Selling order set to: Low to High Value (cheapest items first)")
            return
        elseif msg == "order quality" then
            ScrappyDB.sellOrder = "quality"
            Scrappy.Print("Selling order set to: Junk to Epic Quality (lowest quality first)")
            return
        end

        -- WHY: Parse item level threshold commands
        local ilvlMatch = msg:match("^ilvl%s+(%d+)$")
        if ilvlMatch then
            local newIlvl = tonumber(ilvlMatch)
            if newIlvl and newIlvl >= 0 and newIlvl <= 1000 then
                -- WHY: Disable auto-threshold when manually setting ilvl
                ScrappyDB.autoThreshold = false
                ScrappyDB.ilvlThreshold = newIlvl
                Scrappy.Print("Item level threshold set to " .. newIlvl .. " (auto-threshold disabled)")
            else
                Scrappy.Print("Invalid item level. Use a number between 0 and 1000.")
            end
            return
        end
        
        -- WHY: Parse auto-threshold commands
        local autoThresholdCmd, autoThresholdArg = msg:match("^autothreshold%s+(%w+)%s*([%d%-]*)")
        if autoThresholdCmd then
            if autoThresholdCmd == "on" then
                local offset = tonumber(autoThresholdArg) or -10
                Scrappy.Gear.EnableAutoThreshold(offset)
            elseif autoThresholdCmd == "off" then
                Scrappy.Gear.DisableAutoThreshold()
            else
                Scrappy.Print("Use 'on' or 'off' with autothreshold command.")
            end
            return
        end
        
        -- WHY: Show settings UI
        if msg == "config" or msg == "settings" then
            if Scrappy.SettingsUI and Scrappy.SettingsUI.Show then
                local success, err = pcall(Scrappy.SettingsUI.Show)
                if not success then
                    Scrappy.Print("Error opening settings UI: " .. tostring(err))
                end
            else
                Scrappy.Print("Error: Settings UI not loaded. Try /reload")
            end
            return
        end
        
        -- WHY: Show gear analysis
        if msg == "gear" then
            Scrappy.Gear.ShowGearAnalysis()
            return
        end
        
        -- WHY: Show current settings
        if msg == "status" then
            Scrappy.Config.ShowStatus()
            return
        end
        
        -- WHY: Retry failed selling operations
        if msg == "retry" then
            Scrappy.Recovery.RetryFailedSells()
            return
        end
        
        -- WHY: Cancel ongoing selling
        if msg == "cancel" then
            Scrappy.Recovery.CancelSelling()
            return
        end
        
        -- WHY: Show cache statistics
        if msg == "cache" then
            Scrappy.Config.ShowCacheStats()
            return
        end
        
        -- WHY: Show what materials player has
        if msg == "scan" then
            Scrappy.Config.ScanMaterials()
            return
        end
        
        -- WHY: Quick scan - only show cached materials
        if msg == "quickscan" then
            Scrappy.Config.QuickScanMaterials()
            return
        end
        
        -- WHY: Pre-cache items for better performance
        if msg == "precache" then
            Scrappy.Filters.PreCacheItems()
            return
        end
        
        -- WHY: Test what would be sold
        if msg == "testsell" then
            Scrappy.Config.TestSelling()
            return
        end
        
        -- WHY: Manual sell command
        if msg == "sell" then
            Scrappy.Core.SellItems()
            return
        end
        
        -- WHY: Test classification on specific item
        local testMatch = msg:match("^test%s+(%d+)$")
        if testMatch then
            local itemID = tonumber(testMatch)
            Scrappy.Config.TestItemClassification(itemID)
            return
        end
        
        -- WHY: Debug item classes
        if msg == "debug" then
            Scrappy.Config.DebugItemClasses()
            return
        end
        
        -- WHY: Test dialog handling
        if msg == "testdialog" then
            Scrappy.Print("Testing dialog auto-confirm...")
            Scrappy.Print("AutoConfirmSoulbound setting: " .. tostring(ScrappyDB.autoConfirmSoulbound))
            StaticPopup_Show("SELL_NONREFUNDABLE_ITEM", "Test Item")
            return
        end
        
        -- WHY: Test SettingsUI module
        if msg == "testui" then
            if Scrappy.SettingsUI and Scrappy.SettingsUI.Test then
                Scrappy.SettingsUI.Test()
            else
                Scrappy.Print("SettingsUI.Test not available")
            end
            return
        end
        
        -- WHY: Emergency stop
        if msg == "stop" then
            Scrappy.Recovery.EmergencyStop()
            return
        end
        
        -- WHY: Default case - show help
        Scrappy.Config.ShowHelp()
    end)
    
    if not success then
        Scrappy.Print("Error processing command: " .. (errorMsg or "Unknown error"))
        Scrappy.Config.ShowHelp()
    end
end

-- WHY: Separate function for quality command handling
function Scrappy.Config.HandleQualityCommand(qualityInput, toggle)
    -- WHY: Validate inputs
    if not qualityInput or not toggle then
        Scrappy.Print("Invalid quality command format.")
        return
    end
    
    -- WHY: Accept both numeric and text quality input
    local quality = tonumber(qualityInput)
    if not quality then
        quality = Scrappy.QUALITY_NAME_TO_ID[qualityInput:lower()]
    end
    
    -- WHY: Validate quality range
    if not quality or quality < 0 or quality > 4 then
        Scrappy.Print("Unknown quality: " .. qualityInput .. ". Use 0-4 or junk/common/uncommon/rare/epic")
        return
    end
    
    -- WHY: Validate database structure
    if not ScrappyDB.qualityFilter then
        ScrappyDB.qualityFilter = {}
    end
    
    local qualityName = Scrappy.QUALITY_NAMES[quality] or ("Quality " .. quality)
    
    if toggle == "sell" then
        ScrappyDB.qualityFilter[quality] = true
        Scrappy.Print("Set to sell " .. qualityName .. " items.")
    elseif toggle == "keep" then
        ScrappyDB.qualityFilter[quality] = false
        Scrappy.Print("Set to keep " .. qualityName .. " items.")
    else
        Scrappy.Print("Unknown action: " .. toggle .. ". Use 'sell' or 'keep'.")
    end
end

-- WHY: Handle material filter commands
function Scrappy.Config.HandleMaterialCommand(expansion, toggle)
    -- WHY: Validate inputs
    if not expansion or not toggle then
        Scrappy.Print("Invalid material command format.")
        return
    end
    
    -- WHY: Validate database structure
    if not ScrappyDB.materialFilters then
        ScrappyDB.materialFilters = {}
    end
    
    -- WHY: Check if expansion exists in our filters
    local validExpansions = {
        classic = "Classic (Vanilla)",
        tbc = "The Burning Crusade", 
        wotlk = "Wrath of the Lich King",
        cata = "Cataclysm",
        mop = "Mists of Pandaria",
        wod = "Warlords of Draenor",
        legion = "Legion",
        bfa = "Battle for Azeroth",
        shadowlands = "Shadowlands",
        dragonflight = "Dragonflight",
        tww = "The War Within"
    }
    
    local expansionName = validExpansions[expansion:lower()]
    if not expansionName then
        Scrappy.Print("Unknown expansion: " .. expansion)
        Scrappy.Print("Valid expansions: classic, tbc, wotlk, cata, mop, wod, legion, bfa, shadowlands, dragonflight, tww")
        return
    end
    
    local expansionKey = expansion:lower()
    
    if toggle == "protect" then
        ScrappyDB.materialFilters[expansionKey] = true
        Scrappy.Print("Now protecting " .. expansionName .. " crafting materials from being sold.")
    elseif toggle == "allow" then
        ScrappyDB.materialFilters[expansionKey] = false
        Scrappy.Print("Now allowing " .. expansionName .. " crafting materials to be sold.")
    else
        Scrappy.Print("Unknown action: " .. toggle .. ". Use 'protect' or 'allow'.")
    end
end

-- WHY: Handle adding classification overrides for edge cases
function Scrappy.Config.HandleOverrideCommand(itemID, expansion, materialType)
    if not itemID or not expansion or not materialType then
        Scrappy.Print("Invalid override command format.")
        return
    end
    
    -- WHY: Validate expansion
    local validExpansions = {
        classic = true, tbc = true, wotlk = true, cata = true, mop = true,
        wod = true, legion = true, bfa = true, shadowlands = true, 
        dragonflight = true, tww = true
    }
    
    if not validExpansions[expansion:lower()] then
        Scrappy.Print("Invalid expansion. Use: classic, tbc, wotlk, cata, mop, wod, legion, bfa, shadowlands, dragonflight, tww")
        return
    end
    
    -- WHY: Store in saved variables for persistence
    ScrappyDB.materialOverrides = ScrappyDB.materialOverrides or {}
    ScrappyDB.materialOverrides[itemID] = {
        expansion = expansion:lower(),
        type = materialType:lower()
    }
    
    -- WHY: Clear classification cache to apply immediately
    Scrappy.Filters.ClearClassificationCache()
    
    Scrappy.Print("Added override: ItemID " .. itemID .. " -> " .. expansion .. " " .. materialType)
    Scrappy.Print("This item will now be classified as " .. expansion .. " material.")
end

-- WHY: Show current addon settings
function Scrappy.Config.ShowStatus()
    local ilvl = ScrappyDB.ilvlThreshold or 0
    
    Scrappy.Print("Settings:")
    Scrappy.Print("  Auto-sell: " .. tostring(ScrappyDB.autoSell))
    Scrappy.Print("  Consumables: " .. (ScrappyDB.sellConsumables and "|cffff0000ENABLED|r (can sell flasks/potions)" or "|cff00ff00PROTECTED|r (safe)"))
    Scrappy.Print("  Warbound items: " .. (ScrappyDB.protectWarbound and "|cff00ff00PROTECTED|r" or "|cffff0000NOT PROTECTED|r"))
    Scrappy.Print("  Gear tokens: " .. (ScrappyDB.protectTokens and "|cff00ff00PROTECTED|r" or "|cffff0000NOT PROTECTED|r"))
    if ScrappyDB.autoThreshold then
        local avgIlvl = Scrappy.Gear.GetEquippedAverageItemLevel()
        Scrappy.Print("  Auto-threshold: ENABLED (avg ilvl: " .. string.format("%.1f", avgIlvl) .. ")")
        Scrappy.Print("  Current threshold: " .. tostring(ScrappyDB.ilvlThreshold) .. " (offset: " .. (ScrappyDB.autoThresholdOffset or -10) .. ")")
    else
        Scrappy.Print("  Item level threshold: " .. tostring(ilvl) .. " (manual)")
    end
    -- WHY: Show selling order
    local orderText = "Default"
    if ScrappyDB.sellOrder == "value" then
        orderText = "Value (Low to High)"
    elseif ScrappyDB.sellOrder == "quality" then
        orderText = "Quality (Junk to Epic)"
    end
    Scrappy.Print("  Selling order: " .. orderText)
    
    -- WHY: Show quality filter settings
    for quality = 0, 4 do
        local qualityName = Scrappy.QUALITY_NAMES[quality] or ("Quality " .. quality)
        local enabled = ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[quality]
        local status = enabled and "sell" or "keep"
        Scrappy.Print("  " .. qualityName .. ": " .. status)
    end
    
    -- WHY: Show material filter settings
    if ScrappyDB.materialFilters then
        Scrappy.Print("  Material filters:")
        local expansionNames = {
            classic = "Classic",
            tbc = "TBC", 
            wotlk = "WotLK",
            cata = "Cataclysm",
            mop = "MoP",
            wod = "WoD",
            legion = "Legion",
            bfa = "BfA",
            shadowlands = "Shadowlands",
            dragonflight = "Dragonflight",
            tww = "TWW"
        }
        
        for expansion, enabled in pairs(ScrappyDB.materialFilters) do
            local name = expansionNames[expansion] or expansion
            local status = enabled and "protected" or "not protected"
            Scrappy.Print("    " .. name .. ": " .. status)
        end
    end
end

-- WHY: Show cache statistics for debugging
function Scrappy.Config.ShowCacheStats()
    local cacheStats = Scrappy.Cache.GetCacheStats()
    local sellStatus = Scrappy.Recovery.GetSellStatus()
    local classificationStats = Scrappy.Filters.GetClassificationStats()
    
    Scrappy.Print("Item Cache Statistics:")
    Scrappy.Print("  Cached items: " .. cacheStats.cachedItems)
    Scrappy.Print("  Pending items: " .. cacheStats.pendingItems)
    Scrappy.Print("  Items needing refresh: " .. cacheStats.needsRefresh)
    
    Scrappy.Print("Classification Statistics:")
    Scrappy.Print("  Total queries: " .. classificationStats.totalQueries)
    Scrappy.Print("  Cache hit rate: " .. string.format("%.1f%%", classificationStats.cacheHitRate))
    Scrappy.Print("  Override hits: " .. classificationStats.overrideHits)
    Scrappy.Print("  API calls: " .. classificationStats.apiCalls)
    Scrappy.Print("  Pattern matches: " .. classificationStats.patternMatches)
    Scrappy.Print("  Classification cache size: " .. classificationStats.cacheSize)
    
    Scrappy.Print("Selling Status:")
    Scrappy.Print("  In progress: " .. tostring(sellStatus.inProgress))
    Scrappy.Print("  Queued items: " .. sellStatus.queuedItems)
    Scrappy.Print("  Failed items: " .. sellStatus.failedItems)
end

-- WHY: Scan bags for crafting materials and show what's found
function Scrappy.Config.ScanMaterials()
    if not ScrappyDB then
        Scrappy.Print("Error: Settings not loaded yet.")
        return
    end
    
    Scrappy.Print("Scanning bags for crafting materials...")
    
    local materialsFound = {}
    local totalScanned = 0
    local errors = 0
    local itemsSeen = {}  -- WHY: Track items we've already processed
    
    -- WHY: Scan all bags for materials
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local success, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
        if success and numSlots then
            for slot = 1, numSlots do
                totalScanned = totalScanned + 1
                local itemInfo = Scrappy.Cache.GetItemInfoFromSlot(bag, slot)
                if itemInfo then
                    -- WHY: Only classify each unique item once
                    if not itemsSeen[itemInfo.itemID] then
                        itemsSeen[itemInfo.itemID] = true
                        local materialInfo = Scrappy.Filters.GetMaterialInfo(itemInfo)
                        if materialInfo then
                            materialsFound[materialInfo.expansion] = materialsFound[materialInfo.expansion] or {}
                            table.insert(materialsFound[materialInfo.expansion], {
                                name = itemInfo.name,
                                count = itemInfo.stackCount or 1,
                                quality = itemInfo.quality,
                                materialType = materialInfo.materialType,
                                source = materialInfo.source
                            })
                        end
                    end
                else
                    errors = errors + 1
                end
            end
        end
    end
    
    if next(materialsFound) then
        Scrappy.Print("Found crafting materials:")
        local expansionNames = {
            classic = "Classic",
            tbc = "TBC", 
            wotlk = "WotLK",
            cata = "Cataclysm",
            mop = "MoP",
            wod = "WoD",
            legion = "Legion",
            bfa = "BfA",
            shadowlands = "Shadowlands",
            dragonflight = "Dragonflight",
            tww = "TWW"
        }
        
        for expansion, materials in pairs(materialsFound) do
            local expansionName = expansionNames[expansion] or expansion
            local isProtected = ScrappyDB.materialFilters[expansion]
            local status = isProtected and " (PROTECTED)" or " (not protected)"
            Scrappy.Print("  " .. expansionName .. status .. ":")
            
            for _, material in ipairs(materials) do
                local qualityColor = ""
                if material.quality == 2 then qualityColor = " |cff00ff00(Uncommon)|r"
                elseif material.quality == 3 then qualityColor = " |cff0070dd(Rare)|r"
                elseif material.quality == 4 then qualityColor = " |cffa335ee(Epic)|r" end
                
                local sourceIndicator = ""
                if material.source == "user_override" then sourceIndicator = " ᵘ"
                elseif material.source == "builtin_override" then sourceIndicator = " *"
                elseif material.source == "dynamic" then sourceIndicator = " ᵈ" end
                
                local typeInfo = material.materialType and (" [" .. material.materialType .. "]") or ""
                Scrappy.Print("    " .. material.name .. " x" .. material.count .. qualityColor .. typeInfo .. sourceIndicator)
            end
        end
        
        Scrappy.Print("Use '/scrappy materials [expansion] protect' to protect materials from selling.")
        Scrappy.Print("Legend: * = Built-in rule, ᵘ = User override, ᵈ = Dynamic classification")
    else
        Scrappy.Print("No crafting materials found in bags.")
    end
    
    if errors > 0 then
        Scrappy.Print("Note: " .. errors .. " items couldn't be checked (not cached yet)")
    end
    
    -- WHY: Show performance info
    local stats = Scrappy.Filters.GetClassificationStats()
    if stats.totalQueries > 0 then
        Scrappy.Print("Performance: " .. stats.totalQueries .. " queries, " .. 
                      string.format("%.1f%%", stats.cacheHitRate) .. " cache hit rate")
    end
end

-- WHY: Quick scan - only show materials that are already cached
function Scrappy.Config.QuickScanMaterials()
    if not ScrappyDB then
        Scrappy.Print("Error: Settings not loaded yet.")
        return
    end
    
    local materialsFound = {}
    local itemsSeen = {}
    local successCount = 0
    
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local success, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
        if success and numSlots then
            for slot = 1, numSlots do
                local itemInfo = Scrappy.Cache.GetItemInfoFromSlot(bag, slot)
                if itemInfo and not itemsSeen[itemInfo.itemID] then
                    itemsSeen[itemInfo.itemID] = true
                    successCount = successCount + 1
                    
                    local materialInfo = Scrappy.Filters.GetMaterialInfo(itemInfo)
                    if materialInfo then
                        materialsFound[materialInfo.expansion] = materialsFound[materialInfo.expansion] or {}
                        table.insert(materialsFound[materialInfo.expansion], {
                            name = itemInfo.name,
                            count = itemInfo.stackCount or 1,
                            quality = itemInfo.quality,
                            materialType = materialInfo.materialType,
                            source = materialInfo.source
                        })
                    end
                end
            end
        end
    end
    
    if next(materialsFound) then
        Scrappy.Print("Cached crafting materials:")
        local expansionNames = {
            classic = "Classic", tbc = "TBC", wotlk = "WotLK", cata = "Cataclysm",
            mop = "MoP", wod = "WoD", legion = "Legion", bfa = "BfA",
            shadowlands = "Shadowlands", dragonflight = "Dragonflight", tww = "TWW"
        }
        
        for expansion, materials in pairs(materialsFound) do
            local expansionName = expansionNames[expansion] or expansion
            local isProtected = ScrappyDB.materialFilters[expansion]
            local status = isProtected and " (PROTECTED)" or " (not protected)"
            Scrappy.Print("  " .. expansionName .. status .. ":")
            
            for _, material in ipairs(materials) do
                local qualityColor = ""
                if material.quality == 2 then qualityColor = " |cff00ff00(Uncommon)|r"
                elseif material.quality == 3 then qualityColor = " |cff0070dd(Rare)|r"
                elseif material.quality == 4 then qualityColor = " |cffa335ee(Epic)|r" end
                
                local typeInfo = material.materialType and (" [" .. material.materialType .. "]") or ""
                Scrappy.Print("    " .. material.name .. " x" .. material.count .. qualityColor .. typeInfo)
            end
        end
    else
        Scrappy.Print("No cached crafting materials found.")
    end
    
    Scrappy.Print("(" .. successCount .. " items successfully scanned)")
end

-- WHY: Test what would be sold without actually selling
function Scrappy.Config.TestSelling()
    if not ScrappyDB then
        Scrappy.Print("Error: Settings not loaded yet.")
        return
    end
    
    Scrappy.Print("Testing what would be sold...")
    
    local items = Scrappy.Core.GetItemsToSell()
    local cacheInfo = items._cacheInfo
    items._cacheInfo = nil
    
    if #items == 0 then
        Scrappy.Print("No items would be sold.")
        if cacheInfo and cacheInfo.pendingItems > 0 then
            Scrappy.Print("(" .. cacheInfo.pendingItems .. " items still loading)")
        end
        return
    end
    
    Scrappy.Print("Items that WOULD be sold:")
    for _, item in ipairs(items) do
        local qualityColor = ""
        if item.quality == 2 then qualityColor = "|cff00ff00"
        elseif item.quality == 3 then qualityColor = "|cff0070dd"
        elseif item.quality == 4 then qualityColor = "|cffa335ee" end
        
        local ilvl = tonumber(item.ilvl) or "?"
        Scrappy.Print("  " .. qualityColor .. (item.name or "Unknown") .. "|r (ilvl " .. ilvl .. ")")
    end
    
    Scrappy.Print("Total: " .. #items .. " items would be sold.")
    Scrappy.Print("Use '/scrappy sell' to actually sell these items.")
end

-- WHY: Debug module loading
function Scrappy.Config.DebugModules()
    Scrappy.Print("Module Status:")
    local modules = {"Core", "Config", "UI", "SettingsUI", "Filters", "Cache", "Recovery", "Gear"}
    
    for _, module in ipairs(modules) do
        local status = Scrappy[module] and "✓ Loaded" or "✗ Missing"
        Scrappy.Print("  " .. module .. ": " .. status)
        
        if module == "SettingsUI" and Scrappy[module] then
            local hasShow = Scrappy[module].Show and "✓" or "✗"
            local hasCreateUI = Scrappy[module].CreateUI and "✓" or "✗"
            Scrappy.Print("    Show function: " .. hasShow)
            Scrappy.Print("    CreateUI function: " .. hasCreateUI)
        end
    end
end

-- WHY: Debug item class constants
function Scrappy.Config.DebugItemClasses()
    Scrappy.Print("Item Class Constants:")
    Scrappy.Print("  ITEM_CLASS_CONSUMABLE = " .. tostring(ITEM_CLASS_CONSUMABLE or "nil"))
    Scrappy.Print("  ITEM_CLASS_TRADE_GOODS = " .. tostring(ITEM_CLASS_TRADE_GOODS or "nil"))
    Scrappy.Print("  Expected values: Consumable=0, TradeGoods=7")
    
    -- WHY: Test a few known consumables
    local testItems = {
        [5512] = "Healthstone",  -- Known consumable
        [2447] = "Peacebloom",   -- Known herb
    }
    
    for itemID, itemName in pairs(testItems) do
        local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemID)
        if name then
            Scrappy.Print("  " .. itemName .. " (ID:" .. itemID .. ") = class " .. (class or "nil") .. ", subclass " .. (subclass or "nil"))
        else
            Scrappy.Print("  " .. itemName .. " (ID:" .. itemID .. ") = not cached")
        end
    end
end

-- WHY: Test classification on a specific item
function Scrappy.Config.TestItemClassification(itemID)
    if not itemID then
        Scrappy.Print("Invalid item ID")
        return
    end
    
    local itemInfo = {itemID = itemID}
    local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemID)
    
    if not name then
        Scrappy.Print("Item " .. itemID .. " not found or not cached")
        return
    end
    
    Scrappy.Print("Testing item: " .. name .. " (ID: " .. itemID .. ")")
    Scrappy.Print("  Quality: " .. (quality or "unknown"))
    Scrappy.Print("  Item Level (cached): " .. (ilvl or "unknown"))
    Scrappy.Print("  Min Level: " .. (minLevel or "unknown"))
    Scrappy.Print("  Class: " .. (class or "unknown"))
    Scrappy.Print("  Subclass: " .. (subclass or "unknown"))
    
    -- WHY: Check if this item exists in bags and show actual vs cached ilvl
    local foundInBags = false
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local success, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
        if success and numSlots then
            for slot = 1, numSlots do
                local containerItem = C_Container.GetContainerItemInfo(bag, slot)
                if containerItem and containerItem.itemID == itemID then
                    foundInBags = true
                    local link = C_Container.GetContainerItemLink(bag, slot)
                    local actualIlvl = GetDetailedItemLevelInfo(link)
                    Scrappy.Print("  Found in bag " .. bag .. " slot " .. slot)
                    Scrappy.Print("  Item Level (actual): " .. (actualIlvl or "unknown"))
                    if actualIlvl and ilvl and actualIlvl ~= ilvl then
                        Scrappy.Print("  |cffff0000MISMATCH: Cached=" .. ilvl .. " vs Actual=" .. actualIlvl .. "|r")
                    end
                    break
                end
            end
        end
        if foundInBags then break end
    end
    
    if not foundInBags then
        Scrappy.Print("  Item not found in bags")
    end
    
    -- WHY: Test if it would be sold using bag data if available
    local testItemInfo
    if foundInBags then
        testItemInfo = Scrappy.Cache.GetItemInfoFromSlot and 
            Scrappy.Cache.GetItemInfoFromSlot(bag, slot) or {
            itemID = itemID,
            quality = quality,
            ilvl = ilvl,
            name = name,
            hasNoValue = false
        }
    else
        testItemInfo = {
            itemID = itemID,
            quality = quality,
            ilvl = ilvl,
            name = name,
            hasNoValue = false
        }
    end
    
    local wouldSell = Scrappy.Filters.IsItemSellable(testItemInfo)
    Scrappy.Print("  Would be sold: " .. tostring(wouldSell))
    
    local materialInfo = Scrappy.Filters.GetMaterialInfo(itemInfo)
    if materialInfo then
        Scrappy.Print("  Classification: " .. materialInfo.expansion .. " " .. materialInfo.materialType)
        Scrappy.Print("  Source: " .. materialInfo.source)
        Scrappy.Print("  Protected: " .. tostring(materialInfo.isProtected))
    else
        Scrappy.Print("  Classification: Not a crafting material")
    end
end

-- WHY: Show available commands
function Scrappy.Config.ShowHelp()
    Scrappy.Print("Commands:")
    Scrappy.Print("  /scrappy config              - Open settings UI")
    Scrappy.Print("  /scrappy auto on|off         - Enable/disable auto-sell")
    Scrappy.Print("  /scrappy consumables on|off  - Enable/disable consumable selling (|cffff0000DANGER|r)")
    Scrappy.Print("  /scrappy warbound on|off      - Enable/disable Warbound until equipped protection")
    Scrappy.Print("  /scrappy ilvl [number]       - Set manual item level threshold")
    Scrappy.Print("  /scrappy autothreshold on|off [offset] - Auto-set threshold based on gear")
    Scrappy.Print("  /scrappy tokens on|off        - Enable/disable gear token protection")
    Scrappy.Print("  /scrappy gear                - Show detailed gear analysis")
    Scrappy.Print("  /scrappy quality [#|name] [sell|keep] - Set quality sell rule")
    Scrappy.Print("  /scrappy materials [expansion] [protect|allow] - Set material protection")
    Scrappy.Print("  /scrappy override [itemid] [expansion] [type] - Add classification override")
    Scrappy.Print("  /scrappy order default|value|quality - Set selling order for buyback safety")
    Scrappy.Print("  /scrappy scan                - Scan bags for crafting materials")
    Scrappy.Print("  /scrappy quickscan           - Quick scan (cached items only)")
    Scrappy.Print("  /scrappy precache            - Pre-cache items for better performance")
    Scrappy.Print("  /scrappy testsell            - Test what would be sold (safe preview)")
    Scrappy.Print("  /scrappy sell                - Manually trigger selling")
    Scrappy.Print("  /scrappy test [itemid]       - Test classification on specific item")
    Scrappy.Print("  /scrappy status              - Show current settings")
    Scrappy.Print("  /scrappy retry               - Retry failed selling operations")
    Scrappy.Print("  /scrappy cancel              - Cancel ongoing selling")
    Scrappy.Print("  /scrappy cache               - Show cache statistics")
    Scrappy.Print("  /scrappy stop                - Emergency stop all operations")
    Scrappy.Print(" ")
    Scrappy.Print("Examples:")
    Scrappy.Print("  /scrappy config              - Open the graphical settings panel")
    Scrappy.Print("  /scrappy quality rare keep   - Don't sell rare items")
    Scrappy.Print("  /scrappy consumables off     - Protect all flasks/potions (RECOMMENDED)")
    Scrappy.Print("  /scrappy autothreshold on    - Auto-set threshold 10 below avg equipped ilvl")
    Scrappy.Print("  /scrappy materials legion protect - Protect Legion materials")
end

-- WHY: Register slash commands
SLASH_SCRAPPY1 = "/scrappy"
SlashCmdList["SCRAPPY"] = Scrappy.Config.HandleSlashCommand