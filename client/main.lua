local vmachines, inventory, inventorycount, playermoney, machine, product = {}, {}, 0, 0, false, false
local machineblips = {}
function blipss()
	if Config.MachineBlips then
		for i,blip in pairs(machineblips) do
			RemoveBlip(blip)
		end

		CreateThread(function()
			for i, k in pairs(vmachines) do
				if k.visible then
					local blip = AddBlipForCoord(k.position.x, k.position.y, k.position.z)

					SetBlipSprite(blip, Config.BlipSprite)
					SetBlipColour(blip, Config.BlipColour)
					SetBlipAsShortRange(blip, true)

					BeginTextCommandSetBlipName('STRING')
					AddTextComponentSubstringPlayerName(Config.BlipName)
					EndTextCommandSetBlipName(blip)
						
					machineblips[i] = blip
				end
			end
		end)
	end
end
RegisterNetEvent('esx_vmachines:UpdateMachines')
AddEventHandler('esx_vmachines:UpdateMachines', function(machines)
	vmachines = machines
	blipss()
end)

ESX.TriggerServerCallback('esx_vmachines:GetMachines', function(machines)
	vmachines = machines
	blipss()
end)

function UpdateInventory() 
	inventory= {}
	inventorycount = 0
	for _,v in pairs(ESX.GetPlayerData().inventory) do
		if v.name ~= 'money' then
			inventorycount += 1
			inventory[v.name] = {count = v.count, label = v.label, weight = v.weight}
		end
	end
end

function UpdateMoney() 
	playermoney = 0
	for i, v in pairs(ESX.GetPlayerData().accounts) do
		if v.name == 'money' then
			playermoney = v.money
			break
		end
	end
end

function GetMachine(id)
	ESX.TriggerServerCallback('esx_vmachines:GetMachine', function(errors, _machine)
		if errors then
			ESX.ShowNotification(TranslateCap(errors), 2000, "error")
		else
			machine = _machine
			OpenMachine(id)
		end
	end, id)
end

local confirmed = false

local nearplayers = false

function OpenMachine(id, state, item, success, cancel)
	local elements = {}
	local cb = false
	local cb2 = false
	if state == 'confirm' then
		elements = {
			{icon = "fas fa-question", title = TranslateCap('confirm'), unselectable = true},
			{icon = "fas fa-check", title = TranslateCap('yes'), value = 'yes'},
			{icon = "fas fa-xmark", title = TranslateCap('no'), title = 'no'},
		}
		cb = function(menu, element)
			if element.value == 'yes' then
				success()
			else
				ESX.CloseContext()
			end
		end
		cb2 = cancel
	elseif state == 'price' then
		elements = {
			{icon = "fas fa-dollar-sign", title = machine.content[product].label, unselectable = true},
			{icon = "fas fa-hashtag", title = TranslateCap("price"), inputPlaceholder=machine.content[product].price .. '$', input=true, inputType="number", inputValue=machine.content[product].price, inputMin=0},
			{icon = "fas fa-check", title = TranslateCap("confirm"), value = "confirm"},
			{icon = "fas fa-xmark", title = TranslateCap("cancel"), value = 'cancel'}
		}

		cb = function(menu, element)
			if element.value == 'cancel' then
				ESX.CloseContext()
			else
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:ChangePriceFromMachine', function(errors, price)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.content[product].price = price
							ESX.CloseContext()
						end
					end, id, product, menu.eles[2].inputValue)
				end, function()
					OpenMachine(id, 'price', item)
				end)
			end
		end
		cb2 = function() OpenMachine(id, 'product', item) end
	elseif state == 'product' then
		UpdateMoney()
		--
		local maxcapacity = ESX.GetPlayerData().maxWeight*1000 - ESX.GetPlayerData().weight
		local c = machine.content[product].weight > 99 and machine.content[product].weight or machine.content[product].weight/1000
		maxcapacity = maxcapacity / c
		maxcapacity = maxcapacity > machine.content[product].count and machine.content[product].count or maxcapacity
		local maxafford = playermoney / machine.content[product].price
		if machine.content[product].price < 1 then
			maxafford = maxcapacity
		end
		maxafford = maxafford > maxcapacity and maxcapacity or maxafford
		local maxCount = machine.open and maxcapacity or maxafford
		maxCount = 1 > maxCount and 1 or maxCount
		--
		elements = {
			{icon = "fas fa-cart-arrow-down", title = machine.content[product].label, description = TranslateCap('price') .. ': ' .. machine.content[product].price .. '$', unselectable = true},
			{icon = "fas fa-hashtag", title = TranslateCap("count"), input=true, inputType="number", inputValue=1, inputMin=1, inputMax=maxCount, inputPlaceholder =maxCount},
		}

		if not machine.open then
			table.insert(elements, {icon = "fas fa-cart-shopping", title = TranslateCap("buy"), description = TranslateCap('count') .. ': x' .. machine.content[product].count .. ' - ' .. TranslateCap('weight') .. ': ' .. c/1000 .. ' kg', value = 'buy'})
		else
			table.insert(elements, {icon = "fas fa-arrow-down", title = TranslateCap("retrieve"), description = TranslateCap('count') .. ': x' .. machine.content[product].count .. ' - ' .. TranslateCap('weight') .. ': ' .. c/1000 .. ' kg',value = 'retrieve'})
			if machine.allowed then
				table.insert(elements, {icon = "fas fa-dollar-sign", title = TranslateCap("price"), description = TranslateCap('price') .. ': ' .. machine.content[product].price .. '$', value = 'price'})
			end
		end
		table.insert(elements, {icon = "fas fa-xmark", title = TranslateCap("cancel"), value = 'cancel'})

		cb = function(menu, element) 
			if element.value == 'cancel' then
				ESX.CloseContext()
			elseif element.value == 'price' then
				OpenMachine(id, element.value, item)
			else
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:RemoveFromMachine', function(errors, content, weight)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.weight = weight
							machine.content = content
							ESX.CloseContext()
						end
					end, id, product, menu.eles[2].inputValue, element.value == 'buy')
				end, function()
					if machine.content[product] then
						OpenMachine(id, state, machine, product)
					else
						OpenMachine(id)
					end
				end)
			end
		end
		cb2 = function() OpenMachine(id) end
	elseif state == 'money' then
		UpdateMoney()
		local maquina = machine.money>playermoney and machine.money or playermoney
		elements = {
			{icon = "fas fa-piggy-bank", title = TranslateCap('money'), unselectable = true}, 
			{icon = "fas fa-dollar-sign", title = TranslateCap('count'), input=true, inputType="number", inputValue=1, inputMin=1, inputMax=maquina < 1 and 1 or maquina},
			{icon = "fas fa-plus", title = TranslateCap('store'), description = TranslateCap('you') .. ': ' .. playermoney .. '$', value = 'insert'},
			{icon = "fas fa-minus", title = TranslateCap('retrieve'), description = TranslateCap('machine') .. ': ' .. machine.money .. '$', value = 'remove'},
			{icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'}
		}

		cb = function(menu, element)
			if element.value == 'cancel' then
				ESX.CloseContext()
			elseif element.value == 'insert' then
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:InsertMoneyIntoMachine', function(errors, money)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.money = money
							ESX.CloseContext()
						end
					end, id, menu.eles[2].inputValue)
				end, function()
					OpenMachine(id, state)
				end)
			else
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:DrawMoneyFromMachine', function(errors, money)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.money = money
							ESX.CloseContext()
						end
					end, id, menu.eles[2].inputValue)
				end, function()
					OpenMachine(id, state)
				end)
			end
		end
		cb2 = function() OpenMachine(id) end
	elseif state == 'insert' then
		UpdateInventory()
		--
		local aa = machine.maxweight - machine.weight
		local aar = inventory[item].weight / inventory[item].count
		local ab = aar > 99 and aar or aar*1000
		local ac = aa / ab
		local ad = ac > inventory[item].count and inventory[item].count or ac
		ad = ad < 1 and 1 or ad
		--
		elements = {
			{icon = "fas fa-boxes-packing", title = inventory[item].label, unselectable = true}, 
			{icon = "fas fa-hashtag", title = TranslateCap("count"), input=true, inputType="number", inputPlaceholder = inventory[item].count, inputValue=1, inputMin=1, inputMax=ad, inputPlaceholder=ad},
		}
		if machine.allowed and not machine.content[item] then
			table.insert(elements, {icon = "fas fa-dollar-sign", title = TranslateCap("money"), input=true, inputType="number", inputValue=0, inputMin=0})
		end
		table.insert(elements, {icon = "fas fa-check", title = TranslateCap('store'), value = 'insert'})
		table.insert(elements, {icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'})
		
		cb = function(menu, element)
			if element.value == 'cancel' then
				if inventorycount > 0 then ESX.CloseContext() else OpenMachine(id) end
			else
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:InsertIntoMachine', function(errors, content, weight)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.content = content
							machine.weight = weight
							ESX.CloseContext()
						end
					end, id, item, menu.eles[2].inputValue, menu.eles[3].inputValue or 0)
				end, function()
					UpdateInventory()
					if inventory[item] then
						OpenMachine(id, 'insert', item)
					else
						OpenMachine(id, inventorycount > 0 and 'store')
					end 
				end)
			end
		end
		cb2 = function() OpenMachine(id, 'store') end
	elseif state == 'store' then
		UpdateInventory()
		elements = {
			{icon = "fas fa-folder", title = TranslateCap('inventory'), unselectable = true}, 
		}

		for i, v in pairs(inventory) do
			local weighto = v.weight < 99 and v.weight*1000 or v.weight
			local weighto2 = weighto/v.count
			table.insert(elements, {icon = "fas fa-boxes-packing", title = v.label , description = TranslateCap('count') .. ': x' .. v.count .. ' - ' .. TranslateCap('weight') .. ': ' .. weighto2/1000 .. ' / ' .. weighto/1000 .. ' kg', value = i})
		end
		table.insert(elements, {icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'})

		cb = function(menu, element)
			if element.value == "cancel" then
				ESX.CloseContext()
			else
				OpenMachine(id, 'insert', element.value)
			end
		end
		cb2 = function(menu, element) OpenMachine(id) end
	elseif state == 'name' then
		elements = {
			{icon = "fas fa-palette", title = TranslateCap('changename'), unselectable = true}, 
			{icon = "fas fa-hashtag", title = TranslateCap("name"), input=true, inputType="text", inputPlaceholder=machine.name, inputValue=machine.name},
			{icon = "fas fa-check", title = TranslateCap('confirm'), value = 'confirm'},
			{icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'}
		}
		
		cb = function(menu, element)
			if element.value == 'confirm' then
				local machinename = menu.eles[2].inputValue
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:ChangeNameFromMachine', function(errors, name)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.name = name
							ESX.CloseContext()
						end
					end, id, machinename == '' and machine.name or machinename)
				end, function()
					OpenMachine(id, 'name')
				end)
			else
				ESX.CloseContext()
			end			
		end
		cb2 = function() OpenMachine(id, 'config') end
	elseif state == 'weight' then
		elements = {
			{icon = "fas fa-weight-hanging", title = TranslateCap('changeweight'), unselectable = true}, 
			{icon = "fas fa-hashtag", title = TranslateCap("weight"), input=true, inputType="number", inputValue=machine.maxweight, inputMin=machine.weight, inputPlaceholder=machine.maxweight .. ' g', inputValue=machine.maxweight},
			{icon = "fas fa-check", title = TranslateCap('confirm'), value = 'confirm'},
			{icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'}
		}
		
		cb = function(menu, element)
			if element.value == 'confirm' then
			--
				local machineweight = menu.eles[2].inputValue
				local aa = machineweight < machine.weight and Config.MachineMaxWeight and machine.weight or machineweight
				local ab = aa < 1 and machine.maxweight or aa
			--
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:ChangeWeightFromMachine', function(errors, weight)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.maxweight = weight
							ESX.CloseContext()
						end
					end, id, ab)
				end, function()
					OpenMachine(id, 'weight')
				end)
			else
				ESX.CloseContext()
			end			
		end
		cb2 = function() OpenMachine(id, 'config') end
	elseif state == 'newrestocker' then
		nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck)
		if #nearplayers < 1 then OpenMachine(id, 'config') end
		elements = {
			{icon = "fas fa-person-harassing", title = TranslateCap('nearplayers'), unselectable = true}
		}
		
		for i, k in pairs(nearplayers) do
			table.insert(elements, {icon = "fas fa-person", title = TranslateCap('player') .. ' ' .. GetPlayerServerId(k), description = TranslateCap('restockerdesc'), value=GetPlayerServerId(k)})
		end

		table.insert(elements, {icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'})

		cb = function(menu, element)
			if element.value == 'cancel' then
				ESX.CloseContext()
			else
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:AddRestockerToMachine', function(errors, restockers)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.restockers = restockers
							ESX.CloseContext()
						end
					end, id, element.value)
				end, function()
					nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck)
					if #nearplayers < 1 and #machine.restockers < 1 then OpenMachine(id, 'restockers') else OpenMachine(id, 'config') end
				end)
			end		
		end
		cb2 = function() nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck) if #nearplayers > 0 or #machine.restockers > 0 then OpenMachine(id, 'restockers') else OpenMachine(id, 'config') end end
	
	elseif state == 'restockers' then
		nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck)
		if #nearplayers < 1 and #machine.restockers < 1 then OpenMachine(id, 'config') end
		elements = {
			{icon = "fas fa-person-digging", title = TranslateCap('restockers'), unselectable = true}
		}
		if #nearplayers > 0 then
			table.insert(elements, {icon = "fas fa-plus", title = TranslateCap('newrestocker'), description = TranslateCap('count') .. ': ' .. #nearplayers,value = 'newrestocker'})
		end
		for i, k in pairs(machine.restockers) do
			table.insert(elements, {icon = "fas fa-person", title = k, description = TranslateCap('restockerdesc'), value=i})
		end
		table.insert(elements, {icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'})
		cb = function(menu, element)
			if element.value == 'newrestocker' then
				nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck) if #nearplayers > 0 then OpenMachine(id, 'newrestocker') else ESX.ShowNotification(TranslateCap('playernotfound'), 2000, "error") end
			elseif element.value == 'cancel' then
				ESX.CloseContext()
			else
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:DeleteRestockerFromMachine', function(errors, restockers)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.restockers = restockers
							ESX.CloseContext()
						end
					end, id, element.value)
				end, function()
					nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck)
					if #nearplayers < 1 and #machine.restockers < 1 then OpenMachine(id, 'restockers') else OpenMachine(id, 'config') end
				end)
			end		
		end
		cb2 = function() OpenMachine(id, 'config') end
	elseif state == 'config' then
		elements = {
			{icon = "fas fa-gear", title = TranslateCap('manage'), unselectable = true},
		}
		if Config.MachineBlips and (machine.admin or Config.RestockersCanVisible) then
			if machine.visible then
				table.insert(elements, {icon = "fas fa-eye", title = TranslateCap('visible'), description = TranslateCap('visibledesc'), value = 'visible'})
			else
				table.insert(elements, {icon = "fas fa-eye-slash", title = TranslateCap('notvisible'), description = TranslateCap('notvisibledesc'), value = 'visible'})
			end
		end
		if machine.admin or Config.RestockersCanChangeName then
			table.insert(elements, {icon = "fas fa-palette", title = TranslateCap('changename'), description = TranslateCap('name') .. ': ' .. machine.name, value = 'name'})
		end
		if machine.admin then
			nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck)
			if #nearplayers > 0 or #machine.restockers > 0 then
			table.insert(elements, {icon = "fas fa-person-digging", title = TranslateCap('restockers'), description = TranslateCap('count') .. ': ' .. #machine.restockers, value = 'restockers'})
			end
		end
		if machine.adminadmin then
			table.insert(elements, {icon = "fas fa-weight-hanging", title = TranslateCap('weight'), description = TranslateCap('weight') .. ': ' .. machine.maxweight/1000 .. ' kg', value = 'weight'})
		end
		table.insert(elements, {icon = "fas fa-xmark", title = TranslateCap('cancel'), value = 'cancel'})
		cb = function(menu, element)
			if element.value == 'cancel' then
				ESX.CloseContext()
			elseif element.value == 'name' then
				OpenMachine(id, element.value)
			elseif element.value == 'weight' then
				OpenMachine(id, element.value)
			elseif element.value == 'restockers' then
				nearplayers = ESX.Game.GetPlayersInArea(false, Config.DistanceCheck)
				if #nearplayers > 0 or #machine.restockers > 0 then
					OpenMachine(id, element.value)
				else
					ESX.ShowNotification(TranslateCap('playernotfound'), 2000, "error")
				end
			else
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:ChangeVisibleFromMachine', function(errors, visible)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.visible = visible
							ESX.CloseContext()
						end
					end, id)
				end, function()
					OpenMachine(id, 'config')
				end)
			end
		end
		cb2 = function() OpenMachine(id) end
	else
		UpdateInventory()
		UpdateMoney() 
		elements = {
			{icon = "fas fa-cart-shopping", title = machine.name, description = TranslateCap('weight') .. ': ' .. machine.weight / 1000 .. ' / ' .. machine.maxweight / 1000 .. ' kg', unselectable = true},
		}
		if machine.allowed then
			if not machine.open then
				table.insert(elements, {icon = "fas fa-lock", title = TranslateCap('closed'), description = TranslateCap('opendesc'), value = 'close'})
			else
				table.insert(elements, {icon = "fas fa-unlock", title = TranslateCap('opened'), description = TranslateCap('closedesc'), value = 'close'})
				if machine.admin or Config.RestockersCanChangeName or Config.RestockersCanVisible then
					table.insert(elements, {icon = "fas fa-gear", title = TranslateCap('manage'), description = TranslateCap('managedesc') .. ' #' .. id, value = 'config'})
				end
			end
		else
			if not machine.open and inventorycount > 0 then
				local found = false
				for i,items in pairs(Config.PickItems) do
					for _item, count in pairs(items) do
						if inventory[_item] then
							if inventory[_item].count >= count then
								found = true
							else
								found = false
								break
							end
						end
					end
					if found then
						table.insert(elements, {icon = "fas fa-user-ninja", title = TranslateCap('pick'), description = TranslateCap('pickdesc'), value = 'pick'})
						break
					end
				end
			end
		end
		if machine.open then
			table.insert(elements, {icon = "fas fa-piggy-bank", title = TranslateCap('money'), description = TranslateCap('machine') .. ': ' .. machine.money .. '$ - ' .. TranslateCap('you') .. ': ' .. playermoney .. '$', value = 'money'})
			if inventorycount > 0 then table.insert(elements, {icon = "fas fa-vault", title = TranslateCap('store'), description = TranslateCap('weight') .. ': ' .. ESX.GetPlayerData().weight / 1000 .. ' / ' .. ESX.GetPlayerData().maxWeight .. ' kg', value = 'store'}) end
		end
		if machine.content then
			for product,data in pairs(machine.content) do
				table.insert(elements, {icon = "fas fa-cart-arrow-down", title = data.label, description = TranslateCap('price') .. ': ' .. data.price .. '$ - ' .. TranslateCap('count') .. ': x' .. data.count, value = product})
			end
		end

		cb = function(menu, element)
			if element.value == 'close' then
			local machinename = menu.eles[2].inputValue
				OpenMachine(id, 'confirm', item, function()
					ESX.TriggerServerCallback('esx_vmachines:LockMachine', function(errors, open)
						if errors then
							ESX.ShowNotification(TranslateCap(errors), 2000, "error")
						else
							machine.open = open
							ESX.CloseContext()
						end
					end, id)
				end, function()
					OpenMachine(id)
				end)
			elseif element.value == 'pick' then
				local machinename = menu.eles[2].inputValue
				confirmed = false
				OpenMachine(id, 'confirm', item, function()
					confirmed = true
					ESX.CloseContext()
					ESX.Progressbar(TranslateCap("picking"), Config.PickingTime,{
						FreezePlayer = false, 
						animation =Config.PickAnimation, 
						onFinish = function()
							ESX.TriggerServerCallback('esx_vmachines:LockMachine', function(errors, open)
								machine.open = open
								GetMachine(id)
							end, id, true)
					end})
				end, function()
					if not confirmed then OpenMachine(id) end
				end)
			elseif element.value == 'config' then
				OpenMachine(id, element.value)
			elseif element.value == 'money' then
				OpenMachine(id, element.value)
			elseif element.value == 'store' then
				OpenMachine(id, element.value)
			else
				product = element.value
				OpenMachine(id, 'product')
			end
		end
		cb2 = function()
			TriggerServerEvent('esx_vmachines:ReleaseMachine', id)
		end
	end
	ESX.OpenContext("left", elements, cb, cb2)
end

Citizen.CreateThread(function()
	while true do
		local sleep = 1500
		local ped = PlayerPedId()
		local position = GetEntityCoords(ped)
		for _,w in pairs(vmachines) do
			if #(w.position - position) < Config.DrawDistance then
				sleep = 0
				DrawMarker(Config.MarkerType, w.position.x, w.position.y, w.position.z-1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, nil, nil, false)
				if #(w.position - position) < Config.UsageDistance then
					ESX.ShowHelpNotification(TranslateCap('notify'))
					if IsControlJustReleased(0, 38) then
						GetMachine(w.id)
					end
				end
			end
		end
		Wait(sleep)
	end
end)

RegisterCommand('test1', function(source, args)
	ESX.TriggerServerCallback('esx_vmachines:CreateMachine', function()
		print(json.encode(vmachines))
	end, args[1], args[2])
end)

RegisterCommand('test2', function(source, args)
	ESX.TriggerServerCallback('esx_vmachines:RemoveMachine', function()
		print(json.encode(vmachines))
	end, tonumber(args[1]))
end)

RegisterCommand('test3', function(source, args)
	print(GetEntityModel(GetVehiclePedIsIn(PlayerPedId())))
end)