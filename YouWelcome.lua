local ADDON_NAME = ...

local COOLDOWN = 5 -- seconds between replies (prevents spam/loops)

local DEFAULT_RULES = {
    { trigger = "thanks", response = "You're welcome, %n!" },
}

local DEFAULT_EVENTS = {
    join  = { enabled = true,  response = "Welcome to the guild, %n!" },
    leave = { enabled = false, response = "Farewell, %n!" },
}

local db
local lastReply = {} -- per kind: "chat", "join", "leave"

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

    for kind, defaults in pairs(DEFAULT_EVENTS) do
        db[kind] = db[kind] or { enabled = defaults.enabled, response = defaults.response }
    end
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

-- Sends response to guild chat, replacing %n with name; each kind has its own cooldown
local function Reply(kind, response, name)
    local now = GetTime()
    if now - (lastReply[kind] or 0) < COOLDOWN then return end
    lastReply[kind] = now

    local reply = response:gsub("%%n", (name:gsub("%%", "%%%%")))
    SendChat(reply, "GUILD")
end

local function OnGuildMessage(msg, sender)
    if not db.enabled then return end
    if IsSecret(msg) or IsSecret(sender) then return end

    -- Ignore your own messages
    local senderShort = Ambiguate(sender, "short")
    if senderShort == UnitName("player") then return end

    local response = FindResponse(msg)
    if response then Reply("chat", response, senderShort) end
end

-- Turns a localized global string like "%s has joined the guild." into a Lua pattern
local function ToPattern(fmt)
    if not fmt then return end
    fmt = fmt:gsub("%%%d?%$?s", "\0") -- mark placeholders (%s or %1$s)
    fmt = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return "^" .. fmt:gsub("%z", "(.+)") .. "$"
end

-- System messages that mean someone joined / left the guild (uses the client's language)
local SYSTEM_PATTERNS = {
    { kind = "join",  pattern = ToPattern(ERR_GUILD_JOIN_S) },   -- "%s has joined the guild."
    { kind = "leave", pattern = ToPattern(ERR_GUILD_LEAVE_S) },  -- "%s has left the guild."
    { kind = "leave", pattern = ToPattern(ERR_GUILD_REMOVE_SS) }, -- "%s has been kicked out of the guild by %s."
}

local function OnSystemMessage(msg)
    if not db.enabled or IsSecret(msg) then return end

    for _, p in ipairs(SYSTEM_PATTERNS) do
        local name = p.pattern and msg:match(p.pattern)
        if name then
            local cfg = db[p.kind]
            local response = strtrim(cfg.response or "")
            name = Ambiguate(name:match("|h%[?(.-)%]?|h") or name, "short") -- strip player link if any
            if cfg.enabled and response ~= "" and name ~= UnitName("player") then
                Reply(p.kind, response, name)
            end
            return
        end
    end
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

-- Checkbox + response box for a guild event ("join" / "leave")
local function CreateEventRow(kind, label, y)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 14, y)
    check.text = check.text or check.Text
    check.text:SetText(label)
    check:SetScript("OnClick", function(self)
        db[kind].enabled = self:GetChecked()
    end)

    local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    eb:SetSize(RESPONSE_WIDTH + 36, 24)
    eb:SetPoint("TOPLEFT", 20 + TRIGGER_WIDTH, y - 2)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(255)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then db[kind].response = self:GetText() end
    end)

    return function()
        check:SetChecked(db[kind].enabled)
        eb:SetText(db[kind].response or "")
        eb:SetCursorPosition(0)
    end
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
    panel:SetSize(540, 480)
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
    hint:SetText("|cffffffff%n|r in a response = player name")

    local eventsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    eventsHeader:SetPoint("TOPLEFT", 20, -66)
    eventsHeader:SetText("Guild events")

    local refreshJoin  = CreateEventRow("join",  "Someone joins",  -82)
    local refreshLeave = CreateEventRow("leave", "Someone leaves", -110)

    local rulesHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rulesHeader:SetPoint("TOPLEFT", 20, -150)
    rulesHeader:SetText("Chat rules")

    local triggerHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    triggerHeader:SetPoint("TOPLEFT", 22, -170)
    triggerHeader:SetText("Trigger phrase")

    local responseHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    responseHeader:SetPoint("LEFT", triggerHeader, "LEFT", TRIGGER_WIDTH + 12, 0)
    responseHeader:SetText("Response")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -188)
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
        refreshJoin()
        refreshLeave()
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
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        InitDB()
        f:UnregisterEvent("ADDON_LOADED")
    elseif not db then
        return
    elseif event == "CHAT_MSG_GUILD" then
        local msg, sender = ...
        OnGuildMessage(msg, sender)
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage((...))
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
        for _, kind in ipairs({ "join", "leave" }) do
            Print(("%s [%s]: \"%s\""):format(kind, db[kind].enabled and "on" or "off", db[kind].response or ""))
        end
        if #db.rules == 0 then Print("no rules.") end
        for i, rule in ipairs(db.rules) do
            Print(("%d. \"%s\" -> \"%s\""):format(i, rule.trigger or "", rule.response or ""))
        end
    else
        TogglePanel()
    end
end
