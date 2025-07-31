package.path = package.path .. ';./path/to/module/?.lua'

-- 每次加载时清除 otherworld 模块的缓存
-- api_Log("清除 otherworld 模块的缓存")
-- package.loaded['otherworld'] = nil

-- local otherworld = require 'otherworld'

-- 创建行为树
-- local bt = otherworld.create()

-- 查找文本
local function find_text(params)
    -- 设置默认值
    local defaults = {
        text = "",
        refresh = false,
        click = 0,
        min_x = 450,
        min_y = 0,
        max_x = 1595,
        max_y = 900,
        add_x = 0,
        add_y = 0,
        match = 0,
        threshold = 0.8,
        position = 0,
        sorted = false,
        UI_info = nil
    }
    -- 合并传入参数和默认值
    for k, v in pairs(params) do defaults[k] = v end

    if defaults.UI_info then
        if defaults.sorted then
            for _, actor in ipairs(defaults.UI_info) do
                
            end
        else
            for _, actor in ipairs(defaults.UI_info) do
               
            end
        end
        return false
    else
        return false
    end
end

i = 0
while true do
    i = i + 1
    
    -- 记录开始时间（毫秒）
    local start_time = api_GetTickCount64()  -- 转换为 ms
    
    -- bt:interrupt()  -- 清空节点栈和YIELD标记
    -- bt:run()

    local UI_info = UiElements:Update()

    api_Log(string.format("UiElements 耗时 --> ", api_GetTickCount64() - start_time))

    local current_time = api_GetTickCount64()  -- 转换为 ms
    -- 检测地图启动失败情况
    if find_text({UI_info = UI_info, text = "啟動失敗。地圖無法進入。"}) then
        api_Log("检测到地图启动失败提示，设置need_SmallRetreat为true")
        need_SmallRetreat = true
    end

    -- 定义所有需要检测的文本按钮及其参数
    local button_checks = {
        {UI_info = UI_info, text = "繼續遊戲", add_x = 0, add_y = 0, click = 2},
        {UI_info = UI_info, text = "寶石切割", add_x = 280, add_y = 17, click = 2},
        {UI_info = UI_info, text = "購買或販賣", add_x = 270, add_y = -9, click = 2},
        {UI_info = UI_info, text = "選擇藏身處", add_x = 516, click = 2},
        {UI_info = UI_info, text = "通貨交換", add_x = 300, click = 2},
        {UI_info = UI_info, text = "重組", add_x = 210, add_y = -50, click = 2},
        {UI_info = UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", add_x = 240, min_x = 0, click = 2},
        {UI_info = UI_info, text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片", add_x = 160, add_y = -60, min_x = 0, click = 2},
        {UI_info = UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2},
        {UI_info = UI_info, text = "精選", add_x = 677, min_x = 0, add_y = 10, click = 2}
    }
    
    -- 检查单个按钮
    for _, check in ipairs(button_checks) do
        if find_text(check) then
            api_Log(string.format("检测到按钮: %s，将执行点击操作", check.text))
        end
    end
    
    -- 检查顶部中间页面按钮
    local top_mid_page = {"傳送", "天賦技能", "世界地圖", "重置天賦點數", "Checkpoints"}
    if find_text({UI_info = UI_info, text = top_mid_page, min_x = 0, add_x = 215, click = 2}) then
        api_Log("检测到顶部中间页面按钮，将执行点击操作")
    end
    
    -- 检查仓库页面
    local warehouse_page = {"倉庫","聖域鎖櫃","公會倉庫"}
    if find_text({UI_info = UI_info, text = small_page, min_x = 0, add_x = 253, min_x = 0}) and 
    find_text({UI_info = UI_info, text = "强調物品", min_x = 0, min_x = 0}) then
        api_Log("检测到仓库页面，将执行点击操作")
        find_text({UI_info = UI_info, text = small_page, min_x = 0, click = 2, add_x = 253, min_x = 0})
    end
    
    
    -- 检查交易拒绝情况
    local refuse_click = {"等待玩家接受交易請求..."}
    if find_text({UI_info = UI_info, text = refuse_click, min_x = 0, add_x = 253, click = 2}) then
        api_Log("检测到交易请求等待，将执行拒绝操作")
    end
    
    -- 检查背包保存提示
    local save_click = {"你無法將此背包丟置於此。請問要摧毀它嗎？"}
    if find_text({UI_info = UI_info, text = save_click, min_x = 0, click = 2}) then
        api_Log("检测到背包保存提示，将执行保留操作")
    end

    
    -- 检查小页面按钮
    local small_page = {"背包","技能", "社交", "角色", "活動", "選項"}
    if find_text({UI_info = UI_info, text = small_page, min_x = 0, add_x = 253, min_x = 0, click = 2}) then
        api_Log("检测到小页面按钮，将执行点击操作")
    end
    
    api_Log("未检测到任何阻挡情况，模块返回SUCCESS状态")
    api_Log(string.format("Game_Block 耗时 --> ", api_GetTickCount64() - current_time))
    
    -- 计算当前 Tick 耗时（毫秒）
    local elapsed_ms = (api_GetTickCount64()) - start_time
    api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    api_Log(string.format("-------------------------------------------------------------------------------------------------------------"))
    -- 可选：控制打印频率（如每 N 次打印一次）
    -- if i % 10 == 0 then
    --     api_Log(string.format("Tick %d | 耗时: %.2f ms", i, elapsed_ms))
    -- end
end