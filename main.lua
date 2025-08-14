package.path = package.path .. ';./path/to/module/?.lua'

-- 每次加载时清除 otherworld 模块的缓存
api_Log("清除 plot 模块的缓存")
package.loaded['plot'] = nil

local plot = require 'script/plot'

-- 创建行为树
local bt = plot.create()

i = 0
while true do
    i = i + 1
    
    -- 记录开始时间（毫秒）
    local start_time = api_GetTickCount64()  -- 转换为 ms
    
    bt:interrupt()  -- 清空节点栈和YIELD标记
    bt:run()
    -- a = Actors:Update()
    -- api_Log(#a)
    
    -- 计算当前 Tick 耗时（毫秒）
    -- local a = api_FindPath(793,250,611,378)
    -- if a and next(a) then
    --     api_Log("11111")
    -- else
    --     api_Log("22222")
    -- end
    -- 793,250} -> {611,378
    local elapsed_ms = (api_GetTickCount64()) - start_time
    api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    api_Log(string.format("-------------------------------------------------------------------------------------------------------------"))

    -- 可选：控制打印频率（如每 N 次打印一次）
    -- if i % 10 == 0 then
    --     api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    --     api_Log(string.format("-------------------------------------------------------------------------------------------------------------"))
    -- end
end