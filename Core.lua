-- Core.lua - Main addon initialization and event handling

-- Create our addon namespace
-- WHY: This prevents our variables from conflicting with other addons
local ADDON_NAME = "Scrappy"
local Scrappy = {}
_G[ADDON_NAME] = Scrappy

-- WHY: We store references to our modules here so they can talk to each other
Scrappy.Core = {}
Scrappy.Config = {}
Scrappy.UI = {}
Scrappy.SettingsUI = {}
Scrappy.Filters = {}
Scrappy.Cache = {}
Scrappy.Recovery = {}
Scrappy.Gear = {}

-- WHY: Centralized printing function makes it easy to change formatting later
function Scrappy.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Scrappy:|r " .. msg)
end

-- WHY: Quiet print function for UI changes that can be suppressed
function Scrappy.QuietPrint(msg)
    if not ScrappyDB or not ScrappyDB.quietMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Scrappy:|r " .. msg)
    end
end

-- WHY: Constants are defined once and shared across all modules
Scrappy.QUALITY_NAMES = {
    [0] = "Junk",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic"
}

Scrappy.QUALITY_NAME_TO_ID = {
    junk = 0,
    common = 1,
    uncommon = 2,
    rare = 3,
    epic = 4
}

Scrappy.QUALITY_COLORS = {
    [0] = {r=0.62, g=0.62, b=0.62},
    [1] = {r=1, g=1, b=1},
    [2] = {r=0.12, g=1, b=0},
    [3] = {r=0, g=0.44, b=0.87},
    [4] = {r=0.64, g=0.21, b=0.93}
}

-- WHY: This function will be called by other modules to trigger selling
function Scrappy.Core.SellItems()
    -- WHY: Validate we have a database before proceeding
    if not ScrappyDB then
        Scrappy.Print("Error: Settings not loaded yet. Try again in a moment.")
        return
    end
    
    -- WHY: Check if selling is already in progress
    local sellStatus = Scrappy.Recovery.GetSellStatus()
    if sellStatus.inProgress then
        Scrappy.Print("Selling already in progress (" .. sellStatus.queuedItems .. " items remaining)")
        return
    end
    
    local items = {}
    local errorCount = 0
    local totalScanned = 0
    
    -- WHY: First pass - try to get all items immediately
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local success, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
        if success and numSlots then
            for slot = 1, numSlots do
                totalScanned = totalScanned + 1
                local itemInfo = Scrappy.Cache.GetItemInfoFromSlot(bag, slot)
                if itemInfo then
                    if Scrappy.Filters.IsItemSellable(itemInfo) then
                        table.insert(items, itemInfo)
                    end
                else
                    -- WHY: Item not cached, will be retried automatically
                    errorCount = errorCount + 1
                end
            end
        end
    end
    
    if #items > 0 then
        -- WHY: Use the recovery system for selling
        Scrappy.Recovery.StartSelling(items)
        if errorCount > 0 then
            Scrappy.Print("Note: " .. errorCount .. " of " .. totalScanned .. " items not cached yet - they may appear in future scans")
        end
    else
        if errorCount > 0 then
            Scrappy.Print("No items ready to sell yet. " .. errorCount .. " items still loading - try again in a moment.")
        else
            Scrappy.Print("No items to sell.")
        end
    end
end

-- WHY: Recursive function with timer prevents hitting the server too fast
function Scrappy.Core.SellNextItemQueue(queue)
    if #queue == 0 then return end
    
    local entry = table.remove(queue, 1)
    
    -- WHY: Validate the item still exists before trying to sell it
    local currentItem = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    if not currentItem then
        -- WHY: Item was moved/deleted, skip it and continue
        Scrappy.Core.SellNextItemQueue(queue)
        return
    end
    
    -- WHY: Verify it's still the same item (player might have moved items around)
    if currentItem.itemID ~= entry.itemInfo.itemID then
        -- WHY: Different item in this slot now, skip it
        Scrappy.Core.SellNextItemQueue(queue)
        return
    end
    
    -- WHY: Protected call to prevent errors from stopping the queue
    local success, errorMsg = pcall(C_Container.UseContainerItem, entry.bag, entry.slot)
    if not success then
        Scrappy.Print("Error selling item: " .. (errorMsg or "Unknown error"))
    end
    
    -- WHY: 0.1 second delay prevents server rate limiting
    C_Timer.After(0.1, function()
        Scrappy.Core.SellNextItemQueue(queue)
    end)
end

-- WHY: This function is used by the UI to show what would be sold
function Scrappy.Core.GetItemsToSell()
    if not ScrappyDB then return {} end
    
    local items = {}
    local pendingCount = 0
    
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        local success, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
        if success and numSlots then
            for slot = 1, numSlots do
                local itemInfo = Scrappy.Cache.GetItemInfoFromSlot(bag, slot)
                if itemInfo then
                    if Scrappy.Filters.IsItemSellable(itemInfo) then
                        table.insert(items, itemInfo)
                    end
                else
                    pendingCount = pendingCount + 1
                end
            end
        end
    end
    
    -- WHY: Add metadata about cache status
    items._cacheInfo = {
        pendingItems = pendingCount,
        cacheStats = Scrappy.Cache.GetCacheStats()
    }
    
    return items
end

-- WHY: Event handling is centralized here - makes it easy to see what events we respond to
local function OnMerchantShow()
    if ScrappyDB.autoSell then
        Scrappy.Core.SellItems()
    end
    Scrappy.UI.CreateScrappyButton()
end

-- WHY: Database initialization happens once when addon loads
local function OnAddonLoaded(addonName)
    if addonName ~= ADDON_NAME then return end
    
    -- WHY: We set up default values for our saved variables
    ScrappyDB = ScrappyDB or {}
    ScrappyDB.autoSell = ScrappyDB.autoSell or false
    ScrappyDB.ilvlThreshold = ScrappyDB.ilvlThreshold or 0
    ScrappyDB.protectWarbound = ScrappyDB.protectWarbound or true
    ScrappyDB.sellList = ScrappyDB.sellList or {}
    ScrappyDB.materialFilters = ScrappyDB.materialFilters or {
        classic = false,
        tbc = false,
        wotlk = false,
        cata = false,
        mop = false,
        wod = false,
        legion = false,
        bfa = false,
        shadowlands = false,
        dragonflight = false,
        tww = false
    }
    ScrappyDB.autoConfirmSoulbound = ScrappyDB.autoConfirmSoulbound ~= false  -- Default: true (enabled)
    ScrappyDB.quietMode = ScrappyDB.quietMode or false  -- Default: show messages
    ScrappyDB.sellConsumables = ScrappyDB.sellConsumables or false  -- Default: protect consumables
    ScrappyDB.autoThreshold = ScrappyDB.autoThreshold or false
    ScrappyDB.autoThresholdOffset = ScrappyDB.autoThresholdOffset or -10  -- Default: 10 levels below equipped average
    ScrappyDB.materialOverrides = ScrappyDB.materialOverrides or {}
    ScrappyDB.qualityFilter = ScrappyDB.qualityFilter or {
        [0] = true,  -- Junk
        [1] = true,  -- Common
        [2] = true,  -- Uncommon
        [3] = false, -- Rare
        [4] = false  -- Epic
    }
    
    Scrappy.Print("Loaded successfully!")
end

-- WHY: Single event frame handles all events for the addon
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "MERCHANT_SHOW" then
        OnMerchantShow()
    elseif event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    end
end)