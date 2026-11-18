--[[=========================================================================
    RPProc 2.1 - Rollenspiel-Sprüche per Makro, im Spiel editierbar
    ---------------------------------------------------------------------------
    Aufruf im Makro (Set-Name = deutscher Skillname):

        /wirken Geringes Heilen
        /run RPProc("Geringes Heilen")

        -- Chance im Makro ueberschreiben, Rest aus dem Set:
        /run RPProc("Göttliche Pein", 35)

        -- Explizites Ziel erzwingen ("player", "target", "mouseover", "party1"...):
        /run RPProc("Heilen", nil, "player")
        --> Modi (enemy/friend) sind NICHT per Makro uebersteuerbar, nur im Set.

        -- Channel im Makro ueberschreiben (Positionen dazwischen mit nil):
        /run RPProc("Heilen", nil, nil, "PARTY")

        -- Sprache im Makro, Rest aus dem Set:
        /run RPProc("Machtwort: Schild", nil, nil, nil, 6)

        -- Alles per Makro: Chance 25, Ziel du selbst, Yell, Sprach-ID
        /run RPProc("Erneuerung", 25, "player", "YELL", 6)

    Alternativ als eigene Makro-Zeile OHNE /run (seit 1.3):
        /RPProc("Sturmangriff")

    Prinzip:
      1. Globale Proc-Chance (config.globalChance) - gilt für alle
         Sprüche zusätzlich. Dient als Gesamtdrossel.
      2. Cooldown (config.cooldown) - verhindert Spam bei
         schnellen Kettencasts.
      3. Skill-/Set-Chance - Chance des Sets oder als zweiter Parameter
         im Makro übergeben. So lösen seltene Skills fast immer aus
         und häufig genutzte Skills nur selten.
      4. Ziel: forceUnit (Makro, 3. Parameter) > selfCast > mouseover > target.
         mode = "friend"/"enemy" pro Set filtert das Ziel:
         Freund-Sets sprechen nie einen Gegner an (Self-Heal via
         eigenem Frame = Spruch auf dich), Gegner-Sets nie Verbündete.
      5. Zufälliger Spruch aus der Liste, {name} = Zielname, {me} = dein Name.

    SPEICHERUNG (seit 2.0):
      - Sets + Einstellungen liegen in den SavedVariables (RPProcDB),
        die WoW beim Logout automatisch in
        WTF/Account/<Account>/SavedVariables/RPProc.lua schreibt.
      - Beim ALLERERSTEN Start werden die Seed-Sets aus RPProcData.lua
        (seit 2.8 eigenes Daten-File, in der .toc VOR dieser Datei
        geladen) automatisch in die Datenbank uebernommen. Danach gilt
        NUR noch die Datenbank: Aenderungen an der Datei ueberschreiben
        deine im Spiel gesammelten Sets NICHT mehr.
      - .toc MUSS die Zeile "## SavedVariables: RPProcDB" enthalten,
        sonst wird nichts gespeichert!

    BEARBEITEN IM SPIEL (Set-Name in Anführungszeichen, wenn er
    Leerzeichen, Doppelpunkte etc. enthält):
      /rpp add "Neuer Skill"                    -- Set anlegen (Chance 15)
      /rpp addmsg "Sturmangriff" Khaz Modan!    -- Spruch anhängen
      /rpp addmsg "Heilen" Wird gleich besser, {name}.
      /rpp delmsg "Heilen" 3                     -- Spruch Nr. 3 löschen
      /rpp chance "Heilen" 25                    -- Chance setzen
      /rpp opt "Geisterwolf" selfCast=true      -- Option setzen
      /rpp opt "Jägermal" petRequired=true
      /rpp opt "Heilen" mode=friend
      /rpp opt "Heilen" channel=PARTY
      /rpp opt "Heilen" language=6
      /rpp opt "Heilen" allowDead=true
      /rpp opt "Heilen" spell=false             -- Skill-Check abschalten
      /rpp show "Heilen"                        -- Set ansehen (mit Nummern)
      /rpp del "Alter Skill"                    -- Set löschen
      Optionen: chance, mode(friend/enemy), selfCast, channel, language,
                petRequired, petForbidden, allowDead, allowSelf, spell
      allowSelf: friend-Sets proccen NICHT, wenn du selbst das Ziel bist
                (Standard). Wer es doch will (Selbst-Ansprache), setzt
                /rpp opt "Set" allowSelf=true

    Editor-Fenster:
      /rpp ui                -- grafischer Editor (RPProcUI.lua)
      /rpp reseed            -- Seed-Sets aus der Lua neu einspielen

    Steuerung:
      /rpp on | /rpp off | /rpp toggle
      /rpp debug (toggle) | debug on | debug off
      /rpp cooldown 15        -- globaler Cooldown in Sekunden
      /rpp globalchance 100   -- globale Gesamtdrossel
      /rpp langs               -- verfügbare Sprachen anzeigen
      /rpp langtest 5          -- Sprach-ID testen: sendet SAY in dieser Sprache
=========================================================================]]--

RPProc_Version = "2.8-DataSplit" -- /run print(RPProc_Version) zum Pruefen
-- Daten-File: /run print(RPProc_DataVersion) zeigt die Seed-Version an

---------------------------------------------------------------------
-- Persistente Datenbank (SavedVariables, siehe .toc) + Defaults
---------------------------------------------------------------------

RPProcDB = RPProcDB or {}
RPProcDB.sets   = RPProcDB.sets   or {}
RPProcDB.config = RPProcDB.config or {}

local RPProc_Defaults = {
    globalChance = 100, -- 0-100: gewinnt VOR der Set-Chance, für alles
    cooldown     = 10.0, -- Sekunden zwischen zwei Sprüchen global, 0 = aus
    language     = nil, -- globale Standardsprache (Sprach-ID als Zahl); nil = Client-Standard
    debug        = false,
    enabled      = true,
}

for k, v in pairs(RPProc_Defaults) do
    if RPProcDB.config[k] == nil then RPProcDB.config[k] = v end
end

-- Alle Modul-Teile greifen ueber diese Referenz auf die persistente
-- Config zu: Aenderungen (z.B. /rpp debug off) ueberleben den Logout.
local RPProc_Global = RPProcDB.config

---------------------------------------------------------------------
-- Debug-Ausgabe (nur aktiv bei RPProc_Global.debug = true)
---------------------------------------------------------------------

local function RPProc_Debug(reason)
    if RPProc_Global.debug then
        DEFAULT_CHAT_FRAME:AddMessage("RPProc [debug]: " .. reason)
    end
end

---------------------------------------------------------------------
-- Sicherer API-Aufruf: fehlt eine Funktion oder wirft sie einen Fehler
-- (Forever-Client-Sonderfaelle), liefert SafeCall nil zurueck und der
-- betreffende Teil-Check wird uebersprungen, statt die Proc-Logik zu
-- killen. Ein Fehler wird per RPProc_Debug gemeldet.
---------------------------------------------------------------------

local function RPProc_SafeCall(fn, ...)
    if not fn then return nil end
    -- 2. Rueckgabewert durchreichen (IsUsableSpell: usable, noMana)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    RPProc_Debug("API-Fehler: " .. tostring(a))
    return nil
end

-- Spell-ID-Lookup: Forever-Client liefert bei Spell-Funktionen mit NAME
-- nur nil (IsSpellInRange("Schildhieb", ...) -> nil, Range-Check wurde
-- stillschweigend uebersprungen). C_Spell.GetSpellInfo(name) liefert dort
-- aber eine Tabelle mit spellID; mit der ID funktioniert IsSpellInRange
-- (in-game verifiziert: true in Reichweite, false ausserhalb).
-- Cache: erfolgreiche Treffer und auch Misserfolge (false) merken.
local RPProc_SpellIDCache = {}
local function RPProc_ResolveSpellID(spell)
    if RPProc_SpellIDCache[spell] ~= nil then
        return RPProc_SpellIDCache[spell]
    end
    local id = nil
    local fn = (C_Spell and C_Spell.GetSpellInfo) or GetSpellInfo
    if fn then
        local ok, a, b, c, d, e, f, g = pcall(fn, spell)
        if ok then
            if type(a) == "table" then
                -- modernes Format: Tabelle mit spellID-Feld
                id = a.spellID or a.id
            elseif type(a) == "string" then
                -- altes Mehrfach-Format: name, rank, icon, castTime,
                -- minRange, maxRange, spellID (7. Wert)
                id = g
            end
        end
    end
    RPProc_SpellIDCache[spell] = id or false
    return RPProc_SpellIDCache[spell]
end

---------------------------------------------------------------------
-- SEED-Sets: Startbestand. Wird NUR beim allerersten Start (leere
-- Datenbank) in die SavedVariables kopiert, danach nie wieder
-- angefasst. Ab dann: nur noch im Spiel editieren.
---------------------------------------------------------------------

local function RPProc_DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = RPProc_DeepCopy(v) end
    return t
end

-- SEED-SETS (seit 2.8 im eigenen File RPProcData.lua, globale Tabelle
-- RPProc_SeedData). Die .toc laedt RPProcData.lua VOR dieser Datei.
local RPProc_Seed = RPProc_SeedData or {}
if RPProc_SeedData == nil then
    RPProc_Debug("RPProcData.lua nicht geladen: Seed leer! (.toc-Reihenfolge pruefen)")
end

-- Erster Start: Seed in die Datenbank kopieren. Danach (RPProcDB.seeded)
-- bleibt die Datei fuer den Inhalt ohne Wirkung.
if not RPProcDB.seeded then
    for k, v in pairs(RPProc_Seed) do
        RPProcDB.sets[k] = RPProc_DeepCopy(v)
    end
    RPProcDB.seeded = true
end

-- Migration: Sets ohne cat bekommen die Kategorie aus dem Seed-Line-Up
-- (nur nachtragen, nie ueberschreiben: im Spiel geaenderte Kategorien bleiben)
for k, v in pairs(RPProc_Seed) do
    local s = RPProcDB.sets[k]
    if s and v.cat and s.cat == nil then
        s.cat = v.cat
    end
end

-- Alle Laufzeit-Zugriffe laufen auf die Datenbank.
local RPProc_Sets = RPProcDB.sets

---------------------------------------------------------------------
-- Kernfunktion (wird aus Makros aufgerufen)
---------------------------------------------------------------------

local lastSay = 0

local function RPProc_Impl(setName, chance, forceUnit, channel, language)
    local set = RPProc_Sets[setName]
    if not set then
        RPProc_Debug("Unbekanntes Set '" .. tostring(setName) .. "'")
        return
    end
    if not RPProc_Global.enabled then RPProc_Debug("Addon ist AUS (/rpp on)"); return end

    -- Ziel bestimmen: selfCast = immer Spieler, sonst mouseover/target
    local u
    if set.selfCast then
        u = "player"
    elseif forceUnit and UnitExists(forceUnit) then
        u = forceUnit -- explizites Ziel aus dem Makro, z.B. "player"
    else
        u = UnitExists("mouseover") and "mouseover" or "target"
        if not UnitExists(u) then RPProc_Debug("Kein Ziel (mouseover/target)"); return end
        local friendly = UnitIsFriend("player", u)
        if set.mode == "enemy" then
            if friendly then RPProc_Debug("mode=enemy, aber Ziel ist freundlich"); return end
        elseif set.mode == "friend" then
            if UnitIsUnit(u, "player") then
                if set.allowSelf ~= true then
                    RPProc_Debug("Ziel = Spieler selbst, allowSelf nicht aktiv -> kein Proc")
                    return
                end
                u = "player" -- nur mit allowSelf=true: {name} = dein Name
            elseif not friendly then
                RPProc_Debug("mode=friend, aber Ziel ist feindlich"); return end
        else
            if UnitIsUnit(u, "player") then RPProc_Debug("Ziel = Spieler selbst, nicht erlaubt ohne selfCast"); return end
        end
    end

    -- -1) Pet-Check: pro Set optional petRequired = true -> nur proccen,
    --     wenn ein Kampf-Pet aktiv ist (z.B. "Fass!" beim Jägermal+petattack)
    --     oder petForbidden = true -> nur proccen, wenn KEIN Pet aktiv ist
    --     (z.B. Beschwörungs-Sprüche beim Tier rufen).
    if (set.petRequired or set.petForbidden) and UnitExists then
        local hasPet = UnitExists("pet")
        if set.petRequired and not hasPet then
            RPProc_Debug("Kein Kampf-Pet aktiv, petRequired nicht erfüllt")
            return
        end
        if set.petForbidden and hasPet then
            RPProc_Debug("Kampf-Pet aktiv, petForbidden nicht erfüllt")
            return
        end
    end

    -- 0) Skill-Check: nur proccen, wenn der Zauber einsetzbar ist.
    --    Robust gegen fehlende/andere Spell-APIs (SafeCall).
    --    Wichtig: /wirken laeuft VOR /run im Makro, der Zauber ist beim
    --    Check also evtl. schon gecastet und auf Cooldown. Cooldown heisst
    --    "gerade benutzt" -> Proc erlauben. Kein Cooldown + nicht benutzbar
    --    heisst echter Fehlschlag (kein Mana etc.) -> Proc unterdruecken.
    --    spell = "Anderer Name" -> ueberschreiben, spell = false -> Check abschalten
    local spell = set.spell
    if spell == nil then spell = setName end
    if spell then
        local usableFn = IsUsableSpell or (C_Spell and C_Spell.IsSpellUsable)
        local cdFn     = GetSpellCooldown or (C_Spell and C_Spell.GetSpellCooldown)
        local rangeFn  = IsSpellInRange or (C_Spell and C_Spell.IsSpellInRange)

        local usable, noMana = RPProc_SafeCall(usableFn, spell)
        if usable == nil then
            RPProc_Debug("Zauber '" .. tostring(spell) .. "' nicht pruefbar (API fehlt/Fehler/unbekannt), Check uebersprungen")
        elseif usable == false then
            -- Fall A: Ressource fehlt (noMana = 1 bei Wut/Mana-Mangel).
            -- Makro-Reihenfolge /wirken -> /run heisst: Wir laufen NACH dem
            -- Cast, die Wut/Energie wurde sehr wahrscheinlich eben fuer
            -- genau diesen Cast ausgegeben (Wut-Spells haben oft KEINEN
            -- Cooldown, der alte "gerade benutzt"-Test greift dort nie).
            -- -> Proc erlauben.
            if noMana then
                RPProc_Debug("Zauber '" .. tostring(spell) .. "' ohne Ressource (eben verbraucht) - vermutlich gerade gecastet, Proc erlaubt")
            else
            -- Fall B: anderer Grund (Haltung/Bedingung). Cooldown abfragen:
            -- alte API liefert Zahl, neue (C_Spell) evtl. eine Tabelle mit
            -- startTime/duration -> normalisieren
            local start = RPProc_SafeCall(cdFn, spell)
            if type(start) == "table" then
                start = start.startTime or start.duration or 0
            end
            if start == nil or start == 0 then
                -- Fallback: Manche Clients (Forever) liefern bei IsUsableSpell
                -- KEINEN 2. Rueckgabewert (noMana immer nil) -> Fall A greift
                -- nie. Bei Wut-/Energie-Klassen (UnitPowerType 1/3) bedeutet
                -- "nicht einsetzbar" direkt nach /wirken fast immer: Die
                -- Ressource wurde eben fuer den Cast verbraucht -> Proc
                -- erlauben. Mana-Klassen behalten die strenge Pruefung.
                local powerType = RPProc_SafeCall(UnitPowerType, "player")
                if powerType == 1 or powerType == 3 then
                    RPProc_Debug("Zauber '" .. tostring(spell) .. "' nicht einsetzbar, kein Cooldown, Wut-/Energie-Klasse ("
                        .. tostring(powerType) .. ") - vermutlich eben verbraucht, Proc erlaubt"
                        .. " [usable=" .. tostring(usable) .. ", noMana=" .. tostring(noMana) .. "]")
                    -- weiter zum Proc
                else
                    RPProc_Debug("Zauber '" .. tostring(spell) .. "' nicht einsetzbar (Bedingung), kein Cooldown"
                        .. " [usable=" .. tostring(usable) .. ", noMana=" .. tostring(noMana)
                        .. ", power=" .. tostring(powerType) .. "]")
                    return -- echter Fehlschlag
                end
            end
            -- sonst: auf Cooldown = gerade gecastet, Proc erlauben
            end -- Fall B
        end

        if u ~= "player" then
            local inRange = RPProc_SafeCall(rangeFn, spell, u)
            if inRange == nil then
                -- Name nicht aufloesbar (Forever-Client) -> per Spell-ID
                local sid = RPProc_ResolveSpellID(spell)
                if sid then
                    inRange = RPProc_SafeCall(rangeFn, sid, u)
                end
            end
            if inRange == 0 or inRange == false then
                RPProc_Debug("Ziel ausser Reichweite fuer '" .. tostring(spell) .. "'"
                    .. " [inRange=" .. tostring(inRange) .. "]")
                return
            end
        end

        local deadOrGhost = RPProc_SafeCall(UnitIsDeadOrGhost, u)
        if not set.allowDead and deadOrGhost then
            RPProc_Debug("Ziel ist tot, allowDead nicht gesetzt")
            return
        end
    end

    -- 1) Globale Proc-Chance
    if random(100) > (RPProc_Global.globalChance or 100) then
        RPProc_Debug("Globale Chance (" .. tostring(RPProc_Global.globalChance) .. "%) verfehlt")
        return
    end

    -- 2) Globaler Cooldown (Anti-Spam bei schnellen Zauberketten)
    local cd = RPProc_Global.cooldown or 0
    local now = GetTime()
    if cd > 0 and (now - lastSay) < cd then
        RPProc_Debug("Globaler Cooldown aktiv (" .. string.format("%.1f", cd - (now - lastSay)) .. "s restlich)")
        return
    end

    -- 3) Skill-/Set-Chance (Makro-Parameter schlägt Set-Standard)
    local c = chance or set.chance or 15
    if random(100) > c then
        RPProc_Debug("Proc-Set-Chance (" .. tostring(c) .. "%) verfehlt")
        return
    end
    RPProc_Debug("PROC! " .. tostring(setName))

    -- 4) Spruch wählen und Platzhalter ersetzen
    local n = set.messages and table.getn(set.messages) or 0
    if n == 0 then return end
    lastSay = now
    local msg = set.messages[random(n)]
    msg = gsub(msg, "{name}", UnitName(u) or "")
    msg = gsub(msg, "{me}", UnitName("player") or "")

    -- 5) Ausgabe im konfigurierten Channel und in der gewählten Sprache
    --    Priorität: Makro-Parameter > Set-Eintrag > RPProc_Global.language
    local chan = channel or set.channel or "SAY"
    local langIdx = RPProc_LanguageIndex(language or set.language or
        RPProc_Global.language)
    if chan == "WHISPER" and not set.selfCast then
        SendChatMessage(msg, "WHISPER", langIdx, UnitName(u))
    else
        SendChatMessage(msg, chan, langIdx)
    end
end

-- Oeffentlicher Wrapper: faengt Fehler ab, damit RPProc nie mehr STILL
-- stirbt. Kommt es doch zu einem Lua-Fehler, steht die Meldung mit
-- Fehlerursache im Chat, statt dass gar nichts passiert.
function RPProc(setName, chance, forceUnit, channel, language)
    local ok, err = pcall(RPProc_Impl, setName, chance, forceUnit, channel, language)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("RPProc [error]: " .. tostring(err))
    end
end

-- Sprachname ("Zwergisch") in die Sprach-ID des Clients auflösen.
-- WICHTIG (Forever-Client): Sprach-NAMEN sind dort nicht verlaesslich
-- aufloesbar (GetLanguageList fehlt, alte Liste liefert falsche IDs).
-- Empfehlung: language = NUMMER (globale Sprach-ID). Verifizierte/
-- plausible Tabelle (Retail-IDs, 6+7 auf Forever verifiziert):
-- 1 Orkisch, 2 Darnassisch, 3 Taurisch, 6 Zwergisch, 7 Gemeinsprache,
-- 10 Thalassisch, 13 Gnomisch, 14 Zandali, 33 Verlassenen.
-- Gegenpruefen per /rpp langtest <ID>.
-- Ungültige/unbekannte Namen liefern nil = aktuelle Standardsprache.
function RPProc_LanguageIndex(name)
    if type(name) == "number" then return name end -- Sprach-ID direkt
    if not name then return nil end
    -- Stufe 1 (modern): GetLanguageList() liefert {languageID, name}-Tabellen
    if GetLanguageList then
        for _, lang in ipairs(GetLanguageList()) do
            if lang.name == name then return lang.languageID end
        end
    end
    -- Stufe 2 (klassisch): persoenliche Sprachliste (Achtung: IDs evtl.
    -- inkompatibel zu SendChatMessage, siehe Historie)
    if not GetNumLanguages then return nil end
    for i = 1, GetNumLanguages() do
        if GetLanguageByIndex(i) == name then return i end
    end
    if RPProc_Global.debug then
        DEFAULT_CHAT_FRAME:AddMessage("RPProc: Sprache '" .. name ..
            "' nicht gefunden, nutze Standardsprache")
    end
    return nil
end

---------------------------------------------------------------------
-- Slash-Befehle: /rpp <set> [chance] | Steuerung | Editor
---------------------------------------------------------------------

SLASH_RPPROC1 = "/rpp"

-- Hilfsfunktion: ersten Namen (ggf. in Anführungszeichen) vom Rest trennen
local function RPProc_SplitName(args)
    local setName, rest = string.match(args, '^"([^"]+)"%s*(.*)$')
    if not setName then
        setName, rest = string.match(args, '^(%S+)%s*(.*)$')
    end
    return setName, rest or ""
end

local function RPProc_Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("RPProc: " .. text)
end

local function RPProc_ShowSet(setName)
    local set = RPProc_Sets[setName]
    if not set then RPProc_Msg("Set '" .. tostring(setName) .. "' nicht gefunden"); return end
    RPProc_Msg("Set \"" .. setName .. "\": Chance " .. tostring(set.chance or 15) ..
        "% | mode " .. tostring(set.mode or "-") ..
        " | selfCast " .. tostring(set.selfCast or false) ..
        " | channel " .. tostring(set.channel or "SAY") ..
        " | language " .. tostring(set.language or "-"))
    RPProc_Msg("  petRequired=" .. tostring(set.petRequired or false) ..
        " petForbidden=" .. tostring(set.petForbidden or false) ..
        " allowDead=" .. tostring(set.allowDead or false) ..
        " allowSelf=" .. tostring(set.allowSelf == true) ..
        " spell=" .. tostring(set.spell ~= nil and set.spell or "(Setname)"))
    if not set.messages or table.getn(set.messages) == 0 then
        RPProc_Msg("  (keine Sprüche, /rpp addmsg \"" .. setName .. "\" <Text>)")
    else
        for i, m in ipairs(set.messages) do
            RPProc_Msg("  " .. i .. ". " .. m)
        end
    end
end

local function RPProc_ParseValue(val)
    if val == "true" then return true end
    if val == "false" then return false end
    if val == "nil" then return nil end
    local num = tonumber(val)
    if num then return num end
    return val
end

local function RPProc_EditHandler(args)
    -- args: <subcommand> <set> ...  bereits getrimmt
    local sub, rest = string.match(args, '^(%S+)%s*(.*)$')
    sub = string.lower(sub or "")
    -- Bei leerer Eingabe ("/rpp" ohne Argumente) liefert das Muster nil:
    -- Frueh-Ausstieg VOR dem gsub, sonst crasht string.gsub(nil).
    if sub == "" then return false end
    rest = string.gsub(rest or "", "^%s*(.-)%s*$", "%1")

    if sub == "add" then
        local setName = string.match(rest, '^"([^"]+)"$') or (rest ~= "" and rest or nil)
        if not setName or setName == "" then RPProc_Msg('Benutzung: /rpp add "Setname"'); return true end
        if RPProc_Sets[setName] then RPProc_Msg("Set existiert bereits: \"" .. setName .. "\""); return true end
        RPProc_Sets[setName] = { chance = 15, messages = {} }
        RPProc_Msg("Set angelegt: \"" .. setName .. "\" (Chance 15). Sprüche: /rpp addmsg \"" .. setName .. "\" <Text>")
        return true
    end

    if sub == "del" or sub == "delete" then
        local setName = string.match(rest, '^"([^"]+)"$') or rest
        if not RPProc_Sets[setName] then RPProc_Msg("Set nicht gefunden: " .. tostring(setName)); return true end
        RPProc_Sets[setName] = nil
        RPProc_Msg("Set gelöscht: \"" .. setName .. "\" (beim Logout gespeichert)")
        return true
    end

    if sub == "addmsg" then
        local setName, msg = RPProc_SplitName(rest)
        local set = setName and RPProc_Sets[setName]
        if not set then RPProc_Msg('Benutzung: /rpp addmsg "Setname" <Spruchtext mit {name}/{me}>'); return true end
        if msg == "" then RPProc_Msg("Leerer Spruch, nichts hinzugefügt"); return true end
        table.insert(set.messages, msg)
        RPProc_Msg("Spruch hinzugefügt (" .. table.getn(set.messages) .. " Stück): " .. msg)
        return true
    end

    if sub == "delmsg" then
        local setName, idxStr = RPProc_SplitName(rest)
        local set = setName and RPProc_Sets[setName]
        local idx = tonumber(idxStr)
        if not set or not idx then RPProc_Msg('Benutzung: /rpp delmsg "Setname" <Nr.> (Nummern per /rpp show)'); return true end
        if idx < 1 or idx > table.getn(set.messages) then
            RPProc_Msg("Nummer " .. idx .. " gibt es nicht (1 bis " .. table.getn(set.messages) .. ")")
            return true
        end
        RPProc_Msg("Spruch gelöscht: " .. set.messages[idx])
        table.remove(set.messages, idx)
        return true
    end

    if sub == "chance" then
        local setName, numStr = RPProc_SplitName(rest)
        local set = setName and RPProc_Sets[setName]
        local num = tonumber(numStr)
        if not set or not num then RPProc_Msg('Benutzung: /rpp chance "Setname" 0-100'); return true end
        set.chance = num
        RPProc_Msg("Chance für \"" .. setName .. "\": " .. num .. "%")
        return true
    end

    if sub == "opt" then
        local setName, kv = RPProc_SplitName(rest)
        local set = setName and RPProc_Sets[setName]
        local key, val = string.match(kv, '^(%S+)=(.*)$')
        if not set or not key then
            RPProc_Msg('Benutzung: /rpp opt "Setname" key=value | keys: chance mode selfCast channel language petRequired petForbidden allowDead spell')
            return true
        end
        key = string.lower(key)
        local allowed = { chance=true, mode=true, selfcast=true, channel=true,
            language=true, petrequired=true, petforbidden=true, allowdead=true,
            allowself=true, spell=true }
        if not allowed[key] then
            RPProc_Msg("Unbekannter Key: " .. key)
            return true
        end
        -- Kombi-Keys normalisieren (selfcast -> selfCast usw.)
        local fixes = { selfcast="selfCast", petrequired="petRequired",
            petforbidden="petForbidden", allowdead="allowDead", allowself="allowSelf" }
        key = fixes[key] or key
        set[key] = RPProc_ParseValue(val)
        RPProc_Msg(key .. " = " .. tostring(set[key]) .. " für \"" .. setName .. "\"")
        return true
    end

    if sub == "show" then
        -- Anführungszeichen um den Set-Namen entfernen (wie bei den anderen Befehlen)
        local setName = string.match(rest, '^"(.+)"$') or rest
        RPProc_ShowSet(setName)
        return true
    end

    if sub == "reseed" then
        -- Wartungsmodus bis Release: Der Seed in RPProc.lua ist die
        -- Quelle der Wahrheit. Ueberschreibt ALLE Seed-Sets in der DB
        -- (inkl. eigener In-Game-Aenderungen an diesen Sets!); selbst
        -- angelegte Sets bleiben unberuehrt. UI offen? Schliessen + neu
        -- oeffnen, damit die Anzeige die neuen Daten liest.
        local n = 0
        for k, v in pairs(RPProc_Seed) do
            RPProcDB.sets[k] = RPProc_DeepCopy(v)
            n = n + 1
        end
        RPProc_Msg("Seed neu eingespielt: " .. n .. " Sets ueberschrieben. Eigene Sets unangetastet.")
        return true
    end

    if sub == "ui" or sub == "editor" then
        if RPProcUI_Toggle then
            RPProcUI_Toggle()
        else
            RPProc_Msg("UI nicht geladen: RPProcUI.lua fehlt oder ist in der .toc nicht eingetragen")
        end
        return true
    end

    if sub == "cooldown" then
        local num = tonumber(rest)
        if not num then RPProc_Msg("Benutzung: /rpp cooldown <Sekunden> (0 = aus), aktuell " .. tostring(RPProc_Global.cooldown)); return true end
        RPProc_Global.cooldown = num
        RPProc_Msg("Globaler Cooldown: " .. num .. "s")
        return true
    end

    if sub == "globalchance" then
        local num = tonumber(rest)
        if not num then RPProc_Msg("Benutzung: /rpp globalchance 0-100, aktuell " .. tostring(RPProc_Global.globalChance)); return true end
        RPProc_Global.globalChance = num
        RPProc_Msg("Globale Chance: " .. num .. "%")
        return true
    end

    if sub == "langtest" then
        -- Sprach-Discovery fuer den Forever-Client: Sprach-NAMEN sind dort
        -- nicht zuverlaessig aufloesbar, nur nummerische IDs zaehlen.
        -- Das sendet eine SAY-Nachricht in der gewuenschten ID; im Chat
        -- steht die Sprache als [Tag] -> alle IDs in einer Minute testen.
        local id = tonumber(rest)
        if not id then
            RPProc_Msg('Benutzung: /rpp langtest <Sprach-ID> (sendet eine SAY-Nachricht in dieser Sprache)')
            return true
        end
        local ok, err = pcall(SendChatMessage, "Sprachtest, ID " .. id .. "!", "SAY", id)
        if ok then
            RPProc_Msg("Sprachtest gesendet (ID " .. id .. "): Chat-Ausgabe beachten, dort steht der Sprach-Tag.")
        else
            RPProc_Msg("Sprach-ID " .. id .. " abgelehnt: " .. tostring(err))
        end
        return true
    end

    if sub == "help" then
        RPProc_Msg("Editor: /rpp ui | reseed | langtest | add/del/addmsg/delmsg/chance/opt/show + cooldown/globalchance | Test: /rpp <Set> [Chance] | siehe Dateikopf")
        return true
    end

    return false -- kein Editor-Befehl, Standard-Verarbeitung laeuft weiter
end

local function SlashHandler(args)
    args = string.gsub(args, "^%s*(.-)%s*$", "%1")
    -- Hinten stehende Zahl = Chance, der Rest (mit Leerzeichen) = Set-Name
    local chanceNum = tonumber(string.match(args, "(%d+)%s*$"))
    local name = string.gsub(args, "%s+%d+%s*$", "")
    if name == "langs" then
        RPProc_Msg("Verfügbare Sprachen:")
        if GetNumLanguages then
            for i = 1, GetNumLanguages() do
                DEFAULT_CHAT_FRAME:AddMessage("  " .. GetLanguageByIndex(i))
            end
        end
        RPProc_Msg("Forever: Sprach-IDs als Zahl verwenden (6 = Zwergisch laut Recherche)")
        return
    end
    if name == "on" or name == "off" or name == "toggle" then
        if name == "toggle" then
            RPProc_Global.enabled = not RPProc_Global.enabled
        else
            RPProc_Global.enabled = (name == "on")
        end
        RPProc_Msg((RPProc_Global.enabled and "AKTIV" or "AUS") ..
            " (Sprüche " .. (RPProc_Global.enabled and "proccen" or "unterdrückt") .. ")")
        return
    end
    if name == "debug" or name == "debug on" or name == "debug off" or name == "debug toggle" then
        if name == "debug" or name == "debug toggle" then
            RPProc_Global.debug = not RPProc_Global.debug
        else
            RPProc_Global.debug = (name == "debug on")
        end
        RPProc_Msg("Debug " .. (RPProc_Global.debug and "AN" or "AUS") ..
            " (Diagnose-Meldungen " .. (RPProc_Global.debug and "sichtbar" or "unterdrückt") .. ")")
        return
    end
    -- Editor-Befehle (add, addmsg, del, delmsg, chance, opt, show,
    -- cooldown, globalchance, help)
    if RPProc_EditHandler(args) then return end
    if name ~= "" and RPProc_Sets[name] then
        RPProc(name, chanceNum)
        return
    end
    RPProc_Msg("Sets (gespeichert in SavedVariables):")
    local keys = {}
    for k in pairs(RPProc_Sets) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local set = RPProc_Sets[k]
        DEFAULT_CHAT_FRAME:AddMessage("  " .. k ..
            " (Chance " .. tostring(set.chance or 15) .. "%, " ..
            tostring(set.messages and table.getn(set.messages) or 0) .. " Sprüche" ..
            ", Channel " .. (set.channel or "SAY") .. ")")
    end
    RPProc_Msg("Benutzung: /rpp <set name> [chance] | Editor: /rpp help")
end
SlashCmdList["RPPROC"] = SlashHandler

-- Zusaetzlicher Slash-Befehl /RPProc("Setname") bzw. /RPProc("Setname", 50):
-- erlaubt den Aufruf direkt als Makro-Zeile OHNE /run davor, im Stil
--   /wirken Sturmangriff
--   /RPProc("Sturmangriff")
SLASH_RPPROCDIRECT1 = "/RPProc"
SlashCmdList["RPPROCDIRECT"] = function(args)
    -- Eingabe normalisieren: fuehrendes RPProc( und schliessende ) entfernen
    args = string.gsub(args, "^%s*RPProc%s*%(", "")
    args = string.gsub(args, "%)%s*$", "")
    -- Variante: "Name" [, Zahl]  oder  Name [, Zahl]
    local setName, chanceNum = string.match(args, '^%s*"(.-)"%s*,?%s*(%d*)%s*$')
    if not setName then
        setName, chanceNum = string.match(args, '^%s*([^,%s]+)%s*,?%s*(%d*)%s*$')
    end
    if setName and setName ~= "" then
        RPProc(setName, tonumber(chanceNum))
    else
        RPProc_Msg('Benutzung: /RPProc("Setname") oder /run RPProc("Setname")')
    end
end
