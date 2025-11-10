local _M = {} -- 主接口表
local json = require 'script.lualib.json'
local my_game_info = require 'script\\my_game_info'
local game_str = require 'script\\game_str'
local BD_data = require 'script\\BD'

local CELL_WIDTH = 43.81  -- 每个格子宽度
local CELL_HEIGHT = 43.81  -- 每个格子高度
local START_X = 1059   -- 起始X坐标
local START_Y = 492    -- 起始Y坐标
local START_X_STORE = 12   -- 起始X坐标
local START_Y_STORE = 102 
local START_X_max = 15  -- 超大仓库 起始X坐标
local START_Y_max = 100  -- 超大仓库 起始X坐标
local CELL_WIDTH_max = 22  -- 超大仓库 每个格子宽度
local CELL_HEIGHT_max = 22  -- 超大仓库 每个格子高度
local last_record_time = nil  -- 上次记录的时间戳
local INTERVAL = 10          -- 间隔时间（秒）

_M.point_distance = function(x, y, ac)
    -- 检查参数有效性
    if type(x) ~= "number" or type(y) ~= "number" then
        _M.dbgp("检查参数有效性")
        return nil
    end
    
    -- 获取参考坐标
    local ref_x, ref_y = 0, 0
    
    if type(ac) == "table" then
        -- 处理不同的表结构
        if ac.grid_x and ac.grid_y then
            -- 玩家信息表结构
            ref_x = ac.grid_x or 0
            ref_y = ac.grid_y or 0
        elseif #ac >= 2 then
            -- 数组结构 [x, y]
            ref_x = ac[1] or 0
            ref_y = ac[2] or 0
        else
            -- 无效的表结构
            _M.dbgp("无效的表结构")
            return nil
        end
    elseif ac then
        ref_x = ac.grid_x or 0
        ref_y = ac.grid_y or 0
    else
        -- ac 不是表，无法获取坐标
        _M.dbgp("不是表，无法获取坐标")
        return nil
    end
    
    -- 检查坐标是否为有效数字
    if type(ref_x) ~= "number" or type(ref_y) ~= "number" then
        _M.dbgp("333")
        return nil
    end
    
    -- 情况1: 两个坐标完全相同
    if x == ref_x and y == ref_y then
        return 0  -- 完全相同，距离为0
    end
    
    -- 情况2: 两个坐标不同但计算后距离为0（由于浮点数精度）
    local dx = x - ref_x
    local dy = y - ref_y
    
    -- 处理浮点数精度问题
    local epsilon = 1e-10  -- 很小的阈值
    
    if math.abs(dx) < epsilon and math.abs(dy) < epsilon then
        return 0  -- 实际距离接近0，视为相同坐标
    end
    
    -- 计算欧几里得距离
    local distance_squared = dx * dx + dy * dy
    
    -- 防止数学错误
    if distance_squared < 0 then
        _M.dbgp("111")
        return nil
    end
    
    local distance = math.sqrt(distance_squared)
    
    -- 再次检查浮点数精度（距离非常接近0）
    if distance < epsilon then
        return 0
    end
    
    -- 确保返回有效数字
    if type(distance) == "number" and distance >= 0 then
        return distance
    else
        _M.dbgp("222")
        return nil
    end
end

-- 查找文本
_M.find_text = function(params)
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
        UI_info = nil,
        times = 200,
        not_name_utf8 = false,
        print_log = false,
        delay = 50
    }
    
    -- 合并传入参数和默认值
    for k, v in pairs(params) do defaults[k] = v end

    -- 参数验证
    if type(defaults.text) ~= "string" and type(defaults.text) ~= "table" then
        error("find_text: text参数必须是字符串或表格")
        return false
    end

    -- _M.dbgp("defaults.text -->", defaults.text)

    -- 如果需要刷新或没有UI信息，则更新UI信息
    if defaults.refresh or not defaults.UI_info then
        _M.dbgp("defaults.refresh\n")
        _M.dbgp("defaults.text -->", defaults.text)
        defaults.UI_info = UiElements:Update()
        if not defaults.UI_info or #defaults.UI_info < 1 then
            _M.dbgp("未发现UI信息\n")
            return false
        end
    end

    -- 辅助函数：检查文本匹配
    local function is_text_match(text_to_check, target_texts, match_type)
        if match_type == 2 then -- 部分匹配
            if type(target_texts) == "table" then
                for _, v in ipairs(target_texts) do
                    if string.find(text_to_check, v) then
                        return true
                    end
                end
            else
                return string.find(text_to_check, target_texts)
            end
        else -- 完全匹配
            if type(target_texts) == "table" then
                for _, v in ipairs(target_texts) do
                    if v == text_to_check then
                        return true
                    end
                end
            else
                return text_to_check == target_texts
            end
        end
        return false
    end

    -- 辅助函数：执行点击操作
    local function perform_click(x, y, click_type, add_x, add_y)
        local final_x = x
        local final_y = y
        if (not add_x or add_x == 0) and (not add_y or add_y == 0) then
            _M.dbgp("add_x, add_y")
            local a = math.random(-15, 15)
            final_x = math.floor(x + a)
            local b = math.random(-5, 5)
            final_y = math.floor(y + b)
        else
            final_x = math.floor(x + add_x)
            final_y = math.floor(y + add_y)
        end
        
        _M.dbgp("文本坐标",final_x, final_y)
        if click_type == 1 then
            api_ClickScreen(final_x, final_y, 0)
        elseif click_type == 2 then
            api_ClickScreen(final_x, final_y, 0)
            api_Sleep(times)
            api_ClickScreen(final_x, final_y, 1)
            api_Sleep(100)
        elseif click_type == 3 then
            local hold_time = 8
            api_ClickScreen(final_x, final_y, 3)
            api_Sleep(hold_time * 1000)
            api_ClickScreen(final_x, final_y, 4)
        elseif click_type == 4 then
            _M.ctrl_left_click(final_x, final_y)
        elseif click_type == 5 then
            _M.ctrl_right_click(final_x, final_y)
        elseif click_type == 6 then
            api_Sleep(times)
            api_ClickScreen(final_x, final_y, 2)
            api_Sleep(100)
        elseif click_type == 7 then
            api_ClickScreen(final_x, final_y, 2)
        end
    end

    -- 辅助函数：执行点击操作
    local function perform_click_delay(x, y, click_type, add_x, add_y)
        local final_x = x
        local final_y = y
        if (not add_x or add_x == 0) and (not add_y or add_y == 0) then
            local a = math.random(-15, 15)
            final_x = math.floor(x + a)
            local b = math.random(-5, 5)
            final_y = math.floor(y + b)
        else
            final_x = math.floor(x + add_x)
            final_y = math.floor(y + add_y)
        end
        _M.dbgp("文本坐标",final_x, final_y)
        if click_type == 1 then
            api_ClickScreen(final_x, final_y, 0, defaults.delay, defaults.delay + 15)
        elseif click_type == 2 then
            -- api_ClickScreen(final_x, final_y, 0, defaults.delay, defaults.delay + 15)
            -- api_Sleep(times)
            api_ClickScreen(final_x, final_y, 1, defaults.delay, defaults.delay + 15)
            api_Sleep(100)
        elseif click_type == 3 then
            local hold_time = 8
            api_ClickScreen(final_x, final_y, 3, defaults.delay, defaults.delay + 15)
            api_Sleep(hold_time * 1000)
            api_ClickScreen(final_x, final_y, 4, defaults.delay, defaults.delay + 15)
        elseif click_type == 4 then
            _M.ctrl_left_click(final_x, final_y)
        elseif click_type == 5 then
            _M.ctrl_right_click(final_x, final_y)
        elseif click_type == 6 then
            api_Sleep(times)
            api_ClickScreen(final_x, final_y, 2, defaults.delay, defaults.delay + 15)
            api_Sleep(100)
        elseif click_type == 7 then
            api_ClickScreen(final_x, final_y, 2, defaults.delay, defaults.delay + 15)
        end
    end

    -- 处理排序模式
    if defaults.sorted then
        -- _M.dbgp("进入排序模式\n")
        local text_list = {}
        
        for _, actor in ipairs(defaults.UI_info) do
            if actor.text_utf8 and actor.text_utf8 ~= "" then
                if defaults.min_x <= actor.left and actor.left <= defaults.max_x and 
                   defaults.min_y <= actor.top and actor.top <= defaults.max_y then
                    if is_text_match(actor.text_utf8, defaults.text, defaults.match) then
                        table.insert(text_list, actor)
                    end
                end
            end
        end

        -- _M.printTable(text_list)

        if #text_list > 0 then
            -- 计算与屏幕中心(800,450)的距离并排序
            table.sort(text_list, function(a, b)
                local a_center_x = (a.left + a.right) / 2
                local a_center_y = (a.top + a.bottom) / 2
                local b_center_x = (b.left + b.right) / 2
                local b_center_y = (b.top + b.bottom) / 2

                local dist_a = (a_center_x - 800)^2 + (a_center_y - 450)^2
                local dist_b = (b_center_x - 800)^2 + (b_center_y - 450)^2
                return dist_a < dist_b
            end)

            local center_x = (text_list[1].left + text_list[1].right) / 2
            local center_y = (text_list[1].top + text_list[1].bottom) / 2
            
            if defaults.click > 0 and defaults.delay == 0 then
                perform_click(center_x, center_y, defaults.click, defaults.add_x, defaults.add_y)
            elseif defaults.click > 0 and defaults.delay > 0 then
                perform_click_delay(center_x, center_y, defaults.click, defaults.add_x, defaults.add_y)
            end
            
            return true
        end
        
        return false
    end

    -- 处理非排序模式
    for _, actor in ipairs(defaults.UI_info) do
        if actor.text_utf8 == "" or not actor.text_utf8 then
            goto continue
        end
        if defaults.not_name_utf8 then
            if actor.name_utf8 == "" or not actor.name_utf8 then
                goto continue
            end
        end
        -- if defaults.print_log then
        --     _M.dbgp("------------------")
        --     _M.dbgp(actor.text_utf8)
        --     _M.dbgp(actor.left, actor.right)
        --     _M.dbgp(actor.top, actor.bottom)
        -- end
        if defaults.min_x <= actor.left and actor.left <= defaults.max_x and
           defaults.min_y <= actor.top and actor.top <= defaults.max_y then
            
            if actor.text_utf8 and is_text_match(actor.text_utf8, defaults.text, defaults.match) then
                local center_x = (actor.left + actor.right) / 2
                local center_y = (actor.top + actor.bottom) / 2
                -- _M.dbgp("actor.text_utf8 -- >",actor.text_utf8)
                -- _M.dbgp("actor.left -- >",actor.left)
                -- _M.dbgp("actor.right -- >",actor.right)
                -- _M.dbgp("actor.top -- >",actor.top)
                -- _M.dbgp("actor.bottom -- >",actor.bottom)
                if defaults.click > 0 then
                    perform_click(center_x, center_y, defaults.click, defaults.add_x, defaults.add_y)
                end
                
                if defaults.position == 1 then
                    return {actor.left, actor.top, actor.right, actor.bottom}
                elseif defaults.position == 2 then
                    return actor
                elseif defaults.position == 3 then
                    return {
                        math.floor(center_x + defaults.add_x),
                        math.floor(center_y + defaults.add_y)
                    }
                end
                return true
            end
        end
        ::continue::
    end

    return false
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
        "show_guild_chat=true","map_overlay_mods_hidden=false"
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
            -- return false
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
        {"show_guild_chat=true", "show_guild_chat=false"},
        {"map_overlay_mods_hidden=false", "map_overlay_mods_hidden=true"}
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
    _M.dbgp(cmd)
    -- local handle = io.popen(cmd .. " 2>&1", "r") -- 合并 stderr 到 stdout
    -- local output = handle:read("*a")
    -- local success, exit_code = handle:close()
    os.execute(cmd)
    
    return 1 or -1 -- 如果失败返回 -1
end

-- 安全转为整数（带空值处理）
_M.toInt = function(value, default)
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
    range_info = params.range_info or nil
    player_info = params.player_info
    dis = params.dis or 180
    not_sight = params.not_sight or false
    stuck_monsters = params.stuck_monsters or nil
    not_attack_mos = params.not_attack_mos or nil
    is_active = params.is_active

    if is_active == nil then
        is_active = true
    end

    -- 快速失败检查
    if not params.range_info then 
        _M.dbgp("快速失败检查")
        params.range_info = Actors:Update()
    end
    

    -- 怪物检查主逻辑
    for _, monster in ipairs(params.range_info) do
        -- 快速跳过不符合基本条件的怪物
        if monster.type ~= 1 or                  -- 类型检查
        not monster.is_selectable or          -- 可选性检查
        monster.is_friendly or                -- 友方检查
        monster.life <= 0 or                  -- 生命值检查
        monster.name_utf8 == "" or              -- 名称检查
        _M.table_contains(my_game_info.not_attact_mons_CN_name,monster.name_utf8) or
        _M.table_contains(my_game_info.not_attact_mons_path_name,monster.path_name_utf8)then  -- 路径名检查
            goto continue
        end

        -- if string.find(monster.path_name_utf8,"Metadata/Monsters/TormentedSpirits") then
        --     goto continue
        -- end

        if is_active and not monster.isActive then
            goto continue
        end

        -- 检查坐标有效性
        if not monster.grid_x or not monster.grid_y then
            goto continue
        end

        -- 检查不攻击的怪物
        -- _M.print_log("检查不攻击的怪物")
        if params.not_attack_mos then
            if _M.table_contains(params.not_attack_mos,monster.rarity) then
                goto continue
            end
        end

        -- 检查卡住状态
        if params.stuck_monsters and next(params.stuck_monsters) and _M.table_contains(params.stuck_monsters,monster.id) then
            goto continue
        end

        -- 计算距离
        local distance = _M.point_distance(monster.grid_x, monster.grid_y, player_info)
        -- _M.dbgp("计算距离：",distance,"==============================",dis)
        -- _M.print_log("计算距离：",distance)
        -- _M.printTable(monster)
        if distance and distance <= dis then
            -- 检查视野
            if params.not_sight then
                return true
            elseif not params.not_sight and monster.hasLineOfSight and api_HasObstacleBetween(monster.grid_x, monster.grid_y) then
                return true
            end
            
        end
        
        ::continue::
    end
    
    return false
end

--- 获取范围内所有符合条件的怪物列表（包含详细信息）
_M.get_mos_list_in_range = function(params)
    -- 参数默认值与校验
    range_info = params.range_info or nil
    player_info = params.player_info
    dis = params.dis or 60
    not_sight = params.not_sight or false
    stuck_monsters = params.stuck_monsters or nil
    not_attack_mos = params.not_attack_mos or nil
    is_active = params.is_active

    if is_active == nil then
        is_active = true
    end

    -- 初始化怪物列表
    local monster_list = {}

    -- 快速失败检查
    if not params.range_info then 
        _M.dbgp("更新怪物信息")
        params.range_info = Actors:Update()
    end

    -- 怪物检查主逻辑
    for _, monster in ipairs(params.range_info) do
        -- 快速跳过不符合基本条件的怪物
        if monster.type ~= 1 or                  -- 类型检查
        not monster.is_selectable or          -- 可选性检查
        monster.is_friendly or                -- 友方检查
        monster.life <= 0 or                  -- 生命值检查
        monster.name_utf8 == "" or              -- 名称检查
        _M.table_contains(my_game_info.not_attact_mons_CN_name, monster.name_utf8) or
        _M.table_contains(my_game_info.not_attact_mons_path_name, monster.path_name_utf8) then  -- 路径名检查
            goto continue
        end

        if is_active and not monster.isActive then
            goto continue
        end

        -- 检查坐标有效性
        if not monster.grid_x or not monster.grid_y then
            goto continue
        end

        -- 检查不攻击的怪物
        if params.not_attack_mos then
            if _M.table_contains(params.not_attack_mos, monster.rarity) then
                goto continue
            end
        end

        -- 检查卡住状态
        if params.stuck_monsters and next(params.stuck_monsters) and _M.table_contains(params.stuck_monsters, monster.id) then
            goto continue
        end

        -- 计算距离
        local distance = _M.point_distance(monster.grid_x, monster.grid_y, player_info)
        
        if distance and distance <= dis then
            -- 检查视野
            local valid = false
            if params.not_sight then
                valid = true
            elseif not params.not_sight and monster.hasLineOfSight and not api_HasObstacleBetween(monster.grid_x, monster.grid_y) then
                valid = true
            end
            
            if valid then
                -- 添加怪物信息到列表
                table.insert(monster_list, {
                    id = monster.id,
                    name = monster.name_utf8,
                    path_name = monster.path_name_utf8,
                    grid_x = monster.grid_x,
                    grid_y = monster.grid_y,
                    distance = distance,
                    rarity = monster.rarity,
                    life = monster.life,
                    max_life = monster.max_life
                })
            end
        end
        
        ::continue::
    end
    
    return monster_list
end

--- 查找范围内符合条件的怪物数量
_M.count_mos_in_range = function(params)
    -- 参数默认值与校验
    range_info = params.range_info or nil
    player_info = params.player_info
    dis = params.dis or 60
    not_sight = params.not_sight or false
    stuck_monsters = params.stuck_monsters or nil
    not_attack_mos = params.not_attack_mos or nil
    is_active = params.is_active

    if is_active == nil then
        is_active = true
    end

    -- 初始化计数器
    local count = 0

    -- 快速失败检查
    if not params.range_info then 
        _M.dbgp("更新怪物信息")
        params.range_info = Actors:Update()
    end

    -- 怪物检查主逻辑
    for _, monster in ipairs(params.range_info) do
        -- 快速跳过不符合基本条件的怪物
        if monster.type ~= 1 or                  -- 类型检查
        not monster.is_selectable or          -- 可选性检查
        monster.is_friendly or                -- 友方检查
        monster.life <= 0 or                  -- 生命值检查
        monster.name_utf8 == "" or              -- 名称检查
        _M.table_contains(my_game_info.not_attact_mons_CN_name, monster.name_utf8) or
        _M.table_contains(my_game_info.not_attact_mons_path_name, monster.path_name_utf8) then  -- 路径名检查
            goto continue
        end

        if is_active and not monster.isActive then
            goto continue
        end

        -- 检查坐标有效性
        if not monster.grid_x or not monster.grid_y then
            goto continue
        end

        -- 检查不攻击的怪物
        if params.not_attack_mos then
            if _M.table_contains(params.not_attack_mos, monster.rarity) then
                goto continue
            end
        end

        -- 检查卡住状态
        if params.stuck_monsters and next(params.stuck_monsters) and _M.table_contains(params.stuck_monsters, monster.id) then
            goto continue
        end

        -- 计算距离
        local distance = _M.point_distance(monster.grid_x, monster.grid_y, player_info)
        
        if distance and distance <= dis then
            -- 检查视野
            if params.not_sight then
                count = count + 1
            elseif not params.not_sight and monster.hasLineOfSight and api_HasObstacleBetween(monster.grid_x, monster.grid_y) then
                count = count + 1
            end
        end
        
        ::continue::
    end
    
    return count
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
_M.is_have_mos_boss = function(range_info, boss_list)
    if not boss_list then return false end

    BOSS_WHITELIST = {'多里亞尼'}
    MOB_BLACKLIST = {"惡魔", '複製體', "隱形", "複製之躰"}
    rarity_list = {3}

    for _, monster in ipairs(range_info) do
        if monster.is_selectable and not monster.is_friendly and monster.life > 0 and monster.name_utf8 and _M.table_contains(rarity_list, monster.rarity) then
            -- 通用Boss判断
            if not _M.table_contains(monster.name_utf8, MOB_BLACKLIST) and monster.isActive and (_M.table_contains(monster.name_utf8, boss_list) or monster.life >0) then
                return true
            end
        end
    end
    -- _M.dbgp("没有Boss")
    return false
end

--- 模拟键盘按键操作
-- @param click_str string 按键字符串（如"A", "Enter"等）
-- @param[opt] click_type number 按键类型：0=单击, 1=按下, 2=抬起
_M.click_keyboard = function(click_str, click_type)
    _M.dbgp("模拟键盘按键操作：", click_str, click_type)
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

--- 输入多位数字
-- @param numbers number|string|table 要输入的数字（可以是数字、字符串或数字表）
-- @param[opt] delay number 每个按键之间的延迟（毫秒）
_M.input_numbers = function(numbers, delay)
    delay = delay or 50  -- 默认50毫秒延迟
    
    if numbers == nil then
        _M.dbgp("错误：数字不能为空")
        return false
    end
    
    local num_str
    if type(numbers) == "table" then
        -- 处理数字表
        num_str = table.concat(numbers)
    else
        -- 处理数字或字符串
        num_str = tostring(numbers)
    end
    
    -- 验证是否为有效数字
    if not num_str:match("^%d+$") then
        _M.dbgp("错误：只能输入数字（0-9）")
        return false
    end
    
    _M.dbgp("开始输入数字：", num_str)
    
    -- 逐个输入数字
    for i = 1, #num_str do
        local digit = num_str:sub(i, i)
        _M.click_keyboard(digit, 0)  -- 单击数字键
        
        if delay > 0 and i < #num_str then
            api_Sleep(delay)  -- 添加延迟，避免输入过快
        end
    end
    
    return true
end

-- 左ctrl+左键
_M.ctrl_left_click = function(x, y)
    if x and y then
        _M.click_keyboard('ctrl', 1) -- 使用正确的按键代码
        api_Sleep(200)
        api_ClickScreen(math.floor(x), math.floor(y), 0) -- 使用click方法模拟右键点击
        api_Sleep(200) -- 0.1秒 = 100毫秒
        api_ClickScreen(math.floor(x), math.floor(y), 1) -- 使用click方法模拟左键点击
        api_Sleep(200)
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

-- 获取背包物品中心点
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
    return {math.floor(center_x + 0.5), math.floor(center_y + 0.5)}
end

-- 获取仓库物品中心点
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

            local center = _M.get_center_position_store(
                {actor.start_x, actor.start_y},
                {actor.end_x, actor.end_y}
            )

            -- 支持左键/右键点击
            if click_type == 1 then  
                _M.right_click(center[1], center[2])
            else
                _M.ctrl_left_click(center[1], center[2])
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
    table.insert(parts, "*print_log* ")
    -- 处理每个参数
    for i, v in ipairs(args) do
        local vType = type(v)
        local formatted
        
        if vType == "table" then
            formatted = "{table} "..tostring(v)
        elseif vType == "function" then
            formatted = "{function} "..tostring(v)
        elseif vType == "userdata" then
            formatted = "{userdata} "..tostring(v)
        elseif vType == "thread" then
            formatted = "{thread} "..tostring(v)
        else
            formatted = tostring(v)
        end
        
        table.insert(parts, formatted)
    end
    
    -- 用制表符连接多个参数，并加上换行符
    local formattedText = table.concat(parts, "\t") .. "\n"
    
    -- 调用日志函数
    api_Log(formattedText)
    -- -- 或者使用标准print
    -- print(formattedText)
end

-- 简洁版调试打印函数（自动类型识别）
_M.dbgp = function(...)
    local args = {...}
    local parts = {}
    table.insert(parts, "*dbgp* ")
    -- 处理每个参数
    for i, v in ipairs(args) do
        local vType = type(v)
        local formatted
        
        if vType == "table" then
            formatted = "{table} "..tostring(v)
        elseif vType == "function" then
            formatted = "{function} "..tostring(v)
        elseif vType == "userdata" then
            formatted = "{userdata} "..tostring(v)
        elseif vType == "thread" then
            formatted = "{thread} "..tostring(v)
        else
            formatted = tostring(v)
        end
        
        table.insert(parts, formatted)
    end
    
    -- 用制表符连接多个参数，并加上换行符
    local formattedText = table.concat(parts, "\t") .. "\n"
    
    -- 调用日志函数
    api_Log(formattedText)
    -- 或者使用标准print
    -- print(formattedText)
end
_M.dbgp1 = function(...)
    -- local args = {...}
    -- local parts = {}
    -- table.insert(parts, "*dbgp* ")
    -- -- 处理每个参数
    -- for i, v in ipairs(args) do
    --     local vType = type(v)
    --     local formatted
        
    --     if vType == "table" then
    --         formatted = "{table} "..tostring(v)
    --     elseif vType == "function" then
    --         formatted = "{function} "..tostring(v)
    --     elseif vType == "userdata" then
    --         formatted = "{userdata} "..tostring(v)
    --     elseif vType == "thread" then
    --         formatted = "{thread} "..tostring(v)
    --     else
    --         formatted = tostring(v)
    --     end
        
    --     table.insert(parts, formatted)
    -- end
    
    -- -- 用制表符连接多个参数，并加上换行符
    -- local formattedText = table.concat(parts, "\t") .. "\n"
    
    -- -- 调用日志函数
    -- api_Log(formattedText)
    -- 或者使用标准print
    -- print(formattedText)
end

-- 时间调试（内部阈值设为100毫秒）
_M.time_p = function(...)
    local threshold = 5  -- 内部设定的阈值（毫秒）
    local args = {...}
    
    -- 检查是否是耗时日志格式：倒数第二个参数包含"耗时 -->"且最后一个参数是数字
    -- if #args >= 2 and 
    --    type(args[#args]) == "number" and 
    --    tostring(args[#args-1]):find("耗时 %-%->") then
        
    --     local elapsed = args[#args]  -- 获取耗时值
        
    --     -- 只有耗时超过阈值时才处理
    --     if elapsed < threshold then
    --         return  -- 不满足阈值条件，直接返回
    --     end
    -- end
    
    -- 以下是原有的日志处理逻辑
    local parts = {}
    table.insert(parts, "*time_p* ")
    
    -- 处理每个参数
    for i, v in ipairs(args) do
        local vType = type(v)
        local formatted
        
        if vType == "table" then
            formatted = "{table} "..tostring(v)
        elseif vType == "function" then
            formatted = "{function} "..tostring(v)
        elseif vType == "userdata" then
            formatted = "{userdata} "..tostring(v)
        elseif vType == "thread" then
            formatted = "{thread} "..tostring(v)
        else
            formatted = tostring(v)
        end
        
        table.insert(parts, formatted)
    end
    
    -- 用制表符连接多个参数，并加上换行符
    local formattedText = table.concat(parts, "\t") .. "\n"
    
    -- 调用日志函数
    api_Log(formattedText)
    -- 或者使用标准print
    -- print(formattedText)
end

-- 技能调试
_M.skp = function(...)
    local args = {...}
    local parts = {}

    -- 把每个参数转成字符串（模拟 print 的行为）
    for i, v in ipairs(args) do parts[i] = tostring(v) end

    -- 用制表符（\t）连接多个参数，并加上换行符（\n）
    local formattedText = table.concat(parts, "\t") .. "\n"

    -- 调用 api_Log（假设它只接受一个字符串参数）
    -- api_Log(formattedText)
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
        if _M.table_contains(my_game_info.not_attact_mons_CN_name,unit.name_utf8) or
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
        if _M.table_contains(my_game_info.not_attact_mons_CN_name,monster.name_utf8) or
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
_M.monster_monitor = function(threshold, UI_Info)
    threshold = threshold or 40
    local pattern = "剩餘 (%d+) 隻怪物"

    for _, control in ipairs(UI_Info) do
        if control.text_utf8 then
            local text = control.text_utf8 and
                             control.text_utf8:match("^%s*(.-)%s*$") or ""
            local count = text:match(pattern)
            count = tonumber(count)

            if count and count <= threshold then
                if count == 0 then
                    return true
                end
                return _M.toInt(count) <= threshold
            end
        end
    end
    return false
end


-- 选择异界地图
_M.get_map_oringin = function(params)
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
    local not_have_stackableCurrency = params.not_have_stackableCurrency or false
    local enter_city = params.enter_city or false

    _M.dbgp("[DEBUG] 开始执行 get_map 函数")
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

        -- 检查是否进入城寨
        if _M.table_contains(map_data.name_utf8, my_game_info.Citadel_map) then
            if enter_city then
                -- _M.dbgp("[DEBUG] 地图包含城寨模式")
                local map_level = _M.select_best_map_key({
                    inventory = bag_info,
                    key_level_threshold = key_level_threshold,
                    not_use_map = not_use_map,
                    priority_map = priority_map,
                    min_level = 15
                })
                -- _M.printTable(map_level)
                -- while true do
                --     api_Sleep(1000)
                -- end
                if not map_level then
                    return -1
                else
                    return 9999
                end
            end
            return -1
        end

        if _M.table_contains(map_data.mapPlayModes, "腐化聖域") then
            -- _M.dbgp("[DEBUG] 地图包含腐化聖域模式")
            local map_level = _M.select_best_map_key({
                inventory = bag_info,
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

        if _M.table_contains(map_data.mapPlayModes, game_str.Legendary_Map_MPMD) then
            if not sorted_map or not next(sorted_map) or not _M.table_contains(sorted_map, game_str.Legendary_Map_MPMD) then
                return -1
            end
            -- _M.dbgp("[DEBUG] 地图是傳奇地圖")
            if _M.table_contains(map_data.name_cn_utf8, {game_str.MapUniqueParadise_TWCH, game_str.MapUniqueLake_TWCH, game_str.MapUniqueWildwood_TWCH, game_str.MapUniqueSelenite_TWCH, game_str.MapUniqueMegalith_TWCH}) then
                -- _M.dbgp("[DEBUG] 是純净樂園，得分: 9999")
                local map_level = _M.select_best_map_key({
                    inventory = bag_info,
                    key_level_threshold = key_level_threshold,
                    not_use_map = not_use_map,
                    priority_map = priority_map,
                    min_level = 11
                })
                if map_level then
                    map_level = _M.extract_key_level(map_level.baseType_utf8)
                    if map_level and map_level < 11 then
                        return -1
                    else
                        return 9999
                    end
                end
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
                else
                    return 9999
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
                    if mode == "深渊" and _M.table_contains(map_data.mapPlayModes, "Abyss") then
                        has_required = true
                        break
                    end
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
            _M.dbgp(string.format(  "[DEBUG] 阶段 %d 找到 %d 个有效地图", i + 1, #valid_maps))
            -- 按总分降序排序
            table.sort(valid_maps, function(a, b)
                return a.score > b.score
            end)

            -- 打印前3个最佳地图
            -- for j = 1, math.min(3, #valid_maps) do
            --     _M.dbgp(string.format("[DEBUG] 排名 %d: %s (得分: %d)", j, valid_maps[j].map.name_cn_utf8 or "未知", valid_maps[j].score))
            -- end

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

-- 选择异界地图
_M.get_map3 = function(params)
    -- 解析参数表
    local otherworld_info = params.otherworld_info or {}

    -- 分阶段查找最佳地图
    local maps_Portal = nil
    for _, map_data in ipairs(otherworld_info) do

        if map_data.name_utf8 == "MapLeaguePortal" then
            maps_Portal = map_data
            _M.printTable(map_data)
            -- break
        end

        ::continue::
    end
    
    -- _M.dbgp("[DEBUG] 最终未找到合适地图，返回nil")
    return maps_Portal
end

-- 选择异界地图
_M.get_map1 = function(params)
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
                inventory = bag_info,
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
        if _M.table_contains(map_data.mapPlayModes, game_str.Legendary_Map_MPMD) then
            if not sorted_map or not next(sorted_map) or not _M.table_contains(sorted_map, game_str.Legendary_Map_MPMD) then
                return -1
            end
            -- _M.dbgp("[DEBUG] 地图是傳奇地圖")
            if _M.table_contains(map_data.name_cn_utf8, {game_str.MapUniqueParadise_TWCH, game_str.MapUniqueLake_TWCH, game_str.MapUniqueWildwood_TWCH, game_str.MapUniqueSelenite_TWCH, game_str.MapUniqueMegalith_TWCH}) then
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
                    if mode == "深渊" and _M.table_contains(map_data.mapPlayModes, "Abyss") then
                        has_required = true
                        break
                    end
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
            _M.dbgp(string.format(  "[DEBUG] 阶段 %d 找到 %d 个有效地图", i + 1, #valid_maps))
            -- 按总分降序排序
            table.sort(valid_maps, function(a, b)
                return a.score > b.score
            end)

            -- 打印前3个最佳地图
            -- for j = 1, math.min(3, #valid_maps) do
            --     _M.dbgp(string.format("[DEBUG] 排名 %d: %s (得分: %d)", j, valid_maps[j].map.name_cn_utf8 or "未知", valid_maps[j].score))
            -- end

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

-- 选择异界地图
_M.get_map2 = function(params)
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
    local not_have_stackableCurrency = params.not_have_stackableCurrency or false
    local current_position = params.currency_point or {x = 0, y = 0} -- 添加当前位置参数

    local PRIORITY_MAPS = {
        'MapBluff', -- 绝壁
        'MapBluff_NoBoss', 'MapSwampTower', -- 沉溺尖塔
        'MapSwampTower_NoBoss', 'MapLostTowers', -- 失落尖塔
        'MapLostTowers_NoBoss', 'MapAlpineRidge', 'MapAlpineRidge_NoBoss',
        'MapMesa', -- 平顶荒漠
        'MapMesa_NoBoss'
    }

    -- 计算两点之间的曼哈顿距离
    local function manhattan_distance(x1, y1, x2, y2)
        return math.abs(x1 - x2) + math.abs(y1 - y2)
    end

    -- 计算地图得分的内部函数
    local function calculate_score(map_data, required_modes)
        -- 基础条件检查（一票否决）
        if not map_data.name_utf8 then
            return -1
        end
        if _M.table_contains(my_game_info.trash_map, map_data.name_utf8) then
            return -1
        end
        if _M.table_contains(map_data.mapPlayModes, "腐化聖域") then
            return 9999
        end
        if _M.table_contains(map_data.mapPlayModes, game_str.Legendary_Map_MPMD) then
            if not sorted_map or not next(sorted_map) or not _M.table_contains(sorted_map, game_str.Legendary_Map_MPMD) then
                return -1
            end
            -- _M.dbgp("[DEBUG] 地图是傳奇地圖")
            if _M.table_contains(map_data.name_cn_utf8, {game_str.MapUniqueParadise_TWCH, game_str.MapUniqueLake_TWCH, game_str.MapUniqueWildwood_TWCH, game_str.MapUniqueSelenite_TWCH, game_str.MapUniqueMegalith_TWCH}) then
                -- _M.dbgp("[DEBUG] 是純净樂園，得分: 9999")
                return 9999
            end
            -- _M.dbgp("[DEBUG] 不是純净樂園，得分: -1")
            return -1
        end
        if not_enter_map and
            _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
            return -1
        end
        if not (map_data.isMapAccessible or true) or map_data.isCompleted then
            return -1
        end

        -- 检查必须包含的模式（如果有）
        if required_modes then
            -- 单独处理"先行者高塔"的特殊判断
            if _M.table_contains(required_modes, "先行者高塔") then
                if not _M.table_contains(PRIORITY_MAPS, map_data.name_utf8) then
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
            end

            -- 检查剩余的模式（不包括"先行者高塔"）
            if #required_modes > 0 then
                local has_required = false
                for _, mode in ipairs(required_modes) do
                    if _M.table_contains(map_data.mapPlayModes, mode) then
                        has_required = true
                        break
                    end
                end
                if not has_required then
                    return -1
                end
            end
        end

        -- 初始化评分项
        local score = 0
        local play_modes = map_data.mapPlayModes or {}

        -- 1. 计算sorted_map中的玩法模式匹配
        if #sorted_map > 0 and #play_modes > 0 then
            local matched_score = 0
            local matched_count = 0
            for i, mode in ipairs(sorted_map) do
                if _M.table_contains(play_modes, mode) then
                    -- 越靠前的模式权重越高（100 - 索引位置）
                    local mode_score = 100 - i
                    matched_score = matched_score + mode_score
                    matched_count = matched_count + 1
                end
            end

            -- 匹配数量加成（每个匹配模式额外加50分）
            local count_bonus = matched_count * 100
            score = score + matched_score + count_bonus
        end

        -- 2. 玩法模式总数（基础分）
        local mode_count_score = #play_modes * 100
        score = score + mode_count_score

        -- 3. 距离分数（距离越近分数越高）
        local distance = manhattan_distance(current_position.x, current_position.y, 
                                          map_data.position_x or 0, map_data.position_y or 0)
        local distance_score = math.max(0, 500 - distance * 10) -- 距离每增加1，分数减少10
        score = score + distance_score

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

    -- 首先找到最近的优先地图位置作为中心点
    local center_x, center_y = current_position.x, current_position.y
    local min_distance = math.huge
    local found_priority_center = false
    
    for _, map_data in ipairs(otherworld_info) do
        if _M.table_contains(PRIORITY_MAPS, map_data.name_utf8) then
            local distance = manhattan_distance(current_position.x, current_position.y,
                                              map_data.position_x or 0, map_data.position_y or 0)
            if distance < min_distance then
                min_distance = distance
                center_x, center_y = map_data.position_x or 0, map_data.position_y or 0
                found_priority_center = true
            end
        end
    end

    -- 分阶段查找最佳地图，按辐射距离排序
    local valid_maps = {}
    for i = 0, #effective_sorted_map do
        local required_modes = {}
        if i < #effective_sorted_map then
            for j = 1, i + 1 do
                table.insert(required_modes, effective_sorted_map[j])
            end
        end

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
                if #required_modes == 0 then
                    required_modes = nil
                end
            end
        end

        -- 按距离中心点的曼哈顿距离排序地图
        local sorted_by_distance = {}
        for _, map_data in ipairs(otherworld_info) do
            local distance = manhattan_distance(center_x, center_y,
                                              map_data.position_x or 0, map_data.position_y or 0)
            table.insert(sorted_by_distance, {map = map_data, distance = distance})
        end
        
        table.sort(sorted_by_distance, function(a, b)
            return a.distance < b.distance
        end)

        -- 按距离顺序检查地图
        for _, item in ipairs(sorted_by_distance) do
            local map_data = item.map

            -- 检查错误地图
            if #error_other_map > 0 then
                local is_error = false
                for _, m in ipairs(error_other_map) do
                    if map_data.index_x == m.index_x and map_data.index_y == m.index_y then
                        is_error = true
                        break
                    end
                end
                if is_error then
                    goto continue
                end
            end

            -- 检查禁止进入的地图
            if #not_enter_map > 0 and
                _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
                goto continue
            end

            local score = calculate_score(map_data, #required_modes > 0 and
                                              required_modes or nil)
            if score >= 0 then
                table.insert(valid_maps, {
                    score = score, 
                    map = map_data,
                    distance = manhattan_distance(current_position.x, current_position.y,
                                                map_data.position_x or 0, map_data.position_y or 0)
                })
            end

            ::continue::
        end

        if #valid_maps > 0 then
            -- 按总分降序排序，距离作为次要排序条件
            table.sort(valid_maps, function(a, b)
                if a.score == b.score then
                    return a.distance < b.distance
                end
                return a.score > b.score
            end)
            return valid_maps[1].map
        end
    end

    -- 如果没有找到符合条件的地图，尝试不要求任何特定模式
    if #valid_maps == 0 then
        -- 按距离中心点的曼哈顿距离排序地图
        local sorted_by_distance = {}
        for _, map_data in ipairs(otherworld_info) do
            local distance = manhattan_distance(center_x, center_y,
                                              map_data.position_x or 0, map_data.position_y or 0)
            table.insert(sorted_by_distance, {map = map_data, distance = distance})
        end
        
        table.sort(sorted_by_distance, function(a, b)
            return a.distance < b.distance
        end)

        -- _M.dbgp("請問23輕鬆的2の1")
        -- _M.printTable(sorted_by_distance)
        -- for j = 1, math.min(5, #sorted_by_distance) do
        --     _M.printTable(sorted_by_distance[j])
        --     -- _M.dbgp(string.format("[DEBUG] 排名 %d: %s (得分: %d)", j, valid_maps[j].map.name_cn_utf8 or "未知", valid_maps[j].score))
        -- end
        -- api_Sleep(5000)

        for _, item in ipairs(sorted_by_distance) do
            local map_data = item.map
            
            -- 检查地图是否可进入，如果不可进入则跳过
            -- if not map_data.isMapAccessible then
            --     goto continue
            -- end

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
                    goto continue
                end
            end

            -- 检查禁止进入的地图
            if #not_enter_map > 0 and
                _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
                goto continue
            end

            local score = calculate_score(map_data)
            if score >= 0 then
                table.insert(valid_maps, {
                    score = score, 
                    map = map_data,
                    distance = manhattan_distance(current_position.x, current_position.y,
                                                map_data.position_x or 0, map_data.position_y or 0)
                })
            end

            ::continue::
        end

        if #valid_maps > 0 then
            -- 按总分降序排序，距离作为次要排序条件
            table.sort(valid_maps, function(a, b)
                if a.score == b.score then
                    return a.distance < b.distance
                end
                return a.score > b.score
            end)
            return valid_maps[1].map
        end
    end

    -- 如果以上都没有找到合适的地图，寻找距离最近的可进入地图（不考虑模式匹配）
    local closest_accessible_map = nil
    local min_accessible_distance = math.huge
    
    for _, map_data in ipairs(otherworld_info) do
        -- 只考虑可进入的地图
        if not map_data.isCompleted then
            -- 检查错误地图
            local is_error = false
            if #error_other_map > 0 then
                for _, m in ipairs(error_other_map) do
                    if map_data.index_x == m.index_x and map_data.index_y == m.index_y then
                        is_error = true
                        break
                    end
                end
            end
            
            -- 检查禁止进入的地图
            local is_not_enter = false
            if #not_enter_map > 0 then
                is_not_enter = _M.table_contains(not_enter_map, map_data.name_cn_utf8)
            end
            
            -- 检查垃圾地图
            local is_trash = _M.table_contains(my_game_info.trash_map, map_data.name_utf8 or "")
            
            if not is_error and not is_not_enter and not is_trash then
                local distance = manhattan_distance(current_position.x, current_position.y,
                                                  map_data.position_x or 0, map_data.position_y or 0)
                if distance < min_accessible_distance then
                    min_accessible_distance = distance
                    closest_accessible_map = map_data
                end
            end
        end
    end

    -- 返回最近的可进入地图
    if closest_accessible_map then
        return closest_accessible_map
    end

    return nil
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
    local not_have_stackableCurrency = params.not_have_stackableCurrency or false
    local currency_point = params.currency_point or {}
    local enter_city = params.enter_city or false

    local PRIORITY_MAPS = {
        'MapBluff', -- 绝壁
        'MapBluff_NoBoss', 'MapSwampTower', -- 沉溺尖塔
        'MapSwampTower_NoBoss', 'MapLostTowers', -- 失落尖塔
        'MapLostTowers_NoBoss', 'MapAlpineRidge', 'MapAlpineRidge_NoBoss',
        'MapMesa', -- 平顶荒漠
        'MapMesa_NoBoss'
    }

    -- 计算两点之间的曼哈顿距离
    local function manhattan_distance(x1, y1, x2, y2)
        return math.abs(x1 - x2) + math.abs(y1 - y2)
    end

    current_position = _M.get_map2(params)
    _M.printTable(current_position)
    -- _M.dbgp("11111111111111111111111111111111111111")
    -- api_EndgameNodeMove(current_position.position_x, current_position.position_y)
    -- api_Sleep(2000)
    if not current_position then
        return _M.get_map_oringin(params)
    end

    -- 首先找到最近的优先地图位置作为中心点
    local center_x, center_y = current_position.position_x, current_position.position_y
    local min_distance = math.huge
    local found_priority_center = false

    -- 计算地图得分的内部函数
    local function calculate_score(map_data, required_modes)
        -- 基础条件检查（一票否决）
        if not map_data.name_utf8 then
            return -1
        end
        if _M.table_contains(my_game_info.trash_map, map_data.name_utf8) then
            return -1
        end

        -- 检查是否进入城寨
        if _M.table_contains(map_data.name_utf8, my_game_info.Citadel_map) then
            if enter_city then
                -- _M.dbgp("[DEBUG] 地图包含城寨模式")
                local map_level = _M.select_best_map_key({
                    inventory = bag_info,
                    key_level_threshold = key_level_threshold,
                    not_use_map = not_use_map,
                    priority_map = priority_map,
                    min_level = 15
                })
                -- _M.printTable(map_level)
                -- while true do
                --     api_Sleep(1000)
                -- end
                if not map_level then
                    return -1
                else
                    return 9999
                end
            end
            return -1
        end

        if _M.table_contains(map_data.mapPlayModes, "腐化聖域") then
            local map_level = _M.select_best_map_key({
                inventory = bag_info,
                key_level_threshold = key_level_threshold,
                not_use_map = not_use_map,
                priority_map = priority_map,
                color = 2,
                entry_length = 4
            })
            if not map_level then
                return -1
            else
                return 9999
            end
        end
        if _M.table_contains(map_data.mapPlayModes, game_str.Legendary_Map_MPMD) then
            if not sorted_map or not next(sorted_map) or not _M.table_contains(sorted_map, game_str.Legendary_Map_MPMD) then
                return -1
            end
            if _M.table_contains(map_data.name_cn_utf8, {game_str.MapUniqueParadise_TWCH, game_str.MapUniqueLake_TWCH, game_str.MapUniqueWildwood_TWCH, game_str.MapUniqueSelenite_TWCH, game_str.MapUniqueMegalith_TWCH}) then
                return 9999
            end
            return -1
        end
        if not_enter_map and
            _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
            return -1
        end

        if (not map_data.isMapAccessible) or map_data.isCompleted then
            return -1
        end

        -- -- 检查必须包含的模式（如果有）
        -- if required_modes then
        --     -- 单独处理"先行者高塔"的特殊判断
        --     if _M.table_contains(required_modes, "先行者高塔") then
        --         if not _M.table_contains(PRIORITY_MAPS, map_data.name_utf8) then
        --             return -1
        --         end
        --         -- 如果匹配则继续检查其他模式
        --         local new_required_modes = {}
        --         for _, mode in ipairs(required_modes) do
        --             if mode ~= "先行者高塔" then
        --                 table.insert(new_required_modes, mode)
        --             end
        --         end
        --         required_modes = new_required_modes
        --     end

        --     -- 检查剩余的模式（不包括"先行者高塔"）
        --     if #required_modes > 0 then
        --         local has_required = false
        --         for _, mode in ipairs(required_modes) do
        --             if _M.table_contains(map_data.mapPlayModes, mode) then
        --                 has_required = true
        --                 break
        --             end
        --         end
        --         if not has_required then
        --             return -1
        --         end
        --     end
        -- end

        -- 初始化评分项
        local score = 0
        local play_modes = map_data.mapPlayModes or {}

        -- 1. 计算sorted_map中的玩法模式匹配
        if #sorted_map > 0 and #play_modes > 0 then
            local matched_score = 0
            local matched_count = 0
            for i, mode in ipairs(sorted_map) do
                if _M.table_contains(play_modes, mode) then
                    -- 越靠前的模式权重越高（100 - 索引位置）
                    local mode_score = 100 - i
                    matched_score = matched_score + mode_score
                    matched_count = matched_count + 1
                end
            end

            -- 匹配数量加成（每个匹配模式额外加50分）
            local count_bonus = matched_count * 100
            score = score + matched_score + count_bonus
        end

        -- 2. 玩法模式总数（基础分）
        local mode_count_score = #play_modes * 100
        score = score + mode_count_score

        -- 3. 距离分数（距离越近分数越高）
        local distance = manhattan_distance(current_position.position_x, current_position.position_y, 
                                          map_data.index_x or 0, map_data.index_y or 0)
        local distance_score = math.max(0, 500 - distance * 10) -- 距离每增加1，分数减少10
        score = score + distance_score

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

    _M.dbgp("11111111111222222222")

    -- 分阶段查找最佳地图，按辐射距离排序
    local valid_maps = {}
    for i = 0, #effective_sorted_map do
        local required_modes = {}
        if i < #effective_sorted_map then
            for j = 1, i + 1 do
                table.insert(required_modes, effective_sorted_map[j])
            end
        end

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
                if #required_modes == 0 then
                    required_modes = nil
                end
            end
        end

        -- 按距离中心点的曼哈顿距离排序地图
        local sorted_by_distance = {}
        for _, map_data in ipairs(otherworld_info) do
            if not map_data.isMapAccessible or map_data.isCompleted then
                goto continue
            end
            local distance = manhattan_distance(center_x, center_y,
                                              map_data.position_x or 0, map_data.position_y or 0)
            table.insert(sorted_by_distance, {map = map_data, distance = distance})
            ::continue::
        end
        
        table.sort(sorted_by_distance, function(a, b)
            return a.distance < b.distance
        end)

        -- _M.dbgp("22222222222222222")
        -- -- _M.printTable(sorted_by_distance)
        -- for j = 1, math.min(5, #sorted_by_distance) do
        --     _M.printTable(sorted_by_distance[j])
        --     -- api_EndgameNodeMove(current_position.position_x, current_position.position_y)
        --     -- _M.dbgp(string.format("[DEBUG] 排名 %d: %s (得分: %d)", j, valid_maps[j].map.name_cn_utf8 or "未知", valid_maps[j].score))
        -- end
        
        -- api_Sleep(10000)

        -- 按距离顺序检查地图
        for _, item in ipairs(sorted_by_distance) do
            local map_data = item.map

            -- 检查错误地图
            if #error_other_map > 0 then
                local is_error = false
                for _, m in ipairs(error_other_map) do
                    if map_data.index_x == m.index_x and map_data.index_y == m.index_y then
                        is_error = true
                        break
                    end
                end
                if is_error then
                    goto continue
                end
            end

            -- 检查禁止进入的地图
            if #not_enter_map > 0 and
                _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
                goto continue
            end

            local score = calculate_score(map_data, #required_modes > 0 and
                                              required_modes or nil)
            if score >= 0 then
                table.insert(valid_maps, {
                    score = score, 
                    map = map_data,
                    distance = manhattan_distance(current_position.position_x, current_position.position_y,
                                                map_data.position_x or 0, map_data.position_y or 0)
                })
            end

            ::continue::
        end

        if #valid_maps > 0 then
            -- 先过滤出可进入的地图
            -- local accessible_maps = {}
            -- for _, map_info in ipairs(valid_maps) do
            --     if map_info.isMapAccessible then
            --         table.insert(accessible_maps, map_info)
            --     end
            -- end
            
            -- 如果有可进入的地图，则进行排序
            -- if #accessible_maps > 0 then
                -- 按总分降序排序，距离作为次要排序条件
            table.sort(valid_maps, function(a, b)
                return a.distance < b.distance
            end)
            
            -- 返回最佳地图
            return valid_maps[1].map
            -- else
            --     -- 没有可进入的地图，返回空
            --     return nil  -- 或者 return ""，根据你的需要
            -- end
        end
    end



    -- 如果没有找到符合条件的地图，尝试不要求任何特定模式
    if #valid_maps == 0 then
        -- 按距离中心点的曼哈顿距离排序地图
        local sorted_by_distance = {}
        for _, map_data in ipairs(otherworld_info) do
            local distance = manhattan_distance(center_x, center_y,
                                              map_data.position_x or 0, map_data.position_y or 0)
            table.insert(sorted_by_distance, {map = map_data, distance = distance})
        end
        
        table.sort(sorted_by_distance, function(a, b)
            return a.distance < b.distance
        end)

        for _, item in ipairs(sorted_by_distance) do
            local map_data = item.map
            
            -- 检查地图是否可进入，如果不可进入则跳过
            if not map_data.isMapAccessible then
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
                    goto continue
                end
            end

            -- 检查禁止进入的地图
            if #not_enter_map > 0 and
                _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
                goto continue
            end

            local score = calculate_score(map_data)
            if score >= 0 then
                table.insert(valid_maps, {
                    score = score, 
                    map = map_data,
                    distance = manhattan_distance(current_position.x, current_position.y,
                                                map_data.position_x or 0, map_data.position_y or 0)
                })
            end

            ::continue::
        end

        if #valid_maps > 0 then
            -- 按总分降序排序，距离作为次要排序条件
            table.sort(valid_maps, function(a, b)
                if a.score == b.score then
                    return a.distance < b.distance
                end
                return a.score > b.score
            end)
            return valid_maps[1].map
        end
    end

    -- 如果以上都没有找到合适的地图，寻找距离最近的可进入地图（不考虑模式匹配）
    local closest_accessible_map = nil
    local min_accessible_distance = math.huge
    
    for _, map_data in ipairs(otherworld_info) do
        -- 只考虑可进入的地图
        if map_data.isMapAccessible and not map_data.isCompleted then
            -- 检查错误地图
            local is_error = false
            if #error_other_map > 0 then
                for _, m in ipairs(error_other_map) do
                    if map_data.index_x == m.index_x and map_data.index_y == m.index_y then
                        is_error = true
                        break
                    end
                end
            end
            
            -- 检查禁止进入的地图
            local is_not_enter = false
            if #not_enter_map > 0 then
                is_not_enter = _M.table_contains(not_enter_map, map_data.name_cn_utf8)
            end
            
            -- 检查垃圾地图
            local is_trash = _M.table_contains(my_game_info.trash_map, map_data.name_utf8 or "")
            
            if not is_error and not is_not_enter and not is_trash then
                local distance = manhattan_distance(current_position.x, current_position.y,
                                                  map_data.position_x or 0, map_data.position_y or 0)
                if distance < min_accessible_distance then
                    min_accessible_distance = distance
                    closest_accessible_map = map_data
                end
            end
        end
    end

    -- 返回最近的可进入地图
    if closest_accessible_map then
        return closest_accessible_map
    end

    return nil
end

-- 选择异界地图
-- _M.get_map = function(params)
--     -- 解析参数表
--     local otherworld_info = params.otherworld_info or {}
--     local sorted_map = params.sorted_map or {}
--     local not_enter_map = params.not_enter_map or {}
--     local bag_info = params.bag_info or {}
--     local key_level_threshold = params.key_level_threshold
--     local not_use_map = params.not_use_map or {}
--     local priority_map = params.priority_map or {}
--     local entry_length = params.entry_length
--     local error_other_map = params.error_other_map or {}
--     local not_have_stackableCurrency = params.not_have_stackableCurrency or false
--     local current_position = params.current_position or {x = 0, y = 0}

--     local PRIORITY_MAPS = {
--         'MapBluff', -- 绝壁
--         'MapBluff_NoBoss', 'MapSwampTower', -- 沉溺尖塔
--         'MapSwampTower_NoBoss', 'MapLostTowers', -- 失落尖塔
--         'MapLostTowers_NoBoss', 'MapAlpineRidge', 'MapAlpineRidge_NoBoss',
--         'MapMesa', -- 平顶荒漠
--         'MapMesa_NoBoss'
--     }

--     -- 获取有效的sorted_map（过滤掉0值）
--     local effective_sorted_map = {}
--     if sorted_map then
--         for _, mode in ipairs(sorted_map) do
--             if mode ~= 0 then
--                 table.insert(effective_sorted_map, mode)
--             end
--         end
--     end

--     -- 第一步：找到最近的优先地图位置（不管能否进入）
--     local center_x, center_y = current_position.x, current_position.y
--     local nearest_priority_map = nil
--     local min_distance = math.huge

--     for _, map_data in ipairs(otherworld_info) do
--         -- 检查是否满足优先级条件
--         local has_priority = false
--         if #effective_sorted_map > 0 then
--             for _, mode in ipairs(effective_sorted_map) do
--                 if _M.table_contains(map_data.mapPlayModes or {}, mode) then
--                     has_priority = true
--                     break
--                 end
--             end
--         end

--         if has_priority then
--             local distance = math.sqrt((map_data.index_x - current_position.x)^2 + 
--                                       (map_data.index_y - current_position.y)^2)
--             if distance < min_distance then
--                 min_distance = distance
--                 center_x = map_data.index_x
--                 center_y = map_data.index_y
--                 nearest_priority_map = map_data
--             end
--         end
--     end

--     _M.dbgp(string.format("[DEBUG] 最近优先地图中心: (%d, %d)", center_x, center_y))
--     _M.printTable(nearest_priority_map)
--     if nearest_priority_map then
--         _M.dbgp(string.format("[DEBUG] 最近优先地图: %s", nearest_priority_map.name_cn_utf8 or "未知"))
--     end

--     -- 计算地图得分的内部函数（现在接收center_x和center_y作为参数）
--     local function calculate_score(map_data, required_modes, center_x, center_y)
--         -- 基础条件检查（一票否决）
--         if not map_data.name_utf8 then
--             return -1
--         end
--         if _M.table_contains(my_game_info.trash_map, map_data.name_utf8) then
--             return -1
--         end
--         if _M.table_contains(map_data.mapPlayModes, "腐化聖域") then
--             local map_level = _M.select_best_map_key({
--                 inventory = bag_info,
--                 key_level_threshold = key_level_threshold,
--                 not_use_map = not_use_map,
--                 priority_map = priority_map,
--                 color = 2,
--                 entry_length = 4
--             })
--             if not map_level or not_have_stackableCurrency then
--                 return -1
--             else
--                 return 9999
--             end
--         end
--         if _M.table_contains(map_data.mapPlayModes, game_str.Legendary_Map_MPMD) then
--             if _M.table_contains(map_data.name_cn_utf8, game_str.MapUniqueParadise_TWCH) then
--                 return 9999
--             end
--             return -1
--         end
--         if not_enter_map and _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
--             return -1
--         end
--         if not (map_data.isMapAccessible or true) or map_data.isCompleted then
--             return -1
--         end

--         -- 检查必须包含的模式（如果有）
--         if required_modes then
--             -- 单独处理"先行者高塔"的特殊判断
--             if _M.table_contains(required_modes, "先行者高塔") then
--                 if not _M.table_contains(PRIORITY_MAPS, map_data.name_utf8) then
--                     return -1
--                 end
--                 -- 如果匹配则继续检查其他模式
--                 local new_required_modes = {}
--                 for _, mode in ipairs(required_modes) do
--                     if mode ~= "先行者高塔" then
--                         table.insert(new_required_modes, mode)
--                     end
--                 end
--                 required_modes = new_required_modes
--             end

--             -- 检查剩余的模式（不包括"先行者高塔"）
--             if #required_modes > 0 then
--                 local has_required = false
--                 for _, mode in ipairs(required_modes) do
--                     if _M.table_contains(map_data.mapPlayModes, mode) then
--                         has_required = true
--                         break
--                     end
--                 end
--                 if not has_required then
--                     return -1
--                 end
--             end
--         end

--         -- 初始化评分项
--         local score = 0
--         local play_modes = map_data.mapPlayModes or {}

--         -- 1. 计算sorted_map中的玩法模式匹配
--         if #sorted_map > 0 and #play_modes > 0 then
--             local matched_score = 0
--             local matched_count = 0
--             for i, mode in ipairs(sorted_map) do
--                 if _M.table_contains(play_modes, mode) then
--                     local mode_score = 100 - i
--                     matched_score = matched_score + mode_score
--                     matched_count = matched_count + 1
--                 end
--             end

--             local count_bonus = matched_count * 100
--             score = score + matched_score + count_bonus
--         end

--         -- 2. 玩法模式总数（基础分）
--         local mode_count_score = #play_modes * 100
--         score = score + mode_count_score

--         -- 3. 距离得分（距离中心越近得分越高）
--         if map_data.index_x and map_data.index_y and center_x and center_y then
--             local distance_to_center = math.sqrt((map_data.index_x - center_x)^2 + (map_data.index_y - center_y)^2)
--             local distance_score = math.max(0, 500 - distance_to_center * 10)  -- 最大500分，每单位距离减10分
--             score = score + distance_score
--         end

--         return score
--     end

--     -- 第二步：以中心位置为基准，辐射寻找可进入的地图
--     local valid_maps = {}

--     -- 按距离排序所有地图
--     local sorted_by_distance = {}
--     for _, map_data in ipairs(otherworld_info) do
--         if map_data.index_x and map_data.index_y then
--             local distance = math.sqrt((map_data.index_x - center_x)^2 + 
--                                       (map_data.index_y - center_y)^2)
--             table.insert(sorted_by_distance, {
--                 map = map_data,
--                 distance = distance
--             })
--         end
--     end

--     table.sort(sorted_by_distance, function(a, b)
--         return a.distance < b.distance
--     end)

--     -- 分阶段查找最佳地图（按距离从近到远）
--     for i = 0, #effective_sorted_map do
--         local required_modes = {}
--         if i < #effective_sorted_map then
--             for j = 1, i + 1 do
--                 table.insert(required_modes, effective_sorted_map[j])
--             end
--         end

--         -- 调整"先行者高塔"的特殊处理
--         if #required_modes > 0 and _M.table_contains(required_modes, "先行者高塔") then
--             if required_modes[#required_modes] ~= "先行者高塔" then
--                 local new_required_modes = {}
--                 for _, mode in ipairs(required_modes) do
--                     if mode ~= "先行者高塔" then
--                         table.insert(new_required_modes, mode)
--                     end
--                 end
--                 required_modes = new_required_modes
--                 if #required_modes == 0 then
--                     required_modes = nil
--                 end
--             end
--         end

--         -- 在当前距离范围内查找
--         for _, item in ipairs(sorted_by_distance) do
--             local map_data = item.map
            
--             -- 检查错误地图
--             if #error_other_map > 0 then
--                 local is_error = false
--                 for _, m in ipairs(error_other_map) do
--                     if map_data.index_x == m.index_x and map_data.index_y == m.index_y then
--                         is_error = true
--                         break
--                     end
--                 end
--                 if is_error then
--                     goto continue
--                 end
--             end

--             -- 检查禁止进入的地图
--             if #not_enter_map > 0 and _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
--                 goto continue
--             end

--             local score = calculate_score(map_data, #required_modes > 0 and required_modes or nil, center_x, center_y)
--             if score >= 0 then
--                 table.insert(valid_maps, {
--                     score = score,
--                     map = map_data,
--                     distance = item.distance
--                 })
--             end

--             ::continue::
--         end

--         if #valid_maps > 0 then
--             _M.dbgp(string.format("[DEBUG] 阶段 %d 找到 %d 个有效地图", i + 1, #valid_maps))
--             -- 按总分降序排序，距离作为次要排序条件
--             table.sort(valid_maps, function(a, b)
--                 if a.score ~= b.score then
--                     return a.score > b.score
--                 else
--                     return a.distance < b.distance
--                 end
--             end)

--             return valid_maps[1].map
--         end
--     end

--     -- 如果没有找到符合条件的地图，尝试不要求任何特定模式
--     if #valid_maps == 0 then
--         for _, item in ipairs(sorted_by_distance) do
--             local map_data = item.map
            
--             if not map_data.isMapAccessible then
--                 goto continue
--             end

--             -- 检查错误地图
--             if #error_other_map > 0 then
--                 local is_error = false
--                 for _, m in ipairs(error_other_map) do
--                     if map_data.index_x == m.index_x and map_data.index_y == m.index_y then
--                         is_error = true
--                         break
--                     end
--                 end
--                 if is_error then
--                     goto continue
--                 end
--             end

--             -- 检查禁止进入的地图
--             if #not_enter_map > 0 and _M.table_contains(not_enter_map, map_data.name_cn_utf8) then
--                 goto continue
--             end

--             local score = calculate_score(map_data, nil, center_x, center_y)
--             if score >= 0 then
--                 table.insert(valid_maps, {
--                     score = score,
--                     map = map_data,
--                     distance = item.distance
--                 })
--             end

--             ::continue::
--         end

--         if #valid_maps > 0 then
--             -- 按总分降序排序，距离作为次要排序条件
--             table.sort(valid_maps, function(a, b)
--                 if a.score ~= b.score then
--                     return a.score > b.score
--                 else
--                     return a.distance < b.distance
--                 end
--             end)

--             return valid_maps[1].map
--         end
--     end

--     _M.dbgp("[DEBUG] 最终未找到合适地图，返回nil")
--     return nil
-- end

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
            local center = _M.get_center_position(
                {actor.start_x, actor.start_y},
                {actor.end_x, actor.end_y}
            )

            -- 点击类型分派
            if click_type == 1 then
                _M.right_click(center[1], center[2])
            elseif click_type == 3 then
                _M.ctrl_right_click(center[1], center[2])
            else
                _M.ctrl_left_click(center[1], center[2])
            end

            return true
        end
        ::continue::
    end

    _M.dbgp(("未找到目标物品: %s"):format(target_name))
    return false
end

-- UTF-8安全清理函数（最终版）
_M.clean_utf8 = function(s)
    if not s or s == "" then
        return ""
    end

    local result = {}
    local i = 1
    local len = #s
    
    while i <= len do
        local byte = string.byte(s, i)
        
        -- ASCII字符（0-127）
        if byte < 128 then
            if not string.match(string.char(byte), "[%s　]") then
                table.insert(result, string.char(byte))
            end
            i = i + 1
        -- UTF-8多字节字符
        else
            local char
            if byte >= 0xC0 and byte < 0xE0 then  -- 2字节字符
                char = string.sub(s, i, i+1)
                i = i + 2
            elseif byte >= 0xE0 and byte < 0xF0 then  -- 3字节字符（包括中文）
                char = string.sub(s, i, i+2)
                i = i + 3
            elseif byte >= 0xF0 then  -- 4字节字符
                char = string.sub(s, i, i+3)
                i = i + 4
            else  -- 非法UTF-8起始字节
                i = i + 1  -- 跳过无效字节
                goto continue
            end
            
            -- 验证字符有效性
            if utf8.len(char) == 1 then
                table.insert(result, char)
            end
        end
        ::continue::
    end
    
    return table.concat(result)
end

-- UTF-8安全文本提取（最终版）
_M.extract_utf8_text = function(s)
    if not s or s == "" then
        return ""
    end
    
    local result = {}
    local i = 1
    while i <= #s do
        local c = string.sub(s, i, i)
        
        -- 处理通配符 {数字}
        if c == "{" then
            local j = i
            while j <= #s and string.sub(s, j, j) ~= "}" do
                j = j + 1
            end
            if j <= #s then
                i = j + 1  -- 跳过整个{}块
            else
                i = i + 1
            end
        -- 过滤特殊符号但保护多字节字符
        elseif c:match("[+%-%%#%$%^%*%(%)]") and #c == 1 then
            i = i + 1
        else
            -- 安全获取完整UTF-8字符
            local char = utf8.char(utf8.codepoint(s, i))
            table.insert(result, char)
            i = i + #char  -- 正确跳过多字节字符
        end
    end
    
    return table.concat(result)
end

_M.analyze_map_modifiers = function(modifier_list, item)
    -- 词缀名称到游戏参数的映射
    local modifier_mapping = {
        ["怪物群大小"] = "monsterPackSize",
        ["稀有怪物"] = "rareMonster", 
        ["物品稀有度"] = "itemRarity",
        ["地图掉落机率"] = "mapDropChance"
    }
    
    -- 获取当前地图的词缀数值
    local function get_current_map_stats(item_obj)
        return {
            monsterPackSize = item_obj.monsterPackSize and item_obj.monsterPackSize() or 0,
            rareMonster = item_obj.rareMonster and item_obj.rareMonster() or 0,
            itemRarity = item_obj.itemRarity and item_obj.itemRarity() or 0,
            mapDropChance = item_obj.mapDropChance and item_obj.mapDropChance() or 0
        }
    end
    
    -- 词缀选择算法
    local function select_map_modifiers(parsed_mods, item_obj)
        local selected = {}
        local current_map_stats = get_current_map_stats(item_obj)
        
        if #parsed_mods == 0 then
            return selected
        end
        
        -- 第一个词缀：强满足
        local first_mod = parsed_mods[1]
        local first_key = modifier_mapping[first_mod.name_utf8]
        
        if not first_key then
            print("未知的词缀名称: " .. first_mod.name_utf8)
            return selected
        end
        
        local current_value = current_map_stats[first_key] or 0
        local target_value = first_mod.value_list[1] or 0
        local first_satisfied = (current_value >= target_value)
        
        table.insert(selected, {
            name = first_mod.name_utf8,
            game_key = first_key,
            value = current_value,
            target = target_value,
            satisfied = first_satisfied,
            priority = 1
        })
        
        -- 如果第一个满足，在剩余词缀中按顺序寻找最高满足项
        if first_satisfied and #parsed_mods > 1 then
            for i = 2, #parsed_mods do
                local mod = parsed_mods[i]
                local key = modifier_mapping[mod.name_utf8]
                
                if key then
                    local current_val = current_map_stats[key] or 0
                    local target_val = mod.value_list[1] or 0
                    
                    if current_val >= target_val then
                        table.insert(selected, {
                            name = mod.name_utf8,
                            game_key = key,
                            value = current_val,
                            target = target_val,
                            satisfied = true,
                            priority = i
                        })
                        break -- 只选择第一个满足的
                    end
                else
                    print("未知的词缀名称: " .. mod.name_utf8)
                end
            end
        end
        
        return selected
    end
    
    -- 执行整个流程（直接使用已解析的modifier_list）
    local selected_modifiers = select_map_modifiers(modifier_list, item)
    
    return {
        selected_modifiers = selected_modifiers,
        all_current_stats = get_current_map_stats(item)
    }
end

-- 选择最优地图钥匙
_M.select_best_map_key = function(params)
    -- 解析参数表
    local inventory = params.inventory
    local click = params.click or 0
    local key_level_threshold = params.key_level_threshold
    local type_map = params.type or 0
    local index = params.index or 0
    local score = params.score or 0
    local no_categorize_suffixes = params.no_categorize_suffixes or 0
    local min_level = params.min_level
    local not_use_map = params.not_use_map or {}
    local trashest = params.trashest or false
    local page_type = params.page_type
    local entry_length = params.entry_length or 0
    local START_X = params.START_X or 0
    local START_Y = params.START_Y or 0
    local color = params.color or 0
    local vall = params.vall or false
    local instill = params.instill or false
    local trash_map = params.trash_map or false

    -- 新增：优先打词缀配置
    local priority_map = params.priority_map or {}
    local priority_enabled = params.priority_enabled or false

    if not inventory or #inventory == 0 then
        _M.dbgp("背包为空")
        return nil
    end

    -- UTF-8优化的词缀分类
    local function categorize_suffixes_utf8(suffixes)
        local categories = {
            ['譫妄'] = {},
            ['其他'] = {},
            ['不打'] = {},
            ['无效'] = {},
            ['优先'] = {}  -- 新增：优先词缀分类
        }

        if not suffixes or #suffixes == 0 then
            categories['无效'][1] = '空词条列表'
            return categories
        end

        -- UTF-8安全的排除列表处理
        local processed_not_use_map = {}
        for _, excl in ipairs(not_use_map or {}) do
            if excl then
                local processed = string.gsub(excl, "<rgb%(255,0,0%)>", "")
                processed = _M.clean_utf8(processed)
                processed = _M.extract_utf8_text(processed)
                processed = string.gsub(processed, "[%d%%%s]", "")
                table.insert(processed_not_use_map, processed)
            end
        end

        -- UTF-8安全的优先词缀处理
        local processed_priority_map = {}
        if priority_enabled and priority_map then
            for _, priority in ipairs(priority_map) do
                if priority then
                    local processed = string.gsub(priority, "<rgb%(255,0,0%)>", "")
                    processed = _M.clean_utf8(processed)
                    processed = _M.extract_utf8_text(processed)
                    processed = string.gsub(processed, "[%d%%%s]", "")
                    table.insert(processed_priority_map, processed)
                end
            end
        end

        for i, suffix in ipairs(suffixes) do
            local suffix_name = suffix.name_utf8 or ""

            -- 1. 移除RGB标签
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>", "")
            
            -- 2. UTF-8安全清理
            cleaned_suffix = _M.clean_utf8(cleaned_suffix)
            
            -- 3. UTF-8文本提取
            cleaned_suffix = _M.extract_utf8_text(cleaned_suffix)

            if cleaned_suffix == "" then
                table.insert(categories['无效'], suffix_name)
                goto continue
            end

            -- UTF-8安全的词条处理
            local processed_suffix = string.gsub(cleaned_suffix, "[%d%%%s]", "")

            -- 优先检查优先词缀（如果启用）
            if priority_enabled then
                for _, processed_priority in ipairs(processed_priority_map) do
                    if string.find(processed_suffix, processed_priority, 1, true) then
                        table.insert(categories['优先'], cleaned_suffix)
                        goto continue
                    end
                end
            end

            -- UTF-8安全的排除检查
            for _, processed_excl in ipairs(processed_not_use_map) do
                if string.find(processed_suffix, processed_excl, 1, true) then
                    table.insert(categories['不打'], cleaned_suffix)
                    goto continue
                end
            end

            -- UTF-8安全的疯癫词条检查
            if string.find(processed_suffix, "譫妄", 1, true) then
                table.insert(categories['譫妄'], cleaned_suffix)
                goto continue
            end

            -- 其他UTF-8词条
            table.insert(categories['其他'], cleaned_suffix)

            ::continue::
        end

        return categories
    end

    -- 优先词缀匹配检查函数
    local function has_priority_suffixes(suffixes)
        if not priority_enabled or not priority_map or #priority_map == 0 then
            return false
        end

        if not suffixes or #suffixes == 0 then
            return false
        end

        -- 处理优先词缀列表
        local processed_priority_map = {}
        for _, priority in ipairs(priority_map) do
            if priority then
                local processed = string.gsub(priority, "<rgb%(255,0,0%)>", "")
                processed = _M.clean_utf8(processed)
                processed = _M.extract_utf8_text(processed)
                processed = string.gsub(processed, "[%d%%%s]", "")
                table.insert(processed_priority_map, processed)
            end
        end

        -- 检查是否有匹配的优先词缀
        for _, suffix in ipairs(suffixes) do
            local suffix_name = suffix.name_utf8 or ""
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>", "")
            cleaned_suffix = _M.clean_utf8(cleaned_suffix)
            cleaned_suffix = _M.extract_utf8_text(cleaned_suffix)
            local processed_suffix = string.gsub(cleaned_suffix, "[%d%%%s]", "")

            for _, processed_priority in ipairs(processed_priority_map) do
                if string.find(processed_suffix, processed_priority, 1, true) then
                    return true
                end
            end
        end

        return false
    end

    local best_key = nil
    local max_score = -math.huge
    local min_score = math.huge
    local processed_keys = 0

    -- 预处理key_level_threshold，同时解析优先词缀配置
    local white, blue, gold, valls, level = {}, {}, {}, {}, {}
    local priority_config_by_level = {}  -- 新增：按等级存储优先词缀配置

    if key_level_threshold then
        for _, user_map in ipairs(key_level_threshold) do
            local tier_value = user_map['階級']
            local level_list = {}
            
            if type(tier_value) == "string" and string.find(tier_value, "-") then
                local min_tier, max_tier = tier_value:match("(%d+)-(%d+)")
                min_tier = tonumber(min_tier)
                max_tier = tonumber(max_tier)
                
                if min_tier and max_tier then
                    for t = min_tier, max_tier do
                        table.insert(level_list, t)
                    end
                end
            else
                local tier_num = tonumber(tier_value)
                if tier_num then
                    table.insert(level_list, tier_num)
                end
            end
            
            for _, lvl in ipairs(level_list) do
                table.insert(level, lvl)
                
                -- 存储该等级的优先词缀配置
                priority_config_by_level[lvl] = {
                    priority_map = user_map['优先打词缀'] and user_map['优先打词缀']['詞綴'] or {},
                    priority_enabled = user_map['优先打词缀'] and user_map['优先打词缀']['是否開啟'] or false
                }
                
                if user_map['白'] then
                    if not _M.table_contains(white, lvl) then
                        table.insert(white, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
                
                if user_map['藍'] then
                    if not _M.table_contains(blue, lvl) then
                        table.insert(blue, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
                
                if user_map['黃'] then
                    if not _M.table_contains(gold, lvl) then
                        table.insert(gold, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
            end
        end
    end

    -- 处理物品 - 第一阶段：过滤
    local valid_items = {}  -- 存储所有有效的物品

    for i, item in ipairs(inventory) do
        -- 检查是否为地图钥匙
        if not string.find(item.baseType_utf8 or "", "地圖鑰匙") then
            goto continue
        end

        -- 颜色过滤
        if color > 0 then
            if (item.color or 0) < color then
                goto continue
            end
        end

        local key_level = item.mapLevel

        -- 污染过滤
        if vall then
            if item.contaminated then
                goto continue
            end
        end

        -- 等级过滤
        if min_level and key_level < min_level then
            goto continue
        end

        -- 钥匙等级阈值检查
        if key_level_threshold then
            local valid = false
            if item.color == 0 and #white > 0 and _M.table_contains(white, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end
            if item.color == 1 and #blue > 0 and _M.table_contains(blue, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end
            if item.color == 2 and #gold > 0 and _M.table_contains(gold, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end

            if not valid then
                goto continue
            end
        end

        -- 词缀长度检查
        if entry_length > 0 then
            if (item.fixedSuffixCount or 0) < entry_length and item.contaminated then
                goto continue
            end
        end

        local suffixes = nil
        if (item.color or 0) > 0 then
            suffixes = api_GetObjectSuffix(item.mods_obj)
            if suffixes and #suffixes > 0 then
                -- 排除词缀检查
                -- _M.dbgp("检查排除词缀1")
                if #not_use_map > 0 then
                    -- _M.dbgp("检查排除词缀2")
                    if _M.match_item_suffixes(suffixes, not_use_map, true) then
                        -- _M.dbgp("检查排除词缀3")
                        -- _M.printTable(suffixes)
                        if trashest or trash_map then
                            best_key = item
                            break
                        end
                        goto continue
                    end
                end
            end
        end

        -- 通过所有过滤条件，添加到有效物品列表
        table.insert(valid_items, item)
        
        ::continue::
    end

    -- 如果是trashest模式，直接返回第一个匹配的垃圾物品
    if (trashest or trash_map) and best_key then
        _M.dbgp("trashest模式：选择第一个匹配的垃圾物品")
        if click == 1 then
            if page_type == 7 then
                local pos =  _M.get_center_position_store_max(
                    {best_key.start_x or 0, best_key.start_y or 0},
                    {best_key.end_x or 0, best_key.end_y or 0},
                    15, 100, 22, 22)
                _M.ctrl_left_click(pos[1], pos[2])
                return best_key.mapLevel
            end
            if type_map == 1 then
                _M.ctrl_left_click_store_items(best_key.obj or nil, inventory)
                return best_key.mapLevel
            end
            if type_map == 3 then
                _M.return_more_map(best_key.obj or nil, inventory, START_X, START_Y)
                return best_key.mapLevel
            end
            _M.ctrl_left_click_bag_items(best_key.obj or nil, inventory)
            return best_key.mapLevel
        end
        return best_key
    end

    -- 强满足版本：每个阶级单独处理
    local best_priority_key = nil
    local best_priority_score = -math.huge
    local best_priority_reason = ""
    local found_items = {}  -- 存储找到的物品

    -- 辅助函数：根据词条名称获取物品属性值
    local function get_item_priority_value(item, priority_name)
        if priority_name == "怪物群大小" then
            return item.monsterPackSize
        elseif priority_name == "稀有怪物" then
            return item.rareMonster
        elseif priority_name == "物品稀有度" then
            return item.itemRarity
        elseif priority_name == "地图掉落机率" then
            return item.mapDropChance
        elseif priority_name == "换届石掉落几率" then
            return item.mapDropChance  -- 假设换届石掉落几率使用mapDropChance属性
        else
            _M.dbgp("未知优先词条: " .. tostring(priority_name))
            return nil
        end
    end

    local items_by_tier = {}
    if #valid_items > 0 then
        -- 按阶级分组物品
        for i, item in ipairs(valid_items) do
            local tier = item.mapLevel
            if not items_by_tier[tier] then
                items_by_tier[tier] = {}
            end
            table.insert(items_by_tier[tier], item)
        end
        -- _M.printTable(items_by_tier)
        -- 对每个阶级单独处理
        for tier, tier_items in pairs(items_by_tier) do
            local level_config = priority_config_by_level[tier] or {}
            local level_priority_enabled = level_config.priority_enabled or false
            local level_priority_map = level_config.priority_map or {}

            -- 如果该阶级没有开启优先词缀配置，跳过
            if not level_priority_enabled or #level_priority_map == 0 then
                goto continue_tier
            end
            
            -- 第一轮：处理第一个优先词条
            local first_priority_items = {}
            for i, item in ipairs(tier_items) do
                local first_priority_name = level_priority_map[1]  -- 第一个词条
                if first_priority_name then
                    local item_value = get_item_priority_value(item, first_priority_name)
                    _M.dbgp(string.format("检查阶级%d物品的第1词条(%s)", tier, first_priority_name))
                    
                    -- 检查第一个优先词条
                    if item_value and item_value > 0 then
                        local score = item_value
                        local reason = string.format("阶级%d-第1词条-%s:%d", tier, first_priority_name, score)
                        
                        table.insert(first_priority_items, {
                            item = item,
                            score = score,
                            reason = reason,
                            priority_index = 1,
                            tier = tier
                        })
                    end
                end
            end
            
            if #first_priority_items == 0 then
                best_priority_key = nil
                best_priority_score = -math.huge
                -- _M.dbgp("阶级没有满足第1词条条件的物品", tier)
                -- api_Sleep(5000)
                break  -- 该阶级没有满足条件的物品，整个函数返回nil
            end
            
            -- 第二轮：在满足第一个词条的物品中检查第二个词条
            local second_priority_items = {}
            for i, data in ipairs(first_priority_items) do
                local item = data.item
                
                if #level_priority_map >= 2 then
                    local second_priority_name = level_priority_map[2]  -- 第二个词条
                    if second_priority_name then
                        local item_value = get_item_priority_value(item, second_priority_name)
                        
                        -- 检查第二个优先词条
                        if item_value and item_value > 0 then
                            local total_score = data.score + item_value * 0.8  -- 第二个词条权重降低
                            local reason = data.reason .. string.format("+第2词条-%s:%d", second_priority_name, item_value)
                            
                            table.insert(second_priority_items, {
                                item = item,
                                score = total_score,
                                reason = reason,
                                priority_index = 2,
                                tier = tier
                            })
                        end
                    end
                end
                
                -- 如果没有第二个词条，保留第一个词条的数据
                if #level_priority_map < 2 then
                    table.insert(second_priority_items, data)
                end
            end
            
            if #second_priority_items > 0 then
                -- 第三轮：在满足前两个词条的物品中检查第三个词条
                local third_priority_items = {}
                for i, data in ipairs(second_priority_items) do
                    local item = data.item
                    
                    if #level_priority_map >= 3 then
                        local third_priority_name = level_priority_map[3]  -- 第三个词条
                        if third_priority_name then
                            local item_value = get_item_priority_value(item, third_priority_name)
                            
                            -- 检查第三个优先词条
                            if item_value and item_value > 0 then
                                local total_score = data.score + item_value * 0.6  -- 第三个词条权重进一步降低
                                local reason = data.reason .. string.format("+第3词条-%s:%d", third_priority_name, item_value)
                                
                                table.insert(third_priority_items, {
                                    item = item,
                                    score = total_score,
                                    reason = reason,
                                    priority_index = 3,
                                    tier = tier
                                })
                            end
                        end
                    end
                    
                    -- 如果没有第三个词条，保留之前的数据
                    if #level_priority_map < 3 then
                        table.insert(third_priority_items, data)
                    end
                end
                
                if #third_priority_items > 0 then
                    -- 第四轮：在满足前三个词条的物品中检查第四个词条
                    local fourth_priority_items = {}
                    for i, data in ipairs(third_priority_items) do
                        local item = data.item
                        
                        if #level_priority_map >= 4 then
                            local fourth_priority_name = level_priority_map[4]  -- 第四个词条
                            if fourth_priority_name then
                                local item_value = get_item_priority_value(item, fourth_priority_name)
                                
                                -- 检查第四个优先词条
                                if item_value and item_value > 0 then
                                    local total_score = data.score + item_value * 0.4  -- 第四个词条权重最低
                                    local reason = data.reason .. string.format("+第4词条-%s:%d", fourth_priority_name, item_value)

                                    table.insert(fourth_priority_items, {
                                        item = item,
                                        score = total_score,
                                        reason = reason,
                                        priority_index = 4,
                                        tier = tier
                                    })
                                end
                            end
                        end
                        
                        -- 如果没有第四个词条，保留之前的数据
                        if #level_priority_map < 4 then
                            table.insert(fourth_priority_items, data)
                        end
                    end
                    
                    found_items = fourth_priority_items
                else
                    found_items = second_priority_items
                end
            else
                found_items = first_priority_items
            end
            
            -- 从该阶级最终筛选出的物品中选择分数最高的
            local tier_best_score = -math.huge
            local tier_best_item = nil
            local tier_best_reason = ""
            
            for i, data in ipairs(found_items) do
                if data.score > tier_best_score then
                    tier_best_score = data.score
                    tier_best_item = data.item
                    tier_best_reason = data.reason
                end
            end
            
            -- 更新全局最优
            if tier_best_score > best_priority_score then
                best_priority_score = tier_best_score
                best_priority_key = tier_best_item
                best_priority_reason = tier_best_reason
            end
            
            ::continue_tier::
        end
    end

    -- 第三阶段：确定最终选择
    if not trashest then
        if best_priority_key then
            -- 优先选择有优先词缀的物品
            _M.dbgp("选择优先词缀数值最高的物品: " .. best_priority_reason .. "总分数: " .. tostring(best_priority_score))
            best_key = best_priority_key
            max_score = best_priority_score
        else
            -- 如果有任何阶级开启了优先配置但没有找到匹配物品，返回nil
            local any_priority_enabled = false
            for tier, items in pairs(items_by_tier or {}) do
                local level_config = priority_config_by_level[tier] or {}
                if level_config.priority_enabled and #(level_config.priority_map or {}) > 0 then
                    any_priority_enabled = true
                    break
                end
            end
            
            if any_priority_enabled then
                -- _M.dbgp("有阶级开启了优先词缀配置但未找到匹配物品，返回nil")
                local map111 = _M.select_best_map_key_orange(params)
                if map111 then
                    return map111
                end
                return nil
            elseif #valid_items > 0 then
                -- 如果没有阶级开启优先配置，使用原来的评分逻辑
                _M.dbgp("没有阶级开启优先词缀配置，使用普通评分逻辑")
                
                for i, item in ipairs(valid_items) do
                    local suffixes = nil
                    if (item.color or 0) > 0 then
                        suffixes = api_GetObjectSuffix(item.mods_obj)
                    end
        
                    -- 词缀分类和评分
                    local categories = categorize_suffixes_utf8(suffixes or {})
        
                    local key_level = item.mapLevel
                    -- 计算评分
                    local level_weight = key_level * 5
                    local suffix_score = 0
                    local color_score = 25 * (item.color or 0)
                    if item.contaminated then
                        color_score = color_score + 100
                    end
        
                    local additional_score = 0
                    -- 基于优先级逆序的四个参数加分 (item.itemRarity最重要)
                    if item.itemRarity then
                        local rarity_score = item.itemRarity * 4.0
                        if item.itemRarity >= 90 then
                            rarity_score = rarity_score + 100
                        elseif item.itemRarity >= 70 then
                            rarity_score = rarity_score + 50
                        elseif item.itemRarity >= 50 then
                            rarity_score = rarity_score + 25
                        end
                        additional_score = additional_score + math.min(rarity_score, 300)
                    end

                    if item.rareMonster then
                        local rare_score = item.rareMonster * 3.0
                        if item.rareMonster >= 25 then
                            rare_score = rare_score + 75
                        elseif item.rareMonster >= 15 then
                            rare_score = rare_score + 40
                        elseif item.rareMonster >= 8 then
                            rare_score = rare_score + 20
                        end
                        additional_score = additional_score + math.min(rare_score, 250)
                    end

                    if item.monsterPackSize then
                        local pack_score = item.monsterPackSize * 2.0
                        if item.monsterPackSize >= 35 then
                            pack_score = pack_score + 50
                        elseif item.monsterPackSize >= 25 then
                            pack_score = pack_score + 25
                        elseif item.monsterPackSize >= 15 then
                            pack_score = pack_score + 10
                        end
                        additional_score = additional_score + math.min(pack_score, 180)
                    end

                    if item.mapDropChance then
                        local map_score = item.mapDropChance * 1.5
                        if item.mapDropChance >= 85 then
                            map_score = map_score + 30
                        elseif item.mapDropChance >= 65 then
                            map_score = map_score + 15
                        elseif item.mapDropChance >= 45 then
                            map_score = map_score + 8
                        end
                        additional_score = additional_score + math.min(map_score, 150)
                    end
        
                    local total_score
                    if no_categorize_suffixes == 0 then
                        total_score = level_weight + suffix_score + color_score + additional_score
                    else
                        total_score = level_weight + color_score + additional_score
                    end
        
                    -- 记录最优
                    if index == 0 then
                        if total_score > max_score and total_score > 0 then
                            max_score = total_score
                            best_key = item
                        end
                    else
                        if total_score < min_score then
                            min_score = total_score
                            best_key = item
                        end
                    end
                end
            else
                _M.dbgp("没有找到任何有效的物品")
                best_key = nil
            end
        end
    else
        -- trashest模式：选择最垃圾的物品（评分最低的）
        _M.dbgp("trashest模式：选择评分最低的物品")
        local worst_score = math.huge
        local worst_key = nil
        
        for i, item in ipairs(valid_items) do
            local suffixes = nil
            if (item.color or 0) > 0 then
                suffixes = api_GetObjectSuffix(item.mods_obj)
            end

            -- 词缀分类和评分
            local categories = categorize_suffixes_utf8(suffixes or {})

            local key_level = item.mapLevel
            -- 计算评分（与正常模式相同）
            local level_weight = key_level * 5
            local suffix_score = 0
            local color_score = 25 * (item.color or 0)
            if item.contaminated then
                color_score = color_score + 100
            end

            local additional_score = 0
            if item.itemRarity then
                local rarity_score = item.itemRarity * 4.0
                additional_score = additional_score + math.min(rarity_score, 300)
            end
            if item.rareMonster then
                local rare_score = item.rareMonster * 3.0
                additional_score = additional_score + math.min(rare_score, 250)
            end
            if item.monsterPackSize then
                local pack_score = item.monsterPackSize * 2.0
                additional_score = additional_score + math.min(pack_score, 180)
            end
            if item.mapDropChance then
                local map_score = item.mapDropChance * 1.5
                additional_score = additional_score + math.min(map_score, 150)
            end

            local total_score
            if no_categorize_suffixes == 0 then
                total_score = level_weight + suffix_score + color_score + additional_score
            else
                total_score = level_weight + color_score + additional_score
            end

            -- 选择评分最低的物品
            if total_score < worst_score then
                worst_score = total_score
                worst_key = item
            end
        end
        
        best_key = worst_key
        max_score = worst_score
    end

    -- 后续处理逻辑
    if best_key then
        if score ~= 0 then
            local final_score = 0
            if index == 0 then
                final_score = max_score or 0
            else
                final_score = min_score or 0
            end
            return best_key, final_score
        end
    else
        _M.dbgp("警告: best_key 为 nil")
    end

    -- 执行选择
    if best_key then
        if score == 1 then
            return best_key, best_key.mapLevel
        end
        if click == 1 then
            if page_type == 7 then
                local pos =  _M.get_center_position_store_max(
                    {best_key.start_x or 0, best_key.start_y or 0},
                    {best_key.end_x or 0, best_key.end_y or 0},
                    15, 100, 22, 22)
                _M.ctrl_left_click(pos[1], pos[2])
                return best_key.mapLevel
            end
            if type_map == 1 then
                _M.ctrl_left_click_store_items(best_key.obj or nil, inventory)
                return best_key.mapLevel
            end
            if type_map == 3 then
                _M.return_more_map(best_key.obj or nil, inventory, START_X, START_Y)
                return best_key.mapLevel
            end

            _M.ctrl_left_click_bag_items(best_key.obj or nil, inventory)
            return best_key.mapLevel
        end
        return best_key
    else
        return nil
    end

    return best_key
end

-- 选择最优地图钥匙
_M.select_best_map_key2 = function(params)
    -- 解析参数表
    local inventory = params.inventory
    local click = params.click or 0
    local key_level_threshold = params.key_level_threshold
    local type_map = params.type or 0
    local index = params.index or 0
    local score = params.score or 0
    local no_categorize_suffixes = params.no_categorize_suffixes or 0
    local min_level = params.min_level
    local not_use_map = params.not_use_map or {}
    local trashest = params.trashest or false
    local page_type = params.page_type
    local entry_length = params.entry_length or 0
    local START_X = params.START_X or 0
    local START_Y = params.START_Y or 0
    local color = params.color or 0
    local vall = params.vall or false
    local instill = params.instill or false

    -- 新增：优先打词缀配置
    local priority_map = params.priority_map or {}
    local priority_enabled = params.priority_enabled or false

    if not inventory or #inventory == 0 then
        _M.dbgp("背包为空")
        return nil
    end

    -- UTF-8优化的词缀分类
    local function categorize_suffixes_utf8(suffixes)
        local categories = {
            ['譫妄'] = {},
            ['其他'] = {},
            ['不打'] = {},
            ['无效'] = {},
            ['优先'] = {}  -- 新增：优先词缀分类
        }

        if not suffixes or #suffixes == 0 then
            categories['无效'][1] = '空词条列表'
            return categories
        end

        -- UTF-8安全的排除列表处理
        local processed_not_use_map = {}
        for _, excl in ipairs(not_use_map or {}) do
            if excl then
                local processed = string.gsub(excl, "<rgb%(255,0,0%)>", "")
                processed = _M.clean_utf8(processed)
                processed = _M.extract_utf8_text(processed)
                processed = string.gsub(processed, "[%d%%%s]", "")
                table.insert(processed_not_use_map, processed)
            end
        end

        -- UTF-8安全的优先词缀处理
        local processed_priority_map = {}
        if priority_enabled and priority_map then
            for _, priority in ipairs(priority_map) do
                if priority then
                    local processed = string.gsub(priority, "<rgb%(255,0,0%)>", "")
                    processed = _M.clean_utf8(processed)
                    processed = _M.extract_utf8_text(processed)
                    processed = string.gsub(processed, "[%d%%%s]", "")
                    table.insert(processed_priority_map, processed)
                end
            end
        end

        for i, suffix in ipairs(suffixes) do
            local suffix_name = suffix.name_utf8 or ""

            -- 1. 移除RGB标签
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>", "")
            
            -- 2. UTF-8安全清理
            cleaned_suffix = _M.clean_utf8(cleaned_suffix)
            
            -- 3. UTF-8文本提取
            cleaned_suffix = _M.extract_utf8_text(cleaned_suffix)

            if cleaned_suffix == "" then
                table.insert(categories['无效'], suffix_name)
                goto continue
            end

            -- UTF-8安全的词条处理
            local processed_suffix = string.gsub(cleaned_suffix, "[%d%%%s]", "")

            -- 优先检查优先词缀（如果启用）
            if priority_enabled then
                for _, processed_priority in ipairs(processed_priority_map) do
                    if string.find(processed_suffix, processed_priority, 1, true) then
                        table.insert(categories['优先'], cleaned_suffix)
                        goto continue
                    end
                end
            end

            -- UTF-8安全的排除检查
            for _, processed_excl in ipairs(processed_not_use_map) do
                if string.find(processed_suffix, processed_excl, 1, true) then
                    table.insert(categories['不打'], cleaned_suffix)
                    goto continue
                end
            end

            -- UTF-8安全的疯癫词条检查
            if string.find(processed_suffix, "譫妄", 1, true) then
                table.insert(categories['譫妄'], cleaned_suffix)
                goto continue
            end

            -- 其他UTF-8词条
            table.insert(categories['其他'], cleaned_suffix)

            ::continue::
        end

        return categories
    end

    -- 优先词缀匹配检查函数
    local function has_priority_suffixes(suffixes)
        if not priority_enabled or not priority_map or #priority_map == 0 then
            return false
        end

        if not suffixes or #suffixes == 0 then
            return false
        end

        -- 处理优先词缀列表
        local processed_priority_map = {}
        for _, priority in ipairs(priority_map) do
            if priority then
                local processed = string.gsub(priority, "<rgb%(255,0,0%)>", "")
                processed = _M.clean_utf8(processed)
                processed = _M.extract_utf8_text(processed)
                processed = string.gsub(processed, "[%d%%%s]", "")
                table.insert(processed_priority_map, processed)
            end
        end

        -- 检查是否有匹配的优先词缀
        for _, suffix in ipairs(suffixes) do
            local suffix_name = suffix.name_utf8 or ""
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>", "")
            cleaned_suffix = _M.clean_utf8(cleaned_suffix)
            cleaned_suffix = _M.extract_utf8_text(cleaned_suffix)
            local processed_suffix = string.gsub(cleaned_suffix, "[%d%%%s]", "")

            for _, processed_priority in ipairs(processed_priority_map) do
                if string.find(processed_suffix, processed_priority, 1, true) then
                    return true
                end
            end
        end

        return false
    end

    local best_key = nil
    local max_score = -math.huge
    local min_score = math.huge
    local processed_keys = 0

    -- 预处理key_level_threshold，同时解析优先词缀配置
    local white, blue, gold, valls, level = {}, {}, {}, {}, {}
    local priority_config_by_level = {}  -- 新增：按等级存储优先词缀配置

    if key_level_threshold then
        for _, user_map in ipairs(key_level_threshold) do
            local tier_value = user_map['階級']
            local level_list = {}
            
            if type(tier_value) == "string" and string.find(tier_value, "-") then
                local min_tier, max_tier = tier_value:match("(%d+)-(%d+)")
                min_tier = tonumber(min_tier)
                max_tier = tonumber(max_tier)
                
                if min_tier and max_tier then
                    for t = min_tier, max_tier do
                        table.insert(level_list, t)
                    end
                end
            else
                local tier_num = tonumber(tier_value)
                if tier_num then
                    table.insert(level_list, tier_num)
                end
            end
            
            for _, lvl in ipairs(level_list) do
                table.insert(level, lvl)
                
                -- 存储该等级的优先词缀配置
                priority_config_by_level[lvl] = {
                    priority_map = user_map['优先打词缀'] and user_map['优先打词缀']['詞綴'] or {},
                    priority_enabled = user_map['优先打词缀'] and user_map['优先打词缀']['是否開啟'] or false
                }
                
                if user_map['白'] then
                    if not _M.table_contains(white, lvl) then
                        table.insert(white, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
                
                if user_map['藍'] then
                    if not _M.table_contains(blue, lvl) then
                        table.insert(blue, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
                
                if user_map['黃'] then
                    if not _M.table_contains(gold, lvl) then
                        table.insert(gold, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
            end
        end
        
        -- _M.dbgp("预处理完成，各等级优先词缀配置:")
        -- for lvl, config in pairs(priority_config_by_level) do
        --     _M.dbgp(string.format("等级 %d: 启用=%s, 词缀=%s", 
        --         lvl, tostring(config.priority_enabled), 
        --         table.concat(config.priority_map or {}, ", ")))
        -- end
    end

    -- 处理物品 - 第一阶段：过滤
    local valid_items = {}  -- 存储所有有效的物品

    for i, item in ipairs(inventory) do
        -- 检查是否为地图钥匙
        if not string.find(item.baseType_utf8 or "", "地圖鑰匙") then
            goto continue
        end

        -- 颜色过滤
        if color > 0 then
            if (item.color or 0) < color then
                goto continue
            end
        end

        local key_level = item.mapLevel

        -- 污染过滤
        if vall then
            if item.contaminated then
                goto continue
            end
        end

        -- 等级过滤
        if min_level and key_level < min_level then
            goto continue
        end

        -- 钥匙等级阈值检查
        if key_level_threshold then
            local valid = false
            if item.color == 0 and #white > 0 and _M.table_contains(white, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end
            if item.color == 1 and #blue > 0 and _M.table_contains(blue, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end
            if item.color == 2 and #gold > 0 and _M.table_contains(gold, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end

            if not valid then
                goto continue
            end
        end

        -- 词缀长度检查
        if entry_length > 0 then
            if (item.fixedSuffixCount or 0) < entry_length and item.contaminated then
                goto continue
            end
        end

        local suffixes = nil
        if (item.color or 0) > 0 then
            suffixes = api_GetObjectSuffix(item.mods_obj)
            if suffixes and #suffixes > 0 then
                -- 排除词缀检查
                if #not_use_map > 0 then
                    if _M.match_item_suffixes(suffixes, not_use_map, true) then
                        if trashest then
                            best_key = item
                            break
                        end
                        goto continue
                    end
                end
            end
        end

        -- 通过所有过滤条件，添加到有效物品列表
        table.insert(valid_items, item)
        
        ::continue::
    end

    -- 强满足版本：每个阶级单独处理
    local best_priority_key = nil
    local best_priority_score = -math.huge
    local best_priority_reason = ""
    local found_items = {}  -- 存储找到的物品

    -- 辅助函数：根据词条名称获取物品属性值
    local function get_item_priority_value(item, priority_name)
        if priority_name == "怪物群大小" then
            return item.monsterPackSize
        elseif priority_name == "稀有怪物" then
            return item.rareMonster
        elseif priority_name == "物品稀有度" then
            return item.itemRarity
        elseif priority_name == "地图掉落机率" then
            return item.mapDropChance
        elseif priority_name == "换届石掉落几率" then
            return item.mapDropChance  -- 假设换届石掉落几率使用mapDropChance属性
        else
            _M.dbgp("未知优先词条: " .. tostring(priority_name))
            return nil
        end
    end

    local items_by_tier = {}
    if #valid_items > 0 then
        -- _M.dbgp("开始处理 " .. #valid_items .. " 个有效物品的优先词缀")
        
        -- 按阶级分组物品
        for i, item in ipairs(valid_items) do
            local tier = item.mapLevel
            if not items_by_tier[tier] then
                items_by_tier[tier] = {}
            end
            table.insert(items_by_tier[tier], item)
        end
        
        -- 对每个阶级单独处理
        for tier, tier_items in pairs(items_by_tier) do
            local level_config = priority_config_by_level[tier] or {}
            local level_priority_enabled = level_config.priority_enabled or false
            local level_priority_map = level_config.priority_map or {}

            -- _M.printTable(level_config)
            -- _M.printTable(level_priority_enabled)
            -- _M.printTable(level_priority_map)

            -- _M.dbgp(string.format("处理阶级%d: 配置开启=%s, 词缀数量=%d, 物品数量=%d", 
            --     tier, tostring(level_priority_enabled), #level_priority_map, #tier_items))
            
            -- 如果该阶级没有开启优先词缀配置，跳过
            if not level_priority_enabled or #level_priority_map == 0 then
                -- _M.dbgp(string.format("阶级%d未开启优先词缀配置，跳过", tier))
                goto continue_tier
            end
            
            -- 第一轮：处理第一个优先词条
            local first_priority_items = {}
            for i, item in ipairs(tier_items) do
                local first_priority_name = level_priority_map[1]  -- 第一个词条
                if first_priority_name then
                    local item_value = get_item_priority_value(item, first_priority_name)
                    
                    -- 检查第一个优先词条
                    if item_value and item_value > 0 then
                        local score = item_value
                        local reason = string.format("阶级%d-第1词条-%s:%d", tier, first_priority_name, score)
                        
                        -- _M.dbgp(string.format("阶级%d钥匙满足第1词条(%s): %d", 
                        --     tier, first_priority_name, score))
                        
                        table.insert(first_priority_items, {
                            item = item,
                            score = score,
                            reason = reason,
                            priority_index = 1,
                            tier = tier
                        })
                    end
                end
            end
            
            if #first_priority_items == 0 then
                -- _M.dbgp(string.format("阶级%d没有找到满足第1词条的物品，该阶级返回nil", tier))
                best_priority_key = nil
                best_priority_score = -math.huge
                break  -- 该阶级没有满足条件的物品，整个函数返回nil
            end
            
            -- _M.dbgp(string.format("阶级%d找到 %d 个满足第1词条的物品", tier, #first_priority_items))
            
            -- 第二轮：在满足第一个词条的物品中检查第二个词条
            local second_priority_items = {}
            for i, data in ipairs(first_priority_items) do
                local item = data.item
                
                if #level_priority_map >= 2 then
                    local second_priority_name = level_priority_map[2]  -- 第二个词条
                    if second_priority_name then
                        local item_value = get_item_priority_value(item, second_priority_name)
                        
                        -- 检查第二个优先词条
                        if item_value and item_value > 0 then
                            local total_score = data.score + item_value * 0.8  -- 第二个词条权重降低
                            local reason = data.reason .. string.format("+第2词条-%s:%d", second_priority_name, item_value)
                            
                            -- _M.dbgp(string.format("阶级%d物品同时满足第2词条(%s): %d, 总分: %d", 
                            --     tier, second_priority_name, item_value, total_score))
                            -- _M.dbgp("阶级" .. tier .. "物品同时满足第2词条(" .. second_priority_name .. "): " .. item_value .. ", 总分: " .. total_score)
                            
                            table.insert(second_priority_items, {
                                item = item,
                                score = total_score,
                                reason = reason,
                                priority_index = 2,
                                tier = tier
                            })
                        end
                    end
                end
                
                -- 如果没有第二个词条，保留第一个词条的数据
                if #level_priority_map < 2 then
                    table.insert(second_priority_items, data)
                end
            end
            
            if #second_priority_items > 0 then
                -- _M.dbgp(string.format("阶级%d第二轮筛选后剩余 %d 个物品", tier, #second_priority_items))
                
                -- 第三轮：在满足前两个词条的物品中检查第三个词条
                local third_priority_items = {}
                for i, data in ipairs(second_priority_items) do
                    local item = data.item
                    
                    if #level_priority_map >= 3 then
                        local third_priority_name = level_priority_map[3]  -- 第三个词条
                        if third_priority_name then
                            local item_value = get_item_priority_value(item, third_priority_name)
                            
                            -- 检查第三个优先词条
                            if item_value and item_value > 0 then
                                local total_score = data.score + item_value * 0.6  -- 第三个词条权重进一步降低
                                local reason = data.reason .. string.format("+第3词条-%s:%d", third_priority_name, item_value)
                                
                                -- _M.dbgp(string.format("阶级%d物品同时满足第3词条(%s): %d, 总分: %d", 
                                --     tier, third_priority_name, item_value, total_score))
                                -- _M.dbgp("阶级" .. tier .. "物品同时满足第3词条(" .. third_priority_name .. "): " .. item_value .. ", 总分: " .. total_score)
                                
                                table.insert(third_priority_items, {
                                    item = item,
                                    score = total_score,
                                    reason = reason,
                                    priority_index = 3,
                                    tier = tier
                                })
                            end
                        end
                    end
                    
                    -- 如果没有第三个词条，保留之前的数据
                    if #level_priority_map < 3 then
                        table.insert(third_priority_items, data)
                    end
                end
                
                if #third_priority_items > 0 then
                    -- _M.dbgp(string.format("阶级%d第三轮筛选后剩余 %d 个物品", tier, #third_priority_items))
                    
                    -- 第四轮：在满足前三个词条的物品中检查第四个词条
                    local fourth_priority_items = {}
                    for i, data in ipairs(third_priority_items) do
                        local item = data.item
                        
                        if #level_priority_map >= 4 then
                            local fourth_priority_name = level_priority_map[4]  -- 第四个词条
                            if fourth_priority_name then
                                local item_value = get_item_priority_value(item, fourth_priority_name)
                                
                                -- 检查第四个优先词条
                                if item_value and item_value > 0 then
                                    local total_score = data.score + item_value * 0.4  -- 第四个词条权重最低
                                    local reason = data.reason .. string.format("+第4词条-%s:%d", fourth_priority_name, item_value)
                                    
                                    -- _M.dbgp(string.format("阶级%d物品同时满足第4词条(%s): %d, 总分: %d", 
                                    --     tier, fourth_priority_name, item_value, total_score))
                                    -- _M.dbgp("阶级" .. tier .. "物品同时满足第4词条(" .. fourth_priority_name .. "): " .. item_value .. ", 总分: " .. total_score)

                                    table.insert(fourth_priority_items, {
                                        item = item,
                                        score = total_score,
                                        reason = reason,
                                        priority_index = 4,
                                        tier = tier
                                    })
                                end
                            end
                        end
                        
                        -- 如果没有第四个词条，保留之前的数据
                        if #level_priority_map < 4 then
                            table.insert(fourth_priority_items, data)
                        end
                    end
                    
                    found_items = fourth_priority_items
                else
                    found_items = second_priority_items
                end
            else
                found_items = first_priority_items
            end
            
            -- 从该阶级最终筛选出的物品中选择分数最高的
            local tier_best_score = -math.huge
            local tier_best_item = nil
            local tier_best_reason = ""
            
            for i, data in ipairs(found_items) do
                if data.score > tier_best_score then
                    tier_best_score = data.score
                    tier_best_item = data.item
                    tier_best_reason = data.reason
                end
            end
            
            -- 更新全局最优
            if tier_best_score > best_priority_score then
                best_priority_score = tier_best_score
                best_priority_key = tier_best_item
                best_priority_reason = tier_best_reason
            end
            
            -- _M.dbgp(string.format("阶级%d最优: %s 总分数: %d", tier, tier_best_reason, tier_best_score))
            -- _M.dbgp("阶级" .. tier .. "最优: " .. tier_best_reason .. "总分数: " .. tier_best_score )
            
            ::continue_tier::
        end
    else
        -- _M.dbgp("没有有效物品可供处理")
    end

    -- 第三阶段：确定最终选择
    if not trashest then
        if best_priority_key then
            -- 优先选择有优先词缀的物品
            -- _M.dbgp("选择优先词缀数值最高的物品: " .. best_priority_reason .. "总分数: " .. tostring(best_priority_score))
            best_key = best_priority_key
            max_score = best_priority_score
        else
            -- 如果有任何阶级开启了优先配置但没有找到匹配物品，返回nil
            local any_priority_enabled = false
            -- _M.printTable(items_by_tier)
            for tier, items in pairs(items_by_tier or {}) do
                local level_config = priority_config_by_level[tier] or {}
                if level_config.priority_enabled and #(level_config.priority_map or {}) > 0 then
                    any_priority_enabled = true
                    -- _M.dbgp(string.format("阶级%d开启了优先配置但未找到匹配物品", tier))
                    break
                end
            end
            
            if any_priority_enabled then
                -- _M.dbgp("有阶级开启了优先词缀配置但未找到匹配物品，返回nil")
                return nil
            elseif #valid_items > 0 then
                -- 如果没有阶级开启优先配置，使用原来的评分逻辑
                -- _M.dbgp("没有阶级开启优先词缀配置，使用普通评分逻辑")
                
                for i, item in ipairs(valid_items) do
                    local suffixes = nil
                    if (item.color or 0) > 0 then
                        suffixes = api_GetObjectSuffix(item.mods_obj)
                    end
        
                    -- 词缀分类和评分
                    local categories = categorize_suffixes_utf8(suffixes or {})
        
                    -- trashest模式处理
                    if trashest and
                        not (categories['譫妄'][1] or categories['其他'][1] or
                            categories['不打'][1] or categories['优先'][1]) then
                        best_key = item
                        break
                    end
        
                    local key_level = item.mapLevel
                    -- 计算评分
                    local level_weight = key_level * 5
                    -- local suffix_score = calculate_score_utf8(categories, {})
                    local suffix_score = 0
                    local color_score = 25 * (item.color or 0)
                    if item.contaminated then
                        color_score = color_score + 100
                    end
        
                    local additional_score = 0
                    -- 基于优先级逆序的四个参数加分 (item.itemRarity最重要)
                    -- 优先级1: item.itemRarity (最重要)
                    if item.itemRarity then
                        -- 最高权重，基础分 + 分级奖励
                        local rarity_score = item.itemRarity * 4.0  -- 最高权重系数
                        if item.itemRarity >= 90 then
                            rarity_score = rarity_score + 100  -- 顶级奖励
                        elseif item.itemRarity >= 70 then
                            rarity_score = rarity_score + 50   -- 高级奖励
                        elseif item.itemRarity >= 50 then
                            rarity_score = rarity_score + 25   -- 中级奖励
                        end
                        additional_score = additional_score + math.min(rarity_score, 300)  -- 设置上限
                    end

                    -- 优先级2: item.rareMonster (第二重要)
                    if item.rareMonster then
                        local rare_score = item.rareMonster * 3.0  -- 较高权重
                        if item.rareMonster >= 25 then
                            rare_score = rare_score + 75
                        elseif item.rareMonster >= 15 then
                            rare_score = rare_score + 40
                        elseif item.rareMonster >= 8 then
                            rare_score = rare_score + 20
                        end
                        additional_score = additional_score + math.min(rare_score, 250)
                    end

                    -- 优先级3: item.monsterPackSize (第三重要)
                    if item.monsterPackSize then
                        local pack_score = item.monsterPackSize * 2.0  -- 中等权重
                        if item.monsterPackSize >= 35 then
                            pack_score = pack_score + 50
                        elseif item.monsterPackSize >= 25 then
                            pack_score = pack_score + 25
                        elseif item.monsterPackSize >= 15 then
                            pack_score = pack_score + 10
                        end
                        additional_score = additional_score + math.min(pack_score, 180)
                    end

                    -- 优先级4: item.mapDropChance (最不重要)
                    if item.mapDropChance then
                        local map_score = item.mapDropChance * 1.5  -- 较低权重
                        if item.mapDropChance >= 85 then
                            map_score = map_score + 30
                        elseif item.mapDropChance >= 65 then
                            map_score = map_score + 15
                        elseif item.mapDropChance >= 45 then
                            map_score = map_score + 8
                        end
                        additional_score = additional_score + math.min(map_score, 150)
                    end
        
                    local total_score
                    if no_categorize_suffixes == 0 then
                        total_score = level_weight + suffix_score + color_score + additional_score
                    else
                        total_score = level_weight + color_score + additional_score
                    end
        
                    -- 记录最优
                    if index == 0 then
                        if total_score > max_score and total_score > 0 then
                            max_score = total_score
                            best_key = item
                        end
                    else
                        if total_score < min_score then
                            min_score = total_score
                            best_key = item
                        end
                    end
                end
            else
                _M.dbgp("没有找到任何有效的物品")
                best_key = nil
            end
        end
    end
    
    -- 第三阶段：确定最终选择
    if best_priority_key then
        -- 优先选择有优先词缀的物品
        _M.dbgp("选择优先词缀数值最高的物品: " .. best_priority_reason .. "总分数: " .. tostring(best_priority_score))
        best_key = best_priority_key
        max_score = best_priority_score
    elseif has_priority_config then
        -- 优先配置已开启但未找到匹配物品，返回nil
        _M.dbgp("优先词缀配置已开启但未找到匹配物品，返回nil")
        return nil
    elseif #valid_items > 0 then
        -- 如果没有优先词缀配置或未开启，使用原来的评分逻辑
        _M.dbgp("没有优先词缀配置或未开启，使用普通评分逻辑")
        
        for i, item in ipairs(valid_items) do
            local suffixes = nil
            if (item.color or 0) > 0 then
                suffixes = api_GetObjectSuffix(item.mods_obj)
            end

            -- 词缀分类和评分
            local categories = categorize_suffixes_utf8(suffixes or {})

            -- trashest模式处理
            if trashest and
                not (categories['譫妄'][1] or categories['其他'][1] or
                    categories['不打'][1] or categories['优先'][1]) then
                best_key = item
                break
            end

            local key_level = item.mapLevel
            -- 计算评分
            local level_weight = key_level * 5
            -- local suffix_score = calculate_score_utf8(categories, {})
            local suffix_score = 0
            local color_score = 25 * (item.color or 0)
            if item.contaminated then
                color_score = color_score + 100
            end

            local additional_score = 0

            local total_score
            if no_categorize_suffixes == 0 then
                total_score = level_weight + suffix_score + color_score + additional_score
            else
                total_score = level_weight + color_score + additional_score
            end

            -- 记录最优
            if index == 0 then
                if total_score > max_score and total_score > 0 then
                    max_score = total_score
                    best_key = item
                end
            else
                if total_score < min_score then
                    min_score = total_score
                    best_key = item
                end
            end
        end
    else
        -- _M.dbgp("没有找到任何有效的物品")
        best_key = nil
    end

    -- 后续的点击和执行逻辑保持不变...
    -- 后续处理逻辑（保持不变）
    if best_key then
        if score ~= 0 then
            local final_score = 0
            if index == 0 then
                final_score = max_score or 0
            else
                final_score = min_score or 0
            end
            return best_key, final_score
        end
    else
        _M.dbgp("警告: best_key 为 nil")
    end

    -- 执行选择
    if best_key then
        -- _M.api_print(f"█ 最优选择：{best_key.name_utf8} | 评分：{max_score}")
        if score == 1 then
            return best_key, best_key.mapLevel
        end
        if click == 1 then
            if page_type == 7 then
                local pos =  _M.get_center_position_store_max(
                    {best_key.start_x or 0, best_key.start_y or 0},
                    {best_key.end_x or 0, best_key.end_y or 0},
                    15, 100, 22, 22)
                _M.ctrl_left_click(pos[1], pos[2])
                return best_key.mapLevel
            end
            if type_map == 1 then
                -- _M.api_print(11111111111111)
                _M.ctrl_left_click_store_items(best_key.obj or nil, inventory)
                return best_key.mapLevel
            end
            if type_map == 3 then
                _M.return_more_map(best_key.obj or nil, inventory, START_X, START_Y)
                return best_key.mapLevel
            end

            _M.ctrl_left_click_bag_items(best_key.obj or nil, inventory)
            return best_key.mapLevel
        end
        return best_key
    else
        -- _M.api_print("⚠️ 未找到符合条件的地图钥匙")
        return nil
    end

    return best_key
end

-- 选择最优地图钥匙
_M.select_best_map_key_orange = function(params)
    -- 解析参数表
    local inventory = params.inventory
    local click = params.click or 0
    local key_level_threshold = params.key_level_threshold
    local type_map = params.type or 0
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
    local instill = params.instill or false

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

    -- UTF-8优化的词缀分类
    local function categorize_suffixes_utf8(suffixes)
        -- _M.dbgp("开始UTF-8词缀分类...")
        local categories = {
            ['譫妄'] = {},
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
                -- 1. 移除RGB标签
                local processed = string.gsub(excl, "<rgb%(255,0,0%)>", "")
                
                -- 2. UTF-8安全清理
                processed = _M.clean_utf8(processed)
                
                -- 3. UTF-8文本提取
                processed = _M.extract_utf8_text(processed)
                
                processed = string.gsub(processed, "[%d%%%s]", "")

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
            -- _M.dbgp("原始词缀: "..suffix_name)
    
            -- 1. 移除RGB标签
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>", "")
            -- _M.dbgp("移除RGB后: "..cleaned_suffix)
            
            -- 2. UTF-8安全清理
            cleaned_suffix = _M.clean_utf8(cleaned_suffix)
            -- _M.dbgp("_M.clean_utf8后: "..cleaned_suffix)
            
            -- 3. UTF-8文本提取
            cleaned_suffix = _M.extract_utf8_text(cleaned_suffix)
            -- _M.dbgp("extract_utf8_text后: "..cleaned_suffix)

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
            if string.find(processed_suffix, "譫妄", 1, true) then
                -- _M.dbgp("发现UTF-8譫妄词条")
                table.insert(categories['譫妄'], cleaned_suffix)
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
        if not (categories['譫妄'][1] or categories['其他'][1] or
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
            ["譫妄"] = 10.0
        }

        -- 处理譫妄词条
        for _, suffix in ipairs(categories['譫妄']) do
            -- _M.dbgp(string.format("UTF-8譫妄词条: %s, 权重=5.0",
            --                            suffix))
            score = score + 50 -- 譫妄词条固定加分
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
                                --  "UTF-8未匹配关键词的词条: %s", suffix))
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
            local tier_value = user_map['階級']
            local level_list = {}
            
            -- 处理区间格式（如 "4-15"）
            if type(tier_value) == "string" and string.find(tier_value, "-") then
                local min_tier, max_tier = tier_value:match("(%d+)-(%d+)")
                min_tier = tonumber(min_tier)
                max_tier = tonumber(max_tier)
                
                if min_tier and max_tier then
                    for t = min_tier, max_tier do
                        table.insert(level_list, t)
                    end
                end
            -- 处理单个数值
            else
                local tier_num = tonumber(tier_value)
                if tier_num then
                    table.insert(level_list, tier_num)
                end
            end
            
            -- 为每个层级添加对应的配置
            for _, lvl in ipairs(level_list) do
                -- 将层级添加到总表中
                table.insert(level, lvl)
                
                -- 白色钥匙配置
                if user_map['白'] then
                    if not _M.table_contains(white, lvl) then
                        table.insert(white, lvl)
                        -- _M.dbgp(string.format("添加白色钥匙等级: %d", lvl))
                    end
                    -- 白色污染钥匙
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                            -- _M.dbgp(string.format("添加白色污染钥匙等级: %d", lvl))
                        end
                    end
                end
                
                -- 蓝色钥匙配置  
                if user_map['藍'] then
                    if not _M.table_contains(blue, lvl) then
                        table.insert(blue, lvl)
                        -- _M.dbgp(string.format("添加蓝色钥匙等级: %d", lvl))
                    end
                    -- 蓝色污染钥匙
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                            -- _M.dbgp(string.format("添加蓝色污染钥匙等级: %d", lvl))
                        end
                    end
                end
                
                -- 黄色钥匙配置
                if user_map['黃'] then
                    if not _M.table_contains(gold, lvl) then
                        table.insert(gold, lvl)
                        -- _M.dbgp(string.format("添加黄色钥匙等级: %d", lvl))
                    end
                    -- 黄色污染钥匙
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                            -- _M.dbgp(string.format("添加黄色污染钥匙等级: %d", lvl))
                        end
                    end
                end
            end
        end
    end

    -- _M.dbgp(string.format("开始处理 %d 个物品...", #inventory))
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

        local key_level = item.mapLevel
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
            if item.color == 0 and #white > 0 and _M.table_contains(white, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                    _M.dbgp("匹配污染钥匙等级")
                end
                valid = true
                _M.dbgp("匹配白色钥匙等级")
            end
            if item.color == 1 and #blue > 0 and _M.table_contains(blue, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                    _M.dbgp("匹配污染钥匙等级")
                end
                valid = true
                _M.dbgp("匹配蓝色钥匙等级")
            end
            if item.color == 2 and #gold > 0 and _M.table_contains(gold, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                    _M.dbgp("匹配污染钥匙等级")
                end
                valid = true
                _M.dbgp("匹配黄色钥匙等级")
            end
            -- if #valls > 0 and _M.table_contains(valls, key_level) then
            --     if #valls > 0 and _M.table_contains(valls, key_level) then
            --         valid = true
            --         _M.dbgp("匹配污染钥匙等级")
            --     end
            --     valid = true
            --     _M.dbgp("匹配污染钥匙等级")
            -- end

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
                    -- if _M.analyze_map_modifiers(priority_map, item)then
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
            not (categories['譫妄'][1] or categories['其他'][1] or
                categories['不打'][1]) then
            -- _M.dbgp("trashest模式选择无词缀钥匙")
            best_key = item
            break
        end

        -- instill模式处理
        -- if instill and
        --     not (categories['譫妄'][1] or categories['其他'][1] or
        --         categories['不打'][1]) 
        --     -- _M.dbgp("trashest模式选择无词缀钥匙")
        --     best_key = item
        --     break
        -- end

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

        -- 基于优先级逆序的四个参数加分 (item.itemRarity最重要)
        local additional_score = 0

        -- 优先级1: item.itemRarity (最重要)
        if item.itemRarity then
            -- 最高权重，基础分 + 分级奖励
            local rarity_score = item.itemRarity * 4.0  -- 最高权重系数
            if item.itemRarity >= 90 then
                rarity_score = rarity_score + 100  -- 顶级奖励
            elseif item.itemRarity >= 70 then
                rarity_score = rarity_score + 50   -- 高级奖励
            elseif item.itemRarity >= 50 then
                rarity_score = rarity_score + 25   -- 中级奖励
            end
            additional_score = additional_score + math.min(rarity_score, 300)  -- 设置上限
        end

        -- 优先级2: item.rareMonster (第二重要)
        if item.rareMonster then
            local rare_score = item.rareMonster * 3.0  -- 较高权重
            if item.rareMonster >= 25 then
                rare_score = rare_score + 75
            elseif item.rareMonster >= 15 then
                rare_score = rare_score + 40
            elseif item.rareMonster >= 8 then
                rare_score = rare_score + 20
            end
            additional_score = additional_score + math.min(rare_score, 250)
        end

        -- 优先级3: item.monsterPackSize (第三重要)
        if item.monsterPackSize then
            local pack_score = item.monsterPackSize * 2.0  -- 中等权重
            if item.monsterPackSize >= 35 then
                pack_score = pack_score + 50
            elseif item.monsterPackSize >= 25 then
                pack_score = pack_score + 25
            elseif item.monsterPackSize >= 15 then
                pack_score = pack_score + 10
            end
            additional_score = additional_score + math.min(pack_score, 180)
        end

        -- 优先级4: item.mapDropChance (最不重要)
        if item.mapDropChance then
            local map_score = item.mapDropChance * 1.5  -- 较低权重
            if item.mapDropChance >= 85 then
                map_score = map_score + 30
            elseif item.mapDropChance >= 65 then
                map_score = map_score + 15
            elseif item.mapDropChance >= 45 then
                map_score = map_score + 8
            end
            additional_score = additional_score + math.min(map_score, 150)
        end

        local total_score
        if no_categorize_suffixes == 0 then
            total_score = level_weight + suffix_score + color_score + additional_score
            -- _M.dbgp(string.format(
            --                 "UTF-8总评分: 等级(%d*5=%d) + 词缀(%d) + 颜色(%d) + 附加分(%d) = %d",
            --                 key_level, level_weight, suffix_score, color_score, additional_score,
            --                 total_score))
        else
            total_score = level_weight + color_score + additional_score
            -- _M.dbgp(string.format(
            --                 "UTF-8总评分(忽略词缀): 等级(%d*5=%d) + 颜色(%d) + 附加分(%d) = %d",
            --                 key_level, level_weight, color_score, additional_score, total_score))
        end

        -- 记录最优
        if index == 0 then
            if total_score > max_score and total_score > 0 then
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

    -- 执行选择
    if best_key then
        -- _M.api_print(f"█ 最优选择：{best_key.name_utf8} | 评分：{max_score}")
        if score == 1 then
            return best_key, best_key.mapLevel
        end
        if click == 1 then
            if page_type == 7 then
                local pos =  _M.get_center_position_store_max(
                    {best_key.start_x or 0, best_key.start_y or 0},
                    {best_key.end_x or 0, best_key.end_y or 0},
                    15, 100, 22, 22)
                _M.ctrl_left_click(pos[1], pos[2])
                return best_key.mapLevel
            end
            if type_map == 1 then
                -- _M.api_print(11111111111111)
                _M.ctrl_left_click_store_items(best_key.obj or nil, inventory)
                return best_key.mapLevel
            end
            if type_map == 3 then
                _M.return_more_map(best_key.obj or nil, inventory, START_X, START_Y)
                return best_key.mapLevel
            end

            _M.ctrl_left_click_bag_items(best_key.obj or nil, inventory)
            return best_key.mapLevel
        end
        return best_key
    else
        -- _M.api_print("⚠️ 未找到符合条件的地图钥匙")
        return nil
    end

    return best_key
end

_M.get_center_position_map_page = function(start_cell, end_cell, START_X, START_Y)
    _M.dbgp(string.format("计算中心坐标 | 起始格子: (%d,%d) 结束格子: (%d,%d)\n", 
        start_cell[1], start_cell[2], end_cell[1], end_cell[2]))
    
    -- 参数类型检查 (Lua中没有直接的tuple类型检查，改为检查table)
    if type(start_cell) ~= "table" or type(end_cell) ~= "table" then
        error("start_cell and end_cell must be tables")
    end

    local start_row, start_col = start_cell[1], start_cell[2]
    local end_row, end_col = end_cell[1], end_cell[2]

    -- 计算中心位置为起始和结束格子的平均位置
    local center_x = START_X + ((start_row + end_row) / 2) * CELL_WIDTH
    local center_y = START_Y + ((start_col + end_col) / 2) * CELL_HEIGHT

    -- _M.dbgp(string.format("计算过程 | X: %d + ((%d+%d)/2)*%d = %.1f\n", 
    --     START_X, start_row, end_row, self.CELL_WIDTH, center_x))
    -- _M.dbgp(string.format("计算过程 | Y: %d + ((%d+%d)/2)*%d = %.1f\n", 
    --     START_Y, start_col, end_col, self.CELL_HEIGHT, center_y))

    -- 四舍五入
    local rounded_x = math.floor(center_x + 0.5)
    local rounded_y = math.floor(center_y + 0.5)
    
    -- _M.dbgp(string.format("最终坐标 (四舍五入): (%d, %d)\n", rounded_x, rounded_y))
    return rounded_x, rounded_y
end

_M.return_more_map = function(target_name, store_info, START_X, START_Y, click)
    click = click or 0  -- 默认点击次数为0
    
    -- _M.dbgp(string.format("\n开始查找目标：%s (点击模式：%d)\n", target_name, click))
    -- _M.dbgp(string.format("基准坐标: (%d, %d)\n", START_X, START_Y))
    
    if store_info and #store_info > 0 then
        _M.dbgp(string.format("待检查物品数量：%d\n", #store_info))
        
        for i, actor in ipairs(store_info) do
            -- _M.dbgp(string.format("\n检查物品 #%d:", i))
            -- _M.dbgp(string.format("  baseType=%s", actor.baseType_utf8 or "nil"))
            -- _M.dbgp(string.format("  obj=%s", actor.obj or "nil"))
            -- _M.dbgp(string.format("  位置: (%d,%d)-(%d,%d)", 
            --     actor.start_x, actor.start_y, actor.end_x, actor.end_y))
            
            if actor.baseType_utf8 and (actor.baseType_utf8 == target_name or actor.obj == target_name) then
                -- 计算中心坐标
                local start_cell = {actor.start_x, actor.start_y}
                local end_cell = {actor.end_x, actor.end_y}
                
                -- _M.dbgp("\n√ 匹配成功！开始计算中心坐标...")
                local center_x, center_y = _M.get_center_position_map_page(start_cell, end_cell, START_X, START_Y)
                
                -- 根据点击模式执行操作
                if click == 1 then
                    -- _M.dbgp("执行右键点击操作")
                    _M.right_click(center_x, center_y)
                else
                    -- _M.dbgp("执行Ctrl+左键点击操作")
                    _M.ctrl_left_click(center_x, center_y)
                end
                
                -- _M.dbgp("操作完成，返回true\n")
                return true  -- 找到后退出
            else
                _M.dbgp("× 不匹配目标条件")
            end
        end
    else
        -- _M.dbgp("警告：store_info为空或无效\n")
        _M.dbgp("没有找到任何对象")
    end
    
    _M.dbgp("未找到目标对象，返回false\n")
    return false
end

-- 粘贴输入文本
_M.paste_text = function(text)
    api_SetClipboard(text)
    api_Sleep(200)
    _M.click_keyboard("ctrl", 1)
    api_Sleep(200)
    _M.click_keyboard("a", 0)
    api_Sleep(200)
    _M.click_keyboard("v", 0)
    api_Sleep(200)
    _M.click_keyboard("ctrl", 2)
end

-- 按键输入文本
_M.key_board_input_text = function(text)
    _M.click_keyboard("ctrl", 1)
    api_Sleep(200)
    _M.click_keyboard("a", 0)
    api_Sleep(200)
    _M.click_keyboard("ctrl", 2)
    api_Sleep(200)
    _M.input_numbers(text)
end

-- 词条过滤
_M.filter_item = function(item, suffixes, config_list)
    -- _M.dbgp("\n===== 开始物品过滤 =====")
    -- _M.dbgp(string.format("物品名称: %s",
    --                            item.baseType_utf8 or "未知"))
    -- _M.dbgp(string.format("物品稀有度: %d", item.color or 0))
    -- _M.dbgp(string.format("物品等级: %d", item.DemandLevel or 0))

    -- 遍历所有配置规则
    for i, config in ipairs(config_list) do
        -- _M.dbgp(
        --     string.format("\n检查配置规则 %d/%d", i, #config_list))

        -- 1. 检查名称 (支持"全部物品"通配)
        if type(config["類型"]) == "table" then
            if not _M.table_contains(my_game_info.item_type_china,
                                     config["類型"][1]) then
                -- _M.dbgp("→ 跳过：非装备物品类型")
                goto continue -- 非装备物品则跳过此配置
            end
        elseif not _M.table_contains(my_game_info.item_type_china,
                                     config["類型"]) then
            -- _M.dbgp("→ 跳过：非装备物品类型")
            goto continue -- 非装备物品则跳过此配置
        end

        if config["基礎類型名"] ~= "全部物品" and config["基礎類型名"] ~= item.baseType_utf8 then
            -- _M.dbgp(string.format(
            --                  "→ 跳过：基础类型不匹配（需要：%s）",
            --                  _M.table_contains(config["基礎類型名"], ",")))
            goto continue -- 名称不匹配则跳过此配置
        else
            -- _M.dbgp("√ 基础类型匹配通过")
        end

        -- 2. 检查稀有度
        local rarity_checks = {
            [0] = config["白裝"] or false,
            [1] = config["藍裝"] or false,
            [2] = config["黃裝"] or false,
            [3] = config["暗金"] or false
        }
        if not rarity_checks[item.color or 0] then
            -- _M.dbgp(string.format(
            --                  "→ 跳过：稀有度不匹配（当前：%d）",
            --                  item.color or 0))
            goto continue
        else
            -- _M.dbgp(string.format(
            --                  "√ 稀有度匹配通过（当前：%d）",
            --                  item.color or 0))
        end

        -- 3. 检查物品类型
        local config_type = config["類型"] or ""
        if config_type ~= "" then
            local item_type = type(config_type) == "table" and config_type[1] or
                                  config_type
            if item.category_utf8 ~= my_game_info.type_conversion[item_type] then
                -- _M.dbgp(string.format(
                --                  "→ 跳过：物品类型不匹配（需要：%s）",
                --                  item_type))
                goto continue
            else
                -- _M.dbgp(string.format(
                --                  "√ 物品类型匹配通过（需要：%s）",
                --                  item_type))
            end
        end

        -- 4. 检查物品等级
        local item_config = config["等級"]
        if item_config then
            local item_type = item_config["type"]
            if item_type == "exact" then
                local item_level = item_config["value"]
                if (item.DemandLevel or 0) < item_level then
                    -- _M.dbgp(string.format(
                    --                  "→ 跳过：等级不足（需要：%d，当前：%d）",
                    --                  item_level, item.DemandLevel or 0))
                    goto continue
                else
                    -- _M.dbgp(string.format(
                    --                  "√ 等级匹配通过（需要：%d）",
                    --                  item_level))
                end
            else
                local min_level = item_config["min"]
                local max_level = item_config["max"]
                if min_level and max_level then
                    if (item.DemandLevel or 0) < min_level or
                        (item.DemandLevel or 0) > max_level then
                        -- _M.dbgp(string.format(
                        --                 "→ 跳过：等级超出范围（需要：%d-%d，当前：%d）",
                        --                 min_level, max_level, item.DemandLevel or 0))
                        goto continue
                    else
                        -- _M.dbgp(string.format(
                        --                 "√ 等级范围匹配通过（需要：%d-%d）",
                        --                 min_level, max_level))
                    end
                end
            end
        end

        -- 5. 检查词缀（支持多规则处理）
        local affix_rules = config["物品詞綴"] or {}
        local check_yes = false
        if next(affix_rules) ~= nil then
            -- _M.dbgp("开始检查词缀规则...")
            
            -- 遍历所有词缀规则
            for rule_name, rule_config in pairs(affix_rules) do
                if type(rule_config) ~= "table" then
                    -- _M.dbgp(string.format("→ 跳过无效规则：%s", rule_name))
                    goto rule_continue
                end
                
                -- 检查是否全部包含模式
                local require_all = rule_config["是否全部包含"] or false
                local affix_list = rule_config["詞綴"] or {}

                if type(affix_list) ~= "table" or #affix_list == 0 then
                    -- _M.dbgp(string.format("→ 规则 %s 无有效词缀列表", rule_name))
                    goto rule_continue
                end

                -- _M.dbgp(string.format("检查规则：%s (模式：%s)", 
                --     rule_name, require_all and "全部包含" or "任一包含"))

                local matched_affixes = 0

                -- 检查每个要求的词缀
                -- _M.dbgp("开始检查词缀列表，共 " .. #affix_list .. " 个需要匹配的词缀")
                for i, required_affix in ipairs(affix_list) do
                    -- _M.dbgp(string.format("\n[词缀匹配 %d/%d] 开始检查需求词缀: %s", i, #affix_list, required_affix.name))
                    -- _M.dbgp(string.format("需求值: value1=%s, value2=%s, value3=%s", 
                    --     tostring(required_affix.value1), 
                    --     tostring(required_affix.value2), 
                    --     tostring(required_affix.value3)))
                    
                    local found = false
                    
                    -- 在物品词缀中查找匹配
                    _M.dbgp("开始遍历物品词缀(后缀)，共 " .. #suffixes .. " 个后缀")
                    for j, item_affix in ipairs(suffixes) do
                        -- _M.dbgp(string.format("[物品词缀 %d/%d] 检查: %s", j, #suffixes, item_affix.name_utf8))
                        -- _M.dbgp(string.format("当前词缀值: value1=%s, value2=%s, value3=%s", 
                        --     item_affix.value_list[1] and tostring(item_affix.value_list[1]) or "nil",
                        --     item_affix.value_list[2] and tostring(item_affix.value_list[2]) or "nil",
                        --     item_affix.value_list[3] and tostring(item_affix.value_list[3]) or "nil"))
                        
                        if item_affix.name_utf8 == required_affix.name then
                            -- _M.dbgp("√ 名称匹配成功: " .. required_affix.name)
                            local match = true
                            
                            -- 检查 value1
                            if item_affix.value_list[1] then
                                -- _M.dbgp(string.format("检查value1: 需求=%s, 实际=%s", 
                                --     tostring(required_affix.value1), 
                                --     item_affix.value_list[1] and tostring(item_affix.value_list[1]) or "nil"))
                                
                                if not item_affix.value_list[1] or item_affix.value_list[1] < required_affix.value1 then
                                    match = false
                                    -- _M.dbgp("× value1 不满足条件")
                                else
                                    -- _M.dbgp("√ value1 满足条件")
                                end
                            end
                            
                            -- 检查 value2
                            if match and item_affix.value_list[2] then
                                -- _M.dbgp(string.format("检查value2: 需求=%s, 实际=%s", 
                                --     tostring(required_affix.value2), 
                                --     item_affix.value_list[2] and tostring(item_affix.value_list[2]) or "nil"))
                                
                                if not item_affix.value_list[2] or item_affix.value_list[2] < required_affix.value2 then
                                    match = false
                                    -- _M.dbgp("× value2 不满足条件")
                                else
                                    -- _M.dbgp("√ value2 满足条件")
                                end
                            end
                            
                            -- 检查 value3
                            if match and item_affix.value_list[3] then
                                _M.dbgp(string.format("检查value3: 需求=%s, 实际=%s", 
                                    tostring(required_affix.value3), 
                                    item_affix.value_list[3] and tostring(item_affix.value_list[3]) or "nil"))
                                
                                if not item_affix.value_list[3] or item_affix.value_list[3] < required_affix.value3 then
                                    match = false
                                    -- _M.dbgp("× value3 不满足条件")
                                else
                                    -- _M.dbgp("√ value3 满足条件")
                                end
                            end
                            
                            if match then
                                found = true
                                -- _M.dbgp("√√ 当前词缀完全匹配需求!")
                                break  -- 找到匹配，跳出当前词缀检查
                            else
                                -- _M.dbgp("→ 当前词缀部分条件不匹配，继续检查下一个词缀")
                            end
                        else
                            -- _M.dbgp("× 名称不匹配: " .. item_affix.name_utf8 .. " != " .. required_affix.name)
                        end
                    end
                    
                    -- 更新匹配计数
                    if found then
                        matched_affixes = matched_affixes + 1
                        -- _M.dbgp(string.format("当前匹配计数: %d/%d", matched_affixes, #affix_list))
                    else
                        -- _M.dbgp("× 未找到匹配的词缀: " .. required_affix.name)
                    end
                    
                    -- 如果是 "任一包含" 模式，且已经匹配到一个词缀，可以提前结束
                    if not require_all and matched_affixes > 0 then
                        -- _M.dbgp("√ 满足'任一包含'模式，已找到至少一个匹配词缀，提前结束检查")
                        break
                    end
                end

                -- 检查匹配结果
                -- _M.dbgp("\n最终匹配结果检查:")
                -- _M.dbgp(string.format("匹配模式: %s", require_all and "必须全部匹配" or "任一匹配"))
                -- _M.dbgp(string.format("实际匹配数: %d/%d", matched_affixes, #affix_list))

                if (require_all and matched_affixes == #affix_list) or 
                (not require_all and matched_affixes > 0) then
                    -- _M.dbgp(string.format("√√√ 规则 %s 匹配成功", rule_name))
                    check_yes = true
                else
                    -- _M.dbgp(string.format("××× 规则 %s 不匹配", rule_name))
                end
                
                ::rule_continue::
            end
            
            if not check_yes then
                -- _M.dbgp("→ 所有词缀规则均不匹配")
                goto continue
            end
        else
            check_yes = true
        end

        if check_yes then
            -- 所有条件都满足
            -- _M.dbgp("√ 所有条件匹配成功，保留物品")
            return true
        end

        -- _M.dbgp("→ 继续检查下一个配置规则")
        ::continue::
        
    end

    -- 没有任何配置规则匹配
    -- _M.dbgp("× 无任何配置规则匹配，丢弃物品")
    return false
end

-- 词条匹配（带详细日志）
_M.match_affix_with_template = function(affix_str, template, item_value,
                                        required_value)
    -- _M.dbgp("\n----- 开始词缀匹配 -----")
    -- _M.dbgp(string.format("词缀: %s", affix_str or "无"))
    -- _M.dbgp(string.format("模板: %s", template or "无"))

    -- 空值检查
    if type(affix_str) ~= "string" or type(template) ~= "string" then
        -- _M.dbgp("× 无效输入类型")
        return false
    end

    -- 清理字符串（去除所有空白字符）
    local function clean(s)
        if not s then return "" end
        return string.gsub(s, "[%s　]+", "")
    end

    local affix = clean(affix_str)
    local pattern = clean(template)
    -- _M.dbgp(string.format("清理后词缀: %s", affix))
    -- _M.dbgp(string.format("清理后模板: %s", pattern))

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
    -- _M.dbgp(string.format("纯文本词缀: %s", affix_text))
    -- _M.dbgp(string.format("纯文本模板: %s", pattern_text))

    -- 首先检查文字部分是否匹配
    if affix_text ~= pattern_text then
        -- _M.dbgp("× 文本不匹配")
        return false
    else
        -- _M.dbgp("√ 文本匹配通过")
    end

    -- 如果只需要匹配文字，不需要比较数值
    if required_value == nil then
        -- _M.dbgp("√ 无数值要求，匹配成功")
        return true
    end

    -- 确保item_value是数组
    if type(item_value) ~= "table" then item_value = {item_value} end
    -- _M.dbgp(
    --     string.format("物品数值: %s", table.concat(item_value, ",")))

    -- 确保required_value是数组
    if type(required_value) ~= "table" then required_value = {required_value} end
    -- _M.dbgp(string.format("需求数值: %s",
    --                            table.concat(required_value, ",")))

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
        -- _M.dbgp(string.format("单值比较: %s >= %s → %s",
        --                            item_value[1], required_value[1],
        --                            tostring(result)))
    elseif #item_value == 2 and #required_value == 1 then
        result = safe_to_number(required_value[1]) >=
                     safe_to_number(item_value[1]) and
                     safe_to_number(required_value[1]) <=
                     safe_to_number(item_value[2])
        -- _M.dbgp(string.format("范围比较: %s <= %s <= %s → %s",
        --                            item_value[1], required_value[1],
        --                            item_value[2], tostring(result)))
    elseif #item_value == 1 and #required_value == 2 then
        result = safe_to_number(item_value[1]) >=
                     safe_to_number(required_value[1])
        -- _M.dbgp(string.format("下限比较: %s >= %s → %s",
        --                            item_value[1], required_value[1],
        --                            tostring(result)))
    elseif #item_value == 2 and #required_value == 2 then
        result = (safe_to_number(item_value[1]) >=
                     safe_to_number(required_value[1]) and
                     safe_to_number(item_value[2]) >=
                     safe_to_number(required_value[2]))
        -- _M.dbgp(string.format("双范围比较: [%s,%s] >= [%s,%s] → %s",
        --                            item_value[1], item_value[2],
        --                            required_value[1], required_value[2],
        --                            tostring(result)))
    else
        -- _M.dbgp("× 数值格式不支持")
        result = false
    end

    -- _M.dbgp(string.format("匹配结果: %s", tostring(result)))
    return result
end

-- 词缀规则匹配（带详细日志）
_M.match_item_suffixes = function(item_suffixes, config_suffixes, not_item)
    -- _M.dbgp("\n===== 开始词缀规则匹配 =====")
    -- _M.dbgp(string.format("物品词缀数量: %d", #item_suffixes))
    -- _M.dbgp(string.format("配置规则数量: %d",
    --                            _M.table_size(config_suffixes)))
    -- _M.printTable(config_suffixes)

    local min_matched_count = 0
    local required_suffixes = {}
    local must_contain_all = false

    if not not_item then
        local keys = {}
        for k in pairs(config_suffixes) do table.insert(keys, k) end
        if not config_suffixes or not config_suffixes[keys[1]] or
            not config_suffixes[keys[1]]["詞綴"] then
            -- _M.dbgp("→ 无有效配置规则，默认通过")
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
        -- _M.dbgp(string.format("匹配模式: %s", must_contain_all and
        --                                "必须全部匹配" or "匹配任意"))
        -- _M.dbgp(string.format("最小匹配数: %d", min_matched_count))
    else
        required_suffixes = config_suffixes
        must_contain_all = false
        -- _M.dbgp("→ 直接匹配模式")
    end

    if not required_suffixes or next(required_suffixes) == nil then
        -- _M.dbgp("× 无词缀要求")
        return false
    end

    -- 构建物品词缀列表
    local item_affixes = {}
    for _, affix in ipairs(item_suffixes) do
        table.insert(item_affixes, {affix.name_utf8, affix.value_list})
        -- _M.dbgp(string.format("物品词缀: %s (值: %s)",affix.name_utf8 or "无",table.concat(affix.value_list or {}, ",")))
    end

    local matched_count = 0
    local matched_details = {}

    -- 检查每个要求的词缀
    for required_key, required_value in pairs(required_suffixes) do
        -- _M.dbgp(string.format("\n检查需求词缀: %s", required_key))

        -- 获取配置要求的模板和数值
        local required_template, required_val
        if type(required_value) == "table" and #required_value >= 2 then
            required_template = required_value[1]
            required_val = required_value[2]
            -- _M.dbgp("11111111")
            -- _M.dbgp(string.format("模板: %s, 需求值: %s",
            --                            required_template,
            --                            table.concat(required_val, ",")))
        elseif type(required_suffixes) == "table" and not not_item then
            -- _M.dbgp("22222222")
            required_template = required_key
            required_val = required_value
            -- _M.dbgp(string.format("模板: %s, 需求值: %s",
            --                         required_template, tostring(required_val)))
        else
            required_template = required_value
            required_val = nil
            -- _M.dbgp(string.format("模板: %s (无数值要求)",
            --                            required_template))
        end

        -- 检查物品词缀是否匹配
        -- _M.dbgp("\n正在检查以下词缀:")
        -- _M.dbgp(_M.printTable(item_affixes))
        for _, affix_pair in ipairs(item_affixes) do
            local item_affix = affix_pair[1]
            local item_value = affix_pair[2]

            -- _M.dbgp(string.format("尝试匹配: %s", item_affix))

            if _M.match_affix_with_template(item_affix, required_template,item_value, required_val) then
                matched_count = matched_count + 1
                table.insert(matched_details, string.format("%s 匹配 %s",item_affix,required_template))
                -- _M.dbgp("√ 匹配成功")
                if not must_contain_all then
                    -- _M.dbgp("√ 任意匹配模式，直接返回成功")
                    return true
                end
                break
            else
                -- _M.dbgp("× 匹配失败")
            end
        end
    end

    -- 输出匹配详情
    -- _M.dbgp("\n匹配详情:")
    -- if #matched_details > 0 then
    --     for i, detail in ipairs(matched_details) do
    --         _M.dbgp(string.format("%d. %s", i, detail))
    --     end
    -- else
    --     _M.dbgp("无匹配项")
    -- end

    -- _M.dbgp(string.format("\n总匹配数: %d (需要: %d)", matched_count,
    --                            min_matched_count > 0 and min_matched_count or
    --                                "任意"))

    if min_matched_count > 0 then
        if matched_count >= min_matched_count then
            -- _M.dbgp("√ 满足最小匹配数要求")
            return true
        else
            -- _M.dbgp("× 不满足最小匹配数要求")
            return false
        end
    end

    if must_contain_all then
        local result = matched_count == _M.table_size(required_suffixes)
        -- _M.dbgp(string.format("必须全部匹配: %s", tostring(result)))
        return result
    else
        local result = matched_count > 0
        -- _M.dbgp(string.format("任意匹配: %s", tostring(result)))
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
       click = options.click or 0,         -- 可选，默认 0
       min_x = options.min_x or 0,         -- 可选，默认 0
       min_y = options.min_y or 0,         -- 可选，默认 0
       max_x = options.max_x or 1600,      -- 可选，默认 1600
       max_y = options.max_y or 900,       -- 可选，默认 900
       index = options.index or 0,         -- 可选，默认 0
       ret_data = options.ret_data or false, -- 可选，默认 false
       refresh = options.refresh or false,
       UI_info = options.UI_info or nil
   }
   
    if config.refresh or not config.UI_info then
        _M.print_log("defaults.refresh\n")
        config.UI_info = UiElements:Update()
        if #config.UI_info < 1 then
            _M.dbgp("未发现UI信息\n")
        end
    end

    if config.UI_info then
        for _, value in ipairs(config.UI_info) do
            -- _M.print_log(value.name_utf8)
            if value.name_utf8 == config.text then
                local x = (value.left + value.right) / 2
                local y = (value.top + value.bottom) / 2
                if config.click == 1 then
                    api_ClickScreen(_M.toInt(x), _M.toInt(y),1)
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
        -- 直接处理原始表，添加优化字段
        local config_item = v  -- 直接使用原始引用
        
        -- 添加优化字段
        config_item['名稱模式'] = (string.find(config_item['基礎類型名'] or '', '全部物品') and 'all') or 'specific'
        config_item["颜色"] = {}
        if config_item['白裝'] then table.insert(config_item["颜色"], 0) end
        if config_item['藍裝'] then table.insert(config_item["颜色"], 1) end
        if config_item['黃裝'] then table.insert(config_item["颜色"], 2) end
        if config_item['暗金'] then table.insert(config_item["颜色"], 3) end
        
        if type(config_item["等級"]) == "string" then
            config_item["等級"] = _M.parse_level(config_item["等級"])
        end
        
        table.insert(processed_configs, config_item)
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

-- 公开接口：打印table
_M.printTable = function(tbl, title)
    -- 私有函数：实际执行table打印
    local function _dump(value, indent, visited, output_fn)
        indent = indent or 0
        visited = visited or {}
        output_fn = output_fn or _M.dbgp
        
        -- 处理非table值
        if type(value) ~= "table" then
            if type(value) == "string" then
                return string.format("%q", value)
            else
                return tostring(value)
            end
        end
        
        -- 检查循环引用
        if visited[value] then
            return "<循环引用>"
        end
        visited[value] = true
        
        -- 准备结果缓冲区
        local result = {}
        local spaces = string.rep("  ", indent)
        table.insert(result, "{\n")
        
        -- 先处理数组部分（保证顺序）
        for i = 1, #value do
            table.insert(result, spaces.."  [")
            table.insert(result, tostring(i))
            table.insert(result, "] = ")
            table.insert(result, _dump(value[i], indent + 1, visited, output_fn))
            table.insert(result, ",\n")
        end
        
        -- 再处理非数组部分
        for k, v in pairs(value) do
            -- 跳过已处理的数组部分
            if type(k) ~= "number" or k < 1 or k > #value or math.floor(k) ~= k then
                table.insert(result, spaces.."  ")
                
                -- 处理key的格式
                if type(k) == "string" and string.match(k, "^[%a_][%a%d_]*$") then
                    table.insert(result, k.." = ")
                else
                    table.insert(result, "[")
                    table.insert(result, _dump(k, indent + 1, visited, output_fn))
                    table.insert(result, "] = ")
                end
                
                -- 处理value
                table.insert(result, _dump(v, indent + 1, visited, output_fn))
                table.insert(result, ",\n")
            end
        end
        
        table.insert(result, spaces.."}")
        return table.concat(result)
    end
    title = title or "TABLE DUMP"
    _M.dbgp(title..":\n".._dump(tbl, 0))
end

-- 获取范围内的所有文本/指定文本
-- @param params 参数表，包含以下可选字段：
--   text: 要查找的文本内容
--   min_x, min_y, max_x, max_y: 搜索区域坐标范围
--   index: 调节是否查找文本
-- @return 根据index参数返回不同结果，默认返回所有文本
_M.get_game_control_by_rect = function(data)
    local config = {
        text = data.text or "",          -- 必填
        min_x = data.min_x or 0,         -- 可选，默认 0
        min_y = data.min_y or 0,         -- 可选，默认 0
        max_x = data.max_x or 1600,      -- 可选，默认 1600
        max_y = data.max_y or 900,       -- 可选，默认 900
        index = data.index or 0,         -- 可选，默认 0，
        UI_info = data.UI_info or nil,
        refresh = data.refresh or false,
        round_rect = data.round_rect or nil,
    }
    local text_list = {}
    -- 如果需要刷新或没有UI信息，则更新UI信息
    if config.refresh or not config.UI_info then
        _M.dbgp("defaults.refresh\n")
        _M.dbgp("defaults.text -->", config.text)
        config.UI_info = UiElements:Update()
        if not config.UI_info or #config.UI_info < 1 then
            _M.dbgp("未发现UI信息\n")
            return false
        end
    end

    if config.round_rect and config.round_rect > 0 then
        local range = config.round_rect  -- 范围大小
        for _, v in ipairs(config.UI_info) do
            -- 使用 round_rect 作为范围容差来精准定位
            if v.left >= config.min_x - range and v.left <= config.min_x + range and
               v.top >= config.min_y - range and v.top <= config.min_y + range and
               v.right >= config.max_x - range and v.right <= config.max_x + range and
               v.bottom >= config.max_y - range and v.bottom <= config.max_y + range then
                
                if config.index ~= 0 and config.text and config.text ~= "" then
                    if v.name_utf8 == config.text or v.text_utf8 == config.text then
                        table.insert(text_list, v)
                    end
                else
                    table.insert(text_list, v)
                end
            end
        end
    else
        for _, v in ipairs(config.UI_info) do
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
    end
    
    return text_list
end


-- 根据位置查找文本
_M.find_text_position = function(params)
    -- 设置默认参数
    local defaults = {
        min_x = 450,
        min_y = 0,
        max_x = 1595,
        max_y = 900,
        num = 0,
        text = nil,
        all_text = 0,
        click_times = 0,
        lens = 4,
        match_text = nil,
        refresh = false,
        UI_info = nil
    }
    
    -- 合并传入参数和默认值
    for k, v in pairs(params) do defaults[k] = v end

    if defaults.refresh or not defaults.UI_info then
        defaults.UI_info = UiElements:Update()
        if #defaults.UI_info < 1 then
            _M.dbgp("未发现UI信息\n")
        end
    end
    
    local match_count = 0
    local matched_texts = {}  -- 存储所有匹配的文本
    local matchs_object = {}  -- 存储所有匹配的文本对象
    
    for _, actor in ipairs(defaults.UI_info) do
        
        if actor.text_utf8 == "" then
            goto continue
        end

        -- _M.dbgp("发现文本:", actor.text_utf8, " ,", string.len(actor.text_utf8), "defaults.lens:", defaults.lens)
        -- _M.dbgp(actor.left," ,", actor.top," ,", actor.right)
        -- goto continue


        -- 检查文本长度
        if defaults.lens > 0 and string.len(actor.text_utf8) < defaults.lens then
            goto continue
        end

        -- 检查坐标范围
        if defaults.min_x <= actor.left and actor.left <= defaults.max_x and
           defaults.min_y <= actor.top and actor.top <= defaults.max_y 
           and defaults.min_x <= actor.right and actor.right <= defaults.max_x 
           then
            
            if defaults.num == 1 then
                if defaults.text and actor.text_utf8 ~= defaults.text then
                    goto continue
                end
                match_count = match_count + 1
                table.insert(matched_texts, actor.text_utf8)
                table.insert(matchs_object, actor)
            else
                if defaults.match_text then
                    if string.find(actor.text_utf8, defaults.match_text) then
                        return actor.text_utf8
                    else
                        return nil
                    end
                end
                -- 非1的情况返回第一个匹配项
                return actor.text_utf8
            end
        end
        
        ::continue::
    end
    
    -- 处理点击操作
    if defaults.click_times > 0 and #matchs_object > 0 then
        for i = 1, defaults.click_times do
            if i > match_count then
                return false
            end
            local center_x = (matchs_object[i].left + matchs_object[i].right) / 2
            local center_y = (matchs_object[i].top + matchs_object[i].bottom) / 2
            local x, y = center_x, center_y
            _M.ctrl_left_click(math.floor(x - 10), math.floor(y - 10))
            api_Sleep(1000)
        end
        return true
    end
    
    -- 处理num=1的情况
    if defaults.num == 1 then
        if match_count > 0 then
            _M.dbgp(string.format("找到 %d 个匹配项: %s", match_count, 
                                 table.concat(matched_texts, ", ")))
            return match_count
        end
        return 0  -- 返回0表示没找到
    end
    
    -- 处理all_text=1的情况
    if defaults.all_text == 1 then
        if match_count > 0 then
            _M.dbgp(string.format("找到 %d 个匹配项: %s", match_count, 
                                 table.concat(matched_texts, ", ")))
            return matched_texts
        end
        return 0  -- 返回0表示没找到
    end
    
    return false  -- 默认返回false
end

--- 检查物品是否存在于指定的物品栏中
--- @param self table 当前对象
--- @param item_name string 物品名称（baseType_utf8字段）
--- @param inventory table 物品栏列表
--- @return boolean 如果物品存在则返回true，否则返回false
_M.check_item_in_inventory = function(item_name, inventory, count, nums)
    if inventory then
        local item_count = 0
        for _, item in ipairs(inventory) do
            if item.baseType_utf8 == item_name then
                if count then
                    if item.stackCount > 0 then
                        item_count = item_count + item.stackCount
                    else
                        item_count = item_count + 1
                    end
                else
                    return true  -- 检查到物品，返回true
                end
            end
        end
        if count then
            if nums then
                return item_count
            end
            return item_count >= count
        end
    end
    return false
end

--- 处理异界地图配置，构建索引并整合相关数据
-- @param map_cfg table 包含异界地图配置的表
-- @return void 无返回值，直接修改输入的map_cfg表
_M.process_void_maps = function(map_cfg)
    -- 构建异界地图索引，包含涂油设置和使用通货数据
    local void_maps = map_cfg['地圖鑰匙']
    local tier_index = {}
    local config_index = {}
    local oil_configs = {}
    local currency_configs = {}
    local monster_filter_configs = {}


    for _, config in ipairs(void_maps) do
        -- 强制类型转换
        local tier = config['階級']


        -- 处理区间格式（如 "4-15"）
        if type(tier) == "string" and string.find(tier, "-") then
            local min_tier, max_tier = tier:match("(%d+)-(%d+)")
            min_tier = tonumber(min_tier)
            max_tier = tonumber(max_tier)
            
            if min_tier and max_tier then
                -- 为区间内的每个层级创建索引
                for t = min_tier, max_tier do
                    if not tier_index[t] then
                        tier_index[t] = {}
                    end
                    table.insert(tier_index[t], config)
                end
            end
        -- 处理单个数值
        else
            local tier_num = tonumber(tier)
            if tier_num then
                if not tier_index[tier_num] then
                    tier_index[tier_num] = {}
                end
                table.insert(tier_index[tier_num], config)
            end
        end


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

-- # 获取祭祀物品中心点
_M.get_center_position_altar=function(start_cell, end_cell)
    -- 检查输入是否为表（Lua 中无元组，用表代替）
    if not (type(start_cell) == "table" and type(end_cell) == "table") then
        error("start_cell and end_cell 必须是表")
    end


    local start_row, start_col = start_cell[1], start_cell[2]
    local end_row, end_col = end_cell[1], end_cell[2]
    -- 计算中心位置为起始和结束格子的平均位置
    local center_x = 255 + ((start_row + end_row) / 2) * CELL_WIDTH
    local center_y = 222 + ((start_col + end_col) / 2) * CELL_HEIGHT
    -- 四舍五入
    return {math.floor(center_x + 0.5), math.floor(center_y + 0.5)}
end

-- # 快速点击祭祀物品
_M.ctrl_left_click_altar_items = function(target_name, bag_info, click)
    click = click or 0  -- 默认值为 0

    if bag_info and #bag_info > 0 then
        for _, actor in ipairs(bag_info) do
            if actor.baseType_utf8 and (actor.baseType_utf8 == target_name or actor.obj == target_name) then
                -- 计算中心坐标
                local start_cell = {actor.start_x, actor.start_y}
                local end_cell = {actor.end_x, actor.end_y}
                local center_position = _M.get_center_position_altar(start_cell, end_cell)


                if click == 1 then
                    _M.right_click(center_position[1], center_position[2])  -- Lua 索引从 1 开始
                    return true
                elseif click == 2 then
                    api_ClickScreen(_M.toInt(center_position[1]), _M.toInt(center_position[2]),0)
                    api_Sleep(200)  -- 单位是毫秒
                    api_ClickScreen(_M.toInt(center_position[1]), _M.toInt(center_position[2]),1) -- 使用 click 方法模拟左键点击
                    return true
                elseif click == 3 then
                    api_ClickScreen(_M.toInt(center_position[1]), _M.toInt(center_position[2]),2) -- 使用 click 方法模拟左键点击
                    return true
                else
                    _M.ctrl_left_click(center_position[1], center_position[2])
                    return true  -- 找到后退出
                end
            end
        end
    else
        _M.dbgp("没有找到任何对象")
        return false
    end
end

-- 根据距离玩家位置排序对象列表
-- @param items 要排序的对象列表
-- @param player_info 玩家信息(可选)
-- @return 排序后的列表或nil(如果输入无效)
_M.get_sorted_list = function(table1, player_info)

    -- 获取玩家位置信息
    if not player_info then
        _M.dbgp("错误: 无法获取玩家位置信息")
        return nil
    end

    local player_x, player_y = player_info.grid_x, player_info.grid_y
    -- _M.dbgp(string.format("排序基准点 - X:%.2f, Y:%.2f", player_x, player_y))

    -- 创建排序副本(避免修改原表)
    local sorted_items = {}
    for i, v in ipairs(table1) do
        sorted_items[i] = v
    end

    -- 定义排序函数(按距离平方排序)
    local function sort_by_distance(a, b)
        if not a.grid_x or not a.grid_y or not b.grid_x or not b.grid_y then
            _M.dbgp("警告: 对象缺少坐标信息")
            return false
        end

        local dist_a = (a.grid_x - player_x)^2 + (a.grid_y - player_y)^2
        local dist_b = (b.grid_x - player_x)^2 + (b.grid_y - player_y)^2
        
        return dist_a < dist_b
    end

    -- 执行排序
    table.sort(sorted_items, sort_by_distance)
    return sorted_items
end

-- 查找地图中的对象
_M.check_in_map = function(current_map_info, interactive_object)
    if not current_map_info then
        return nil
    end
    for _, k in ipairs(current_map_info) do
        if k.name_utf8 == interactive_object and k.flagStatus == 0 and k.flagStatus1 == 1 and k.grid_x ~= 0 and k.grid_y ~= 0 then
            return k
        end
    end
    return nil
end

-- 查找范围内的对象
_M.check_in_range = function(range_info, interactive_object, object)
    for _, k in ipairs(range_info) do
        if object then
            if k.name_utf8 == object or k.path_name_utf8 == object then
                return k
            end
        end
        if interactive_object == "MapDevice" then
            if k.name_utf8 == "黃金製圖儀" or k.name_utf8 == "地圖裝置" then
                return k
            end
        end
        if (k.name_utf8 == interactive_object or k.path_name_utf8 == interactive_object) and k.grid_x ~= 0 and k.grid_y ~= 0 then
            return k
        end
    end
    return nil
end

-- 检查背包是否有未鉴定物品
-- 返回未鉴定物品的名称列表
_M.items_not_identified = function(bag_info)
    local not_identified_items = {}  -- 存储未鉴定物品的数组
    
    if not bag_info then
        return false
    end
    
    for _, item in ipairs(bag_info) do
        if item.baseType_utf8 and item.not_identified and not _M.table_contains(my_game_info.not_need_identify, item.category_utf8) then
            table.insert(not_identified_items, item.baseType_utf8)  -- 添加未鉴定物品名称到数组
        end
    end
    
    return not_identified_items  -- 返回未鉴定物品名称列表
end

-- 获取空格位置（动态参数版本）
-- 参数表 fields:
--   width: 物品宽（必须）
--   height: 物品高（必须）
--   w: 容器排(默认5)
--   h: 容器列(默认12)
--   click: 是否点击(默认0)
--   gox: 容器左上角坐标x(默认1059)
--   goy: 容器左上角坐标y(默认492)
--   grid_x: 格子宽(默认43.81)
--   grid_y: 格子高(默认43.81)
--   index: 背包查询参数(默认1)
--   info: 可选背包信息(默认nil)
--   ret_number: false: 返回空间数量(默认fasle)
_M.get_space_point = function(params)
    -- 参数校验和默认值设置
    assert(params.width and params.height, "必须提供width和height参数")
    
    local width = params.width
    local height = params.height
    local w = params.w or 5
    local h = params.h or 12
    local click = params.click or 0
    local gox = params.gox or 1059
    local goy = params.goy or 492
    local grid_x = params.grid_x or 43.81
    local grid_y = params.grid_y or 43.81
    local index = params.index or 1
    local info = params.info or nil
    local ret_number = params.ret_number or false
     
    -- 初始化背包网格
    local backpack = {}
    for i = 1, w do
        backpack[i] = {}
        for j = 1, h do
            backpack[i][j] = false
        end
    end
    
    -- 检查是否可以放置物品
    local function can_place_item(backpack, item_top_left, item_bottom_right)
        for i = item_top_left[1], item_bottom_right[1] - 1 do
            for j = item_top_left[2], item_bottom_right[2] - 1 do
                if backpack[j + 1][i + 1] then  -- Lua数组从1开始
                    return false
                end
            end
        end
        return true
    end
    
    -- 放置物品到背包
    local function place_item(backpack, item_top_left, item_bottom_right)
        if can_place_item(backpack, item_top_left, item_bottom_right) then
            local occupied_coords = {}
            for i = item_top_left[2], item_bottom_right[2] - 1 do
                for j = item_top_left[1], item_bottom_right[1] - 1 do
                    backpack[i + 1][j + 1] = true
                    table.insert(occupied_coords, {j, i})  -- 记录坐标(x,y)
                end
            end
            return occupied_coords
        end
        return nil
    end
    
    -- 查找严格符合指定宽度和高度的空格位置
    local function find_space_for_item_strict(backpack, width, height)
        for i = 1, #backpack - height + 1 do
            for j = 1, #backpack[1] - width + 1 do
                local item_top_left = {j - 1, i - 1}  -- 转换为0-based坐标
                local item_bottom_right = {j - 1 + width, i - 1 + height}
                
                -- 检查这个区域是否完全空闲
                local can_place = true
                for x = item_top_left[2], item_bottom_right[2] - 1 do
                    for y = item_top_left[1], item_bottom_right[1] - 1 do
                        if backpack[x + 1][y + 1] then
                            can_place = false
                            break
                        end
                    end
                    if not can_place then break end
                end
                
                if can_place then
                    return place_item(backpack, item_top_left, item_bottom_right)
                end
            end
        end
        return nil
    end

    -- 返回空闲空间数量
    local function get_space_count(backpack)
        local count = 0
        for i = 1, w do
            for j = 1, h do
                if not backpack[i][j] then
                    count = count + 1
                end
            end
        end
        return count
    end
    
    -- 计算中心点坐标
    local function calculate_center(occupied_coords, grid_origin, grid_size)
        if not occupied_coords or #occupied_coords == 0 then
            return nil
        end
        
        local min_x = occupied_coords[1][1]
        local max_x = occupied_coords[1][1]
        local min_y = occupied_coords[1][2]
        local max_y = occupied_coords[1][2]
        
        for _, coord in ipairs(occupied_coords) do
            min_x = math.min(min_x, coord[1])
            max_x = math.max(max_x, coord[1])
            min_y = math.min(min_y, coord[2])
            max_y = math.max(max_y, coord[2])
        end
        
        -- 计算中心点坐标
        local center_x = grid_origin[1] + (max_x + 1 - min_x) / 2 * grid_size[1]
        local center_y = grid_origin[2] + (max_y + 1 - min_y) / 2 * grid_size[2]
        
        return {center_x, center_y}
    end
    
    -- 获取背包物品信息并标记已占用位置 
    local inventorys = nil
    if info and next(info) then
        inventorys = info
    else
        inventorys = api_Getinventorys(index,0)
    end
    if inventorys then
        for _, item in ipairs(inventorys) do
            local top_left = {item.start_x, item.start_y}
            local bottom_right = {item.end_x, item.end_y}
            place_item(backpack, top_left, bottom_right)
        end
    end

    if ret_number then
       local count =  get_space_count(backpack)
       return count
    end

    
    -- 查找空格位置
    local result = find_space_for_item_strict(backpack, width, height)
    if not result then
        return false
    end
    
    -- 计算并返回中心点坐标
    local a = result[1][1]
    local b = result[1][2]
    local grid_origin = {result[1][1] * grid_x + gox, result[1][2] * grid_y + goy}
    -- local grid_origin = {gox, goy}
    local grid_size = {grid_x, grid_y}
    local point = calculate_center(result, grid_origin, grid_size)
    
    if click == 1 then
        api_ClickScreen(_M.toInt(point[1]), _M.toInt(point[2]),1) -- 0.5秒
        return true
    else
        return point
    end
end

-- 坐标点击
_M.click_position = function(x, y, click)
    if x and y then
        api_ClickScreen(_M.toInt(x), _M.toInt(y), 0)
        api_Sleep(300)
        if click == 1 then
            _M.ctrl_left_click(x, y)
        elseif click == 2 then
            _M.ctrl_right_click(x, y)
        else
            api_ClickScreen(_M.toInt(x), _M.toInt(y), 1)
        end
    end
end

_M.format_map_data = function(config)
    -- 将获取到的剧情地图数据格式化为 ['地图名称', '章节'] 格式的列表
    local map_data = config['全局設置']['剧情地图设置'] or {}  -- 获取剧情地图数据，默认为空表
    
    -- 获取地图名称和章节
    local map_name = map_data['地图名'] or ''
    local chapter = map_data['章节'] or ''
    
    -- 处理章节格式
    if chapter ~= '' then
        if string.find(chapter, '^第') and string.find(chapter, '章$') then
            -- 检查章节是否是中文大写数字
            local chapter_num = string.match(chapter, '第(.-)章')
            if tonumber(chapter_num) ~= nil then  -- 如果是阿拉伯数字（如"第1章"），保持不变
                chapter = "第 " .. chapter_num .. " 章"
            else  -- 如果是中文大写数字（如"第一章"），转换为 <red>{第一章}
                chapter = "<red>{" .. chapter .. "}"
            end
        end
    end
    
    -- 如果地图名称和章节都存在，添加到格式化列表中
    if map_name ~= '' and chapter ~= '' then
        return {chapter, map_name}
    end
    
    return nil
end


_M.get_map_data = function(chapter, map_name)
    --[[
    根据章节名和地图名，返回对应的地图数据。
    
    参数:
        chapter (str): 章节名，例如 "第1章" 或 "<red>{第一章}"。
        map_name (str): 地图名，例如 "河岸" 或 "风沙沼泽"。
    
    返回:
        list: 地图数据，格式为 [[UI名, 参数值], 有无传送点, [一层屏幕坐标, 二层屏幕坐标], 二层名]。
            如果未找到，返回 nil。
    ]]
    
    -- 假设 the_story_map 是用户提供的全局变量
    local the_story_map = my_game_info.the_story_map
    
    -- 检查章节是否存在
    if the_story_map[chapter] then
        -- 检查地图是否存在
        if the_story_map[chapter][map_name] then
            return the_story_map[chapter][map_name]
        end
    end
    
    -- 如果未找到，返回 nil
    return nil
end


-- 返回任务地图信息
-- area (string/number): 要查询的任务区域标识符（键名）
_M.task_area_list_data = function(area)
    for k, data in pairs(my_game_info.task_area_list) do
        if k == area then
            return data
        end
    end
    return nil
end


-- 返回周围对象距离
-- name (string): 要查找的目标对象名称（UTF-8编码）
-- actors (table): 包含周围对象信息的数组，每个元素应包含 name_utf8、grid_x 和 grid_y 字段
-- player_info (table): 包含玩家位置信息的表，结构应与 _M.point_distance 函数要求的格式一致
_M.check_pos_dis = function(name, actors, player_info, all_info)
    if next(actors) then
        for _,point in ipairs(actors) do
            if point.name_utf8 == name then
                distance = _M.point_distance(point.grid_x, point.grid_y, player_info)
                if all_info then
                    return {distance, {point.grid_x, point.grid_y}}
                end
                return distance
            end
        end
    end
    return nil
end


-- 传送点是否开启
-- area (string/number): 要查询的任务区域标识符（键名）
-- waypoint (table): 传送点总表
_M.Waypoint_is_open = function(area, waypoint)
    if not waypoint or #waypoint == 0 then
        return false
    end
    for _,v in ipairs(waypoint) do
        if v.name == area and v.is_open == true then
            return true
        end
    end
    return false
end

-- 键值对计数
_M.countTableItems = function(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- 生成随机字符串
_M.generate_random_string = function(length)
    math.randomseed(os.time())
    local letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local result = {}
    for i = 1, length do
        local random_index = math.random(1, #letters)
        result[i] = letters:sub(random_index, random_index)
    end
    return table.concat(result)
end

-- 获取超大仓库物品中心点
_M.get_center_position_store_max = function(start_cell, end_cell)
    -- 参数校验
    if not start_cell or not end_cell or 
        type(start_cell) ~= "table" or type(end_cell) ~= "table" or
        #start_cell < 2 or #end_cell < 2 then
        return nil
    end

    local start_row, start_col = start_cell[1], start_cell[2]
    local end_row, end_col = end_cell[1], end_cell[2]

    -- 计算中心位置
    local center_x = START_X_max + ((start_row + end_row) / 2) * CELL_WIDTH_max
    local center_y = START_Y_max + ((start_col + end_col) / 2) * CELL_HEIGHT_max

    -- 四舍五入
    return {math.floor(center_x + 0.5), math.floor(center_y + 0.5)}
end

-- 获取地图钥匙等级
_M.extract_level = function(text)
    -- 从字符串中提取括号内的数字作为等级
    -- 参数: text (string) - 包含等级信息的字符串，例如 "地圖鑰匙（階級 1）"
    -- 返回: number 或 nil - 提取到的等级数字，如果未找到则返回 nil
    
    -- 使用 Lua 的字符串模式匹配
    local level = text:match("階級%s*(%d+)")
    if level then
        return tonumber(level)  -- 转换为数字
    end
    local level = text:match("等級%s*(%d+)")
    if level then
        return tonumber(level)  -- 转换为数字
    end
    return nil
end

-- 获取自定义物品类型
_M.get_item_type = function(item)
    local text = ""
    if item.category_utf8 == "StackableCurrency" then
        if item.baseType_utf8 and (string.find(item.baseType_utf8,"精煉") or string.find(item.baseType_utf8,"液態")) then
            text = "精煉"
        elseif item.baseType_utf8 and string.find(item.baseType_utf8,"催化劑") then
            text = "催化劑"
        elseif item.baseType_utf8 and string.find(item.baseType_utf8,"精髓") then
            text = "精髓"
        elseif item.baseType_utf8 and (string.find(item.baseType_utf8,"破碎的") or string.find(item.baseType_utf8,"保存良好的") or string.find(item.baseType_utf8,"古老的")) then
            text = "深淵骸骨"
        else
            text = "通貨"
        end
    end
    if item.category_utf8 == "SoulCore" then
        if item.baseType_utf8 and string.find(item.baseType_utf8,"符文") then
            text = "符文"
        elseif item.baseType_utf8 and string.find(item.baseType_utf8,"魔符") then
            text = "魔符"
        else
            text = "靈魂核心"
        end
    end
    return text
end

-- 判断是否不捡
_M.is_do_without_pick_up = function(item, items_info)

    local text = _M.get_item_type(item)
    local item_key = ""
    if text ~= "" then
        item_key = text
    else
        for k, v in pairs(my_game_info.type_conversion) do
            if item.category_utf8 == v then
                item_key = k
                break
            end
        end
    end
    local function split_str(input, sep)
        sep = sep or "|"  -- 默认分隔符是 |
        local result = {}
        for item in string.gmatch(input, "([^"..sep.."]+)") do
            table.insert(result, string.match(item, "^%s*(.-)%s*$"))
        end
        return result
    end
    
    if item_key and item_key ~= "" then
        local item_type_list = {}
        for _, v in ipairs(items_info) do
            if v['類型'] == item_key then
                table.insert(item_type_list,v)
            end
        end
        if item_type_list and next(item_type_list) then
            local not_pick_up_item = nil
            for _, v in ipairs(item_type_list) do
                if v["不撿"] then
                    local item_name_list = split_str(v['基礎類型名'])
                    if v['基礎類型名'] == "全部物品" or (v["名稱"] and v["名稱"] ~= "" and not item.not_identified and _M.table_contains(item_name_list,item.baseType_utf8) and string.find(v["名稱"],item.name_utf8)) or ((not v["名稱"] or v["名稱"] == "") and _M.table_contains(item_name_list,item.baseType_utf8)) then
                        not_pick_up_item = v
                        break
                    end
                end
            end
            if not_pick_up_item then
                return true
            end
        end
    end
    return false
end

-- 物品過濾
_M.match_item = function(item, cfg, index)
    local index = index or nil
    -- _M.dbgp(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    -- _M.dbgp("item.category_utf8: "..item.category_utf8)
    local text = _M.get_item_type(item)
    -- _M.dbgp(type(cfg['類型'].."======================================"))
    if text ~= "" and cfg['類型'] ~= text then
        -- _M.dbgp("類型不匹配1")
        return false
    end
    -- 类型匹配
    -- _M.dbgp(type(cfg['類型']).."======================================")
    -- _M.dbgp(cfg['類型'].."======================================")
    -- _M.dbgp(my_game_info.type_conversion[cfg['類型']].."======================================")
    if not cfg['類型'] or cfg['類型']=="" or item.category_utf8 ~= my_game_info.type_conversion[cfg['類型']] then
        -- _M.dbgp("類型不匹配2")
        return false
    end
    -- 名称匹配
    if cfg['名稱模式'] == 'specific' then
        local name = cfg["名稱"] or ""
        if name and name ~= ""then
            if not string.find(cfg['基礎類型名'],item.baseType_utf8) or not string.find(name,item.name_utf8) then
                -- _M.dbgp("名稱不匹配1")
                return false
            end
        end
        local function split_str(input, sep)
            sep = sep or "|"  -- 默认分隔符是 |
            local result = {}
            for item in string.gmatch(input, "([^"..sep.."]+)") do
                table.insert(result, string.match(item, "^%s*(.-)%s*$"))
            end
            return result
        end
        local item_name_list = split_str(cfg['基礎類型名'])
        if not cfg['基礎類型名'] or cfg['基礎類型名'] == "" or not _M.table_contains(item_name_list,item.baseType_utf8) then  -- string.find(cfg['基礎類型名'],item.baseType_utf8)
            -- _M.dbgp("名稱不匹配2")
            return false
        end
    else
        local name = cfg["名稱"] or ""
        if name and name ~= ""then
            if not item.not_identified and not string.find(name,item.name_utf8) then
                -- _M.dbgp("名稱不匹配3")
                return false
            end
        end
    end
    -- 等级检查
    local level = cfg["等級"]
    local item_type = level.type
    if item.category_utf8 == "Map" then
        local map_level = _M.extract_level(item.baseType_utf8)
        if item_type == "exact" then
            local item_level = level.value
            if map_level < item_level-3 then
                -- _M.dbgp("地图精确等级不匹配1")
                return false
            end 
        else
            local min_level = level.min
            local  max_level = level.max
            if map_level < min_level or map_level > max_level then
                -- _M.dbgp("地图等级不匹配1")
                return false
            end    
        end
    elseif _M.table_contains(item.category_utf8,{'UncutSkillGemStackable', 'UncutReservationGemStackable','UncutSupportGemStackable'}) then 
        local skill_level = _M.extract_level(item.baseType_utf8)
        -- _M.dbgp("skill_level: ",skill_level)
        -- api_Sleep(100000)
        if item_type == "exact" then
            local item_level = level.value
            if skill_level < item_level or skill_level > item_level then
                -- _M.dbgp("宝石精确等级不匹配1")
                return false
            end
        else
            local min_level = level.min
            local max_level = level.max
            if index then
                if item.category == 'UncutSkillGemStackable' then
                    if skill_level < 2 or skill_level > max_level then
                        return false
                    end
                else
                    if skill_level < min_level or skill_level > max_level then
                        -- _M.dbgp("宝石等级不匹配1")
                        return false
                    end 
                end
            else  
                if skill_level < min_level or skill_level > max_level then
                    -- _M.dbgp("宝石等级不匹配1")
                    return false
                end    
            end
        end
    else
        if item_type == "exact" then
            local item_level = level.value
            if item.DemandLevel < item_level then
                -- _M.dbgp("物品精确等级不匹配1")
                return false
            end 
        else
            local min_level = level.min
            local  max_level = level.max
            if item.DemandLevel < min_level or item.DemandLevel > max_level then
                -- _M.dbgp("物品等级不匹配1")
                return false
            end    
        end
    end
    -- 颜色检查
    local color = item.color or -1
    if not cfg['颜色'] or not next(cfg['颜色']) or not _M.table_contains(color,cfg['颜色']) then
        -- _M.dbgp("颜色不匹配1")
        return false
    end
    local quality = cfg["quality"] or nil
    local sockets = cfg["sockets"] or nil
    if quality and quality ~= "" and not item.contaminated then
        if item.quality < tonumber(quality) then
            return false
        end 
    end
    if sockets and sockets ~= ""  and not item.contaminated then
        if item.sockets < tonumber(sockets) then
            return false
        end 
    end
    -- 通货排除
    if item.category_utf8 == "StackableCurrency" and _M.table_contains(item.baseType_utf8,{'黃金',"金幣"}) then
        return false
    end
    return true
end

-- 判断两点距离
_M.get_point_distance = function(x1, y1, x2, y2)
    local x_num = 0
    local y_num = 0
    
    if (x1 > 0 and x2 > 0) or (x1 < 0 and x2 < 0) then
        x_num = (x1 - x2) ^ 2
    elseif (x1 > 0 and x2 < 0) or (x1 < 0 and x2 > 0) then
        x_num = (x1 + x2) ^ 2
    end

    if (y1 > 0 and y2 > 0) or (y1 < 0 and y2 < 0) then
        y_num = (y1 - y2) ^ 2
    elseif (y1 > 0 and y2 < 0) or (y1 < 0 and y2 > 0) then
        y_num = (y1 + y2) ^ 2
    end

    local distance = math.sqrt(x_num + y_num)
    return distance
end

-- 深度拷贝函数（完整版）
_M.deepCopy = function(orig)
    -- 处理非table类型和nil
    if type(orig) ~= "table" then return orig end
    
    -- 循环引用处理表
    local seen = {}
    
    -- 局部递归函数
    local function _copy(obj)
        -- 基础类型直接返回
        if type(obj) ~= "table" then return obj end
        
        -- 如果已经拷贝过则直接返回
        if seen[obj] then return seen[obj] end
        
        -- 创建新table
        local new = {}
        seen[obj] = new  -- 记录已拷贝
        
        -- 拷贝所有字段（包括元表）
        for k, v in pairs(obj) do
            new[_copy(k)] = _copy(v)  -- 递归拷贝key和value
        end
        
        -- 拷贝元表
        return setmetatable(new, _copy(getmetatable(obj)))
    end
    
    return _copy(orig)
end

-- 随机点击屏幕
_M.random_click = function(x, y, w, h)
    local x1 = x + math.random(0, w)
    local y1 = y + math.random(0, h)
    api_ClickScreen(x1, y1, 1)
end

-- 根据名字返回其所在地图
_M.party_pos = function(name,team_info)
     -- 根据成员名称返回其当前地图名称
     for _, m in ipairs(team_info) do
        _M.dbgp(m.name_utf8)
        _M.dbgp(m.current_map_name_utf8)
        if m.name_utf8 == name then
            return m.current_map_name_utf8
        end
    end
    return nil
end

-- biao
_M.has_common_element = function(t1, t2)
    -- 类型检查（当前实现）
    if t1 == nil or t2 == nil or type(t1) ~= "table" or type(t2) ~= "table" then
        return false
    end
    
    -- 优化：如果其中一个表为空，直接返回false
    if #t1 == 0 or #t2 == 0 then
        return false
    end
    
    -- 优化：使用哈希表提高查找效率（对于较大的表）
    local lookup = {}
    for _, v in ipairs(t1) do
        lookup[v] = true
    end
    
    for _, v in ipairs(t2) do
        if lookup[v] then
            return true
        end
    end
    
    return false
end

-- 快速点击背包物品
_M.ctrl_left_click_interface_items = function(target_name, item_info, click_type)
    if not item_info or type(item_info) ~= "table" then
        _M.dbgp("仓库信息无效")
        return false
    end

    for _, actor in ipairs(item_info) do
        -- 更安全的属性访问和条件判断
        local match = actor.baseType_utf8 and 
                     (actor.baseType_utf8 == target_name or 
                      (actor.obj and actor.obj == target_name))
        
        if match then
            -- 添加坐标有效性检查
            local x = (actor.RectSart_x + actor.RectEnd_x) / 2
            local y = (actor.RectSart_y + actor.RectEnd_y) / 2

            -- 支持左键/右键点击
            if click_type == 1 then  
                _M.right_click(x, y)
            else
                _M.ctrl_left_click(x, y)
            end

            return true
        end
    end

    _M.dbgp(("未找到目标对象: %s"):format(target_name))
    return false
end
-- 根据目标点排序最近列表
    
_M.sort_recent_point_list = function(point_list, x, y)
    -- 计算每个点与目标点的距离，并存储到临时表
    local points_with_distance = {}
    for _, point in ipairs(point_list) do
        local dx = point.x - x
        local dy = point.y - y
        local distance = math.sqrt(dx * dx + dy * dy)
        table.insert(points_with_distance, {
            point = point,
            distance = distance
        })
    end


    -- 按距离从小到大排序
    table.sort(points_with_distance, function(a, b)
        return a.distance < b.distance
    end)


    -- 提取排序后的坐标点（去掉临时存储的距离）
    local sorted_points = {}
    for _, item in ipairs(points_with_distance) do
        table.insert(sorted_points, item.point)
    end


    return sorted_points
end

-- 获取指定text的物品排序
_M.get_sorted_obj = function(text, range_info, player_info)
    -- 1. 检查玩家信息
    if not player_info then
        _M.dbgp("错误: 无法获取玩家位置信息")
        return nil
    end
    
    -- 2. 缓存玩家位置（有效期1秒）
    local current_time = os.time()
    if not _M._last_player_pos or current_time - (_M._last_pos_time or 0) > 1.0 then
        _M._last_player_pos = {grid_x = player_info.grid_x, grid_y = player_info.grid_y}
        _M._last_pos_time = current_time
    end
    local px, py = _M._last_player_pos.grid_x, _M._last_player_pos.grid_y
    _M.dbgp(string.format("排序基准点 - X:%.2f, Y:%.2f", px, py))
    
    -- 3. 定义筛选函数
    local function is_match(actor)
        if type(text) == "string" then
            if string.find(actor.baseType_utf8 or "", text) ~= nil or string.find(actor.name_utf8 or "", text) ~= nil then
                return true
            else
                return false
            end
        elseif type(text) == "table" then
            for _, name in ipairs(text) do
                if (name == actor.baseType_utf8) or (name == actor.name_utf8) then
                    return true
                end
            end
            return false
        elseif type(text) == "number" then
            return text == actor.type
        end
        return false
    end
    
    -- 4. 单次遍历同时筛选和计算距离
    local matched = {}
    for _, actor in ipairs(range_info) do
        if is_match(actor) and actor.grid_x and actor.grid_y then
            local dx = actor.grid_x - px
            local dy = actor.grid_y - py
            table.insert(matched, {dist = dx*dx + dy*dy, actor = actor})
        end
    end
    
    -- 5. 优化排序（直接使用预计算的平方距离）
    table.sort(matched, function(a, b)
        return a.dist < b.dist
    end)
    
    -- 提取排序后的actor列表
    local result = {}
    for _, item in ipairs(matched) do
        table.insert(result, item.actor)
    end
    
    return result
end

-- 根据距离判断周围boss
_M.is_have_boss_distance = function(range_info,player_info,boss_list,dis)
    dis = dis or 100  -- 默认距离100
    
    if not range_info or not player_info then
        return false
    end
    
    for _, monster in ipairs(range_info) do
        -- 检查多里亞尼的特殊情况
        if monster.name_utf8 == '多里亞尼' and monster.hasLineOfSight 
           and monster.life > 0 and monster.stateMachineList 
           and monster.stateMachineList['boss_life_bar'] == 0 then
            return false
        end
        if monster.name_utf8 == '白之亞瑪' and  monster.life > 0 
            and monster.stateMachineList and monster.stateMachineList['dead'] == 1 then
            return false
        end
        
        -- 计算距离平方(优化性能，避免math.sqrt)
        local dx = monster.grid_x - player_info.grid_x
        local dy = monster.grid_y - player_info.grid_y
        local distance_sq = dx*dx + dy*dy
        local within_distance = distance_sq <= (dis * dis)
        
        -- 检查稀有度为3的怪物
        if monster.name_utf8 ~= '' and monster.rarity == 3 
           and monster.life > 0 and not monster.is_friendly 
           and within_distance 
           and not _M.table_contains(monster.name_utf8, my_game_info.not_attact_mons_CN_name)
           and not string.find(monster.name_utf8, "神殿")
           and not _M.table_contains(monster.name_utf8, my_game_info.not_attact_mons_path_name)
           and monster.isActive then
            return true
        end
        
        -- 检查boss列表中的怪物
        if monster.name_utf8 ~= '' and _M.table_contains(monster.name_utf8, boss_list)
           and monster.life > 0 and not monster.is_friendly 
           and within_distance and monster.hasLineOfSight
           and not _M.table_contains(monster.name_utf8, my_game_info.not_attact_mons_CN_name)
           and not string.find(monster.name_utf8, "神殿")
           and not _M.table_contains(monster.name_utf8, my_game_info.not_attact_mons_path_name)
           and monster.isActive then
            return true
        end
    end
    return false
end

-- 获取队伍信息
_M.get_team_info = function(team_info ,config ,player_info, index)
    local team_members = team_info
    local plot_config = config["全局設置"]["大带小设置"] or {}
    local captain = plot_config["队长名"]
    local leader = plot_config["大号名称"]
    local my_profession = '未知' -- 初始化您的職業为未知
    if player_info and team_members then
        for role, name_data in pairs(team_members) do
            if type(name_data) == "table" then
                -- 处理表类型（如小號名）
                for _, name in ipairs(name_data) do
                    if player_info.name_utf8 and name == player_info.name_utf8 then
                        my_profession = role
                        break
                    end
                end
            else
                -- 处理字符串类型
                if player_info.name_utf8 and name_data == player_info.name_utf8 then
                    my_profession = role
                    break
                end
            end
        end
    end
    if index == 0 then
        return captain , leader , my_profession
    elseif index == 2 then
        return my_profession
    elseif index == 3 then
        return leader
    elseif index == 4 then
        return captain
    elseif index == 5 then
        -- 获取小號信息，排除线路、队长和大号
        local small_accounts_values = {}
        for role, name in pairs(team_members) do
            if role ~= '队长名' and role ~= '大号名称' then
                table.insert(small_accounts_values, name)
            end
        end
        return small_accounts_values  -- 返回小號值列表
    elseif index == 6 then
        -- 获取小號信息，排除线路和大号
        local small_accounts_values = {}
        for role, name in pairs(team_members) do
            if role ~= '大号名称' then
                table.insert(small_accounts_values, name)
            end
        end
        return small_accounts_values  -- 返回小號值列表
    end
end
        
-- 查询本地任务信息
--- @param tasks_data table 任务数据表，结构为 {[任务名] = {任务详情}}
--- @param text string 要查询的任务名称
--- @return table|nil 返回包含任务详细信息的表，结构为：
_M.get_task_info = function(tasks_data,text)
    if tasks_data[text] then
        local task_data = tasks_data[text]
        return {
            task_name = text,
            map_name = task_data.map_name or nil,
            interaction_object = task_data.interaction_object or nil,
            boss_name = task_data.Boss or nil,
            grid_x = task_data.grid_x or nil,
            grid_y = task_data.grid_y or nil,
            special_map_point = task_data.special_map_point or nil,
            interaction_object_map_name = task_data.interaction_object_map_name or nil,
            index = task_data.index  -- 仅在需要时计算索引
        }
    end
    
    return {}
end

-- 死循环长时间长按文本
_M.while_click = function(UI_info,text ,mate, range_info,is_leader)
    local time = api_GetTickCount64()  -- 点击计时器
    local point = _M.find_text({UI_info = UI_info, text = text, min_x=0 ,click = 1,refresh = true,position = 3})
    if not point or not next(point) then
        return
    end
    api_ClickScreen(_M.toInt(point[1]) ,_M.toInt(point[2]), 3)
    while true do
        range_info = Actors:Update()
        if _M.is_have_mos({range_info = range_info , player_info = mate ,dis = 160}) and is_leader then
            _M.dbgp("发现怪物")
            break
        end
        if api_GetTickCount64() - time >= 30 * 1000 then
            break
        end
        if not _M.find_text({UI_info = UI_info, text = text,max_y = 690 ,max_x = 1140,min_y = 220,refresh = true}) then
            break
        end
    end
    api_ClickScreen(_M.toInt(point[1]) ,_M.toInt(point[2]), 4)
end

-- 查询BD信息
_M.get_BD_info = function(...)
    local data = BD_data 
    local args = {...}

    if #args > 0 then
        -- 动态访问任务数据
        for _, arg in ipairs(args) do
            if data[arg] then
                data = data[arg]  -- 逐层访问
            else
                _M.dbgp("没有该层")
                return nil  -- 如果某个参数不存在，返回 nil
            end
        end
        return data  -- 返回最终访问到的数据
    end
    
    return data
    
end

-- 根据小队名返回文本位置
_M.get_member_name_according = function(UI_info, text, min_x, min_y, max_x, max_y)
    -- Default parameter values
    min_x = min_x or 75
    min_y = min_y or 0
    max_x = max_x or 400
    max_y = max_y or 666

    if UI_info and #UI_info > 0 then
        for _, actor in ipairs(UI_info) do
            if min_x <= actor.left and actor.left <= max_x and 
               min_y <= actor.top and actor.top <= max_y and actor.text_utf8 == text then
                -- Calculate center position
                local center_x = (actor.left + actor.right) / 2
                local center_y = (actor.top + actor.bottom) / 2
                return center_x, center_y  -- Return coordinates if found
            end
        end
        return 0, 0  -- No matching actor found in the specified area
    else
        return 0, 0  -- No actors found at all
    end
end

_M.move_towards = function(start, end_pos, speed)
    local dx = end_pos[1] - start[1]
    local dy = end_pos[2] - start[2]

    local distance = math.sqrt(dx^2 + dy^2)

    local dx_normalized, dy_normalized
    if distance > 0 then
        dx_normalized = dx / distance * speed
        dy_normalized = dy / distance * speed
    else
        dx_normalized = 0
        dy_normalized = 0
    end
    
    -- Calculate new coordinates
    local new_x = start[1] + dx_normalized
    local new_y = start[2] + dy_normalized
    
    return {new_x, new_y}
end
_M.check_task_map_without = function()
    local task = api_GetQuestList(0)
    local task_maps = my_game_info.task_maps
    local map_name = nil
    if task then
        -- 创建一个表来存储未完成的任务名称
        local completed_tasks = {}
        for _, k in ipairs(task) do
            if k.SubQuestState == "任務完成" then
                completed_tasks[k.MainQuestName] = true
            end
        end
        local all_finished_tasks = {}  -- 用于存储所有已完成的任务
        
        for _, map_info in ipairs(task_maps) do
            map_name = map_info[1]
            local tasks = map_info[2]
            
            -- 检查已完成的任务
            local finished_tasks = {}
            local unfinished_tasks1 = {}
            
            for _, task_name in ipairs(tasks) do
                if completed_tasks[task_name] then
                    table.insert(finished_tasks, task_name)
                else
                    table.insert(unfinished_tasks1, task_name)
                end
            end
            
            if #finished_tasks > 0 then
                for _, task_name in ipairs(finished_tasks) do
                    table.insert(all_finished_tasks, task_name)
                end
            end
            
            if #unfinished_tasks1 > 0 then
                return map_name, all_finished_tasks  -- 返回元组 (map_name, all_finished_tasks)
            end
        end
        
        return map_name, all_finished_tasks  -- 如果没有未完成的任务，返回 (nil, all_finished_tasks)
    else
        return nil, {}  -- 如果没有任务，返回 (nil, {})
    end
end
-- 获取传送点屏幕坐标
_M.waypoint_pos = function(area, waypoint)
    for _, i in ipairs(waypoint) do
        if i.name == area then
            return {(i.left + i.right) / 2, (i.top + i.bottom) / 2}
        end
    end
    return {0, 0}
end
-- 其他可能用到的API
_M.get_current_time = function() return api_GetTickCount64() end

-- 拆分字符串
_M.split_string = function(type_str,delimiter)
    -- local dark_gold_plauqe = {}
    -- local ordinary = {}
    local function split_by_pipe(input)
        local result = {}
        for item in string.gmatch(input, "([^"..delimiter.."]+)") do
            table.insert(result, string.match(item, "^%s*(.-)%s*$"))
        end
        return result
    end
    if string.find(type_str, delimiter) then
        return split_by_pipe(type_str)  -- 返回拆分的列表
    else
        return {type_str}              -- 返回单元素列表
    end
end

-- 获取创建角色坐标
_M.role_point = function(role_name)
    local role_list = my_game_info.role_matching
    if role_list then
        for k, v in pairs(role_list) do
            if role_name == k then
                return v
            end
        end
    end
    return nil
end
-- 生成一个随机字母字符串
_M.generate_random_string = function( length)
    local letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local result = ""
    for i = 1, length do
        local random_index = math.random(1, #letters)
        result = result .. string.sub(letters, random_index, random_index)
    end
    return result
end
-- 随机生成获取角色名称
_M.get_name_text = function()
    local list_of_names = {
        "John",
        "George",
        "Thomas",
        "Taylor",
        "Kendrick",
        "Nicki",
        "Dua",
        "Selena",
        "Lady",
        "Miley",
        "Jennifer",
        "Kanye",
        "Cardi",
        "The",
        "Shawn",
        "Rihanna",
        "Justin",
        "Demi",
        "Jennifer",
        "Swift",
        "Lamar",
        "Minaj",
        "Lipa",
        "Gomez",
        "Gaga",
        "Cyrus",
        "Lopez",
        "West",
        "Kendrick",
        "Weeknd",
        "Mendes",
        "Lady",
        "Bieber",
        "Lovato",
        "Hudson",
        "George",
        "Jennifer",
        "Drake",
        "Travis",
        "Harry",
        "Adele",
        "Katy",
        "Selena",
        "Marc",
        "John",
        "Drake",
        "Lamar",
        "Nicki",
        "Dua",
        "Selena",
        "Gaga",
        "Miley",
        "Jennifer",
        "Washington",
        "Washington",
        "Bryson",
        "Scott",
        "Styles",
        "Bruno",
        "Perry",
        "Gomez",
        "Anthony",
        "Legend",
        "Kendrick",
        "Drake",
        "Minaj",
        "Lipa",
        "Gomez",
        "Katy",
        "Cyrus",
        "Lopez",
        "Thomas",
        "Bill",
        "Knowles",
        "Ariana",
        "Tiller",
        "Khalid",
        "Camila",
        "Mars",
        "Taylor",
        "Ariana",
        "Shakira",
        "Mary",
        "The",
        "Lamar",
        "Bryson",
        "Travis",
        "Harry",
        "Adele",
        "Perry",
        "Selena",
        "Marc",
        "John",
        "Jay",
        "Grande",
        "Cardi",
        "The",
        "Cabello",
        "Rihanna",
        "Swift",
        "Grande",
        "Jennifer",
        "Tiller",
        "Scott",
        "Styles",
        "Bruno",
        "Taylor",
        "Gomez",
        "Anthony",
        "Legend",
        "Jennifer",
        "Weeknd",
        "Shawn",
        "Justin",
        "Demi",
        "Hudson",
        "Blige",
        "Khalid",
        "Camila",
        "Mars",
        "Swift",
        "Ariana",
        "Shakira",
        "Mary",
        "Kanye",
        "Mendes",
        "Bieber",
        "Lovato",
        "Jay",
        "Cabello",
        "Grande",
        "Knowles",
        "Blige",
        "West",
        "Bill",
        "Abraham",
        "Mark",
        "Michael",
        "Tom",
        "Robert",
        "Brad",
        "Will",
        "Lin",
        "Wale",
        "Lincoln",
        "Edison",
        "Zuckerberg",
        "Jordan",
        "Hanks",
        "Pitt",
        "Smith",
        "Manuel",
        "Dre",
        "Kelly",
        "Kennedy",
        "Bush",
        "Henry",
        "Warren",
        "Serena",
        "Meryl",
        "Niro",
        "Denzel",
        "Miranda",
        "Snoop",
        "Tupac",
        "Martin",
        "Barack",
        "Ford",
        "Buffett",
        "Williams",
        "Streep",
        "Morgan",
        "Aniston",
        "Beyoncé",
        "Sheeran",
        "Dogg",
        "Shakur",
        "Luther",
        "Obama",
        "Elon",
        "LeBron",
        "Leonardo",
        "Freeman",
        "Matt",
        "Viola",
        "Ice",
        "Jefferson",
        "King",
        "Donald",
        "Gates",
        "Musk",
        "James",
        "DiCaprio",
        "Johnny",
        "Damon",
        "Davis",
        "Cube",
        "Notorious",
        "Franklin",
        "Trump",
        "Steve",
        "Jeff",
        "Kobe",
        "Depp",
        "Scarlett",
        "Octavia",
        "Billie",
        "Eminem",
        "BIG",
        "Cole",
        "Ronald",
        "Joe",
        "Jobs",
        "Bezos",
        "Bryant",
        "Lawrence",
        "Angelina",
        "Johansson",
        "Spencer",
        "Eilish",
        "Roosevelt",
        "Reagan",
        "Biden",
        "Jolie",
        "Clinton"
    }
    local sj = _M.generate_random_string(math.random(1, 3))
    local index = math.random(1, 3)
    local name_text

    if index == 1 then
        name_text = sj .. list_of_names[math.random(1, #list_of_names)] .. list_of_names[math.random(1, #list_of_names)]
    elseif index == 2 then
        name_text = list_of_names[math.random(1, #list_of_names)] .. sj .. list_of_names[math.random(1, #list_of_names)]
    elseif index == 3 then
        name_text = list_of_names[math.random(1, #list_of_names)] .. list_of_names[math.random(1, #list_of_names)] .. sj
    end
    return name_text
end
-- 将字符串转换为Lua表格式
_M.parse_data_string = function(data_str)
    -- 输入: 'user_name': player_info.name_utf8, 'map_name': task.map_name, 'task_name': task.task_name, 'task_index': task.index
    -- 输出: {user_name = "player_info.name_utf8", map_name = "task.map_name", task_name = "task.task_name", task_index = "task.index"}
    local result = {}
    
    -- 使用正则表达式匹配键值对
    for key, value in data_str:gmatch("([^=,]+)=([^,]+)") do
        -- 去除键和值的前后空格
        key = key:gsub("^%s*(.-)%s*$", "%1")
        value = value:gsub("^%s*(.-)%s*$", "%1")
        result[key] = value
    end
    
    return result
end

-- 直接按位置提取（移除时间检查）
_M.direct_parse_log_line = function(line)
    -- 提取时间部分（前19个字符）
    local date_time = line:sub(1, 19)
    
    -- 将日期时间转换为毫秒
    local year, month, day, hour, minute, second = date_time:match("^(%d+)/(%d+)/(%d+)%s+(%d+):(%d+):(%d+)$")
    
    if not (year and month and day and hour and minute and second) then
        return nil
    end
    
    -- 创建时间对象
    local time_table = {
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(minute),
        sec = tonumber(second)
    }
    
    local log_timestamp = os.time(time_table) * 1000  -- 转换为毫秒
    
    -- 找到%的位置
    local percent_pos = line:find("%%")
    if percent_pos then
        -- 找到冒号的位置
        local colon_pos = line:find(":", percent_pos)
        if colon_pos then
            -- 提取名称（%和:之间）
            local name = line:sub(percent_pos + 1, colon_pos - 1)
            -- 提取数据（:之后）
            local data = line:sub(colon_pos + 2)  -- +2 跳过冒号和空格
            
            -- 解析数据字符串为Lua表
            local parsed_data = _M.parse_data_string(data)
            
            return {
                timestamp = log_timestamp,
                name = name,
                data = parsed_data,
            }
        end
    end
    
    return nil
end

-- 读取文件的倒数 n 行（返回按从旧到新的顺序，即靠前的是较早的行）
_M.read_tail_lines= function(file_path, n, chunk_size)
    chunk_size = chunk_size or 8192
    local f = io.open(file_path, "rb")
    if not f then return nil, "无法打开文件: " .. tostring(file_path) end

    local size = f:seek("end")
    local pos = size
    local chunks = {}
    local nl_cnt = 0

    -- 从文件末尾向前读，直到累计到 n 个换行或读到文件开头
    while pos > 0 and nl_cnt <= n do
        local r = math.min(chunk_size, pos)
        f:seek("set", pos - r)
        local chunk = f:read(r)
        pos = pos - r
        table.insert(chunks, 1, chunk) -- 插入到前面，保持正确顺序
        
        -- 计算换行符数量
        local _, c = chunk:gsub("\n", "")
        nl_cnt = nl_cnt + c
    end
    f:close()

    -- 拼接所有块
    local buf = table.concat(chunks)
    
    -- 处理可能被截断的第一行（不完整的行）
    local start_idx = 1
    if pos > 0 then -- 如果没读到文件开头，说明第一行可能不完整
        local first_newline = buf:find("\n")
        if first_newline then
            start_idx = first_newline + 1
        end
    end

    -- 解析所有行
    local all_lines = {}
    local remaining = buf:sub(start_idx)
    
    for line in remaining:gmatch("([^\r\n]*)\r?\n?") do
        if line ~= "" then
            all_lines[#all_lines + 1] = line
        end
    end

    -- 如果最后一行没有换行符，需要单独处理
    if buf:sub(-1) ~= "\n" and buf:sub(-1) ~= "\r" and #all_lines > 0 then
        -- 最后一行是有效的，但可能已经被上面的模式匹配到了
    end

    -- 只保留最后 n 行
    local start_idx = math.max(#all_lines - n + 1, 1)
    local tail = {}
    for i = start_idx, #all_lines do
        tail[#tail + 1] = all_lines[i]
    end
    
    return tail
end

-- 只处理"倒数 last_n_lines 到文件末行"的内容
-- file_path: 日志文件
-- max_age_ms: 允许的最大时间窗（毫秒）
-- last_n_lines: 仅扫描的尾部行数（默认 3000，可按需调整）
_M.process_recent_logs_unique= function(file_path, max_age_ms, last_n_lines)
    last_n_lines = last_n_lines or 3000

    local lines, err = _M.read_tail_lines(file_path, last_n_lines)
    if not lines then
        print(err)
        return {}
    end

    -- 反转：让最新的行在前面，便于遇到过期时间就提前返回
    local reversed_lines = {}
    for i = 1, #lines do
        reversed_lines[i] = lines[#lines - i + 1]
    end
    local latest_data = {}  -- { name = parsed_data }
    local seen_names  = {}  -- { name = latest_timestamp }
    local current_ts  = os.time() * 1000
    for _, line in ipairs(reversed_lines) do
        
        -- 快速校验时间戳格式：YYYY/MM/DD HH:MM:SS
        local date_time = line:sub(1, 19)
        local y, m, d, H, M, S = date_time:match("^(%d+)/(%d+)/(%d+)%s+(%d+):(%d+):(%d+)$")
        if not (y and m and d and H and M and S) then
            
            goto continue
        end

        local tt = {
            year  = tonumber(y),
            month = tonumber(m),
            day   = tonumber(d),
            hour  = tonumber(H),
            min   = tonumber(M),
            sec   = tonumber(S),
        }
        local log_ts = os.time(tt) * 1000

        -- 超过时间窗口就可以提前结束（因为已是从新到旧在扫）
        if current_ts - log_ts > max_age_ms then
            return latest_data
        end
        
        -- 业务解析（保持与你原来的 direct_parse_log_line 一致）
        local parsed = _M.direct_parse_log_line(line)
        if parsed then
            local name      = parsed.name
            local data      = parsed.data
            local timestamp = parsed.timestamp

            if not seen_names[name] or timestamp > seen_names[name] then
                seen_names[name] = timestamp
                latest_data[name] = data
            end
        end

        ::continue::
    end

    return latest_data
end
-- -- 记录调用时间的函数
-- _M.record_call_time = function(index,)
--     -- local current_time = os.time()
--     local recorded = false
    
--     -- 首次调用或满足间隔条件时记录
--     if last_record_time == nil then
--         if index == 1 then
--             _M.click_keyboard()
--         end
--         last_record_time = api_GetTickCount64()
--         recorded = true
--     elseif(api_GetTickCount64() - last_record_time >= INTERVAL) then
--         last_record_time = api_GetTickCount64()
--         recorded = true
--     end
    
--     return recorded
-- end



return _M
