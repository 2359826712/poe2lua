local _M = {}  -- 主接口表
local json = require 'json'
local my_game_info = require 'my_game_info'

--- 计算玩家与目标点的距离
_M.point_distance = function(x, y, ac)
    -- 确定玩家坐标
    local player_x, player_y
    -- 如果 ac 是 table 类型且有 x,y 字段
    if type(ac) == "table" then
        player_x = ac[1]
        player_y = ac[2]
    else
        player_x = ac.grid_x
        player_y = ac.grid_y
    end
    -- 计算距离
    local dx = x - player_x
    local dy = y - player_y
    
    local distance = math.sqrt(dx*dx + dy*dy)

    -- print(string.format("[结果] 距离: %.2f (%.1f,%.1f)->(%.1f,%.1f)", 
    -- distance, player_x, player_y, x, y))

    return distance
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
        position = 0
    }
    -- 合并传入参数和默认值
    for k, v in pairs(params) do
        defaults[k] = v
    end
    if (not defaults.UI_info) or #defaults.UI_info == 0 then
        print("没有找到UI信息")
        return false
    end
    if defaults.UI_info then
        for _, actor in ipairs(defaults.UI_info) do
            if defaults.min_x <= actor.left and actor.left <= defaults.max_x and defaults.min_y <= actor.top and actor.top <= defaults.max_y then
                local shouldProcess = true
                local function text_data(text)
                    if defaults.match == 2 then
                        for _,v in ipairs(defaults.text) do
                            if string.find(actor.text_utf8, text) then
                                return true
                            end
                        end
                    else
                        for _,v in ipairs(defaults.text) do
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
                if shouldProcess  then
                    local center_x = (actor.left + actor.right) / 2
                    local center_y = (actor.top + actor.bottom) / 2
                    local x, y = center_x, center_y
                    if defaults.click == 1 then
                        api_ClickScreen(math.floor(x + defaults.add_x), math.floor(y + defaults.add_y),0)
                    elseif defaults.click == 2 then
                        api_ClickScreen(math.floor(x + defaults.add_x), math.floor(y + defaults.add_y),1)
                    elseif defaults.click == 3 then
                        local hold_time = 8
                        api_ClickScreen(math.floor(x + defaults.add_x), math.floor(y + defaults.add_y),3)
                        api_Sleep(hold_time * 1000)
                        api_ClickScreen(math.floor(x + defaults.add_x), math.floor(y + defaults.add_y),4)
                    elseif defaults.click == 4 then
                        _M.ctrl_left_click(math.floor(x + defaults.add_x), math.floor(y + defaults.add_y))
                    elseif defaults.click == 5 then
                        _M.ctrl_right_click(math.floor(x + defaults.add_x), math.floor(y + defaults.add_y))
                    end
                    if defaults.position == 1 then
                        return {actor.left, actor.top, actor.right, actor.bottom}
                    elseif defaults.position == 2 then
                        return actor
                    elseif defaults.position == 3 then
                        return {math.floor(x + defaults.add_x), math.floor(y + defaults.add_y)}
                    end
                    return true
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


--- 检查是否存在符合条件的怪物
-- @param args 参数表，包含以下可选字段：
--   mos: 怪物列表
--   player_info: 玩家信息(必须包含grid_x/grid_y坐标)
--   dis: 检测距离(默认180)
--   not_sight: 是否忽略视野(1表示忽略)
--   stuck_monsters: 被卡住的怪物ID表
--   not_attack_mos: 不攻击的怪物列表
--   is_active: 是否活跃状态
-- @return boolean 如果存在符合条件的怪物返回true，否则false
-- @throws 如果距离参数dis不是正数会抛出错误
_M.is_have_mos = function(args)
    -- 参数默认值与校验
    local params = {
        mos = nil,
        player_info = nil,
        dis = 180,
        not_sight = nil,
        stuck_monsters = nil,
        not_attack_mos = nil,
        is_active = nil
    }
    
    -- 合并传入参数
    for k, v in pairs(args) do
        if params[k] ~= nil then  -- 只接受预定义的参数
            params[k] = v
        end
    end
    -- 参数默认值与校验
    params.dis = params.dis or 180
    if type(params.dis) ~= "number" or params.dis <= 0 then
        error("距离参数dis必须是正数")
    end
    player_info = params.player_info
    -- 快速失败检查
    if not params.mos or not player_info or not player_info.grid_x or not player_info.grid_y then
        return false
    end

    -- 预处理常量
    local check_sight = params.not_sight == 1
    local squared_dis = params.dis * params.dis  -- 预先计算平方距离避免循环内重复计算

    -- 怪物检查主逻辑
    for _, monster in ipairs(params.mos) do
        -- 快速跳过不符合基本条件的怪物
        if monster.type == 1                        -- 是怪物类型
           and monster.is_selectable                -- 可选中
           and not monster.is_friendly              -- 非友方
           and monster.life and monster.life > 0    -- 存活
           and monster.grid_x and monster.grid_y    -- 有有效坐标
           and monster.name_utf8 then              -- 有名称

            -- 攻击资格检查 (按性能消耗从低到高排序)
            local should_attack = true
            
            -- 1. 检查卡住状态 (哈希查找O(1))
            if should_attack and params.stuck_monsters and params.stuck_monsters[monster.id] then
                should_attack = false
            end

            -- 2. 检查距离 (平方距离比较避免开方)
            if should_attack then
                local dx = monster.grid_x - player_info.grid_x
                local dy = monster.grid_y - player_info.grid_y
                local distance_sq = dx*dx + dy*dy
                
                if distance_sq <= squared_dis then
                    -- 3. 最后检查视野 (可能涉及射线检测等昂贵操作)
                    if not check_sight or monster.hasLineOfSight then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- 是否有Boss
_M.is_have_mos_boss = function(mos, boss_list)
    if not mos or not boss_list then
        return false
    end

    BOSS_WHITELIST = {'多里亞尼'}
    MOB_BLACKLIST = {"惡魔", '複製體', "隱形", "複製之躰"}
    rarity_list = {2,3}

    for _, monster in ipairs(mos) do
        if monster.is_selectable and not monster.is_friendly and monster.life > 0 and rarity_list[monster.rarity] and monster.name_utf8 then
            -- 通用Boss判断
            if not table.contains(MOB_BLACKLIST, monster.name_utf8) and 
                monster.isActive and 
                (table.contains(boss_list, monster.name_utf8) or monster.life > 0) then
                return true
            end
        end
    end
    -- print("没有Boss")
    return false
end



--- 模拟键盘按键操作
-- @param click_str string 按键字符串（如"A", "Enter"等）
-- @param[opt] click_type number 按键类型：0=单击, 1=按下, 2=抬起
_M.click_keyboard=function(click_str, click_type)
    -- 参数默认值处理
    click_type = click_type or 2  -- 0=按下, 1=抬起, 2=按下并抬起
    local key_code = my_game_info.ascii_dict[click_str:lower()]
    if click_type == 0 then
        api_Keyboard(key_code,2)
    elseif click_type == 1 then
        api_Keyboard(key_code,0)
    elseif click_type == 2 then
        api_Keyboard(key_code,1)
    end
end


-- 左ctrl+左键
_M.ctrl_left_click = function(x, y)
    if x and y then
        _M.click_keyboard('ctrl',1)  -- 使用正确的按键代码
        api_Sleep(100)  -- 0.1秒 = 100毫秒
        api_ClickScreen(math.floor(x), math.floor(y),1) -- 使用click方法模拟左键点击
        api_Sleep(100)
        _M.click_keyboard('ctrl',2)  -- 使用正确的按键代码
    end
end


-- 左ctrl+右键
_M.ctrl_right_click = function(x, y)
    if x and y then
        _M.click_keyboard('ctrl',1)  -- 使用正确的按键代码
        api_Sleep(100)
        api_ClickScreen(math.floor(x), math.floor(y),2)  -- 使用click方法模拟右键点击
        api_Sleep(100)
        _M.click_keyboard('ctrl',2)  -- 使用正确的按键代码
    end
end

-- 其他可能用到的API
_M.get_current_time = function()
    return os.time()
end

return _M