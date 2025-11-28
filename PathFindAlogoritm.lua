-- Credit: Lantas
local DEFAULT_CONFIG = {
    enableDiagonal = true,
    walkDelay = 300,
    minTilesForSmartWalk = 3,
    tilesPerStep = 2
}

local PathfindingModule = {}

local function calculateDistance(pointA, pointB)
    local deltaX = math.abs(pointA.x - pointB.x)
    local deltaY = math.abs(pointA.y - pointB.y)
    return deltaX + deltaY
end

local function getNeighborTiles(currentNode, worldGrid, allowDiagonal)
    local neighborList = {}
    
    local movementDirections = {
        {x = 0, y = -1},
        {x = 0, y = 1},
        {x = -1, y = 0},
        {x = 1, y = 0}
    }
    
    if allowDiagonal then
        table.insert(movementDirections, {x = -1, y = -1})
        table.insert(movementDirections, {x = 1, y = -1})
        table.insert(movementDirections, {x = -1, y = 1})
        table.insert(movementDirections, {x = 1, y = 1})
    end
    
    for _, direction in ipairs(movementDirections) do
        local neighborX = currentNode.x + direction.x
        local neighborY = currentNode.y + direction.y
        
        if worldGrid[neighborY] and worldGrid[neighborY][neighborX] == 0 then
            table.insert(neighborList, {x = neighborX, y = neighborY})
        end
    end
    
    return neighborList
end

function PathfindingModule.findPath(startPos, goalPos, worldGrid, allowDiagonal)
    local openList = {}
    local closedList = {}
    local parentMap = {}
    local gCostMap = {}
    local fCostMap = {}
    
    table.insert(openList, startPos)
    gCostMap[startPos.y .. "," .. startPos.x] = 0
    fCostMap[startPos.y .. "," .. startPos.x] = calculateDistance(startPos, goalPos)
    
    while #openList > 0 do
        local lowestIndex = 1
        for index, node in ipairs(openList) do
            local nodeKey = node.y .. "," .. node.x
            local currentLowestKey = openList[lowestIndex].y .. "," .. openList[lowestIndex].x
            if fCostMap[nodeKey] < fCostMap[currentLowestKey] then
                lowestIndex = index
            end
        end
        
        local currentNode = table.remove(openList, lowestIndex)
        
        if currentNode.x == goalPos.x and currentNode.y == goalPos.y then
            local finalPath = {}
            while currentNode do
                table.insert(finalPath, 1, {x = currentNode.x, y = currentNode.y})
                currentNode = parentMap[currentNode.y .. "," .. currentNode.x]
            end
            return finalPath
        end
        
        closedList[currentNode.y .. "," .. currentNode.x] = true
        
        for _, neighborNode in ipairs(getNeighborTiles(currentNode, worldGrid, allowDiagonal)) do
            local neighborKey = neighborNode.y .. "," .. neighborNode.x
            
            if not closedList[neighborKey] then
                local currentNodeKey = currentNode.y .. "," .. currentNode.x
                local tentativeGCost = gCostMap[currentNodeKey] + 1
                local isInOpenList = false
                
                for _, openNode in ipairs(openList) do
                    if openNode.x == neighborNode.x and openNode.y == neighborNode.y then
                        isInOpenList = true
                        break
                    end
                end
                
                if not isInOpenList or tentativeGCost < gCostMap[neighborKey] then
                    parentMap[neighborKey] = currentNode
                    gCostMap[neighborKey] = tentativeGCost
                    fCostMap[neighborKey] = tentativeGCost + calculateDistance(neighborNode, goalPos)
                    
                    if not isInOpenList then
                        table.insert(openList, neighborNode)
                    end
                end
            end
        end
    end
    
    return nil
end

local function generateWorldGrid(worldWidth, worldHeight)
    local grid = {}
    
    for tileY = 1, worldHeight do
        grid[tileY] = {}
        for tileX = 1, worldWidth do
            local tile = GetTile(tileX, tileY)
            
            if tile and tile.fg ~= 0 and tile.fg ~= 9268 then
                grid[tileY][tileX] = 1
            else
                grid[tileY][tileX] = 0
            end
        end
    end
    
    return grid
end

local function executeSmartWalk(goalX, goalY, userConfig)
    local config = {}
    for key, value in pairs(DEFAULT_CONFIG) do
        config[key] = value
    end
    if userConfig then
        for key, value in pairs(userConfig) do
            config[key] = value
        end
    end
    
    LogToConsole("=== Starting Pathfinding ===")
    
    local playerPos = GetLocal().pos
    local startPosition = {x = math.floor(playerPos.x / 32), y = math.floor(playerPos.y / 32)}
    local goalPosition = {x = goalX, y = goalY}
    
    LogToConsole("Start Position: (" .. startPosition.x .. "," .. startPosition.y .. ")")
    LogToConsole("Goal Position: (" .. goalPosition.x .. "," .. goalPosition.y .. ")")
    
    local world = GetWorld()
    local worldWidth = world.width
    local worldHeight = world.height
    
    local worldGrid = generateWorldGrid(worldWidth, worldHeight)
    
    local pathResult = PathfindingModule.findPath(
        startPosition,
        goalPosition,
        worldGrid,
        config.enableDiagonal
    )
    
    if not pathResult then
        LogToConsole("ERROR: Path not found!")
        return false, "Path not found"
    end
    
    local totalTiles = #pathResult
    LogToConsole("Total tiles in path: " .. totalTiles)
    
    if totalTiles > config.minTilesForSmartWalk then
        LogToConsole("Using SMART WALK (2 tiles per step)")
        
        local currentStep = 1
        while currentStep <= totalTiles do
            local targetTile = pathResult[currentStep]
            FindPath(targetTile.x, targetTile.y)
            LogToConsole("Step " .. currentStep .. "/" .. totalTiles .. " -> (" .. targetTile.x .. "," .. targetTile.y .. ")")
            Sleep(config.walkDelay)
            
            currentStep = currentStep + config.tilesPerStep
        end
        
        local finalTile = pathResult[totalTiles]
        FindPath(finalTile.x, finalTile.y)
        LogToConsole("REACHED GOAL: (" .. finalTile.x .. "," .. finalTile.y .. ")")
        
    else
        LogToConsole("Using NORMAL WALK (tile by tile)")
        
        for stepNumber, targetTile in ipairs(pathResult) do
            FindPath(targetTile.x, targetTile.y)
            LogToConsole("Step " .. stepNumber .. "/" .. totalTiles .. " -> (" .. targetTile.x .. "," .. targetTile.y .. ")")
            Sleep(config.walkDelay)
        end
    end
    
    LogToConsole("=== Pathfinding Complete! ===")
    return true, "Success", pathResult
end

local PathFinderModule = {}

function PathFinderModule.walkTo(goalX, goalY, config)
    return executeSmartWalk(goalX, goalY, config)
end

function PathFinderModule.findPath(startX, startY, goalX, goalY, enableDiagonal)
    if enableDiagonal == nil then
        enableDiagonal = true
    end
    
    local world = GetWorld()
    local worldGrid = generateWorldGrid(world.width, world.height)
    
    local startPos = {x = startX, y = startY}
    local goalPos = {x = goalX, y = goalY}
    
    return PathfindingModule.findPath(startPos, goalPos, worldGrid, enableDiagonal)
end

function PathFinderModule.hasPath(startX, startY, goalX, goalY)
    local path = PathFinderModule.findPath(startX, startY, goalX, goalY)
    return path ~= nil
end

return PathFinderModule
