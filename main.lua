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
-- otherworld.run()
-- 运行行为树
-- print("开始运行行为树...")
-- while true do
--       -- 清空节点栈和YIELD标记
--     bt:run()
-- end
UI_info = {}
local size =  UiElements:Update()
print(size .. "\n")
if size > 0 then
    print(size .. "\n")
    local sum = 0;
    for i = 0, size - 1, 1 do
        sum = sum + 1
        -- print(sum .. " " .. UiElements[i].name_utf8 .. '' .. UiElements[i].text_utf8)
        table.insert(UI_info, UiElements[i])
    end
end
while true do
    text_table = {
        ['Checkpoints'] = {1013, 25},
        ['寶石切割'] = {1013, 25},
        ['世界地圖'] = {1013, 25},
        ['天賦技能'] = {1013, 25}
    }
    -- 遍历查找并点击
    for text, pos in pairs(text_table) do
        print(text)
        local found = poe2_api.find_text({
            text = text,
            min_x = min_x
        })
        -- 如果找到，更新坐标表
        if found then
            api_ClickScreen(pos[1], pos[2], 1)
        end
    end
end
