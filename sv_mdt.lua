local call_index = 0

RegisterServerEvent("mdt:hotKeyOpen")
AddEventHandler("mdt:hotKeyOpen", function()
	local usource = source
    local xPlayer = QBCore.Functions.GetPlayer(usource)
    if xPlayer.PlayerData.job.name == 'police' then
    	exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(reports)
    		for r = 1, #reports do
    			reports[r].charges = json.decode(reports[r].charges)
    		end
    		exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(warrants)
    			for w = 1, #warrants do
    				warrants[w].charges = json.decode(warrants[w].charges)
    			end
    			local officer = GetCharacterName(usource)
    			TriggerClientEvent('mdt:toggleVisibilty', usource, reports, warrants, officer, xPlayer.PlayerData.job.name, xPlayer.PlayerData.job.grade.name)
    		end)
    	end)
    end
end)

RegisterServerEvent("mdt:getOffensesAndOfficer")
AddEventHandler("mdt:getOffensesAndOfficer", function()
	local usource = source
	local charges = {}
	exports.oxmysql:fetch('SELECT * FROM fine_types', {}, function(fines)
		for j = 1, #fines do
			if fines[j].category == 0 or fines[j].category == 1 or fines[j].category == 2 or fines[j].category == 3 then
				table.insert(charges, fines[j])
			end
		end

		local officer = GetCharacterName(usource)

		TriggerClientEvent("mdt:returnOffensesAndOfficer", usource, charges, officer)
	end)
end)

RegisterServerEvent("mdt:performOffenderSearch")
AddEventHandler("mdt:performOffenderSearch", function(query)
	local usource = source
	local matches = {}
	exports.oxmysql:fetch("SELECT * FROM `players` WHERE `charinfo` LIKE ? OR `metadata` LIKE ?", {string.lower('%'..query..'%'),string.lower('%'..query..'%')}, function(result) -- % wildcard, needed to search for all alike results
		for index, data in ipairs(result) do
			if data.charinfo then
				local player = json.decode(data.charinfo)
				local metadata = json.decode(data.metadata)
				local core = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)

				if core then
					player = core['PlayerData']['charinfo']
					metadata = core['PlayerData']['metadata']
				end

				player.id = data.id
				player.metadata = metadata
				player.bloodtype = metadata.bloodtype
				player.fingerprint = metadata.fingerprint
				player.citizenid = data.citizenid
				table.insert(matches, player)
			end
		end

		TriggerClientEvent("mdt:returnOffenderSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("mdt:getOffenderDetails")
AddEventHandler("mdt:getOffenderDetails", function(offender)
	local usource = source
	GetLicenses(offender.citizenid, function(licenses) offender.licenses = licenses end)
	while offender.licenses == nil do Citizen.Wait(0) end
    exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {offender.id}, function(result)

        offender.notes = ""
        offender.mugshot_url = ""
        offender.bail = false
        if result[1] then
            offender.notes = result[1].notes
            offender.mugshot_url = result[1].mugshot_url
            offender.bail = result[1].bail
        end

        exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {offender.id}, function(convictions)

            if convictions[1] then
                offender.convictions = {}
                for i = 1, #convictions do
                    local conviction = convictions[i]
                    offender.convictions[conviction.offense] = conviction.count
                end
            end

            exports.oxmysql:fetch('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {offender.id}, function(warrants)

                if warrants[1] then
                    offender.haswarrant = true
                end

				exports.oxmysql:fetch('SELECT * FROM `player_vehicles` WHERE `citizenid` = ?', {offender.id}, function(vehicles)
					for i = 1, #vehicles do
						vehicles[i].model = vehicles[i].vehicle
						if vehicles[i].mods then
							local vehmods = json.decode(vehicles[i].mods)
							if colors[tostring(vehmods.color2)] and colors[tostring(vehmods.color1)] then
								vehicles[i].color = colors[tostring(vehmods.color2)] .. " on " .. colors[tostring(vehmods.color1)]
							elseif colors[tostring(vehmods.color1)] then
								vehicles[i].color = colors[tostring(vehmods.color1)]
							elseif colors[tostring(vehmods.color2)] then
								vehicles[i].color = colors[tostring(vehmods.color2)]
							else
								vehicles[i].color = "Unknown"
							end
						end
						vehicles[i].vehicle = nil
					end
					offender.vehicles = vehicles
					offender.phone_number = offender.phone
					offender.dateofbirth = offender.birthdate
					TriggerClientEvent("mdt:returnOffenderDetails", usource, offender)
				end)
            end)
        end)
    end)
end)

RegisterServerEvent("mdt:getOffenderDetailsById")
AddEventHandler("mdt:getOffenderDetailsById", function(char_id)
    local usource = source
    exports.oxmysql:fetch('SELECT * FROM `players` WHERE `id` = ?', {char_id}, function(result)
		local charinfo = json.decode(result[1].charinfo)
        local offender = result[1]

        if not offender then
            TriggerClientEvent("mdt:closeModal", usource)
            TriggerClientEvent("mdt:sendNotification", usource, "This person no longer exists.")
            return
        end
    
        GetLicenses(offender.citizenid, function(licenses) offender.licenses = licenses end)
        while offender.licenses == nil do Citizen.Wait(0) end

        exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {offender.id}, function(result)

            offender.notes = ""
            offender.mugshot_url = ""
            offender.bail = false
            if result[1] then
                offender.notes = result[1].notes
                offender.mugshot_url = result[1].mugshot_url
                offender.bail = result[1].bail
            end

            exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {offender.id}, function(convictions) 

                if convictions[1] then
                    offender.convictions = {}
                    for i = 1, #convictions do
                        local conviction = convictions[i]
                        offender.convictions[conviction.offense] = conviction.count
                    end
                end

                exports.oxmysql:fetch('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {offender.id}, function(warrants)
                    
                    if warrants[1] then
                        offender.haswarrant = true
                    end

                    exports.oxmysql:fetch('SELECT * FROM `player_vehicles` WHERE `citizenid` = ?', {offender.citizenid}, function(vehicles)
                        for i = 1, #vehicles do
                            vehicles[i].model = vehicles[i].vehicle
                            if vehicles[i].mods then
                                local vehmods = json.decode(vehicles[i].mods)
                                if colors[tostring(vehmods.color2)] and colors[tostring(vehmods.color1)] then
                                    vehicles[i].color = colors[tostring(vehmods.color2)] .. " on " .. colors[tostring(vehmods.color1)]
                                elseif colors[tostring(vehmods.color1)] then
                                    vehicles[i].color = colors[tostring(vehmods.color1)]
                                elseif colors[tostring(vehmods.color2)] then
                                    vehicles[i].color = colors[tostring(vehmods.color2)]
                                else
                                    vehicles[i].color = "Unknown"
                                end
                            end
                            vehicles[i].vehicle = nil
                        end
                        offender.vehicles = vehicles
						offender.firstname = charinfo.firstname
						offender.lastname = charinfo.lastname
                        offender.phone_number = charinfo.phone
                        offender.dateofbirth = charinfo.birthdate
						offender.bloodtype  = charinfo.bloodtype
						offender.nationality = charinfo.nationality
                        TriggerClientEvent("mdt:returnOffenderDetails", usource, offender)
                    end)
                end)
            end)
        end)
    end)
end)

RegisterServerEvent("mdt:saveOffenderChanges")
AddEventHandler("mdt:saveOffenderChanges", function(id, changes, identifier)
	local usource = source
	exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {id}, function(result)
		if result[1] then
			exports.oxmysql:execute('UPDATE `user_mdt` SET `notes` = ?, `mugshot_url` = ?, `bail` = ? WHERE `char_id` = ?', {id, changes.notes, changes.mugshot_url, changes.bail})
		else
			exports.oxmysql:insert('INSERT INTO `user_mdt` (`char_id`, `notes`, `mugshot_url`, `bail`) VALUES (?, ?, ?, ?)', {id, changes.notes, changes.mugshot_url, changes.bail})
		end
		for i = 1, #changes.licenses_removed do
			local license = changes.licenses_removed[i]
			exports.oxmysql:execute('DELETE FROM `user_licenses` WHERE `type` = ? AND `owner` = ?', {license.type, identifier})
		end

		if changes.convictions ~= nil then
			for conviction, amount in pairs(changes.convictions) do	
				exports.oxmysql:execute('UPDATE `user_convictions` SET `count` = ? WHERE `char_id` = ? AND `offense` = ?', {id, amount, conviction})
			end
		end

		for i = 1, #changes.convictions_removed do
			exports.oxmysql:execute('DELETE FROM `user_convictions` WHERE `char_id` = ? AND `offense` = ?', {id, changes.convictions_removed[i]})
		end

		TriggerClientEvent("mdt:sendNotification", usource, "Offender changes have been saved.")
	end)
end)

RegisterServerEvent("mdt:saveReportChanges")
AddEventHandler("mdt:saveReportChanges", function(data)
	exports.oxmysql:execute('UPDATE `mdt_reports` SET `title` = ?, `incident` = ? WHERE `id` = ?', {data.id, data.title, data.incident})
	TriggerClientEvent("mdt:sendNotification", source, "Report changes have been saved.")
end)

RegisterServerEvent("mdt:deleteReport")
AddEventHandler("mdt:deleteReport", function(id)
	exports.oxmysql:execute('DELETE FROM `mdt_reports` WHERE `id` = ?', {id})
	TriggerClientEvent("mdt:sendNotification", source, "Report has been successfully deleted.")
end)

RegisterServerEvent("mdt:submitNewReport")
AddEventHandler("mdt:submitNewReport", function(data)
	local usource = source
	
	local author = GetCharacterName(source)
	if tonumber(data.sentence) and tonumber(data.sentence) > 0 then
		data.sentence = tonumber(data.sentence)
	else 
		data.sentence = nil 
	end
	charges = json.encode(data.charges)
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	exports['ghmattimysql']:execute('INSERT INTO `mdt_reports` (`char_id`, `title`, `incident`, `charges`, `author`, `name`, `date`, `jailtime`) VALUES (@id, @title, @incident, @charges, @author, @name, @date, @sentence)', {
		['@id']  = data.char_id,
		['@title'] = data.title,
		['@incident'] = data.incident,
		['@charges'] = charges,
		['@author'] = author,
		['@name'] = data.name,
		['@date'] = data.date,
		['@sentence'] = data.sentence
	}, 
	function(id)
		whichId = id['insertId']
		TriggerEvent("mdt:getReportDetailsById", whichId, usource)
		TriggerClientEvent("mdt:sendNotification", usource, "A new report has been submitted.")
	end)

	for offense, count in pairs(data.charges) do
		exports['ghmattimysql']:execute('SELECT * FROM `user_convictions` WHERE `offense` = @offense AND `char_id` = @id', {
			['@offense'] = offense,
			['@id'] = data.char_id
		}, function(result)
			if result[1] then
				exports['ghmattimysql']:execute('UPDATE `user_convictions` SET `count` = @count WHERE `offense` = @offense AND `char_id` = @id', {
					['@id']  = data.char_id,
					['@offense'] = offense,
					['@count'] = count + 1
				})
			else
				exports['ghmattimysql']:execute('INSERT INTO `user_convictions` (`char_id`, `offense`, `count`) VALUES (@id, @offense, @count)', {
					['@id']  = data.char_id,
					['@offense'] = offense,
					['@count'] = count
				})
			end
		end)
	end
end)

RegisterServerEvent("mdt:performReportSearch")
AddEventHandler("mdt:performReportSearch", function(query)
	local usource = source
	local matches = {}
	exports.oxmysql:fetch("SELECT * FROM `mdt_reports` WHERE `id` LIKE :test OR LOWER(`title`) LIKE :test OR LOWER(`name`) LIKE :test OR LOWER(`author`) LIKE :test or LOWER(`charges`) LIKE :test", {
		test = string.lower('%'..query..'%')
	}, function(result) -- % wildcard, needed to search for all alike results

		for index, data in ipairs(result) do
			data.charges = json.decode(data.charges)
			table.insert(matches, data)
		end

		TriggerClientEvent("mdt:returnReportSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("mdt:sentencePlayer")
AddEventHandler("mdt:sentencePlayer", function( jailtime, charges, char_id, fine, players)
	
	local src = source
	local offender = char_id

	if offender ~= nil then
		TriggerClientEvent("mdt:client:JailPlayer", src, jailtime, offender, fine)
	end


	for _, src in pairs(players) do
		if src ~= 0 and GetPlayerName(src) then
			exports['ghmattimysql']:execute('SELECT * FROM `players` WHERE `citizenid` = @identifier', {
				['@identifier'] = char_id
			}, function(result)
	
				if result[1].id == char_id then
					if jailtime and jailtime > 0 then
						jailtime = math.ceil(jailtime)
					end
					if fine > 0 then
						-- TriggerClientEvent here if you want to send the money directly to the qb-bossmenu for police. -- OPTIONAL.
					end
					return
				end

				TriggerClientEvent("mdt:client:JailCommand", src, 'NHB84639', 5)
			end)
		end
	end

end)

RegisterServerEvent("mdt:performVehicleSearch")
AddEventHandler("mdt:performVehicleSearch", function(query)
	local usource = source
	local matches = {}
	exports.oxmysql:fetch("SELECT * FROM `player_vehicles` WHERE LOWER(`plate`) LIKE ?", {string.lower('%'..query..'%')}, function(result) -- % wildcard, needed to search for all alike results
		for index, data in ipairs(result) do
			data.model = data.vehicle
			if data.mods ~= nil then
				local vehmods = json.decode(data.mods)
				data.color = colors[tostring(vehmods.color1)]
				if colors[tostring(vehmods.color2)] then
					data.color = colors[tostring(vehmods.color2)] .. " on " .. colors[tostring(vehmods.color1)]
				end
			end
			table.insert(matches, data)
		end

		TriggerClientEvent("mdt:returnVehicleSearchResults", usource, matches)
	end)
end)

RegisterServerEvent("mdt:performVehicleSearchInFront")
AddEventHandler("mdt:performVehicleSearchInFront", function(query)
	local usource = source
	local xPlayer = QBCore.Functions.GetPlayer(usource)
    if xPlayer.PlayerData.job.name == 'police' then
    	exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(reports)
    		for r = 1, #reports do
    			reports[r].charges = json.decode(reports[r].charges)
    		end
    		exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 3) sub ORDER BY `id` DESC", {}, function(warrants)
    			for w = 1, #warrants do
    				warrants[w].charges = json.decode(warrants[w].charges)
    			end
    			exports.oxmysql:fetch("SELECT * FROM `player_vehicles` WHERE `plate` = ?", {query}, function(result)
					local officer = GetCharacterName(usource)
    				TriggerClientEvent('mdt:toggleVisibilty', usource, reports, warrants, officer, xPlayer.PlayerData.job.name)
					TriggerClientEvent("mdt:returnVehicleSearchInFront", usource, result, query)
				end)
    		end)
    	end)
	end
end)

RegisterServerEvent("mdt:getVehicle")
AddEventHandler("mdt:getVehicle", function(vehicle)
	local usource = source
    exports.oxmysql:fetch("SELECT * FROM `players` WHERE `citizenid` = ?", {vehicle.citizenid}, function(result)

		if result[1] then
			local player = json.decode(result[1].charinfo)
			vehicle.owner = player.firstname .. ' ' .. player.lastname
			vehicle.owner_id = result[1].id
		end

        exports.oxmysql:fetch('SELECT * FROM `vehicle_mdt` WHERE `plate` = ?', {vehicle.plate}, function(data)

            if data[1] then
                if data[1].stolen == 1 then vehicle.stolen = true else vehicle.stolen = false end
                if data[1].notes ~= null then vehicle.notes = data[1].notes else vehicle.notes = '' end
            else
                vehicle.stolen = false
                vehicle.notes = ''
            end

            exports.oxmysql:fetch('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {vehicle.owner_id}, function(warrants)

                if warrants[1] then
                    vehicle.haswarrant = true
                end

                exports.oxmysql:fetch('SELECT `bail` FROM user_mdt WHERE `char_id` = ?', {vehicle.owner_id}, function(bail)

                    if bail and bail[1] and bail[1].bail == 1 then
                        vehicle.bail = true
                    else
                        vehicle.bail = false
                    end
	                vehicle.type = 'Vehicle'
	                TriggerClientEvent("mdt:returnVehicleDetails", usource, vehicle)
                end)
            end)
        end)
    end)
end)

RegisterServerEvent("mdt:getWarrants")
AddEventHandler("mdt:getWarrants", function()
	local usource = source
	exports.oxmysql:fetch("SELECT * FROM `mdt_warrants`", {}, function(warrants)
		for i = 1, #warrants do
			warrants[i].expire_time = ""
			warrants[i].charges = json.decode(warrants[i].charges)
		end
		TriggerClientEvent("mdt:returnWarrants", usource, warrants)
	end)
end)

RegisterServerEvent("mdt:submitNewWarrant")
AddEventHandler("mdt:submitNewWarrant", function(data)
	local usource = source
	data.charges = json.encode(data.charges)
	data.author = GetCharacterName(source)
	data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
	exports.oxmysql:insert('INSERT INTO `mdt_warrants` (`name`, `char_id`, `report_id`, `report_title`, `charges`, `date`, `expire`, `notes`, `author`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {data.name, data.char_id, data.report_id, data.report_title, data.charges, data.date, data.expire, data.notes, data.author}, function()
		TriggerClientEvent("mdt:completedWarrantAction", usource)
		TriggerClientEvent("mdt:sendNotification", usource, "A new warrant has been created.")
	end)
end)

RegisterServerEvent("mdt:deleteWarrant")
AddEventHandler("mdt:deleteWarrant", function(id)
	local usource = source
	exports.oxmysql:execute('DELETE FROM `mdt_warrants` WHERE `id` = ?', {id}, function()
		TriggerClientEvent("mdt:completedWarrantAction", usource)
	end)
	TriggerClientEvent("mdt:sendNotification", usource, "Warrant has been successfully deleted.")
end)

RegisterServerEvent("mdt:getReportDetailsById")
AddEventHandler("mdt:getReportDetailsById", function(query, _source)
	if _source then source = _source end
	local usource = source
	exports.oxmysql:fetch("SELECT * FROM `mdt_reports` WHERE `id` = ?", {query}, function(result)
		if result and result[1] then
			result[1].charges = json.decode(result[1].charges)
			TriggerClientEvent("mdt:returnReportDetails", usource, result[1])
		else
			TriggerClientEvent("mdt:closeModal", usource)
			TriggerClientEvent("mdt:sendNotification", usource, "This report cannot be found.")
		end
	end)
end)

RegisterServerEvent("mdt:newCall")
AddEventHandler("mdt:newCall", function(details, caller, coords, sendNotification)
	call_index = call_index + 1
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:newCall", source, details, caller, coords, call_index)
			if sendNotification ~= false then
				TriggerClientEvent("InteractSound_CL:PlayOnOne", source, 'demo', 0.0)
				TriggerClientEvent("mythic_notify:client:SendAlert", source, {type="infom", text="You have received a new call.", length=5000, style = { ['background-color'] = '#ffffff', ['color'] = '#000000' }})
			end
		end
	end
end)

RegisterServerEvent("mdt:attachToCall")
AddEventHandler("mdt:attachToCall", function(index)
	local usource = source
	local charname = GetCharacterName(usource)
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:newCallAttach", source, index, charname)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have attached to this call.")
end)

RegisterServerEvent("mdt:detachFromCall")
AddEventHandler("mdt:detachFromCall", function(index)
	local usource = source
	local charname = GetCharacterName(usource)
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:newCallDetach", source, index, charname)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have detached from this call.")
end)

RegisterServerEvent("mdt:editCall")
AddEventHandler("mdt:editCall", function(index, details)
	local usource = source
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:editCall", source, index, details)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have edited this call.")
end)

RegisterServerEvent("mdt:deleteCall")
AddEventHandler("mdt:deleteCall", function(index)
	local usource = source
	local xPlayers = QBCore.Functions.GetPlayers()
	for i= 1, #xPlayers do
		local source = xPlayers[i]
		local xPlayer = QBCore.Functions.GetPlayer(source)
		if xPlayer.PlayerData.job.name == 'police' then
			TriggerClientEvent("mdt:deleteCall", source, index)
		end
	end
	TriggerClientEvent("mdt:sendNotification", usource, "You have deleted this call.")
end)

RegisterServerEvent("mdt:saveVehicleChanges")
AddEventHandler("mdt:saveVehicleChanges", function(data)
	if data.stolen then data.stolen = 1 else data.stolen = 0 end
	local usource = source
	exports.oxmysql:fetch('SELECT * FROM `vehicle_mdt` WHERE `plate` = ?', {data.plate}, function(result)
		if result[1] then
			exports.oxmysql:execute('UPDATE `vehicle_mdt` SET `stolen` = ?, `notes` = ? WHERE `plate` = ?', {data.plate, data.stolen, data.notes})
		else
			exports.oxmysql:insert('INSERT INTO `vehicle_mdt` (`plate`, `stolen`, `notes`) VALUES (?, ?, ?)', {data.plate, data.stolen, data.notes})
		end
		
		TriggerClientEvent("mdt:sendNotification", usource, "Vehicle changes have been saved.")
	end)
end)

function GetLicenses(identifier, cb)
	local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
	if player ~= nil then
		local playerlicenses = player.PlayerData.metadata["licences"]
		local licenses = {}

		for type,_ in pairs(playerlicenses) do
			if playerlicenses[type] then
				local licenseType = nil
				local label = nil

				if type == "driver" then
					licenseType = "driver_license" label = "Drivers License"
				elseif type == "weapon" then
					licenseType = "weapon_license" label = "Weapons License"
				end

				table.insert(licenses, {
					type = licenseType,
					label = label
				})
			end
		end
		cb(licenses)
	else
		cb(false)
	end
end

function GetCharacterName(source)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	if xPlayer then
		return xPlayer.PlayerData.charinfo.firstname
	end
end

function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2 
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "   
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end
