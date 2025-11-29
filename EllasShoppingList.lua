-- EllasShoppingList.lua
-- Lightweight shopping list addon

local _, ans = ...

ADDON_NAME = "EllasShoppingList"

EllasShoppingListDB = EllasShoppingListDB or {
    lists = {
        ["Default"] = {}
    },
    current = "Default",
    itemCache = {}, -- { [id] = {link=..., name=..., price=...} }
    minimapIconTable = {}
}

-- Utilities
local function itemIdFromLink(link)
    if not link then return nil end
    local itemID = link:match("Hitem:(%d+)")
    if itemID then
        itemID = tonumber(itemID)
        return itemID
    end
    return nil
end

local function NormalizeListName(name)
    return name and name ~= "" and name or "Default"
end

local function AddListIfMissing(name)
    name = NormalizeListName(name)
    if not EllasShoppingListDB.lists[name] then
        EllasShoppingListDB.lists[name] = {}
    end
    EllasShoppingListDB.current = name
end

local function FormatGoldString(copperAmount)
    local copper = copperAmount % 100
    local silver = math.floor((copperAmount / 100)) % 100
    local gold = math.floor(copperAmount / 10000)
    local goldStr = string.format("%d |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t", gold)
    local silverStr = string.format("%02d |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t", silver)
    local copperStr = string.format("%02d |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", copper)
    return goldStr .. " " .. silverStr .. " " .. copperStr
end

local function AddItemToCache(link)
    if not link then return end
    if not C_Item then return end -- ensure API available
    local itemLink = link
    local itemID = itemIdFromLink(link)
    if not itemID then return end
    local iconID = C_Item.GetItemIconByID(itemID)
    local name = C_Item.GetItemNameByID(link)
    local price = select(11, C_Item.GetItemInfo(link)) or "??"
    if not name then
        name = link
    end
    EllasShoppingListDB.itemCache[itemID] = { link = itemLink, name = name, icon = iconID, price = price }
end

local function GetVendorPrice(merchantIndex)
    if not C_MerchantFrame then return nil end
    local itemInfo = C_MerchantFrame.GetItemInfo(merchantIndex)
    if itemInfo and itemInfo.price then
        return itemInfo.price
    end
    return nil
end

local function AddItemToCurrentList(itemLink, qty)
    if not itemLink then return false, "No item link" end
    if not C_Item then return false, "C_Item API not available" end
    qty = tonumber(qty) or 1
    local cur = EllasShoppingListDB.current or "Default"
    AddListIfMissing(cur)
    local itemID = itemIdFromLink(itemLink)
    if not itemID then return false, "Invalid item link" end
    local iconID = C_Item.GetItemIconByID(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    local entry = { link = itemLink, name = name, qty = qty, icon = iconID }
    tinsert(EllasShoppingListDB.lists[cur], entry)
    AddItemToCache(itemLink)
    return true
end

-- Hotkey function called by the binding (must be global)
function EllasShoppingList_AddHoveredItem()
    -- Try to get item from GameTooltip
    local tooltip = GameTooltip
    if not tooltip then
        print("|cff33eecc" .. ADDON_NAME .. ":|r no tooltip found")
        return
    end
    local name, link = tooltip:GetItem()
    if not link then
        print("|cff33eecc" .. ADDON_NAME .. ":|r No item link in tooltip to add.")
        return
    end
    local ok, err = AddItemToCurrentList(link, 1)
    if ok then
        print("|cff33eecc" .. ADDON_NAME .. ":|r Added", link, "x1 to list:", EllasShoppingListDB.current)
        EllasShoppingList_UI_Update()
    else
        print("|cff33eecc" .. ADDON_NAME .. ":|r Failed to add:", err)
    end
end

-- UI creation
local MainFrame
local rowFrames = {}

-- Up to this many visible rows in main list
local VISIBLE_ROWS = 10

-- Update the list display
function EllasShoppingList_UI_Update()
    if not MainFrame then return end
    local cur = EllasShoppingListDB.current or "Default"
    AddListIfMissing(cur)
    local list = EllasShoppingListDB.lists[cur]
    -- update label
    MainFrame.title:SetText(ADDON_NAME .. " - " .. cur)

    local num = #list
    local offset = FauxScrollFrame_GetOffset(MainFrame.scroll) or 0
    FauxScrollFrame_Update(MainFrame.scroll, num, VISIBLE_ROWS, 22)

    for i = 1, VISIBLE_ROWS do
        local idx = i + offset
        local row = rowFrames[i]
        if idx <= num then
            local entry = list[idx]
            local id = itemIdFromLink(entry.link)
            local price = "??"
            local qty = entry.qty or 1
            if id then
                local cacheItem = EllasShoppingListDB.itemCache[id]
                if cacheItem and cacheItem.price then
                    local priceNr = tonumber(cacheItem.price) or 0
                    priceNr = priceNr * qty
                    price = FormatGoldString(priceNr)
                end
            end
            row.link = entry.link
            row.icon:SetTexture(entry.icon or 0)
            row.nameText:SetTextToFit(entry.name or entry.link)
            row.qtyEdit:SetText(tostring(qty))
            local goldStr = "|cFFFFD700" .. price .. "|r"
            row.priceText:SetTextToFit(goldStr)

            row:Show()
        else
            row:Hide()
        end
    end
end

-- Remove an item at visible row index
local function RemoveAtVisible(i)
    local offset = FauxScrollFrame_GetOffset(MainFrame.scroll) or 0
    local idx = i + offset
    local cur = EllasShoppingListDB.current
    if EllasShoppingListDB.lists[cur] and EllasShoppingListDB.lists[cur][idx] then
        tremove(EllasShoppingListDB.lists[cur], idx)
        EllasShoppingList_UI_Update()
    end
end

-- Change qty for visible row index
local function SetQtyAtVisible(i, qty)
    local offset = FauxScrollFrame_GetOffset(MainFrame.scroll) or 0
    local idx = i + offset
    local cur = EllasShoppingListDB.current
    qty = tonumber(qty) or 1
    if EllasShoppingListDB.lists[cur] and EllasShoppingListDB.lists[cur][idx] then
        EllasShoppingListDB.lists[cur][idx].qty = qty
        EllasShoppingList_UI_Update()
    end
end

-- Build main UI
local function BuildMainFrame()
    MainFrame = CreateFrame("Frame", ADDON_NAME .. "MainFrame", UIParent, "BasicFrameTemplateWithInset")
    MainFrame.width = 400
    MainFrame:SetSize(MainFrame.width, 300)
    MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    MainFrame:SetFrameStrata("MEDIUM")
    MainFrame:Hide()
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
    MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)

    MainFrame.title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    MainFrame.title:SetPoint("TOP", MainFrame.TitleBg or MainFrame, "TOP", 0, -2)

    -- Dropdown to choose list
    MainFrame.listDropdown = CreateFrame("Frame", ADDON_NAME .. "ListDropdown", MainFrame, "UIDropDownMenuTemplate")
    MainFrame.listDropdown:SetPoint("TOPLEFT", 0, -36)
    UIDropDownMenu_SetWidth(MainFrame.listDropdown, 140)

    local function UpdateDropdown()
        UIDropDownMenu_Initialize(MainFrame.listDropdown, function(self, level, menuList)
            for name, _ in pairs(EllasShoppingListDB.lists) do
                local listInfo = UIDropDownMenu_CreateInfo()
                listInfo.text = name
                listInfo.checked = (name == EllasShoppingListDB.current)
                listInfo.func = function()
                    EllasShoppingListDB.current = name
                    EllasShoppingList_UI_Update()
                    UpdateDropdown()
                end
                UIDropDownMenu_AddButton(listInfo)
            end
            -- Separator + new list entry
            local sepInfo = UIDropDownMenu_CreateInfo()
            sepInfo.isTitle = true
            sepInfo.text = " "
            UIDropDownMenu_AddButton(sepInfo)
            local createInfo = UIDropDownMenu_CreateInfo()
            createInfo.text = "Create New List..."
            createInfo.func = function()
                StaticPopup_Show("ELLS_CREATE_LIST")
            end
            UIDropDownMenu_AddButton(createInfo)
            local deleteInfo = UIDropDownMenu_CreateInfo()
            deleteInfo.text = "Delete Current List"
            deleteInfo.func = function()
                if EllasShoppingListDB.current == "Default" then
                    print("Cannot delete Default list.")
                    return
                end
                EllasShoppingListDB.lists[EllasShoppingListDB.current] = nil
                EllasShoppingListDB.current = "Default"
                EllasShoppingList_UI_Update()
                UpdateDropdown()
            end
            UIDropDownMenu_AddButton(deleteInfo)
        end)
        UIDropDownMenu_SetSelectedName(MainFrame.listDropdown, EllasShoppingListDB.current)
    end

    -- Buttons: Search Add, Close
    local addSearchBtn = CreateFrame("Button", nil, MainFrame, "GameMenuButtonTemplate")
    addSearchBtn:SetPoint("TOPRIGHT", -12, -38)
    addSearchBtn:SetSize(120, 24)
    addSearchBtn:SetText("Search/Add")
    addSearchBtn:SetScript("OnClick", function()
        -- populate cache from bags & merchant
        EllasShoppingList_PopulateCache()
        EllasShoppingList_ShowSearch()
    end)

    local closeBtn = CreateFrame("Button", nil, MainFrame, "GameMenuButtonTemplate")
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    closeBtn:SetSize(80, 24)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() MainFrame:Hide() end)

    -- Scroll area with FauxScrollFrame
    MainFrame.scroll = CreateFrame("ScrollFrame", ADDON_NAME .. "FauxScrollFrame", MainFrame, "FauxScrollFrameTemplate")
    MainFrame.scroll:SetPoint("TOPLEFT", 12, -70)
    MainFrame.scroll:SetPoint("BOTTOMRIGHT", -12, 48)
    MainFrame.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 22, EllasShoppingList_UI_Update)
    end)

    -- Create rows
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", ADDON_NAME .. "Row" .. i, MainFrame)
        row:SetPoint("TOPLEFT", MainFrame.scroll, "TOPLEFT", 6, -((i - 1) * 22 + 6))
        row:SetSize(MainFrame.scroll:GetWidth() - 6, 20)

        -- Quantity edit
        row.qtyEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.qtyEdit:SetSize(20, 18)
        row.qtyEdit:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.qtyEdit:SetAutoFocus(false)
        row.qtyEdit:SetNumeric(true)
        row.qtyEdit:SetJustifyH("CENTER")
        row.qtyEdit:SetScript("OnEnterPressed", function(self)
            SetQtyAtVisible(i, self:GetText())
        end)
        row.qtyEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        -- Icon (18x18)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", row.qtyEdit, "RIGHT", 6, 0)
        row.icon:SetTexture(0)

        -- Item name
        row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.nameText:SetJustifyH("LEFT")

        -- Remove Btn
        row.removeBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        row.removeBtn:SetSize(18, 18)
        row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.removeBtn:SetScript("OnClick", function() RemoveAtVisible(i) end)

        -- Vendor price
        row.priceText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        row.priceText:SetPoint("RIGHT", row.removeBtn, "LEFT", -6, 0)
        row.priceText:SetJustifyH("LEFT")

        row:Hide()
        rowFrames[i] = row
    end

    -- Popup for creating new list
    StaticPopupDialogs["ELLS_CREATE_LIST"] = {
        text = "Enter new list name:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        whileDead = true,
        timeout = 0,
        hideOnEscape = true,
        OnShow = function(self, data)
            self.EditBox:SetText("NewList")
        end,
        OnAccept = function(self, _data, _data2)
            local name = self.EditBox:GetText()
            if not name or name == "" then name = "List" end
            EllasShoppingListDB.lists[name] = EllasShoppingListDB.lists[name] or {}
            EllasShoppingListDB.current = name
            EllasShoppingList_UI_Update()
            UpdateDropdown()
        end
    }

    UpdateDropdown()
    MainFrame:Hide()

    tinsert(UISpecialFrames, MainFrame:GetName())
end

function SearchItemSource()
    return EllasShoppingListDB.itemCache
end

function EllasShoppingList_ShowSearch()
    if not ans.SearchUi.searchFrame then 
        ans.SearchUi:BuildSearchFrame(ADDON_NAME, AddItemToCurrentList, SearchItemSource)
    end
    ans.SearchUi:Show()
end

-- Populate cache from bags and merchant frame
function EllasShoppingList_PopulateCache()
    -- bags
    if C_Container then
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local link = C_Container.GetContainerItemLink(bag, slot)
                if link then
                    AddItemToCache(link)
                end
            end
        end
    end
    -- equipped?
    for i = 1, 19 do
        local link = GetInventoryItemLink("player", i)
        if link then AddItemToCache(link) end
    end
    -- merchant
    if MerchantFrame and MerchantFrame:IsShown() then
        local num = GetMerchantNumItems()
        for i = 1, num do
            local link = GetMerchantItemLink(i)
            if link then AddItemToCache(link) end
        end
    end
end

-- Initialization
local ldb = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
    type = "launcher",
    text = "EllasShoppingList",
    icon = "Interface\\ICONS\\INV_Misc_Bag_10",
    OnClick = function(self, button)
        if MainFrame and MainFrame:IsShown() then
            MainFrame:Hide()
        else
            if not MainFrame then BuildMainFrame() end
            MainFrame:Show()
            EllasShoppingList_UI_Update()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Ellas Shopping List")
        tooltip:AddLine("Left-Click: Toggle UI")
    end,
})
local ldbi = LibStub("LibDBIcon-1.0")

local function Init()
    print("Init called")
    if EllasShoppingListDB.lists == nil then
        EllasShoppingListDB.lists = { ["Default"] = {} }
    end
    if EllasShoppingListDB.current == nil then
        EllasShoppingListDB.current = "Default"
    end
    if EllasShoppingListDB.itemCache == nil then
        EllasShoppingListDB.itemCache = {}
    end

    if not EllasShoppingListDB.minimapIconTable then
        EllasShoppingListDB.minimapIconTable = {}
    end

    ldbi:Register(ADDON_NAME, ldb, EllasShoppingListDB.minimapIconTable)
end

-- Event handling
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Init()
        if not MainFrame then BuildMainFrame() end
        if not ans.SearchUi.searchFrame then ans.SearchUi:BuildSearchFrame(ADDON_NAME, AddItemToCurrentList, SearchItemSource) end
        print("|cff33eeccEllasShoppingList:|r Loaded. Use the minimap button or /ells to open.")
        -- Create slash command
        SLASH_ELLAS1 = "/ells"
        SlashCmdList["ELLAS"] = function(msg)
            if MainFrame:IsShown() then MainFrame:Hide() else
                MainFrame:Show(); EllasShoppingList_UI_Update()
            end
        end
    elseif event == "MERCHANT_SHOW" then
        -- populate cache automatically when merchant opens
        EllasShoppingList_PopulateCache()
        -- Update vendor prices for items in current list
        if EllasShoppingListDB.itemCache then
            print("Updating vendor prices in item cache...")
            local num = GetMerchantNumItems()
            -- Search for this item in the merchant window
            for merchantIdx = 1, num do
                local link = GetMerchantItemLink(merchantIdx)
                if link then
                    local id = itemIdFromLink(link)
                    if not EllasShoppingListDB.itemCache[id] then
                        AddItemToCache(link)
                    end
                    if EllasShoppingListDB.itemCache[id] then
                        local price = GetVendorPrice(merchantIdx)
                        if price then
                            EllasShoppingListDB.itemCache[id].price = price
                        end
                    end
                end
            end
            if MainFrame and MainFrame:IsShown() then
                EllasShoppingList_UI_Update()
            end
        end
    end
end)

-- Expose UI update function globally so hotkey or other code can call it
EllasShoppingList_UI_Update = EllasShoppingList_UI_Update

-- Bindings support: expose function requested by binding name
-- The binding name defined in Bindings.xml maps to the function call:
-- In the bindings UI you assign a key to "Add hovered item to shopping list" which calls the binding function below.
-- _G["BINDING_HEADER_ELLS"] = "Ellas Shopping List"
_G["BINDING_NAME_ELLS_ADD_HOVERED_ITEM"] = "Add hovered item to shopping list"
