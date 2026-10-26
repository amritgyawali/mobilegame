extends RefCounted
## Talisman definitions: names, prices and the one-sentence rules shown to the
## player. Effects are implemented by id in round_model.gd (scoring) and
## run_model.gd (economy); content never contains code.

const COMMON = 0
const UNCOMMON = 1
const RARE = 2
const LEGENDARY = 3
const PRICES = [4, 6, 8, 12]
const RARITY_NAMES = ["Common", "Uncommon", "Rare", "Legendary"]
const ELEMENT_NAMES = ["", "Sky", "Wind", "Fire", "Water", "Earth"]
## Element bonus talismans: id -> element index.
const ELEMENT_BONUS = {"sky_feather": 1, "wind_chime": 2, "ember_heart": 3, "river_pearl": 4, "earth_drum": 5}

## id -> {name, rarity, code (badge letters), group (archetype), text}
const ALL = {
	"climbing_rope": {"name": "Climbing Rope", "rarity": COMMON, "code": "CR", "group": "Combo", "text": "+20 Base on any placement that clears a line."},
	"tea_thermos": {"name": "Tea Thermos", "rarity": COMMON, "code": "TT", "group": "Combo", "text": "+2 Mult on any placement that clears a line."},
	"sky_feather": {"name": "Sky Feather", "rarity": COMMON, "code": "SF", "group": "Element", "text": "+4 Mult for each pure Sky (+) line."},
	"wind_chime": {"name": "Wind Chime", "rarity": COMMON, "code": "WC", "group": "Element", "text": "+4 Mult for each pure Wind (o) line."},
	"ember_heart": {"name": "Ember Heart", "rarity": COMMON, "code": "EH", "group": "Element", "text": "+4 Mult for each pure Fire (^) line."},
	"river_pearl": {"name": "River Pearl", "rarity": COMMON, "code": "RP", "group": "Element", "text": "+4 Mult for each pure Water (~) line."},
	"earth_drum": {"name": "Earth Drum", "rarity": COMMON, "code": "ED", "group": "Element", "text": "+4 Mult for each pure Earth (#) line."},
	"trail_map": {"name": "Trail Map", "rarity": COMMON, "code": "TM", "group": "Utility", "text": "+1 reroll every round."},
	"coin_purse": {"name": "Coin Purse", "rarity": COMMON, "code": "CP", "group": "Gold", "text": "+1 more Coin for each unused tray when you win a round."},
	"sturdy_boots": {"name": "Sturdy Boots", "rarity": COMMON, "code": "SB", "group": "Streak", "text": "Streak bonus can reach +5 Mult instead of +3."},
	"camp_lantern": {"name": "Camp Lantern", "rarity": COMMON, "code": "CL", "group": "Streak", "text": "+3 Mult on the first clear of every tray."},
	"porters_basket": {"name": "Porter's Basket", "rarity": COMMON, "code": "PB", "group": "Combo", "text": "Shards of 5 or more cells give +40 Base."},
	"little_pebble": {"name": "Little Pebble", "rarity": COMMON, "code": "LP", "group": "Minimalist", "text": "1-cell shards give +30 Base."},
	"hagglers_beads": {"name": "Haggler's Beads", "rarity": COMMON, "code": "HB", "group": "Gold", "text": "Everything at the Trader costs 1 Coin less."},
	"stone_collector": {"name": "Stone Collector", "rarity": COMMON, "code": "SC", "group": "Demolition", "text": "+15 Base for each Stone a clear cracks or breaks."},
	"twin_rope": {"name": "Twin Rope", "rarity": UNCOMMON, "code": "TR", "group": "Combo", "text": "x2 Mult when you clear 2 or more lines at once."},
	"avalanche": {"name": "Avalanche", "rarity": UNCOMMON, "code": "AV", "group": "Growth", "text": "+1 Mult for every line cleared so far this round."},
	"snowball": {"name": "Snowball", "rarity": UNCOMMON, "code": "SN", "group": "Growth", "text": "Gains +1 Mult for the rest of the run each time you clear 3+ lines at once."},
	"clean_slate": {"name": "Clean Slate", "rarity": UNCOMMON, "code": "CS", "group": "Minimalist", "text": "Perfect clears give x5 Mult instead of x3."},
	"minimalists_stone": {"name": "Minimalist's Stone", "rarity": UNCOMMON, "code": "MS", "group": "Minimalist", "text": "+6 Mult if 10 or fewer tiles remain after the placement."},
	"cairn": {"name": "Cairn", "rarity": UNCOMMON, "code": "CA", "group": "Utility", "text": "+1 Mult for each talisman you hold."},
	"momentum": {"name": "Momentum", "rarity": UNCOMMON, "code": "MO", "group": "Streak", "text": "Each streak step gives +1 Mult instead of +0.5."},
	"rainbow_scarf": {"name": "Rainbow Scarf", "rarity": UNCOMMON, "code": "RS", "group": "Rainbow", "text": "A line holding all 5 elements counts as a pure line."},
	"echo_valley": {"name": "Echo Valley", "rarity": UNCOMMON, "code": "EV", "group": "Element", "text": "Pure line bonuses (+50 Base, +1 Mult) count twice."},
	"ice_axe": {"name": "Ice Axe", "rarity": UNCOMMON, "code": "IA", "group": "Demolition", "text": "Stones break in one clear instead of two."},
	"thunderclap": {"name": "Thunderclap", "rarity": RARE, "code": "TC", "group": "Combo", "text": "x3 Mult when you clear 3 or more lines at once."},
	"snow_leopard_fang": {"name": "Snow Leopard's Fang", "rarity": RARE, "code": "LF", "group": "Element", "text": "x1.5 Mult for each pure line in the placement."},
	"golden_yak": {"name": "Golden Yak", "rarity": RARE, "code": "GY", "group": "Gold", "text": "x(1 + Coins / 20) Mult. 30 Coins = x2.5."},
	"hourglass": {"name": "Hourglass", "rarity": RARE, "code": "HG", "group": "Utility", "text": "+2 trays every round, but no streak bonus."},
	"lantern_festival": {"name": "Lantern Festival", "rarity": RARE, "code": "LN", "group": "Streak", "text": "Every 5th clearing placement in a round gets x4 Mult."},
	"mirror_lake": {"name": "Mirror Lake", "rarity": RARE, "code": "ML", "group": "Utility", "text": "Copies the talisman in the slot to its right."},
	"heart_of_mountain": {"name": "Heart of the Mountain", "rarity": LEGENDARY, "code": "HM", "group": "Any", "text": "x2 Mult on every placement."},
	"storm_crown": {"name": "Storm Crown", "rarity": LEGENDARY, "code": "SK", "group": "Streak", "text": "Your streak never breaks; it only pauses on a placement without a clear."},
	"eternal_glacier": {"name": "Eternal Glacier", "rarity": LEGENDARY, "code": "EG", "group": "Growth", "text": "Gains x0.05 Mult for the rest of the run each time you clear a line."},
	"ninth_peak": {"name": "The Ninth Peak", "rarity": LEGENDARY, "code": "NP", "group": "Utility", "text": "+2 talisman slots."},
	"firebird_feather": {"name": "Firebird Feather", "rarity": LEGENDARY, "code": "FF", "group": "Safety", "text": "Once, when you would lose, restart the round instead. Then it burns away."},
}

## Badge colours by archetype.
const GROUP_COLORS = {
	"Combo": Color("7bbde2"), "Element": Color("ed9781"), "Utility": Color("a9b9af"), "Gold": Color("e7bf73"),
	"Streak": Color("c8a2e0"), "Minimalist": Color("e6e4cd"), "Demolition": Color("b0a090"), "Growth": Color("85bca1"),
	"Rainbow": Color("f0b6c8"), "Any": Color("f4f0df"), "Safety": Color("f0a060"),
}
const RARITY_COLORS = [Color("a9b9af"), Color("7bbde2"), Color("e7bf73"), Color("f0a060")]

static func exists(id: String) -> bool:
	return ALL.has(id)

static func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "rarity": COMMON, "code": "??", "group": "Any", "text": ""})

static func price(id: String) -> int:
	return PRICES[int(info(id).rarity)]

static func sell_price(id: String) -> int:
	return price(id) / 2

static func ids_of_rarity(rarity: int) -> Array:
	var result: Array = []
	for id in ALL:
		if int(ALL[id].rarity) == rarity:
			result.append(id)
	result.sort()
	return result

static func color(id: String) -> Color:
	return GROUP_COLORS.get(info(id).group, Color("f4f0df"))
