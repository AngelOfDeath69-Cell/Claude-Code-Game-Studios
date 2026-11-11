extends RefCounted
## Data-driven configuration for Dragon Legends (balance values and dragon defs).

## Balance values, see `data/balance.json`.
var balance: Dictionary = {}
## Element id -> { name, color }.
var elements: Dictionary = {}
## Dragon id -> definition, see `data/dragons.json`.
var dragons: Dictionary = {}


## Loads `balance.json` and `dragons.json` from [param dir].
static func load_from(dir: String) -> RefCounted:
	var d := new()
	d.balance = JSON.parse_string(FileAccess.get_file_as_string(dir + "/balance.json"))
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/dragons.json"))
	d.elements = raw["elements"]
	for def: Dictionary in raw["dragons"]:
		d.dragons[def["id"]] = def
	return d
