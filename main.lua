package.path = package.path .. ';./path/to/module/?.lua'
local otherworld = require 'otherworld'
local player_info = api_GetLocalPlayer()
print(player_info.name)
print(player_info.grid_x)
print(player_info.grid_y)
if player_info.grid_x == 0 then
    return
end

-- 运行行为树
print("开始运行行为树...")
otherworld.run()

-- local size =  WorldItems:Update()
-- print(size .. "\n")
-- if size > 0 then
--     print(size .. "\n")
--     local sum = 0;
--     for i = 0, size - 1, 1 do
--         sum = sum + 1
--         print("index:" .. i .. " " .. WorldItems[i].name_utf8)
--         -- print("index:" .. i .. " " .. WorldItems[i].baseType_utf8)
--     end

--     print("sum:" .. sum .. "\n")

-- end
