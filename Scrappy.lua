-- Scrappy.lua

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Scrappy:|r " .. msg)
end

local QUALITY_NAMES = {
    [0] = "Junk",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic"
}

local QUALITY_NAME_TO_ID = {
    junk = 0,
    common = 1,
    uncommon = 2,
    rare = 3,
    epic = 4
}

local QUALITY_COLORS = {
    [0] = {r=0.62, g=0.62, b=0.62},
    [1] = {r=1, g=1, b=1},
    [2] = {r=0.12, g=1, b=0},
    [3] = {r=0, g=0.44, b=0.87},
    [4] = {r=0.64, g=0.21, b=0.93}
}

local EXPANSION_MATERIALS = {
    shadowlands = {
        [173202] = true, -- Shrouded Cloth
        [172231] = true, -- Soul Dust
        [171315] = true, -- Death Blossom
        [171428] = true, -- Heavy Callous Hide
        [172437] = true, -- Tenebrous Ribs
    },
    bfa = {
        [152512] = true, -- Monelite Ore
        [152579] = true, -- Storm Silver Ore
        [152513] = true, -- Platinum Ore
        [152541] = true, -- Coarse Leather
        [152875] = true, -- Gloom Dust
    },
    legion = {
        [124124] = true, -- Blood of Sargeras
        [151564] = true, -- Empyrium
        [124115] = true, -- Stormscale
        [130179] = true, -- Eye of Prophecy
        [124118] = true, -- Lean Shank
    }
}

local function IsItemSellable(itemInfo)
    if not itemInfo or not itemInfo.itemID then return false end
    if itemInfo.hasNoValue then return false end

    -- Quality filters
    local q = itemInfo.quality or -1
    if ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[q] == false then
        return false
    end

    -- Expansion material filter
    if ScrappyDB.materialFilters then
        for expansion, enabled in pairs(ScrappyDB.materialFilters) do
            if enabled and EXPANSION_MATERIALS[expansion] and EXPANSION_MATERIALS[expansion][itemInfo.itemID] then
                return true
            end
        end
    end

    local ilvlThreshold = ScrappyDB.ilvlThreshold or 0
    local ilvl = tonumber(itemInfo.ilvl)
    if ilvl and ilvl > 0 and ilvl <= ilvlThreshold then
        return true
    end

    if ScrappyDB.sellList and ScrappyDB.sellList[itemInfo.itemID] then
        return true
    end

    return itemInfo.quality == 0 -- Junk
end

local function GetItemInfoFromSlot(bag, slot)
    local item = C_Container.GetContainerItemInfo(bag, slot)
    if not item then return nil end

    local name, _, quality, ilvl = GetItemInfo(item.itemID)
    return {
        itemID = item.itemID,
        quality = quality,
        ilvl = ilvl,
        name = name,
        hasNoValue = item.hasNoValue
    }
end

local function SellNextItemQueue(queue)
    if #queue == 0 then return end
    local entry = table.remove(queue, 1)
    C_Container.UseContainerItem(entry.bag, entry.slot)
    C_Timer.After(0.1, function()
        SellNextItemQueue(queue)
    end)
end

local function SellItems()
    local queue = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = GetItemInfoFromSlot(bag, slot)
            if IsItemSellable(itemInfo) then
                table.insert(queue, {bag = bag, slot = slot})
            end
        end
    end

    if #queue > 0 then
        Print("Selling " .. #queue .. " item(s)...")
        SellNextItemQueue(queue)
    else
        Print("No items to sell.")
    end
end

local function GetItemsToSell()
    local items = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = GetItemInfoFromSlot(bag, slot)
            if IsItemSellable(itemInfo) then
                table.insert(items, itemInfo)
            end
        end
    end
    return items
end

local function CreateScrappyButton()
    if _G["ScrappySellButton"] then return end

    local button = CreateFrame("Button", "ScrappySellButton", MerchantFrame, "UIPanelButtonTemplate")
    button:SetSize(32, 32)
    button:SetPoint("LEFT", MerchantFrameTab2, "RIGHT", 10, 0)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\ICONS\\INV_Misc_Coin_01")

    button:SetScript("OnClick", function()
        SellItems()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sell with Scrappy")

        local items = GetItemsToSell()

        if #items == 0 then
            GameTooltip:AddLine("Nothing to sell.", 1, 1, 1)
        else
            local groups = {}
            for _, item in ipairs(items) do
                local q = item.quality or 0
                groups[q] = groups[q] or {}
                table.insert(groups[q], item)
            end

            for quality = 0, 4 do
                local group = groups[quality]
                if group then
                    table.sort(group, function(a, b)
                        return (tonumber(a.ilvl) or 0) < (tonumber(b.ilvl) or 0)
                    end)

                    local qName = QUALITY_NAMES[quality] or ("Quality " .. quality)
                    local color = QUALITY_COLORS[quality] or {r=1, g=1, b=1}
                    GameTooltip:AddLine(qName .. ":", color.r, color.g, color.b)

                    for _, item in ipairs(group) do
                        local ilvl = tonumber(item.ilvl) or "?"
                        GameTooltip:AddLine("  ilvl " .. ilvl .. " - " .. (item.name or ("ItemID " .. item.itemID)), 1, 1, 1)
                    end
                end
            end
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function OnMerchantShow()
    if ScrappyDB.autoSell then
        SellItems()
    end
    CreateScrappyButton()
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg)
    if event == "MERCHANT_SHOW" then
        OnMerchantShow()
    elseif event == "ADDON_LOADED" and arg == "Scrappy" then
        ScrappyDB = ScrappyDB or {}
        ScrappyDB.autoSell = ScrappyDB.autoSell or false
        ScrappyDB.ilvlThreshold = ScrappyDB.ilvlThreshold or 0
        ScrappyDB.sellList = ScrappyDB.sellList or {}
        ScrappyDB.materialFilters = ScrappyDB.materialFilters or {
            shadowlands = false,
            bfa = false,
            legion = false
        }
        ScrappyDB.qualityFilter = ScrappyDB.qualityFilter or {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = false,
            [4] = false
        }
    end
end)

SLASH_SCRAPPY1 = "/scrappy"
SlashCmdList["SCRAPPY"] = function(msg)
    msg = msg:lower()
    local ilvl = ScrappyDB.ilvlThreshold or 0

    local qInput, toggle = msg:match("^quality%s+(%w+)%s+(%w+)$")
    if qInput and toggle then
        local q = tonumber(qInput)
        if not q then
            q = QUALITY_NAME_TO_ID[qInput:lower()]
        end
        if q and ScrappyDB.qualityFilter then
            if toggle == "sell" then
                ScrappyDB.qualityFilter[q] = true
                Print("Set to sell quality " .. q .. " (" .. (QUALITY_NAMES[q] or "?") .. ") items.")
            elseif toggle == "keep" then
                ScrappyDB.qualityFilter[q] = false
                Print("Set to keep quality " .. q .. " (" .. (QUALITY_NAMES[q] or "?") .. ") items.")
            else
                Print("Unknown action: " .. toggle .. ". Use 'sell' or 'keep'.")
            end
        else
            Print("Unknown quality: " .. qInput)
        end
        return
    end

    if msg == "auto on" then
        ScrappyDB.autoSell = true
        Print("Auto-sell enabled.")
    elseif msg == "auto off" then
        ScrappyDB.autoSell = false
        Print("Auto-sell disabled.")
    elseif msg:match("^ilvl %d+") then
        local newIlvl = tonumber(msg:match("^ilvl (%d+)"))
        ScrappyDB.ilvlThreshold = newIlvl
        Print("Item level threshold set to " .. newIlvl)
    elseif msg == "status" then
        Print("Settings:")
        Print("  Auto-sell: " .. tostring(ScrappyDB.autoSell))
        Print("  ilvlThreshold: " .. tostring(ilvl))
        for q = 0, 4 do
            local name = QUALITY_NAMES[q] or ("Quality " .. q)
            local enabled = ScrappyDB.qualityFilter and ScrappyDB.qualityFilter[q] and "sell" or "keep"
            Print("  Quality " .. q .. " (" .. name .. "): " .. enabled)
        end
    else
        Print("Commands:")
        Print("  /scrappy auto on|off         - Enable/disable auto-sell")
        Print("  /scrappy ilvl [number]       - Set ilvl sell threshold")
        Print("  /scrappy quality [#||name] [sell||keep] - Set quality sell rule")
        Print("  /scrappy status              - Show current settings")
    end
end
