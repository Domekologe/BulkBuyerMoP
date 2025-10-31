-- locales/de.lua
local L = LibStub("AceLocale-3.0"):NewLocale("BulkBuyerMoP", "deDE")
if not L then return end

-- UI labels
L.TITLE                = "BulkBuyer"
L.AMOUNT               = "Menge"
L.AMOUNT_ITEMS         = "Menge (Stücke)"
L.AMOUNT_BUNDLES       = "Menge (Bündel)"
L.AMOUNT_RANGE         = "Menge (%d–%d)"
L.AMOUNT_RANGE_BUNDLES = "Bündel (%d–%d)"
L.OK                   = "OK"
L.CURRENCY             = "Währung"
L.NO_COST              = "Kein Preis"
L.ITEM_LABEL           = "Item"
L.COST_PER_CLICK       = "Kosten pro Klick"
L.BUNDLE_HINT          = "Bundle-Hinweis"
L.CURRENT_TOTAL        = "Aktuelle Gesamtkosten"
L.UNITWORD_BUNDLES     = "Bündel"
L.UNITWORD_ITEMS       = "Stück"

-- Dialog headers
L.DIALOG_HEADER        = "Wieviel gesamt?"
L.DIALOG_HEADER_HINT   = "Wieviel gesamt?\nItem: %s\nKosten pro Klick: %s\n(Bundle-Hinweis: %d)"
L.DIALOG_HEADER_ENFORCED = "Wieviele Bündel?\nItem: %s\nKosten pro Klick: %s\n(Bundle zwingend: %d)"

-- Chat messages
L.STOPPED              = "%s: abgebrochen (%s). Fortschritt: %d/%d %s"
L.DONE_STACK           = "%d Bündel × %d = %d Stück von %s gekauft."
L.DONE_PIECES          = "%d Stück von %s gekauft."
L.TOTAL_COST           = "Gesamtkosten: %s"
L.REASON_MERCHANT_CLOSED  = "Händler geschlossen"
L.REASON_SOLD_OUT          = "ausverkauft"
L.REASON_NOTHING_TO_BUY    = "nichts mehr zu kaufen"
L.REASON_NOT_ENOUGH_GOLD   = "zu wenig Gold/Währung"
L.REASON_BAG_ERROR         = "Taschenfehler"
L.REASON_NEW_PURCHASE      = "Neuer Kauf gestartet"
L.INVALID_ITEM             = "Ungültiges Item"
L.NOTHING_TO_BUY_ZERO      = "Nichts zu kaufen (0)."
L.PLAN_PIECES			 = "Plane den Kauf von %d Stück für %s."
L.PLAN_STACK  			 = "Plane den Kauf von %d Bündeln à %d = %d Stück für %s."


-- Slash lines
L.SLASH_LINE1          = "ALT-Klick auf Händlerware, um die Menge zu wählen. SHIFT-Klick = Blizzard-Standard."
L.SLASH_LINE2          = "/bulkbuyer round up|nearest|down; /bulkbuyer chunk stack|fixed [n]; /bulkbuyer verbose on|off; /bulkbuyer slidercap <N>"
L.ROUND_SET            = "Rundung gesetzt auf: %s"
L.ROUND_BAD            = "Verwendung: /bulkbuyer round up|nearest|down"
L.CHUNK_FIXED_SET      = "Chunk-Modus fix; Einheiten pro Tick: %d"
L.CHUNK_FIXED_HINT     = "Verwendung: /bulkbuyer chunk fixed <1..200>"
L.CHUNK_STACK_SET      = "Chunk-Modus stapelbasiert."
L.CHUNK_USAGE          = "Verwendung: /bulkbuyer chunk stack|fixed [n]"
L.VERBOSE_ON           = "Verbose an."
L.VERBOSE_OFF          = "Verbose aus."

-- Money
L.GOLD_SHORT   = "g"
L.SILVER_SHORT = "s"
L.COPPER_SHORT = "k"
