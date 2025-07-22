package.path = package.path .. ';./path/to/module/?.lua'
local otherworld = require 'otherworld'
local poe2_api = require 'poe2api'
local player_info = api_GetLocalPlayer()
print(player_info.name)
print(player_info.grid_x)
print(player_info.grid_y)
if player_info.grid_x == 0 then
    return
end
otherworld.run()
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
