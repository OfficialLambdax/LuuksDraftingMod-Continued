local M = {}
local lpack = require("lpack")

-- This function takes in vehicle data and packs it into a string.
-- TODO: Optimize the string result?
local function dataToString(data)
    return string.format("%q", lpack.encode(data))
end

-- This is a special function that runs every frame, and has full access to
-- vehicle data for the current vehicle.
-- TODO: Perhaps pass deltatime as well? Could be used for improved interpolation/prediction
local function updateGFX(dt)
    local data = {}

    data.vehicleID = obj:getID()
    data.velocity = vec3(obj:getVelocity())
    data.vectors = {}
    data.vectors.forward = vec3(obj:getDirectionVector()):normalized()
    data.vectors.up = vec3(obj:getDirectionVectorUp()):normalized()

    data.position = vec3(obj:getCenterPosition())
    data.size = vec3(obj:getInitialWidth(), obj:getInitialLength(), obj:getInitialHeight())

    obj:queueGameEngineLua("luuksdraftingmod.onVehicleData(" .. dataToString(data) .. ")")
end

local function onInit()
    print("--------------------------Luuks drafting mod loaded!--------------------------")
end

local function drawSphereWrapper(rad, pos)
    obj.debugDrawProxy:drawSphere(rad, pos, color(50, 50, 50, 255))
end

local function onReset()
    obj:queueGameEngineLua("if luuksdraftingmod == nil then extensions.load(\"luuksdraftingmod\") end")
end

M.onInit = onInit
M.onReset = onReset
M.updateGFX = updateGFX
M.drawSphereWrapper = drawSphereWrapper

return M
