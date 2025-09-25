package.path = package.path .. ';./path/to/module/?.lua'

-- 根据otherworld.json实现的完整行为树系统
package.path = package.path .. ';lualib/?.lua'
local behavior_tree = require 'behavior3.behavior_tree'
local bret = require 'behavior3.behavior_ret'
-- 加载基础节点类型
local base_nodes = require 'behavior3.sample_process'
local my_game_info = require 'script/my_game_info'
local main_task = require 'script/main_task'

local script_dir = api_GetExecutablePath()
-- api_Log(script_dir)
local json_path = script_dir .."\\config.json"
local user_info_path = script_dir .."\\config.ini"
local json = require 'script.lualib.json'

local poe2_api = require "script/poe2api"
api_Log("清除 poe2api 模块的缓存")
package.loaded['poe2api'] = nil
-- 自定义节点实现
local custom_nodes = {
    -- 获取用户配置信息
    Get_User_Config_Info = {
        run = function(self, env)
            poe2_api.print_log("获取用户配置信息...")
            local start_time = api_GetTickCount64() -- 开始时间
            if not env.user_config then
                local config = poe2_api.load_config(json_path)
                local user_info = poe2_api.load_ini(user_info_path)["UserInfo"]
                -- 玩法優先級
                local map_priority = config["刷圖設置"]["玩法優先級"]
                local map_sorted_items_sort = poe2_api.sort_map_by_key(map_priority)
                poe2_api.printTable(map_sorted_items_sort)
                if map_priority['是否開啟'] then
                    env.sorted_map = map_sorted_items_sort
                else
                    env.sorted_map = nil
                end
                poe2_api.dbgp("1111111111...")
                -- # 碑牌順序
                local play_priority = config["刷圖設置"]["碑牌優先級"]
                local sorted_keys = poe2_api.sort_map_by_key(play_priority)
                local result = {}
                for _, key in ipairs(sorted_keys) do
                    if my_game_info.map_type[key] then
                        table.insert(result, my_game_info.map_type[key])
                    end
                end         
                env.user_config = config
                env.user_info = user_info
                env.stone_order = result
                env.is_insert_stone = play_priority["是否開啟"]

                -- 检查是否需要售卖地图
                env.need_sale_map = config["全局設置"]["刷图通用設置"]["自动清理地图(个人仓库)"]
                
                local item_filters = config["物品過濾"] or {}  -- 获取物品过滤配置数组
                -- 两种独立的分类表
                local item_config_by_type = {}      -- 按【類型】分类
                local item_config_by_base_type = {} -- 按【基礎類型名】分类

                for _, filter in ipairs(item_filters) do
                    if not filter["不撿"] then
                        -- ========== 按【類型】分类 ==========
                        local item_type = filter["類型"] or "未分类"
                        if not item_config_by_type[item_type] then
                            item_config_by_type[item_type] = {}
                        end
                        table.insert(item_config_by_type[item_type], filter)  -- 直接引用原数据

                        -- ========== 按【基礎類型名】分类 ==========
                        local base_type = filter["基礎類型名"] or "全部物品"
                        if not item_config_by_base_type[base_type] then
                            item_config_by_base_type[base_type] = {}
                        end
                        table.insert(item_config_by_base_type[base_type], filter)  -- 直接引用原数据
                    end
                end

                env.item_config_name = item_config_by_base_type
                env.item_config_type = item_config_by_type

                -- 滴注操作
                local map_cfg = config['刷圖設置'] or {}
                poe2_api.process_void_maps(map_cfg)
                env.dist_ls = config["刷圖設置"]['異界地圖索引']["涂油设置"] or {}
                -- 更新地图相关设置（添加空值保护）
                env.user_map = (config["刷圖設置"] or {})["地圖鑰匙"] or ""
                -- poe2_api.printTable(env.user_map)
                -- api_Sleep(100000)
                env.not_use_map = (config['刷圖設置'] or {})["不打地圖詞綴"] or {}
                env.priority_map = (config["刷圖設置"] or {})["優先打地圖詞綴"] or {}
                env.not_enter_map = (config["刷圖設置"] or {})["不打地圖名"] or {}

                -- 处理怪物躲避设置（添加空值保护）
                local global_settings = config["全局設置"] or {}
                local common_settings = global_settings["刷图通用設置"] or {}
                local monster_avoid = common_settings["怪物近距離躲避"] or {}

                env.space = monster_avoid["是否開啟"] or false
                env.space_time = monster_avoid["閾值"] or 0
                env.space_config = monster_avoid

                local space_monster = {}

                -- 检查每种怪物类型是否存在，不存在则默认为false
                if monster_avoid["白"] then
                    table.insert(space_monster, 0)
                end
                if monster_avoid["藍"] then
                    table.insert(space_monster, 1)
                end
                if monster_avoid["黃"] then
                    table.insert(space_monster, 2)
                end
                if monster_avoid["Boss"] then
                    table.insert(space_monster, 3)
                end

                env.space_monster = space_monster

                env.is_bird = env.user_config["全局設置"]["刷图通用設置"]["是否骑鸟"] or false

                -- 处理保护设置
                local protection_cfg = config["全局設置"]["保護設置"] or {}
                
                -- 解析保护配置的辅助函数
                local function parse_protection(item_cfg)
                    item_cfg = item_cfg or {}
                    local enable_flag = item_cfg["是否開啟"]
                    
                    -- 处理启用标志
                    local enabled
                    if type(enable_flag) == "boolean" then
                        enabled = enable_flag
                    elseif type(enable_flag) == "string" then
                        enabled = (enable_flag:lower():gsub("%s+", "") == "true" or 
                                enable_flag == "1" or 
                                enable_flag:lower() == "yes")
                    else
                        enabled = false
                    end
                    
                    -- 处理数值
                    local function parse_number(value, default)
                        if value == nil then return default end
                        local num = tonumber(value)
                        return num or default
                    end
                    
                    return {
                        enable = enabled,
                        threshold = parse_number(item_cfg["閾值"], 0),
                        interval = parse_number(item_cfg["使用間隔"], 0)
                    }
                end
                
                -- 解析保护设置
                local protection_settings = {
                    health_recovery = parse_protection(protection_cfg["血少回血"]),
                    mana_recovery = parse_protection(protection_cfg["藍少回藍"]),
                    shield_recovery = parse_protection(protection_cfg["盾少回血"])
                }
                
                -- 解析紧急设置
                local emergency_settings = {
                    low_health = parse_protection(protection_cfg["血少逃跑"]),
                    low_mana = parse_protection(protection_cfg["藍少逃跑"]),
                    low_shield = parse_protection(protection_cfg["盾少逃跑"]),
                }
                
                -- 设置到黑板
                env.protection_settings = protection_settings
                env.emergency_settings = emergency_settings

                -- 查找最小攻击距离
                local skill_config = config["技能設置"]
                local min_distance = math.huge  -- 初始化为一个很大的数

                for _, v in pairs(skill_config) do 
                    -- if v["启用"] and v["技能屬性"] == "攻击技能" and (v["白怪"] or v["藍怪"] or v["黃怪"] or v["Boss"]) then
                    if v["启用"] and v["技能屬性"] == "攻击技能" and (v["白怪"] or v["藍怪"] or v["黃怪"]) then
                        if v["攻擊距離"] < min_distance then
                            min_distance = v["攻擊距離"]
                        end
                    end
                end

                -- 边走边释放技能
                -- env.walk_attack = env.user_config["全局設置"]["刷图通用設置"]["边走边释放技能"] or false

                -- 如果没有找到符合条件的技能，设置默认值
                if min_distance == math.huge then
                    min_distance = 100  -- 默认攻击距离
                    -- print("警告：未找到符合条件的攻击技能，使用默认攻击距离：" .. min_distance)
                end

                env.min_attack_dis = min_distance
                poe2_api.dbgp("env.min_attack_dis ==>>", env.min_attack_dis)
                -- api_Sleep(1000000)

                -- 加载躲避技能

                if not self.open_mos_skill then
                    self.open_mos_skill = true
                    local skills = config["全局設置"]["刷图通用設置"]["是否躲避技能"]
                    if skills then
                        -- 圆形
                        for _,k in ipairs(my_game_info.MonitoringSkills_Circle) do
                            -- poe2_api.dbgp(k[2])
                            api_RegisterCircle(k[2] , k[3])
                        end

                        -- 扇形
                        for _,k in ipairs(my_game_info.MonitoringSkills_Sector) do
                            -- poe2_api.dbgp(k[2])
                            api_RegisterSector(k[1] , 0, k[2], k[3])
                        end

                        -- 矩形
                        for _,k in ipairs(my_game_info.MonitoringSkills_Rect) do
                            -- poe2_api.dbgp(k[2])
                            api_RegisterRect(k[1] , k[2], k[3])
                        end
                    end
                    -- # 高傷害技能
                    for _,k in ipairs(my_game_info.High_Damage_Skill) do
                        api_RegisterCircle(k[2] , k[3], 2)
                    end
                end

                --  获取配置中的大号名字
                env.leader_name = config["全局設置"]["跟随设置"]["大号名称"] or nil
                env.follow_move = config["全局設置"]["跟随设置"]["是否開啟"] or false
                if not env.team_info then
                    -- 组队信息初始化
                    env.team_info = {
                        ["大號名"] = config["組隊設置"]["大號名"] or "",
                        ["隊長名"] = config["組隊設置"]["隊長名"] or "",
                        ["小號名"] = {}
                    }
                end
            end
            poe2_api.time_p("Get_User_Config_Info... 耗时 --> ", api_GetTickCount64() - start_time)

            -- while true do
            --     Actors:Update() 
            --     api_Sleep(100)
            --     return bret.RUNNING
            -- end

            return bret.SUCCESS
        end
    },

    -- 判断游戏窗口 poe2_api.time_p("判断游戏窗口... 耗时 --> ", api_GetTickCount64() - current_time)
    Is_Game_Windows = {
        run = function(self, env)
            poe2_api.print_log("判断游戏窗口")
            local current_time = api_GetTickCount64()

            if not env.user_info then
                local user_info = poe2_api.load_ini(user_info_path)["UserInfo"]
                env.user_info = user_info
            end
            local game_path = env.user_info["gamedir"]
            poe2_api.dbgp("game_path:" .. game_path)
            
            local log_path = poe2_api.load_config(json_path)["組隊設置"]["日志路径"]
            if self.delete_log == nil then
                os.execute('del /f /q "' .. log_path .. '"')
                self.delete_log = true
            end
            local process_name = string.find(game_path:lower(), "steam.exe") and "PathOfExileSteam.exe" or
                "PathOfExile.exe"
            if not env.config_file then
                -- 获取文档目录路径
                env.documents_path = os.getenv('USERPROFILE') .. '\\Documents'
                -- 构建配置目录路径
                env.config_dir = env.documents_path .. '\\My Games\\Path of Exile 2'
                -- 构建配置文件路径
                env.config_file = env.config_dir .. '\\poe2_production_Config.ini'
            end


            -- local elapsed_ms = (api_GetTickCount64()) - start_time
            -- poe2_api.dbgp("构建配置文件路径:"..string.format( elapsed_ms))
            -- if env.hwrd_time ~=0 then
            --     poe2_api.dbgp("时间差值：:"..api_GetTickCount64() - env.hwrd_time)
            -- end
            poe2_api.dbgp("hwrd_time1:" .. env.hwrd_time)
            if env.hwrd_time == 0 or os.time() - env.hwrd_time >= 60 then
                env.game_window = api_FindWindowByProcess("", "Path of Exile 2", process_name, 0)
                poe2_api.dbgp("game_window:" .. env.game_window)
                env.hwrd_time = os.time()
                poe2_api.dbgp("------------------")
                poe2_api.dbgp("hwrd_time2:" .. env.hwrd_time)
                -- api_Sleep(5000)
                -- elapsed_ms = (api_GetTickCount64()) - start_time
                -- poe2_api.dbgp("获取窗口句柄:"..string.format( elapsed_ms))
            end


            -- 判断游戏窗口
            if (not env.game_window or env.game_window == 0) and not env.error_kill then
                poe2_api.dbgp("窗口不存在==================================================")
                -- 判断游戏配置文件是否存在
                local file = io.open(env.config_file, "r")
                if file then
                    file:close()
                    if poe2_api.check_NCStorageLocalData_config(env.config_dir) then
                        poe2_api.print_log("游戏配置文件异常,替换配置文件")
                        poe2_api.set_NCStorageLocalData_config(env.config_file)
                        poe2_api.time_p("判断游戏窗口(RUNNING)... 耗时 --> ", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    end
                end
                env.is_set = false
                env.take_rest = false
                env.game_window = 0
                env.hwrd_time = 0
                -- error("窗口不存在=")
                -- api_Sleep(5000)
                -- elapsed_ms = (api_GetTickCount64()) - start_time
                -- poe2_api.dbgp("判断游戏窗口:"..string.format( elapsed_ms))
                poe2_api.time_p("判断游戏窗口(FAIL)... 耗时 --> ", api_GetTickCount64() - current_time)
                return bret.FAIL
            end
            poe2_api.time_p("判断游戏窗口(SUCCESS)... 耗时 --> ", api_GetTickCount64() - current_time)
            return bret.SUCCESS
        end
    },

    -- 加入游戏异界
    Join_Game = {
        run = function(self, env)
            poe2_api.print_log("加入异界游戏...")
            if self.bool == nil then
                self.config_exe = false
                self.bool = false
                self.bool1 = false
            end
            local start_time = api_GetTickCount64() -- 转换为 ms

            local game_path = env.user_info["gamedir"]
            poe2_api.dbgp("game_path:" .. game_path)
            local process_name = string.find(game_path:lower(), "steam.exe") and "PathOfExileSteam.exe" or
                "PathOfExile.exe"


            if env.time_out == 0 then
                env.time_out = os.time()
            end
            -- 判断是否关闭游戏
            if env.speel_ip_number >= 50
                or env.error_kill
                or env.is_set
                or env.switching_lines >= 120
                or poe2_api.find_text({ text = "This operation requires the account to be logged in.", UI_info = env.UI_info })
                or poe2_api.find_text({ text = "> 已斷線: Unable to deserialise packet with pid", UI_info = env.UI_info, min_x = 0 }) then
                poe2_api.dbgp("error_kill:", env.error_kill)
                poe2_api.dbgp("speel_ip_number:", env.speel_ip_number)
                poe2_api.dbgp("is_set:", env.is_set)
                poe2_api.dbgp("switching_lines:", env.switching_lines)
                poe2_api.dbgp("find_test (to be logged in.):",
                    poe2_api.find_text({
                        text = "This operation requires the account to be logged in.",
                        UI_info = env
                            .UI_info
                    }))
                poe2_api.dbgp("find_test (packet with pid):",
                    poe2_api.find_text({ text = "> 已斷線: Unable to deserialise packet with pid", UI_info = env.UI_info, min_x = 0 }))
                env.is_game_exe = false
                env.login_state = nil
                env.speel_ip_number = 0
                env.switching_lines = 0
                env.account_state = nil
                env.time_out = 0
                env.error_kill = false
                env.game_window = 0
                env.hwrd_time = 0
                local pid = api_EnumProcess(process_name)

                if pid and next(pid) and pid[1] ~= 0 then
                    api_SetWindowState(env.game_window, 13)
                    -- poe2_api.terminate_process(pid)
                    api_Sleep(10000)
                    return bret.RUNNING
                end

                -- error("关闭游戏===============")
                -- api_Sleep(5000)
                poe2_api.time_p("关闭游戏(RUNNING)... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.RUNNING
            end
            local elapsed_ms = (api_GetTickCount64()) - start_time
            poe2_api.dbgp("判断是否关闭游戏:" .. string.format(elapsed_ms))
            -- 加载中
            if poe2_api.click_text_UI({ UI_info = env.UI_info, text = "loading_screen_tip_label" }) then
                env.last_exp_check = api_GetTickCount64()
                env.last_exception_time = 0
                env.need_SmallRetreat = false
                env.need_ReturnToTown = false
                env.enter_map_click_counter = 0
                env.sacrificial_refresh = 0
                env.have_ritual = false
                env.find_path_FAIL = 0
                env.stuck_monsters = nil
                env.is_dizhu = false
                env.click_grid_pos = false
                env.need_item = nil
                env.interactive = nil
                env.not_items_buy = false
                env.open_map_UI = false -- 重置地图UI信息
                env.afoot_altar = nil
                env.record_map = nil
                env.path_list = {}
                env.end_point = nil
                env.one_other_map = nil
                env.is_timeout = false
                env.is_timeout_exit = false
                -- self.reset_states()
                local current_time = api_GetTickCount64()
                env.last_exception_time_move = 0.0
                env.last_exp_check_move = current_time
                if env.player_info and env.player_info.grid_x ~= 0 then
                    env.last_exp_value = env.player_info.currentExperience
                end
                poe2_api.dbgp("已重置所有经验监控状态")
                api_Sleep(2000)
                env.switching_lines = env.switching_lines + 1
                poe2_api.time_p("Join_Game_Otherworld(RUNNING)... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.RUNNING
            end
            if poe2_api.find_text({UI_info = env.UI_info, text = "選擇一種位移類型", min_x = 0}) then
                poe2_api.find_text({UI_info = env.UI_info, text = "滑鼠", min_x = 0,click = 2 })
                return bret.RUNNING
            end
            if poe2_api.click_text_UI({ text = "life_orb", UI_info = env.UI_info })
                or poe2_api.click_text_UI({ text = "resume_game", UI_info = env.UI_info })
                or poe2_api.find_text({ text = "清單", UI_info = env.UI_info, min_x = 0, min_y = 0, max_x = 400 }) then
                local player_info = env.player_info
                env.kill_process = true
                env.switching_lines = 0
                if not self.config_exe then
                    local file = io.open(env.config_file, "r")
                    if file then
                        file:close()
                        if poe2_api.check_NCStorageLocalData_config(env.config_dir) then
                            poe2_api.print_log("游戏配置文件异常,需要关闭游戏")
                            env.is_set = true
                            poe2_api.time_p("游戏配置文件异常,需要关闭游戏(RUNNING)... 耗时 --> ", api_GetTickCount64() - start_time)
                            return bret.RUNNING
                        else
                            self.config_exe = true
                        end
                    end
                end

                if poe2_api.find_text({ UI_info = env.UI_info, text = "你無法在遊戲暫停時使用該道具。", min_x = 0 }) and not self.bool1 then
                    self.bool1 = true
                    poe2_api.click_keyboard("space")
                end
                if not self.bool and not poe2_api.table_contains(poe2_api.get_team_info(env.team_info, env.user_config, env.player_info, 2), { "大號名", "未知" }) then
                    poe2_api.print_log("等待获取任务信息")
                    poe2_api.dbgp("等待获取任务信息")
                    self.bool = true
                end
                poe2_api.dbgp("已进入游戏")
                -- 计算当前 Tick 耗时（毫秒）
                poe2_api.time_p("已进入游戏耗时(SUCCESS)... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end
            local text_list = { "與副本連線失敗。", "伺服器斷線。", "> Steam：未連接到 Steam", "Steam：未連接到 Steam", "已斷線", "操作逾時","由於在短時間內執行過多指令，因此被伺服器暫時切斷連線。" }
            if poe2_api.find_text({ text = text_list, UI_info = env.UI_info, min_x = 0 }) then
                poe2_api.find_text({ text = "確定", UI_info = env.UI_info, min_x = 0, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({ text = "伺服器關閉維修中，請稍後再試。", UI_info = env.UI_info, min_x = 0 }) then
                error("服务器维护中,已停止运行")
            end
            if poe2_api.find_text({ text = "Your account has been banned by an administrator.", UI_info = env.UI_info }) then
                error("封号!!!")
            end
            if poe2_api.find_text({ text = "登入錯誤", UI_info = env.UI_info }) then
                error("账号或者密码错误")
            end
            if poe2_api.find_text({ text = { "此帳號已被鎖定，請至信箱確認解鎖郵件中的解鎖碼並在此輸入。", "重新寄送解鎖信" }, UI_info = env.UI_info, min_x = 0 }) then
                error("请手动处理邮箱验证")
            end
            if poe2_api.find_text({ text = "此帳號已被其他使用者登入。", UI_info = env.UI_info }) then
                error("此帳號已被其他使用者登入。")
            end

            local text_list1 = { "Login Error", "The operation timed out.", "Entry to this league has closed.",
                "Abnormal Disconnection", "Disconnection", "Disconnected", "偵測到老舊的 GPU 驅動程式。請更新至最新版本。",
                "你的帳號沒有《流亡黯道 2》的搶 先體驗資格。立即在我們的網站上領取搶先體驗金鑰或購買資格。", "搶先體驗" }
            if poe2_api.find_text({ text = text_list1, UI_info = env.UI_info }) then
                poe2_api.find_text({ text = "確定", UI_info = env.UI_info, min_x = 0, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({ text = "Your IP has been banned. Please contact support if you think this is a mistake.", UI_info = env.UI_info }) then
                env.speel_ip_number = env.speel_ip_number + 1
                poe2_api.find_text({ text = "確定", UI_info = env.UI_info, min_x = 0, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({ text = "同意", UI_info = env.UI_info }) then
                poe2_api.find_text({ text = "同意", UI_info = env.UI_info, min_x = 0, add_x = 150, click = 2 })
                poe2_api.find_text({ text = "繼續", UI_info = env.UI_info, min_x = 800, min_y = 450, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({ text = "建立帳號", UI_info = env.UI_info, min_x = 0, max_y = 790 })
                or poe2_api.find_text({ text = "若要使用 Steam 登入，你必須先建立一個 Steam 的《流亡黯道》帳號。", UI_info = env.UI_info, min_x = 0 }) then
                poe2_api.find_text({ text = "帳號名稱", UI_info = env.UI_info, min_x = 0, add_x = 161, click = 2 })
                api_Sleep(500)
                local text = poe2_api.generate_random_string(math.random(8, 10))

                poe2_api.paste_text(text)
                api_Sleep(500)
                poe2_api.find_text({ text = "帳號名稱", UI_info = env.UI_info, min_x = 0, add_x = 110, add_y = 53, click = 2 })
                api_Sleep(500)
                return bret.RUNNING
            end
            local account = env.user_info["account"]
            local password = env.user_info["password"]
            if poe2_api.click_text_UI({ text = "username_textbox", UI_info = env.UI_info }) and not poe2_api.find_text({ text = account, UI_info = env.UI_info, min_x = 646, min_y = 572, max_x = 953, max_y = 609 }) then
                poe2_api.click_text_UI({ text = "username_textbox", UI_info = env.UI_info, click = 1 })
                api_Sleep(500)
                poe2_api.paste_text(account)
                api_Sleep(500)
                return bret.RUNNING
            end
            if poe2_api.click_text_UI({ text = "password_textbox", UI_info = env.UI_info }) and not poe2_api.find_text({ text = password, UI_info = env.UI_info, min_x = 646, min_y = 623, max_x = 953, max_y = 660 }) then
                poe2_api.click_text_UI({ text = "password_textbox", UI_info = env.UI_info, click = 1 })
                api_Sleep(500)
                poe2_api.paste_text(password)
                api_Sleep(500)
                return bret.RUNNING
            end
            if poe2_api.click_text_UI({ text = "login_button", UI_info = env.UI_info }) then
                poe2_api.find_text({ text = "登入", UI_info = env.UI_info, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({ text = "已驗證。", UI_info = env.UI_info, min_x = 0 })
                and poe2_api.find_text({ text = "開始遊戲", UI_info = env.UI_info }) then
                poe2_api.dbgp1("dsgvfsdvsdzvdv")
                poe2_api.click_keyboard("space")
                return bret.RUNNING
            end
            if poe2_api.find_text({ text = "Standard", UI_info = env.UI_info }) then
                poe2_api.find_text({ text = "Standard", UI_info = env.UI_info, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            end
            local creat_new_role = env.creat_new_role
            if poe2_api.find_text({ text = "開始遊戲", UI_info = env.UI_info })
                and not creat_new_role then
                poe2_api.find_text({ text = "開始遊戲", UI_info = env.UI_info, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            else
                poe2_api.find_text({ text = "建立角色", UI_info = env.UI_info, click = 2 })
                api_Sleep(1000)
                return bret.RUNNING
            end
            poe2_api.dbgp("UI未找到任何元素")
            return bret.RUNNING
        end
    },

    -- 官方加入游戏
    Official_Join_Game = {
        run = function(self, env)
            poe2_api.print_log("通过官方渠道加入游戏...")
            local current_time = api_GetTickCount64()

            local function launch_poe2(game_path, game_dir)
                --[[
                专门用于启动Path of Exile 2的函数

                参数:
                    game_path: PoE2主程序路径
                    game_dir: PoE2安装目录
                返回:
                    bool: 启动是否成功
                ]] --

                -- 检查文件和目录是否存在
                local file = io.open(game_path, "r")
                if not file then
                    poe2_api.dbgp(string.format("游戏程序未找到: %s", game_path))
                    return false
                end
                file:close()

                -- 检查目录是否存在
                local dir_handle = io.popen('cd "' .. game_dir .. '" 2>&1')
                local dir_result = dir_handle:read("*a")
                dir_handle:close()
                if dir_result:find("系统找不到指定的路径") or dir_result:find("cannot find the path") then
                    poe2_api.dbgp(string.format("游戏目录未找到: %s", game_dir))
                    return false
                end

                -- 启动游戏

                local command = string.format('start "" /D "%s" "%s"', game_dir, game_path)
                local launch_ok = os.execute(command)

                -- 检查启动结果
                if launch_ok then
                    poe2_api.print_log("游戏启动成功")
                    return true
                else
                    poe2_api.dbgp(string.format("游戏启动失败: %s", launch_ok))
                    return false
                end
            end
            local function get_dirname(path)
                -- 处理 Windows 路径分隔符
                path = path:gsub("/", "\\")
                -- 移除末尾的斜杠（如果有）
                path = path:gsub("[\\/]+$", "")
                -- 获取最后一个斜杠之前的部分
                local dir = path:match("^(.*)[\\/]") or "."
                return dir
            end
            local launch_timeout = env.launch_timeout
            local game_path = env.user_info["gamedir"]
            local is_steam_version = string.find(game_path:lower(), "steam.exe")
            -- 判断官方/steam
            if is_steam_version then
                poe2_api.print_log("steam版本============================================")
                return bret.FAIL
            end
            if launch_timeout ~= 0 and launch_timeout then
                if os.time() - launch_timeout > 120 then
                    poe2_api.print_log("官方游戏启动超时2分钟，重新启动")
                    local pid = api_EnumProcess("PathOfExile.exe")
                    local game_window = api_FindWindowByProcess("", "Path of Exile 2", "PathOfExile.exe", 0)
                    if pid and next(pid) and pid[1] ~= 0 and game_window and game_window ~= 0 then
                        api_SetWindowState(game_window, 13)
                        -- poe2_api.terminate_process(pid)
                        env.game_window = 0
                        env.hwrd_time = 0
                        api_Sleep(10000)
                        return bret.RUNNING
                    end
                    env.kill_process = false
                    env.launch_timeout = 0
                    return bret.RUNNING
                else
                    poe2_api.print_log("等待游戏窗口")
                    return bret.RUNNING
                end
            end
            -- 判断游戏窗口
            -- local pid = nil
            local pid1 = false

            local window_handlesteam = api_FindWindowByProcess("", "Path of Exile 2", "PathOfExileSteam.exe", 0)
            if window_handlesteam and window_handlesteam ~= 0 then
                pid1 = true
            end

            local window_handle = api_FindWindowByProcess("", "Path of Exile 2", "PathOfExile.exe", 0)
            if window_handle and window_handle ~= 0 then
                pid1 = true
            end
            if pid1 then
                poe2_api.print_log("第一次启动,清理游戏进程")
                if window_handlesteam and window_handlesteam ~= 0 then
                    api_SetWindowState(window_handlesteam, 13)
                    env.game_window = 0
                    env.hwrd_time = 0
                    api_Sleep(10000)
                    return bret.RUNNING
                end
                if window_handle and window_handle ~= 0 then
                    api_SetWindowState(window_handle, 13)
                    env.game_window = 0
                    env.hwrd_time = 0
                    api_Sleep(10000)
                    return bret.RUNNING
                end
                -- poe2_api.terminate_process(pid)
            end

            -- 启动游戏
            local game_dir = get_dirname(game_path)
            local launch_result = launch_poe2(game_path, game_dir)
            if launch_result then
                poe2_api.print_log("游戏启动成功")
                if launch_timeout == 0 then
                    env.launch_timeout = os.time()
                end
                api_Sleep(5000)
            else
                poe2_api.print_log("游戏启动失败")
            end
            return bret.RUNNING
        end
    },

    -- 通过Steam启动游戏
    Launch_Game_Steam = {
        
        run = function(self, env)
            poe2_api.print_log("通过Steam启动游戏...")
            -- local login_state = env.login_state
            local game_path = env.user_info["gamedir"]
            if not self.last_time then
                self.last_time = 0
                return bret.RUNNING
            end
            poe2_api.dbgp("login_state: "..tostring(env.login_state))
            if not env.login_state then
                poe2_api.print_log("清空数据")
                env.kill_process=false
                env.game_window = 0
                env.hwrd_time = 0
                poe2_api.delete_steam_account_history(game_path)
                local steam_pid = api_EnumProcess("steam.exe")
                poe2_api.dbgp(tostring(#steam_pid.."==========================="))
                poe2_api.dbgp(tostring(steam_pid[1].."==========================="))
                -- for k, v in pairs(steam_pid) do
                --     poe2_api.dbgp(tostring(k) .. tostring(v))
                -- end
                poe2_api.dbgp("steam_pid: "..tostring(steam_pid))
                if steam_pid and next(steam_pid) and steam_pid[1] ~= 0 then
                    poe2_api.exec_cmd("taskkill /f /im steam.exe")
                    api_Sleep(2000)
                    return bret.RUNNING
                end
                local steamwebhelper_pid = api_EnumProcess("steamwebhelper.exe")
                poe2_api.dbgp(tostring(#steamwebhelper_pid.."===========================1111"))
                if steamwebhelper_pid and next(steamwebhelper_pid) and  steamwebhelper_pid[1] ~= 0 then
                    poe2_api.exec_cmd("taskkill /f /im steamwebhelper.exe")
                    api_Sleep(2000)
                    return bret.RUNNING
                end
                env.login_state = "启动登录窗口"
                if self.last_time == 0 then
                    self.last_time = os.time()
                end
                return bret.RUNNING
            end
            if env.login_state == "启动登录窗口" then
                -- local start_path = string.format("%s -applaunch %d", game_path, 2694490)
                local start_cmd = string.format('start "" "%s" -applaunch %d', game_path, 2694490)
                local steam_pid = api_EnumProcess("steam.exe")
                if not steam_pid or not next(steam_pid) or steam_pid[1] == 0 then
                    poe2_api.exec_cmd(start_cmd)
                    poe2_api.dbgp("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
                    api_Sleep(5000)
                    env.login_state = "等待登录窗口"
                    self.last_time = os.time()
                    return bret.RUNNING
                end
            end
            if env.login_state == "等待登录窗口" then
                local steam_login_hwnd = api_FindWindow("SDL_app", "登录 Steam",0)
                if steam_login_hwnd and steam_login_hwnd ~= 0 then
                    env.login_state = "输入帳號"
                    self.last_time = os.time()
                    return bret.RUNNING
                end
                poe2_api.print_log("等待登录窗口")
                if os.time() - self.last_time > 120 then
                    poe2_api.print_log("等待登录窗口超时")
                    env.login_state = nil
                    self.last_time = 0
                    return bret.RUNNING
                end
                api_Sleep(2000)
                return bret.RUNNING
            end
            if env.login_state == "输入帳號" then
                local account = env.user_info["account"]
                local password = env.user_info["password"]
                -- local steam_login_hwnd = api_FindWindow("Chrome_RenderWidgetHostHWND","Chrome Legacy Window",0)
                local steam_login_hwnd = api_FindWindow("SDL_app", "登录 Steam",0)
                -- poe2_api.dbgp("111:",steam_login_hwnd)
                -- api_Sleep(10000000)
                if steam_login_hwnd and steam_login_hwnd ~= 0 then
                    api_SetWindowState(steam_login_hwnd, 8)
                    api_Sleep(1000)
                    -- api_SetWindowState(steam_login_hwnd, 9)
                    -- api_Sleep(1000)
                    local left, top, right, bottom = api_GetWindowRect(steam_login_hwnd)
                    api_ClickScreen(poe2_api.toInt(left + 345),poe2_api.toInt(top + 140) , 1)
                    api_Sleep(1000)
                    poe2_api.paste_text(account)
                    api_Sleep(1000)
                    api_ClickScreen(poe2_api.toInt(left + 345), poe2_api.toInt(top + 206) , 1)
                    api_Sleep(1000)
                    poe2_api.paste_text(password)
                    api_Sleep(1000)
                    poe2_api.click_keyboard("enter",0)     
                    env.login_state = "等待steam主窗口"
                    self.last_time = os.time()
                    return bret.RUNNING

                else
                    poe2_api.print_log("登录窗口不存在")
                    env.login_state = nil
                    self.last_time = 0
                    return bret.RUNNING
                end
                
                -- 根据窗口句柄 获取窗口坐标
                return bret.RUNNING
            end
            if env.login_state == "等待steam主窗口" then
                poe2_api.print_log("等待steam主窗口")
                local steam_login_hwnd = api_FindWindowByProcess("","Steam","steamwebhelper.exe",0)
                if steam_login_hwnd and steam_login_hwnd ~= 0 then
                    env.login_state = "等待游戏窗口"
                    self.last_time = os.time()
                    return bret.RUNNING
                end
                if os.time() - self.last_time > 120 then
                    poe2_api.print_log("等待steam主窗口超时")
                    env.login_state = nil
                    self.last_time = 0
                    return bret.RUNNING
                end
                api_Sleep(2000)
                return bret.RUNNING
            end
            if env.login_state == "等待游戏窗口" then
                poe2_api.print_log("等待steam游戏窗口")
                if os.time() - self.last_time > 120 then
                    poe2_api.print_log("等待steam游戏窗口超时")
                    env.login_state = nil
                    self.last_time = 0
                    return bret.RUNNING
                end
                api_Sleep(2000)
                return bret.RUNNING
            end
            return bret.RUNNING
        end
    },

    -- 获取UI信息
    Get_UI_Info = {
        run = function(self, env)
            poe2_api.print_log("获取UI信息...")
            local start_time = api_GetTickCount64() -- 开始时间
            env.UI_info = UiElements:Update()
            if #env.UI_info < 1 then
                api_Sleep(4000)
                return bret.RUNNING
            end
            -- for _,k in ipairs(env.UI_info) do
            --     if k.text_utf8 ~= "" then
            --         poe2_api.dbgp(k.text_utf8)
            --     end
            -- end
            poe2_api.time_p("Get_UI_Info... 耗时 --> ", api_GetTickCount64() - start_time)
            -- api_Sleep(4000)
            return bret.SUCCESS
        end
    },

    -- 获取信息
    Get_Info = {
        run = function(self, env)
            poe2_api.print_log("获取游戏信息...")
            local start_time = api_GetTickCount64() -- 开始时间

            local player_info_start_time = api_GetTickCount64()
            env.player_info = api_GetLocalPlayer()
            -- poe2_api.printTable(env.player_info)
            if poe2_api.countTableItems(env.player_info) < 1 then
                poe2_api.dbgp("空人物信息")
                return bret.RUNNING
            end
            poe2_api.time_p("    获取人物信息... 耗时 --> ", api_GetTickCount64() - player_info_start_time)

            local range_info_start_time = api_GetTickCount64() -- 记录开始时间(毫秒)
            if not self.last_check then
                self.last_check = range_info_start_time
            end
            if range_info_start_time - self.last_check > 0 or not env.range_info or #env.range_info < 1 then
                env.range_info = Actors:Update()
                self.last_check = range_info_start_time
                if #env.range_info < 1 then
                    poe2_api.dbgp("等待获取周围对象信息...")
                    return bret.RUNNING
                end
                poe2_api.time_p("    获取周围对象信息... 耗时 --> ", api_GetTickCount64() - range_info_start_time)
            end
            -- api_GetMinimapActorInfo() - 获取小地图周围对象信息
            local current_map_info_start_time = api_GetTickCount64()
            env.current_map_info = api_GetMinimapActorInfo()
            if not env.current_map_info then
                poe2_api.dbgp("空小地图周围对象信息")
                return bret.RUNNING
            end
            -- for _,k in ipairs(env.current_map_info) do
            --     poe2_api.dbgp(k.name_utf8)
            --     poe2_api.dbgp(k.grid_x)
            --     poe2_api.dbgp(k.grid_y)
            --     poe2_api.dbgp(k.flagStatus)
            --     poe2_api.dbgp(k.flagStatus1)
            --     poe2_api.dbgp("==============================")
            -- end
            -- while true do
            --     api_Sleep(1000)
            -- end
            poe2_api.time_p("    获取小地图周围对象信息... 耗时 --> ", api_GetTickCount64() - current_map_info_start_time)

            -- 队伍数据信息
            local team_info_data_start_time = api_GetTickCount64()
            env.team_info_data = api_GetTeamInfo()
            poe2_api.dbgp('获取队伍信息')
            poe2_api.time_p("    获取队伍信息... 耗时 --> ", api_GetTickCount64() - team_info_data_start_time)
            -- 周围装备信息
            local range_items_start_time = api_GetTickCount64()
            env.range_items = WorldItems:Update()
            -- poe2_api.printTable(env.range_items)
            poe2_api.time_p("    获取周围装备信息... 耗时 --> ", api_GetTickCount64() - range_items_start_time)

            -- 背包信息（主背包）
            local bag_info_start_time = api_GetTickCount64()
            env.bag_info = api_Getinventorys(1, 0)
            poe2_api.time_p("    获取背包信息信息... 耗时 --> ", api_GetTickCount64() - bag_info_start_time)

            -- api_GetTeleportationPoint() - 获取传送点信息
            if not env.waypoint and env.player_info.name_utf8 ==  env.user_config["組隊設置"]["大號名"] then --and env.player_info.name_utf8 ==  env.user_config["組隊設置"]["大號名"]
                local waypoint_start_time = api_GetTickCount64()
                if not poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖",refresh = true}) then
                    api_Sleep(800)
                    poe2_api.click_keyboard("u")
                end
                api_Sleep(200)
                env.waypoint = api_GetTeleportationPoint()
                api_Sleep(200)
                -- poe2_api.printTable(env.waypoint)
                poe2_api.click_keyboard("u")

                poe2_api.time_p("    获取传送点信息... 耗时 --> ", api_GetTickCount64() - waypoint_start_time)
            end

            -- 测试函数
            local function dumpInventory(inventory)
                local itemFields = {
                    "name_utf8", "baseType_utf8", "start_x", "start_y", "end_x", "end_y",
                    "not_identified", "category_utf8", "color", "world_x", "world_y", "grid_x", "grid_y",
                    "skillGemLevel", "skillStoneLevel", "isWearable", "DemandStrength", "DemandAgility",
                    "DemandWisdom", "DemandLevel", "obj", "contaminated", "id", "tribute",
                    "totalDeferredConsumption", "fixedSuffixCount", "mods_obj", "stackCount"
                }

                for _, item in ipairs(inventory) do
                    api_Log("==============================")
                    -- local Suffix = api_GetObjectSuffix(item.mods_obj)
                    -- local Suffix1 = api_GetObjectSuffix(item.obj)
                    -- poe2_api.printTable(item.fixedSuffixCount)
                    -- poe2_api.printTable(Suffix)
                    -- poe2_api.printTable(Suffix1)
                    -- api_Log("Suffix")
                    -- api_Log(Suffix)
                    -- api_Log("Suffix1")
                    -- api_Log(Suffix1)
                    -- 遍历预定义的属性列表，确保按固定顺序输出
                    for _, field in ipairs(itemFields) do
                        local value = item[field]
                        api_Log(string.format("%-25s: %s", field, tostring(value)))
                    end

                    api_Log("----------------------------------")
                end

                api_Sleep(1000000) -- 暂停程序（注意：长时间暂停可能导致游戏无响应）
            end

            -- 测试函数
            local function dumprange(inventory)
                local itemFields = {
                    "obj", "name_utf8", "world_x", "world_y", "world_z", "grid_x", "grid_y", "max_life",
                    "life", "max_mana", "mana", "max_shield",
                    "shield", "type", "current_map_name_utf8", "is_selectable",
                    "level", "strength", "dexterity", "intelligence",
                    "spirit_max", "spirit_use", "is_friendly", "hasTasksToAccept",
                    "hasLineOfSight", "isActive", "rarity", "path_name_utf8",
                    "currentExperience", "id", "isInDangerArea", "stateMachineList", "gold",
                    "isInBossBattle", "remainingPortalCount", "isMoving", "magicProperties"
                }

                for _, item in ipairs(inventory) do
                    if item.name_utf8 == "" or item.life == 0 or not item.isActive then
                        goto continue
                    end
                    api_Log("==============================")
                    -- 遍历预定义的属性列表，确保按固定顺序输出
                    for _, field in ipairs(itemFields) do
                        local value = item[field]
                        api_Log(string.format("%-25s: %s", field, tostring(value)))
                    end

                    api_ClickMove(item.grid_x, item.grid_y, 0)
                    api_Sleep(1000)

                    api_Log("----------------------------------")
                    ::continue::
                end

                api_Sleep(1000000) -- 暂停程序（注意：长时间暂停可能导致游戏无响应）
            end

            -- 调用函数
            -- dumpInventory(env.range_items)
            -- dumprange(env.range_info)
            -- poe2_api.printTable(api_GetQuestList(0))
            -- api_Sleep(1000000) -- 暂停程序（注意：长时间暂停可能导致游戏无响应）
            
            if self.wear_items == nil then
                self.wear_items = true
            end
            -- 其他物品栏信息（批量处理）
            if self.wear_items then
                local inventory_sections = {
                    { 2, "item2" }, { 3, "item3" }, { 4, "item4" },
                    { 5, "item5" }, { 6, "item6" }, { 7, "item7" },
                    { 8, "item8" }, { 9, "item9" }, { 0xa, "item0xa" }, { 0xb, "item0xb" }
                }
                for _, section in ipairs(inventory_sections) do
                    local section_id = section[1]
                    local section_name = section[2]
                    if not env[section_name] then
                        local items = api_Getinventorys(section_id, 0)
                        env[section_name] = items
                    end
                end
                self.wear_items = false
            end

            poe2_api.time_p("Get_Info... 总耗时 --> ", api_GetTickCount64() - start_time)
            return bret.SUCCESS
        end
    },

    -- 清理
    Clear = {
        run = function(self, env)
            poe2_api.print_log("执行清理...")
            local start_time = api_GetTickCount64()
            if not self.time1 then
                self.bool = false
                self.time1 = 0
                poe2_api.dbgp("初始化")
            end
            local player_info = env.player_info
            if not player_info or not next(player_info) then
                poe2_api.dbgp("人物信息为空")
                return bret.RUNNING
            end
            if self.time1 == 0 then
                self.time1 = api_GetTickCount64()
            end
            if poe2_api.find_text({ UI_info = env.UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2 }) then
                return bret.RUNNING
            end
            if player_info.life ~= 0 and not poe2_api.click_text_UI({ text = "respawn_at_checkpoint_button", UI_info = env.UI_info }) then
                if (string.match(player_info.current_map_name_utf8, "town") and not self.bool) or start_time - self.time1 > 5 * 60 * 1000 then
                    if not poe2_api.find_text({ UI_info = env.UI_info, text = "/clear", min_x = 0 }) then
                        api_ClickMove(poe2_api.toInt(player_info.grid_x), poe2_api.toInt(player_info.grid_y),7)
                        api_Sleep(1000)
                        poe2_api.click_keyboard("enter")
                        api_Sleep(500)
                        poe2_api.click_keyboard("backspace")
                        api_Sleep(500)
                        poe2_api.paste_text("/clear")
                        api_Sleep(500)
                        poe2_api.click_keyboard("enter")
                        api_Sleep(500)
                        self.bool = true
                        self.time1 = 0
                        return bret.RUNNING
                    end
                elseif not string.match(player_info.current_map_name_utf8, "town") then
                    self.bool = false
                end
            end
            poe2_api.time_p("执行清理... 耗时 --> ", api_GetTickCount64() - start_time)
            return bret.SUCCESS
        end
    },

    -- 休息控制
    RestController = {
        run = function(self, env)
            poe2_api.print_log("执行休息控制...")
            poe2_api.dbgp("执行休息控制...")
            local player_info = env.player_info
            local start_time = api_GetTickCount64() -- 开始时间
            -- 特殊情况跳出
            if poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) ~= "大號名" or player_info.isInBossBattle or poe2_api.is_have_mos({ range_info = env.range_info, player_info = player_info, dis = 80, stuck_monsters = env.stuck_monsters, not_attack_mos = env.not_attack_mos }) then
                return bret.SUCCESS
            end
            -- 初始化检查
            if not self._is_initialized then
                poe2_api.dbgp("初始化休息控制器...")
                local config = env.user_config["全局設置"]["刷图通用設置"]["定時休息"] or {}
                
                -- 工作时间配置（单位：分钟→毫秒）
                local base_work = tonumber(config["運行時間"]) or 60  -- 默认60分钟
                local work_random_range = math.min(tonumber(config["工作時間隨機範圍"]) or 0.1, 0.3) -- 限制最大30%波动
                self.work_duration_ms = math.floor(base_work * 60 * 1000 * (1 + (math.random() * work_random_range * 2 - work_random_range)))
                
                -- 休息时间配置（单位：分钟→毫秒）
                local base_rest = tonumber(config["休息時間"]) or 10  -- 默认10分钟
                local rest_random_range = math.min(tonumber(config["休息時間隨機範圍"]) or 0.1, 0.3) -- 限制最大30%波动
                self.rest_duration_ms = math.floor(base_rest * 60 * 1000 * (1 + (math.random() * rest_random_range * 2 - rest_random_range)))

                -- 功能开关
                self.is_open = config["是否開啟"] or false
                self.is_kill_game = config["休息时是否关闭游戏"] or false
                
                -- 初始化状态（使用毫秒时间戳）
                local current_time_ms = api_GetTickCount64()
                self._is_resting = false
                self._next_state_change_time_ms = current_time_ms + self.work_duration_ms
                self._last_update_time_ms = current_time_ms
                self._is_initialized = true
                
                poe2_api.dbgp("初始化完成 - 工作时间:%d分钟 休息时间:%d分钟", self.work_duration_ms/(60*1000), self.rest_duration_ms/(60*1000))
                return bret.RUNNING
            end

            -- 功能关闭直接返回成功
            if not self.is_open then
                poe2_api.dbgp("休息功能未开启，直接返回SUCCESS")
                poe2_api.time_p("休息功能未开启... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end
            
            local current_time_ms = api_GetTickCount64()

            local function _perform_rest_actions()
                poe2_api.dbgp("执行休息操作...")
                if not (poe2_api.find_text({UI_info = env.UI_info, text = "回到角色選擇畫面"}) or poe2_api.click_text_UI({UI_info = env.UI_info, text = "exit_to_character_selection"})) then
                    if poe2_api.click_text_UI({UI_info = env.UI_info, text = "life_orb"}) and poe2_api.click_text_UI({UI_info = env.UI_info, text = "mana_orb"}) then
                        poe2_api.click_keyboard("esc")
                    end
                end
                api_Sleep(1000)
            end

            local function _handle_state_transition()
                self._is_resting = not self._is_resting
                local duration_ms = self._is_resting and self.rest_duration_ms or self.work_duration_ms
                self._next_state_change_time_ms = current_time_ms + duration_ms
                self._last_update_time_ms = current_time_ms
                
                -- 更新环境变量
                env.take_rest = self._is_resting
                
                if self._is_resting then
                    poe2_api.dbgp("切换到休息状态")
                    
                    if not string.find(player_info.current_map_name_utf8, "own") then
                        poe2_api.dbgp("休息回城")
                        for _, name in ipairs(my_game_info.city_map) do
                            poe2_api.find_text({ UI_info = env.UI_info, text = name, click = 2 })
                        end
                        api_ClickScreen(1230, 815, 0)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(2000)
                        return bret.RUNNING
                    end
                    
                    -- 进入休息状态
                    if self.is_kill_game then
                        env.error_kill = true
                        poe2_api.dbgp("设置需要关闭游戏")
                    end
                    poe2_api.dbgp(string.format("工作时间到，开始休息 (%d分钟)", math.floor(self.rest_duration_ms/(60*1000))))
                    -- _perform_rest_actions()
                    -- poe2_api.dbgp(string.format("工作时间到，开始休息 (%d分钟)", math.floor(self.rest_duration_ms/(60*1000))))
                    -- api_Sleep(11000000)
                    return bret.RUNNING
                else
                    -- 返回工作状态
                    env.error_kill = false
                    poe2_api.dbgp(string.format("休息结束，开始工作 (%d分钟)",  math.floor(self.work_duration_ms/(60*1000))))
                    self._is_initialized = false
                    return bret.SUCCESS
                end
            end

            local function _update_status()
                local time_remaining_ms = math.max(0, self._next_state_change_time_ms - current_time_ms)
                
                if self._is_resting then
                    poe2_api.dbgp("当前处于休息状态")

                    
                    -- 休息状态更新（每分钟60000毫秒）
                    if current_time_ms - self._last_update_time_ms >= 60000 then
                        self._last_update_time_ms = current_time_ms
                        local mins = math.floor(time_remaining_ms/(60*1000))
                        local secs = math.floor((time_remaining_ms%(60*1000))/1000)
                        poe2_api.print_log(string.format("休息中... 剩余时间: %02d分%02d秒", mins, secs))
                        env.take_rest = true
                        
                        if not string.find(player_info.current_map_name_utf8, "own") then
                            poe2_api.dbgp("休息回城(状态更新)")
                            for _, k in ipairs(my_game_info.city_map) do
                                poe2_api.find_text({ UI_info = env.UI_info, text = k.name_utf8, click = 2 })
                            end
                            api_ClickScreen(1230, 815, 0)
                            api_Sleep(500)
                            api_ClickScreen(1230, 815, 1)
                        end
                        api_Sleep(1000)
                    end
                    api_Sleep(2000)
                    return bret.RUNNING
                else
                    -- 工作状态更新（每5分钟300000毫秒）
                    if current_time_ms - self._last_update_time_ms >= 300000 then
                        self._last_update_time_ms = current_time_ms
                        local hours = math.floor(time_remaining_ms/(3600*1000))
                        local mins = math.floor((time_remaining_ms%(3600*1000))/(60*1000))
                        local secs = math.floor((time_remaining_ms%(60*1000))/1000)
                        poe2_api.print_log(string.format("工作中... 距离休息还有: %d小时%02d分钟%02d秒", hours, mins, secs))
                        env.take_rest = false
                    end
                    return bret.SUCCESS
                end
            end

            -- 状态切换检查（毫秒级比较）
            if current_time_ms >= self._next_state_change_time_ms then
                poe2_api.dbgp("检测到状态切换时间到达")
                poe2_api.time_p("检测到状态切换时间到达... 耗时 --> ", api_GetTickCount64() - start_time)
                return _handle_state_transition()
            end
                
            -- 状态更新
            poe2_api.dbgp("更新当前状态...")
            poe2_api.time_p("更新当前状态... 耗时 --> ", api_GetTickCount64() - start_time)
            return _update_status()
        end
    },

    -- 检查长时间未移动
    Check_LongTime_Not_Move = {
        run = function(self, env)
            poe2_api.print_log("开始执行长时间经验检查...")
            
            local current_time = api_GetTickCount64()
            local take_rest = env.take_rest
            local player_info = env.player_info
        -- 特殊情况跳出
            if player_info.isInBossBattle and poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) ~= "大號名" then
                return bret.SUCCESS
            end
            --- 辅助函数
            -- 检查是否处于停滞移动状态
            local function _check_stagnant_movement()
                local current = env.player_info
                if not current then return false end
                
                local last_pos = env.last_position or {0, 0}
                local distance = poe2_api.point_distance(last_pos[1], last_pos[2], current)
                
                -- 更新位置记录
                env.last_position = {current.grid_x, current.grid_y}
                
                poe2_api.dbgp(string.format("移动距离检查: %.2f (阈值:15)", distance))
                return distance < 15
            end
            -- 重置移动检查状态
            local function reset_states_move()
                local current_time = api_GetTickCount64()
                local current = env.player_info
                env.last_exception_time_move = 0.0
                env.last_exp_check_move = current_time
                env.last_exp_value_move = env.player_info.currentExperience
                env.last_position = {current.grid_x, current.grid_y}
                poe2_api.dbgp("已重置所有移动监控状态")
            end

            -- 获取可交互对象
            local function get_range()
                local valid_objects = {
                    "甕", "壺", "屍體", "巢穴", "籃子", "小雕像", "石塊",
                    "鬆動碎石", "瓶子", "盒子", "腐爛木材", "保險箱", "腐爛木材"
                }
                
                -- 对范围对象进行排序
                local sorted_range = poe2_api.get_sorted_list(env.range_info, env.player_info)
                if not sorted_range then
                    poe2_api.dbgp("警告: 无法获取排序后的范围列表")
                    return false
                end

                poe2_api.dbgp(string.format("检查 %d 个范围内的对象", #sorted_range))
                
                -- 遍历查找符合条件的对象
                for _, obj in ipairs(sorted_range) do
                    -- 调试输出当前对象信息
                    poe2_api.dbgp(string.format("检查对象: %s (类型: %s, 激活: %s, 可选: %s)", 
                        obj.name_utf8 or "无名", 
                        obj.type or "未知", 
                        tostring(obj.isActive), 
                        tostring(obj.is_selectable)))
                    
                    if obj.name_utf8 and 
                    poe2_api.table_contains(valid_objects, obj.name_utf8) and
                    obj.isActive and 
                    obj.is_selectable and
                    obj.grid_x and obj.grid_y then
                        
                        local distance = poe2_api.point_distance(obj.grid_x, obj.grid_y, player_info)
                        if distance then
                            poe2_api.dbgp(string.format("对象 %s 距离: %.2f", obj.name_utf8, distance))
                            
                            if distance <= 20 then
                                poe2_api.dbgp("找到符合条件的交互对象: ", obj.name_utf8)
                                return obj
                            end
                        end
                    end
                end
                
                poe2_api.dbgp("未找到符合条件的交互对象")
                return false
            end
            
            -- 节流控制
            if self.last_check and current_time - self.last_check < 500 then
                poe2_api.dbgp("节流控制: 检查间隔小于0.5秒，跳过")
                poe2_api.time_p("Check_LongTime_EXP_Add(节流控制)... 耗时 --> ", api_GetTickCount64() - current_time)
                return bret.SUCCESS
            end

            self.last_check = current_time   

            if take_rest then
                poe2_api.dbgp("正在休息，跳过异常处理")
                return bret.SUCCESS
            end

            -- 检查移动状态
            local is_moving = _check_stagnant_movement()
            poe2_api.dbgp("移动状态检查: ", is_moving and "未移动" or "移动中")
            -- 移动状态变化时重置状态
            if not is_moving then
                poe2_api.dbgp("移动状态变化，重置移动检查状态")
                reset_states_move()
            end

            -- 计算真实停滞时间
            local space_time = 10
            local real_stagnation_time_move = current_time - (env.last_exp_check_move or 0)
            
            poe2_api.dbgp(string.format("移动停滞时间: %.2f秒", real_stagnation_time_move / 1000))

            -- 处理长时间未移动情况
            if is_moving and real_stagnation_time_move > space_time * 1000 then
                poe2_api.dbgp(string.format("长时间未移动(%.2f秒 > %d秒)，执行恢复操作", 
                    real_stagnation_time_move / 1000, space_time))
                
                if not take_rest then
                    poe2_api.print_log("清路径333")
                    env.end_point = nil
                    env.target_point = nil
                    env.path_list = {}
                    env.is_arrive_end = true
                    poe2_api.dbgp1("sgewgbfdbgfdhn")
                    poe2_api.click_keyboard("space")
                    
                    if env.range_info and player_info then
                        local target = get_range()
                        if target then
                            api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y), 0)
                            api_Sleep(500)
                            api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y), 1)
                            api_Sleep(500)
                            poe2_api.find_text({UI_info = env.UI_info, text = target.name_utf8, click = 2, refresh = true, min_x = 0})
                            api_Sleep(500)
                        end
                        
                        local walkpoint = api_FindRandomWalkablePosition(player_info.grid_x, 50)
                        api_ClickMove(poe2_api.toInt(walkpoint.x), poe2_api.toInt(walkpoint.y),
                             7)
                        api_Sleep(500)
                        poe2_api.dbgp1("fdgrgrfhfhdfhb")
                        poe2_api.click_keyboard("space")
                        api_Sleep(100)
                    end
                    env.last_exp_check_move = api_GetTickCount64()
                    return bret.RUNNING
                end
            end
            poe2_api.time_p("Check_LongTime_EXP_Add(SUCCESS)... 耗时 --> ", api_GetTickCount64() - current_time)
            return bret.SUCCESS
        end
    },
    -- 检查异界死亡
    Is_Deth = {
        run = function(self, env)
            poe2_api.print_log("死亡初始化")
            poe2_api.dbgp("死亡初始化")
            local start_time = api_GetTickCount64()
            local player_info = env.player_info

            if not self.respawn_wait_start then
                self.respawn_wait_start = 0
                self.click_time = 0
                self.death_time = 0
            end
            if not player_info then
                poe2_api.dbgp("玩家信息不存在，跳过死亡初始化")
                return bret.RUNNING
            end
            if player_info.life ~= 0 then
                self.click_time = 0
                self.death_time = 0
                poe2_api.time_p("Is_Deth... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end
            if player_info.life == 0 and poe2_api.find_text({ UI_info = env.UI_info, text = "在記錄點重生" }) then
                if poe2_api.click_text_UI({ UI_info = env.UI_info, text = "respawn_at_checkpoint_button" }) and not env.is_timeout and not env.is_timeout_exit then
                    poe2_api.dbgp1("rewyrejhgfdbnsdbvs")
                    poe2_api.click_keyboard("space")
                end
                poe2_api.dbgp("点击确认")
                poe2_api.find_text({ UI_info = env.UI_info, text = "確定", click = 2, min_x = 0 })
                api_ClickScreen(915, 490, 1)
                local relife_text = { "在記錄點重生", "在城鎮重生" }
                local point = poe2_api.find_text({ UI_info = env.UI_info, text = relife_text, min_x = 0, position = 3 })
                if not point then
                    poe2_api.time_p("Is_Deth(RUNNING)... 耗时 --> ", api_GetTickCount64() - start_time)
                    poe2_api.dbgp("Is_Deth(RUNNING1)")
                    return bret.RUNNING
                end

                api_ClickScreen(point[1], point[2], 0)
                api_Sleep(1000)
                api_ClickScreen(point[1], point[2], 1)
                if self.death_time == 0 then
                    self.death_time = api_GetTickCount64()
                end
                if self.click_time == 0 then
                    self.click_time = api_GetTickCount64()
                end
                if (start_time - self.death_time >= 60 * 1000) and (poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) == "大號名") then
                    env.is_timeout_exit = true
                end
                if start_time - self.click_time >= 5 * 1000 then
                    poe2_api.find_text({ UI_info = env.UI_info, text = "在記錄點重生", click = 2 })
                    self.click_time = 0
                end
                env.area_list = {}
                env.is_need_check = false
                env.stuck_monsters = nil
                env.item_name = nil
                env.item_pos = nil
                env.afoot_altar = nil
                env.record_map = nil
                env.check_all_points = false
                env.empty_path = false
                env.map_name = nil
                env.interaction_object = nil
                env.item_move = false
                env.item_end_point = { 0, 0 }
                env.attack_move = false
                env.ok = false
                env.not_need_wear = false
                env.currency_check = false
                env.sell_end_point = { 0, 0 }
                env.is_better = false
                env.mos_out = 0
                env.is_arrive_end = false
                env.not_need_pick = false
                env.is_not_ui = false
                env.no_item_wear = false
                env.my_role = nil
                env.is_set = false
                env.end_point = nil
                env.path_list = {}
                env.run_point = nil
                env.teleport_area = nil
                env.follow_role = nil
                env.one_other_map = nil
                env.need_item = nil
                env.center_radius = 0
                env.center_point = {}

                if self.respawn_wait_start == 0 then
                    self.respawn_wait_start = api_GetTickCount64()
                    return bret.RUNNING
                elseif api_GetTickCount64() - self.respawn_wait_start < 2 then
                    return bret.RUNNING
                else
                    self.respawn_wait_start = 0
                end
            end
            poe2_api.time_p("Is_Deth... 耗时 --> ", api_GetTickCount64() - start_time)
            poe2_api.dbgp("Is_Deth(SUCCESS2)")
            return bret.SUCCESS
        end
    },

    -- 检查低血量/蓝量
    CheckLowHpMp = {
        run = function(self, env)
            local start_time = api_GetTickCount64()
            poe2_api.dbgp("开始执行蓝血检查:")
            
            local player = env.player_info
            local prot = env.protection_settings
            local emerg = env.emergency_settings
            
            -- 初始化计时器（如果不存在）
            if self.last_health_recovery_time == nil then
                self.last_health_recovery_time = api_GetTickCount64()
                self.last_mana_recovery_time = api_GetTickCount64()
                self.last_shield_recovery_time = api_GetTickCount64()
                self._emergency_cooldown = 0
                poe2_api.dbgp("初始化计时器完成")
            end
            
            -- 检查玩家信息
            if not player then
                poe2_api.dbgp("错误: 玩家信息为空")
                return bret.RUNNING
            end

            local function _handle_regular_recovery(player, prot, now)
                poe2_api.dbgp("开始处理常规恢复...")
                poe2_api.dbgp("当前生命值:", player.life, "/", player.max_life)
                poe2_api.dbgp("当前法力值:", player.mana, "/", player.max_mana)
                poe2_api.dbgp("当前护盾值:", player.shield, "/", player.max_shield)
                
                -- 血量恢复
                local hp_cfg = prot.health_recovery or {}
                if hp_cfg.enable then
                    local threshold = player.max_life * (hp_cfg.threshold / 100)
                    local interval = (hp_cfg.interval or 0) / 1000
                    
                    poe2_api.dbgp(string.format("血量检查: 当前 %.1f < 阈值 %.1f (%.1f%%) 且冷却 %.1fs >= 间隔 %.1fs", 
                        player.life, threshold, hp_cfg.threshold, 
                        start_time - self.last_health_recovery_time, interval))
                    
                    if player.life < threshold and now - self.last_health_recovery_time >= interval then
                        poe2_api.dbgp("触发血量恢复 - 按下1键")
                        poe2_api.click_keyboard("1")
                        self.last_health_recovery_time = now
                    end
                end
                
                -- 蓝量恢复
                local mp_cfg = prot.mana_recovery or {}
                if mp_cfg.enable then
                    local threshold = player.max_mana * (mp_cfg.threshold / 100)
                    local interval = (mp_cfg.interval or 0) / 1000
                    
                    poe2_api.dbgp(string.format("蓝量检查: 当前 %.1f < 阈值 %.1f (%.1f%%) 且冷却 %.1fs >= 间隔 %.1fs", 
                        player.mana, threshold, mp_cfg.threshold, 
                        now - self.last_mana_recovery_time, interval))
                    
                    if player.mana < threshold and now - self.last_mana_recovery_time >= interval then
                        poe2_api.dbgp("触发蓝量恢复 - 按下2键")
                        poe2_api.click_keyboard("2")
                        self.last_mana_recovery_time = now
                    end
                end
                
                -- 护盾恢复
                local shield_cfg = prot.shield_recovery or {}
                if shield_cfg.enable then
                    local threshold = player.max_shield * (shield_cfg.threshold / 100)
                    local interval = (shield_cfg.interval or 0) / 1000
                    
                    poe2_api.dbgp(string.format("护盾检查: 当前 %.1f < 阈值 %.1f (%.1f%%) 且冷却 %.1fs >= 间隔 %.1fs", 
                        player.shield, threshold, shield_cfg.threshold, 
                        now - self.last_shield_recovery_time, interval))
                    
                    if player.shield < threshold and now - self.last_shield_recovery_time >= interval then
                        poe2_api.dbgp("触发护盾恢复 - 按下1键")
                        poe2_api.click_keyboard("1")
                        self.last_shield_recovery_time = now
                    end
                end
                
                return bret.SUCCESS
            end
            
            -- 检查是否在安全区域
            if poe2_api.table_contains(my_game_info.hideout, player.current_map_name_utf8) or 
            string.find(player.current_map_name_utf8, "town") then
                poe2_api.dbgp("在安全区域，跳过检查")
                return bret.SUCCESS
            end
            
            -- 处理常规恢复
            local regular_status = _handle_regular_recovery(player, prot, start_time)
            if regular_status ~= bret.SUCCESS then
                poe2_api.dbgp("常规恢复处理返回:", regular_status)
                return regular_status
            end

            poe2_api.time_p("CheckLowHpMp_Otherworld... 耗时 --> ", api_GetTickCount64() - start_time)
            return bret.SUCCESS
        end
    },

    -- 检查是否在主页面
    Not_Main_Page = {
        run = function(self, env)
            poe2_api.print_log("检查是否在主页面...")
            local strat_time = api_GetTickCount64()

            local current_map_info = env.current_map_info
            local player_info = env.player_info
            if not self.time1 or self.time1 == 0 then
                self.time1 = api_GetTickCount64()
                self.exit_time = nil
                self.life_time = 0
            end
            local ctime = strat_time - self.time1
            if ctime > 120 * 1000 and player_info.life > 0 then
                env.is_timeout_exit = true
                self.time1 = 0
            elseif player_info.life == 0 then
                self.time1 = 0
            end
            local function have_roman_number()
                local ROMAN_NUMERALS = {
                    "I", "II", "III", "IV", "V",
                    "VI", "VII", "VIII", "IX", "X",
                    "XI", "XII", "XIII", "XIV", "XV", "XVI"
                }
                if poe2_api.find_text({ UI_info = env.UI_info, text = ROMAN_NUMERALS, min_x = 520, min_y = 420, max_x = 560, max_y = 470 }) then
                    return true
                else
                    return false
                end
            end
            if poe2_api.find_text({ UI_info = env.UI_info, text = "你的天賦樹", min_x = 0 }) then
                api_Sleep(500)
                api_ClickScreen(800,510,1)
                return bret.RUNNING
            end
            if player_info and player_info.current_map_name_utf8 == 'G1_1' then
                poe2_api.dbgp("当前地图为G1_1，开始检查教学提示")
                
                -- 检查使用新技能提示
                if poe2_api.find_text({UI_info = env.UI_info, text = "按下<normal>{<n>{W}}來使用你的新技能"}) or 
                   poe2_api.find_text({UI_info = env.UI_info, text = "按下<normal>{<n>{滑鼠左鍵}}來使用你的新技能"}) then
                    poe2_api.dbgp("找到使用新技能提示，按下w键")
                    poe2_api.click_keyboard('w')
                end
                
                -- 检查躲避攻击提示
                if poe2_api.find_text({UI_info = env.UI_info, text = "按下<normal>{<n>{空白鍵}}躲避攻擊", min_x = 0}) then
                    poe2_api.dbgp("找到躲避攻击提示，按下空格键")
                    poe2_api.click_keyboard("space")
                end
                
                -- 检查跳过教学提示
                if poe2_api.find_text({UI_info = env.UI_info, text = "略過教學"}) then
                    poe2_api.dbgp("找到跳过教学提示，点击跳过")
                    poe2_api.find_text({UI_info = env.UI_info, text = "略過教學", click = 2, min_x = 0})
                    return bret.RUNNING
                end
                
                -- 检查开启天赋树提示
                if poe2_api.find_text({UI_info = nil, text = "開啟天賦樹畫面"}) then
                    poe2_api.dbgp("找到开启天赋树提示")
                    -- 如果没有跳过教学提示，则按ESC
                    if not poe2_api.find_text({UI_info = nil, text = "略過教學", min_x = 0}) then
                        poe2_api.dbgp("按ESC键关闭提示")
                        poe2_api.click_keyboard("esc")
                        poe2_api.sleep(2000)
                        poe2_api.infos_time(current_time, self.name)
                        return bret.RUNNING
                    end
                end
            end
            -- 大号，小号更新障碍
            if poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) == "大號名" then
                if not poe2_api.table_contains(player_info.current_map_name_utf8, { "G2_3","G3_17"}) or poe2_api.find_text({ UI_info = env.UI_info, text = "競技場", min_x = 0 }) then
                    if player_info.current_map_name_utf8 == "G2_2" then
                        api_UpdateMapObstacles(180)
                    else
                        api_UpdateMapObstacles(100)
                    end
                end
            else
                if not poe2_api.table_contains(player_info.current_map_name_utf8, { "G1_12" }) then
                    api_UpdateMapObstacles(100)
                end
            end

            local click_2 = { "接受任務", "繼續" }
            if poe2_api.find_text({ UI_info = env.UI_info, text = click_2, click = 2 }) then
                api_Sleep(500) -- Equivalent to api_Sleep(500)
                return bret.RUNNING
            end
            -- 检查交易拒绝情况
            local refuse_click = { "等待玩家接受交易請求..." }
            if poe2_api.find_text({ UI_info = env.UI_info, text = refuse_click, min_x = 0, add_x = 253, click = 2 }) then
                poe2_api.dbgp("检测到交易请求等待，将执行拒绝操作")
                return bret.RUNNING
            end

            -- 传送确认遮挡
            if poe2_api.find_text({ UI_info = env.UI_info, text = "你確定要傳送至此玩家的位置？" }) then
                api_ClickScreen(916, 467, 0)
                api_Sleep(500)
                api_ClickScreen(916, 467, 1)
                api_Sleep(500)
                self.life_time = 0
                return bret.RUNNING
            end

            -- 世界地图遮挡
            if poe2_api.find_text { UI_info = env.UI_info, text = "世界地圖", min_x = 0, add_x = 215, click = 2 } then
                return bret.RUNNING
            end

            -- 检查点遮挡
            local a = poe2_api.get_game_control_by_rect({UI_info = env.UI_info,min_x = 985,min_y = 5,max_x = 1034,max_y = 47})
            if poe2_api.find_text({UI_info = env.UI_info, text="記錄點", add_x = 213, max_y = 50}) and a and next(a) then
                poe2_api.find_text({UI_info = env.UI_info, text="記錄點", click=2, add_x = 213, max_y = 50})
                return bret.RUNNING
            end

            -- 领取任务奖励
            if poe2_api.find_text({ UI_info = env.UI_info, text = "獎勵", min_x = 100 }) then
                poe2_api.dbgp("领取任务奖励")
                if player_info.current_map_name_utf8 == "G4_4_2" then
                    poe2_api.find_text({ UI_info = env.UI_info, text = "獎勵", min_x = 100, add_x = 50,add_y = 100 , click = 2 })
                else
                    poe2_api.find_text({ UI_info = env.UI_info, text = "獎勵", min_x = 100, add_y = 100, click = 2 })
                end
                api_Sleep(500)
                if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                    if have_roman_number() then
                        poe2_api.get_space_point({ width = 1, height = 1, click = 1 })
                    else
                        poe2_api.get_space_point({ width = 4, height = 2, click = 1 })
                    end
                    return bret.RUNNING
                else
                    poe2_api.dbgp("打開背包")
                    poe2_api.click_keyboard("i")
                    return bret.RUNNING
                end
            end

            -- 团队队友死亡长时间未救其它小号处理
            local function count_gravestones(map_info)
                if not map_info or #map_info == 0 then
                    return 0
                end
                local count = 0
                for _, obj in ipairs(map_info) do
                    if obj.name_utf8 == "PlayerGravestone" then
                        count = count + 1
                    end
                end
                return count
            end
            if count_gravestones(current_map_info) == 0 then
                if not env.is_timeout and not env.is_timeout_exit then
                    if poe2_api.find_text({ UI_info = env.UI_info, text = "回到角色選擇畫面" }) then
                        poe2_api.click_keyboard("space")
                    end
                end
                self.life_time = 0
                env.is_timeout = false
            elseif count_gravestones(current_map_info) > 0 and poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) ~= "大號名" and player_info.life > 0 and player_info.isInBossBattle and not poe2_api.is_have_mos({ range_info = env.range_info, player_info = player_info }) then
                if self.life_time == 0 then
                    self.life_time = api_GetTickCount64()
                end
                if api_GetTickCount64() - self.life_time > 90 * 1000 and poe2_api.table_contains(player_info.current_map_name_utf8, { "G1_15", "C_G1_15" }) then
                    if not poe2_api.find_text({ UI_info = env.UI_info, text = "回到角色選擇畫面" }) then
                        poe2_api.click_keyboard("esc")
                        env.is_timeout = true
                    end
                    api_Sleep(500)
                    return bret.RUNNING
                end
            end

            -- 不在城镇
            if not string.find(player_info.current_map_name_utf8, "own") then
                -- 超时记录点重生
                if env.is_timeout and poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) == "大號名" then
                    if poe2_api.click_text_UI({ UI_info = env.UI_info, text = "respawn_at_checkpoint_button", refresh = true }) then
                        poe2_api.find_text({ UI_info = env.UI_info, text = "在記錄點重生", min_x = 0, click = 2 })
                        api_Sleep(500)
                        poe2_api.find_text({ UI_info = env.UI_info, text = "確認", min_x = 0, click = 2, refresh = true })
                        api_Sleep(500)
                        env.end_point = nil
                        env.is_arrive_end = false
                        env.path_list = {}
                        env.target_point = nil
                        env.is_timeout = false
                    else
                        poe2_api.click_keyboard("esc")
                        api_Sleep(500)
                        return bret.RUNNING
                    end
                end

                -- 小退
                if env.is_timeout_exit then
                    if self.exit_time then
                        if strat_time - self.exit_time > 30 * 1000 then
                            poe2_api.print_log("小退超时")
                            env.error_kill = true
                            self.exit_time = nil -- 重置计时器
                        elseif poe2_api.find_text({ text = "開始遊戲", UI_info = env.UI_info, click = 2 }) and poe2_api.find_text({ text = "建立角色", UI_info = env.UI_info, click = 2 }) then
                            self.exit_time = nil
                            env.error_kill = false
                            env.is_timeout_exit = false
                        end
                    end
                    if poe2_api.find_text({ UI_info = env.UI_info, text = "回到角色選擇畫面", click = 2 }) then
                        if not self.exit_time then
                            self.exit_time = strat_time --# 开始计时
                        end
                        api_Sleep(6000)
                        return bret.RUNNING
                    elseif poe2_api.click_text_UI({ UI_info = env.UI_info, text = "exit_to_character_selection", click = 1, index = 1 }) then
                        if not self.exit_time then
                            self.exit_time = strat_time
                        end
                        api_Sleep(6000)
                        return bret.RUNNING
                    end
                    -- # 打开选项菜单
                    if not (poe2_api.find_text({ UI_info = env.UI_info, text = "回到角色選擇畫面" }) or
                            poe2_api.click_text_UI({ UI_info = env.UI_info, text = "exit_to_character_selection" })) and
                        poe2_api.click_text_UI({ UI_info = env.UI_info, text = "life_orb" }) and
                        poe2_api.click_text_UI({ UI_info = env.UI_info, text = "mana_orb" }) then
                        if not self.exit_time then
                            self.exit_time = strat_time
                        end
                        poe2_api.click_keyboard("esc")
                        return bret.RUNNING
                    end
                end

                -- 回城
                if env.back_city then
                    poe2_api.dbgp("回城操作")
                    for _, name in ipairs(my_game_info.city_map) do
                        if poe2_api.find_text({ UI_info = env.UI_info, text = name, click = 2 }) then
                            if string.find(player_info.current_map_name_utf8, "own") then
                                env.back_city = false
                                return bret.RUNNING
                            end
                        end
                    end
                    api_ClickScreen(1230, 815, 0)
                    api_Sleep(500)
                    api_ClickScreen(1230, 815, 1)
                    api_Sleep(2000)
                    return bret.RUNNING
                end
            else
                env.is_timeout = false
                env.back_city = false
                env.is_timeout_exit = false
            end

            -- 城镇遮挡
            if player_info and string.find(player_info.current_map_name_utf8, "own") then
                

                if poe2_api.find_text({ UI_info = env.UI_info, text = "你無法將此道具丟置於此。請問要摧毀它嗎？", min_x = 0, min_y = 0 }) then
                    poe2_api.find_text({ UI_info = env.UI_info, text = "保留", min_x = 0, min_y = 0, click = 2 })
                    return bret.RUNNING
                end
                if poe2_api.find_text({ UI_info = env.UI_info, text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片", min_x = 0 }) then
                    poe2_api.click_keyboard('space')
                    return bret.RUNNING
                end
                local item = api_Getinventorys(0xd, 0)
                if item and #item > 0 then
                    local point = poe2_api.get_space_point({
                        width = item[1].end_x - item[1].start_x,
                        height = item[1]
                            .end_y - item[1].start_y
                    })
                    if point then
                        if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                            api_ClickScreen(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]), 1)
                            api_Sleep(500)
                            return bret.RUNNING
                        else
                            poe2_api.click_keyboard("i")
                            return bret.RUNNING
                        end
                    end
                end
            end
            self.time1 = 0
            poe2_api.time_p("Not_Main_Page 耗时 -->", api_GetTickCount64() - strat_time)
            return bret.SUCCESS
        end
    },

    -- 设置基础技能
    Set_Base_Skill = {
        run = function(self, env)
            poe2_api.print_log("设置基础技能...")
            poe2_api.dbgp("设置基础技能...")
            local start_time = api_GetTickCount64()

            if not self.is_initialized then
                poe2_api.dbgp("初始化设置基础技能")
                self.bool = false  -- 初始化时间戳
                self.bool1 = false
                self.is_initialized = true
            end

            local skill_location = function(skill_name, skill_pos, selectable_skills)
                if not selectable_skills then
                    return false
                end
                -- 获取指定位置
                poe2_api.dbgp("skill_location", skill_name, skill_pos, selectable_skills)
                local point = my_game_info.skill_pos[skill_pos]
                -- 将所有 text_utf8 属性的值存储在一个集合中
                local skill_names = {}
                for _, skill_control in ipairs(selectable_skills) do
                    if skill_control.text_utf8 then
                        skill_names[skill_control.text_utf8] = true
                    end
                end
                
                -- 检查 skill_name 是否在集合中
                if not skill_names[skill_name] then
                    return false
                end
                
                -- 遍历所有可选择的技能控件
                for _, skill_control in ipairs(selectable_skills) do
                    if skill_name == skill_control.text_utf8 then
                        -- 计算中间位置
                        local center_x = (skill_control.left + skill_control.right) / 2
                        local center_y = (skill_control.top + skill_control.bottom) / 2
                        
                        -- 检查位置是否在指定范围内
                        if point[1] - 5 < center_x and center_x < point[1] + 5 and 
                        point[2] - 5 < center_y and center_y < point[2] + 5 then
                            return true
                        end
                    end
                end
                return false
            end

            local get_move_skill = function(selectable_skills)
                poe2_api.dbgp("get_move_skill", selectable_skills)
                if not skill_location("", "MIDDLE", selectable_skills) then
                    return false
                end
                return true
            end
            
            local set_pos = function(skill_name, rom_x, rom_y, selectable_skills)
                poe2_api.dbgp("set_pos", skill_name, rom_x, rom_y, selectable_skills)
                if not selectable_skills then
                    return false
                end
                for _, k in ipairs(selectable_skills) do
                    if 1104 <= k.left and k.left <= 1597 and k.bottom <= 770 and skill_name == k.text_utf8 then
                        local center_x = (k.left + k.right) / 2 + rom_x
                        local center_y = (k.top + k.bottom) / 2 + rom_y
                        api_ClickScreen(math.floor(center_x), math.floor(center_y),1)
                        api_Sleep(500)
                        return true
                    end
                end
                return false
            end
            
            local cancel_left_skill = function(selectable_skills)
                poe2_api.dbgp("cancel_left_skill", selectable_skills)
                if not selectable_skills then
                    return false
                end
                for _, k in ipairs(selectable_skills) do
                    if 1277 <= k.left and k.left <= 1285 and k.top > 790 and k.bottom <= 832 and k.right < 1316 then
                        return true
                    end
                end
                return false
            end

            if not env.mouse_check then
                poe2_api.dbgp("mouse_check", mouse_check)
                poe2_api.time_p("mouse_check... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end

            if poe2_api.find_text({UI_info = env.UI_info, text = "繼續遊戲", click = 2}) then
                poe2_api.dbgp("发现'繼續遊戲'文本，点击处理中...")
                return bret.RUNNING
            end

            if not (poe2_api.click_text_UI({UI_info = env.UI_info, text = "life_orb"})
             or poe2_api.click_text_UI({UI_info = env.UI_info, text = "resume_game"})
             or poe2_api.find_text({UI_info = env.UI_info, text = "清單",min_x = 0,min_y = 0,max_x = 400})) then
                poe2_api.print_log("未找到游戏界面")
                return bret.RUNNING
            end
            poe2_api.dbgp("获取技能")
            local selectable_skills = api_GetSelectableSkillControls()
            local allskill_info = api_GetAllSkill()
            local skill_slots = api_GetSkillSlots()
            -- poe2_api.dbgp("1111")
            -- poe2_api.printTable(selectable_skills)
            -- poe2_api.dbgp("2222")
            -- poe2_api.printTable(allskill_info)
            -- poe2_api.dbgp("3333")
            -- poe2_api.printTable(skill_slots)
            
            if not selectable_skills then
                poe2_api.print_log("获取可选技能技能控件信息失败")
                return bret.RUNNING
            end
            if not allskill_info then
                poe2_api.print_log("获取全部技能信息失败")
                return bret.RUNNING
            end
            if not skill_slots then
                poe2_api.print_log("获取快捷栏技能信息失败")
                return bret.RUNNING
            end
            self.bool = cancel_left_skill( selectable_skills)
            self.bool1 = get_move_skill(selectable_skills)
            poe2_api.print_log("self.bool",self.bool)
            if not self.bool1 then
                poe2_api.dbgp("未设鼠标中键")
                if not set_pos("", 0, 0, selectable_skills) then
                    local point = my_game_info.skill_pos["MIDDLE"]
                    api_ClickScreen(math.floor(point[1]), math.floor(point[2]),1)
                    api_Sleep(500)
                end
                return bret.RUNNING
            end
            
            if self.bool then
                poe2_api.dbgp("取消鼠标左键技能")
                if not set_pos('', 50, 0, selectable_skills) then
                    local point = my_game_info.skill_pos["P"]
                    api_ClickScreen(math.floor(point[1]), math.floor(point[2]),1)
                    api_Sleep(500)
                end
                return bret.RUNNING
            end
            poe2_api.time_p("检查基础技能... 耗时 --> ", api_GetTickCount64() - start_time)
            env.mouse_check = false
            return bret.SUCCESS
        end
    },

    -- 使用任务道具
    Use_Task_Props = {
        run = function(self, env)
            poe2_api.print_log("使用任务道具...")
            poe2_api.dbgp("使用任务道具")
            local bag_info = env.bag_info
            local player_info = env.player_info
            local function is_props(bag)
                local QUEST_PROPS = {
                    "知識之書", "火焰核心", "寶石花顱骨", "寶石殼顱骨",
                    "專精之書", "凜冬狼的頭顱", "燭光精髓", "傑洛特顱骨",
                }
                for _, item in ipairs(bag) do
                    if item.baseType_utf8 and item.category_utf8 then
                        if poe2_api.table_contains(QUEST_PROPS, item.baseType_utf8) and item.category_utf8 == "QuestItem" then
                            return item
                        end
                        if  not string.find(item.baseType_utf8, "空白刺青") and string.find(item.baseType_utf8, "刺青") and item.category_utf8 == "QuestItem" then
                            return item
                        end
                    end
                end
                return nil
            end
            if bag_info and next(bag_info) then
                local props = is_props(bag_info)
                if (poe2_api.check_item_in_inventory("寶石花顱骨", bag_info) or poe2_api.check_item_in_inventory("寶石殼顱骨", bag_info) or poe2_api.check_item_in_inventory("傑洛特顱骨", bag_info)) and not string.find(player_info.current_map_name_utf8, "own") then
                    return bret.SUCCESS
                end
                if props and next(props) then
                    if not poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                        poe2_api.click_keyboard("i")
                        return bret.RUNNING
                    end
                    local point = poe2_api.get_center_position({ props.start_x, props.start_y },
                        { props.end_x, props.end_y })
                    if next(point) then
                        poe2_api.right_click(point[1], point[2])
                        return bret.RUNNING
                    end
                end
            end
            return bret.SUCCESS
        end
    },

    -- 是否存储物品
    Is_Store_Items = {
        run = function(self, env)
            poe2_api.print_log("是否存储...")
            local config = env.user_config
            local map_config = config['刷圖設置']["地圖鑰匙"]
            local altar_shop_config = config['刷圖設置']["祭祀購買"]
            -- local dist_ls = config['刷圖設置']['異界地圖']['涂油设置']
            local not_use_map = env.not_use_map
            local user_map = env.user_map
            local priority_map = env.priority_map
            local player_info = env.player_info
            local items_info = poe2_api.get_items_config_info(config)
            local current_map = api_GetTickCount64()
            -- 不在城区
            if not string.match(player_info.current_map_name_utf8, "own") then
                env.not_exist_stone = {}
                env.is_get_plaque_node = true
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            -- 判断两个键值对表是否相等
            local function deep_equal_unordered_full(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end

                -- 检查所有键值对（包括非数字键）
                local visited = {}
                for k, v in pairs(a) do
                    if not deep_equal_unordered_full(v, b[k]) then
                        return false
                    end
                    visited[k] = true
                end

                -- 检查 b 中有没有 a 没有的键
                for k, _ in pairs(b) do
                    if not visited[k] then
                        return false
                    end
                end

                return true
            end
            local function get_object(name, data_list)
                for _, v in ipairs(data_list) do
                    if v.name_utf8 == name and v.grid_x ~= 0 and v.grid_y ~= 0 then
                        if v.flagStatus and v.flagStatus == 0 and v.flagStatus1 == 1 then
                            poe2_api.dbgp("get_object 找到匹配对象(flagStatus):", v)
                            return v
                        end
                        if v.life and v.is_selectable then
                            poe2_api.dbgp("get_object 找到匹配对象(life):", v)
                            return v
                        end
                    end
                end
                poe2_api.dbgp("get_object: 未找到匹配对象")
                return false
            end
            -- 词条过滤
            local function match_item_suffixes(item_suffixes, config_suffixes)
                if not item_suffixes or not next(item_suffixes) then
                    return false
                end
                if not config_suffixes or not next(config_suffixes) then
                    return false
                end
                for _, v in ipairs(item_suffixes) do
                    for _, v1 in ipairs(config_suffixes) do
                        if v.name_utf8 == v1 then
                            return true
                        end
                    end
                end
                return false
            end
            -- 祭祀购买是否配置了存储页
            local function is_not_altar_shop(item)
                local text = poe2_api.get_item_type(item)
                poe2_api.print_log("祭祀购买物品类型:" .. text)
                local item_key = ""
                if text ~= "" then
                    item_key = text
                else
                    poe2_api.dbgp("999999999999999999")
                    poe2_api.dbgp("item.category_utf8:" .. item.category_utf8)
                    for k, v in pairs(my_game_info.type_conversion) do
                        -- poe2_api.dbgp("k:"..k.." v:"..v)
                        if item.category_utf8 == v then
                            item_key = k
                            break
                        end
                    end
                end
                poe2_api.dbgp("item_key:" .. type(item_key))
                if item_key and item_key ~= "" then
                    local item_type_list = {}
                    for _, v in ipairs(items_info) do
                        poe2_api.dbgp("type(v):" .. v['類型'])

                        if v['類型'] == item_key then
                            poe2_api.dbgp("10101010101")
                            table.insert(item_type_list, v)
                        end
                    end

                    if item_type_list and next(item_type_list) then
                        for _, v in ipairs(item_type_list) do
                            if not v["不撿"] then
                                if v['基礎類型名'] == "全部物品" or string.find(v['基礎類型名'], item.baseType_utf8) then
                                    return true
                                end
                            end
                        end
                    end
                else
                    error("物品名称:" .. item.name_utf8 .. "新物品类型:" .. item.category_utf8 .. "请联系我们添加，感谢您的支持")
                end
                return false
            end
            -- 背包排序
            local function get_store_bag_info(bag)
                local function item_save_as1(goods, cfg_object)
                    local satisfy = {}
                    for _, v in ipairs(items_info) do
                        if not v["不撿"] and v["存倉頁名"] and v["存倉頁名"] ~= "" and string.find(v["基礎類型名"], goods.baseType_utf8) then
                            table.insert(satisfy, v)
                        end
                    end
                    if next(satisfy) then
                        for _, v in ipairs(satisfy) do
                            if not deep_equal_unordered_full(v, cfg_object) then
                                if v["工會倉庫"] then
                                    return 1
                                else
                                    return 2
                                end
                            end
                        end
                    end
                    return false
                end
                local store_bag = {}
                local store_bag1 = {}
                local store_bag2 = {}
                for _, v in ipairs(bag) do
                    for _, item in ipairs(items_info) do
                        if poe2_api.match_item(v, item, 1) and not item["工會倉庫"] and not item["不撿"] then
                            local a = item_save_as1(v, item)
                            if a then
                                if a == 1 then
                                    table.insert(store_bag2, v)
                                    break
                                end
                            end
                            table.insert(store_bag1, v)
                        elseif poe2_api.match_item(v, item, 1) and item["工會倉庫"] and not item["不撿"] then
                            local a = item_save_as1(v, item)
                            if a then
                                if a == 2 then
                                    table.insert(store_bag1, v)
                                    break
                                end
                            end
                            table.insert(store_bag2, v)
                        end
                    end
                end
                poe2_api.dbgp("store_bag1:" .. #store_bag1)
                poe2_api.dbgp("store_bag2:" .. #store_bag2)
                for _, v in ipairs(store_bag1) do
                    table.insert(store_bag, v)
                end

                for _, v in ipairs(store_bag2) do
                    table.insert(store_bag, v)
                end

                return store_bag
            end
            -- 判断是否需要存储
            local function get_store_item(bag, is_insert_stone, unique_storage_pages, public_warehouse_pages,
                                          map_ys_level_min)
                -- 获取背包中的地图钥匙
                local function get_map_number()
                    local items = {}
                    for _, item in ipairs(bag) do
                        if item.category_utf8 == "Map" then
                            table.insert(items, item)
                        end
                    end
                    if items and next(items) then
                        return items
                    end
                    return false
                end

                -- 获取背包中不打等级的地图钥匙
                local function get_map_not_level()
                    local map = get_map_number()
                    if map then
                        local tiers = {}
                        for _, v in ipairs(map_config) do
                            table.insert(tiers, tonumber(v["階級"]))
                        end
                        if tiers and next(tiers) then
                            for _, v1 in ipairs(map) do
                                if not poe2_api.table_contains(poe2_api.extract_level(v1.baseType_utf8), tiers) then
                                    return v1
                                end
                            end
                        end
                    end
                    return false
                end
                -- 获取背包中不打词条的地图钥匙
                local function get_map_not_entry()
                    local map = get_map_number()
                    if map then
                        for _, item in ipairs(map) do
                            if item.color > 0 and not item.not_identified and match_item_suffixes(api_GetObjectSuffix(item.mods_obj), not_use_map) then
                                return item
                            end
                        end
                    end
                    return false
                end
                -- 找不是疯癫的地图
                local function get_map_not_crazy()
                    local map = get_map_number()
                    local max_map = poe2_api.select_best_map_key({
                        inventory = bag,
                        key_level_threshold = user_map,
                        not_use_map =
                            not_use_map,
                        priority_map = priority_map
                    })
                    if max_map then
                        local max_map_level = poe2_api.extract_level(max_map.baseType_utf8)
                        local is_oiled = nil
                        for _, v in ipairs(map_config) do
                            if v["階級"] == max_map_level then
                                is_oiled = v["塗油設置"]["是否塗油"]
                            end
                        end
                        if is_oiled then
                            local function is_crazy(item)
                                local item_entry = api_GetObjectSuffix(item.mods_obj)
                                if item_entry and next(item_entry) then
                                    for _, entry in ipairs(item_entry) do
                                        if string.find(entry.name_utf8, "譫妄") then
                                            -- table.insert()
                                            return true
                                        end
                                    end
                                end
                            end
                            for _, v in ipairs(map) do
                                if not is_crazy(v) then
                                    if v.obj ~= max_map.obj then
                                        return v
                                    end
                                end
                            end
                        end
                    end
                    return false
                end

                -- 是否另存为
                local function item_save_as(goods, cfg_object)
                    local satisfy = {}
                    for _, v in ipairs(items_info) do
                        if not v["不撿"] and v["存倉頁名"] and v["存倉頁名"] ~= "" and string.find(v["基礎類型名"], goods.baseType_utf8) then
                            table.insert(satisfy, v)
                        end
                    end
                    if satisfy and next(satisfy) then
                        for _, v in ipairs(satisfy) do
                            if not deep_equal_unordered_full(v, cfg_object) then
                                if v["工會倉庫"] then
                                    return { goods, v["存倉頁名"], 1 }
                                else
                                    return { goods, v["存倉頁名"], 0 }
                                end
                            end
                        end
                    end
                    return false
                end
                -- 判断是否设置了词缀
                local function is_valid_affix(affix)
                    return affix and (affix["name"] and affix.name ~= "")
                end
                local function get_ct_config(object_cfg)
                    local affixes = object_cfg["物品詞綴"] or {}
                    for _, affix_group in pairs(affixes) do
                        if affix_group and type(affix_group) == "table" then
                            local affix_list = affix_group["詞綴"]
                            if affix_list then
                                for _, affix in ipairs(affix_list) do
                                    if is_valid_affix(affix) then
                                        -- poe2_api.dbgp("找到有效詞綴："..affix.name)
                                        return true
                                    end
                                end
                            end
                        end
                    end
                    return false
                end
                local min_map = poe2_api.select_best_map_key({
                    inventory = bag,
                    index = 1,
                    no_categorize_suffixes = 1,
                    min_level =
                        map_ys_level_min,
                    trashest = true
                })

                if unique_storage_pages and next(unique_storage_pages) then
                    for _, i in ipairs(unique_storage_pages) do
                        for _, b in ipairs(bag) do
                            -- poe2_api.dbgp("b.baseType_utf8:"..b.baseType_utf8)
                            for _, item in ipairs(items_info) do
                                if poe2_api.match_item(b, item, 1) and item["存倉頁名"] == i and not item["工會倉庫"] and not item["不撿"] then
                                    if ((item["名稱"] and item["名稱"] ~= "" and item["名稱"] ~= "全部物品") or get_ct_config(item)) and b.not_identified then
                                        poe2_api.dbgp("1")
                                        break
                                    end
                                    if b.baseType_utf8 == "知識卷軸" then
                                        break
                                    end
                                    if b.category_utf8 ~= "StackableCurrency" and poe2_api.is_do_without_pick_up(b, items_info) then
                                        poe2_api.dbgp("2")
                                        break
                                    end
                                    if b.category_utf8 == "QuestItem" then
                                        poe2_api.dbgp("3")
                                        break
                                    end
                                    if b.category_utf8 == "Map" then
                                        local map_not_level = get_map_not_level()
                                        if map_not_level then
                                            env.store_item = { map_not_level, i, 0 }
                                            poe2_api.dbgp("4")
                                            return true
                                        end
                                        if b.color > 0 then
                                            if not_use_map then
                                                local not_entry = get_map_not_entry()
                                                if not_entry then
                                                    env.store_item = { not_entry, i, 0 }
                                                    poe2_api.dbgp("5")
                                                    return true
                                                end
                                            end
                                        end
                                        local crazy = get_map_not_crazy()
                                        if crazy then
                                            env.store_item = { crazy, i, 0 }
                                            poe2_api.dbgp("7")
                                            return true
                                        end
                                        if min_map and b.obj ~= min_map.obj then
                                            poe2_api.dbgp("8")
                                            break
                                        end
                                    end
                                    if is_insert_stone then
                                        if b.category_utf8 == "TowerAugmentation" and env.is_get_plaque then
                                            poe2_api.dbgp("9")
                                            break
                                        end
                                    end
                                    if poe2_api.table_contains(b.category_utf8, my_game_info.equip_type) and b.color > 0 and not b.not_identified then
                                        local suffixes = api_GetObjectSuffix(b.mods_obj)
                                        if suffixes and next(suffixes) and not poe2_api.filter_item(b, suffixes, config["物品過濾"]) then
                                            poe2_api.dbgp("10")
                                            break
                                        end
                                    end
                                    local save_as = item_save_as(b, item)
                                    if save_as and next(save_as) then
                                        env.store_item = save_as
                                        poe2_api.dbgp("11")
                                        return true
                                    end
                                    env.store_item = { b, i, 0 }
                                    return true
                                end
                            end
                        end
                    end
                end
                if public_warehouse_pages and next(public_warehouse_pages) then
                    for _, i in ipairs(public_warehouse_pages) do
                        for _, b in ipairs(bag) do
                            for _, item in ipairs(items_info) do
                                if poe2_api.match_item(b, item, 1) and item["存倉頁名"] == i and item["工會倉庫"] and not item["不撿"] then
                                    if ((item["名稱"] and item["名稱"] ~= "" and item["名稱"] ~= "全部物品") or get_ct_config(item)) and b.not_identified then
                                        break
                                    end
                                    if b.baseType_utf8 == "知識卷軸" then
                                        break
                                    end
                                    if b.category_utf8 ~= "StackableCurrency" and poe2_api.is_do_without_pick_up(b, items_info) then
                                        break
                                    end
                                    if b.category_utf8 == "QuestItem" then
                                        break
                                    end
                                    if b.category_utf8 == "Map" then
                                        local map_not_level = get_map_not_level()
                                        if map_not_level then
                                            env.store_item = { map_not_level, i, 1 }
                                            return true
                                        end
                                        if b.color > 0 then
                                            if not_use_map then
                                                local not_entry = get_map_not_entry()
                                                if not_entry then
                                                    env.store_item = { not_entry, i, 1 }
                                                    return true
                                                end
                                            end
                                        end
                                        local crazy = get_map_not_crazy()
                                        if crazy then
                                            env.store_item = { crazy, i, 1 }
                                            return true
                                        end
                                        if min_map and b.obj ~= min_map.obj then
                                            break
                                        end
                                    end
                                    if is_insert_stone then
                                        if b.category_utf8 == "TowerAugmentation" and env.is_get_plaque then
                                            break
                                        end
                                    end
                                    if poe2_api.table_contains(b.category_utf8, my_game_info.equip_type) and b.color > 0 and not b.not_identified then
                                        local suffixes = api_GetObjectSuffix(b.mods_obj)
                                        if suffixes and next(suffixes) and not poe2_api.filter_item(b, suffixes, config["物品過濾"]) then
                                            break
                                        end
                                    end
                                    local save_as = item_save_as(b, item)
                                    if save_as and next(save_as) then
                                        env.store_item = save_as
                                        return true
                                    end
                                    env.store_item = { b, i, 1 }
                                    return true
                                end
                            end
                        end
                    end
                end
                return false
            end
            local player_info = env.player_info
            local bag_info = env.bag_info
            local current_map_info = env.current_map_info
            -- 没有人物信息
            if not next(player_info) then
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.RUNNING
            end
            if not get_object("倉庫", env.range_info) then
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            -- 是否需要合成
            if env.is_need_strengthen then
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            -- 背包为空
            if not bag_info or not next(bag_info) then
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            -- 是否需要点金
            if not env.is_public_warehouse then
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            -- 碑牌是否需要点金
            if not env.is_public_warehouse_plaque then
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            local items_info = poe2_api.get_items_config_info(config)
            local unique_storage_pages = {}
            for _, v in ipairs(items_info) do
                if v['存倉頁名'] and v['存倉頁名'] ~= "" and not v['工會倉庫'] and not v["不撿"] then
                    table.insert(unique_storage_pages, v['存倉頁名'])
                end
            end

            local public_warehouse_pages = {}
            for _, v in ipairs(items_info) do
                if v['存倉頁名'] and v['存倉頁名'] ~= "" and v['工會倉庫'] and not v["不撿"] then
                    table.insert(public_warehouse_pages, v['存倉頁名'])
                end
            end
            -- 未配置物品过滤
            if (not unique_storage_pages or not next(unique_storage_pages)) and (not public_warehouse_pages or not next(public_warehouse_pages)) then
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            local map_level_type = {}
            local map_ys_level_min = 0
            for _, v in ipairs(items_info) do
                if string.find(v["類型"], "地圖鑰匙") and not v["不撿"] then
                    table.insert(map_level_type, v['等級'])
                end
            end
            if next(map_level_type) then
                local map_type = map_level_type[1]["type"]
                if map_type == "exact" then
                    local item_level = map_level_type[1]["value"]
                    map_ys_level_min = item_level - 3
                else
                    local min_level = map_level_type[1]["min"]
                    map_ys_level_min = min_level
                end
            end
            -- 是否需要插入碑牌
            local is_insert_stone = env.is_insert_stone
            local bag_store_info = get_store_bag_info(bag_info)
            -- poe2_api.dbgp("bag_store_info",type(bag_store_info),#bag_store_info)
            local store = get_store_item(bag_store_info, is_insert_stone, unique_storage_pages, public_warehouse_pages,
                map_ys_level_min)

            if not store then
                -- poe2_api.dbgp("ooooooooooooooo")
                local not_config_altar_item = nil
                for _, v in ipairs(bag_info) do
                    if poe2_api.table_contains(altar_shop_config, v.baseType_utf8) then
                        not_config_altar_item = v
                    end
                end
                if not_config_altar_item then
                    if not is_not_altar_shop(not_config_altar_item) then
                        local text = poe2_api.get_item_type(not_config_altar_item)
                        local item_key = ""
                        if text ~= "" then
                            item_key = text
                        else
                            for k, v in ipairs(my_game_info.type_conversion) do
                                if not_config_altar_item.category_utf8 == v then
                                    item_key = k
                                    break
                                end
                            end
                        end
                        error("未配置购物祭祀物品：->" ..
                            not_config_altar_item.name_utf8 .. "<-,物品类型为:->" .. item_key .. "<-,相关存储页请在物品配置中添加")
                    end
                end
                env.exchange_status = false
                if poe2_api.find_text({ UI_info = env.UI_info, text = "強調物品", min_y = 700, min_x = 250 }) then
                    poe2_api.click_keyboard('space')
                    api_Sleep(500)
                end
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.SUCCESS
            end
            poe2_api.find_text({ text = "再會", UI_info = env.UI_info, click = 2 })
            if poe2_api.find_text({ text = { '重鑄台' }, UI_info = env.UI_info, min_x = 0 }) and poe2_api.find_text({ text = '摧毀三個相似的物品，重鑄為一個新的物品', UI_info = env.UI_info, min_x = 0 }) then
                poe2_api.click_keyboard('space')
                api_Sleep(500)
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.RUNNING
            end
            -- if poe2_api.find_text({text = {'世界地圖',"購買或販賣物品"}, UI_info=env.UI_info,min_x=0}) then
            if poe2_api.find_text({ text = { '世界地圖' }, UI_info = env.UI_info, min_x = 0 }) then
                -- poe2_api.dbgp("999999999999999999999999999999999999999999")
                poe2_api.click_keyboard('space')
                api_Sleep(500)
                poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                return bret.RUNNING
            end
            local store_item = env.store_item
            poe2_api.dbgp("store_item", store_item[1].baseType_utf8, store_item[3])
            -- api_Sleep(5000)
            if store_item[3] == 0 then
                if poe2_api.find_text({ UI_info = env.UI_info, text = "強調物品", min_y = 700, min_x = 250 }) and poe2_api.find_text({ UI_info = env.UI_info, text = "公會倉庫", min_x = 0, min_y = 32, max_x = 381, max_y = 81 }) then
                    poe2_api.click_keyboard('space')
                    api_Sleep(500)
                    poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                    return bret.RUNNING
                end
            elseif store_item[3] == 1 then
                poe2_api.dbgp("公仓")
                if poe2_api.find_text({ UI_info = env.UI_info, text = "強調物品", min_y = 700, min_x = 250 }) and poe2_api.find_text({ UI_info = env.UI_info, text = "倉庫", min_x = 0, min_y = 32, max_x = 381, max_y = 81 }) then
                    poe2_api.click_keyboard('space')
                    api_Sleep(500)
                    poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
                    return bret.RUNNING
                end
            end
            if env.store_item[3] == 0 then
                env.warehouse_type_interactive = "个仓"
            else
                env.warehouse_type_interactive = "公仓"
            end
            poe2_api.dbgp("存仓-----------------------------------------------1010101")
            poe2_api.time_p("Is_Store_Items", api_GetTickCount64() - current_map)
            return bret.FAIL
        end
    },

    -- 存储动作
    Store_Items = {
        run = function(self, env)
            poe2_api.print_log("存储行为...")
            poe2_api.dbgp("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
            local current_time = api_GetTickCount64()
            local text = ""
            if env.warehouse_type_interactive == "个仓" then
                text = "倉庫"
                if poe2_api.find_text({ text = "強調物品", UI_info = env.UI_info, min_x = 250, min_y = 700 })
                    and poe2_api.find_text({ text = "公會倉庫", UI_info = env.UI_info, min_x = 0, min_y = 32, max_x = 381, max_y = 81 }) then
                    poe2_api.click_keyboard("space")
                    api_Sleep(500)
                    return bret.RUNNING
                end
            elseif env.warehouse_type_interactive == "公仓" then
                text = "公會倉庫"
                if poe2_api.find_text({ text = "強調物品", UI_info = env.UI_info, min_x = 250, min_y = 700 })
                    and poe2_api.find_text({ text = "倉庫", UI_info = env.UI_info, min_x = 0, min_y = 32, max_x = 381, max_y = 81 }) then
                    poe2_api.click_keyboard("space")
                    api_Sleep(500)
                    return bret.RUNNING
                end
            else
                error("未知的仓库类型")
            end
            if not poe2_api.find_text({ text = "強調物品", UI_info = env.UI_info, min_x = 250, min_y = 700 }) then
                -- and poe2_api.find_text({text = text,UI_info = env.UI_info,min_x=0,min_y=32,max_x=381,max_y=81}) then
                poe2_api.dbgp("存仓11111-----------------------------------------------1010101")
                return bret.FAIL
            end

            if not self.bool then
                self.type = 0
                self.timeout = 0
                self.is_wait = false
                self.wait_item = nil
                self.current = nil
                self.obj = nil
                self.num = 0
                self.bool = true
                return bret.RUNNING
            end
            local store_item = env.store_item
            local bag_info = env.bag_info
            local current_map_info = env.current_map_info
            local config = env.user_config
            local map_config = config['刷圖設置']["地圖鑰匙"]
            local currency_exchange_is_opens = config['刷圖設置']["通貨交換設置"]
            -- return bret.SUCCESS
            local function map_color()
                local color_map = {}
                if not map_config or not next(map_config) then
                    return false
                end
                for _, i in ipairs(map_config) do
                    local color = {}
                    if i["白"] then table.insert(color, 0) end
                    if i["藍"] then table.insert(color, 1) end
                    if i["黃"] then table.insert(color, 2) end
                    color_map[i["階級"]] = color
                end
                return color_map
            end
            local function is_get_map_color(map_info, map)
                if not map_info or not next(map_info) then
                    return false
                end
                for k, v in ipairs(map_info) do
                    if poe2_api.extract_level(map.baseType_utf8) == k then
                        if v then
                            if poe2_api.table_contains(map.color, v) then
                                return true
                            end
                        end
                    end
                end
                return false
            end
            local map_color_info = map_color()
            -- 检测某物品是否超过三
            local function has_three_duplicates(lst)
                local counter = {}
                for _, v in ipairs(lst) do
                    counter[v] = (counter[v] or 0) + 1
                end
                for _, count in pairs(counter) do
                    if count >= 3 then
                        return true
                    end
                end
                return false
            end
            local items_info = poe2_api.get_items_config_info(config)

            local page = {}
            local index = 0
            if store_item[3] == 0 then
                for _, item in ipairs(items_info) do
                    if not item["不撿"] and string.find(item["類型"], "地圖鑰匙") and not item["工會倉庫"] then
                        table.insert(page, item["存倉頁名"])
                        index = 0
                    end
                end
            else
                for _, item in ipairs(items_info) do
                    if not item["不撿"] and string.find(item["類型"], "地圖鑰匙") and item["工會倉庫"] then
                        table.insert(page, item["存倉頁名"])
                        index = 2
                    end
                end
            end
            if self.timeout == 0 then
                self.timeout = api_GetTickCount64()
            end
            if api_GetTickCount64() - self.timeout > 5000 then
                self.type = 0
                self.timeout = 0
            end
            if store_item[3] == 1 then
                if self.num > 16 then
                    error("仓库已满，手动清理1111")
                end
            else
                if self.num > 8 then
                    currency_exchange_is_opens = currency_exchange_is_opens["是否自動對換"] or false
                    if currency_exchange_is_opens then
                        if env.exchange_status then
                            error("仓库已满，手动清理1111")
                        end
                        if env.warehouse_full and not poe2_api.get_space_point({ width = 2, height = 4, info = bag_info }) then
                            error("仓库已满，手动清理1111")
                        end
                        env.warehouse_full = store_item[2]
                        self.num = 0
                        return bret.RUNNING
                    else
                        error("仓库已满，手动清理1111")
                    end
                end
            end
            if self.is_wait then
                if api_GetTickCount64() - self.current < self.wait_item then
                    poe2_api.print_log("等待间隔时间到达")
                    return bret.RUNNING
                end
            end
            if not poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                poe2_api.click_keyboard("i")
                poe2_api.dbgp("开背包5")
                self.is_wait = true
                self.current = api_GetTickCount64()
                self.wait_item = 1000
                return bret.RUNNING
            end
            self.is_wait = false
            local tab_list_button = poe2_api.click_text_UI({ text = "tab_list_button", UI_info = env.UI_info, ret_data = true })
            local godown_info = api_GetRepositoryPages(store_item[3])
            local precut_page = nil
            -- poe2_api.dbgp(store_item[1].name_utf8)
            for _, v in ipairs(godown_info) do
                -- poe2_api.dbgp(v.name_utf8)
                if v.name_utf8 == tostring(store_item[2]) then
                    precut_page = v
                    break
                end
            end
            if not precut_page then
                poe2_api.print_log("找不到仓库页2222 ->" .. store_item[2] .. "<-")
                api_Sleep(1000)
                return bret.RUNNING
            end
            if not tab_list_button then
                if self.type ~= store_item[2] or precut_page.manage_index == 0 then
                    if poe2_api.find_text({ text = store_item[2], UI_info = env.UI_info, max_y = 90, min_x = 0, max_x = 500, click = 2 }) then
                        self.is_wait = true
                        self.current = api_GetTickCount64()
                        self.wait_item = 500
                        self.type = store_item[2]
                        return bret.RUNNING
                    else
                        poe2_api.print_log("找不到仓库页333 ->" .. store_item[2], "<-")
                        api_Sleep(1000)
                        return bret.RUNNING
                    end
                end
            else
                poe2_api.dbgp("UI_info", env.UI_info)
                poe2_api.printTable(env.UI_info)
                local lock = poe2_api.get_game_control_by_rect({UI_info = env.UI_info,min_x = 549,min_y = 34,max_x = 585,max_y = 75})
                local lock_button = {}
                for _, v in ipairs(lock) do
                    if v.name_utf8 == "" and v.text_utf8 == "" then
                        table.insert(lock_button, v)
                    end
                end
                if not lock_button or not next(lock_button) then
                    api_ClickScreen(poe2_api.toInt((tab_list_button.left + tab_list_button.right) / 2),
                        poe2_api.toInt((tab_list_button.top + tab_list_button.bottom) / 2), 1)
                    api_Sleep(2000)
                    api_ClickScreen(poe2_api.toInt(((tab_list_button.left + tab_list_button.right) / 2) + 30),
                        poe2_api.toInt(((tab_list_button.top + tab_list_button.bottom) / 2) - 30), 1)
                    api_Sleep(1000)
                    return bret.RUNNING
                end
                if self.type ~= store_item[2] or precut_page.manage_index == 0 then
                    if poe2_api.find_text({ text = store_item[2], UI_info = env.UI_info, max_y = 469, min_x = 556, min_y = 20, max_x = 851, click = 2 }) then
                        self.is_wait = true
                        self.current = api_GetTickCount64()
                        self.wait_item = 500
                        self.type = store_item[2]
                        return bret.RUNNING
                    else
                        poe2_api.print_log("找不到仓库页1111 ->", store_item[2], "<-")
                        api_Sleep(1000)
                        return bret.RUNNING
                    end
                end
            end
            local need_synthesis = config["全局設置"]["刷图通用設置"]["自動合成地圖"]
            if need_synthesis then
                local is_czt = nil
                for _, v in ipairs(current_map_info) do
                    if v.name_utf8 == "TreasureVaultHammerActive" and v.flagStatus1 == 1 then
                        is_czt = v
                        break
                    end
                end
                if is_czt and page and next(page) and self.type == page[1] then
                    local warehouse = api_Getinventorys(precut_page.manage_index, index)
                    if warehouse and next(warehouse) then
                        local a = {}
                        for _, v in ipairs(warehouse) do
                            if v.category_utf8 == "Map" and not v.contaminated and poe2_api.extract_level(v.baseType_utf8) < 15 and is_get_map_color(map_color_info, v) then
                                table.insert(a, v.baseType_utf8)
                            end
                        end
                        if a and next(a) then
                            if has_three_duplicates(a) then
                                env.is_need_strengthen = true
                                return bret.RUNNING
                            else
                                env.is_need_strengthen = false
                            end
                        else
                            env.is_need_strengthen = false
                        end
                    end
                end
            end
            if poe2_api.table_contains(precut_page.type, { 0, 1 }) then
                local warehouse = api_Getinventorys(precut_page.manage_index, index)
                if warehouse and next(warehouse) then
                    local w = store_item[1].end_x - store_item[1].start_x
                    local h = store_item[1].end_y - store_item[1].start_y
                    local point = poe2_api.get_space_point({
                        width = w,
                        height = h,
                        w = 12,
                        h = 12,
                        gox = 14,
                        goy = 99,
                        info =
                            warehouse
                    })
                    if not point then
                        currency_exchange_is_opens = currency_exchange_is_opens["是否自動對換"] or false
                        if currency_exchange_is_opens then
                            if env.exchange_status then
                                error("仓库已满，手动清理2222")
                            end
                            if env.warehouse_full and not poe2_api.get_space_point({ width = 2, height = 4, info = bag_info }) then
                                error("仓库已满，手动清理2222")
                            end
                            if store_item[3] == 0 then
                                env.warehouse_full = store_item[2]
                                return bret.RUNNING
                            else
                                error("仓库已满，手动清理2222")
                            end
                        else
                            error("仓库已满，手动清理2222")
                        end
                    end
                end
            elseif precut_page.type == 7 then
                local warehouse = api_Getinventorys(precut_page.manage_index, index)
                if warehouse and next(warehouse) then
                    local w = store_item[1].end_x - store_item[1].start_x
                    local h = store_item[1].end_y - store_item[1].start_y
                    local point = poe2_api.get_space_point({
                        width = w,
                        height = h,
                        w = 24,
                        h = 24,
                        gox = 15,
                        goy = 100,
                        grid_x = 22,
                        grid_y = 22,
                        info =
                            warehouse
                    })
                    if not point then
                        currency_exchange_is_opens = currency_exchange_is_opens["是否自動對換"] or false
                        if currency_exchange_is_opens then
                            if env.exchange_status then
                                error("仓库已满，手动清理3333")
                            end
                            if env.warehouse_full and not poe2_api.get_space_point({ width = 2, height = 4, info = bag_info }) then
                                error("仓库已满，手动清理3333")
                            end
                            if store_item[3] == 0 then
                                env.warehouse_full = store_item[2]
                                return bret.RUNNING
                            else
                                error("仓库已满，手动清理3333")
                            end
                        else
                            error("仓库已满，手动清理3333")
                        end
                    end
                end
            end
            if self.obj and self.obj == store_item[1].obj then
                self.num = self.num + 1
            end
            if not self.obj then
                self.obj = store_item[1].obj
            end
            if self.obj ~= store_item[1].obj then
                self.obj = store_item[1].obj
                self.num = 0
            end
            if self.num and self.num ~= 0 and self.num % 3 == 0 then
                local x = math.random(100, 1500)
                local y = math.random(50, 100)
                api_ClickScreen(poe2_api.toInt(x), poe2_api.toInt(y), 0)
                api_Sleep(300)
                poe2_api.click_keyboard('alt')
                api_Sleep(300)
                if poe2_api.find_text({ UI_info = env.UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2 }) then
                    return bret.RUNNING
                end
            end
            poe2_api.ctrl_left_click_bag_items(store_item[1].obj, bag_info, 3)
            api_Sleep(300)
            return bret.RUNNING
        end
    },

    -- 物品丢弃
    Story_Discard = {
        run = function(self, env)
            poe2_api.print_log("物品丢弃...")
            local start_time = api_GetTickCount64()
            if not self.bool then
                self.item_name = nil
                self.index = 0
                self.bool = true
            end
            local config = env.user_config
            local is_decompose = config['全局設置']["刷图通用設置"]["是否分解暗金"] or false
            local altar_shop_config = config['刷圖設置']["祭祀購買"]
            -- local range_info = env.range_info
            local player_info = env.player_info
            local bag_info = env.bag_info
           
            local processed_configs = poe2_api.get_items_config_info(config)
            local Attachments = api_Getinventorys(0xd,0)
            -- 背包和附着物为空
            if (not bag_info or not next(bag_info)) and (not Attachments or not next(Attachments)) then
                poe2_api.dbgp("背包和附着物为空,不丢弃")
                poe2_api.time_p("物品丢弃（SUCCESS1）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS 
            end
            if poe2_api.table_contains(player_info.current_map_name_utf8,my_game_info.hideout) then
                poe2_api.dbgp("在城镇不丢弃")
                return bret.SUCCESS     
            end
            -- 是否需要丢弃
            local function get_not_item(items)
                local function is_props(bag)
                    if poe2_api.table_contains(bag.category_utf8, {'QuestItem','InstanceLocalItem'}) then
                        return true
                    end
                    return false
                end
                local function get_not(item)
                    local props = is_props(item)
                    if props then
                        return false
                    end
                    if poe2_api.is_do_without_pick_up(item,processed_configs) then
                        return true
                    end
                    for _, cfg in ipairs(processed_configs) do
                        if poe2_api.match_item(item,cfg,1) then
                            if cfg["不撿"] then
                                if poe2_api.table_contains(item.baseType_utf8,altar_shop_config) then
                                    return false
                                end
                                if is_decompose and type(is_decompose)~="table" then
                                    if item.color == 3 and poe2_api.table_contains(item.category_utf8,my_game_info.equip_type) then
                                        return false
                                        
                                    end
                                end
                                return true
                            end
                            if item.baseType_utf8 == "知識卷軸" then
                                local number = 0
                                for _, v in ipairs(items) do
                                    if v.baseType_utf8 == "知識卷軸" then
                                        number = number + v.stackCount
                                    end
                                end
                                if number > 80 then
                                    return true
                                end
                            end
                            if poe2_api.table_contains(item.category_utf8,my_game_info.equip_type) and not item.not_identified then
                                local suffixes = api_GetObjectSuffix(item.mods_obj)
                                if not suffixes or #suffixes == 0 then
                                    return {item}
                                end
                                if not poe2_api.filter_item(item,suffixes,config["物品過濾"]) then
                                    if is_decompose and type(is_decompose)~="table" then
                                        if item.color == 3 and poe2_api.table_contains(item.category_utf8,my_game_info.equip_type) then
                                            return false
                                        end
                                    end
                                    return true
                                end
                            end
                            return false
                        end
                        if is_decompose and type(is_decompose)~="table" then
                            if item.color == 3 and poe2_api.table_contains(item.category_utf8,my_game_info.equip_type) then
                                return false
                            end
                        end
                    end
                    if poe2_api.table_contains(item.baseType_utf8,altar_shop_config) then
                        return false
                    end
                    return true
                end
                if not items or not next(items) then
                    return false
                end
                for _, item in ipairs(items) do
                    local is_dis = get_not(item)
                    if is_dis then
                        if type(is_dis) == "table" then
                            return is_dis
                        end
                        if item.baseType_utf8 == "知識卷軸" then
                            local mininumber = nil
                            local miniobj = nil
                            for _, v in ipairs(items) do
                                if v.baseType_utf8 == "知識卷軸" then
                                    if not mininumber or mininumber > v.stackCount then
                                        miniobj = v
                                        mininumber = v.stackCount
                                    end
                                end
                            end
                            env.discard_item = miniobj
                            return true
                        end
                        env.discard_item = item
                        return true
                    end
                end
                return false
            end
            -- 找黑雾祭坛
            local function get_altar(range_info)
                if not range_info or not next(range_info) then
                    return false
                end
                for _, i in ipairs(range_info) do
                    if i.path_name_utf8 and i.path_name_utf8 ~= "" and string.find("Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable",i.path_name_utf8) then
                        -- local stateMachineList = i:GetStateMachineList()
                        if i.stateMachineList and next(i.stateMachineList) then
                            local current_state = (i.stateMachineList or {}).current_state or 5
                            local interaction_enabled = (i.stateMachineList or {}).interaction_enabled or 5
                            if current_state == 2 and interaction_enabled == 0 then
                                return i
                            end
                        end
                        
                    end
                end
                return false
            end
            -- 判断自身一定范围内是否有激活怪
            local function get_monster(range_info,mate,distance)
                if not range_info or not next(range_info) then
                    return false
                end
                for _, v in ipairs(range_info) do
                    if v.type == 1 and not v.is_friendly and v.life > 0
                     and not poe2_api.table_contains(v.name_utf8,my_game_info.not_attact_mons_CN_name)
                     and v.isActive and not string.find(v.name_utf8,"神殿") and v.is_selectable then
                        local dis = poe2_api.point_distance(v.grid_x, v.grid_y,mate)
                        if dis and dis < distance then
                            return true
                        end
                    end
                end
                return false
            end
            local is_not_item = get_not_item(bag_info)
            -- 没有要丢弃物品和附着物为空
            if not is_not_item and (not Attachments or not next(Attachments)) then
                poe2_api.dbgp("没有要丢弃物品和附着物为空,不丢弃")
                poe2_api.time_p("物品丢弃（SUCCESS2）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end
            local is_altar = get_altar(env.range_info)
            if is_altar then
                local dis = poe2_api.point_distance(is_altar.grid_x, is_altar.grid_y,player_info)
                if dis and dis < 105 then
                    poe2_api.dbgp("在黑屋祭坛,不丢弃")
                    poe2_api.time_p("物品丢弃（SUCCESS3）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.SUCCESS
                end
            end
            local mon = get_monster(env.range_info,player_info,100)
            if mon then
                poe2_api.dbgp("在怪附近,不丢弃")
                poe2_api.time_p("物品丢弃（SUCCESS4）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end
            if player_info.isInDangerArea then
                poe2_api.dbgp("玩家是否在危险区域:", player_info.isInDangerArea)
                local point = api_GetSafeAreaLocation(player_info.grid_x, player_info.grid_y, 60, 10, 0, 0.5)
                if point then
                    api_ClickMove(poe2_api.toInt(point.x),poe2_api.toInt(point.y),7)
                    api_Sleep(100)
                    poe2_api.dbgp1("+++++++++++++++++++++++++++++++++++++++++++++++")
                    poe2_api.click_keyboard("space")
                    poe2_api.time_p("物品丢弃（RUNNING1）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
            end
            if type(is_not_item) == "table" then
                if not poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                    poe2_api.click_keyboard("i")
                    api_Sleep(300)
                    poe2_api.dbgp("开背包,刷新词条")
                    poe2_api.time_p("物品丢弃（RUNNING2）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
                local point = poe2_api.get_center_position({is_not_item[1].start_x,is_not_item[1].start_y},{is_not_item[1].end_x,is_not_item[1].end_y})
                if point and next(point) then
                    api_ClickScreen(poe2_api.toInt(point[1]),poe2_api.toInt(point[2]),0)
                    poe2_api.time_p("物品丢弃（RUNNING3）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
            end
            if not Attachments or not next(Attachments) then
                if not bag_info or not next(bag_info) then
                    env.discard_item = nil
                    poe2_api.time_p("物品丢弃（RUNNING4）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
                local obj = nil
                for _, v in ipairs(bag_info) do
                    if v.obj == env.discard_item.obj then
                        obj = v
                    end
                end
                if not obj then
                    env.discard_item = nil
                    poe2_api.time_p("物品丢弃（RUNNING5）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
                if not poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                    poe2_api.click_keyboard("i")
                    api_Sleep(300)
                    poe2_api.dbgp("开背包,丢弃1")
                    poe2_api.time_p("物品丢弃（RUNNING6）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
                local point = poe2_api.get_center_position({env.discard_item.start_x,env.discard_item.start_y},{env.discard_item.end_x,env.discard_item.end_y})
                api_ClickScreen(poe2_api.toInt(point[1]),poe2_api.toInt(point[2]),1)
                api_Sleep(500)
                poe2_api.time_p("物品丢弃（RUNNING7）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.RUNNING
            else
                local index_list ={2,3,4,5,6,7,8,9,0xa,0xb}
                local point_list = {
                    [2] = {1320,250},
                    [3] = {1151,191},
                    [4] = {1493,191},
                    [5] = {1322,133},
                    [6] = {1410,201},
                    [7] = {1237,255},
                    [8] = {1410,255},
                    [9] = {1213,330},
                    [0xa] = {1431,330},
                    [0xb] = {1322,353},
                }
                local point = nil
                for _, v in ipairs(index_list) do
                    local item = env["item"..v]
                    if item and next(item) then
                        if Attachments[1].baseType_utf8 == item[1].baseType_utf8 
                        and Attachments[1].DemandStrength == item[1].DemandStrength
                        and Attachments[1].DemandAgility == item[1].DemandAgility
                        and Attachments[1].DemandWisdom == item[1].DemandWisdom
                        and Attachments[1].DemandLevel == item[1].DemandLevel
                        and Attachments[1].not_identified == item[1].not_identified
                        and Attachments[1].category_utf8 == item[1].category_utf8
                        and Attachments[1].color == item[1].color then
                            local current_item = api_Getinventorys(v,0)
                            if current_item and next(current_item) then
                                if current_item[1].baseType_utf8 == item[1].baseType_utf8 
                                and current_item[1].DemandStrength == item[1].DemandStrength
                                and current_item[1].DemandAgility == item[1].DemandAgility
                                and current_item[1].DemandWisdom == item[1].DemandWisdom
                                and current_item[1].DemandLevel == item[1].DemandLevel
                                and current_item[1].not_identified == item[1].not_identified
                                and current_item[1].category_utf8 == item[1].category_utf8
                                and current_item[1].color == item[1].color then
                                else
                                    point = point_list[v]
                                    break
                                end
                            else
                                point = point_list[v]
                                break
                            end
                        end
                    end
                end
                if point then
                    if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                        api_ClickScreen(poe2_api.toInt(point[1]),poe2_api.toInt(point[2]),1)
                        api_Sleep(100)
                        poe2_api.time_p("物品丢弃（RUNNING8）... 耗时 --> ", api_GetTickCount64() - start_time)
                        return bret.RUNNING
                    else
                        poe2_api.dbgp("开背包,丢弃2")
                        poe2_api.click_keyboard("i")
                        api_Sleep(300)
                        poe2_api.time_p("物品丢弃（RUNNING9）... 耗时 --> ", api_GetTickCount64() - start_time)
                        return bret.RUNNING
                    end
                else     
                    -- 先设置随机种子（只需执行一次）
                    math.randomseed(os.time())
                    -- 生成 [20, 450) 范围内的随机浮点数
                    local x = 20 + (450 - 20) * math.random()
                    -- 生成 [50, 500) 范围内的随机浮点数
                    local y = 50 + (500 - 50) * math.random()
                    api_ClickScreen(poe2_api.toInt(x),poe2_api.toInt(y),1)
                    api_Sleep(200)
                    if not self.item_name then
                        self.item_name = Attachments[1].baseType_utf8
                    end
                    if self.item_name ~= Attachments[1].baseType_utf8 then
                        self.item_name = Attachments[1].baseType_utf8
                    else
                        self.index = self.index + 1
                    end
                    if self.index > 8 then
                        if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                            poe2_api.click_keyboard("i")
                            poe2_api.dbgp("关背包6")
                            api_Sleep(300)
                        end
                        local point = api_FindRandomWalkablePosition(math.floor(player_info.grid_x),math.floor(player_info.grid_y),50)
                        if point then
                            api_ClickMove(poe2_api.toInt(point.x),poe2_api.toInt(point.y),1)
                            api_Sleep(200)
                            poe2_api.dbgp1("rsdgjtgjasdvzxbfdhfsdh")
                            poe2_api.click_keyboard("space")
                            self.index = 0
                        end
                    end
                    poe2_api.time_p("物品丢弃（RUNNING10）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
            end
            poe2_api.time_p("物品丢弃（RUNNING11）... 耗时 --> ", api_GetTickCount64() - start_time)
            return bret.RUNNING
        end
    },
    
    -- 鉴定指定装备
    Identify_designated_equipment = {
        run = function(self, env)
            poe2_api.print_log("鉴定指定装备...") 
            local player_info = env.player_info
            local attack_dis_map = env.map_level_dis
            local stuck_monsters = env.stuck_monsters
            local not_attack_mos = env.not_attack_mos
            local config = env.user_config

            if self.need_identify_in_map == nil then
                self.need_identify_in_map = config["全局設置"]["刷图通用設置"]["是否图内鉴定"]
                return bret.RUNNING
            end

            if not self.need_identify_in_map then
                return bret.SUCCESS
            end

            local config_name = env.item_config_name
            local config_type = env.item_config_type

            poe2_api.dbgp(string.format("当前地图: %s, 危险区域: %s", 
                player_info.current_map_name_utf8 or "未知", 
                tostring(player_info.isInDangerArea)))
            
            if poe2_api.table_contains(player_info.current_map_name_utf8, my_game_info.hideout) then
                return bret.SUCCESS
            end

            -- poe2_api.dbgp("====== 开始装备鉴定流程 ======")

            -- 创建反向字典
            local reverse_type_conversion = {}
            for k, v in pairs(my_game_info.type_conversion) do
                reverse_type_conversion[v] = k
                -- poe2_api.dbgp(string.format("类型转换表: %s -> %s", k, v))
            end

            local function convert_key(key)
                local converted = my_game_info.type_conversion[key] or reverse_type_conversion[key]
                -- poe2_api.dbgp(string.format("类型转换: %s -> %s", key, converted or "无对应转换"))
                return converted
            end

            local function convert_config_type(config_type_dict)
                if not config_type_dict then
                    poe2_api.dbgp("警告: 配置类型字典为空")
                    return {}
                end
                
                local converted_dict = {}
                poe2_api.dbgp("开始转换配置类型...")
                
                for chinese_type, info_list in pairs(config_type_dict) do
                    local english_type = my_game_info.type_conversion[chinese_type]
                    -- poe2_api.dbgp(string.format("处理类型: %s -> %s", chinese_type, english_type or "无对应英文"))
                    
                    if english_type then
                        -- 处理内嵌'類型'字段
                        if type(info_list) == "table" and info_list["類型"] then
                            poe2_api.dbgp("发现嵌套类型字段，开始处理...")
                            if type(info_list["類型"]) == "table" then
                                local converted_types = {}
                                for _, t in ipairs(info_list["類型"]) do
                                    local converted = my_game_info.type_conversion[t] or t
                                    table.insert(converted_types, converted)
                                    -- poe2_api.dbgp(string.format("转换嵌套类型: %s -> %s", t, converted))
                                end
                                info_list["類型"] = converted_types
                            else
                                local converted = my_game_info.type_conversion[info_list["類型"]] or info_list["類型"]
                                info_list["類型"] = {converted}
                                -- poe2_api.dbgp(string.format("转换单类型: %s -> %s", info_list["類型"], converted))
                            end
                        end
                        converted_dict[english_type] = info_list
                    else
                        poe2_api.dbgp(string.format("严重警告: 未找到类型 '%s' 的英文转换", chinese_type))
                    end
                end
                
                poe2_api.dbgp("配置类型转换完成")
                return converted_dict
            end

            -- 转换配置类型
            poe2_api.dbgp("开始转换主配置类型...")
            config_type = convert_config_type(config_type)
            -- poe2_api.dbgp(string.format("转换后配置类型条目数: %d", table.count(config_type)))

            if poe2_api.find_text({UI_info = env.UI_info, text = "繼續遊戲", click = 2}) then
                poe2_api.dbgp("城外鉴定: 发现'繼續遊戲'文本，点击处理中...")
                return bret.RUNNING
            end

            local appraisal_item_list = {}

            local function need_appraisal(bag_info)
                if not bag_info then
                    poe2_api.dbgp("城外鉴定: 背包信息为空")
                    return false
                end
                
                -- poe2_api.dbgp(string.format("开始检查背包物品，总数: %d", #bag_info))
                
                local function get_matched_config(bag)
                    -- 初始物品信息检查
                    -- poe2_api.dbgp("\n========== 开始物品匹配流程 ==========")
                    -- poe2_api.dbgp(string.format("[物品基本信息] 名称: %s | 类型: %s | 基础类型: %s | 颜色: %d", 
                    --     bag.name_utf8 or "nil", 
                    --     bag.category_utf8 or "nil", 
                    --     bag.baseType_utf8 or "nil", 
                    --     bag.color or -1))
                    
                    -- 检查config_type是否存在
                    if not config_type then
                        -- poe2_api.dbgp("[错误] config_type 配置表不存在！")
                        return nil
                    end
                
                    -- 1. 首先检查类型匹配
                    -- poe2_api.dbgp("\n=== 开始类型配置匹配 ===")
                    for config_name, item_config in pairs(config_type) do
                        -- poe2_api.dbgp(string.format("\n[检查配置组] 配置组名称: %s", config_name))
                        -- poe2_api.dbgp("[配置内容] %s", poe2_api.printTable(item_config))

                        for idx, item in ipairs(item_config) do
                            -- poe2_api.dbgp("\n[检查配置项] 序号: %d", idx)
                            -- poe2_api.dbgp("------------------------------------------------------------------------")
                            if type(item) ~= "table" then
                                -- poe2_api.dbgp("[警告] 配置项不是table类型，跳过")
                                goto continue
                            end
                
                            -- 类型检查
                            local item_type = item["類型"]
                            -- poe2_api.dbgp(string.format("[类型检查] 配置类型: %s | 物品类型: %s", 
                            --     poe2_api.printTable(item_type), 
                            --     bag.category_utf8 or "nil"))
                
                            -- 处理类型匹配
                            local type_match = false
                            if type(item_type) == "table" and #item_type > 0 then
                                type_match = (item_type[1] == convert_key(bag.category_utf8))
                            elseif type(item_type) == "string" then
                                type_match = (item_type == convert_key(bag.category_utf8))
                            else
                                -- poe2_api.dbgp("[警告] 配置类型格式无效")
                            end
                
                            if not type_match then
                                -- poe2_api.dbgp("-> 类型不匹配，跳过")
                                goto continue
                            end
                            -- poe2_api.dbgp("-> 类型匹配通过")
                
                            -- 基础类型检查
                            local base_type = item["基礎類型名"] or "nil"
                            -- poe2_api.dbgp(string.format("[基础类型检查] 配置基础类型: %s | 物品基础类型: %s", 
                            --     base_type, bag.baseType_utf8 or "nil"))
                
                            if bag.baseType_utf8 ~= base_type and base_type ~= "全部物品" then
                                -- poe2_api.dbgp("-> 基础类型不匹配，跳过")
                                goto continue
                            end
                            poe2_api.dbgp("-> 基础类型匹配通过")
                
                            -- 品质检查
                            local quality_check = {
                                white = item["白裝"],
                                blue = item["藍裝"],
                                yellow = item["黃裝"],
                                unique = item["暗金"]
                            }
                            -- poe2_api.dbgp(string.format("[品质检查] 配置要求: 白=%s 蓝=%s 黄=%s 暗金=%s | 物品颜色: %d",
                            --     tostring(quality_check.white),
                            --     tostring(quality_check.blue),
                            --     tostring(quality_check.yellow),
                            --     tostring(quality_check.unique),
                            --     bag.color or -1))
                
                            local quality_ok = false
                            if bag.color == 0 and quality_check.white then
                                quality_ok = true
                            elseif bag.color == 1 and quality_check.blue then
                                quality_ok = true
                            elseif bag.color == 2 and quality_check.yellow then
                                quality_ok = true
                            elseif bag.color == 3 and quality_check.unique then
                                quality_ok = true
                            end
                
                            if not quality_ok then
                                poe2_api.dbgp("-> 品质不匹配，跳过")
                                goto continue
                            end
                            poe2_api.dbgp("-> 品质检查通过")
                
                            -- 名称检查
                            if item["名稱"] then
                                -- poe2_api.dbgp(string.format("[名称检查] 配置名称: %s | 物品名称: %s",
                                --     item["名稱"], bag.name_utf8 or "nil"))
                                
                                if item["名稱"] == bag.name_utf8 then
                                    -- poe2_api.dbgp("-> 名称完全匹配，返回配置")
                                    -- poe2_api.dbgp("[匹配成功] 配置详情:\n%s", poe2_api.printTable(item))
                                    return item
                                else
                                    -- poe2_api.dbgp("-> 名称不匹配，继续检查")
                                end
                            else
                                -- poe2_api.dbgp("[名称检查] 配置无名称要求，检查词缀")
                                
                                -- 词缀检查
                                if item["物品詞綴"] then
                                    poe2_api.dbgp("[词缀检查] 发现词缀配置")
                                    local affix_dict = item["物品詞綴"]
                                    
                                    if affix_dict and type(affix_dict) == "table" then
                                        for affix_name, v in pairs(affix_dict) do
                                            if type(v) == "table" and v["詞綴"] then
                                                -- poe2_api.dbgp(string.format("-> 发现有效词缀: %s", affix_name))
                                                -- poe2_api.dbgp(string.format("[匹配成功] 配置详情:\n%s", poe2_api.printTable(item)))
                                                return item
                                            end
                                        end
                                    end
                                end
                            end
                
                            -- 如果前面都通过但没返回，检查基础类型名
                            -- poe2_api.dbgp("[最终检查] 基础类型名匹配检查")
                            if base_type == bag.baseType_utf8 or base_type == "全部物品" then
                                -- poe2_api.dbgp("-> 基础类型名匹配，返回配置")
                                -- poe2_api.dbgp(string.format("[匹配成功] 配置详情:\n%s", poe2_api.printTable(item)))
                                return item
                            end
                
                            ::continue::
                        end
                    end
                    
                    -- 2. 检查名称匹配
                    poe2_api.dbgp("\n=== 开始名称配置匹配 ===")
                    if not config_name then
                        poe2_api.dbgp("[警告] config_name 配置表不存在")
                    else
                        for config_name, item_config in pairs(config_name) do
                            -- poe2_api.dbgp(string.format("\n[检查名称配置组] %s", config_name))
                            
                            for idx, item in ipairs(item_config) do
                                -- poe2_api.dbgp(string.format("[检查配置项] 序号: %d", idx))
                                
                                if type(item) == "table" then
                                    -- poe2_api.dbgp(string.format("[基础类型比较] 配置: %s | 物品: %s",
                                    --     item["基礎類型名"] or "nil", bag.baseType_utf8 or "nil"))
                                    
                                    if item["基礎類型名"] == bag.baseType_utf8 then
                                        poe2_api.dbgp("-> 基础类型匹配")
                                        
                                        local type_ok = true
                                        if item["類型"] and item["類型"][1] then
                                            type_ok = (item["類型"][1] == bag.category_utf8)
                                            -- poe2_api.dbgp(string.format("[类型比较] 配置: %s | 物品: %s | 结果: %s",
                                            --     item["類型"][1], bag.category_utf8 or "nil",
                                            --     type_ok and "匹配" or "不匹配"))
                                        end
                                        
                                        if type_ok then
                                            -- poe2_api.dbgp("-> 所有条件匹配，返回配置")
                                            return item
                                        end
                                    end
                                end
                            end
                        end
                    end
                
                    poe2_api.dbgp("\n[匹配结果] 未找到匹配配置")
                    return nil
                end

                local items_to_identify = {}
                poe2_api.dbgp("开始扫描背包物品...")
                
                for i, bag in ipairs(bag_info) do
                    -- poe2_api.dbgp(string.format("\n物品 %d/%d: %s (类型: %s, 基础类型: %s, 颜色: %d, 已鉴定: %s)", 
                    --     i, #bag_info, bag.name_utf8 or "无名", bag.category_utf8 or "无类型", 
                    --     bag.baseType_utf8 or "无基础类型", bag.color or -1, 
                    --     tostring(not bag.not_identified)))
                    
                    -- 基础条件：未鉴定、未污染、不在排除列表
                    if not (bag.not_identified and
                            not poe2_api.table_contains(my_game_info.not_need_identify, bag.category_utf8)) then
                        -- poe2_api.dbgp("物品已鉴定或在不需鉴定列表中，跳过")
                        goto continue_item
                    end
                    
                    -- 特殊类别直接加入鉴定列表
                    if poe2_api.table_contains({"Map", "TowerAugmentation"}, bag.category_utf8) then
                        poe2_api.dbgp("特殊类别物品，直接加入鉴定列表")
                        table.insert(items_to_identify, bag)
                        goto continue_item
                    end

                    -- 获取匹配的配置
                    poe2_api.dbgp("开始匹配配置...")
                    local matched_config = get_matched_config(bag)
                    
                    -- 检查物品詞綴配置
                    if matched_config and matched_config["物品詞綴"] then
                        poe2_api.dbgp("找到匹配配置，检查词缀...")
                        local affix_dict = matched_config["物品詞綴"]
                        if affix_dict and type(affix_dict) == "table" then
                            local has_valid_affix = false
                            for affix_name, v in pairs(affix_dict) do
                                if type(v) == "table" and v["詞綴"] then
                                    poe2_api.dbgp(string.format("发现有效词缀: %s", affix_name))
                                    has_valid_affix = true
                                    break
                                end
                            end
                            
                            if has_valid_affix then
                                poe2_api.dbgp("物品有有效词缀，加入鉴定列表")
                                table.insert(items_to_identify, bag)
                            else
                                poe2_api.dbgp("配置中无有效词缀，跳过")
                            end
                        end
                    else
                        poe2_api.dbgp("未找到匹配配置或配置无词缀要求")
                    end
                    ::continue_item::
                end

                if #items_to_identify > 0 then
                    poe2_api.dbgp(string.format("找到 %d 件需要鉴定的物品", #items_to_identify))
                    appraisal_item_list = items_to_identify
                    return items_to_identify
                end
                poe2_api.dbgp("未找到需要鉴定的物品")
                return false
            end

            poe2_api.dbgp("开始检查是否需要鉴定...")
            local bag_info = api_Getinventorys(1, 0)
            if not bag_info then
                poe2_api.dbgp("错误: 无法获取背包信息")
                return bret.SUCCESS
            end

            local items_to_identify = need_appraisal(bag_info)
            if not items_to_identify then
                poe2_api.dbgp("当前没有需要鉴定的物品")
                return bret.SUCCESS
            end

            poe2_api.dbgp(string.format("需要鉴定的物品数量: %d", #items_to_identify))
            
            if player_info.isInDangerArea then
                poe2_api.dbgp("警告: 玩家处于危险区域，暂停鉴定")
                return bret.SUCCESS
            end

            local has_monsters = poe2_api.is_have_mos({range_info = env.range_info, 
                player_info = player_info, 
                attack_dis_map = attack_dis_map, 
                stuck_monsters = stuck_monsters, 
                not_attack_mos = not_attack_mos,
                not_sight = true
            })
            
            if has_monsters then
                poe2_api.dbgp("警告: 周围有怪物，暂停鉴定")
                return bret.SUCCESS
            end

            local function use_items(bag_info, click)
                if not bag_info then 
                    poe2_api.dbgp("错误: use_items 传入的背包信息为空")
                    return false 
                end
                
                poe2_api.dbgp("开始查找知识卷轴...")
                for _, actor in ipairs(bag_info) do
                    if actor.baseType_utf8 == "知識卷軸" then
                        poe2_api.dbgp(string.format("找到知识卷轴，位置: %d,%d - %d,%d", 
                            actor.start_x, actor.start_y, actor.end_x, actor.end_y))
                        
                        if click == 1 then
                            -- 计算中心坐标
                            local start_cell = {actor.start_x, actor.start_y}
                            local end_cell = {actor.end_x, actor.end_y}
                            local center_position = poe2_api.get_center_position(start_cell, end_cell)
                            
                            poe2_api.dbgp(string.format("卷轴中心位置: %d, %d", center_position[1], center_position[2]))
                            
                            poe2_api.dbgp("点击卷轴...")
                            api_ClickScreen(center_position[1], center_position[2],0)
                            api_Sleep(200)
                            api_ClickScreen(center_position[1], center_position[2],2)
                            api_Sleep(500)
                        end
                        return true
                    end
                end
                poe2_api.dbgp("警告: 背包中没有找到知识卷轴")
                return false
            end

            poe2_api.dbgp("准备使用卷轴...")
            if not use_items(bag_info) then
                poe2_api.dbgp("错误: 无法使用知识卷轴")
                return bret.SUCCESS
            end

            -- 重新获取背包信息
            poe2_api.dbgp("重新获取背包信息...")
            bag_info = api_Getinventorys(1, 0)
            if not bag_info then
                poe2_api.dbgp("错误: 重新获取背包信息失败")
                return bret.SUCCESS
            end

            items_to_identify = need_appraisal(bag_info)
            if not items_to_identify then
                poe2_api.dbgp("重新检查后没有需要鉴定的物品")
                return bret.SUCCESS
            end

            if (poe2_api.is_have_mos({range_info = env.range_info, player_info = player_info}) and 
                (poe2_api.table_contains(my_game_info.hideout_CH, player_info.current_map_name_utf8) or 
                string.find(player_info.current_map_name_utf8, "town"))) then
                poe2_api.dbgp("警告: 安全区域发现怪物，暂停鉴定")
                return bret.SUCCESS
            end
            
            poe2_api.dbgp("开始鉴定物品...")
            for _, items in ipairs(bag_info) do
                for _, k in ipairs(items_to_identify) do
                    if items.obj == k.obj then
                        poe2_api.dbgp(string.format("鉴定物品: %s (类型: %s)", 
                            items.name_utf8 or "无名", items.category_utf8 or "无类型"))
                        
                        if not poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                            poe2_api.dbgp("未检测到背包UI，尝试打开背包...")
                            poe2_api.click_keyboard("i")
                            api_Sleep(500)
                        end

                        use_items(bag_info, 1)
                        api_Sleep(500)
                        
                        -- 计算中心坐标
                        local start_cell = {items.start_x, items.start_y}
                        local end_cell = {items.end_x, items.end_y}
                        local center_position = poe2_api.get_center_position(start_cell, end_cell)
                        poe2_api.dbgp(string.format("物品中心位置: %d, %d", center_position[1], center_position[2]))

                        poe2_api.dbgp("左键点击物品...")
                        api_ClickScreen(center_position[1], center_position[2],0)
                        api_Sleep(200)
                        poe2_api.dbgp("右键点击物品...")
                        api_ClickScreen(center_position[1], center_position[2],1)
                        api_Sleep(200)
                        
                        poe2_api.dbgp("物品鉴定完成")
                        return bret.RUNNING
                    end
                end
            end

            poe2_api.dbgp("错误: 未找到匹配的需要鉴定的物品")
            return bret.SUCCESS
        end
    },

    -- 检查是否拾取
    Is_Pick_UP = {
        run = function(self, env)
            poe2_api.print_log("检查是否需要拾取...")
            local start_time = api_GetTickCount64()
            local current_time = api_GetTickCount64()
            if not self.bool then
                self.id1 = nil
                self.number = 0
                self.bool = true
                self.wait = false
                self.wait_time = 0
                self.currte_time = 0
            end
            local config = env.user_config
            local need_item = env.need_item
            local is_decompose = config["全局設置"]["刷图通用設置"]["是否分解暗金"] or false
            local altar_shop_config = config['刷圖設置']["祭祀購買"]
            local stuck_monsters = env.stuck_monsters
            -- local item_list = env.range_items
            local player_info = env.player_info
            -- local range_info = env.range_info
            local bag_info = env.bag_info
            -- local current_map_info = env.current_map_info
            if not next(player_info) then
                poe2_api.dbgp("人物信息为空")
                poe2_api.time_p("检查是否拾取（RUNNING1）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.RUNNING
            end
            if string.find(player_info.current_map_name_utf8,"town") then
                env.need_item = nil
                env.boss_drop = nil
                env.interactive = nil
                return bret.SUCCESS
            end
            local function get_item(items,processed_configs)
                
                local sorted_items = poe2_api.get_sorted_list(items,player_info)
                if not sorted_items or not next(sorted_items) then
                    poe2_api.dbgp("数据有问题2222")
                    return false
                end
                -- for _, v in ipairs(sorted_items) do
                --     poe2_api.dbgp(v.name_utf8)
                --     poe2_api.dbgp(v.baseType_utf8)
                --     poe2_api.dbgp(v.category_utf8)
                --     poe2_api.dbgp(tostring(v.grid_x))
                --     poe2_api.dbgp(tostring(v.grid_y))
                --     poe2_api.dbgp(tostring("========================================"))
                -- end
                poe2_api.dbgp(tostring(#sorted_items))
                for _, item in ipairs(sorted_items) do
                    -- api_Sleep(5000)
                    -- poe2_api.dbgp(item.name_utf8)
                    -- poe2_api.dbgp(item.baseType_utf8)
                    -- poe2_api.dbgp(item.category_utf8)
                    -- poe2_api.dbgp(tostring(item.grid_x))
                    -- poe2_api.dbgp(tostring(item.grid_y))
                    -- poe2_api.dbgp(tostring("========================================"))
                    if item.grid_x ~= 0 and item.grid_y ~= 0 then
                        -- poe2_api.dbgp("cccccccccccccccccccccccccccccccccc")
                        for _, cfg in ipairs(processed_configs) do
                            
                            if poe2_api.match_item(item,cfg,1) then
                                -- poe2_api.dbgp("999================================================")
                                if env.pick_up_timeout and next(env.pick_up_timeout) and poe2_api.table_contains(item.id,env.pick_up_timeout) then
                                    break
                                end
                                if not cfg['不撿'] then
                                    if poe2_api.is_do_without_pick_up(item,processed_configs) then
                                        break
                                    end
                                    local item_entry = cfg["物品詞綴"] or {}
                                    if item_entry and next(item_entry) then
                                        local function get_cfg_entry(entry_list)
                                            for k, v in pairs(entry_list) do
                                                if v and type(v) ~= "boolean" then  -- 确保 v 不是 nil 且不是 boolean
                                                    if v["詞綴"] and next(v["詞綴"]) then  -- 检查 "詞綴" 是否存在
                                                        return true
                                                    end
                                                end
                                            end
                                            return false
                                        end
                                        if get_cfg_entry(item_entry) then
                                            if poe2_api.table_contains(item.category_utf8,my_game_info.equip_type)
                                             and not item.not_identified then
                                                local suffixes = api_GetObjectSuffix(item.mods_obj)
                                                if suffixes and next(suffixes) then
                                                    if not poe2_api.filter_item(item,suffixes,config["物品過濾"]) then
                                                        poe2_api.dbgp("词缀不符合*******************************************")
                                                        break
                                                    end
                                                else
                                                    poe2_api.dbgp("未找到物品词缀——————————————————————————————————————————————")
                                                    break
                                                end
                                                
                                            end
                                        end
                                    end
                                    if bag_info and next(bag_info) then
                                        if item.baseType_utf8 == "知識卷軸" then
                                            local number = 0
                                            for _, v in ipairs(bag_info) do
                                                if v.baseType_utf8 == "知識卷軸" then
                                                    number = number + v.stackCount
                                                end
                                            end
                                            if number >= 80 then
                                                break
                                            end
                                        end
                                    end
                                    local distance = poe2_api.point_distance(item.grid_x,item.grid_y,player_info)
                                    local function is_point(grid_x,grid_y)
                                        local point = api_FindNearestReachablePoint(math.floor(grid_x),math.floor(grid_y),15,0)
                                        local ralet = api_FindPath(player_info.grid_x,player_info.grid_y,math.floor(point.x),math.floor(point.y))
                                        return ralet
                                    end
                                    if distance and distance > 15 then
                                        local ralet = is_point(item.grid_x,item.grid_y)
                                        if not ralet or not next(ralet) then
                                            poe2_api.dbgp("无路径")
                                            break
                                        end
                                    end
                                    env.interactive = item
                                    env.need_item = item
                                    return true
                                end
                                break
                            end

                        end
                        if poe2_api.table_contains(item.baseType_utf8,altar_shop_config) then
                            -- poe2_api.dbgp("kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk")
                            if env.pick_up_timeout and next(env.pick_up_timeout) and poe2_api.table_contains(item.id,env.pick_up_timeout) then
                                break
                            end
                            env.interactive = item
                            env.need_item = item
                            return true
                        end
                        if is_decompose then
                            -- poe2_api.dbgp("mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm")
                            if item.color == 3 and poe2_api.table_contains(item.category_utf8,my_game_info.equip_type) then
                                if env.pick_up_timeout and next(env.pick_up_timeout) and poe2_api.table_contains(item.id,env.pick_up_timeout) then
                                    -- poe2_api.dbgp("jjjjjjjjjjjjjjjjjjjjjjjjjjjjjj")
                                    break
                                end
                                env.interactive = item
                                env.need_item = item
                                -- poe2_api.dbgp("hhhhhhhhhhhhhhhhhhhhhh")
                                return true
                            end
                        end
                    end
                end
                return false
            end
            
            if (not env.range_items or not next(env.range_items)) and not env.need_item then
                poe2_api.dbgp("无物品可捡1")
                poe2_api.time_p("无物品可捡1(SUCCESS1)... 耗时 -->", api_GetTickCount64() - current_time )
                return bret.SUCCESS
            end
            local processed_configs = poe2_api.get_items_config_info(config)
            if not need_item then
                if not get_item(env.range_items,processed_configs) then
                    poe2_api.dbgp("无物品可捡2")
                    poe2_api.time_p("检查是否拾取（SUCCESS2）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.SUCCESS
                end
            end
            poe2_api.dbgp("1")
            -- 判断自身一定范围内是否有激活怪
            local function is_monster(range_info,mate,distance)
                if not range_info or not next(range_info) then
                    return false
                end
                if distance > env.min_attack_dis then
                    distance = env.min_attack_dis  
                end
                for _, v in ipairs(range_info) do
                    if v.type == 1 and not v.is_friendly and v.life > 0
                     and not poe2_api.table_contains(v.name_utf8,my_game_info.not_attact_mons_CN_name)
                     and v.isActive and not string.find(v.name_utf8,"神殿") and v.hasLineOfSight and v.is_selectable
                     and (not stuck_monsters or not next(stuck_monsters) or not stuck_monsters[v.id]) then
                        local dis = poe2_api.point_distance(v.grid_x, v.grid_y,mate)
                        if dis and dis < distance then
                            return true
                        end
                    end
                end
                return false
            end
            local is_target = is_monster(env.range_info, player_info,40)
            if is_target and player_info.name_utf8 == env.user_config["組隊設置"]["大號名"] then
                poe2_api.dbgp("附近有怪，不捡")
                poe2_api.time_p("检查是否拾取（SUCCESS3）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end
            if self.wait then
                if api_GetTickCount64() - self.current_time < self.wait_time then
                    poe2_api.dbgp("等待中")
                    poe2_api.time_p("检查是否拾取（SUCCESS4）... 耗时 --> ", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
                self.wait = false
            end
            poe2_api.dbgp("2")
            -- 判断特殊交互对象
            local function get_interactive(range_info)
                if not range_info or not next(range_info) then
                    return false
                end
                for _, v in ipairs(range_info) do
                    if v.name_utf8 ~= "" and poe2_api.table_contains(v.name_utf8,{"開關","門","把手"}) and v.isActive and v.is_selectable
                     and v.grid_x ~= 0 and v.grid_y ~= 0 then
                        if poe2_api.table_contains(v.name_utf8,{"開關","把手"}) then
                            local dis = poe2_api.point_distance(v.grid_x, v.grid_y, player_info)
                            if dis and dis <= 70 then
                                return v
                            end
                        end
                        if v.name_utf8 == "門" then
                            local dis = poe2_api.point_distance(v.grid_x, v.grid_y, player_info)
                            if dis and dis <= 25 then
                                return v
                            end
                        end
                        
                    end
                end
                return false
            end
            local is_interactive = get_interactive(env.range_info)
            if is_interactive then
                poe2_api.dbgp("特殊交互对象，不捡:  "..is_interactive.name_utf8)
                poe2_api.time_p("检查是否拾取（SUCCESS6）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end
            poe2_api.dbgp("3")
            need_item = env.need_item
            env.interactive = need_item
            if self.currte_time == 0 then
                self.currte_time = api_GetTickCount64()
            end
            if api_GetTickCount64() - self.currte_time > 10*1000 then
                local path = api_FindNearestReachablePoint(need_item.grid_x, need_item.grid_y,50,0)
                if path.x == path.y == -1 then
                    poe2_api.dbgp("物品无路径")
                    env.need_item = nil
                    env.interactive = nil
                    self.currte_time = 0
                    return bret.SUCCESS
                end
            end
            local distance = poe2_api.point_distance(need_item.grid_x, need_item.grid_y,player_info)
            poe2_api.dbgp("距离: "..distance)
            if distance then
                if distance < 25 then
                    local is_item = nil
                    poe2_api.dbgp("need_item.id: "..need_item.id)
                    for _, i in ipairs(env.range_items) do 
                        poe2_api.dbgp("i.id: "..i.id)
                        if i.id == need_item.id then 
                            is_item = i
                            break
                        end 
                    end
                    if not is_item then
                        env.need_item = nil
                        poe2_api.dbgp("物品已捡起1")
                        poe2_api.time_p("检查是否拾取（RUNNING2）... 耗时 --> ", api_GetTickCount64() - start_time)
                        return bret.RUNNING
                    end
                    poe2_api.dbgp("111================")
                    local size = my_game_info.item_size[need_item.category_utf8]
                    poe2_api.dbgp("size:"..size[1],size[2])
                    local point = poe2_api.get_space_point({width=size[1],height=size[2],info=bag_info})
                    if not point and not player_info.isInBossBattle then
                        poe2_api.dbgp("背包空间不足，回城")
                        for _, i in ipairs(env.range_info) do
                            if i.name_utf8 ~= "" and i.type == 5 and poe2_api.table_contains(i.name_utf8,my_game_info.hideout_CH) then
                                local dis = poe2_api.point_distance(i.grid_x, i.grid_y, player_info)
                                if dis and dis < 25 then
                                    poe2_api.find_text({text = i.name_utf8,UI_info = env.UI_info,min_x=0,min_y=200,click=2})
                                    api_Sleep(200)
                                    env.need_item = nil
                                    poe2_api.time_p("检查是否拾取（RUNNING3）... 耗时 --> ", api_GetTickCount64() - start_time)
                                    return bret.RUNNING
                                end
                            end
                        end  
                        api_ClickMove(poe2_api.toInt(player_info.grid_x),poe2_api.toInt(player_info.grid_y),7)
                        api_Sleep(300) 
                        -- 先设置随机种子（只需执行一次）
                        math.randomseed(os.time())
                        -- 生成 [0, 25) 范围内的随机浮点数
                        local x = 0 + (5 - 0) * math.random()
                        -- 生成 [0, 25) 范围内的随机浮点数
                        local y = 0 + (5 - 0) * math.random()
                        api_ClickScreen(poe2_api.toInt(x+1230),poe2_api.toInt(y+815),0)
                        api_Sleep(50)
                        api_ClickScreen(poe2_api.toInt(x+1230),poe2_api.toInt(y+815),1)
                        self.wait = true
                        self.current_time = api_GetTickCount64()
                        self.wait_time = 2000
                        poe2_api.dbgp("等待回城")
                        poe2_api.time_p("检查是否拾取（RUNNING4）... 耗时 --> ", api_GetTickCount64() - start_time)
                        return bret.RUNNING
                    end
                    local bool = false
                    for _, i in ipairs(env.range_info) do
                        if i.name_utf8 ~= "" and i.type == 5 and poe2_api.table_contains(i.name_utf8,my_game_info.hideout_CH) then
                            local dis = poe2_api.point_distance(i.grid_x, i.grid_y, need_item)
                            if dis and dis < 25 then
                                bool = true
                                break
                            end
                        end
                    end
                    poe2_api.dbgp("是否在隐藏点: "..tostring(bool))
                    if bool then
                        for _, v in ipairs(env.range_info) do
                            if v.name_utf8 ~= "" and v.type == 5 and poe2_api.table_contains(v.name_utf8,my_game_info.hideout_CH) then
                                local dis = poe2_api.point_distance(v.grid_x, v.grid_y, player_info)
                                if dis and dis < 25 then
                                    local point = api_FindRandomWalkablePosition(math.floor(player_info.grid_x),math.floor(player_info.grid_y),70)
                                    if point then
                                        api_ClickMove(poe2_api.toInt(point.x),poe2_api.toInt(point.y),0)
                                        -- api_Sleep(200)
                                        poe2_api.dbgp1("fdgherhtfbfdbsrghdghjm")
                                        poe2_api.click_keyboard("space")
                                        api_Sleep(200)
                                        poe2_api.time_p("检查是否拾取（RUNNING5）... 耗时 --> ", api_GetTickCount64() - start_time)
                                        return bret.RUNNING
                                    end
                                end
                            end
                        end
                        local point = api_FindRandomWalkablePosition(math.floor(player_info.grid_x),math.floor(player_info.grid_y),70)
                        if point then
                            api_ClickMove(poe2_api.toInt(point.x),poe2_api.toInt(point.y),7)
                            api_Sleep(300)
                            -- 先设置随机种子（只需执行一次）
                            math.randomseed(os.time())
                            -- 生成 [0, 25) 范围内的随机浮点数
                            local x = 0 + (5 - 0) * math.random()
                            -- 生成 [0, 25) 范围内的随机浮点数
                            local y = 0 + (5 - 0) * math.random()
                            api_ClickScreen(poe2_api.toInt(x+1230),poe2_api.toInt(y+815),0)
                            api_Sleep(50)
                            api_ClickScreen(poe2_api.toInt(x+1230),poe2_api.toInt(y+815),1)
                            self.wait = true
                            self.current_time = api_GetTickCount64()
                            self.wait_time = 2000
                            -- -- api_Sleep(200)
                            -- poe2_api.click_keyboard("space")
                            poe2_api.time_p("检查是否拾取（RUNNING6）... 耗时 --> ", api_GetTickCount64() - start_time)
                            return bret.RUNNING
                        end
                    end   
                    if not player_info.isMoving then
                        if not self.id1 then
                            self.id1 = env.need_item.id
                        end
                        if self.id1 == env.need_item.id then
                            self.number = self.number + 1
                        else
                            self.number = 1
                            self.id1 = env.need_item.id
                            -- poe2_api.dbgp("物品已捡起,更新状态")
                            -- api_Sleep(1000)
                        end
                        if self.number % 10 == 0 then
                            local point = api_FindRandomWalkablePosition(math.floor(player_info.grid_x),math.floor(player_info.grid_y),70)
                            if point then
                                api_ClickMove(poe2_api.toInt(point.x),poe2_api.toInt(point.y),7)
                            end
                        end
                        poe2_api.dbgp("number: "..self.number)
                        if self.number >= 50 then
                            table.insert(env.pick_up_timeout,env.need_item.id)
                            env.need_item = nil
                            self.number = 0
                            poe2_api.time_p("检查是否拾取（RUNNING7）... 耗时 --> ", api_GetTickCount64() - start_time)
                            return bret.RUNNING
                        end
                    end
                    poe2_api.dbgp("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")   
                elseif distance < 50 then
                    local is_item = nil
                    for _, i in ipairs(env.range_items) do 
                        if i.id == need_item.id then 
                            is_item = i
                            break
                        end 
                    end
                    if not is_item then
                        env.need_item = nil
                        poe2_api.dbgp("物品已捡起2")
                        poe2_api.time_p("检查是否拾取（SUCCESS1）... 耗时 --> ", api_GetTickCount64() - start_time)
                        return bret.RUNNING
                    end
                    local bool = false
                    for _, i in ipairs(env.range_info) do
                        if i.name_utf8 ~= "" and i.type == 5 and poe2_api.table_contains(i.name_utf8,my_game_info.hideout_CH) then
                            local dis = poe2_api.point_distance(i.grid_x, i.grid_y, need_item)
                            if dis and dis < 25 then
                                bool = true
                                break
                            end
                        end
                    end
                    if bool then
                        for _, v in ipairs(env.range_info) do
                            if v.name_utf8 ~= "" and v.type == 5 and poe2_api.table_contains(v.name_utf8,my_game_info.hideout_CH) then
                                local dis = poe2_api.point_distance(v.grid_x, v.grid_y, player_info)
                                if dis and dis < 30 then
                                    local point = api_FindRandomWalkablePosition(math.floor(player_info.grid_x),math.floor(player_info.grid_y),70)
                                    if point then
                                        api_ClickMove(poe2_api.toInt(point.x),poe2_api.toInt(point.y),0)
                                        -- api_Sleep(200)
                                        poe2_api.dbgp1("fdsvsdvsdvdsfdrsfv")
                                        poe2_api.click_keyboard("space")
                                        poe2_api.time_p("检查是否拾取（RUNNING8）... 耗时 --> ", api_GetTickCount64() - start_time)
                                        return bret.RUNNING
                                    end
                                end
                            end
                        end
                        local point = api_FindRandomWalkablePosition(math.floor(player_info.grid_x),math.floor(player_info.grid_y),70)
                        
                        if point then
                            api_ClickMove(poe2_api.toInt(point.x),poe2_api.toInt(point.y),7)
                            api_Sleep(300)
                            -- 先设置随机种子（只需执行一次）
                            math.randomseed(os.time())
                            -- 生成 [0, 25) 范围内的随机浮点数
                            local x = 0 + (5 - 0) * math.random()
                            -- 生成 [0, 25) 范围内的随机浮点数
                            local y = 0 + (5 - 0) * math.random()
                            api_ClickScreen(poe2_api.toInt(x+1230),poe2_api.toInt(y+815),0)
                            api_Sleep(50)
                            api_ClickScreen(poe2_api.toInt(x+1230),poe2_api.toInt(y+815),1)
                            self.wait = true
                            self.current_time = api_GetTickCount64()
                            self.wait_time = 2000                            -- -- api_Sleep(200)
                            -- poe2_api.click_keyboard("space")
                            poe2_api.time_p("检查是否拾取（RUNNING9）... 耗时 --> ", api_GetTickCount64() - start_time)
                            return bret.RUNNING
                        end
                    end
                       
                end
                
            end
            if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                poe2_api.click_keyboard("i")
                poe2_api.dbgp("关背包7")
                api_Sleep(200)
                poe2_api.time_p("检查是否拾取（RUNNING10）... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.RUNNING
            end
            poe2_api.dbgp("背包已關閉*********************************************************")
            poe2_api.time_p("检查是否拾取（FAIL1）... 耗时 --> ", api_GetTickCount64() - start_time)
            return bret.FAIL
        end
    },
    
    -- 打开仓库(warehouse_type_interactive 为空情况在调用之前，提前处理)
    Open_Warehouse = {
        run = function(self, env)
            poe2_api.print_log("开始执行 Open_Warehouse")

            if not self.nubmer_index then
                self.nubmer_index = 0
                poe2_api.dbgp("初始化完成，设置 nubmer_index = 0")
                return bret.RUNNING
            end

            -- poe2_api.dbgp("打开仓库,.")
            local obj = nil
            local text = nil
            local warehouse = nil
            local current_map_info = env.current_map_info

            local player_info = env.player_info
            local warehouse_type_interactive = env.warehouse_type_interactive

            poe2_api.dbgp("环境变量检查:", {
                warehouse_type_interactive = warehouse_type_interactive,
                current_map_info = current_map_info and #current_map_info or "nil",
                player_info = player_info and "exists" or "nil"
            })

            local function get_object(name, data_list)
                for _, v in ipairs(data_list) do
                    if v.name_utf8 == name and v.grid_x ~= 0 and v.grid_y ~= 0 then
                        if v.flagStatus and v.flagStatus == 0 and v.flagStatus1 == 1 then
                            poe2_api.dbgp("get_object 找到匹配对象(flagStatus):", v)
                            return v
                        end
                        if v.life and v.is_selectable then
                            poe2_api.dbgp("get_object 找到匹配对象(life):", v)
                            return v
                        end
                    end
                end
                poe2_api.dbgp("get_object: 未找到匹配对象")
                return false
            end

            poe2_api.dbgp("仓库类型:", warehouse_type_interactive)

            if warehouse_type_interactive == "个仓" then
                poe2_api.dbgp("查找个人仓库...")
                local warehouse_obj = get_object("StashPlayer", current_map_info)
                if warehouse_obj then
                    obj = 'StashPlayer'
                    text = "倉庫"
                    warehouse = warehouse_obj
                    poe2_api.dbgp("找到 StashPlayer 仓库:", warehouse_obj)
                else
                    local warehouse_obj1 = get_object("倉庫", env.range_info)
                    if warehouse_obj1 then
                        obj = '倉庫'
                        text = "倉庫"
                        warehouse = warehouse_obj1
                        poe2_api.dbgp("找到 倉庫 (备用):", warehouse_obj1)
                    end
                end
            elseif warehouse_type_interactive == "公仓" then
                poe2_api.dbgp("查找公会仓库...")
                local warehouse_obj = get_object("StashGuild", current_map_info)
                if warehouse_obj then
                    obj = 'StashGuild'
                    text = "公會倉庫"
                    warehouse = warehouse_obj
                    poe2_api.dbgp("找到 StashGuild 仓库:", warehouse_obj)
                else
                    local warehouse_obj1 = get_object("公會倉庫", env.range_info)
                    if warehouse_obj1 then
                        obj = '公會倉庫'
                        text = "公會倉庫"
                        warehouse = warehouse_obj1
                        poe2_api.dbgp("找到 公會倉庫 (备用):", warehouse_obj1)
                    end
                end
            else
                poe2_api.dbgp("错误: 仓库类型未配置", warehouse_type_interactive)
                error("在配置物品过滤中,有物品的存仓页未配置")
            end

            if not warehouse then
                poe2_api.dbgp("错误: 找不到仓库对象")
                error("找不到仓库或者公会仓库")
            end

            poe2_api.dbgp("最终仓库对象:",
                obj,
                text,
                warehouse
            )

            -- 检查是否已经打开仓库界面
            local emphasize_text = poe2_api.find_text({ UI_info = env.UI_info, text = "強調物品", min_x = 250, min_y = 700 })
            local warehouse_text = poe2_api.find_text({ UI_info = env.UI_info, text = text, min_x = 0, min_y = 32, max_x = 381, max_y = 81 })

            poe2_api.dbgp("界面检查结果:", {
                emphasize_text = emphasize_text and "found" or "not found",
                warehouse_text = warehouse_text and "found" or "not found"
            })

            if emphasize_text and warehouse_text then
                poe2_api.dbgp("仓库界面已打开，返回SUCCESS")
                return bret.SUCCESS
            end

            local distance = poe2_api.point_distance(warehouse.grid_x, warehouse.grid_y, player_info)
            poe2_api.dbgp("与仓库的距离:", distance)

            if distance > 30 then
                poe2_api.dbgp("距离仓库太远(", distance, ")，返回FAIL")
                env.interactive = obj
                return bret.FAIL
            else
                local continue_game = poe2_api.find_text({ UI_info = env.UI_info, text = "繼續遊戲", click = 2 })
                if continue_game then
                    poe2_api.dbgp("发现'繼續遊戲'文本，返回RUNNING")
                    return bret.RUNNING
                end

                poe2_api.dbgp("尝试移动到仓库位置:", warehouse.grid_x, warehouse.grid_y)

                api_ClickMove(poe2_api.toInt(warehouse.grid_x), poe2_api.toInt(warehouse.grid_y), 1)

                if self.nubmer_index >= 10 then
                    poe2_api.dbgp("尝试次数超过10次(", self.nubmer_index, ")，执行ESC并重置计数器")
                    poe2_api.click_keyboard("space")
                    api_Sleep(500)
                    self.nubmer_index = 0
                end

                self.nubmer_index = self.nubmer_index + 1
                poe2_api.dbgp("当前尝试次数:", self.nubmer_index)

                api_Sleep(500)
                return bret.RUNNING
            end
        end
    },

    -- 城镇任务接收
    Interactive_Npc_In_Town = {
        run = function(self, env)
            poe2_api.print_log("城镇交互-任务")
            poe2_api.dbgp("[Interactive_Npc_In_Town]开始处理城镇任务")
            local range_info = env.range_info
            local team_info = env.team_info
            local user_config = env.user_config
            local player_info = env.player_info
            local current_time = api_GetTickCount64()
            if not string.find(player_info.current_map_name_utf8, "own") or poe2_api.get_team_info(team_info, user_config, player_info, 2) == "大號名" then
                poe2_api.dbgp("[The_Interactive_Npc_Exist]不在城镇或为大号,不进行任何操作")
                poe2_api.time_p("Interactive_Npc_In_Town",api_GetTickCount64() - current_time)
                return bret.FAIL
            end
            local function is_have_active_npc(ranges)
                if ranges then
                    for _, m in pairs(ranges) do
                        if m.name_utf8 and m.hasTasksToAccept then
                            return m
                        end
                    end
                end
                return false
            end

            if string.find(player_info.current_map_name_utf8, "own") then
                local npc_names = is_have_active_npc(range_info)
                if npc_names and not string.find(npc_names.name_utf8, '沙漠') then
                    env.npc_names = npc_names
                    poe2_api.dbgp("Interactive_Npc_In_Town(SUCCESS1)")
                    poe2_api.time_p("Interactive_Npc_In_Town",api_GetTickCount64() - current_time)
                    return bret.SUCCESS
                end
            end
            poe2_api.dbgp("[The_Interactive_Npc_Exist]未找到城镇任务npc")
            poe2_api.time_p("Interactive_Npc_In_Town",api_GetTickCount64() - current_time)
            return bret.FAIL
        end
    },

    -- 城镇任务npc是否存在
    The_Interactive_Npc_Exist = {
        run = function(self, env)
            poe2_api.print_log("城镇任务npc是否存在")
            poe2_api.dbgp("[The_Interactive_Npc_Exist]城镇任务npc是否存在")
            if self.last_click_time == nil then
                poe2_api.dbgp("[The_Interactive_Npc_Exist]初始化")
                self.last_click_time = 0
                self.click_cooldown = 1000
            end
            local npc_names = env.npc_names
            local player_info = env.player_info
            local current_time = api_GetTickCount64()
            if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                poe2_api.click_keyboard("space")
                poe2_api.dbgp("The_Interactive_Npc_Exist(RUNNING1)")
                return bret.RUNNING
            end
            if npc_names and string.find(player_info.current_map_name_utf8, "town") then
                local distance = poe2_api.point_distance(npc_names.grid_x, npc_names.grid_y, player_info)
                local point = api_FindNearestReachablePoint(npc_names.grid_x, npc_names.grid_y, 15, 0)
                if distance <= 25 then
                    poe2_api.dbgp("[The_Interactive_Npc_Exist]与城镇npcdistance:", distance)
                    if poe2_api.find_text({ UI_info = env.UI_info, text = npc_names.name_utf8}) then
                        poe2_api.dbgp("[The_Interactive_Npc_Exist]找到城镇任务npc:", npc_names.name_utf8)
                        if self.last_click_time == 0 then
                            self.last_click_time = api_GetTickCount64()
                        end
                        if api_GetTickCount64() - self.last_click_time > self.click_cooldown then
                            if poe2_api.find_text({ UI_info = env.UI_info, text = "再會", refresh = true }) then
                                poe2_api.dbgp("打开Npc对话选项")
                                poe2_api.time_p("The_Interactive_Npc_Exist",api_GetTickCount64() - current_time)
                                
                                return bret.FAIL
                            end
                            poe2_api.dbgp("[The_Interactive_Npc_Exist]点击城镇任务npc:", npc_names.name_utf8)
                            poe2_api.find_text({ UI_info = env.UI_info, text = npc_names.name_utf8, click = 2 })
                            self.last_click_time = 0
                        end
                        poe2_api.dbgp("The_Interactive_Npc_Exist(RUNNING1)")
                        return bret.RUNNING
                    end
                    poe2_api.dbgp("[The_Interactive_Npc_Exist]未找到城镇任务npc")
                end
                poe2_api.dbgp("[The_Interactive_Npc_Exist]与城镇npcdistance:", distance)
                env.end_point = { point.x, point.y }
                poe2_api.dbgp("The_Interactive_Npc_Exist(SUCCESS1)")
                poe2_api.time_p("The_Interactive_Npc_Exist",api_GetTickCount64() - current_time)
                return bret.SUCCESS
            end
            poe2_api.dbgp("The_Interactive_Npc_Exist(FAIL1)")
            poe2_api.time_p("The_Interactive_Npc_Exist",api_GetTickCount64() - current_time)
            return bret.FAIL
        end
    },
    -- 组队
    Team = {
        run = function(self, env)
            poe2_api.print_log("组队")
            poe2_api.dbgp("组队")
            local player_info = env.player_info
            local range_info = env.range_info
            local captain_name = env.user_config["組隊設置"]["隊長名"] or ""
            local leader_name = env.user_config["組隊設置"]["大號名"] or ""
            local team_info_data = env.team_info_data
            local log_path = poe2_api.load_config(json_path)["組隊設置"]["日志路径"]
            local current_time = api_GetTickCount64()
            if player_info.current_map_name_utf8 == "G1_1" then
                poe2_api.dbgp("在新手剧情不组队")
                poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                return bret.SUCCESS
            end
            local num = env.user_config["組隊設置"]["隊伍人數"]
            if team_info_data and #team_info_data == num then
                if self.bool then
                    if poe2_api.find_text({ text = "社交", UI_info = env.UI_info, min_x=0, min_y=32, max_x=381, max_y=81}) then
                        poe2_api.click_keyboard("j")
                        api_Sleep(500)
                        poe2_api.dbgp("Team(RUNNING1)")
                        poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    end
                    
                    -- 检查队伍数据一致性
                    local current_team_info = api_GetTeamInfo()
                    local is_consistent = true
                    
                    -- 检查队伍人数是否一致
                    if #current_team_info ~= #env.team_info_data then
                        is_consistent = false
                    else
                        -- 检查每个队员信息是否一致
                        for i, member in ipairs(current_team_info) do
                            local expected_member = env.team_info_data[i]
                            if not expected_member or member.name_utf8 ~= expected_member.name_utf8 or 
                               member.roleStatus ~= expected_member.roleStatus then
                                is_consistent = false
                                break
                            end
                        end
                    end
                    
                    if not is_consistent then
                        poe2_api.dbgp("队伍数据不一致，需要重新组队")
                        self.bool = false  -- 重置状态，触发重新组队
                        env.team_info_data = nil  -- 清除旧的队伍数据
                        return bret.RUNNING  -- 返回RUNNING让行为树重新执行组队逻辑
                    end
                    
                    poe2_api.dbgp("Team(SUCCESS1)")
                    poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                    return bret.SUCCESS
                end
                
                local a = 0
                for _, member in ipairs(team_info_data) do
                    if member.roleStatus == 2 or (member.roleStatus == 0 and member.name_utf8 == captain_name) then
                        a = a + 1
                    end
                end
                if a == num then
                    
                    poe2_api.dbgp("将小号加入到team_info")
                    for _, member in ipairs(team_info_data) do
                        if not poe2_api.table_contains(member.name_utf8,{ captain_name,leader_name}) and not poe2_api.table_contains(member.name_utf8,env.team_info["小號名"])then
                            table.insert(env.team_info["小號名"], member.name_utf8)
                        end
                    end
                    if poe2_api.find_text({ text = "社交", UI_info = env.UI_info, min_x=0, min_y=32, max_x=381, max_y=81}) then
                        poe2_api.click_keyboard("j")
                        api_Sleep(500)
                        poe2_api.dbgp("Team(RUNNING2)")
                        poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    end
                    self.bool = true
                    env.team_info_data = api_GetTeamInfo()
                    poe2_api.dbgp("Team(SUCCESS2)")
                    poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                    return bret.SUCCESS
                end
            elseif player_info.name_utf8 ~= captain_name then
                if poe2_api.find_text({UI_info = env.UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2}) then
                    return bret.RUNNING
                end
                for _, member in ipairs(team_info_data) do
                    if member.roleStatus == 0 and member.name_utf8 == captain_name then
                        poe2_api.dbgp("是指定队长")
                        if player_info.name_utf8 == leader_name and poe2_api.is_have_mos({range_info = range_info, player_info = player_info, dis = 70}) then
                            poe2_api.dbgp("Team(SUCCESS3)")
                            poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                            return bret.SUCCESS
                        end
                        if poe2_api.find_text({ text = "社交", UI_info = env.UI_info, min_x=0, min_y=32, max_x=381, max_y=81}) then
                            poe2_api.click_keyboard("j")
                            api_Sleep(500)
                            poe2_api.dbgp("Team(RUNNING3)")
                            poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                            return bret.RUNNING
                        end
                        poe2_api.dbgp("Team(RUNNING4)")
                        poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    elseif member.roleStatus == 0 and member.name_utf8 ~= captain_name then
                        poe2_api.dbgp("不是指定队长")
                        break
                    end
                end
            end
            if player_info.name_utf8 == captain_name then
                
                local function direct_parse_log_line(line, max_age_ms)
                    -- 直接按位置提取
                    -- 格式: 2025/09/13 14:37:31 447941390 3ef232c2 [INFO Client 10252] @來自 king_qq: king_qq
                    
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
                    local current_timestamp = api_GetTickCount64()  -- 当前时间（毫秒）
                    
                    -- 检查时间是否在指定毫秒范围内
                    if current_timestamp - log_timestamp > max_age_ms then
                        -- 日志时间太旧，跳过
                        return nil
                    end
                    
                    -- 找到@來自的位置
                    local at_pos = line:find("@來自")
                    if at_pos then
                        poe2_api.dbgp("我是队长")
                        -- 找到冒号的位置
                        local colon_pos = line:find(":", at_pos)
                        if colon_pos then
                            -- 只提取接收者名称（: 之后）
                            local receiver_name = line:sub(colon_pos + 1):gsub("^%s*(.-)%s*$", "%1")
                            
                            return {
                                timestamp = log_timestamp,
                                receiver_name = receiver_name
                            }
                        end
                    end
                    
                    return nil
                end
                -- 从文件末尾向前读取并解析，只读取指定毫秒时间范围内的内容
                local function process_recent_logs_unique(file_path, max_age_ms)
                    local file = io.open(file_path, "r")
                    if not file then
                        print("无法打开文件: " .. file_path)
                        return {}
                    end
                    
                    -- 读取整个文件内容
                    local content = file:read("*a")
                    file:close()
                    
                    -- 按行分割
                    local lines = {}
                    for line in content:gmatch("[^\r\n]+") do
                        table.insert(lines, line)
                    end
                    
                    -- 反转行顺序（从后往前，最新的在前面）
                    local reversed_lines = {}
                    for i = #lines, 1, -1 do
                        table.insert(reversed_lines, lines[i])
                    end
                    
                    local unique_receivers = {}  -- 使用表来去重
                    local receiver_names = {}    -- 最终结果：存储唯一的接收者名称
                    
                    for _, line in ipairs(reversed_lines) do
                        local parsed_line = direct_parse_log_line(line, max_age_ms)
                        if parsed_line then
                            local receiver_name = parsed_line.receiver_name
                            -- 检查是否已经存在，如果不存在则添加
                            if not unique_receivers[receiver_name] then
                                unique_receivers[receiver_name] = true
                                table.insert(receiver_names, receiver_name)
                            end
                        else
                            -- 如果遇到超时的记录，提前停止
                            break
                        end
                    end
                    
                    return receiver_names  -- 返回格式：{"king_qq", "other_name", ...}（唯一）
                end
                -- 处理日志文件，获取最近的接收者名称（5分钟内）
                local recent_receivers = process_recent_logs_unique(log_path, 5 * 60 * 1000)
                
                -- 过滤掉大号名，只保留小号名
                local small_account_names = {}
                for _, name in ipairs(recent_receivers) do
                    if name ~= leader_name then
                        table.insert(small_account_names, name)
                    end
                end
                
                -- 将小号名加入到 env.team_info["小號名"]
                if not env.team_info then
                    env.team_info = {}
                end
                env.team_info["小號名"] = small_account_names
                
                poe2_api.dbgp("找到的小号名: " .. table.concat(small_account_names, ", "))
            elseif player_info.name_utf8 ~= leader_name then
                local current_time = 0
                if current_time == 0  then
                    current_time = api_GetTickCount64()
                end
                if (not self.bool1) or (api_GetTickCount64() - current_time > 1000*60) then
                    poe2_api.dbgp("发送名字给队长")
                    self.bool1 = true
                    poe2_api.click_keyboard("enter")
                    api_Sleep(200)
                    poe2_api.paste_text("@"..captain_name.." "..player_info.name_utf8)
                    api_Sleep(200)
                    poe2_api.click_keyboard("enter")
                    -- 使用临时表进行去重检查
                    local temp_table = {}
                    for _, name in ipairs(env.team_info["小號名"]) do
                        temp_table[name] = true
                    end
                    
                    -- 如果不存在才添加
                    if not temp_table[player_info.name_utf8] then
                        table.insert(env.team_info["小號名"], player_info.name_utf8)
                        poe2_api.dbgp("添加小号名: " .. player_info.name_utf8)
                    else
                        poe2_api.dbgp("小号名已存在: " .. player_info.name_utf8)
                    end
                end
            end
            local function get_valid_members()
                -- 获取有效成员名单
                poe2_api.dbgp("获取有效成员名单")
                local members = {}
                if env.team_info["大號名"] and env.team_info["大號名"] ~= "" then
                    table.insert(members, {"大號名", env.team_info["大號名"]})
                end
                if env.team_info["隊長名"] and env.team_info["隊長名"] ~= "" then
                    table.insert(members, {"隊長名", env.team_info["隊長名"]})
                end
                if env.team_info["小號名"] then
                    for _, name in ipairs(env.team_info["小號名"]) do
                        table.insert(members, {"小號名", name})
                    end
                end
                return members
            end
            
            local function get_player_info()
                -- 获取当前玩家信息
                local current_player = player_info.name_utf8
                local result = {}
                for _, m in ipairs(get_valid_members()) do
                    if m[2] == current_player then
                        table.insert(result, m)
                    end
                end
                return result
            end
            
            local function get_team_info()
                -- 获取队友信息（排除自己）
                local current_player = player_info.name_utf8
                local result = {}
                for _, m in ipairs(get_valid_members()) do
                    if m[2] ~= current_player then
                        table.insert(result, m)
                    end
                end
                return result
            end
            
            local function get_game_not_team_info(team_members)
                -- 获取不在游戏队伍中的成员
                if team_info_data ~= nil then
                    local game_team_names_set = {}
                    for _, member in ipairs(team_info_data) do
                        game_team_names_set[member.name_utf8] = true
                    end
                    
                    local teams_names_set = {}
                    for _, member in ipairs(team_members) do
                        teams_names_set[member[2]] = true
                    end
                    
                    local not_in_team_names = {}
                    for name in pairs(teams_names_set) do
                        if not game_team_names_set[name] then
                            table.insert(not_in_team_names, name)
                        end
                    end
                    
                    if #not_in_team_names > 0 then
                        return not_in_team_names
                    else
                        return false
                    end
                end
                
                local result = {}
                for _, member in ipairs(team_members) do
                    table.insert(result, member[2])
                end
                return result
            end

            local player = get_player_info()
            if not player or #player == 0 then
                error("该号不在组队信息中，请修改组队配置信息")
            end
            if team_info_data and #team_info_data >= num and captain_name == player_info.name_utf8 then
                for _, member in ipairs(team_info_data) do
                    -- 检查成员是否不在队伍信息中
                    local found = false
                    for _, value in pairs(env.team_info) do
                        if type(value) == "table" then
                            for _, name in ipairs(value) do
                                if name == member.name_utf8 then
                                    found = true
                                    break
                                end
                            end
                        else
                            if value == member.name_utf8 then
                                found = true
                                break
                            end
                        end
                        if found then break end
                    end
                    
                    if not found then
                        if not poe2_api.find_text({ text = "社交", UI_info = env.UI_info, min_x=0, min_y=32, max_x=381, max_y=81}) then
                            poe2_api.click_keyboard("j")
                            api_Sleep(500)
                            poe2_api.dbgp("Team(RUNNING5)")
                            poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                            return bret.RUNNING
                        end
                        poe2_api.find_text({UI_info = env.UI_info, text = "目前隊伍", min_x = 0, click = 2,refresh = true})
                        poe2_api.find_text({UI_info = env.UI_info, text = "離開", min_x = 0, click = 2,refresh = true})
                        poe2_api.dbgp("Team(RUNNING6)")
                        poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    end
                end
            end
            -- 判断队伍是否完成
            if team_info_data ~= nil then
                local game_team_names_set = {}
                for _, member in ipairs(team_info_data) do
                    if member.roleStatus ~= 1 then
                        game_team_names_set[member.name_utf8] = true
                    end
                end
                
                local all_names = {}
                for _, role_type_value in pairs(env.team_info) do
                    if type(role_type_value) == "table" then
                        for _, name in ipairs(role_type_value) do
                            if name ~= nil then
                                all_names[name] = true
                            end
                        end
                    else
                        if role_type_value ~= nil then
                            all_names[role_type_value] = true
                        end
                    end
                end
                
                -- 检查all_names是否是game_team_names_set的子集
                local is_subset = true
                for name in pairs(all_names) do
                    if not game_team_names_set[name] then
                        is_subset = false
                        break
                    end
                end
                
                if is_subset then
                    if poe2_api.find_text({UI_info = env.UI_info, text = "社交", min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
                        poe2_api.click_keyboard("j")
                        api_Sleep(500)
                        poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    end
                    poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                    return bret.SUCCESS
                end
            end

            if player[1][1] == "隊長名" then
                if not poe2_api.find_text({UI_info = env.UI_info, text = "社交", min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
                    poe2_api.click_keyboard("j")
                    api_Sleep(500)
                    poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                    return bret.RUNNING
                end

                if not poe2_api.find_text({UI_info = env.UI_info, text = "隊伍邀請：", min_x = 0,refresh = true}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "建立隊伍", min_x = 0, click = 2,refresh = true})
                    poe2_api.find_text({UI_info = env.UI_info, text = "目前隊伍", min_x = 0, click = 2,refresh = true})
                    api_Sleep(500)
                    poe2_api.dbgp("Team(RUNNING7)")
                    poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                    return bret.RUNNING
                end

                local members = get_team_info()
                if members and #members > 0 then
                    local not_teams = get_game_not_team_info(members)
                    if not_teams then
                        poe2_api.find_text({UI_info = env.UI_info,text ="隊伍邀請：", min_x = 0, click = 2, add_x = 100,refresh = true})
                        api_Sleep(200)
                        poe2_api.paste_text(not_teams[1])  -- 获取第一个不在队伍中的成员
                        api_Sleep(200)
                        poe2_api.find_text({UI_info = env.UI_info,text = "隊伍邀請：", min_x = 0, click = 2, add_x = 274,refresh = true})
                        api_Sleep(5*1000)
                        poe2_api.dbgp("Team(RUNNING8)")
                        poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    end
                end
                poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                poe2_api.dbgp("Team(RUNNING9)")
                return bret.RUNNING

            elseif player[1][1] ~= "隊長名" then
                if not poe2_api.find_text({UI_info = env.UI_info, text = "社交", min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
                    poe2_api.click_keyboard("j")
                    api_Sleep(500)
                    poe2_api.dbgp("Team(RUNNING10)")
                    poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                    return bret.RUNNING
                end

                if not poe2_api.find_text({UI_info = env.UI_info, text = "隊伍邀請：", min_x = 0}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "建立隊伍", min_x = 0, click = 2})
                    poe2_api.find_text({UI_info = env.UI_info, text = "目前隊伍", min_x = 0, click = 2})
                    api_Sleep(500)
                    poe2_api.dbgp("Team(RUNNING11)")
                    poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                    return bret.RUNNING
                end

                local members = get_team_info()
                local function get_captain_name()
                    for _, member in ipairs(members) do
                        if member[1] == "隊長名" then
                            return member[2]
                        end
                    end
                    return false
                end

                if members and #members > 0 then
                    local captain = get_captain_name()
                    local game_team_names_set = {}
                    if team_info_data then
                        for _, member in ipairs(team_info_data) do
                            if member.roleStatus == 0 then
                                game_team_names_set[member.name_utf8] = true
                            end
                        end
                    end
                    
                    if captain then
                        if team_info_data and #team_info_data > 0 then
                            if not game_team_names_set[captain] then
                                poe2_api.find_text({UI_info = env.UI_info, text = "目前隊伍", min_x = 0, click = 2})
                                poe2_api.find_text({UI_info = env.UI_info, text = "離開", min_x = 0, click = 2})
                                api_Sleep(500)
                                poe2_api.dbgp("Team(RUNNING12)")
                                poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                                return bret.RUNNING
                            end
                            
                            local game_team_names_set2 = {}
                            for _, member in ipairs(team_info_data) do
                                if member.roleStatus == 2 then
                                    game_team_names_set2[member.name_utf8] = true
                                end
                            end
                            
                            if game_team_names_set2[player[1][2]] then
                                api_Sleep(1000)
                                poe2_api.dbgp("Team(RUNNING13)")
                                poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                                return bret.RUNNING
                            end
                        else
                            poe2_api.dbgp("接受")
                            if poe2_api.find_text({UI_info = env.UI_info, text = "接受", min_x = 0, max_x = 515, click = 2}) then
                                api_Sleep(500)
                                poe2_api.dbgp("Team(RUNNING14)")
                                poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                                return bret.RUNNING
                            end
                            api_Sleep(1000)
                            poe2_api.dbgp("Team(RUNNING15)")
                            poe2_api.time_p("Team", api_GetTickCount64() - current_time)
                            return bret.RUNNING
                        end
                    else
                        error("隊長信息获取失败,组队配置异常")
                    end
                end
            end
        end
    },
    -- 检查是否为大号
    Check_Role = {
        run = function(self, env)
            poe2_api.print_log("检查是否为大号")
            poe2_api.dbgp("[Check_Role]检查是否为大号")
            local player_info = env.player_info
            local team_info = env.team_info
            local current_time = api_GetTickCount64()
            local user_config = env.user_config
            local log_path = user_config["組隊設置"]["日志路径"]
            local leader_name = env.user_config["組隊設置"]["大號名"] or ""
            if player_info.name_utf8 ~= leader_name then
                poe2_api.dbgp("Check_Role(FAIL1)")
                return bret.FAIL
            end
             
            -- 将字符串转换为Lua表格式
            local function parse_data_string(data_str)
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
            local function direct_parse_log_line(line)
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
                        local parsed_data = parse_data_string(data)
                        
                        return {
                            timestamp = log_timestamp,
                            name = name,
                            data = parsed_data,
                        }
                    end
                end
                
                return nil
            end

            -- 从文件末尾向前读取并解析，只读取指定毫秒时间范围内的内容
            local function process_recent_logs_unique(file_path, max_age_ms)
                local file = io.open(file_path, "r")
                if not file then
                    print("无法打开文件: " .. file_path)
                    return {}
                end
                
                -- 读取整个文件内容
                local content = file:read("*a")
                file:close()
                
                -- 按行分割
                local lines = {}
                for line in content:gmatch("[^\r\n]+") do
                    table.insert(lines, line)
                end
                
                -- 反转行顺序（从后往前，最新的在前面）
                local reversed_lines = {}
                for i = #lines, 1, -1 do
                    table.insert(reversed_lines, lines[i])
                end
                
                local latest_data = {}  -- 最终结果：{name = parsed_data}
                local seen_names = {}   -- 跟踪每个名称的最新时间戳
                local current_timestamp = os.time() * 1000
                
                for _, line in ipairs(reversed_lines) do
                    -- 先快速检查时间格式
                    local date_time = line:sub(1, 19)
                    local year, month, day, hour, minute, second = date_time:match("^(%d+)/(%d+)/(%d+)%s+(%d+):(%d+):(%d+)$")
                    
                    if not (year and month and day and hour and minute and second) then
                        -- 不是有效的时间格式，跳过这行
                        goto continue
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
                    
                    local log_timestamp = os.time(time_table) * 1000
                    
                    -- 检查时间是否在指定毫秒范围内
                    if current_timestamp - log_timestamp > max_age_ms then
                        -- 日志时间太旧，提前返回
                        return latest_data
                    end
                    
                    -- 解析日志行（不再传递max_age_ms参数）
                    local parsed_line = direct_parse_log_line(line)
                    if parsed_line then
                        local name = parsed_line.name
                        local data = parsed_line.data
                        local timestamp = parsed_line.timestamp
                        
                        -- 如果这个名称还没有处理过，或者当前记录的时间戳更新，则更新数据
                        if not seen_names[name] or timestamp > seen_names[name] then
                            seen_names[name] = timestamp
                            latest_data[name] = data
                        end
                    end
                    
                    ::continue::
                end
                
                return latest_data
            end
            -- 获取队伍成员列表（排除自己）
            local function get_team_members()
                local members = {}
                
                -- 检查 team_info 中是否有 "小號名" 这个键
                if team_info["小號名"] then
                    -- 遍历小号列表
                    for _, small_name in ipairs(team_info["小號名"]) do
                        if small_name and small_name ~= player_info.name_utf8 then
                            table.insert(members, small_name)
                        end
                    end
                end
                
                -- 检查是否有队长且不是当前玩家
                if team_info["隊長名"] and team_info["隊長名"] ~= player_info.name_utf8 then
                    table.insert(members, team_info["隊長名"])
                end
                
                return members
            end

            -- 主逻辑
            local team_members = get_team_members()
            local num = env.user_config["組隊設置"]["隊伍人數"] or 1
            local expected_mission_count = num - 1

            -- 设置超时时间（如果在藏身处则30秒，否则5分钟）
            local max_time = 1000 * 60 * 10  -- 5分钟

            poe2_api.dbgp(max_time)
            -- 解析日志获取成员任务信息
            local member_task_info = process_recent_logs_unique(log_path, max_time)
            if not member_task_info or next(member_task_info) == nil then
                poe2_api.dbgp("没有找到队友发送的任务信息")
                poe2_api.time_p("Check_Role",api_GetTickCount64()- current_time)
                return bret.RUNNING
            end

            -- 检查接收到的任务数量
            local received_count = 0
            local stored_missions = {}
            local received_missions = {}

            -- 统计有效任务数量
            for name, mission_data in pairs(member_task_info) do
                if poe2_api.table_contains(name,team_members ) then
                    received_count = received_count + 1
                    stored_missions[name] = mission_data
                    table.insert(received_missions, mission_data)
                end
            end

            poe2_api.dbgp("接收到 " .. received_count .. " 个队友的任务信息，期望数量: " .. expected_mission_count)

            -- 检查是否所有小号信息都已接收完成
            if received_count >= expected_mission_count then
                poe2_api.dbgp("所有队友信息已接收完成")
                
                -- 查找最小任务索引
                local min_index = math.huge
                local task_name = "无"
                
                for _, mission_data in pairs(stored_missions) do
                    local current_index = tonumber(mission_data.task_index or math.huge)
                    
                    if current_index < min_index then
                        min_index = current_index
                        task_name = mission_data.task_name or "无"
                    end
                end
                                
                if task_name == "无" or not task_name or task_name == "" then
                    env.map_name = player_info.current_map_name_utf8 
                    env.task_name = nil
                    env.task_index = nil
                    poe2_api.dbgp("Check_Role(SUCCESS1)")
                    poe2_api.time_p("Check_Role",api_GetTickCount64() - current_time)
                    return bret.SUCCESS
                end
                
                -- 设置任务信息
                env.task_name = task_name
                env.task_index = tostring(min_index)
                
                poe2_api.dbgp("选择任务: " .. task_name .. ", 索引: " .. min_index)
                poe2_api.dbgp("Check_Role(SUCCESS2)")
                poe2_api.time_p("Check_Role",api_GetTickCount64() - current_time)
                return bret.SUCCESS
            else
                poe2_api.dbgp("等待更多队友信息，当前: " .. received_count .. "/" .. expected_mission_count)
                poe2_api.dbgp("Check_Role(RUNNING1)")
                poe2_api.time_p("Check_Role",api_GetTickCount64() - current_time)
                return bret.RUNNING
            end
        end
    },

    -- 大号查询本地任务信息
    Query_Current_Task_Information_Local = {
        run = function(self, env)
            poe2_api.print_log("大号查询本地任务信息")
            poe2_api.dbgp("[Query_Current_Task_Information_Local]大号查询本地任务信息")
            local team_info_data = env.team_info_data
            local task_name = env.task_name
            local player_info = env.player_info
            local current_time = api_GetTickCount64()
            local team_info = env.team_info
            local user_config = env.user_config

            -- 获取队友位置
            local function party_pos(name)
                poe2_api.dbgp("[party_pos]获取队友位置:", name)
                for _, member in ipairs(team_info_data) do
                    if member["name_utf8"] == name then
                        return member["current_map_name_utf8"]
                    end
                end
                return nil
            end

            -- 判断队友当前位置
            local function party_member_map(map)
                poe2_api.dbgp("[party_member_map]判断队友当前位置:", map)
                for _, member in ipairs(team_info_data) do
                    if poe2_api.table_contains(map, member["current_map_name_utf8"]) then
                        return true
                    end
                end
                return false
            end


            local task = poe2_api.get_task_info(main_task.tasks_data, task_name)
            if next(task) then
                if poe2_api.click_text_UI({ UI_info = env.UI_info, text = "respawn_at_checkpoint_button" }) and not env.special_relife_point then
                    poe2_api.click_keyboard("space")
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]RUNNING1")
                    return bret.RUNNING
                end

                if task.boss_name then
                    poe2_api.dbgp("检测到boss_name：", task.boss_name)
                    env.boss_name = task.boss_name
                else
                    env.boss_name = nil
                end

                if task.map_name then
                    poe2_api.dbgp("检测到map_name：", task.map_name)
                    env.map_name = task.map_name
                else
                    env.map_name = nil
                end

                if task.interaction_object then
                    poe2_api.dbgp("检测到interaction_object：", task.interaction_object)
                    env.interaction_object = task.interaction_object
                else
                    env.interaction_object = nil
                end

                if task.interaction_ui then
                    poe2_api.dbgp("检测到interaction_ui：", task.interaction_ui)
                    env.interaction_ui = task.interaction_ui
                else
                    env.interaction_ui = nil
                end

                if task.grid_x then
                    poe2_api.dbgp("检测到grid_x：", task.grid_x)
                    env.grid_x = task.grid_x
                else
                    env.grid_x = nil
                end

                if task.grid_y then
                    poe2_api.dbgp("检测到grid_y：", task.grid_y)
                    env.grid_y = task.grid_y
                else
                    env.grid_y = nil
                end

                if task.special_map_point then
                    poe2_api.dbgp("检测到special_map_point：", task.special_map_point)
                    env.special_map_point = task.special_map_point
                else
                    env.special_map_point = nil
                end

                if task.interaction_object_map_name then
                    poe2_api.dbgp("检测到interaction_object_map_name：", task.interaction_object_map_name)
                    env.interaction_object_map_name = task.interaction_object_map_name
                else
                    env.interaction_object_map_name = nil
                end

                if party_member_map({ "G3_6_2"}) and task.task_name == "與艾瓦對話" then
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]與艾瓦對話")
                    env.map_name = "G3_6_2"
                    env.interaction_object_map_name = { "艾瓦" }
                    env.interaction_object = { "艾瓦" }
                elseif party_member_map({ "G3_6_1"}) and task.task_name == "召喚艾瓦詢問她的建議" then
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]召喚艾瓦詢問她的建議")
                    env.map_name = "G3_6_1"
                    env.interaction_object_map_name = {'艾瓦'}
                    env.interaction_object = {'召喚艾瓦', '艾瓦', '門'}
                elseif party_member_map({ "G3_6_2"}) and task.task_name == "召喚艾瓦，尋求她的意見" then
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]召喚艾瓦，尋求她的意見")
                    env.map_name = "G3_6_2"
                    env.interaction_object = { '中型靈魂核心', ' <questitem>{發電機}', '門' }
                elseif (party_member_map({ "G2_town"}) or player_info.current_map_name_utf8 =="G2_3a") and task.task_name == "返回車隊，與芮蘇討論封閉的古老關口" then
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]返回車隊，與芮蘇討論封閉的古老關口")
                    env.map_name = "G2_town"
                    env.interaction_object = { "芮蘇" }
                elseif party_member_map({  "G2_9_2" }) and task.boss_name and poe2_api.table_contains(task.boss_name, "憎惡者．賈嫚拉") then
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]憎惡者．賈嫚拉")
                    env.map_name = "G2_9_2"
                    env.boss_name = { "玷汙者托爾．谷爾" }
                    env.interaction_object = { "ToGuive", "卡洛翰的姐妹" }
                    env.interaction_object_map_name = { "TorGulActive" }
                end
                poe2_api.dbgp("[Query_Current_Task_Information_Local]SUCCESS1")
                poe2_api.time_p("[Query_Current_Task_Information_Local]",(api_GetTickCount64() - current_time))
                return bret.SUCCESS
            end
            if poe2_api.find_text({ UI_info = env.UI_info, text = "快行" }) then
                poe2_api.dbgp("[Query_Current_Task_Information_Local]SUCCESS2")
                return bret.SUCCESS
            end
            if not next(task) then
                local maps = env.map_name
                if maps then
                    if maps == "ctask" then
                        error("任务完成")
                    end
                    if maps == "G3_7" then
                        poe2_api.dbgp("检测到G3_7：")
                        if poe2_api.table_contains(player_info.current_map_name_utf8, { "G3_7", "G3_town", "G3_8" }) then
                            env.map_name = "G3_town"
                        end
                        env.interaction_object = { "召喚瑟維", "瑟維" }
                    end
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]SUCCESS3")
                    return bret.SUCCESS
                end
                if not maps then
                    poe2_api.dbgp("未识别到小号任务")
                    return bret.RUNNING
                end
            end
            poe2_api.dbgp("[Query_Current_Task_Information_Local]SUCCESS4")
            return bret.SUCCESS
        end
    },

    -- 小号查询任务信息
    Query_Current_Task_Information = {
        run = function(self, env)
            poe2_api.print_log("小号查询任务信息")
            local current_time = api_GetTickCount64()
            poe2_api.dbgp("[Query_Current_Task_Information]小号查询任务信息")
            if self.raw_time == nil then
                self.raw = {}
                self.raw_time = 0
                self.update = {}
                self.mas = nil
            end
            local range_info = env.range_info
            local player_info = env.player_info
            local waypoint = env.waypoint
            local bag_info = env.bag_info
            local current_map_info = env.current_map_info
            local team_info = env.team_info
            local config = env.user_config
            local max_time = 1000 * 60 * 5  -- 5分钟
            local function bag_object_sum(name)
                poe2_api.dbgp("[Query_Current_Task_Information]检测背包中的物品数量：")
                if not bag_info then
                    return false
                end
                local a = 0
                for _, obj in pairs(bag_info) do
                    if obj.baseType_utf8 == name then
                        a = a + 1
                    end
                end
                return a
            end
            local function mini_map_obj(name)
                poe2_api.dbgp("[Query_Current_Task_Information]检测地图上是否存在物体：", name)
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == name and item.flagStatus1 == 1 then
                        return item  -- 直接返回第一个匹配项
                    end
                end
                return nil -- 无匹配时返回nil
            end

            local function deep_equal_unordered(a, b)
                poe2_api.dbgp("[Query_Current_Task_Information]两个table是否完全相同")
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end
                if #a ~= #b then return false end

                -- 统计 a 的元素（支持嵌套 table）
                local count = {}
                for _, v in ipairs(a) do
                    local key = type(v) == "table" and table.concat(v, ",") or tostring(v)
                    count[key] = (count[key] or 0) + 1
                end

                -- 检查 b 的元素
                for _, v in ipairs(b) do
                    local key = type(v) == "table" and table.concat(v, ",") or tostring(v)
                    if not count[key] then return false end
                    count[key] = count[key] - 1
                end

                return true
            end

            local function paste_text(text)
                -- 然后输入百分号（Shift+5）
                poe2_api.click_keyboard("shift", 1)  -- 按下shift
                api_Sleep(200)
                poe2_api.click_keyboard("5", 0)      -- 按下5（配合shift产生%）
                api_Sleep(200)
                poe2_api.click_keyboard("shift", 2)  -- 释放shift
                api_Sleep(200)
                -- 先输入原有文本
                api_SetClipboard(text)
                api_Sleep(200)
                poe2_api.click_keyboard("ctrl", 1)
                api_Sleep(200)
                poe2_api.click_keyboard("v", 0)
                api_Sleep(200)
                poe2_api.click_keyboard("ctrl", 2)
                api_Sleep(200)
            end

            --- 根据主任务顺序获取任务状态
            -- @param api_result api_GetQuestList(0)返回的结果
            -- @param main_task_order 主任务顺序列表
            -- @return 按主任务顺序排列的未完成子任务详情列表（如果主任务完成则跳过）
            local function get_ordered_quest_status(api_result, main_task_order)
                -- 创建主任务到任务详情的映射
                local task_dict = {}
                for _, task in ipairs(api_result) do
                    local main_quest = task.MainQuestName
                    local sub_quest_state = task.SubQuestState
                    local description = task.Description
                    
                    if not main_quest then
                        poe2_api.dbgp("[Query_Current_Task_Information]获取不到任务信息")
                        return bret.RUNNING
                    end
                    
                    if not task_dict[main_quest] then
                        task_dict[main_quest] = {}
                    end
                    
                    -- 只添加未完成的任务
                    if sub_quest_state ~= "任務完成" and description ~= "" then
                        table.insert(task_dict[main_quest], {
                            state = sub_quest_state,
                            description = description
                        })
                    end
                end
                local quest_details = {}
                local seen_details = {} -- 用于快速查找重复项
                
                for _, main_task in ipairs(main_task_order) do
                    if task_dict[main_task] and #task_dict[main_task] > 0 then
                        -- 遍历该主任务的所有未完成子任务
                        for _, quest in ipairs(task_dict[main_task]) do
                            local detail = quest.description
                            -- 检查是否已经存在相同的详情且不为空
                            if detail and detail ~= "" and not seen_details[detail] then
                                table.insert(quest_details, detail)
                                seen_details[detail] = true -- 标记为已存在
                            end
                        end
                    end
                end
                
                return quest_details
            end
            -- poe2_api.printTable(api_GetQuestList(0))
            local main_task_info = get_ordered_quest_status(api_GetQuestList(0), my_game_info.mian_task)
            if next(main_task_info) then
                -- 处理main_task_info中的反斜杠和换行符
                for i = 1, #main_task_info do
                    if type(main_task_info[i]) == "string" then
                        -- 移除反斜杠和数字序列（如\13），换行符和所有空格
                        main_task_info[i] = main_task_info[i]:gsub("\\%d+", ""):gsub("\\", ""):gsub("[\n%s]", "")
                    end
                end
                -- poe2_api.printTable(main_task_info)
                if (poe2_api.table_contains(main_task_info, "追尋傳奇人物奧爾巴拉的腳步，重鑄瓦斯提里的戰角") or poe2_api.table_contains(main_task_info, "跟艾瓦談談發生的事")) and #(main_task_info) > 1 then
                    task = poe2_api.get_task_info(main_task.tasks_data,main_task_info[2]) 
                else
                    task = poe2_api.get_task_info(main_task.tasks_data,main_task_info[1])
                end
            else
                task = nil
            end
            if poe2_api.find_text({UI_info = env.UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2}) then
                return bret.RUNNING
            end
            
            if task and next(task) then
                self.mas = nil
                env.special_relife_point = false
                env.task_name = task.task_name
                if poe2_api.click_text_UI({ UI_info = env.UI_info, text = "respawn_at_checkpoint_button" }) then
                    poe2_api.click_keyboard("space")
                    poe2_api.dbgp("[Query_Current_Task_Information]RUNNING1")
                    return bret.RUNNING
                end
                if task.boss_name then
                    poe2_api.dbgp("检测到boss_name：", task.boss_name)
                    env.boss_name = task.boss_name
                else
                    env.boss_name = nil
                end

                if task.map_name then
                    poe2_api.dbgp("检测到map_name：", task.map_name)
                    env.map_name = task.map_name
                else
                    env.map_name = nil
                end

                if task.interaction_object then
                    poe2_api.dbgp("检测到interaction_object：", task.interaction_object)
                    env.interaction_object = task.interaction_object
                else
                    env.interaction_object = nil
                end

                if task.interaction_ui then
                    poe2_api.dbgp("检测到interaction_ui：", task.interaction_ui)
                    env.interaction_ui = task.interaction_ui
                else
                    env.interaction_ui = nil
                end

                if task.grid_x then
                    poe2_api.dbgp("检测到grid_x：", task.grid_x)
                    env.grid_x = task.grid_x
                else
                    env.grid_x = nil
                end

                if task.grid_y then
                    poe2_api.dbgp("检测到grid_y：", task.grid_y)
                    env.grid_y = task.grid_y
                else
                    env.grid_y = nil
                end

                if task.special_map_point then
                    poe2_api.dbgp("检测到special_map_point：", task.special_map_point)
                    env.special_map_point = task.special_map_point
                else
                    env.special_map_point = nil
                end

                if task.interaction_object_map_name then
                    poe2_api.dbgp("检测到interaction_object_map_name：", task.interaction_object_map_name)
                    env.interaction_object_map_name = task.interaction_object_map_name
                else
                    env.interaction_object_map_name = nil
                end

                if not poe2_api.table_contains(player_info.current_map_name_utf8, { "G3_town" }) and task.task_name == "回到過去，進入奧札爾" then
                    poe2_api.dbgp("[Query_Current_Task_Information]回到過去，進入奧札爾")
                    env.map_name = "G3_town"
                    task.task_name = "高地神塔營地"
                    env.task_name = task.task_name
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G3_6_2" }) and task.task_name == "與艾瓦對話" then
                    poe2_api.dbgp("[Query_Current_Task_Information]與艾瓦對話")
                    env.map_name = "G3_6_2"
                    env.interaction_object_map_name = { "艾瓦" }
                    env.interaction_object = { "艾瓦" }
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G3_6_2" }) and task.task_name == "召喚艾瓦，尋求她的意見" then
                    poe2_api.dbgp("[Query_Current_Task_Information]召喚艾瓦，尋求她的意見")
                    env.map_name = "G3_6_2"
                    env.interaction_object = { '中型靈魂核心', ' <questitem>{發電機}', '門' }
                elseif player_info.current_map_name_utf8 == "G3_6_1" and task.task_name == "召喚艾瓦詢問她的建議" then
                    poe2_api.dbgp("[Query_Current_Task_Information_Local]召喚艾瓦詢問她的建議")
                    env.map_name = "G3_6_1"
                    env.interaction_object_map_name = {'艾瓦'}
                    env.interaction_object = {'召喚艾瓦', '艾瓦', '門'}
                elseif player_info.current_map_name_utf8 == "G2_3a" and task.task_name == "使用貧脊之地的地圖前往哈拉妮關口所在之處" then
                    poe2_api.dbgp("[Query_Current_Task_Information]G2_3a使用貧脊之地的地圖前往哈拉妮關口所在之處")
                    env.map_name = "G2_3a"
                    env.grid_x = 587
                    env.grid_y = 733
                    env.interaction_object = { "絲克瑪．阿薩拉" }
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G2_town"}) and task.task_name == "返回車隊，與芮蘇討論封閉的古老關口" then
                    poe2_api.dbgp("[Query_Current_Task_Information]返回車隊，與芮蘇討論封閉的古老關口")
                    env.map_name = "G2_town"
                    env.interaction_object = { "芮蘇" }
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, {  "G2_9_2" }) then
                    poe2_api.dbgp("[Query_Current_Task_Information]前往戴斯哈尖塔")
                    local sister = poe2_api.get_sorted_obj("卡洛翰的姐妹", range_info, player_info)
                    if ((task.boss_name and poe2_api.table_contains('憎惡者．賈嫚拉', task.boss_name))) or not mini_map_obj('SacredSpiresShrineLandmarkInactive') or (sister and #sister > 0 and sister[1].stateMachineList and sister[1].stateMachineList.active == 0) then
                        env.map_name = "G2_9_2"
                        task.task_name = "戴斯哈尖塔"
                        env.task_name = task.task_name
                        env.boss_name = { "玷汙者托爾．谷爾" }
                        env.interaction_object = { "ToGuive", "卡洛翰的姐妹" }
                        env.interaction_object_map_name = { "TorGulActive" }
                    end
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G1_12" }) and not poe2_api.check_item_in_inventory("寶石花顱骨", bag_info) then
                    poe2_api.dbgp("[Query_Current_Task_Information]收集寶石花顱骨")
                    task.task_name = "擊敗迷霧之王"
                    env.task_name = task.task_name
                    env.map_name = "G1_12"
                    env.boss_name = { "迷霧之王" }
                    env.interaction_object = { " 祭祀神壇", "寶石花顱骨" }
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G2_4_1" }) and not poe2_api.check_item_in_inventory("卡巴拉部落聖物", bag_info) then
                    poe2_api.dbgp("[Query_Current_Task_Information]收集卡巴拉部落聖物 - 1")
                    task.task_name = "凱斯城"
                    env.task_name = task.task_name
                    env.map_name = "G2_4_1"
                    env.boss_name = { "異界．干擾女王．卡巴拉" }
                    env.interaction_object = { "卡巴拉部落聖物" }
                    env.interaction_object_map_name = nil
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G2_5_2" }) and not poe2_api.check_item_in_inventory("太陽部落聖物", bag_info) then
                    poe2_api.dbgp("[Query_Current_Task_Information]收集太陽部落聖物 - 1")
                    task.task_name = "骨坑"
                    env.task_name = task.task_name
                    env.map_name = "G2_5_2"
                    env.interaction_object = { "太陽部落聖物" }
                    env.interaction_object_map_name = nil
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G3_14" }) and not poe2_api.check_item_in_inventory("犧牲之心", bag_info) then
                    poe2_api.dbgp("[Query_Current_Task_Information]收集犧牲之心 - 1")
                    task.task_name = "奧札爾"
                    env.task_name = task.task_name
                    env.map_name = "G3_14"
                    env.interaction_object = { "犧牲之心" }
                    env.interaction_object_map_name = nil
                elseif poe2_api.table_contains(player_info.current_map_name_utf8, { "G3_7" }) and not poe2_api.check_item_in_inventory("傑洛特顱骨", bag_info) then
                    poe2_api.dbgp("[Query_Current_Task_Information]收集傑洛特顱骨")
                    task.task_name = "阿札克泥沼"
                    env.task_name = task.task_name
                    env.map_name = "G3_7"
                    env.interaction_object = { "傑洛特顱骨" }
                    env.interaction_object_map_name = nil
                elseif player_info.current_map_name_utf8 == "G2_1" and env.map_name ~="G2_1" then
                    task.task_name = "進入阿杜拉車隊"
                    env.task_name = task.task_name
                    env.map_name = "G2_1"
                    env.interaction_object = {'阿杜拉車隊'}
                    env.interaction_object_map_name = {'G2_town'}
                elseif player_info.current_map_name_utf8 == "G3_1" and env.map_name ~="G3_1" then
                    task.task_name = "高地神塔營地"
                    env.task_name = task.task_name
                    env.map_name = "G3_town"
                end
                if poe2_api.get_team_info(team_info, config, player_info, 1) ~= "大號名" then
                    poe2_api.dbgp("[Query_Current_Task_Information]有task发送任务信息")
                    if not poe2_api.table_contains(player_info.current_map_name_utf8, { "G1_1" }) and not poe2_api.find_text({ UI_info = env.UI_info, text = "抵達皆伐" }) then
                        if not next(self.raw) or (self.raw_time ~= 0 and api_GetTickCount64() - self.raw_time > max_time) then
                            -- 发送任务信息
                            local task_text = "task_name=" .. task.task_name .. ",task_index=" .. task.index ..",map_name=" .. env.map_name
                            poe2_api.click_keyboard("enter")
                            api_Sleep(200)
                            poe2_api.click_keyboard("backspace")
                            api_Sleep(200)
                            paste_text(task_text)
                            api_Sleep(500)
                            poe2_api.click_keyboard("enter")
                            api_Sleep(500)
                            self.raw_time = api_GetTickCount64()
                            self.raw = { task.task_name, task.index }
                        end
                        self.update = { task.task_name, task.index }
                        if not deep_equal_unordered(self.raw, self.update) then
                            self.raw = {}
                            poe2_api.dbgp("[Query_Current_Task_Information]RUNNING2")
                            return bret.RUNNING
                        end
                    end
                end
            else
                poe2_api.dbgp("[Query_Current_Task_Information]无task发送任务信息")
                env.task_name = nil
                env.map_name = nil
                env.interaction_object = nil
                env.interaction_object_map_name = nil
                self.mas = nil
                if poe2_api.click_text_UI({ UI_info = env.UI_info, text = "respawn_at_checkpoint_button" }) then
                    poe2_api.click_keyboard("space")
                    poe2_api.dbgp("[Query_Current_Task_Information]RUNNING3")
                    return bret.RUNNING
                end
                if not self.mas then
                    self.mas, finished_tasks = poe2_api.check_task_map_without()
                    if not self.mas and not next(finished_tasks) then
                        poe2_api.print_log("没有任务信息")
                        poe2_api.dbgp("[Query_Current_Task_Information]RUNNING4")
                        return bret.RUNNING
                    end
                end
                if player_info.level < 2 or player_info.current_map_name_utf8 == "G1_1" then
                    poe2_api.dbgp("[Query_Current_Task_Information]新手剧情")
                    env.task_name = "與受傷的居民交談"
                    env.map_name = "G1_1"
                    env.interaction_object = { "受傷的男人" }
                    poe2_api.dbgp("[Query_Current_Task_Information]SUCCESS1")
                    poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                    return bret.SUCCESS
                else
                    if self.mas == "G2_town" then
                        poe2_api.dbgp("[Query_Current_Task_Information]获取G2_town地图任务信息")
                        
                        if not poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖",refresh = true}) then
                            poe2_api.click_keyboard("u")
                        end
                        api_Sleep(200)
                        env.waypoint = api_GetTeleportationPoint()
                        api_Sleep(200)
                        poe2_api.click_keyboard("u")
                        if poe2_api.Waypoint_is_open("G3_town", waypoint) then
                            poe2_api.dbgp("[Query_Current_Task_Information]RUNNING5")
                            return bret.RUNNING
                        end
                        if poe2_api.get_team_info(team_info, config, player_info, 2) ~= "大號名" then
                            local task_text = "task_name=" .. "返回阿杜拉車隊，並與札卡交談" .. ",task_index=" .. 83 ..",map_name=" .. self.mas
                            poe2_api.click_keyboard("enter")
                            api_Sleep(500)
                            paste_text(task_text)
                            api_Sleep(500)
                            poe2_api.click_keyboard("enter")
                            api_Sleep(500)
                            env.map_name = self.mas
                            poe2_api.dbgp("[Query_Current_Task_Information]SUCCESS2")
                            poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                            return bret.SUCCESS
                        end
                    elseif self.mas == "G3_town" then
                        poe2_api.dbgp("[Query_Current_Task_Information]获取G3_town地图任务信息")
                        if poe2_api.get_team_info(team_info, config, player_info, 2) ~= "大號名" then
                            if not next(self.raw) or (self.raw_time ~= 0 and api_GetTickCount64() - self.raw_time > max_time) then
                                -- 发送任务信息
                                local task_text = "task_name=" .. "高地神塔營地" .. ",task_index=" .. 179 ..",map_name=" .. self.mas
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                paste_text(task_text)
                                api_Sleep(500)
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                self.raw_time = api_GetTickCount64()
                                self.raw = { "高地神塔營地", 179 }
                            end
                            self.update = { "高地神塔營地", 179 }
                            if not deep_equal_unordered(self.raw, self.update) then
                                self.raw = {}
                                poe2_api.dbgp("[Query_Current_Task_Information]RUNNING2")
                                return bret.RUNNING
                            end
                            env.map_name = self.mas
                            poe2_api.dbgp("[Query_Current_Task_Information]SUCCESS3")
                            poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                            return bret.SUCCESS
                        end
                    elseif self.mas == "G1_12" then
                        poe2_api.dbgp("[Query_Current_Task_Information]获取G1_12地图任务信息")
                        if poe2_api.get_team_info(team_info, config, player_info, 2) ~= "大號名" then
                            if not next(self.raw) or (self.raw_time ~= 0 and api_GetTickCount64() - self.raw_time > max_time) then
                                -- 发送任务信息
                                local task_text = "task_name=" .. "尋找祭祀神壇並淨化它們" .. ",task_index=" .. 80 ..",map_name=" .. self.mas
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                paste_text(task_text)
                                api_Sleep(500)
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                self.raw_time = api_GetTickCount64()
                                self.raw = { "尋找祭祀神壇並淨化它們", 80 }
                            end
                            self.update = { "尋找祭祀神壇並淨化它們", 80 }
                            if not deep_equal_unordered(self.raw, self.update) then
                                self.raw = {}
                                poe2_api.dbgp("[Query_Current_Task_Information]RUNNING2")
                                return bret.RUNNING
                            end
                            env.map_name = self.mas
                            poe2_api.dbgp("[Query_Current_Task_Information]SUCCESS4")
                            poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                            return bret.SUCCESS
                        end
                    elseif self.mas == "G3_7" then
                        poe2_api.dbgp("[Query_Current_Task_Information]获取G3_7地图任务信息")
                        if poe2_api.table_contains(player_info.current_map_name_utf8, { "G3_town", "G3_7", "G3_8" }) then
                            env.grid_x = nil
                            env.grid_y = nil
                            env.interaction_object = { "召喚瑟維", "瑟維" }
                            if poe2_api.get_team_info(team_info, config, player_info, 2) ~= "大號名" then
                                if not next(self.raw) or (self.raw_time ~= 0 and api_GetTickCount64() - self.raw_time > max_time) then
                                    -- 发送任务信息
                                    local task_text = "task_name=" .. "阿札克泥沼" .. ",task_index=" .. 250 ..",map_name=" .. self.mas
                                    poe2_api.click_keyboard("enter")
                                    api_Sleep(500)
                                    paste_text(task_text)
                                    api_Sleep(500)
                                    poe2_api.click_keyboard("enter")
                                    api_Sleep(500)
                                    self.raw_time = api_GetTickCount64()
                                    self.raw = { "阿札克泥沼", 250 }
                                end
                                self.update = { "阿札克泥沼", 250 }
                                if not deep_equal_unordered(self.raw, self.update) then
                                    self.raw = {}
                                    poe2_api.dbgp("[Query_Current_Task_Information]RUNNING2")
                                    return bret.RUNNING
                                end
                                env.map_name = self.mas
                                poe2_api.dbgp("[Query_Current_Task_Information]SUCCESS5")
                                poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                                return bret.SUCCESS
                            end
                        else
                            poe2_api.dbgp("[Query_Current_Task_Information]前往G3_7,先前往G3_town地图")
                            if poe2_api.get_team_info(team_info, config, player_info, 2) ~= "大號名" then
                                if not next(self.raw) or (self.raw_time ~= 0 and api_GetTickCount64() - self.raw_time > max_time) then
                                    -- 发送任务信息
                                    local task_text = "task_name=" .. "高地神塔營地" .. ",task_index=" .. 0 ..",map_name=" .. "G3_town"
                                    poe2_api.click_keyboard("enter")
                                    api_Sleep(500)
                                    paste_text(task_text)
                                    api_Sleep(500)
                                    poe2_api.click_keyboard("enter")
                                    api_Sleep(500)
                                    self.raw_time = api_GetTickCount64()
                                    self.raw = { "高地神塔營地", 0 }
                                end
                                self.update = { "高地神塔營地", 0 }
                                if not deep_equal_unordered(self.raw, self.update) then
                                    self.raw = {}
                                    poe2_api.dbgp("[Query_Current_Task_Information]RUNNING2")
                                    return bret.RUNNING
                                end
                                env.map_name = "G3_town"
                                poe2_api.dbgp("[Query_Current_Task_Information]SUCCESS6")
                                poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                                return bret.SUCCESS
                            end
                        end
                    elseif self.mas == "G4_1_1" then
                        poe2_api.dbgp("[Query_Current_Task_Information]获取G4_1_1地图任务信息")
                        if poe2_api.get_team_info(team_info, config, player_info, 2) ~= "大號名" then
                            if not next(self.raw) or (self.raw_time ~= 0 and api_GetTickCount64() - self.raw_time > max_time) then
                                -- 发送任务信息
                                local task_text = "task_name=" .. "金氏島" .. ",task_index=" .. 278 ..",map_name=" .. self.mas
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                paste_text(task_text)
                                api_Sleep(500)
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                self.raw_time = api_GetTickCount64()
                                self.raw = { "金氏島", 278 }
                            end
                            self.update = { "金氏島", 278 }
                            if not deep_equal_unordered(self.raw, self.update) then
                                self.raw = {}
                                poe2_api.dbgp("[Query_Current_Task_Information]金氏島RUNNING2")
                                return bret.RUNNING
                            end
                            env.map_name = self.mas
                            poe2_api.dbgp("[Query_Current_Task_Information]金氏島SUCCESS3")
                            poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                            return bret.SUCCESS
                        end
                    elseif self.mas == "G4_4_1" then
                        poe2_api.dbgp("[Query_Current_Task_Information]获取G4_4_1地图任务信息")
                        if poe2_api.get_team_info(team_info, config, player_info, 2) ~= "大號名" then
                            if not next(self.raw) or (self.raw_time ~= 0 and api_GetTickCount64() - self.raw_time > max_time) then
                                -- 发送任务信息
                                local task_text = "task_name=" .. "悉妮蔻拉之眼" .. ",task_index=" .. 278 ..",map_name=" .. self.mas
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                paste_text(task_text)
                                api_Sleep(500)
                                poe2_api.click_keyboard("enter")
                                api_Sleep(500)
                                self.raw_time = api_GetTickCount64()
                                self.raw = { "悉妮蔻拉之眼", 278 }
                            end
                            self.update = { "悉妮蔻拉之眼", 278 }
                            if not deep_equal_unordered(self.raw, self.update) then
                                self.raw = {}
                                poe2_api.dbgp("[Query_Current_Task_Information]悉妮蔻拉之眼-RUNNING2")
                                return bret.RUNNING
                            end
                            env.map_name = self.mas
                            poe2_api.dbgp("[Query_Current_Task_Information]-悉妮蔻拉之眼-SUCCESS3")
                            poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
                            return bret.SUCCESS
                        end
                    end
                end
                self.mas = nil
                poe2_api.dbgp("[Query_Current_Task_Information]RUNNING10")
                return bret.RUNNING
            end
            poe2_api.time_p("[Query_Current_Task_Information]",(api_GetTickCount64() - current_time))
            return bret.SUCCESS
        end
    },

    -- 是否队伍中存在死亡队友
    Is_Exception_Team = {
        run = function(self, env)
            poe2_api.print_log("判断是否队伍中存在死亡队友...")
            poe2_api.dbgp("=== 开始判断是否队伍中存在死亡队友 ===")
            if self.bool == nil then
                self.bool = false
            end
            local team_info_data = env.team_info_data
            local range_info = env.range_info
            local player_info = env.player_info
            local boss_name = env.boss_name
            local team_info = env.team_info
            local user_config = env.user_config
            local function is_death(range_info, team_info)
                poe2_api.dbgp("[Is_Exception_Team]判断是否存在死亡队友...")
                -- 将 team_info 转换为字典，以 name_utf8 作为键
                local team_dict = {}
                for _, member in ipairs(team_info) do
                    team_dict[member.name_utf8] = member
                end

                -- 遍历 range_info，查找生命值为 0 的友好成员
                for _, i in ipairs(range_info) do
                    if i.is_friendly and i.life == 0 and team_dict[i.name_utf8] then
                        return i
                    end
                end

                return false
            end

            local function is_monster(range_info, mate)
                poe2_api.dbgp("[Is_Exception_Team]判断死亡队友是否存在撕裂者...")
                local mx, my = mate.grid_x, mate.grid_y
                -- 查找符合条件的怪物
                for _, i in ipairs(range_info) do
                    if not i.is_friendly and i.life > 0 and i.name_utf8 ~= ""
                        and (i.name_utf8 == "撕裂者" or i.name_utf8 == "白之亞瑪")
                        and poe2_api.get_point_distance(mate.grid_x, mate.grid_y, i.grid_x, i.grid_y) < 200 then
                        return i
                    end
                end
                return false
            end

            local function check_pos_dis(names, range_info, player_info)
                poe2_api.dbgp("[Is_Exception_Team]判断指定名称与主角的距离")
                if range_info ~= nil then
                    for _, point in ipairs(range_info) do
                        if point.name_utf8 == names then
                            local l = poe2_api.point_distance(point.grid_x, point.grid_y, player_info)
                            return l
                        end
                    end
                end
                return nil
            end

            if not next(team_info_data) or not next(range_info) then
                poe2_api.dbgp("[Is_Exception_Team]没组队")
                env.monster_info = nil
                self.bool = false
                env.relife_stuck_monsters = {}
                return bret.SUCCESS
            end
            local mate = is_death(range_info, team_info_data)

            if not mate then
                poe2_api.dbgp("[Is_Exception_Team]不存在死亡队友")
                self.bool = false
                env.relife_stuck_monsters = {}
                env.life_time = nil
                env.monster_info = nil
                return bret.SUCCESS
            end
            if player_info.life == 0 then
                poe2_api.dbgp("[Is_Exception_Team]玩家已死亡")
                env.life_time = nil
                env.relife_stuck_monsters = {}
                env.monster_info = nil
                return bret.RUNNING
            end
            if (boss_name or player_info.isInBossBattle) and not poe2_api.table_contains(player_info.current_map_name_utf8,{"G4_4_1","G4_4_2"})  then
                local boss_info = poe2_api.is_have_boss_distance(range_info, player_info, boss_name, 180)
                if boss_info or player_info.isInBossBattle then
                    poe2_api.dbgp("[Is_Exception_Team]当前处于BOSS战斗中")
                    env.life_time = nil
                    env.relife_stuck_monsters = {}
                    env.monster_info = nil
                    return bret.SUCCESS
                end
            end
            if is_monster(range_info, player_info) then
                poe2_api.dbgp("[Is_Exception_Team]玩家当前有撕裂者或白之亞瑪")
                env.life_time = nil
                env.relife_stuck_monsters = {}
                env.monster_info = nil
                return bret.SUCCESS
            end
            if not self.bool then
                env.end_point             = nil
                env.path_list             = {}
                env.empty_path            = nil
                env.relife_stuck_monsters = {}
                self.bool                 = true
                return bret.RUNNING
            end
            if not poe2_api.table_contains(poe2_api.get_team_info(team_info, user_config, player_info, 2), { "大號名", "未知" })
                and check_pos_dis(poe2_api.get_team_info(team_info, user_config, player_info, 3), range_info, player_info) == nil then
                env.monster_info = nil
                return bret.SUCCESS
            end
            env.mate_info = mate
            return bret.FAIL
        end
    },

    -- 是否需要移动
    Is_Move = {
        run = function(self, env)
            poe2_api.dbgp("===[Is_Move]是否需要移动 ===")
            poe2_api.print_log("判断是否需要移动...")
            local range_info = env.range_info
            local range_sorted = poe2_api.get_sorted_list(env.range_info, env.player_info)
            local player_info = env.player_info
            local range_info_sorted = poe2_api.get_sorted_list(range_info, player_info)
            local UI_info = env.UI_info
            local user_config = env.user_config
            local team_info = env.team_info
            local boss_name = env.boss_name
            local mate = env.mate_info
            local away_monster_info = nil
            local arena_list = poe2_api.get_sorted_obj("競技場", range_info, player_info)
            local relife_stuck_monsters = env.relife_stuck_monsters
            local stuck_monsters = env.stuck_monsters
            if stuck_monsters == nil then
                stuck_monsters = {}
            end
            local function reset_navigation_state()
                -- 重置导航相关状态
                env.end_point = nil
                env.path_list = {}
                env.empty_path = nil
            end

            local function is_monster(range_info)
                -- 使用循环代替生成器表达式
                for _, i in ipairs(range_info) do
                    if ((i.name_utf8 == "巨像．札爾瑪拉斯" or i.name_utf8 == "玷汙者托爾．谷爾" or i.name_utf8 == "巨型守衛者．瓦斯威德")
                            and i.life > 0 and not i.is_friendly and i.isActive)
                        or ((i.name_utf8 == '多里亞尼的凱旋' or i.name_utf8 == '崛起之王．賈嫚拉')
                            and i.hasLineOfSight and i.isActive and i.life > 0)
                        or (not i.is_friendly and i.life > 0
                            and not poe2_api.table_contains(stuck_monsters, i.id)
                            and not string.find(i.name_utf8, "神殿")
                            and not poe2_api.table_contains(my_game_info.not_attact_mons_CN_name, i.name_utf8)
                            and not poe2_api.table_contains(my_game_info.not_attact_mons_path_name, i.name_utf8)
                            and i.isActive and i.rarity ~= 3)
                        and not poe2_api.table_contains(relife_stuck_monsters, i.id) then
                        return i
                    end
                end
                return false
            end

            local function is_point(grid_x, grid_y)
                local point = api_FindNearestReachablePoint(grid_x, grid_y, 50, 0)
                local ralet = api_FindPath(player_info.grid_x, player_info.grid_y, point.x, point.y)
                return ralet
            end

            local function away_monster(range_info, monster_id)
                -- 使用循环代替生成器表达式
                for _, i in ipairs(range_info) do
                    if i.id == monster_id then
                        return i
                    end
                end
                return false
            end

            if mate then
                local distance = poe2_api.point_distance(mate.grid_x, mate.grid_y, player_info)
                local monster = is_monster(range_info_sorted)
                local monster_info = env.monster_info
                local door_list = poe2_api.get_sorted_obj("門", range_info, player_info)
                if door_list and #door_list >0  and poe2_api.point_distance(door_list[1].grid_x, door_list[1].grid_y, player_info) < 15 then
                    poe2_api.dbgp("[Is_Move]门在身边")
                    if poe2_api.find_text({ UI_info = UI_info, text = "門", min_x = 0 }) and door_list[1].is_selectable
                        and not poe2_api.table_contains(player_info.current_map_name_utf8, { "G1_15", "G3_8", "G3_14"}) then
                        api_ClickMove(door_list[1].grid_x, door_list[1].grid_y, 1)
                        reset_navigation_state()
                        return bret.RUNNING
                    end
                end
                
                if monster_info then
                    poe2_api.dbgp("[Is_Move]monster_info存在")
                    away_monster_info = away_monster(range_info_sorted, monster_info.id)
                end
                if monster then
                    monster_distacne = poe2_api.get_point_distance(mate.grid_x, mate.grid_y, monster.grid_x,monster.grid_y)
                    poe2_api.dbgp("[Is_Move]monster存在monster_distacne",monster_distacne)
                    if (monster and poe2_api.table_contains(poe2_api.get_team_info(team_info, user_config, player_info, 2), { "大號名", "未知" })
                            and monster_distacne < 180) or monster_info then
                        poe2_api.dbgp("[Is_Move]大號打怪")
                        if monster and monster_distacne < 180 then
                            poe2_api.dbgp("[Is_Move]怪物存在且距离小于180")
                            if not env.path_list or not next(env.path_list) then
                                local point = is_point(monster.grid_x, monster.grid_y)
                                if not point or #point == 0 then
                                    poe2_api.dbgp("[Is_Move]怪物坐标非法")
                                    table.insert(relife_stuck_monsters, monster.id)
                                    return bret.RUNNING
                                end
                            end

                            env.monster_info = monster
                            monster_info = monster
                            env.end_point = { monster.grid_x, monster.grid_y }
                        end
                        if monster_info then
                            poe2_api.dbgp("[Is_Move]有黑板参怪物")
                            if not away_monster_info then
                                poe2_api.dbgp("[Is_Move]没有远距离怪物信息")
                                env.end_point = { monster.grid_x, monster.grid_y }
                            else
                                poe2_api.dbgp("[Is_Move]有远距离怪物信息")
                                env.monster_info = away_monster_info
                                point_monster = api_FindNearestReachablePoint(away_monster_info.grid_x,away_monster_info.grid_y, 25, 0)
                                env.end_point = { monster.grid_x, monster.grid_y }
                            end
                            if poe2_api.point_distance(monster_info.grid_x, monster_info.grid_y, player_info) < env.min_attack_dis and monster_info.life <= 0 then
                                table.insert(relife_stuck_monsters, monster.id)
                                return bret.RUNNING
                            end
                        end
                        if point_monster.x ~= -1 and point_monster.y ~= -1 then
                            env.life_time = nil
                            if poe2_api.point_distance(monster_info.grid_x, monster_info.grid_y, player_info) < env.min_attack_dis and monster_info.hasLineOfSight == true then
                                env.is_arrive_end = true
                            end
                            poe2_api.dbgp("[Is_Move]怪物坐标合法")
                            return bret.FAIL
                        end
                    end
                end
                for _, i in ipairs(range_sorted) do
                    if string.find(i.name_utf8, "神殿") and i.isActive and i.is_selectable then
                        api_Sleep(500)
                        api_ClickMove(i.grid_x, i.grid_y, 1)
                        api_Sleep(500)
                        return bret.RUNNING
                    end
                end
                if distance > 100 and poe2_api.is_have_mos({ range_info = range_info_sorted, player_info = player_info, dis = 40 }) then
                    if monster and poe2_api.table_contains(poe2_api.get_team_info(team_info, user_config, player_info, 2), { "大號名", "未知" }) then
                        poe2_api.dbgp("[Is_Move]与死亡队友距离大于100且与怪物距离小于40")
                        point_monster = api_FindNearestReachablePoint(monster.grid_x, monster.grid_y, 25, 0)
                        env.end_point = { point_monster.x, point_monster.y }
                        return bret.FAIL
                    end
                elseif distance > 25 then
                    poe2_api.dbgp("[Is_Move]与队友距离大于25")
                    local boss_info_mate = poe2_api.is_have_boss_distance(range_info, mate, boss_name, 180)
                    if poe2_api.find_text({ UI_info = UI_info, text = "競技場", min_x = 0 }) and arena_list and
                        arena_list[1].hasLineOfSight and arena_list[1].is_selectable and api_FindPath(player_info.grid_x, player_info.grid_y, arena_list[1].grid_x, arena_list[1].grid_y) then
                        poe2_api.find_text({ UI_info = UI_info, text = "競技場", min_x = 0, click = 2 })
                        reset_navigation_state()
                        return bret.RUNNING
                    end
                    if boss_info_mate and arena_list then
                        poe2_api.dbgp("[Is_Move]与队友距离大于25且与boss距离小于180")
                        local arena_point = api_FindNearestReachablePoint(arena_list[1].grid_x, arena_list[1].grid_y, 25,0)
                        poe2_api.dbgp(arena_point.x, arena_point.y)
                        env.end_point = { arena_point.x, arena_point.y }
                    else
                        local mate_point = api_FindNearestReachablePoint(mate.grid_x, mate.grid_y, 15, 0)
                        env.end_point = { mate_point.x, mate_point.y }
                    end
                    return bret.FAIL
                else
                    poe2_api.dbgp("[Is_Move]与队友距离小于25")
                    return bret.SUCCESS
                end
            else
                return bret.RUNNING
            end
        end
    },

    -- 队友死亡是否需要攻击
    Is_Attack = {
        run = function(self, env)
            poe2_api.dbgp("[Is_Attack]判断是否攻击...")
            poe2_api.print_log("判断是否攻击...")
            local relife_stuck_monsters = env.relife_stuck_monsters
            local range_info = env.range_info
            local player_info = env.player_info
            local range_info_sorted = poe2_api.get_sorted_list(range_info, player_info)
            local UI_info = env.UI_info
            local user_config = env.user_config
            local team_info = env.team_info
            local boss_name = env.boss_name
            local mate = env.mate_info
            if env.stuck_monsters == nil then
                env.stuck_monsters = {}
            end

            local function is_monster(range_info)
                -- Iterate through each item in range_info
                for _, i in ipairs(range_info) do
                    if (((i.name_utf8 == "巨像．札爾瑪拉斯" or i.name_utf8 == "玷汙者托爾．谷爾" or i.name_utf8 == "巨型守衛者．瓦斯威德")
                            and i.life > 0 and not i.is_friendly and i.isActive)
                        or ((i.name_utf8 == '多里亞尼的凱旋' or i.name_utf8 == '崛起之王．賈嫚拉')
                            and i.hasLineOfSight and i.isActive and i.life > 0)
                        or (not i.is_friendly and i.life > 0
                            and not poe2_api.table_contains(env.stuck_monsters, i.id)
                            and not string.find(i.name_utf8, "神殿")
                            and not poe2_api.table_contains(my_game_info.not_attact_mons_CN_name, i.name_utf8)
                            and not poe2_api.table_contains(my_game_info.not_attact_mons_path_name, i.name_utf8)
                            and i.isActive and i.type == 1))
                        and not poe2_api.table_contains(relife_stuck_monsters, i.id) then
                        return i
                    end
                end
                return false
            end
            local monster = is_monster(range_info_sorted)
            if not poe2_api.table_contains(poe2_api.get_team_info(team_info, user_config, player_info, 2), { "大號名", "未知" }) then
                env.monster_info = nil
                return bret.SUCCESS
            end
            local distance = poe2_api.point_distance(mate.grid_x, mate.grid_y, player_info)
            if distance > 100 and poe2_api.is_have_mos({ range_info = range_info_sorted, player_info = player_info, dis = 40 }) then
                poe2_api.dbgp("[Is_Attack]与死亡队友距离大于100且与怪物距离小于40")
                env.monster_info = monster
                return bret.FAIL
            elseif monster and poe2_api.table_contains(poe2_api.get_team_info(team_info, user_config, player_info, 2), { "大號名", "未知" }) and
                poe2_api.get_point_distance(mate.grid_x, mate.grid_y, monster.grid_x, monster.grid_y) < 180 then
                poe2_api.dbgp("[Is_Attack]与怪物距离小于40")
                env.monster_info = monster
                return bret.FAIL
            else
                env.monster_info = nil
                return bret.SUCCESS
            end
        end
    },

    -- 长按点击复活
    Click = {
        run = function(self, env)
            poe2_api.dbgp("点击复活")
            poe2_api.print_log("点击复活")
            local relife_stuck_monsters = env.relife_stuck_monsters
            local range_info = env.range_info
            local player_info = env.player_info
            local range_info_sorted = poe2_api.get_sorted_list(range_info, player_info)
            local UI_info = env.UI_info
            local user_config = env.user_config
            local team_info = env.team_info
            local mate = env.mate_info
            local current_map_info = env.current_map_info
            local function is_monster(range_info)
                -- Iterate through each item in range_info
                for _, i in ipairs(range_info) do
                    if ((i.name_utf8 == "巨像．札爾瑪拉斯" or i.name_utf8 == "玷汙者托爾．谷爾" or i.name_utf8 == "巨型守衛者．瓦斯威德")
                            and i.life > 0 and not i.is_friendly and i.isActive)
                        or ((i.name_utf8 == '多里亞尼的凱旋' or i.name_utf8 == '崛起之王．賈嫚拉')
                            and i.hasLineOfSight and i.isActive and i.life > 0)
                        or (not i.is_friendly and i.life > 0
                            and not string.find(i.name_utf8, "神殿")
                            and not poe2_api.table_contains(env.stuck_monsters, i.id)
                            and not poe2_api.table_contains(my_game_info.not_attact_mons_CN_name, i.name_utf8)
                            and not poe2_api.table_contains(my_game_info.not_attact_mons_path_name, i.name_utf8)
                            and i.isActive and i.type == 1)
                        and not poe2_api.table_contains(relife_stuck_monsters, i.id) then
                        return i
                    end
                end
                return false
            end
            if env.stuck_monsters == nil then
                env.stuck_monsters = {}
            end
            local monster = is_monster(range_info_sorted)
            if monster then
                distance = poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info)
            end
            if monster and distance < 180 and poe2_api.get_team_info(team_info, user_config, player_info, 2) == "大號名" then
                return bret.RUNNING
            end
            local life_time = env.life_time
            if not life_time then
                life_time = api_GetTickCount64()
                env.life_time = life_time
            end
            local function count_gravestones(map_info)
                if not map_info then
                    return false
                end
                local count = 0
                for _, obj in ipairs(map_info) do
                    if obj.name_utf8 == "PlayerGravestone" then
                        count = count + 1
                    end
                end
                return count
            end
            local relife_time = api_GetTickCount64() - life_time
            if relife_time > 90 * 1000 and poe2_api.get_team_info(team_info, user_config, player_info, 2) == "大號名" and count_gravestones(current_map_info) > 0 then
                env.life_time = nil
                env.is_timeout = true
                return bret.RUNNING
            end
            if not poe2_api.find_text({ UI_info = UI_info, text = "復甦", min_x = 0 }) then
                return bret.RUNNING
            end
            local is_leader = false
            if poe2_api.get_team_info(team_info, user_config, player_info, 2) == "大號名" then
                is_leader = true
            end
            poe2_api.while_click(UI_info, "復甦", player_info, range_info, is_leader)
            return bret.RUNNING
        end
    },

    -- 是否拾取任务或BD
    Is_Pick_Up_Task_Props = {
        run = function(self, env)
            poe2_api.print_log("是否拾取任务和BD")
            poe2_api.dbgp("[Is_Pick_Up_Task_Props]是否拾取任务和BD")
            local range_items = env.range_items
            local player_info = env.player_info
            local user_config = env.user_config
            local current_time = api_GetTickCount64()
            local user_new_item = poe2_api.get_BD_info(user_config["組隊設置"]["職業"], "装备信息")
            local function is_items()
                if range_items then
                    for _, item in ipairs(range_items) do
                        if player_info.current_map_name_utf8 == "G1_1" and user_new_item[item.category_utf8] and item.grid_x ~= 0 then
                            local point = api_FindNearestReachablePoint(item.grid_x, item.grid_y, 20, 0)
                            if not api_FindPath(player_info.grid_x, player_info.grid_y, point.x, point.y) then
                                poe2_api.dbgp("[Is_Pick_Up_Task_Props]无法到达點位")
                                return false
                            end
                            return true
                        elseif poe2_api.table_contains(item.category_utf8, { 'QuestItem', "Active Skill Gem" }) and not poe2_api.table_contains(item.baseType_utf8, { "黃金", "金幣", "紅色蘑菇", "綠色蘑菇", "藍色蘑菇", "龍蜥最後通牒雕刻" }) and item.grid_x ~= 0 then
                            local point = api_FindNearestReachablePoint(item.grid_x, item.grid_y, 20, 0)
                            if not api_FindPath(player_info.grid_x, player_info.grid_y, point.x, point.y) then
                                return false
                            end
                            return true
                        end
                    end
                    return false
                end
            end
            if is_items() then
                poe2_api.dbgp("进入[Traverse_and_check_equipment]遍历周围装备")
                poe2_api.time_p("[Is_Pick_Up_Task_Props]FAIL",api_GetTickCount64() - current_time)
                return bret.FAIL
            else
                env.item_name = nil
                poe2_api.dbgp("[Is_Pick_Up_Task_Props]SUCCESS")
                poe2_api.time_p("[Is_Pick_Up_Task_Props]SUCCESS",api_GetTickCount64() - current_time)
                return bret.SUCCESS
            end
        end
    },

    -- 遍历周围装备
    Traverse_and_check_equipment = {
        run = function(self, env)
            poe2_api.dbgp("[Traverse_and_check_equipment]遍历周围装备...")
            poe2_api.print_log("遍历周围装备...")
            local range_items = env.range_items
            local player_info = env.player_info
            local user_config = env.user_config
            local user_new_item = poe2_api.get_BD_info(user_config["組隊設置"]["職業"], "装备信息")
            local function processItem(item, player_info)
                env.item_name = item.baseType_utf8
                env.end_point = { item.grid_x, item.grid_y }

                if poe2_api.point_distance(item.grid_x, item.grid_y, player_info) < 25 and
                    (api_HasObstacleBetween(item.grid_x, item.grid_y) or item.baseType_utf8 == "水之精髓") then
                    return bret.FAIL
                end
                return bret.SUCCESS
            end
            if range_items then
                for _, item in ipairs(range_items) do
                    if player_info.current_map_name_utf8 == "G1_1" and user_new_item[item.category_utf8] and item.grid_x ~= 0 then
                        env.mouse_check = true
                        return processItem(item, player_info)
                    elseif poe2_api.table_contains(item.category_utf8, { 'QuestItem', "Active Skill Gem" }) and not poe2_api.table_contains(item.baseType_utf8, { "黃金", "金幣", "紅色蘑菇", "綠色蘑菇", "藍色蘑菇", "龍蜥最後通牒雕刻" }) and item.grid_x ~= 0 then
                        return processItem(item, player_info)
                    end
                end
            end
            return bret.RUNNING
        end
    },

    -- 拾取周围装备
    Pick_Up_Ground_Item = {
        run = function(self, env)
            poe2_api.print_log("拾取地上物品...")
            poe2_api.dbgp("[Pick_Up_Ground_Item]拾取地上物品...")
            local player_info = env.player_info
            local UI_info = env.UI_info
            local item_name = env.item_name
            local bag_info = env.bag_info
            local range_items = env.range_items

            local function check_item_in_round(item_name, inventory)
                if inventory then
                    for _, item in ipairs(inventory) do
                        if item.baseType_utf8 == item_name then
                            return true -- 检查到物品，返回true
                        end
                    end
                end
                return false
            end

            if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                poe2_api.click_keyboard("i")
                poe2_api.dbgp("开背包2")
            end
            if range_items then
                for _, item in ipairs(range_items) do
                    if item.baseType_utf8 == item_name then
                        if poe2_api.find_text({ UI_info = UI_info, text = item.baseType_utf8, sorted = true }) then
                            poe2_api.find_text({ UI_info = UI_info, text = item.baseType_utf8, sorted = true, click = 2 })
                        else
                            api_ClickMove(poe2_api.toInt(item.grid_x), poe2_api.toInt(item.grid_y), 1)
                        end
                        api_Sleep(100)
                    end
                end
            end
            return bret.RUNNING
        end
    },

    -- 需要两次传送
    Need_Twice_Teleport = {
        run = function(self, env)
            poe2_api.dbgp("[Need_Twice_Teleport]需要两次传送...")
            poe2_api.print_log("需要两次传送...")
            local player_info = env.player_info
            local task_area = env.map_name
            local special_map_point = env.special_map_point
            local interaction_object = env.interaction_object
            local team_info = env.team_info
            local user_config = env.user_config
            local current_map_name = player_info.current_map_name_utf8
            local current_time = api_GetTickCount64()
            local my_profession = poe2_api.get_team_info(team_info, user_config, player_info, 2)
            if string.find(player_info.current_map_name_utf8, "town") and special_map_point and not poe2_api.table_contains(my_profession, { "大號名", "未知" }) then
                if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                    poe2_api.click_keyboard("space")
                    return bret.RUNNING
                end
                if special_map_point and poe2_api.find_text({ UI_info = env.UI_info, text = interaction_object[1], min_x = 195, refresh = true }) then
                    if poe2_api.find_text({ UI_info = env.UI_info, text = "快行" }) then
                        poe2_api.click_keyboard("space")
                    end
                    poe2_api.find_text({ UI_info = env.UI_info, text = interaction_object[1], click = 2, min_x = 195, refresh = true })
                    return bret.RUNNING
                end
                if special_map_point and not poe2_api.find_text({ UI_info = env.UI_info, text = interaction_object[1], min_x = 195, refresh = true }) then
                    if env.waypoint ~= nil and #env.waypoint > 0 then
                        waypoint_screen = poe2_api.waypoint_pos("G2_town_marker_lockedgates",env.waypoint)
                        if waypoint_screen[1] == 0 and waypoint_screen[2] == 0 then
                            waypoint_screen = poe2_api.waypoint_pos("G2_town_marker_gates",env.waypoint)
                        end
                    end
                    if (not waypoint_screen) or (waypoint_screen[1] == 0 and waypoint_screen[2] == 0) then
                        if not poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖",refresh = true}) then
                            api_Sleep(800)
                            poe2_api.click_keyboard("u")
                        end
                        api_Sleep(200)
                        env.waypoint = api_GetTeleportationPoint()
                        api_Sleep(1000)
                        return bret.RUNNING
                    end
                    api_Sleep(300)
                    if string.find(player_info.current_map_name_utf8, "G2_town") then
                        if not poe2_api.find_text({ UI_info = env.UI_info, text = "快行", refresh = true }) then
                            if poe2_api.find_text({ UI_info = env.UI_info, text = "沙漠", min_y = 100, min_x = 195, max_x = 1185, max_y = 880, refresh = true }) then
                                poe2_api.find_text({ UI_info = env.UI_info, text = "沙漠", click = 2, min_y = 100, min_x = 195, max_x = 1185, max_y = 880, refresh = true })
                                env.end_point = nil
                                env.empty_path = false
                                return bret.RUNNING
                            else
                                env.end_point = { 547, 253 }
                                poe2_api.time_p("Need_Twice_Teleport",api_GetTickCount64() - current_time ) 
                                return bret.SUCCESS
                            end
                        else
                            if poe2_api.find_text({ UI_info = env.UI_info, text = "快行", refresh = true }) then
                                api_ClickScreen(poe2_api.toInt(waypoint_screen[1]), poe2_api.toInt(waypoint_screen[2]), 0)
                                api_Sleep(600)
                                api_ClickScreen(poe2_api.toInt(waypoint_screen[1]), poe2_api.toInt(waypoint_screen[2]), 1)
                                api_Sleep(600)
                                if poe2_api.find_text({ UI_info = env.UI_info, text = "快行" }) then
                                    poe2_api.click_keyboard("space")
                                end
                            end
                            return bret.RUNNING
                        end
                    end
                end
            else
                if poe2_api.find_text({ UI_info = env.UI_info, text = "快行" }) then
                    poe2_api.click_keyboard("space")
                end
            end
            poe2_api.time_p("Need_Twice_Teleport",api_GetTickCount64() - current_time ) 
            return bret.FAIL
        end
    },

    -- 點擊大號傳送
    Click_Leader_To_Teleport = {
        run = function(self, env)
            poe2_api.print_log("點擊大號傳送...")
            poe2_api.dbgp("[Click_Leader_To_Teleport]點擊大號傳送...")
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            local actors = env.range_info
            local user_config = env.user_config
            local team_info = env.team_info
            local task_area = env.map_name
            local task_name = env.task_name
            local team_info_data = env.team_info_data
            local interaction_object = env.interaction_object
            local UI_info = env.UI_info
            local bag_info = env.bag_info
            local special_map_point = env.special_map_point
            local team_member_2 = poe2_api.get_team_info(team_info, user_config, player_info, 2)
            local team_member_3 = poe2_api.get_team_info(team_info, user_config, player_info, 3)
            local team_member_4 = poe2_api.get_team_info(team_info, user_config, player_info, 4)
            local current_map = player_info.current_map_name_utf8
            local current_map_info = env.current_map_info
            local num = user_config["組隊設置"]["隊伍人數"]
            if self.time1 == nil then
                poe2_api.dbgp("[Click_Leader_To_Teleport]初始化時間")
                self.time1 = 0
            end
            local condition_met = (current_map == "C_G1_1" and string.find(task_area, "C")) or
                (current_map ~= "G1_1" and not poe2_api.find_text({ UI_info = UI_info, text = "抵達皆伐" }))
            if not condition_met then
                poe2_api.dbgp("[Click_Leader_To_Teleport]在新手剧情")
                poe2_api.time_p("Click_Leader_To_Teleport",api_GetTickCount64() - current_time ) 
                return bret.SUCCESS
            end
            if poe2_api.table_contains(team_member_2, { "大號名", "未知" }) then
                poe2_api.time_p("Click_Leader_To_Teleport",api_GetTickCount64() - current_time ) 
                return bret.FAIL
            end
            if poe2_api.find_text({ UI_info = UI_info, text = "傳送", min_x = 0 }) then
                poe2_api.find_text({ UI_info = UI_info, text = "傳送", min_x = 0, add_x = 215, click = 2 })
                return bret.RUNNING
            end
            -- 获取队友位置
            local function party_pos(name)
                poe2_api.dbgp("[party_pos]获取队友位置:")
                for _, member in ipairs(team_info_data) do
                    if member["name_utf8"] == name then
                        poe2_api.dbgp("[party_pos]获取队友位置信息:",member["current_map_name_utf8"])
                        return member["current_map_name_utf8"]
                    end
                end
                return nil
            end

            local function check_pos_dis(names)
                poe2_api.dbgp("[check_pos_dis]获取队友位置距离:")
                if not actors then
                    return nil
                end
                local target = nil
                for _, a in ipairs(actors) do
                    if a.name_utf8 == names then
                        target = a
                        break
                    end
                end
                if target then
                    return poe2_api.point_distance(
                            target.grid_x,
                            target.grid_y,
                            player_info
                    )
                else
                    return nil
                end
            end
            local function mini_map_obj(name)
                poe2_api.dbgp("[Click_Leader_To_Teleport]检测地图上是否存在物体：", name)
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == name then
                        return item  -- 直接返回第一个匹配项
                    end
                end
                return nil -- 无匹配时返回nil
            end
            local function mini_map_obj_flagStatus(name)
                poe2_api.dbgp("[Is_Team_leader]检测地图上是否存在物体：", name)
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == name and item.flagStatus1 == 1 then
                        return item  -- 直接返回第一个匹配项
                    end
                end
                return nil -- 无匹配时返回nil
            end
            local function get_range_pos(name)
                poe2_api.dbgp("[get_range_pos]获取周围位置:")
                local range_info_sorted = poe2_api.get_sorted_list(actors, player_info)
                for _, actor in ipairs(range_info_sorted) do
                    if actor.name_utf8 == name then
                        return { actor.grid_x, actor.grid_y }
                    end
                end
                return nil
            end
            -- 获取团队距离
            local function party_dis_memember(actors)
                -- 从黑板中获取团队信息
                local members = team_info_data
                if not members then
                    poe2_api.dbgp("警告：未找到团队信息")
                    return false
                end
            
                -- 将 members 转换为集合（使用表实现）
                local member_names = {}
                for _, member in ipairs(members) do
                    member_names[member.name_utf8] = true
                end
            
                -- 统计匹配的数量
                local match_count = 0
                for _, actor in ipairs(actors) do
                    if actor.name_utf8 ~= player_info.name_utf8 and member_names[actor.name_utf8] then
                        match_count = match_count + 1
                    end
                end
            
                -- 返回结果
                return match_count == num - 1
            end
            if poe2_api.table_contains(current_map, { "G1_12", "G3_7" }) then
                local SPECIAL_SKULL_NAMES = { ['寶石花顱骨'] = true, ['寶石殼顱骨'] = true, ['傑洛特顱骨'] = true }
                for _, i in ipairs(actors) do
                    if SPECIAL_SKULL_NAMES[i.name_utf8] then
                        return bret.RUNNING
                    end
                end
            end
            if not party_dis_memember(actors) and string.find(current_map, "a") and task_name == "使用貧脊之地的地圖前往哈拉妮關口所在之處" then
                poe2_api.dbgp("等待大号")
                return bret.RUNNING
            end
            if poe2_api.table_contains(current_map, { "G3_12",  "G2_4_3", "G1_15"}) then
                local function check_role_path(names)
                    poe2_api.dbgp("[check_role_path] 检查指定角色是否有可达路径")
                    if not actors or #actors == 0 then -- 提前检查空值
                        poe2_api.api_print("警告：未找到范围内的角色信息")
                        return false
                    end

                    local point = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y, 25, 0)

                    -- 遍历所有actor检查是否有符合条件的
                    for _, actor in ipairs(actors) do
                        if actor.name_utf8 == names then
                            local target = api_FindNearestReachablePoint(actor.grid_x, actor.grid_y, 25, 1)
                            local result = api_FindPath(point.x, point.y, target.x, target.y)
                            if result and #result > 0 then
                                return true
                            end
                        end
                    end

                    return false
                end
                if not check_role_path(team_member_3) and check_pos_dis(team_member_3) and check_pos_dis(team_member_3) > 30 then
                    if self.time1 == 0 then
                        self.time1 = api_GetTickCount64()
                    end
                    poe2_api.dbgp(api_GetTickCount64() - self.time1 > 30 * 1000)
                    if api_GetTickCount64() - self.time1 > 30 * 1000 then
                        if string.find(current_map, "own") then
                            self.time1 = 0
                            return bret.SUCCESS
                        end
                        for _, name in ipairs(my_game_info.city_map) do
                            if poe2_api.find_text({ UI_info = UI_info, text = name, click = 2 }) then
                                return bret.RUNNING
                            end
                        end
                        api_ClickScreen(1230, 815, 0)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(2000)
                        return bret.RUNNING
                    end
                else
                    self.time1 = 0
                end
            else
                self.time1 = 0
            end
            if task_name == "返回城鎮並與瑟維交談" and string.find(task_area, "G3_town")
                and (poe2_api.check_item_in_inventory("寶石殼顱骨", bag_info) or poe2_api.check_item_in_inventory("傑洛特顱骨", bag_info))
                and poe2_api.check_item_in_inventory("尹娜杜克的幽暗長鋒", bag_info) then
                poe2_api.dbgp("返回城鎮並與瑟維交談")
                for _, name in ipairs(my_game_info.city_map) do
                    if string.find(current_map, "own") then
                        return bret.SUCCESS
                    end
                    if poe2_api.find_text({ UI_info = UI_info, text = name, click = 2 }) then
                        return bret.RUNNING
                    end
                end
                api_ClickScreen(1230, 815, 0)
                api_Sleep(500)
                api_ClickScreen(1230, 815, 1)
                api_Sleep(2000)
                return bret.RUNNING
            end
            if (string.find(current_map, "a") and special_map_point) or (string.find(current_map, "own") and task_area and current_map == task_area) then
                return bret.SUCCESS
            end
            if not special_map_point and poe2_api.find_text({ UI_info = UI_info, text = "快行" }) then
                poe2_api.click_keyboard("space")
                return bret.RUNNING
            end
            if task_name == "自瘋狂中存活" then
                local function npc_stateMachineList()
                    for _,k in ipairs(actors) do
                        if k.name_utf8 == "芙雷雅．哈特林" then
                            if k.stateMachineList and k.stateMachineList["activated"] == 1 then
                                poe2_api.dbgp("芙雷雅．哈特林npc")
                                return true
                            end
                        end
                    end
                    return false
                end
                local npc_stateMachineList = npc_stateMachineList()
                if npc_stateMachineList then
                    env.leader_teleport = true
                else
                    env.leader_teleport = false
                end
            end
            if env.leader_teleport then
                if team_member_2 == "隊長名" then
                    poe2_api.dbgp(1111)
                    if task_area == "G4_2_2" then
                        if task_name == "自瘋狂中存活" then
                            local g4_area_name = mini_map_obj("G4_2_1")
                            if g4_area_name then
                                local distance = poe2_api.point_distance(g4_area_name.grid_x, g4_area_name.grid_y, player_info)
                                if distance < 30 then
                                    poe2_api.find_text({UI_info = env.UI_info, text ="凱吉灣", click = 2})
                                    return bret.RUNNING
                                else                    
                                    env.end_point= {g4_area_name.grid_x, g4_area_name.grid_y}
                                    return bret.FAIL
                                end
                            end
                        elseif task_name == "旅程結束" then
                            local g4_area_name = mini_map_obj("G4_2_2")
                            if g4_area_name then
                                local distance = poe2_api.point_distance(g4_area_name.grid_x, g4_area_name.grid_y, player_info)
                                if distance < 30 then
                                    if not poe2_api.find_text({ UI_info = UI_info, text = "副本管理員", click = 0, refresh = true }) then
                                        api_Sleep(500)
                                        poe2_api.find_text({UI_info = env.UI_info, text ="旅程結束", click = 4})
                                        api_Sleep(500)
                                    else
                                        api_Sleep(500)
                                        poe2_api.find_text({ UI_info = UI_info, text = "新副本", click = 2, min_x = 0, refresh = true })
                                        api_Sleep(500)
                                        if poe2_api.click_text_UI({ UI_info = env.UI_info, text = "loading_screen_tip_label" }) then
                                            env.leader_teleport = false
                                        end
                                    end
                                    return bret.RUNNING
                                else                    
                                    env.end_point= {g4_area_name.grid_x, g4_area_name.grid_y}
                                    return bret.FAIL
                                end
                            end
                        end
                    end
                end
                return bret.RUNNING
            end
            if poe2_api.table_contains(current_map, { "G3_1" }) and poe2_api.table_contains(task_area, { "G3_1" }) and task_name =="與黑衣幽魂對話，了解下一步該做什麼" then
                poe2_api.dbgp("检测到任务区域:G3_1")
                return bret.SUCCESS
            end
            if poe2_api.table_contains(current_map, { "G2_1" }) and poe2_api.table_contains(task_area, { "G2_1" }) and task_name == "進入阿杜拉車隊" then
                poe2_api.dbgp("检测到任务:進入阿杜拉車隊")
                return bret.SUCCESS
            end
            if poe2_api.table_contains(current_map, { "G4_2_2" }) and poe2_api.table_contains(task_area, { "G4_2_2" }) and task_name =="自瘋狂中存活" then
                poe2_api.dbgp("检测到任务区域:G4_2_2")
                return bret.SUCCESS
            end
            if poe2_api.table_contains(current_map, { "G3_2_2" }) and poe2_api.table_contains(task_area, { "G3_2_2" }) and
                not check_pos_dis(team_member_3) then
                poe2_api.dbgp("检测到任务区域:G3_2_2")
                return bret.RUNNING
            end
            if current_map == "G3_town" and poe2_api.table_contains(task_area, { "G3_14", "G3_16", "G3_17"}) or poe2_api.table_contains(task_name, { "回到過去，進入奧札爾", "穿過城鎮中的時空傳送門以移至殘忍難度" }) then
                local point = get_range_pos("倉庫")
                local waypoint_point = get_range_pos("傳送點")
                local waypoint_pos = get_range_pos("崎點")
                local distance_between = nil
                if not waypoint_pos and not point then
                    local a = poe2_api.get_point_distance(point[1], point[2], waypoint_point[1], waypoint_point[2])
                    local b = poe2_api.point_distance(waypoint_point[1], waypoint_point[2], player_info)
                    if a and b then
                        if a < 120 and b < 50 then
                            poe2_api.find_text({ UI_info = UI_info, text = "崎點", click = 2, min_x = 0 })
                        else
                            if string.find(player_info.current_map_name_utf8, "town") then
                                local towards_point = poe2_api.move_towards({ player_info.grid_x, player_info.grid_y },
                                    waypoint_pos, 20)
                                api_ClickMove(poe2_api.toInt(towards_point[1]), poe2_api.toInt(towards_point[2]), 0)
                                api_Sleep(100)
                                poe2_api.click_keyboard("space")
                            end
                        end
                        return bret.RUNNING
                    end
                elseif not waypoint_pos and point then
                    local towards_point = poe2_api.move_towards({ player_info.grid_x, player_info.grid_y }, point, 20)
                    api_ClickMove(poe2_api.toInt(towards_point[1]), poe2_api.toInt(towards_point[2]),0)
                    api_Sleep(100)
                    poe2_api.click_keyboard("space")
                    return bret.RUNNING
                elseif waypoint_pos and not point then
                    if waypoint_point then
                        distance_between = poe2_api.get_point_distance(waypoint_point[1], waypoint_point[2],
                            waypoint_pos[1], waypoint_pos[2])
                        if not distance_between or (distance_between and distance_between > 100) then
                            local towards_point = poe2_api.move_towards({ player_info.grid_x, player_info.grid_y },
                                waypoint_pos, 20)
                            api_ClickMove(poe2_api.toInt(towards_point[1]), poe2_api.toInt(towards_point[2]),0)
                            api_Sleep(100)
                            poe2_api.click_keyboard("space")
                            return bret.RUNNING
                        end
                    end
                end
            end
            if poe2_api.table_contains(task_area, { "G3_14", "G3_16", "G3_17", "G3_12" }) and not poe2_api.table_contains(party_pos(team_member_3), { "G3_town", "G3_14", "G3_16", "G3_17", "G3_12"}) then
                if check_pos_dis(team_member_3) == nil then
                    if team_member_2 == "小號" then
                        if not poe2_api.find_text({ UI_info = UI_info, text = "你確定要傳送至此玩家的位置？" }) then
                            local x, y = poe2_api.get_member_name_according(UI_info, team_member_4)
                            if y ~= 0 then
                                local rand_x = 14 + math.random(-7, 7)
                                local rand_y = y + 21 + math.random(-7, 7)
                                api_ClickScreen(poe2_api.toInt(rand_x), poe2_api.toInt(rand_y), 0)
                                api_Sleep(500)
                                api_ClickScreen(poe2_api.toInt(rand_x), poe2_api.toInt(rand_y), 1)
                            end
                            return bret.RUNNING
                        else
                            api_ClickScreen(916, 467, 0)
                            api_Sleep(500)
                            api_ClickScreen(916, 467, 1)
                            return bret.SUCCESS
                        end
                    end
                else
                    return bret.SUCCESS
                end
            end
            if string.find(current_map, "G3_12") and ((interaction_object and poe2_api.table_contains(interaction_object, "召瓦尔") and check_pos_dis(team_member_3)) or (check_pos_dis("艾瓦") and check_pos_dis("艾瓦") < 25) or not check_pos_dis("競技場")) then
                return bret.RUNNING
            end
            local count = 3 
            if party_pos(team_member_3) == "" and task_area ~= "G3_12" then
                if string.find(current_map, "Hideout") then
                    poe2_api.dbgp("在藏身处")
                    return bret.SUCCESS
                end
                if poe2_api.table_contains(current_map, { "G2_3a","G3_2_2" })  then
                    poe2_api.dbgp("在G2_3a或G3_2_2")
                    return bret.SUCCESS
                end
                error("大号没有位置信息或掉线")
            end
            local waypoint_name_utf8 = (party_pos(team_member_3) ~="" and poe2_api.task_area_list_data(party_pos(team_member_3))[1][2]) or nil
            if poe2_api.table_contains(task_area, {"G3_12"}) and not waypoint_name_utf8 then
                waypoint_name_utf8  = poe2_api.task_area_list_data(task_area)[1][2]
            end
            if  poe2_api.find_text({ UI_info = UI_info, text = waypoint_name_utf8, min_x = 0, min_y = 0, max_x = 195, max_y = 590 }) then
                for i = 0, count - 1 do
                    if not poe2_api.find_text({ UI_info = UI_info, text = "你確定要傳送至此玩家的位置？" }) then
                        if poe2_api.find_text({ UI_info = UI_info, text = "快行" }) then
                            poe2_api.click_keyboard("space")
                            return bret.RUNNING
                        end
                        local x, y = poe2_api.get_member_name_according(UI_info, team_member_3)
                        poe2_api.dbgp("x,y",x,y)
                        if y ~= 0 then
                            local rand_x = 14 + math.random(-7, 7)
                            local rand_y = y + 21 + math.random(-7, 7)
                            api_ClickScreen(poe2_api.toInt(rand_x), poe2_api.toInt(rand_y), 0)
                            api_Sleep(500)
                            api_ClickScreen(poe2_api.toInt(rand_x), poe2_api.toInt(rand_y), 1)
                        end
                        return bret.RUNNING
                    else
                        api_ClickScreen(916, 467, 0)
                        api_Sleep(500)
                        api_ClickScreen(916, 467, 1)
                        return bret.SUCCESS
                    end
                end
                return bret.RUNNING
            end

            if current_map == task_area and string.find(current_map, "G4") and string.find(task_area, "G4") then 
                local g4_area_name = get_range_pos(poe2_api.task_area_list_data(task_area)[1][2])
                if g4_area_name then
                    local distance = poe2_api.point_distance(g4_area_name[1], g4_area_name[2], player_info)
                    poe2_api.dbgp(g4_area_name,distance)
                    if distance < 30 then
                        poe2_api.find_text({UI_info = env.UI_info, text = poe2_api.task_area_list_data(task_area)[1][2], click = 2})
                        return bret.RUNNING
                    else                    
                        env.end_point= {g4_area_name[1], g4_area_name[2]}
                        return bret.FAIL
                    end
                end
            end
            if current_map == task_area and task_area == "G4_4_1" then
                if poe2_api.find_text({UI_info = env.UI_info, text = "通道", min_x = 0}) and mini_map_obj_flagStatus("Waypoint") then
                    poe2_api.find_text({UI_info = env.UI_info, text = "通道", min_x = 0,click = 2})
                    return bret.RUNNING
                end
            end
            if check_pos_dis(team_member_3) then
                local point = get_range_pos(team_member_3)
                local arena_list = poe2_api.get_sorted_obj("競技場", env.range_info, player_info)
                
                if poe2_api.find_text({UI_info = env.UI_info, text = "你確定要傳送至此玩家的位置？"}) then
                    poe2_api.click_keyboard("space")
                end
                
                if arena_list and #arena_list > 0  and arena_list[1].hasLineOfSight and arena_list[1].is_selectable and api_FindPath(player_info.grid_x, player_info.grid_y, point[1], point[2]) then
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "競技場"}) then
                        local arena = get_range_pos("競技場")
                        if arena then
                            local NearestReachablePoint = api_FindNearestReachablePoint(arena[1], arena[2], 40, 1)
                            env.end_point = {NearestReachablePoint.x, NearestReachablePoint.y}
                            return bret.FAIL
                        end
                    end
                    
                    poe2_api.find_text({UI_info = env.UI_info, text = "競技場",click = 2})
                    env.end_point = nil
                    env.is_arrive_end = false
                    env.path_list = {}
                    env.entrancelist = {}
                    return bret.RUNNING
                end
            end
            if check_pos_dis(team_member_3) and check_pos_dis(team_member_3) > 100 and poe2_api.table_contains(current_map, { "G1_15", "G2_3"}) then
                local function next_level()
                    local entrance = get_range_pos("樓梯")
                    local checkpoint_pos = get_range_pos("記錄點")
                    -- 提前返回如果任一位置不存在
                    if not entrance or not checkpoint_pos then
                        return false
                    end
                    -- 直接返回距离计算结果
                    local distance = poe2_api.get_point_distance(entrance[1], entrance[2], checkpoint_pos[1],
                        checkpoint_pos[2]) or 100
                    return distance < 80
                end
                if string.find(current_map, "G1_15") then
                    
                    if not mini_map_obj("GargoyleInactive") and mini_map_obj("Waypoint") then
                        return bret.SUCCESS
                    end
                end
                local ladder = get_range_pos("樓梯")
                if check_pos_dis("崛起之王．賈嫚拉") == nil and string.find(current_map, "G2_3") then
                    return bret.SUCCESS
                elseif poe2_api.find_text({ UI_info = UI_info, text = "樓梯", min_x = 0 }) and poe2_api.find_text({ UI_info = UI_info, text = "記錄點", min_x = 0}) then
                    return bret.SUCCESS
                elseif not next_level() and ladder then
                    if ladder and (poe2_api.table_contains(current_map, { "G1_15", "C_G1_15" }) or not poe2_api.find_text({ UI_info = UI_info, text = "樓梯", min_x = 0 })) then
                        if check_pos_dis("樓梯") > 50 then
                            local ladder_point = api_FindNearestReachablePoint(ladder[1], ladder[2], 40, 0)
                            env.end_point = { ladder_point.x, ladder_point.y }
                            return bret.FAIL
                        end
                    end
                    poe2_api.find_text({ UI_info = UI_info, text = "樓梯", min_x = 0, click = 2 })
                    env.end_point = nil
                    env.entrancelist = {}
                    env.path_list = {}
                    return bret.RUNNING
                end
            end
            poe2_api.time_p("=== '[Click_Leader_To_Teleport] ===",api_GetTickCount64() - current_time)
            return bret.SUCCESS
        end
    },

    -- 是否为团队大号
    Is_Team_leader = {
        run = function(self, env)
            poe2_api.print_log("是否为团队大号...")
            poe2_api.dbgp("=== '[Is_Team_leader]是否为团队大号 ===")
            local player_info = env.player_info
            local range_info = env.range_info
            local UI_info = env.UI_info
            local user_config = env.user_config
            local team_info = env.team_info
            local task_area = env.map_name
            local arena_list = poe2_api.get_sorted_obj("競技場", range_info, player_info)
            local me_area = player_info.current_map_name_utf8
            local team_member_2 = poe2_api.get_team_info(team_info, user_config, player_info, 2)
            if team_member_2 ~= "大號名" then
                return bret.FAIL
            end
            return bret.SUCCESS
        end
    },

    -- 是否要传送
    Is_Teleport = {
        run = function(self, env)
            poe2_api.print_log("是否要传送...")
            poe2_api.dbgp("=== '[Is_Teleport]是否要传送 ===")
            if self.follow == nil then
                self.time1 = 0
                self.bool = false
                self.bool1 = false
                self.follow = false
                self.back_city = false
                self.click_ke = false
                self.louti_id = nil
            end
            local task_area = env.map_name
            local player_info = env.player_info
            if not poe2_api.task_area_list_data(task_area) or not player_info then
                return bret.RUNNING
            end
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            local me_area = player_info.current_map_name_utf8
            local range_info = env.range_info
            local UI_info = env.UI_info
            local user_config = env.user_config
            local team_info = env.team_info
            local team_info_data = env.team_info_data
            local team_member_2 = poe2_api.get_team_info(team_info, user_config, player_info, 2)
            local team_member_3 = poe2_api.get_team_info(team_info, user_config, player_info, 3)
            local team_member_4 = poe2_api.get_team_info(team_info, user_config, player_info, 4)
            local boss_name = env.boss_name
            local interaction_object = env.interaction_object
            local task_name = env.task_name
            local special_map_point = env.special_map_point
            local num = user_config["組隊設置"]["隊伍人數"]
            local current_map_info = env.current_map_info
            local arena_list = poe2_api.get_sorted_obj("競技場", range_info, player_info)

            -- 获取队友位置
            local function party_pos(name)
                poe2_api.dbgp("[party_pos]获取队友位置:",name)
                for _, member in ipairs(team_info_data) do
                    if member["name_utf8"] == name then
                        poe2_api.dbgp("[party_pos]获取队友位置:",member["current_map_name_utf8"])
                        return member["current_map_name_utf8"]
                    end
                end
                return nil
            end

            -- 获取团队是否在同一地图
            local function party_pos_memember(map)
                local members = team_info_data
                if not members then
                    poe2_api.api_print("警告：未找到团队信息")
                    return false
                end

                -- 使用计数器统计满足条件的成员数量
                local match_count = 0
                for _, member in ipairs(members) do
                    if member.name_utf8 ~= team_member_3 and member.current_map_name_utf8 == map then
                        match_count = match_count + 1
                    end
                end

                -- 返回结果
                return match_count == num - 1
            end

            -- 获取团队距离
            local function party_dis_memember(actors)
                -- 从黑板中获取团队信息
                local members = team_info_data
                if not members then
                    poe2_api.dbgp("警告：未找到团队信息")
                    return false
                end
            
                -- 将 members 转换为集合（使用表实现）
                local member_names = {}
                for _, member in ipairs(members) do
                    member_names[member.name_utf8] = true
                end
            
                -- 统计匹配的数量
                local match_count = 0
                for _, actor in ipairs(actors) do
                    if actor.name_utf8 ~= team_member_3 and member_names[actor.name_utf8] then
                        match_count = match_count + 1
                    end
                end
            
                -- 返回结果
                return match_count == num - 1
            end

            -- 团队是否有路径
            local function party_path_memember()
                local members = team_info_data
                if not members then
                    poe2_api.api_print("警告：未找到团队信息")
                    return false
                end
                
                -- 将 members 转换为集合（使用表实现），以提高查找效率
                local member_names = {}
                for _, member in ipairs(members) do
                    member_names[member.name_utf8] = true
                end
            
                -- 统计满足条件的角色数量
                local match_count = 0
            
                -- 遍历周围角色
                for _, actor in ipairs(range_info) do
                    -- 检查角色是否在团队中
                    if not member_names[actor.name_utf8] or actor.name_utf8 == team_member_3 then
                        goto continue
                    end

                    -- 检查路径是否可达
                    local point = api_FindNearestReachablePoint(actor.grid_x, actor.grid_y, 25, 0)
                    local path =  api_FindPath(player_info.grid_x, player_info.grid_y, point.x, point.y)
                    if path and #path > 0 then
                        match_count = match_count + 1
                        if match_count == num - 1 then
                            return match_count
                        end
                    end

                    ::continue::
                end
                return match_count == num - 1
            end

            -- 指定对象路径
            local function check_role_path(names)
                -- 获取范围内的角色信息
                local near_point = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y, 25, 0)

                if range_info == nil then
                    poe2_api.dbgp("警告：未找到范围内的角色信息")
                    return false
                end

                -- 遍历角色
                for _, actor in ipairs(range_info) do
                    local near_point_actor = api_FindNearestReachablePoint(actor.grid_x, actor.grid_y, 25, 1)
                    local result = api_FindPath(near_point.x, near_point.y, near_point_actor.x, near_point_actor.y)
                    if actor.name_utf8 == names and result and #result > 0 then
                        return true
                    end
                end

                -- 未找到满足条件的角色
                return false
            end
            -- 获取周围指定对象grid_x,grid_y,id
            local function get_range_pos(name)
                local actors = poe2_api.get_sorted_list(range_info, player_info)

                for _, a in ipairs(actors) do
                    if a.name_utf8 == name then
                        return { a.grid_x, a.grid_y, a.id }
                    end
                end
                return nil
            end

            -- 周围楼梯
            local function next_level()
                poe2_api.dbgp("[next_level]检测周围楼梯")
                local entrance = get_range_pos("樓梯")
                local checkpoint_pos = get_range_pos("記錄點")
                -- 提前返回如果任一位置不存在
                if not entrance or not checkpoint_pos then
                    return false
                end
                -- 直接返回距离计算结果
                local distance = poe2_api.get_point_distance(entrance[1], entrance[2], checkpoint_pos[1],
                    checkpoint_pos[2]) or 100
                if distance < 80 then
                    self.louti_id = entrance[3]
                    return true
                end
                return false
            end

            -- 小地图找物品
            local function mini_map_obj(name)
                poe2_api.dbgp("[Is_Team_leader]检测地图上是否存在物体：", name)
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == name then
                        return item  -- 直接返回第一个匹配项
                    end
                end
                return nil -- 无匹配时返回nil
            end
            local function mini_map_obj_flagStatus(name)
                poe2_api.dbgp("[Is_Team_leader]检测地图上是否存在物体：", name)
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == name and item.flagStatus1 == 1 then
                        return item  -- 直接返回第一个匹配项
                    end
                end
                return nil -- 无匹配时返回nil
            end
            local function check_pos_dis(names)
                poe2_api.dbgp("[check_pos_dis]获取位置距离:", names)
                
                if not range_info then
                    poe2_api.dbgp("[check_pos_dis]range_info 为 nil")
                    return nil
                end
                if names == nil then
                    poe2_api.dbgp("[check_pos_dis]names 为 nil")
                    return nil
                end
                -- 如果 names 是字符串，转换为表
                if type(names) == "string" then
                    names = {names}
                elseif type(names) ~= "table" then
                    return nil
                end
                if #names == 0 then
                    poe2_api.dbgp("[check_pos_dis]names表为空")
                    return nil
                end
                local target = nil
                
                -- 遍历所有可能的名称
                for _, name in ipairs(names) do
                    for _, a in ipairs(range_info) do
                        if a.name_utf8 == name then
                            target = a
                            break
                        end
                    end
                    if target then
                        break  -- 找到目标就跳出循环
                    end
                end
                
                if target then
                    return poe2_api.point_distance(
                        target.grid_x,
                        target.grid_y,
                        player_info
                    )
                else
                    poe2_api.dbgp("[check_pos_dis]未找到目标")
                    return nil
                end
            end
            if task_area == nil or me_area == "G1_1" or (string.find(me_area, "G2_3a") and special_map_point and string.find(task_area, "G2_town")) then
                env.not_move = true
                return bret.SUCCESS
            end
            if not self.follow and ((special_map_point and interaction_object and string.find(me_area, "G2_town")) or (me_area ~= task_area and poe2_api.table_contains(task_area, { "G3_1", "G3_2_2" }) and not party_dis_memember(range_info))
                    or (me_area ~= task_area and poe2_api.table_contains(task_area, { "G3_12",  "G3_14", "G3_16", "G3_17" })) or poe2_api.table_contains(task_name, { "回到過去，進入奧札爾", "探索科佩克神殿並尋找瓦爾的知識展覽室" }) or (poe2_api.table_contains(party_pos(team_member_4), { "G2_1","G4_2_2" }))) then
                
                poe2_api.dbgp("大号跟随传送")
                if not poe2_api.find_text({ UI_info = env.UI_info, text = "/clear", min_x = 0 })and not self.bool2 then
                    api_Sleep(1000)
                    poe2_api.click_keyboard("enter")
                    api_Sleep(500)
                    poe2_api.click_keyboard("backspace")
                    api_Sleep(500)
                    poe2_api.paste_text("/clear")
                    api_Sleep(500)
                    poe2_api.click_keyboard("enter")
                    api_Sleep(500)
                    self.bool2 = true
                    return bret.RUNNING
                end
                if me_area == "G3_town" and (poe2_api.table_contains(task_area, { "G3_14", "G3_16", "G3_17" }) or poe2_api.table_contains(task_name, { "回到過去，進入奧札爾", "穿過城鎮中的時空傳送門以移至殘忍難度" })) then
                    local point = get_range_pos("倉庫")
                    local waypoint_point = get_range_pos("傳送點")
                    local waypoint_pos = get_range_pos("崎點")
                    local distance_between = nil
                    if waypoint_pos and point then
                        local a = (poe2_api.get_point_distance(point[1], point[2], waypoint_pos[1], waypoint_pos[2]) or nil)
                        local b = poe2_api.point_distance(waypoint_pos[1], waypoint_pos[2], player_info)
                        if a and b then
                            if a < 120 and b < 50 then
                                poe2_api.find_text({ UI_info = UI_info, text = "崎點", click = 2, min_x = 0 })
                            else
                                if string.find(me_area, "town") then
                                    local towards_point = poe2_api.move_towards({ player_info.grid_x, player_info.grid_y },
                                        waypoint_pos, 20)
                                    api_ClickMove(poe2_api.toInt(towards_point[1]), poe2_api.toInt(towards_point[2]),0)
                                    api_Sleep(100)
                                    poe2_api.click_keyboard("space")
                                end
                            end
                        end
                        return bret.RUNNING
                    elseif not waypoint_pos and point then
                        local towards_point = poe2_api.move_towards({ player_info.grid_x, player_info.grid_y }, point, 20)
                        api_ClickMove(poe2_api.toInt(towards_point[1]), poe2_api.toInt(towards_point[2]), 0)
                        api_Sleep(100)
                        poe2_api.click_keyboard("space")
                        return bret.RUNNING
                    elseif waypoint_pos and not point then
                        if waypoint_point then
                            distance_between = (poe2_api.get_point_distance(waypoint_point[1], waypoint_point[2], waypoint_pos[1], waypoint_pos[2]) or nil)
                        end
                        if not distance_between or (distance_between and distance_between > 100) then
                            local towards_point = poe2_api.move_towards({ player_info.grid_x, player_info.grid_y },
                                waypoint_pos, 20)
                            api_ClickMove(poe2_api.toInt(towards_point[1]), poe2_api.toInt(towards_point[2]),0)
                            api_Sleep(100)
                            poe2_api.click_keyboard("space")
                            return bret.RUNNING
                        end
                    end
                end
                local count = 3
                local waypoint_name_utf8 = poe2_api.task_area_list_data(task_area)[1][2]
                if not check_pos_dis(team_member_4) and poe2_api.find_text({ UI_info = UI_info, text = waypoint_name_utf8, min_x = 0, min_y = 0, max_x = 195, max_y = 590 }) then
                    for i = 1, count do
                        if not poe2_api.find_text({ UI_info = UI_info, text = "你確定要傳送至此玩家的位置？" }) then
                            local x, y = poe2_api.get_member_name_according(UI_info, team_member_4)
                            poe2_api.dbgp("x,y",x,y)
                            if y ~= 0 then
                                local rand_x = 14 + math.random(-7, 7)
                                local rand_y = y + 21 + math.random(-7, 7)
                                api_ClickScreen(poe2_api.toInt(rand_x), poe2_api.toInt(rand_y), 0)
                                api_Sleep(500)
                                api_ClickScreen(poe2_api.toInt(rand_x), poe2_api.toInt(rand_y), 1)
                            end
                            self.bool2 = nil
                            return bret.RUNNING
                        else
                            api_ClickScreen(916, 467, 0)
                            api_Sleep(500)
                            api_ClickScreen(916, 467, 1)
                            return bret.RUNNING
                        end
                    end
                    return bret.RUNNING
                else
                    if poe2_api.find_text({ UI_info = UI_info, text = "你確定要傳送至此玩家的位置？" }) then
                        poe2_api.click_keyboard("space")
                    end
                end
            end
            poe2_api.time_p("Is_Teleport",(api_GetTickCount64() - current_time))
            if poe2_api.table_contains(me_area, { "G1_15" }) and poe2_api.table_contains(task_area, { "G1_15"}) and next_level() then
                if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info ,dis = 50}) then
                    env.not_move = true
                    return bret.SUCCESS
                end
                if not check_pos_dis(boss_name) and party_dis_memember(range_info) and not party_path_memember() then
                    poe2_api.dbgp("G1_15-小号没下楼梯")
                    self.follow = true
                    if not poe2_api.click_text_UI({ text = "respawn_at_checkpoint_button", UI_info = UI_info }) and not self.bool1 then
                        poe2_api.dbgp("向記錄點翻滚")
                        local walkpoint = poe2_api.find_text({ UI_info = UI_info, text = "記錄點", position = 3 })
                        if walkpoint then
                            api_ClickScreen(poe2_api.toInt(walkpoint[1]), poe2_api.toInt(walkpoint[2]),0)
                            api_Sleep(500)
                            poe2_api.click_keyboard("space")
                        end
                        self.bool1 = true
                    end
                    if self.time1 == 0 then
                        self.time1 = api_GetTickCount64()
                    end
                    if api_GetTickCount64() - self.time1 >= 30 * 1000 then
                        for _, name in ipairs(my_game_info.city_map) do
                            if poe2_api.find_text({ UI_info = env.UI_info, text = name, click = 0 }) then
                                self.time1 = 0
                                self.bool1 = false
                                return bret.RUNNING
                            end
                        end
                        api_ClickScreen(1230, 815, 0)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(2000)
                    end
                    return bret.RUNNING
                else
                    self.follow = false
                end
            end
            poe2_api.time_p("Is_Teleport-G1_15",(api_GetTickCount64() - current_time))
            if poe2_api.table_contains(me_area, { "G2_4_3" }) and poe2_api.table_contains(task_area, { "G2_4_3"}) and poe2_api.find_text({ UI_info = UI_info, text = "掩埋神殿", min_x = 0 }) then
                if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info,dis = 50 }) then
                    env.not_move = true
                    return bret.SUCCESS
                end
                if not party_path_memember() then
                    if not poe2_api.click_text_UI({ text = "respawn_at_checkpoint_button", UI_info = UI_info }) and not self.bool1 then
                        poe2_api.dbgp("向記錄點翻滚")
                        local walkpoint = poe2_api.find_text({ UI_info = UI_info, text = "記錄點", position = 3 })
                        if walkpoint then
                            api_ClickScreen(poe2_api.toInt(walkpoint[1]), poe2_api.toInt(walkpoint[2]),0)
                            api_Sleep(500)
                            poe2_api.click_keyboard("space")
                        end
                        self.bool1 = true
                    end
                    if self.time1 == 0 then
                        self.time1 = api_GetTickCount64()
                    end
                    if api_GetTickCount64() - self.time1 >= 30 * 1000 then
                        for _, name in ipairs(my_game_info.city_map) do
                            if poe2_api.find_text({ UI_info = env.UI_info, text = name, click = 0 }) then
                                self.time1 = 0
                                self.bool1 = false
                                return bret.RUNNING
                            end
                        end
                        api_ClickScreen(1230, 815, 0)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(2000)
                    end
                    return bret.RUNNING
                else
                    self.follow = false
                end
            end
            poe2_api.time_p("Is_Teleport1",(api_GetTickCount64() - current_time))
            if poe2_api.table_contains(me_area, { "G3_12" }) and poe2_api.table_contains(task_area, { "G3_12" }) and not poe2_api.is_have_boss_distance(range_info, player_info, boss_name) then
                if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info,dis = 70 }) then
                    env.not_move = true
                    return bret.SUCCESS
                end
                if next_level() and check_pos_dis("樓梯") and check_pos_dis("樓梯") < 70 and not check_role_path(team_member_4) and check_pos_dis(team_member_4) and check_pos_dis(team_member_4) > 30 then
                    poe2_api.dbgp("G3_12楼梯")
                    self.follow = true
                    poe2_api.find_text({ UI_info = UI_info, text = "競技場", click = 2 })
                    if not poe2_api.click_text_UI({ text = "respawn_at_checkpoint_button", UI_info = UI_info }) and not self.bool1 then
                        poe2_api.dbgp("向記錄點翻滚")
                        local walkpoint = poe2_api.find_text({ UI_info = UI_info, text = "記錄點", position = 3 })
                        if walkpoint then
                            api_ClickScreen(poe2_api.toInt(walkpoint[1]), poe2_api.toInt(walkpoint[2]),0)
                            api_Sleep(500)
                            poe2_api.click_keyboard("space")
                        end
                       
                        self.bool1 = true
                    end
                    if self.time1 == 0 then
                        self.time1 = api_GetTickCount64()
                    end
                    if api_GetTickCount64() - self.time1 >= 30 * 1000 then
                        for _, name in ipairs(my_game_info.city_map) do
                            if poe2_api.find_text({ UI_info = env.UI_info, text = name, click = 0 }) then
                                self.time1 = 0
                                self.bool1 = false
                                return bret.RUNNING
                            end
                        end
                        api_ClickScreen(1230, 815, 0)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(2000)
                    end
                    return bret.RUNNING
                elseif not check_pos_dis(team_member_4) then
                    return bret.RUNNING
                else
                    self.follow = false
                    if poe2_api.click_text_UI({ text = "respawn_at_checkpoint_button", UI_info = UI_info }) then
                        poe2_api.click_keyboard("space")
                        return bret.RUNNING
                    end
                end
            end
            poe2_api.time_p("Is_Teleport2",(api_GetTickCount64() - current_time))
            if string.find(me_area, "G3_town") then
                if not check_pos_dis("傳送點") then
                    if not check_pos_dis("崎點") and poe2_api.find_text({ UI_info = UI_info, text = "淹沒之城", min_x = 0 })
                        and (not interaction_object or not poe2_api.table_contains(interaction_object, "科佩克")) and task_name ~= "找出控制機關並啟用水道，抽乾該區的水。" then
                        poe2_api.find_text({ UI_info = UI_info, text = "淹沒之城", click = 2 })
                        return bret.RUNNING
                    elseif interaction_object and poe2_api.table_contains(interaction_object, "科佩克") and poe2_api.find_text({ UI_info = UI_info, text = "淹沒之城", min_x = 0 }) and poe2_api.find_text({ UI_info = UI_info, text = "科佩克神殿", min_x = 0 }) then
                        poe2_api.find_text({ UI_info = UI_info, text = "科佩克神殿", min_x = 0, click = 2 })
                        self.click_ke = true
                        return bret.RUNNING
                    end
                    if self.click_ke and string.find(task_area, "G3_12") and not string.find(me_area, "G3_12") then
                        poe2_api.find_text({ UI_info = UI_info, text = "科佩克神殿", min_x = 0, click = 2 })
                    else
                        self.click_ke = false
                    end
                end
            end
            if task_name == "科佩克神殿" and string.find(me_area, "G3_12") then
                return bret.RUNNING
            end
            if task_name == "瑪特蘭水道" and string.find(me_area, "G3_2_2") then
                return bret.RUNNING
            end
            if string.find(me_area, "own") then
                self.back_city = true
            end
            if me_area == task_area then
                if string.find(me_area,"G4") then
                    local g4_area_name = get_range_pos(poe2_api.task_area_list_data(task_area)[1][2])
                    if g4_area_name then
                        local distance = poe2_api.point_distance(g4_area_name[1], g4_area_name[2], player_info)
                        if distance < 30 then
                            poe2_api.find_text({UI_info = env.UI_info, text = poe2_api.task_area_list_data(task_area)[1][2], click = 2})
                            return bret.RUNNING
                        else                    
                            env.end_point= {g4_area_name[1], g4_area_name[2]}
                            return bret.SUCCESS
                        end
                    end
                end
                if task_area == "G4_4_1" then
                    if poe2_api.find_text({UI_info = env.UI_info, text = "通道", min_x = 0}) and mini_map_obj_flagStatus("Waypoint") then
                        poe2_api.find_text({UI_info = env.UI_info, text = "通道", min_x = 0,click = 2})
                        return bret.RUNNING
                    end
                end
                if not string.find(me_area, "own") then
                    if (not party_pos_memember(me_area) or not party_dis_memember(range_info)) and not self.back_city then
                        if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info }) or player_info.isInBossBattle then
                            env.not_move = true
                            return bret.SUCCESS
                        end
                        if self.time1 == 0 then
                            self.time1 = api_GetTickCount64()
                        end
                        local retime = api_GetTickCount64() - self.time1
                        if retime >= 60 * 1000 and player_info.life ~= 0 then
                            for _, name in ipairs(my_game_info.city_map) do
                                if poe2_api.find_text({ UI_info = env.UI_info, text = name, click = 2 }) then
                                    return bret.RUNNING
                                end
                            end
                            api_ClickScreen(1230, 815, 0)
                            api_Sleep(500)
                            api_ClickScreen(1230, 815, 1)
                            api_Sleep(2000)
                        end
                        return bret.RUNNING
                    else
                        self.time1 = 0
                        self.back_city = false
                    end
                else
                    self.time1 = 0
                    if poe2_api.click_text_UI({ text = "respawn_at_checkpoint_button", UI_info = UI_info }) then
                        poe2_api.click_keyboard("space")
                        return bret.RUNNING
                    end
                end
                if poe2_api.find_text({ UI_info = UI_info, text = "傳送", click = 0, min_x = 0 }) then
                    poe2_api.click_keyboard("space")
                    return bret.RUNNING
                end
                if arena_list and #arena_list > 0 and arena_list[1].hasLineOfSight and arena_list[1].is_selectable and api_FindPath(player_info.grid_x, player_info.grid_y, arena_list[1].grid_x, arena_list[1].grid_y) then
                    if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info }) then
                        poe2_api.dbgp("有怪物不点击arena_list")
                        env.not_move = true
                        return bret.SUCCESS
                    end
                    if not poe2_api.find_text({ UI_info = UI_info, text = "競技場" }) then
                        local arena = get_range_pos("競技場")
                        if arena then
                            local near_point = api_FindNearestReachablePoint(arena[1], arena[2], 40, 1)
                            env.end_point = { near_point.x, near_point.y }
                            return bret.SUCCESS
                        end
                    end
                    poe2_api.find_text({ UI_info = UI_info, text = "競技場", click = 2 })
                    env.end_point = nil
                    env.entrancelist = {}
                    env.end_point = {}
                    return bret.RUNNING
                end
                if poe2_api.table_contains(me_area, { "G1_15", "G2_3", "G3_12"}) then
                    local louti = get_range_pos("樓梯")
                    if poe2_api.table_contains(me_area, { "G1_15" }) then
                        if not mini_map_obj("GargoyleInactive") and mini_map_obj("Waypoint") then
                            env.not_move = true
                            return bret.SUCCESS
                        end
                    end
                    if not check_pos_dis(team_member_4) and team_member_2 ~= "未知" then
                        return bret.RUNNING
                    end
                    if not check_pos_dis("崛起之王．賈嫚拉") and string.find(me_area, "G2_3$") then
                        env.is_arrive_end = true
                        return bret.SUCCESS
                    elseif poe2_api.find_text({ UI_info = UI_info, text = "樓梯", min_x = 0 }) and poe2_api.find_text({ UI_info = UI_info, text = "記錄點", min_x = 0}) then
                        poe2_api.dbgp("已在下一层")
                        self.louti_id = louti[3]
                        env.not_move = true
                        return bret.SUCCESS
                    elseif not next_level() and louti then
                        poe2_api.dbgp("进入点击楼梯操作")
                        if self.louti_id and self.louti_id == louti[3] then
                            poe2_api.dbgp("樓梯id相同")
                            env.not_move = true
                            return bret.SUCCESS
                        end
                        if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info }) then
                            poe2_api.dbgp("有怪物不点击樓梯")
                            env.not_move = true
                            return bret.SUCCESS
                        end
                        if louti and (not poe2_api.table_contains(me_area, { "G2_3" }) or not poe2_api.find_text({ UI_info = UI_info, text = "樓梯", min_x = 0 })) then
                            if check_pos_dis("樓梯") > 50 then
                                poe2_api.dbgp("樓梯距离太远")
                                local nearest_point = api_FindNearestReachablePoint(louti[1], louti[2], 40, 0)
                                env.end_point = { nearest_point.x, nearest_point.y }
                                return bret.SUCCESS
                            end
                        end
                        poe2_api.find_text({ UI_info = UI_info, text = "樓梯", min_x = 0, click = 2 })
                        env.end_point = nil
                        env.entrancelist = {}
                        env.end_point = {}
                        return bret.RUNNING
                    end
                end
                poe2_api.time_p("Is_Telepor3",(api_GetTickCount64() - current_time))
                env.not_move = true
                return bret.SUCCESS
            end
            if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info }) then
                env.not_move = true
                return bret.SUCCESS
            end
            poe2_api.dbgp("=== 进入传送判断 ===")
            poe2_api.time_p("Is_Telepor4",(api_GetTickCount64() - current_time))
            return bret.FAIL
        end
    },

    -- 传送点是否打开
    Is_Open_Task_Wayoint = {
        run = function(self, env)
            local task_area = env.map_name
            local player_info = env.player_info
            local task_area_name = poe2_api.task_area_list_data(task_area)[1][1]
            local waypoint = env.waypoint
            local current_map = player_info.current_map_name_utf8
            if current_map == task_area then
                return bret.RUNNING
            end
            if poe2_api.task_area_list_data(task_area)[2] == "有" and poe2_api.Waypoint_is_open(task_area, waypoint) then
                if string.find(task_area, "G2") and not string.find(current_map, "G2") and task_area~="G2_1" then
                    env.teleport_area = "G2_town"
                    return bret.SUCCESS
                end

                if string.find(task_area, "G3") and not string.find(current_map, "G3") then
                    env.teleport_area = "G3_town"
                    return bret.SUCCESS
                end

                env.teleport_area = task_area
                return bret.SUCCESS
            else
                if task_area == "G3_12" then
                    env.teleport_area = task_area
                    return bret.SUCCESS
                end

                if not poe2_api.Waypoint_is_open(task_area, waypoint) and task_area ~= "G3_2_2"  then
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖",refresh = true}) then
                        api_Sleep(800)
                        poe2_api.click_keyboard("u")
                    end
                    api_Sleep(200)
                    if string.find(task_area, "G1") then
                        api_Sleep(500)
                        poe2_api.find_text({ UI_info = env.UI_info, text = "第 1 章", click = 2, refresh = true })
                        api_Sleep(500)
                        env.waypoint = api_GetTeleportationPoint()
                    elseif string.find(task_area, "G2") then
                        api_Sleep(500)
                        poe2_api.find_text({ UI_info = env.UI_info, text = "第 2 章", click = 2, refresh = true })
                        api_Sleep(500)
                        env.waypoint = api_GetTeleportationPoint()
                    elseif string.find(task_area, "G3") then
                        api_Sleep(500)
                        poe2_api.find_text({ UI_info = env.UI_info, text = "第 3 章", click = 2, refresh = true })
                        api_Sleep(500)
                        env.waypoint = api_GetTeleportationPoint()
                    elseif string.find(task_area, "G4") then
                        api_Sleep(500)
                        poe2_api.find_text({ UI_info = env.UI_info, text = "第 4 章", click = 2, refresh = true })
                        api_Sleep(500)
                        env.waypoint = api_GetTeleportationPoint()
                    elseif string.find(task_area, "P") then
                        api_Sleep(500)
                        poe2_api.find_text({ UI_info = env.UI_info, text = "間歇", click = 2, refresh = true })
                        api_Sleep(500)
                        env.waypoint = api_GetTeleportationPoint()
                    end
                    api_Sleep(200)
                    poe2_api.click_keyboard("u")
                    poe2_api.print_log("任务地区" .. task_area_name .. "传送点未打开")
                    return bret.RUNNING
                end

                poe2_api.print_log("任务地区传送点未打开")
                return bret.RUNNING
            end
        end
    },

    -- 传送点是否在附近
    Teleport_Is_Near = {
        run = function(self, env)
            local player_info = env.player_info
            local task_area = env.map_name
            local current_map = player_info.current_map_name_utf8
            local teleport_area = env.teleport_area
            local range_info = env.range_info
            local UI_info = env.UI_info
            local current_map_info = env.current_map_info

            local function get_actor_pos(name)
                for _, a in ipairs(range_info) do
                    if string.find(a.name_utf8 , name) then
                        return { a.grid_x, a.grid_y, a.id }
                    end
                end
                return nil
            end

            local function get_current_map_info_pos(name)
                for _, a in ipairs(current_map_info) do
                    if a.name_utf8 == name then
                        return { a.grid_x, a.grid_y }
                    end
                end
                return nil
            end

            local function check_pos_dis(names)
                poe2_api.dbgp("[Teleport_Is_Near]判断指定名称与主角的距离")
                if range_info ~= nil then
                    for _, point in ipairs(range_info) do
                        if string.find(point.name_utf8 , names) then
                            local l = poe2_api.point_distance(point.grid_x, point.grid_y, player_info)
                            return l
                        end
                    end
                end
                return nil
            end
            local function check_current_map_info_dis(names)
                poe2_api.dbgp("[Teleport_Is_Near]判断指定小地图与主角的距离")
                if current_map_info ~= nil and #current_map_info > 0  then
                    for _, point in ipairs(current_map_info) do
                        if point.name_utf8 == names then
                            local l = poe2_api.point_distance(point.grid_x, point.grid_y, player_info)
                            return l
                        end
                    end
                end
                return nil
            end
            if poe2_api.find_text({ UI_info = UI_info, text = "記錄點", click = 0 }) then
                if not check_pos_dis("記錄點") then
                    api_Sleep(8 * 1000)
                    return bret.RUNNING
                end
            end
            if string.find(task_area, "G3_12") then
                poe2_api.dbgp("[task_area]G3_12")
                if string.find(current_map, "G3_town") then
                    poe2_api.dbgp("[task_area]G3_12,在城镇")
                    local target_pos = { 458, 324 }

                    local foundPath = api_FindPath(player_info.grid_x, player_info.grid_y, target_pos[1], target_pos[2])
                    if foundPath then
                        env.end_point = { target_pos[1], target_pos[2] }
                        return bret.SUCCESS
                    end

                    -- ==== 传送点距离检测 ====
                    local point = get_actor_pos("傳送點")
                    local distance = check_pos_dis("傳送點")
                    if distance > 30 then
                        env.end_point = { point[1], point[2] }
                        return bret.SUCCESS
                    end

                    -- ====处理区域前缀 ====
                    local area_prefix = ""
                    if string.find(current_map or "", "C_") then
                        area_prefix = "C_"
                    end
                    env.teleport_area = area_prefix .. "G3_12"
                    return bret.FAIL
                else
                    poe2_api.dbgp("[task_area]G3_12,回到城镇")
                    if poe2_api.find_text({ UI_info = UI_info, text = "傳送", click = 0 }) then
                        poe2_api.click_keyboard("space")
                        return bret.RUNNING
                    end

                    for _, name in ipairs(my_game_info.city_map) do
                        if poe2_api.find_text({ UI_info = UI_info, text = name, click = 2 }) then
                            return bret.RUNNING
                        end
                    end
                    api_ClickScreen(1230, 815, 0)
                    api_Sleep(500)
                    api_ClickScreen(1230, 815, 1)
                    api_Sleep(2000)
                    return bret.RUNNING
                end
            end
            if not string.find(teleport_area, "G3_1$") and string.find(current_map, "G3_1$") then
                poe2_api.dbgp("[teleport_area]G3_town")
                local has_teleport = check_pos_dis("傳送點")
                if not has_teleport then
                    if poe2_api.find_text({ UI_info = env.UI_info, text = "城鎮傳送門", click = 2 }) then
                        if check_pos_dis("傳送點") then
                            return bret.FAIL
                        end
                        return bret.RUNNING
                    end
                    api_ClickScreen(1230, 815, 0)
                    api_Sleep(500)
                    api_ClickScreen(1230, 815, 1)
                    api_Sleep(2000)
                    return bret.RUNNING
                else
                    local point = get_actor_pos("傳送點")
                    if check_pos_dis("傳送點") > 30 then
                        env.end_point = { point[1], point[2] }
                        return bret.SUCCESS
                    end
                    return bret.FAIL
                end
            end
            if (teleport_area == "G2_town" and current_map == "G2_1") or not check_current_map_info_dis("Waypoint") or (not check_pos_dis("傳送點") and check_current_map_info_dis("Waypoint") > 200) then
                poe2_api.dbgp("非常规传送点处理")
                if string.find(current_map, "G2_1$") and not check_pos_dis("札卡") then
                    poe2_api.dbgp("[teleport_area]G2_1札卡")
                    if poe2_api.find_text({ UI_info = UI_info, text = "城鎮傳送門", click = 2 }) then
                        if check_pos_dis("傳送點") then
                            local point = get_actor_pos("傳送點")
                            if check_pos_dis("傳送點") > 30 then
                                env.end_point = { point[1], point[2] }
                                return bret.SUCCESS
                            end
                            return bret.FAIL
                        end
                        return bret.RUNNING
                    end
                    api_ClickScreen(1230, 815, 0)
                    api_Sleep(500)
                    api_ClickScreen(1230, 815, 1)
                    api_Sleep(2000)
                    return bret.RUNNING
                elseif string.find(current_map, "G2_1$") and check_pos_dis("札卡") then
                    local point = get_actor_pos("阿杜拉車隊")
                    if point and check_pos_dis("阿杜拉車隊") > 30 then
                        env.end_point = { point[1], point[2] }
                        return bret.SUCCESS
                    end
                    poe2_api.find_text({ UI_info = UI_info, text = "阿杜拉車隊", click = 2 })
                    return bret.SUCCESS
                end

                if not string.find(current_map, "town") then
                    poe2_api.dbgp("[Teleport_Is_Near]非城区处理")
                    if poe2_api.find_text({ UI_info = UI_info, text = "傳送", click = 0 }) then
                        poe2_api.click_keyboard("space")
                        return bret.RUNNING
                    end
                    for _, name in ipairs(my_game_info.city_map) do
                        if poe2_api.find_text({ UI_info = UI_info, text = name, click = 2 }) then
                            if string.find(current_map, "town") then
                                env.teleport_area = task_area
                                return bret.FAIL
                            end
                            return bret.RUNNING
                        end
                    end
                    api_ClickScreen(1230, 815, 0)
                    api_Sleep(500)
                    api_ClickScreen(1230, 815, 1)
                    api_Sleep(2000)
                    return bret.RUNNING
                end

                if string.find(current_map, "G3_town") and not check_pos_dis("傳送點") then
                    env.end_point = { 434, 299 }
                    return bret.SUCCESS
                end
                if string.find(current_map, "G2_town") then
                    env.end_point = { 345, 192 }
                    return bret.SUCCESS
                end
                return bret.FAIL
            else
                poe2_api.dbgp("常规传送点处理")
                local point = get_actor_pos("傳送點")
                local map_info_point = get_current_map_info_pos("Waypoint")
                local waypoint_pos = get_actor_pos("崎點")
                if point then
                    if current_map == "G3_town" and waypoint_pos and not poe2_api.table_contains(task_area, { "G3_14", "G3_16", "G3_17" }) then
                        local distance_between = poe2_api.get_point_distance(point[1], point[2], waypoint_pos[1],
                            waypoint_pos[2])
                        local distance_to_player = poe2_api.point_distance(waypoint_pos[1], waypoint_pos[2], player_info)      
                        if distance_between < 100 then
                            if distance_to_player > 30 then
                                env.end_point = { waypoint_pos[1], waypoint_pos[2] }
                                return bret.SUCCESS
                            else
                                poe2_api.find_text({ UI_info = UI_info, text = "崎點", click = 2 })
                                return bret.RUNNING
                            end
                        end
                    end
                    if (point and check_pos_dis("傳送點") > 30) or (map_info_point and not point and check_current_map_info_dis("Waypoint") <= 300 ) then
                        if not point then
                            point = map_info_point
                        end
                        env.end_point = { point[1], point[2] }
                        return bret.SUCCESS
                    end
                    return bret.FAIL
                end
            end
            return bret.RUNNING
        end
    },

    -- 地区传送
    Click_Map_To_Area_Teleport = {
        run = function(self, env)
            poe2_api.print_log("地区传送模块开始执行...")
            poe2_api.dbgp("[Click_Map_To_Area_Teleport]地区传送模块开始执行...")
            local teleport_area = env.teleport_area
            local task_area_name = poe2_api.task_area_list_data(teleport_area)[1][1]
            local UI_info = env.UI_info
            local player_info = env.player_info
            local current_map = player_info.current_map_name_utf8
            local waypoint = env.waypoint
            local waypoint_screen = poe2_api.waypoint_pos(teleport_area,waypoint)
            if self.s_time == nil then
                self.s_time = 0
                self.last_click_time = 0
                self.click_cooldown = 1
            end
            if self.s_time == 0 then
                self.s_time = api_GetTickCount64()
            end
            -- 获取地面UI层级
            local function switch_ground()
                poe2_api.dbgp("获取地面UI层级...")
                local controls = poe2_api.get_game_control_by_rect({
                    UI_info = env.UI_info, 
                    min_x = 1525, 
                    min_y = 230, 
                    max_x = 1600,
                    max_y = 560
                })
                
                -- 使用表来筛选符合条件的控件
                local filtered_controls = {}
                for _, control in ipairs(controls) do
                    if control.name_utf8 == "" and control.left == 1544.625 then
                        table.insert(filtered_controls, control)
                    end
                end
                
                if #filtered_controls == 0 then
                    poe2_api.dbgp("未找到符合条件的UI控件")
                    return false
                end
                
                -- 使用排序方法找到最小top值
                table.sort(filtered_controls, function(a, b)
                    return a.top < b.top
                end)
                
                local min_top = filtered_controls[1].top
                poe2_api.dbgp("最小top值:", min_top)
                return min_top
            end
            if current_map ~= teleport_area then
                if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81,refresh = true}) then
                    poe2_api.click_keyboard("i")
                end
                if poe2_api.find_text({ UI_info = UI_info, text = "傳送點", refresh = true,min_x = 0 }) then
                    local ctime = api_GetTickCount64()
                    if ctime - self.s_time > 30 * 1000 then
                        poe2_api.click_keyboard("space")
                        self.s_time = 0
                    end
                    if self.last_click_time == 0 then
                        self.last_click_time = api_GetTickCount64()
                    end
                    if api_GetTickCount64() - self.last_click_time > self.click_cooldown * 1000 then
                        poe2_api.find_text({ UI_info = UI_info, text = "傳送點", click = 2, refresh = true })
                        self.last_click_time = 0
                    end
                    return bret.RUNNING
                else
                    local mini_top = switch_ground()
                    if not mini_top then
                        return bret.RUNNING
                    end
                    self.s_time = 0
                    if string.find(teleport_area, "G1") and not poe2_api.find_text({UI_info = env.UI_info, text = "奧格姆郡，約恆曆", min_x = 0, match = 2, refresh = true}) then
                        poe2_api.dbgp("切层级")
                        api_Sleep(600)
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 0)
                        api_Sleep(600)
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 1)
                        api_Sleep(600)
                        poe2_api.find_text({ UI_info = UI_info, text = "第 1 章", click = 2, refresh = true })
                        api_Sleep(600)
                        return bret.RUNNING
                    elseif string.find(teleport_area, "G2") and not poe2_api.find_text({UI_info = env.UI_info, text = "七大水域之地", min_x = 0, match = 2, refresh = true}) then
                        poe2_api.dbgp("切层级")
                        api_Sleep(600)
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 0)
                        api_Sleep(600)
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 1)
                        api_Sleep(600)
                        poe2_api.find_text({ UI_info = UI_info, text = "第 2 章", click = 2, refresh = true })
                        api_Sleep(600)
                        return bret.RUNNING
                    elseif string.find(teleport_area, "G3") and not poe2_api.find_text({UI_info = env.UI_info, text = "奧札爾區域草稿 #", min_x = 0, match = 2, refresh = true}) and not poe2_api.find_text({UI_info = env.UI_info, text = "古奧札爾草稿", min_x = 0, match = 2, refresh = true}) then
                        poe2_api.dbgp("切层级")
                        api_Sleep(600)
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 0)
                        api_Sleep(600)
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 1)
                        api_Sleep(600)
                        poe2_api.find_text({ UI_info = UI_info, text = "第 3 章", click = 2, refresh = true })
                        api_Sleep(600)
                        return bret.RUNNING
                    elseif string.find(teleport_area, "G4") and not poe2_api.find_text({UI_info = env.UI_info, text = "金司馬區港", min_x = 0, match = 2, refresh = true}) then
                        api_Sleep(600)
                        poe2_api.find_text({ UI_info = UI_info, text = "第 4 章", click = 2, refresh = true })
                        api_Sleep(600)
                        return bret.RUNNING
                    end
                    if poe2_api.find_text({UI_info = env.UI_info, text = "奧格姆郡，約恆曆", min_x = 0, match = 2}) or 
                        poe2_api.find_text({UI_info = env.UI_info, text = "七大水域之地", min_x = 0, match = 2}) or 
                        poe2_api.find_text({UI_info = env.UI_info, text = "奧札爾區域草稿 #", min_x = 0, match = 2}) or 
                        poe2_api.find_text({UI_info = env.UI_info, text = "古奧札爾草稿", min_x = 0, match = 2}) or
                        poe2_api.find_text({UI_info = env.UI_info, text = "金司馬區港", min_x = 0, match = 2}) then
                        if not poe2_api.find_text({ UI_info = UI_info, text = task_area_name, click = 0, refresh = true }) then
                            if #(poe2_api.task_area_list_data(teleport_area)) < 3 then
                                waypoint_screen = poe2_api.waypoint_pos(teleport_area,env.waypoint)
                                if waypoint_screen[1] <= 0 or waypoint_screen[2] <= 0  then
                                    poe2_api.dbgp("获取传送点失败，重新获取传送点")
                                    api_Sleep(1000)
                                    env.waypoint = api_GetTeleportationPoint()
                                    api_Sleep(1000)
                                    return bret.RUNNING
                                end
                                if teleport_area == "G2_town" then
                                    api_Sleep(1000)
                                    env.waypoint = api_GetTeleportationPoint()
                                    api_Sleep(1000)
                                    waypoint_screen = poe2_api.waypoint_pos(teleport_area,env.waypoint)
                                end
                                api_ClickScreen(poe2_api.toInt(waypoint_screen[1]), poe2_api.toInt(waypoint_screen[2]), 0)
                                api_Sleep(1000)
                                if teleport_area ~= "G3_town" and not poe2_api.find_text({ UI_info = UI_info, text = task_area_name, click = 0,min_x = 0, refresh = true }) then
                                    api_Sleep(300)
                                    poe2_api.click_keyboard("space")
                                    return bret.RUNNING
                                end
                                api_Sleep(300)
                                if string.find(teleport_area, "own") or  poe2_api.table_contains(teleport_area, {"G1_7","G2_1"}) then
                                    poe2_api.dbgp("回城镇或者去G1_7")
                                    api_ClickScreen(poe2_api.toInt(waypoint_screen[1]), poe2_api.toInt(waypoint_screen[2]), 1)
                                    return bret.RUNNING
                                end
                                if not string.find(teleport_area, "own") and not poe2_api.table_contains(teleport_area, {"G1_7","G2_1"}) and
                                    not poe2_api.find_text({ UI_info = UI_info, text = "副本管理員", click = 0, refresh = true }) then
                                    poe2_api.ctrl_left_click(waypoint_screen[1],waypoint_screen[2])
                                    api_Sleep(2000)
                                end
                                local point = poe2_api.find_text({ UI_info = UI_info, text = "新副本", min_x = 0, position = 3, refresh = true })
                                poe2_api.find_text({ UI_info = UI_info, text = "新副本", click = 2, min_x = 0, refresh = true })
                                if point and #point > 0  then
                                    api_ClickScreen(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]), 1)
                                elseif teleport_area == "G1_7" then
                                    api_ClickScreen(poe2_api.toInt(waypoint_screen[1]), poe2_api.toInt(waypoint_screen[2]), 1)
                                end
                                return bret.RUNNING
                            else
                                poe2_api.dbgp("切地下层级")
                                api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 0)
                                api_Sleep(300)
                                api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 1)
                                api_Sleep(2000)
                            end
                        end
                    elseif #(poe2_api.task_area_list_data(teleport_area)) < 3 then
                        poe2_api.dbgp("切地上层级")
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 0)
                        api_Sleep(300)
                        api_ClickScreen(1567, poe2_api.toInt(mini_top) + 22, 1)
                        api_Sleep(2000)
                    end
                   
                    if #(poe2_api.task_area_list_data(teleport_area)) > 2 then
                        env.waypoint = api_GetTeleportationPoint()
                        local task_two_area_name = poe2_api.task_area_list_data(teleport_area)[3]
                        teleport_area = teleport_area.."_Underground"
                        waypoint_screen = poe2_api.waypoint_pos(teleport_area,env.waypoint)
                        api_Sleep(1000)
                        api_ClickScreen(poe2_api.toInt(waypoint_screen[1]), poe2_api.toInt(waypoint_screen[2]), 0)
                        api_Sleep(1000)
                        if not poe2_api.find_text({ UI_info = UI_info, text = task_two_area_name, click = 0, min_x = 0, refresh = true }) then
                            api_Sleep(300)
                            poe2_api.click_keyboard("space")
                            return bret.RUNNING
                        end
                        if not string.find(teleport_area, "own") and
                            not poe2_api.find_text({ UI_info = UI_info, text = "副本管理員", click = 0, refresh = true }) then
                            poe2_api.ctrl_left_click(waypoint_screen[1],waypoint_screen[2])
                            api_Sleep(2000)
                        end
                        local point = poe2_api.find_text({ UI_info = UI_info, text = "新副本", min_x = 0, position = 3, refresh = true })
                        poe2_api.find_text({ UI_info = UI_info, text = "新副本", click = 2, min_x = 0, refresh = true })
                        if point then
                            api_ClickScreen(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]), 1)
                        end
                    end
                    env.map_name = nil
                    return bret.RUNNING
                end
            else
                return bret.SUCCESS
            end
        end
    },

    -- 是否在新手剧情（技能）
    Not_In_New_Area_Skill = {
        run = function(self, env)
            poe2_api.print_log("是否在新手剧情（技能）模块开始执行...")
            poe2_api.dbgp("=== 是否在新手剧情（技能） ===")
            local player_info = env.player_info
            local UI_info = env.UI_info
            local user_config = env.user_config
            local items = env.bag_info
            local current_time = api_GetTickCount64()
            if player_info.current_map_name_utf8 == "G1_1" then
                poe2_api.dbgp('全部技能信息')
                env.allskill_info = api_GetAllSkill()
                poe2_api.dbgp('获取可选技能控件')
                env.selectable_skills = api_GetSelectableSkillControls()
                local selectable_skills = env.selectable_skills
                poe2_api.dbgp('技能槽信息')
                env.skill_slots = api_GetSkillSlots()
                local skill_slots = env.skill_slots
                local function check_skill_in_pos(name)
                    poe2_api.dbgp("[check_skill_in_pos] 检查技能是否在技能栏上: " .. tostring(name))
                    for _, k in ipairs(skill_slots) do
                        if name == k.name_utf8 then
                            poe2_api.dbgp("[check_skill_in_pos] 技能在技能栏上: " .. tostring(name))
                            return true
                        end
                    end
                    poe2_api.dbgp("[check_skill_in_pos] 技能不在技能栏上: " .. tostring(name))
                    return false
                end
                
                local function skill_location(skill_name, skill_pos)
                    poe2_api.dbgp("[skill_location] 检查技能位置: " .. tostring(skill_name) .. " 位置: " .. tostring(skill_pos))
                    local point = my_game_info.skill_pos[skill_pos]
                    local skill_names = {}
                    for _, skill_control in ipairs(selectable_skills) do
                        poe2_api.printTable(skill_control)
                        skill_names[skill_control.text_utf8] = true
                    end
                    -- 检查 skill_name 是否在集合中
                    if not skill_names[skill_name] then
                        poe2_api.dbgp("[skill_location] 技能不在可选列表中: " .. tostring(skill_name))
                        return false
                    end
                    -- 遍历所有可选择的技能控件
                    for _, skill_control in ipairs(selectable_skills) do
                        if skill_name == skill_control.text_utf8 then
                            -- 计算中间位置
                            local center_x = (skill_control.left + skill_control.right) / 2
                            local center_y = (skill_control.top + skill_control.bottom) / 2
                            
                            -- 检查位置是否在指定范围内
                            if (point[1] - 5 < center_x and center_x < point[1] + 5) and 
                            (point[2] - 5 < center_y and center_y < point[2] + 5) then
                                poe2_api.dbgp("[skill_location] 技能位置正确: " .. tostring(skill_name))
                                return true
                            else
                                poe2_api.dbgp("[skill_location] 技能位置不正确: " .. tostring(skill_name) .. " 坐标: " .. center_x .. "," .. center_y)
                            end
                        end
                    end
                    
                    poe2_api.dbgp("[skill_location] 技能位置检查失败: " .. tostring(skill_name))
                    return false
                end
                
                local function is_skills(name)
                    poe2_api.dbgp("[is_skills] 检查技能是否存在: " .. tostring(name))
                    for k, v in ipairs(env.allskill_info) do
                        if v.name_utf8 == name then
                            poe2_api.dbgp("[is_skills] 技能存在: " .. tostring(name))
                            return true
                        end
                    end
                    poe2_api.dbgp("[is_skills] 技能不存在: " .. tostring(name))
                    return false
                end
                
                local function is_adjust_skills()
                    poe2_api.dbgp("[is_adjust_skills] 开始检查是否需要调整技能")
                    local skills = poe2_api.get_BD_info(user_config["組隊設置"]['職業'], "技能")
                    poe2_api.dbgp("skills",skills)
                    poe2_api.printTable(skills)
                    for k, v in pairs(skills) do
                        poe2_api.dbgp("[is_adjust_skills] 检查技能: " .. tostring(k) .. " - " .. tostring(v["skill_name"]))
                        -- 技能列表没有技能
                        if not is_skills(v["skill_name"]) then
                            env.skill_pos = v["skill_pos"]
                            env.skill_name = k
                            poe2_api.dbgp("[is_adjust_skills] 需要调整: 技能不存在")
                            return true
                        
                        -- 技能列表有技能，但是不在技能栏上
                        elseif not check_skill_in_pos(v["skill_name"]) and v["primary_or_secondary"] then
                            env.skill_pos = v["skill_pos"]
                            env.skill_name = k
                            poe2_api.dbgp("[is_adjust_skills] 需要调整: 技能不在技能栏上")
                            return true
                        
                        -- 技能列表有技能，但是不在指定位置
                        elseif not skill_location(v["skill_name"], v["skill_pos"]) and v["primary_or_secondary"] then
                            env.skill_pos = v["skill_pos"]
                            env.skill_name = k
                            poe2_api.dbgp("[is_adjust_skills] 需要调整: 技能位置不正确")
                            return true
                        end
                    end
                    
                    poe2_api.dbgp("[is_adjust_skills] 无需调整技能")
                    return false
                end
                
                local function is_exist(name)
                    poe2_api.dbgp("[is_exist] 检查物品是否存在: " .. tostring(name))
                    local level = poe2_api.get_BD_info(user_config["組隊設置"]['職業'], "技能", env.skill_name, "level_skillstone")
                    poe2_api.dbgp("[is_exist] 所需等级: " .. tostring(level))
                    if items and #items > 0 then
                        for _, item in ipairs(items) do
                            if item.name_utf8 == name and item.skillGemLevel == level then
                                poe2_api.dbgp("[is_exist] 物品存在: " .. tostring(name) .. " 等级: " .. tostring(level))
                                return true
                            end
                        end
                    end
                    poe2_api.dbgp("[is_exist] 物品不存在: " .. tostring(name))
                    return false
                end

                
                -- 判断武器技能是否存在
                local function is_weapon_skill()
                    poe2_api.dbgp("[is_weapon_skill] 检查武器技能")
                    for _, skill_info in pairs(env.allskill_info) do
                        if skill_info.name_utf8 ~= "" and not skill_info.name_utf8:find("WeaponGrantedSummon") then
                            if skill_info.name_utf8:find("WeaponGranted") or poe2_api.table_contains(skill_info.name_utf8, {"FireboltPlayer","MeleeBowPlayer","MeleeCrossbowPlayer","MeleeSpearOffHandPlayer","Melee1HMacePlayer","MeleeQuarterstaffPlayer"}) then
                                poe2_api.dbgp("[is_weapon_skill] 找到武器技能: " .. tostring(skill_info.name_utf8))
                                return skill_info.name_utf8
                            end
                        end
                    end
                    poe2_api.dbgp("[is_weapon_skill] 未找到武器技能")
                    return false
                end
                
                -- 判断技能列表中有无自定义技能 背包有无技能石
                local function get_skill_names()
                    poe2_api.dbgp("[get_skill_names] 开始获取技能名称")
                    
                    local function get_skill()
                        poe2_api.dbgp("[get_skill] 获取角色技能")
                        local skills = poe2_api.get_BD_info(user_config["組隊設置"]['職業'], "技能")
                        for k, v in pairs(skills) do
                            local name = k:gsub(" ", "") .. "Player"
                            poe2_api.dbgp("[get_skill] 检查技能: " .. tostring(name))
                            for _, skill_info in pairs(env.allskill_info) do
                                if skill_info.name_utf8 ~= "" and not skill_info.name_utf8:find("WeaponGranted") and skill_info.name_utf8:find(name) then
                                    poe2_api.dbgp("[get_skill] 找到自定义技能: " .. tostring(skill_info.name_utf8))
                                    return true
                                end
                            end
                        end
                        poe2_api.dbgp("[get_skill] 未找到自定义技能")
                        return false
                    end
                
                    local function get_backpack()
                        poe2_api.dbgp("[get_backpack] 检查背包技能石")
                        if items then
                            for _, item in ipairs(items) do
                                if item.baseType_utf8 == "技能寶石" then
                                    poe2_api.dbgp("[get_backpack] 找到技能石: " .. tostring(item.name_utf8))
                                    return true
                                end
                            end
                        end
                        poe2_api.dbgp("[get_backpack] 未找到技能石")
                        return false
                    end
                
                    local function get_paskill(name)
                        poe2_api.dbgp("[get_paskill] 检查技能位置: " .. tostring(name))
                        local skill_slots = env.skill_slots
                        if not skill_slots then
                            poe2_api.dbgp("[get_paskill] 技能槽信息为空")
                            return false
                        else
                            for _, slot in ipairs(skill_slots) do
                                if slot.name_utf8 == name then
                                    poe2_api.dbgp("[get_paskill] 找到技能: " .. tostring(name))
                                    if not skill_location(name, "Q") then
                                        poe2_api.dbgp("[get_paskill] 技能位置不正确")
                                        return false
                                    end
                                    poe2_api.dbgp("[get_paskill] 技能位置正确")
                                    return true
                                end
                            end
                            poe2_api.dbgp("[get_paskill] 未找到技能: " .. tostring(name))
                            return false
                        end
                    end
                
                    if not get_skill() and not get_backpack() then
                        poe2_api.dbgp("[get_skill_names] 需要检查武器技能")
                        local name = is_weapon_skill()
                        if not name then
                            name = "MeleeUnarmedPlayer"
                            poe2_api.dbgp("[get_skill_names] 使用默认武器技能: " .. tostring(name))
                        end
                        if not get_paskill(name) then
                            poe2_api.dbgp("[get_skill_names] 武器技能检查失败")
                            return false
                        end
                    end
                    poe2_api.dbgp("[get_skill_names] 技能检查完成")
                    return true
                end

                local bool = get_skill_names()
                -- 移动装备 and 技能列表有自定义技能或者有技能石才调自定义技能
                if  bool then
                    if not is_adjust_skills() then
                        if poe2_api.find_text({UI_info = env.UI_info, text = "技能", min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
                            poe2_api.click_keyboard("space")
                            return bret.RUNNING
                        end
                        if poe2_api.find_text({UI_info = env.UI_info, text = "點擊  <N>{<normal>{I}} 查看背包。", min_x = 450, min_y = 600}) then
                            poe2_api.click_keyboard("i")
                        end
                        if poe2_api.find_text({UI_info = env.UI_info, text = "按下<normal>{<n>{W}}來使用你的新技能", min_x = 0}) then
                            poe2_api.click_keyboard("w")
                        end
                        return bret.SUCCESS
                    end
                    
                    local skill = poe2_api.get_BD_info(user_config["組隊設置"]['職業'], "技能", env.skill_name, "skill_name")
                    if skill and not is_skills(skill) and not poe2_api.check_item_in_inventory(env.skill_name,items) and not is_exist("技能寶石") then
                        if poe2_api.find_text({UI_info = env.UI_info, text = "技能", min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
                            poe2_api.click_keyboard("space")
                            return bret.RUNNING
                        end
                        if poe2_api.find_text({UI_info = env.UI_info, text = "點擊  <N>{<normal>{I}} 查看背包。", min_x = 450, min_y = 600}) then
                            poe2_api.click_keyboard("w")
                        end
                        if poe2_api.find_text({UI_info = env.UI_info, text = "按下<normal>{<n>{W}}來使用你的新技能", min_x = 0}) then
                            poe2_api.click_keyboard("w")
                        end
                        return bret.SUCCESS
                    end
                else
                    if not bool then
                        local skill_name = is_weapon_skill()
                        env.skill_pos = "Q"
                        if skill_name then
                            env.skill_name = skill_name
                        else
                            env.skill_name = "MeleeUnarmedPlayer"
                        end
                    end
                end
                poe2_api.dbgp("[is_fast_skill] 检查技能: " .. tostring(env.skill_name))
                return bret.FAIL
            end
            if poe2_api.find_text({ UI_info = env.UI_info, text = "技能", min_x = 0, min_y = 32, max_x = 381, max_y = 81 }) then
                poe2_api.click_keyboard("esc")
                return bret.RUNNING
            end
            poe2_api.time_p("Not_In_New_Area_Skill",api_GetTickCount64() - current_time ) 
            return bret.SUCCESS
        end
    },

    Is_Fast_Skill = {
        run = function(self, env)
            local function check_skill_in_pos()
                local skill_name = env.skill_name
                
                -- 检查是否是武器技能
                if string.find(skill_name, "WeaponGranted") or poe2_api.table_contains(skill_name, {"FireboltPlayer", "MeleeBowPlayer", "MeleeCrossbowPlayer", "MeleeSpearOffHandPlayer", "Melee1HMacePlayer", "MeleeQuarterstaffPlayer"}) then
                    return true
                end
                
                -- 检查技能是否在技能栏上
                local shortcut_skill_info = env.skill_slots or {}
                for _, k in ipairs(shortcut_skill_info) do
                    if skill_name == k.name_utf8 then
                        poe2_api.dbgp("[check_skill_in_pos] 技能在技能栏上: " .. tostring(skill_name))
                        return true
                    end
                end
                
                poe2_api.dbgp("[check_skill_in_pos] 技能不在技能栏上: " .. tostring(skill_name))
                return false
            end
            
            local function skill_location()
                local skill_name = env.skill_name
                local skill_pos = env.skill_pos
                
                poe2_api.dbgp("[skill_location] 检查技能位置: " .. tostring(skill_name) .. " 位置: " .. tostring(skill_pos))
                
                local point = my_game_info.skill_pos[skill_pos]
                local selectable_skills = env.selectable_skills or {}
                
                -- 检查技能是否在可选列表中
                local skill_names = {}
                for _, skill in ipairs(selectable_skills) do
                    skill_names[skill.text_utf8] = true
                end
                
                if not skill_names[skill_name] then
                    poe2_api.dbgp("[skill_location] 技能不在可选列表中: " .. tostring(skill_name))
                    return false
                end
                
                -- 检查技能位置
                for _, skill_control in ipairs(selectable_skills) do
                    if skill_name == skill_control.text_utf8 then
                        -- 计算中间位置
                        local center_x = (skill_control.left + skill_control.right) / 2
                        local center_y = (skill_control.top + skill_control.bottom) / 2
                        
                        -- 检查位置是否在指定范围内
                        if (point[1] - 5 < center_x and center_x < point[1] + 5) and 
                           (point[2] - 5 < center_y and center_y < point[2] + 5) then
                            poe2_api.dbgp("[skill_location] 技能位置正确: " .. tostring(skill_name))
                            return true
                        else
                            poe2_api.dbgp("[skill_location] 技能位置不正确: " .. tostring(skill_name) .. " 坐标: " .. center_x .. "," .. center_y)
                        end
                    end
                end
                
                poe2_api.dbgp("[skill_location] 技能位置检查失败: " .. tostring(skill_name))
                return false
            end
            
            -- 主逻辑
            if not check_skill_in_pos() then
                return bret.FAIL
            end
            
            if not skill_location() then
                return bret.SUCCESS
            end
            
            return bret.RUNNING
        end
    },

    Adjust_Skills = {
        run = function(self, env)
            local user_config = env.user_config 
            local function set_pos()
                local selectable_skills = env.selectable_skills or {}
                local skill_name = env.skill_name
                
                poe2_api.dbgp("[set_pos] 开始设置技能位置，技能名称: " .. tostring(skill_name))
                poe2_api.dbgp("[set_pos] 可选技能数量: " .. tostring(#selectable_skills))
                
                for _, k in ipairs(selectable_skills) do
                    poe2_api.dbgp("[set_pos] 检查技能: " .. tostring(k.text_utf8) .. " 坐标: (" .. k.left .. "," .. k.top .. ")")
                    
                    if skill_name == "" then
                        poe2_api.dbgp("[set_pos] 处理空技能名称情况")
                        if 1104 <= k.left and k.left <= 1597 and 562 <= k.top and k.top <= 841 and skill_name == k.text_utf8 then
                            local center_x = (k.left + k.right) / 2
                            local center_y = (k.top + k.bottom) / 2
                            poe2_api.dbgp("[set_pos] 找到空技能位置，点击坐标: (" .. math.floor(center_x) .. "," .. math.floor(center_y) .. ")")
                            api_ClickScreen(math.floor(center_x), math.floor(center_y), 0)
                            api_Sleep(500)
                            api_ClickScreen(math.floor(center_x), math.floor(center_y), 1)
                            api_Sleep(2000)
                            return true
                        end
                        
                    elseif skill_name == "MeleeUnarmedPlayer" or string.find(skill_name or "", "WeaponGranted") or poe2_api.table_contains(skill_name, {"FireboltPlayer", "MeleeBowPlayer", "MeleeCrossbowPlayer", "MeleeSpearOffHandPlayer", "Melee1HMacePlayer", "MeleeQuarterstaffPlayer"}) then
                        poe2_api.dbgp("[set_pos] 处理武器技能: " .. tostring(skill_name))
                        if skill_name == "MeleeUnarmedPlayer" then
                            poe2_api.dbgp("[set_pos] 处理徒手技能")
                            if 1104 <= k.left and k.left <= 1597 and 562 <= k.top and k.top <= 841 and skill_name == k.text_utf8 then
                                local center_x = (k.left + k.right) / 2
                                local center_y = (k.top + k.bottom) / 2
                                poe2_api.dbgp("[set_pos] 找到徒手技能位置，点击坐标: (" .. math.floor(center_x) .. "," .. math.floor(center_y) .. ")")
                                api_ClickScreen(math.floor(center_x), math.floor(center_y), 0)
                                api_Sleep(500)
                                api_ClickScreen(math.floor(center_x), math.floor(center_y), 1)
                                api_Sleep(2000)
                                return true
                            end
                        else
                            poe2_api.dbgp("[set_pos] 处理其他武器技能")
                            if 1104 <= k.left and k.left <= 1597 and 562 <= k.top and k.top <= 841 and skill_name == k.text_utf8 then
                                local center_x = (k.left + k.right) / 2
                                local center_y = (k.top + k.bottom) / 2
                                poe2_api.dbgp("[set_pos] 找到武器技能位置，点击坐标: (" .. math.floor(center_x) .. "," .. math.floor(center_y) .. ")")
                                api_ClickScreen(math.floor(center_x), math.floor(center_y), 0)
                                api_Sleep(500)
                                api_ClickScreen(math.floor(center_x), math.floor(center_y), 1)
                                api_Sleep(2000)
                                return true
                            end
                        end
                        
                    else
                        poe2_api.dbgp("[set_pos] 处理普通技能")
                        -- 检查位置是否在指定范围内 FallingThunderPlayer MeleeQuarterstaffPlayer
                        local skill = poe2_api.get_BD_info(user_config["組隊設置"]['職業'], "技能", env.skill_name, "skill_name")
                        poe2_api.dbgp("[set_pos] 从配置获取的技能名称: " .. tostring(skill))
                        
                        if skill and 1104 <= k.left and k.left <= 1597 and 562 <= k.top and k.top <= 841 and string.find(k.text_utf8 or "", skill) then
                            local center_x = (k.left + k.right) / 2
                            local center_y = (k.top + k.bottom) / 2
                            poe2_api.dbgp("[set_pos] 找到普通技能位置，点击坐标: (" .. math.floor(center_x) .. "," .. math.floor(center_y) .. ")")
                            api_ClickScreen(math.floor(center_x), math.floor(center_y), 0)
                            api_Sleep(500)
                            api_ClickScreen(math.floor(center_x), math.floor(center_y), 1)
                            api_Sleep(2000)
                            return true
                        end
                    end
                end
                
                poe2_api.dbgp("[set_pos] 未找到匹配的技能位置")
                return false
            end
            
            poe2_api.dbgp("开始设置技能位置流程")
            if not set_pos() then
                poe2_api.dbgp("[set_pos] 使用默认技能位置: " .. tostring(env.skill_pos))
                local point = my_game_info.skill_pos[env.skill_pos]
                if point then
                    poe2_api.dbgp("[set_pos] 点击默认位置坐标: (" .. math.floor(point[1]) .. "," .. math.floor(point[2]) .. ")")
                    api_ClickScreen(math.floor(point[1]), math.floor(point[2]), 0)
                    api_Sleep(100)
                    api_ClickScreen(math.floor(point[1]), math.floor(point[2]), 1)
                    api_Sleep(2000)
                else
                    poe2_api.dbgp("[set_pos] 错误: 未找到技能位置 " .. tostring(env.skill_pos) .. " 的坐标点")
                end
            else
                poe2_api.dbgp("[set_pos] 成功设置技能位置")
            end
            return bret.RUNNING
        end
    },

    Is_Skill_In_Skill_List = {
        run = function(self, env)
            local skill_name = env.skill_name
            poe2_api.dbgp("[技能检查] 开始检查技能，技能名称: " .. tostring(skill_name))
            local function is_skills(name)
                poe2_api.dbgp("[is_skills] 检查技能是否存在: " .. tostring(name))
                for k, v in ipairs(env.allskill_info) do
                    if v.name_utf8 == name then
                        poe2_api.dbgp("[is_skills] 技能存在: " .. tostring(name))
                        return true
                    end
                end
                poe2_api.dbgp("[is_skills] 技能不存在: " .. tostring(name))
                return false
            end
            -- 检查空技能名、徒手技能或武器技能
            if skill_name == "" or skill_name == "MeleeUnarmedPlayer" or string.find(skill_name or "", "WeaponGranted") then
                poe2_api.dbgp("[技能检查] 满足条件（空技能/徒手技能/武器技能），返回成功")
                return bret.SUCCESS
            end

            poe2_api.dbgp("[技能检查] 不是空技能/徒手技能/武器技能，继续检查配置")

            -- 检查技能是否存在
            local skill_config_name = poe2_api.get_BD_info(env.user_config["組隊設置"]['職業'], "技能", skill_name, "skill_name")
            poe2_api.dbgp("[技能检查] 从配置获取的技能名称: " .. tostring(skill_config_name))

            local skill_exists = false

            if skill_config_name then
                poe2_api.dbgp("[技能检查] 调用 is_skills 函数检查技能是否存在")
                -- 调用 is_skills 函数检查技能是否存在
                skill_exists = is_skills(skill_config_name)
                poe2_api.dbgp("[技能检查] is_skills 返回结果: " .. tostring(skill_exists))
            else
                poe2_api.dbgp("[技能检查] 未从配置中找到技能名称")
            end

            if skill_exists then
                poe2_api.dbgp("[技能检查] 技能存在，返回成功")
                return bret.SUCCESS
            end

            poe2_api.dbgp("[技能检查] 技能不存在，返回失败")
            return bret.FAIL
        end
    },

    Is_Bag_Have_Skill_Stone = {
        run = function(self, env)
            local skill_name = env.skill_name
            local bag_info = env.bag_info

            poe2_api.dbgp("[背包检查] 开始检查背包物品，技能名称: " .. tostring(skill_name))
            poe2_api.dbgp("[背包检查] 背包信息: " .. tostring(bag_info and #bag_info or 0) .. " 个物品")

            -- 检查背包中是否有指定物品
            local has_item = poe2_api.check_item_in_inventory(skill_name, bag_info)

            poe2_api.dbgp("[背包检查] backpack_items 返回结果: " .. tostring(has_item))

            if has_item then
                poe2_api.dbgp("[背包检查] 背包中存在物品，返回成功")
                return bret.SUCCESS
            end

            poe2_api.dbgp("[背包检查] 背包中不存在物品，返回失败")
            return bret.FAIL
        end
    },

    Put_Skill_In_Skill_List = {
        run = function(self, env) 
            
            poe2_api.dbgp("开始检查背包和技能文本")

            -- 检查背包文本
            if not poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                poe2_api.dbgp("未找到背包文本，按下I键打开背包")
                poe2_api.click_keyboard("i")
                return bret.RUNNING
            else
                poe2_api.dbgp("已找到背包文本")
            end

            -- 检查技能文本
            if not poe2_api.find_text({UI_info = env.UI_info, text = "技能", min_x = 0}) then
                poe2_api.dbgp("未找到技能文本，开始检查背包物品")
                local items = env.bag_info
                if items then
                    poe2_api.dbgp("背包物品数量: " .. tostring(#items))
                    for _, item in ipairs(items) do
                        poe2_api.dbgp("检查物品: " .. tostring(item.name_utf8) .. " (类型: " .. tostring(item.baseType_utf8) .. ")")
                        if item.baseType_utf8 == env.skill_name then
                            poe2_api.dbgp("找到匹配的技能物品: " .. tostring(item.name_utf8))
                            -- 计算中心坐标
                            local start_cell = {item.start_x, item.start_y}
                            local end_cell = {item.end_x, item.end_y}
                            local center_position = poe2_api.get_center_position(start_cell, end_cell)
                            poe2_api.dbgp("物品坐标: 起始(" .. item.start_x .. "," .. item.start_y .. ") 结束(" .. item.end_x .. "," .. item.end_y .. ")")
                            poe2_api.dbgp("中心坐标: (" .. math.floor(center_position[1]) .. "," .. math.floor(center_position[2]) .. ")")

                            api_ClickScreen(math.floor(center_position[1]), math.floor(center_position[2]), 0)
                            api_Sleep(500)
                            api_ClickScreen(math.floor(center_position[1]), math.floor(center_position[2]), 2)
                            poe2_api.dbgp("已右键点击物品")
                        end
                    end
                else
                    poe2_api.dbgp("背包信息为空")
                end
                return bret.RUNNING
            else
                poe2_api.dbgp("已找到技能文本")
            end

            poe2_api.dbgp("开始处理背包中的技能物品")
            local items = env.bag_info
            if items then
                poe2_api.dbgp("背包物品数量: " .. tostring(#items))
                for _, item in ipairs(items) do
                    poe2_api.dbgp("检查物品: " .. tostring(item.name_utf8) .. " (类型: " .. tostring(item.baseType_utf8) .. ")")
                    if item.baseType_utf8 == env.skill_name then
                        poe2_api.dbgp("找到匹配的技能物品: " .. tostring(item.name_utf8))
                        -- 计算中心坐标
                        local start_cell = {item.start_x, item.start_y}
                        local end_cell = {item.end_x, item.end_y}
                        local center_position = poe2_api.get_center_position(start_cell, end_cell)
                        poe2_api.dbgp("物品坐标: 起始(" .. item.start_x .. "," .. item.start_y .. ") 结束(" .. item.end_x .. "," .. item.end_y .. ")")
                        poe2_api.dbgp("中心坐标: (" .. math.floor(center_position[1]) .. "," .. math.floor(center_position[2]) .. ")")

                        api_ClickScreen(math.floor(center_position[1]), math.floor(center_position[2]), 0)
                        api_Sleep(500)
                        poe2_api.ctrl_left_click(center_position[1], center_position[2])
                        poe2_api.dbgp("已Ctrl+左键点击物品")
                        poe2_api.sleep(1000)
                    end
                end
            else
                poe2_api.dbgp("背包信息为空")
            end

            poe2_api.dbgp("处理完成，返回运行状态")
            return bret.RUNNING
        end
    },
    -- 是否需要攻击
    Check_Is_Need_Attack = {
        run = function(self, env)
            poe2_api.dbgp("Check_Is_Need_Attack是否需要攻击模块开始执行...")
            poe2_api.print_log("Check_Is_Need_Attack是否需要攻击模块开始执行...")
            local player_info = env.player_info
            local UI_info = env.UI_info
            local current_time = api_GetTickCount64()
            local range_info = env.range_info
            local boss_name = env.boss_name
            local stuck_monsters = env.stuck_monsters
            local not_attack_mos = env.not_attack_mos
            local team_info = env.team_info
            local user_config = env.user_config
            local attack_dis_map = 100
            local team_member_2 = poe2_api.get_team_info(team_info, user_config, player_info, 2)
            if (poe2_api.is_have_boss_distance(range_info, player_info,boss_name, 180) 
                or poe2_api.is_have_mos({range_info = range_info, player_info = player_info, dis = attack_dis_map, stuck_monsters = stuck_monsters,not_attack_mos = not_attack_mos}))
                and (team_member_2 == "大號名" or player_info.current_map_name_utf8 == "G1_1") then
                poe2_api.dbgp("需要攻击")
                poe2_api.time_p("[Check_Is_Need_Attack]",(api_GetTickCount64() - current_time))

                return bret.FAIL        
            else
                poe2_api.dbgp("不需要攻击")
                poe2_api.time_p("[Check_Is_Need_Attack]",(api_GetTickCount64() - current_time))

                return bret.SUCCESS        
            end
        end
    },

    -- 释放技能动作
    ReleaseSkillAction = {
        run = function(self, env)
            poe2_api.dbgp("ReleaseSkillAction释放技能动作模块开始执行...")
            poe2_api.print_log("ReleaseSkillAction释放技能动作模块开始执行...")
            local current_time_ms = api_GetTickCount64()
            --- 辅助函数
            -- 根据稀有度获取可释放的技能
            local available_skills = {}
            local function _get_available_skills(monster_rarity)
                -- 根据怪物稀有度获取可用技能
                local current_time = api_GetTickCount64()
                
                for _, skill in ipairs(self.skills) do
                    
                    -- 检查冷却
                    poe2_api.dbgp("current_time --> ",current_time)
                    poe2_api.dbgp("skill.name --> ",skill.name)
                    poe2_api.dbgp("self.skill_cooldowns[skill.name] --> ",self.skill_cooldowns[skill.name])
                    if current_time < (self.skill_cooldowns[skill.name] or 0) then
                        goto continue
                    end
                    
                    -- 检查技能是否适合攻击该稀有度怪物
                    if monster_rarity == 3 then  -- Boss
                        if not skill.target_targets["Boss"] then
                            goto continue
                        end
                    elseif monster_rarity == 2 then  -- 黄怪
                        if not skill.target_targets["黃怪"] then
                            goto continue
                        end
                    elseif monster_rarity == 1 then  -- 蓝怪
                        if not skill.target_targets["藍怪"] then
                            goto continue
                        end
                    elseif monster_rarity == 0 then  -- 白怪
                        if not skill.target_targets["白怪"] then
                            goto continue
                        end
                    end
                    
                    table.insert(available_skills, skill)
                    
                    ::continue::
                end
                return available_skills
            end

            -- 取可释放的单个技能
            local function _select_skill(available_skills)
                local current_time = api_GetTickCount64()
                
                -- 参数检查
                if type(available_skills) ~= "table" or #available_skills == 0 then
                    error("Invalid skills list: " .. tostring(available_skills))
                end
                
                -- 筛选有效技能（有数字间隔的技能）
                local valid_skills = {}
                for _, skill in ipairs(available_skills) do
                    if type(skill.interval) == "number" then
                        table.insert(valid_skills, skill)
                    end
                end
                
                if #valid_skills == 0 then
                    error("No valid skills with numeric intervals")
                end
                
                -- 排序技能（先按interval降序，再按priority升序）
                table.sort(valid_skills, function(a, b)
                    if a.interval ~= b.interval then
                        return a.interval > b.interval  -- 降序
                    else
                        return (a.priority or 0) < (b.priority or 0)  -- 升序
                    end
                end)
                
                -- 获取最大间隔值
                local max_interval = valid_skills[1].interval
                local candidates = {}
                for _, skill in ipairs(valid_skills) do
                    if skill.interval == max_interval then
                        table.insert(candidates, skill)
                    else
                        break  -- 因为已排序，可以提前退出
                    end
                end
                
                -- 随机选择一个候选技能
                if #candidates > 0 then
                    return candidates[math.random(#candidates)]
                else
                    return nil
                end
            end

            -- 获取技能设置
            local function parse_skill_config()
                local skill_setting = env.user_config["技能設置"]
                local new_skills = {}
                local preserved_cooldowns = {}
                local current_time = api_GetTickCount64()
                
                -- 确保skill_cooldowns表存在
                if not self.skill_cooldowns then
                    self.skill_cooldowns = {}
                end
                
                -- 遍历技能设置
                for key, skill_data in pairs(skill_setting) do
                    -- 只处理启用技能
                    if skill_data["启用"] then
                        -- 处理攻击技能
                        if skill_data["技能屬性"] == "攻击技能"then
                            local skill = {
                                name = key,
                                key = key,
                                interval = (tonumber(skill_data["釋放間隔"]) or 0) / 1000,
                                priority = 1,  -- 默认值
                                weight = 1.0,  -- 默认值
                                attack = skill_data["釋放對象"],
                                attack_range = tonumber(skill_data["攻擊距離"]) or 100,
                                target_targets = {
                                    ["白怪"] = skill_data["白怪"] or false,
                                    ["藍怪"] = skill_data["藍怪"] or false,
                                    ["黃怪"] = skill_data["黃怪"] or false,
                                    ["Boss"] = skill_data["Boss"] or false
                                }
                            }
                            
                            -- 保留原有冷却时间
                            if self.skill_cooldowns[skill.name] then
                                preserved_cooldowns[skill.name] = self.skill_cooldowns[skill.name]
                            else
                                preserved_cooldowns[skill.name] = 0
                            end
                            
                            table.insert(new_skills, skill)
                        end
                    end
                end
                
                self.skills = new_skills
                poe2_api.printTable(self.skills)
                self.skill_cooldowns = preserved_cooldowns
                
                -- 提取技能权重
                self._skill_weights = {}
                for _, skill in ipairs(self.skills) do
                    table.insert(self._skill_weights, skill.weight)
                end
                
            end
            
            -- 计算释放距离
            local function _calculate_intermediate_position(start_x, start_y, end_x, end_y, ratio)
                local current_time = api_GetTickCount64()
                ratio = ratio or 0.8  -- 默认比例0.8
                
                -- 计算方向向量
                local dx = end_x - start_x
                local dy = end_y - start_y
                
                -- 添加随机扰动（避免完全直线移动）
                if ratio > 0.5 then  -- 靠近目标时增加随机性
                    dx = dx * (0.9 + math.random() * 0.2)  -- 0.9-1.1
                    dy = dy * (0.9 + math.random() * 0.2)
                end
                
                -- 计算中间点
                local mid_x = start_x + dx * ratio
                local mid_y = start_y + dy * ratio
                
                return mid_x, mid_y
            end

            -- 选择释放对象
            local function _calculate_movement(skill, monster, player_info)
                local current_time = api_GetTickCount64()
                local target_type = skill.target or "敵對"
                local move_x, move_y, move_z = nil, nil, nil
                
                -- 根据技能目标类型计算基础位置
                if target_type == "敵對" then
                    -- 对敌人释放：向怪物方向移动，但保持一定距离
                    local angle = math.random() * 2 * math.pi  -- 随机角度
                    local distance = 2 + math.random() * 3    -- 随机距离2-5
                    move_x = monster.grid_x
                    move_y = monster.grid_y
                    move_z = monster.world_z
                    
                elseif target_type == "自身" then
                    -- 对自身释放：小范围随机移动
                    move_x = player_info.grid_x + (math.random() * 4 - 2)  -- -2到2
                    move_y = player_info.grid_y + (math.random() * 4 - 2)
                    move_z =poe2_api.toInt(player_info.world_z)
                    
                elseif target_type == "敵對尸體" then
                    -- 对尸体释放：查找最近的尸体
                    local death_em = poe2_api.enemy_death_target_object({env.range_info,env.player_info})
                    if death_em then
                        move_x = death_em.grid_x + (math.random() * 6 - 3)  -- -3到3
                        move_y = death_em.grid_y + (math.random() * 6 - 3)
                    end
                    
                elseif target_type == "友方召喚物" then
                    -- 对友方召唤物释放
                    local fr_ob = poe2_api.friendly_target_object({env.range_info,env.player_info})
                    if fr_ob then
                        move_x, move_y = api_FindNearestReachablePoint(
                            fr_ob.grid_x,
                            fr_ob.grid_y,
                            20,
                            0
                        )
                    end
                end
                
                -- 默认位置（如果前面未计算）
                if move_x == nil or move_y == nil then
                    move_x = monster.grid_x
                    move_y = monster.grid_y
                    move_z = monster.world_z
                end
                
                -- 特殊技能处理（如传送类技能）
                if skill.key == '`' then
                    -- 计算玩家到怪物的中间位置
                    move_x, move_y = _calculate_intermediate_position(
                        player_info.grid_x,
                        player_info.grid_y,
                        monster.grid_x,
                        monster.grid_y,
                        0.70  -- ratio
                    )
                end
                
                -- poe2_api.dbgp(777777777777777777)
                -- 
                return move_x, move_y, move_z
            end

            -- 释放技能
            local function _execute_skill(skill, monster, player_info)
                poe2_api.dbgp("释放技能=-=-=-->>>>")
                poe2_api.printTable(skill)
                local current_time = api_GetTickCount64()
                
                -- 计算移动位置
                local move_x, move_y, move_z =  _calculate_movement(skill, monster, player_info)

                if self.attack_last_time == nil then
                    self.attack_last_time = api_GetTickCount64()
                end

                api_ClickMove(math.floor(move_x), math.floor(move_y), 0)
                
                -- 设置冷却时间
                local skill_start = api_GetTickCount64()
                local base_cd = skill.interval
                poe2_api.dbgp("base_cd =-=-=-->>>>", base_cd)
                local actual_cd = (math.max(base_cd * (1 + math.random() * 0.2), 0.1)) * 1000
                self.skill_cooldowns[skill.name] = skill_start + actual_cd
                
                -- 释放技能
                poe2_api.click_keyboard(skill.key)
                poe2_api.dbgp("释放技能=-=-=-->>>>", skill.key)
            end
            
            -- 特殊boss处理
            local function _handle_special_boss_movement(boss, player_info)
                local current_time = api_GetTickCount64()
                
                -- 使用pcall进行错误处理（替代try-catch）
                -- 计算安全距离（30单位）
                local safe_distance = 30
                local angle = math.atan2(
                    boss.grid_y - player_info.grid_y,
                    boss.grid_x - player_info.grid_x
                )
                
                -- 计算目标位置（保持安全距离）
                local target_x = boss.grid_x - safe_distance * math.cos(angle)
                local target_y = boss.grid_y - safe_distance * math.sin(angle)
                
                -- 寻找可达点
                local reachable_x, reachable_y = api_FindNearestReachablePoint(
                    target_x, 
                    target_y,
                    safe_distance * 0.7,  -- radius
                    0  -- z
                )
                
                -- 设置移动目标
                env.attack_move = true
                env.end_point = {reachable_x, reachable_y}
            
            end

            

            --- 主要动作
            poe2_api.dbgp("释放技能...")
            nearest_distance_sq = math.huge

            -- 加载技能设置
            if not self.is_have_skills then
                poe2_api.dbgp("加载技能设置...")
                self.stuck_monsters = {}
                
                parse_skill_config()
                self.is_have_skills = true
                return bret.RUNNING
            end

            local player_info = env.player_info
            if not self.skills or #self.skills == 0 then
                poe2_api.dbgp("主动攻击无技能")
                return bret.FAIL
            end

            if (player_info.mana < (player_info.max_mana * 0.15)) then
                poe2_api.dbgp("蓝量小于15%")
                return bret.FAIL
            end

            -- 是否激活
            local is_active = true

            local valid_monsters = nil
            local boss_name = env.boss_name
            local current_map_info = env.current_map_info
            
            local range_info = env.range_info
            -- 怪物筛选和处理逻辑
            for _, monster in ipairs(env.range_info) do

                -- 快速失败条件检查（按计算成本从低到高排序）
                if not monster.is_selectable or          -- 可选性检查
                monster.is_friendly or                -- 友方检查
                monster.life <= 0 or                  -- 生命值检查
                monster.name_utf8 == "" or              -- 名称检查
                poe2_api.table_contains(my_game_info.not_attact_mons_CN_name, monster.name_utf8) or
                poe2_api.table_contains(my_game_info.not_attact_mons_path_name , monster.path_name_utf8) then  -- 路径名检查
                    goto continue
                end
                -- 检查是否在中心点半径范围内
                if  #env.center_point > 0 and env.center_radius > 0 then
                    local distance_to_center = math.sqrt(
                        (monster.grid_x - env.center_point[1])^2 + 
                        (monster.grid_y - env.center_point[2])^2
                    )
                    if distance_to_center > env.center_radius then
                        goto continue  -- 超出范围则跳过
                    end
                else
                    if self.stuck_monsters and poe2_api.table_contains(self.stuck_monsters, monster.id) then
                        goto continue
                    end
                end
                
                -- 是否激活  
                if (not monster.isActive) and is_active then
                    goto continue
                end
                
                -- 稀有度检查
                if env.not_attack_mos and env.not_attack_mos[monster.rarity] then
                    goto continue
                end

                -- 计算距离平方
                local distance_sq = poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info)
                -- poe2_api.dbgp("当前怪物：",monster.name_utf8,"，距离：",distance_sq,"米") q

                if (boss_name and poe2_api.table_contains(monster.name_utf8, boss_name)) or monster.rarity == 3 then
                    if distance_sq < nearest_distance_sq then
                        nearest_distance_sq = distance_sq
                        valid_monsters = monster
                    end
                else
                    if monster.hasLineOfSight and distance_sq < nearest_distance_sq then
                        nearest_distance_sq = distance_sq
                        valid_monsters = monster

                    end
                    
                end
                ::continue::
            end

            if valid_monsters then
                -- 获取当前目标ID
                local current_target_id = valid_monsters and valid_monsters.id or nil
                poe2_api.dbgp("a valid_monsters ------------------------------------------------------->")
                poe2_api.dbgp("a valid_monsters name -->" ,valid_monsters.name_utf8)
                poe2_api.dbgp("a valid_monsters path_name -->" ,valid_monsters.path_name_utf8)
                poe2_api.dbgp("a valid_monsters: ",tostring(string.format("%x",valid_monsters.obj)))
                poe2_api.dbgp("a life -->" ,valid_monsters.life)
                poe2_api.dbgp("a grid_x -->" ,valid_monsters.grid_x)
                poe2_api.dbgp("a grid_y -->" ,valid_monsters.grid_y)


                if not (#env.center_point > 0 and env.center_radius > 0) then
                    -- 第二次遍历进行卡住检测和其他处理
                    for _, monster in ipairs(env.range_info) do
                        local current_time = api_GetTickCount64()
                        
                        -- 快速失败条件检查
                        if not monster.is_selectable or 
                        poe2_api.table_contains(self.stuck_monsters,monster.id) or 
                        monster.is_friendly then
                            goto continue_second
                        end

                        if monster.name_utf8 == "" then
                            goto continue_second
                        end

                        -- 黑名单检查
                        if poe2_api.table_contains(my_game_info.not_attact_mons_CN_name, monster.name_utf8) or
                            poe2_api.table_contains(my_game_info.not_attact_mons_path_name, monster.path_name_utf8) or
                        string.find(monster.name_utf8 or "", "神殿") then
                            goto continue_second
                        end
                        
                        --- 基础状态检查       
                        if (not monster.isActive) and is_active then
                            goto continue_second
                        end

                        if not (monster.life > 0) then
                            goto continue_second
                        end
                        
                        -- 死亡怪物处理
                        if monster.life <= 0 then
                            self.monster_tracker[monster.id] = nil
                            self.stuck_monsters = {}
                            goto continue_second
                        end
                        
                        -- 卡住检测（仅对当前目标）
                        if monster.id == current_target_id then
                            -- 目标切换时重置所有数据
                            if current_target_id ~= self.last_target_id then
                                self.current_target_data = {
                                    first_seen = current_time,
                                    last_seen = current_time,
                                    initial_life = monster.life,
                                    grid_x = monster.grid_x,
                                    grid_y = monster.grid_y,
                                    rarity = monster.rarity
                                }
                                self.last_target_id = current_target_id
                            else
                                -- 仅更新时间戳
                                self.current_target_data.last_seen = current_time
                            end
                            
                            -- 计算存活时间和生命比例
                            local time_elapsed = current_time - self.current_target_data.first_seen
                            local life_ratio = monster.life / math.max(self.current_target_data.initial_life, 1)
                            
                            -- 获取稀有度对应的时间阈值
                            local rarity_index = math.min(monster.rarity, 3) + 1  -- Lua数组从1开始
                            local time_thresholds = {45, 60, 120, 180}
                            local time_threshold = (time_thresholds[rarity_index]) * 1000

                            -- 综合判断条件
                            if time_elapsed > time_threshold and life_ratio > 0.95 then
                                table.insert(self.stuck_monsters, monster.id)
                                poe2_api.dbgp(string.format("%s 卡住（%.1f秒未击杀）", monster.name_utf8 or "未知怪物", time_elapsed / 1000))
                                valid_monsters = nil
                                goto continue_second
                            end
                        end
                        ::continue_second::
                    end
                end
            end

            -- 更新黑板数据
            if self.stuck_monsters then
                env.stuck_monsters = self.stuck_monsters
                -- poe2_api.printTable(self.stuck_monsters)
            end

            env.valid_monsters = valid_monsters

            if valid_monsters then
                -- 计算距离
                local distance = math.sqrt((valid_monsters.grid_x - player_info.grid_x)^2 + 
                                        (valid_monsters.grid_y - player_info.grid_y)^2)

                poe2_api.dbgp("++++++++++++++++++++++++++++++++++")
                poe2_api.dbgp(string.format("攻击 %s(稀有度:%d) | 距离: %.1f",valid_monsters.name_utf8 or "未知怪物", valid_monsters.rarity or 0, distance))
                poe2_api.dbgp("is_friendly: ", tostring(valid_monsters.is_friendly))
                poe2_api.dbgp("hasLineOfSight: ", tostring(valid_monsters.hasLineOfSight))
                poe2_api.dbgp("isActive: ", tostring(valid_monsters.isActive))
                -- poe2_api.dbgp("isActive: ", tostring(valid_monsters.isActive))
                -- poe2_api.dbgp("rarity: ", tostring(valid_monsters.rarity))
                -- poe2_api.dbgp("path_name_utf8: ", tostring(valid_monsters.path_name_utf8))
                poe2_api.dbgp("obj: ", tostring(string.format("%x",valid_monsters.obj)))
                poe2_api.dbgp("grid_x: ", tostring(string.format("%x",valid_monsters.grid_x)))
                poe2_api.dbgp("grid_y: ", tostring(string.format("%x",valid_monsters.grid_y)))
                -- api_ClickMove(valid_monsters.grid_x, valid_monsters.grid_y, player_info.world_z, 0)
                poe2_api.dbgp("magicProperties: ", tostring(valid_monsters.magicProperties))
                poe2_api.printTable(valid_monsters.magicProperties)
                -- poe2_api.dbgp("stateMachineList: ", tostring(valid_monsters.stateMachineList))
                poe2_api.dbgp("血量：", valid_monsters.life )
                -- poe2_api.print_log("type --> ", type(valid_monsters))
                poe2_api.dbgp("++++++++++++++++++++++++++++++++++")
                if poe2_api.table_contains(valid_monsters.name_utf8, {'鋼鐵伯爵','巨像．札爾瑪拉斯','崛起之王．賈嫚拉'}) and not valid_monsters.isActive then
                    return bret.SUCCESS
                end
                if string.find(valid_monsters.name_utf8, "多里亞尼") and valid_monsters.stateMachineList and valid_monsters.stateMachineList["boss_life_bar"] == 0 then
                    return bret.SUCCESS
                end
                if valid_monsters.name_utf8 == '異界．干擾女王．卡巴拉' then
                    if distance > 50 then
                        env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                        env.attack_move = true
                        return bret.FAIL
                    end
                end
                if valid_monsters.name_utf8 == "撕裂者" then
                    for _,v in ipairs(current_map_info) do
                        if v.name_utf8 == "RathbreakerActive" and math.sqrt((v.grid_x - player_info.grid_x) * 2 + (v.grid_y - player_info.grid_y) * 2)>25 then
                            env.attack_move = true
                            env.end_point = {v.grid_x, v.grid_y}
                            return bret.FAIL
                        end
                    end
                end
                if valid_monsters.name_utf8 == "憎惡者．賈嫚拉" or valid_monsters.name_utf8 == "國王的侍從" then
                    for _,k in ipairs(env.range_info) do
                        if k.name_utf8 == "絲克瑪．阿薩拉" and k.stateMachineList and k.stateMachineList["sandstorm_defence"] == 1 then
                            if poe2_api.point_distance(k.grid_x,k.grid_y,player_info) > 25 then
                                env.attack_move = true
                                env.end_point = {k.grid_x, k.grid_y}
                                return bret.FAIL
                            elseif poe2_api.point_distance(k.grid_x,k.grid_y,player_info) > 20 then
                                return bret.RUNNING
                            end
                        end
                    end
                end
                if valid_monsters.name_utf8 == "白之亞瑪" then
                    for _,k in ipairs(env.range_info) do
                        if string.find(k.animated_name_utf8,"Metadata/Characters/Dex/DexFourB") and k.stateMachineList and k.stateMachineList["chosen_one"] == 1 then
                            if poe2_api.point_distance(k.grid_x,k.grid_y,player_info) > 25 then
                                env.attack_move = true
                                env.end_point = {k.grid_x, k.grid_y}
                                return bret.FAIL
                            elseif poe2_api.point_distance(k.grid_x,k.grid_y,player_info) > 20 then
                                return bret.RUNNING
                            end
                        end
                    end
                end
                
                -- 特殊Boss处理
                local special_bosses = {'巨蛇女王．瑪娜莎', '被遺忘的囚犯．帕拉薩'}
                if poe2_api.table_contains(valid_monsters.name_utf8, special_bosses) and distance > 50 and not valid_monsters.isActive then
                    poe2_api.dbgp("special_bosses,或者未激活")
                    _handle_special_boss_movement(valid_monsters, player_info)
                    poe2_api.dbgp("移动到目标附近444")
                    return bret.FAIL
                end
                -- 构建可用技能池

                local available_skills = _get_available_skills(valid_monsters.rarity)

                local min_attack_range = 0
                if available_skills and #available_skills > 0 then
                    for _, skill in ipairs(available_skills) do
                        if skill.attack_range > min_attack_range then
                            min_attack_range = skill.attack_range
                        end
                    end
                end

                env.min_attack_range = min_attack_range
                
                if available_skills and #available_skills > 0 then
                    local selected_skill = _select_skill(available_skills)
                    if distance > 25 then
                        poe2_api.printTable(valid_monsters.magicProperties)
                        -- 检查特殊词缀
                        for _, prop in ipairs(my_game_info.first_magicProperties or {}) do
                            if poe2_api.table_contains(valid_monsters.magicProperties, prop) then
                                env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                                poe2_api.dbgp("移动到目标附近111")
                                return bret.FAIL
                            end
                            ::continue_prop::
                        end
                    end

                    poe2_api.dbgp("selected_skill.attack_range", selected_skill.attack_range)
                    poe2_api.dbgp("min_attack_range", min_attack_range)
                    poe2_api.dbgp("distance", distance)

                    if valid_monsters.name_utf8 ~= "骨之暴君．札瓦里" then
                        
                        if distance > selected_skill.attack_range and distance > min_attack_range or not valid_monsters.isActive then
                            -- poe2_api.dbgp("移动到目标附近")
                            -- -- 拾取不移动
                            -- if need_item and not env.center_point and not center_radius then
                            --     return bret.SUCCESS
                            -- end
                            
                            if env.afoot_altar then
                                local distance = poe2_api.point_distance(env.afoot_altar.grid_x, env.afoot_altar.grid_y, env.player_info)
                                if distance < 105 then
                                    env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                                    poe2_api.dbgp("移动到目标附近222")
                                    return bret.FAIL
                                end
                            end
                            
                            -- env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                            -- return bret.FAIL
                            return bret.SUCCESS
                        end
                    else
                        if distance > 80 then
                            env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                            poe2_api.dbgp("移动到目标附近333")
                            return bret.FAIL
                        end
                    end
                    
                    _execute_skill(selected_skill, valid_monsters, player_info)
                    poe2_api.dbgp("释放：")
                    poe2_api.printTable(selected_skill)
                end
                return bret.RUNNING
            end

            poe2_api.time_p("ReleaseSkillAction 耗时 --> ", api_GetTickCount64() - current_time_ms)
            return bret.RUNNING
        end
    },

    -- 躲避技能
    DodgeAction = {
        run = function(self, env)
            poe2_api.dbgp("DodgeAction")
            local is_initialized  = false
            if self.last_space_time == nil then
                self.last_space_time = 0.0 -- 上次按下空格的时间
                self.space_cooldown = 1500 -- 空格键冷却时间（秒）
                self.last_space_time1 = 0.0
                is_initialized = true
            end

            local is_bird = false
            for _,k in ipairs(env.player_info.buffs) do
                if k.name_en == "on_rhoa_mount" then
                    is_bird = true
                    break
                end
            end
            
            local _handle_space_action = function(monster, space_flag, space_monsters, space_time, player_info)
                -- 处理空格键操作
                if not space_time then
                    space_time = 1500
                else
                    space_time = space_time
                end
                local result_60 = api_GetSafeAreaLocation(env.player_info.grid_x, env.player_info.grid_y, 100, space_check_dis, 1, 0.5)
                if ((space_flag and poe2_api.table_contains(space_monsters,monster.rarity))) and
                api_GetTickCount64() - self.last_space_time >= space_time  then
                    local result = nil
                    if not result_60 or (result_60.x == env.player_info.grid_y and result_60.y == env.player_info.grid_y) then
                        result = api_GetNextCirclePosition(monster.grid_x, monster.grid_y, player_info.grid_x, player_info.grid_y, 50,20,0)
                    else
                        result = result_60
                    end
                    api_ClickMove(poe2_api.toInt(result.x), poe2_api.toInt(result.y), 0)
                    api_Sleep(200)
                    poe2_api.dbgp1("_handle_space_action")
                    if is_bird then
                        api_ClickMove(poe2_api.toInt(result.x), poe2_api.toInt(result.y), 7)
                    else
                        poe2_api.click_keyboard("space")
                    end
                    self.last_space_time = api_GetTickCount64()
                end
            end   

            local _handle_space_action_path_name = function(player_info, space_time)
                -- 处理空格键操作（添加20单位距离限制）
                space_time = space_time or 1500
                local ret = nil
                local danger = api_IsPointInAnyActive(player_info.grid_x , player_info.grid_y , 100)
                if danger and danger.inside then
                    local safe_point = danger.safeTile

                    if safe_point and safe_point.x ~= -1 and safe_point.y ~= -1 then
                        if not api_ClickMove(poe2_api.toInt(safe_point.x), poe2_api.toInt(safe_point.y), 7) or not api_HasObstacleBetween(safe_point.x, safe_point.y) then
                            poe2_api.dbgp("安全点过远或有障碍物")
                            env.end_point = {safe_point.x, safe_point.y}
                            return bret.FAIL
                        end
                        api_Sleep(200)
                        env.end_point = nil
                        env.path_list = nil
                        if not is_bird or danger.action == 2 then
                            poe2_api.click_keyboard("space")
                        end
                        return true
                    end
                end
                return false
            end

            -- 更新方法，执行躲避逻辑
            local monsters = env.range_info
            local player_info = env.player_info
            local space = env.space
            local space_time = env.space_time
            local space_monster = env.space_monster
            if not monsters or not player_info then
                return bret.SUCCESS
            end
            local space_check_dis = env.space_config["躲避距离"]
            local min_attack_range = env.min_attack_range or 70
            if space then
                for _, monster in ipairs(monsters) do
                    dis = poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info)
                    if poe2_api.table_contains(monster.name_utf8, {'多里亞尼','崛起之王．賈嫚拉'}) and monster.life > 0 and dis and dis < space_check_dis then
                        _handle_space_action(monster, space, space_monster, space_time, player_info)
                    end
                    if monster.life > 0 and monster.isActive  and not poe2_api.table_contains(monster.name_utf8, {"","惡魔"}) and dis and dis < space_check_dis and 
                    not monster.is_friendly and monster.hasLineOfSight then
                        if not poe2_api.table_contains(my_game_info.type_3_boss, monster.name_utf8) and monster.type ~= 1 then
                            goto continue
                        end
                        for _, prop in ipairs(my_game_info.first_magicProperties or {}) do
                            if poe2_api.table_contains(monster.magicProperties, prop) then
                                poe2_api.dbgp("特殊词缀怪物,不闪避")
                                goto continue
                            end
                        end
                        _handle_space_action(monster, space, space_monster, space_time, player_info)
                    end
                    ::continue::
                end
            end
            
            _handle_space_action_path_name(player_info)
            return bret.SUCCESS
        end
    },

    -- 是否在新手剧情（攻击和交互）
    Is_In_New_Area = {
        run = function(self, env)
            poe2_api.print_log("是否在新手剧情（攻击和交互）模块开始执行...")

            poe2_api.dbgp("=== 是否在新手剧情（攻击和交互） ===")
            local player_info = env.player_info

            if player_info.current_map_name_utf8 == "G1_1" then
                poe2_api.time_p("[Is_In_New_Area]",(api_GetTickCount64() - current_time))
                return bret.SUCCESS
            end
            poe2_api.time_p("[Is_In_New_Area]",(api_GetTickCount64() - current_time))
            return bret.FAIL
        end
    },

    -- 是否有交互对象
    Is_Have_Interaction_Object = {
        run = function(self, env)
            poe2_api.dbgp("=== 是否有交互对象 ===")
            poe2_api.print_log("是否有交互对象模块开始执行...")
            if self.last_click_time == nil then
                self.last_click_time = 0
                self.click_cooldown = 1 
            end
            local function have_roman_number()
                local ROMAN_NUMERALS = {
                    "I", "II", "III", "IV", "V",
                    "VI", "VII", "VIII", "IX", "X",
                    "XI", "XII", "XIII", "XIV", "XV", "XVI"
                }
                if poe2_api.find_text({ UI_info = env.UI_info, text = ROMAN_NUMERALS, min_x = 520, min_y = 420, max_x = 560, max_y = 470 }) then
                    return true
                else
                    return false
                end
            end
            local player_info = env.player_info
            local range_info = env.range_info
            local interaction_object = env.interaction_object
            local interaction_object_map_name = env.interaction_object_map_name
            local task_area = env.map_name
            local current_time = api_GetTickCount64()
            local me_area = player_info.current_map_name_utf8
            local team_info = env.team_info
            local user_config = env.user_config
            local team_member_2 = poe2_api.get_team_info(team_info,user_config,player_info,2)
            if interaction_object then
                if poe2_api.find_text({ UI_info = env.UI_info, text = "繼續"}) then
                    poe2_api.click_keyboard("space")
                    return bret.RUNNING
                end
                if poe2_api.find_text({ UI_info = env.UI_info, text = "獎勵", min_x = 100}) then
                    poe2_api.dbgp("领取任务奖励")
                    if not me_area == "G4_2" then
                        poe2_api.find_text({ UI_info = env.UI_info, text = "獎勵", min_x = 100, add_y = 100 , click = 2 })
                    end
                    poe2_api.find_text({ UI_info = env.UI_info, text = "獎勵", min_x = 100, add_y = 100 , click = 2 })
                    api_Sleep(500)
                    if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                        if have_roman_number() then
                            poe2_api.get_space_point({ width = 1, height = 1, click = 1 })
                        else
                            poe2_api.get_space_point({ width = 4, height = 2, click = 1 })
                        end
                    else
                        poe2_api.click_keyboard("i")
                        return bret.RUNNING
                    end
                    poe2_api.get_space_point({ width = 4, height = 2, click = 1 })
                    if not poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                        poe2_api.click_keyboard("i")
                        return bret.RUNNING
                    end
                end
                if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                    poe2_api.click_keyboard("i")
                    return bret.RUNNING
                end
                if poe2_api.find_text({ UI_info = env.UI_info, text = "繼續"}) then
                    poe2_api.click_keyboard("space")
                    return bret.RUNNING
                end 
            end
            if team_member_2 == "大號名" and string.find(me_area, "town") and me_area ~= "G3_town" then
                return bret.SUCCESS
            end
            if me_area == "G1_1" then
                if poe2_api.find_text({ UI_info = env.UI_info, text = "大箱子",min_x = 0}) then
                    env.end_point = nil
                    env.is_arrive_end = false
                    env.path_list = {}
                    if self.last_click_time == 0 then
                        self.last_click_time = api_GetTickCount64()
                    end
                    if api_GetTickCount64() - self.last_click_time > self.click_cooldown then
                        poe2_api.find_text({ UI_info = env.UI_info, text = "大箱子",min_x = 0, click = 2})
                        self.last_click_time = 0
                    end
                    return bret.RUNNING
                end
                local career = user_config["組隊設置"]["職業"]
                local setinfo = my_game_info.newbie_gear[career]
                local skilltext = setinfo["skill"]
                if skilltext then
                    if poe2_api.find_text({ UI_info = env.UI_info, text = skilltext,min_x = 0}) then
                        env.end_point = nil
                        env.is_arrive_end = false
                        env.path_list = {}
                        poe2_api.find_text({ UI_info = env.UI_info, text = skilltext,min_x = 0, click = 2})
                        return bret.RUNNING
                    end
                end
                local geartext = setinfo["gear"]
                if geartext and me_area == "G1_1" then
                    if poe2_api.find_text({ UI_info = env.UI_info, text = geartext,min_x = 0}) then
                        env.end_point = nil
                        env.is_arrive_end = false
                        env.path_list = {}
                        poe2_api.find_text({ UI_info = env.UI_info, text = geartext,min_x = 0, click = 2})
                        return bret.RUNNING
                    end
                end
            end
            if (interaction_object or interaction_object_map_name ) and me_area == task_area then
                if env.modify_interaction then
                    poe2_api.dbgp("修改交互对象")
                    env.interaction_object = env.interaction_object_copy
                    env.interaction_object_map_name = env.interaction_object_map_name_copy
                    env.modify_interaction = false
                end
                if env.is_not_ui then
                    env.is_not_ui = false
                    poe2_api.time_p("[Is_Have_Interaction_Object]",(api_GetTickCount64() - current_time))
                    return bret.SUCCESS
                end
                if env.not_need_active then
                    env.not_need_active = false
                    poe2_api.time_p("[Is_Have_Interaction_Object]",(api_GetTickCount64() - current_time))
                    return bret.SUCCESS
                end
                poe2_api.dbgp("进入周围是否有交互对象")
                poe2_api.time_p("[Is_Have_Interaction_Object]",(api_GetTickCount64() - current_time))

                return bret.FAIL
            end
            poe2_api.time_p("[Is_Have_Interaction_Object]",(api_GetTickCount64() - current_time))
            return bret.SUCCESS
        end
    }, 

    -- 周围是否有交互对象 
    The_Interactive_Object_Exist = {
        run = function(self, env)
            poe2_api.dbgp("=== 周围是否有交互对象 ===")
            poe2_api.print_log("=== 周围是否有交互对象 ===")
            local bag_info = env.bag_info
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            local range_info = env.range_info
            local UI_info = env.UI_info
            local interaction_object = env.interaction_object
            local task_name = env.task_name
            local grid_x = env.grid_x
            local grid_y = env.grid_y
            local record_map = env.record_map
            local range_items = env.range_items
            local map_result = env.map_result
            local current_map_info = env.current_map_info
            local sorted_range_info = poe2_api.get_sorted_list(range_info, player_info)
            local boss_name = env.boss_name
            local interaction_object_map_name = env.interaction_object_map_name
            local team_member_2 = poe2_api.get_team_info(env.team_info,env.user_config,player_info,2)
            if player_info.current_map_name_utf8 ~= "G4_4_2" then
                self.pick_up_fire = false
                self.pick_up_ice = false
                self.pick_up_Electricity = false
            end
            if self.time1 == nil then
                self.time1 = 0
                self.path_result = nil
                self.pick_up_fire = false
                self.pick_up_ice = false
                self.pick_up_Electricity = false
            end
            -- 小地图是否有指定对象
            local function mini_map_obj(name)
                local result = {}
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == name then
                        table.insert(result, item)
                    end
                end
                return result
            end
            -- 小地图是否有指定对象距离
            local function min_map_dis(name)
                local function target_distance(actor)
                    -- 计算与玩家的平方距离
                    return (actor.grid_x - player_info.grid_x) ^ 2 + (actor.grid_y - player_info.grid_y) ^ 2
                end
                
                local targets = {}
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == name and item.flagStatus1 == 1 then
                        table.insert(targets, item)
                    end
                end
                
                table.sort(targets, function(a, b)
                    return target_distance(a) < target_distance(b)
                end)
                
                return targets
            end
            if interaction_object or interaction_object_map_name then
                local interaction_object_set = interaction_object
                local local_x = player_info.grid_x
                local local_y = player_info.grid_y
                -- 公共函数
                local function get_distance(x,y)
                    return poe2_api.point_distance(x,y,player_info)
                end
                local function should_break_mos()
                    return (poe2_api.is_have_mos({range_info = range_info, player_info = player_info}) and team_member_2 == "大號名" )
                end
                if poe2_api.table_contains("門",interaction_object_set) then
                    local door_list = poe2_api.get_sorted_obj("門",range_info,player_info)
                    if door_list and #door_list > 0 and poe2_api.find_text({ UI_info = UI_info, text = "門", min_x = 0}) then
                        for _,door in ipairs(door_list) do
                            if should_break_mos() then 
                                poe2_api.dbgp("打怪，不开门")
                                env.not_need_active = true
                                return bret.RUNNING
                            end
                            if door.is_selectable then
                                local door_point = api_FindNearestReachablePoint(door.grid_x, door.grid_y,10,1)
                                if get_distance(door.grid_x,door.grid_y) < 25 then
                                    poe2_api.dbgp("距离门小于25，点击门")
                                    api_ClickMove(poe2_api.toInt(door.grid_x),poe2_api.toInt(door.grid_y),1)
                                    return bret.RUNNING
                                else
                                    poe2_api.dbgp("距离门大于25，找门")
                                    local door_path = api_FindPath(local_x,local_y,door_point.x,door_point.y)
                                    if door_path and #door_path > 0 then
                                        poe2_api.dbgp("找到门的路径")
                                        env.end_point = {door_point.x,door_point.y}
                                        if poe2_api.table_contains(player_info.current_map_name_utf8,{"G3_6_1"}) then
                                            env.interaction_object = {'門'}
                                        end
                                        return bret.SUCCESS
                                    else
                                        poe2_api.dbgp("未找到门的路径")
                                        door_point = api_FindRandomWalkablePosition(door.grid_x, door.grid_y,50)
                                        api_ClickMove(poe2_api.toInt(door_point.x),poe2_api.toInt(door_point.y),0)
                                        poe2_api.click_keyboard("space")
                                        env.not_need_active = true
                                        return bret.RUNNING
                                    end
                                end
                            end
                        end
                    end
                end
                if poe2_api.table_contains("壓桿",interaction_object_set) then
                    poe2_api.dbgp("检测到压杆")
                    if team_member_2 ~= "大號名" then
                        env.is_not_ui = true
                        return bret.RUNNING
                    end
                    local target = min_map_dis("WaterwaysLever")
                    local range_target = poe2_api.get_sorted_obj("壓桿",range_info,player_info)
                    if target and #target > 0 then
                        local target_point = api_FindNearestReachablePoint(target[1].grid_x, target[1].grid_y,20,0)
                        if get_distance(target[1].grid_x, target[1].grid_y) < 30 then
                            poe2_api.dbgp("距离压杆小于30，点击压杆")
                            poe2_api.find_text({ UI_info = UI_info, text = "壓桿", min_x = 200, click = 2})
                            api_Sleep(5000)
                            api_UpdateMapObstacles(100)
                            return bret.RUNNING
                        else
                            local target_point_path = api_FindPath(local_x,local_y,target_point.x,target_point.y)
                            if target_point_path and #target_point_path > 0 then
                                poe2_api.dbgp("找到压杆的路径",get_distance(target[1].grid_x, target[1].grid_y))
                                env.end_point = {target_point.x,target_point.y}
                                return bret.SUCCESS
                            else
                                poe2_api.dbgp("未找到压杆的路径")
                                target_point = api_FindRandomWalkablePosition(target[1].grid_x, target[1].grid_y,50)
                                api_ClickMove(poe2_api.toInt(target_point.x),poe2_api.toInt(target_point.y),0)
                                poe2_api.click_keyboard("space")
                                env.not_need_active = true
                                return bret.RUNNING
                            end
                        end
                    else
                        local point = {}
                        poe2_api.dbgp("未找到压杆设置探索范围40")
                        point = api_GetUnexploredArea(40)
                        if point.x == -1 and point.y == -1 then
                            for _,target in ipairs(range_target) do
                                if should_break_mos() then 
                                    break
                                end
                                if target.stateMachineList and target.stateMachineList.water_level ~= 2 then
                                    api_UpdateMapObstacles(100)
                                    if get_distance(target.grid_x,target.grid_y) < 25 then
                                        poe2_api.dbgp("距离压杆小于25，点击压杆")
                                        poe2_api.find_text({ UI_info = UI_info, text = "壓桿", min_x = 200, click = 2})
                                        api_Sleep(5000)
                                        api_UpdateMapObstacles(100)
                                        return bret.RUNNING
                                    end
                                    local target_point = api_FindNearestReachablePoint(target.grid_x, target.grid_y,20,0)
                                    local target_path = api_FindPath(local_x,local_y,target_point.x,target_point.y)
                                    if target_path and #target_path > 0 then
                                        env.end_point = {target_point.x,target_point.y}
                                        return bret.SUCCESS
                                    end
                                    env.is_not_ui = true
                                    return bret.RUNNING
                                end
                            end
                        end
                    end
                end
                
                if poe2_api.table_contains("<questitem>{發電機}",interaction_object_set) then
                    poe2_api.dbgp("检测到发电机")
                    local target = interaction_object[1]
                    if (not bag_info or #bag_info == 0) or ((not poe2_api.check_item_in_inventory("中型靈魂核心",bag_info)) or poe2_api.find_text({ UI_info = UI_info, text = target, max_x=1347, min_x=200}))
                        and not poe2_api.find_text({ UI_info = UI_info, text = "<questitem>{大型靈魂核心}", max_x=1550, min_x=0}) then
                        local core_list = poe2_api.get_sorted_obj("中型靈魂核心", range_items, player_info)
                        if core_list and #core_list > 0 then
                            local core = core_list[1]
                            if get_distance(core.grid_x,core.grid_y) < 25 then
                                poe2_api.find_text({ UI_info = UI_info, text = target, max_x=1347, min_x=200, click = 2})
                                env.end_point = nil
                                env.is_arrive_end = false
                                env.path_list = {}
                                return bret.RUNNING
                            else
                                poe2_api.dbgp("距离核心大于25，找核心")
                                env.end_point = {core.grid_x,core.grid_y}
                                return bret.SUCCESS
                            end
                        end
                        env.is_not_ui = true
                        return bret.RUNNING
                    else
                        local core_list = poe2_api.get_sorted_obj("<questitem>{大型靈魂核心}", range_info, player_info)
                        if core_list and #core_list > 0 and core_list[1].stateMachineList and core_list[1].stateMachineList.powered == 1 and core_list[1].stateMachineList.fight_ready == 2 then
                            local core = core_list[1]
                            if get_distance(core.grid_x,core.grid_y) < 30 then
                                poe2_api.find_text({ UI_info = UI_info, text = "<questitem>{大型靈魂核心}", max_x=1347, min_x=200, click = 2})
                                env.end_point = nil
                                env.is_arrive_end = false
                                env.path_list = {}
                                env.is_not_ui = true
                                return bret.RUNNING
                            elseif get_distance(core.grid_x,core.grid_y) < 150 then
                                local core_point = api_FindNearestReachablePoint(core.grid_x, core.grid_y,20,1)
                                env.end_point = {core_point.x,core_point.y}
                                return bret.SUCCESS
                            end
                        end
                        local generator_list = poe2_api.get_sorted_obj("<questitem>{發電機}", range_info, player_info)
                        if generator_list and #generator_list > 0 then
                            for _,generator in ipairs(generator_list) do
                                if generator.stateMachineList and  generator.stateMachineList.activate == 0 then
                                    if get_distance(generator.grid_x,generator.grid_y) < 30 then
                                        if team_member_2 ~="大號名" then
                                            env.is_not_ui = true
                                            return bret.RUNNING
                                        end
                                        poe2_api.find_text({ UI_info = UI_info, text = "<questitem>{發電機}", max_x=1347, min_x=200, click = 2})
                                        env.end_point = nil
                                        env.is_arrive_end = false
                                        env.path_list = {}
                                        return bret.RUNNING
                                    else
                                        local generator_point = api_FindNearestReachablePoint(generator.grid_x, generator.grid_y,20,1)
                                        env.end_point = {generator_point.x,generator_point.y}
                                        return bret.SUCCESS
                                    end
                                end
                            end
                        end
                    end
                end
                if poe2_api.table_contains("石陣祭壇",interaction_object_set) and #interaction_object > 1 then
                    poe2_api.dbgp("检测到石陣祭壇")
                    local target = "小型靈魂核心"
                    if (not bag_info or #bag_info == 0) or ((not poe2_api.check_item_in_inventory(target,bag_info)) or poe2_api.find_text({ UI_info = UI_info, text = target, max_x=1347, min_x=200}))
                        and not poe2_api.find_text({ UI_info = UI_info, text = "吉卡尼的聖域", max_x=1550, min_x=0}) then
                        local core_list = poe2_api.get_sorted_obj(target, range_items, player_info)
                        if core_list and #core_list > 0 then
                            local core = core_list[1]
                            if get_distance(core.grid_x,core.grid_y) < 25 then
                                poe2_api.dbgp("小型靈魂核心距离小于25，点击小型靈魂核心")
                                poe2_api.find_text({ UI_info = UI_info, text = target, max_x=1347, min_x=200, click = 2})
                                env.end_point = nil
                                env.is_arrive_end = false
                                env.path_list = {}
                                return bret.RUNNING
                            else
                                env.end_point = {core.grid_x,core.grid_y}
                                return bret.SUCCESS
                            end
                        end
                        env.is_not_ui = true
                        return bret.RUNNING
                    end
                end
                if poe2_api.table_contains("卡洛翰的姐妹",interaction_object_set) then
                    poe2_api.dbgp("检测到卡洛翰的姐妹")
                    local sister = poe2_api.get_sorted_obj("卡洛翰的姐妹", range_info, player_info)
                    if sister and #sister > 0 then
                        if sister[1].stateMachineList and sister[1].stateMachineList.active == 0 then
                            if get_distance(sister[1].grid_x,sister[1].grid_y) < 30 then
                                poe2_api.find_text({ UI_info = UI_info, text = "卡洛翰的姐妹", max_x=1347, min_x=200, click = 2})
                                env.end_point = nil
                                env.is_arrive_end = false
                                env.path_list = {}
                                return bret.RUNNING
                            else
                                local sister_point = api_FindNearestReachablePoint(sister[1].grid_x, sister[1].grid_y,20,0)
                                env.end_point = {sister_point.x,sister_point.y}
                                return bret.SUCCESS
                            end 
                        end
                        env.is_not_ui = true
                        env.record_map = nil
                    end
                end
                if poe2_api.table_contains("召喚瑟維",interaction_object_set) then
                    poe2_api.dbgp("检测到召喚瑟維")
                    local servi = poe2_api.get_sorted_obj("召喚瑟維", range_info, player_info)
                    if servi and #servi > 0 then
                        local sister_toward = poe2_api.move_towards({local_x,local_y},{servi[1].grid_x,servi[1].grid_y}, 50)
                        api_ClickMove(poe2_api.toInt(sister_toward[1]),poe2_api.toInt(sister_toward[2]),0)
                        poe2_api.click_keyboard("space")
                        api_Sleep(300)
                        poe2_api.find_text({UI_info = UI_info, text = "召喚瑟維", min_x=160, click = 2})
                    end
                end
                if player_info.current_map_name_utf8 == "G2_3" then
                    local npc = poe2_api.get_sorted_obj("絲克瑪．阿薩拉", range_info, player_info)
                    if npc and #npc > 0 then
                        if not npc[1].isActive then
                            poe2_api.dbgp("检测到絲克瑪．阿薩拉未激活，将执行点击操作")
                            return bret.RUNNING
                        end
                    end
                end
                if player_info.current_map_name_utf8 == "G2_2" and task_name == "返回車隊，與芮蘇討論封閉的古老關口" then
                    poe2_api.dbgp("芭芭拉的巨靈之幣")
                    local seals = poe2_api.get_sorted_obj("古代封印", range_info, player_info)
                    local runes = poe2_api.get_sorted_obj("符文之印", range_info, player_info)
                    if seals and #seals > 0  and runes and #runes > 0 then
                        if seals[1].stateMachineList and seals[1].stateMachineList.open == 0 then
                            poe2_api.dbgp("古代封印未開")
                            if get_distance(seals[1].grid_x,seals[1].grid_y) < 30 then
                                poe2_api.find_text({ UI_info = UI_info, text = "古代封印", max_x=1347, min_x=200, click = 2})
                                env.end_point = nil
                                env.is_arrive_end = false
                                env.path_list = {}
                                return bret.RUNNING
                            else
                                local seals_point = api_FindNearestReachablePoint(seals[1].grid_x, seals[1].grid_y,20,1)
                                env.end_point = {seals_point.x,seals_point.y}
                                return bret.SUCCESS
                            end
                        end
                        for _, rune in ipairs(runes) do
                            if rune.stateMachineList and rune.stateMachineList.open == 0 then
                                poe2_api.dbgp("符文之印未開")
                                if get_distance(rune.grid_x,rune.grid_y) < 30 then
                                    if team_member_2 ~="大號名" then
                                        env.is_not_ui = true
                                        return bret.RUNNING
                                    end
                                    poe2_api.find_text({ UI_info = UI_info, text = "符文之印", max_x=1347, min_x=200, click = 2})
                                    env.end_point = nil
                                    env.is_arrive_end = false
                                    env.path_list = {}
                                    return bret.RUNNING
                                else
                                    local rune_point = api_FindNearestReachablePoint(rune.grid_x, rune.grid_y,20,1)
                                    env.end_point = {rune_point.x,rune_point.y}
                                    return bret.SUCCESS
                                end
                            end
                        end
                    end
                    if (not bag_info or #bag_info == 0) or (not poe2_api.check_item_in_inventory("芭芭拉的巨靈之幣",bag_info) and team_member_2 ~="大號名") or team_member_2 == "大號名" then
                        local boss = poe2_api.get_sorted_obj("叛徒芭芭拉", range_info, player_info)
                        if boss and #boss > 0 and boss[1].life > 0 and player_info.isInBossBattle then
                            env.interaction_object = nil 
                            env.record_map = nil
                            if get_distance(boss[1].grid_x,boss[1].grid_y) < 30 then
                                poe2_api.dbgp("叛徒芭芭拉距离<30")
                                return bret.RUNNING
                            end
                            env.end_point ={boss[1].grid_x,boss[1].grid_y}
                            return bret.SUCCESS
                        end
                        env.is_not_ui = true
                        env.interaction_object_copy = nil
                        env.interaction_object_map_name_copy = nil 
                        env.modify_interaction = true
                        return bret.RUNNING
                    end
                end
                if poe2_api.table_contains("瘋狂讚美詩",interaction_object_set) then
                    poe2_api.dbgp("瘋狂讚美詩")
                    local handle = poe2_api.get_sorted_obj("瘋狂讚美詩", range_info, player_info)
                    local boss = poe2_api.get_sorted_obj("存活儀式．燭光",range_info,player_info)
                    if handle and #handle > 0 and boss and #boss > 0 then
                        for _,h in ipairs(handle) do
                            if boss[1] and boss[1].life > 0 then
                                if get_distance(h.grid_x,h.grid_y) < 30 then
                                    if not boss[1].isActive then
                                        poe2_api.find_text({ UI_info = UI_info, text = "瘋狂讚美詩", max_x=1347, min_x=200, click = 2})
                                        env.end_point = nil
                                        env.is_arrive_end = false
                                        env.path_list = {}
                                        return bret.RUNNING
                                    end
                                else
                                    local handle_point = api_FindNearestReachablePoint(h.grid_x, h.grid_y,20,1)
                                    env.end_point = {handle_point.x,handle_point.y}
                                    return bret.SUCCESS
                                end
                            else
                                env.record_map = nil
                                env.is_not_ui = true
                                return bret.RUNNING
                            end
                        end
                    end
                end
                if grid_x and grid_y then
                    local distacne = poe2_api.point_distance(grid_x,grid_y,player_info)
                    poe2_api.dbgp("固定点grid_x, grid_y",distacne)
                    if distacne> 25 then
                        if api_FindPath(local_x,local_y,grid_x,grid_y) then
                            env.end_point = {grid_x,grid_y}
                            return bret.SUCCESS
                        end
                    else
                        env.is_arrive_end = true
                        return bret.SUCCESS
                    end
                end
                if poe2_api.table_contains("把手",interaction_object_set) then
                    local handle = poe2_api.get_sorted_obj("把手", range_info, player_info)
                    if handle and #handle > 0 and player_info.current_map_name_utf8 == "G1_13_2" then
                        for _,h in ipairs(handle) do
                            if h.stateMachineList and h.stateMachineList.helper_state ~= 2 then
                                if get_distance(h.grid_x,h.grid_y) < 30 then
                                    poe2_api.find_text({ UI_info = UI_info, text = "把手", max_x=1347, min_x=200, click = 1})
                                    api_Sleep(500)
                                    poe2_api.find_text({ UI_info = UI_info, text = "把手", max_x=1347, min_x=200, click = 2})
                                    api_Sleep(2000)
                                    env.end_point = nil
                                    env.is_arrive_end = false
                                    env.path_list = {}
                                    local handle_point = api_FindRandomWalkablePosition(h.grid_x, h.grid_y,40)
                                    api_ClickMove(poe2_api.toInt(handle_point.x),poe2_api.toInt(handle_point.y),0)
                                    api_Sleep(300)
                                    poe2_api.click_keyboard("space")
                                    env.not_need_active = true
                                    return bret.RUNNING
                                else
                                    local handle_point = api_FindNearestReachablePoint(h.grid_x, h.grid_y,30,1)
                                    env.end_point = {handle_point.x,handle_point.y}
                                    return bret.SUCCESS
                                end
                            end
                        end
                    end
                end
                if not sorted_range_info or #sorted_range_info == 0 then
                    poe2_api.dbgp("没有检测到周围对象")
                    return bret.RUNNING
                end
                if player_info.current_map_name_utf8 == "G1_2" then
                    if  #mini_map_obj("CroneInactive") == 0 then
                        poe2_api.dbgp("G1_2-小地图没有-CroneInactive")
                        interaction_object_set = nil 
                        env.interaction_object = nil
                        interaction_object_map_name = {"CroneActive"}
                        env.interaction_object_map_name = {"CroneActive"}
                        env.interaction_object_copy = nil
                        env.interaction_object_map_name_copy = {"CroneActive"}
                        env.modify_interaction = true
                    end
                elseif player_info.current_map_name_utf8 == "G2_4_1" then
                    if #mini_map_obj("KabalaInactive") == 0 then
                        poe2_api.dbgp("G2_4_1小地图没有KabalaInactive")
                        interaction_object_set = nil 
                        env.interaction_object = nil
                        interaction_object_map_name = {"KabalaActive"}
                        env.interaction_object_map_name = {"KabalaActive"}
                        env.interaction_object_copy = nil
                        env.interaction_object_map_name_copy = {"KabalaActive"}
                        env.modify_interaction = true
                    end
                elseif player_info.current_map_name_utf8 == "G3_3" then
                    if #mini_map_obj("SilverbackBlackfistBossInactive") == 0 then
                        poe2_api.dbgp("G3_3小地图没有SilverbackBlackfistBossInactive")
                        interaction_object_set = nil 
                        env.interaction_object = nil
                        interaction_object_map_name = {"SilverbackBlackfistBossActive"}
                        env.interaction_object_map_name = {"SilverbackBlackfistBossActive"}
                        env.interaction_object_copy = nil
                        env.interaction_object_map_name_copy = {"SilverbackBlackfistBossActive"}
                        env.modify_interaction = true
                    end
                elseif player_info.current_map_name_utf8 == "G3_6_1" and not poe2_api.table_contains("艾瓦",interaction_object_set) then
                    if #mini_map_obj("BlackjawBossInactive") == 0 then
                        poe2_api.dbgp("G3_6_1地图没有BlackjawBossInactive")
                        interaction_object_set = {"門", "小型靈魂核心", "石陣祭壇"} 
                        env.interaction_object = {"門", "小型靈魂核心", "石陣祭壇"} 
                        interaction_object_map_name = {"BlackjawBossActive"}
                        env.interaction_object_map_name = {"BlackjawBossActive"}
                        env.interaction_object_copy = {"門", "小型靈魂核心", "石陣祭壇"}
                        env.interaction_object_map_name_copy = {"BlackjawBossActive"}
                        env.modify_interaction = true
                    end
                elseif player_info.current_map_name_utf8 == "G4_1_1" then
                    if #mini_map_obj("IsleOfKinBossInactive") == 0 then
                        poe2_api.dbgp("G4_1_1-地图没有-IsleOfKinBossInactive")
                        interaction_object_set = nil
                        env.interaction_object = nil 
                        interaction_object_map_name = {"IsleOfKinBossActive"}
                        env.interaction_object_map_name = {"IsleOfKinBossActive"}
                        env.interaction_object_copy = nil
                        env.interaction_object_map_name_copy = {"IsleOfKinBossActive"}
                        env.modify_interaction = true
                    end
                elseif player_info.current_map_name_utf8 == "G4_4_1" then
                    if team_member_2 == "大號名" then
                        if #mini_map_obj("G4_4_2BossActive") == 0 then
                            poe2_api.dbgp("G4_4_1-地图没有-G4_4_2BossActive")
                            interaction_object_set = nil
                            env.interaction_object = nil
                            interaction_object_map_name = nil
                            env.interaction_object_map_name =nil
                            env.interaction_object_copy = nil
                            env.interaction_object_map_name_copy = nil
                            env.modify_interaction = true
                        end
                    else
                        if #mini_map_obj("G4_4_2BossInactive") == 0 then
                            poe2_api.dbgp("G4_4_1-地图没有-G4_4_2BossActive")
                            interaction_object_set = {"表示敬意"} 
                            env.interaction_object = {"表示敬意"}  
                            interaction_object_map_name = nil
                            env.interaction_object_map_name =nil
                            env.interaction_object_copy = {"表示敬意"} 
                            env.interaction_object_map_name_copy = nil
                            env.modify_interaction = true
                        end
                    end
                elseif player_info.current_map_name_utf8 == "G4_4_2" then
                    if #mini_map_obj("G4_4_2_Encounter_ValakoTribeInactive") ~= 0 then
                        self.pick_up_fire = true
                    end
                    if #mini_map_obj("G4_4_2_Encounter_TasalioTribeInactive") ~= 0 then
                        self.pick_up_ice = true
                    end
                    if #mini_map_obj("G4_4_2_Encounter_NgamahuTribeInactive") ~= 0 then
                        self.pick_up_Electricity = true
                    end
                    local task_text = {"將塔赫亞的空白紋身交給悉妮蔻拉圖騰","將塔薩里的空白紋身交給悉妮蔻拉圖騰","將拿馬乎的空白紋身交給悉妮蔻拉圖騰"}
                    if #mini_map_obj("G4_4_2_Encounter_ValakoTribeInactive") == 0 and not self.pick_up_fire then
                        if min_map_dis("G4_4_2_Encounter_ValakoTribeActive") and #min_map_dis("G4_4_2_Encounter_ValakoTribeActive") > 0 then
                            self.pick_up_fire = true
                            return bret.RUNNING
                        end    
                        poe2_api.dbgp("G4_4_2-地图没有-G4_4_2_Encounter_ValakoTribeInactive")
                        interaction_object_set = nil
                        env.interaction_object = nil
                        env.interaction_object_copy = nil
                        interaction_object_map_name = {"G4_4_2_Encounter_ValakoTribeActive"}
                        env.interaction_object_map_name = {"G4_4_2_Encounter_ValakoTribeActive"}
                        env.interaction_object_map_name_copy = {"G4_4_2_Encounter_ValakoTribeActive"}
                        env.modify_interaction = true
                    end
                    if #mini_map_obj("G4_4_2_Encounter_TasalioTribeInactive") == 0 and not self.pick_up_ice then
                        if min_map_dis("G4_4_2_Encounter_ValakoTribeActive") and #min_map_dis("G4_4_2_Encounter_ValakoTribeActive") > 0 then
                            self.pick_up_ice = true
                            return bret.RUNNING
                        end   
                        poe2_api.dbgp("G4_4_2-地图没有-G4_4_2_Encounter_TasalioTribeInactive")
                        interaction_object_set = nil
                        env.interaction_object = nil
                        env.interaction_object_copy = nil
                        interaction_object_map_name = {"G4_4_2_Encounter_TasalioTribeActive"}
                        env.interaction_object_map_name = {"G4_4_2_Encounter_TasalioTribeActive"}
                        env.interaction_object_map_name_copy = {"G4_4_2_Encounter_TasalioTribeActive"}
                        env.modify_interaction = true
                    end
                    if #mini_map_obj("G4_4_2_Encounter_NgamahuTribeInactive") == 0 and not self.pick_up_Electricity then
                        if min_map_dis("G4_4_2_Encounter_NgamahuTribeActive") and #min_map_dis("G4_4_2_Encounter_NgamahuTribeActive") > 0 then
                            self.pick_up_Electricity = true
                            return bret.RUNNING
                        end 
                        poe2_api.dbgp("G4_4_2-地图没有-G4_4_2_Encounter_NgamahuTribeInactive")
                        interaction_object_set = nil
                        env.interaction_object = nil
                        env.interaction_object_copy = nil
                        interaction_object_map_name = {"G4_4_2_Encounter_NgamahuTribeActive"}
                        env.interaction_object_map_name = {"G4_4_2_Encounter_NgamahuTribeActive"}
                        env.interaction_object_map_name_copy = {"G4_4_2_Encounter_NgamahuTribeActive"}
                        env.modify_interaction = true
                    end
                    if poe2_api.table_contains(task_name,task_text) then
                        interaction_object_set = {"悉妮蔻拉圖騰"}
                        env.interaction_object = {"悉妮蔻拉圖騰"}
                        env.interaction_object_copy = {"悉妮蔻拉圖騰"}
                    end 
                    if task_name == '向悉妮蔻拉圖騰領取獎勵' then
                        interaction_object_set = {"悉妮蔻拉圖騰","塔赫亞的考驗獎勵","拿馬乎的考驗獎勵","塔薩里奧的考驗獎勵"}
                        env.interaction_object = {"悉妮蔻拉圖騰","塔赫亞的考驗獎勵","拿馬乎的考驗獎勵","塔薩里奧的考驗獎勵"}
                        env.interaction_object_copy = {"悉妮蔻拉圖騰","塔赫亞的考驗獎勵","拿馬乎的考驗獎勵","塔薩里奧的考驗獎勵"}
                    end                  
                elseif player_info.current_map_name_utf8 == "G3_12" and poe2_api.table_contains("艾瓦",interaction_object_set) and team_member_2 ~="大號名" then
                    poe2_api.dbgp("G3_12地图")
                    interaction_object_set = nil
                    env.interaction_object = nil
                    interaction_object_map_name = {"艾瓦"}
                    env.interaction_object_map_name = {"艾瓦"}
                    env.interaction_object_copy = nil
                    env.interaction_object_map_name_copy = {"艾瓦"}
                    env.modify_interaction = true
                end
                if interaction_object_set and not poe2_api.table_contains("Per",interaction_object_set) then
                    for _,obj in ipairs(sorted_range_info) do
                        if poe2_api.table_contains(' 祭祀神壇',interaction_object_set) then 
                            if poe2_api.table_contains({"Metadata/Terrain/Leagues/Ritual/RitualRuneLight"},obj.path_name_utf8) and poe2_api.find_text({ UI_info = UI_info, text = " 祭祀神壇", min_x=200}) and obj.hasLineOfSight then
                                if get_distance(obj.grid_x,obj.grid_y) > 30 then
                                    local rune_point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y,15, 0)
                                    env.end_point = {rune_point.x,rune_point.y}
                                    return bret.SUCCESS 
                                else
                                    env.is_arrive_end = true
                                    return bret.SUCCESS
                                end
                            end   
                        end
                        if not obj.name_utf8 then
                            goto continue
                        end
                        if poe2_api.table_contains(obj.name_utf8,interaction_object_set) then
                            if task_name == "擊敗憎惡者．賈嫚拉" and player_info.current_map_name_utf8 == "G2_12_2" and not poe2_api.find_text({ UI_info = UI_info, text = obj.name_utf8, min_x=200}) then
                                if get_distance(obj.grid_x,obj.grid_y) > 30 then
                                    local interaction_point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y,29,1)
                                    env.end_point = {interaction_point.x,interaction_point.y}
                                    return bret.SUCCESS
                                else
                                    env.is_arrive_end = true
                                    return bret.SUCCESS
                                end
                            end
                            if obj.name_utf8 == "符文之印" then
                                if obj.stateMachineList and obj.stateMachineList.ready ==1 and obj.stateMachineList.stabbed == 0 then
                                    if get_distance(obj.grid_x,obj.grid_y) < 25 then
                                        api_ClickMove(poe2_api.toInt(obj.grid_x),poe2_api.toInt(obj.grid_y),1)
                                        if self.time1 == 0 then
                                            self.time1 = api_GetTickCount64()
                                        end
                                        if api_GetTickCount64() - self.time1 > 6*1000 then
                                            local obj_walk_point = api_FindRandomWalkablePosition(obj.grid_x, obj.grid_y,30)
                                            api_ClickMove(obj_walk_point.x,obj_walk_point.y,0)
                                            poe2_api.click_keyboard("space")
                                            self.time1 = 0
                                        end
                                        return bret.RUNNING
                                    else
                                        self.time1 = 0
                                        local obj_reach_point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y,10,0)
                                        env.end_point = {obj_reach_point.x,obj_reach_point.y}  
                                        return bret.SUCCESS
                                    end
                                end
                                goto continue
                            end
                            if poe2_api.table_contains(obj.name_utf8,{"受傷的男人", "水之女神", "水之女神．哈拉妮","表示敬意"}) and get_distance(obj.grid_x,obj.grid_y) > 25 and get_distance(obj.grid_x,obj.grid_y) < 150 then
                                local obj_reach_point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y,15, 0)
                                if obj_reach_point.x ~= -1 then
                                    env.end_point = {obj_reach_point.x,obj_reach_point.y}
                                else
                                    env.end_point = {obj.grid_x,obj.grid_y}
                                end
                                return bret.SUCCESS
                            end
                            if poe2_api.find_text({ UI_info = UI_info, text = obj.name_utf8, min_x=0}) and ( obj.hasLineOfSight or poe2_api.table_contains(obj.type,{-1,4}) or (obj.type == 3 and obj.is_selectable) or poe2_api.table_contains(obj.name_utf8, {"受傷的男人", "水之女神", "水之女神．哈拉妮"})) then
                                poe2_api.dbgp("找到目标UI")
                                if get_distance(obj.grid_x,obj.grid_y) > 30 then
                                    local interaction_point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y,15,0)
                                    env.end_point = {interaction_point.x,interaction_point.y}
                                    return bret.SUCCESS
                                else
                                    env.is_arrive_end = true
                                    return bret.SUCCESS
                                end
                            end
                            if poe2_api.table_contains(player_info.current_map_name_utf8,{"G2_10_2","G4_1_2","G4_4_2"}) and poe2_api.table_contains(obj.name_utf8, {"法里登叛變者．芮蘇","馬提奇","悉妮蔻拉圖騰"}) then
                                if get_distance(obj.grid_x,obj.grid_y) < 30 then
                                    api_ClickMove(poe2_api.toInt(obj.grid_x),poe2_api.toInt(obj.grid_y),1)
                                    env.is_arrive_end = true
                                    return bret.SUCCESS
                                else
                                    env.end_point = {obj.grid_x,obj.grid_y}
                                    return bret.SUCCESS
                                end
                                
                                
                            end
                            if obj.hasLineOfSight and obj.is_selectable and get_distance(obj.grid_x,obj.grid_y) < 30 then
                                api_ClickMove(poe2_api.toInt(obj.grid_x),poe2_api.toInt(obj.grid_y),1)
                                return bret.RUNNING
                            end
                        end
                        ::continue::
                    end
                end
                if interaction_object_map_name then
                    poe2_api.dbgp("小地图")
                    for _,map_obj in ipairs(current_map_info) do
                        local name = map_obj.name_utf8
                        if (not name or not poe2_api.table_contains(name,interaction_object_map_name)) and not record_map then
                            goto continue 
                        end
                        if not record_map then
                            env.record_map = {map_obj.grid_x, map_obj.grid_y}
                        end
                        record_map = env.record_map
                        if record_map and name and poe2_api.table_contains(name,interaction_object_map_name) and record_map[1] ~= map_obj.grid_x and record_map[2] ~= map_obj.grid_y then
                            env.record_map = nil
                            env.map_result = nil
                            return bret.RUNNING
                        end
                        local map_distance = 30
                        if team_member_2 ~= "大號名" and poe2_api.table_contains(player_info.current_map_name_utf8,{"G3_12"}) then
                            map_distance = 25
                        end
                        if get_distance(record_map[1],record_map[2]) < map_distance then
                            if team_member_2 ~= "大號名" and poe2_api.table_contains(player_info.current_map_name_utf8,{"G3_12"}) then
                                return bret.SUCCESS
                            end
                            env.record_map = nil
                            if boss_name and #boss_name > 0 then
                                local boss_list = poe2_api.get_sorted_obj(boss_name,range_info,player_info)
                                if boss_list and #boss_list > 0 and boss_list[1].life >0 then
                                    local boss = boss_list[1]
                                    local toward_boss = poe2_api.move_towards({local_x,local_y},{boss.grid_x,boss.grid_y},20)
                                    api_ClickMove(poe2_api.toInt(toward_boss[1]),poe2_api.toInt(toward_boss[2]),0)
                                    api_Sleep(100)
                                    poe2_api.click_keyboard("space")
                                end
                                local toward_record_map = poe2_api.move_towards({local_x,local_y},{record_map[1],record_map[2]},20)
                                api_ClickMove(poe2_api.toInt(toward_record_map[1]),poe2_api.toInt(toward_record_map[2]),0)
                                api_Sleep(100)
                                poe2_api.click_keyboard("space")
                            end
                            env.is_arrive_end = true
                            return bret.SUCCESS
                        end
                        local record_map_near_point = api_FindNearestReachablePoint(record_map[1], record_map[2], 30, 0)
                        local player_near_point = api_FindNearestReachablePoint(local_x, local_y, 30, 0)
                        if not map_result then
                            map_result = true
                            env.map_result = true
                            self.path_result = api_FindPath(player_near_point.x, player_near_point.y, record_map_near_point.x, record_map_near_point.y)
                        end
                        if self.path_result and #self.path_result > 0 then
                            env.end_point = {record_map_near_point.x,record_map_near_point.y}
                            return bret.SUCCESS
                        else
                            env.not_need_active = true
                            return bret.RUNNING
                        end
                        ::continue::
                    end
                end
                env.record_map = nil
                map_result = nil
                env.map_result = nil
                self.path_result = nil
            end
            env.not_need_active = true
            poe2_api.time_p("[The_Interactive_Object_Exist]",(api_GetTickCount64() - current_time))
            return bret.RUNNING
        end
    },

    -- 交互
    Interactive = {
        run = function(self, env)
            poe2_api.dbgp("交互Interactive")
            poe2_api.print_log("交互")
            local interaction_object = env.interaction_object
            local player_info = env.player_info
            local range_info = env.range_info
            local current_map_info = env.current_map_info
            local UI_info = env.UI_info
            local team_member_2 = poe2_api.get_team_info(env.team_info,env.user_config,player_info,2)
            local function party_dis(actors, mini_map_name)
                local members = env.team_info_data
                if not members then
                    poe2_api.api_print("警告：未找到团队信息")
                    return false
                end
            
                local member_names = {}
                for _, m in ipairs(members) do
                    if m.name_utf8 ~= player_info.name_utf8 then
                        member_names[m.name_utf8] = true
                    end
                end
            
                local target = nil
                for _, o in ipairs(current_map_info) do
                    if o.name_utf8 == mini_map_name then
                        target = o
                        break
                    end
                end
            
                if not target then
                    return false
                end
            
                for _, actor in ipairs(actors) do
                    if member_names[actor.name_utf8] then
                        local distance = poe2_api.get_point_distance(actor.grid_x, actor.grid_y,target.grid_x, target.grid_y)
                        if distance > 25 then
                            return false
                        end
                    end
                end
            
                return true
            end
            if self.last_click_time == nil then
                self.last_click_time = 0
            end 
            if not interaction_object or #interaction_object == 0 then
                env.is_not_ui = true
                return bret.RUNNING 
            end
            if team_member_2 == "大號名" and poe2_api.table_contains("黑衣幽魂", interaction_object) then
                return bret.RUNNING
            end
            if team_member_2 == "小號名" and poe2_api.table_contains(interaction_object[1],{"石陣祭壇"}) then
                env.is_not_ui = true
                return bret.RUNNING
            end
            if team_member_2 == "小號名" and poe2_api.table_contains(interaction_object,"調查平台") then
                if not party_dis(range_info,"艾瓦") then
                    return bret.RUNNING
                end
            end
            if #interaction_object > 1 then
                api_Sleep(500)
                if interaction_object[2] == "艾瓦" then  -- Lua 索引从1开始
                    if poe2_api.find_text({UI_info = UI_info,text = interaction_object[1], min_x = 160,refresh = true}) then
                        api_Sleep(500)
                        poe2_api.find_text({UI_info = UI_info,text = interaction_object[1], click = 2, min_x = 160,refresh = true})
                        api_Sleep(500)
                    end
                end
                if poe2_api.find_text({UI_info = UI_info,text = interaction_object[2], min_x = 160,refresh = true}) then
                    api_Sleep(500)
                    poe2_api.find_text({UI_info = UI_info,text = interaction_object[2], click = 2, min_x = 160,refresh = true})
                    api_Sleep(500)
                end
                if #interaction_object > 2 then
                    if poe2_api.find_text({UI_info = UI_info,text = interaction_object[3], min_x = 160,refresh = true}) then
                        api_Sleep(500)
                        poe2_api.find_text({UI_info = UI_info,text = interaction_object[3], click = 2, min_x = 160,refresh = true})
                        api_Sleep(500)
                    end
                    if #interaction_object > 3 then
                        if poe2_api.find_text({UI_info = UI_info,text = interaction_object[4], min_x = 160,refresh = true}) then
                            api_Sleep(500)
                            poe2_api.find_text({UI_info = UI_info,text = interaction_object[4], click = 2, min_x = 160,refresh = true})
                            api_Sleep(500)
                        end
                        if #interaction_object > 4 then
                            if poe2_api.find_text({UI_info = UI_info,text = interaction_object[5], min_x = 160,refresh = true}) then
                                api_Sleep(500)
                                poe2_api.find_text({UI_info = UI_info,text = interaction_object[5], click = 2, min_x = 160,refresh = true})
                                api_Sleep(500)
                            end
                        end
                        if #interaction_object > 5 then
                            if poe2_api.find_text({UI_info = UI_info,text = interaction_object[6], min_x = 160,refresh = true}) then
                                api_Sleep(500)
                                poe2_api.find_text({UI_info = UI_info,text = interaction_object[6], click = 2, min_x = 160,refresh = true})
                                api_Sleep(500)
                            end
                        end
                        if #interaction_object > 6 then
                            if poe2_api.find_text({UI_info = UI_info,text = interaction_object[7], min_x = 160,refresh = true}) then
                                api_Sleep(500)
                                poe2_api.find_text({UI_info = UI_info,text = interaction_object[7], click = 2, min_x = 160,refresh = true})
                                api_Sleep(500)
                            end
                        end
                    end
                end
            end
            if poe2_api.find_text({UI_info = UI_info,text = "繼續", min_x = 160,refresh = true,click = 2}) then
                poe2_api.click_keyboard("space")
                env.interaction_object = nil
                api_Sleep(500)
                return bret.SUCCESS
            end
            if poe2_api.find_text({UI_info = UI_info,text = "接受任務", min_x = 160,refresh = true,click = 2}) then
                api_Sleep(500)
                return bret.RUNNING
            end
            local ac = poe2_api.find_text({UI_info = UI_info,text = interaction_object[1], max_x=1347,min_x=160,position = 3,refresh = true})
            if ac and #ac > 0 then
                if poe2_api.table_contains(interaction_object[1],{"符文之印","壓桿"}) then
                    return bret.RUNNING
                end
                if self.last_click_time == 0 then
                    self.last_click_time = api_GetTickCount64()
                end
                if poe2_api.table_contains(interaction_object[1], {"石陣祭壇"}) and api_GetTickCount64() - self.last_click_time > 15*1000 then
                    self.last_click_time = 0
                    api_ClickScreen(poe2_api.toInt(ac[1].x),poe2_api.toInt(ac[1].y),0)
                    api_Sleep(200)
                    api_ClickScreen(poe2_api.toInt(ac[1].x),poe2_api.toInt(ac[1].y),1)
                    api_Sleep(500)
                    poe2_api.click_keyboard("space")
                elseif not poe2_api.table_contains(interaction_object[1], {"石陣祭壇"}) then
                    self.last_click_time = 0
                end
                poe2_api.find_text({UI_info = UI_info,text = interaction_object[1], click = 2, max_x=1347,max_y=775,min_x=160,refresh = true})
                api_Sleep(500)
                return bret.RUNNING
            end
            self.last_click_time = 0
            return bret.RUNNING
        end
    },

    Is_Follow_Move = {
        run = function(self, env)
            poe2_api.dbgp("跟随移动模块开始执行...")
            poe2_api.print_log("跟随移动模块开始执行...")
            local player_info = env.player_info
            local me_area = player_info.current_map_name_utf8
            local team_member_2 = poe2_api.get_team_info(env.team_info,env.user_config,player_info,2)
            if poe2_api.table_contains(team_member_2,{"大號名", "未知"}) or me_area == "G1_1" or poe2_api.find_text({ UI_info = env.UI_info,text = "抵達皆伐"}) then
                poe2_api.dbgp("大号不跟随")
                return bret.SUCCESS
            elseif string.find(me_area, "town") then
                poe2_api.dbgp("城镇不跟随")
                return bret.RUNNING
            elseif poe2_api.table_contains(me_area,{"G2_3a"}) then
                poe2_api.dbgp("特殊地图不跟随")
                return bret.SUCCESS
            else
                poe2_api.dbgp("跟随移动模块开始执行")
                return bret.FAIL
            end
        end
    },

    -- 是否与隊長距离过远
    Is_Far_Away_From_Capital = {
        run = function(self, env)
            poe2_api.dbgp("是否与队长距离过远模块开始执行...")
            poe2_api.print_log("是否与队长距离过远模块开始执行...")
            local player_info = env.player_info
            local range_info = env.range_info
            local team_member_3 = poe2_api.get_team_info(env.team_info,env.user_config,player_info,3)
            local point = nil
            for _, actor in ipairs(range_info) do
                if actor.name_utf8 == team_member_3 then
                    point = actor
                    break
                end
            end 
            if point and poe2_api.point_distance(point.grid_x, point.grid_y, player_info) < 70 then
                poe2_api.dbgp("与队长距离小与80")
                env.path_list_follow = {}
                env.end_point_follow = nil
                return bret.SUCCESS
            else
                poe2_api.dbgp("与队长距离过远")
                return bret.FAIL
            end
        end
    },

    -- 移动到近点大号位置
    Move_To_Near_Leader_Point = {
        run = function(self, env)
            poe2_api.dbgp("移动到近点大号位置模块开始执行...")
            poe2_api.print_log("移动到近点大号位置模块开始执行...")
            local player_info = env.player_info
            local range_info = env.range_info
            local team_member_3 = poe2_api.get_team_info(env.team_info,env.user_config,player_info,3)
            if self.timeout == nil then
                self.timeout = 8*1000
                self.bool = false
                self.current_time = 0
            end
            if self.current_time == 0 then
                self.current_time = api_GetTickCount64()
            end
            if api_GetTickCount64() - self.current_time > self.timeout then
                poe2_api.dbgp("移动到近点大号位置模块执行超时")
                local safe_point = api_GetSafeAreaLocation(env.player_info.grid_x, env.player_info.grid_y, 60, 10, 0, 0.5)
                api_ClickMove(poe2_api.toInt(safe_point.x), poe2_api.toInt(safe_point.y) , 0)
                api_Sleep(200)
                poe2_api.click_keyboard("space")
                self.current_time = 0
                return bret.RUNNING
            end

            local function check_pos(names)
                for _, actor in ipairs(range_info) do
                    if actor.name_utf8 == names then
                        return actor
                    end
                end
                return nil
            end
            local a = poe2_api.get_game_control_by_rect({UI_info = env.UI_info,min_x = 985,min_y = 5,max_x = 1034,max_y = 47})
            if poe2_api.find_text({UI_info = env.UI_info, text="記錄點", add_x = 213, max_y = 50}) and a and next(a) then
                poe2_api.find_text({UI_info = env.UI_info, text="記錄點", click=2, add_x = 213, max_y = 50})
                return bret.RUNNING
            end
            local target = check_pos(team_member_3)
            if target then
                if poe2_api.point_distance(target.grid_x, target.grid_y, player_info) <= 10 then
                    poe2_api.dbgp("与队长距离小于10")
                    env.path_list_follow = {}
                    local player_walk_point = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 30)
                    local dis = poe2_api.point_distance(player_walk_point.x, player_walk_point.y, player_info)
                    if dis >= 20 then
                        api_ClickMove(poe2_api.toInt(player_walk_point.x), poe2_api.toInt(player_walk_point.y) , 0)
                        api_Sleep(200)
                        poe2_api.click_keyboard("space")
                        return bret.RUNNING
                    end
                    self.bool = false
                    self.current_time = 0
                    return bret.RUNNING
                elseif poe2_api.point_distance(target.grid_x, target.grid_y, player_info) <= 30 then
                    poe2_api.dbgp("与队长距离小于30")
                    env.path_list_follow = {}
                    local safe_point = api_GetSafeAreaLocation(env.player_info.grid_x, env.player_info.grid_y, 60, 10, 0, 0.5)
                    api_ClickMove(poe2_api.toInt(safe_point.x), poe2_api.toInt(safe_point.y) , 7)
                    self.bool = false
                    api_Sleep(200)
                    self.current_time = 0
                    return bret.RUNNING
                elseif poe2_api.point_distance(target.grid_x, target.grid_y, player_info) <= 60 then
                    poe2_api.dbgp("与队长距离小于60")
                    env.path_list_follow = {}
                    if not self.bool then
                        self.bool = true
                        poe2_api.click_keyboard("shift")
                    end
                    self.current_time = 0
                    return bret.RUNNING
                elseif poe2_api.point_distance(target.grid_x, target.grid_y, player_info) <= 70 then
                    poe2_api.dbgp("与队长距离小于70")
                    self.bool = false
                    self.current_time = 0
                    api_ClickMove(poe2_api.toInt(target.x), poe2_api.toInt(target.y) , 0)
                    api_Sleep(200)
                    api_ClickMove(poe2_api.toInt(target.x), poe2_api.toInt(target.y) , 7)
                    api_Sleep(200)
                    return bret.RUNNING
                end
            end
            return bret.RUNNING
        end
    },

    -- 跟随移动获取路径
    GET_Path_Follow = {
        run = function(self, env)
            poe2_api.dbgp("跟随移动获取路径模块开始执行...")
            poe2_api.print_log("跟随移动获取路径模块开始执行...")
            local player_info = env.player_info
            local range_info = env.range_info
            local current_time = api_GetTickCount64()
            local path_list_follow = env.path_list_follow
            if path_list_follow and #path_list_follow > 0 then
                poe2_api.dbgp("跟随移动有路径")
                poe2_api.time_p("GET_Path_Follow",api_GetTickCount64()-current_time)
                return bret.SUCCESS
            end
            local team_member_3 = poe2_api.get_team_info(env.team_info,env.user_config,player_info,3)
            local function check_pos(names)
                for _, actor in ipairs(range_info) do
                    if actor.name_utf8 == names then
                        return actor
                    end
                end
                return nil
            end
            local target = check_pos(team_member_3)
            if not target then
                poe2_api.dbgp("没有目标：大号")
                return bret.RUNNING
            end
            local reachable_point = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y,50, 0)
            local target_reachable_point = api_FindNearestReachablePoint(target.grid_x, target.grid_y,40,0)
            local result = api_FindPath(reachable_point.x, reachable_point.y, target_reachable_point.x, target_reachable_point.y)
            if result and #result > 0 then
                poe2_api.dbgp("跟随移动获取路径成功")
                local coordinates = poe2_api.extract_coordinates(result, 22)
                env.path_list_follow = coordinates
                table.remove(coordinates, 1)
                env.target_point_follow = {coordinates[1].x, coordinates[1].y}
            else
                poe2_api.dbgp("跟随移动获取路径失败")
                local arena_list =poe2_api.get_sorted_obj("競技場",range_info,player_info)
                if arena_list and #arena_list > 0 and arena_list[1].hasLineOfSight and arena_list[1].is_selectable then
                    local arena_list_path = api_FindPath(reachable_point.x, reachable_point.y, arena_list[1].grid_x, arena_list[1].grid_y)
                    if arena_list_path and #arena_list_path > 0 then
                        local coordinates = poe2_api.extract_coordinates(arena_list_path, 22)
                        env.path_list_follow = coordinates
                        if #coordinates > 1 then
                            table.remove(coordinates, 1)
                        end
                        env.target_point_follow = {coordinates[1].x, coordinates[1].y}
                    end
                elseif arena_list and #arena_list > 0 and not arena_list[1].hasLineOfSight then
                    api_RestoreOriginalMap()
                else
                    local player_walk_point = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 30)
                    api_ClickMove(poe2_api.toInt(player_walk_point.x), poe2_api.toInt(player_walk_point.y) , 7)
                end
                api_ClickMove(poe2_api.toInt(reachable_point.x), poe2_api.toInt(reachable_point.y) , 7)
                api_RestoreOriginalMap()
                return bret.RUNNING
            end
            poe2_api.time_p("GET_Path_Follow",api_GetTickCount64()-current_time)
            return bret.SUCCESS
        end
    }, 

    -- 移动到远点大号位置
    Move_To_Far_Leader_Point = {
        run = function(self, env)
            poe2_api.dbgp("移动到远点大号位置模块开始执行...")
            poe2_api.print_log("移动到远点大号位置模块开始执行...")
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            local range_info = env.range_info
            local path_list_follow = env.path_list_follow
            local team_member_3 = poe2_api.get_team_info(env.team_info, env.user_config, player_info, 3)
            local point = env.target_point_follow
            local move_interval = math.random() * 0.2 + 0.2

            poe2_api.dbgp(string.format("玩家信息: 地图=%s, 生命=%d, 坐标=(%d,%d)", 
                player_info.current_map_name_utf8 or "未知", 
                player_info.life or 0, 
                player_info.grid_x or 0, 
                player_info.grid_y or 0))
            poe2_api.dbgp(string.format("目标点: %s", point and string.format("(%d,%d)", point[1], point[2]) or "无"))
            poe2_api.dbgp(string.format("队伍成员3: %s", team_member_3 or "无"))
            poe2_api.dbgp(string.format("移动间隔: %.2f秒", move_interval))

            if self.timeout == nil then
                poe2_api.dbgp("初始化超时参数")
                self.last_move_time = api_GetTickCount64()
                self.timeout = 6 * 1000
                self.current_time = 0
                self.last_point_time = 0
                self.movement_threshold = 15
                self.special_maps = {"G1_6", "G3_2_2", "G3_12"}
                poe2_api.dbgp(string.format("超时设置: timeout=%dms, threshold=%d", self.timeout, self.movement_threshold))
            end

            if env.roll_time == nil or self.current_time == 0 then
                poe2_api.dbgp("设置翻滚时间基准")
                self.current_time = api_GetTickCount64()
            end

            if env.exit_time == nil or self.last_point_time == 0 then
                poe2_api.dbgp("设置退出时间基准")
                self.last_point_time = api_GetTickCount64()
            end

            local function check_pos(names)
                poe2_api.dbgp(string.format("在范围信息中查找角色: %s", names))
                for _, actor in ipairs(range_info) do
                    if actor.name_utf8 == names then
                        poe2_api.dbgp(string.format("找到角色: %s, 坐标=(%d,%d)", names, actor.grid_x or 0, actor.grid_y or 0))
                        return actor
                    end
                end
                poe2_api.dbgp(string.format("未找到角色: %s", names))
                return nil
            end

            env.roll_time = math.abs(current_time - self.current_time)
            env.exit_time = math.abs(current_time - self.last_point_time)

            if env.roll_time > self.timeout and not player_info.isMoving and player_info.life > 0 then
                poe2_api.dbgp("移动到远点大号位置模块超时翻滚")
                
                local function get_range()
                    local valid_objects = {
                        "甕", "壺", "屍體", "巢穴", "籃子", "小雕像", "石塊",
                        "鬆動碎石", "瓶子", "盒子", "腐爛木材", "保險箱", "腐爛木材"
                    }
                    
                    poe2_api.dbgp("开始查找可交互对象")
                    local sorted_range = poe2_api.get_sorted_list(env.range_info, env.player_info)
                    if not sorted_range then
                        poe2_api.dbgp("警告: 无法获取排序后的范围列表")
                        return false
                    end

                    poe2_api.dbgp(string.format("检查 %d 个范围内的对象", #sorted_range))
                    
                    for _, obj in ipairs(sorted_range) do
                        poe2_api.dbgp(string.format("检查对象: %s (类型: %s, 激活: %s, 可选: %s, 坐标=(%d,%d))", 
                            obj.name_utf8 or "无名", 
                            obj.type or "未知", 
                            tostring(obj.isActive), 
                            tostring(obj.is_selectable),
                            obj.grid_x or 0,
                            obj.grid_y or 0))
                        
                        if obj.name_utf8 and 
                        poe2_api.table_contains(valid_objects, obj.name_utf8) and
                        obj.isActive and 
                        obj.is_selectable and
                        obj.grid_x and obj.grid_y then
                            
                            local obj_distance = poe2_api.point_distance(obj.grid_x, obj.grid_y, player_info)
                            if obj_distance then
                                poe2_api.dbgp(string.format("对象 %s 距离: %.2f", obj.name_utf8, obj_distance))
                                
                                if obj_distance <= 20 then
                                    poe2_api.dbgp("找到符合条件的交互对象: " .. obj.name_utf8)
                                    return obj
                                end
                            end
                        end
                    end
                    
                    poe2_api.dbgp("未找到符合条件的交互对象")
                    return false
                end
                
                local target = get_range()
                if target then
                    poe2_api.dbgp(string.format("与对象交互: %s, 坐标=(%d,%d)", target.name_utf8, target.grid_x, target.grid_y))
                    api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y),  0)
                    api_Sleep(500)
                    api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y),  1)
                    api_Sleep(500)
                    poe2_api.find_text({UI_info = env.UI_info, text = target.name_utf8, click = 2, refresh = true, min_x = 0})
                    api_Sleep(500)
                else
                    poe2_api.dbgp("没有找到可交互对象，尝试向队长移动")
                end
                
                local leader = check_pos(team_member_3)
                if leader then
                    local leader_point = poe2_api.move_towards({player_info.grid_x, player_info.grid_y}, {leader.grid_x, leader.grid_y}, 20)
                    api_ClickMove(poe2_api.toInt(leader_point[1]), poe2_api.toInt(leader_point[2]),  0)
                    api_Sleep(500)
                    poe2_api.click_keyboard("space")
                end
                
                env.path_list_follow = {}
                env.target_point_follow = nil
                return bret.RUNNING
                
            elseif player_info.isMoving or player_info.life == 0 then
                poe2_api.dbgp("重置翻滚时间: 移动距离超过阈值或玩家死亡")
                env.roll_time = nil                
            end

            if env.exit_time > 60 * 1000 and not player_info.isMoving and player_info.life > 0 then
                poe2_api.dbgp("移动到远点大号位置模块超时小退")
                env.exit_time = nil
                if not poe2_api.table_contains(self.special_maps, player_info.current_map_name_utf8) and 
                    player_info.life > 0 and 
                    not poe2_api.is_have_mos({range_info = range_info, player_info = player_info}) and 
                    not player_info.isInBossBattle then
                    poe2_api.dbgp("满足小退条件，执行小退")
                    env.is_timeout_exit = true
                    return bret.RUNNING
                else
                    poe2_api.dbgp("不满足小退条件")
                end
            elseif player_info.isMoving or player_info.life == 0 then
                poe2_api.dbgp("重置退出时间: 移动距离超过阈值或玩家死亡")
                env.exit_time = nil    
            end

            -- 执行移动（按时间间隔）
            if current_time - self.last_move_time >= move_interval * 1000 then
                poe2_api.dbgp("执行移动检查")
                if point then
                    local dis = poe2_api.point_distance(point[1], point[2], player_info)
                    poe2_api.dbgp(string.format("目标点距离: %.2f, 坐标=(%d,%d)", dis or 0, point[1], point[2]))
                    
                    if dis and dis > 70 then
                        poe2_api.print_log("清路径10101")
                        poe2_api.dbgp("距离过远，清除路径并寻找再会点")
                        poe2_api.find_text({ UI_info = env.UI_info, text = "再會", click = 2 })
                        env.target_point_follow = nil
                        env.path_list_follow = {}
                        return bret.RUNNING
                    end
                    poe2_api.dbgp("----点击移动----")
                    if not api_ClickMove(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]), 7) then
                        env.path_list_follow = {}
                        env.target_point_follow = nil
                        poe2_api.time_p("执行移动(RUNNING4) 耗时 -->", api_GetTickCount64() - current_time)
                        return bret.RUNNING
                    end
                    self.last_move_time = current_time
                else
                    poe2_api.dbgp("无目标点，无法移动")
                end
            end

            if point then
                poe2_api.dbgp("检查是否到达目标点")
                local reach_point = api_FindNearestReachablePoint(point[1], point[2], 15, 1)
                local reach_distance = poe2_api.point_distance(reach_point.x, reach_point.y, player_info)
                poe2_api.dbgp(string.format("最近可达点距离: %.2f", reach_distance or 0))
                
                if reach_distance < 25 then
                    poe2_api.dbgp("已接近目标点，更新路径")
                    if env.path_list_follow and #env.path_list_follow > 0 then
                        local new_point = {env.path_list_follow[1].x, env.path_list_follow[1].y}
                        env.target_point_follow = new_point
                        table.remove(env.path_list_follow, 1)
                        poe2_api.dbgp(string.format("新目标点: (%d,%d)", new_point[1], new_point[2]))
                    end
                    poe2_api.time_p("[Move_To_Far_Leader_Point]",(api_GetTickCount64() - current_time))
                    return bret.RUNNING
                end
                env.last_position_story = {player_info.grid_x, player_info.grid_y}
            end

            poe2_api.dbgp("移动模块执行完成")
            poe2_api.time_p("[Move_To_Far_Leader_Point]",(api_GetTickCount64() - current_time))
            return bret.RUNNING
        end
    },

    -- 区域移动
    Check_Target_Point = {
        run = function(self, env)
            poe2_api.dbgp("区域移动模块开始执行...")
            poe2_api.print_log("区域移动模块开始执行...")
            local player_info = env.player_info
            local current_map_info = env.current_map_info
            local current_map = player_info.current_map_name_utf8
            local entrancelist = env.entrancelist
            local interaction_object = env.interaction_object
            local interaction_object_map_name = env.interaction_object_map_name
            local range_info = env.range_info
            local boss_name = env.boss_name
            local path_list = env.path_list
            local current_time = api_GetTickCount64()
            local team_member_2 = poe2_api.get_team_info(env.team_info,env.user_config,player_info,2)
            local special_maps_1 = {"G1_15","G3_12" }
            local special_maps_2 = current_map
            local special_maps_3 = {"G3_2_2"}
            local exclude_items = {"門", "中型靈魂核心", "壓桿","瘋狂讚美詩"}
            local point = nil
            local UI_info = env.UI_info

            -- 检查两个表 t1 和 t2 是否有共同的元素
            local function has_common_element(t1, t2)
                if t1 == nil or t2 == nil or type(t1) ~= "table" or type(t2) ~= "table" then
                    return false
                end
                for _, v1 in ipairs(t1) do
                    for _, v2 in ipairs(t2) do
                        if v1 == v2 then return true end
                    end
                end
                return false
            end
            if path_list and #path_list > 1 then
                poe2_api.dbgp("[Check_Target_Point] path_list有路径")
                return bret.SUCCESS
            end
            if player_info.isInBossBattle and poe2_api.is_have_boss_distance(range_info, player_info,boss_name,100) then
                poe2_api.dbgp("检测到boss")
                return bret.RUNNING
            end
            if poe2_api.table_contains(current_map,my_game_info.hideout) then
                poe2_api.dbgp("在城镇")
                return bret.RUNNING
            end
            if interaction_object and not has_common_element(exclude_items, interaction_object) then
                poe2_api.dbgp("[check_target_point]检测到交互对象")
                if poe2_api.find_text({ UI_info = UI_info, text = interaction_object[1] }) and (team_member_2 == "大號名" or current_map == "G1_1") then
                    env.end_point = nil
                    env.is_arrive_end = true
                    return bret.SUCCESS
                end
            end
            if interaction_object_map_name then
                poe2_api.dbgp("[check_target_point]检测到小地图对象")
                for _,actor in ipairs(current_map_info) do
                    if actor.name_utf8 and poe2_api.table_contains(actor.name_utf8, interaction_object_map_name) and 
                        not poe2_api.table_contains('RitualRune', interaction_object_map_name) then
                        if poe2_api.point_distance(actor.grid_x, actor.grid_y, player_info) < 50 then
                            env.end_point = nil
                            env.is_arrive_end = true
                            return bret.SUCCESS
                        end
                    end
                end
            end
            if poe2_api.table_contains(team_member_2,{"大號名","未知"}) then
                poe2_api.dbgp("设置大号探索范围")
                special_map = {"G1_2","G1_12","G1_13_1","G1_13_2","G1_15",
                        "G2_2","G2_4_1","G2_6","G2_8","G2_9_2","G2_9_1",
                        "G3_2_2","G3_3","G3_6_1","G3_7","G3_12","G3_17",
                }
                if poe2_api.table_contains(special_map,current_map) then
                    if poe2_api.table_contains(current_map,{"G3_2_2","G2_9_1","G3_6_1"}) then
                        poe2_api.dbgp("大号探索范围50")
                        point = api_GetUnexploredArea(50)
                    end
                    poe2_api.dbgp("大号探索范围70")
                    point = api_GetUnexploredArea(70)
                else
                    poe2_api.dbgp("大号探索范围100")
                    point = api_GetUnexploredArea(100)
                end
            else
                poe2_api.dbgp("设置小号探索范围")
                point = api_GetUnexploredArea(100)
            end
            if not point then
                poe2_api.dbgp("没有找到未探索区域")
                return bret.RUNNING
            end
            if point.x == -1 and point.y == -1 then
                poe2_api.dbgp("探索区域已探索完毕")
                -- while true do
                --     api_Sleep(1)
                -- end
                -- if poe2_api.table_contains(current_map, special_maps_1) then
                --     poe2_api.dbgp("检测到特殊地图[special_maps_1]，重新设置探索区域")
                    
                --     if not entrancelist or #entrancelist == 0 then
                --         poe2_api.dbgp("入口列表为空，开始收集入口和检查点信息")
                --         local chickpointlist = {}
                        
                --         -- 获取入口和检查点actor
                --         local entr_actors = {}
                --         local chk_actors = {}
                        
                --         for _, a in ipairs(current_map_info) do
                --             if a.name_utf8 == "Entrance" and a.grid_x and a.grid_y then
                --                 table.insert(entr_actors, a)
                --             elseif a.name_utf8 == "Checkpoint" and a.grid_x and a.grid_y then
                --                 table.insert(chk_actors, a)
                --             end
                --         end
                        
                --         poe2_api.dbgp("找到 " .. #entr_actors .. " 个入口点和 " .. #chk_actors .. " 个检查点")
                        
                --         -- 填充入口列表
                --         entrancelist = {}
                --         for _, a in ipairs(entr_actors) do
                --             table.insert(entrancelist, {a.grid_x, a.grid_y})
                --         end
                        
                --         -- 填充检查点列表
                --         for _, a in ipairs(chk_actors) do
                --             table.insert(chickpointlist, {a.grid_x, a.grid_y})
                --         end
                        
                --         poe2_api.dbgp("入口列表数量: " .. #entrancelist .. ", 检查点列表数量: " .. #chickpointlist)
                        
                --         -- 移除靠近检查点的入口点
                --         local remove_points = {}
                --         for _, p1 in ipairs(entrancelist) do
                --             for _, p2 in ipairs(chickpointlist) do
                --                 if poe2_api.get_point_distance(p1[1], p1[2], p2[1], p2[2]) < 100 then
                --                     table.insert(remove_points, p1)
                --                     poe2_api.dbgp("移除靠近检查点的入口: (" .. p1[1] .. ", " .. p1[2] .. ")")
                --                     break
                --                 end
                --             end
                --         end
                        
                --         if #remove_points > 0 then
                --             poe2_api.dbgp("需要移除 " .. #remove_points .. " 个靠近检查点的入口")
                --             local new_entrancelist = {}
                --             for _, p in ipairs(entrancelist) do
                --                 local should_remove = false
                --                 for _, rp in ipairs(remove_points) do
                --                     if p[1] == rp[1] and p[2] == rp[2] then
                --                         should_remove = true
                --                         break
                --                     end
                --                 end
                --                 if not should_remove then
                --                     table.insert(new_entrancelist, p)
                --                 end
                --             end
                --             entrancelist = new_entrancelist
                --             poe2_api.dbgp("移除后剩余入口数量: " .. #entrancelist)
                --         end
                --     else
                --         poe2_api.dbgp("使用现有入口列表，数量: " .. #entrancelist)
                --     end
                    
                --     -- 入口路径处理
                --     poe2_api.dbgp("开始处理 " .. #entrancelist .. " 个入口路径")
                --     local processed_entrances = {}
                    
                --     for i, entrance in ipairs(entrancelist) do
                --         if not entrance or #entrance ~= 2 then
                --             poe2_api.dbgp("跳过无效入口点 #" .. i)
                --             goto continue
                --         end
                        
                --         poe2_api.dbgp("处理入口点 #" .. i .. ": (" .. entrance[1] .. ", " .. entrance[2] .. ")")
                        
                --         -- 路径查找
                --         local path_result = api_FindPath(player_info.grid_x, player_info.grid_y, entrance[1], entrance[2])
                --         if path_result and #path_result > 0 then
                --             poe2_api.dbgp("找到到入口点 #" .. i .. " 的路径")
                --             env.end_point = {entrance[1], entrance[2]}
                --             env.is_arrive_end = false
                            
                --             -- 距离和UI检测
                --             local dist_check = poe2_api.point_distance(entrance[1], entrance[2], player_info) < 50
                --             local ui_check = false
                            
                --             -- 检查UI文本
                --             local ui_texts = {"樓梯", "門", "競技場"}
                --             for _, text in ipairs(ui_texts) do
                --                 if poe2_api.find_text({UI_info = UI_info, text = text}) then
                --                     ui_check = true
                --                     poe2_api.dbgp("检测到UI文本: " .. text)
                --                     break
                --                 end
                --             end
                            
                --             if dist_check and ui_check then
                --                 poe2_api.dbgp("到达入口点 #" .. i .. " 并检测到UI，移除该入口")
                --                 table.insert(processed_entrances, i)
                --                 if #entrancelist == #processed_entrances then
                --                     poe2_api.dbgp("所有入口点都已处理，重新初始化探索区域")
                --                     api_InitExplorationArea()
                --                 end
                --                 env.entrancelist = entrancelist
                --                 return bret.RUNNING
                --             elseif dist_check and not ui_check then
                --                 poe2_api.dbgp("到达入口点 #" .. i .. " 但未检测到UI，移除该入口")
                --                 table.insert(processed_entrances, i)
                --                 if #entrancelist == #processed_entrances then
                --                     poe2_api.dbgp("所有入口点都已处理，重新初始化探索区域")
                --                     api_InitExplorationArea()
                --                 end
                --                 env.entrancelist = entrancelist
                --                 return bret.RUNNING
                --             else
                --                 poe2_api.dbgp("未到达入口点 #" .. i .. "，继续移动")
                --                 env.entrancelist = entrancelist
                --             end
                            
                --             return bret.SUCCESS
                --         else
                --             poe2_api.dbgp("无法找到到入口点 #" .. i .. " 的直接路径，尝试寻找附近可达点")
                            
                --             -- 随机移动处理
                --             local round_pos = api_FindNearestReachablePoint(entrance[1], entrance[2], 50, 0)
                --             if round_pos then
                --                 local rx, ry = round_pos.x, round_pos.y
                --                 poe2_api.dbgp("找到附近可达点: (" .. rx .. ", " .. ry .. ")")
                                
                --                 local round_result = api_FindPath(player_info.grid_x, player_info.grid_y, rx, ry)
                                
                --                 if not round_result then
                --                     poe2_api.dbgp("无法到达附近可达点，移除入口点 #" .. i)
                --                     table.insert(processed_entrances, i)
                --                     if #entrancelist == #processed_entrances then
                --                         poe2_api.dbgp("所有入口点都已处理，重新初始化探索区域")
                --                         api_InitExplorationArea()
                --                     end
                --                     env.entrancelist = entrancelist
                --                     return bret.RUNNING
                --                 else
                --                     poe2_api.dbgp("设置目标点为附近可达点: (" .. rx .. ", " .. ry .. ")")
                --                     env.end_point = {rx, ry}
                --                 end
                                
                --                 return bret.SUCCESS
                --             else
                --                 poe2_api.dbgp("无法找到入口点 #" .. i .. " 的附近可达点")
                --             end
                --         end
                        
                --         ::continue::
                --     end
                    
                --     -- 移除已处理的入口
                --     if #processed_entrances > 0 then
                --         poe2_api.dbgp("移除 " .. #processed_entrances .. " 个已处理的入口点")
                --         local new_entrancelist = {}
                --         for i, entrance in ipairs(entrancelist) do
                --             local should_remove = false
                --             for _, idx in ipairs(processed_entrances) do
                --                 if i == idx then
                --                     should_remove = true
                --                     break
                --                 end
                --             end
                --             if not should_remove then
                --                 table.insert(new_entrancelist, entrance)
                --             end
                --         end
                --         entrancelist = new_entrancelist
                --         poe2_api.dbgp("移除后剩余入口数量: " .. #entrancelist)
                --     end
                    
                --     env.entrancelist = entrancelist
                --     poe2_api.dbgp("入口路径处理完成，继续运行")
                --     return bret.RUNNING
                -- end
                if poe2_api.table_contains(current_map, special_maps_3) then
                    api_RestoreOriginalMap()
                    local walk_point = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 200)
                    if walk_point and #walk_point > 0 and walk_point.x == -1 then
                        api_ClickMove(poe2_api.toInt(walk_point.x), poe2_api.toInt(walk_point.y),7)
                    end 
                    local point = api_GetUnexploredArea(50)
                    if point and #point > 0 and point.x == -1 then
                        api_InitExplorationArea()
                    end
                    api_Sleep(100)
                    return bret.RUNNING
                end
                -- 石碑处理
                if interaction_object and poe2_api.table_contains(interaction_object, "鐵鏽方尖碑") then
                    if not entrancelist or #entrancelist == 0 then
                        -- 初始化入口列表
                        poe2_api.dbgp("初始化鐵鏽方尖碑入口列表")
                        entrancelist = {}
                        for _, a in ipairs(current_map_info) do
                            if a.name_utf8 == "RustObeliskInactive" then
                                table.insert(entrancelist, {a.grid_x, a.grid_y})
                            end
                        end
                        
                        -- 过滤距离玩家太近的点
                        poe2_api.dbgp("过滤距离玩家过近的入口点")
                        local filtered_list = {}
                        for _, p in ipairs(entrancelist) do
                            if poe2_api.point_distance(p[1], p[2], player_info) >= 100 then
                                table.insert(filtered_list, p)
                            end
                        end
                        entrancelist = filtered_list
                    end
                    
                    -- 处理每个入口点
                    for i = #entrancelist, 1, -1 do
                        local entrance = entrancelist[i]
                        if not entrance then
                            poe2_api.dbgp("入口点为空，跳过")
                            goto continue
                        end
                        
                        -- 查找路径
                        poe2_api.dbgp(string.format("查找路径到入口点 (%d, %d)", entrance[1], entrance[2]))
                        local path_result = api_FindPath(player_info.grid_x, player_info.grid_y, entrance[1], entrance[2])
                        
                        if path_result and #path_result > 0 then
                            -- 设置终点
                            env.end_point = {entrance[1], entrance[2]}
                            env.is_arrive_end = false
                            
                            -- 检查距离和UI
                            local dist_check = poe2_api.point_distance(entrance[1], entrance[2], player_info) < 50
                            local ui_check = false
                            
                            -- 检查UI文本
                            local ui_texts = {"鐵鏽方尖碑"}
                            for _, text in ipairs(ui_texts) do
                                if poe2_api.find_text({UI_info = UI_info, text = text}) then
                                    ui_check = true
                                    break
                                end
                            end
                            
                            if dist_check and ui_check then
                                -- 到达目标点且有UI显示，移除该入口
                                poe2_api.dbgp("到达目标点且检测到UI，移除入口点")
                                table.remove(entrancelist, i)
                                if #entrancelist == 0 then
                                    api_InitExplorationArea()
                                end
                                env.entrancelist = entrancelist
                                return bret.RUNNING
                            elseif dist_check and not ui_check then
                                -- 到达目标点但无UI显示，移除该入口
                                poe2_api.dbgp("到达目标点但未检测到UI，移除入口点")
                                table.remove(entrancelist, i)
                                if #entrancelist == 0 then
                                    api_InitExplorationArea()
                                end
                                env.entrancelist = entrancelist
                                return bret.RUNNING
                            else
                                -- 未到达目标点，继续移动
                                poe2_api.dbgp("继续向目标点移动")
                                env.entrancelist = entrancelist
                                return bret.SUCCESS
                            end
                        else
                            -- 无法找到路径，尝试寻找附近可达点
                            poe2_api.dbgp("无法直接到达目标点，寻找附近可达点")
                            local round_pos = api_FindNearestReachablePoint(entrance[1], entrance[2], 50, 0)
                            
                            if round_pos then
                                local rx, ry = round_pos.x, round_pos.y
                                local round_result = api_FindPath(player_info.grid_x, player_info.grid_y, rx, ry)
                                
                                if not round_result then
                                    -- 无法到达附近点，移除该入口
                                    poe2_api.dbgp("无法到达附近点，移除入口点")
                                    table.remove(entrancelist, i)
                                    if #entrancelist == 0 then
                                        api_InitExplorationArea()
                                    end
                                    env.entrancelist = entrancelist
                                    return bret.RUNNING
                                else
                                    -- 设置附近点为终点
                                    poe2_api.dbgp("设置附近点为终点")
                                    bb.set("end_point", {rx, ry})
                                    return bret.SUCCESS
                                end
                            else
                                -- 找不到附近点，移除该入口
                                poe2_api.dbgp("找不到附近可达点，移除入口点")
                                table.remove(entrancelist, i)
                            end
                        end
                        
                        ::continue::
                    end
                    
                    return bret.RUNNING
                end
                if current_map == special_maps_2 then
                    -- 寻找随机可行走位置
                    local rand_pos = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                    if rand_pos then
                        poe2_api.dbgp("找到随机可行走位置，执行移动")
                        
                        -- 点击移动到随机位置
                        api_ClickMove(poe2_api.toInt(rand_pos.x), poe2_api.toInt(rand_pos.y),  7)
                        
                        -- 按下空格键（可能用于交互或确认）
                        poe2_api.click_keyboard("space")
                        -- 更新地图信息
                        api_InitExplorationArea()
                        
                        -- 记录时间信息并返回运行状态
                        return bret.RUNNING
                    end
                end
            else
                poe2_api.dbgp(point.x, point.y)
                env.end_point = {point.x, point.y}
                poe2_api.dbgp(env.is_arrive_end)
                poe2_api.time_p("check_target_point",(api_GetTickCount64()-current_time))
                return bret.SUCCESS
            end
        end
    },

    -- 清理遮挡页面
    Game_Block = {
        run = function(self, env)
            poe2_api.print_log("游戏阻挡处理模块开始执行...")
            poe2_api.dbgp("=== 开始处理游戏阻挡 ===")

            local current_time = api_GetTickCount64()

            local player_info = env.player_info

            -- 检查交易拒绝情况
            local refuse_click = { "等待玩家接受交易請求..." }
            if poe2_api.find_text({ UI_info = env.UI_info, text = refuse_click, min_x = 0, add_x = 253, click = 2 }) then
                poe2_api.dbgp("检测到交易请求等待，将执行拒绝操作")
                return bret.RUNNING
            end

            ---常驻
            local all_check = {
                { UI_info = env.UI_info, text = "繼續遊戲", add_x = 0, add_y = 0, click = 2 },
                { UI_info = env.UI_info, text = "寶石切割", add_x = 280, add_y = 17, click = 2 },
                { UI_info = env.UI_info, text = "技能", min_x = 0, max_y = 81,add_x = 253, click = 2 },
            }
            -- 检查单个按钮
            for _, check in ipairs(all_check) do
                if poe2_api.find_text(check) then
                    poe2_api.dbgp(string.format("检测到按钮: %s，将执行点击操作", check.text))
                    return bret.RUNNING
                end
            end


            if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                poe2_api.click_keyboard("i")
                api_Sleep(500)
                return bret.RUNNING
            end

            if poe2_api.find_text({ UI_info = env.UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2 }) then
                return bret.RUNNING
            end

            -- 检查顶部中间页面按钮
            local top_mid_page = { "傳送" }
            if poe2_api.find_text({ UI_info = env.UI_info, text = top_mid_page, min_x = 0,max_y=30, add_x = 215, click = 2 }) then
                return bret.RUNNING
            end
            local a = poe2_api.get_game_control_by_rect({UI_info = env.UI_info,min_x = 985,min_y = 5,max_x = 1034,max_y = 47})
            if poe2_api.find_text({UI_info = env.UI_info, text="記錄點", add_x = 213, max_y = 50}) and a and next(a) then
                poe2_api.find_text({UI_info = env.UI_info, text="記錄點", click=2, add_x = 213, max_y = 50})
                return bret.RUNNING
            end
            -- 按键
            if not self.once_check then
                api_Log("检查是否在主页面11111")
                local once_check = {
                    { UI_info = env.UI_info, text = "精選", add_x = 677, min_x = 0, add_y = 10, click = 2 },
                    { UI_info = env.UI_info, text = "角色", min_x = 0, add_x = 253, click = 2 },
                    { UI_info = env.UI_info, text = "活動", min_x = 0, add_x = 253, click = 2 },
                    { UI_info = env.UI_info, text = "選項", min_x = 0, add_x = 253, click = 2 },
                    { UI_info = env.UI_info, text = "重置天賦點數", min_x = 0, add_x = 215, click = 2 },
                    { UI_info = env.UI_info, text = "天賦技能", min_x = 0, add_x = 215, click = 2 },
                    { UI_info = env.UI_info, text = "黯幣", min_x = 0, min_y = 0, max_y = 81, add_x = 673, add_y = 4, click = 2 },
                    { UI_info = env.UI_info, text = "願望清單", min_x = 0, min_y = 0, max_y = 81, add_x = 673, add_y = 4, click = 2 },

                }
                -- 检查单个按钮
                for _, check in ipairs(once_check) do
                    if poe2_api.find_text(check) then
                        poe2_api.dbgp(string.format("检测到按钮: %s，将执行点击操作", check.text))
                        return bret.RUNNING
                    end
                end
                self.once_check = true
            end

            -- 藏身处特殊处理
            local current_map_info = env.current_map_info
            local function is_map_device(obj_list)
                if not obj_list or #obj_list == 0 then
                    return false
                end
                for _, i in ipairs(obj_list) do
                    if i.name_utf8 == "MapDevice" then
                        return true
                    end
                end
                return false
            end
            local map = is_map_device(current_map_info)
            if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and map then
                poe2_api.dbgp("当前位于藏身处")

                -- 检测地图启动失败情况
                if poe2_api.find_text({ UI_info = env.UI_info, text = "啟動失敗。地圖無法進入。" }) then
                    poe2_api.dbgp("检测到地图启动失败提示，设置need_SmallRetreat为true")
                    env.need_SmallRetreat = true
                    return bret.RUNNING
                end

                local reward_click = { "任務獎勵", "獎勵" }
                if poe2_api.find_text({ UI_info = env.UI_info, text = reward_click, min_x = 100 }) then
                    poe2_api.dbgp("检测到奖励提示，将执行点击操作")
                    poe2_api.find_text({ UI_info = env.UI_info, text = reward_click, min_x = 0, add_y = 100, click = 2 })
                    if poe2_api.find_text({text = "背包",UI_info = env.UI_info, min_x = 1020,min_y=32,max_x=1600,max_y=81}) then
                        local point = poe2_api.get_space_point({ width = 2, height = 2, index = 1 })
                        if point then
                            api_ClickScreen(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]), 1)
                            return bret.RUNNING
                        else
                            return bret.SUCCESS
                        end
                    else
                        poe2_api.click_keyboard("i")
                        return bret.RUNNING
                    end
                end

                --- 藏身处
                local in_safe = {
                    { UI_info = env.UI_info, text = "購買或販賣", add_x = 270, add_y = -9, click = 2 },
                    { UI_info = env.UI_info, text = "選擇藏身處", add_x = 516, click = 2 },
                    { UI_info = env.UI_info, text = "通貨交換", add_x = 300, click = 2 },
                    { UI_info = env.UI_info, text = "重組", add_x = 210, add_y = -50, click = 2 },
                    { UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", add_x = 240, min_x = 0, click = 2 },
                    { UI_info = env.UI_info, text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片", add_x = 160, add_y = -60, min_x = 0, click = 2 },
                    { UI_info = env.UI_info, text = "世界地圖", min_x = 0, add_x = 215, click = 2 },
                }
                -- 检查单个按钮
                for _, check in ipairs(in_safe) do
                    if poe2_api.find_text(check) then
                        poe2_api.dbgp(string.format("检测到按钮: %s，将执行点击操作", check.text))
                        return bret.RUNNING
                    end
                end
                -- 检查背包保存提示
                local save_click = { "你無法將此背包丟置於此。請問要摧毀它嗎？" }
                if poe2_api.find_text({ UI_info = env.UI_info, text = save_click, min_x = 0, click = 2 }) then
                    poe2_api.dbgp("检测到背包保存提示，将执行保留操作")
                    return bret.RUNNING
                end
                -- 检查仓库页面
                local warehouse_page = { "倉庫", "聖域鎖櫃", "公會倉庫" }
                if poe2_api.find_text({ UI_info = env.UI_info, text = small_page, min_x = 0, add_x = 253 }) and
                    poe2_api.find_text({ UI_info = env.UI_info, text = "強調物品", min_x = 0 }) then
                    poe2_api.dbgp("检测到仓库页面，将执行点击操作")
                    poe2_api.find_text({ UI_info = env.UI_info, text = small_page, min_x = 0, click = 2, add_x = 253 })
                    return bret.RUNNING
                end

                local item = api_Getinventorys(0xd, 0)
                if item and next(item) then
                    local width = item[1].end_x - item[1].start_x
                    local height = item[1].end_y - item[1].start_y
                    local point = poe2_api.get_space_point({width=width, height=height})

                    poe2_api.dbgp(string.format("物品尺寸: 宽%d, 高%d", width, height))

                    if point then
                        poe2_api.dbgp(string.format("获取到空间点: (%d, %d)", point[1], point[2]))

                        if poe2_api.find_text("背包") then
                            poe2_api.dbgp("检测到背包文字，将执行点击操作")
                            api_ClickScreen(point[1], point[2])
                            api_Sleep(100)
                            api_ClickScreen(point[1], point[2], 1)
                            api_Sleep(500)
                        else
                            poe2_api.dbgp("未检测到背包文字，将按I键打开背包")
                            poe2_api.click_keyboard("i")
                        end
                        return bret.RUNNING
                    else
                        poe2_api.dbgp("警告: 无法获取物品空间点")
                    end
                else
                    poe2_api.dbgp("警告: 无法获取背包物品信息")
                end
            end

            poe2_api.dbgp("未检测到任何阻挡情况，模块返回SUCCESS状态")
            poe2_api.time_p("Game_Block 耗时 --> ", api_GetTickCount64() - current_time)
            return bret.SUCCESS
        end
    },

    -- 点击交互文本
    Click_Item_Text = {
        run = function(self, env)
            poe2_api.print_log("点击交互文本...")
            poe2_api.dbgp("点击交互文本...")
            local current_time = api_GetTickCount64()
            local interactive_object = env.interactive
            local player_info = env.player_info
            local current_map_info = env.current_map_info

            local path_list = env.path_list
            local need_item = env.need_item

            if not self.bool then
                self.is_click_z = false
                self.bool = true
            end

            -- 辅助函数定义
            local function check_in_map()
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

            local function check_in_range(object)
                for _, k in ipairs(env.range_info) do
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
                    if (k.name_utf8 == interactive_object or k.path_name_utf8 == interactive_object) and k.grid_x ~= 0 and k.grid_y ~= 0 and k.is_selectable then
                        return k
                    end
                end
                return nil
            end

            local function need_move(obj, dis)
                local text = obj.baseType_utf8 or obj.name_utf8
                local x, y
                local point
                if text == "門" then
                    point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y, 15, 1)
                    local ralet = api_FindPath(player_info.grid_x, player_info.grid_y, point.x, point.y)
                    if not ralet then
                        point = api_FindRandomWalkablePosition(obj.grid_x, obj.grid_y, 15)
                        x, y = point.x, point.y
                    else
                        x, y = point.x, point.y
                    end
                else
                    if not need_item then
                        point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y, 50, 0)
                        x, y = point.x, point.y
                    else
                        poe2_api.dbgp("dgdvjinbvdijsknvijbiihjbjkdv")
                        x, y = obj.grid_x, obj.grid_y
                    end
                end
                poe2_api.dbgp("移动目标点:", x, y)
                local distance = poe2_api.point_distance(x, y, player_info)
                poe2_api.dbgp("距离:", distance)
                if distance and distance > dis then
                    env.end_point = { x, y }
                    return { x, y }
                end
                return false
            end

            -- 主逻辑
            if type(interactive_object) == "string" then
                local map_obj = check_in_map()
                local range_obj = check_in_range()

                local target_obj = map_obj or range_obj
                if not target_obj then
                    poe2_api.dbgp("未找到对象")
                    return bret.FAIL
                end

                local distance = poe2_api.point_distance(target_obj.grid_x, target_obj.grid_y, player_info)
                poe2_api.dbgp("交互对象: " ..
                    target_obj.name_utf8 .. " | 位置: " .. target_obj.grid_x .. "," .. target_obj.grid_y .. " | 距离: " ..
                    distance)

                if need_move(target_obj, 15) then
                    poe2_api.dbgp("移动交互对象")
                    return bret.FAIL
                end

                poe2_api.dbgp("点击交互对象")

                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                    api_Sleep(1000)
                end

                if target_obj.name_utf8 == "MapDevice" then
                    local m_list = { "黃金製圖儀", "地圖裝置" }
                    api_Sleep(800)
                    local maps = check_in_range(
                        'Metadata/Terrain/Missions/Hideouts/Objects/MapDeviceVariants/ZigguratMapDevice')
                    if poe2_api.find_text({ UI_info = env.UI_info, text = '地圖裝置', click = 2, refresh = true }) then
                        api_Sleep(100)
                        return bret.RUNNING
                    end
                    if maps then
                        -- api_ClickMove(maps.grid_x, maps.grid_y, maps.world_z + 110, 0)
                        api_ClickMove(poe2_api.toInt(maps.grid_x), poe2_api.toInt(maps.grid_y), 0)
                        api_Sleep(800)
                    end
                    for _, i in ipairs(m_list) do
                        if poe2_api.find_text({ UI_info = env.UI_info, text = i, click = 2, refresh = true }) then
                            api_Sleep(100)
                            return bret.RUNNING
                        end
                    end
                end

                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and target_obj.name_utf8 ~= '傳送點' and not map_obj then
                    poe2_api.find_text({ UI_info = env.UI_info, text = interactive_object, click = 2, refresh = true })
                    api_Sleep(100)
                    return bret.RUNNING
                end

                if player_info.isMoving then
                    poe2_api.dbgp("等待静止")
                    api_Sleep(1000)
                    return bret.RUNNING
                end

                if not poe2_api.find_text({ UI_info = env.UI_info, text = interactive_object, click = 2, max_x = 1200, refresh = true }) then
                    api_ClickMove(poe2_api.toInt(target_obj.grid_x), poe2_api.toInt(target_obj.grid_y),1)
                end
                api_Sleep(100)
            else
                poe2_api.dbgp1("交互对象: " ..
                    interactive_object.name_utf8 .. " | 位置: " .. interactive_object.grid_x .. "," ..
                    interactive_object.grid_y)
                poe2_api.dbgp("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                local a = poe2_api.point_distance(interactive_object.grid_x, interactive_object.grid_x, env.player_info)
                poe2_api.dbgp("a:", a)
                local text = ""
                local ok, value = pcall(function()
                    return interactive_object.baseType_utf8
                end)
                if ok and value ~= nil then
                    text = interactive_object.baseType_utf8
                    -- text = ""
                else
                    text = interactive_object.name_utf8
                end
                poe2_api.dbgp("text:", text)
                local point = need_move(interactive_object, 30)
                if point then
                    poe2_api.dbgp("text1:", text)
                    -- poe2_api.dbgp("移动交互对象")
                    if env.path_list and next(env.path_list) then
                        local distence = poe2_api.point_distance(env.path_list[#env.path_list].x,
                            env.path_list[#env.path_list].y, point)
                        if distence and distence > 20 and text ~= "門" then
                            poe2_api.dbgp("交互目标点，不一致，清空路径")
                            poe2_api.print_log("清路径555")
                            env.path_list = {}
                        end
                    end
                    poe2_api.dbgp("text2:", text)
                    -- poe2_api.printTable(point)
                    return bret.FAIL
                end
                if player_info.isMoving then
                    poe2_api.dbgp("等待静止")
                    api_Sleep(200)
                    return bret.RUNNING
                end
                if interactive_object and (not text or text == "" or poe2_api.table_contains(text, { "門", "聖潔神殿" }) or not poe2_api.find_text({ text = text, UI_info = env.UI_info, min_x = 200, max_y = 750, match = 2, max_x = 1200, sorted = true, click = 2 })) then
                    if poe2_api.table_contains(text, { "門", "聖潔神殿" }) then
                        if text == "門" and poe2_api.find_text({ text = "出土遺物", UI_info = env.UI_info, min_x = 200, max_y = 750, match = 2, max_x = 1200, sorted = true }) then
                            poe2_api.click_keyboard("z")
                            self.is_click_z = true
                            return bret.RUNNING
                        end
                        api_ClickMove(poe2_api.toInt(interactive_object.grid_x),poe2_api.toInt(interactive_object.grid_y), 1)
                    else
                        if env.need_item and env.need_item == interactive_object then
                            api_ClickMove(poe2_api.toInt(interactive_object.grid_x),poe2_api.toInt(interactive_object.grid_y),  1)
                        else
                            local ok, value = pcall(function()
                                return interactive_object.path_name_utf8
                            end)
                            if ok and value ~= nil then
                                if string.find("Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable", interactive_object.path_name_utf8) then
                                    poe2_api.find_text({ text = "點擊以開始祭祀", UI_info = env.UI_info, min_x = 200, max_y = 750, match = 2, max_x = 1200, sorted = true, click = 2 })
                                else
                                    api_ClickMove(poe2_api.toInt(interactive_object.grid_x),poe2_api.toInt(interactive_object.grid_y),1)
                                end
                            else
                                api_ClickMove(poe2_api.toInt(interactive_object.grid_x),poe2_api.toInt(interactive_object.grid_y), 1)
                            end
                        end
                    end
                end
                if text == "門" then
                    api_Sleep(400)
                    if self.is_click_z then
                        poe2_api.click_keyboard("z")
                        self.is_click_z = false
                    end
                    api_UpdateMapObstacles(100)
                end
                if poe2_api.table_contains(text, { "水閘門控制桿", "把手" }) then
                    api_Sleep(500)
                    poe2_api.dbgp1("点击水闸门控制杆,等待目标")
                    poe2_api.dbgp1("wait_target: ", wait_target)
                    env.wait_target = true
                end
                local ok, value = pcall(function()
                    return interactive_object.path_name_utf8
                end)
                if ok and value ~= nil then
                    if string.find("Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable", interactive_object.path_name_utf8) then
                    end
                end
                poe2_api.print_log("清路径666")
                env.path_list = {}
                env.need_item = nil
                env.interactive = nil
                env.interaction_object = nil
                env.interactiontimeout = api_GetTickCount64()
                return bret.RUNNING
            end
            return bret.RUNNING
        end
    },

    -- 是否需要移动
    Is_Path_Move = {
        run = function(self, env)
            poe2_api.dbgp("是否需要移动(Is_Path_Move)...")
            poe2_api.print_log("是否需要移动(Is_Path_Move)...")
            if env.not_move then
                env.not_move = false
                return bret.SUCCESS
            end
            if env.is_arrive_end == true then
                env.end_point = nil
                poe2_api.dbgp("Is_Path_Move-清空路径")
                env.path_list = {}
                env.is_arrive_end = false
                return bret.SUCCESS
            end
            if not env.is_arrive_end then
                return bret.FAIL
            end
        end
    },

    -- 检查是否到达点(别名)
    Is_Arrive = {
        run = function(self, env)
            poe2_api.print_log("检查是否到达目标点(Is_Arrive)...")
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            local is_arrive_end_dis = 25 -- 默认值
            if player_info.life == 0 then
                poe2_api.dbgp("Is_Arrive-玩家死亡，清空路径")
                env.end_point = nil
                env.run_point = nil
                env.path_list = {}
                env.is_arrive_end = false
                env.target_point = {}
                -- return bret.FAIL
                poe2_api.dbgp("正在前往目标点...111222")
                return bret.RUNNING
            end

            -- 检查空路径
            if env.empty_path then
                env.is_arrive_end = true
                env.empty_path = false
                -- return bret.SUCCESS
                poe2_api.dbgp("正在前往目标点...111111")
                return bret.RUNNING
            end
            -- 检查是否到达终点
            local point = env.end_point
            poe2_api.printTable(point)
            if point and #point > 0 then
                dis = poe2_api.point_distance(point[1], point[2], player_info)
                poe2_api.dbgp("dis:", dis)
                poe2_api.dbgp("api_HasObstacleBetween:", api_HasObstacleBetween(point[1], point[2]))
                if api_HasObstacleBetween(point[1], point[2]) and dis and (dis < is_arrive_end_dis) then
                    poe2_api.dbgp1("有路径，有射线")
                    env.is_arrive_end = true
                    env.end_point = nil
                    env.path_list = {}
                    env.run_point = nil
                    poe2_api.time_p("检查是否到达目标点(Is_Arrive)(RUNNING1)... 耗时 --> ", api_GetTickCount64() - current_time)
                    return bret.RUNNING
                end
                env.is_arrive_end = false
                poe2_api.time_p("检查是否到达目标点(Is_Arrive)(SUCCESS2)... 耗时 --> ", api_GetTickCount64() - current_time)
                return bret.SUCCESS
            else
                poe2_api.dbgp("没有路径，没有射线")
                env.is_arrive_end = false
                env.path_list = {}
                poe2_api.time_p("检查是否到达目标点(mydian)(RUNNING)... 耗时 --> ", api_GetTickCount64() - current_time)
                return bret.RUNNING
            end
        end
    },

    -- 获取路径
    GET_Path = {
        run = function(self, env)
            poe2_api.print_log("获取路径...")
            poe2_api.dbgp("获取路径...")
            local start_time = api_GetTickCount64()
            if not self.time1  then
                poe2_api.dbgp("[GET_Path] 初始化：失败次数")
                self.FAIL_count = 0
                self.time1 = 0
            end
            local start_current_time = api_GetTickCount64()

            local player_info = env.player_info
            local range_info = env.range_info
            -- 检查终点是否存在
            local point = env.end_point
            poe2_api.dbgp("终点")
            poe2_api.printTable(env.end_point)
            if not point or not next(point) then
                poe2_api.dbgp("[GET_Path] 错误：未设置终点")
                return bret.FAIL
            end

            -- 如果已有路径，使用下一个路径点
            local path_list = env.path_list

            if path_list and #path_list > 1 then
                poe2_api.dbgp("路径点数env.path_list: " .. #env.path_list)

                local dis = poe2_api.point_distance(path_list[1].x, path_list[1].y, player_info)
                if dis and dis < 20 then
                    env.target_point = { path_list[1].x, path_list[1].y }
                    -- poe2_api.dbgp("len 5465 移除已使用的点")
                    -- table.remove(path_list, 1) -- 移除已使用的点
                end
                poe2_api.dbgp(path_list[1].x, path_list[1].y)
                poe2_api.time_p("已有路径(SUCCESS) 耗时 -->", api_GetTickCount64() - start_current_time)
                return bret.SUCCESS
            end

            -- 计算最近可到达的点
            local arrive_point = api_FindNearestReachablePoint(point[1], point[2], 40, 0)
            poe2_api.dbgp("计算最近可到达的点")
            poe2_api.dbgp(arrive_point.x, arrive_point.y)
            poe2_api.dbgp(env.end_point[1], env.end_point[2])
            if arrive_point.x == -1 and arrive_point.y == -1 then
                arrive_point.x = env.end_point[1]
                arrive_point.y = env.end_point[2]
            end
            -- 计算起点
            poe2_api.dbgp("计算起点",player_info.grid_x, player_info.grid_y)

            poe2_api.dbgp(player_info.grid_x, player_info.grid_y)
            local player_position = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y, 50, 0)

            local result = api_FindPath(player_position.x, player_position.y, arrive_point.x, arrive_point.y)
            poe2_api.time_p("计算路径成功 耗时 -->", api_GetTickCount64() - start_current_time,
                "两点：{" .. player_position.x .. "," .. player_position.y .. "} -> {" .. arrive_point.x .. "," .. arrive_point.y .. "}")

            if result and #result > 0 then
                -- 处理路径结果
                local result_start_current_time = api_GetTickCount64()
                result = poe2_api.extract_coordinates(result, 22)
                self.time1 = 0
                if #result > 1 then
                    table.remove(result, 1) -- 移除起点
                    poe2_api.dbgp("移除起点")
                    env.path_list = result
                    env.target_point = { result[1].x, result[1].y }
                    -- table.insert(result, {x = env.end_point[1], y = env.end_point[2]}) -- 替换end_x,end_y为实际坐标
                    table.insert(result, { x = env.end_point[1], y = env.end_point[2] }) -- 替换end_x,end_y为实际坐标

                    poe2_api.dbgp("[GET_Path] 路径计算成功，点数: " .. #result)
                end
                poe2_api.time_p("处理路径结果 耗时 -->", api_GetTickCount64() - result_start_current_time)
                return bret.SUCCESS
            else
                -- 路径计算失败处理
                poe2_api.dbgp("[GET_Path] 计算路径失败")
                if self.time1 == 0 then
                    self.time1 = api_GetTickCount64()
                end
                env.map_result = nil
                local ctime = start_time - self.time1
                poe2_api.dbgp("ctime:", ctime)
                if ctime > 30 * 1000 then
                    poe2_api.dbgp("[GET_Path] 未找到路径 45 秒，恢复初始地图")
                    api_RestoreOriginalMap()
                    if ctime > 60 * 1000 then
                        poe2_api.dbgp("[GET_Path] 未找到路径 60 秒，回城")
                        if string.find(player_info.current_map_name_utf8, "own") then
                            self.time1 = 0
                            return bret.RUNNING
                        end
                        for _, name in ipairs(my_game_info.city_map) do
                            if poe2_api.find_text({ UI_info = env.UI_info, text = name, click = 2 }) then
                                return bret.RUNNING
                            end
                        end
                        api_ClickScreen(1230, 815, 0)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(2000)
                        return bret.RUNNING
                    end
                end
                -- 竞技场处理
                -- 获取周围指定对象grid_x,grid_y,id
                local function get_range_pos(name)
                    local actors = poe2_api.get_sorted_list(range_info, player_info)

                    for _, a in ipairs(actors) do
                        if a.name_utf8 == name then
                            return { a.grid_x, a.grid_y, a.id }
                        end
                    end
                    return nil
                end
                local arena_list = poe2_api.get_sorted_obj("競技場", range_info, player_info)
                if poe2_api.find_text({ UI_info = env.UI_info, text = "競技場" }) and arena_list and #arena_list > 0 and arena_list[1].hasLineOfSight and arena_list[1].is_selectable and api_FindPath(player_info.grid_x, player_info.grid_y, arena_list[1].grid_x, arena_list[1].grid_y) then
                    poe2_api.dbgp("競技場")
                    if poe2_api.is_have_mos({ range_info = range_info, player_info = player_info }) then
                        poe2_api.dbgp("有怪物不点击arena_list")
                        return bret.SUCCESS
                    end
                    poe2_api.find_text({ UI_info = env.UI_info, text = "競技場", click = 2 })
                    env.end_point = nil
                    env.entrancelist = {}
                    env.end_point = {}
                    return bret.RUNNING
                end
                -- 城镇处理
                if poe2_api.table_contains(player_info.current_map_name_utf8, "own") then
                    local result = api_FindNearestReachablePoint(point.x, point.y, 50, 0)
                    api_ClickMove(poe2_api.toInt(result.x), poe2_api.toInt(result.y),0)
                    poe2_api.click_keyboard("space")
                end
                return bret.RUNNING
            end
        end
    },

    -- 点击移动
    Move_To_Target_Point = {
        run = function(self, env)
            -- 初始化逻辑直接放在 run 函数开头
            poe2_api.dbgp("点击移动 节点...")
            local start_time = api_GetTickCount64()

            if not self.last_move_time then
                poe2_api.dbgp("初始化 Move_To_Target_Point 节点...")
                self.last_move_time = api_GetTickCount64()
                self.last_point = nil
                self.movement_threshold = 15
                return bret.RUNNING -- 初始化后返回 RUNNING，等待下一帧继续执行
            end
            if env.roll_time == nil or self.current_time == nil then
                self.current_time = api_GetTickCount64()
            end

            -- 正常执行移动逻辑
            poe2_api.dbgp("移动到目标点...")
            local point = env.target_point
            if not point then
                poe2_api.dbgp("[Move_To_Target_Point] 错误：未设置目标点")
                return bret.RUNNING
            end

            local player_info = env.player_info
            if not player_info then
                poe2_api.dbgp("[Move_To_Target_Point] 错误：未设置玩家信息")
                return bret.RUNNING
            end
            local range_info = env.range_info
            env.roll_time = start_time - self.current_time
            local roll_time = env.roll_time

            -- 检查终点是否变化
            local end_point = env.end_point
            if not self.last_point and end_point then
                poe2_api.dbgp("设置last_point")
                self.last_point = end_point
            end

            -- 超时翻滚逻辑
            if roll_time > 5 * 1000 and not player_info.isMoving and player_info.life > 0 then
                poe2_api.dbgp("超时翻滚")
                -- 获取可交互对象
                local function get_range()
                    if not player_info then
                        poe2_api.dbgp("错误:player_info 为空")
                        return false
                    end

                    local valid_objects = {
                        "甕", "壺", "屍體", "巢穴", "籃子", "小雕像", "石塊",
                        "鬆動碎石", "瓶子", "盒子", "腐爛木材", "保險箱", "腐爛木材"
                    }

                    -- 对范围对象进行排序
                    local sorted_range = poe2_api.get_sorted_list(range_info, player_info)
                    if not sorted_range then
                        poe2_api.dbgp("警告: 无法获取排序后的范围列表")
                        return false
                    end

                    poe2_api.dbgp(string.format("检查 %d 个范围内的对象", #sorted_range))

                    -- 遍历查找符合条件的对象
                    for _, obj in ipairs(sorted_range) do
                        -- 调试输出当前对象信息
                        poe2_api.dbgp(string.format("检查对象: %s (类型: %s, 激活: %s, 可选: %s)",
                            obj.name_utf8 or "无名",
                            obj.type or "未知",
                            tostring(obj.isActive),
                            tostring(obj.is_selectable)))

                        if obj.name_utf8 and
                            poe2_api.table_contains(valid_objects, obj.name_utf8) and
                            obj.isActive and
                            obj.is_selectable and
                            obj.grid_x and obj.grid_y then
                            local distance = poe2_api.point_distance(obj.grid_x, obj.grid_y, player_info)
                            poe2_api.dbgp(string.format("对象 %s 距离: %.2f", obj.name_utf8, distance))

                            if distance <= 20 then
                                poe2_api.dbgp("找到符合条件的交互对象: " .. obj.name_utf8)
                                return obj
                            end
                        end
                    end

                    poe2_api.dbgp("未找到符合条件的交互对象")
                    return false
                end
                local target = get_range()
                if target and next(target) then
                    api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y),0)
                    api_Sleep(300)
                    api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y),1)
                    api_Sleep(300)
                end
                -- 竞技场处理
                local arena_list = poe2_api.get_sorted_obj("競技場", range_info, player_info)
                if poe2_api.find_text({ UI_info = env.UI_info, text = "競技場", min_x = 0 })
                    and arena_list and arena_list[1].hasLineOfSight and arena_list[1].is_selectable
                    and api_FindPath(player_info.grid_x, player_info.grid_y, arena_list[1].grid_x, arena_list[1].grid_y) then
                    poe2_api.find_text({ UI_info = env.UI_info, text = "競技場", min_x = 0, click = 2 })
                    env.end_point = nil
                    poe2_api.dbgp("超时翻滚-競技場-清理path_list")
                    env.path_list = {}
                end
                if point then
                    local player_point = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                    if player_point then
                        api_ClickMove(poe2_api.toInt(player_point.x), poe2_api.toInt(player_point.y), 7)
                    end
                end
                poe2_api.click_keyboard("space")
                poe2_api.dbgp("超时翻滚-清理path_list")
                env.end_point = nil
                env.path_list = {}
                env.target_point = nil
                return bret.RUNNING
            elseif player_info.isMoving or player_info.life == 0 then
                env.roll_time = nil
            end

            local current_time = api_GetTickCount64()
            local move_interval = math.random() * 0.2 + 0.2 -- 随机间隔 0.1~0.2 秒

            -- 执行移动（按时间间隔）
            if current_time - self.last_move_time >= move_interval * 1000 then
                if point then
                    poe2_api.dbgp("----点击移动----")
                    if not api_ClickMove(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]),  7) then
                        poe2_api.dbgp("点击移动失败")
                        env.path_list = {}
                        env.target_point = nil
                        env.is_arrive_end = true
                        env.end_point = nil
                        poe2_api.time_p("执行移动(RUNNING4) 耗时 -->", api_GetTickCount64() - start_time)
                        return bret.RUNNING
                    end
                    self.last_move_time = current_time
                end
            end

            -- 检查是否到达目标点
            if point then
                local dis = poe2_api.point_distance(point[1], point[2], player_info)
                -- poe2_api.dbgp("距离：" .. dis)
                if dis and dis < 25 then
                    if env.path_list and #env.path_list > 0 then
                        env.target_point = { env.path_list[1].x, env.path_list[1].y }
                        -- poe2_api.dbgp("len 5604 移除已使用的点")
                        table.remove(env.path_list, 1)  
                    end
                    poe2_api.time_p("执行移动(RUNNING5) 耗时 -->", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
                env.last_position_story = { player_info.grid_x, player_info.grid_y }
                return bret.RUNNING
            else
                poe2_api.dbgp("没有point清理路径")
                env.end_point = nil
                env.path_list = {}
                poe2_api.time_p("执行移动 耗时 -->", api_GetTickCount64() - start_time)
                return bret.RUNNING
            end
        end
    },

}
local all_nodes = {}
for k, v in pairs(base_nodes) do all_nodes[k] = v end
for k, v in pairs(custom_nodes) do all_nodes[k] = v end

-- 注册自定义节点
local behavior_node = require 'behavior3.behavior_node'
behavior_node.process(all_nodes)
-- 创建行为树环境
local env_params = {
    user_config = nil,
    user_info = nil,                   -- 用户信息
    user_map = nil,                    -- 地图
    player_class = nil,                -- 職業
    player_spec = nil,                 -- 专精
    space = nil,                       -- 躲避
    space_monster = nil,               -- 躲避怪物
    space_time = nil,                  -- 躲避时间
    protection_settings = nil,         -- 普通保護設置
    emergency_settings = nil,          -- 紧急設置
    login_state = nil,                 -- 登录状态，初始值为nil
    speel_ip_number = 0,               -- 設置当前IP地址的数量，初始值为0
    is_game_exe = false,               -- 游戏是否正在执行，初始值为false
    shouting_number = 0,               -- 喊话次数，初始值为0
    area_list = {},                    -- 存储区域列表，初始值为空列表
    account_state = nil,               -- 账户状态，初始值为nil
    switching_lines = 0,               -- 线路切换状态，初始值为0
    time_out = 0,                      --  超时时间，初始值为0
    skill_name = nil,                  -- 当前技能名称，初始值为nil
    skill_pos = nil,                   -- 当前技能位置，初始值为nil
    is_need_check = false,             -- 是否需要检查，初始值为false
    item_name = nil,                   -- 当前物品名称，初始值为nil
    item_pos = nil,                    -- 当前物品位置，初始值为nil
    check_all_points = false,          -- 是否检查所有点，初始值为false
    path_list = {},                    -- 存储路径列表，初始值为空列表
    empty_path = false,                -- 路径是否为空，初始值为false
    boss_name = nil,                   -- 当前boss名称，初始值为nil
    map_name = nil,                    -- 当前地图名称，初始值为nil
    interaction_object = nil,          -- 交互对象，初始值为nil
    item_move = false,                 -- 物品是否移动，初始值为false
    item_end_point = {},               -- 物品的终点位置，初始值为[0, 0]
    ok = false,                        -- 是否确认，初始值为false
    not_need_wear = false,             -- 是否不需要装备，初始值为false
    currency_check = false,            -- 是否进行货币检查，初始值为false
    sell_end_point = {},               -- 卖物品的终点位置，初始值为[0,0]
    is_better = false,                 -- 是否更好，初始值为false
    mos_out = 0,                       -- 显示的数量，初始值为0
    is_arrive_end = false,             -- 是否到达终点，初始值为false
    not_need_pick = false,             -- 是否不需要拾取，初始值为false
    is_not_ui = false,                 -- 是否不是UI界面，初始值为false
    entrancelist = {},                 -- 入口位置列表
    creat_new_role = false,            -- 新角色
    Level_reach = false,               -- 是否要刷级
    changer_leader = false,            -- 是否要换队长
    send_message = false,              -- 是否要发信息
    obtain_message = false,            -- 是否要换接收信息
    no_item_wear = false,              -- 不用要穿戴的物品
    my_role = nil,                     -- 角色，初始值为nil
    is_set = false,                    --是否建立
    end_point = nil,                   --终点，初始值为nil
    teleport_area = nil,               -- 传送地区，初始值为nil
    follow_role = nil,                 -- 跟随的角色，初始值为nil
    map_count = 0,                     -- 地图数，初始值为0
    task_name = nil,                   -- 任务名称，初始值为nil
    subtask_name = nil,                -- 子任务名称，初始值为nil
    special_map_point = nil,           -- 特殊点，初始值为nil
    mate_info = nil,                   -- 已死队员信息信息
    monster_info = nil,                -- 怪物信息
    range_info = nil,                  -- 周围对象信息信息
    bag_info = nil,                    -- 背包信息
    range_items = nil,                 -- 周围装备信息
    shortcut_skill_info = {},          -- 快捷栏技能信息
    allskill_info = {},                -- 全部技能信息
    selectableskill_info = {},         -- 可选技能技能控件信息
    skill_gem_info = {},               -- 技能宝石列表信息
    team_info = nil,                   -- 获取队伍信息
    team_info_data = nil,              -- 获取队伍数据信息
    player_info = nil,                 -- 人物信息
    UI_info = nil,                     -- UI控件信息
    skill_number = 0,                  -- 放技能次数
    path_bool = false,                 -- 跟隨超距離判斷
    interaction_object_map_name = nil, -- 交互对象所在地图名称
    not_need_active = false,           -- 不激活
    target_point = {},                 -- 目标坐标，初始值为空列表
    grid_x = nil,
    grid_y = nil,
    target_point_follow = nil,    -- 目标跟随点，初始值为nil
    is_timeout = false,           -- 是否超时
    special_relife_point = false, -- 特殊重生点
    need_identify = false,        -- 需要鉴定
    one_other_map = nil,          -- 只去另外一个地图
    current_map_info = nil,       -- 小地图信息
    need_item = nil,            -- 异界可拾取对象
    discard_item = nil,           -- 丢弃对象
    store_item = nil,             -- 存储对象
    interactive = nil,            -- 交互对象
    is_shop = false,              -- 是否购买
    is_map_complete = false,      -- 是否是地图完成
    pick_up_timeout = {},         -- 拾取物品超时
    wait_target = false,          -- 等待交互
    start_time = nil,             -- 設置黑板变量 开始时间，初始化为 nil
    life_time = nil,              -- 設置黑板变量 復活时间，初始化为 nil
    last_end_point = {},          -- 設置黑板变量 終點，初始化为 0
    priority_map = nil,           -- 優先打地圖詞綴,
    last_exception_time = nil,
    need_ReturnToTown = false,
    need_SmallRetreat = false,
    retry_count = 0,
    error_back = false,         -- 意外退出
    map_recorded = false,       -- 地图状态记录
    mouse_check = true,         -- 检查鼠标技能
    click_grid_pos = false,     -- 补丁视角处理
    current_pair_index = 0,     -- 初始化当前兑换索引
    last_execution_time = 0,    -- 初始化当前兌換時間
    not_more_ritual = true,     -- 取消后续祭坛
    warehouse_full = nil,       -- 个仓某页是否已满
    exchange_status = false,    -- 是否兌換完成（存仓用）
    not_items_buy = false,      -- 祭祀无物品购买
    open_map_UI = false,        -- 地图ui是否打开
    is_public_warehouse = true, --共倉點金是否存儲
    is_get_plaque_node = true,  --取碑牌节点，专用是否需要取碑牌
    is_public_warehouse_plaque = true,
    last_retreat_time = 0,
    path_list_follow = nil,
    hard_chapter = false,
    map_level_dis = nil,
    is_arrive_end_dis = nil,
    end_point_attack = nil,
    path_list_attack = nil,
    target_point_attack = nil,
    is_arrive_end_attack = false,
    is_have_map = nil,
    is_strengthened_map = true,
    strengthened_map_obj = nil,
    chapter_name = nil,
    target_chapter_name = nil,
    target_map_name = nil,
    is_find_boss = false,
    not_interactive = nil,
    enter_map_click_counter = 0,
    is_get_plaque = false,
    is_timeout_exit = false, --超时小退
    afoot_altar = nil,
    center_point = {},
    center_radius = 0,
    run_point = nil,
    valid_monsters = nil,
    launch_timeout = 0,
    stuck_monsters = nil,
    item2 = nil,
    item3 = nil,
    item4 = nil,
    item5 = nil,
    item6 = nil,
    item7 = nil,
    item8 = nil,
    item9 = nil,
    item0xa = nil,
    item0xb = nil,
    not_attack_mos = nil,
    min_attack_range = nil,
    back_city = false, --回城
    click_traverse = nil,
    error_kill = false,
    kill_process = false,
    last_position_story = { 0, 0 },
    take_rest = false,
    buy_items = false,
    roll_time = nil,                   --翻滚时间
    exit_time = nil,                   -- 小退时间
    relife_stuck_monsters = {},        --复活队友跳怪
    map_result = nil,                  --小地图路径
    tasks_data = main_task.tasks_data, --任务列表
    npc_names = nil,                   --NPC名稱
    waypoint = nil,                    --传送点
    waypoint_screen_point = nil,       --传送点屏幕坐标
    record_map = nil,                  --记录小地图
    log_path = nil,                    --日志路径
    interaction_object_copy = nil,     --交互对象copy
    interaction_object_map_name_copy = nil, -- 交互对象所在地图名称copy
    modify_interaction = false,
    not_move = false, -- 不移动
    leader_teleport = false, --队长传送
    warehouse_type_interactive = nil,  -- 仓库类型交互（个仓/公仓/nil）
    hwrd_time = 0,                     -- 获取窗口句柄间隔
    game_window = 0,                   -- 暂存的窗口句柄
    streng_map_flushed_switch = false, -- 强化地图刷新开关
    currency_name = nil,               -- 使用通货物品名称
    need_sale_map = false,             -- 是否需要卖地图
    full_map = false,                  -- 地图是否已满
    min_attack_dis = nil,
    in_exchange = false,               --在兑换状态
    -- 新增性能监控配置
    debug_tree_time = true,            -- 打印整棵树耗时
    debug_all_nodes = false,           -- 不打印所有节点调试信息(避免日志过多)
    suppress_node_debug = true         -- 抑制节点调试输出
}
-- 导出模块接口
local plot_bt = {}

-- 创建行为树
function plot_bt.create()
    -- 直接使用已定义的 env_params，并更新配置
    local bt = behavior_tree.new("story_complete", env_params)
    return bt
end

return plot_bt
