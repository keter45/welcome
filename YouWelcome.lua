local ADDON_NAME = ...

local COOLDOWN = 5 -- seconds between replies (prevents spam/loops)

local DEFAULT_RULES = {
    { trigger = "thanks", response = "You're welcome, %n!" },
}

local db
local lastReply = 0

local function Print(msg)
    print("|cff33ff99You Welcome|r: " .. msg)
end

-- Midnight (12.x) moved SendChatMessage to C_ChatInfo
local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

-- In 12.x, chat messages may arrive as "secret values" (unreadable by addons)
local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local function InitDB()
    YouWelcomeDB = YouWelcomeDB or {}
    db = YouWelcomeDB
    if db.enabled == nil then db.enabled = true end

    if not db.rules then
        db.rules = {}
        -- Migrate the single trigger/response from v1.x
        if db.trigger or db.response then
            tinsert(db.rules, { trigger = db.trigger or "", response = db.response or "" })
        else
            for _, r in ipairs(DEFAULT_RULES) do
                tinsert(db.rules, { trigger = r.trigger, response = r.response })
            end
        end
    end
    db.trigger, db.response, db.cooldown = nil, nil, nil
end

---------------------------------------------------------------------------
-- Core logic
---------------------------------------------------------------------------
-- Returns the response of the first rule whose trigger appears in msg
local function FindResponse(msg)
    local lowered = msg:lower()
    for _, rule in ipairs(db.rules) do
        local trigger  = strtrim(rule.trigger or "")
        local response = strtrim(rule.response or "")
        -- Plain, case-insensitive search (no Lua patterns)
        if trigger ~= "" and response ~= "" and lowered:find(trigger:lower(), 1, true) then
            return response
        end
    end
end

local function OnGuildMessage(msg, sender)
    if not db.enabled then return end
    if IsSecret(msg) or IsSecret(sender) then return end

    -- Ignore your own messages
    local senderShort = Ambiguate(sender, "short")
    if senderShort == UnitName("player") then return end

    local response = FindResponse(msg)
    if not response then return end

    local now = GetTime()
    if now - lastReply < COOLDOWN then return end
    lastReply = now

    local reply = response:gsub("%%n", (senderShort:gsub("%%", "%%%%")))
    SendChat(reply, "GUILD")
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local ROW_HEIGHT = 30
local TRIGGER_WIDTH, RESPONSE_WIDTH = 170, 250

local panel, scrollChild, emptyText
local rows = {}

local function CreateEditBox(parent, width, field)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width, 24)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(255)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local rule = db.rules[parent.index]
        if rule then rule[field] = self:GetText() end
    end)
    return eb
end

local RefreshRows

local function GetRow(i)
    if rows[i] then return rows[i] end

    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(TRIGGER_WIDTH + RESPONSE_WIDTH + 50, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 6, -(i - 1) * ROW_HEIGHT)

    row.trigger = CreateEditBox(row, TRIGGER_WIDTH, "trigger")
    row.trigger:SetPoint("LEFT", 0, 0)

    row.response = CreateEditBox(row, RESPONSE_WIDTH, "response")
    row.response:SetPoint("LEFT", row.trigger, "RIGHT", 12, 0)

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(24, 22)
    row.remove:SetPoint("LEFT", row.response, "RIGHT", 6, 0)
    row.remove:SetText("X")
    row.remove:SetScript("OnClick", function()
        tremove(db.rules, row.index)
        RefreshRows()
    end)
    row.remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove rule")
        GameTooltip:Show()
    end)
    row.remove:SetScript("OnLeave", GameTooltip_Hide)

    rows[i] = row
    return row
end

function RefreshRows()
    for i, rule in ipairs(db.rules) do
        local row = GetRow(i)
        row.index = i
        row.trigger:SetText(rule.trigger or "")
        row.response:SetText(rule.response or "")
        row.trigger:SetCursorPosition(0)
        row.response:SetCursorPosition(0)
        row:Show()
    end
    for i = #db.rules + 1, #rows do
        rows[i]:Hide()
    end
    scrollChild:SetHeight(math.max(#db.rules * ROW_HEIGHT, 1))
    emptyText:SetShown(#db.rules == 0)
end

local function CreatePanel()
    panel = CreateFrame("Frame", "YouWelcomePanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(540, 380)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    tinsert(UISpecialFrames, "YouWelcomePanel") -- close with ESC

    panel.TitleText:SetText("You Welcome")

    local enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 14, -30)
    enabled.text = enabled.text or enabled.Text
    enabled.text:SetText("Enabled")
    enabled:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
    end)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPRIGHT", -16, -40)
    hint:SetText("|cffffffff%n|r in a response = sender name")

    local triggerHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    triggerHeader:SetPoint("TOPLEFT", 22, -66)
    triggerHeader:SetText("Trigger phrase")

    local responseHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    responseHeader:SetPoint("LEFT", triggerHeader, "LEFT", TRIGGER_WIDTH + 12, 0)
    responseHeader:SetText("Response")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -84)
    scroll:SetPoint("BOTTOMRIGHT", -34, 48)

    scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(TRIGGER_WIDTH + RESPONSE_WIDTH + 60, 1)
    scroll:SetScrollChild(scrollChild)

    emptyText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("CENTER", scroll, "CENTER")
    emptyText:SetText("No rules yet. Click \"Add rule\" to create one.")

    local add = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    add:SetSize(110, 24)
    add:SetPoint("BOTTOMLEFT", 14, 14)
    add:SetText("Add rule")
    add:SetScript("OnClick", function()
        tinsert(db.rules, { trigger = "", response = "" })
        RefreshRows()
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
        rows[#db.rules].trigger:SetFocus()
    end)

    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("BOTTOMRIGHT", -16, 20)
    info:SetText("Changes are saved automatically. First matching rule wins.")

    panel:SetScript("OnShow", function()
        enabled:SetChecked(db.enabled)
        RefreshRows()
    end)
end

local function TogglePanel()
    if not panel then CreatePanel() end
    panel:SetShown(not panel:IsShown())
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_GUILD")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        InitDB()
        f:UnregisterEvent("ADDON_LOADED")
    elseif event == "CHAT_MSG_GUILD" and db then
        local msg, sender = ...
        OnGuildMessage(msg, sender)
    end
end)

SLASH_YOUWELCOME1 = "/yw"
SLASH_YOUWELCOME2 = "/youwelcome"
SlashCmdList.YOUWELCOME = function(arg)
    arg = strtrim(arg or ""):lower()
    if arg == "on" then
        db.enabled = true;  Print("enabled.")
    elseif arg == "off" then
        db.enabled = false; Print("disabled.")
    elseif arg == "list" then
        if #db.rules == 0 then Print("no rules.") end
        for i, rule in ipairs(db.rules) do
            Print(("%d. \"%s\" -> \"%s\""):format(i, rule.trigger or "", rule.response or ""))
        end
    else
        TogglePanel()
    end
end
