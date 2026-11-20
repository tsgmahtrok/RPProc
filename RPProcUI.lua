--[[=========================================================================
    RPProcUI - Grafischer Editor fuer RPProc (Version 2.5-BackdropFix)
    ---------------------------------------------------------------------------
    Oeffnen:  /rpp ui   (oder /rpp editor)
    Alles was hier geaendert wird, landet direkt in den SavedVariables
    (RPProcDB) und wird beim Logout gespeichert. Kein /reload noetig.

    Robustheits-Design: bewusst NUR Basis-UI-APIs (CreateFrame, Buttons,
    EditBox, FontStrings, Farb-Texturen) OHNE Templates (kein
    FauxScrollFrame, kein UIDropDownMenu, kein Ace, kein
    BackdropTemplate). Hintergruende als Farb-TEXTURES statt
    Backdrop-API (moderne Clients haben deren Funktionen entfernt).
    Paginierung statt Scrollbars. Falls der Client exotisch ist,
    funktioniert dies trotzdem.
    Alle mutierenden Zugriffe laufen direkt auf RPProcDB.sets/config,
    die Engine liest dieselben Tabellen -> Aenderungen greifen sofort.
=========================================================================]]--

local DB = RPProcDB                 -- SavedVariables (von RPProc.lua initialisiert)
local SETS = DB.sets
local CFG = DB.config

-- Zustand
local frame                        -- Hauptfenster (lazy erstellt)
local setPage, setMaxPage = 1, 1   -- Seiten der Set-Liste
local msgPage, msgMaxPage = 1, 1   -- Seiten der Spruch-Liste
local selectedSet = nil            -- Name des gewaehlten Sets
local catFilter = nil              -- aktiver Kategorie-Filter (nil = alle)
local selectedMsg = nil            -- Index des gewaehlten Spruchs
local setRows, msgRows = {}, {}    -- Button-Pools
local widgets = {}                 -- Detail-Widgets fuer Refresh

local SETS_PER_PAGE = 14
local MSGS_PER_PAGE = 7

-- Font-Objekte mit Fallback (falls einer auf dem Client fehlt)
RPProcUI_VERSION = "2.12.2-ChannelFix"

local F_NORMAL = GameFontNormal or GameFontHighlight
local F_HIGH = GameFontHighlight or F_NORMAL
local F_GREEN = GameFontGreen or F_HIGH
local F_LARGE = GameFontNormalLarge or F_HIGH

-- Hintergrund als TEXTURE statt Backdrop-API: die Backdrop-Funktionen
-- fehlen auf modernen Clients (zugunsten von BackdropTemplate entfernt),
-- Texture-Farbfuellung gibt es ueberall. Feature-Erkennung alte/neue API.
local function MakeBG(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    if t.SetColorTexture then
        t:SetColorTexture(r, g, b, a)
    else
        t:SetTexture(r, g, b, a)
    end
    t:SetAllPoints(parent)
    return t
end

local function SetBG(tex, r, g, b, a)
    if not tex then return end
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    else
        tex:SetTexture(r, g, b, a)
    end
end

---------------------------------------------------------------------
-- Kleine Helfer
---------------------------------------------------------------------

local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("RPProc: " .. tostring(text))
end

local function CatOf(name)
    return (SETS[name] and SETS[name].cat) or "General"
end

local function SortedSetNames()
    local keys = {}
    for k in pairs(SETS) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        local ca, cb = CatOf(a), CatOf(b)
        if ca ~= cb then
            if ca == "General" then return true end
            if cb == "General" then return false end
            return ca < cb
        end
        return a < b
    end)
    return keys
end

local function SetCount()
    local n = 0
    for _ in pairs(SETS) do n = n + 1 end
    return n
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Trim(s)
    return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

-- Stilierter Button (Text-only, mit einfachem Backdrop)
-- Hover-Erklaerung: Titel gelb, Text weiss, Beispiel gruen.
-- GameTooltip ist auf exotischen Clients evtl. anders benannt -> Guard.
local function AddTip(btn, title, body, example)
    if not btn or not GameTooltip then return end
    btn:SetScript("OnEnter", function(self)
        SetBG(self.tex, 0.35, 0.35, 0.15, 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(body, 1, 1, 1, 1)
        if example then GameTooltip:AddLine(example, 0.4, 0.9, 0.4, 1) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        SetBG(self.tex, 0.15, 0.15, 0.15, 0.9)
        GameTooltip:Hide()
    end)
end

local function MakeButton(parent, text, width, x, y, onClick, align)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", x, y)
    b.tex = MakeBG(b, 0.15, 0.15, 0.15, 0.9)
    if b.SetNormalFontObject then b:SetNormalFontObject(F_HIGH) end
    if b.SetHighlightFontObject then b:SetHighlightFontObject(F_NORMAL) end
    b:SetText(text)
    if align == "LEFT" then
        -- Eigener FontString statt Button-Text: GetFontString/justify des
        -- Button-Textes ist auf exotischen Clients unzuverlaessig. Wir
        -- rendern den Text selbst und leiten SetText darauf um.
        b:SetText("")
        local fs = b:CreateFontString(nil, "OVERLAY")
        if fs.SetFontObject then fs:SetFontObject(F_HIGH) end
        fs:SetJustifyH("LEFT")
        fs:SetPoint("TOPLEFT", b, "TOPLEFT", 15, 0)
        fs:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 0)
        fs:SetText(text)
        b.leftText = fs
        b.SetText = function(self, t)
            self.leftText:SetText(t)
        end
    end
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) SetBG(self.tex, 0.35, 0.35, 0.15, 0.95) end)
    b:SetScript("OnLeave", function(self) SetBG(self.tex, 0.15, 0.15, 0.15, 0.9) end)
    return b
end

-- Schlichtes Label
local function MakeLabel(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    -- 5px Tiefversatz: Ausgleich gegenueber Button-Text (22px Button, Text zentriert)
    fs:SetPoint("TOPLEFT", x, y - 5)
    if fs.SetFontObject then fs:SetFontObject(font or F_NORMAL) end
    fs:SetText(text)
    return fs
end

-- Eingabefeld (einzeilig)
local function MakeEditBox(parent, width, x, y)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetWidth(width)
    e:SetHeight(24)
    e:SetPoint("TOPLEFT", x, y)
    e.tex = MakeBG(e, 0, 0, 0, 0.9)
    if e.SetFontObject then e:SetFontObject(F_HIGH) end
    if e.SetTextInsets then e:SetTextInsets(10, 0, 0, 0) end -- 10px Text-Offset links
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return e
end

---------------------------------------------------------------------
-- Refresh-Funktionen
---------------------------------------------------------------------

-- Sprachen-Dropdown: Forever-Client-IDs (empirisch verifiziert, siehe
-- decisions.md): Zwerg spricht genau 6 = Zwergisch, 7 = Gemein.
-- Sprach-IDs: Retail-ID-Tabelle (Sebastian), 6=Zwergisch und 7=Gemein
-- auf dem Forever-Client verifiziert, Rest plausibel (per /rpp langtest
-- gegenpruefbar). Nicht spielbare Fraktions-/NPC-Sprachen weggelassen.
local LANG_ENTRIES = {
    { label = "Standard",     value = nil },
    { label = "Gemeinsprache", value = 7 },
    { label = "Zwergisch",    value = 6 },
    { label = "Orkisch",      value = 1 },
    { label = "Darnassisch",  value = 2 },
    { label = "Taurisch",     value = 3 },
    { label = "Thalassisch",  value = 10 },
    { label = "Gnomisch",     value = 13 },
    { label = "Zandali",      value = 14 },
    { label = "Verlassenen",  value = 33 },
}

local function LangLabel(v)
    if v == nil then return "Standard" end
    for _, e in ipairs(LANG_ENTRIES) do
        if e.value == v then return e.label end
    end
    return "ID " .. tostring(v)
end

local function RefreshConfig()
    if not widgets.cdVal then return end
    widgets.cdVal:SetText(string.format("%.1fs", CFG.cooldown or 0))
    widgets.gcVal:SetText((CFG.globalChance or 100) .. "%")
    widgets.debugBtn:SetText("Debug: " .. (CFG.debug and "|cff00ff00AN|r" or "|cffff0000AUS|r"))
    widgets.powerBtn:SetText("Addon: " .. (CFG.enabled and "|cff00ff00AKTIV|r" or "|cffff0000AUS|r"))
end

local function RefreshSetList()
    local keys = SortedSetNames()
    if catFilter then
        local f = {}
        for _, k in ipairs(keys) do
            if CatOf(k) == catFilter then table.insert(f, k) end
        end
        keys = f
    end
    local total = SetCount()
    local shown = table.getn(keys)
    setMaxPage = math.max(1, math.ceil(shown / SETS_PER_PAGE))
    setPage = Clamp(setPage, 1, setMaxPage)
    if catFilter then
        widgets.setCountLbl:SetText("Sets (" .. shown .. "/" .. total .. "):")
    else
        widgets.setCountLbl:SetText("Sets (" .. total .. "):")
    end
    widgets.setPageLbl:SetText("Seite " .. setPage .. "/" .. setMaxPage)
    local first = (setPage - 1) * SETS_PER_PAGE
    for i = 1, SETS_PER_PAGE do
        local row = setRows[i]
        local idx = first + i
        local key = keys[idx]
        if key then
            local set = SETS[key]
            -- Reine Namensanzeige: Chance/Spruchzahl stehen im Detail, die
            -- Kategorie signalisiert der Filter. Zeile bleibt dadurch ruhig.
            row:SetText(key)
            row.key = key
            row:Show()
            if key == selectedSet then
                SetBG(row.tex, 0.45, 0.35, 0.10, 1)
            else
                SetBG(row.tex, 0.12, 0.12, 0.12, 0.9)
            end
        else
            row.key = nil
            row:Hide()
        end
    end
end

local function RefreshMessages()
    local set = selectedSet and SETS[selectedSet]
    if not widgets.msgCountLbl then return end
    if not set then
        widgets.msgCountLbl:SetText("Sprüche: (kein Set gewählt)")
        widgets.msgEditBox:SetText("")
        widgets.msgEditBox:Disable()
        for i = 1, MSGS_PER_PAGE do msgRows[i]:Hide() end
        widgets.msgPageLbl:SetText("-")
        return
    end
    local n = set.messages and table.getn(set.messages) or 0
    msgMaxPage = math.max(1, math.ceil(n / MSGS_PER_PAGE))
    msgPage = Clamp(msgPage, 1, msgMaxPage)
    if selectedMsg and (selectedMsg < 1 or selectedMsg > n) then selectedMsg = nil end
    widgets.msgCountLbl:SetText("Sprüche (" .. n .. "):")
    widgets.msgPageLbl:SetText("Seite " .. msgPage .. "/" .. msgMaxPage)
    local first = (msgPage - 1) * MSGS_PER_PAGE
    for i = 1, MSGS_PER_PAGE do
        local row = msgRows[i]
        local idx = first + i
        if set.messages and set.messages[idx] then
            row:SetText(idx .. ". " .. string.sub(set.messages[idx], 1, 100))
            row.idx = idx
            row:Show()
            if idx == selectedMsg then
                SetBG(row.tex, 0.45, 0.35, 0.10, 1)
            else
                SetBG(row.tex, 0.12, 0.12, 0.12, 0.9)
            end
        else
            row.idx = nil
            row:Hide()
        end
    end
    widgets.msgEditBox:Enable()
    if selectedMsg and set.messages and set.messages[selectedMsg] then
        if not widgets.msgEditBox:HasFocus() then
            widgets.msgEditBox:SetText(set.messages[selectedMsg])
        end
    else
        widgets.msgEditBox:SetText("")
    end
end

local function RefreshDetail()
    local set = selectedSet and SETS[selectedSet]
    if not widgets.setNameLbl then return end
    if not set then
        widgets.setNameLbl:SetText("(Set links wählen oder /rpp add)")
        widgets.chanceLbl:SetText("-")
        widgets.modeBtn:Hide()
        widgets.channelBtn:Hide()
        widgets.testBtn:Hide()
        widgets.macroLbl:Hide()
        widgets.macroBox:Hide()
        widgets.tglSelfCast:Hide()
        widgets.tglAllowSelf:Hide()
        widgets.tglPetReq:Hide()
        widgets.tglPetFor:Hide()
        widgets.tglAllowDead:Hide()
        widgets.tglNoAnimals:Hide()
        widgets.spellLbl:Hide()
        widgets.spellBox:Hide()
        widgets.langLbl:Hide()
        widgets.langBtn:Hide()
        widgets.langIDLbl:Hide()
        widgets.langIDBox:Hide()
        if widgets.langMenu then widgets.langMenu:Hide() end
        widgets.catLbl:Hide()
        widgets.catBtn:Hide()
        if widgets.catMenu then widgets.catMenu:Hide() end
        widgets.delBtn:Hide()
        return
    end
    widgets.setNameLbl:SetText(selectedSet)
    widgets.chanceLbl:SetText((set.chance or 15) .. "%")
    widgets.modeBtn:Show()
    widgets.channelBtn:Show()
    widgets.testBtn:Show()
    widgets.macroLbl:Show()
    widgets.macroBox:Show()
    widgets.tglSelfCast:Show()
    widgets.tglAllowSelf:Show()
    widgets.tglPetReq:Show()
    widgets.tglPetFor:Show()
    widgets.tglAllowDead:Show()
    widgets.tglNoAnimals:Show()
    widgets.spellLbl:Show()
    widgets.spellBox:Show()
    widgets.langLbl:Show()
    widgets.langBtn:Show()
    widgets.langIDLbl:Show()
    widgets.langIDBox:Show()
    widgets.catLbl:Show()
    widgets.catBtn:Show()
    widgets.delBtn:Show()

    local modeTxt = "Ziel: Alle"
    if set.mode == "friend" then modeTxt = "Ziel: |cff00ff00Freund|r" end
    if set.mode == "enemy" then modeTxt = "Ziel: |cffff0000Gegner|r" end
    widgets.modeBtn:SetText(modeTxt)
    widgets.channelBtn:SetText("Channel: " .. (set.channel or "SAY"))

    local function TglText(on, label)
        return (on and "|cff00ff00[x]|r " or "|cffff6666[ ]|r ") .. label
    end
    if not widgets.macroBox:HasFocus() then
        widgets.macroBox:SetText('/run RPProc("' .. selectedSet .. '")')
    end
    widgets.tglSelfCast:SetText(TglText(set.selfCast == true, "Ziel: Ich selbst"))
    widgets.tglAllowSelf:SetText(TglText(set.allowSelf == true, "An mich als Freund"))
    widgets.tglPetReq:SetText(TglText(set.petRequired == true, "Nur mit Pet aktiv"))
    widgets.tglPetFor:SetText(TglText(set.petForbidden == true, "Nur ohne Pet"))
    widgets.tglAllowDead:SetText(TglText(set.allowDead == true, "Auch tote Ziele"))
    widgets.tglNoAnimals:SetText(TglText(set.excludeAnimals == true, "Keine Wildtiere"))

    if not widgets.spellBox:HasFocus() then
        if set.spell == false then
            widgets.spellBox:SetText("false")
        elseif set.spell == nil then
            widgets.spellBox:SetText(selectedSet or "")
        else
            widgets.spellBox:SetText(set.spell)
        end
    end
    widgets.langBtn:SetText(LangLabel(set.language))
    if not widgets.langIDBox:HasFocus() then
        widgets.langIDBox:SetText(set.language and tostring(set.language) or "")
    end
    widgets.catBtn:SetText(set.cat or "General")
end

local function RefreshAll()
    RefreshConfig()
    RefreshSetList()
    RefreshDetail()
    RefreshMessages()
end

---------------------------------------------------------------------
-- Aktionen
---------------------------------------------------------------------

local function SelectSet(name)
    selectedSet = name
    selectedMsg = nil
    msgPage = 1
    RefreshAll()
end

local function DoSetPage(delta)
    setPage = Clamp(setPage + delta, 1, setMaxPage)
    RefreshSetList()
end

local function DoMsgPage(delta)
    msgPage = Clamp(msgPage + delta, 1, msgMaxPage)
    selectedMsg = nil
    RefreshMessages()
end

local function NewSet()
    local name = Trim(widgets.newSetBox:GetText())
    if name == "" then Msg("Bitte links im Eingabefeld einen Namen eingeben") return end
    if SETS[name] then Msg("Set existiert bereits: " .. name) return end
    SETS[name] = { chance = 15, messages = {}, cat = "General" }
    widgets.newSetBox:SetText("")
    selectedSet = name
    selectedMsg = nil
    msgPage, setPage = 1, math.ceil(SetCount() / SETS_PER_PAGE)
    RefreshAll()
    Msg("Set angelegt: " .. name)
end

local function DeleteSet()
    if not selectedSet then return end
    SETS[selectedSet] = nil
    Msg("Set gelöscht: " .. selectedSet)
    selectedSet = nil
    selectedMsg = nil
    setPage = Clamp(setPage, 1, math.max(1, math.ceil(SetCount() / SETS_PER_PAGE)))
    RefreshAll()
end

local function ChangeChance(delta)
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    set.chance = Clamp((set.chance or 15) + delta, 0, 100)
    RefreshDetail()
    RefreshSetList()
end

local function CycleMode()
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    if set.mode == nil then set.mode = "friend"
    elseif set.mode == "friend" then set.mode = "enemy"
    else set.mode = nil end
    RefreshDetail()
end

local function CycleChannel()
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    -- "SAY" explizit statt nil: ipairs bricht beim ERSTEN nil sofort ab,
    -- mit nil als erstem Eintrag lief die Suche nie und der Channel blieb
    -- fuer immer SAY (der Ur-Bug des "wir haben nur SAY"-Zustands).
    local order = { "SAY", "YELL", "PARTY", "RAID", "GUILD", "OFFICER",
        "RAID_WARNING", "EMOTE", "WHISPER" }
    local cur = set.channel or "SAY"
    local nextCh = order[1]
    for i, ch in ipairs(order) do
        if ch == cur then nextCh = order[i + 1] or order[1] break end
    end
    set.channel = nextCh
    RefreshDetail()
end

local function ToggleField(field)
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    if set[field] == true then set[field] = nil else set[field] = true end
    RefreshDetail()
end

local function SaveSpell()
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    local v = Trim(widgets.spellBox:GetText())
    if v == "" or (selectedSet and v == selectedSet) then set.spell = nil
    elseif string.lower(v) == "false" then set.spell = false
    else set.spell = v end
    widgets.spellBox:ClearFocus()
    RefreshDetail()
end

local function PickCat(cat)
    local set = selectedSet and SETS[selectedSet]
    if set then
        set.cat = cat
        RefreshDetail()
        RefreshSetList()
    end
    if widgets.catMenu then widgets.catMenu:Hide() end
end

-- Generisches 2-spaltiges Popup-Menue unter einem Button
local function MenuPopup(btn, menuKey, entries, cur, onSelect)
    local menu = widgets[menuKey]
    if not menu then
        menu = CreateFrame("Frame", nil, frame)
        menu:SetWidth(172)
        MakeBG(menu, 0.05, 0.05, 0.05, 0.98)
        widgets[menuKey] = menu
        widgets[menuKey .. "Rows"] = {}
    end
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    if menu:IsShown() then menu:Hide() return end
    local n = table.getn(entries)
    -- bis 6 Eintraege einspaltig (lesbare Liste), darunter 2 Spalten
    local cols = (n > 6) and 2 or 1
    local btnW = (cols == 2) and 80 or 160
    local rows = math.ceil(n / cols)
    local pool = widgets[menuKey .. "Rows"]
    for i = 1, math.max(n, table.getn(pool)) do
        local r = pool[i]
        if i <= n then
            local col = (i - 1) % cols
            local rw = math.floor((i - 1) / cols) + 1
            local x, y = 5 + col * 82, -4 - (rw - 1) * 20
            if not r then
                r = MakeButton(menu, "", 80, x, y, function(self)
                    onSelect(self.entry)
                    if menu:IsShown() then menu:Hide() end
                end, "LEFT")
                pool[i] = r
                r:SetScript("OnEnter", function(self) SetBG(self.tex, 0.45, 0.35, 0.10, 1) end)
                r:SetScript("OnLeave", function(self)
                    SetBG(self.tex, self.sel and 0.45 or 0.12, self.sel and 0.35 or 0.12,
                        self.sel and 0.10 or 0.12, 1)
                end)
            end
            r:SetWidth(btnW)
            r:SetPoint("TOPLEFT", x, y)
            r.entry = entries[i]
            r.sel = (entries[i] == cur)
            r:SetText(tostring(entries[i]))
            SetBG(r.tex, r.sel and 0.45 or 0.12, r.sel and 0.35 or 0.12,
                r.sel and 0.10 or 0.12, r.sel and 1 or 0.9)
            r:Show()
        elseif r then
            r:Hide()
        end
    end
    menu:SetHeight(8 + rows * 20)
    menu:Show()
end

local function PickLang(label)
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    for _, e in ipairs(LANG_ENTRIES) do
        if e.label == label then
            set.language = e.value
            break
        end
    end
    RefreshDetail()
end

local function ToggleLangMenu()
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    local entries = {}
    for _, e in ipairs(LANG_ENTRIES) do table.insert(entries, e.label) end
    local cur = LangLabel(set.language)
    if not set.language then
        -- Standard ist immer dabei
    elseif LangLabel(set.language) == ("ID " .. tostring(set.language)) then
        table.insert(entries, LangLabel(set.language)) -- manuelle ID mit anzeigen
        cur = LangLabel(set.language)
    end
    MenuPopup(widgets.langBtn, "langMenu", entries, cur, PickLang)
end
-- Kategorie-Presets (enum-artig) + selbst vergebene Kategorien
local CAT_PRESETS = {
    "General", "Krieger", "Paladin", "Jäger", "Schurke", "Priester",
    "Todesritter", "Schamane", "Magier", "Hexenmeister",
    "Mönch", "Druide", "Dämonenjäger", "Evoker",
}

local function KnownCats()
    local seen, list = {}, {}
    for _, c in ipairs(CAT_PRESETS) do seen[c] = true table.insert(list, c) end
    for _, set in pairs(SETS) do
        local c = set.cat
        if c and c ~= "" and not seen[c] then
            seen[c] = true
            table.insert(list, c)
        end
    end
    return list
end

local function ToggleCatMenu()
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    MenuPopup(widgets.catBtn, "catMenu", KnownCats(), set.cat or "General", PickCat)
end

local function FilterPick(cat)
    -- Achtung: "(cat == "Alle") and nil or cat" geht NICHT (and-or-Falle:
    -- nil ist falsy, "Alle" wuerde als Filter gesetzt -> 0/42-Anzeige)
    if cat == "Alle" then
        catFilter = nil
    else
        catFilter = cat
    end
    widgets.filterBtn:SetText(catFilter or "Alle")
    setPage = 1
    RefreshSetList()
end

local function ToggleFilterMenu()
    local entries = { "Alle" }
    for _, c in ipairs(KnownCats()) do table.insert(entries, c) end
    MenuPopup(widgets.filterBtn, "filterMenu", entries, catFilter or "Alle", FilterPick)
end

local function NewMsg()
    local set = selectedSet and SETS[selectedSet]
    if not set then return end
    local text = Trim(widgets.msgEditBox:GetText())
    if text == "" then text = "Neuer Spruch" end
    set.messages = set.messages or {}
    table.insert(set.messages, text)
    selectedMsg = table.getn(set.messages)
    msgPage = math.max(1, math.ceil(selectedMsg / MSGS_PER_PAGE))
    widgets.msgEditBox:SetText("")
    RefreshDetail()
    RefreshMessages()
    RefreshSetList()
end

local function DeleteMsg()
    local set = selectedSet and SETS[selectedSet]
    if not set or not selectedMsg then return end
    table.remove(set.messages, selectedMsg)
    selectedMsg = nil
    RefreshMessages()
    RefreshDetail()
    RefreshSetList()
end

local function SaveMsg()
    local set = selectedSet and SETS[selectedSet]
    if not set or not selectedMsg then return end
    local text = Trim(widgets.msgEditBox:GetText())
    if text ~= "" then
        set.messages[selectedMsg] = text
    end
    widgets.msgEditBox:ClearFocus()
    RefreshMessages()
end

local function SelectMsg(idx)
    selectedMsg = idx
    local set = selectedSet and SETS[selectedSet]
    if set and set.messages and set.messages[idx] then
        widgets.msgEditBox:SetText(set.messages[idx])
    end
    RefreshMessages()
end

---------------------------------------------------------------------
-- Fenster bauen
---------------------------------------------------------------------

local function BuildFrame()
    frame = CreateFrame("Frame", "RPProcUIFrame", UIParent)
    frame:SetWidth(950)
    frame:SetHeight(485)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    MakeBG(frame, 0.05, 0.05, 0.05, 0.95)
    frame:EnableKeyboard(false)
    tinsert(UISpecialFrames, "RPProcUIFrame") -- ESC schliesst das Fenster

    -- Titel + Close
    MakeLabel(frame, "RPProc Editor " .. RPProcUI_VERSION, 15, -12, F_LARGE)
    local closeBtn = MakeButton(frame, "X", 26, 909, -10, function() frame:Hide() end)

    -- Config-Zeile
    MakeLabel(frame, "Global Cooldown", 15, -40)
    MakeButton(frame, "-5s", 40, 140, -40, function()
        CFG.cooldown = Clamp((CFG.cooldown or 0) - 5, 0, 120) RefreshConfig() end)
    widgets.cdVal = MakeLabel(frame, "-", 185, -40, F_GREEN)
    widgets.cdVal:SetJustifyH("CENTER")
    widgets.cdVal:SetWidth(60)
    MakeButton(frame, "+5s", 40, 250, -40, function()
        CFG.cooldown = Clamp((CFG.cooldown or 0) + 5, 0, 120) RefreshConfig() end)

    MakeLabel(frame, "Global Chance", 310, -40)
    MakeButton(frame, "-10", 34, 415, -40, function()
        CFG.globalChance = Clamp((CFG.globalChance or 100) - 10, 0, 100) RefreshConfig() end)
    widgets.gcVal = MakeLabel(frame, "-", 455, -40, F_GREEN)
    widgets.gcVal:SetJustifyH("CENTER")
    widgets.gcVal:SetWidth(65)
    MakeButton(frame, "+10", 34, 525, -40, function()
        CFG.globalChance = Clamp((CFG.globalChance or 100) + 10, 0, 100) RefreshConfig() end)

    widgets.debugBtn = MakeButton(frame, "Debug", 90, 735, -40, function()
        CFG.debug = not CFG.debug RefreshConfig() end)
    widgets.powerBtn = MakeButton(frame, "Addon", 100, 835, -40, function()
        CFG.enabled = not CFG.enabled RefreshConfig() end)

    ------------------- Linke Spalte: Set-Liste -------------------
    widgets.setCountLbl = MakeLabel(frame, "Sets:", 15, -68, F_NORMAL)
    widgets.filterBtn = MakeButton(frame, "Alle", 95, 110, -68, ToggleFilterMenu)
    widgets.newSetBox = MakeEditBox(frame, 140, 15, -93)
    MakeButton(frame, "Neu", 46, 160, -94, NewSet)

    for i = 1, SETS_PER_PAGE do
        local row = MakeButton(frame, "", 190, 15, -121 - (i - 1) * 22, function(self)
            if self.key then SelectSet(self.key) end
        end, "LEFT")
        row:SetHeight(20)
        setRows[i] = row
    end

    MakeButton(frame, "<<", 34, 15, -443, function() DoSetPage(-1) end)
    widgets.setPageLbl = MakeLabel(frame, "-", 60, -443, F_HIGH)
    MakeButton(frame, ">>", 34, 170, -443, function() DoSetPage(1) end)

    ------------------- Rechte Spalte: Details -------------------
    widgets.setNameLbl = MakeLabel(frame, "", 230, -68, F_LARGE)
    widgets.setNameLbl:SetTextColor(1.0, 0.82, 0.0)

    widgets.testBtn = MakeButton(frame, "Test!", 70, 865, -66, function()
        if selectedSet then RPProc(selectedSet, 100) end
    end)
    widgets.delBtn = MakeButton(frame, "Set löschen", 100, 745, -66, DeleteSet)

    -- Chance
    MakeLabel(frame, "Chance:", 230, -100)
    MakeButton(frame, "-", 24, 300, -100, function() ChangeChance(-5) end)
    widgets.chanceLbl = MakeLabel(frame, "-", 330, -100, F_GREEN)
    widgets.chanceLbl:SetJustifyH("CENTER")
    widgets.chanceLbl:SetWidth(45)
    MakeButton(frame, "+", 24, 375, -100, function() ChangeChance(5) end)

    -- Mode + Channel
    widgets.modeBtn = MakeButton(frame, "Ziel", 130, 415, -100, CycleMode)
    widgets.channelBtn = MakeButton(frame, "Channel", 130, 552, -100, CycleChannel)

    -- Toggles (2 pro Reihe)
    widgets.macroLbl = MakeLabel(frame, "Makro:", 570, -204)
    widgets.macroBox = MakeEditBox(frame, 310, 625, -202)
    widgets.macroBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Clipboard-ersatz: WoW hat KEINE Clipboard-API. Ein Klick markiert
    -- den kompletten Makro-Text, danach reicht Strg+C.
    widgets.macroBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    widgets.tglSelfCast = MakeButton(frame, "", 160, 230, -128, function() ToggleField("selfCast") end, "LEFT")
    AddTip(widgets.tglSelfCast, "Ziel: Ich selbst",
        "Ein Spruch der ausschließlich auf dich selbst zielt. Ziel-Reihenfolge: Makro-Zwang > dieser Schalter > Mouseover > Ziel.",
        "Beispiel: Steingestalt, Geisterwolf (Self-Buffs).")
    widgets.tglAllowSelf = MakeButton(frame, "", 160, 400, -128, function() ToggleField("allowSelf") end, "LEFT")
    AddTip(widgets.tglAllowSelf, "An mich als Freund",
        "Freund-Sprüche lösen normal nicht aus, wenn du selbst das Ziel bist. Aktiviere dies, wenn dich ein eigener Spruch dennoch ansprechen soll.",
        "Beispiel: Heilung auf dich selbst: 'Wird gleich besser, <dein Name>.'")
    widgets.tglPetReq = MakeButton(frame, "", 160, 230, -152, function() ToggleField("petRequired") end, "LEFT")
    AddTip(widgets.tglPetReq, "Nur mit Pet aktiv",
        "Sprüche lösen nur aus, wenn dein Begleiter aktiv ist.",
        "Beispiel: 'Fass!' beim Jägermal.")
    widgets.tglPetFor = MakeButton(frame, "", 160, 400, -152, function() ToggleField("petForbidden") end, "LEFT")
    AddTip(widgets.tglPetFor, "Nur ohne Pet",
        "Sprüche lösen nur aus, wenn du kein Pet beschworen hast - ein totes Tier zählt noch als vorhanden.",
        "Beispiel: Sprüche beim 'Tier rufen'.")
    widgets.tglAllowDead = MakeButton(frame, "", 160, 230, -176, function() ToggleField("allowDead") end, "LEFT")
    AddTip(widgets.tglAllowDead, "Auch tote Ziele",
        "Sprüche lösen aus, wenn das anvisierte Ziel tot ist - Standardmässig schweigen Sets für Tote.",
        "Beispiel: Auferstehung: 'Geh noch nicht ins Licht, {name}.'")
    widgets.tglNoAnimals = MakeButton(frame, "", 160, 400, -176, function() ToggleField("excludeAnimals") end, "LEFT")
    AddTip(widgets.tglNoAnimals, "Keine Wildtiere",
        "Sprüche lösen nicht aus, wenn das Ziel ein Wildtier ist (Engine 2.9.3+: excludeAnimals). Wildtiere handeln nicht aus freiem Willen und können z.B. nicht 'im Namen des Lichts' angeklagt werden. Ist der Kreature-Typ nicht lesbar, schweigt das Set ebenfalls (fail-safe).",
        "Beispiel: Siegel des Furors: Anklage nur gegen willenstragende Ziele, nicht gegen Eisgrizzly.")

    -- spell + language
    widgets.spellLbl = MakeLabel(frame, "Spell ID:", 570, -128)
    widgets.spellBox = MakeEditBox(frame, 140, 625, -126)
    widgets.spellBox:SetScript("OnTabPressed", SaveSpell)
    widgets.spellBox:SetScript("OnEnterPressed", function(self) SaveSpell() self:ClearFocus() end)
    widgets.langLbl = MakeLabel(frame, "Sprache:", 570, -156)
    widgets.langBtn = MakeButton(frame, "", 140, 625, -154, ToggleLangMenu)
    -- Freie Sprach-ID (Forever-Client): verifiziert sind nur 6 = Zwergisch
    -- und 7 = Gemein. Weitere IDs ermittelt man per /rpp langtest <ID>.
    -- Das Feld zeigt/ändert die rohe ID des Sets (leer = Standard).
    widgets.langIDLbl = MakeLabel(frame, "Sprach-ID:", 780, -156)
    widgets.langIDBox = MakeEditBox(frame, 60, 825, -154)
    if widgets.langIDBox.SetNumeric then widgets.langIDBox:SetNumeric(true) end
    widgets.langIDBox:SetScript("OnEnterPressed", function(self)
        local set = selectedSet and SETS[selectedSet]
        if set then
            set.language = tonumber(Trim(self:GetText())) -- leer -> nil = Standard
        end
        self:ClearFocus()
        RefreshDetail()
    end)
    AddTip(widgets.langIDBox, "Sprach-ID direkt",
        "Numerische Sprach-ID fuer dieses Set. Verifiziert: 6 = Zwergisch, 7 = Gemein. Unbekannte IDs findest du in einer Minute mit /rpp langtest <ID>.",
        "Beispiel: /rpp langtest 5 sendet eine SAY-Nachricht in Sprache 5 - im Chat steht der Sprach-Tag.")

    widgets.catLbl = MakeLabel(frame, "Kat.:", 780, -128)
    widgets.catBtn = MakeButton(frame, "", 110, 825, -126, ToggleCatMenu)

    ------------------- Sprüche -------------------
    widgets.msgCountLbl = MakeLabel(frame, "Sprüche:", 230, -230, F_NORMAL)
    widgets.msgPageLbl = MakeLabel(frame, "-", 785, -230, F_HIGH)
    MakeButton(frame, "<<", 34, 863, -230, function() DoMsgPage(-1) end)
    MakeButton(frame, ">>", 34, 901, -230, function() DoMsgPage(1) end)

    for i = 1, MSGS_PER_PAGE do
        local row = MakeButton(frame, "", 700, 230, -256 - (i - 1) * 21, function(self)
            if self.idx then SelectMsg(self.idx) end
        end, "LEFT")
        row:SetHeight(20)
        msgRows[i] = row
    end

    -- Spruch-Editbox + Aktionen
    widgets.msgEditBox = MakeEditBox(frame, 567, 230, -415)
    widgets.msgEditBox:SetScript("OnEnterPressed", function(self) SaveMsg() self:ClearFocus() end)
    MakeButton(frame, "Übernehmen", 105, 830, -415, SaveMsg)
    MakeButton(frame, "Hinzufügen", 100, 230, -443, NewMsg)
    MakeButton(frame, "Löschen", 70, 335, -443, DeleteMsg)

    RefreshAll()
end

---------------------------------------------------------------------
-- Toggle (Slash-Ziel von RPProc.lua: /rpp ui)
---------------------------------------------------------------------

function RPProcUI_Toggle()
    if not frame then
        local ok, err = pcall(BuildFrame)
        if ok then
            DEFAULT_CHAT_FRAME:AddMessage("RPProcUI " .. RPProcUI_VERSION .. " geladen (/run print(RPProcUI_VERSION) zum Pruefen)")
        end
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("RPProc [error]: UI-Aufbau fehlgeschlagen: " .. tostring(err))
            frame = nil
            return
        end
    end
    if frame:IsShown() then
        frame:Hide()
    else
        RefreshAll()
        frame:Show()
    end
end
