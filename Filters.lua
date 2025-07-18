-- Filters.lua - Item filtering and classification

local Scrappy = _G["Scrappy"]

-- Item class constants
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_CLASS_TRADE_GOODS = 7
local ITEM_CLASS_GEM = 3
local ITEM_CLASS_REAGENT = 5

-- Override table for edge cases that don't classify automatically  
local MATERIAL_OVERRIDES = {
    -- Special profession currencies
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
    
    -- High-value enchanting materials
    [20725] = {expansion = "classic", type = "enchanting"},     -- Nexus Crystal
    [22450] = {expansion = "tbc", type = "enchanting"},         -- Void Crystal
    [34057] = {expansion = "wotlk", type = "enchanting"},       -- Abyss Crystal
    [52722] = {expansion = "cata", type = "enchanting"},        -- Maelstrom Crystal
    [74248] = {expansion = "mop", type = "enchanting"},         -- Sha Crystal
    [111245] = {expansion = "wod", type = "enchanting"},        -- Luminous Shard
    [124442] = {expansion = "legion", type = "enchanting"},     -- Chaos Crystal
    [152877] = {expansion = "bfa", type = "enchanting"},        -- Veiled Crystal
    
    -- Rare herbs
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
    [123918] = {expansion = "legion", type = "ore"},            -- Leystone Ore
    [123919] = {expansion = "legion", type = "ore"},            -- Felslate
    [171833] = {expansion = "shadowlands", type = "ore"},       -- Elethium Ore
    [190311] = {expansion = "dragonflight", type = "ore"},      -- Khaz'gorite Ore
}

-- Pattern matching for material types
local MATERIAL_PATTERNS = {
    herb = {"leaf", "blossom", "flower", "petal", "bloom", "weed", "moss", "vine", "grass", "herb", "root", "lotus", "thistle"},
    ore = {"ore", "nugget", "bar", "ingot", "metal"},
    leather = {"hide", "leather", "skin", "scale", "fur", "pelt"},
    enchanting = {"dust", "essence", "shard", "crystal"},
    gem = {"ruby", "sapphire", "emerald", "diamond", "garnet", "topaz", "opal", "amethyst", "stone", "gem"},
    cloth = {"cloth", "silk", "linen", "wool", "fabric", "thread", "weave"}
}

local classificationStats = {
    totalQueries = 0,
    cacheHits = 0,
    overrideHits = 0,
    apiCalls = 0,
    patternMatches = 0
}

local classificationCache = {}

-- Determine expansion based on item level and ID ranges
local function DetermineExpansion(itemInfo, ilvl, minLevel, name)
    ilvl = ilvl or 0
    minLevel = minLevel or 0
    local itemID = itemInfo.itemID
    
    -- For crafting materials, prioritize item ID ranges over item level
    -- This fixes issues where low-level materials from recent expansions
    -- get misclassified as classic due to low item levels
    
    -- Item ID ranges (most reliable for crafting materials)
    if itemID >= 210000 then return "tww" end
    if itemID >= 190000 then return "dragonflight" end
    if itemID >= 170000 then return "shadowlands" end  -- Shrouded Cloth (173202) should hit this
    if itemID >= 150000 then return "bfa" end
    if itemID >= 120000 then return "legion" end
    if itemID >= 100000 then return "wod" end
    if itemID >= 70000 then return "mop" end
    if itemID >= 50000 then return "cata" end
    if itemID >= 35000 then return "wotlk" end
    if itemID >= 20000 then return "tbc" end
    
    -- Only use item level ranges as fallback for gear items
    -- This helps with gear that might not follow strict ID ranges
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
    
    -- Final fallback for very old items or edge cases
    return "classic"
end

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

-- Check if item is Warbound until equipped
local function IsWarboundUntilEquipped(bag, slot)
    if not bag or not slot then return false end
    
    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if not itemLink then return false end
    
    local tooltipData = C_TooltipInfo.GetBagItem(bag, slot)
    if not tooltipData or not tooltipData.lines then return false end
    
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

-- Fallback warbound detection using tooltip scanning
local function IsWarboundUntilEquippedFallback(bag, slot)
    if not bag or not slot then return false end
    
    if not _G["ScrappyTooltipScanner"] then
        local scanner = CreateFrame("GameTooltip", "ScrappyTooltipScanner", nil, "GameTooltipTemplate")
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    
    local scanner = _G["ScrappyTooltipScanner"]
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)
    
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

-- Item classification using multiple strategies
local function ClassifyItem(itemInfo)
    if not itemInfo or not itemInfo.itemID then return nil end
    
    -- Check saved overrides first (only if database is loaded)
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
    
    -- Check hardcoded overrides (built-in edge cases)
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
    
    -- Use WoW's item classification API
    local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemInfo.itemID)
    if not name then return nil end
    
    classificationStats.apiCalls = classificationStats.apiCalls + 1
    
    -- Check if it's a crafting material by item class
    local isCraftingMaterial = (class == ITEM_CLASS_TRADE_GOODS) or 
                              (class == ITEM_CLASS_GEM) or 
                              (class == ITEM_CLASS_REAGENT) or
                              (class == "Trade Goods") or
                              (class == "Tradeskill") or  -- Some items return "Tradeskill" instead
                              (class == "Gem") or
                              (class == "Reagent")
    
    if not isCraftingMaterial then return nil end
    
    -- Determine expansion and material type
    local expansion = DetermineExpansion(itemInfo, ilvl, minLevel, name)
    local materialType = GetMaterialTypeFromName(name)
    
    return {
        isCraftingMaterial = true,
        expansion = expansion,
        materialType = materialType,
        source = "dynamic"
    }
end

-- Main classification function with caching
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
        classificationCache[itemInfo.itemID] = classification
    else
        -- Cache negative results temporarily to avoid repeated failed lookups
        classificationCache[itemInfo.itemID] = {
            isCraftingMaterial = false,
            failed = true,
            timestamp = GetTime()
        }
    end
    
    return classification
end

-- Clear old failed cache entries periodically
local function CleanupClassificationCache()
    local currentTime = GetTime()
    local cleaned = 0
    
    for itemID, classification in pairs(classificationCache) do
        -- Remove failed entries older than 30 seconds
        if classification.failed and currentTime - (classification.timestamp or 0) > 30 then
            classificationCache[itemID] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        Scrappy.QuietPrint("Cleaned " .. cleaned .. " expired cache entries")
    end
end

-- Periodic cache cleanup
local cleanupTimer = C_Timer.NewTicker(30, CleanupClassificationCache)

function Scrappy.Filters.GetItemInfoFromSlot(bag, slot)
    return Scrappy.Cache.GetItemInfoFromSlot(bag, slot)
end

-- Core filtering function with protections
function Scrappy.Filters.IsItemSellable(itemInfo)
    -- Basic validation
    if not itemInfo or not itemInfo.itemID then 
        return false 
    end
    if itemInfo.hasNoValue then 
        return false 
    end
    if not ScrappyDB then 
        return false 
    end

    -- Get item classification first to check for consumables and profession gear
    local name, link, quality, ilvl, minLevel, class, subclass = GetItemInfo(itemInfo.itemID)
    if not name then 
        return false 
    end

    -- CRITICAL FIX: Always get the actual item level from bag when possible
    local actualIlvl = ilvl or 0
    
    if itemInfo.bag and itemInfo.slot then
        local containerItemLink = C_Container.GetContainerItemLink(itemInfo.bag, itemInfo.slot)
        if containerItemLink then
            local detailedIlvl = GetDetailedItemLevelInfo(containerItemLink)
            if detailedIlvl and detailedIlvl > 0 then
                actualIlvl = detailedIlvl
            end
        end
    end
    
    if itemInfo.ilvl and tonumber(itemInfo.ilvl) and tonumber(itemInfo.ilvl) ~= tonumber(ilvl) then
        actualIlvl = tonumber(itemInfo.ilvl)
    end

    -- Check for Warbound until equipped items (if protection is enabled)
    if ScrappyDB and ScrappyDB.protectWarbound and itemInfo.bag and itemInfo.slot then
        
        local isWarbound = false
        local success, result = pcall(IsWarboundUntilEquipped, itemInfo.bag, itemInfo.slot)
        if success then
            isWarbound = result
        else
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

    -- Enhanced gear token protection (if protection is enabled)
    if ScrappyDB and ScrappyDB.protectTokens and name then
        
        local lowerName = name:lower()
        
        -- Comprehensive token detection patterns
        local tokenPatterns = {
            -- Classic tier token patterns
            "helm of the.*conqueror", "pauldrons of the.*conqueror", "breastplate of the.*conqueror",
            "gauntlets of the.*conqueror", "leggings of the.*conqueror",
            "helm of the.*protector", "pauldrons of the.*protector", "breastplate of the.*protector", 
            "gauntlets of the.*protector", "leggings of the.*protector",
            "helm of the.*vanquisher", "pauldrons of the.*vanquisher", "breastplate of the.*vanquisher",
            "gauntlets of the.*vanquisher", "leggings of the.*vanquisher",
            
            -- General token patterns
            ".*token", ".*insignia", ".*emblem", ".*badge", ".*seal",
            "fragment of", "shard of", "essence of.*armor", "armor.*essence",
            
            -- Tier and set patterns
            "tier.*token", "set.*token", "armor.*token", "tier.*fragment", "set.*fragment",
            "tier.*shard", "set.*shard", "tier.*piece", "set.*piece",
            
            -- Shadowlands specific patterns
            ".*module", "mystic.*module", ".*tier.*module", "shoulder.*module", 
            "chest.*module", "helm.*module", "leg.*module", "glove.*module",
            ".*nexus", ".*core", "conduit.*upgrade", "soulbind.*upgrade",
            
            -- Upgrade and catalyst patterns
            ".*catalyst", "revival.*catalyst", "creation.*catalyst", "tier.*catalyst",
            "upgrade.*crystal", "catalyst.*charge", "revival.*charge",
            
            -- Currency-like tokens that are actually items
            ".*charge", "primordial.*saronite", "runed.*orb",
            "trophy of the.*crusade", "mark of.*sanctification",
            
            -- Modern expansion patterns
            ".*cache", ".*coffer", ".*vault", ".*chest.*token",
            ".*upgrade.*token", ".*tier.*token", ".*gear.*token",
            
            -- Dragonflight patterns
            "primal.*spark", "concentrated.*primal", "shadowflame.*spark",
            "aspect.*crest", "wyrm.*crest", "drake.*crest", "whelp.*crest",
            "enchanted.*crest", "runed.*crest", "gilded.*crest",
            
            -- The War Within patterns
            "valorstone", "weathered.*valorstone", "carved.*valorstone", "runed.*valorstone",
            "gilded.*valorstone", ".*aspect", ".*fragment.*aspect",
            
            -- General upgrade materials that might be tokens
            "upgrade.*stone", "upgrade.*gem", "upgrade.*orb",
            "empowerment.*token", "enhancement.*token", "improvement.*token",
            
            -- PvP tokens
            "conquest.*token", "honor.*token", "gladiator.*token", "elite.*token",
            "pvp.*token", "rated.*token", "arena.*token", "battleground.*token",
            
            -- Mythic+ and raid tokens
            "mythic.*token", "raid.*token", "dungeon.*token", "keystone.*token",
            "weekly.*token", "bonus.*token", "cache.*token"
        }
        
        -- Check for token patterns
        for _, pattern in ipairs(tokenPatterns) do
            if lowerName:find(pattern) then
                Scrappy.QuietPrint("PROTECTED: " .. name .. " (gear token pattern: " .. pattern .. ")")
                return false
            end
        end
        
        -- Enhanced detection for items that might be tokens but don't match patterns
        local tokenQuality = quality or 0
        local tokenIlvl = tonumber(actualIlvl) or 0
        
        -- Check for high-quality items with suspicious characteristics
        if tokenQuality >= 2 then -- Uncommon or higher
            -- Items with these keywords are likely tokens regardless of other factors
            local highSuspicionKeywords = {
                "tier", "set", "armor", "weapon", "trophy", "mark", "emblem", 
                "badge", "insignia", "seal", "fragment", "shard", "essence",
                "upgrade", "enhancement", "improvement", "empowerment",
                "catalyst", "spark", "crest", "valorstone", "aspect",
                "module", "nexus", "core", "crystal", "orb", "charge"
            }
            
            for _, keyword in ipairs(highSuspicionKeywords) do
                if lowerName:find(keyword) then
                    
                    -- Additional context checks to reduce false positives
                    local contextKeywords = {
                        "gear", "equipment", "armor", "weapon", "tier", "set",
                        "upgrade", "token", "fragment", "shard", "piece"
                    }
                    
                    local hasContext = false
                    for _, context in ipairs(contextKeywords) do
                        if lowerName:find(context) then
                            hasContext = true                            break
                        end
                    end
                    
                    -- If it has suspicious keyword + context, protect it
                    if hasContext then
                        Scrappy.QuietPrint("PROTECTED: " .. name .. " (likely gear token - suspicious keyword: " .. keyword .. " with context)")
                        return false
                    end
                    
                    -- Even without context, protect high-quality items with very suspicious keywords
                    local criticalKeywords = {"tier", "set", "upgrade", "catalyst", "spark", "valorstone", "module"}
                    for _, critical in ipairs(criticalKeywords) do
                        if keyword == critical then
                            Scrappy.QuietPrint("PROTECTED: " .. name .. " (likely gear token - critical keyword: " .. keyword .. ")")
                            return false
                        end
                    end
                end
            end
        end
        
        -- Special case: Epic or Legendary items with no item level are very suspicious
        if tokenIlvl == 0 and tokenQuality >= 4 then -- Epic or Legendary with no ilvl
            Scrappy.QuietPrint("PROTECTED: " .. name .. " (Epic/Legendary with no ilvl - likely token)")
            return false
        end
        
        -- Special case: Items with "mystic" in the name (Shadowlands tier modules)
        if lowerName:find("mystic") then
            Scrappy.QuietPrint("PROTECTED: " .. name .. " (contains 'mystic' - likely Shadowlands tier token)")
            return false
        end
        
        -- FIXED: Check item class/subclass for additional token indicators
        if class then
            local lowerClass = tostring(class):lower()
            -- Miscellaneous items are often tokens, BUT exclude actual equipment
            if lowerClass:find("miscellaneous") and tokenQuality >= 3 then
                
                -- IMPORTANT: Check if this is actually equippable gear
                -- If it has an equipment slot, it's real gear, not a token
                local itemEquipLoc = select(9, GetItemInfo(itemInfo.itemID))
                
                if itemEquipLoc and itemEquipLoc ~= "" then
                    -- This is equippable gear (trinket, ring, etc.) - NOT a token
                else
                    -- This is non-equippable miscellaneous item - likely a token
                    local miscTokenKeywords = {"upgrade", "tier", "set", "token", "fragment", "shard", "catalyst", "spark", "crest"}
                    for _, keyword in ipairs(miscTokenKeywords) do
                        if lowerName:find(keyword) then
                            Scrappy.QuietPrint("PROTECTED: " .. name .. " (high-quality miscellaneous item with token keyword: " .. keyword .. ")")
                            return false
                        end
                    end
                end
            end
        end
    end
    
    -- Enhanced consumable protection - allow junk-quality consumables
    if class == 0 or class == "Consumable" then
        
        local consumableQuality = quality or 0
        
        -- Allow junk-quality consumables to be sold (they're usually vendor trash)
        if consumableQuality == 0 then
            Scrappy.QuietPrint("Allowing junk consumable: " .. (name or "Unknown Item") .. " (quality 0, class=" .. tostring(class) .. ")")
            -- Continue with normal filtering logic instead of returning false
        else
            -- For higher quality consumables, still protect them
            Scrappy.QuietPrint("PROTECTED: " .. (name or "Unknown Item") .. " (consumable, class=" .. tostring(class) .. ")")
            return false
        end
    end
    
    -- Never sell profession equipment
    if class == 7 or class == "Trade Goods" then       
        -- Profession Tools subclass
        if subclass == 12 or subclass == "Device" or subclass == "Devices" then
            Scrappy.QuietPrint("PROTECTED: " .. (name or "Unknown Item") .. " (profession tool)")
            return false
        end
        
        -- Food & Drink protection
        if subclass == 8 or subclass == "Food & Drink" then
            Scrappy.QuietPrint("PROTECTED: " .. (name or "Unknown Item") .. " (food/drink)")
            return false
        end
    end
    
    -- Enhanced name-based protection for profession equipment that might slip through
    if name then
        local lowerName = name:lower()
                
        -- Consumable keywords - use word boundaries to avoid false matches
        local consumableKeywords = {
            "flask", "potion", "elixir", "food", "drink", "scroll", "bandage", 
            "healthstone", "conjured", "feast", "fish", "bread", "cheese",
            "pylon", "statue", "totem", "crystal", "orb", "phial", 
            "cavedweller", "delight", "soup", "stew", "cake", "pie"
        }
        
        -- Profession tool keywords
        local professionKeywords = {
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
        
        -- Check for consumable keywords (but only if not already handled above)
        local itemQuality = quality or 0
        if itemQuality > 0 then -- Only check if not junk quality (junk consumables allowed above)
            for _, keyword in ipairs(consumableKeywords) do
                if lowerName:find(keyword) then
                    Scrappy.QuietPrint("PROTECTED: " .. name .. " (consumable keyword: " .. keyword .. ")")
                    return false
                end
            end
        end
        
        -- Check for profession tool keywords
        for _, pattern in ipairs(professionKeywords) do
            if lowerName:find(pattern) then
                Scrappy.QuietPrint("PROTECTED: " .. name .. " (profession tool pattern: " .. pattern .. ")")
                return false
            end
        end
        
        -- Additional specific profession tool checks using word boundaries
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

    -- Check quality filters first (this determines base sellability)
    local itemQuality = quality or 0
    local qualityAllowsSelling = ScrappyDB and ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[itemQuality]
        
    -- If quality doesn't allow selling, don't sell regardless of item level
    if not qualityAllowsSelling then
        return false
    end

    -- Check explicit sell list (overrides everything else)
    if ScrappyDB and ScrappyDB.sellList and ScrappyDB.sellList[itemInfo.itemID] then
        return true
    end

    -- IMPORTANT: Check material protection BEFORE item level threshold
    -- Materials should be protected regardless of their item level
    if ScrappyDB and ScrappyDB.materialFilters then        
        local classification = GetItemClassification(itemInfo)
        if classification and classification.isCraftingMaterial and classification.expansion then
            local isProtected = ScrappyDB.materialFilters[classification.expansion]
            if isProtected then
                return false  -- Don't sell protected materials
            end
        end
    end

    -- Check item level threshold (only if quality allows selling and materials aren't protected)
    local ilvlThreshold = (ScrappyDB and ScrappyDB.ilvlThreshold) or 0
    local itemIlvl = tonumber(actualIlvl) or 0
        
    -- If threshold is set and item has level, use threshold logic
    if ilvlThreshold > 0 and itemIlvl > 0 then
        if itemIlvl <= ilvlThreshold then
            return true  -- Sell items at or below threshold
        else
            return false -- Don't sell items above threshold
        end
    end

    -- Default behavior when no threshold is set - only sell based on quality
    return true
end

-- Helper function using smart classification
function Scrappy.Filters.IsExpansionMaterial(itemID)
    local itemInfo = {itemID = itemID}
    local classification = GetItemClassification(itemInfo)
    if classification and classification.isCraftingMaterial then
        return classification.expansion
    end
    return nil
end

-- Get detailed material information
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

-- Get classification performance statistics
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

-- Clear classification cache when needed
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

-- Force cache items immediately for better performance
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
                    -- Force WoW to cache the item
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