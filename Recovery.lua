-- Recovery.lua - Selling recovery and retry system

-- WHY: Get reference to our addon namespace
local Scrappy = _G["Scrappy"]
Scrappy.Recovery = {}

-- WHY: Track selling operations for recovery
local sellQueue = {}
local failedSells = {}
local sellInProgress = false

-- WHY: Configuration for retry behavior
local MAX_SELL_RETRIES = 2
local SELL_RETRY_DELAY = 0.3
local QUEUE_TIMEOUT = 30 -- seconds

-- WHY: Enhanced selling with recovery capabilities and dialog suppression
function Scrappy.Recovery.StartSelling(items)
    if sellInProgress then
        Scrappy.Print("Selling already in progress. Please wait...")
        return false
    end
    
    if not items or #items == 0 then
        Scrappy.Print("No items to sell.")
        return false
    end
    
    -- WHY: Set up dialog auto-acceptance for soulbound warnings
    Scrappy.Recovery.SetupDialogHandling()
    
    -- WHY: Clear previous state
    sellQueue = {}
    failedSells = {}
    sellInProgress = true
    
    -- WHY: Convert items to sell queue entries
    for _, item in ipairs(items) do
        table.insert(sellQueue, {
            bag = item.bag,
            slot = item.slot,
            itemID = item.itemID,
            name = item.name,
            attempts = 0,
            startTime = GetTime()
        })
    end
    
    Scrappy.Print("Starting to sell " .. #sellQueue .. " item(s)...")
    Scrappy.Recovery.ProcessSellQueue()
    return true
end

-- WHY: Process the sell queue with recovery
function Scrappy.Recovery.ProcessSellQueue()
    if #sellQueue == 0 then
        Scrappy.Recovery.FinalizeSelling()
        return
    end
    
    local entry = table.remove(sellQueue, 1)
    local currentTime = GetTime()
    
    -- WHY: Check for timeout
    if currentTime - entry.startTime > QUEUE_TIMEOUT then
        Scrappy.Print("Timed out selling: " .. (entry.name or "Unknown Item"))
        table.insert(failedSells, entry)
        Scrappy.Recovery.ProcessSellQueue()
        return
    end
    
    -- WHY: Validate the item still exists and is the same
    local currentItem = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    if not currentItem or currentItem.itemID ~= entry.itemID then
        -- WHY: Item moved or changed, skip it
        Scrappy.Recovery.ProcessSellQueue()
        return
    end
    
    -- WHY: Check if item is locked (being sold)
    if currentItem.isLocked then
        -- WHY: Item is locked, retry after delay
        entry.attempts = entry.attempts + 1
        if entry.attempts <= MAX_SELL_RETRIES then
            C_Timer.After(SELL_RETRY_DELAY, function()
                table.insert(sellQueue, 1, entry) -- Re-add to front of queue
                Scrappy.Recovery.ProcessSellQueue()
            end)
        else
            table.insert(failedSells, entry)
            Scrappy.Recovery.ProcessSellQueue()
        end
        return
    end
    
    -- WHY: Attempt to sell the item
    entry.attempts = entry.attempts + 1
    local success, errorMsg = pcall(C_Container.UseContainerItem, entry.bag, entry.slot)
    
    if success then
        -- WHY: Selling initiated successfully
        -- If there's a confirmation dialog, our hook will handle it
        C_Timer.After(0.15, function()  -- Slightly longer delay to allow for dialogs
            Scrappy.Recovery.ProcessSellQueue()
        end)
    else
        -- WHY: Sell failed, retry or mark as failed
        if entry.attempts <= MAX_SELL_RETRIES then
            C_Timer.After(SELL_RETRY_DELAY, function()
                table.insert(sellQueue, 1, entry) -- Re-add to front of queue
                Scrappy.Recovery.ProcessSellQueue()
            end)
        else
            Scrappy.Print("Failed to sell: " .. (entry.name or "Unknown Item") .. " - " .. (errorMsg or "Unknown error"))
            table.insert(failedSells, entry)
            Scrappy.Recovery.ProcessSellQueue()
        end
    end
end

-- WHY: Finalize selling process and report results
function Scrappy.Recovery.FinalizeSelling()
    sellInProgress = false
    
    -- WHY: Clean up dialog handling
    Scrappy.Recovery.CleanupDialogHandling()
    
    if #failedSells > 0 then
        Scrappy.Print("Selling completed with " .. #failedSells .. " failed item(s).")
        
        -- WHY: Offer to retry failed items
        if #failedSells <= 5 then -- Only show details for small numbers
            for _, failed in ipairs(failedSells) do
                Scrappy.Print("  Failed: " .. (failed.name or "Unknown Item"))
            end
        end
        
        Scrappy.Print("Type '/scrappy retry' to attempt selling failed items again.")
    else
        Scrappy.Print("All items sold successfully!")
    end
end

-- WHY: Retry failed selling operations
function Scrappy.Recovery.RetryFailedSells()
    if #failedSells == 0 then
        Scrappy.Print("No failed items to retry.")
        return
    end
    
    if sellInProgress then
        Scrappy.Print("Selling already in progress. Please wait...")
        return
    end
    
    -- WHY: Convert failed items back to regular items for selling
    local retryItems = {}
    for _, failed in ipairs(failedSells) do
        -- WHY: Re-validate the item still exists
        local itemInfo = Scrappy.Cache.GetItemInfoFromSlot(failed.bag, failed.slot, true)
        if itemInfo and itemInfo.itemID == failed.itemID then
            table.insert(retryItems, itemInfo)
        end
    end
    
    if #retryItems == 0 then
        Scrappy.Print("No failed items are available to retry.")
        failedSells = {}
        return
    end
    
    Scrappy.Print("Retrying " .. #retryItems .. " failed item(s)...")
    failedSells = {}
    Scrappy.Recovery.StartSelling(retryItems)
end

-- WHY: Get current selling status
function Scrappy.Recovery.GetSellStatus()
    return {
        inProgress = sellInProgress,
        queuedItems = #sellQueue,
        failedItems = #failedSells
    }
end

-- WHY: Cancel ongoing selling operation
function Scrappy.Recovery.CancelSelling()
    if not sellInProgress then
        Scrappy.Print("No selling operation in progress.")
        return
    end
    
    local canceledCount = #sellQueue
    sellQueue = {}
    sellInProgress = false
    
    Scrappy.Print("Canceled selling operation. " .. canceledCount .. " item(s) were not processed.")
    
    if #failedSells > 0 then
        Scrappy.Print("Type '/scrappy retry' to attempt selling " .. #failedSells .. " previously failed items.")
    end
end

-- WHY: Emergency stop for when things go wrong
function Scrappy.Recovery.EmergencyStop()
    sellQueue = {}
    failedSells = {}
    sellInProgress = false
    Scrappy.Recovery.CleanupDialogHandling()
    Scrappy.Print("Emergency stop activated. All selling operations halted.")
end

-- WHY: Set up automatic handling of soulbound confirmation dialogs
function Scrappy.Recovery.SetupDialogHandling()
    -- WHY: Only set up if auto-confirm is enabled
    if not ScrappyDB.autoConfirmSoulbound then return end
    
    -- WHY: Hook StaticPopup_Show to intercept soulbound confirmations
    if not Scrappy.Recovery.originalStaticPopupShow then
        Scrappy.Recovery.originalStaticPopupShow = StaticPopup_Show
        StaticPopup_Show = function(which, text_arg1, text_arg2, data, ...)
            -- WHY: Handle different types of sell confirmations
            if sellInProgress and (which == "SELL_NONREFUNDABLE_ITEM" or 
                                  which == "CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL" or
                                  which == "DELETE_ITEM") then
                
                Scrappy.QuietPrint("Auto-confirming: " .. which)
                
                -- WHY: Call the original function first to set up the popup properly
                local popup = Scrappy.Recovery.originalStaticPopupShow(which, text_arg1, text_arg2, data, ...)
                
                -- WHY: Then immediately confirm it
                C_Timer.After(0.05, function()
                    -- WHY: Find the active popup and confirm it
                    for i = 1, 4 do
                        local popupFrame = _G["StaticPopup" .. i]
                        if popupFrame and popupFrame:IsVisible() and popupFrame.which == which then
                            local button = popupFrame.button1
                            if button and button:IsEnabled() and button:IsVisible() then
                                button:Click()
                                Scrappy.QuietPrint("Confirmed popup: " .. which)
                                break
                            end
                        end
                    end
                end)
                
                return popup
            end
            
            -- WHY: For all other popups, use normal behavior
            return Scrappy.Recovery.originalStaticPopupShow(which, text_arg1, text_arg2, data, ...)
        end
    end
end

-- WHY: Clean up dialog handling when selling is complete
function Scrappy.Recovery.CleanupDialogHandling()
    -- WHY: Restore original StaticPopup_Show if we hooked it
    if Scrappy.Recovery.originalStaticPopupShow then
        StaticPopup_Show = Scrappy.Recovery.originalStaticPopupShow
        Scrappy.Recovery.originalStaticPopupShow = nil
    end
    
    -- WHY: Clean up dialog frame
    if _G["ScrappyDialogFrame"] then
        _G["ScrappyDialogFrame"]:UnregisterAllEvents()
    end
end