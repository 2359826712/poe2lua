package.path = package.path .. ';./path/to/module/?.lua'

-- 根据otherworld.json实现的完整行为树系统
package.path = package.path .. ';lualib/?.lua'
local behavior_tree = require 'behavior3.behavior_tree'
local bret = require 'behavior3.behavior_ret'
-- 加载基础节点类型
local base_nodes = require 'behavior3.sample_process'
local my_game_info = require 'my_game_info'
local main_task = require 'main_task'
local script_path = debug.getinfo(1, "S").source:sub(2)
local path = script_path:gsub("/", "\\")
local script_dir = path:match("(.*\\)")
local json_path = script_dir .. "config.json"
local user_info_path = script_dir .. "config.ini"
local poe2_api = require "poe2api"
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
                env.not_use_map = (config['刷圖設置'] or {})["不打地圖詞綴"] or {}
                env.priority_map = (config["刷圖設置"] or {})["優先打地圖詞綴"] or {}
                env.not_enter_map = (config["刷圖設置"] or {})["不打地圖名"] or {}

                -- 处理怪物躲避设置（添加空值保护）
                local global_settings = config["全局設置"] or {}
                local common_settings = global_settings["刷图通用設置"] or {}
                local monster_avoid = common_settings["怪物近距離躲避"] or {}

                env.space = monster_avoid["是否開啟"] or false
                env.space_time = monster_avoid["閾值"] or 0

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
                local skill_list = {}
                for _, v in pairs(skill_config) do 
                    if v["启用"] and v["技能屬性"] == "攻击技能" and (v["白怪"] or v["藍怪"] or v["黃怪"]) then
                        table.insert(skill_list,v["攻擊距離"])
                    end
                end
                -- poe2_api.printTable(skill_list)
                -- api_Sleep(100000000000000)
                env.min_attack_dis = math.min(table.unpack(skill_list))

                -- 加载躲避技能

                if not self.open_mos_skill then
                    self.open_mos_skill = true
                    local skills = config["全局設置"]["刷图通用設置"]["是否躲避技能"]
                    if skills then
                        for _,k in ipairs(my_game_info.MonitoringSkills) do
                            api_AddMonitoringSkills(k[1] , k[2] , k[3])
                        end
                    end
                    -- # 高傷害技能
                    for _,k in ipairs(my_game_info.High_Damage_Skill) do
                        api_AddMonitoringSkills(k[1] , k[2] , k[3])
                    end
                end

                -- 组队信息初始化
                env.team_info = {
                    ["大號名"] = config["組隊設置"]["大號名"] or "",
                    ["隊長名"] = config["組隊設置"]["隊長名"] or "",
                    ["小號名"] = {}
                }
            end
            poe2_api.time_p("Get_User_Config_Info... 耗时 --> ", api_GetTickCount64() - start_time)
            return bret.SUCCESS
        end
    },
    
    -- 判断游戏窗口 poe2_api.time_p("判断游戏窗口... 耗时 --> ", api_GetTickCount64() - current_time)
    Is_Game_Windows={
        run = function(self, env)
            poe2_api.print_log("判断游戏窗口")
            local current_time = api_GetTickCount64()

            if not env.user_info then
                local user_info = poe2_api.load_ini(user_info_path)["UserInfo"]
                env.user_info = user_info
            end
            local game_path = env.user_info["gamedir"]
            poe2_api.dbgp("game_path:"..game_path)
            local process_name = string.find(game_path:lower(), "steam.exe") and "PathOfExileSteam.exe" or "PathOfExile.exe"
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
            poe2_api.dbgp("hwrd_time1:"..env.hwrd_time)
            if env.hwrd_time == 0 or os.time() - env.hwrd_time >= 60 then
                env.game_window = api_FindWindowByProcess("","Path of Exile 2",process_name,0)
                poe2_api.dbgp("game_window:"..env.game_window)
                env.hwrd_time = os.time()
                poe2_api.dbgp("------------------")
                poe2_api.dbgp("hwrd_time2:"..env.hwrd_time)
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
                env.take_rest =false
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
            if self.bool == nil  then
                self.config_exe = false
                self.bool = false
                self.bool1 = false
            end
            local start_time = api_GetTickCount64()  -- 转换为 ms

            local game_path = env.user_info["gamedir"]
            poe2_api.dbgp("game_path:"..game_path)
            local process_name = string.find(game_path:lower(), "steam.exe") and "PathOfExileSteam.exe" or "PathOfExile.exe"
            
            
            if env.time_out == 0 then
                env.time_out = os.time()
            end
            -- 判断是否关闭游戏
            if env.speel_ip_number >= 50 
            or env.error_kill 
            or env.is_set 
            or env.switching_lines>=120 
            or poe2_api.find_text({text = "This operation requires the account to be logged in.", UI_info = env.UI_info})
            or poe2_api.find_text({text = "> 已斷線: Unable to deserialise packet with pid", UI_info = env.UI_info,min_x = 0}) then
                poe2_api.dbgp("error_kill:", env.error_kill)
                poe2_api.dbgp("speel_ip_number:" , env.speel_ip_number)
                poe2_api.dbgp("is_set:", env.is_set)
                poe2_api.dbgp("switching_lines:", env.switching_lines)
                poe2_api.dbgp("find_test (to be logged in.):", poe2_api.find_text({text = "This operation requires the account to be logged in.", UI_info = env.UI_info}))
                poe2_api.dbgp("find_test (packet with pid):", poe2_api.find_text({text = "> 已斷線: Unable to deserialise packet with pid", UI_info = env.UI_info,min_x = 0}))
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
                
                if pid and next(pid) and pid[1]~=0 then
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
            poe2_api.dbgp("判断是否关闭游戏:"..string.format( elapsed_ms))
             -- 加载中
            if poe2_api.click_text_UI({UI_info = env.UI_info, text = "loading_screen_tip_label"}) then
                env.last_exp_check = api_GetTickCount64()
                env.last_exception_time = 0
                env.need_SmallRetreat = false
                env.need_ReturnToTown = false
                env.enter_map_click_counter = 0
                env.sacrificial_refresh = 0
                env.have_ritual = false
                env.find_path_failure = 0
                env.stuck_monsters = nil
                env.is_dizhu = false
                env.click_grid_pos = false
                env.need_item = nil
                env.interactive = nil
                env.not_items_buy = false
                env.open_map_UI = false -- 重置地图UI信息
                env.afoot_altar = nil
                env.path_list = nil
                env.end_point = nil
                env.one_other_map = nil
                env.is_timeout = false
                env.is_timeout_exit = false
                -- self.reset_states()
                local current_time = api_GetTickCount64()
                env.last_exception_time_move = 0.0
                env.last_exp_check_move = current_time
                if env.player_info and env.player_info.grid_x ~=0 then
                    env.last_exp_value = env.player_info.currentExperience
                end
                poe2_api.dbgp("已重置所有经验监控状态") 
                api_Sleep(2000)
                env.switching_lines =  env.switching_lines + 1
                poe2_api.time_p("Join_Game_Otherworld(RUNNING)... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.RUNNING
            end

            if poe2_api.click_text_UI({text = "life_orb",UI_info = env.UI_info})
             or poe2_api.click_text_UI({text = "resume_game",UI_info = env.UI_info})
              or poe2_api.find_text({text = "清單",UI_info = env.UI_info,min_x = 0,min_y = 0,max_x = 400}) then
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

                if poe2_api.find_text({UI_info = env.UI_info, text = "你無法在遊戲暫停時使用該道具。", min_x = 0}) and not self.bool1 then
                    self.bool1 = true
                    poe2_api.click_keyboard("space")
                end
                if not self.bool and not poe2_api.table_contains(poe2_api.get_team_info(env.team_info, env.user_config, env.player_info , 2),{"大號名","未知"}) then
                    poe2_api.print_log("等待获取任务信息")
                    poe2_api.dbgp("等待获取任务信息")
                    self.bool = true
                    local mas = nil
                    local finished_tasks = {}
                    if not env.hard_chapter then
                        mas,finished_tasks  = poe2_api.check_task_map_without(0)
                    else
                        mas,finished_tasks  = poe2_api.check_task_map_without(1)
                    end
                    if poe2_api.table_contains("部落復仇", finished_tasks) or (mas and string.find(mas,"C"))  then
                        env.hard_chapter = true
                        env.tasks_data = main_task.tasks_data_hard
                    elseif not poe2_api.table_contains("部落復仇", finished_tasks) then
                        env.tasks_data = main_task.tasks_data
                    end
                end
                poe2_api.dbgp("已进入游戏")
                -- 计算当前 Tick 耗时（毫秒）
                poe2_api.time_p("已进入游戏耗时(SUCCESS)... 耗时 --> ", api_GetTickCount64() - start_time)
                return bret.SUCCESS
            end

            if poe2_api.find_text({text = "伺服器關閉維修中，請稍後再試。",UI_info = env.UI_info,min_x = 0}) then
                error("服务器维护中,已停止运行")
            end
            if poe2_api.find_text({text = "Your account has been banned by an administrator.",UI_info = env.UI_info}) then
                error("封号!!!")
            end
            if poe2_api.find_text({text = "登入錯誤",UI_info = env.UI_info}) then
                error("账号或者密码错误")
            end
            if poe2_api.find_text({text = {"此帳號已被鎖定，請至信箱確認解鎖郵件中的解鎖碼並在此輸入。","重新寄送解鎖信"},UI_info = env.UI_info,min_x = 0}) then
                error("请手动处理邮箱验证")
            end
            if poe2_api.find_text({text = "此帳號已被其他使用者登入。",UI_info = env.UI_info}) then
                error("此帳號已被其他使用者登入。")
            end
            local text_list = {"與副本連線失敗。","伺服器斷線。","> Steam：未連接到 Steam","Steam：未連接到 Steam","已斷線","操作逾時","由於在短時間內執行過多指令，因此被伺服器暫時切斷連線。"}
            if poe2_api.find_text({text = text_list,UI_info = env.UI_info,min_x = 0}) then
                poe2_api.find_text({text = "確定",UI_info = env.UI_info,min_x = 0,click = 2})
                api_Sleep(1000)
                return bret.RUNNING
            end
            local text_list1 = {"Login Error","The operation timed out.","Entry to this league has closed.","Abnormal Disconnection","Disconnection","Disconnected","偵測到老舊的 GPU 驅動程式。請更新至最新版本。","你的帳號沒有《流亡黯道 2》的搶 先體驗資格。立即在我們的網站上領取搶先體驗金鑰或購買資格。","搶先體驗"}
            if poe2_api.find_text({text = text_list1,UI_info = env.UI_info}) then
                poe2_api.find_text({text = "確定",UI_info = env.UI_info,min_x = 0,click = 2})
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({text = "Your IP has been banned. Please contact support if you think this is a mistake.",UI_info = env.UI_info}) then
                env.speel_ip_number = env.speel_ip_number + 1
                poe2_api.find_text({text = "確定",UI_info = env.UI_info,min_x = 0,click = 2})
                api_Sleep(1000)
                return bret.RUNNING       
            end
            if poe2_api.find_text({text = "同意",UI_info = env.UI_info}) then
                poe2_api.find_text({text = "同意",UI_info = env.UI_info,min_x = 0,add_x = 150,click = 2})
                poe2_api.find_text({text = "繼續",UI_info = env.UI_info,min_x = 800,min_y = 450,click = 2})
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({text = "建立帳號",UI_info = env.UI_info,min_x = 0,max_y = 790})
            or poe2_api.find_text({text = "若要使用 Steam 登入，你必須先建立一個 Steam 的《流亡黯道》帳號。",UI_info = env.UI_info,min_x = 0}) then
                poe2_api.find_text({text = "帳號名稱",UI_info = env.UI_info,min_x = 0,add_x = 161,click = 2})
                api_Sleep(500)
                local text = poe2_api.generate_random_string(math.random(8, 10))
                
                poe2_api.paste_text(text)
                api_Sleep(500)
                poe2_api.find_text({text = "帳號名稱",UI_info = env.UI_info,min_x = 0,add_x = 110,add_y = 53,click = 2})
                api_Sleep(500)
                return bret.RUNNING
            end
            local account = env.user_info["account"]
            local password = env.user_info["password"]
            if poe2_api.click_text_UI({text = "username_textbox",UI_info = env.UI_info}) and not poe2_api.find_text({text = account,UI_info = env.UI_info,min_x = 646,min_y = 572,max_x = 953,max_y = 609}) then
                poe2_api.click_text_UI({text = "username_textbox",UI_info = env.UI_info,click = 1})
                api_Sleep(500)
                poe2_api.paste_text(account)
                api_Sleep(500)
                return bret.RUNNING
            end
            if poe2_api.click_text_UI({text = "password_textbox",UI_info = env.UI_info}) and not poe2_api.find_text({text = password,UI_info = env.UI_info,min_x = 646,min_y = 623,max_x = 953,max_y = 660}) then
                poe2_api.click_text_UI({text = "password_textbox",UI_info = env.UI_info,click = 1})
                api_Sleep(500)
                poe2_api.paste_text(password)
                api_Sleep(500)
                return bret.RUNNING
            end
            if poe2_api.click_text_UI({text = "login_button",UI_info = env.UI_info}) then
                poe2_api.find_text({text = "登入",UI_info = env.UI_info,click = 2})
                api_Sleep(1000)
                return bret.RUNNING
            end
            if poe2_api.find_text({text = "已驗證。",UI_info = env.UI_info,min_x = 0})
            and poe2_api.find_text({text = "開始遊戲",UI_info = env.UI_info}) then
                poe2_api.dbgp1("dsgvfsdvsdzvdv")
                poe2_api.click_keyboard("space")
                return bret.RUNNING
            end
            if poe2_api.find_text({text = "Standard",UI_info = env.UI_info}) then
                poe2_api.find_text({text = "Standard",UI_info = env.UI_info,click = 2})
                api_Sleep(1000)
                return bret.RUNNING
            end
            local creat_new_role = env.creat_new_role
            if poe2_api.find_text({text = "開始遊戲",UI_info = env.UI_info}) 
            and not creat_new_role then
                poe2_api.find_text({text = "開始遊戲",UI_info = env.UI_info,click = 2})
                api_Sleep(1000)
                return bret.RUNNING
            else
                poe2_api.find_text({text = "建立角色",UI_info = env.UI_info,click = 2})
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
                ]]--
                
                -- 检查文件和目录是否存在
                local file = io.open(game_path, "r")
                if not file then
                    poe2_api.dbgp(string.format("游戏程序未找到: %s", game_path))
                    return false
                end
                file:close()
                
                -- 检查目录是否存在
                local dir_handle = io.popen('cd "'..game_dir..'" 2>&1')
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
                    local game_window = api_FindWindowByProcess("","Path of Exile 2","PathOfExile.exe",0)
                    if pid and next(pid) and pid[1] ~= 0 and game_window and game_window ~= 0 then
                        api_SetWindowState(game_window, 13)
                        -- poe2_api.terminate_process(pid)
                        env.game_window = 0
                        env.hwrd_time = 0
                        api_Sleep(10000)
                        return bret.RUNNING
                    end
                    env.kill_process=false
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

            local window_handlesteam = api_FindWindowByProcess("","Path of Exile 2","PathOfExileSteam.exe",0)
            if window_handlesteam and window_handlesteam ~= 0 then
                pid1 = true
                
            end

            local window_handle = api_FindWindowByProcess("","Path of Exile 2","PathOfExile.exe",0)
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
                local steam_login_hwnd = api_FindWindowByProcess("","登录 Steam","steamwebhelper.exe",0)
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
                local steam_login_hwnd = api_FindWindowByProcess("","登录 Steam","steamwebhelper.exe",0)
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
            if poe2_api.countTableItems(env.player_info) < 1 then
                poe2_api.dbgp("空人物信息")
                return bret.RUNNING
            end
            poe2_api.time_p("    获取人物信息... 耗时 --> ", api_GetTickCount64() - player_info_start_time)

            local range_info_start_time = api_GetTickCount64()  -- 记录开始时间(毫秒)
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
            -- poe2_api.printTable(env.current_map_info)
            poe2_api.time_p("    获取小地图周围对象信息... 耗时 --> ", api_GetTickCount64() - current_map_info_start_time)

            -- 周围装备信息
            local range_items_start_time = api_GetTickCount64()
            env.range_items = WorldItems:Update()
            -- poe2_api.printTable(env.range_items)
            poe2_api.time_p("    获取周围装备信息... 耗时 --> ", api_GetTickCount64() - range_items_start_time)
            
            -- 背包信息（主背包）
            local bag_info_start_time = api_GetTickCount64()
            env.bag_info = api_Getinventorys(1,0)
            poe2_api.time_p("    获取背包信息信息... 耗时 --> ", api_GetTickCount64() - bag_info_start_time)

            -- api_GetTeleportationPoint() - 获取传送点信息
            if not env.waypoint then
                local waypoint_start_time = api_GetTickCount64()
                env.waypoint = api_GetTeleportationPoint()
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
                
                api_Sleep(1000000)  -- 暂停程序（注意：长时间暂停可能导致游戏无响应）
            end

            -- 测试函数
            local function dumprange(inventory)
                local itemFields = {
                    "obj","name_utf8","world_x","world_y","world_z","grid_x" ,"grid_y" ,"max_life",
                    "life","max_mana","mana","max_shield",
                    "shield","type" ,"current_map_name_utf8" ,"is_selectable" ,
                    "level" ,"strength" ,"dexterity" ,"intelligence" ,
                    "spirit_max" , "spirit_use" ,"is_friendly" , "hasTasksToAccept" ,
                    "hasLineOfSight" , "isActive" ,"rarity" , "path_name_utf8" ,
                    "currentExperience" , "id" ,"isInDangerArea" ,"stateMachineList" , "gold" , 
                    "isInBossBattle" ,"remainingPortalCount" , "isMoving" ,"magicProperties" 
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
                    
                    api_ClickMove(item.grid_x, item.grid_y,0)
                    api_Sleep(1000)
                    
                    api_Log("----------------------------------")
                    ::continue::
                end
                
                api_Sleep(1000000)  -- 暂停程序（注意：长时间暂停可能导致游戏无响应）
            end
            
            -- 调用函数
            -- dumpInventory(env.range_items)
            -- dumprange(env.range_info)


            if self.wear_items == nil then
                self.wear_items = true
            end
            -- 其他物品栏信息（批量处理）
            if self.wear_items then
                local inventory_sections = {
                    {2, "item2"}, {3, "item3"}, {4, "item4"},
                    {5, "item5"}, {6, "item6"}, {7, "item7"},
                    {8, "item8"}, {9, "item9"}, {0xa, "item0xa"}, {0xb, "item0xb"}
                }
                for _, section in ipairs(inventory_sections) do
                    local section_id = section[1]
                    local section_name = section[2]
                    if not env[section_name] then
                        local items = api_Getinventorys(section_id,0)
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
            if not self.time then
                self.bool =false
                self.time = 0
                poe2_api.dbgp("初始化")
            end
            local player_info = env.player_info
            if not player_info or not next(player_info) then 
                poe2_api.dbgp("人物信息为空")
                return bret.RUNNING
            end
            if self.time == 0 then
                self.time = api_GetTickCount64()
            end 
            if player_info.life ~= 0 and not poe2_api.click_text_UI({text="respawn_at_checkpoint_button",UI_info = env.UI_info}) then
                if (string.match(player_info.current_map_name_utf8,"town") and not self.bool) or start_time - self.time > 5* 60 * 1000 then
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "/clear",min_x = 0 }) then
                        api_ClickMove(poe2_api.toInt(player_info.grid_x), poe2_api.toInt(player_info.grid_y), poe2_api.toInt(player_info.world_z), 7)
                        api_Sleep(1000)
                        poe2_api.click_keyboard("enter",0)
                        api_Sleep(500)
                        poe2_api.paste_text("/clear")
                        api_Sleep(500)
                        poe2_api.click_keyboard("enter",0)
                        api_Sleep(500)
                        self.bool = true
                        self.time = 0
                        return bret.RUNNING
                    end
                elseif not string.match(player_info.current_map_name_utf8,"town") then
                    self.bool = false
                end
            end  
            poe2_api.dbgp("完成")
            local elapsed_ms = (api_GetTickCount64()) - start_time
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
            if poe2_api.get_team_info(env.team_info, env.user_config, player_info , 2) ~="大號名" or player_info.isInBossBattle or poe2_api.is_have_mos({range_info = env.range_info , player_info = player_info , dis = 80 , stuck_monsters = env.stuck_monsters, not_attack_mos = env.not_attack_mos }) then
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

            local function _handle_state_transition()
                self._is_resting = not self._is_resting
                local duration_ms = self._is_resting and self.rest_duration_ms or self.work_duration_ms
                self._next_state_change_time_ms = current_time_ms + duration_ms
                self._last_update_time_ms = current_time_ms
                
                -- 更新环境变量
                env.take_rest = self._is_resting
                
                if self._is_resting then
                    poe2_api.dbgp("切换到休息状态")
                    
                    -- 进入休息状态
                    if self.is_kill_game then
                        env.error_kill = true
                        poe2_api.dbgp("设置需要关闭游戏")
                    end
                    poe2_api.dbgp(string.format("工作时间到，开始休息 (%d分钟)", math.floor(self.rest_duration_ms/(60*1000))))
                    if not string.find(player_info.current_map_name_utf8,"own") then
                        for _, name in ipairs(my_game_info.city_map) do
                            poe2_api.find_text({UI_info = env.UI_info, text = name, click = 2})
                        end
                        api_ClickScreen(1230,815,0)
                        api_Sleep(500)
                        api_ClickScreen(1230,815,1)
                    end
                    poe2_api.dbgp(string.format("工作时间到，开始休息 (%d分钟)", math.floor(self.rest_duration_ms/(60*1000))))
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
                        if not string.find(player_info.current_map_name_utf8,"own") then
                            for _, k in ipairs(my_game_info.city_map) do
                                poe2_api.find_text({UI_info = env.UI_info, text = k.name_utf8, click = 2})
                            end
                            api_ClickScreen(1230,815,0)
                            api_Sleep(500)
                            api_ClickScreen(1230,815,1)
                        end
                        
                        
                    end
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

    -- 检查长时间未增长经验
    Check_LongTime_EXP_Add = {
        run = function(self, env)
            poe2_api.print_log("开始执行长时间经验检查...")
            local current_time = api_GetTickCount64()
            local take_rest = env.take_rest
            local player_info = env.player_info
            -- 特殊情况跳出
            if poe2_api.get_team_info(env.team_info, env.user_config, player_info , 2) ~="大號名" then
                return bret.SUCCESS
            end
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
                if not player_info then
                    poe2_api.dbgp("错误:player_info 为空")
                    return false
                end

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
            local real_stagnation_time_move = current_time - (env.last_exp_check_move or 0)
            
            poe2_api.dbgp(string.format("移动停滞时间: %.2f秒", real_stagnation_time_move / 1000))

            -- 根据场景设置不同的超时时间
            local space_time = 8
            -- 处理长时间未移动情况
            if is_moving and real_stagnation_time_move > space_time * 1000 then
                poe2_api.dbgp(string.format("长时间未移动(%.2f秒 > %d秒)，执行恢复操作", 
                    real_stagnation_time_move / 1000, space_time))
                
                if not take_rest then
                    poe2_api.print_log("清路径333")
                    env.end_point = nil
                    env.target_point = nil
                    env.path_list = nil
                    env.is_arrive_end = true
                    poe2_api.dbgp1("sgewgbfdbgfdhn")
                    poe2_api.click_keyboard("space")
                    
                    if env.range_info and player_info then
                        local target = get_range()
                        if target then
                            api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y), poe2_api.toInt(player_info.world_z), 1)
                            api_Sleep(200)
                            poe2_api.find_text({UI_info = env.UI_info, text = target.name_utf8, click = 2})
                            api_Sleep(300)
                        end
                        
                        local x, y = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                        api_ClickMove(poe2_api.toInt(x), poe2_api.toInt(y), poe2_api.toInt(player_info.world_z), 7)
                        api_Sleep(500)
                        poe2_api.dbgp1("fdgrgrfhfhdfhb")
                        poe2_api.click_keyboard("space")
                        api_Sleep(100)
                    end
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
            if player_info.life == 0 and poe2_api.find_text({UI_info = env.UI_info, text="在記錄點重生"}) then
                
                if poe2_api.click_text_UI({UI_info = env.UI_info, text="respawn_at_checkpoint_button"}) and not env.is_timeout and not env.is_timeout_exit then
                    poe2_api.dbgp1("rewyrejhgfdbnsdbvs")
                    poe2_api.click_keyboard("space")
                end
                poe2_api.dbgp("点击确认")
                poe2_api.find_text({UI_info = env.UI_info, text="確定",click=2, min_x=0})
                api_ClickScreen(915, 490,1)
                local relife_text = {"在記錄點重生","在城鎮重生"} 
                local point = poe2_api.find_text({UI_info = env.UI_info, text = relife_text, min_x = 0, position = 3})
                if not point then
                    poe2_api.time_p("Is_Deth_Otherworld(RUNNING)... 耗时 --> ", api_GetTickCount64() - start_time)
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
                if (start_time - self.death_time >= 60 * 1000) and (poe2_api.get_team_info( env.team_info, env.user_config, player_info, 2) == "大號名") then
                    env.is_timeout_exit = true
                end
                if start_time - self.click_time >= 5*1000 then
                    poe2_api.find_text({UI_info = env.UI_info, text = "在記錄點重生", click = 2})
                    self.click_time = 0
                end
                env.area_list = {}
                env.is_need_check = false
                env.stuck_monsters = nil
                env.item_name = nil
                env.item_pos = nil
                env.afoot_altar = nil
                env.check_all_points = false
                env.empty_path = false
                env.map_name = nil
                env.interaction_object = nil
                env.item_move = false
                env.item_end_point = {0, 0}
                env.attack_move = false
                env.ok = false
                env.not_need_wear = false
                env.currency_check = false
                env.sell_end_point = {0, 0}
                env.is_better = false
                env.mos_out = 0
                env.is_arrive_end = false
                env.not_need_pick = false
                env.is_not_ui = false
                env.no_item_wear = false
                env.my_role = nil
                env.is_set = false
                env.end_point = nil
                env.path_list = nil
                env.run_point = nil
                env.teleport_area = nil
                env.teleport = nil
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
            return bret.RUNNING
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
            if not self.time or self.time ==0 then
                self.time =api_GetTickCount64()
                self.exit_time = nil
                self.life_time = 0
            end
            local ctime = strat_time - self.time
            if ctime > 120*1000 and player_info.life > 0 then
                env.is_timeout_exit = true
                self.time = 0
            elseif player_info.life == 0  then
                self.time = 0
            end
            local function have_roman_number()
                local ROMAN_NUMERALS = {
                "I", "II", "III", "IV", "V",
                "VI", "VII", "VIII", "IX", "X",
                "XI", "XII", "XIII", "XIV", "XV", "XVI"
                }
                if poe2_api.find_text({UI_info = env.UI_info, text = ROMAN_NUMERALS, min_x = 520, min_y = 420, max_x = 560, max_y = 470}) then
                    return true
                else
                    return false
                end
            end

            -- 大号，小号更新障碍
            if poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) =="大號名" then
                if poe2_api.table_contains(player_info.current_map_name_utf8, {"G2_3","C_G2_3","C_G2_9_1","G2_9_1","C_G3_17","G3_17"}) and not poe2_api.find_text({UI_info = env.UI_info, text = "競技場" , min_x = 0}) then
                    api_UpdateMapObstacles(100)
                end
            else
                if not poe2_api.table_contains(player_info.current_map_name_utf8 , {"C_G1_12","G1_12"}) then
                    api_UpdateMapObstacles(100)
                end
            end

            -- 检查交易拒绝情况
            local refuse_click = {"等待玩家接受交易請求..."}
            if poe2_api.find_text({UI_info = env.UI_info, text = refuse_click, min_x = 0, add_x = 253, click = 2}) then
                poe2_api.dbgp("检测到交易请求等待，将执行拒绝操作")
                return bret.RUNNING
            end

            -- 传送确认遮挡
            if poe2_api.find_text({UI_info = env.UI_info, text = "你確定要傳送至此玩家的位置？"}) then
                api_ClickScreen(916,467,0)
                api_Sleep(500)
                api_ClickScreen(916,467,1)
                api_Sleep(500)
                self.life_time = 0
                return bret.RUNNING
            end

            -- 世界地图遮挡
            if poe2_api.find_text{UI_info = env.UI_info, text = "世界地圖", min_x = 0, add_x = 215, click = 2} then
                return bret.RUNNING
            end
            
            -- 检查点遮挡
            if poe2_api.find_text({UI_info = env.UI_info, text = "Checkpoints", min_x = 0, add_x = 215, click = 2}) then
                return bret.RUNNING
            end

            -- 领取任务奖励
            if poe2_api.find_text({UI_info = env.UI_info, text = "獎勵", min_x = 100}) then
                poe2_api.find_text({UI_info = env.UI_info, text = "獎勵", add_y=50,click=2})
                api_Sleep(500)
                if poe2_api.find_text({UI_info = env.UI_info, text = "背包"}) then
                    if have_roman_number() then
                        poe2_api.get_space_point({width = 1, height = 1, click = 1})
                    else
                        poe2_api.get_space_point({width = 4, height = 2, click = 1})
                    end
                    return bret.RUNNING
                end
            end

            -- 团队队友死亡长时间未救其它小号处理
            local function  count_gravestones(map_info)
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
                    if poe2_api.find_text({UI_info = env.UI_info, text = "回到角色選擇畫面"}) then
                        poe2_api.click_keyboard("space")
                    end
                end
                self.life_time = 0
                env.is_timeout = false
            elseif count_gravestones(current_map_info) > 0 and poe2_api.get_team_info(env.team_info, env.user_config, player_info, 2) ~= "大號名" and player_info.life >0 and player_info.isInBossBattle and not poe2_api.is_have_mos({range_info = env.range_info, player_info = player_info}) then
                if self.life_time == 0 then
                    self.life_time = api_GetTickCount64()
                end
                if api_GetTickCount64() - self.life_time > 90 * 1000  and poe2_api.table_contains(player_info.current_map_name_utf8, {"G1_15","C_G1_15"}) then
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "回到角色選擇畫面"}) then
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
                    if poe2_api.click_text_UI({UI_info = env.UI_info, text = "respawn_at_checkpoint_button", refresh = true}) then
                        poe2_api.find_text({UI_info = env.UI_info, text = "在記錄點重生", min_x= 0, click = 2})
                        api_Sleep(500)
                        poe2_api.find_text({UI_info = env.UI_info, text = "確認", min_x= 0, click = 2, refresh = true})
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
                            self.exit_time = nil  -- 重置计时器
                        elseif poe2_api.find_text({text = "開始遊戲",UI_info = env.UI_info,click = 2}) and poe2_api.find_text({text = "建立角色",UI_info = env.UI_info,click = 2}) then
                            self.exit_time = nil 
                            env.error_kill = false
                            env.is_timeout_exit = false
                        end
                    end
                    if poe2_api.find_text({UI_info = env.UI_info, text = "回到角色選擇畫面", click=2}) then
                        if not self.exit_time then
                            self.exit_time = strat_time  --# 开始计时
                        end
                        api_Sleep(6000)
                        return bret.RUNNING
                    elseif poe2_api.click_text_UI({UI_info = env.UI_info, text = "exit_to_character_selection", click=1 , index=1}) then
                        if not self.exit_time then
                            self.exit_time = strat_time
                        end
                        api_Sleep(6000)
                        return bret.RUNNING
                    end
                    -- # 打开选项菜单
                    if not (poe2_api.find_text({UI_info = env.UI_info,  text = "回到角色選擇畫面"}) or 
                        poe2_api.click_text_UI({UI_info = env.UI_info, text = "exit_to_character_selection"})) and 
                        poe2_api.click_text_UI({UI_info = env.UI_info, text = "life_orb"}) and 
                        poe2_api.click_text_UI({UI_info = env.UI_info, text = "mana_orb"}) then
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
                        if poe2_api.find_text({UI_info = env.UI_info, text = name, click = 2}) then
                            if string.find(player_info.current_map_name_utf8, "own") then
                                env.back_city = false
                                return bret.RUNNING
                            end
                        end
                    end
                    api_ClickScreen(1230, 815, 0)
                    api_Sleep(500)
                    api_ClickScreen(1230, 815, 1)
                    return bret.RUNNING
                end
            else
                env.is_timeout = false
                env.back_city = false
                env.is_timeout_exit = false
            end

            -- 城镇遮挡
            if player_info and string.find(player_info.current_map_name_utf8,"own") then
                local click_2 ={"接受任務" ,"繼續"}
                if poe2_api.find_text({UI_info = env.UI_info, text = click_2, click = 2}) then
                    api_Sleep(500)  -- Equivalent to time.sleep(0.5)
                    return bret.RUNNING
                end

                if poe2_api.find_text({UI_info = env.UI_info, text = "你無法將此道具丟置於此。請問要摧毀它嗎？", min_x = 0, min_y = 0}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "保留", min_x = 0, min_y = 0, click = 2})
                    return bret.RUNNING
                end
                if poe2_api.find_text({UI_info = env.UI_info, text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片", min_x = 0}) then
                    poe2_api.click_keyboard('space')
                    return bret.RUNNING
                end
                local item = api_Getinventorys(0xd,0)
                if item and #item > 0 then
                    local point = poe2_api.get_space_point({width = item[1].end_x - item[1].start_x,height = item[1].end_y - item[1].start_y})
                    if point then
                        if poe2_api.find_text({UI_info = env.UI_info, text = "背包"}) then
                            api_ClickScreen(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]),1)
                            api_Sleep(500)
                            return bret.RUNNING
                        else
                            poe2_api.click_keyboard("i")
                            return bret.RUNNING
                        end
                    end
                end
            end
            self.time = 0
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
                    if 1277 <= k.left and k.left <= 1280 and k.top > 793 and k.bottom <= 831 and k.right < 1315 then
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
    Use_Task_Props ={
        run = function(self, env)
            poe2_api.print_log("使用任务道具...")
            poe2_api.dbgp("使用任务道具")
            local bag_info = env.bag_info
            local player_info = env.player_info
            local function is_props(bag)
                local QUEST_PROPS = {
                    "知識之書", "火焰核心", "寶石花顱骨", "寶石殼顱骨",
                    "專精之書", "凜冬狼的頭顱", "燭光精髓", "傑洛特顱骨"
                }
                for _,item in ipairs(bag) do
                    if item.baseType_utf8 and item.category then
                        if poe2_api.table_contains(QUEST_PROPS, item.baseType_utf8)  and item.category == "QuestItem" then
                            return item
                        end
                    end
                end
                return nil
            end
            if bag_info and next(bag_info) then
                local props = is_props(bag_info)
                if (poe2_api.check_item_in_inventory("寶石花顱骨",bag_info) or poe2_api.check_item_in_inventory("寶石殼顱骨",bag_info) or poe2_api.check_item_in_inventory("傑洛特顱骨",bag_info)) and not string.find(player_info.current_map_name_utf8,"own") then
                    return bret.SUCCESS
                end
                if props and next(props) then
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "背包", min_x = 1000, min_y = 32, max_x = 1600, max_y = 81}) then
                        poe2_api.click_keyboard("i")
                        return bret.RUNNING
                    end
                    local point = poe2_api.get_center_position({props.start_x , props.start_y},{props.end_x , props.end_y})
                    if next(point) then
                        poe2_api.right_click(point[1],point[2])
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
            local items_info = poe2_api.get_items_config_info(config)
            -- 不在城区
            if not string.match(player_info.current_map_name_utf8,"own") then
                env.not_exist_stone = {}
                env.is_get_plaque_node = true
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
                poe2_api.print_log("祭祀购买物品类型:"..text)
                local item_key = ""
                if text ~= "" then
                    item_key = text
                else
                    poe2_api.dbgp("999999999999999999")
                    poe2_api.dbgp("item.category_utf8:"..item.category_utf8)
                    for k, v in pairs(my_game_info.type_conversion) do
                        -- poe2_api.dbgp("k:"..k.." v:"..v)
                        if item.category_utf8 == v then
                            item_key = k
                            break
                        end
                    end
                end
                poe2_api.dbgp("item_key:"..type(item_key))
                if item_key and item_key ~= "" then
                    local item_type_list = {}
                    for _, v in ipairs(items_info) do
                        poe2_api.dbgp("type(v):"..v['類型'])
                        
                        if v['類型'] == item_key then
                            poe2_api.dbgp("10101010101")
                            table.insert(item_type_list,v)
                        end
                    end
                    
                    if item_type_list and next(item_type_list) then
                        
                        for _, v in ipairs(item_type_list) do
                            if not v["不撿"] then
                                if v['基礎類型名'] == "全部物品" or string.find(v['基礎類型名'],item.baseType_utf8) then
                                    return true
                                end
                            end
                        end
                    end
                else
                    error("物品名称:"..item.name_utf8.."新物品类型:"..item.category_utf8.."请联系我们添加，感谢您的支持")
                end
                return false

            end
            -- 背包排序
            local function get_store_bag_info(bag)
                local function item_save_as1(goods,cfg_object)
                    local satisfy = {}
                    for _, v in ipairs(items_info) do
                        if not v["不撿"] and v["存倉頁名"] and v["存倉頁名"] ~= "" and string.find(v["基礎類型名"],goods.baseType_utf8) then
                            table.insert(satisfy,v)
                        end
                    end
                    if next(satisfy) then
                        for _, v in ipairs(satisfy) do
                            if not deep_equal_unordered_full(v,cfg_object) then
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
                for _,v in ipairs(bag) do
                    
                    for _, item in ipairs(items_info) do
                        if poe2_api.match_item(v,item) and not item["工會倉庫"] and not item["不撿"] then
                            local a = item_save_as1(v,item)
                            if a then
                                if a == 1 then
                                    table.insert(store_bag2,v)
                                    break
                                end
                            end
                            table.insert(store_bag1,v)
                        elseif poe2_api.match_item(v,item) and item["工會倉庫"] and not item["不撿"] then
                            local a = item_save_as1(v,item)
                            if a then
                                if a == 2 then
                                    table.insert(store_bag1,v)
                                    break
                                end
                            end
                            table.insert(store_bag2,v)
                        end
                    end
                end
                poe2_api.dbgp("store_bag1:"..#store_bag1)
                poe2_api.dbgp("store_bag2:"..#store_bag2)
                for _, v in ipairs(store_bag1) do
                    table.insert(store_bag, v)
                end
                
                for _, v in ipairs(store_bag2) do
                    table.insert(store_bag, v)
                end
               
                return store_bag
                
            end
            -- 判断是否需要存储
            local function get_store_item(bag,is_insert_stone,unique_storage_pages,public_warehouse_pages,map_ys_level_min)
                 
                -- 获取背包中的地图钥匙
                local function get_map_number()
                    local items = {}
                    for _, item in ipairs(bag) do
                        if item.category_utf8 == "Map" then
                            table.insert(items,item)
                        end
                    end
                    if items and next(items) then
                        return items
                    end
                    return false
                end
                -- 获取背包地图数量
                local function map_index()
                    local number = get_map_number()
                    if number and #number >= 4 then
                        return true
                    end
                    return false
                    
                end
                
                -- 获取背包中不打等级的地图钥匙
                local function get_map_not_level()
                    local map = get_map_number()
                    if map then
                        local tiers = {}
                        for _, v in ipairs(map_config) do
                            table.insert(tiers,tonumber(v["階級"]))
                        end
                        if tiers and next(tiers) then
                            for _, v1 in ipairs(map) do
                               if not poe2_api.table_contains(poe2_api.extract_level(v1.baseType_utf8),tiers) then
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
                        for _,item in ipairs(map) do
                            if item.color > 0 and not item.not_identified and match_item_suffixes(api_GetObjectSuffix(item.mods_obj),not_use_map) then
                                return item
                            end
                        end
                    end
                    return false
                end
                -- 找不是疯癫的地图
                local function get_map_not_crazy()
                    local map = get_map_number()
                    local max_map = poe2_api.select_best_map_key({inventory=bag,key_level_threshold=user_map,not_use_map = not_use_map,priority_map = priority_map})
                    if max_map then
                        local max_map_level = poe2_api.extract_level(max_map.baseType_utf8)
                        local is_oiled = nil
                        for _,v in ipairs(map_config) do
                            if v["階級"] == max_map_level then
                                is_oiled = v["塗油設置"]["是否塗油"]
                            end
                        end
                        if is_oiled then
                            local function is_crazy(item)
                                local item_entry = api_GetObjectSuffix(item.mods_obj)
                                if item_entry and next(item_entry) then
                                    for _, entry in ipairs(item_entry) do
                                        if string.find(entry.name_utf8,"譫妄") then
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
                local function item_save_as(goods,cfg_object)
                    local satisfy = {}
                    for _, v in ipairs(items_info) do
                        if not v["不撿"] and v["存倉頁名"] and v["存倉頁名"] ~= "" and string.find(v["基礎類型名"],goods.baseType_utf8) then
                            table.insert(satisfy,v)
                        end
                    end
                    if satisfy and next(satisfy) then
                        for _, v in ipairs(satisfy) do
                            if not deep_equal_unordered_full(v,cfg_object) then
                                if v["工會倉庫"] then
                                    return {goods,v["存倉頁名"],1}
                                else
                                    return {goods,v["存倉頁名"],0}
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
                local min_map = poe2_api.select_best_map_key({inventory=bag,index = 1,no_categorize_suffixes = 1,min_level=map_ys_level_min,trashest=true})
                
                if unique_storage_pages and next(unique_storage_pages) then
                    for _, i in ipairs(unique_storage_pages) do
                        for _, b in ipairs(bag) do
                            -- poe2_api.dbgp("b.baseType_utf8:"..b.baseType_utf8)
                            for _, item in ipairs(items_info) do
                                if poe2_api.match_item(b,item) and item["存倉頁名"] == i and not item["工會倉庫"] and not item["不撿"] then
                                    if ((item["名稱"] and item["名稱"] ~= "" and item["名稱"] ~= "全部物品") or get_ct_config(item)) and b.not_identified then
                                        poe2_api.dbgp("1")
                                        break
                                    end
                                    if b.baseType_utf8 == "知識卷軸" then
                                        break
                                    end
                                    if b.category_utf8 ~= "StackableCurrency" and poe2_api.is_do_without_pick_up(b,items_info) then
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
                                            env.store_item = {map_not_level,i,0}
                                            poe2_api.dbgp("4")
                                            return true
                                        end
                                        if b.color > 0 then
                                            if not_use_map then
                                                local not_entry = get_map_not_entry()
                                                if not_entry then
                                                    env.store_item = {not_entry,i,0}
                                                    poe2_api.dbgp("5")
                                                    return true
                                                end    
                                            end   
                                        end
                                        if not map_index() then
                                            poe2_api.dbgp("6")
                                            break
                                        end
                                        local crazy = get_map_not_crazy()
                                        if crazy then
                                            env.store_item = {crazy,i,0}
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
                                    if poe2_api.table_contains(b.category_utf8,my_game_info.equip_type) and b.color > 0 and not b.not_identified then
                                        local suffixes = api_GetObjectSuffix(b.mods_obj)
                                        if suffixes and next(suffixes) and not poe2_api.filter_item(b,suffixes,config["物品過濾"]) then
                                            poe2_api.dbgp("10")
                                            break
                                        end
                                    end
                                    local save_as = item_save_as(b,item)
                                    if save_as and next(save_as) then
                                        env.store_item  = save_as
                                        poe2_api.dbgp("11")
                                        return true
                                    end
                                    env.store_item = {b,i,0}
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
                                if poe2_api.match_item(b,item) and item["存倉頁名"] == i and item["工會倉庫"] and not item["不撿"] then
                                    if ((item["名稱"] and item["名稱"] ~= "" and item["名稱"] ~= "全部物品") or get_ct_config(item)) and b.not_identified then
                                        break
                                    end
                                    if b.baseType_utf8 == "知識卷軸" then
                                        break
                                    end
                                    if b.category_utf8 ~= "StackableCurrency" and poe2_api.is_do_without_pick_up(b,items_info) then
                                        break
                                    end
                                    if b.category_utf8 == "QuestItem" then
                                        break
                                    end
                                    if b.category_utf8 == "Map" then
                                        local map_not_level = get_map_not_level()
                                        if map_not_level then
                                            env.store_item = {map_not_level,i,1}
                                            return true
                                        end
                                        if b.color > 0 then
                                            if not_use_map then
                                                local not_entry = get_map_not_entry()
                                                if not_entry then
                                                    env.store_item = {not_entry,i,1}
                                                    return true
                                                end    
                                            end   
                                        end
                                        if not map_index() then
                                            break
                                        end
                                        local crazy = get_map_not_crazy()
                                        if crazy then
                                            env.store_item = {crazy,i,1}
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
                                    if poe2_api.table_contains(b.category_utf8,my_game_info.equip_type) and b.color > 0 and not b.not_identified then
                                        local suffixes = api_GetObjectSuffix(b.mods_obj)
                                        if suffixes and next(suffixes) and not poe2_api.filter_item(b,suffixes,config["物品過濾"]) then
                                            break
                                        end
                                    end
                                    local save_as = item_save_as(b,item)
                                    if save_as and next(save_as) then
                                        env.store_item  = save_as
                                        return true
                                    end
                                    env.store_item = {b,i,1}
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
                return bret.RUNNING
            end
            
            -- 是否需要合成
            if env.is_need_strengthen then
                return bret.SUCCESS
            end
            -- 背包为空
            if not bag_info or not next(bag_info) then
                return bret.SUCCESS
            end
            -- 是否需要点金
            if not env.is_public_warehouse then
                return bret.SUCCESS
            end
            -- 碑牌是否需要点金
            if not env.is_public_warehouse_plaque then
                return bret.SUCCESS
            end
            local items_info = poe2_api.get_items_config_info(config)
            local unique_storage_pages = {}
            for _, v in ipairs(items_info) do
                if v['存倉頁名'] and v['存倉頁名'] ~= "" and not v['工會倉庫'] and not v["不撿"] then
                    table.insert(unique_storage_pages,v['存倉頁名'])
                end
            end
            
            local public_warehouse_pages = {}
            for _, v in ipairs(items_info) do
                if v['存倉頁名'] and v['存倉頁名'] ~= "" and v['工會倉庫'] and not v["不撿"] then
                    table.insert(public_warehouse_pages,v['存倉頁名'])
                end
            end
            -- 未配置物品过滤
            if (not unique_storage_pages or not next(unique_storage_pages)) and (not public_warehouse_pages or not next(public_warehouse_pages)) then
                return bret.SUCCESS
            end
            local map_level_type = {}
            local map_ys_level_min = 0
            for _, v in ipairs(items_info) do
                if string.find(v["類型"],"地圖鑰匙") and not v["不撿"] then
                    table.insert(map_level_type,v['等級'])
                end
            end
            if next(map_level_type) then
                local map_type = map_level_type[1]["type"]
                if map_type == "exact" then
                    local item_level = map_level_type[1]["value"]
                    map_ys_level_min = item_level-3
                else
                    local min_level = map_level_type[1]["min"]
                    map_ys_level_min = min_level
                end
            end
            -- 是否需要插入碑牌
            local is_insert_stone = env.is_insert_stone
            local bag_store_info = get_store_bag_info(bag_info)
            -- poe2_api.dbgp("bag_store_info",type(bag_store_info),#bag_store_info)
            local store = get_store_item(bag_store_info,is_insert_stone,unique_storage_pages,public_warehouse_pages,map_ys_level_min)
            
            if not store then
                -- poe2_api.dbgp("ooooooooooooooo")
                local not_config_altar_item = nil
                for _, v in ipairs(bag_info) do
                    if poe2_api.table_contains(altar_shop_config,v.baseType_utf8) then
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
                        error("未配置购物祭祀物品：->"..not_config_altar_item.name_utf8 .."<-,物品类型为:->".. item_key .."<-,相关存储页请在物品配置中添加")
                    end
                end
                env.exchange_status = false
                return bret.SUCCESS
            end
            poe2_api.find_text({text = "再會",UI_info = env.UI_info,click =2})
            if poe2_api.find_text({text = {'重鑄台'}, UI_info=env.UI_info,min_x=0}) and poe2_api.find_text({text = '摧毀三個相似的物品，重鑄為一個新的物品', UI_info=env.UI_info,min_x=0}) then
                poe2_api.click_keyboard('space')
                api_Sleep(500)
                return bret.RUNNING
            end
            -- if poe2_api.find_text({text = {'世界地圖',"購買或販賣物品"}, UI_info=env.UI_info,min_x=0}) then
            if poe2_api.find_text({text = {'世界地圖'}, UI_info=env.UI_info,min_x=0}) then
                -- poe2_api.dbgp("999999999999999999999999999999999999999999")
                poe2_api.click_keyboard('space')
                api_Sleep(500)
                return bret.RUNNING
            end
            local store_item = env.store_item
            poe2_api.dbgp("store_item",store_item[1].baseType_utf8,store_item[3])
            -- api_Sleep(5000)
            if store_item[3] == 0 then
                if poe2_api.find_text({UI_info=env.UI_info,text="強調物品",min_y=700,min_x=250}) and poe2_api.find_text({UI_info=env.UI_info,text="公會倉庫",min_x=0,min_y=32,max_x=381,max_y=81}) then
                    poe2_api.click_keyboard('space')
                    api_Sleep(500)
                    return bret.RUNNING
                end
            elseif store_item[3] == 1 then
                poe2_api.dbgp("公仓")
                if poe2_api.find_text({UI_info=env.UI_info,text="強調物品",min_y=700,min_x=250}) and poe2_api.find_text({UI_info=env.UI_info,text="倉庫",min_x=0,min_y=32,max_x=381,max_y=81}) then
                    poe2_api.click_keyboard('space')
                    api_Sleep(500)
                    return bret.RUNNING
                end
            end
            if env.store_item[3] == 0 then
                env.warehouse_type_interactive = "个仓"
            else
                env.warehouse_type_interactive = "公仓"
            end
            poe2_api.dbgp("存仓-----------------------------------------------1010101")
            return bret.FAIL
            
        end
    },

    -- 存储动作
    Store_Items = {
        run = function(self, env)
            poe2_api.print_log("存储行为...")
            poe2_api.dbgp("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
            local text = ""
            if env.warehouse_type_interactive == "个仓" then
                text = "倉庫"
                if poe2_api.find_text({text = "強調物品",UI_info = env.UI_info,min_x = 250,min_y = 700}) 
                and poe2_api.find_text({text = "公會倉庫",UI_info = env.UI_info,min_x=0,min_y=32,max_x=381,max_y=81}) then
                    poe2_api.click_keyboard("space")
                    api_Sleep(500)
                    return bret.RUNNING
                end
            elseif env.warehouse_type_interactive == "公仓" then
                text = "公會倉庫"
                if poe2_api.find_text({text = "強調物品",UI_info = env.UI_info,min_x = 250,min_y = 700}) 
                and poe2_api.find_text({text = "倉庫",UI_info = env.UI_info,min_x=0,min_y=32,max_x=381,max_y=81}) then
                    poe2_api.click_keyboard("space")
                    api_Sleep(500)
                    return bret.RUNNING
                end
            else
                error("未知的仓库类型")
            end
            if not poe2_api.find_text({text = "強調物品",UI_info = env.UI_info,min_x = 250,min_y = 700}) then
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
            local function is_get_map_color(map_info,map)
                if not map_info or not next(map_info) then
                    return false
                end
                for k, v in ipairs(map_info) do
                    if poe2_api.extract_level(map.baseType_utf8) == k then
                        if v then
                            if poe2_api.table_contains(map.color,v) then
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
                    if not item["不撿"] and string.find(item["類型"],"地圖鑰匙") and not item["工會倉庫"] then
                        table.insert(page,item["存倉頁名"])
                        index = 0
                    end  
                end
            else
                for _, item in ipairs(items_info) do
                    if not item["不撿"] and string.find(item["類型"],"地圖鑰匙") and item["工會倉庫"] then
                        table.insert(page,item["存倉頁名"])
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
                        if env.warehouse_full and not poe2_api.get_space_point({width=2,height=4,info=bag_info}) then
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
            if not poe2_api.find_text({text="背包",UI_info=env.UI_info,min_x=1000,min_y=32,max_x=1600,max_y=81}) then
                poe2_api.click_keyboard("i")
                poe2_api.dbgp("开背包5")
                self.is_wait = true
                self.current = api_GetTickCount64()
                self.wait_item = 1000
                return bret.RUNNING
            end
            self.is_wait = false
            local tab_list_button = poe2_api.click_text_UI({text = "tab_list_button", UI_info = env.UI_info,ret_data = true})
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
                poe2_api.print_log("找不到仓库页2222 ->"..store_item[2].."<-")
                api_Sleep(1000)
                return bret.RUNNING
            end
            if not tab_list_button then
                
                if self.type ~= store_item[2] or precut_page.manage_index == 0 then
                    if poe2_api.find_text({text=store_item[2],UI_info=env.UI_info,max_y=90,min_x=0,max_x=500,click = 2}) then
                        self.is_wait = true
                        self.current = api_GetTickCount64()
                        self.wait_item = 500
                        self.type = store_item[2]
                        return bret.RUNNING
                    
                    else
                        poe2_api.print_log("找不到仓库页333 ->"..store_item[2].."<-")
                        api_Sleep(1000)
                        return bret.RUNNING
                    end
                end
            else
                poe2_api.dbgp("UI_info",env.UI_info)
                poe2_api.printTable(env.UI_info)
                local lock = poe2_api.get_game_control_by_rect({ UI_info = env.UI_info,min_x = 549,min_y = 34,max_x = 584,max_y = 74})
                local lock_button = {}
                for _,v in ipairs(lock) do
                    if v.name_utf8 == "" and v.text_utf8 == "" then
                        table.insert(lock_button,v)
                    end
                end
                if not lock_button or not next(lock_button) then
                    api_ClickScreen(poe2_api.toInt((tab_list_button.left+tab_list_button.right)/2),poe2_api.toInt((tab_list_button.top+tab_list_button.bottom)/2),1)
                    api_Sleep(2000)
                    api_ClickScreen(poe2_api.toInt(((tab_list_button.left+tab_list_button.right)/2) + 30),poe2_api.toInt(((tab_list_button.top+tab_list_button.bottom)/2) - 30),1)
                    api_Sleep(1000)
                    return bret.RUNNING
                end
                if self.type ~= store_item[2] or precut_page.manage_index == 0 then
                    if poe2_api.find_text({text=store_item[2],UI_info=env.UI_info,max_y=469,min_x=556,min_y=20,max_x=851,click = 2}) then
                        self.is_wait = true
                        self.current = api_GetTickCount64()
                        self.wait_item = 500
                        self.type = store_item[2]
                        return bret.RUNNING
                    else
                        poe2_api.print_log("找不到仓库页1111 ->"..store_item[2].."<-")
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
                    local warehouse = api_Getinventorys(precut_page.manage_index,index)
                    if warehouse and next(warehouse) then
                        local a = {}
                        for _, v in ipairs(warehouse) do
                            if v.category_utf8 == "Map" and not v.contaminated and poe2_api.extract_level(v.baseType_utf8)<15 and is_get_map_color(map_color_info,v) then
                                table.insert(a,v.baseType_utf8)
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
            if poe2_api.table_contains(precut_page.type,{0,1}) then
                local warehouse = api_Getinventorys(precut_page.manage_index,index)
                if warehouse and next(warehouse) then
                    local w = store_item[1].end_x - store_item[1].start_x
                    local h = store_item[1].end_y - store_item[1].start_y
                    local point = poe2_api.get_space_point({width=w,height=h,w=12,h=12,gox=14,goy=99,info=warehouse})
                    if not point then 
                        currency_exchange_is_opens = currency_exchange_is_opens["是否自動對換"] or false
                        if currency_exchange_is_opens then
                            if env.exchange_status then
                                error("仓库已满，手动清理2222")
                            end
                            if env.warehouse_full and not poe2_api.get_space_point({width=2,height=4,info=bag_info}) then
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
                local warehouse = api_Getinventorys(precut_page.manage_index,index)
                if warehouse and next(warehouse) then
                    local w = store_item[1].end_x - store_item[1].start_x
                    local h = store_item[1].end_y - store_item[1].start_y
                    local point = poe2_api.get_space_point({width=w,height=h,w=24,h=24,gox=15,goy=100,grid_x=22,grid_y=22,info=warehouse})
                    if not point then 
                        currency_exchange_is_opens = currency_exchange_is_opens["是否自動對換"] or false
                        if currency_exchange_is_opens then
                            if env.exchange_status then
                                error("仓库已满，手动清理3333")
                            end
                            if env.warehouse_full and not poe2_api.get_space_point({width=2,height=4,info=bag_info}) then
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
                api_ClickScreen(poe2_api.toInt(x),poe2_api.toInt(y),0)
                api_Sleep(300)
                poe2_api.click_keyboard('alt')
                api_Sleep(300)
                if poe2_api.find_text({text="私訊",UI_info=env.UI_info,min_x=0,min_y=0,max_x=1000}) then
                    poe2_api.click_keyboard("enter")
                    api_Sleep(300)
                end
            end
            poe2_api.ctrl_left_click_bag_items(store_item[1].obj,bag_info,3)
            api_Sleep(300)
            return bret.RUNNING
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
            
            -- poe2_api.dbgp("打开仓库...")
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

            local function get_object(name,data_list)
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
                    local warehouse_obj1 = get_object("倉庫",env.range_info)
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
                    local warehouse_obj1 = get_object("公會倉庫",env.range_info)
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
                obj ,
                text,
                warehouse
            )

            -- 检查是否已经打开仓库界面
            local emphasize_text = poe2_api.find_text({UI_info = env.UI_info, text = "強調物品", min_x = 250, min_y = 700})
            local warehouse_text = poe2_api.find_text({UI_info = env.UI_info, text = text, min_x=0, min_y=32, max_x=381, max_y=81})
            
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

            if distance > 25 then
                poe2_api.dbgp("距离仓库太远(", distance, ")，返回FAIL")
                env.interactive = obj
                return bret.FAIL
            else
                local continue_game = poe2_api.find_text({UI_info = env.UI_info, text = "繼續遊戲", click = 2})
                if continue_game then
                    poe2_api.dbgp("发现'繼續遊戲'文本，返回RUNNING")
                    return bret.RUNNING
                end

                poe2_api.dbgp("尝试移动到仓库位置:", warehouse.grid_x, warehouse.grid_y)

                api_ClickMove(poe2_api.toInt(warehouse.grid_x), poe2_api.toInt(warehouse.grid_y), poe2_api.toInt(player_info.world_z), 1)

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

    -- 清理遮挡页面
    Game_Block = {
        run = function(self, env)
            poe2_api.print_log("游戏阻挡处理模块开始执行...")
            poe2_api.dbgp("=== 开始处理游戏阻挡 ===")
            
            local current_time = api_GetTickCount64()
            
            local player_info = env.player_info

            -- 检查交易拒绝情况
            local refuse_click = {"等待玩家接受交易請求..."}
            if poe2_api.find_text({UI_info = env.UI_info, text = refuse_click, min_x = 0, add_x = 253, click = 2}) then
                poe2_api.dbgp("检测到交易请求等待，将执行拒绝操作")
                return bret.RUNNING
            end

            ---常驻
            local all_check = {
                {UI_info = env.UI_info, text = "繼續遊戲", add_x = 0, add_y = 0, click = 2},
                {UI_info = env.UI_info, text = "寶石切割", add_x = 280, add_y = 17, click = 2},
                {UI_info = env.UI_info, text = "技能", min_x = 0, add_x = 253, click = 2},
            }
            -- 检查单个按钮
            for _, check in ipairs(all_check) do
                if poe2_api.find_text(check) then
                    poe2_api.dbgp(string.format("检测到按钮: %s，将执行点击操作", check.text))
                    return bret.RUNNING
                end
            end


            if poe2_api.find_text({UI_info = env.UI_info, text = "背包", add_x = 250, min_x = 0, click = 2}) then
                return bret.RUNNING
            end

            if poe2_api.find_text({UI_info = env.UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2}) then
                return bret.RUNNING
            end

            -- 检查顶部中间页面按钮
            local top_mid_page = {"傳送", "Checkpoints"}
            if poe2_api.find_text({UI_info = env.UI_info, text = top_mid_page, min_x = 0, add_x = 215, click = 2}) then
                return bret.RUNNING
            end

            -- 按键
            if not self.once_check then
                api_Log("检查是否在主页面11111")
                local once_check = {
                    {UI_info = env.UI_info, text = "精選", add_x = 677, min_x = 0, add_y = 10, click = 2},
                    
                    {UI_info = env.UI_info, text = "社交", min_x = 0, add_x = 253, click = 2},
                    {UI_info = env.UI_info, text = "角色", min_x = 0, add_x = 253, click = 2},
                    {UI_info = env.UI_info, text = "活動", min_x = 0, add_x = 253, click = 2},
                    {UI_info = env.UI_info, text = "選項", min_x = 0, add_x = 253, click = 2},
                    {UI_info = env.UI_info, text = "重置天賦點數", min_x = 0, add_x = 215, click = 2},
                    {UI_info = env.UI_info, text = "天賦技能", min_x = 0, add_x = 215, click = 2},
                    {UI_info = env.UI_info, text = "黯幣",min_x = 0,min_y = 0,max_y = 81,add_x = 673,add_y = 4,click = 2},
                    {UI_info = env.UI_info, text = "願望清單",min_x = 0,min_y = 0,max_y = 81,add_x = 673,add_y = 4,click = 2},

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
                if poe2_api.find_text({UI_info = env.UI_info, text = "啟動失敗。地圖無法進入。"}) then
                    poe2_api.dbgp("检测到地图启动失败提示，设置need_SmallRetreat为true")
                    env.need_SmallRetreat = true
                    return bret.RUNNING
                end

                local reward_click = {"任務獎勵","獎勵"}
                if poe2_api.find_text({UI_info = env.UI_info, text = reward_click,min_x = 100}) then 
                    poe2_api.find_text({UI_info = env.UI_info, text = reward_click, min_x = 0 ,add_y = 50,click = 2})
                    if poe2_api.find_text({UI_info = env.UI_info, text ="背包"} ) then
                        local point = poe2_api.get_space_point({width = 2,height = 2,index = 1})
                        if point then
                            api_ClickScreen(poe2_api.toInt(point[0]),poe2_api.toInt(point[1]),1)
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
                    {UI_info = env.UI_info, text = "購買或販賣", add_x = 270, add_y = -9, click = 2},
                    {UI_info = env.UI_info, text = "選擇藏身處", add_x = 516, click = 2},
                    {UI_info = env.UI_info, text = "通貨交換", add_x = 300, click = 2},
                    {UI_info = env.UI_info, text = "重組", add_x = 210, add_y = -50, click = 2},
                    {UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", add_x = 240, min_x = 0, click = 2},
                    {UI_info = env.UI_info, text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片", add_x = 160, add_y = -60, min_x = 0, click = 2},
                    {UI_info = env.UI_info, text = "世界地圖", min_x = 0, add_x = 215, click = 2},
                }
                -- 检查单个按钮
                for _, check in ipairs(in_safe) do
                    if poe2_api.find_text(check) then
                        poe2_api.dbgp(string.format("检测到按钮: %s，将执行点击操作", check.text))
                        return bret.RUNNING
                    end
                end
                -- 检查背包保存提示
                local save_click = {"你無法將此背包丟置於此。請問要摧毀它嗎？"}
                if poe2_api.find_text({UI_info = env.UI_info, text = save_click, min_x = 0, click = 2}) then
                    poe2_api.dbgp("检测到背包保存提示，将执行保留操作")
                    return bret.RUNNING
                end
                -- 检查仓库页面
                local warehouse_page = {"倉庫","聖域鎖櫃","公會倉庫"}
                if poe2_api.find_text({UI_info = env.UI_info, text = small_page, min_x = 0, add_x = 253}) and 
                poe2_api.find_text({UI_info = env.UI_info, text = "强調物品", min_x = 0}) then
                    poe2_api.dbgp("检测到仓库页面，将执行点击操作")
                    poe2_api.find_text({UI_info = env.UI_info, text = small_page, min_x = 0, click = 2, add_x = 253})
                    return bret.RUNNING
                end
                
                local item = api_Getinventorys(0xd,0)
                if item and next(item) then
                    local width = item[1].end_x - item[1].start_x
                    local height = item[1].end_y - item[1].start_y
                    local point = poe2_api.get_space_point(width, height)
                    
                    poe2_api.dbgp(string.format("物品尺寸: 宽%d, 高%d", width, height))
                    
                    if point then
                        poe2_api.dbgp(string.format("获取到空间点: (%d, %d)", point[1], point[2]))
                        
                        if poe2_api.find_text("背包") then
                            poe2_api.dbgp("检测到背包文字，将执行点击操作")
                            api_ClickScreen(point[1], point[2])
                            api_Sleep(100)
                            api_ClickScreen(point[1], point[2],1)
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
            
            local function need_move(obj,dis)
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
                    env.end_point = {x, y}
                    return {x, y}
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
                poe2_api.dbgp("交互对象: "..target_obj.name_utf8.." | 位置: "..target_obj.grid_x..","..target_obj.grid_y.." | 距离: "..distance)
                
                if need_move(target_obj,15) then
                    poe2_api.dbgp("移动交互对象")
                    return bret.FAIL
                end

                poe2_api.dbgp("点击交互对象")
                
                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                    api_Sleep(1000)
                end

                if target_obj.name_utf8 == "MapDevice" then
                    local m_list = {"黃金製圖儀", "地圖裝置"}
                    api_Sleep(800)
                    local maps = check_in_range('Metadata/Terrain/Missions/Hideouts/Objects/MapDeviceVariants/ZigguratMapDevice')
                    if poe2_api.find_text({UI_info = env.UI_info, text = '地圖裝置', click = 2, refresh = true}) then
                        api_Sleep(100)
                        return bret.RUNNING
                    end
                    if maps then
                        -- api_ClickMove(maps.grid_x, maps.grid_y, maps.world_z + 110, 0)
                        api_ClickMove(poe2_api.toInt(maps.grid_x), poe2_api.toInt(maps.grid_y), poe2_api.toInt(maps.world_z - 70), 0)
                        api_Sleep(800)
                    end
                    for _, i in ipairs(m_list) do
                        if poe2_api.find_text({UI_info = env.UI_info, text = i, click = 2, refresh = true}) then
                            api_Sleep(100)
                            return bret.RUNNING
                        end
                    end
                end
                
                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and target_obj.name_utf8 ~= '傳送點' and not map_obj then
                    poe2_api.find_text({UI_info = env.UI_info, text = interactive_object, click = 2, refresh = true})
                    api_Sleep(100)
                    return bret.RUNNING
                end
                
                if player_info.isMoving then
                    poe2_api.dbgp("等待静止")
                    api_Sleep(1000)
                    return bret.RUNNING
                end

                if not poe2_api.find_text({UI_info = env.UI_info, text = interactive_object, click = 2, max_x = 1200, refresh = true}) then
                    api_ClickMove(poe2_api.toInt(target_obj.grid_x), poe2_api.toInt(target_obj.grid_y),poe2_api.toInt(player_info.world_z), 1)
                end
                api_Sleep(100)
            else
                poe2_api.dbgp1("交互对象: "..interactive_object.name_utf8.." | 位置: "..interactive_object.grid_x..","..interactive_object.grid_y)
                poe2_api.dbgp("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                local a = poe2_api.point_distance(interactive_object.grid_x,interactive_object.grid_x,env.player_info)
                poe2_api.dbgp("a:",a)
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
                poe2_api.dbgp("text:",text)
                local point = need_move(interactive_object,30)
                if point then
                    poe2_api.dbgp("text1:",text)
                    -- poe2_api.dbgp("移动交互对象")
                    if env.path_list and next(env.path_list) then
                        local distence = poe2_api.point_distance(env.path_list[#env.path_list].x,env.path_list[#env.path_list].y,point)
                        if distence and distence > 20 and text ~= "門" then
                            poe2_api.dbgp("交互目标点，不一致，清空路径")
                            poe2_api.print_log("清路径555")
                            env.path_list = {}
                        end
                    end
                    poe2_api.dbgp("text2:",text)
                    -- poe2_api.printTable(point)
                    return bret.FAIL
                end
                if player_info.isMoving then
                    poe2_api.dbgp("等待静止")
                    api_Sleep(200)
                    return bret.RUNNING
                end
                if interactive_object and (not text or text == "" or poe2_api.table_contains(text,{"門","聖潔神殿"}) or not poe2_api.find_text({text = text, UI_info = env.UI_info, min_x=200,max_y=750,match=2,max_x=1200,sorted = true, click=2})) then
                    if poe2_api.table_contains(text,{"門","聖潔神殿"}) then
                        if text == "門" and poe2_api.find_text({text = "出土遺物", UI_info = env.UI_info, min_x=200,max_y=750,match=2,max_x=1200,sorted = true}) then
                            poe2_api.click_keyboard("z")
                            self.is_click_z = true
                            return bret.RUNNING
                        end
                        api_ClickMove(poe2_api.toInt(interactive_object.grid_x), poe2_api.toInt(interactive_object.grid_y), poe2_api.toInt(player_info.world_z - 70), 1)
                    else
                        if env.need_item and env.need_item == interactive_object then
                            api_ClickMove(poe2_api.toInt(interactive_object.grid_x), poe2_api.toInt(interactive_object.grid_y), poe2_api.toInt(player_info.world_z), 1)
                        else
                            local ok, value = pcall(function() 
                                return interactive_object.path_name_utf8 
                            end)
                            if ok and value ~= nil then
                                if string.find("Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable", interactive_object.path_name_utf8) then
                                    poe2_api.find_text({text = "點擊以開始祭祀", UI_info = env.UI_info, min_x=200,max_y=750,match=2,max_x=1200,sorted = true, click=2})
                                else
                                    api_ClickMove(poe2_api.toInt(interactive_object.grid_x), poe2_api.toInt(interactive_object.grid_y), poe2_api.toInt(player_info.world_z - 250), 1)
                                end
                            else
                                api_ClickMove(poe2_api.toInt(interactive_object.grid_x), poe2_api.toInt(interactive_object.grid_y), poe2_api.toInt(player_info.world_z - 250), 1)
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
                if poe2_api.table_contains(text,{"水閘門控制桿","把手"}) then
                    api_Sleep(500)
                    poe2_api.dbgp1("点击水闸门控制杆,等待目标")
                    poe2_api.dbgp1("wait_target: ",wait_target)
                    env.wait_target = true
                end
                local ok, value = pcall(function() 
                    return interactive_object.path_name_utf8 
                end)
                if ok and value ~= nil then
                    if string.find("Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable", interactive_object.path_name_utf8) then
                        -- env.afoot_altar = interactive_object
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

    -- 检查是否到达点(别名)
    Is_Arrive = {
        run = function(self, env)
            poe2_api.print_log("检查是否到达目标点(Is_Arrive)...")
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            local is_arrive_end_dis = 25 -- 默认值

            if player_info.life == 0 then
                env.end_point = nil
                env.run_point = nil
                env.path_list = nil
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
                local path_list = env.path_list
                dis = poe2_api.point_distance(point[1], point[2], player_info)
                if api_HasObstacleBetween(point[1], point[2]) and dis and ( dis < is_arrive_end_dis ) then
                    poe2_api.dbgp1("有路径，有射线")
                    env.is_arrive_end = true
                    env.end_point = nil
                    env.path_list = nil
                    env.run_point = nil
                    poe2_api.time_p("检查是否到达目标点(Is_Arrive)(RUNNING1)... 耗时 --> ", api_GetTickCount64() - current_time)
                    return bret.RUNNING
                end
                env.is_arrive_end = false
                poe2_api.time_p("检查是否到达目标点(Is_Arrive)(SUCCESS2)... 耗时 --> ", api_GetTickCount64() - current_time)
                return bret.SUCCESS
            else
                env.is_arrive_end = false
                env.path_list = nil
                poe2_api.time_p("检查是否到达目标点(mydian)(RUNNING)... 耗时 --> ", api_GetTickCount64() - current_time)
                return bret.RUNNING
            end
        end
    },

    -- 获取路径
    GET_Path = {
        run = function(self, env)
            poe2_api.print_log("获取路径...")
            local start_time = api_GetTickCount64()
            if self.FAIL_count == nil then
                poe2_api.dbgp("[GET_Path] 初始化：失败次数")
                self.FAIL_count = 0
                self.time = 0
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
                    env.target_point = {path_list[1].x, path_list[1].y}
                    -- poe2_api.dbgp("len 5465 移除已使用的点")
                    -- table.remove(path_list, 1) -- 移除已使用的点
                end
                poe2_api.dbgp(path_list[1].x, path_list[1].y)
                poe2_api.time_p("已有路径(SUCCESS) 耗时 -->", api_GetTickCount64() - start_current_time)
                return bret.SUCCESS
            end
            
            -- 计算最近可到达的点
            point = api_FindNearestReachablePoint(point[1],point[2], 50, 0)
            poe2_api.dbgp("计算最近可到达的点")
            poe2_api.dbgp(point.x, point.y)
            poe2_api.dbgp("yuasnhi")
            poe2_api.dbgp(env.end_point[1],env.end_point[2])

            -- 计算起点
            local player_position = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y, 50, 0)

            local result = api_FindPath(player_position.x, player_position.y, point.x, point.y)
            poe2_api.time_p("计算路径成功 耗时 -->", api_GetTickCount64() - start_current_time,"两点：{"..player_position.x..","..player_position.y.."} -> {"..point.x..","..point.y.."}")
            
            if result and #result > 0 then
                -- 处理路径结果
                local result_start_current_time = api_GetTickCount64()
                result = poe2_api.extract_coordinates(result, 22)
                self.time= 0
                if #result > 1 then
                    table.remove(result, 1) -- 移除起点
                    poe2_api.dbgp("移除起点")
                    env.path_list = result
                    env.target_point = {result[1].x, result[1].y}
                    -- table.insert(result, {x = env.end_point[1], y = env.end_point[2]}) -- 替换end_x,end_y为实际坐标
                    table.insert(result, {x = env.end_point[1], y = env.end_point[2]}) -- 替换end_x,end_y为实际坐标

                    poe2_api.dbgp("[GET_Path] 路径计算成功，点数: " .. #result)
                end
                poe2_api.time_p("处理路径结果 耗时 -->", api_GetTickCount64() - result_start_current_time)
                return bret.SUCCESS
            else
                
                -- 路径计算失败处理
                poe2_api.dbgp("[GET_Path] 计算路径失败")
                if self.time == 0 then
                    self.time = api_GetTickCount64()
                end
                local ctime = start_time - self.time
                if ctime > 30 * 1000 then
                    poe2_api.dbgp("[GET_Path] 未找到路径 45 秒，恢复初始地图")
                    api_RestoreOriginalMap()
                    if ctime > 60 * 1000 then
                        poe2_api.dbgp("[GET_Path] 未找到路径 60 秒，回城")
                        if string.find(player_info.current_map_name_utf8, "own") then
                            self.time = 0 
                            return bret.RUNNING
                        end
                        for _, name in ipairs(my_game_info.city_map) do
                            if poe2_api.find_text({UI_info = env.UI_info, text = name, click = 2}) then
                                return bret.RUNNING
                            end
                        end
                        api_ClickScreen(1230,815,0)
                        api_Sleep(500)
                        api_ClickScreen(1230,815,1)
                        return bret.RUNNING
                    end
                end
                local function  get_sorted_obj(obj_list, obj_name)
                    local result={}
                    for i,v in ipairs(obj_list) do
                        if v.name_utf8 == obj_name then
                            table.insert(result, v)
                        end
                    end
                    return result
                end
                -- 竞技场处理
                local objlist = poe2_api.get_sorted_list(range_info,player_info)
                local arena_list = get_sorted_obj(objlist,"競技場")
                if poe2_api.find_text({UI_info = env.UI_info, text = "競技場", min_x = 0}) 
                    and arena_list and arena_list[1].hasLineOfSight and arena_list[1].is_selectable 
                    and api_FindPath(player_info.grid_x,player_info.grid_y,arena_list[1].grid_x,arena_list[1].grid_y) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "競技場", min_x = 0,click = 2})
                    env.end_point = nil
                    env.empty_path = false
                    env.is_arrive_end = false
                    env.path_list = {}
                    return bret.RUNNING
                end
                -- 城镇处理
                if poe2_api.table_contains(player_info.current_map_name_utf8, "own") then
                    local result = api_FindNearestReachablePoint(point.x, point.y,50,0)
                    api_ClickMove(poe2_api.toInt(result.x), poe2_api.toInt(result.y), poe2_api.toInt(player_info.world_z), 0)
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
                return bret.RUNNING  -- 初始化后返回 RUNNING，等待下一帧继续执行
            end
            if env.roll_time ==nil or self.current_time ==nil then
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
            local last_pos = env.last_position_story
            env.roll_time = start_time - self.current_time
            local roll_time = env.roll_time 
            local distance = poe2_api.point_distance(last_pos[1], last_pos[2],player_info)
            
            -- 检查终点是否变化
            local end_point = env.end_point
            if not self.last_point and end_point then
                poe2_api.dbgp("设置last_point")
                self.last_point = end_point
            end
            
            -- 如果终点变化超过阈值，重置路径
            if self.last_point and end_point and env.path_list then
                local last_path_point = env.path_list[#env.path_list]
                local dis = poe2_api.point_distance(
                    self.last_point[1], self.last_point[2],
                    {end_point[1], end_point[2]}
                )
                if dis and dis > 25 then
                    self.last_point = end_point
                    poe2_api.print_log("清路径888")
                    env.path_list = nil
                    env.target_point = {}
                    env.is_arrive_end = true
                    env.end_point = nil
                    poe2_api.time_p("执行移动(RUNNING1) 耗时 -->", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
            end

            -- 超时翻滚逻辑
            if roll_time > 5*1000 and distance < self.movement_threshold then
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
                    api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y), poe2_api.toInt(player_info.world_z), 0)
                    api_Sleep(300)
                    api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y), poe2_api.toInt(player_info.world_z), 1)
                    api_Sleep(300)
                end
                -- 根据名字排序 
                local function  get_sorted_obj(obj_list, obj_name)
                    local result={}
                    for i,v in ipairs(obj_list) do
                        if v.name_utf8 == obj_name then
                            table.insert(result, v)
                        end
                    end
                    return result
                end
                -- 竞技场处理
                local objlist = poe2_api.get_sorted_list(range_info,player_info)
                local arena_list = get_sorted_obj(objlist,"競技場")
                if poe2_api.find_text({UI_info = env.UI_info, text = "競技場", min_x = 0}) 
                    and arena_list and arena_list[1].hasLineOfSight and arena_list[1].is_selectable 
                    and api_FindPath(player_info.grid_x,player_info.grid_y,arena_list[1].grid_x,arena_list[1].grid_y) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "競技場", min_x = 0,click = 2})
                    env.end_point = nil
                    env.path_list = nil
                end
                if point then
                    local player_point = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                    if player_point then
                        api_ClickMove(poe2_api.toInt(player_point.x), poe2_api.toInt(player_point.y), poe2_api.toInt(player_info.world_z - 70), 7)
                    end
                end
                poe2_api.click_keyboard("space")
                env.roll_time = nil
                env.end_point = nil
                env.path_list = nil
                env.target_point = nil
                return bret.RUNNING
            elseif distance >= self.movement_threshold then
                env.roll_time = nil
            end

            local current_time = api_GetTickCount64()
            local move_interval = math.random() * 0.2 + 0.2  -- 随机间隔 0.1~0.2 秒
            
            -- 如果终点变化超过阈值，重置路径
            if self.last_point and end_point and env.path_list then
                local last_path_point = env.path_list[#env.path_list]
                local dis = poe2_api.point_distance(
                    self.last_point[1], self.last_point[2],
                    {end_point[1], end_point[2]}
                )
                if dis and dis > 25 then
                    self.last_point = end_point
                    poe2_api.print_log("清路999")
                    env.path_list = nil
                    env.target_point = {}
                    env.is_arrive_end = true
                    env.end_point = nil
                    poe2_api.time_p("执行移动(RUNNING2) 耗时 -->", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
            end
            
            -- 执行移动（按时间间隔）
            if current_time - self.last_move_time >= move_interval * 1000 then
                if point then
                    local dis = poe2_api.point_distance(point[1], point[2], player_info)
                    poe2_api.dbgp(point[1], ",", point[2], ",", dis)
                    if dis and dis > 70 then
                        poe2_api.print_log("清路径10101")
                        poe2_api.find_text({ UI_info = env.UI_info, text = "再會", click = 2}) 
                        env.path_list = nil
                        env.target_point = {}
                        env.end_point = nil
                        poe2_api.time_p("执行移动(RUNNING3) 耗时 -->", api_GetTickCount64() - start_time)
                        return bret.RUNNING
                    end
                    api_ClickMove(poe2_api.toInt(point[1]), poe2_api.toInt(point[2]), poe2_api.toInt(player_info.world_z), 7)
                    self.last_move_time = current_time
                end
            end

            -- 检查是否到达目标点
            if point then
                local dis = poe2_api.point_distance(point[1], point[2], player_info)
                -- poe2_api.dbgp("距离：" .. dis)
                if dis and dis < 25 then
                    if env.path_list and #env.path_list > 0 then
                        env.target_point = {env.path_list[1].x, env.path_list[1].y}
                        -- poe2_api.dbgp("len 5604 移除已使用的点")
                        table.remove(env.path_list, 1)
                    end
                    env.roll_time = nil
                    poe2_api.time_p("执行移动(RUNNING4) 耗时 -->", api_GetTickCount64() - start_time)
                    return bret.RUNNING
                end
                env.last_position_story = {player_info.grid_x, player_info.grid_y}
                return bret.RUNNING
            else
                env.end_point = nil
                env.path_list = nil
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
    user_info = nil, -- 用户信息
    user_map = nil, -- 地图
    player_class = nil, -- 職業
    player_spec = nil, -- 专精
    space = nil, -- 躲避
    space_monster = nil,-- 躲避怪物
    space_time = nil,-- 躲避时间
    protection_settings = nil,-- 普通保護設置
    emergency_settings = nil,-- 紧急設置
    login_state = nil,-- 登录状态，初始值为nil
    speel_ip_number = 0,-- 設置当前IP地址的数量，初始值为0
    is_game_exe = false,-- 游戏是否正在执行，初始值为false
    shouting_number = 0, -- 喊话次数，初始值为0
    area_list = {}, -- 存储区域列表，初始值为空列表
    account_state = nil, -- 账户状态，初始值为nil
    switching_lines = 0, -- 线路切换状态，初始值为0
    time_out = 0, --  超时时间，初始值为0
    skill_name = nil,-- 当前技能名称，初始值为nil
    skill_pos = nil,-- 当前技能位置，初始值为nil
    is_need_check = false,-- 是否需要检查，初始值为false
    item_name = nil,-- 当前物品名称，初始值为nil
    item_pos = nil, -- 当前物品位置，初始值为nil
    check_all_points = false, -- 是否检查所有点，初始值为false
    path_list = {}, -- 存储路径列表，初始值为空列表
    empty_path = false, -- 路径是否为空，初始值为false
    boss_name = nil,-- 当前boss名称，初始值为nil
    map_name = nil, -- 当前地图名称，初始值为nil
    interaction_object = nil, -- 交互对象，初始值为nil
    item_move = false, -- 物品是否移动，初始值为false
    item_end_point = {}, -- 物品的终点位置，初始值为[0, 0]
    ok = false, -- 是否确认，初始值为false
    not_need_wear = false, -- 是否不需要装备，初始值为false
    currency_check = false, -- 是否进行货币检查，初始值为false
    sell_end_point = {}, -- 卖物品的终点位置，初始值为[0,0]
    is_better = false, -- 是否更好，初始值为false
    mos_out = 0, -- 显示的数量，初始值为0
    is_arrive_end = false, -- 是否到达终点，初始值为false
    not_need_pick = false, -- 是否不需要拾取，初始值为false
    is_not_ui = false, -- 是否不是UI界面，初始值为false
    entrancelist = {}, -- 入口位置列表
    creat_new_role = false, -- 新角色
    Level_reach = false, -- 是否要刷级
    changer_leader = false, -- 是否要换队长
    send_message = false, -- 是否要发信息
    obtain_message = false, -- 是否要换接收信息
    no_item_wear = false, -- 不用要穿戴的物品
    my_role = nil, -- 角色，初始值为nil
    is_set = false, --是否建立
    end_point = nil, --终点，初始值为nil
    teleport_area = nil, -- 传送地区，初始值为nil
    teleport = nil, -- 传送点，初始值为nil
    follow_role = nil, -- 跟随的角色，初始值为nil
    map_count = 0, -- 地图数，初始值为0
    task_name = nil, -- 任务名称，初始值为nil
    subtask_name = nil, -- 子任务名称，初始值为nil
    special_map_point = nil, -- 特殊点，初始值为nil
    mate_info = nil, -- 已死队员信息信息
    monster_info = nil, -- 怪物信息
    range_info = nil, -- 周围对象信息信息
    bag_info = nil, -- 背包信息
    range_item_info = nil, -- 周围装备信息
    shortcut_skill_info = nil, -- 快捷栏技能信息
    allskill_info = nil, -- 全部技能信息
    selectableskill_info = nil, -- 可选技能技能控件信息
    skill_gem_info = nil, -- 技能宝石列表信息
    team_info = nil, -- 获取队伍信息
    team_info_data = nil, -- 获取队伍数据
    player_info = nil, -- 人物信息
    UI_info = nil, -- UI控件信息
    skill_number = 0, -- 放技能次数
    path_bool = false, -- 跟隨超距離判斷
    interaction_object_map_name = nil, -- 交互对象所在地图名称
    not_need_active = false, -- 不激活
    target_point = {}, -- 目标坐标，初始值为空列表
    grid_x = nil, 
    grid_y = nil,
    target_point_follow = nil, -- 目标跟随点，初始值为nil
    is_timeout = false, -- 是否超时
    special_relife_point = false, -- 特殊重生点
    need_identify = false, -- 需要鉴定
    one_other_map = nil, -- 只去另外一个地图
    current_map_info = nil, -- 小地图信息
    need_item = false, -- 异界可拾取对象
    discard_item = nil, -- 丢弃对象
    store_item = nil, -- 存储对象
    interactive = nil, -- 交互对象
    is_shop = false, -- 是否购买
    is_map_complete = false, -- 是否是地图完成
    pick_up_timeout = {}, -- 拾取物品超时
    wait_target = false, -- 等待交互
    start_time = nil, -- 設置黑板变量 开始时间，初始化为 nil
    life_time = nil, -- 設置黑板变量 復活时间，初始化为 nil
    last_end_point = {}, -- 設置黑板变量 終點，初始化为 0
    priority_map = nil, -- 優先打地圖詞綴,
    last_exception_time = nil,
    need_ReturnToTown = false,
    need_SmallRetreat = false,
    not_open_waypoint = false, --小号传送点是否开启，发送给大号
    retry_count = 0,
    error_back = false, -- 意外退出
    map_recorded = false, -- 地图状态记录
    mouse_check = true, -- 检查鼠标技能
    click_grid_pos = false, -- 补丁视角处理
    current_pair_index = 0, -- 初始化当前兑换索引
    last_execution_time = 0, -- 初始化当前兌換時間
    not_more_ritual = true, -- 取消后续祭坛
    warehouse_full = nil, -- 个仓某页是否已满
    exchange_status = false, -- 是否兌換完成（存仓用）
    not_items_buy = false, -- 祭祀无物品购买
    open_map_UI = false, -- 地图ui是否打开
    is_public_warehouse = true, --共倉點金是否存儲
    is_get_plaque_node = true, --取碑牌节点，专用是否需要取碑牌
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
    center_point = 0,
    center_radius = {},
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
    last_position_story = { 0, 0},
    take_rest = false,
    buy_items = false,
    roll_time = nil,
    exit_time = nil,
    relife_stuck_monsters = {}, --复活队友跳怪
    map_result = nil, --小地图路径
    tasks_data = main_task.tasks_data, --任务列表

    warehouse_type_interactive = nil,  -- 仓库类型交互（个仓/公仓/nil）
    hwrd_time = 0, -- 获取窗口句柄间隔
    game_window = 0,  -- 暂存的窗口句柄
    streng_map_flushed_switch = false, -- 强化地图刷新开关
    currency_name = nil, -- 使用通货物品名称
    need_sale_map = false, -- 是否需要卖地图
    full_map = false, -- 地图是否已满
    min_attack_dis = nil,
    in_exchange = false, --在兑换状态
    -- 新增性能监控配置
    debug_tree_time = true,      -- 打印整棵树耗时
    debug_all_nodes = false,     -- 不打印所有节点调试信息(避免日志过多)
    suppress_node_debug = true   -- 抑制节点调试输出
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