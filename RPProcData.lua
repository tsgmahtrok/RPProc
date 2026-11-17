--[[=========================================================================
    RPProcData - Seed-Sets fuer RPProc (NUR Daten, keine Logik)
    ---------------------------------------------------------------------------
    Diese Datei enthaelt ausschliesslich die Seed-Tabelle als globale
    Variable RPProc_SeedData. Sie wird in der .toc VOR RPProc.lua
    geladen; die Engine uebernimmt die Sets beim allerersten Start in
    die SavedVariables (RPProcDB) und per /rpp reseed auf Wunsch neu.
    Ab dem ersten Start gilt die Datenbank, Aenderungen an dieser Datei
    wirken nur noch ueber /rpp reseed.

    Format pro Set:
      ["Skillname"] = {
          cat = "Kategorie",          -- General, Jäger, Krieger, Paladin...
          chance = 25,                -- Proc-Chance in %
          selfCast = true,            -- Spruch gilt dir selbst
          mode = "enemy",             -- optional: friend/enemy-Zielfilter
          petRequired = true,          -- optional: nur mit aktiven Pet
          allowDead = true,           -- optional: Ziel darf tot sein
          messages = { "Spruch mit {name}", ... },
      },
    Platzhalter: {name} = Zielname, {me} = dein Name.
=========================================================================]]--

RPProc_DataVersion = "2026-11-16" -- /run print(RPProc_DataVersion) zum Pruefen

RPProc_SeedData = {
    -- << General >>
    ["Mineraliensuche"] = {
        cat = "General",
        chance = 30,
        selfCast = true,
        messages = {
            "Ich glaube, ..ich rieche Erz!",
            "Ich spüre, Erz..",
        },
    },
    ["Steingestalt"] = {
        cat = "General",
        chance = 30,
        selfCast = true,
        messages = {
            "Hart wie Stein!",
            "Fels und Stein!",
            "Kraft der Ahnen!",
            "Kraft der Irdenen!",
            "Ich bin hart wie Stein!",
            "Ich bin ein Kind der Irdenen!",
            "An mir beißt du dir die Zähne aus!",
        },
    },
    ["Schatzsucher"] = {
        cat = "General",
        chance = 30,
        selfCast = true,
        messages = {
            "Wo verstecken sich die Schätze?",
            "Ich glaube, ich rieche Reichtum..",
        },
    },

    -- << Druide >>
    -- << Hexenmeister >>
    -- << Jäger >>
    ["Arkaner Schuss"] = {
        cat = "Jäger",
        chance = 5,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Ruhig halten.",
            "Blattschuß.",
            "Volle Ladung.",
            "Diese Kugel ist speziell für dich, {name}.",
            "Diese Kugel trägt den Namen {name}.",
            "Zwischen die Augen.",
        },
    },
    ["Erschütternder Schuss"] = {
        cat = "Jäger",
        chance = 5,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Immer langsam, {name}.",
            "Nich' so schnell, {name}.",
            "Oy, mach langsam, {name}.",
        },
    },
    ["Aspekt des Affen"] = {
        cat = "Jäger",
        chance = 30,
        selfCast = true,
        messages = {
            "Vorsicht ist geboten.",
            "Ich bin bereit.",
            "Gewandt wie ein Affe.",
            "Flink wie der Affe.",
        },
    },
    ["Aspekt des Falken"] = {
        cat = "Jäger",
        chance = 30,
        selfCast = true,
        messages = {
            "Ich habe die Augen eines Falken.",
            "Konzentration..",
            "Wie ein Falke.",
        },
    },
    ["Aspekt des Geparden"] = {
        cat = "Jäger",
        chance = 30,
        selfCast = true,
        messages = {
            "Flinke Füße!",
            "Der Weg ist weit.",
            "Ich eile.",
            "Wie der Gepard.",
        },
    },
    ["Mal des Jägers"] = {
        cat = "Jäger",
        chance = 15,
        selfCast = false,
        mode = "enemy",
        petRequired = true, -- "Fass!" nur, wenn das Pet wirklich zuschlagen kann
        messages = {
            "Fass!",
            "Schnapp dir {name}!",
            "Beiss!",
            "Und los!",
            "Hol dir {name}!",
            "Auf geht's!",
            "Geh', spiel mit {name}!",
        },
    },
    ["Raptorstoß"] = {
        cat = "Jäger",
        chance = 5,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Von dir hol' ich mir'n Stück, {name}.",
            "Spür' die Klinge, {name}.",
            "Spür' meine Klinge, {name}.",
            "Zwischen die Rippen geht am schnellsten.",
            "Aus dir mach ich gehacktes, {name}.",
        },
    },
    ["Tier freigeben"] = {
        cat = "Jäger",
        chance = 90,
        petRequired = true, -- "Fass!" nur, wenn das Pet wirklich zuschlagen kann
        messages = {
            "Auf deinen Platz.",
            "Bis gleich.",
            "Du hast jetzt eine Runde freizeit.",
        },
    },
    ["Tier füttern"] = {
        cat = "Jäger",
        chance = 30,
        petRequired = true, -- "Fass!" nur, wenn das Pet wirklich zuschlagen kann
        messages = {
            "Hier, eine Kleinigkeit für dich..",
            "Wer ist ein Feiner? Hier, für dich..",
            "Gut gemacht! Hier hast du was..",
        },
    },
    ["Tier rufen"] = {
        cat = "Jäger",
        chance = 90,
        selfCast = true,
        petRequired = true, -- "Fass!" nur, wenn das Pet wirklich zuschlagen kann
        messages = {
            "Hiiieer her!",
            "Bei Fuß!",
        },
    },
    ["Tier wiederbeleben"] = {
        cat = "Jäger",
        chance = 90,
        petRequired = false, -- "Fass!" nur, wenn das Pet wirklich zuschlagen kann
        messages = {
            "Bin schon da, ich hab dich.",
            "Wird gleich besser.",
            "Lass mich mal sehen, wird gleich besser.",
            "Ich kümmer' mich um dich.",
            "Das haben wir gleich, bleib ruhig.",
        },
    },
    ["Wildtiere aufspüren"] = {
        cat = "Jäger",
        chance = 30,
        selfCast = true,
        messages = {
            "Der Duft der Wildnis.",
            "Ich spüre, wir sind nicht allein.",
            "Die Spuren von wilden Kreaturen..",
            "Ich spüre etwas wildes in der Nähe..",
        },
    },
    ["Wildtier zähmen"] = {
        cat = "Jäger",
        chance = 90,
        petRequired = false, -- "Fass!" nur, wenn das Pet wirklich zuschlagen kann
        messages = {
            "Ruhig, {name}.",
            "Brav, {name}.",
        },
    },

    -- << Krieger >>
    ["Blutrausch"] = {
        cat = "Krieger",
        chance = 10,
        selfCast = true,
        messages = {
            "Aargh!",
            "Graah!",
            "Für Grim Batol!",
        },
    },
    ["Demoralisierungsruf"] = {
        cat = "Krieger",
        chance = 15,
        selfCast = true,
        messages = {
            "Ist das schon alles?!",
            "Für Khaz Modan!",
            "Fels und Stein!",
            "Kein Zoll breit zurück!",
            "Ich werde nicht weichen!",
            "Kraft und Ehre!",
            "Je kürzer die Beine, desto größer die Wut!",
        },
    },
    ["Donnerknall"] = {
        cat = "Krieger",
        chance = 10,
        selfCast = true,
        messages = {
            "Jetzt knallt's!",
            "Fels und Stein!",
            "Na los, tanzen wir!",
        },
    },
    ["Entwaffnen"] = {
        cat = "Krieger",
        chance = 25,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Au! Gib mir das!",
            "Uh schick, kann ich ma' seh'n?",
            "Gib das her, du verletzt noch jemand!",
            "Zeig' ma' her, was hast du denn da, {name}?",
        },
    },
    ["Gegenschlag"] = {
        cat = "Krieger",
        chance = 90,
        selfCast = true,
        messages = {
            "Kommt nur her!",
            "Ich nehm's mit euch allen auf!",
            "Ein Zwerg ist genug für euch!",
        },
    },
    ["Heldenhafter Stoß"] = {
        cat = "Krieger",
        chance = 10,
        selfCast = false,
        messages = {
            "Nimm das, {name}!",
            "Ich halbier' dich, {name}!",
            "Fels und Stein!",
            "Dir zeig' ich's, {name}!",
            "Je'n heldenhafteren Stoß gesehen als den hier, {name}?",
        },
    },
    ["Rache"] = {
        cat = "Krieger",
        chance = 25,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Hah!",
            "Ney!",
            "Hahah!",
            "Hast'e g'dacht!",
            "Hoo ya!",
            "Versuch's nochmal!",
            "So nich'!",
            "Kopfnuss!",
        },
    },
    ["Kniesehne"] = {
        cat = "Krieger",
        chance = 10,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Nich' so schnell, {name}!",
            "Auf die Sehne!",
            "Schnipp Schnapp, Sehne ab!",
            "Immer langsam, {name}!",
        },
    },
    ["Schildhieb"] = {
        cat = "Krieger",
        chance = 25,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Hier wird nich' gezaubert!",
            "Halt den Mund!",
            "Ich Zauber dir gleich'n Ring um die Aug'n!",
            "Klappe zu!",
            "Ausgefuchtelt!",
            "Ausgezaubert!",
            "Ah, ah, ah!",
            "Friss mein' Schild!",
            "Haste g'dacht!",
            "Still!",
            "Bist du Still!",
            "Ney, so nich!",
            "Wirst du wohl!",
        },
    },
    ["Schildschlag"] = {
        cat = "Krieger",
        chance = 25,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Friss mein' Schild!",
            "Friss das!",
            "Nimm das!",
            "Auf die Zwölf!",
            "Voll reingelauf'n!",
            "Voll aufs Maul!",
            "Das gibt Kopfweh!",
            "Das gibt 'ne Beule!",
        },
    },
    ["Schildwall"] = {
        cat = "Krieger",
        chance = 90,
        selfCast = true,
        messages = {
            "Ich werde nich' wanken!",
            "Ich werde nich' straucheln!",
            "Bis hier hin, un' nich' weiter!",
            "An mir kommst du nich' vorbei!",
            "Khaz Modan und Grim Batol!",
            "Stahl und Stein!",
            "Wie Fels und Stein!",
            "Heute ist nich' der Tag!",
            "Ich bin die Wand, an der du zerschellst!",
        },
    },
    ["Schlachtruf"] = {
        cat = "Krieger",
        chance = 15,
        selfCast = true,
        messages = {
            "Grim Batol!",
            "Für Grim Batol!",
            "Wildhammer!",
            "Für Falstad und die Aerie!",
            "Fels und Stein!",
            "Für die Allianz!",
            "Grim Batol und Khaz Modan!",
            "Für Falstad und die Garde!",
        },
    },
    ["Siegesrausch"] = {
        cat = "Krieger",
        chance = 15,
        selfCast = true,
        messages = {
			"Was hab'n wir denn hier?",
            "Nun zu dir, {name}!",
            "Und nun zu uns, {name}!",
            "Weiter geht's!",
        },
    },
    ["Spalten"] = {
        cat = "Krieger",
        chance = 15,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Hahaa!",
        },
    },
    ["Spott"] = {
        cat = "Krieger",
        chance = 15,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Oink Oink!",
            "Ey, {name}!",
            "Kommst du her!",
            "Willst du wohl?!",
            "Schau mich an, {name}!",
            "Dein Kopf, auf 'nem Spieß, {name}!",
            "Kopfnuss gefällig?",
            "Von dir will ich'n Stück, {name}!",
            "Du willst'n Stück von mir?!",
            "Wer hat noch nich', wer will nochma!",
        },
    },
    ["Sturmangriff"] = {
        cat = "Krieger",
        chance = 20,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Zwerg is da!",
            "Stüüürmt!",
            "Sturmangrifff!",
            "Die ersten 10 gehör'n mir!",
            "Aus der Baaahn!",
            "Baaaahn frei!",
            "Hier kommt Zwerg!",
            "Aaangriff!",
            "Attackeee!",
            "Für die Wildhammer!",
            "Für Falstad!",
            "Für Khaz Modan!",
            "Flinke Füße!",
        },
    },
    ["Verwunden"] = {
        cat = "Krieger",
        chance = 10,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Oy, verteil' deine Organe nich' überall!",
            "Oy, spritz hier nich' alles voll Eingeweide!",
            "Lass' ma seh'n, Leber, Niere, Galle, alles da.",
            "Oy, alles auf die neuen Stiefel!",
            "Ich hack' dich in Stücke!",
            "Oy! Blut' mir nich' die Stiefel voll!",
            "Ich Schlitz dich auf, {name}!",
            "Heut' gibt's gehacktes, du bist eingelad'n, {name}!",
        },
    },
    ["Zerschmettern"] = {
        cat = "Krieger",
        chance = 10,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Stirb!",
        },
    },
    ["Überwältigen"] = {
        cat = "Krieger",
        chance = 10,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Hoo!",
            "Zack!",
            "Erwischt!",
            "Zu langsam!",
            "Auf die Zwölf!",
            "Ich spalt' dir den Schädel!",
        },
    },

    -- << Magier >>

    -- << Paladin >>
    ["Göttlicher Schutz"] = {
        cat = "Paladin",
        chance = 90,
        selfCast = true,
        messages = {
            "Schutz des Lichts!",
            "Licht, schütze mich!",
            "Licht, schütze deinen Diener!",
            "Licht! Spende mir deinen Schutz!",
            "Der Schutz des Lichts!",
        },
    },
    ["Heiliges Licht"] = {
        cat = "Paladin",
        chance = 15,
        selfCast = false,
        mode = "friend",
        messages = {
            "Das Licht bringt Heilung, {name}.",
            "Licht heile, {name}.",
            "Gleich fühlst du dich besser, {name}.",
            "Wird gleich besser, {name}.",
            "Halte durch, {name}, die Gebete sind mit dir.",
            "Licht!",
            "Licht, gib mir Kraft!",
        },
    },
    ["Richturteil"] = {
        cat = "Paladin",
        chance = 15,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Spüre das Licht, {name}!",
            "Im Namen des Lichts!",
            "Das Licht strafe dich, {name}!",
        },
    },
    ["Segen der Macht"] = {
        cat = "Paladin",
        chance = 35,
        selfCast = false,
        mode = "friend",
        messages = {
            "Ich segne dich, {name}, mit der Macht des Lichts!",
            "Der Segen der Macht, {name}.",
            "Licht, gib {name} die Macht.",
            "Licht, segne {name} mit deiner Macht.",
            "Segne {name} mit der Macht des Lichts.",
            "Das Licht gebe dir Macht, {name}.",
        },
    },
    ["Segen der Weisheit"] = {
        cat = "Paladin",
        chance = 35,
        selfCast = false,
        mode = "friend",
        messages = {
            "Ich segne dich, {name}, mit der Weisheit des Lichts.",
            "{name}, empfange den Segen der Weisheit.",
            "Der Segen der Weisheit, {name}.",
            "Licht, gib {name} die Weisheit.",
            "Segne {name} mit der Weisheit des Lichts.",
            "Licht segne {name} mit Weisheit.",
            "Das Licht gebe dir Weisheit, {name}.",
            "Das Licht schenke dir Weisheit, {name}.",
        },
    },
    ["Segen der Könige"] = {
        cat = "Paladin",
        chance = 35,
        selfCast = false,
        mode = "friend",
        messages = {
            "Ich segne dich, {name}, mit der Kraft die nur Königen zu teil wird.",
            "Licht segne {name} mit der Kraft der Könige.",
            "Das Licht gebe dir die Kraft der Könige, {name}.",
            "Das Licht schenke dir die Kraft der Könige, {name}.",
            "Empfange die Kraft der Könige, {name}.",
        },
    },
    ["Segen der Rettung"] = {
        cat = "Paladin",
        chance = 35,
        selfCast = false,
        mode = "friend",
        messages = {
            "Ich segne dich, {name}, das Licht möge dich retten.",
            "Licht segne {name} und errette seine Seele.",
            "Das Licht errette dich, {name}.",
            "Empfange Rettung, {name}, durch die Kraft des Lichts.",
        },
    },
    ["Siegel des Kreuzfahrers"] = {
        cat = "Paladin",
        chance = 15,
        selfCast = true,
        messages = {
            "Das Licht ist mit mir!",
            "Licht gib mir Kraft!",
            "Licht, Stärke deinen Diener!",
        },
    },
    ["Siegel der Rechtschaffenheit"] = {
        cat = "Paladin",
        chance = 15,
        selfCast = true,
        messages = {
            "Licht, erleuchte meinen Weg!",
            "Licht, leite meine Hand!",
            "Licht, leite meinen Pfad!",
            "Für das Licht!",
        },
    },

    -- << Priester >>
    ["Auferstehung"] = {
        cat = "Priester",
        chance = 60,
        selfCast = false,
        mode = "friend",
        allowDead = true,
        messages = {
            "Geh noch nicht ins Licht, {name}.",
            "Das Licht möge deine Seele erneuern, {name}.",
            "Licht, vertreibe den Schatten und rette {name}.",
            "Nicht so schnell {name}, du bist mit diesem Leben noch nicht fertig.",
        },
    },
    ["Erneuerung"] = {
        cat = "Priester",
        chance = 25,
        selfCast = false,
        mode = "friend",
        messages = {
            "Das könnte etwas kitzeln, {name}.",
            "Das Licht bringt neue Kraft, {name}.",
            "Licht, erneuere {name}'s Kräfte.",
        },
    },
    ["Geringes Heilen"] = {
        cat = "Priester",
        chance = 15,
        selfCast = false,
        mode = "friend",
        messages = {
            "Das Licht bringt Heilung, {name}.",
            "Licht heile, {name}.",
            "Gleich fühlst du dich besser, {name}.",
            "Wird gleich besser, {name}.",
            "Halte durch, {name}, die Gebete sind mit dir.",
            "Licht!",
            "Licht, gib mir Kraft!",
        },
    },
    ["Großes Heilen"] = {
        cat = "Priester",
        chance = 15,
        selfCast = false,
        mode = "friend",
        messages = {
            "Das Licht bringt Heilung, {name}.",
            "Licht heile, {name}.",
            "Wird gleich besser, {name}.",
            "Halte durch, {name}, die Gebete sind mit dir.",
            "Licht!",
            "Licht, gib mir Kraft!",
        },
    },
    ["Göttliche Pein"] = {
        cat = "Priester",
        chance = 15,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Spüre den Zorn des Lichts, {name}!",
            "Das Licht strafe dich, {name}!",
        },
    },
    ["Heilen"] = {
        cat = "Priester",
        chance = 15,
        selfCast = false,
        mode = "friend",
        messages = {
            "Das Licht bringt Heilung, {name}.",
            "Licht heile, {name}.",
            "Gleich fühlst du dich besser, {name}.",
            "Wird gleich besser, {name}.",
            "Halte durch, {name}, die Gebete sind mit dir.",
            "Licht!",
            "Licht, gib mir Kraft!",
        },
    },
    ["Inneres Feuer"] = {
        cat = "Priester",
        chance = 60,
        selfCast = true,
        messages = {
            "Das Licht in mir!",
            "Licht gib mir Kraft!",
        },
    },
    ["Machtwort: Schild"] = {
        cat = "Priester",
        chance = 25,
        selfCast = false,
        mode = "friend",
        messages = {
            "Das Licht sei dein Schild, {name}.",
            "Das Licht beschützt, {name}.",
        },
    },
    ["Machtwort: Seelenstärke"] = {
        cat = "Priester",
        chance = 60,
        selfCast = false,
        mode = "friend",
        messages = {
            "Wandel im Segen des Lichts, {name}.",
            "Licht, segne {name}.",
            "Möge das Licht dich begleiten, {name}.",
            "Ein Segen für dich, {name}.",
            "Möge das Licht deine Pfade erleuchten, {name}.",
            "Das Licht gibt dir Kraft, {name}.",
        },
    },
    ["Schattenwort: Schmerz"] = {
        cat = "Priester",
        chance = 15,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Dein Wort sei 'Schmerz'",
            "Der Schatten bringt 'Schmerz'",
            "Sprich das Wort und es sei 'Schmerz'",
            "Deine Strafe sei 'Schmerz', {name}.",
            "Wo kein Licht, das ist nur 'Schmerz'!",
        },
    },

    -- << Schamane >>
    ["Blitzschlagschild"] = {
        cat = "Schamane",
        chance = 35,
        selfCast = true,
        messages = {
            "Ich bin der Sturm!",
            "Elektrifiziert!",
            "Die Spannung steigt!",
            "Hier kommt das Kribbeln!",
        },
    },
    ["Erdschock"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "enemy",
        messages = {
            "Friss Dreck, {name}.",
            "Friss Staub, {name}.",
            "Geister der Erde!",
            "Ich hab' 'ne Hand voll Dreheck!",
            "Ihr Geister der Erde!",
            "Fels und Stein, {name}.",
            "Gestein und Staub, alles für dich, {name}!",
            "Schonmal Dreck im Auge gehabt? Nein? Hier!",
        },
    },
    ["Flammenschock"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "enemy",
        messages = {
            "{name} zu Asche!",
            "Ihr Geister der Flamme!",
            "Ihr Geister des Feuers!",
            "Zu heiss für dich, {name}!",
            "Verbrenn dich nich', {name}!",
            "Heut' gibt's gerösteten {name}.",
            "Heut' gibt's flammbierten {name}.",
            "Du spielst mit dem Feuer, {name}!",
        },
    },
    ["Frostschock"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "enemy",
        messages = {
            "{name}, schockgefrostet!",
            "Jetzt wird's eisig!",
            "Eiskalt!",
            "Eis, Eis, {name}!",
            "Zu kalt für dich, {name}?!",
            "Unterkühl' dich nich, {name}!",
            "Heut' gibt's {name}, tiefgekühlt!",
        },
    },
    ["Geisterwolf"] = {
        cat = "Schamane",
        chance = 60,
        selfCast = true,
        messages = {
            "Ihr Ahnen, schenkt mir die Kraft des Wolfes!",
            "Kraft des Wolfes!",
            "Ich habe die Kraft des Wolfes!",
            "Ich rufe dich, mein innerer Schweine..wolf!",
            "Ich mach mich auf die Pfoten!",
        },
    },
    ["Geist der Ahnen"] = {
        cat = "Schamane",
        chance = 60,
        selfCast = false,
        mode = "friend",
        allowDead = true,
        messages = {
            "Die Geister rufen dich noch nicht, {name}!",
            "Die Ahnen haben noch Aufgaben für dich, {name}.",
            "Kehre zurück, {name}, deine Reise ist nicht zu Ende.",
            "Nicht so schnell, {name}, die Ahnen entscheiden, wann du gehst.",
            "Der Fluss deines Lebens fließt noch, {name}.",
            "Ihr Ahnen, schenkt {name} neues Leben!"
        },
    },
    ["Geringe Welle der Heilung"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "friend",
        messages = {
            "Ihr Geister, spendet {name} Linderung!",
            "Geister des Wassers, heilt {name}.",
            "Wird gleich besser, {name}.",
            "Gleich fühlst du dich besser, {name}.",
            "Lass das Wasser wirken, {name}.",
        },
    },
    ["Krankheit heilen"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "friend",
        messages = {
            "Für diese Krankheit hab' ich'n Mittel, {name}.",
            "Zeig mal her, das haben wir gleich kuriert, {name}.",
            "Ihr Geister, erlöst {name} von dieser Krankheit.",
            "Ihr Geister, nehmt die Krankheit von {name}.",
        },
    },
    ["Ruf der Elemente"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "friend",
        messages = {
            "Ihr Geister, hört mein Gebet!",
            "Ihr Elemente, hört mein Gebet!",
            "Ihr Geister, ich brauche eure Kraft!",
            "Ihr Elemente und Geister, hört meinen Ruf!",
        },
    },
    ["Welle der Heilung"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "friend",
        messages = {
            "Neue Kraft fliesst in deinen Körper, {name}.",
            "Geister des Wassers, heilt {name}.",
            "Werde eins mit dem Fluss, {name}.",
            "Die Geister heilen dich, {name}.",
            "Halte durch, {name}, die Geister walten.",
            "Spüre den Fluss des Wassers, {name}.",
            "Die Wasser des Lebens fließen für dich, {name}.",
            "Lass das Wasser wirken, {name}.",
            "Spüre die heilende Kraft des Wassers, {name}.",
        },
    },
    ["Vergiftung heilen"] = {
        cat = "Schamane",
        chance = 10,
        selfCast = false,
        mode = "friend",
        messages = {
            "Für dieses Gift kenn' ich'n Gegenmittel, {name}.",
            "Zeig mal her, das haben wir gleich, {name}.",
            "Garstiges Gift, {name}, ich kümmer' mich.",
            "Ihr Geister, nehmt das Gift von {name}.",
            "Ihr Geister, erlöst {name} von diesem Gift.",
        },
    },

    -- << Schurke >>
    -- << Todesritter >>
}
