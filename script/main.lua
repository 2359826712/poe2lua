-- package.path = package.path .. ';./path/to/module/?.lua'

-- api_Log(package)
-- 每次加载时清除 otherworld 模块的缓存
api_Log("清除 otherworld 模块的缓存")
package.loaded['script/otherworld'] = nil
package.loaded['script/poe2api'] = nil
package.loaded['json'] = nil

local package_path = api_GetExecutablePath()
local script_dir = package_path:match("(.*[/\\])") .. "script/"
-- api_Log("脚本目录: " .. script_dir)
math.randomseed(os.time())
local otherworld = require 'script/otherworld'
local poe2api = require 'script/poe2api'
local json = require 'script.lualib.json'
local random_str = require 'script/random_str'
-- 创建行为树
local bt = otherworld.create()
-- api_Log("版号: V 09.15.01")
i = 0
while true do
    i = i + 1
    local Obfuscate =  random_str.Obfuscate("abcd")
    poe2api.paste_text(Obfuscate)
    -- 记录开始时间（毫秒）
    local start_time = api_GetTickCount64()  -- 转换为 ms

    -- api_RestoreOriginalMap()
    -- api_UpdateMapObstacles(100)
    -- point = api_GetUnexploredArea(120)
    -- api_Log("point -- > ")
    -- api_Log(point.x)
    -- api_Log(point.y)

    -- api_Log("----------")
    -- player_info = api_GetLocalPlayer()
    -- api_GetTeleportationPoint()
    -- printTable(api_GetTeleportationPoint())
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
    -- api_Log("6666")"Metadata/Effects/Spells/monsters_effects/Act4_FOUR/GreatWhiteOne/ao/piranha_puddle_01.ao", 20

    -- api_Log("==========")
    -- -- -- api_RegisterCircle("Metadata/Effects/Spells/monsters_effects/Act4_FOUR/GreatWhiteOne/ao/piranha_puddle_01.ao" , 20, 2)
    -- -- -- -- api_AddMonitoringSkills(1,"Metadata/Effects/Spells/monsters_effects/Act4_FOUR/GreatWhiteOne/ao/piranha_puddle_01.ao")
    -- MonitoringSkills_Circle = {
    --     {"Metadata/Effects/Spells/monsters_effects/Gallows/Act1/LivingBlood/LivingBlood.ao", 20, 2}
    -- }
    -- api_RegisterCircle("Metadata/Effects/Spells/monsters_effects/Act4_FOUR/TwilightOrderGuardBoss/ao/SkyBeam.ao" , 28 , 2)
    -- Actors:Update() 
    -- local p = api_GetLocalPlayer()
    -- local result_60 = api_GetSafeAreaLocation(p.grid_x, p.grid_y, 100, 60, 2, 0.5)
    -- api_Log("keep_distancen -- > "..result_60.x.." , "..result_60.y)
    -- api_Log("player_info.grid_x, player_info.grid_y -- > "..p.grid_x.." , ".. p.grid_y)
    -- if l then
    --     local r = api_IsPointInAnyActive(l.grid_x , l.grid_y , 0)
    --     if r then
    --         api_FindNearestSafeTile(l.grid_x , l.grid_y , 100 , 2)
    --     end
    -- end
    
    
--     dec.inside       (bool)  是否在危险区域内。
-- --     dec.depthInside  (number) 深入危险区的深度（越大越危险）。
-- --     dec.safeTile     (table) 最近安全格 { x, y }。
-- --     dec.action       (int)   行动建议：
--     for _,v in pairs(danger) do
--         api_Log(v)
--     end

    -- api_Log("++++++++++++++++++++++++++++")
    -- api_ClickScreen(100, 850, 0, 10, 15)
    -- api_Sleep(500)
    -- (api_GetExecutablePath())
    -- api_UpdateMapObstacles(100)
    
    bt:interrupt()  -- 清空节点栈和YIELD标记
    local success, err = pcall(function()
        bt:run()
    end)
    if not success then
        -- 打印错误信息
        -- api_Log(string.format("注意Tick %d:", i))
        -- api_Log(string.format("注意信息: %s", tostring(err)))
        -- error(err)
        api_SetStatusText("开图次数:"..(poe2api.runtime.open_map_count).."\n异常提示:"..(err or ""))
        error(tostring(err))
        -- while true do
        --     api_Sleep(1000)
        -- end
    end

    local elapsed_ms = (api_GetTickCount64()) - start_time
    api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    api_Log(string.format("-------------------------------------------------------------------------------------------------------------"))

    -- 可选：控制打印频率（如每 N 次打印一次）
    -- if i % 10 == 0 then
    --     api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    --     api_Log(string.format("-------------------------------------------------------------------------------------------------------------"))
    -- end
    
end