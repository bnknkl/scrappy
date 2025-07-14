-- Cache.lua - Item caching and retry system

local Scrappy = _G["Scrappy"]
Scrappy.Cache = {}

-- Store cached item info to avoid repeated API calls
local itemCache = {}

-- Track items that need to be retried due to cache misses
local pendingItems = {}

-- Prevent infinite retry loops
local MAX_RETRY_ATTEMPTS = 3
local RETRY_DELAY = 0.5

-- Cache item information to improve performance and reliability
function Scrappy.Cache.GetItemInfo(itemID)
    if not itemID or itemID <= 0 then return nil end
    
    -- Check if we already have this item cached
    if itemCache[itemID] then
        return itemCache[itemID]
    end
    
    -- Try to get item info from WoW's API
    local name, _, quality, ilvl, minLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(itemID)
    
    if name then
        -- Cache the result for future use
        local itemInfo = {
            itemID = itemID,
            name = name,
            quality = quality or 0,
            ilvl = ilvl or 0,
            minLevel = minLevel or 0,
            class = class,
            subclass = subclass,
            maxStack = maxStack or 1,
            equipSlot = equipSlot,
            texture = texture,
            cached = true
        }
        itemCache[itemID] = itemInfo
        return itemInfo
    end
    
    -- Item not cached yet, return nil but don't cache the failure
    return nil
end

-- Extract item information from a bag slot
function Scrappy.Cache.GetItemInfoFromSlot(bag, slot, skipRetry)
    -- Validate input parameters
    if not bag or not slot or bag < 0 or slot < 1 then
        return nil
    end
    
    -- Protect against invalid bag/slot combinations
    local numSlots = C_Container.GetContainerNumSlots(bag)
    if not numSlots or slot > numSlots then
        return nil
    end
    
    -- Get container item info
    local containerItem = C_Container.GetContainerItemInfo(bag, slot)
    if not containerItem or not containerItem.itemID then
        return nil
    end
    
    -- Try to get cached item info
    local itemInfo = Scrappy.Cache.GetItemInfo(containerItem.itemID)
    if itemInfo then
        -- Get the ACTUAL item level from the specific item in the bag (important for timewarped items)
        local actualItemLevel = GetDetailedItemLevelInfo(C_Container.GetContainerItemLink(bag, slot))
        if not actualItemLevel then
            -- Fallback to container item level or cached level
            actualItemLevel = containerItem.itemLevel or itemInfo.ilvl or 0
        end
        
        -- Merge container-specific info with cached item info, using ACTUAL item level
        return {
            itemID = containerItem.itemID,
            name = itemInfo.name,
            quality = itemInfo.quality,
            ilvl = actualItemLevel,  -- Use actual level, not cached level
            minLevel = itemInfo.minLevel,
            class = itemInfo.class,
            subclass = itemInfo.subclass,
            maxStack = itemInfo.maxStack,
            equipSlot = itemInfo.equipSlot,
            texture = itemInfo.texture,
            hasNoValue = containerItem.hasNoValue or false,
            stackCount = containerItem.stackCount or 1,
            isLocked = containerItem.isLocked or false,
            bag = bag,
            slot = slot
        }
    end
    
    -- Item not cached, queue for retry if not already skipping
    if not skipRetry then
        Scrappy.Cache.QueueItemForRetry(bag, slot, containerItem.itemID)
    end
    
    return nil
end

-- Queue an item for retry when it's not cached
function Scrappy.Cache.QueueItemForRetry(bag, slot, itemID)
    -- Check if already queued to prevent duplicates
    for _, pending in ipairs(pendingItems) do
        if pending.bag == bag and pending.slot == slot then
            return
        end
    end
    
    table.insert(pendingItems, {
        bag = bag,
        slot = slot,
        itemID = itemID,
        attempts = 0,
        nextRetry = GetTime() + RETRY_DELAY
    })
end

-- Process pending items that need to be retried
function Scrappy.Cache.ProcessPendingItems()
    if #pendingItems == 0 then return end
    
    local currentTime = GetTime()
    local processed = {}
    
    for i = #pendingItems, 1, -1 do
        local pending = pendingItems[i]
        
        -- Check if it's time to retry this item
        if currentTime >= pending.nextRetry then
            pending.attempts = pending.attempts + 1
            
            -- Try to get the item info again
            local itemInfo = Scrappy.Cache.GetItemInfo(pending.itemID)
            if itemInfo then
                -- Success! Remove from pending list
                table.remove(pendingItems, i)
                table.insert(processed, {
                    bag = pending.bag,
                    slot = pending.slot,
                    itemInfo = itemInfo
                })
            elseif pending.attempts >= MAX_RETRY_ATTEMPTS then
                -- Too many failures, give up on this item
                table.remove(pendingItems, i)
            else
                -- Schedule next retry with exponential backoff
                pending.nextRetry = currentTime + (RETRY_DELAY * pending.attempts)
            end
        end
    end
    
    -- Notify other systems about newly processed items
    if #processed > 0 then
        Scrappy.Cache.OnItemsProcessed(processed)
    end
end

-- Called when items are successfully processed after retry
function Scrappy.Cache.OnItemsProcessed(processedItems)
    -- This could trigger UI updates or other notifications
    if #processedItems > 0 then
        Scrappy.Print("Successfully cached " .. #processedItems .. " item(s)")
    end
end

-- Clear cache when major inventory changes occur
function Scrappy.Cache.InvalidateCache()
    -- Don't clear the entire cache, just mark for refresh
    for itemID, itemInfo in pairs(itemCache) do
        itemInfo.needsRefresh = true
    end
end

-- Get current cache statistics for debugging
function Scrappy.Cache.GetCacheStats()
    local cached = 0
    local needsRefresh = 0
    
    for itemID, itemInfo in pairs(itemCache) do
        cached = cached + 1
        if itemInfo.needsRefresh then
            needsRefresh = needsRefresh + 1
        end
    end
    
    return {
        cachedItems = cached,
        pendingItems = #pendingItems,
        needsRefresh = needsRefresh
    }
end

-- Periodic processing of pending items
local cacheFrame = CreateFrame("Frame")
cacheFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Only process every 0.1 seconds to avoid performance issues
    self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
    if self.timeSinceLastUpdate >= 0.1 then
        Scrappy.Cache.ProcessPendingItems()
        self.timeSinceLastUpdate = 0
    end
end)

-- Handle bag update events to process newly loaded items
cacheFrame:RegisterEvent("BAG_UPDATE")
cacheFrame:RegisterEvent("ITEM_LOCK_CHANGED")
cacheFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" then
        local bagID = ...
        -- When a bag updates, try to process any pending items from that bag
        C_Timer.After(0.1, function()
            Scrappy.Cache.ProcessPendingItems()
        end)
    elseif event == "ITEM_LOCK_CHANGED" then
        -- Item lock state changed, might affect selling
        local bag, slot = ...
        if bag and slot then
            -- Small delay to let the lock state settle
            C_Timer.After(0.05, function()
                Scrappy.Cache.ProcessPendingItems()
            end)
        end
    end
end)