local _M = {} -- 主接口表
local json = require 'json'
local my_game_info = require 'my_game_info'


local CELL_WIDTH = 43.81  -- 每个格子宽度
local CELL_HEIGHT = 43.81  -- 每个格子高度
local START_X = 1059   -- 起始X坐标
local START_Y = 492    -- 起始Y坐标
local START_X_STORE = 12   -- 起始X坐标
local START_Y_STORE = 102 

_M.point_distance = function(x, y, ac)
    -- 检查 x, y 是否为有效数字
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil -- 或者返回 nil，取决于你的需求
    end

    -- 检查 ac 是否有效
    if not ac then
        return nil -- 如果 ac 是 nil，直接返回 0 或 nil
    end

    -- 确定玩家坐标
    local player_x, player_y
    if type(ac) == "table" then
        player_x = ac[1] or 0 -- 如果 ac[1] 是 nil，默认 0
        player_y = ac[2] or 0 -- 如果 ac[2] 是 nil，默认 0
    else
        player_x = ac.grid_x or 0 -- 如果 grid_x 不存在，默认 0
        player_y = ac.grid_y or 0 -- 如果 grid_y 不存在，默认 0
    end

    -- 计算距离
    local dx = x - player_x
    local dy = y - player_y

    local distance = math.sqrt(dx * dx + dy * dy)

    return distance or nil -- 确保返回值有效
end

-- 查找文本函数
--- 在指定区域内查找文本并执行点击操作
-- @param params 参数表，包含以下可选字段：
--   text: 要查找的文本内容
--   UI_info: UI元素信息表
--   click: 点击类型(0不点击,1左键,2右键,3长按,4Ctrl+左键,5Ctrl+右键)
--   min_x, min_y, max_x, max_y: 搜索区域坐标范围
--   add_x, add_y: 点击位置偏移量
--   match: 匹配模式(0精确匹配,2模糊匹配)
--   threshold: 匹配阈值(默认0.8)
--   position: 返回位置信息(0不返回,1返回矩形坐标,2返回完整元素,3返回中心点坐标)
-- @return 根据position参数返回不同结果，默认返回操作是否成功
_M.find_text = function(params)
    -- 设置默认值
    local defaults = {
        text = "",
        UI_info = nil,
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
    }
    -- 合并 params
    for k, v in pairs(params) do
        defaults[k] = v
    end
    if (not defaults.UI_info) or #defaults.UI_info == 0 then
        _M.dbgp("find_text没有找到UI信息")
        return false
    end

    if defaults.UI_info then
        if defaults.sorted then
            -- _M.dbgp("paixvvvvvvvv")
            local text_list = {}
            for _, actor in ipairs(defaults and defaults.UI_info or {}) do
                if actor.text_utf8 ~= nil and actor.text_utf8 ~= "" then
                    -- _M.dbgp(actor.text_utf8)
                    if defaults.min_x <= actor.left and actor.left <=
                        defaults.max_x and defaults.min_y <= actor.top and
                        actor.top <= defaults.max_y then
                        if defaults.match == 2 then
                            for _, v in ipairs(defaults.text) do
                                if string.find(actor.text_utf8, v) then
                                    table.insert(text_list, actor)
                                end
                            end
                        else
                            for _, v in ipairs(defaults.text) do
                                if v == text then
                                    table.insert(text_list, actor)
                                end
                            end
                        end
                    end
                end
            end

            local function target_distance(actor)
                -- 计算与玩家的距离
                local distance = math.sqrt(
                                     (actor.left - 800) ^ 2 + (actor.top - 450) ^
                                         2)
                return distance
            end

            if text_list and #text_list > 0 then
                table.sort(text_list, function(a, b)
                    return target_distance(a) < target_distance(b)
                end)

                local center_x = (text_list[1].left + text_list[1].right) / 2
                local center_y = (text_list[1].top + text_list[1].bottom) / 2
                local x, y = center_x, center_y

                if click == 1 then
                    api_ClickScreen(math.floor(x + defaults.add_x),
                                    math.floor(y + defaults.add_y), 0)
                elseif click == 2 then
                    api_ClickScreen(math.floor(x + defaults.add_x),
                                    math.floor(y + defaults.add_y), 0)
                    api_Sleep(200)
                    api_ClickScreen(math.floor(x + defaults.add_x),
                                    math.floor(y + defaults.add_y), 1)
                end

                return true -- 找到符合条件的 actor，返回成功
            end

        else
            for _, actor in ipairs(defaults and defaults.UI_info or {}) do
                if defaults.min_x <= actor.left and actor.left <= defaults.max_x and
                    defaults.min_y <= actor.top and actor.top <= defaults.max_y then
                    local shouldProcess = true
                    local function text_data(text)
                        if defaults.match == 2 then
                            for _, v in ipairs(defaults.text) do
                                if string.find(actor.text_utf8, v) then
                                    return true
                                end
                            end
                        else
                            for _, v in ipairs(defaults.text) do
                                if v == text then
                                    return true
                                end
                            end
                        end
                        return false
                    end
                    if defaults.match == 2 then
                        if type(defaults.text) ~= "string" then
                            if not text_data(actor.text_utf8) then
                                shouldProcess = false
                            end
                        else

                            if not string.find(actor.text_utf8, defaults.text) then
                                shouldProcess = false
                            end
                        end
                    else
                        if type(defaults.text) ~= "string" then
                            if not text_data(actor.text_utf8) then
                                shouldProcess = false
                            end
                        else
                            if actor.text_utf8 ~= defaults.text then
                                shouldProcess = false
                            end
                        end
                    end
                    if shouldProcess then
                        local center_x = (actor.left + actor.right) / 2
                        local center_y = (actor.top + actor.bottom) / 2
                        local x, y = center_x, center_y

                        if defaults.click == 1 then
                            api_ClickScreen(math.floor(x + defaults.add_x),
                                            math.floor(y + defaults.add_y), 0)
                        elseif defaults.click == 2 then
                            api_ClickScreen(math.floor(x + defaults.add_x),
                                    math.floor(y + defaults.add_y), 0)
                            api_Sleep(200)
                            api_ClickScreen(math.floor(x + defaults.add_x),
                                            math.floor(y + defaults.add_y), 1)
                        elseif defaults.click == 3 then
                            local hold_time = 8
                            api_ClickScreen(math.floor(x + defaults.add_x),
                                            math.floor(y + defaults.add_y), 3)
                            api_Sleep(hold_time * 1000)
                            api_ClickScreen(math.floor(x + defaults.add_x),
                                            math.floor(y + defaults.add_y), 4)
                        elseif defaults.click == 4 then
                            _M.ctrl_left_click(math.floor(x + defaults.add_x),
                                               math.floor(y + defaults.add_y))
                        elseif defaults.click == 5 then
                            _M.ctrl_right_click(math.floor(x + defaults.add_x),
                                                math.floor(y + defaults.add_y))
                        end

                        if defaults.position == 1 then
                            return {
                                actor.left, actor.top, actor.right, actor.bottom
                            }
                        elseif defaults.position == 2 then
                            return actor
                        elseif defaults.position == 3 then
                            return {
                                math.floor(x + defaults.add_x),
                                math.floor(y + defaults.add_y)
                            }
                        end
                        return true
                    end
                end
            end
        end
        return false
    else
        return false
    end
end

-- 步长
_M.extract_coordinates = function(vec2_array, step)
    -- 检查 vec2_array 是否为空或步长无效
    if not vec2_array or #vec2_array == 0 or step <= 0 then
        return {}
    end

    -- 初始化结果表，包含起始点
    local result = {vec2_array[1]}
    -- 遍历中间点，根据步长提取
    for i = 2, #vec2_array - 1 do
        if (i + 1) % step == 0 then table.insert(result, vec2_array[i]) end
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
    visited = visited or {} -- 用于检测循环引用

    if type(tbl) ~= "table" then
        _M.dbgp(indent .. "Value is not a table: " .. tostring(tbl))
        return
    end

    if next(tbl) == nil then -- 检查空表
        _M.dbgp(indent .. "{}  -- empty table")
        return
    end

    visited[tbl] = true
    _M.dbgp(indent .. "{")

    for k, v in pairs(tbl) do
        local keyStr = "[" .. tostring(k) .. "] = "
        if type(v) == "table" then
            if visited[v] then
                _M.dbgp(indent .. "  " .. keyStr .. "<cycle reference>")
            else
                _M.dbgp(indent .. "  " .. keyStr)
                _M.dbgp(v, indentLevel + 1, visited)
            end
        else
            _M.dbgp(indent .. "  " .. keyStr .. tostring(v))
        end
    end

    _M.dbgp(indent .. "}")
end

-- 读取json文件
_M.load_config = function(path)
    local file = io.open(path, "r") -- 打开文件
    if not file then error("Failed to open config file: " .. path) end
    local content = file:read("*a") -- 读取全部内容 
    file:close()
    return json.decode(content) -- 解析 JSON
end

-- 读取ini文件
_M.load_ini = function(path)
    local file = io.open(path, "r")
    if not file then error("Failed to open INI file: " .. path) end
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
                    key, value = key:match("^%s*(.-)%s*$"),
                                 value:match("^%s*(.-)%s*$")
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
    for _, item in ipairs(filtered) do table.insert(sorted_keys, item.key) end
    return sorted_keys
end

-- 检查游戏配置是否正确
_M.check_NCStorageLocalData_config = function(config_path)
    local check_list = {
        "auto_equip=false", "always_highlight=false", "disable_tutorials=true",
        "output_all_dialogue_to_chat=true", "show_global_chat=true",
        "show_chat_timestamps=true", "show_trade_chat=true",
        "show_guild_chat=true"
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
        return lines -- 返回包含所有行的表
    end
    local data_path = config_path .. "\\poe2_production_Config.ini"
    local file = read_ini_lines(data_path)
    if file then
        -- 检查每个配置项
        for _, value in ipairs(check_list) do
            for _, value1 in ipairs(file) do
                if value1 == value then return true end
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
        {"auto_equip=false", "auto_equip=true"}, -- 自动装备
        {"always_highlight=false", "always_highlight=true"}, -- 总是高光
        {"disable_tutorials=true", "disable_tutorials=false"}, -- 关闭教程
        {
            "output_all_dialogue_to_chat=true",
            "output_all_dialogue_to_chat=false"
        }, {"show_global_chat=true", "show_global_chat=false"},
        {"show_chat_timestamps=true", "show_chat_timestamps=false"},
        {"show_trade_chat=true", "show_trade_chat=false"},
        {"show_guild_chat=true", "show_guild_chat=false"}
    }
    -- 检查文件是否存在
    local file = io.open(config_path, "r")
    if not file then
        _M.dbgp("配置文件不存在: " .. config_path)
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
        _M.dbgp("无法写入配置文件: " .. config_path)
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
    ]] --
    local handle = io.popen('taskkill /PID ' .. pid .. ' /F', 'r')
    local result = handle:read('*a')
    handle:close()
    if result:find("SUCCESS") then
        _M.dbgp(string.format("成功终止进程 (PID: %d)", pid))
        return true
    elseif result:find("not found") or result:find("不存在") then
        _M.dbgp(string.format("进程不存在 (PID: %d)", pid))
        return false
    elseif result:find("Access is denied") or result:find("拒绝访问") then
        _M.dbgp(string.format(
                         "权限不足，无法终止进程 (PID: %d)", pid))
        return false
    else
        _M.dbgp(string.format("终止进程失败 (PID: %d): %s", pid,
                                   result))
        return false
    end
end

-- 清除steam账号数据
_M.delete_steam_account_history = function(steam_path)
    steam_path = steam_path:gsub("/", "\\")

    -- 获取Steam安装目录（移除最后的steam.exe）
    local steam_dir = steam_path:match("^(.*)\\steam%.exe$") or
                          steam_path:match("^(.*)/steam%.exe$")
    if not steam_dir then
        _M.dbgp("无效的Steam路径")
        return
    end

    -- 尝试删除 loginusers.vdf 文件
    local file_to_delete = steam_dir .. "\\config\\loginusers.vdf"
    local file = io.open(file_to_delete, "r")
    if file then
        file:close()
        os.remove(file_to_delete)
    end
end

-- 启动steam或者终止steam/steamwebhelper进程
_M.exec_cmd = function(cmd)
    local handle = io.popen(cmd .. " 2>&1", "r") -- 合并 stderr 到 stdout
    local output = handle:read("*a")
    local success, exit_code = handle:close()
    return exit_code or -1 -- 如果失败返回 -1
end

-- 安全转为整数（带空值处理）
_M.toExactInt = function(value, default)
    -- 默认值处理（如果传入default参数）
    if value == nil then
        return default or 0  -- 可自定义默认值
    end

    -- 类型检查
    local value_type = type(value)
    
    -- 已经是整数
    if math.type(value) == "integer" then
        return value
    end
    
    -- 数字类型处理
    if value_type == "number" then
        -- 检查是否为NaN/Infinity
        if value ~= value then return default or 0 end  -- NaN检查
        if math.abs(value) == math.huge then return default or 0 end  -- 无穷大检查
        
        -- 四舍五入（处理-0.5~0.5范围特殊情况）
        local rounded = math.floor(value + 0.5)
        
        -- 溢出检查（Lua 5.3+ 整数范围）
        if math.type(rounded) == "integer" then
            return rounded
        else
            return default or 0
        end
    end
    
    -- 字符串类型尝试转换
    if value_type == "string" then
        local num = tonumber(value:match("^%s*(-?%d+)%s*$"))
        if num then return math.floor(num) end
    end
    
    -- 其他类型返回默认值
    return default or 0
end

--- 检查是否存在符合条件的怪物
_M.is_have_mos = function(params)
    -- 参数默认值与校验
    mos = params.mos or {}
    player_info = params.player_info
    dis = params.dis or 180
    not_sight = params.not_sight or 0
    stuck_monsters = params.stuck_monsters or nil
    not_attack_mos = params.not_attack_mos or nil
    is_active = params.is_active == nil and true or is_active

    -- 快速失败检查
    if not params.mos or not params.player_info then 
        return false 
    end
    
    -- 预处理常量
    local check_sight = params.not_sight == 1

    -- 怪物检查主逻辑
    for _, monster in ipairs(params.mos) do
        -- 快速跳过不符合基本条件的怪物
        if monster.type ~= 1 or                  -- 类型检查
        not monster.is_selectable or          -- 可选性检查
        monster.is_friendly or                -- 友方检查
        monster.life <= 0 or                  -- 生命值检查
        not monster.name_utf8 or              -- 名称检查
        _M.table_contains(my_game_info.not_attact_mons_CN_name,monster.name_utf8) or
        _M.table_contains(my_game_info.not_attact_mons_path_name,monster.name_utf8)then  -- 路径名检查
            goto continue
        end

        if params.is_active and not monster.isActive then
            goto continue
        end

        -- 检查坐标有效性
        if not monster.grid_x or not monster.grid_y then
            goto continue
        end

        -- 检查不攻击的怪物
        _M.print_log("检查不攻击的怪物")
        if params.not_attack_mos then
            if _M.table_contains(params.not_attack_mos,monster.rarity) then
                goto continue
            end
        end

        -- 检查卡住状态
        if params.stuck_monsters and _M.table_contains(params.stuck_monsters,monster.id) then
            goto continue
        end

        -- 计算距离
        local distance = _M.point_distance(monster.grid_x, monster.grid_y, player_info)
        if distance and distance <= dis then
            -- 检查视野
            if not check_sight or monster.hasLineOfSight then
                return true
            end
        end
        
        ::continue::
    end
    
    return false
end

-- 检查值是否在表中（不严格要求参数顺序）
_M.table_contains = function(a, b)
    -- 自动判断哪个是 table，哪个是 value
    local tbl, value
    if type(a) == "table" then
        tbl, value = a, b
    else
        tbl, value = b, a
    end

    -- 如果传入的 tbl 不是 table，直接返回 false
    if type(tbl) ~= "table" then return false end

    -- 遍历检查（支持 ipairs 遍历数组部分）
    for _, v in ipairs(tbl) do if v == value then return true end end
    return false
end

-- 是否有Boss
_M.is_have_mos_boss = function(mos, boss_list)
    if not mos or not boss_list then return false end

    BOSS_WHITELIST = {'多里亞尼'}
    MOB_BLACKLIST = {"惡魔", '複製體', "隱形", "複製之躰"}
    rarity_list = {2, 3}

    for _, monster in ipairs(mos) do
        if monster.is_selectable and not monster.is_friendly and monster.life >
            0 and monster.name_utf8 and
            (monster.rarity == 2 or monster.rarity == 3) then
            -- 通用Boss判断
            if not _M.table_contains(monster.name_utf8, MOB_BLACKLIST) and
                monster.isActive and
                (_M.table_contains(monster.name_utf8, boss_list) or monster.life >
                    0) then return true end
        end
    end
    -- _M.dbgp("没有Boss")
    return false
end

--- 模拟键盘按键操作
-- @param click_str string 按键字符串（如"A", "Enter"等）
-- @param[opt] click_type number 按键类型：0=单击, 1=按下, 2=抬起
_M.click_keyboard = function(click_str, click_type)
    -- 参数默认值处理
    click_type = click_type or 0
    local key_code = my_game_info.ascii_dict[click_str:lower()]
    if click_type == 0 then
        api_Keyboard(key_code, 2)
    elseif click_type == 1 then
        api_Keyboard(key_code, 0)
    elseif click_type == 2 then
        api_Keyboard(key_code, 1)
    end
end

-- 左ctrl+左键
_M.ctrl_left_click = function(x, y)
    if x and y then
        _M.click_keyboard('ctrl', 1) -- 使用正确的按键代码
        api_Sleep(100) -- 0.1秒 = 100毫秒
        api_ClickScreen(math.floor(x), math.floor(y), 1) -- 使用click方法模拟左键点击
        api_Sleep(100)
        _M.click_keyboard('ctrl', 2) -- 使用正确的按键代码
    end
end

-- 右键
_M.right_click = function(x, y)
    if x and y then
        api_ClickScreen(math.floor(x), math.floor(y), 0) 
        api_Sleep(100) -- 0.1秒 = 100毫秒
        api_ClickScreen(math.floor(x), math.floor(y), 2)
    end
end

-- 获取背包物品中心点（Lua优化版）
_M.get_center_position = function(start_cell, end_cell)
    -- 参数验证（Lua中使用table代替tuple）
    if not (type(start_cell) == "table" and #start_cell == 2 and
            type(end_cell) == "table" and #end_cell == 2) then
        error("参数必须是包含2个数字的表格，格式示例：{row, col}")
    end

    -- 解构赋值
    local start_row, start_col = start_cell[1], start_cell[2]
    local end_row, end_col = end_cell[1], end_cell[2]

    -- 验证布局参数
    if not (START_X and START_Y and 
            CELL_WIDTH and CELL_HEIGHT) then
        error("缺少必要的布局参数：START_X/START_Y/CELL_WIDTH/CELL_HEIGHT")
    end

    -- 计算中心坐标（优化计算顺序减少括号嵌套）
    local center_x = START_X + (start_row + end_row) * 0.5 * CELL_WIDTH
    local center_y = START_Y + (start_col + end_col) * 0.5 * CELL_HEIGHT

    -- 四舍五入（Lua标准实现）
    return math.floor(center_x + 0.5), math.floor(center_y + 0.5)
end

-- 获取仓库物品中心点（改进版）
_M.get_center_position_store = function(start_cell, end_cell)
    -- 更健壮的参数检查（Lua中实际使用table而非tuple）
    if not (type(start_cell) == "table" and #start_cell == 2 and
            type(end_cell) == "table" and #end_cell == 2) then
        error("参数必须是包含2个数字的表格，格式示例：{row, col}")
    end
    
    local start_row, start_col = start_cell[1], start_cell[2]
    local end_row, end_col = end_cell[1], end_cell[2]

    -- 计算中心位置（添加参数有效性验证）
    if not (START_X_STORE and CELL_WIDTH and START_Y_STORE and CELL_HEIGHT) then
        error("缺少必要的布局参数")
    end
    
    local center_x = START_X_STORE + ((start_row + end_row) / 2) * CELL_WIDTH
    local center_y = START_Y_STORE + ((start_col + end_col) / 2) * CELL_HEIGHT

    -- 使用数学库的四舍五入
    return {math.floor(center_x + 0.5), math.floor(center_y + 0.5)}
end

-- 快速点击仓库物品
_M.ctrl_left_click_store_items = function(target_name, store_info, click_type)
    if not store_info or type(store_info) ~= "table" then
        _M.dbgp("仓库信息无效")
        return false
    end

    for _, actor in ipairs(store_info) do
        -- 更安全的属性访问和条件判断
        local match = actor.baseType_utf8 and 
                     (actor.baseType_utf8 == target_name or 
                      (actor.obj and actor.obj == target_name))
        
        if match then
            -- 添加坐标有效性检查
            if not (actor.start_x and actor.start_y and actor.end_x and actor.end_y) then
                _M.dbgp("对象坐标信息不完整")
                return false
            end

            local center_x, center_y = _M.get_center_position_store(
                {actor.start_x, actor.start_y},
                {actor.end_x, actor.end_y}
            )

            -- 支持左键/右键点击
            if click_type == 1 then  
                _M.right_click(center_x, center_y)
            else
                _M.ctrl_left_click(center_x, center_y)
            end

            return true
        end
    end

    _M.dbgp(("未找到目标对象: %s"):format(target_name))
    return false
end

-- 左ctrl+右键
_M.ctrl_right_click = function(x, y)
    if x and y then
        _M.click_keyboard('ctrl', 1) -- 使用正确的按键代码
        api_Sleep(100)
        api_ClickScreen(math.floor(x), math.floor(y), 2) -- 使用click方法模拟右键点击
        api_Sleep(100)
        _M.click_keyboard('ctrl', 2) -- 使用正确的按键代码
    end
end

-- 日志打印（适配 api_Log，使其输出和 print 一致）
_M.print_log = function(...)
    local args = {...}
    local parts = {}

    -- 把每个参数转成字符串（模拟 print 的行为）
    for i, v in ipairs(args) do parts[i] = tostring(v) end

    -- 用制表符（\t）连接多个参数，并加上换行符（\n）
    local formattedText = table.concat(parts, "\t") .. "\n"

    -- 调用 api_Log（假设它只接受一个字符串参数）
    api_Log(formattedText)
    -- print(formattedText)
end

-- 调试打印(带时间)
_M.dbgp = function(...)
    local args = {...}
    local parts = {}

    -- 把每个参数转成字符串（模拟 print 的行为）
    for i, v in ipairs(args) do parts[i] = tostring(v) end

    -- 用制表符（\t）连接多个参数，并加上换行符（\n）
    local formattedText = table.concat(parts, "\t") .. "\n"

    -- 调用 api_Log（假设它只接受一个字符串参数）
    api_Log(formattedText)
    -- api_Sleep(1000000)
    -- print(formattedText)
end

-- 友方目標對象
--- 查找符合条件的友好目标对象
-- @param args 参数表，包含以下字段：
--   mos: 怪物列表
--   player_info: 玩家信息
--   valid_monsters: 可用怪物列表(可选)
--   dis: 搜索距离(默认180)
--   not_sight: 是否检查视野(默认0)
--   find_farthest: 是否查找最远目标(默认false)
-- @return 返回符合条件的友好目标对象，若无则返回nil
_M.friendly_target_object = function(args)
    local params = {
        mos = {}, -- 怪物列表
        player_info = {}, -- 玩家信息
        valid_monsters = {}, -- 可用怪物列表
        dis = 180, -- 搜索距离
        not_sight = 0, -- 是否检查视野
        find_farthest = false -- 是否查找最远目标
    }
    -- 合并传入参数和默认值
    for k, v in pairs(args) do params[k] = v end

    -- 参数有效性检查
    if not params.mos or not params.player_info then return nil end

    -- 确保玩家坐标有效
    if not params.player_info.grid_x or not params.player_info.grid_y then
        return nil
    end

    -- 预计算距离平方
    local dis_sq = params.dis * params.dis

    local target_friendly = nil
    -- 根据查找模式初始化距离比较值
    local compare_distance_sq = params.find_farthest and -math.huge or math.huge

    for _, unit in ipairs(params.mos) do
        -- 检查坐标有效性
        if not unit.grid_x or not unit.grid_y then goto continue end
        -- 排除玩家自身（如果启用）
        if unit.name_utf8 and unit.name_utf8 == params.player_info.name_utf8 then
            goto continue
        end
        -- 基础条件检查
        if not (unit.name_utf8 and unit.is_friendly) then goto continue end

        -- 名称过滤
        if my_game_info.not_attact_mons_CN_name[unit.name_utf8] or
            string.find(unit.name_utf8, "神殿") then goto continue end

        -- 距离计算（使用valid_monsters或player_info作为基准点）
        local base = valid_monsters or player_info
        local dx = unit.grid_x - base.grid_x
        local dy = unit.grid_y - base.grid_y
        local distance_sq = dx * dx + dy * dy

        -- 超出搜索范围
        if distance_sq > dis_sq then goto continue end

        -- 根据查找模式更新目标
        if (params.find_farthest and distance_sq > compare_distance_sq) or
            (not params.find_farthest and distance_sq < compare_distance_sq) then
            compare_distance_sq = distance_sq
            target_friendly = unit
        end

        ::continue::
    end

    return target_friendly
end

-- 敵對死亡目標對象（返回最近對象）
--- 查找最近的死亡敌对怪物目标
-- @param args 参数表，包含以下字段：
--   mos: 怪物列表
--   player_info: 玩家信息(必须包含grid_x/grid_y坐标)
--   dis: 搜索距离(默认180)
--   not_sight: 是否检查视野(0=检查,1=不检查)
-- @return table|nil 返回符合条件的最近怪物对象，未找到返回nil
-- @note 会过滤神殿类怪物和配置表中不攻击的怪物
_M.enemy_death_target_object = function(args)
    local params = {
        mos = {}, -- 怪物列表
        player_info = {}, -- 玩家信息
        dis = 180, -- 搜索距离
        not_sight = 0 -- 是否检查视野
    }
    -- 合并传入参数和默认值
    for k, v in pairs(args) do params[k] = v end
    -- 参数有效性检查
    if not params.mos or not params.player_info then return nil end

    -- 确保玩家坐标有效
    if not params.player_info.grid_x or not params.player_info.grid_y then
        return nil
    end

    -- 预计算距离平方
    local dis_sq = params.dis * params.dis
    local check_sight = params.not_sight == 1

    local nearest_monster = nil
    local min_distance_sq = math.huge
    for _, monster in ipairs(params.mos) do
        -- 检查坐标有效性
        if not monster.grid_x or not monster.grid_y then goto continue end
        -- 基础条件检查
        if not (monster.name_utf8 and monster.life == 0 and
            not monster.is_friendly and monster.isActive and monster.type == 1) then
            goto continue
        end
        -- 名称过滤
        if my_game_info.not_attact_mons_CN_name[monster.name_utf8] or
            string.find(monster.name_utf8, "神殿") then goto continue end

        -- 距离计算
        local dx = monster.grid_x - player_info.grid_x
        local dy = monster.grid_y - player_info.grid_y
        local distance_sq = dx * dx + dy * dy
        -- 超出搜索范围
        if distance_sq > dis_sq then goto continue end

        -- 视野检查
        if monster.hasLineOfSight then
            -- 更新最近目标
            if distance_sq < min_distance_sq then
                min_distance_sq = distance_sq
                nearest_monster = monster
            end
        end

        ::continue::
    end

    return nearest_monster
end

-- 创建新的怪物监视器
--- @param threshold number 触发阈值(默认40)
-- @return table 返回怪物监视器对象
-- @note 监视器对象包含以下方法:
--   parse_count(text): 解析文本中的怪物数量
--   check_and_act(game_controls): 检查并执行动作
_M.monster_monitor = function(threshold, game_controls)
    threshold = threshold or 40
    local pattern = "剩餘 (%d+) 隻怪物"

    for _, control in ipairs(game_controls) do
        if control.text_utf8 then
            local text = control.text_utf8 and
                             control.text_utf8:match("^%s*(.-)%s*$") or ""
            local count = text:match(pattern)
            count = tonumber(count)

            if count and count <= threshold then
                return int(count) <= threshold
            end
        end
    end
    return false
end

-- 选择异界地图
_M.get_map = function(params)
    -- 解析参数表
    local otherworld_info = params.otherworld_info or {}
    local sorted_map = params.sorted_map or {}
    local not_enter_map = params.not_enter_map or {}
    local bag_info = params.bag_info or {}
    local key_level_threshold = params.key_level_threshold
    local not_use_map = params.not_use_map or {}
    local priority_map = params.priority_map or {}
    local entry_length = params.entry_length
    local error_other_map = params.error_other_map or {}
    local not_have_stackableCurrency = params.not_have_stackableCurrency or
                                           false

    -- _M.dbgp("[DEBUG] 开始执行 get_map 函数")
    -- _M.dbgp("[DEBUG] 参数信息:")
    -- _M.dbgp("[DEBUG] - otherworld_info 数量: " .. #otherworld_info)
    -- _M.dbgp("[DEBUG] - sorted_map: " .. table.concat(sorted_map, ", "))
    -- _M.dbgp("[DEBUG] - not_enter_map: " ..
    --                  table.concat(not_enter_map, ", "))
    -- _M.dbgp("[DEBUG] - error_other_map 数量: " .. #error_other_map)
    -- _M.dbgp("[DEBUG] - not_have_stackableCurrency: " ..
    --                  tostring(not_have_stackableCurrency))

    local PRIORITY_MAPS = {
        'MapBluff', -- 绝壁
        'MapBluff_NoBoss', 'MapSwampTower', -- 沉溺尖塔
        'MapSwampTower_NoBoss', 'MapLostTowers', -- 失落尖塔
        'MapLostTowers_NoBoss', 'MapAlpineRidge', 'MapAlpineRidge_NoBoss',
        'MapMesa', -- 平顶荒漠
        'MapMesa_NoBoss'
    }

    -- 计算地图得分的内部函数
    local function calculate_score(map_data, required_modes)
        -- _M.dbgp(string.format(
        --                  "[DEBUG] 开始计算地图得分: %s (位置: %d,%d)",
        --                  map_data.name_cn_utf8 or "未知", map_data.index_x,
        --                  map_data.index_y))

        -- 基础条件检查（一票否决）
        if not map_data.name_utf8 then
            -- _M.dbgp("[DEBUG] 地图无name_utf8字段，得分: -1")
            return -1
        end
        if _M.table_contains(my_game_info.trash_map, map_data.name_utf8) then
            -- _M.dbgp("[DEBUG] 地图在垃圾地图列表中，得分: -1")
            return -1
        end
        if _M.table_contains(map_data.mapPlayModes, "腐化聖域") then
            -- _M.dbgp("[DEBUG] 地图包含腐化聖域模式")
            local map_level = _M.select_best_map_key({
                bag_info = bag_info,
                key_level_threshold = key_level_threshold,
                not_use_map = not_use_map,
                priority_map = priority_map,
                color = 2,
                entry_length = 4
            })
            if not map_level or not_have_stackableCurrency then
                -- _M.dbgp(
                --     "[DEBUG] 没有合适的钥匙或不满足货币条件，得分: -1")
                return -1
            else
                -- _M.dbgp(
                --     "[DEBUG] 腐化聖域地图满足条件，得分: 9999")
                return 9999
            end
        end
        if _M.table_contains(map_data.mapPlayModes, "傳奇地圖") then
            -- _M.dbgp("[DEBUG] 地图是傳奇地圖")
            if _M.table_contains(map_data.name_cn_utf8, "純净樂園") then
                -- _M.dbgp("[DEBUG] 是純净樂園，得分: 9999")
                return 9999
            end
            -- _M.dbgp("[DEBUG] 不是純净樂園，得分: -1")
            return -1
        end
        if not_enter_map and
            _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
            -- _M.dbgp("[DEBUG] 地图在不进入列表中，得分: -1")
            return -1
        end
        if not (map_data.isMapAccessible or true) or map_data.isCompleted then
            -- _M.dbgp("[DEBUG] 地图不可访问或已完成，得分: -1")
            return -1
        end

        -- 检查必须包含的模式（如果有）
        if required_modes then
            -- _M.dbgp("[DEBUG] 需要检查的模式要求: " .. table.concat(required_modes, ", "))

            -- 单独处理"先行者高塔"的特殊判断
            if _M.table_contains(required_modes, "先行者高塔") then
                -- _M.dbgp("[DEBUG] 检查先行者高塔条件")
                if not _M.table_contains(PRIORITY_MAPS, map_data.name_utf8) then
                    -- _M.dbgp("[DEBUG] 地图不在PRIORITY_MAPS中，得分: -1")
                    return -1
                end
                -- 如果匹配则继续检查其他模式
                local new_required_modes = {}
                for _, mode in ipairs(required_modes) do
                    if mode ~= "先行者高塔" then
                        table.insert(new_required_modes, mode)
                    end
                end
                required_modes = new_required_modes
                -- _M.dbgp("[DEBUG] 更新后的required_modes: " .. (next(required_modes) and table.concat(required_modes, ", ") or "空"))
            end

            -- 检查剩余的模式（不包括"先行者高塔"）
            if #required_modes > 0 then
                -- _M.dbgp("[DEBUG] 检查剩余的模式要求")
                local has_required = false
                for _, mode in ipairs(required_modes) do
                    if _M.table_contains(map_data.mapPlayModes, mode) then
                        has_required = true
                        break
                    end
                end
                if not has_required then
                    -- _M.dbgp("[DEBUG] 不满足模式要求，得分: -1")
                    return -1
                end
                -- _M.dbgp("[DEBUG] 满足模式要求")
            end
        end

        -- 初始化评分项
        local score = 0
        local play_modes = map_data.mapPlayModes or {}
        -- _M.dbgp("[DEBUG] 地图玩法模式: " .. table.concat(play_modes, ", "))

        -- 1. 计算sorted_map中的玩法模式匹配
        if #sorted_map > 0 and #play_modes > 0 then
            -- _M.dbgp("[DEBUG] 计算sorted_map匹配分数")
            local matched_score = 0
            local matched_count = 0
            for i, mode in ipairs(sorted_map) do
                if _M.table_contains(play_modes, mode) then
                    -- 越靠前的模式权重越高（100 - 索引位置）
                    local mode_score = 100 - i
                    matched_score = matched_score + mode_score
                    matched_count = matched_count + 1
                    -- _M.dbgp(string.format( "[DEBUG] 匹配模式: %s (位置: %d, 得分: %d)", mode, i, mode_score))
                end
            end

            -- 匹配数量加成（每个匹配模式额外加50分）
            local count_bonus = matched_count * 100
            score = score + matched_score + count_bonus
            -- _M.dbgp(string.format( "[DEBUG] 模式匹配得分: %d (匹配得分: %d, 数量加成: %d)", score, matched_score, count_bonus))
        end

        -- 2. 玩法模式总数（基础分）
        local mode_count_score = #play_modes * 100
        score = score + mode_count_score
        -- _M.dbgp(string.format( "[DEBUG] 最终得分: %d (模式数量得分: %d)", score, mode_count_score))

        return score
    end

    -- 获取有效的sorted_map（过滤掉0值）
    local effective_sorted_map = {}
    if sorted_map then
        for _, mode in ipairs(sorted_map) do
            if mode ~= 0 then
                table.insert(effective_sorted_map, mode)
            end
        end
    end
    -- _M.dbgp("[DEBUG] 有效sorted_map: " .. table.concat(effective_sorted_map, ", "))

    -- 分阶段查找最佳地图
    local valid_maps = {}
    for i = 0, #effective_sorted_map do
        -- _M.dbgp(string.format("[DEBUG] 阶段 %d/%d 查找", i + 1, #effective_sorted_map + 1))

        -- 第1阶段：要求包含第1个模式
        -- 第2阶段：要求包含第1或第2个模式
        -- ...
        -- 最后阶段：不要求任何特定模式
        local required_modes = {}
        if i < #effective_sorted_map then
            for j = 1, i + 1 do
                table.insert(required_modes, effective_sorted_map[j])
            end
        end

        -- _M.dbgp("[DEBUG] 当前阶段要求模式: " .. (next(required_modes) and table.concat(required_modes, ", ") or "无"))

        -- 如果"先行者高塔"存在且不在最后一位，则排除它
        if #required_modes > 0 and
            _M.table_contains(required_modes, "先行者高塔") then
            if required_modes[#required_modes] ~= "先行者高塔" then
                local new_required_modes = {}
                for _, mode in ipairs(required_modes) do
                    if mode ~= "先行者高塔" then
                        table.insert(new_required_modes, mode)
                    end
                end
                required_modes = new_required_modes
                if #required_modes == 0 then -- 如果排除后数组为空
                    required_modes = nil
                end
                -- _M.dbgp("[DEBUG] 调整后的要求模式: " .. (required_modes and table.concat(required_modes, ", ") or "无"))
            end
        end

        for _, map_data in ipairs(otherworld_info) do
            if not map_data.isMapAccessible then
                -- _M.dbgp(string.format( "[DEBUG] 跳过不可访问地图: %s",  map_data.name_cn_utf8 or "未知"))
                goto continue
            end

            -- 检查错误地图
            if #error_other_map > 0 then
                local is_error = false
                for _, m in ipairs(error_other_map) do
                    if map_data.index_x == m.index_x and map_data.index_y ==
                        m.index_y then
                        is_error = true
                        break
                    end
                end
                if is_error then
                    -- _M.dbgp(string.format( "[DEBUG] 跳过错误地图: %s (位置: %d,%d)", map_data.name_cn_utf8 or "未知", map_data.index_x, map_data.index_y))
                    goto continue
                end
            end

            -- 检查禁止进入的地图
            if #not_enter_map > 0 and
                _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
                -- _M.dbgp(string.format( "[DEBUG] 跳过禁止进入地图: %s", map_data.name_cn_utf8 or "未知"))
                goto continue
            end

            local score = calculate_score(map_data, #required_modes > 0 and
                                              required_modes or nil)
            if score >= 0 then
                -- _M.dbgp(string.format( "[DEBUG] 有效地图: %s (得分: %d)", map_data.name_cn_utf8 or "未知", score))
                table.insert(valid_maps, {score = score, map = map_data})
            else
                -- _M.dbgp(string.format( "[DEBUG] 无效地图: %s (得分: %d)", map_data.name_cn_utf8 or "未知", score))
            end

            ::continue::
        end

        if #valid_maps > 0 then
            -- _M.dbgp(string.format(  "[DEBUG] 阶段 %d 找到 %d 个有效地图", i + 1, #valid_maps))
            -- 按总分降序排序
            table.sort(valid_maps, function(a, b)
                return a.score > b.score
            end)

            -- 打印前3个最佳地图
            for j = 1, math.min(3, #valid_maps) do
                -- _M.dbgp(string.format("[DEBUG] 排名 %d: %s (得分: %d)", j, valid_maps[j].map.name_cn_utf8 or "未知", valid_maps[j].score))
            end

            -- _M.dbgp(string.format("[DEBUG] 选择最佳地图: %s", valid_maps[1].map.name_cn_utf8 or "未知"))
            return valid_maps[1].map
        else
            -- _M.dbgp(string.format( "[DEBUG] 阶段 %d 未找到有效地图", i + 1))
        end
    end

    -- 如果没有找到符合条件的地图，尝试不要求任何特定模式
    if #valid_maps == 0 then
        -- _M.dbgp("[DEBUG] 尝试不要求任何特定模式")
        for _, map_data in ipairs(otherworld_info) do
            if not map_data.isMapAccessible then
                -- _M.dbgp(string.format( "[DEBUG] 跳过不可访问地图: %s", map_data.name_cn_utf8 or "未知"))
                goto continue
            end

            -- 检查错误地图
            if #error_other_map > 0 then
                local is_error = false
                for _, m in ipairs(error_other_map) do
                    if map_data.index_x == m.index_x and map_data.index_y ==
                        m.index_y then
                        is_error = true
                        break
                    end
                end
                if is_error then
                    -- -- -- _M.dbgp(string.format( "[DEBUG] 跳过错误地图: %s (位置: %d,%d)", map_data.name_cn_utf8 or "未知", map_data.index_x, map_data.index_y))
                    goto continue
                end
            end

            -- 检查禁止进入的地图
            if #not_enter_map > 0 and
                _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
                -- _M.dbgp(string.format( "[DEBUG] 跳过禁止进入地图: %s", map_data.name_cn_utf8 or "未知"))
                goto continue
            end

            local score = calculate_score(map_data)
            if score >= 0 then
                -- -- _M.dbgp(string.format( "[DEBUG] 有效地图: %s (得分: %d)", map_data.name_cn_utf8 or "未知", score))
                table.insert(valid_maps, {score = score, map = map_data})
            else
                -- -- _M.dbgp(string.format( "[DEBUG] 无效地图: %s (得分: %d)", map_data.name_cn_utf8 or "未知", score))
            end

            ::continue::
        end

        if #valid_maps > 0 then
            -- _M.dbgp(string.format("[DEBUG] 找到 %d 个有效地图", #valid_maps))
            -- 按总分降序排序
            table.sort(valid_maps, function(a, b)
                return a.score > b.score
            end)

            -- 打印前3个最佳地图
            for j = 1, math.min(3, #valid_maps) do
                -- -- _M.dbgp(string.format("[DEBUG] 排名 %d: %s (得分: %d)", j, valid_maps[j].map.name_cn_utf8 or "未知", valid_maps[j].score))
            end

            -- _M.dbgp(string.format("[DEBUG] 选择最佳地图: %s", valid_maps[1].map.name_cn_utf8 or  "未知"))
            return valid_maps[1].map
        else
            -- _M.dbgp("[DEBUG] 未找到任何有效地图")
        end
    end

    -- _M.dbgp("[DEBUG] 最终未找到合适地图，返回nil")
    return nil
end

-- 从钥匙名称中提取等级数字（UTF-8安全）
_M.extract_key_level = function(key_name)
    if not key_name then
        -- _M.dbgp("UTF-8警告: 尝试提取空钥匙名称的等级")
        return 0
    end
    -- UTF-8安全的数字提取
    local digits = string.match(key_name, "%d+")
    local level = digits and tonumber(digits) or 0
    -- _M.dbgp(string.format("UTF-8从 '%s' 中提取等级: %d",
    --                            key_name, level))
    return level
end

-- 快速点击背包物品
_M.ctrl_left_click_bag_items = function(target_name, bag_info, click_type, match_mode)
    -- 参数验证
    if not bag_info or type(bag_info) ~= "table" then
        _M.dbgp("背包信息无效")
        return false
    end

    -- 默认值处理
    click_type = click_type or 0
    match_mode = match_mode or 0

    for _, actor in ipairs(bag_info) do
        if not actor.baseType_utf8 then goto continue end

        -- 匹配逻辑分离提高可读性
        local is_match = false
        if match_mode == 1 then
            is_match = string.find(actor.baseType_utf8, target_name) ~= nil
        else
            is_match = (actor.baseType_utf8 == target_name) or 
                       (actor.obj and actor.obj == target_name)
        end

        if is_match then
            -- 坐标验证
            if not (actor.start_x and actor.start_y and actor.end_x and actor.end_y) then
                _M.dbgp("对象坐标信息不完整")
                return false
            end

            -- 计算点击位置
            local center_x, center_y = _M.get_center_position(
                {actor.start_x, actor.start_y},
                {actor.end_x, actor.end_y}
            )

            -- 点击类型分派
            if click_type == 1 then
                _M.right_click(center_x, center_y)
            elseif click_type == 3 then
                _M.ctrl_right_click(center_x, center_y)
            else
                _M.ctrl_left_click(center_x, center_y)
            end

            return true
        end
        ::continue::
    end

    _M.dbgp(("未找到目标物品: %s"):format(target_name))
    return false
end

-- 选择最优地图钥匙
_M.select_best_map_key = function(params)
    -- 解析参数表
    local inventory = params.inventory or {}
    local click = params.click or 0
    local key_level_threshold = params.key_level_threshold
    local type = params.type or 0
    local index = params.index or 0
    local score = params.score or 0
    local no_categorize_suffixes = params.no_categorize_suffixes or 0
    local min_level = params.min_level
    local not_use_map = params.not_use_map or {}
    local trashest = params.trashest or false
    local priority_map = params.priority_map or {}
    local page_type = params.page_type
    local entry_length = params.entry_length or 0
    local START_X = params.START_X or 0
    local START_Y = params.START_Y or 0
    local color = params.color or 0
    local vall = params.vall or false

    -- _M.dbgp("===== 开始选择最优地图钥匙 (UTF-8优化版) =====")
    -- _M.dbgp(string.format(
    --                  "参数: click=%d, type=%d, index=%d, score=%d, no_categorize=%d, min_level=%s, trashest=%s, entry_length=%d, color=%d, vall=%s",
    --                  click, type, index, score, no_categorize_suffixes,
    --                  tostring(min_level), tostring(trashest), entry_length,
    --                  color, tostring(vall)))

    if not inventory or #inventory == 0 then
        _M.dbgp("背包为空")
        return nil
    end

    -- UTF-8安全的字符串处理函数
    local function clean_utf8(s)
        if not s then
            -- _M.dbgp("UTF-8警告: 尝试清理空字符串")
            return ""
        end
        
        -- 使用更安全的方式去除空白字符（包括全角空格）
        -- 首先将字符串转换为UTF-8字符表
        local utf8chars = {}
        for _, c in utf8.codes(s) do
            table.insert(utf8chars, utf8.char(c))
        end
        
        -- 过滤掉空白字符
        local cleaned_chars = {}
        for _, char in ipairs(utf8chars) do
            if not (char:match("[%s　]")) then  -- 匹配半角和全角空格
                table.insert(cleaned_chars, char)
            end
        end
        
        local cleaned = table.concat(cleaned_chars)
        -- _M.dbgp(string.format("UTF-8清理: '%s' -> '%s'", s, cleaned))
        return cleaned
    end

    -- UTF-8安全的文本提取
    local function extract_utf8_text(s)
        if not s then
            -- _M.dbgp("UTF-8警告: 尝试从空字符串提取文本")
            return ""
        end
        -- 去除通配符
        s = string.gsub(s, "{%d+(:[^}]*)?}", "")
        -- 去除特定符号但保留中文字符
        s = string.gsub(s, "[+%-%%#%$%^%*%(%)]", "")
        -- _M.dbgp(string.format("UTF-8提取纯文本: '%s' -> '%s'", s, s))
        return s
    end

    

    -- UTF-8优化的词缀分类
    local function categorize_suffixes_utf8(suffixes)
        -- _M.dbgp("开始UTF-8词缀分类...")
        local categories = {
            ['瘋癲'] = {},
            ['其他'] = {},
            ['不打'] = {},
            ['无效'] = {}
        }

        if not suffixes or #suffixes == 0 then
            -- _M.dbgp("UTF-8警告: 空词条列表")
            categories['无效'][1] = '空词条列表'
            return categories
        end

        -- UTF-8安全的排除列表处理
        local processed_not_use_map = {}
        for _, excl in ipairs(not_use_map or {}) do
            if excl then
                local processed = string.gsub(excl, "[%d%%%s]", "")
                table.insert(processed_not_use_map, processed)
                -- _M.dbgp(string.format(
                --                  "UTF-8处理排除词条: '%s' -> '%s'", excl,
                --                  processed))
            end
        end

        for i, suffix in ipairs(suffixes) do
            local suffix_name = suffix.name_utf8 or ""
            -- _M.dbgp(string.format("处理UTF-8词缀 %d/%d: %s", i,
            --                            #suffixes, suffix_name))

            -- UTF-8安全清理
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>",
                                               "")
            cleaned_suffix = clean_utf8(cleaned_suffix)
            cleaned_suffix = extract_utf8_text(cleaned_suffix)

            if cleaned_suffix == "" then
                -- _M.dbgp("UTF-8词条为空，标记为无效")
                table.insert(categories['无效'], suffix_name)
                goto continue
            end

            -- UTF-8安全的词条处理
            local processed_suffix = string.gsub(cleaned_suffix, "[%d%%%s]", "")
            -- _M.dbgp(string.format("UTF-8预处理词条: '%s' -> '%s'",
            --                            cleaned_suffix, processed_suffix))

            -- UTF-8安全的排除检查
            for _, processed_excl in ipairs(processed_not_use_map) do
                if string.find(processed_suffix, processed_excl, 1, true) then
                    -- _M.dbgp(string.format(
                    --                  "UTF-8匹配排除词条: '%s' 包含 '%s'",
                    --                  processed_suffix, processed_excl))
                    table.insert(categories['不打'], cleaned_suffix)
                    goto continue
                end
            end

            -- UTF-8安全的疯癫词条检查
            if string.find(processed_suffix, "瘋癲", 1, true) then
                -- _M.dbgp("发现UTF-8疯癫词条")
                table.insert(categories['瘋癲'], cleaned_suffix)
                goto continue
            end

            -- 其他UTF-8词条
            -- _M.dbgp("归类为UTF-8普通词条")
            table.insert(categories['其他'], cleaned_suffix)

            ::continue::
        end

        -- _M.dbgp("UTF-8词缀分类结果:")
        -- for cat, items in pairs(categories) do
        --     _M.dbgp(string.format("  %s: %d 个", cat, #items))
        --     for i, item in ipairs(items) do
        --         _M.dbgp(string.format("    %d. %s", i, item))
        --     end
        -- end
        return categories
    end

    -- UTF-8安全的数值提取
    local function extract_numbers_utf8(suffix)
        local suffix_name = suffix.name_utf8 or ""
        -- _M.dbgp(string.format("UTF-8提取数值: %s", suffix_name))
        local value = 0

        -- UTF-8安全的关键词检查
        local function contains_utf8(str, pattern)
            return string.find(str, pattern, 1, true) ~= nil
        end

        if suffix.value_list and #suffix.value_list > 0 then
            local num = suffix.value_list[1]
            -- _M.dbgp(string.format("UTF-8基础数值: %d", num))

            -- 使用UTF-8安全的关键词检查
            if contains_utf8(suffix_name, "增加") or
                contains_utf8(suffix_name, "額外") or
                contains_utf8(suffix_name, "多") or
                contains_utf8(suffix_name, "穿透") then
                value = num
                -- _M.dbgp("UTF-8正向数值")
            elseif contains_utf8(suffix_name, "減少") or
                contains_utf8(suffix_name, "降低") or
                contains_utf8(suffix_name, "抗性") then
                value = -num
                -- _M.dbgp("UTF-8负向数值")
            end
        end
        -- _M.dbgp(string.format("UTF-8最终数值: %d", value))
        return value
    end

    -- UTF-8优化的评分函数
    local function calculate_score_utf8(categories, numbers)
        -- _M.dbgp("开始UTF-8评分计算...")
        -- 空词条直接返回0分
        if not (categories['瘋癲'][1] or categories['其他'][1] or
            categories['不打'][1] or categories['无效'][1]) then
            -- _M.dbgp("UTF-8无有效词条，评分=0")
            return 0
        end

        -- 排除项绝对否决
        if categories['不打'][1] then
            -- _M.dbgp("UTF-8发现排除词条，评分=-999999")
            return -999999
        end

        local score = 0
        local value_weights = {
            ["物品稀有度"] = 3.0,
            ["物品數量"] = 2.5,
            ["魔法怪物"] = 1.8,
            ["稀有怪物"] = 1.6,
            ["怪物群數量"] = 1.2,
            ["瘋癲"] = 5.0
        }

        -- 处理疯癫词条
        for _, suffix in ipairs(categories['瘋癲']) do
            -- _M.dbgp(string.format("UTF-8疯癫词条: %s, 权重=5.0",
            --                            suffix))
            score = score + 50 -- 疯癫词条固定加分
        end

        -- 处理其他词条
        for _, suffix in ipairs(categories['其他']) do
            local matched = false
            for kw, weight in pairs(value_weights) do
                if string.find(suffix, kw, 1, true) then
                    local num = numbers[suffix] or 0
                    -- _M.dbgp(string.format(
                    --                  "UTF-8匹配关键词 '%s': 数值=%d, 权重=%.1f, 贡献=%d",
                    --                  kw, num, weight, num * weight))
                    score = score + num * weight
                    matched = true
                    break
                end
            end
            if not matched then
                -- _M.dbgp(string.format(
                --                  "UTF-8未匹配关键词的词条: %s", suffix))
            end
        end

        local final_score = math.floor(score)
        -- _M.dbgp(string.format("UTF-8最终评分: %d", final_score))
        return final_score
    end

    local best_key = nil
    local max_score = -math.huge
    local min_score = math.huge
    local processed_keys = 0

    -- 预处理key_level_threshold
    local white, blue, gold, valls, level = {}, {}, {}, {}, {}
    if key_level_threshold then
        -- _M.dbgp("处理钥匙等级阈值...")
        for _, user_map in ipairs(key_level_threshold) do
            local levels = tonumber(user_map['階級'] or 0)
            table.insert(level, levels)
            if user_map['白'] then
                if not _M.table_contains(white, levels) then
                    table.insert(white, levels)
                    -- _M.dbgp(string.format("添加白色钥匙等级: %d",
                    --                            levels))
                end
            end
            if user_map['藍'] then
                if not _M.table_contains(blue, levels) then
                    table.insert(blue, levels)
                    -- _M.dbgp(string.format("添加蓝色钥匙等级: %d",
                    --                            levels))
                end
            end
            if user_map['黃'] then
                if not _M.table_contains(gold, levels) then
                    table.insert(gold, levels)
                    -- _M.dbgp(string.format("添加黄色钥匙等级: %d",
                    --                            levels))
                end
            end
            if user_map['已污染'] then
                if not _M.table_contains(valls, levels) then
                    table.insert(valls, levels)
                    -- _M.dbgp(string.format("添加污染钥匙等级: %d",
                    --                            levels))
                end
            end
        end
    end

    -- _M.dbgp(string.format("开始处理 %d 个背包物品...", #inventory))
    for i, item in ipairs(inventory) do
        -- _M.dbgp(string.format("\n处理物品 %d/%d: %s", i, #inventory,
        --                            item.baseType_utf8 or "未知"))

        -- 检查是否为地图钥匙（UTF-8安全）
        if not string.find(item.baseType_utf8 or "", "地圖鑰匙") then
            -- _M.dbgp("不是地图钥匙，跳过")
            goto continue
        end

        -- 颜色过滤
        if color > 0 then
            if (item.color or 0) < color then
                -- _M.dbgp(string.format(
                --                  "颜色不匹配: 需要=%d, 实际=%d", color,
                --                  item.color or 0))
                goto continue
            end
        end

        local key_level = _M.extract_key_level(item.baseType_utf8)
        -- _M.dbgp(string.format("钥匙等级: %d", key_level))

        -- 污染过滤
        if vall then
            if item.contaminated then
                -- _M.dbgp("跳过污染钥匙(根据vall参数)")
                goto continue
            end
        end

        -- 等级过滤
        if min_level and key_level < min_level then
            -- _M.dbgp(string.format("等级过低: 需要=%d, 实际=%d",
            --                            min_level, key_level))
            goto continue
        end

        -- 钥匙等级阈值检查
        if key_level_threshold then
            local valid = false
            if #white > 0 and _M.table_contains(white, key_level) then
                valid = true
                -- _M.dbgp("匹配白色钥匙等级")
            end
            if #blue > 0 and _M.table_contains(blue, key_level) then
                valid = true
                -- _M.dbgp("匹配蓝色钥匙等级")
            end
            if #gold > 0 and _M.table_contains(gold, key_level) then
                valid = true
                -- _M.dbgp("匹配黄色钥匙等级")
            end
            if #valls > 0 and _M.table_contains(valls, key_level) then
                valid = true
                -- _M.dbgp("匹配污染钥匙等级")
            end

            if not valid then
                -- _M.dbgp("不满足任何钥匙等级阈值条件")
                goto continue
            end
        end

        -- 词缀长度检查
        if entry_length > 0 then
            if (item.fixedSuffixCount or 0) < entry_length and item.contaminated then
                -- _M.dbgp(string.format("词缀不足: 需要=%d, 实际=%d",
                --                            entry_length,
                --                            item.fixedSuffixCount or 0))
                goto continue
            end
        end

        local suffixes = nil
        if (item.color or 0) > 0 then
            -- 获取UTF-8编码的词缀
            suffixes = api_GetObjectSuffix(item.mods_obj)
            -- _M.dbgp(string.format("获取到 %d 个UTF-8词缀",
            --                            suffixes and #suffixes or 0))

            if suffixes and #suffixes > 0 then
                -- 排除词缀检查
                if #not_use_map > 0 then
                    if _M.match_item_suffixes(suffixes, not_use_map, true) then
                        -- _M.dbgp("匹配到排除词缀")
                        if trashest then
                            best_key = item
                            -- _M.dbgp("trashest模式，选择此钥匙")
                            break
                        end
                        goto continue
                    end
                end

                -- 优先词缀检查
                if #priority_map > 0 then
                    if _M.match_item_suffixes(suffixes, priority_map, true) then
                        -- _M.dbgp("匹配到优先词缀，直接选择")
                        best_key = item
                        break
                    end
                end
            end
        end

        -- UTF-8词缀分类
        local categories = categorize_suffixes_utf8(suffixes or {})

        -- trashest模式处理
        if trashest and
            not (categories['瘋癲'][1] or categories['其他'][1] or
                categories['不打'][1]) then
            -- _M.dbgp("trashest模式选择无词缀钥匙")
            best_key = item
            break
        end

        -- 提取数值
        local numbers = {}
        if suffixes and #suffixes > 0 then
            for _, s in ipairs(suffixes) do
                numbers[s.name_utf8 or ""] = extract_numbers_utf8(s)
            end
        end

        -- 计算评分
        local level_weight = key_level * 5
        local suffix_score = calculate_score_utf8(categories, numbers)
        local color_score = 25 * (item.color or 0)
        if item.contaminated then
            color_score = color_score + 100
            -- _M.dbgp("污染钥匙额外加分100")
        end

        local total_score
        if no_categorize_suffixes == 0 then
            total_score = level_weight + suffix_score + color_score
            -- _M.dbgp(string.format(
            --                  "UTF-8总评分: 等级(%d*5=%d) + 词缀(%d) + 颜色(%d) = %d",
            --                  key_level, level_weight, suffix_score, color_score,
            --                  total_score))
        else
            total_score = level_weight + color_score
            -- _M.dbgp(string.format(
            --                  "UTF-8总评分(忽略词缀): 等级(%d*5=%d) + 颜色(%d) = %d",
            --                  key_level, level_weight, color_score, total_score))
        end

        -- 记录最优
        if index == 0 then
            if total_score > max_score then
                max_score = total_score
                best_key = item
                -- _M.dbgp("新的最高分钥匙")
            end
        else
            if total_score < min_score then
                min_score = total_score
                best_key = item
                -- _M.dbgp("新的最低分钥匙")
            end
        end

        processed_keys = processed_keys + 1
        ::continue::
    end

    if best_key then
        -- _M.dbgp("\n===== UTF-8选择结果 =====")
        
        -- 安全访问所有字段（带默认值）
        -- _M.dbgp("选择的钥匙:", best_key.baseType_utf8 or "未知")
        
        -- 提取等级时防止 nil
        local key_level = 0
        if best_key.baseType_utf8 then
            key_level = _M.extract_key_level(best_key.baseType_utf8) or 0
        end
        -- _M.dbgp("等级:", key_level)
        
        -- _M.dbgp("颜色:", best_key.color or 0)
        -- _M.dbgp("污染:", best_key.contaminated and "是" or "否")
        if score ~= 0 then
            -- 确保 index/max_score/min_score 有效
            local final_score = 0
            if index == 0 then
                final_score = max_score or 0
            else
                final_score = min_score or 0
            end
            -- _M.dbgp("分数:", final_score)
            return best_key, final_score
        end
    else
        _M.dbgp("警告: best_key 为 nil")
    end

    -- 获取超大仓库物品中心点
    local function get_center_position_store_max(start_cell, end_cell, start_x, start_y, w, h)
        -- 参数类型检查
        if not (type(start_cell) == "table" and type(end_cell) == "table") then
            error("start_cell and end_cell must be tables")
        end
        
        local start_row, start_col = start_cell[1], start_cell[2]
        local end_row, end_col = end_cell[1], end_cell[2]

        -- 计算中心位置为起始和结束格子的平均位置
        local center_x = start_x + (((start_row + end_row) / 2) * w)
        local center_y = start_y + (((start_col + end_col) / 2) * h)

        -- 四舍五入
        return math.floor(center_x + 0.5), math.floor(center_y + 0.5)
    end

    -- 执行选择
    if best_key then
        -- _M.api_print(f"█ 最优选择：{best_key.name_utf8} | 评分：{max_score}")
        if score == 1 then
            return best_key, _M.extract_key_level(best_key.baseType_utf8 or "未知")
        end
        if click == 1 then
            if page_type == 7 then
                local pos = get_center_position_store_max(
                    {best_key.start_x or 0, best_key.start_y or 0},
                    {best_key.end_x or 0, best_key.end_y or 0},
                    15, 100, 22, 22)
                _M.ctrl_left_click(pos[1], pos[2])
                return _M.extract_key_level(best_key.baseType_utf8 or "未知")
            end
            if type == 1 then
                -- _M.api_print(11111111111111)
                _M.ctrl_left_click_store_items(best_key.obj or nil, inventory)
                return _M.extract_key_level(best_key.baseType_utf8 or "未知")
            end
            if type == 3 then
                _M.return_more_map(best_key.obj or nil, inventory, START_X, START_Y)
                return _M.extract_key_level(best_key.baseType_utf8 or "未知")
            end
            _M.ctrl_left_click_bag_items(best_key.obj or nil, inventory)
            return _M.extract_key_level(best_key.baseType_utf8 or "未知")
        end
        return best_key
    else
        -- _M.api_print("⚠️ 未找到符合条件的地图钥匙")
        return nil
    end

    return best_key
end

-- 粘贴输入文本
_M.paste_text = function(text)
    api_SetClipboard(text)
    api_Sleep(100)
    _M.click_keyboard("ctrl", 1)
    api_Sleep(100)
    _M.click_keyboard("a", 0)
    api_Sleep(100)
    _M.click_keyboard("v", 0)
    api_Sleep(100)
    _M.click_keyboard("ctrl", 2)
end

-- 词条过滤
_M.filter_item = function(item, suffixes, config_list)
    _M.dbgp("\n===== 开始物品过滤 =====")
    _M.dbgp(string.format("物品名称: %s",
                               item.baseType_utf8 or "未知"))
    _M.dbgp(string.format("物品稀有度: %d", item.color or 0))
    _M.dbgp(string.format("物品等级: %d", item.DemandLevel or 0))

    -- 遍历所有配置规则
    for i, config in ipairs(config_list) do
        _M.dbgp(
            string.format("\n检查配置规则 %d/%d", i, #config_list))

        -- 1. 检查名称 (支持"全部物品"通配)
        if type(config["類型"]) == "table" then
            if not _M.table_contains(my_game_info.item_type_china,
                                     config["類型"][1]) then
                _M.dbgp("→ 跳过：非装备物品类型")
                goto continue -- 非装备物品则跳过此配置
            end
        elseif not _M.table_contains(my_game_info.item_type_china,
                                     config["類型"]) then
            _M.dbgp("→ 跳过：非装备物品类型")
            goto continue -- 非装备物品则跳过此配置
        end

        if config["基礎類型名"] ~= "全部物品" and
            not _M.table_contains(config["基礎類型名"], item.baseType_utf8) then
            _M.dbgp(string.format(
                             "→ 跳过：基础类型不匹配（需要：%s）",
                             table.concat(config["基礎類型名"], ",")))
            goto continue -- 名称不匹配则跳过此配置
        else
            _M.dbgp("√ 基础类型匹配通过")
        end

        -- 2. 检查稀有度
        local rarity_checks = {
            [0] = config["白裝"] or false,
            [1] = config["藍裝"] or false,
            [2] = config["黃裝"] or false,
            [3] = config["暗金"] or false
        }
        if not rarity_checks[item.color or 0] then
            _M.dbgp(string.format(
                             "→ 跳过：稀有度不匹配（当前：%d）",
                             item.color or 0))
            goto continue
        else
            _M.dbgp(string.format(
                             "√ 稀有度匹配通过（当前：%d）",
                             item.color or 0))
        end

        -- 3. 检查物品类型
        local config_type = config["類型"] or ""
        if config_type ~= "" then
            local item_type = type(config_type) == "table" and config_type[1] or
                                  config_type
            if item.category ~= my_game_info.type_conversion[item_type] then
                _M.dbgp(string.format(
                                 "→ 跳过：物品类型不匹配（需要：%s）",
                                 item_type))
                goto continue
            else
                _M.dbgp(string.format(
                                 "√ 物品类型匹配通过（需要：%s）",
                                 item_type))
            end
        end

        -- 4. 检查物品等级
        local item_config = config["等級"]
        if item_config then
            local item_type = item_config["type"]
            if item_type == "exact" then
                local item_level = item_config["value"]
                if (item.DemandLevel or 0) < item_level then
                    _M.dbgp(string.format(
                                     "→ 跳过：等级不足（需要：%d，当前：%d）",
                                     item_level, item.DemandLevel or 0))
                    goto continue
                else
                    _M.dbgp(string.format(
                                     "√ 等级匹配通过（需要：%d）",
                                     item_level))
                end
            else
                local min_level = item_config["min"]
                local max_level = item_config["max"]
                if (item.DemandLevel or 0) < min_level or
                    (item.DemandLevel or 0) > max_level then
                    _M.dbgp(string.format(
                                     "→ 跳过：等级超出范围（需要：%d-%d，当前：%d）",
                                     min_level, max_level, item.DemandLevel or 0))
                    goto continue
                else
                    _M.dbgp(string.format(
                                     "√ 等级范围匹配通过（需要：%d-%d）",
                                     min_level, max_level))
                end
            end
        end

        -- 5. 检查词缀（支持多规则处理）
        local affix_rules = config["物品詞綴"] or {}
        local check_yes = false
        if next(affix_rules) ~= nil then
            _M.dbgp("开始检查词缀规则...")
            local all_rules_passed = true
            for rule_name, rule_config in pairs(affix_rules) do
                if type(rule_config) ~= "table" then
                    _M.dbgp(string.format("→ 跳过无效规则：%s",
                                               rule_name))
                    goto rule_continue -- 跳过无效规则
                end

                -- 检查"詞綴"字段
                local affix_field = rule_config["詞綴"]

                if affix_field == nil then
                    _M.dbgp(string.format("→ 规则 %s 无词缀字段",
                                               rule_name))
                    goto rule_continue -- 没有"詞綴"字段则跳过
                elseif type(affix_field) == "boolean" then
                    _M.dbgp(string.format("→ 规则 %s 为布尔值",
                                               rule_name))
                    goto rule_continue -- 布尔值跳过
                elseif not (next(affix_field) ~= nil) then -- 空列表/字符串/字典等
                    _M.dbgp(string.format("→ 规则 %s 词缀为空",
                                               rule_name))
                    goto rule_continue
                end

                -- 对每个规则单独检查
                _M.dbgp(string.format("检查规则：%s", rule_name))
                if not _M.match_item_suffixes(suffixes,
                                              {[rule_name] = rule_config}) then
                    _M.dbgp(string.format("→ 规则 %s 不匹配",
                                               rule_name))
                    all_rules_passed = false
                    goto rule_continue -- 该规则不满足则继续匹配下个规则
                end

                if _M.match_item_suffixes(suffixes, {[rule_name] = rule_config}) then
                    _M.dbgp(string.format(
                                     "√ 规则 %s 匹配成功，直接返回",
                                     rule_name))
                    return true -- 任一规则满足则跳过当前配置
                end

                ::rule_continue::
            end

            if not all_rules_passed then
                _M.dbgp("→ 部分词缀规则不匹配")
                goto continue
            else
                _M.dbgp("√ 所有词缀规则匹配通过")
                check_yes = true
            end
        end

        if check_yes then
            -- 所有条件都满足
            _M.dbgp("√ 所有条件匹配成功，保留物品")
            return true
        end

        _M.dbgp("→ 继续检查下一个配置规则")
        ::continue::
        
    end

    -- 没有任何配置规则匹配
    _M.dbgp("× 无任何配置规则匹配，丢弃物品")
    return false
end

-- 词条匹配（带详细日志）
_M.match_affix_with_template = function(affix_str, template, item_value,
                                        required_value)
    _M.dbgp("\n----- 开始词缀匹配 -----")
    _M.dbgp(string.format("词缀: %s", affix_str or "无"))
    _M.dbgp(string.format("模板: %s", template or "无"))

    -- 空值检查
    if type(affix_str) ~= "string" or type(template) ~= "string" then
        _M.dbgp("× 无效输入类型")
        return false
    end

    -- 清理字符串（去除所有空白字符）
    local function clean(s)
        if not s then return "" end
        return string.gsub(s, "[%s　]+", "")
    end

    local affix = clean(affix_str)
    local pattern = clean(template)
    _M.dbgp(string.format("清理后词缀: %s", affix))
    _M.dbgp(string.format("清理后模板: %s", pattern))

    -- 提取纯文字部分（去除所有数字索引的通配符和符号）
    local function extract_text(s)
        if not s then return "" end
        -- 去除所有 {n} 或 {n:format} 形式的通配符（n为数字）
        s = string.gsub(s, "{%d+(:[^}]*)?}", "")
        -- 去除所有符号（+、-、%等）
        s = string.gsub(s, "[+%-%%]", "")
        return s
    end

    local affix_text = extract_text(affix)
    local pattern_text = extract_text(pattern)
    _M.dbgp(string.format("纯文本词缀: %s", affix_text))
    _M.dbgp(string.format("纯文本模板: %s", pattern_text))

    -- 首先检查文字部分是否匹配
    if affix_text ~= pattern_text then
        _M.dbgp("× 文本不匹配")
        return false
    else
        _M.dbgp("√ 文本匹配通过")
    end

    -- 如果只需要匹配文字，不需要比较数值
    if required_value == nil then
        _M.dbgp("√ 无数值要求，匹配成功")
        return true
    end

    -- 确保item_value是数组
    if type(item_value) ~= "table" then item_value = {item_value} end
    _M.dbgp(
        string.format("物品数值: %s", table.concat(item_value, ",")))

    -- 确保required_value是数组
    if type(required_value) ~= "table" then required_value = {required_value} end
    _M.dbgp(string.format("需求数值: %s",
                               table.concat(required_value, ",")))

    -- 数值比较
    local function safe_to_number(val)
        if type(val) == "number" then return val end
        local num = tonumber(val)
        return num or 0
    end

    local result = false
    if #item_value == 1 and #required_value == 1 then
        result = safe_to_number(item_value[1]) >=
                     safe_to_number(required_value[1])
        _M.dbgp(string.format("单值比较: %s >= %s → %s",
                                   item_value[1], required_value[1],
                                   tostring(result)))
    elseif #item_value == 2 and #required_value == 1 then
        result = safe_to_number(required_value[1]) >=
                     safe_to_number(item_value[1]) and
                     safe_to_number(required_value[1]) <=
                     safe_to_number(item_value[2])
        _M.dbgp(string.format("范围比较: %s <= %s <= %s → %s",
                                   item_value[1], required_value[1],
                                   item_value[2], tostring(result)))
    elseif #item_value == 1 and #required_value == 2 then
        result = safe_to_number(item_value[1]) >=
                     safe_to_number(required_value[1])
        _M.dbgp(string.format("下限比较: %s >= %s → %s",
                                   item_value[1], required_value[1],
                                   tostring(result)))
    elseif #item_value == 2 and #required_value == 2 then
        result = (safe_to_number(item_value[1]) >=
                     safe_to_number(required_value[1]) and
                     safe_to_number(item_value[2]) >=
                     safe_to_number(required_value[2]))
        _M.dbgp(string.format("双范围比较: [%s,%s] >= [%s,%s] → %s",
                                   item_value[1], item_value[2],
                                   required_value[1], required_value[2],
                                   tostring(result)))
    else
        _M.dbgp("× 数值格式不支持")
        result = false
    end

    _M.dbgp(string.format("匹配结果: %s", tostring(result)))
    return result
end

-- 词缀规则匹配（带详细日志）
_M.match_item_suffixes = function(item_suffixes, config_suffixes, not_item)
    _M.dbgp("\n===== 开始词缀规则匹配 =====")
    _M.dbgp(string.format("物品词缀数量: %d", #item_suffixes))
    _M.dbgp(string.format("配置规则数量: %d",
                               _M.table_size(config_suffixes)))

    local min_matched_count = 0
    local required_suffixes = {}
    local must_contain_all = false

    if not not_item then
        local keys = {}
        for k in pairs(config_suffixes) do table.insert(keys, k) end
        if not config_suffixes or not config_suffixes[keys[1]] or
            not config_suffixes[keys[1]]["詞綴"] then
            _M.dbgp("→ 无有效配置规则，默认通过")
            return true
        end
        required_suffixes = config_suffixes[keys[1]]["詞綴"]
        must_contain_all = config_suffixes[keys[1]]["是否全部包含"] or
                               false
        if required_suffixes then
            min_matched_count = required_suffixes["满足几保留"] and
                                    (required_suffixes["满足几保留"][1] or
                                        0) or 0
        end
        _M.dbgp(string.format("匹配模式: %s", must_contain_all and
                                       "必须全部匹配" or "匹配任意"))
        _M.dbgp(string.format("最小匹配数: %d", min_matched_count))
    else
        required_suffixes = config_suffixes
        must_contain_all = false
        _M.dbgp("→ 直接匹配模式")
    end

    if not required_suffixes or next(required_suffixes) == nil then
        _M.dbgp("× 无词缀要求")
        return false
    end

    -- 构建物品词缀列表
    local item_affixes = {}
    for _, affix in ipairs(item_suffixes) do
        table.insert(item_affixes, {affix.name_utf8, affix.value_list})
        _M.dbgp(string.format("物品词缀: %s (值: %s)",
                                   affix.name_utf8 or "无",
                                   table.concat(affix.value_list or {}, ",")))
    end

    local matched_count = 0
    local matched_details = {}

    -- 检查每个要求的词缀
    for required_key, required_value in pairs(required_suffixes) do
        _M.dbgp(string.format("\n检查需求词缀: %s", required_key))

        -- 获取配置要求的模板和数值
        local required_template, required_val
        if type(required_value) == "table" and #required_value >= 2 then
            required_template = required_value[1]
            required_val = required_value[2]
            _M.dbgp(string.format("模板: %s, 需求值: %s",
                                       required_template,
                                       table.concat(required_val, ",")))
        elseif type(required_suffixes) == "table" then
            required_template = required_key
            required_val = required_value
            _M.dbgp(string.format("模板: %s, 需求值: %s",
                                       required_template, tostring(required_val)))
        else
            required_template = required_value
            required_val = nil
            _M.dbgp(string.format("模板: %s (无数值要求)",
                                       required_template))
        end

        -- 检查物品词缀是否匹配
        for _, affix_pair in ipairs(item_affixes) do
            local item_affix = affix_pair[1]
            local item_value = affix_pair[2]

            _M.dbgp(string.format("尝试匹配: %s", item_affix))
            if _M.match_affix_with_template(item_affix, required_template,
                                            item_value, required_val) then
                matched_count = matched_count + 1
                table.insert(matched_details, string.format("%s 匹配 %s",
                                                            item_affix,
                                                            required_template))
                _M.dbgp("√ 匹配成功")
                if not must_contain_all then
                    _M.dbgp("√ 任意匹配模式，直接返回成功")
                    return true
                end
                break
            else
                _M.dbgp("× 匹配失败")
            end
        end
    end

    -- 输出匹配详情
    _M.dbgp("\n匹配详情:")
    if #matched_details > 0 then
        for i, detail in ipairs(matched_details) do
            _M.dbgp(string.format("%d. %s", i, detail))
        end
    else
        _M.dbgp("无匹配项")
    end

    -- _M.dbgp(string.format("\n总匹配数: %d (需要: %d)", matched_count,
    --                            min_matched_count > 0 and min_matched_count or
    --                                "任意"))

    if min_matched_count > 0 then
        if matched_count >= min_matched_count then
            _M.dbgp("√ 满足最小匹配数要求")
            return true
        else
            _M.dbgp("× 不满足最小匹配数要求")
            return false
        end
    end

    if must_contain_all then
        local result = matched_count == _M.table_size(required_suffixes)
        _M.dbgp(string.format("必须全部匹配: %s", tostring(result)))
        return result
    else
        local result = matched_count > 0
        _M.dbgp(string.format("任意匹配: %s", tostring(result)))
        return result
    end
end

-- 辅助函数：获取table大小
_M.table_size = function(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

--- 点击指定文本的UI元素
-- @param text string 要查找的UI文本内容
-- @param ui_info table UI元素信息表
-- @param click number 是否执行点击操作(1=点击,0=不点击)
-- @param min_x number 搜索区域最小X坐标(默认0)
-- @param min_y number 搜索区域最小Y坐标(默认0)
-- @param max_x number 搜索区域最大X坐标(默认1600)
-- @param max_y number 搜索区域最大Y坐标(默认900)
-- @return boolean 是否找到并处理了指定文本的UI元素
_M.click_text_UI = function(options)
    -- 默认参数
    local config = {
       text = options.text or "",          -- 必填
       ui_info = options.ui_info or {},    -- 必填
       click = options.click or 0,         -- 可选，默认 0
       min_x = options.min_x or 0,         -- 可选，默认 0
       min_y = options.min_y or 0,         -- 可选，默认 0
       max_x = options.max_x or 1600,      -- 可选，默认 1600
       max_y = options.max_y or 900,       -- 可选，默认 900
       index = options.index or 0,         -- 可选，默认 0
       ret_data = options.ret_data or false -- 可选，默认 false
   }
   local ui_info = nil
   if config.index ~= 0 then
       local UI_info = {}
       local size =  UiElements:Update()
       if size > 0 then
           local sum = 0;
           for i = 0, size - 1, 1 do
               sum = sum + 1
               table.insert(UI_info, UiElements[i])
           end
       end
       ui_info = UI_info
   else
       ui_info = config.ui_info
   end
   if ui_info and next(ui_info) then
       for _, value in ipairs(ui_info) do
           -- _M.print_log(value.name_utf8)
           if value.name_utf8 == config.text then
               local x = (value.left + value.right) / 2
               local y = (value.top + value.bottom) / 2
               if config.click == 1 then
                   api_ClickScreen(x, y,1)
               end
               -- _M.print_log(456)
               if config.ret_data then
                   return value
               end
               return true
           end
       end
   end
   return false
end

-- 读取配置文件中物品过滤，并优化
_M.get_items_config_info = function(config)
    local item_congif_list = config["物品過濾"]
    local processed_configs = {}
    for _, v in ipairs(item_congif_list) do
        
        v['名稱模式'] = (string.find(v['基礎類型名'] or '', '全部物品') and 'all') or 'specific'
        v["颜色"] = {}
        if v['白裝'] then table.insert(v['颜色'], 0) end
        if v['藍裝'] then table.insert(v['颜色'], 1) end
        if v['黃裝'] then table.insert(v['颜色'], 2) end
        if v['暗金'] then table.insert(v['颜色'], 3) end
        v["等級"] = _M.parse_level(v["等級"])
        
        table.insert(processed_configs, v)
    end
    return processed_configs
end 

-- confing 等级解析
_M.parse_level = function(level_str)
    if not level_str or level_str == "" then
        return { type = "any", min = 0, max = 9999 }
    end
    -- 匹配 "20" 形式（纯数字）
    local single_num = level_str:match("^(%d+)$")
    if single_num then
        return { type = "exact", value = tonumber(single_num)}
    end
    -- 匹配 "1-20" 形式（范围）
    local min, max = level_str:match("^(%d+)%-(%d+)$")
    if min and max then
        return { type = "range", min = tonumber(min), max = tonumber(max) }
    end
    -- 匹配 "15+" 形式（下限）
    local min_plus = level_str:match("^(%d+)%+$")
    if min_plus then
        return { type = "lower_bound", min = tonumber(min_plus), max = 9999 }
    end
    -- 其他情况（无效格式）
    return { type = "any", min = 0, max = 9999 }
end


-- 其他可能用到的API
_M.get_current_time = function() return os.time() end

-- 获取范围内的所有文本/指定文本
-- @param params 参数表，包含以下可选字段：
--   text: 要查找的文本内容
--   UI_info: UI元素信息表
--   min_x, min_y, max_x, max_y: 搜索区域坐标范围
--   index: 调节是否查找文本
-- @return 根据index参数返回不同结果，默认返回所有文本
_M.get_game_control_by_rect = function(data)
    local config = {
        text = data.text or "",          -- 必填
        ui_info = data.ui_info or {},    -- 必填
        min_x = data.min_x or 0,         -- 可选，默认 0
        min_y = data.min_y or 0,         -- 可选，默认 0
        max_x = data.max_x or 1600,      -- 可选，默认 1600
        max_y = data.max_y or 900,       -- 可选，默认 900
        index = data.index or 0,         -- 可选，默认 0
    }
    local text_list = {}
    for _, v in ipairs(config.ui_info) do
        if v.left >= config.min_x and v.top >= config.min_y and v.right <= config.max_x and v.bottom <= config.max_y then
            if config.index ~= 0 and config.text and config.text ~= "" then
                if v.name_utf8 == config.text or v.text_utf8 == config.text then
                    table.insert(text_list,v)
                end
            else
                table.insert(text_list,v)
            end
        end
    end
    return text_list
end

--- 检查物品是否存在于指定的物品栏中
--- @param self table 当前对象
--- @param item_name string 物品名称（baseType_utf8字段）
--- @param inventory table 物品栏列表
--- @return boolean 如果物品存在则返回true，否则返回false
_M.check_item_in_inventory = function(item_name, inventory)
    if inventory then
        for _, item in ipairs(inventory) do
            if item.baseType_utf8 == item_name then
                return true  -- 检查到物品，返回true
            end
        end
    end
    return false
end


--- 处理异界地图配置，构建索引并整合相关数据
-- @function process_void_maps
-- @param map_cfg table 包含异界地图配置的表
-- @return void 无返回值，直接修改输入的map_cfg表
_M.process_void_maps = function(map_cfg)
    -- 构建异界地图索引，包含涂油设置和使用通货数据
    local void_maps = map_cfg['異界地圖']['地圖鑰匙']
    local tier_index = {}
    local config_index = {}
    local oil_configs = {}
    local currency_configs = {}
    local monster_filter_configs = {}


    for _, config in ipairs(void_maps) do
        -- 强制类型转换
        local tier = config['階級']


        -- 建立层级索引
        if not tier_index[tier] then
            tier_index[tier] = {}
        end
        table.insert(tier_index[tier], config)


        -- 建立复合索引
        local key = tier .. "_" .. (config['攻擊距離'] or "")
        config_index[key] = config


        -- 自动生成启用状态
        config['已启用'] = config['白'] or config['藍'] or config['黃'] or config['已污染']


        -- 动态加载涂油设置（增强安全处理）
        local oil_key = tier
        local oil_settings = config['塗油設置'] or {}


        -- 安全获取是否涂油标志
        local oil_flag = oil_settings['是否塗油']
        local should_oil = false
        if type(oil_flag) == "boolean" then
            should_oil = oil_flag
        elseif oil_flag ~= nil then
            should_oil = tostring(oil_flag):lower() == "true" or tostring(oil_flag) == "1" or tostring(oil_flag):lower() == "yes"
        end


        -- 只有当需要涂油时才创建配置
        if should_oil then
            oil_configs[oil_key] = {
                ['倉庫類型'] = '',
                ['是否塗油'] = true,
                ['配方'] = {}
            }


            -- 处理仓库类型
            local storage_type = oil_settings['倉庫類型']
            if storage_type ~= nil then
                oil_configs[oil_key]['倉庫類型'] = tostring(storage_type):gsub("^%s*(.-)%s*$", "%1")
            end


            -- 处理配方（支持最多3个配方）
            local recipes = {}
            for i = 1, 3 do
                local recipe_key = '配方' .. i
                local recipe_value = oil_settings[recipe_key]
                if recipe_value ~= nil then
                    local safe_recipe = tostring(recipe_value):gsub("^%s*(.-)%s*$", "%1")
                    if safe_recipe ~= "" then
                        table.insert(recipes, safe_recipe)
                    end
                end
            end
            oil_configs[oil_key]['配方'] = recipes
        end


        -- 动态加载通货使用设置（安全处理不存在的键）
        local currency_key = tier
        local currency_defaults = {
            ['是否開啟'] = false,
            ['蛻變石'] = 0,
            ['增幅石'] = 0,
            ['富豪石'] = 0,
            ['點金石'] = 0,
            ['崇高石'] = 0,
            ['瓦爾寶珠'] = 0
        }


        -- 安全获取通货设置
        local currency_settings = config['使用通貨'] or {}
        if type(currency_settings) == "table" then
            currency_configs[currency_key] = {}
            for key, default in pairs(currency_defaults) do
                currency_configs[currency_key][key] = currency_settings[key] or default
            end
        else
            currency_configs[currency_key] = currency_defaults
        end


        -- 怪物过滤配置
        local monster_filter_key = tier
        monster_filter_configs[monster_filter_key] = {
            ['不打Boss'] = config['不打Boss'] or false,
            ['不打白怪'] = config['不打白怪'] or false,
            ['不打藍怪'] = config['不打藍怪'] or false,
            ['不打黃怪'] = config['不打黃怪'] or false,
            ['開箱子'] = tostring(config['開箱子'] or ""):gsub("^%s*(.-)%s*$", "%1")
        }
    end


    -- 更新地图配置，整合所有数据
    map_cfg['異界地圖索引'] = {
        ['按层级'] = tier_index,
        ['按配置'] = config_index,
        ['总数量'] = #void_maps,
        ['涂油设置'] = oil_configs,
        ['通货使用'] = currency_configs,
        ['怪物过滤'] = monster_filter_configs
    }
end
return _M
