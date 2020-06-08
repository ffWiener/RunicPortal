--[[

Copyright © 2020, Wiener
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of RunicPortal nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Sammeh BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]

_addon.name = 'RunicPortal'
_addon.author = 'Wiener'
_addon.version = '0.1.0'
_addon.command = 'rp'

require('tables')
local packets = require('packets')

local _portals = T{
    -- Aht Urhgan Whitegate
    [16982076] = {menuId=101},
    -- Azouph Isle
    [17101271] = {menuId=131},
    -- Dvucca Isle
    [17101274] = {menuId=134},
    -- Mamool Ja
    [16990590] = {menuId=109},
    -- Halvung
    [17027539] = {menuId=109},
    -- Ilrusi Atoll
    [16998988] = {menuId=109},
    -- Nyzul Isle
    [17072236] = {menuId=117},
    [17072237] = {menuId=118}
}

local assaultOrders = {
    [762] = {menuId=120, manualSelection=1}, --leujaoam
    [763] = {menuId=121, manualSelection=3}, --mamool ja
    [764] = {menuId=122, manualSelection=4}, --lebros
    [765] = {menuId=123, manualSelection=2}, --periqia
    [766] = {menuId=124, manualSelection=5}, --ilrusi
    [878] = {menuId=125, manualSelection=6}, --nyzul
}

local shortcuts = {
    ["ai"] = 1,
    ["azouph"] = 1,
    ["ls"] = 1,
    ["leujaoam"] = 1,
    ["di"] = 2,
    ["dvucca"] = 2,
    ["p"] = 2,
    ["periqia"] = 2,
    ["mj"] = 3,
    ["mamool"] = 3,
    ["h"] = 4,
    ["halvung"] = 4,
    ["lc"] = 4,
    ["lebros"] = 4,
    ["ia"] = 5,
    ["ilrusi"] = 5,
    ["n"] = 6,
    ["nyzul"] = 6,
}

local _validZones = T{50,79,52,61,54,72}

local _packet = nil
local _lastPacket = nil
local _warping = false
local _doubleReply = false
local _destination = nil

windower.register_event('addon command', function(...)
    local args = T{...}
    local cmd = args[1]

    print(args[0], args[1], args[2])

    if cmd == "reset" then
        ResetDialogue()
    else
        local info = windower.ffxi.get_info()
        if info and _validZones:contains(info.zone) then
            _packet = FindRunicPortal(info.zone)
            if _packet then
                if SetPacketMenuId(info.zone, cmd) then
                    windower.add_to_chat(10, "engaging dialogue")
                    _warping = true
                    _lastPacket = _packet
                    EngageDialogue(_packet['Target'], _packet['Target Index'])
                end
            end
        else
            windower.add_to_chat(10, "Zone does not contain a runic portal!")
        end
    end
end)

function EngageDialogue(target, targetIndex)
	if target and targetIndex then
		local packet = packets.new('outgoing', 0x01A, {
			["Target"]=target,
			["Target Index"]=targetIndex,
			["Category"]=0,
			["Param"]=0,
			["_unknown1"]=0})
		packets.inject(packet)
	end
end

windower.register_event('incoming chunk',function(id,data,modified,injected,blocked)
    if id == 0x034 or id == 0x032 then
        if _warping and _packet then
            local p = packets.parse('incoming',data)
            if p['Menu ID'] == _packet['Menu ID'] then
                local dpacket = packets.new('outgoing', 0x05B)

                if _doubleReply then
                    dpacket["Target"]=_packet['Target']
                    dpacket["Option Index"]=0
                    dpacket["_unknown1"]=0
                    dpacket["Target Index"]=_packet['Target Index']
                    dpacket["Automated Message"]=true
                    dpacket["_unknown2"]=0
                    dpacket["Zone"]=_packet['Zone']
                    dpacket["Menu ID"]=p['Menu ID']
                    packets.inject(dpacket)
                end

                dpacket["Target"]=_packet['Target']
                local optionIndex = 1
                if _destination ~= nil then optionIndex = _destination end
                dpacket["Option Index"]=optionIndex
                dpacket["_unknown1"]=0
                dpacket["Target Index"]=_packet['Target Index']
                dpacket["Automated Message"]=false
                dpacket["_unknown2"]=0
                dpacket["Zone"]=_packet['Zone']
                dpacket["Menu ID"]=p['Menu ID']
                packets.inject(dpacket)

        		_packet = nil
                _destination = nil
                _warping = false
        		return true
            end
        end
	end
end)

function GetBasePortalPacket(zoneId)
    local playerMob = windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id)
    for i,v in pairs(windower.ffxi.get_mob_array()) do
        if string.find(v.name, "Runic Portal") then
            local distance = GetDistance(playerMob.x, playerMob.y, playerMob.z, v.x, v.y, v.z)
            if distance < 6 then
                windower.add_to_chat(10,'Found: '..v.name..'  Distance:'..string.format("%.2f", distance))
                local basePacket = {}
                basePacket['me'] = windower.ffxi.get_player().index
                basePacket['Target'] = v['id']
                basePacket['Target Index'] = i
                basePacket['Zone'] = zoneId
                return basePacket
            end
        end
    end
    return nil
end

function FindRunicPortal(zoneId)
    local basePacket = GetBasePortalPacket(zoneId)
    if basePacket then
        local target = basePacket['Target']
        if _portals[target] then
            return basePacket
        else
            windower.add_to_chat(10, "Unrecognized runic portal found!")
            return nil
        end
    else
        windower.add_to_chat(10, "Not near a runic portal to warp!")
        return nil
    end
end

function FindAssaultOrder()
    local KIs = windower.ffxi.get_key_items()
    for _,v in ipairs(KIs) do
        if assaultOrders[v] ~= nil then return assaultOrders[v] end
    end
    return nil
end

function SetPacketMenuId(zoneId, cmd, target)
    _destination = nil
    local target = _packet['Target']
    windower.add_to_chat(10, "got valid target: " .. target)
    if target ~= nil then
        if zoneId == 50 then
            _doubleReply = false
            local assaultOrder = {}
            assaultOrder = FindAssaultOrder()
            if assaultOrder == nil then
                if cmd == nil then
                    windower.add_to_chat(10, "No runic portal destination given!")
                    return false
                else
                    local oi = shortcuts[cmd]
                    if oi ~= nil then
                        windower.add_to_chat(10, "shortcut found: " .. cmd)
                        _destination = oi
                        _packet['Menu ID'] = _portals[target].menuId
                        return true
                    else
                        windower.add_to_chat(10, "No runic portal destination given!")
                        return false
                    end
                end
            else -- we have assault orders
                if cmd == nil then
                    _packet['Menu ID'] = assaultOrder.menuId
                    windower.add_to_chat(10, "assault orders and nil command, using menuId: " .. tostring(assaultOrder.menuId))
                    return true
                else
                    windower.add_to_chat(10, "Runic portal destination issued with assault orders!  Use //rp to warp to zone.")
                    return false
                end
            end
        else
            windower.add_to_chat(10, "regular warp: " .. tostring(zoneId))
            _doubleReply = true
            _packet['Menu ID'] = _portals[target].menuId
            return true
        end
    else
        windower.add_to_chat(10, "not going to warp")
        return false
    end
end

function GetDistance(x1, y1, z1, x2, y2, z2)
    return math.sqrt(sq(x2-x1) + sq(y2-y1) + sq(z2-z1))
end

function sq(num)
    return num * num
end

function ResetDialogue()
	if _warping and _packet then
		local resetPacket = packets.new('outgoing', 0x05B)
		resetPacket["Target"]=_lastPacket['Target']
		resetPacket["Option Index"]="0"
		resetPacket["_unknown1"]="16384"
		resetPacket["Target Index"]=_lastPacket['Target Index']
		resetPacket["Automated Message"]=false
		resetPacket["_unknown2"]=0
		resetPacket["Zone"]=_lastPacket['Zone']
		resetPacket["Menu ID"]=_lastPacket['Menu ID']
		packets.inject(resetPacket)

		_warping = false
		windower.add_to_chat(10, 'Reset sent.')
	else
		windower.add_to_chat(10, 'Not in middle of warp.')
	end
end
