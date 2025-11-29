local _, ans = ...

SearchUi = {
    searchFrame = nil,
    itemSource = nil
}

EllasShoppingListDB = EllasShoppingListDB or {}

local VISIBLE_ROWS = 8
local SCROLL_LINE_HEIGHT = 22
local SEARCH = "Search"

function SearchUi:Show()
    self:UpdateResults()
    self.searchFrame:Show()
end

-- Search frame
function SearchUi:BuildSearchFrame(addonName, action, itemSource)
    self.itemSource = itemSource
    self.searchFrame = CreateFrame("Frame", addonName .. "SearchFrame", UIParent, "BasicFrameTemplateWithInset")
    self.searchFrame:SetSize(360, 300)
    self.searchFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    self.searchFrame:SetFrameStrata("HIGH")
    self.searchFrame:Hide()
    self.searchFrame:SetMovable(true)
    self.searchFrame:EnableMouse(true)
    self.searchFrame:RegisterForDrag("LeftButton")
    self.searchFrame:SetScript("OnDragStart", self.searchFrame.StartMoving)
    self.searchFrame:SetScript("OnDragStop", self.searchFrame.StopMovingOrSizing)
    self.searchFrame.addAction = action

    self.searchFrame.title = self.searchFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.searchFrame.title:SetPoint("TOP", self.searchFrame.TitleBg or self.searchFrame, "TOP", 0, 0)
    self.searchFrame.title:SetText("Search Items")

    self.searchFrame.searchBox = CreateFrame("EditBox", nil, self.searchFrame, "SearchBoxTemplate")
    self.searchFrame.searchBox:SetPoint("TOPLEFT", 12, -36)
    self.searchFrame.searchBox:SetSize(220, 24)
    self.searchFrame.searchBox:SetAutoFocus(false)
    self.searchFrame.searchBox:SetScript("OnTextChanged", function(self) 
        SearchBoxTemplate_OnTextChanged(self);
        if SearchUi then SearchUi:UpdateResults() end
    end)

    self.searchFrame.resultsScroll = CreateFrame("ScrollFrame", addonName .. "SearchFaux", self.searchFrame,
        "FauxScrollFrameTemplate")
    self.searchFrame.resultsScroll:SetPoint("TOPLEFT", 12, -60)
    self.searchFrame.resultsScroll:SetPoint("BOTTOMRIGHT", -12, 58)
    self.searchFrame.resultsScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, SCROLL_LINE_HEIGHT)
        if SearchUi.UpdateResults then 
            SearchUi:UpdateResults()
        end
    end)


    self.searchFrame.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, self.searchFrame)
        row:SetSize(320, 20)
        row:SetPoint("TOPLEFT", self.searchFrame.resultsScroll, "TOPLEFT", 6, -((i - 1) * 22 + 6))
        
        -- Icon (18x18)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
        -- Name
        row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.nameText:SetWidth(200)

        -- Add
        row.addBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.addBtn:SetSize(60, 18)
        row.addBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.addBtn:SetText("Add")
        row.addBtn:SetScript("OnClick", function()
            if not row.link then return end
            if self.searchFrame.addAction then
                self.searchFrame.addAction(row.link, 1)
                print("|cff33eeccEllasShoppingList:|r Added", row.link)
                EllasShoppingList_UI_Update()
            end
        end)
        row:Hide()
        self.searchFrame.rows[i] = row
    end

    -- Add by ItemID box
    self.searchFrame.byId = CreateFrame("EditBox", addonName .. "AddByIndexBox", self.searchFrame, "InputBoxTemplate")
    self.searchFrame.byId:SetPoint("BOTTOMLEFT", 12, 12)
    self.searchFrame.byId:SetSize(140, 24)
    self.searchFrame.byId:SetAutoFocus(false)
    self.searchFrame.byId:SetNumeric(true)
    self.searchFrame.byId:SetMaxLetters(7)

    -- Label for Add by ItemID
    self.searchFrame.byId.label = self.searchFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.searchFrame.byId.label:SetPoint("BOTTOMLEFT", self.searchFrame.byId, "TOPLEFT", 0, 6)
    self.searchFrame.byId.label:SetText("Add by ItemID")

    -- Add by ItemID button
    self.searchFrame.byIdBtn = CreateFrame("Button", nil, self.searchFrame, "GameMenuButtonTemplate")
    self.searchFrame.byIdBtn:SetPoint("LEFT", self.searchFrame.byId, "RIGHT", 6, 0)
    self.searchFrame.byIdBtn:SetSize(60, 24)
    self.searchFrame.byIdBtn:SetText("Add")
    self.searchFrame.byIdBtn:SetScript("OnClick", function()
        local itemId = tonumber(self.searchFrame.byId:GetText() or "")
        if not itemId then
            print("|cff33eeccEllasShoppingList:|r Invalid ItemID")
            return
        end
        if not C_Item then return end -- Api Not available
        local _, itemLink = C_Item.GetItemInfo(itemId)
        if not itemLink then
            print("|cff33eeccEllasShoppingList:|r ItemID not found...API might not be ready, please try agian.")
            return
        end
        if self.searchFrame.addAction then
            self.searchFrame.addAction(itemLink, 1)
            print("|cff33eeccEllasShoppingList:|r Added", itemLink)
            EllasShoppingList_UI_Update()
        end
    end)

    local closeBtn = CreateFrame("Button", nil, self.searchFrame, "GameMenuButtonTemplate")
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    closeBtn:SetSize(80, 24)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() self.searchFrame:Hide() end)

    tinsert(UISpecialFrames, self.searchFrame:GetName())
end

function SearchUi:UpdateResults()
    local query = (self.searchFrame.searchBox:GetText() or ""):lower()
    local matches = {}
    if not self.itemSource then
        print("No item source set..")
        return
    end
    local items = self.itemSource()
    if not items then
        print("Item source empty")
        return
    end
    for _, v in pairs(items) do
        if query == "" or (v.name and string.find(string.lower(v.name), query, 1, true)) then
            tinsert(matches, v)
        end
    end
    table.sort(matches, function(a, b) return (a.name or "") < (b.name or "") end)
    local num = #matches
    -- Ensure the faux-scroll offset is valid before updating the frame.
    -- If the filtered total shrank below the current offset, clamp it to the max allowed.
    local maxOffset = math.max(0, num - VISIBLE_ROWS)
    local curOffset = FauxScrollFrame_GetOffset(self.searchFrame.resultsScroll) or 0
    if curOffset > maxOffset then
        FauxScrollFrame_SetOffset(self.searchFrame.resultsScroll, maxOffset)
    elseif curOffset < 0 then
        FauxScrollFrame_SetOffset(self.searchFrame.resultsScroll, 0)
    end
    FauxScrollFrame_Update(self.searchFrame.resultsScroll, num, VISIBLE_ROWS, SCROLL_LINE_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.searchFrame.resultsScroll) or 0

    for i = 1, VISIBLE_ROWS do
        local idx = i + offset
        local row = self.searchFrame.rows[i]
        if idx <= num then
            local item = matches[idx]
            row.link = item.link
            row.itemName = item.name
            row.nameText:SetTextToFit(item.name or item.link)
            row.icon:SetTexture(item.icon or "")
            
            row:Show()
        else
            row:Hide()
        end
    end
end

ans.SearchUi = SearchUi
