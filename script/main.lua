package.path = package.path .. ';./path/to/module/?.lua'

-- 每次加载时清除 otherworld 模块的缓存
api_Log("清除 plot 模块的缓存")
package.loaded['script/plot'] = nil
package.loaded['script/poe2api'] = nil
package.loaded['json'] = nil

local plot = require 'script/plot'
local poe2api = require 'script/poe2api'
local json = require 'json'

-- 创建行为树
local bt = plot.create()

i = 0
while true do
    i = i + 1
    
    -- 记录开始时间（毫秒）
    local start_time = api_GetTickCount64()  -- 转换为 ms
    -- local arrive_point = api_FindNearestReachablePoint(1734,841, 50, 0)
    -- api_Log(arrive_point.x)
    -- api_Log(arrive_point.y)
    -- local result = api_FindPath(1575,843, arrive_point.x,arrive_point.y)
    -- api_Log(result)
    -- point = api_GetUnexploredArea(70)
    -- api_Log("获取未探索区域")
    -- api_Log(point.x)
    -- api_Log(point.y)
    -- -- rpoint = api_FindNearestReachablePoint(point.x, point.y, 15, 0)
    -- -- api_Log("计算最近可到达的点")
    -- -- api_Log(rpoint.x)
    -- -- api_Log(rpoint.y)
    -- if point.x ==-1 and point.y == -1 then
    --     api_Log("没有未探索区域")
    --     while true do
    --         api_Sleep(1)
    --     end
    -- end
    -- -- api_RestoreOriginalMap()
    -- api_UpdateMapObstacles(100)
    -- point = api_GetUnexploredArea(120)
    -- api_Log("point -- > ")
    -- api_Log(point.x)
    -- api_Log(point.y)

    -- api_Log("----------")
    -- player_info = api_GetLocalPlayer()
    -- -- printTable(player_info)
    -- api_Log("1111")
    -- range_info = Actors:Update()
    -- -- printTable(range_info)
    -- api_Log("2222")
    -- current_map_info = api_GetMinimapActorInfo()
    -- -- printTable(current_map_info)
    -- api_Log("3333")
    -- range_items = WorldItems:Update()
    -- -- printTable(range_items)
    -- api_Log("4444")
    -- bag_info = api_Getinventorys(1,0)
    -- -- printTable(bag_info)
    -- api_Log("5555")
    -- UI_info = UiElements:Update()
    -- -- printTable(UI_info)
    -- api_Log("6666")

    -- api_Log("==========")
    
    bt:interrupt()  -- 清空节点栈和YIELD标记
    bt:run()

    local elapsed_ms = (api_GetTickCount64()) - start_time
    api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    api_Log(string.format("-------------------------------------------------------------------------------------------------------------"))

    -- 可选：控制打印频率（如每 N 次打印一次）
    -- if i % 10 == 0 then
    --     api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    --     api_Log(string.format("-------------------------------------------------------------------------------------------------------------"))
    -- end
    
end