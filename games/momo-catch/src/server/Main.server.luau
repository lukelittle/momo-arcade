--!strict
-- Momo Catch server entry point. Builds the world, then starts each service.

local WorldBuilder = require(script.Parent.WorldBuilder)
local DataService = require(script.Parent.DataService)
local BasketService = require(script.Parent.BasketService)
local RoundService = require(script.Parent.RoundService)

WorldBuilder.build()
WorldBuilder.getMomoFolder()
DataService.init()
BasketService.init()
RoundService.init()
