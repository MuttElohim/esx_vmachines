Config = {}
Config.Locale = GetConvar('esx:locale', 'en')

Config.UsageDistance = 1.0

Config.MachinesOffset = 2.5

Config.DrawDistance = 10.0

Config.MarkerSize   = {x = 1.5, y = 1.5, z = 1.0}
-- https://g.co/kgs/mfbHRP
Config.MarkerColor  = {r = 102, g = 102, b = 204}
-- https://docs.fivem.net/docs/game-references/markers/
Config.MarkerType   = 1

Config.DistanceCheck = 3.0

Config.MachineItem = 'bread'

Config.AdminFreeMachineItem = true

Config.PickItems = {
	{['bread'] = 1},
	{['water'] = 1},
	{['bread'] = 1, ['water'] = 3},
}

Config.ConsumablePick = true

Config.PickingTime = 25000

Config.PickAnimation ={
	type = "anim",
	dict = "anim@mp_player_intmenu@key_fob@", 
	lib = "fob_click" 
}

Config.MachineMaxWeight = true

Config.DefaultMaxWeight = 50000

-- Config.RestockersCanConfig = true

Config.RestockersCanChangeName = true

Config.RestockersCanVisible = true

Config.MachineBlips = true
-- https://docs.fivem.net/docs/game-references/blips/#blips
Config.BlipSprite = 59
-- https://docs.fivem.net/docs/game-references/blips/#blip-colors
Config.BlipColour = 3

Config.BlipName = TranslateCap('machine')