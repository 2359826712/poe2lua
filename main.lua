package.path = package.path .. ';./path/to/module/?.lua'
local otherworld = require 'otherworld'
local poe2_api = require 'poe2api'
local my_game_info = require 'my_game_info'
local player_info = api_GetLocalPlayer()
print(player_info.name_utf8)
print(player_info.grid_x)
print(player_info.grid_y)
if player_info.grid_x == 0 then
    return
end
local size = Actors:Update()
local range_info = {}
if size > 0 then
    print(size .. "\n")
    local sum = 0;
    for i = 0, size - 1, 1 do
        sum = sum + 1
        table.insert(range_info, Actors[i])
    end
end
-- 创建行为树
-- local bt = otherworld.create()

-- -- -- 运行行为树
-- print("开始运行行为树...")
-- i = 0
-- while true do
--     i = i + 1
--     print("\n=== 游戏Tick", i, "===")
--     bt:interrupt()
--     -- 带错误保护的执行
--     local status, err = pcall(bt.run, bt)
--     if not status then
--         print("运行出错:", err)
--     end
-- end
-- 运行行为树
-- print("开始运行行为树...")  
-- while true do
--       -- 清空节点栈和YIELD标记
--     bt:run()
-- end
-- UI_info = {}
-- local size =  UiElements:Update()
-- print(size .. "\n")
-- if size > 0 then
--     print(size .. "\n")
--     local sum = 0;
--     for i = 0, size - 1, 1 do
--         sum = sum + 1
--         -- print(sum .. " " .. UiElements[i].name_utf8 .. '' .. UiElements[i].text_utf8)
--         table.insert(UI_info, UiElements[i])
--     end
-- end
