-- locales/en.lua
local L = LibStub("AceLocale-3.0"):NewLocale("BulkBuyerMoP", "enUS", true)

-- UI labels
L.TITLE                = "BulkBuyer"
L.AMOUNT               = "Amount"
L.AMOUNT_ITEMS         = "Amount (items)"
L.AMOUNT_BUNDLES       = "Amount (bundles)"
L.AMOUNT_RANGE         = "Amount (%d–%d)"
L.AMOUNT_RANGE_BUNDLES = "Bundles (%d–%d)"
L.OK                   = "OK"
L.CURRENCY             = "Currency"
L.NO_COST              = "No cost"
L.ITEM_LABEL           = "Item"
L.COST_PER_CLICK       = "Cost per click"
L.BUNDLE_HINT          = "Bundle size hint"
L.CURRENT_TOTAL        = "Current total"
L.UNITWORD_BUNDLES     = "bundles"
L.UNITWORD_ITEMS       = "items"

-- Dialog headers
L.DIALOG_HEADER        = "How many in total?"
L.DIALOG_HEADER_HINT   = "How many in total?\nItem: %s\nCost per click: %s\n(Bundle size hint: %d)"
L.DIALOG_HEADER_ENFORCED = "How many bundles?\nItem: %s\nCost per click: %s\n(Bundle size enforced: %d)"

-- Chat messages
L.STOPPED              = "%s: stopped (%s). Progress: %d/%d %s"
L.DONE_STACK           = "Bought %d bundles × %d = %d items of %s."
L.DONE_PIECES          = "Bought %d items of %s."
L.TOTAL_COST           = "Total cost: %s"
L.REASON_MERCHANT_CLOSED  = "merchant closed"
L.REASON_SOLD_OUT          = "sold out"
L.REASON_NOTHING_TO_BUY    = "nothing left to buy"
L.REASON_NOT_ENOUGH_GOLD   = "not enough gold/currency"
L.REASON_BAG_ERROR         = "bag error"
L.REASON_NEW_PURCHASE      = "new purchase started"
L.INVALID_ITEM             = "Invalid item"
L.NOTHING_TO_BUY_ZERO      = "Nothing to buy (0)."
L.PLAN_PIECES			 = "Planning to buy %d items for %s."
L.PLAN_STACK  			 = "Planning to buy %d bundles of %d each = %d items for %s."


-- Slash lines
L.SLASH_LINE1          = "ALT-click a merchant item to choose amount. SHIFT-click = Blizzard default."
L.SLASH_LINE2          = "/bulkbuyer round up|nearest|down; /bulkbuyer chunk stack|fixed [n]; /bulkbuyer verbose on|off; /bulkbuyer slidercap <N>"
L.ROUND_SET            = "Rounding set to: %s"
L.ROUND_BAD            = "Use: /bulkbuyer round up|nearest|down"
L.CHUNK_FIXED_SET      = "Chunk mode fixed; units per tick: %d"
L.CHUNK_FIXED_HINT     = "Use: /bulkbuyer chunk fixed <1..200>"
L.CHUNK_STACK_SET      = "Chunk mode stack-based."
L.CHUNK_USAGE          = "Use: /bulkbuyer chunk stack|fixed [n]"
L.VERBOSE_ON           = "Verbose on."
L.VERBOSE_OFF          = "Verbose off."

-- Money
L.GOLD_SHORT   = "g"
L.SILVER_SHORT = "s"
L.COPPER_SHORT = "c"
