local ADDON_NAME = ...

local COOLDOWN = 5 -- seconds between replies (prevents spam/loops)

local DEFAULTS = {
    enabled  = true,
    trigger  = "thanks",
    response = "You're welcome, %n!",
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

local function InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

---------------------------------------------------------------------------
-- Core logic
---------------------------------------------------------------------------
local function OnGuildMessage(msg, sender)
    if not db.enabled or InCombat() then return end
    if IsSecret(msg) or IsSecret(sender) then return end

    local trigger  = strtrim(db.trigger or "")
    local response = strtrim(db.response or "")
    if trigger == "" or response == "" then return end

    -- Ignore your own messages
    local senderShort = Ambiguate(sender, "short")
    if senderShort == UnitName("player") then return end

    -- Plain, case-insensitive search (no Lua patterns)
    if not msg:lower():find(trigger:lower(), 1, true) then return end

    local now = GetTime()
    if now - lastReply < COOLDOWN then return end
    lastReply = now

    local reply = response:gsub("%%n", (senderShort:gsub("%%", "%%%%")))
    SendChat(reply, "GUILD")
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local panel

local function CreateLabeledEditBox(parent, label, anchor, yOffset)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    text:SetText(label)

    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(300, 24)
    eb:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 6, -4)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(255)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", eb.ClearFocus)
    return eb, text
end

local function CreatePanel()
    panel = CreateFrame("Frame", "YouWelcomePanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(360, 250)
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
    enabled:SetPoint("TOPLEFT", 14, -32)
    enabled.text = enabled.text or enabled.Text
    enabled.text:SetText("Enabled")
    enabled:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
    end)

    local triggerBox, triggerLabel = CreateLabeledEditBox(panel, "Trigger phrase:", enabled, -6)
    triggerLabel:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -6)

    local responseBox, responseLabel = CreateLabeledEditBox(panel, "Response  (|cffffffff%n|r = sender name):", triggerBox, -10)
    responseLabel:ClearAllPoints()
    responseLabel:SetPoint("TOPLEFT", triggerLabel, "BOTTOMLEFT", 0, -38)

    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(100, 24)
    save:SetPoint("BOTTOMRIGHT", -14, 14)
    save:SetText("Save")
    save:SetScript("OnClick", function()
        db.trigger  = strtrim(triggerBox:GetText())
        db.response = strtrim(responseBox:GetText())
        triggerBox:ClearFocus()
        responseBox:ClearFocus()
        Print(("Saved. Trigger: \"%s\" -> Response: \"%s\""):format(db.trigger, db.response))
    end)

    local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    test:SetSize(100, 24)
    test:SetPoint("RIGHT", save, "LEFT", -8, 0)
    test:SetText("Preview")
    test:SetScript("OnClick", function()
        local r = strtrim(responseBox:GetText()):gsub("%%n", UnitName("player"))
        Print("Reply would be: " .. r)
    end)

    panel:SetScript("OnShow", function()
        enabled:SetChecked(db.enabled)
        triggerBox:SetText(db.trigger or "")
        responseBox:SetText(db.response or "")
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
        YouWelcomeDB = YouWelcomeDB or {}
        for k, v in pairs(DEFAULTS) do
            if YouWelcomeDB[k] == nil then YouWelcomeDB[k] = v end
        end
        db = YouWelcomeDB
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
    else
        TogglePanel()
    end
end
