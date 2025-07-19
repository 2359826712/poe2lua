local _M = {}  -- 主接口表
local json = require 'json'
local my_game_info = require 'my_game_info'

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
_M.find_text = function(text, UI_info, click, min_x, min_y, max_x, max_y, add_x, add_y, match, threshold, random_w, random_h, position)
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
_M.natural_move = function (target_x, target_y, random_w, random_h)

end

-- 步长
_M.extract_coordinates = function(vec2_array, step)
    -- 检查 vec2_array 是否为空或步长无效
    if not vec2_array or #vec2_array == 0 or step <= 0 then
        -- self:api_print("坐标数组为空或步长无效")
        return {}
    end

    -- 初始化结果表，包含起始点
    local result = {vec2_array[1]}
    -- 遍历中间点，根据步长提取
    for i = 2, #vec2_array - 1 do
        if (i + 1) % step == 0 then
            table.insert(result, vec2_array[i])
        end
    end
    
    -- 添加结束点
    table.insert(result, vec2_array[#vec2_array])
    
    return result
end


--- 打印 table 内容（递归处理嵌套 table）
-- @param tbl 要打印的 table
-- @param indent 缩进（可选，用于格式化嵌套 table）
_M.printTable = function(tbl, indentLevel, visited)
    indentLevel = indentLevel or 0
    local indent = string.rep("  ", indentLevel)
    visited = visited or {}  -- 用于检测循环引用

    if type(tbl) ~= "table" then
        print(indent .. "Value is not a table: " .. tostring(tbl))
        return
    end

    if next(tbl) == nil then  -- 检查空表
        print(indent .. "{}  -- empty table")
        return
    end

    visited[tbl] = true
    print(indent .. "{")
    
    for k, v in pairs(tbl) do
        local keyStr = "[" .. tostring(k) .. "] = "
        if type(v) == "table" then
            if visited[v] then
                print(indent .. "  " .. keyStr .. "<cycle reference>")
            else
                print(indent .. "  " .. keyStr)
                printTable(v, indentLevel + 1, visited)
            end
        else
            print(indent .. "  " .. keyStr .. tostring(v))
        end
    end
    
    print(indent .. "}")
end

-- 读取json文件
_M.load_config = function(path)
    local file = io.open(path, "r")  -- 打开文件
    if not file then
        error("Failed to open config file: " .. path)
    end
    local content = file:read("*a")  -- 读取全部内容 
    file:close()
    return json.decode(content)     -- 解析 JSON
end

-- 读取ini文件
_M.load_ini = function(path)
    local file = io.open(path, "r")
    if not file then
        error("Failed to open INI file: " .. path)
    end
    local config = {}
    local current_section = nil
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$"):gsub("[;#].*$", "")
        if #line > 0 then
            local section = line:match("^%[([^%]]+)%]$")
            if section then
                current_section = section
                config[current_section] = {}
            else
                local key, value = line:match("^([^=]+)=(.+)$")
                if key and value then
                    key, value = key:match("^%s*(.-)%s*$"), value:match("^%s*(.-)%s*$")
                    if current_section then
                        config[current_section][key] = value
                    else
                        config[key] = value
                    end
                end
            end
        end
    end
    file:close()
    return config
end

-- 将配置中优先级相关的键值对转换为排序后的键列表
_M.sort_map_by_key = function(tbl)
    local filtered = {}
    for k, v in pairs(tbl) do
        if v and type(v) == "number" and v > 0 then
            table.insert(filtered, {key = k, value = v})
        end
    end
    -- 按 value 升序排序
    table.sort(filtered, function(a, b) return a.value < b.value end)
    -- 提取排序后的 keys
    local sorted_keys = {}
    for _, item in ipairs(filtered) do
        table.insert(sorted_keys, item.key)
    end
    return sorted_keys
end

-- 检查游戏配置是否正确
_M.check_NCStorageLocalData_config = function(config_path)
    local check_list = {
        "auto_equip=false",
        "always_highlight=false",
        "disable_tutorials=true",
        "output_all_dialogue_to_chat=true",
        "show_global_chat=true",
        "show_chat_timestamps=true",
        "show_trade_chat=true",
        "show_guild_chat=true",
    }
    local function read_ini_lines(config_path)
        local file = io.open(config_path, "r")
        if not file then
            return nil, "无法打开文件: " .. config_path
        end
        
        local lines = {}
        for line in file:lines() do
            -- 保留每行的原始内容（包括换行符）
            table.insert(lines, line)
        end
        file:close()
        return lines  -- 返回包含所有行的表
    end
    local data_path = config_path .. "\\poe2_production_Config.ini"
    local file = read_ini_lines(data_path)
    if file then
        -- 检查每个配置项
        for _, value in ipairs(check_list) do
            for _, value1 in ipairs(file) do
                if value1 == value then
                    return true
                end
            end
        return false
        end
    return false
    end
end

-- 修改游戏配置
_M.set_NCStorageLocalData_config = function(config_path)
    local set_list = {
        -- {"TLGame.TLOption.SkillGatherTarget#2=false", "TLGame.TLOption.SkillGatherTarget#2=true"},  -- 自动锁定目标
        {"auto_equip=false", "auto_equip=true"},    -- 自动装备
        {"always_highlight=false", "always_highlight=true"},    -- 总是高光
        {"disable_tutorials=true", "disable_tutorials=false"},   -- 关闭教程
        {"output_all_dialogue_to_chat=true", "output_all_dialogue_to_chat=false"},
        {"show_global_chat=true", "show_global_chat=false"},
        {"show_chat_timestamps=true", "show_chat_timestamps=false"},
        {"show_trade_chat=true", "show_trade_chat=false"},
        {"show_guild_chat=true", "show_guild_chat=false"},
    }
    -- 检查文件是否存在
    local file = io.open(config_path, "r")
    if not file then
        print("配置文件不存在: " .. config_path)
        return false
    end
    -- 读取文件内容
    local content = file:read("*a")
    file:close()
    -- 进行替换
    for _, change in ipairs(set_list) do
        local from, to = change[1], change[2]
        content = content:gsub(from, to)
    end
    -- 写回文件
    file = io.open(config_path, "w")
    if not file then
        print("无法写入配置文件: " .. config_path)
        return false
    end
    file:write(content)
    file:close()
    return true
end

-- 结束游戏进程
_M.terminate_process = function(pid)
    --[[
    根据 PID 强制终止指定进程
    参数:
        pid: 要终止的进程PID（必须）
    返回:
        bool: True表示成功终止，False表示失败
    ]]--
    local handle = io.popen('taskkill /PID ' .. pid .. ' /F', 'r')
    local result = handle:read('*a')
    handle:close()
    if result:find("SUCCESS") then
        print(string.format("成功终止进程 (PID: %d)", pid))
        return true
    elseif result:find("not found") or result:find("不存在") then
        print(string.format("进程不存在 (PID: %d)", pid))
        return false
    elseif result:find("Access is denied") or result:find("拒绝访问") then
        print(string.format("权限不足，无法终止进程 (PID: %d)", pid))
        return false
    else
        print(string.format("终止进程失败 (PID: %d): %s", pid, result))
        return false
    end
end

-- 清除steam账号数据
_M.delete_steam_account_history = function(steam_path)
    steam_path = steam_path:gsub("/", "\\")
    
    -- 获取Steam安装目录（移除最后的steam.exe）
    local steam_dir = steam_path:match("^(.*)\\steam%.exe$") or steam_path:match("^(.*)/steam%.exe$")
    if not steam_dir then
        print("无效的Steam路径")
        return
    end
    
    -- 尝试删除 loginusers.vdf 文件
    local file_to_delete = steam_dir.."\\config\\loginusers.vdf"
    local file = io.open(file_to_delete, "r")
    if file then
        file:close()
        os.remove(file_to_delete)
    end
end

-- 启动steam或者终止steam/steamwebhelper进程
_M.exec_cmd = function(cmd)
    local handle = io.popen(cmd .. " 2>&1", "r")  -- 合并 stderr 到 stdout
    local output = handle:read("*a")
    local success, exit_code = handle:close()
    return exit_code or -1  -- 如果失败返回 -1
end

-- 是否有怪物
_M.is_have_mos = function(mos, player_info, dis, not_sight, stuck_monsters, not_attack_mos, is_active)
    -- 设置默认参数值
    dis = dis or 180
    not_sight = not_sight or 0
    stuck_monsters = stuck_monsters or nil
    not_attack_mos = not_attack_mos or nil
    is_active = (is_active == nil) and true or is_active  -- 默认true，但允许显式传false
    
    -- 参数有效性检查
    if type(dis) ~= "number" then
        error("距离参数dis必须是数值类型")
    end
    
    if not mos then
        return false
    end

    -- 确保玩家坐标有效
    if player_info.grid_x == nil or player_info.grid_y == nil then
        return false
    end
    
    -- 统一处理两种模式
    local check_sight = not_sight == 1
    
    for _, monster in ipairs(mos) do
        -- 使用正向条件和提前continue来优化逻辑
        if monster.type == 1 
           and monster.is_selectable
           and not monster.is_friendly
           
           and monster.life > 0
           and monster.grid_x 
           and monster.grid_y then
            -- and monster.name_utf8 
            -- and not my_game_info.not_attact_mons_path_name[monster.path_name_utf8]
            -- 检查不攻击的怪物
            local shouldAttack = true
            
            -- if not_attack_mos and not_attack_mos[monster.rarity] then
            --     shouldAttack = false
            -- end
            
            -- if shouldAttack and stuck_monsters and stuck_monsters[monster.id] then
            --     shouldAttack = false
            -- end
            
            -- if shouldAttack and is_active and not monster.isActive then
            --     shouldAttack = false
            -- end
            
            -- if shouldAttack and (poe2api.my_game_info.not_attact_mons_CN_name[monster.name_utf8] or 
            --    string.find(monster.name_utf8 or "", "神殿")) then
            --     shouldAttack = false
            -- end
            -- print(monster.name_utf8)
            if shouldAttack then
                -- 距离计算
                local dis_sq = _M.point_distance(monster.grid_x, monster.grid_y, player_info)
                if dis_sq <= dis then
                    -- 视野检查
                    if check_sight or monster.hasLineOfSight then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- 其他可能用到的API
_M.get_current_time = function()
    return os.time()
end

return _M