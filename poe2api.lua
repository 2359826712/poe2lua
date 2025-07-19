local _M = {}  -- 主接口表

-- 子模块: af_api (障碍物检测相关)
_M.af_api = {
    --- 检测两点之间是否有障碍物
    -- @param x 目标点x坐标
    -- @param y 目标点y坐标
    -- @return boolean 是否有障碍物
    api_HasObstacleBetween = function(x, y)
        -- 实际实现应调用游戏引擎的障碍检测
        -- 这里是模拟实现：
        local has_obstacle = math.random() > 0.5  -- 50%概率返回有障碍
        print(string.format("[af_api] 检测障碍物 (%.1f,%.1f): %s", 
              x, y, has_obstacle and "有" or "无"))
        return has_obstacle
    end
}

--- 休眠
-- -- @param n 休眠时间(秒)
-- _M.sleep = function sleep(n)
--     if n > 0 then
--         os.execute("ping -n " .. tonumber(n + 1) .. " localhost > NUL")
--     end
-- end

--- 计算玩家与目标点的距离
-- @param x 目标点x坐标
-- @param y 目标点y坐标
-- @param player_info 玩家信息表
-- @return number 距离值
_M.point_distance = function(x, y, player_info)
    local dx = x - player_info.grid_x
    local dy = y - player_info.grid_y
    local distance = math.sqrt(dx*dx + dy*dy)
    -- print(string.format("[poe2_api] 距离计算: 玩家(%.1f,%.1f) -> 目标(%.1f,%.1f) = %.2f", 
    --       player_info.x, player_info.y, x, y, distance))
    return distance
end

--- 查找文本
-- @param text string 要查找的文本
-- @param UI_info table|nil UI信息表，可选
-- @param click number 点击模式：0-不点击，1-移动鼠标，2-左键点击，3-长按左键，4-ctrl+左键点击，5-ctrl+右键点击
-- @param min_x number 查找区域最小X坐标，默认450
-- @param min_y number 查找区域最小Y坐标，默认0
-- @param max_x number 查找区域最大X坐标，默认1595
-- @param max_y number 查找区域最大Y坐标，默认900
-- @param add_x number X坐标额外偏移量，默认0
-- @param add_y number Y坐标额外偏移量，默认0
-- @param match number 匹配模式：0-精确匹配，1-相似度匹配，2-包含匹配
-- @param threshold number 相似度阈值，默认0.8
-- @param random_w number 随机宽度偏移，默认10
-- @param random_h number 随机高度偏移，默认10
-- @param position number 返回位置模式：0-返回布尔值，1-返回矩形坐标，2-返回actor对象，3-返回中心坐标
-- @return boolean|table 查找结果，根据position参数返回不同类型
function _M.find_text(text, UI_info, click, min_x, min_y, max_x, max_y, add_x, add_y, match, threshold, random_w, random_h, position)
    -- 参数默认值处理
    click = click or 0
    min_x = min_x or 450
    min_y = min_y or 0
    max_x = max_x or 1595
    max_y = max_y or 900
    add_x = add_x or 0
    add_y = add_y or 0
    match = match or 0
    threshold = threshold or 0.8
    random_w = random_w or 10
    random_h = random_h or 10
    position = position or 0
    
    local start_time = os.time()
    
    -- 如果没有传入UI信息，则调用API获取
    if not UI_info then
        if match == 0 then
            UI_info = af_api.api_GetGameControl("", min_x, min_y, 1600, 900, text, 0)
        else
            UI_info = af_api.api_GetGameControl("", 0, 0, 1600, 900, "", 0)
        end
    end
    
    if UI_info then
        -- 相似度匹配模式
        if match == 1 then
            for _, actor in ipairs(UI_info) do
                -- 计算文本相似度
                local similarity = string.similarity(text, actor.text_utf8)
                if similarity >= threshold and min_x <= actor.left and actor.left <= max_x and min_y <= actor.top and actor.top <= max_y then
                    -- 计算中心位置
                    local center_x = (actor.left + actor.right) / 2
                    local center_y = (actor.top + actor.bottom) / 2
                    local x, y = center_x, center_y
                    
                    -- 根据点击模式执行不同操作
                    if click == 1 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                    elseif click == 2 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                        sleep(0.3)
                        af_api.api_LeftClick()
                        sleep(0.2)
                    elseif click == 3 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                        local hold_time = 8
                        af_api.api_LeftDown()
                        for _ = 1, math.floor(hold_time * 2) do
                            sleep(0.5)
                            af_api.api_MoveToEx(math.floor(x + add_x), math.floor(y + add_y), 2, 2)
                        end
                        af_api.api_LeftUp()
                    elseif click == 4 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                        _M.ctrl_left_click(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                    end
                    
                    -- 根据position参数返回不同结果
                    if position == 1 then
                        return {actor.left, actor.top, actor.right, actor.bottom}
                    elseif position == 2 then
                        return actor
                    elseif position == 3 then
                        return {math.floor(x + add_x), math.floor(y + add_y)}
                    end
                    return true
                end
            end
        end
        
        -- 精确匹配或包含匹配模式
        for _, actor in ipairs(UI_info) do
            if min_x <= actor.left and actor.left <= max_x and min_y <= actor.top and actor.top <= max_y then
                -- 检查文本匹配条件
                local text_match = false
                if match == 2 then
                    text_match = string.find(actor.text_utf8, text) ~= nil
                else
                    text_match = actor.text_utf8 == text
                end
                
                if text_match then
                    -- 计算中心位置
                    local center_x = (actor.left + actor.right) / 2
                    local center_y = (actor.top + actor.bottom) / 2
                    local x, y = center_x, center_y
                    
                    -- 根据点击模式执行不同操作
                    if click == 1 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                    elseif click == 2 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                        sleep(0.3)
                        af_api.api_LeftClick()
                        sleep(0.2)
                    elseif click == 3 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                        local hold_time = 8
                        af_api.api_LeftDown()
                        sleep(hold_time)
                        af_api.api_LeftUp()
                    elseif click == 4 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                        sleep(0.3)
                        _M.ctrl_left_click(math.floor(x + add_x), math.floor(y + add_y))
                    elseif click == 5 then
                        _M.natural_move(math.floor(x + add_x), math.floor(y + add_y), random_w, random_h)
                        sleep(0.3)
                        _M.ctrl_right_click(math.floor(x + add_x), math.floor(y + add_y))
                    end
                    
                    -- 根据position参数返回不同结果
                    if position == 1 then
                        return {actor.left, actor.top, actor.right, actor.bottom}
                    elseif position == 2 then
                        return actor
                    elseif position == 3 then
                        return {math.floor(x + add_x), math.floor(y + add_y)}
                    end
                    return true
                end
            end
        end
    end
    
    return false
end

--- 增强随机性拟真移动（智能禁用近距离抖动）
-- @param target_x number 目标X坐标
-- @param target_y number 目标Y坐标
-- @param random_w number 随机宽度偏移，默认0
-- @param random_h number 随机高度偏移，默认0
function _M.natural_move(target_x, target_y, random_w, random_h)

end

-- 其他可能用到的API
_M.get_current_time = function()
    return os.time()
end

return _M