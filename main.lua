-- package.path = package.path .. ';./path/to/module/?.lua'
-- local otherworld = require 'otherworld'
local player_info = api_GetLocalPlayer()
print(player_info.name)
print(player_info.grid_x)
print(player_info.grid_y)
if player_info.grid_x == 0 then
    return
end
local result = api_FindPath(player_info.grid_x, player_info.grid_y, 519, 1166)
print(type(result))
print(result[1].x)

-- local size =  WorldItems:Update()
-- print(size)
-- if size > 0 then
--     print(size .. "\n")
--     local sum = 0;
--     for i = 0, size - 1, 1 do
--         sum = sum + 1
--         print("index:" .. i .. " " .. WorldItems[i].baseType_utf8)
--     end

--     print("sum:" .. sum .. "\n")

-- end
-- local point = api_GetSafeAreaLocation()
-- print(point.x .. " " .. point.y)

-- result=api_FindPath(player.grid_x, player.grid_y, 1000, 1000)
-- print(#a)
-- -- 假设的配置和游戏信息
-- local config = {
--     ["刷圖設置"] = {
--         ["異界地圖"] = { ["不打地圖詞綴"] = false },
--         ["玩法優先級"] = { ["是否開啟"] = true, ["玩法1"] = 1, ["玩法2"] = 2 },
--         ["碑牌優先級"] = { ["是否開啟"] = true, ["碑牌1"] = 1, ["碑牌2"] = 2 }
--     }
-- }

-- local my_game_info = {
--     boss_name = "最终Boss",
--     map_type = {
--         ["碑牌1"] = "类型A",
--         ["碑牌2"] = "类型B"
--     }
-- }



-- 示例：检查 "Path of Exile" 窗口是否在前台



-- -- 创建行为树
-- local bt = otherworld.create(config, my_game_info)

-- -- 运行行为树
-- print("开始运行行为树...")
-- otherworld.run(bt)

