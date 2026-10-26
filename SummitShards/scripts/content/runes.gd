extends RefCounted
## Rune definitions: one-use powers bought at the Trader and used during a
## round. Effects are implemented by id in round_model.use_rune() and
## run_model.use_rune(); content never contains code.

const PRICE = 3
const SLOTS = 2
## How a rune picks its target: "" (none), "line" (a row or column) or
## "slot" (a tray shard).
const ALL = {
	"rune_time": {"name": "Rune of Time", "code": "Ti", "target": "", "text": "+2 trays this round."},
	"rune_shatter": {"name": "Rune of Shattering", "code": "Sh", "target": "line", "text": "Destroy a row or column you choose. Your streak is kept."},
	"rune_thaw": {"name": "Rune of Thaw", "code": "Th", "target": "", "text": "Remove every Stone on the board."},
	"rune_wealth": {"name": "Rune of Wealth", "code": "We", "target": "", "text": "Double your Coins (up to +15). Works at Camp too."},
	"rune_echo": {"name": "Rune of Echo", "code": "Ec", "target": "", "text": "Your next placement scores twice."},
	"rune_shrink": {"name": "Rune of Shrinking", "code": "Sk", "target": "slot", "text": "Turn one shard in the tray into a 1-cell dot."},
	"rune_still": {"name": "Rune of Stillness", "code": "St", "target": "", "text": "Your next 3 placements cannot break your streak."},
	"dye_sky": {"name": "Sky Dye", "code": "+", "target": "", "text": "Every shard in the tray becomes Sky (+).", "element": 1},
	"dye_wind": {"name": "Wind Dye", "code": "o", "target": "", "text": "Every shard in the tray becomes Wind (o).", "element": 2},
	"dye_fire": {"name": "Fire Dye", "code": "^", "target": "", "text": "Every shard in the tray becomes Fire (^).", "element": 3},
	"dye_water": {"name": "Water Dye", "code": "~", "target": "", "text": "Every shard in the tray becomes Water (~).", "element": 4},
	"dye_earth": {"name": "Earth Dye", "code": "#", "target": "", "text": "Every shard in the tray becomes Earth (#).", "element": 5},
}
## Runes that can free a blocked board, so holding one keeps a stuck round
## alive until it is used.
const RESCUES = ["rune_shatter", "rune_shrink"]
const COLOR = Color("b89ae0")

static func exists(id: String) -> bool:
	return ALL.has(id)

static func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "code": "?", "target": "", "text": ""})

static func ids() -> Array:
	var list: Array = ALL.keys()
	list.sort()
	return list
