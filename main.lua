package.path = package.path .. ';./path/to/module/?.lua'
api_Log("清除 otherworld 模块的缓存")
package.loaded['otherworld'] = nil
local otherworld = require 'otherworld'


-- 创建行为树
local bt = otherworld.create()

-- -- 运行行为树
-- api_Log("开始运行行为树...")
i = 0
while true do
    i = i + 1
    -- api_Log("\n=== 游戏Tick", i, "===")
    bt:interrupt()  -- 清空节点栈和YIELD标记
    bt:run()
    -- api_Sleep(1000)
end
-- otherworld.run(bt)

-- local size =  WorldItems:Update()
-- api_Log(size .. "\n")
-- if size > 0 then
--     api_Log(size .. "\n")
--     local sum = 0;
--     for i = 0, size - 1, 1 do
--         sum = sum + 1
--         api_Log("index:" .. i .. " " .. WorldItems[i].name_utf8)
--         -- api_Log("index:" .. i .. " " .. WorldItems[i].baseType_utf8)
--     end

--     api_Log("sum:" .. sum .. "\n")

-- end
