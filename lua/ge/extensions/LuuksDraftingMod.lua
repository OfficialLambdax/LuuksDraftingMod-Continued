local overallStrengthMultiplier = 1

local M = {}

local lpack = require("lpack")
local isInMP = (MP ~= nil)

local enableDebug = false

local vehicleData = {}

local function v3_distance(a, b)
    return math.sqrt(math.abs(a.x - b.x)^2 + math.abs(a.y - b.y)^2 + math.abs(a.z - b.z)^2)
end

local function v3_len(a)
    return math.sqrt(math.abs(a.x)^2 + math.abs(a.y)^2 + math.abs(a.z)^2)
end

local function v3_normalize(a)
    local l = v3_len(a)
    local r = {}
    r.x = a.x / l
    r.y = a.y / l
    r.z = a.z / l
    return r
end

local function v3_neg(a)
    local r = {}
    r.x = -a.x
    r.y = -a.y
    r.z = -a.z
    return r
end

local function v3_add(a, b)
    local r = {}
    r.x = a.x + b.x
    r.y = a.y + b.y
    r.z = a.z + b.z
    return r
end

local function v3_sub(a, b)
    local r = {}
    r.x = a.x - b.x
    r.y = a.y - b.y
    r.z = a.z - b.z
    return r
end

local function v3_mul(a, b)
    local r = {}
    r.x = a.x * b.x
    r.y = a.y * b.y
    r.z = a.z * b.z
    return r
end

local function v3_mul_f(a, b)
    local r = {}
    r.x = a.x * b
    r.y = a.y * b
    r.z = a.z * b
    return r
end

local function v3_div(a, b)
    local r = {}
    r.x = a.x / b.x
    r.y = a.y / b.y
    r.z = a.z / b.z
    return r
end

local function v3_div_f(a, b)
    local r = {}
    r.x = a.x / b
    r.y = a.y / b
    r.z = a.z / b
    return r
end

local function v3_lerp(a, b, t)
    local r = {}
    r.x = a.x + (b.x - a.x) * t
    r.y = a.y + (b.y - a.y) * t
    r.z = a.z + (b.z - a.z) * t
    return r
end

local function v3_dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function drawPointCmd(rad, p, color)
    if not enableDebug then return "" end
    local color = color or "color(50, 50, 50, 255)"
    return "obj.debugDrawProxy:drawSphere(" .. rad .. ", vec3(" .. tostring(p.x) .. ", " .. tostring(p.y) .. ", " .. tostring(p.z) .. "), " .. color .. ");"
end

local function drawLineCmd(a, b, color)
    if not enableDebug then return "" end
    local color = color or "color(50, 50, 50, 255)"
    local cmd = "local a = vec3(" .. a.x .. ", " .. a.y .. ", " .. a.z .. ");"
    cmd = cmd .. "local b = vec3(" .. b.x .. ", " .. b.y .. ", " .. b.z .. ");"
    cmd = cmd .. "for i=1,20 do local t = i / 20; local p = vec3(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t); obj.debugDrawProxy:drawSphere(0.1, p, " .. color .. ") end;"
    return cmd
end

local function calcDraft(id, data)
    local cmd = ""
    if data ~= nil then
        local bestDrafts = {}
        -- local cmd = "LuuksDraftingMod.drawSphereWrapper(" .. tostring(data.size.x * 0.5) .. ", vec3(" .. tostring(data.position.x) .. ", " .. tostring(data.position.y) .. ", " .. tostring(data.position.z) .. "), color(50, 50, 50, 255))"
        -- be:getPlayerVehicle(0):queueLuaCommand(cmd)
        for vehID, vehData in pairs(vehicleData) do
            if vehID ~= id and vehData ~= nil then
                local speedCoeff = 3 + (v3_len(vehData.velocity) / 10)
                local dist = v3_distance(data.position, vehData.position)
                local diff = v3_sub(vehData.position, data.position)
                local dot = v3_dot(vehData.vectors.forward, v3_normalize(diff))
                if dot < 0 then dot = 0 end -- Remove negative draft strength possibility
                dot = dot^speedCoeff -- Custom draft strength curve to give a quicker drop off in draft strength when not perfectly in line with the car ahead
                if dot > 1 then dot = 1 end -- Clamp just in case
                -- dot = dot * v3_dot(vehData.vectors.forward, data.vectors.forward) -- Make sure that if we are facing an entirely different direction, we aren't still getting massive draft strength

                -- Distance coefficient
                local velCoeff = math.max(v3_len(vehData.velocity) / 30, 1)
                local maxDist = 35 * velCoeff
                local distCoeff = 1 - (math.min(dist, maxDist) / maxDist)
                if distCoeff > 1 then distCoeff = 1 end
                if distCoeff < 0 then distCoeff = 0 end
                distCoeff = 1 - distCoeff
                distCoeff = distCoeff * distCoeff
                distCoeff = 1 - distCoeff

                -- Velocity difference multiplier
                -- The bigger the velocity difference, the more strength the draft gives
                local velMult = (math.max(v3_len(vehData.velocity), 1)) / (math.max(v3_len(data.velocity), 1)) * (1.0 - (math.min(v3_dot(vehData.vectors.forward, data.vectors.forward), 0)))
                velMult = math.max(velMult / 8, 1)
                -- velMult = math.sqrt(velMult)
                -- velMult = velMult

                -- Final strength calculation
                local draftAngle = v3_normalize(v3_lerp(diff, v3_normalize(vehData.velocity), distCoeff))
                local draftStrength = v3_mul_f(v3_normalize(draftAngle), dot)
                draftStrength = v3_mul_f(draftStrength, distCoeff)

                -- cmd = cmd .. drawLineCmd(data.position, v3_add(data.position, v3_mul_f(draftStrength, 5)))

                local frontalArea = data.size.x * data.size.z
                local aeroForces = v3_mul_f(vehData.velocity, frontalArea)
                local aeroForcesCoeff = v3_dot(v3_normalize(data.velocity), v3_normalize(aeroForces)) * v3_len(aeroForces)
                aeroForcesCoeff = aeroForcesCoeff / 20
                local wind = draftStrength
                wind = v3_mul_f(wind, math.max(aeroForcesCoeff, 0))
                wind = v3_mul_f(wind, velMult)
                wind = v3_mul_f(wind, overallStrengthMultiplier)

                cmd = cmd .. drawLineCmd(data.position, v3_add(data.position, v3_mul_f(wind, 5)), "color(255,255,50,255)")

                -- cmd = cmd .. "obj:setWind(" .. wind.x .. ", " .. wind.y .. ", " .. wind.z .. ");"
                if not (wind.x == nil or wind.y == nil or wind.z == nil) then
                    -- totalWindStrength = v3_add(totalWindStrength, wind)
                    table.insert(bestDrafts, wind)
                end
            end
        end

        if #bestDrafts > 0 then
            function windSort(a, b)
                return v3_len(a) > v3_len(b)
            end

            table.sort(bestDrafts, windSort)

            local c = math.min(3,#bestDrafts)
            local div = 0
            local totalWindStrength = { x = 0, y = 0, z = 0 }
            for i=1,c do
                local weight = v3_len(bestDrafts[i])
                if weight > 0 then
                    totalWindStrength.x = totalWindStrength.x + bestDrafts[i].x * weight
                    totalWindStrength.y = totalWindStrength.y + bestDrafts[i].y * weight
                    totalWindStrength.z = totalWindStrength.z + bestDrafts[i].z * weight
                    div = div + weight
                end
            end
            if div > 0 then
                totalWindStrength = v3_div_f(totalWindStrength, div)

                cmd = cmd .. drawLineCmd(data.position, v3_add(data.position, v3_mul_f(totalWindStrength, 5)), "color(50,255,50,255)")
                cmd = cmd .. "obj:setWind(" .. totalWindStrength.x .. ", " .. totalWindStrength.y .. ", " .. totalWindStrength.z .. ");"

                local obj = be:getObjectByID(id)
                if obj ~= nil then
                    obj:queueLuaCommand(cmd)
                end
            end
        end
    end
end

local function onUpdate(dtSim, dtRaw)
    if isInMP then
        if be:getPlayerVehicle(0) == nil then return end
        local playerVehID = be:getPlayerVehicle(0):getID()
        calcDraft(playerVehID, vehicleData[playerVehID])
    else
        for id, data in pairs(vehicleData) do
            calcDraft(id, data)
        end
    end

    vehicleData = {}
end

local function onVehicleData(dataPacked)
    local data = lpack.decode(dataPacked)
    vehicleData[data.vehicleID] = {}
    -- Copy values over
    for k, v in pairs(data) do
        vehicleData[data.vehicleID][k] = v
    end
end

function onInit()
    print("--------------------------Luuks drafting mod GE loaded!--------------------------")
end

local function toggleDraftDebug()
    enableDebug = not enableDebug
end

M.onInit = onInit
M.onUpdate = onUpdate
M.onVehicleData = onVehicleData
M.toggleDraftDebug = toggleDraftDebug

return M
