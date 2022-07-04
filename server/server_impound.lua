_ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) _ESX = obj end)

-- Allowed to reset during server restart
-- You can use this number to calculate a vehicle spawn location index if you have multiple
-- eg: 3 spawnlocations = index % 3 + 1
local _UnimpoundedVehicleCount = 1;

RegisterServerEvent('hrp_pd_impound:ImpoundVehicle')
RegisterServerEvent('hrp_pd_impound:GetImpoundedVehicles')
RegisterServerEvent('hrp_pd_impound:GetVehicles')
RegisterServerEvent('hrp_pd_impound:UnimpoundVehicle')
RegisterServerEvent('hrp_pd_impound:UnlockVehicle')

AddEventHandler('hrp_pd_impound:ImpoundVehicle', function (form)
	Citizen.Trace("hrp_pd_impound: " .. form.plate);
	_source = source;
	MySQL.Async.execute('INSERT INTO `h_impounded_vehicles` VALUES (@plate, @officer, @mechanic, @releasedate, @fee, @reason, @notes, CONCAT(@vehicle), @identifier, @hold_o, @hold_m)',
		{
			['@plate'] 			= form.plate,
			['@officer']     	= form.officer,
			['@mechanic']       = form.mechanic,
			['@releasedate']	= form.releasedate,
			['@fee']			= form.fee,
			['@reason']			= form.reason,
			['@notes']			= form.notes,
			['@vehicle']		= form.vehicle,
			['@identifier']		= form.identifier,
			['@hold_o']			= form.hold_o,
			['@hold_m']			= form.hold_m
		}, function(rowsChanged)
			if (rowsChanged == 0) then
				TriggerClientEvent('esx:showNotification', _source, 'Could not impound')
			
			else
				TriggerClientEvent('esx:showNotification', _source, 'Vehicle Impounded')
	
				
			end
	end)
end)

AddEventHandler('hrp_pd_impound:GetImpoundedVehicles', function (identifier)
	_source = source;
	MySQL.Async.fetchAll('SELECT * FROM `h_impounded_vehicles` WHERE `identifier` = @identifier ORDER BY `releasedate`',
		{
			['@identifier'] = identifier,
		}, function (impoundedVehicles)
			TriggerClientEvent('hrp_pd_impound:SetImpoundedVehicles', _source, impoundedVehicles)
	end)
end)

AddEventHandler('hrp_pd_impound:UnimpoundVehicle', function (plate)
	_source = source;
	_xPlayer = _ESX.GetPlayerFromId(_source)

	_UnimpoundedVehicleCount = _UnimpoundedVehicleCount + 1;

	Citizen.Trace('hrp_pd_impound: Unimpounding Vehicle with plate: ' .. plate);

	local veh = MySQL.Sync.fetchAll('SELECT * FROM `h_impounded_vehicles` WHERE `plate` = @plate',
	{
		['@plate'] = plate,
	})

	if(veh == nil) then
		TriggerClientEvent("hrp_pd_impound:CannotUnimpound")
		return
	

	elseif (_xPlayer.getMoney() < veh[1].fee) then
	--	TriggerClientEvent("hrp_pd_impound:CannotUnimpound")
		TriggerClientEvent('okokNotify:Alert', _xPlayer, "Information:","You Donot have enough Money in your Hand.!!" , 5000, 'warning')
	else

		_xPlayer.removeMoney(round(veh[1].fee));
		TriggerEvent('esx_addonaccount:getSharedAccount', 'society_police', function(account)
		if account then
			account.addMoney(round(veh[1].fee))
		end
	end)
		MySQL.Async.execute('DELETE FROM `h_impounded_vehicles` WHERE `plate` = @plate',
		{
			['@plate'] = plate,
		}, function (rows)
			TriggerClientEvent('hrp_pd_impound:VehicleUnimpounded', _source, veh[1], _UnimpoundedVehicleCount)
		end)
	end
end)

AddEventHandler('hrp_pd_impound:GetVehicles', function ()
	_source = source;

	local vehicles = MySQL.Async.fetchAll('SELECT * FROM `h_impounded_vehicles`', nil, function (vehicles)
		TriggerClientEvent('hrp_pd_impound:SetImpoundedVehicles', _source, vehicles);
	end);
end)

AddEventHandler('hrp_pd_impound:UnlockVehicle', function (plate)
	MySQL.Async.execute('UPDATE `h_impounded_vehicles` SET `hold_m` = false, `hold_o` = false WHERE `plate` = @plate', {
		['@plate'] = plate
	}, function (bs)
		-- Something
	end)
end)

-------------------------------------------------------------------------------------------------------------------------------
-- Stupid extra shit because fuck all of this
-------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent('hrp_pd_impound:GetCharacter')
AddEventHandler('hrp_pd_impound:GetCharacter', function (identifier)
	local _source = source
	MySQL.Async.fetchAll('SELECT * FROM `users` WHERE `identifier` = @identifier',
		{
			['@identifier'] 		= identifier,
		}, function(users)
		TriggerClientEvent('hrp_pd_impound:SetCharacter', _source, users[1]);
	end)
end)

RegisterServerEvent('hrp_pd_impound:GetVehicleAndOwner')
AddEventHandler('hrp_pd_impound:GetVehicleAndOwner', function (plate)
	local _source = source
	if (Config.NoPlateColumn == false) then
		MySQL.Async.fetchAll('select * from `owned_vehicles` LEFT JOIN `users` ON users.identifier = owned_vehicles.owner WHERE `plate` = rtrim(@plate)',
			{
				['@plate'] 		= plate,
			}, function(vehicleAndOwner)
			TriggerClientEvent('hrp_pd_impound:SetVehicleAndOwner', _source, vehicleAndOwner[1]);
		end)
	else
		MySQL.Async.fetchAll('SELECT * FROM `owned_vehicles` LEFT JOIN `users` ON users.identifier = owned_vehicles.owner', {}, function (result)
			for i=1, #result, 1 do
				local vehicleProps = json.decode(result[i].vehicle)

				if vehicleProps.plate:gsub("%s+", "") == plate:gsub("%s+", "") then
					vehicleAndOwner = result[i];
					vehicleAndOwner.plate = vehicleProps.plate;
					TriggerClientEvent('hrp_pd_impound:SetVehicleAndOwner', _source, vehicleAndOwner);
					break;
				end
			end
		end)
	end
end)


function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function round(x)
	return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end
