local vmachines, busymachines, dbloaded = {}, {}, false

function CreateDB()
    MySQL.query('CREATE TABLE IF NOT EXISTS vmachines (id int(11) NOT NULL, identifier varchar(60) NOT NULL, position varchar(255) DEFAULT NULL, content longtext NOT NULL, money int(11) DEFAULT 0, restockers longtext NOT NULL, open bit DEFAULT false, name varchar(50) NOT NULL, weight int(11) NOT NULL DEFAULT 0, maxweight int(11) DEFAULT NULL, visible bit DEFAULT false)', {}, function(result)
        if result.warningStatus == 0 then
            MySQL.query('ALTER TABLE vmachines ADD UNIQUE KEY id (id), MODIFY id int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT 3', {}, function() dbloaded = true end)
		else
			MySQL.query('SELECT * FROM vmachines', {}, function(machines)
				for _,machine in pairs(machines) do
					local pos = json.decode(machine.position)
					table.insert(vmachines, {id = machine.id, position = vector3(pos.x, pos.y, pos.z), visible = machine.visible})
				end
				dbloaded = true
			end)
        end
    end)
end

RegisterNetEvent('esx_vmachines:ReleaseMachine')
RegisterServerEvent('esx_vmachines:ReleaseMachine', function(id)
	if busymachines[id] == source then
		local _busymachines = {}
		for machine, player in pairs(busymachines) do
			if machine ~= id then
				_busymachines[machine] = player
			end
		end
		busymachines = _busymachines
	end
end)

ESX.RegisterServerCallback('esx_vmachines:GetMachines', function(source, cb)
	repeat Wait(0) until(dbloaded)
	cb(vmachines)
end)

ESX.RegisterServerCallback('esx_vmachines:CreateMachine', function(source, cb, name, weight)
	local xPlayer = ESX.GetPlayerFromId(source)
	local position = xPlayer.getCoords()
	for _,machine in pairs(vmachines) do
		if #(machine.position - vector3(position.x, position.y, position.z)) < Config.MachinesOffset then
			cb('machinenear') return
		end
	end
--
	if not Config.AdminFreeMachineItem or xPlayer.getGroup() ~= 'admin' then
		local item = Config.MachineItem
		if xPlayer.getInventoryItem(item).count < 1 then cb('itemnotfound') return end
		xPlayer.removeInventoryItem(item, 1)
	end
	if not weight or xPlayer.getGroup() ~= 'admin' then
		weight = Config.DefaultMaxWeight
	end
--
	MySQL.insert('INSERT INTO vmachines (identifier, position, name, maxweight, restockers, content) VALUES (?, ?, ?, ?, ?, ?)', {xPlayer.getIdentifier(), json.encode(position), name or TranslateCap('machine'), weight, '{}', '{}'}, function(id)
		table.insert(vmachines, {id = id, position = vector3(position.x, position.y, position.z), visible = false})
		TriggerClientEvent('esx_vmachines:UpdateMachines', -1, vmachines)
		cb(false)
	end)
end)

function Checks(source, id, machine, admin, restocker)
	if not machine then return 'machinenotfound' end
	for machine, player in pairs(busymachines) do
		if machine == id and player ~= source then
			return 'machinebusy'
		end
	end
	busymachines[id] = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local machinepos = json.decode(machine.position)
	if #(xPlayer.getCoords(true) - vector3(machinepos.x, machinepos.y, machinepos.z)) > Config.DistanceCheck then return end
	if admin then
		local identifier = xPlayer.getIdentifier()
		local auth = false
		if restocker then
			for _,restocker in pairs(json.decode(machine.restockers)) do
				if restocker == identifier then
					auth = true
				end
			end
		end
		if xPlayer.getGroup() ~= 'admin' then
			if machine.identifier == identifier then auth = true end
		else
			auth = true
		end
		if not auth then
			return 'notenoughperms'
		end
	end
end

ESX.RegisterServerCallback('esx_vmachines:RemoveMachine', function(source, cb, id)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local checks = Checks(source, id, machine, true, false, Config.MachineItem, 1)
		if checks then cb(checks) return end
--
		if machine.weight > 0 then cb('machinenotempty') return end
--
		local xPlayer = ESX.GetPlayerFromId(source)
		if not Config.AdminFreeMachineItem or xPlayer.getGroup() ~= 'admin' then
			local item = Config.MachineItem
			if xPlayer.getInventoryItem(item).weight + xPlayer.getWeight() > xPlayer.getMaxWeight() then return end
			xPlayer.addInventoryItem(item, 1)
		end
		MySQL.query('DELETE FROM vmachines WHERE id = ?', {id}, function()
			local _vmachines = {}
			for _,machine in pairs(vmachines) do
				if machine.id ~= id then table.insert(_vmachines, machine) end
			end
			vmachines = _vmachines
			TriggerClientEvent('esx_vmachines:UpdateMachines', -1, vmachines)
			cb()
		end)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:ChangePriceFromMachine', function(source, cb, id, item, price)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local checks = Checks(source, id, machine, true, true)
		if checks then cb(checks) return end
		local content = json.decode(machine.content)
--
		if not content then cb('emptymachine') return end
		if not content[item] then cb('itemnotfound') return end
--
		content[item].price = price
		MySQL.update('UPDATE vmachines SET content = ? WHERE id = ?', {json.encode(content), id}, function()
			cb(false, price)
		end)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:GetMachine', function(source, cb, id)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local checks = Checks(source, id, machine)
		if checks then cb(checks) return end
		local _machine = {id = machine.id, name = machine.name, open = machine.open, content = json.decode(machine.content), weight = machine.weight, maxweight = machine.maxweight, money = machine.money, visible = machine.visible, restockers = json.decode(machine.restockers)}
		local xPlayer = ESX.GetPlayerFromId(source)
		local identifier = xPlayer.getIdentifier()
		if xPlayer.getGroup() == 'admin' or machine.identifier == identifier then
			_machine.allowed = true
			_machine.admin = true
			if xPlayer.getGroup() == 'admin' then
				_machine.adminadmin = true
			end
		else
			for _,restocker in pairs(json.decode(machine.restockers)) do
				if restocker == identifier then
					_machine.allowed = true
					break
				end
			end
		end
		cb(false, _machine)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:RemoveFromMachine', function(source, cb, id, item, count, buy)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local check = not buy and not machine.open
		local checks = Checks(source, id, machine, check, check)
		if checks then cb(checks) return end
		local content = json.decode(machine.content)
		local xPlayer = ESX.GetPlayerFromId(source)
--
		if not content then cb('emptymachine') return end
		if not content[item] then cb('itemnotfound') return end
--
		if content[item].count < count then
			count = content[item].count
		end
		if count < 1 then cb('itemnotfound') return end
		local price = buy and content[item].price * count or 0
		if price > xPlayer.getAccount('money').money then cb('notenoughmoney') return end
		local weight = xPlayer.getInventoryItem(item).weight * count
		if weight + xPlayer.getWeight() > xPlayer.getMaxWeight() then cb('notenoughspace') return end
		content[item].count -= count
		local _content = {}
		if content[item].count < 1 then
			for i, v in pairs(content) do
				if i ~= item then
					_content[i] = v
				end			
			end
		else
			_content = content
		end
		MySQL.update('UPDATE vmachines SET content = ?, money = ?, weight = ? WHERE id = ?', {json.encode(_content), machine.money + price, machine.weight - weight, id}, function()
			xPlayer.removeInventoryItem('money', price)
			xPlayer.addInventoryItem(item, count)
			cb(false, _content, machine.weight - weight)
		end)
	end)
end)
--
ESX.RegisterServerCallback('esx_vmachines:InsertIntoMachine', function(source, cb, id, item, count, price)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local check = not machine.open
		local checks = Checks(source, id, machine, check, check)
		if checks then cb(checks) return end
		local xPlayer = ESX.GetPlayerFromId(source)
		if xPlayer.getInventoryItem(item).count < count then
			count = xPlayer.getInventoryItem(item).count
		end
		if count < 1 then cb('itemnotfound') return end
		local weight = xPlayer.getInventoryItem(item).weight * count + machine.weight
		if Config.MachineMaxWeight and weight > machine.maxweight then cb('notenoughspace') return end
		local content = json.decode(machine.content)
		if content[item] then
			content[item].count += count
		else
			content[item] = {label = ESX.GetItemLabel(item), count = count, price = price, weight = xPlayer.getInventoryItem(item).weight > 99 and xPlayer.getInventoryItem(item).weight or xPlayer.getInventoryItem(item).weight*1000}
		end
		MySQL.update('UPDATE vmachines SET content = ?, weight = ? WHERE id = ?', {json.encode(content), weight, id}, function()
			xPlayer.removeInventoryItem(item, count)
			cb(false, content, weight)
		end)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:DrawMoneyFromMachine', function(source, cb, id, money)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local check = not machine.open
		local checks = Checks(source, id, machine, check, check)
		if checks then cb(checks) return end
		if machine.money < money then
			money = machine.money
		end
		if money < 1 then cb('notenoughmoney') return end
		MySQL.update('UPDATE vmachines SET money = ? WHERE id = ?', {machine.money - money, id}, function()
			ESX.GetPlayerFromId(source).addInventoryItem('money', money)
			cb(false, machine.money - money)
		end)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:InsertMoneyIntoMachine', function(source, cb, id, money)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local check = not machine.open
		local checks = Checks(source, id, machine, check, check)
		if checks then cb(checks) return end
		local xPlayer = ESX.GetPlayerFromId(source)
		if xPlayer.getAccount('money').money < money then 
			money = xPlayer.getAccount('money').money
		end
		if money < 1 then cb('notenoughmoney') return end
		MySQL.update('UPDATE vmachines SET money = ? WHERE id = ?', {machine.money + money, id}, function()
			xPlayer.removeInventoryItem('money', money)
			cb(false, machine.money + money)
		end)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:LockMachine', function(source, cb, id, pick)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local check = not pick or machine.open
		local checks = Checks(source, id, machine, check, check)
		if checks then cb(checks) return end
--
		if pick then
			local xPlayer = ESX.GetPlayerFromId(source)
			local found = false
			for i,items in pairs(Config.PickItems) do
				for item, count in pairs(items) do
					if xPlayer.getInventoryItem(item).count >= count then
						found = true
					else
						found = false
						break
					end
				end
				if found then 
					if Config.ConsumablePick then	
						for item, count in pairs(Config.PickItems[i]) do
							xPlayer.removeInventoryItem(item, count)
						end
					end
					break
				end
			end
			if not found then cb('nopickitem') return end
		end
--
		MySQL.update('UPDATE vmachines SET open = ? WHERE id = ?', {not machine.open, id}, function()
			cb(false, not machine.open)
		end)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:ChangeNameFromMachine', function(source, cb, id, name)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local checks = Checks(source, id, machine, true, Config.RestockersCanChangeName)
		if checks then cb(checks) return end
		MySQL.update('UPDATE vmachines SET name = ? WHERE id = ?', {name, id}, function()
			cb(false, name)
		end)
	end)
end)--

ESX.RegisterServerCallback('esx_vmachines:ChangeWeightFromMachine', function(source, cb, id, weight)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer.getGroup() == 'admin' then
		MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
			local checks = Checks(source, id, machine)
			if checks then cb(checks) return end
			MySQL.update('UPDATE vmachines SET maxweight = ? WHERE id = ?', {weight, id}, function()
				cb(false, weight)
			end)
		end)
	end
end)--

ESX.RegisterServerCallback('esx_vmachines:ChangeVisibleFromMachine', function(source, cb, id)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local checks = Checks(source, id, machine, true, Config.RestockersCanVisible)
		if checks then cb(checks) return end
		MySQL.update('UPDATE vmachines SET visible = ? WHERE id = ?', {not machine.visible, id}, function()
			if Config.MachineBlips then
				for _, _machine in pairs(vmachines) do
					if _machine.id == id then
						_machine.visible = not machine.visible
						break
					end
				end
				TriggerClientEvent('esx_vmachines:UpdateMachines', -1, vmachines)
			end
			cb(false, not machine.visible)
		end)
	end)
end)--

--??

ESX.RegisterServerCallback('esx_vmachines:AddRestockerToMachine', function(source, cb, id, playerId)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local checks = Checks(source, id, machine, true)
		if checks then cb(checks) return end

		local xPlayer = ESX.GetPlayerFromId(playerId)

		local restockers = json.decode(machine.restockers)
		table.insert(restockers, xPlayer.getIdentifier())

		MySQL.update('UPDATE vmachines SET restockers = ? WHERE id = ?', {json.encode(restockers), id}, function()
			cb(false, restockers)
		end)
	end)
end)

ESX.RegisterServerCallback('esx_vmachines:DeleteRestockerFromMachine', function(source, cb, id, player)
	MySQL.single('SELECT * FROM vmachines WHERE id = ?', {id}, function(machine)
		local checks = Checks(source, id, machine, true)
		if checks then cb(checks) return end

		local restockers = json.decode(machine.restockers)
		table.remove(restockers, player)

		MySQL.update('UPDATE vmachines SET restockers = ? WHERE id = ?', {json.encode(restockers), id}, function()
			cb(false, restockers)
		end)
	end)
end)

CreateDB()