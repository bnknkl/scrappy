-- Filters.lua - Smart item filtering with hybrid classification and Warbound protection

-- WHY: Get reference to our addon namespace
local Scrappy = _G["Scrappy"]

-- WHY: Item class constants from WoW's API
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_CLASS_TRADE_GOODS = 7
local ITEM_CLASS_GEM = 3
local ITEM_CLASS_REAGENT = 5

-- WHY: Small override table for items that don't classify correctly automatically
-- This replaces the massive 2000+ item table with just the edge cases
local MATERIAL_OVERRIDES = {
    -- Special profession currencies that don't follow normal patterns
    [124124] = {expansion = "legion", type = "special"},        -- Blood of Sargeras
    [190454] = {expansion = "dragonflight", type = "special"},  -- Primal Chaos
    [191251] = {expansion = "dragonflight", type = "special"},  -- Primal Focus
    [171428] = {expansion = "shadowlands", type = "special"},   -- Heavy Callous Hide
    [152668] = {expansion = "bfa", type = "special"},           -- Expulsom
    [113588] = {expansion = "wod", type = "special"},           -- Temporal Crystal
    [151568] = {expansion = "legion", type = "special"},        -- Primal Sargerite
    [184395] = {expansion = "shadowlands", type = "special"},   -- Vestige of Origins
    [211515] = {expansion = "tww", type = "special"},           -- Residual Memories
    [224069] = {expansion = "tww", type = "special"},           -- Concentrated Residual Memories
    
    -- High-value items that might classify as wrong expansion due to level scaling
    [20725] = {expansion = "classic", type = "enchanting"},     -- Nexus Crystal
    [22450] = {expansion = "tbc", type = "enchanting"},         -- Void Crystal
    [34057] = {expansion = "wotlk", type = "enchanting"},       -- Abyss Crystal
    [52722] = {expansion = "cata", type = "enchanting"},        -- Maelstrom Crystal
    [74248] = {expansion = "mop", type = "enchanting"},         -- Sha Crystal
    [111245] = {expansion = "wod", type = "enchanting"},        -- Luminous Shard
    [124442] = {expansion = "legion", type = "enchanting"},     -- Chaos Crystal
    [152877] = {expansion = "bfa", type = "enchanting"},        -- Veiled Crystal
    
    -- Rare herbs that might not classify correctly
    [13468] = {expansion = "classic", type = "herb"},           -- Black Lotus
    [22793] = {expansion = "tbc", type = "herb"},               -- Mana Thistle
    [36908] = {expansion = "wotlk", type = "herb"},             -- Frost Lotus
    [79011] = {expansion = "mop", type = "herb"},               -- Fool's Cap
    [124105] = {expansion = "legion", type = "herb"},           -- Starlight Rose
    [152510] = {expansion = "bfa", type = "herb"},              -- Anchor Weed
    
    -- Valuable ores
    [23426] = {expansion = "tbc", type = "ore"},                -- Khorium Ore
    [36910] = {expansion = "wotlk", type = "ore"},              -- Titanium Ore
    [52183] = {expansion = "cata", type = "ore"},               -- Pyrite Ore
    [72103] = {expansion = "mop", type = "ore"},                -- White Trillium Ore
    [123919] = {expansion = "legion", type = "ore"},            -- Felslate
    [171833] = {expansion = "shadowlands", type = "ore"},       -- Elethium Ore
    [190311] = {expansion = "dragonflight", type = "ore"},      -- Khaz'gorite Ore
}

-- WHY: Pattern-based classification for material types
local MATERIAL_PATTERNS = {
    herb = {"leaf", "blossom", "flower", "petal", "bloom", "weed", "moss", "vine", "grass", "herb", "root", "lotus", "thistle"},
    ore = {"ore", "nugget", "bar", "ingot", "metal"},
    leather = {"hide", "leather", "skin", "scale", "fur", "pelt"},
    enchanting = {"dust", "essence", "shard", "crystal"},
    gem = {"ruby", "sapphire", "emerald", "diamond", "garnet", "topaz", "opal", "amethyst", "stone", "gem"},
    cloth = {"cloth", "silk", "linen", "wool", "fabric", "thread", "weave"}
}

-- WHY: Performance tracking
local classificationStats = {
    totalQueries = 0,
    cacheHits = 0,
    overrideHits = 0,
    apiCalls = 0,
    patternMatches = 0
}

-- WHY: Cache for item classifications
local classificationCache = {}

-- WHY: Smart expansion detection using multiple factors
local function DetermineExpansion(itemInfo, ilvl, minLevel, name)
    ilvl = ilvl or 0
    minLevel = minLevel or 0
    local itemID = itemInfo.itemID
    
    -- Strategy 1: Item level ranges (most accurate for gear)
    if minLevel >= 70 and ilvl >= 580 then return "tww" end
    if minLevel >= 70 and ilvl >= 550 then return "tww" end
    if minLevel >= 60 and ilvl >= 350 then return "dragonflight" end
    if minLevel >= 50 and ilvl >= 100 then return "shadowlands" end
    if minLevel >= 110 and ilvl >= 280 then return "bfa" end
    if minLevel >= 100 and ilvl >= 650 then return "legion" end
    if minLevel >= 90 and ilvl >= 590 then return "wod" end
    if minLevel >= 85 and ilvl >= 380 then return "mop" end
    if minLevel >= 80 and ilvl >= 280 then return "cata" end
    if minLevel >= 68 and ilvl >= 200 then return "wotlk" end
    if minLevel >= 58 and ilvl >= 80 then return "tbc" end
    if ilvl > 0 and ilvl < 80 then return "classic" end
    
    -- Strategy 2: Item ID ranges (fallback for crafting materials)
    if itemID >= 210000 then return "tww" end
    if itemID >= 190000 then return "dragonflight" end
    if itemID >= 170000 then return "shadowlands" end
    if itemID >= 150000 then return "bfa" end
    if itemID >= 120000 then return "legion" end
    if itemID >= 100000 then return "wod" end
    if itemID >= 70000 then return "mop" end
    if itemID >= 50000 then return "cata" end
    if itemID >= 35000 then return "wotlk" end
    if itemID >= 20000 then return "tbc" end
    
    return "classic"
end

-- WHY: Determine material type from item name patterns
local function GetMaterialTypeFromName(name)
    if not name then return "other" end
    
    local lowerName = name:lower()
    for materialType, patterns in pairs(MATERIAL_PATTERNS) do
        for _, pattern in ipairs(patterns) do
            if lowerName:find(pattern) then
                classificationStats.patternMatches = classificationStats.patternMatches + 1
                return materialType
            end
        end
    end
    return "other"
end

-- WHY: Check if an item is Warbound until equipped
local function IsWarboundUntilEquipped(bag, slot)
    if not bag or not slot then return false end
    
    -- WHY: Get the item link to examine its properties
    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if not itemLink then return false end
    
    -- WHY: Check tooltip for Warbound text
    local tooltipData = C_TooltipInfo.GetBagItem(bag, slot)
    if not tooltipData or not tooltipData.lines then return false end
    
    -- WHY: Look for "Warbound until equipped" text in tooltip
    for _, line in ipairs(tooltipData.lines) do
        if line.leftText then
            local text = line.leftText:lower()
            if text:find("warbound until equipped") then
                return true
            end
        end
    end
    
    return false
end

-- WHY: Fallback method for Warbound detection using tooltip scanning
local function IsWarboundUntilEquippedFallback(bag, slot)
    if not bag or not slot then return false end
    
    -- WHY: Create a hidden tooltip frame for scanning
    if not _G["ScrappyTooltipScanner"] then
        local scanner = CreateFrame("GameTooltip", "ScrappyTooltipScanner", nil, "GameTooltipTemplate")
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    
    local scanner = _G["ScrappyTooltipScanner"]
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)
    
    -- WHY: Scan tooltip lines for Warbound text
    for i = 1, scanner:NumLines() do
        local line = _G["ScrappyTooltipScannerTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:lower():find("warbound until equipped") then
                return true
            end
        end
    end
    
    return false
end

-- WHY: Smart item classification using multiple strategies
local function ClassifyItem(itemInfo)
    if not itemInfo or not itemInfo.itemID then return nil end
    
    -- Strategy 1: Check saved overrides first
    if ScrappyDB and ScrappyDB.materialOverrides and ScrappyDB.materialOverrides[itemInfo.itemID] then
        local override = ScrappyDB.materialOverrides[itemInfo.itemID]
        classificationStats.overrideHits = classificationStats.overrideHits + 1
        return {
            isCraftingMaterial = true,
            expansion = override.expansion,
            materialType = override.type,
            source = "user_override"
        }
    end
    
    -- Strategy 2: Check hardcoded overrides (built-in edge cases)
    local override = MATERIAL_OVERRIDES[itemInfo.itemID]
    if override then
        classificationStats.overrideHits = classificationStats.overrideHits + 1
        return {
            isCraftingMaterial = true,
            expansion = override.expansion,
            materialType = override.type,
            source = "builtin_override"
        }
    end
    
    -- Strategy 3: Use WoW's item classification API
    local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemInfo.itemID)
    if not name then return nil end
    
    classificationStats.apiCalls = classificationStats.apiCalls + 1
    
    -- Check if it's a crafting material by item class
    local isCraftingMaterial = (class == ITEM_CLASS_TRADE_GOODS) or 
                              (class == ITEM_CLASS_GEM) or 
                              (class == ITEM_CLASS_REAGENT)
    
    if not isCraftingMaterial then return nil end
    
    -- Strategy 4: Determine expansion and material type
    local expansion = DetermineExpansion(itemInfo, ilvl, minLevel, name)
    local materialType = GetMaterialTypeFromName(name)
    
    return {
        isCraftingMaterial = true,
        expansion = expansion,
        materialType = materialType,
        source = "dynamic"
    }
end

-- WHY: Main classification function with better caching and rate limiting
local function GetItemClassification(itemInfo)
    if not itemInfo or not itemInfo.itemID then return nil end
    
    classificationStats.totalQueries = classificationStats.totalQueries + 1
    
    -- Check cache first
    local cached = classificationCache[itemInfo.itemID]
    if cached then
        classificationStats.cacheHits = classificationStats.cacheHits + 1
        return cached
    end
    
    -- Compute classification
    local classification = ClassifyItem(itemInfo)
    if classification then
        -- WHY: Cache successful classifications
        classificationCache[itemInfo.itemID] = classification
    else
        -- WHY: Cache negative results temporarily to avoid repeated failed lookups
        classificationCache[itemInfo.itemID] = {
            isCraftingMaterial = false,
            failed = true,
            timestamp = GetTime()
        }
    end
    
    return classification
end

-- WHY: Clear old failed cache entries periodically
local function CleanupClassificationCache()
    local currentTime = GetTime()
    local cleaned = 0
    
    for itemID, classification in pairs(classificationCache) do
        -- WHY: Remove failed entries older than 30 seconds
        if classification.failed and currentTime - (classification.timestamp or 0) > 30 then
            classificationCache[itemID] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        Scrappy.Print("Cleaned " .. cleaned .. " expired cache entries")
    end
end

-- WHY: Periodic cache cleanup
local cleanupTimer = C_Timer.NewTicker(30, CleanupClassificationCache)

-- WHY: This function extracts item information from a bag slot
function Scrappy.Filters.GetItemInfoFromSlot(bag, slot)
    -- WHY: Use the enhanced cache system for better reliability
    return Scrappy.Cache.GetItemInfoFromSlot(bag, slot)
end

-- WHY: Updated core filtering function with STRICT consumable, profession, and Warbound protection
function Scrappy.Filters.IsItemSellable(itemInfo)
    -- WHY: Basic validation
    if not itemInfo or not itemInfo.itemID then return false end
    if itemInfo.hasNoValue then return false end
    if not ScrappyDB then return false end

    -- WHY: ABSOLUTE PROTECTION - Check for Warbound until equipped items
    if itemInfo.bag and itemInfo.slot then
        local isWarbound = false
        
        -- WHY: Try modern API first, fallback to tooltip scanning
        local success, result = pcall(IsWarboundUntilEquipped, itemInfo.bag, itemInfo.slot)
        if success then
            isWarbound = result
        else
            -- WHY: Fallback to tooltip scanning
            local fallbackSuccess, fallbackResult = pcall(IsWarboundUntilEquippedFallback, itemInfo.bag, itemInfo.slot)
            if fallbackSuccess then
                isWarbound = fallbackResult
            end
        end
        
        if isWarbound then
            Scrappy.QuietPrint("PROTECTED: " .. (itemInfo.name or "Unknown Item") .. " (Warbound until equipped)")
            return false
        end
    end

    -- WHY: Get item classification to check for consumables and profession gear
    local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemInfo.itemID)
    if not name then 
        -- WHY: Item not cached, can't determine if it's safe, so don't sell it
        return false 
    end
    
    -- WHY: ABSOLUTE PROTECTION - Check both numeric and string class values for consumables
    if class == 0 or class == "Consumable" then
        Scrappy.QuietPrint("PROTECTED: " .. (name or "Unknown Item") .. " (consumable, class=" .. tostring(class) .. ")")
        return false
    end
    
    -- WHY: ABSOLUTE PROTECTION - Never sell profession equipment
    if class == 7 or class == "Trade Goods" then
        -- WHY: Profession Tools subclass
        if subclass == 12 or subclass == "Device" or subclass == "Devices" then
            Scrappy.QuietPrint("PROTECTED: " .. (name or "Unknown Item") .. " (profession tool)")
            return false
        end
        
        -- WHY: Food & Drink protection
        if subclass == 8 or subclass == "Food & Drink" then
            Scrappy.QuietPrint("PROTECTED: " .. (name or "Unknown Item") .. " (food/drink)")
            return false
        end
    end
    
    -- WHY: Enhanced name-based protection for profession equipment that might slip through
    if name then
        local lowerName = name:lower()
        
        -- WHY: Consumable keywords - use word boundaries to avoid false matches
        local consumableKeywords = {
            "flask", "potion", "elixir", "food", "drink", "scroll", "bandage", 
            "healthstone", "conjured", "feast", "fish", "bread", "cheese",
            "pylon", "statue", "totem", "crystal", "orb", "phial", 
            "cavedweller", "delight", "soup", "stew", "cake", "pie"
        }
        
        -- WHY: Profession tool keywords - use word boundaries and more specific patterns
        local professionKeywords = {
            -- WHY: Use word boundaries (%f[%w]) to match whole words only
            "skinning knife", "mining pick", "herbalism", "blacksmith hammer", 
            "hammer", "tongs", "anvil", "forge", "crucible", "mortar", "pestle",
            "needle", "thread", "awl", "knife", "chisel", "file", "pliers",
            "lockpick", "thieves' tools", "enchanting rod", "runed.*rod",
            "alchemist.*stone", "philosopher.*stone",
            "engineering.*spanner", "gyromatic", "arclight spanner",
            "fishing pole", "fishing rod", "lure", "bait", "tackle box", 
            "jewelcrafter.*loupe", "gem.*cutter", "cutting.*tool",
            "leatherworker.*knife", "fleshing.*knife", "skinning.*knife",
            "tailoring.*needle", "embroidery.*needle", "spinning wheel",
            "cooking.*pot", "cauldron", "ladle", "spatula", "cleaver",
            "inscription.*quill", "scribing.*tool", "vellum"
        }
        
        -- WHY: Check for consumable keywords (simple contains check for these)
        for _, keyword in ipairs(consumableKeywords) do
            if lowerName:find(keyword) then
                Scrappy.QuietPrint("PROTECTED: " .. name .. " (consumable keyword: " .. keyword .. ")")
                return false
            end
        end
        
        -- WHY: Check for profession tool keywords (more specific matching)
        for _, pattern in ipairs(professionKeywords) do
            if lowerName:find(pattern) then
                Scrappy.QuietPrint("PROTECTED: " .. name .. " (profession tool pattern: " .. pattern .. ")")
                return false
            end
        end
        
        -- WHY: Additional specific profession tool checks using word boundaries
        local specificChecks = {
            {pattern = "%f[%w]ink%f[%W]", description = "ink"}, -- Only match "ink" as whole word
            {pattern = "%f[%w]rod%f[%W]", description = "rod"}, -- Only match "rod" as whole word  
            {pattern = "%f[%w]pick%f[%W]", description = "pick"}, -- Only match "pick" as whole word
            {pattern = "%f[%w]awl%f[%W]", description = "awl"}, -- Only match "awl" as whole word
            {pattern = "enchant.*rod", description = "enchanting rod"},
            {pattern = "fishing.*pole", description = "fishing pole"},
            {pattern = "mining.*pick", description = "mining pick"},
            {pattern = "skinning.*knife", description = "skinning knife"},
        }
        
        for _, check in ipairs(specificChecks) do
            if lowerName:find(check.pattern) then
                Scrappy.QuietPrint("PROTECTED: " .. name .. " (profession tool: " .. check.description .. ")")
                return false
            end
        end
    end

    -- WHY: Check quality filters
    local quality = itemInfo.quality or 0
    if ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[quality] == false then
        return false
    end

    -- WHY: Check explicit sell list
    if ScrappyDB.sellList and ScrappyDB.sellList[itemInfo.itemID] then
        return true
    end

    -- WHY: Check item level threshold
    local ilvlThreshold = ScrappyDB.ilvlThreshold or 0
    local ilvl = tonumber(itemInfo.ilvl) or 0
    if ilvlThreshold > 0 and ilvl > 0 and ilvl <= ilvlThreshold then
        return true
    end

    -- WHY: Use smart classification for material filtering
    if ScrappyDB.materialFilters then
        local classification = GetItemClassification(itemInfo)
        if classification and classification.isCraftingMaterial and classification.expansion then
            local isProtected = ScrappyDB.materialFilters[classification.expansion]
            if isProtected then
                return false  -- Don't sell protected materials
            end
        end
    end

    -- WHY: Default behavior - sell junk quality items
    return quality == 0
end

-- WHY: Helper function using smart classification
function Scrappy.Filters.IsExpansionMaterial(itemID)
    local itemInfo = {itemID = itemID}
    local classification = GetItemClassification(itemInfo)
    if classification and classification.isCraftingMaterial then
        return classification.expansion
    end
    return nil
end

-- WHY: Get detailed material information
function Scrappy.Filters.GetMaterialInfo(itemInfo)
    local classification = GetItemClassification(itemInfo)
    if classification and classification.isCraftingMaterial then
        return {
            expansion = classification.expansion,
            materialType = classification.materialType,
            isProtected = ScrappyDB.materialFilters and ScrappyDB.materialFilters[classification.expansion] or false,
            source = classification.source
        }
    end
    return nil
end

-- WHY: Get classification performance statistics
function Scrappy.Filters.GetClassificationStats()
    local cacheSize = 0
    for _ in pairs(classificationCache) do
        cacheSize = cacheSize + 1
    end
    
    return {
        totalQueries = classificationStats.totalQueries,
        cacheHits = classificationStats.cacheHits,
        overrideHits = classificationStats.overrideHits,
        apiCalls = classificationStats.apiCalls,
        patternMatches = classificationStats.patternMatches,
        cacheSize = cacheSize,
        cacheHitRate = classificationStats.totalQueries > 0 and 
                      (classificationStats.cacheHits / classificationStats.totalQueries * 100) or 0
    }
end

-- WHY: Clear classification cache when needed
function Scrappy.Filters.ClearClassificationCache()
    classificationCache = {}
    classificationStats = {
        totalQueries = 0,
        cacheHits = 0,
        overrideHits = 0,
        apiCalls = 0,
        patternMatches = 0
    }
    Scrappy.Print("Classification cache cleared")
end

-- WHY: Force cache items immediately for better performance
function Scrappy.Filters.PreCacheItems()
    local cached = 0
    local failed = 0
    
    Scrappy.Print("Pre-caching items in bags...")
    
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local success, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
        if success and numSlots then
            for slot = 1, numSlots do
                local containerItem = C_Container.GetContainerItemInfo(bag, slot)
                if containerItem and containerItem.itemID then
                    -- WHY: Force WoW to cache the item
                    local name = GetItemInfo(containerItem.itemID)
                    if name then
                        cached = cached + 1
                    else
                        failed = failed + 1
                    end
                end
            end
        end
    end
    
    Scrappy.Print("Pre-cache complete: " .. cached .. " cached, " .. failed .. " failed")
    if failed > 0 then
        Scrappy.Print("Wait a moment and try '/scrappy scan' again")
    end
end