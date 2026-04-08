extends Node

signal achievement_unlocked(id: String, name: String)

const ACHIEVEMENTS := [
	{"id": "first_blood", "name": "First Blood", "desc": "Kill your first fish"},
	{"id": "centurion", "name": "Centurion", "desc": "Kill 100 fish in one run"},
	{"id": "slaughter", "name": "Slaughter", "desc": "Kill 500 fish in one run"},
	{"id": "wave5", "name": "Wave Rider", "desc": "Survive 5 waves"},
	{"id": "wave10", "name": "Veteran", "desc": "Survive 10 waves"},
	{"id": "boss_slayer", "name": "Boss Slayer", "desc": "Defeat a Kraken"},
	{"id": "level10", "name": "Powered Up", "desc": "Reach level 10"},
	{"id": "level20", "name": "Unstoppable", "desc": "Reach level 20"},
	{"id": "dasher", "name": "Speed Demon", "desc": "Dash 50 times in one run"},
	{"id": "survivor5", "name": "Survivor", "desc": "Survive for 5 minutes"},
	{"id": "survivor10", "name": "Endurance", "desc": "Survive for 10 minutes"},
	{"id": "combo10", "name": "Combo King", "desc": "Reach a 10x combo"},
	{"id": "combo30", "name": "Combo Master", "desc": "Reach a 30x combo"},
	{"id": "rich", "name": "Treasure Hunter", "desc": "Collect 500 gold total"},
	{"id": "weathered", "name": "Storm Chaser", "desc": "Survive a storm event"},
	{"id": "whirlpool", "name": "Vortex Escape", "desc": "Escape a whirlpool"},
]

func check(player_kills: int, player_level: int, player_dashes: int,
		   wave: int, game_time: float, combo: int, 
		   bosses_killed: int, storms_survived: int, whirlpools_escaped: int) -> void:
	var unlocked: Array = GameManager.save_data["achievements"]
	var total_gold: int = GameManager.save_data["gold"]
	
	var checks := {
		"first_blood": player_kills >= 1,
		"centurion": player_kills >= 100,
		"slaughter": player_kills >= 500,
		"wave5": wave >= 5,
		"wave10": wave >= 10,
		"boss_slayer": bosses_killed >= 1,
		"level10": player_level >= 10,
		"level20": player_level >= 20,
		"dasher": player_dashes >= 50,
		"survivor5": game_time >= 300.0,
		"survivor10": game_time >= 600.0,
		"combo10": combo >= 10,
		"combo30": combo >= 30,
		"rich": total_gold >= 500,
		"weathered": storms_survived >= 1,
		"whirlpool": whirlpools_escaped >= 1,
	}
	
	for ach_id in checks:
		if ach_id not in unlocked and checks[ach_id]:
			unlocked.append(ach_id)
			var ach_name := ""
			for a in ACHIEVEMENTS:
				if a["id"] == ach_id:
					ach_name = a["name"]
					break
			achievement_unlocked.emit(ach_id, ach_name)
