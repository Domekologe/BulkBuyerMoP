-- BulkBuyerMoP - Mists of Pandaria Classic
-- ALT-click: enter total items; addon auto-detects vendor unit (per-click yield).
-- If vendor truly sells in packs (extended/currency), we enforce bundles; otherwise pieces.
-- Buys per inventory stack per tick to avoid bag errors.
-- SHIFT-click: Blizzard default.
-- Creator: Domekologe
-- All comments are in English.

local ADDON = ...
BulkBuyerMoPDB = BulkBuyerMoPDB or {}
if type(BulkBuyerMoPDB.aceStatus) ~= "table" then
    BulkBuyerMoPDB.aceStatus = {}
end

-- Config defaults
BulkBuyerMoPDB.sliderCapPieces = BulkBuyerMoPDB.sliderCapPieces or 500
BulkBuyerMoPDB.roundMode  = BulkBuyerMoPDB.roundMode  or "up"     -- up|nearest|down (only if unit>1)
BulkBuyerMoPDB.chunkMode  = BulkBuyerMoPDB.chunkMode  or "stack"  -- "stack" (default) or "fixed"
BulkBuyerMoPDB.chunkSize  = BulkBuyerMoPDB.chunkSize  or 1        -- units per tick if chunkMode="fixed" (items if unit=1, bundles if unit>1)
BulkBuyerMoPDB.verbose    = BulkBuyerMoPDB.verbose    or false

local AceGUI = LibStub("AceGUI-3.0")
local L      = LibStub("AceLocale-3.0"):GetLocale("BulkBuyerMoP")

-- Forward decl
local IsExtendedCost

-- small formatter (localized)
local function T(key, ...)
    local s = L[key] or key
    if select("#", ...) > 0 then
        return s:format(...)
    end
    return s
end

local BulkBuyerAceDialog -- AceGUI widget (not just .frame)
local BulkBuyerAce_InUISpecial = false
local function AddToUISpecialOnce(frameName)
    if not BulkBuyerAce_InUISpecial then
        tinsert(UISpecialFrames, frameName)
        BulkBuyerAce_InUISpecial = true
    end
end

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BulkBuyer|r: "..tostring(msg)) end
local function VPrint(msg) if BulkBuyerMoPDB.verbose then Print(msg) end end

-- Money formatting (localized coin shorts)
local function FormatMoney(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return ("%d%s %d%s %d%s"):format(g, L.GOLD_SHORT, s, L.SILVER_SHORT, c, L.COPPER_SHORT)
    elseif s > 0 then return ("%d%s %d%s"):format(s, L.SILVER_SHORT, c, L.COPPER_SHORT)
    else return ("%d%s"):format(c, L.COPPER_SHORT) end
end

-- Detect non-gold costs (currencies/tokens/items) - simple check
local function IsCurrencyItem(index)
    local name, _, price = GetMerchantItemInfo(index)
    if not name then return false end
    local costCount = GetMerchantItemCostInfo(index) or 0
    if costCount and costCount > 0 then
        for i = 1, costCount do
            local tex, amount, link, currencyName = GetMerchantItemCostItem(index, i)
            if (amount and amount > 0) and (link or currencyName or tex) then
                return true
            end
        end
    end
    if price and price > 0 then
        return false
    end
    return false
end

-- Extract itemID from a link (Classic-safe)
local function GetItemIDFromLink(link)
    if not link then return nil end
    local id = link:match("item:(%d+)")
    if id then return tonumber(id) end
    return nil
end

-- Currency/item cost formatter
local function FormatCurrencyEntry(tex, amount, nameOrLink)
    local icon = tex and ("|T"..tex..":12:12|t ") or ""
    local label = nameOrLink or L.CURRENCY or "Currency"
    return ("%s%s×%d"):format(icon, label, amount)
end

-- Costs for N clicks (units): returns gold (copper) + list {tex, amount, label}
local function GetCostsForUnits(index, units)
    local _, _, price = GetMerchantItemInfo(index)
    local totalGold = (price or 0) * (units or 1)

    local costCount = GetMerchantItemCostInfo(index) or 0
    local entries = {}
    if costCount and costCount > 0 then
        for i = 1, costCount do
            local tex, amount, link, currencyName = GetMerchantItemCostItem(index, i)
            if amount and amount > 0 then
                entries[#entries+1] = {
                    tex   = tex,
                    amount = amount * (units or 1),
                    label = currencyName or link,
                }
            end
        end
    end
    return totalGold, entries
end

local function FormatCostsString(goldCopper, entries)
    local parts = {}
    if goldCopper and goldCopper > 0 then
        parts[#parts+1] = FormatMoney(goldCopper)
    end
    if entries and #entries > 0 then
        for _,e in ipairs(entries) do
            parts[#parts+1] = FormatCurrencyEntry(e.tex, e.amount, e.label)
        end
    end
    if #parts == 0 then
        return L.NO_COST
    end
    return table.concat(parts, " + ")
end

-- Determines if merchant entry has any non-gold/extended cost (currency or item).
-- IMPORTANT: We ONLY trust the presence of cost lines. We IGNORE the old 'extendedCost' flag.
function IsExtendedCost(index)
    local costCount = GetMerchantItemCostInfo(index) or 0
    return (costCount and costCount > 0) and true or false
end

-- Vendor unit detection: how many items does one BuyMerchantItem(index, 1) yield?
-- Extended/currency: enforced bundles (quantityField). Gold: treat as free-per-piece (unit=1).
local function DetectVendorUnit(index)
    local name, _, price, quantityField = GetMerchantItemInfo(index)
    if not name then return 1 end
    quantityField = quantityField or 1

    if IsExtendedCost(index) then
        -- Enforced bundles for currencies/tokens/items
        return math.max(1, quantityField)
    end

    -- Pure gold: allow arbitrary pieces regardless of quantityField visual bundle
    return 1
end

-- Round to vendor unit multiples
local function RoundToUnit(itemsWanted, unit, mode)
    if unit <= 1 then return itemsWanted end
    local u = unit
    if mode == "down" then
        return math.floor(itemsWanted / u) * u
    elseif mode == "nearest" then
        return math.floor((itemsWanted + u/2) / u) * u
    else
        return math.ceil(itemsWanted / u) * u
    end
end

-- Inventory stack size in items
local function InventoryStackSizePieces(index)
    local link = GetMerchantItemLink(index)
    local _, _, _, _, _, _, _, stackSize = GetItemInfo(link or "")
    return stackSize or 0
end

-- Purchase queue tracked in UNITS (= BuyMerchantItem calls):
--   - items if unit=1 (gold, piecewise)
--   - bundles if unit>1 (extended cost, enforced)
local queue = nil

local function StopQueue(reason)
    if not queue then return end
    if reason and queue.name then
        local unitWord = (queue.unit > 1) and L.UNITWORD_BUNDLES or L.UNITWORD_ITEMS
        Print(T("STOPPED", queue.name, reason, queue.boughtUnits, queue.totalUnits, unitWord))
    end
    queue = nil
end

local function StepQueue()
    if not queue then return end
    if not MerchantFrame or not MerchantFrame:IsShown() then
        StopQueue(T("REASON_MERCHANT_CLOSED"))
        return
    end

    if queue.unitsLeft <= 0 then
        local pieces = queue.boughtUnits * queue.unit
        local goldTotal, entriesTotal = GetCostsForUnits(queue.index, queue.boughtUnits)
        local finalCostStr = FormatCostsString(goldTotal, entriesTotal)

        if queue.unit > 1 then
            Print(T("DONE_STACK", queue.boughtUnits, queue.unit, pieces, queue.name))
        else
            Print(T("DONE_PIECES", pieces, queue.name))
        end

        if (goldTotal and goldTotal > 0) or (entriesTotal and #entriesTotal > 0) then
            Print(T("TOTAL_COST", finalCostStr))
        end
        queue = nil
        return
    end

    -- limited stock clamp
    local _, _, _, _, numAvailable = GetMerchantItemInfo(queue.index)
    local limit = nil
    if numAvailable and numAvailable >= 0 then
        if numAvailable <= 0 then
            StopQueue(T("REASON_SOLD_OUT"))
            return
        end
        limit = numAvailable
    end

    -- units to buy this tick
    local toBuy
    if (BulkBuyerMoPDB.chunkMode or "stack") == "stack" then
        local stackPieces = InventoryStackSizePieces(queue.index)
        if stackPieces and stackPieces > 0 then
            if queue.unit > 1 then
                toBuy = math.max(1, math.floor(stackPieces / queue.unit))
            else
                toBuy = stackPieces
            end
        else
            toBuy = 1
        end
    else
        toBuy = math.max(1, BulkBuyerMoPDB.chunkSize or 1)
    end

   -- [IMPORTANT] Extended-cost: must buy exactly 1 per call (one enforced bundle per click)
	-- Extended-cost: exactly 1 bundle per tick
	if queue.isExtendedCost then
		toBuy = 1
	end
	-- Gold (forceSinglePiece): DO NOT clamp to 1; we want to pass quantity as items
	-- (no code here)

    toBuy = math.min(toBuy, queue.unitsLeft)
    if limit then toBuy = math.min(toBuy, limit) end
    if toBuy <= 0 then
        StopQueue(T("REASON_NOTHING_TO_BUY"))
        return
    end

    local cost = queue.price * toBuy
    if queue.price > 0 and GetMoney() < cost then
        StopQueue(T("REASON_NOT_ENOUGH_GOLD"))
        return
    end

    VPrint(("Buy tick: %d %s"):format(toBuy, (queue.unit>1) and L.UNITWORD_BUNDLES or L.UNITWORD_ITEMS))

    -- Do the actual buy
    if queue.isExtendedCost then
        -- Exactly 1 enforced bundle per tick, no quantity arg
        BuyMerchantItem(queue.index)
    elseif queue.forceSinglePiece then
		-- Gold item with vendor bundle shown but pieces allowed: pass quantity as ITEMS
		BuyMerchantItem(queue.index, toBuy)
	else
		-- Normal gold items
		BuyMerchantItem(queue.index, toBuy)
	end


    queue.unitsLeft  = queue.unitsLeft - toBuy
    queue.boughtUnits = queue.boughtUnits + toBuy

    C_Timer.After(0.15, StepQueue)
end

-- Watch bag errors to abort
local bag_errors = {
    [LE_GAME_ERR_INV_FULL] = true,
    [LE_GAME_ERR_INTERNAL_BAG_ERROR] = true,
    [LE_GAME_ERR_TRADE_MAX_COUNT_EXCEEDED] = true,
}
local errFrame = CreateFrame("Frame")
errFrame:RegisterEvent("UI_ERROR_MESSAGE")
errFrame:SetScript("OnEvent", function(_, _, msgType, msg)
    if not queue then return end
    if msgType and bag_errors[msgType] then
        StopQueue(T("REASON_BAG_ERROR"))
    end
end)

local function StartQueue(index, totalUnits, unit)
    local name, _, price, quantityField = GetMerchantItemInfo(index)
    if not name then Print(T("INVALID_ITEM")) return end
    quantityField = quantityField or 1
    local isExt = IsExtendedCost(index)

    queue = {
        index = index,
        name = name,
        price = price or 0,
        unit = unit or 1,           -- items per BuyMerchantItem(1) (bundles if extended)
        totalUnits = totalUnits,    -- total BuyMerchantItem calls planned
        unitsLeft = totalUnits,
        boughtUnits = 0,
        isExtendedCost = isExt,
        -- Gold + vendor shows bundle (>1) -> safest is single piece clicks
        forceSinglePiece = (not isExt) and (quantityField > 1),
    }
    VPrint(("Plan: %d %s (unit=%d items each)"):format(
        totalUnits, (unit>1) and L.UNITWORD_BUNDLES or L.UNITWORD_ITEMS, unit))
    StepQueue()
end

local function BeginPurchase(index, itemsWanted)
    local name = GetMerchantItemInfo(index)
    if not name then Print(T("INVALID_ITEM")) return end

    -- We handle both gold and currency
    local _isCurrency = IsCurrencyItem(index) -- informative
    local unit = DetectVendorUnit(index)      -- 1 for gold, bundle size for extended

    local itemsRounded = RoundToUnit(itemsWanted, unit, BulkBuyerMoPDB.roundMode or "up")
    if itemsRounded <= 0 then Print(T("NOTHING_TO_BUY_ZERO")) return end

    local totalUnits = math.max(1, math.ceil(itemsRounded / unit))
    if queue then StopQueue(T("REASON_NEW_PURCHASE")) end

    local goldTotal, entriesTotal = GetCostsForUnits(index, totalUnits)
    local costStr = FormatCostsString(goldTotal, entriesTotal)
    if unit > 1 then
        Print(T("PLAN_STACK", totalUnits, unit, itemsRounded, costStr))
    else
        Print(T("PLAN_PIECES", itemsRounded, costStr))
    end

    StartQueue(index, totalUnits, unit)
end

-- UpdateAmountAce shows totals for the dialog where 'n' means:
--  - bundles if isBundleMode=true (extended cost with enforced unit>1)
--  - pieces  if isBundleMode=false (pure gold)
local function UpdateAmountAce(costLabel, index, n)
    local name, _, _, quantityField = GetMerchantItemInfo(index)
    if not name then return end
    if not n or n < 0 then n = 0 end

    local unit  = DetectVendorUnit(index)          -- items per click
    local isExt = IsExtendedCost(index)
    local isBundleMode = isExt and (unit > 1)

    local totalUnits, itemsRounded

    if isBundleMode then
        -- n is number of bundles/clicks; 1 unit == 1 click
        totalUnits  = math.max(0, math.floor(n + 0.0001))
        itemsRounded = totalUnits * unit
    else
        -- gold mode: n is pieces, round to vendor unit (==1 here)
        itemsRounded = RoundToUnit(n, unit, BulkBuyerMoPDB.roundMode or "up")
        if itemsRounded < 0 then itemsRounded = 0 end
        totalUnits = (itemsRounded > 0) and math.max(1, math.ceil(itemsRounded / unit)) or 0
    end

    local goldTotal, entriesTotal = GetCostsForUnits(index, totalUnits)
    local totalCostStr = FormatCostsString(goldTotal, entriesTotal)
    local gold1, entries1 = GetCostsForUnits(index, 1)
    local perClickCost = FormatCostsString(gold1, entries1)

    local hintHeader
    if isBundleMode then
        hintHeader = T("DIALOG_HEADER_ENFORCED", name, perClickCost, unit) -- enforced bundle
    else
        -- For gold items, do not confuse with "bundle hint", even if quantityField>1 visually
        hintHeader = ("%s\n%s: %s\n%s: %s")
            :format(T("DIALOG_HEADER"), L.ITEM_LABEL, name, L.COST_PER_CLICK, perClickCost)
    end

    local text
    if totalUnits > 0 then
        if unit > 1 then
            -- Show: total cost + "X bundles × unit = Y items"
            text = ("%s\n\n%s:\n\n %s  (%d %s × %d = %d %s)")
                :format(hintHeader, L.CURRENT_TOTAL, totalCostStr,
                         totalUnits, L.UNITWORD_BUNDLES, unit, (totalUnits * unit), L.UNITWORD_ITEMS)
        else
            text = ("%s\n\n%s:\n\n %s  (%d %s)")
                :format(hintHeader, L.CURRENT_TOTAL, totalCostStr, itemsRounded, L.UNITWORD_ITEMS)
        end
    else
        text = hintHeader .. ("\n\n%s:\n\n –"):format(L.CURRENT_TOTAL)
    end

    costLabel:SetText(text)
end

local function GetAceStatus()
    if type(BulkBuyerMoPDB) ~= "table" then BulkBuyerMoPDB = {} end
    if type(BulkBuyerMoPDB.aceStatus) ~= "table" then BulkBuyerMoPDB.aceStatus = {} end
    return BulkBuyerMoPDB.aceStatus
end

local function EnsureBulkBuyerDialog()
    if BulkBuyerAceDialog and BulkBuyerAceDialog.frame then
        return BulkBuyerAceDialog
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle(T("TITLE"))
    frame:SetStatusText("")
    frame:SetLayout("List")
    frame:SetWidth(400)
    frame:SetHeight(300)
    -- Resize bounds (compat for MoP)
    local minW, minH, maxW, maxH = 380, 260, 1600, 1200
    if frame.frame then
        if frame.frame.SetResizeBounds then
            frame.frame:SetResizeBounds(minW, minH, maxW, maxH)
        else
            if frame.frame.SetMinResize then frame.frame:SetMinResize(minW, minH) end
            if frame.frame.SetMaxResize then frame.frame:SetMaxResize(maxW, maxH) end
        end
    end

    frame:SetStatusTable(GetAceStatus())

    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        BulkBuyerAceDialog = nil
    end)

    local costLabel = AceGUI:Create("Label")
    costLabel:SetFullWidth(true)
    costLabel:SetText("–")
    frame:AddChild(costLabel)

    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel(T("AMOUNT"))
    editbox:SetText("1")
    editbox:SetFullWidth(true)
    frame:AddChild(editbox)

    local slider = AceGUI:Create("Slider")
    slider:SetLabel(T("AMOUNT_RANGE", 1, BulkBuyerMoPDB.sliderCapPieces or 500))  -- formatted
    slider:SetSliderValues(1, 500, 1)
    slider:SetValue(1)
    slider:SetFullWidth(true)
    frame:AddChild(slider)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local okBtn = AceGUI:Create("Button")
    okBtn:SetText(T("OK"))
    okBtn:SetWidth(100)
    group:AddChild(okBtn)

    frame:AddChild(group)

    -- store refs
    frame.costLabel = costLabel
    frame.editbox   = editbox
    frame.slider    = slider
    frame.okBtn     = okBtn

    -- ESC close
    _G["BulkBuyerAceFrame"] = frame.frame
    AddToUISpecialOnce("BulkBuyerAceFrame")

    -- callbacks
    slider:SetCallback("OnValueChanged", function(_, _, val)
        val = math.floor((val or 1) + 0.5)
        frame.editbox:SetText(tostring(val))
        if frame.currentIndex then
            UpdateAmountAce(frame.costLabel, frame.currentIndex, val)
        end
    end)

    editbox:SetCallback("OnEnterPressed", function(_, _, text)
        local n = tonumber(text)
        if n then
            local minV, maxV = 1, select(2, frame.slider:GetSliderValues())
            if not maxV then
                -- recompute if AceGUI doesn't expose values
                if frame.isBundleMode then
                    local capPieces = BulkBuyerMoPDB.sliderCapPieces or 500
                    maxV = math.max(1, math.floor(capPieces / (frame.currentUnit or 1)))
                else
                    maxV = BulkBuyerMoPDB.sliderCapPieces or 500
                end
            end
            n = math.min(maxV, math.max(minV, math.floor(n + 0.5)))
            frame.slider:SetValue(n)
            if frame.currentIndex then
                UpdateAmountAce(frame.costLabel, frame.currentIndex, n)
            end
        end
    end)

    okBtn:SetCallback("OnClick", function()
        local n = tonumber(frame.editbox:GetText()) or 0
        if n > 0 and frame.currentIndex then
            if frame.isBundleMode then
                -- n = bundles; each click yields 'unit' items
                BeginPurchase(frame.currentIndex, n * (frame.currentUnit or 1))
            else
                -- n = pieces
                BeginPurchase(frame.currentIndex, n)
            end
            frame.frame:Hide()
        end
    end)

    frame:DoLayout()

    BulkBuyerAceDialog = frame
    return BulkBuyerAceDialog
end

-- Configure dialog to work in "pieces" (gold) or "bundles" (extended cost).
local function ConfigureDialogForIndex(frame, index)
    local unit   = DetectVendorUnit(index)   -- 1 for gold, bundle size for extended
    local isExt  = IsExtendedCost(index)

    frame.currentIndex = index
    frame.currentUnit  = unit                -- items per click (bundle size if extended)
    frame.isBundleMode = isExt and (unit > 1) or false

    -- Determine slider range
    local minV, maxV, step = 1, 1, 1
    if frame.isBundleMode then
        -- work in BUNDLES: slider value = number of clicks (bundles)
        local capPieces = BulkBuyerMoPDB.sliderCapPieces or 500
        local capBundles = math.max(1, math.floor(capPieces / unit))

        -- stock clamp if limited
        local _, _, _, _, numAvailable = GetMerchantItemInfo(index)
        if numAvailable and numAvailable >= 0 then
            capBundles = math.max(1, math.min(capBundles, numAvailable))
        end

        maxV = capBundles
        frame.slider:SetLabel(T("AMOUNT_RANGE_BUNDLES", 1, maxV))
        frame.editbox:SetLabel(T("AMOUNT_BUNDLES"))
    else
        -- work in PIECES (gold case)
        maxV = BulkBuyerMoPDB.sliderCapPieces or 500
        frame.slider:SetLabel(T("AMOUNT_RANGE", 1, maxV))
        frame.editbox:SetLabel(T("AMOUNT_ITEMS"))
    end

    frame.slider:SetSliderValues(minV, maxV, step)
end

local function ShowBulkBuyerDialog(index)
    local dlg = EnsureBulkBuyerDialog()

    -- Configure per item (bundles vs pieces) and slider range
    ConfigureDialogForIndex(dlg, index)

    dlg:PauseLayout()
    dlg.editbox:SetText("1")
    dlg.slider:SetValue(1)
    dlg.costLabel:SetText("–")
    dlg:ResumeLayout()

    if dlg.content then
        dlg.content:SetHeight(1)
    end
    dlg:DoLayout()

    UpdateAmountAce(dlg.costLabel, index, 1) -- n = bundles OR pieces depending on mode
    dlg.frame:Show()
    dlg.frame:Raise()
end

-- Override Blizzard handlers so ALT is intercepted reliably.
local function InstallOverrides()
    if _G.BulkBuyerMoP_OverridesInstalled then return end
    _G.BulkBuyerMoP_OverridesInstalled = true

    -- CompactVendor hook
    if CompactVendorFrameMerchantButtonTemplate and CompactVendorFrameMerchantButtonTemplate.OnClick then
        hooksecurefunc(CompactVendorFrameMerchantButtonTemplate, "OnClick", function(self, button, down)
            local merchantItem = self.merchantItem
            if merchantItem then
                local index = merchantItem:GetIndex()
                if index then
                    if button == "LeftButton" and IsAltKeyDown() then
                        ShowBulkBuyerDialog(index)
                    end
                end
            end
        end)
    end

    if type(MerchantItemButton_OnClick) == "function" and not _G.BulkBuyerMoP_Orig_OnClick then
        _G.BulkBuyerMoP_Orig_OnClick = MerchantItemButton_OnClick
        MerchantItemButton_OnClick = function(self, button, ...)
            if IsAltKeyDown() then
                local index = self and self.GetID and self:GetID()
                if index then
                    ShowBulkBuyerDialog(index)
                    return
                end
            end
            return _G.BulkBuyerMoP_Orig_OnClick(self, button, ...)
        end
    end

    if type(MerchantItemButton_OnModifiedClick) == "function" and not _G.BulkBuyerMoP_Orig_OnModifiedClick then
        _G.BulkBuyerMoP_Orig_OnModifiedClick = MerchantItemButton_OnModifiedClick
        MerchantItemButton_OnModifiedClick = function(self, button, ...)
            if IsAltKeyDown() then
                local index = self and self.GetID and self:GetID()
                if index then
                    ShowBulkBuyerDialog(index)
                    return
                end
            end
            return _G.BulkBuyerMoP_Orig_OnModifiedClick(self, button, ...)
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function() InstallOverrides() end)

-- Slash
SLASH_BULKBUYER1 = "/bulkbuyer"
SlashCmdList["BULKBUYER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local sub, a1, a2 = msg:match("^(%S+)%s*(%S*)%s*(.*)$")
    if sub == "round" and a1 and a1 ~= "" then
        a1 = a1:lower()
        if a1 == "up" or a1 == "nearest" or a1 == "down" then
            BulkBuyerMoPDB.roundMode = a1
            Print(T("ROUND_SET", a1))
        else
            Print(T("ROUND_BAD"))
        end
    elseif sub == "chunk" then
        local mode = (a1 or ""):lower()
        if mode == "stack" or mode == "fixed" then
            BulkBuyerMoPDB.chunkMode = mode
            if mode == "fixed" then
                local n = tonumber(a2)
                if n and n >= 1 and n <= 200 then
                    BulkBuyerMoPDB.chunkSize = n
                    Print(T("CHUNK_FIXED_SET", n))
                else
                    Print(T("CHUNK_FIXED_HINT"))
                end
            else
                Print(T("CHUNK_STACK_SET"))
            end
        else
            Print(T("CHUNK_USAGE"))
        end
    elseif sub == "verbose" then
        local v = (a1 or ""):lower()
        if v == "on" then BulkBuyerMoPDB.verbose = true; Print(T("VERBOSE_ON"))
        elseif v == "off" then BulkBuyerMoPDB.verbose = false; Print(T("VERBOSE_OFF"))
        else Print("Use: /bulkbuyer verbose on|off") end
    elseif sub == "slidercap" then
        local n = tonumber(a1)
        if n and n >= 20 and n <= 2000 then
            BulkBuyerMoPDB.sliderCapPieces = math.floor(n)
            Print(("Slider cap set to %d (pieces baseline)."):format(BulkBuyerMoPDB.sliderCapPieces))
            Print("Tip: In bundle mode, the slider's max is cap/UNIT (e.g. 500/20 = 25 bundles).")
        else
            Print("Use: /bulkbuyer slidercap <20..2000>  (default 500)")
        end
    else
        Print(T("SLASH_LINE1"))
        Print(T("SLASH_LINE2"))
    end
end
