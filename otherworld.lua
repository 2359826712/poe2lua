package.path = package.path .. ';./path/to/module/?.lua'

-- 根据otherworld.json实现的完整行为树系统
package.path = package.path .. ';lualib/?.lua'
local behavior_tree = require 'behavior3.behavior_tree'
local bret = require 'behavior3.behavior_ret'
-- 加载基础节点类型
local base_nodes = require 'behavior3.sample_process'
local my_game_info = require 'my_game_info'
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
            local config = poe2_api.load_config(json_path)
            local user_info = poe2_api.load_ini(user_info_path)["UserInfo"]
            -- 玩法優先級
            local map_priority = config["刷圖設置"]["玩法優先級"]
            local map_sorted_items_sort = poe2_api.sort_map_by_key(map_priority)
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
            env.dist_ls = config["刷圖設置"]['異界地圖索引']["滴注设置"] or {}
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

            return bret.SUCCESS
        end
    },

    -- 加入游戏异界
    Join_Game_Otherworld = {
        run = function(self, env)
            poe2_api.print_log("加入异界游戏...")
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
                env.interaction_object = nil
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
                return bret.RUNNING
            end
            return bret.SUCCESS
        end
    },

    -- 官方加入游戏
    Official_Join_Game = {
        run = function(self, env)
            poe2_api.print_log("通过官方渠道加入游戏...")
            return bret.SUCCESS
        end
    },

    -- 通过Steam启动游戏
    Launch_Game_Steam = {
        run = function(self, env)
            poe2_api.print_log("通过Steam启动游戏...")
            return bret.SUCCESS
        end
    },

    -- 获取UI信息
    Get_UI_Info = {
        run = function(self, env)
            poe2_api.print_log("获取UI信息...")
            local start_time = api_GetTickCount64()
            env.UI_info = UiElements:Update()
            if #UiElements < 1 then
                api_Sleep(4000)
                return bret.RUNNING
            end
            poe2_api.print_log("获取UI信息... 耗时 --> ", api_GetTickCount64() - start_time)
            return bret.SUCCESS
        end
    },

    -- 获取信息
    Get_Info = {
        run = function(self, env)
            poe2_api.print_log("获取游戏信息...")
            local player_info = api_GetLocalPlayer()
            if not player_info then
                poe2_api.dbgp("空人物信息")
                
                return bret.RUNNING
            end
            env.player_info = player_info

            local start_time = api_GetTickCount64()  -- 记录开始时间(毫秒)
            env.range_info = Actors:Update()
            if #Actors < 0 then
                poe2_api.print_log("未发现周围对象 | 耗时: 0.00 毫秒\n")
                return bret.RUNNING
            end
            poe2_api.print_log("获取周围对象信息... 耗时 --> ", api_GetTickCount64() - start_time)

            -- api_GetMinimapActorInfo() - 获取小地图周围对象信息
            local current_map_info = api_GetMinimapActorInfo()
            env.current_map_info = current_map_info

            -- 周围装备信息
            WorldItems:Update()
            if #WorldItems < 1 then
                poe2_api.dbgp("周围没有装备信息\n")
            end
            env.range_items = WorldItems
            
            -- 背包信息（主背包）
            local inventory = api_Getinventorys(1,0)
            env.bag_info = inventory
            
            local function dumpInventory(inventory)
                local itemFields = {
                    "name_utf8", "baseType_utf8", "start_x", "start_y", "end_x", "end_y",
                    "not_identified", "category_utf8", "color", "world_x", "world_y", "grid_x", "grid_y",
                    "skillGemLevel", "skillStoneLevel", "isWearable", "DemandStrength", "DemandAgility",
                    "DemandWisdom", "DemandLevel", "obj", "contaminated", "id", "tribute",
                    "totalDeferredConsumption", "fixedSuffixCount", "mods_obj", "stackCount"
                }
                
                for _, item in ipairs(inventory) do
                    api_Log("----------------------------------")
                    
                    -- 遍历预定义的属性列表，确保按固定顺序输出
                    for _, field in ipairs(itemFields) do
                        local value = item[field]
                        api_Log(string.format("%-25s: %s", field, tostring(value)))
                    end
                    
                    api_Log("----------------------------------")
                end
                
                api_Sleep(1000000)  -- 暂停程序（注意：长时间暂停可能导致游戏无响应）
            end
            
            -- 调用函数
            -- dumpInventory(inventory)


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

            return bret.SUCCESS
        end
    },

    -- 清理
    Clear = {
        run = function(self, env)
            poe2_api.print_log("执行清理...")
            return bret.SUCCESS
        end
    },

    -- 休息控制
    RestController = {
        run = function(self, env)
            poe2_api.dbgp("执行休息控制...")
            
            -- 初始化检查
            if not self._is_initialized then
                poe2_api.dbgp("初始化休息控制器...")
                local config = env.user_config["全局設置"]["刷图通用設置"]["定時休息"] or {}
                
                -- 工作时间配置（单位：小时→毫秒）
                local base_work = tonumber(config["運行時間"]) or 1  -- 默认1小时
                local work_random_range = math.min(tonumber(config["工作時間隨機範圍"]) or 0.1, 0.3) -- 限制最大30%波动
                self.work_duration_ms = math.floor(base_work * 3600 * 1000 * (1 + (math.random() * work_random_range * 2 - work_random_range)))
                
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
                return bret.SUCCESS
            end
            
            local current_time_ms = api_GetTickCount64()

            local function _perform_rest_actions()
                poe2_api.dbgp("执行休息操作...")
                
                if not (poe2_api.find_text({UI_info = env.UI_info, text = "回到角色選擇畫面"}) or 
                    poe2_api.click_text_UI({UI_info = env.UI_info, text = "exit_to_character_selection"})) then
                    if poe2_api.click_text_UI({UI_info = env.UI_info, text = "life_orb"}) and 
                    poe2_api.click_text_UI({UI_info = env.UI_info, text = "mana_orb"}) then
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
                    local player_info = env.player_info
                    if not poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                        env.need_ReturnToTown = true
                        poe2_api.dbgp("不在藏身处，设置需要回城")
                        return bret.SUCCESS
                    end
                    
                    -- 进入休息状态
                    if self.is_kill_game then
                        env.error_kill = true
                        poe2_api.dbgp("设置需要关闭游戏")
                    end
                    _perform_rest_actions()
                    poe2_api.dbgp(string.format("工作时间到，开始休息 (%d分钟)", self.rest_duration_ms/(60*1000)))
                    return bret.RUNNING
                else
                    -- 返回工作状态
                    env.error_kill = false
                    poe2_api.dbgp(string.format("休息结束，开始工作 (%d分钟)", self.work_duration_ms/(60*1000)))
                    self._is_initialized = false
                    return bret.SUCCESS
                end
            end

            local function _update_status()
                local time_remaining_ms = math.max(0, self._next_state_change_time_ms - current_time_ms)
                
                if self._is_resting then
                    poe2_api.dbgp("当前处于休息状态")
                    local player_info = env.player_info
                    if not poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                        env.need_ReturnToTown = true
                        poe2_api.dbgp("不在藏身处，设置需要回城")
                        return bret.SUCCESS
                    end
                    
                    -- 休息状态更新（每分钟60000毫秒）
                    if current_time_ms - self._last_update_time_ms >= 60000 then
                        self._last_update_time_ms = current_time_ms
                        local mins = math.floor(time_remaining_ms/(60*1000))
                        local secs = math.floor((time_remaining_ms%(60*1000))/1000)
                        poe2_api.print_log(string.format("休息中... 剩余时间: %02d分%02d秒", mins, secs))
                        env.take_rest = true
                        
                        
                        if not (poe2_api.find_text({UI_info = env.UI_info, text = "回到角色選擇畫面"}) or 
                            poe2_api.click_text_UI({UI_info = env.UI_info, text = "exit_to_character_selection"})) and 
                            poe2_api.click_text_UI({UI_info = env.UI_info, text = "life_orb"}) and 
                            poe2_api.click_text_UI({UI_info = env.UI_info, text = "mana_orb"}) then
                            poe2_api.click_keyboard("esc")
                        end
                        api_Sleep(1000)
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
                return _handle_state_transition()
            end
                
            -- 状态更新
            poe2_api.dbgp("更新当前状态...")
            return _update_status()
        end
    },

    -- 小撤退
    SmallRetreat = {
        run = function(self, env)
            poe2_api.print_log("执行小撤退")
            local current_time = api_GetTickCount64()
            
            local player_info = env.player_info
            if not env.need_SmallRetreat then
                poe2_api.dbgp("小退条件不满足")   
                self.error_kill_start_time = nil
                return bret.SUCCESS
            end
            if not self.last_action_time then
                self.init = true
                poe2_api.dbgp("初始化小撤退")
                self.last_action_time = 0 -- 记录上次操作时间
                self.action_interval = 2 -- 操作间隔时间
                self.error_kill_start_time = nil -- 超时计时器
            end
            local reset_states = function(env)
                -- 统一状态重置方法
                local current_time = api_GetTickCount64()
                env.last_exception_time = 0
                env.last_exp_check = current_time
                env.last_exp_value = player_info.currentExperience
                -- logger.debug("已重置所有监控状态")
            end

            if not self.error_kill_start_time then
                self.error_kill_start_time = api_GetTickCount64()
            end
            -- 超时判断（10次点击约15秒）
            if self.error_kill_start_time and (current_time - self.error_kill_start_time) > 30*1000 then
                print("小退超时")
                env.error_kill = true
                self.error_kill_start_time = nil  -- 重置计时器
                env.need_SmallRetreat = false
                
                return bret.RUNNING
            else
                env.error_kill = false
            end
            if env.need_SmallRetreat then
                env.path_list = {}
                
                if current_time - self.last_action_time >= self.action_interval then
                    -- # 点击返回
                    if poe2_api.find_text({UI_info = env.UI_info, text = "回到角色選擇畫面", click=2}) then
                        if not self.error_kill_start_time then
                             self.error_kill_start_time = current_time  --# 开始计时
                        end
                        api_Sleep(6000)
                        return bret.RUNNING
                    elseif poe2_api.click_text_UI({UI_info = env.UI_info, text = "exit_to_character_selection", click=1 , index=1}) then
                        if not self.error_kill_start_time then
                            self.error_kill_start_time = current_time
                        end
                        api_Sleep(6000)
                        return bret.RUNNING
                    end
                    -- # 打开选项菜单
                    if not (poe2_api.find_text({UI_info = env.UI_info,  text = "回到角色選擇畫面"}) or 
                           poe2_api.click_text_UI({UI_info = env.UI_info, text = "exit_to_character_selection"})) and 
                           poe2_api.click_text_UI({UI_info = env.UI_info, text = "life_orb"}) and 
                           poe2_api.click_text_UI({UI_info = env.UI_info, text = "mana_orb"}) then
                        if not self.error_kill_start_time then
                            self.error_kill_start_time = current_time
                        end
                        poe2_api.click_keyboard("esc")
                        self.last_action_time = current_time + 2
                        return bret.RUNNING
                    end
                    -- # 成功执行后重置超时计时器
                    self.error_kill_start_time = false
                    env.last_exp_check =current_time
                    self.last_exception_time = 0
                    env.need_SmallRetreat = False
                    reset_states(env)
                    return bret.RUNNING
                else
                    return bret.RUNNING
                end
            end
        end
    },

    -- 返回城镇
    ReturnToTown = {
        run = function(self, env)
            poe2_api.print_log("执行返回城镇...")
            poe2_api.dbgp("开始执行返回城镇")
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
             
            local find_path_failure = env.find_path_failure or 0
            if not env.need_ReturnToTown then
                poe2_api.dbgp("返回城镇条件不满足") 
                return bret.SUCCESS
            end  
            -- 初始化时间
            if not self.current_time and env.need_ReturnToTown then
                poe2_api.dbgp("初始化返回城镇") -- 初始化时间
                self.current_time = current_time
                self.timeout = 20  -- 超时时间（秒）
            end
            local reset_states = function(env)
                -- 统一状态重置方法
                local current_time = api_GetTickCount64()
                env.last_exception_time_move = 0
                env.last_exp_check_move = current_time
                env.last_exp_value_move = env.player_info.currentExperience
                -- logger.debug("已重置所有经验监控状态")
            end

            local spcify_monsters = function()
                if env.range_info then
                    for _, monster in ipairs(env.range_info) do
                        if monster.name_utf8 == '巨蛇女王．瑪娜莎' and monster.life > 0 then
                            return true
                        end
                    end
                end
                return false
            end
            -- 检查是否超时
            if (current_time - self.current_time) > self.timeout*1000 then
                poe2_api.dbgp("返回城镇超时")
                env.need_ReturnToTown = false
                env.need_SmallRetreat = true
                
                return bret.RUNNING
            end
            if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8)  then
                poe2_api.dbgp("已返回城镇")
                env.need_ReturnToTown = false
                env.find_path_failure = 0
            end
            
            if env.need_ReturnToTown or find_path_failure > 10 then
                env.path_list = {}
                if find_path_failure > 10 then
                    env.is_map_complete = true
                end
                
                local success, status = pcall(function()
                    if poe2_api.find_text({UI_info = env.UI_info, text = "你無法在遊戲暫停時使用該道具。", min_x = 0}) then
                        poe2_api.dbgp("发现暂停")
                        poe2_api.click_keyboard("space")
                        api_Sleep(500)
                        if not poe2_api.find_text("/clear", 0) then
                            poe2_api.click_keyboard("enter")
                            api_Sleep(500)
                            poe2_api.paste_text("/clear")
                            api_Sleep(500)
                            poe2_api.click_keyboard("enter")
                            api_Sleep(1000)
                            
                            return bret.RUNNING
                        end
                    end
                    
                    if poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物", min_x = 0})  then
                        poe2_api.dbgp("发现恩賜之物")
                        poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物", min_x = 0, click = 2, add_x = 272})
                        
                        return bret.RUNNING
                    end
                    
                    if player_info.isInBossBattle then
                        poe2_api.dbgp("在boss战")
                        env.need_ReturnToTown = false
                        env.need_SmallRetreat = true
                        
                        return bret.RUNNING
                    end
                    
                    if poe2_api.is_have_mos({range_info = env.range_info, player_info}) or spcify_monsters() then
                        poe2_api.dbgp("发现怪物")
                        return bret.SUCCESS
                    end
                    
                    if not string.find(player_info.current_map_name_utf8, "town") and not poe2_api.table_contains(my_game_info.hideout_CH, player_info.current_map_name_utf8) then
                        if poe2_api.find_text({UI_info = env.UI_info,  text = "傳送", min_x = 700, max_y = 40, max_x = 830}) then
                            poe2_api.dbgp("发现传送")
                            poe2_api.click_keyboard("space")
                            return bret.RUNNING
                        end
                        poe2_api.dbgp("回城")
                        for _, k in ipairs(env.range_info) do
                            if k.name_utf8 ~= '' and k.type == 5 and poe2_api.table_contains(my_game_info.hideout_CH, k.name_utf8) then
                                if poe2_api.point_distance(k.grid_x, k.grid_y, player_info) < 25 then
                                    poe2_api.dbgp("发现城镇UI")
                                    if not poe2_api.find_text({UI_info = env.UI_info, text = k.name_utf8, click = 2}) then
                                        poe2_api.dbgp("点击城镇UI失败")
                                        api_ClickMove(poe2_api.toInt(k.grid_x), poe2_api.toInt(k.grid_y), poe2_api.toInt(k.world_z-100), 7)
                                    end
                                    return bret.RUNNING
                                end
                            end
                        end
                        
                        -- 点击传送
                        poe2_api.dbgp("点击传送")
                        api_ClickMove(poe2_api.toInt(player_info.grid_x), poe2_api.toInt(player_info.grid_y), poe2_api.toInt(player_info.world_z), 7)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815,0)
                        api_Sleep(200)
                        api_ClickScreen(1230, 815,1)
                        api_Sleep(1000)
                        return bret.RUNNING
                    else
                        local point = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                        if point then
                            api_ClickMove(poe2_api.toInt(point.x), poe2_api.toInt(point.y), poe2_api.toInt(player_info.world_z - 70), 7)
                        end
                        
                        -- 仅在完全回城后重置状态
                        if string.find(player_info.current_map_name_utf8, "town") or my_game_info.hideout[player_info.current_map_name_utf8] then
                            env.last_exp_check = api_GetTickCount64()
                            env.last_exception_time = 0
                            env.need_ReturnToTown = false
                            reset_states(env)
                            
                            return bret.SUCCESS
                        end
                        
                        
                        return bret.RUNNING
                    end
                end)
                
                if not success then
                    poe2_api.dbgp("执行返回城镇失败")
                    poe2_api.dbgp("捕获到异常:", status)
                    return bret.RUNNING
                else
                    poe2_api.dbgp("执行返回城镇成功")
                    return bret.SUCCESS
                end     
            end
        end
    },

    -- 检查长时间未增长经验
    Check_LongTime_EXP_Add = {
        run = function(self, env)
            poe2_api.print_log("开始执行长时间经验检查...")

            if 1 > 0 then
                poe2_api.dbgp("所有异常处理功能未启用，跳过检测流程")
                return bret.SUCCESS
            end
            
            local current_time = api_GetTickCount64()
            local take_rest = env.take_rest
            local buy_items = env.buy_items
            local config = env.user_config
            local player_info = env.player_info
            
            

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
            
            -- 检查至少有一个异常处理功能启用
            local function _check_feature_enabled()
                -- 经验相关功能
                local exp_town_enabled = config['全局設置']['異常處理']['沒有經驗回城']['是否開啟']
                local exp_retreat_enabled = config['全局設置']['異常處理']['沒有經驗小退']['是否開啟']
                
                -- 移动相关功能
                local move_town_enabled = config['全局設置']['異常處理']['不動回城']['是否開啟']
                local move_retreat_enabled = config['全局設置']['異常處理']['不動小退']['是否開啟']
                
                -- 任一功能启用即为true
                local enabled = exp_town_enabled or exp_retreat_enabled or move_town_enabled or move_retreat_enabled
                poe2_api.dbgp(string.format("功能启用检查 - 经验回城:%s, 经验小退:%s, 移动回城:%s, 移动小退:%s", 
                    tostring(exp_town_enabled), tostring(exp_retreat_enabled), 
                    tostring(move_town_enabled), tostring(move_retreat_enabled)))
                
                return enabled
            end

            -- 重置经验检查状态
            local function reset_states_exp()
                local current_time = api_GetTickCount64()
                local current = env.player_info
                env.last_exception_time = 0.0
                env.last_exp_check = current_time
                env.last_exp_value = env.player_info.currentExperience
                env.last_position = {current.grid_x, current.grid_y}
                poe2_api.dbgp("已重置所有经验监控状态")
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
                local sorted_range = poe2_api.get_sorted_list()
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
            if self.last_check and current_time - self.last_check < 0.5 then
                poe2_api.dbgp("节流控制: 检查间隔小于0.5秒，跳过")
                
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

            -- 获取配置参数
            local no_exp_to_town = config['全局設置']['異常處理']['沒有經驗回城']['是否開啟']
            local no_exp_to_town_time = config['全局設置']['異常處理']['沒有經驗回城']['閾值'] * 60 * 1000
            local no_exp_to_change = config['全局設置']['異常處理']['沒有經驗小退']['是否開啟']
            local no_exp_to_change_time = config['全局設置']['異常處理']['沒有經驗小退']['閾值'] * 60 * 1000

            local no_move_to_town = config['全局設置']['異常處理']['不動回城']['是否開啟']
            local no_move_to_town_time = config['全局設置']['異常處理']['不動回城']['閾值'] * 60 * 1000
            local no_move_to_change = config['全局設置']['異常處理']['不動小退']['是否開啟']
            local no_move_to_change_time = config['全局設置']['異常處理']['不動小退']['閾值'] * 60 * 1000

            -- 经验增长时重置状态
            if player_info.currentExperience ~= env.last_exp_value then
                poe2_api.dbgp("经验值变化，重置经验检查状态")
                reset_states_exp()
            end
            
            -- 移动状态变化时重置状态
            if not is_moving then
                poe2_api.dbgp("移动状态变化，重置移动检查状态")
                reset_states_move()
            end

            -- 计算真实停滞时间
            local real_stagnation_time = current_time - (env.last_exp_check or 0)
            local real_stagnation_time_move = current_time - (env.last_exp_check_move or 0)
            
            poe2_api.dbgp(string.format("经验停滞时间: %.2f秒, 移动停滞时间: %.2f秒", 
                real_stagnation_time, real_stagnation_time_move))

            -- 检查功能是否启用
            if not _check_feature_enabled() then
                poe2_api.dbgp("所有异常处理功能未启用，跳过检测流程")
                
                return bret.SUCCESS
            end

            -- 初始化首次检查
            if env.last_exp_check == 0 then
                poe2_api.dbgp("初始化经验检查状态")
                env.last_exp_value = player_info.currentExperience
                env.last_exp_check = current_time
                
                return bret.SUCCESS
            end

            -- 每20秒按一次alt键
            if not self.last_alt_press_time or current_time - self.last_alt_press_time >= 20 then
                poe2_api.dbgp("执行ALT键检查")
                poe2_api.click_keyboard("alt")
                api_Sleep(10)
                poe2_api.click_keyboard("alt", 2)
                api_Sleep(10)
                poe2_api.click_keyboard("alt", 2)
                self.last_alt_press_time = current_time
            end

            -- 根据场景设置不同的超时时间
            local space_time = 8
            local map_strenght = env.strengthened_map_obj
            local return_town = env.return_town
            
            if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) then
                    return bret.SUCCESS
                end
                space_time = 60
            elseif map_strenght then
                space_time = 120
            elseif return_town then
                space_time = 15
            elseif buy_items then
                space_time = 30
            end

            -- 处理长时间未移动情况
            if is_moving and real_stagnation_time_move > space_time * 1000 then
                poe2_api.dbgp(string.format("长时间未移动(%.2f秒 > %d秒)，执行恢复操作", 
                    real_stagnation_time_move, space_time))
                
                if not env.need_SmallRetreat and not env.need_ReturnToTown and not take_rest then
                    env.end_point = nil
                    env.target_point = nil
                    env.path_list = nil
                    env.is_arrive_end = true
                    
                    poe2_api.click_keyboard('space')
                    
                    if env.range_info and player_info then
                        local target = get_range()
                        if target then
                            api_ClickMove(poe2_api.toInt(target.grid_x), poe2_api.toInt(target.grid_y), poe2_api.toInt(player_info.world_z), 1)
                            api_Sleep(100)
                            poe2_api.find_text({UI_info = env.UI_info, text = target.name_utf8, click = 2})
                            api_Sleep(300)
                        end
                        
                        local x, y = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                        api_ClickMove(poe2_api.toInt(x), poe2_api.toInt(y), poe2_api.toInt(player_info.world_z), 7)
                        api_Sleep(300)
                        poe2_api.click_keyboard('space')
                        api_Sleep(100)
                    end
                    
                    if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                        local x, y = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                        api_ClickMove(poe2_api.toInt(x), poe2_api.toInt(y), poe2_api.toInt(player_info.world_z), 7)
                        api_Sleep(500)
                        poe2_api.click_keyboard('space')
                        api_Sleep(500)
                        poe2_api.click_keyboard('space')
                    end
                end
            end

            -- 检查触发条件
            local trigger_town = nil
            local trigger_retreat = nil
            local trigger_town_move = nil
            local trigger_retreat_move = nil
            
            if no_exp_to_town then
                local town_th = no_exp_to_town_time or math.huge
                trigger_town = real_stagnation_time >= town_th
                poe2_api.dbgp(string.format("经验回城检查: %.2f >= %.2f = %s", 
                    real_stagnation_time, town_th, tostring(trigger_town)))
            end
            
            if no_exp_to_change then
                local retreat_th = no_exp_to_change_time or math.huge
                trigger_retreat = real_stagnation_time >= retreat_th
                poe2_api.dbgp(string.format("经验小退检查: %.2f >= %.2f = %s", 
                    real_stagnation_time, retreat_th, tostring(trigger_retreat)))
            end

            if no_move_to_town then
                local town_th_move = no_move_to_town_time or math.huge
                trigger_town_move = real_stagnation_time_move >= town_th_move
                poe2_api.dbgp(string.format("移动回城检查: %.2f >= %.2f = %s", 
                    real_stagnation_time_move, town_th_move, tostring(trigger_town_move)))
            end
            
            if no_move_to_change then
                local retreat_th_move = no_move_to_change_time or math.huge
                trigger_retreat_move = real_stagnation_time_move >= retreat_th_move
                poe2_api.dbgp(string.format("移动小退检查: %.2f >= %.2f = %s", 
                    real_stagnation_time_move, retreat_th_move, tostring(trigger_retreat_move)))
            end

            -- 处理触发条件
            if trigger_town or trigger_retreat or trigger_town_move or trigger_retreat_move then
                poe2_api.dbgp(string.format("触发异常处理条件 - 经验停滞:%.2f秒, 移动停滞:%.2f秒", 
                    real_stagnation_time, real_stagnation_time_move))
                
                -- 优先级：回城 > 小退
                if real_stagnation_time > no_exp_to_change_time then
                    env.is_map_complete = true
                    env.need_SmallRetreat = true
                    poe2_api.dbgp("触发小退条件")
                    
                    return bret.SUCCESS
                end
                
                if (trigger_town and no_exp_to_town) or (trigger_town_move and no_move_to_town) then
                    if not poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                        env.is_map_complete = true
                        env.need_ReturnToTown = true
                        poe2_api.dbgp("触发回城条件")
                    end
                    
                    return bret.SUCCESS
                elseif (trigger_retreat and no_exp_to_change) or (trigger_retreat_move and no_move_to_change) then
                    env.is_map_complete = true
                    env.need_SmallRetreat = true
                    poe2_api.dbgp("触发小退条件")
                    
                    return bret.SUCCESS
                end
            end
            
            
            return bret.SUCCESS
        end
    },

    -- 检查异界死亡
    Is_Deth_Otherworld = {
        run = function(self, env)
            poe2_api.print_log("死亡初始化(异界)")
            poe2_api.dbgp("死亡初始化(异界)")
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            
            if not self.respawn_wait_start then
                self.respawn_wait_start = 0
            end
            if not player_info then
                poe2_api.dbgp("玩家信息不存在，跳过死亡初始化")
                return bret.RUNNING
            end
            
            if player_info.life == 0 and 
            (poe2_api.find_text({UI_info = env.UI_info, text="在記錄點重生"}) or 
                poe2_api.find_text({UI_info = env.UI_info, text="在藏身處復活"}) or 
                poe2_api.find_text({UI_info = env.UI_info, text="在城鎮重生"}) or
                poe2_api.find_text({UI_info = env.UI_info, text="在開始地圖頭目遭遇之後復活，會移除區域 內所有其他遭遇和怪物"})) then
                
                if poe2_api.click_text_UI({UI_info = env.UI_info, text="respawn_at_checkpoint_button"}) then
                    poe2_api.click_keyboard("space")
                end
                poe2_api.dbgp("点击确认")
                poe2_api.find_text({UI_info = env.UI_info, text="確定",click=2, min_x=0})
                api_ClickScreen(915, 490,1)
                relife_text = {"在記錄點重生","在藏身處復活","在城鎮重生"} 
                if poe2_api.find_text({UI_info = env.UI_info, text = relife_text, min_x = 0}) then
                    api_Sleep(1000)
                    poe2_api.find_text({UI_info = env.UI_info, text = relife_text,click = 2, min_x = 0})
                end
                env.teleport =  nil
                env.area_list = {}
                env.is_need_check = false
                env.stuck_monsters = nil
                env.item_name = nil
                env.item_pos = nil
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
            return bret.SUCCESS
        end
    },

    -- 检查低血量/蓝量
    CheckLowHpMp_Otherworld = {
        run = function(self, env)
            local current_time = api_GetTickCount64()
            poe2_api.dbgp("开始执行蓝血检查:")
            
            local player = env.player_info
            local prot = env.protection_settings
            local emerg = env.emergency_settings
            
            -- 初始化计时器（如果不存在）
            if not self.last_health_recovery_time then
                self.last_health_recovery_time = 0
                self.last_mana_recovery_time = 0
                self.last_shield_recovery_time = 0
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
                        now - self.last_health_recovery_time, interval))
                    
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
            local regular_status = _handle_regular_recovery(player, prot, current_time)
            if regular_status ~= bret.SUCCESS then
                poe2_api.dbgp("常规恢复处理返回:", regular_status)
                return regular_status
            end
            
            return bret.SUCCESS
        end
    },

    -- 逃跑
    Escape = {
        run = function(self, env)
            poe2_api.dbgp("开始执行逃跑检查...")
            local current_time = api_GetTickCount64()
            local now = current_time
            local player_info = env.player_info
            
            local emerg = env.emergency_settings
            local run_point = env.run_point
            local valid_monsters = env.valid_monsters
            local afoot_altar = env.afoot_altar
            
            if not player_info then
                poe2_api.dbgp("错误: 玩家信息为空")
                return bret.RUNNING
            end
            
            if player_info.isInBossBattle or afoot_altar then
                poe2_api.dbgp("在Boss战或祭坛中，跳过逃跑检查")
                return bret.SUCCESS
            end

            -- 检查祭坛
            -- local is_altar = _get_altar(range_info)
            -- if is_altar then
            --     poe2_api.dbgp("发现祭坛，检查周围怪物...")
            --     api_UpdateAutomaticUpdateBarrier(false)
            --     local dis = poe2_api.point_distance(is_altar.grid_x, is_altar.grid_y, player_info)
            --     if dis < 96 and _is_monster(range_info, player_info, 60, is_altar) then
            --         poe2_api.dbgp("祭坛附近有怪物，不执行逃跑")
            --         return bret.SUCCESS
            --     end
            -- end

            local function _is_monster(mate, dis, objter)
                for _, i in ipairs(env.range_info) do
                    if i.type == 1 and not i.is_friendly and i.life > 0 and 
                    not poe2_api.table_contains(my_game_info.not_attact_mons_CN_name, i.name_utf8) and 
                    i.isActive and not string.find(i.name_utf8, "神殿") and 
                    i.hasLineOfSight and i.is_selectable then
                        local dist1 = poe2_api.point_distance(mate.grid_x, mate.grid_y, {i.grid_x, i.grid_y})
                        local dist2 = poe2_api.point_distance(objter.grid_x, objter.grid_y, {i.grid_x, i.grid_y})
                        if dist1 and dist2 and dist1 <= dis and (not objter or dist2 > 99) then
                            poe2_api.dbgp(string.format("发现怪物: %s, 距离: %.1f", i.name_utf8, dist))
                            return i
                        end
                    end
                end
                return false
            end
    
            -- function _get_altar(range_info)
            --     for _, i in ipairs(range_info) do
            --         if i.path_name_utf8 == "Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable" and 
            --         i.stateMachineList and i.stateMachineList.current_state == 2 and 
            --         i.stateMachineList.interaction_enabled == 0 then
            --             poe2_api.dbgp("发现祭坛")
            --             return i
            --         end
            --     end
            --     return nil
            -- end
    
            local function _handle_space_action(monster, space_time)
                poe2_api.dbgp("执行空格键躲避动作...")
                local player_info = api_GetLocalPlayer()
                if not player_info then
                    poe2_api.dbgp("错误: 获取玩家信息失败")
                    return
                end
                
                space_time = space_time or 1.5
                space_time = space_time / 1000
                
                if monster and api_GetTickCount64() - (self.last_space_time or 0) >= space_time and math.random() < 0.8 then
                    poe2_api.dbgp(string.format("躲避怪物: %s", monster.name_utf8))
                    local result = api_GetNextCirclePosition(
                        monster.grid_x, monster.grid_y, 
                        player_info.grid_x, player_info.grid_y, 80
                    )
                    api_ClickMove(result.x, result.y, player_info.world_z - 70, 0)
                    api_Sleep(100)
                    poe2_api.click_keyboard('space')
                    self.last_space_time = api_GetTickCount64() + math.random(-0.05, 0.05)
                end
            end
    
            local function _handle_regular_space(player, prot, now, run_point, valid_monsters)
                poe2_api.dbgp("处理常规逃跑逻辑...")
                local point = {}
                local current_time = api_GetTickCount64()
                
                -- 血量逃跑
                local hp_cfg = prot.low_health or {}
                if hp_cfg.enable then
                    local threshold = player.max_life * (hp_cfg.threshold / 100)
                    poe2_api.dbgp(string.format("血量逃跑检查: 当前 %.1f/%.1f, 阈值 %.1f", 
                        player.life, player.max_life, threshold))
                    
                    if player.life < threshold then
                        if not run_point then
                            poe2_api.dbgp("血量过低，寻找安全区域...")
                            local ret = api_GetSafeAreaLocationNoMonsters(70)
                            if ret and ret.x ~= -1 and ret.y ~= -1 then
                                point = {ret.x, ret.y}
                            end
                            
                            if next(point) ~= nil then
                                poe2_api.dbgp("找到安全点，设置逃跑路径")
                                env.run_point = point
                            else
                                poe2_api.dbgp("未找到安全点，执行躲避动作")
                                _handle_space_action(valid_monsters)
                                return bret.RUNNING
                            end
                        else
                            poe2_api.dbgp("已有逃跑路径，设置终点")
                            env.end_point = run_point
                            return bret.FAIL
                        end
                    else
                        env.run_point = nil
                    end
                end
    
                -- 蓝量逃跑
                local mp_cfg = prot.low_mana or {}
                if mp_cfg.enable then
                    local threshold = player.max_mana * (mp_cfg.threshold / 100)
                    poe2_api.dbgp(string.format("蓝量逃跑检查: 当前 %.1f/%.1f, 阈值 %.1f", 
                        player.mana, player.max_mana, threshold))
                    
                    if player.mana < threshold then
                        poe2_api.dbgp("蓝量过低，寻找安全区域...")
                        if not run_point then
                            local ret = api_GetSafeAreaLocationNoMonsters(70)
                            if ret and ret.x ~= -1 and ret.y ~= -1 then
                                point = {ret.x, ret.y}
                            end
                            
                            if next(point) ~= nil then
                                poe2_api.dbgp("找到安全点，设置逃跑路径")
                                env.end_point = point
                                return bret.FAIL
                            else
                                poe2_api.dbgp("未找到安全点，执行躲避动作")
                                _handle_space_action(valid_monsters)
                            end
                        else
                            poe2_api.dbgp("已有逃跑路径，设置终点")
                            env.end_point = run_point
                            return bret.FAIL
                        end
                    else
                        env.run_point = nil
                    end
                end
    
                -- 护盾逃跑
                local shield_cfg = prot.low_shield or {}
                if shield_cfg.enable then
                    local threshold = player.max_shield * (shield_cfg.threshold / 100)
                    poe2_api.dbgp(string.format("护盾逃跑检查: 当前 %.1f/%.1f, 阈值 %.1f", 
                        player.shield, player.max_shield, threshold))
                    
                    if player.shield < threshold then
                        poe2_api.dbgp("护盾过低，寻找安全区域...")
                        if not run_point then
                            local ret = api_GetSafeAreaLocationNoMonsters(70)
                            if ret and ret.x ~= -1 and ret.y ~= -1 then
                                point = {ret.x, ret.y}
                            end
                            
                            if next(point) ~= nil then
                                poe2_api.dbgp("找到安全点，设置逃跑路径")
                                env.run_point = point
                            else
                                poe2_api.dbgp("未找到安全点，执行躲避动作")
                                _handle_space_action(valid_monsters)
                            end
                        else
                            poe2_api.dbgp("已有逃跑路径，设置终点")
                            env.end_point = run_point
                            return bret.FAIL
                        end
                    else
                        env.run_point = nil
                    end
                end
    
                return bret.SUCCESS
            end

            -- 处理常规逃跑
            poe2_api.dbgp("处理常规逃跑")
            local status = _handle_regular_space(player_info, emerg, now, run_point, valid_monsters)
            poe2_api.dbgp("常规逃跑处理返回状态:", status)
            if status and status ~= bret.SUCCESS then
                poe2_api.dbgp("常规逃跑处理返回状态:", status)
                return status
            end
            return bret.SUCCESS
        end
    },

    -- 检查是否在主页面
    Not_Main_Page_Otherworld = {
        run = function(self, env)
            poe2_api.print_log("检查是否在主页面...")
            local current_time = api_GetTickCount64()

            local current_map_info = env.current_map_info
            local player_info = env.player_info

            -- if player_info then
            --     return bret.SUCCESS
            -- end
            
            if poe2_api.click_text_UI({UI_info = env.UI_info, text = "loading_screen_tip_label",index = 1}) then
                if not poe2_api.click_text_UI({UI_info = env.UI_info, text = "loading_screen_tip_label",index = 1}) then
                    api_Sleep(500)
                end
                poe2_api.dbgp("加载中....")
                return bret.RUNNING
            end
            
            if poe2_api.find_text({UI_info = env.UI_info, text = "你的天賦樹", min_x = 0}) then
                api_ClickScreen(800, 510,1)
                return bret.RUNNING
            end
            
            if poe2_api.find_text({UI_info = env.UI_info, text = "按下 <N>{<normal>{1}} 來使用生命藥劑。", min_x = 0}) then
                poe2_api.click_keyboard('1') -- 使用生命药水
            end

            local click_2 ={"接受任務" ,"繼續" }
            if poe2_api.find_text({UI_info = env.UI_info, text = click_2, click = 2}) then
                api_Sleep(500)  -- Equivalent to time.sleep(0.5)
                return bret.RUNNING
            end

            local esc_click= {"你無法將此背包丟置於此。請問要摧毀它嗎？","回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片"}
            if poe2_api.find_text({UI_info = env.UI_info, text = esc_click, min_x = 0}) then
                poe2_api.click_keyboard("esc")
                return bret.RUNNING
            end

            if poe2_api.find_text({UI_info = env.UI_info, text = "你無法將此道具丟置於此。請問要摧毀它嗎？", min_x = 0, min_y = 0}) then
                poe2_api.find_text({UI_info = env.UI_info, text = "保留", min_x = 0, min_y = 0, click = 2})
                return bret.RUNNING
            end

            if player_info and poe2_api.table_contains(my_game_info.hideout,player_info.current_map_name_utf8) then
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

            if poe2_api.find_text({UI_info = env.UI_info, text = "你可以在此回報其他玩家不洽當的遊戲行為，請選擇其違反的行為並附上簡短的敘述。我們不會將結果告知回報者。請注意，若是惡意使用回報系統經查證後，將可能導致你的回報功能被關閉，或甚至無法再行遊玩流亡黯道。感謝你協助維護瓦爾克拉斯的和平。",min_x = 0}) then
                api_ClickScreen(1187,309,1)
                return bret.RUNNING
            end

            local top_left_page= {"社交","角色","選項","技能","活動"}
            if poe2_api.find_text({UI_info = env.UI_info, text = top_left_page,min_x = 0,min_y = 32,max_x = 381,max_y = 81}) then
                poe2_api.find_text({UI_info = env.UI_info, text = top_left_page,min_x = 0,min_y = 32,max_x = 381,max_y = 81,add_x = 250,add_y = -8,click = 2})
                return bret.RUNNING
            end

            local top_mid_page = {"傳送", "天賦技能", "重置天賦點數", "Checkpoints"}    
            if poe2_api.find_text({UI_info = env.UI_info, text = top_mid_page,min_x = 0,add_x = 215, click = 2}) then
                return bret.RUNNING
            end

            local shop_click = {"精選","黯幣","願望清單"}
            if poe2_api.find_text({UI_info = env.UI_info, text = shop_click,min_x = 0,min_y = 0,max_y = 81}) then
                poe2_api.find_text({UI_info = env.UI_info, text = shop_click,min_x = 0,min_y = 0,max_y = 81,add_x = 673,add_y = 4,click = 2})
                return bret.RUNNING
            end

            if poe2_api.find_text({UI_info = env.UI_info, text = "私訊",min_x = 0,min_y = 0,max_x = 400}) then
                poe2_api.find_text({UI_info = env.UI_info, text = "私訊",min_x = 0,min_y = 0,max_x = 400,add_x = 265,click = 2})
                return bret.RUNNING
            end
            if poe2_api.find_text({UI_info = env.UI_info, text="你確定要傳送至此玩家的位置？"}) then
                api_ClickScreen(916,467,1)
                return bret.RUNNING 
            end

            if poe2_api.find_text({UI_info = env.UI_info, text = "浩劫覺醒獎勵",min_x = 100,max_x = 1300,match = 1,threshold = 0.8}) then
                poe2_api.find_text({UI_info = env.UI_info, text = "浩劫覺醒獎勵",min_x = 100,max_x = 1300,match = 1,threshold = 0.8,click = 2})
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

            if not poe2_api.table_contains(my_game_info.hideout , player_info.current_map_name_utf8) then
                if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖",min_x = 0}) then
                    poe2_api.click_keyboard("esc")
                end
            end

            local time_end = api_GetTickCount64()
            poe2_api.time_p("Not_Main_Page_Otherworld 耗时 -->", time_end - current_time)
            return bret.SUCCESS
        end
    },

    -- 设置基础技能
    Set_Base_Skill = {
        run = function(self, env)
            poe2_api.print_log("设置基础技能...")
            poe2_api.dbgp("设置基础技能...")
            
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
            local mouse_check = env.mouse_check or false
            
            if not mouse_check then
                poe2_api.dbgp("mouse_check", mouse_check)
                return bret.SUCCESS
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

            return bret.SUCCESS
        end
    },


    -- 使用任务道具
    Use_Task_Props = {
        run = function(self, env)
            poe2_api.print_log("使用任务道具...")
            return bret.SUCCESS
        end
    },

    -- 对话分解NPC
    Dialogue_Break_Down_NPC = {
        run = function(self, env)
            poe2_api.dbgp("开始执行对话分解NPC...")
            local current_time = api_GetTickCount64()
            local bag_info = env.bag_info
            local player_info = env.player_info
            local config = env.user_config
            
            
            poe2_api.dbgp(string.format("当前地图: %s", player_info.current_map_name_utf8 or "未知"))
            poe2_api.dbgp(string.format("背包物品数量: %d", bag_info and #bag_info or 0))

            -- 不在藏身处直接返回
            if not poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                poe2_api.dbgp("不在藏身处，跳过分解流程")
                return bret.SUCCESS
            end
            
            local break_down = config["全局設置"]["刷图通用設置"]["是否分解暗金"]
            -- local break_down = fasle
            poe2_api.dbgp(string.format("分解暗金设置: %s", tostring(break_down)))
            
            -- 检查是否有可分解物品
            local function check_brak_items()
                poe2_api.dbgp("开始检查可分解物品...")
                if bag_info then
                    for _, item in ipairs(bag_info) do
                        if poe2_api.table_contains(my_game_info.sell_list, item.category_utf8) and item.color ~= 0 then
                            -- poe2_api.dbgp(string.format("找到可分解物品: %s (类型: %s, 颜色: %d)", 
                            --     item.baseType_utf8 or "无名", item.category_utf8 or "无类型", item.color or -1))
                            return true
                        end
                    end
                end
                poe2_api.dbgp("未找到可分解物品")
                return false
            end
            
            
            poe2_api.dbgp("当前在藏身处")
            
            -- 获取物品配置信息
            local function get_items_config_info()
                poe2_api.dbgp("开始解析物品过滤配置...")
                local item_configs = config["物品過濾"] or {}
                local processed_configs = {}
                
                for i, cfg in ipairs(item_configs) do
                    poe2_api.dbgp(string.format("处理配置项 %d: 类型=%s, 基础类型=%s", 
                        i, cfg["類型"] or "无", cfg["基礎類型名"] or "无"))
                    
                    local processed = {
                        ["類型"] = cfg["類型"] and type(cfg["類型"]) == "table" and cfg["類型"] or {cfg["類型"]},
                        ["名稱模式"] = cfg["基礎類型名"] and cfg["基礎類型名"] == "全部物品" and "all" or "specific",
                        ["匹配名稱"] = cfg["基礎類型名"] and cfg["基礎類型名"] ~= "全部物品" and {cfg["基礎類型名"]} or {},
                        ["颜色"] = {}
                    }
                    
                    if cfg["白裝"] then table.insert(processed["颜色"], 0) end
                    if cfg["藍裝"] then table.insert(processed["颜色"], 1) end
                    if cfg["黃裝"] then table.insert(processed["颜色"], 2) end
                    if cfg["暗金"] then table.insert(processed["颜色"], 3) end
                    
                    processed["不撿"] = cfg["不撿"]
                    processed["等級"] = cfg["等級"]
                    
                    poe2_api.dbgp(string.format("配置项 %d 处理结果: 不捡=%s, 颜色条件=%s", 
                        i, tostring(processed["不撿"]), table.concat(processed["颜色"], ",")))
                    
                    table.insert(processed_configs, processed)
                end
                return processed_configs
            end
            
            local processed_configs = get_items_config_info()
            poe2_api.dbgp(string.format("共加载 %d 条物品过滤规则", #processed_configs))
            
            -- 提取等级
            local function extract_level(text)
                local level = string.match(text, "階級%s*(%d+)")
                poe2_api.dbgp(string.format("从文本 '%s' 中提取等级: %s", text, level or "无"))
                return level and tonumber(level) or nil
            end
            
            -- 匹配物品
            local function match_item(item, cfg)
                poe2_api.dbgp(string.format("开始匹配物品: %s (类型: %s)", item.baseType_utf8 or "无名", item.category_utf8 or "无类型"))
                
                if not cfg["類型"][1] or item.category_utf8 ~= my_game_info.type_conversion[cfg["類型"][1]] then
                    poe2_api.dbgp("类型不匹配，跳过")
                    return false
                end
                
                -- 名称匹配
                if cfg["名稱模式"] == "specific" then
                    if not cfg["匹配名稱"][1] or not poe2_api.table_contains(cfg["匹配名稱"], item.baseType_utf8) then
                        poe2_api.dbgp("名称不匹配，跳过")
                        return false
                    end
                end
                
                -- 等级检查
                local level = cfg["等級"]
                if level then
                    local item_type = level["type"]
                    poe2_api.dbgp(string.format("等级检查: 类型=%s", item_type))
                    
                    if item.category_utf8 == "Map" then
                        local map_level = extract_level(item.baseType_utf8)
                        if item_type == "exact" then
                            local item_level = level["value"]
                            if map_level and map_level < item_level - 3 then
                                poe2_api.dbgp(string.format("地图等级 %d 低于要求 %d，跳过", map_level, item_level))
                                return false
                            end
                        else
                            local min_level = level["min"]
                            local max_level = level["max"]
                            if map_level and (map_level < min_level or map_level > max_level) then
                                poe2_api.dbgp(string.format("地图等级 %d 不在范围 %d-%d 内，跳过", map_level, min_level, max_level))
                                return false
                            end
                        end
                    elseif poe2_api.table_contains({"UncutSkillGem", "UncutReservationGem", "UncutSupportGem"}, item.category_utf8) then
                        if item_type == "exact" then
                            local item_level = level["value"]
                            if item.skillGemLevel and (item.skillGemLevel < item_level or item.skillGemLevel > item_level) then
                                poe2_api.dbgp(string.format("宝石等级 %d 不符合要求 %d，跳过", item.skillGemLevel or 0, item_level))
                                return false
                            end
                        else
                            local min_level = level["min"]
                            local max_level = level["max"]
                            if item.skillGemLevel and (item.skillGemLevel < min_level or item.skillGemLevel > max_level) then
                                poe2_api.dbgp(string.format("宝石等级 %d 不在范围 %d-%d 内，跳过", item.skillGemLevel or 0, min_level, max_level))
                                return false
                            end
                        end
                    else
                        if item_type == "exact" then
                            local item_level = level["value"]
                            if item.DemandLevel and item.DemandLevel < item_level - 3 then
                                poe2_api.dbgp(string.format("物品需求等级 %d 低于要求 %d，跳过", item.DemandLevel or 0, item_level))
                                return false
                            end
                        else
                            local min_level = level["min"]
                            local max_level = level["max"]
                            if item.DemandLevel and min_level and max_level and (item.DemandLevel < min_level or item.DemandLevel > max_level) then
                                poe2_api.dbgp(string.format("物品需求等级 %d 不在范围 %d-%d 内，跳过", item.DemandLevel or 0, min_level, max_level))
                                return false
                            end
                        end
                    end
                end
                
                -- 颜色检查
                if #cfg["颜色"] > 0 and not poe2_api.table_contains(cfg["颜色"], item.color) then
                    poe2_api.dbgp(string.format("颜色 %d 不符合条件 %s，跳过", item.color or -1, table.concat(cfg["颜色"], ",")))
                    return false
                end
                
                -- 通货排除黄金
                if item.category_utf8 == "StackableCurrency" and poe2_api.table_contains({"黃金", "金幣"}, item.baseType_utf8) then
                    poe2_api.dbgp("排除黄金货币，跳过")
                    return false
                end
                
                poe2_api.dbgp("物品匹配成功")
                return true
            end
            
            -- 检查是否不拾取
            local function is_do_without_pick_up(item)
                poe2_api.dbgp(string.format("检查物品 %s 是否设置为不拾取", item.baseType_utf8 or "无名"))
                
                local item_key = nil
                for k, v in pairs(my_game_info.type_conversion) do
                    if v == item.category_utf8 then
                        item_key = k
                        break
                    end
                end
                
                if item_key then
                    for _, cfg in ipairs(processed_configs) do
                        if cfg["類型"][1] == item_key then
                            if cfg["不撿"] and (cfg["基礎類型名"] == "全部物品" or item.baseType_utf8 == cfg["基礎類型名"]) then
                                poe2_api.dbgp("物品设置为不拾取")
                                return true
                            end
                        end
                    end
                end
                return false
            end
            
            -- 获取不需要的物品列表
            local function get_not_item(items)
                poe2_api.dbgp("开始筛选不需要的物品...")
                local break_list = {}
                
                local function get_not(item)
                    poe2_api.dbgp(string.format("检查物品: %s (类型: %s, 颜色: %d)", 
                        item.baseType_utf8 or "无名", item.category_utf8 or "无类型", item.color or -1))
                    
                    if item.category_utf8 == "QuestItem" and item.baseType_utf8 == "知識之書" then
                        poe2_api.dbgp("知识之书，保留")
                        return false
                    end
                    
                    if is_do_without_pick_up(item) then
                        return true
                    end
                    
                    for _, cfg in ipairs(processed_configs) do
                        if match_item(item, cfg) then
                            if cfg["不撿"] then
                                poe2_api.dbgp("配置标记为不捡")
                                return true
                            end
                            
                            if item.baseType_utf8 == "知識卷軸" then
                                local index = {}
                                for _, i in ipairs(items) do
                                    if i.baseType_utf8 == "知識卷軸" then
                                        table.insert(index, i)
                                    end
                                end
                                if #index > 2 then
                                    poe2_api.dbgp("知识卷轴超过2个，标记为分解")
                                    return true
                                end
                            end
                            
                            if poe2_api.table_contains(my_game_info.equip_type, item.category_utf8) and item.color > 0 and not item.not_identified then
                                local suffixes = api_GetObjectSuffix(item.mods_obj)
                                if not suffixes then
                                    poe2_api.dbgp("无词缀物品，标记为分解")
                                    return {item}
                                end
                                if not poe2_api.filter_item(item, suffixes, config["物品過濾"] or {}) then
                                    poe2_api.dbgp("词缀不符合要求，标记为分解")
                                    return true
                                end
                            end
                            poe2_api.dbgp("物品符合保留条件")
                            return false
                        end
                    end
                    poe2_api.dbgp("无匹配配置，默认保留")
                    return true
                end
                
                if not items then
                    poe2_api.dbgp("无物品数据")
                    return false
                end
                
                for _, item in ipairs(items) do
                    if not poe2_api.table_contains(my_game_info.sell_list, item.category_utf8) and item.color ~= 3 then
                        poe2_api.dbgp(string.format("物品 %s 不在分解列表中，跳过", item.baseType_utf8 or "无名"))
                        goto continue
                    end
                    
                    if item.color == 0 then
                        poe2_api.dbgp("白色物品，跳过")
                        goto continue
                    end
                    
                    local is_dis = get_not(item)
                    if is_dis then
                        poe2_api.dbgp("添加到分解列表")
                        table.insert(break_list, item)
                    end
                    
                    ::continue::
                end
                
                poe2_api.dbgp(string.format("共找到 %d 件需要分解的物品", #break_list))
                return break_list
            end
            
            local break_list = nil
            if break_down and check_brak_items() then
                if bag_info then
                    break_list = get_not_item(bag_info)
                    if not break_list or #break_list == 0 then
                        poe2_api.dbgp("没有需要分解的物品")
                        return bret.SUCCESS
                    end
                end
                
                if current_time - (self.last_action_time or 0) >= (self.action_interval or 1) then
                    poe2_api.dbgp("检查UI界面...")
                    
                    if poe2_api.find_text({UI_info = env.UI_info, text = "重鑄台", min_x = 0}) and poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0}) then
                        poe2_api.dbgp("发现重铸台界面，按空格关闭")
                        poe2_api.click_keyboard("space")
                        self.last_action_time = current_time
                        return bret.RUNNING
                    end
                    
                    if poe2_api.find_text({UI_info = env.UI_info, text = "重置天賦點數", min_x = 0, max_y = 200}) then
                        poe2_api.dbgp("发现天赋重置界面，按空格关闭")
                        poe2_api.click_keyboard("space")
                        self.last_action_time = current_time
                        return bret.RUNNING
                    end
                    
                    if poe2_api.find_text({UI_info = env.UI_info, text = "購買或販賣", min_x = 0, max_x = 800}) then
                        poe2_api.dbgp("发现商店界面，按空格关闭")
                        poe2_api.click_keyboard("space")
                        self.last_action_time = current_time
                        return bret.RUNNING
                    end
                    
                    if poe2_api.find_text({UI_info = env.UI_info, text = "重置天賦點數", min_x = 0}) and poe2_api.find_text({UI_info = env.UI_info, text = "返還輿圖天賦", min_x = 0}) then
                        poe2_api.dbgp("发现天赋重置确认界面，点击'再会'")
                        poe2_api.find_text({UI_info = env.UI_info, text = "再會", click = 2})
                        self.last_action_time = current_time
                        return bret.RUNNING
                    end
                    
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "時間建造者．凱亞祖利 的物品", min_x = 0}) then
                        poe2_api.dbgp("未发现分解NPC物品界面")
                        api_Sleep(100)
                        if not poe2_api.find_text({UI_info = env.UI_info, text = "祛魔物品", min_x = 0}) then
                            poe2_api.dbgp("设置交互对象为时间建造者")
                            env.interactive = "時間建造者．凱亞祖利"
                            return bret.FAIL
                        else
                            poe2_api.dbgp("发现祛魔物品界面，点击关闭")
                            poe2_api.find_text({UI_info = env.UI_info, text = "祛魔物品", click = 2})
                            api_Sleep(1000)
                        end
                    else
                        if break_list and #break_list > 0 then
                            poe2_api.dbgp("开始分解物品...")
                            for _, item in ipairs(break_list) do
                                poe2_api.dbgp(string.format("分解物品: %s", item.baseType_utf8 or "无名"))
                                poe2_api.ctrl_left_click_bag_items(item.obj, bag_info)
                                api_Sleep(200)
                            end
                            poe2_api.dbgp("点击确认分解")
                            poe2_api.find_text({UI_info = env.UI_info, text = "接受", min_x = 315, min_y = 719, max_x = 443, max_y = 752, click = 2})
                        end
                    end
                else
                    poe2_api.dbgp(string.format("操作冷却中，剩余时间: %.1f秒", 
                        (self.action_interval or 1) - (current_time - (self.last_action_time or 0))))
                end
                return bret.RUNNING
            else
                if poe2_api.find_text({UI_info = env.UI_info, text = "祛魔物品"}) and not env.is_shop then
                    poe2_api.dbgp("发现祛魔物品界面且不在商店，点击关闭")
                    poe2_api.find_text({UI_info = env.UI_info, text = "再會", click = 2})
                    api_Sleep(100)
                end
                poe2_api.dbgp("无需分解操作")
                return bret.SUCCESS
            end
        end
    },

    -- 检查是否获得牌匾
    Is_Get_Plaque = {
        run = function(self, env)
            poe2_api.print_log("检查是否获得牌匾...")
            return bret.SUCCESS
        end
    },

    -- 是否要滴注
    need_to_instill = {
        run = function(self, env)
            poe2_api.print_log("是否要滴注")
            local dist_ls = env.dist_ls
            local bag_info = env.bag_info
            local not_use_map = env.not_use_map
            -- 精炼表
            local formula_list = {}
            local warehouse_type = env.warehouse_type
            local player_info = env.player_info
            local user_map = env.user_map
            local priority_map = env.priority_map
            local is_dizhu = env.is_dizhu
            
            -- 非藏身处不滴注
            if not poe2_api.table_contains(player_info.current_map_name_utf8,my_game_info.hideout)then
                env.dizhu_end = false
                return bret.SUCCESS
            end
            if env.one_other_map then
                return bret.SUCCESS
            end
            local function shut_down_pages()
                if poe2_api.find_text({UI_info = env.UI_info, text="滴注中",min_x=200,max_x=1050,max_y=300})then
                    local a = api_Getinventorys(0x25,0)
                    if a then
                        if not poe2_api.find_text({UI_info = env.UI_info, text="背包",min_x=1000,min_y=32,max_x=1600,max_y=81}) then
                            poe2_api.click_keyboard("i")
                            api_Sleep(100)
                            return bret.RUNNING
                        end
                        poe2_api.find_text({UI_info = env.UI_info, text = "滴注中",min_x=200,max_x=1050,max_y=300,click=4,add_y=130})
                        api_Sleep(200)
                        poe2_api.find_text({UI_info = env.UI_info, text = "滴注中",min_x=200,max_x=1050,max_y=300,click=4,add_y=240,add_x=-75})
                        api_Sleep(200)
                        poe2_api.find_text({UI_info = env.UI_info, text = "滴注中",min_x=200,max_x=1050,max_y=300,click=4,add_y=240})
                        api_Sleep(200)
                        poe2_api.find_text({UI_info = env.UI_info, text = "滴注中",min_x=200,max_x=1050,max_y=300,click=4,add_y=240,add_x=75})
                        api_Sleep(200)
                        return bret.RUNNING
                    end
                    poe2_api.find_text({UI_info = env.UI_info, text = "滴注中",min_x=200,max_x=1050,max_y=300,click=2,add_y=-10,add_x=156})
                    return bret.RUNNING
                end
                return bret.SUCCESS
            end
            -- 检查是否滴注过
            local function check_item_in_bag(bag_info, name, obj)
                if obj then
                    if obj.color == 0 then
                        poe2_api.dbgp("白色钥匙,不滴注")
                        return true
                    end
                    local suffixes = api_GetObjectSuffix(obj.mods_obj)
                    if suffixes then
                        -- 是否有【瘋癲】
                        for _, s in ipairs(suffixes) do
                            if string.find(s.name_utf8, "瘋癲") then
                                -- 有词条，被滴注过
                                return true
                            end
                        end
                        -- 有词条，没滴注过
                        return false
                    end
                end

                for _, item in ipairs(bag_info) do
                    if item.baseType_utf8 == name then
                        if item.color == 0 then
                            goto continue
                        end

                        local suffixes = api_GetObjectSuffix(item.mods_obj)
                        if suffixes then
                            -- 是否有【瘋癲】
                            local b = false
                            for _, s in ipairs(suffixes) do
                                if string.find(s.name_utf8, "瘋癲") then
                                    -- 有词条，被滴注过
                                    b = true
                                    break
                                end
                            end
                            -- 有词条，没滴注过
                            if not b then return item end
                        else
                            -- 没词条
                            if item.color ~= 0 then
                                -- 不是白色钥匙
                                -- 开背包
                                for i = 1, 10 do
                                    if poe2_api.find_text({UI_info = env.UI_info, min_x = 1040, min_y = 46, max_x = 1090, max_y = 70, text = "背包" }) then
                                        break
                                    end
                                    poe2_api.click_keyboard("i")
                                    api_Sleep(300)
                                end

                                local b = false
                                local pos = poe2_api.get_center_position(
                                    {item.start_x, item.start_y},
                                    {item.end_x, item.end_y}
                                )
                                if pos then
                                    poe2_api.natural_move(pos[1], pos[2])
                                    api_Sleep(1000)
                                    -- 再判断一次
                                    local suffixes = api_GetObjectSuffix(item.mods_obj)
                                    if suffixes then
                                        for _, s in ipairs(suffixes) do
                                            if string.find(s.name_utf8, "瘋癲") then
                                                -- 有词条，被滴注过
                                                b = true
                                                break
                                            end
                                        end
                                        if not b then return item end
                                    end
                                end
                                if b then break end
                            end
                        end
                    end
                    ::continue::
                end
                return false
            end
            -- # 无精炼
            if env.dizhu_end or is_dizhu then
                return shut_down_pages()
            end
            for k, dist in pairs(dist_ls) do
                -- 是否滴注
                if not dist["是否塗油"] or dist["是否塗油"] == false then
                    return shut_down_pages()
                end
                
                local level = string.gsub("地圖鑰匙（階級 1）", "1", tostring(k))
                if not poe2_api.check_item_in_inventory(level, bag_info ) then
                    goto continue
                end
                local map_level = poe2_api.select_best_map_key(
                {   
                    inventory = bag_info,
                    key_level_threshold = user_map,
                    not_use_map = not_use_map,
                    priority_map = priority_map,
                    vall = true
                })
                -- 是否滴注过 【瘋癲】
                if map_level then
                    if check_item_in_bag(bag_info, 1, map_level) then
                        poe2_api.dbgp("地图钥匙已滴注过")
                        return shut_down_pages()
                    end
                else
                    env.is_dizhu = true
                    return bret.SUCCESS
                end
                -- 钥匙存在，没滴注过
                
                for _, s in ipairs(dist["配方"]) do
                    if s ~= "无" then
                        table.insert(formula_list, s)
                    end
                end
                if #formula_list == 0 then
                    -- 钥匙符合条件，但未设置 配方
                    goto continue
                end
                -- 解析 倉庫類型
                local warehouse_type = dist['倉庫類型']
                env.warehouse_type = warehouse_type
                if warehouse_type == "倉庫" then
                    env.warehouse_type_interactive = "个仓"
                else
                    env.warehouse_type_interactive = "公仓"
                end
                -- 地图钥匙等级
                local key_level = k
                env.key_level = key_level
                break
                ::continue::
            end
            -- # 是否操作过滴注
            if env.is_dizhu then
                return shut_down_pages()
            end
            
            -- # 是否有精炼表
            if next(formula_list) then
                env.refining_list = formula_list
                if not env.is_over then
                    return bret.FAIL
                else
                    return bret.SUCCESS
                end
            else
                return shut_down_pages()
            end
        end
    },
    -- 检查背包
    check_bag = {
        run = function(self, env)
            poe2_api.print_log("检查背包")
            -- 自定义补充精炼 优先级列表
            local Custom_refining_list = {
                "精煉的孤立",
                "精煉的苦難",
                "精煉的恐懼",
                "精煉的絕望",
                "精煉的厭惡",
                "精煉的忌妒",
                "精煉的偏執",
                "精煉的貪婪",
                "精煉的罪孽",
                "精煉的憤怒"
            }
            -- 检查背包中物品
            local function Custom_refining(bag_info)
                -- 检视背包
                for _, refining in ipairs(Custom_refining_list) do
                    for _, item in ipairs(bag_info) do
                        if refining == item.baseType_utf8 then
                            -- 背包有精炼
                            return refining
                        end
                    end
                end
                -- 如果没有找到匹配项，可以返回 nil 或其他默认值
                return nil
            end
            -- # 所需的精炼
            local need_refining = env.refining_list
            local missing_refinement = env.missing_refinement
            -- # 刷新背包信息
            env.bag_info = api_Getinventorys(1,0)
            -- # 指定等级 地图钥匙 检查
            local key_level = env.key_level
            -- 生成格式化字符串（替换 "1" 为 key_level）
            local key = string.gsub("地圖鑰匙（階級 1）", "1", tostring(key_level))
            if not env.check_map_key then
                if poe2_api.check_item_in_inventory(key,env.bag_info) then
                    env.exists_key = true
                else
                    -- # 背包中没有指定钥匙，选择最优钥匙
                    env.exists_key = false
                end
            end

            env.map_key_name = key
            -- 调用精炼检查逻辑
            for k, refining in ipairs(need_refining) do
                if refining == nil then
                    local c_refining = Custom_refining(env.bag_info)
                    if c_refining then
                        refining = c_refining
                        need_refining[k] = c_refining
                    end
                end

                if not refining or not poe2_api.check_item_in_inventory(refining,env.bag_info) then
                    table.insert(missing_refinement, refining)
                end
            end
            -- 是否少油：是,仓库取
            if #missing_refinement > 0 then
                if #missing_refinement == #need_refining then
                    env.is_refinement = false
                    env.missing_refinement = missing_refinement
                    return bret.SUCCESS
                end

                local a = {}
                for _, x in ipairs(need_refining) do
                    local found = false
                    for _, m in ipairs(missing_refinement) do
                        if x == m then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(a, x)
                    end
                end

                env.missing_refinement = missing_refinement
                env.is_refinement = a[1]
                return bret.SUCCESS
            end

            env.is_refinement = need_refining[1]
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

            local function get_object(name)
                for _, v in ipairs(env.range_info) do
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
                    local warehouse_obj1 = get_object("倉庫")
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
                    local warehouse_obj1 = get_object("公會倉庫")
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

                -- if env.target_point and env.end_point then
                --     poe2_api.dbgp("Open_Warehouse取消按键")
                --     api_ClickMove(poe2_api.toInt(warehouse.grid_x), poe2_api.toInt(warehouse.grid_y), poe2_api.toInt(player_info.world_z), 9)
                --     api_Sleep(100)
                -- end

                api_ClickMove(poe2_api.toInt(warehouse.grid_x), poe2_api.toInt(warehouse.grid_y), poe2_api.toInt(player_info.world_z), 1)

                if self.nubmer_index >= 10 then
                    poe2_api.dbgp("尝试次数超过10次(", self.nubmer_index, ")，执行ESC并重置计数器")
                    poe2_api.click_keyboard("esc")
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

    -- 仓库取物品
    Warehouse_pickup_items = {
        run = function(self, env)
            poe2_api.print_log("仓库取物品...")
            local text = ""
            if env.warehouse_type == "倉庫" then
                text = "倉庫"
            else
                text = "公會倉庫"
            end
            -- 确认打开仓库
            if not (poe2_api.find_text({UI_info = env.UI_info, text = "強調物品",min_x = 250,min_y = 700}) and poe2_api.find_text({UI_info = env.UI_info, text = text,min_x=0,min_y=32,max_x=381,max_y=81})) then
                return bret.RUNNING
            end
            local all_refinement_list = {}
            local refinement_pos = {
                ["精煉的恐懼"] = {274, 331},
                ["精煉的厭惡"] = {160, 330},
                ["精煉的絕望"] = {218, 329},
                ["精煉的偏執"] = {331, 269},
                ["精煉的憤怒"] = {161, 271},
                ["精煉的罪孽"] = {218, 272},
                ["精煉的苦難"] = {335, 333},
                ["精煉的忌妒"] = {392, 272},
                ["精煉的貪婪"] = {275, 275},
                ["精煉的孤立"] = {390, 330}
            }
            local missing_refinement = env.missing_refinement
            local refining_list = env.refining_list
            local bag_info = env.bag_info
            
            local config = env.user_config
            local check_res = false
            -- # 重置 背包 精煉
            local function reset_backpack_refinement(bag_info)
                for _, item in ipairs(bag_info) do
                    if string.find(item.baseType_utf8, "精煉") and not poe2_api.table_contains(refining_list, item.baseType_utf8) then
                        poe2_api.ctrl_left_click_bag_items(item.baseType_utf8, bag_info)
                    end
                end
            end
            -- 寻找背包中的精炼
            local function look_for_refinement_in_backpack(bag_info,page_type,page_name)
                for _, item in ipairs(bag_info) do
                    -- 寻找指定的精炼
                    if poe2_api.table_contains(missing_refinement, item.baseType_utf8) then
                        local pos= poe2_api.get_center_position_store({item.start_x, item.start_y}, {item.end_x, item.end_y})
                        local all_refinement = {
                            ["仓库页"] = page_name,
                            ["精煉"] = item.baseType_utf8,
                            ["坐标"] = {pos[1], pos[2]}
                        }
                        if page_type == 15 then
                            all_refinement["坐标"] = refinement_pos[item.baseType_utf8]
                        elseif page_type == 3 then
                            -- 通貨頁
                            local point = my_game_info.currency_page[{item.start_x, item.start_y}]
                            all_refinement["坐标"] = point
                        end
                        table.insert(all_refinement_list, all_refinement)
                        return true
                    end
                end
                return false
            end
            -- 从背包中拿出精炼
            local function out_of_refinement_in_backpack()
                for _,aj in ipairs(all_refinement_list) do
                    if poe2_api.table_contains(missing_refinement, aj["精煉"]) then
                        if not aj["坐标"] then
                            poe2_api.dbgp("坐标未找到")
                            return false
                        end
                        -- 查找仓库页文本并点击
                        if poe2_api.find_text({UI_info = env.UI_info, text = aj["仓库页"], max_y = 90, min_x = 0, max_x = 500, min_y = 0, click = 2}) then
                            api_Sleep(200)
                        elseif poe2_api.find_text({UI_info = env.UI_info, text = aj["仓库页"], max_y = 469, min_x = 556, min_y = 20, max_x = 851, click = 2}) then
                            api_Sleep(200)
                        else
                            return false
                        end
                        poe2_api.ctrl_left_click(aj["坐标"][1],aj["坐标"][2])
                        api_Sleep(500)
                        local filtered = {}
                        for _, x in ipairs(missing_refinement) do
                            if x ~= aj["精煉"] then
                                table.insert(filtered, x)
                            end
                        end
                        env.missing_refinement = filtered
                    end
                end
            end
            reset_backpack_refinement(bag_info)
            -- # 仓库类型
            local pages = nil
            if env.warehouse_type == "倉庫" then
                local items_info = poe2_api.get_items_config_info(config)
                local unique_storage_pages = {}
                for _, item in ipairs(items_info) do
                    if item["類型"][1] == "精煉" and item['存倉頁名'] and not item["不撿"] and item["基礎類型名"] == "全部物品" and not item["工會倉庫"] then
                        unique_storage_pages[item['存倉頁名']] = true
                    end
                end
                if next(unique_storage_pages) ~= nil then
                    local pages_list = api_GetRepositoryPages(0)
                    local pages = {}
                    for _, i in ipairs(pages_list) do
                        if unique_storage_pages[i.name_utf8] then
                            table.insert(pages, i)
                        end
                    end
                else
                    -- 仓库页
                    pages = api_GetRepositoryPages(0)
                end
            elseif env.warehouse_type == "工會倉庫" then
                local items_info = poe2_api.get_items_config_info(config)
                local unique_storage_pages = {}
                for _, item in ipairs(items_info) do
                    if item["類型"][1] == "精煉" and item['存倉頁名'] and not item["不撿"] and item["基礎類型名"] == "全部物品" and item["工會倉庫"] then
                        unique_storage_pages[item['存倉頁名']] = true
                    end
                end
                if next(unique_storage_pages) ~= nil then
                    local pages_list = api_GetRepositoryPages(1)
                    local pages = {}
                    for _, i in ipairs(pages_list) do
                        if unique_storage_pages[i.name_utf8] then
                            table.insert(pages, i)
                        end
                    end
                else
                    -- 工会仓库页
                    pages = api_GetRepositoryPages(1)
                end
            else
                poe2_api.api_print("【倉庫類型】 错误！")
                return bret.FAIL
            end
            
            -- 獲取列表按鈕
            local tab_list_button = poe2_api.click_text_UI({UI_info = env.UI_info, text = "tab_list_button",ret_data = true})

            -- 獲取鎖定按鈕
            local lock = poe2_api.get_game_control_by_rect({min_x = 549,min_y = 34,max_x = 584,max_y = 74})
            local lock_button = {}
            for _,v in ipairs(lock) do
                if v.name_utf8 == "" and v.text_utf8 == "" then
                    table.insert(lock_button,v)
                end
            end
            if next(missing_refinement) ~= nil then
                local old_page = {}
                for _, page in ipairs(pages) do
                    -- 缺少的精炼已全部取出
                    if not missing_refinement then
                        break
                    end
            
                    -- 仓库页去重
                    if old_page[page.name_utf8] then
                        goto continue
                    else
                        old_page[page.name_utf8] = true
                    end
            
                    -- 跳過地图页
                    local skip_types = {[3]=true, [4]=true, [5]=true, [8]=true, [17]=true, [18]=true}
                    if skip_types[page.type] then
                        goto continue
                    end
                    
                    if not tab_list_button then
                        if poe2_api.find_text({UI_info = env.UI_info, text=page.name_utf8, max_y=90, min_x=0, max_x=500, min_y=0, click=2}) then
                            api_Sleep(200)
                        else
                            goto continue
                        end
                    else
                        if not lock_button or not next(lock_button) then
                            api_ClickScreen(poe2_api.toInt((tab_list_button.left+tab_list_button.right)/2),poe2_api.toInt((tab_list_button.top+tab_list_button.bottom)/2),1)
                            api_Sleep(2000)
                            api_ClickScreen(poe2_api.toInt((tab_list_button.left+tab_list_button.right)/2 + 30),poe2_api.toInt((tab_list_button.top+tab_list_button.bottom)/2 - 30),1)
                            api_Sleep(5000)
                            return bret.RUNNING
                        end
                        if poe2_api.find_text({UI_info = env.UI_info, text=page.name_utf8, max_y=469, min_x=556, min_y=20, max_x=851, click=2}) then
                            api_Sleep(500)
                        else
                            goto continue
                        end
                    end
            
                    -- 仓库
                    if env.warehouse_type == "倉庫" then
                        -- 检查仓库类型
                        if not poe2_api.find_text({UI_info = env.UI_info, text = '倉庫', min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
                            api_ClickScreen(523, 57,1)
                            return bret.RUNNING
                        end
                        
                        -- 检查仓库页
                        local bag_ls = api_Getinventorys(page.manage_index,0)
                        if not bag_ls then
                            goto continue
                        end
                        check_res = look_for_refinement_in_backpack(bag_item_rect, page.type, page.name_utf8)
            
                        if not check_res then
                            -- 该仓库没有精炼
                            goto continue
                        end
            
                        if check_res then
                            -- 有 指定精炼
                            out_of_refinement_in_backpack()
                        end
                    else
                        -- 公会仓库
                        if not poe2_api.find_text({UI_info = env.UI_info, text = '公會倉庫', min_x=0, min_y=32, max_x=381, max_y=81}) then
                            api_ClickScreen(523, 57,1)
                            return bret.RUNNING
                        end
            
                        if page.manage_index == 0 then
                            local pages1 = api_GetRepositoryPages(1)
                            for _, page1 in ipairs(pages1) do
                                if page.name_utf8 == page1.name_utf8 and page1.manage_index ~= 0 then
                                    page.manage_index = page1.manage_index
                                    break
                                end
                            end
                        end
                        local bag_ls = api_Getinventorys(page.manage_index, 2)
                        if not bag_ls then
                            goto continue
                        end
            
                        local check_res = look_for_refinement_in_backpack(bag_ls, page.type, page.name_utf8)
            
                        if not check_res then
                            -- 该仓库没有精炼
                            goto continue
                        end
            
                        if check_res then
                            -- 有 指定精炼
                            out_of_refinement_in_backpack()
                        end
                    end
            
                    ::continue::
                end
            end
            if env.missing_refinement then
                local refining_list = env.refining_list or {}
                local missing_refinement = env.missing_refinement or {}
                local new_refining_list = {}
                for _,refining in ipairs(refining_list) do
                    local found = false
                    for _,not_refining in ipairs(missing_refinement) do
                        if refining == not_refining then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(new_refining_list, refining)
                    end
                end
                env.refining_list = new_refining_list
            end
           -- 检查精炼列表是否为空
            if not env.refining_list or #env.refining_list == 0 then
                -- env.dizhu_end = true
                return bret.RUNNING
            end
            return bret.FAIL
        end
    },

    -- 检查背包页面
    is_bag_page = {
        run = function(self, env)
            poe2_api.print_log("是否已打开背包")
            
            -- # 清除页面
            if poe2_api.find_text({UI_info = env.UI_info, text = '購買或販賣', min_x = 0, max_x = 800}) then
                api_ClickScreen(792,169,1)
                api_Sleep(200)
            end

            if poe2_api.find_text({UI_info = env.UI_info, text = '重鑄台', min_x = 0}) and poe2_api.find_text({UI_info = env.UI_info, text = '摧毀三個相似的物品，重鑄為一個新的物品', min_x = 0}) then
                api_ClickScreen(1010,153,1)
                api_Sleep(200)
            end

            if not poe2_api.find_text({UI_info = env.UI_info, text = "背包" , min_x = 1040, min_y = 46, max_x = 1090, max_y = 70}) then
                poe2_api.click_keyboard("i",0)
                api_Sleep(300)
            end

            return bret.FAIL
        end
    },

    -- 重置物品
    res_item = {
        run = function(self, env)
            poe2_api.print_log("重置物品...")
            env.bag_info = api_Getinventorys(1,0)
            -- 检查背包中是否有任意精炼，有则点击打开滴注页面，无则结束节点
            local function check_refinement()
                for _, item in ipairs(env.bag_info) do
                    if string.find(item.baseType_utf8, "精煉") then
                        return item
                    end
                end
                return false
            end
            local it = check_refinement()
            if it then
                -- 清除多余页面
                if poe2_api.find_text({UI_info = env.UI_info, text ="強調物品" , min_x = 280,min_y = 730, max_x = 342, max_y = 758}) then
                    poe2_api.ctrl_left_click_bag_items(it.obj, env.bag_info, 1)
                    api_Sleep(500)
                end
                poe2_api.ctrl_left_click_bag_items(it.obj,env.bag_info,1)
                api_Sleep(500)
                -- 重置放置的地图钥匙
                if next(api_Getinventorys(0x26,0)) then
                    poe2_api.ctrl_left_click(520, 361)
                    api_Sleep(300)
                end
                -- 重置所有放置的精炼
                local re_pos = {{443, 467}, {520, 468}, {593, 470}}
                if next(api_Getinventorys(0x25,0)) then
                    for _, rp in ipairs(re_pos) do
                        poe2_api.ctrl_left_click(rp[1], rp[2])
                        api_Sleep(300)
                    end
                end
                env.is_refinement = it.baseType_utf8
            end
            return bret.FAIL
        end
    },

    -- 检查滴注页面
    Check_the_drip_page = {
        run = function(self, env)
            poe2_api.print_log("检查滴注页面")
            if poe2_api.find_text({UI_info = env.UI_info, text = "滴注中", min_x = 240, min_y = 210, max_x = 305, max_y = 231}) then
                poe2_api.dbgp("在滴注页面")
                return bret.FAIL
            else
                poe2_api.dbgp("不在滴注页面")
                return bret.SUCCESS
            end
        end
    },

    -- 打开滴注
    open_drip_page = {
        run = function(self, env)
            poe2_api.print_log("打开滴注")
            if env.is_refinement then
                poe2_api.ctrl_left_click_bag_items(env.is_refinement,env.bag_info,1)
                api_Sleep(800)
            end
            return bret.RUNNING
        end
    },

    -- 放置钥匙
    place_key = {
        run = function(self, env)
            poe2_api.print_log("放置地图钥匙")
            local bag_info = env.bag_info
            local key = env.map_key
            local key_ok = env.key_ok
            local user_map = env.user_map
            local not_use_map = env.not_use_map
            local priority_map = env.priority_map
            table.insert(not_use_map, "此區域玩家瘋癲")
            -- 選擇最佳地圖
            local map_level = poe2_api.select_best_map_key(
                {
                    inventory  = bag_info,
                    key_level_threshold = user_map,
                    not_use_map = not_use_map,
                    priority_map = priority_map,
                    vall = true
                }
            )

            if map_level then
                -- 點擊地圖物品
                poe2_api.ctrl_left_click_bag_items(
                    map_level.obj,
                    bag_info,
                    2
                )
                api_Sleep(200)
            end
            env.key_ok = key_ok
            api_Sleep(500)
            env.check_map_key = true
            return bret.SUCCESS
        end
    },

    -- 放置精炼
    place_refining = {
        run = function(self, env)
            poe2_api.print_log("放置精炼")
            local refining_list = env.refining_list
            local re_pos = {{443, 467}, {520, 468}, {593, 470}}
            if api_Getinventorys(0x25,0) then
                for _, rp in ipairs(re_pos) do
                    poe2_api.ctrl_left_click(rp[1], rp[2])
                end
            end
            local in_refining = {}
            for _,i in ipairs(refining_list) do
                for _,bag in ipairs(api_Getinventorys(1,0)) do
                    if bag.baseType_utf8 == i then
                        table.insert(in_refining,i)
                        break
                    end
                end
            end
            for k , in_refining in ipairs(in_refining) do
                poe2_api.ctrl_left_click_bag_items(in_refining,api_Getinventorys(1,0))
                api_Sleep(300)
            end

            -- 检查
            local in_instill = api_Getinventorys(0x25,0)
            for k,instill in ipairs(in_instill) do
                if instill.baseType_utf8 ~= in_refining[k] then
                    -- 放回背包
                    poe2_api.ctrl_left_click(re_pos[k][1], re_pos[k][2])
                    api_Sleep(300)
                    poe2_api.ctrl_left_click_bag_items(instill,api_Getinventorys(1,0))
                    api_Sleep(300)
                end
            end
            poe2_api.ctrl_left_click(525,701)
            api_Sleep(300)
            
            -- 取出地图
            if api_Getinventorys(0x26,0) then
                poe2_api.ctrl_left_click(520,361)
                api_Sleep(300)
            end

            -- 取出精煉
            if api_Getinventorys(0x25,0) then
                for _, rp in ipairs(re_pos) do
                    poe2_api.ctrl_left_click(rp[1], rp[2])
                    api_Sleep(300)
                end
            end

            local ui_esc = {"滴注","背包"}
            for _,ui in ipairs(ui_esc) do
                if poe2_api.find_text({UI_info = env.UI_info, text = ui}) then
                    poe2_api.click_keyboard("space")
                    api_Sleep(300)
                end
            end

            -- 结束
            env.is_over = true
            return bret.SUCCESS
        end
    },

    -- 存储物品
    Store_items = {
        run = function(self, env)
            poe2_api.print_log("存储物品...")
            return bret.SUCCESS
        end
    },

    -- 商店地图
    Shop_Map = {
        run = function(self, env)
            poe2_api.print_log("访问商店地图...")
            return bret.SUCCESS
        end
    },

    -- 更新地图石
    Update_Map_Stone = {
        run = function(self, env)
            poe2_api.print_log("更新地图石...")
            return bret.SUCCESS
        end
    },

    -- 检查是否需要拿地图
    Is_Need_Take_Map = {
        run = function(self, env)
            poe2_api.print_log("检查是否需要拿地图...")
            poe2_api.dbgp("开始执行 Is_Need_Take_Map 检查")
            
            local current_time = api_GetTickCount64()
            local bag_info = env.bag_info
            local player_info = env.player_info
            
            local is_map_complete = env.is_map_complete
            local user_map = env.user_map
            local not_use_map = env.not_use_map
            local is_have_map = env.is_have_map
            local current_map_info = env.current_map_info
            local one_other_map = env.one_other_map
            local config = env.user_config
            local entry_length_take_map = env.entry_length_take_map
            

            -- poe2_api.dbgp("环境变量检查:", {
            --     bag_info = bag_info and #bag_info or "nil",
            --     player_info = player_info and "exists" or "nil",
            --     range_info = range_info and #range_info or "nil",
            --     is_map_complete = is_map_complete,
            --     user_map = user_map,
            --     not_use_map = not_use_map,
            --     is_have_map = is_have_map,
            --     config = config and "exists" or "nil"
            -- })

            if not player_info then
                return bret.RUNNING
            end
        
            -- 检查背包中是否有地图
            local function check_map_in_bag(bag_info, return_count)
                return_count = return_count or true
                local matches = {}
                
                if bag_info then
                    for _, item in ipairs(bag_info) do
                        if item.baseType_utf8 and string.find(item.baseType_utf8, "地圖鑰匙") then
                            table.insert(matches, item)
                        end
                    end
                end
                
                if return_count then
                    return #matches > 0 and #matches or false
                else
                    return #matches > 0 and matches or false
                end
            end
        
            -- 检查当前是否在城镇或藏身处
            local function is_in_town_or_hideout()
                local result = false
                if string.find(player_info.current_map_name_utf8 or "", "town") then
                    result = true
                end
                
                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                    result = true
                end
                
                -- poe2_api.dbgp("is_in_town_or_hideout 检查:", {
                --     current_map = player_info.current_map_name_utf8,
                --     result = result
                -- })
                return result
            end
        
            -- 获取非地图物品（传送点/异界之门除外）
            local function get_not_map()
                local result = false
                for _, item in ipairs(env.range_info) do
                    if item.type == 5 and item.name_utf8 ~= '' and 
                    item.name_utf8 ~= "傳送點" and item.name_utf8 ~= '異界之門' then
                        result = item
                        break
                    end
                end
                
                -- poe2_api.dbgp("get_not_map 结果:", result)
                return result
            end
        
            -- 主逻辑
            if not is_in_town_or_hideout() then
                poe2_api.dbgp("不在城镇或藏身处，直接返回SUCCESS")
                return bret.SUCCESS
            end
        
            -- 如果已经在世界地图界面，直接返回成功
            local world_map_text = poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", max_y = 100, min_x = 250})
            if world_map_text then
                poe2_api.dbgp("已在世界地图界面，返回SUCCESS")
                return bret.SUCCESS
            end
        
            -- 检查是否需要合成地图
            local need_synthesis = config["全局設置"]["刷图通用設置"]["自動合成地圖"]
            poe2_api.dbgp("自动合成地图设置:", need_synthesis)
            poe2_api.dbgp("env.is_need_strengthen:", env.is_need_strengthen)
            
            if env.is_need_strengthen and need_synthesis then
                poe2_api.dbgp("需要强化地图，返回FAIL")
                return bret.FAIL
            end
        
            -- 检查背包中的地图
            local map_count = check_map_in_bag(bag_info)
            local best_map = poe2_api.select_best_map_key({
                inventory = bag_info, 
                key_level_threshold = user_map,
                not_use_map = not_use_map
            })

            -- poe2_api.dbgp("背包地图检查结果:", {
            --     map_count = map_count,
            --     best_map = best_map and "exists" or "nil"
            -- })
        
            poe2_api.dbgp("背包地图数量: " .. (map_count or 0))

            items_info = poe2_api.get_items_config_info(env.user_config)
            -- 创建唯一存储页面集合
            local unique_storage_pages = {}
            for _, item in ipairs(items_info) do
                if item["類型"] and item["類型"] == "地圖鑰匙" and item["存倉頁名"] and not item["工會倉庫"] then
                    unique_storage_pages[item["存倉頁名"]] = true
                end
            end

            poe2_api.dbgp("存储页面信息:", {unique_storage_pages = unique_storage_pages or nil})
            
            poe2_api.dbgp("仓库类型设置:", env.warehouse_type_interactive)
        
            if not map_count or map_count < 1 or not best_map then
                -- poe2_api.dbgp("背包没有符合条件的地图")
                return bret.FAIL
            end

            
        
            -- 如果在藏身处且有可交互的非地图物品
            if is_in_town_or_hideout() then
                local not_map = get_not_map()
                -- poe2_api.dbgp("藏身处非地图物品检查:", not_map)
                
                if not_map and not is_map_complete then
                    if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) then
                        -- poe2_api.dbgp("发现世界地图文本，执行ESC")
                        poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0})
                        poe2_api.click_keyboard('esc')
                    end
                    return bret.SUCCESS
                end
            end

            -- poe2_api.dbgp("Is_Need_Take_Map 检查完成，返回SUCCESS")
            return bret.SUCCESS
        end
    },

    -- 取地图
    Take_Map = {
        run = function(self, env)
            poe2_api.print_log("从仓库拿地图...")
            poe2_api.dbgp("开始执行取地图 - 环境变量:", env)
            
            local current_time = api_GetTickCount64()
            local bag_info = env.bag_info
            local user_map = env.user_map
            local current_map_info = env.current_map_info
            local not_use_map = env.not_use_map
            local config = env.user_config
            local need_synthesis = config["全局設置"]["刷图通用設置"]["自動合成地圖"]
            -- local need_synthesis = false
            local player_info = env.player_info
            local entry_length_take_map = env.entry_length_take_map
            local map_update_to = env.map_update_to
            local text = nil
            
            
            poe2_api.dbgp("config配置 - 需要合成:", need_synthesis, "词条数量:", entry_length_take_map, "地图升级至:", map_update_to)
            
            if not current_map_info or not player_info then
                poe2_api.dbgp("缺失必要数据 - 当前地图信息副本:", current_map_info, "玩家信息:", player_info)
                return bret.RUNNING
            end
        
            -- 获取物品配置信息
            local items_info = poe2_api.get_items_config_info(config)
    
            poe2_api.dbgp("物品配置信息:", items_info)
            
            -- 创建唯一存储页面集合
            local unique_storage_pages = {}
            for _, item in ipairs(items_info) do
                if item["類型"] and item["類型"] == "地圖鑰匙" and item["存倉頁名"] and not item["工會倉庫"] then
                    unique_storage_pages[item["存倉頁名"]] = true
                end
            end
            
            -- 检查是否有唯一存储页面
            local has_storage_pages = next(unique_storage_pages) ~= nil
            
            if has_storage_pages then
                text = "倉庫"
            else
                text = "公會倉庫"
            end

            local emphasize_text = poe2_api.find_text({UI_info = env.UI_info, text = "強調物品", min_x = 250, min_y = 700})
            local warehouse_text = poe2_api.find_text({UI_info = env.UI_info, text = text, min_x=0, min_y=32, max_x=381, max_y=81})

            if not emphasize_text and not warehouse_text then
                if has_storage_pages then
                    env.warehouse_type_interactive = "个仓"
                else
                    env.warehouse_type_interactive = "公仓"
                end
                return bret.FAIL
            elseif text == "公會倉庫" then
                if poe2_api.find_text({UI_info = env.UI_info, text = "倉庫", min_x=0, min_y=32, max_x=381, max_y=81,add_x = 250, click = 2}) then
                    return bret.RUNNING
                end
            elseif text == "倉庫" then
                if poe2_api.find_text({UI_info = env.UI_info, text = "公會倉庫", min_x=0, min_y=32, max_x=381, max_y=81,add_x = 250, click = 2}) then
                    return bret.RUNNING
                end
            end
            
            -- 检查背包中的地图
            local function check_map_in_bag(bag_info)
                local count = 0  -- 初始化计数器为0
                
                poe2_api.dbgp("检查背包中的地图 - 背包信息:", bag_info)
                
                if bag_info then
                    for _, item in ipairs(bag_info) do
                        -- 查找包含“地圖鑰匙”的物品
                        if item.baseType_utf8 and string.find(item.baseType_utf8, "地圖鑰匙") then
                            count = count + 1  -- 找到则计数+1
                        end
                    end
                end
                
                poe2_api.dbgp("检查背包地图结果（数量）:", count)
                return count  -- 直接返回数量，无匹配时自然为0
            end
            
            -- 检查相同地图是否超过3个
            local function check_same_map_over_3(bag_info)
                poe2_api.dbgp("检查相同地图是否超过3个 - 背包信息:", bag_info)
                
                local item_counts = {}
                if bag_info then
                    for _, actor in ipairs(bag_info) do
                        if actor.baseType_utf8 and string.find(actor.baseType_utf8, "地圖鑰匙") and not actor.contaminated and not actor.not_identified and actor.baseType_utf8 ~= "地圖鑰匙（階級 15）" and actor.baseType_utf8 ~= "地圖鑰匙（階級 16）" then
                            item_counts[actor.baseType_utf8] = (item_counts[actor.baseType_utf8] or 0) + 1
                        end
                    end
                else
                    poe2_api.dbgp("背包没有地图")
                    poe2_api.dbgp("检查相同地图结果:", false)
                    return false
                end
                
                -- 检查是否有至少3个相同的物品
                local synthesis_possible = false
                for _, count in pairs(item_counts) do
                    if count >= 3 then
                        synthesis_possible = true
                        break
                    end
                end
                
                poe2_api.dbgp("检查相同地图结果 - 物品计数:", item_counts, "是否可以合成:", synthesis_possible)
                return synthesis_possible
            end

            local page = nil
            for _, item in ipairs(items_info) do
                if item["類型"] and item["類型"] == "地圖鑰匙" and item["存倉頁名"] and not item["不捡"] then
                    page = item["存倉頁名"]
                end
            end

            poe2_api.dbgp("page",page)

            local function check_map_test(max_y, min_x, max_x, min_y, map_num)
                -- 初始化变量
                local map_page = false
                local page_index = 0
                local user_map = env.user_map
                local not_use_map = env.not_use_map
                local map_update_to = env.map_update_to
                local need_synthesis = env.need_synthesis
                local bag_info = env.bag_info
                
                -- 调试输出初始参数
                poe2_api.dbgp("开始执行check_map_test - 参数:", 
                    "max_y" , max_y,
                    "min_x" , min_x,
                    "max_x" , max_x,
                    "min_y" , min_y,
                    "map_num" , map_num
                )
                
                -- 获取仓库页面
                local repositoryPages
                if text == "公會倉庫" then
                    repositoryPages = api_GetRepositoryPages(1)
                    poe2_api.dbgp("获取公会仓库页面 - 结果:", repositoryPages and #repositoryPages or 0)
                else
                    repositoryPages = api_GetRepositoryPages(0)
                    poe2_api.dbgp("获取普通仓库页面 - 结果:", repositoryPages and #repositoryPages or 0)
                end
                
                -- 检查是否为地图页
                if repositoryPages then
                    poe2_api.dbgp("开始检查仓库页面 - 总页数:", #repositoryPages)
                    for i, page_info in ipairs(repositoryPages) do
                        poe2_api.dbgp("检查页面#"..i.." - 名称:", page_info.name_utf8, "类型:", page_info.type)
                        if page_info.name_utf8 == page and page_info.type == 5 then
                            map_page = true
                            poe2_api.dbgp("找到匹配的地图页 - 索引:", i)
                            break
                        end
                    end
                end
                
                -- 选择最佳地图
                local best_map = poe2_api.select_best_map_key({
                    inventory = bag_info,
                    key_level_threshold = user_map,
                    not_use_map = not_use_map,
                    entry_length = map_update_to
                })
                poe2_api.dbgp("选择最佳地图 - 结果:", best_map ~= nil)
                
                
                -- 处理地图页
                if map_page then
                    poe2_api.dbgp("开始处理地图页 - 页面名称:", page)
                    
                    if poe2_api.find_text({UI_info = env.UI_info, 
                        text = page,
                        max_y = max_y,
                        min_x = min_x,
                        max_x = max_x,
                        min_y = min_y,
                        click = 2
                    }) then
                        api_Sleep(500)
                    end
                    
                    -- 初始化颜色和等级列表
                    local white, blue, gold, valls, level = {}, {}, {}, {}, {}
                    if user_map then
                        poe2_api.dbgp("开始解析用户地图配置 - 配置数量:", #user_map)
                        for _, config in ipairs(user_map) do
                            local levels = tonumber(config["階級"]) or 0
                            table.insert(level, levels)
                            
                            poe2_api.dbgp("配置项 - 等级:", levels, 
                                         "白图:", config["白"], 
                                         "蓝图:", config["藍"], 
                                         "黄图:", config["黃"], 
                                         "污染:", config["已污染"])
                            
                            if config["白"] and not poe2_api.table_contains(white, levels) then
                                table.insert(white, levels)
                            end
                            if config["藍"] and not poe2_api.table_contains(blue, levels) then
                                table.insert(blue, levels)
                            end
                            if config["黃"] and not poe2_api.table_contains(gold, levels) then
                                table.insert(gold, levels)
                            end
                            if config["已污染"] and not poe2_api.table_contains(valls, levels) then
                                table.insert(valls, levels)
                            end
                        end
                    end
                    
                    -- 罗马数字映射
                    local ROMAN_NUMERALS = {
                        [1] = "I", [2] = "II", [3] = "III", [4] = "IV", [5] = "V",
                        [6] = "VI", [7] = "VII", [8] = "VIII", [9] = "IX", [10] = "X",
                        [11] = "XI", [12] = "XII", [13] = "XIII", [14] = "XIV", [15] = "XV", [16] = "XVI"
                    }
                    
                    local the_maps_num = 0
                    local click_positions = {152, 202, 252, 302, 352, 402}
                    
                    -- 按等级降序查找
                    table.sort(level, function(a, b) return a > b end)
                    poe2_api.dbgp("排序后的等级列表 - 内容:", table.concat(level, ","))
                    
                    for _, num in ipairs(level) do
                        poe2_api.dbgp("处理等级 - 当前等级:", num)
                        if num >= 1 and num <= 16 then
                            local roman_num = ROMAN_NUMERALS[num]
                            poe2_api.dbgp("转换罗马数字 - 数字:", num, "罗马数字:", roman_num)
                            
                            local a = poe2_api.find_text({UI_info = env.UI_info, 
                                refresh = true,
                                text = roman_num,
                                max_y = 242,
                                min_x = 0,
                                max_x = 544,
                                min_y = 0,
                                position = 1
                            })
                            
                            if a then
                                poe2_api.dbgp("找到罗马数字 - 位置X:", a[1], "位置Y:", a[2])
                                
                                local min_x = a[1] - 45
                                local min_y = a[2] - 45
                                local max_x = a[1] + 45
                                local max_y = a[2] + 45
                                
                                the_maps_num = poe2_api.find_text_position({UI_info = env.UI_info, 
                                    refresh = true,
                                    min_x = min_x,
                                    min_y = min_y,
                                    max_x = max_x,
                                    max_y = max_y,
                                    lens = 0
                                })
                                the_maps_num = tonumber(the_maps_num) or 0
                                poe2_api.dbgp("地图数量检测 - 数量:", the_maps_num)
                                
                                if the_maps_num == 0 then
                                    poe2_api.dbgp("跳过空地图 - 罗马数字:", roman_num)
                                    goto continue
                                end
                                
                                if poe2_api.find_text({UI_info = env.UI_info, 
                                    refresh = true,
                                    text = roman_num,
                                    max_y = 242,
                                    min_x = 0,
                                    max_x = 544,
                                    min_y = 0,
                                    click = 2
                                }) then
                                    api_Sleep(500)
                                    
                                    local c = poe2_api.find_text_position({UI_info = env.UI_info, 
                                        refresh = true,
                                        min_x = 13,
                                        min_y = 263,
                                        max_x = 544,
                                        max_y = 622,
                                        num = 1,
                                        text = roman_num,
                                        click_times = 2,
                                        lens = 0
                                    })
                                    
                                    local b = poe2_api.select_best_map_key({
                                        inventory = api_Getinventorys(1, 0),
                                        key_level_threshold = user_map,
                                        not_use_map = not_use_map,
                                        entry_length = map_update_to
                                    })
                                    poe2_api.dbgp("背包地图检查 - 最佳地图:", b ~= nil)
                                    
                                    if map_num then
                                        local current_map_count = check_map_in_bag(api_Getinventorys(1, 0))
                                        poe2_api.dbgp("地图数量验证 - 当前:", current_map_count, "需要:", map_num + 3)
                                        
                                        if current_map_count >= map_num + 3 and b then
                                            poe2_api.dbgp("满足地图数量要求 - 返回成功")
                                            return true
                                        end
                                    end
                                    
                                    if c == 0 then
                                        poe2_api.dbgp("开始尝试点击不同位置 - 位置列表:", table.concat(click_positions, ","))
                                        
                                        for _, k in ipairs(click_positions) do
                                            poe2_api.dbgp("尝试位置 - X坐标:", k)
                                            local b = poe2_api.select_best_map_key({
                                                inventory = api_Getinventorys(1, 0),
                                                key_level_threshold = user_map,
                                                not_use_map = not_use_map,
                                                entry_length = map_update_to
                                            })
                                            
                                            if map_num then
                                                local map_num1 = check_map_in_bag(api_Getinventorys(1, 0))
                                                poe2_api.dbgp("地图数量检查 - 当前:", map_num1, "需要:", map_num)
                                                
                                                if map_num1 >= map_num and b then
                                                    poe2_api.dbgp("满足最低数量要求 - 返回成功")
                                                    return true
                                                end
                                            end
                                            
                                            api_ClickScreen(k, 258, 1)
                                            api_Sleep(1000)

                                            c = poe2_api.find_text_position({UI_info = env.UI_info, 
                                                refresh = true,
                                                min_x = 13,
                                                min_y = 263,
                                                max_x = 544,
                                                max_y = 622,
                                                num = 1,
                                                text = roman_num,
                                                click_times = 2,
                                                lens = 0
                                            })
                                            poe2_api.dbgp("点击后查找结果 - 找到数量:", c)
                                            
                                            if c > 0 then
                                                poe2_api.dbgp("位置点击成功 - 返回成功")
                                                return true
                                            end
                                        end
                                        goto continue
                                    end
                                    
                                    poe2_api.dbgp("成功点击罗马数字 " .. roman_num .. " (对应等级 " .. num .. ")")
                                    return true
                                end
                            else
                                poe2_api.dbgp("未找到罗马数字 - 跳过")
                            end
                        else
                            poe2_api.dbgp("无效等级 - 跳过")
                        end
                        ::continue::
                    end
                    return false
                end
                
                -- 非地图页处理
                poe2_api.dbgp("开始处理非地图页 - 页面名称:", page)
                
                if poe2_api.find_text({UI_info = env.UI_info, 
                    refresh = true,
                    text = page,
                    max_y = max_y,
                    min_x = min_x,
                    max_x = max_x,
                    min_y = min_y,
                    click = 2
                }) then
                    api_Sleep(1000)
                    
                    -- 获取页面索引
                    local page_index = 0
                    for _, page_info in ipairs(repositoryPages) do
                        if page_info.name_utf8 == page and page_info.type ~= 5 then
                            page_index = page_info.manage_index
                            break
                        end
                    end
                    poe2_api.dbgp("获取页面索引 - 结果:", page_index)
                    
                    -- 获取仓库物品
                    local items
                    if text == "公會倉庫" then
                        items = api_Getinventorys(page_index, 2)
                        poe2_api.dbgp("获取公会仓库物品 - 数量:", items and #items or 0)
                    else
                        items = api_Getinventorys(page_index, 0)
                        poe2_api.dbgp("获取普通仓库物品 - 数量:", items and #items or 0)
                    end
                    
                    -- 检查是否可以合成
                    local can_synthesize = check_same_map_over_3(items)
                    poe2_api.dbgp("合成检查 - 是否可以合成:", can_synthesize, "需要合成:", need_synthesis)
                    
                    -- 如果不需要合成或地图数量足够
                    if not (need_synthesis and can_synthesize) then
                        if map_num then
                            local bag_count = check_map_in_bag(api_Getinventorys(1, 0))
                            poe2_api.dbgp("背包地图检查 - 当前数量:", bag_count, "需要数量:", map_num)
                            
                            if bag_count > map_num and best_map then
                                env.entry_length_take_map = false
                                poe2_api.dbgp("满足数量要求 - 返回成功")
                                return true
                            end
                        end
                    end
                    
                    -- 从仓库取地图
                    poe2_api.dbgp("开始从仓库取地图")
                    local select_result = poe2_api.select_best_map_key({
                        inventory = items,
                        click = 1,
                        key_level_threshold = user_map,
                        type = 1,
                        not_use_map = not_use_map,
                        entry_length = map_update_to
                    })
                    poe2_api.dbgp("选择地图结果:", select_result ~= nil)
                    
                    if map_num then
                        local bag_count = check_map_in_bag(api_Getinventorys(1, 0))
                        poe2_api.dbgp("最终检查 - 当前数量:", bag_count, "需要数量:", map_num)
                        if bag_count > map_num and best_map then
                            poe2_api.dbgp("满足最终数量要求 - 返回成功")
                            return true
                        end
                    end
                end
                
                env.is_need_strengthen = false
                poe2_api.dbgp("所有检查未通过 - 返回失败")
                return false
            end

            
            -- 检查宝藏金锤是否激活
            local c = nil
            if current_map_info then
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == "TreasureVaultHammerActive" and item.flagStatus1 == 1 then
                        c = item
                        break
                    end
                end
            end
            poe2_api.dbgp("检查宝藏金锤是否激活:", c)
            
            -- 选择最佳地图
            local d = poe2_api.select_best_map_key({
                inventory = bag_info,
                key_level_threshold = user_map,
                not_use_map = not_use_map,
                entry_length = map_update_to
            })
            poe2_api.dbgp("选择最佳地图结果:", d)
            
            -- 检查背包地图数量
            local a = check_map_in_bag(bag_info)
            local is_need_strengthen = env.is_need_strengthen
            poe2_api.dbgp("初始检查 - 背包中的地图:", a, "最佳地图:", d, "是否需要强化:", is_need_strengthen)
            
            if not a or not d or a < 2 or is_need_strengthen then
                local reason = not a and "没有地图" or (not d and "没有合适地图" or (a < 2 and "地图少于2张" or "需要强化"))
                poe2_api.dbgp("需要获取更多地图 - 原因:", reason)
                
                -- 获取仓库标签按钮
                local tab_list_button = poe2_api.click_text_UI({UI_info = env.UI_info, text = "tab_list_button",ret_data = true})

                poe2_api.dbgp("tab_list_button:", tostring(tab_list_button))

                if not tab_list_button then
                    -- 未展开标签列表的情况
                    poe2_api.dbgp("未展开标签列表的情况")
                    if is_need_strengthen or need_synthesis then
                        check_map_test(90, 0, 500, 0)
                        return bret.RUNNING
                    end
                    
                    -- 尝试打开指定仓库页
                    if poe2_api.find_text({UI_info = env.UI_info, text = page, max_y = 90, min_x = 0, max_x = 500, min_y = 0, click = 2}) then
                        api_Sleep(1500)
                        
                        local repositoryPages
                        if text == "公會倉庫" then
                            repositoryPages = api_GetRepositoryPages(1)
                        else
                            repositoryPages = api_GetRepositoryPages(0)
                        end
                        
                        -- 获取页面索引
                        local page_index = 0
                        for _, page in ipairs(repositoryPages) do
                            if page.name_utf8 == page and page.type ~= 5 then
                                page_index = page.manage_index
                                break
                            end
                        end
                        
                        -- 获取仓库物品
                        local items
                        if text == "公會倉庫" then
                            items = api_Getinventorys(page_index, 2)
                        else
                            items = api_Getinventorys(page_index, 0)
                        end
                        
                        -- 检查是否可以合成
                        local can_synthesize = check_same_map_over_3(items)
                        
                        -- 如果背包已有足够地图且不需要合成
                        if check_map_in_bag(api_Getinventorys(1,0)) > 2 and d and not can_synthesize then
                            env.is_have_map = true
                            return bret.RUNNING
                        end
                        
                        -- 尝试从仓库取地图
                        local success = check_map_test(90, 0, 500, 0, 3)
                        if not success then
                            poe2_api.dbgp("仓库没有用户设置的地图钥匙")
                            self.times = (self.times or 0) + 1
                            
                            if self.times > 2 then
                                self.times = 0
                                if entry_length_take_map then
                                    env.map_up = true
                                else
                                    env.map_up = false
                                    env.is_shop = true
                                end
                            end
                            return bret.RUNNING
                        end
                        
                        -- 检查是否成功获取地图
                        if check_map_in_bag(api_Getinventorys(1,0)) > 2 then
                            env.is_have_map = true
                            return bret.RUNNING
                        end
                    end
                else
                    -- 已展开标签列表的情况
                    poe2_api.dbgp("已展开标签列表的情况")
                    local lock = poe2_api.get_game_control_by_rect({min_x = 549,min_y = 34,max_x = 584,max_y = 74})
                    
                    local lock_button = {}
                    for _,v in ipairs(lock) do
                        if v.name_utf8 == "" and v.text_utf8 == "" then
                            table.insert(lock_button,v)
                        end
                    end

                    if not lock_button or not next(lock_button) then
                        api_ClickScreen((tab_list_button.left+tab_list_button.right)/2,(tab_list_button.top+tab_list_button.bottom)/2,1)
                        api_Sleep(2000)
                        api_ClickScreen(((tab_list_button.left+tab_list_button.right)/2) + 30,((tab_list_button.top+tab_list_button.bottom)/2) - 30,1)
                        api_Sleep(1000)
                        return bret.RUNNING
                    else
                        -- 直接处理已展开的列表
                        poe2_api.dbgp("直接处理已展开的列表")
                        if is_need_strengthen and need_synthesis then
                            check_map_test(90, 0, 500, 0)
                            return bret.RUNNING
                        end
                        -- 尝试打开指定仓库页
                        poe2_api.dbgp("尝试打开指定仓库页", page)
                        if poe2_api.find_text({UI_info = env.UI_info, text = page, max_y = 469, min_x = 556, min_y = 20, max_x = 851, click = 2}) then
                            api_Sleep(1500)
                            
                            local repositoryPages
                            if text == "公會倉庫" then
                                repositoryPages = api_GetRepositoryPages(1)
                            else
                                repositoryPages = api_GetRepositoryPages(0)
                            end
                            
                            -- 获取页面索引
                            poe2_api.dbgp("获取页面索引")
                            local page_index = 0
                            for _, page in ipairs(repositoryPages) do
                                if page.name_utf8 == page and page.type ~= 5 then
                                    page_index = page.manage_index
                                    break
                                end
                            end
                            
                            -- 获取仓库物品
                            poe2_api.dbgp("获取仓库物品")
                            local items = nil
                            if text == "公會倉庫" then
                                items = api_Getinventorys(page_index, 2)
                            else
                                items = api_Getinventorys(page_index, 0)
                            end
                            
                            -- 检查是否可以合成
                            local can_synthesize = check_same_map_over_3(items)
                            
                            -- 如果背包已有足够地图且不需要合成
                            poe2_api.dbgp("如果背包已有足够地图且不需要合成")
                            if check_map_in_bag(api_Getinventorys(1,0)) > 2 and d and not can_synthesize then
                                env.is_have_map = true
                                return bret.RUNNING
                            end
                            
                            -- 尝试从仓库取地图
                            poe2_api.dbgp("尝试从仓库取地图")
                            local success = check_map_test(469, 556, 851, 20, 2)
                            if not success then
                                poe2_api.dbgp("仓库没有用户设置的地图钥匙")
                                self.times = (self.times or 0) + 1
                                
                                if self.times > 2 then
                                    self.times = 0
                                    if entry_length_take_map then
                                        env.map_up = true
                                    else
                                        env.map_up = false
                                        env.is_shop = true
                                    end
                                end
                                return bret.RUNNING
                            end
                            
                            -- 检查是否成功获取地图
                            if check_map_in_bag(api_Getinventorys(1,0)) > 2 then
                                env.is_have_map = true
                                return bret.RUNNING
                            end
                        end
                    end
                end
            end
            
            env.is_have_map = false
            poe2_api.dbgp("结束取地图 - 是否有地图:", env.is_have_map)
            return bret.RUNNING
        end
    },

    -- 可堆叠货币丢弃
    StackableCurrency_Discard = {
        run = function(self, env)
            poe2_api.print_log("丢弃可堆叠货币...")
            return bret.SUCCESS
        end
    },

    -- 鉴定指定装备
    Identify_designated_equipment = {
        run = function(self, env)
            
            local player_info = env.player_info
            local attack_dis_map = env.map_level_dis
            local stuck_monsters = env.stuck_monsters
            local not_attack_mos = env.not_attack_mos
            local config = env.user_config
            
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
                                            -- poe2_api.dbgp(string.format("[匹配成功] 配置详情:\n%s", poe2_api.table_to_string(item)))
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
                not_attack_mos = not_attack_mos
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
                        
                        if not poe2_api.find_text({UI_info = env.UI_info, text = "背包", min_x = 1000, min_y = 32, max_x = 1600, max_y = 81}) then
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
            return bret.SUCCESS
        end
    },

    -- 祭坛购买
    Shop_Sacrifice_Items = {
        run = function(self, env)
            poe2_api.print_log("祭祀購買...")
            if not self.init then
                self.init = true
                self.deferred_items = {}
            end
            local player_info = env.player_info
            local user_config = env.user_config
            local _get_valid_items = function(all_items, tribute)
                self.deferred_items = {}
                if not all_items or #all_items == 0 then
                    return {}, {}, 0, {}, {}, {}
                end
            
                local ritual_config = user_config['刷圖設置']['祭祀購買']
                if not ritual_config then
                    return {}, {}, 0, {}, {}, {}
                end
            
                -- 创建优先级字典，确保顺序与 ritual_config 一致
                local priority_dict = {}
                for idx, item in ipairs(ritual_config) do
                    priority_dict[item] = idx
                end
            
                -- 初始化物品分组
                local item_groups = {}
                for _, item_name in ipairs(ritual_config) do
                    item_groups[item_name] = {}
                end
            
                -- 分类物品
                local not_appeared_items = {}
                for _, item in ipairs(all_items) do
                    if item.baseType_utf8 and item_groups[item.baseType_utf8] then
                        table.insert(item_groups[item.baseType_utf8], item)
                    elseif item.baseType_utf8 == '隱藏道具' then
                        table.insert(not_appeared_items, item)
                    end
                end
            
                -- 按优先级排序物品
                local all_config_items = {}
                local all_config_items_no_price = {}
            
                -- 遍历 ritual_config 的顺序
                for _, item_name in ipairs(ritual_config) do
                    if item_groups[item_name] and #item_groups[item_name] > 0 then
                        -- 按价格排序（优先选择价格低的）
                        table.sort(item_groups[item_name], function(a, b)
                            local a_cost = a.totalDeferredConsumption or math.huge
                            local b_cost = b.totalDeferredConsumption or math.huge
                            if a_cost == b_cost then
                                -- 价格相同，则按 tribute（贡品值）排序
                                return (b.tribute or math.huge) < (a.tribute or math.huge)
                            else
                                return a_cost < b_cost
                            end
                        end)
            
                        -- 添加到 all_config_items
                        for _, item in ipairs(item_groups[item_name]) do
                            local condition1 = not item.totalDeferredConsumption or item.totalDeferredConsumption < tribute
                            local condition2 = not item.tribute or item.tribute < tribute
                            if condition1 or condition2 then
                                table.insert(all_config_items, item)
                            end
                        end
            
                        -- 添加到 all_config_items_no_price
                        for _, item in ipairs(item_groups[item_name]) do
                            if not item.tribute or (60000 > item.tribute and item.tribute > tribute) then
                                table.insert(all_config_items_no_price, item)
                            end
                        end
                    end
                end
            
                -- 打印所有存在的配置物品（按 ritual_config 顺序）
                local mapped_items = {}
                for _, item_name in ipairs(ritual_config) do
                    if item_groups[item_name] and #item_groups[item_name] > 0 then
                        table.insert(mapped_items, item_name)
                    end
                end
                poe2_api.dbgp("所有存在的配置物品: " .. table.concat(mapped_items, ", "))
            
                return all_config_items, all_config_items_no_price, not_appeared_items
            end

            if not poe2_api.click_text_UI({UI_info = env.UI_info, text = "ritual_open_shop_button"  }) then
                return bret.SUCCESS
            end
            
            local SacrificeItems = api_GetSacrificeItems()
            if not (0 < SacrificeItems.maxCount and SacrificeItems.maxCount < 10) or not (0 < SacrificeItems.finishedCount and SacrificeItems.finishedCount < 10) or #SacrificeItems.items == 0 then
                if poe2_api.click_text_UI({UI_info = env.UI_info, text = "ritual_open_shop_button"  ,click = 1 }) then
                    api_Sleep(500)
                    return bret.RUNNING
                end
                return bret.SUCCESS
            end
            
            local all_items, all_items_no_price, not_appeared_items = _get_valid_items(SacrificeItems.items, SacrificeItems.leftGifts)
            
            if SacrificeItems.MaxRefreshCount == SacrificeItems.CurrentRefreshCount and #all_items == 0 then
                env.buy_items =  false
                env.have_ritual = false
                env.not_more_ritual = false
                if poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物"  }) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物" , min_x = 0 , add_x = 272})
                    return bret.SUCCESS
                end
                return bret.SUCCESS
            end
            
            poe2_api.dbgp("祭坛总数:", SacrificeItems.maxCount, " 已完成数量:", SacrificeItems.finishedCount, " 当前贡礼:", SacrificeItems.leftGifts)
            poe2_api.dbgp("祭坛可刷新总数:", SacrificeItems.MaxRefreshCount, " 祭坛已刷新数:", SacrificeItems.CurrentRefreshCount)
            
            local life = player_info.remainingPortalCount
            poe2_api.dbgp("剩余重生机会:", life, "次")
            
            if #all_items == 0 then
                poe2_api.dbgp("没有可购买物品或者暂缓物品")
                if SacrificeItems.leftGifts > SacrificeItems.refreshCost and SacrificeItems.MaxRefreshCount > SacrificeItems.CurrentRefreshCount and #not_appeared_items == 0 then
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物" , min_x = 0}) then
                        env.buy_items = true
                        poe2_api.click_text_UI({UI_info = env.UI_info, text ="ritual_open_shop_button", click = 1})
                        api_Sleep(2000)
                        return bret.RUNNING
                    end
                    poe2_api.dbgp("第" .. SacrificeItems.CurrentRefreshCount .. "次刷新贡礼")
                    poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物" , click = 2 ,min_x = 0 , add_x = 203, add_y = 53})
                    api_Sleep(2000)
                    return bret.RUNNING
                end
                
                if poe2_api.find_text({UI_info = env.UI_info, text ="恩賜之物"}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物" , min_x = 0 , add_x = 272, click = 2})
                    env.buy_items =  false
                    return bret.SUCCESS
                end

                env.have_ritual = true
                env.buy_items =  false
                return bret.SUCCESS
            end
            
            if SacrificeItems.finishedCount < SacrificeItems.maxCount and #all_items_no_price > 0 and life >= 2 or not_appeared_items then
                env.have_ritual = true
                env.buy_items =  false
                if poe2_api.find_text({UI_info = env.UI_info, text ="恩賜之物"}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物" , min_x = 0 , add_x = 272})
                    env.buy_items =  false
                end
                return bret.SUCCESS
            else
                env.have_ritual = false
            end
            env.buy_items =  true
            if not poe2_api.find_text({UI_info = env.UI_info, text ="恩賜之物"}) then
                poe2_api.click_text_UI({UI_info = env.UI_info, text ="ritual_open_shop_button", click = 1})
                api_Sleep(1000)
                return bret.RUNNING
            end
            
            -- Buy affordable items
            local function buy_affordable(item)
                if not poe2_api.find_text({UI_info = env.UI_info, text = "暫緩道具"}) then
                    poe2_api.find_text({UI_info = env.UI_info, text ="取消", click = 2})
                    api_Sleep(1000)
                    return bret.RUNNING
                end
                
                poe2_api.dbgp("正在购买 " .. item.baseType_utf8)
                if poe2_api.ctrl_left_click_altar_items(item.obj, all_items) then
                    api_Sleep(500)
                end
            end
            
            -- Defer items
            local function deferred(item)
                if poe2_api.find_text({UI_info = env.UI_info, text = "暫緩道具"}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "暫緩道具", click = 2})
                    api_Sleep(1000)
                    return bret.RUNNING
                end
                
                if poe2_api.find_text({UI_info = env.UI_info, text = "確認"}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "恩賜之物"  ,click = 2 , min_x = 0 , add_x = 272})
                    api_Sleep(500)
                    return bret.RUNNING
                end
                
                poe2_api.dbgp("暫緩 " .. item.baseType_utf8)
                if poe2_api.ctrl_left_click_altar_items(item.obj, all_items, 2) then
                    api_Sleep(500)
                end

                poe2_api.find_text({UI_info = env.UI_info, text = "確認", click = 2, refresh = true})
            end
            
            if #all_items > 0 then
                for _, item in ipairs(all_items) do
                    SacrificeItems = api_GetSacrificeItems()
                    if item.tribute < SacrificeItems.leftGifts then
                        buy_affordable(item)
                        api_Sleep(500)
                        return bret.RUNNING
                    else
                        deferred(item)
                        api_Sleep(500)
                        return bret.RUNNING
                    end
                end
            end
            
            return bret.RUNNING
        end
    },

    -- 游戏保险箱
    Gameplay_Safe_Box = {
        run = function(self, env)
            poe2_api.print_log("访问游戏保险箱...")
            return bret.SUCCESS
        end
    },

    -- 躲避技能
    DodgeAction = {
        name = "躲避",
        run = function(self, env)
            local is_initialized  = false
            if not is_initialized then
                self.last_space_time = 0.0 -- 上次按下空格的时间
                self.space_cooldown = 1.5  -- 空格键冷却时间（秒）
                self.last_space_time1 = 0.0
                is_initialized = true
            end
            
            
            local _handle_space_action = function(monster, space_flag, space_monsters, space_time, player_info)
                -- 处理空格键操作
                if not space_time then
                    space_time = 1.5
                else
                    space_time = space_time / 1000
                end
                if space_flag and
                poe2_api.table_contains(space_monsters,monster.rarity) and
                api_GetTickCount64() - self.last_space_time >= space_time then
                    local result = api_GetNextCirclePosition(
                        monster.grid_x, monster.grid_y, 
                        player_info.grid_x, player_info.grid_y, 50,20,0
                    )
                    api_ClickMove(poe2_api.toInt(result.x), poe2_api.toInt(result.y), poe2_api.toInt(player_info.world_z), 0)
                    api_Sleep(200)
                    poe2_api.click_keyboard('space')
                    self.last_space_time = api_GetTickCount64() + (math.random(-5, 5)* 0.01)
                end
            end    
            local _handle_space_action_path_name = function(player_info, space_time)
                -- 处理空格键操作（添加20单位距离限制）
                space_time = space_time or 1.5
                if player_info.isInDangerArea then
                    local rct = api_GetSafeAreaLocation()
                    local ret = api_GetSafeAreaLocationNoMonsters(40)
                    if ret and ret.x ~= -1 and ret.y ~= -1 then
                        api_ClickMove(poe2_api.toInt(ret.x), poe2_api.toInt(ret.y) ,poe2_api.toInt(player_info.world_z), 0)
                        api_Sleep(200)
                        poe2_api.click_keyboard('space')
                        return true
                    else
                        local rct = api_GetSafeAreaLocation()
                        api_ClickMove(poe2_api.toInt(rct.x),poe2_api.toInt(rct.y),poe2_api.toInt(player_info.world_z), 0)
                        api_Sleep(200)
                        poe2_api.click_keyboard('space')
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
            local min_attack_range = env.min_attack_range or 60
            function has_common_element(t1, t2)
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
            if space then
                for _, monster in ipairs(monsters) do
                    dis = poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info)
                    if monster.life > 0 and monster.isActive and monster.type == 1 and dis and dis < min_attack_range and 
                    not monster.is_friendly then
                        if has_common_element(my_game_info.first_magicProperties, monster:GetObjectMagicProperties()) then
                            poe2_api.dbgp("特殊词缀怪物"..monster:GetObjectMagicProperties().."不闪避")
                            goto continue
                        end
                        _handle_space_action(monster, space, space_monster, space_time, player_info)
                    end
                    ::continue::
                end
            end
            
            _handle_space_action_path_name( player_info)
            return bret.SUCCESS
        end
    },

    -- 清理遮挡页面
    Game_Block = {
        run = function(self, env)
            poe2_api.print_log("游戏阻挡处理模块开始执行...")
            poe2_api.dbgp("=== 开始处理游戏阻挡 ===")
            
            local current_time = api_GetTickCount64()
            
            local player_info = env.player_info
            -- if player_info then
            --     return bret.SUCCESS
            -- end
            
            -- poe2_api.dbgp(string.format("当前时间戳: %d", current_time))
            -- poe2_api.dbgp(string.format("当前地图: %s", player_info.current_map_name_utf8 or "未知"))
            
            -- 检测地图启动失败情况
            if poe2_api.find_text({UI_info = env.UI_info, text = "啟動失敗。地圖無法進入。"}) then
                poe2_api.dbgp("检测到地图启动失败提示，设置need_SmallRetreat为true")
                env.need_SmallRetreat = true
                return bret.RUNNING
            end

            -- 定义所有需要检测的文本按钮及其参数
            local button_checks = {
                {UI_info = env.UI_info, text = "繼續遊戲", add_x = 0, add_y = 0, click = 2},
                {UI_info = env.UI_info, text = "寶石切割", add_x = 280, add_y = 17, click = 2},
                {UI_info = env.UI_info, text = "購買或販賣", add_x = 270, add_y = -9, click = 2},
                {UI_info = env.UI_info, text = "選擇藏身處", add_x = 516, click = 2},
                {UI_info = env.UI_info, text = "通貨交換", add_x = 300, click = 2},
                {UI_info = env.UI_info, text = "重組", add_x = 210, add_y = -50, click = 2},
                {UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", add_x = 240, min_x = 0, click = 2},
                {UI_info = env.UI_info, text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片", add_x = 160, add_y = -60, min_x = 0, click = 2},
                {UI_info = env.UI_info, text = "私訊", add_x = 265, min_x = 0, max_x = 400, click = 2},
                {UI_info = env.UI_info, text = "精選", add_x = 677, min_x = 0, add_y = 10, click = 2}
            }
            
            -- 检查单个按钮
            for _, check in ipairs(button_checks) do
                if poe2_api.find_text(check) then
                    poe2_api.dbgp(string.format("检测到按钮: %s，将执行点击操作", check.text))
                    return bret.RUNNING
                end
            end
            
            -- 检查顶部中间页面按钮
            local top_mid_page = {"傳送", "天賦技能", "世界地圖", "重置天賦點數", "Checkpoints"}
            if poe2_api.find_text({UI_info = env.UI_info, text = top_mid_page, min_x = 0, add_x = 215, click = 2}) then
                poe2_api.dbgp("检测到顶部中间页面按钮，将执行点击操作")
                return bret.RUNNING
            end
            
            -- 检查仓库页面
            local warehouse_page = {"倉庫","聖域鎖櫃","公會倉庫"}
            if poe2_api.find_text({UI_info = env.UI_info, text = small_page, min_x = 0, add_x = 253, min_x = 0}) and 
            poe2_api.find_text({UI_info = env.UI_info, text = "强調物品", min_x = 0, min_x = 0}) then
                poe2_api.dbgp("检测到仓库页面，将执行点击操作")
                poe2_api.find_text({UI_info = env.UI_info, text = small_page, min_x = 0, click = 2, add_x = 253, min_x = 0})
                return bret.RUNNING
            end
            
            
            -- 检查交易拒绝情况
            local refuse_click = {"等待玩家接受交易請求..."}
            if poe2_api.find_text({UI_info = env.UI_info, text = refuse_click, min_x = 0, add_x = 253, click = 2}) then
                poe2_api.dbgp("检测到交易请求等待，将执行拒绝操作")
                return bret.RUNNING
            end
            
            -- 检查背包保存提示
            local save_click = {"你無法將此背包丟置於此。請問要摧毀它嗎？"}
            if poe2_api.find_text({UI_info = env.UI_info, text = save_click, min_x = 0, click = 2}) then
                poe2_api.dbgp("检测到背包保存提示，将执行保留操作")
                return bret.RUNNING
            end

            
            -- 检查小页面按钮
            local small_page = {"背包","技能", "社交", "角色", "活動", "選項"}
            if poe2_api.find_text({UI_info = env.UI_info, text = small_page, min_x = 0, add_x = 253, min_x = 0, click = 2}) then
                poe2_api.dbgp("检测到小页面按钮，将执行点击操作")
                return bret.RUNNING
            end
            
            -- 藏身处特殊处理
            if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and map then
                poe2_api.dbgp("当前位于藏身处，开始处理背包物品")
                
                local item = api_Getinventorys(0xd,0)
                if item then
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

    -- 检查是否需要攻击
    Check_Is_Need_Attack = {
        run = function(self, env)
            poe2_api.print_log("检查是否需要攻击...")
            local player_info = env.player_info

            local is_active = true
            local not_sight = false
            
            if not player_info then
                poe2_api.dbgp("玩家信息不存在")
                return bret.RUNNING
            end
            
            if string.find(player_info.current_map_name_utf8, "Claimable") then
                is_active = false
                not_sight = true
            end
            -- 特殊怪物檢查

            local function spcify_monsters()
                local spcify_monsters_name_list = {"巨蛇女王．瑪娜莎"}
                for _, monster in ipairs(env.range_info) do
                    for _, name in ipairs(spcify_monsters_name_list) do
						if monster.name_utf8 == name then
							return true
						end
					end
                end
                return false
            end
            
            nomarl_monster = poe2_api.is_have_mos({range_info = env.range_info, player_info = player_info,is_active = is_active, not_sight = not_sight,stuck_monsters = env.stuck_monsters})

            Boss_monster = poe2_api.is_have_mos_boss(env.range_info, my_game_info.boss_name)

            if nomarl_monster or Boss_monster or spcify_monsters() then
                poe2_api.dbgp("需要攻击")
                return bret.SUCCESS
            else
                poe2_api.dbgp("不需要攻击")
                return bret.FAIL
            end
        end
    },

    -- 释放技能动作
    ReleaseSkillAction = {
        run = function(self, env)
            local current_time_ms = api_GetTickCount64()
            --- 辅助函数
            -- 根据稀有度获取可释放的技能
            local function _get_available_skills(monster_rarity)
                -- 根据怪物稀有度获取可用技能
                local current_time = api_GetTickCount64()
                local available_skills = {}

                for _, skill in ipairs(self.skills) do
                    local is_available = true
                    
                    -- 检查冷却
                    -- poe2_api.skp("current_time --> ",current_time)
                    -- poe2_api.skp("skill.name --> ",skill.name)
                    -- poe2_api.skp("self.skill_cooldowns[skill.name] --> ",self.skill_cooldowns[skill.name])
                    if current_time < (self.skill_cooldowns[skill.name] or 0) then
                        is_available = false
                    end
                    
                    -- 检查技能是否适合攻击该稀有度怪物
                    if is_available then
                        if monster_rarity == 3 then  -- Boss
                            if not skill.target_targets["Boss"] then
                                is_available = false
                            end
                        elseif monster_rarity == 2 then  -- 黄怪
                            if not skill.target_targets["黃怪"] then
                                is_available = false
                            end
                        elseif monster_rarity == 1 then  -- 蓝怪
                            if not skill.target_targets["藍怪"] then
                                is_available = false
                            end
                        elseif monster_rarity == 0 then  -- 白怪
                            if not skill.target_targets["白怪"] then
                                is_available = false
                            end
                        end
                    end
                    
                    if is_available then
                        table.insert(available_skills, skill)
                    end
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
                local current_time = api_GetTickCount64()
                
                -- 计算移动位置
                local move_x, move_y, move_z =  _calculate_movement(skill, monster, player_info)

                if not self.attack_last_time then
                    self.attack_last_time = api_GetTickCount64()
                end

                api_ClickMove(math.floor(move_x), math.floor(move_y), poe2_api.toInt(move_z), 0)
                
                -- 设置冷却时间
                local skill_start = api_GetTickCount64()
                local base_cd = skill.interval
                local actual_cd = (math.max(base_cd * (0.9 + math.random() * 0.2), 0.1)) * 1000
                self.skill_cooldowns[skill.name] = skill_start + actual_cd
                
                -- 释放技能
                poe2_api.click_keyboard(skill.key)
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
            if not self.skills then
                poe2_api.dbgp("加载技能设置...")
                self.stuck_monsters = {}
                
                parse_skill_config()
                return bret.RUNNING
            end

            local valid_monsters = nil
            
            -- 怪物筛选和处理逻辑
            for _, monster in ipairs(env.range_info) do
                -- if monster.name_utf8 == "" then
                --     goto continue
                -- end
                -- poe2_api.dbgp("monster ------------------------------------------------------->")
                -- poe2_api.dbgp("monster name -->" ,monster.name_utf8)
                -- poe2_api.dbgp("obj: " .. tostring(string.format("%x",monster.obj)))
                -- poe2_api.dbgp("monster -->" ,monster.life)
                -- local a = monster
                -- poe2_api.print_log("a monster ------------------------------------------------------->")
                -- poe2_api.print_log("a monster name -->" ,a.name_utf8)
                -- poe2_api.print_log("a obj: " .. tostring(string.format("%x",a.obj)))
                -- poe2_api.print_log("a monster -->" ,a.life)

                -- 快速失败条件检查（按计算成本从低到高排序）
                if monster.type ~= 1 or                  -- 类型检查
                not monster.is_selectable or          -- 可选性检查
                monster.is_friendly or                -- 友方检查
                monster.life <= 0 or                  -- 生命值检查
                monster.name_utf8 == "" or              -- 名称检查
                poe2_api.table_contains(my_game_info.not_attact_mons_CN_name, monster.name_utf8) or
                poe2_api.table_contains(my_game_info.not_attact_mons_path_name , monster.path_name_utf8) then  -- 路径名检查
                    goto continue
                end

                if self.stuck_monsters and poe2_api.table_contains(self.stuck_monsters, monster.id) then
                    goto continue
                end

                -- 是否激活
                if not string.find(player_info.current_map_name_utf8 or "", "Claimable") and not monster.isActive then
                    goto continue
                end

                -- 稀有度检查
                if env.not_attack_mos and env.not_attack_mos[monster.rarity] then
                    goto continue
                end

                -- 检查是否在中心点半径范围内
                if #env.center_point > 0 and env.center_radius > 0 then
                    local distance_to_center = math.sqrt(
                        (monster.grid_x - env.center_point[1])^2 + 
                        (monster.grid_y - env.center_point[2])^2
                    )
                    if distance_to_center > env.center_radius then
                        goto continue  -- 超出范围则跳过
                    end
                end
                
                -- 计算距离平方
                local distance_sq = poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info)
                -- poe2_api.dbgp("当前怪物：" .. monster.name_utf8 .. "，距离：" .. distance_sq .. "米")

                if not player_info.isInBossBattle and monster.rarity ~= 3 and not string.find(player_info.current_map_name_utf8 or "", "Claimable") then
                    if monster.hasLineOfSight and distance_sq < nearest_distance_sq then
                        nearest_distance_sq = distance_sq
                        valid_monsters = monster

                    end
                else
                    if distance_sq < nearest_distance_sq then
                        nearest_distance_sq = distance_sq
                        valid_monsters = monster
                    end
                end
                ::continue::
            end

            if valid_monsters then
                env.valid_monsters = valid_monsters

                -- 获取当前目标ID
                local current_target_id = valid_monsters and valid_monsters.id or nil
                poe2_api.dbgp("a valid_monsters ------------------------------------------------------->")
                poe2_api.dbgp("a valid_monsters name -->" ,valid_monsters.name_utf8)
                poe2_api.dbgp("a valid_monsters: " .. tostring(string.format("%x",valid_monsters.obj)))
                poe2_api.dbgp("a valid_monsters -->" ,valid_monsters.life)


                if not (#env.center_point > 0 and env.center_radius > 0) then
                    -- 第二次遍历进行卡住检测和其他处理
                    for _, monster in ipairs(env.range_info) do
                        local current_time = api_GetTickCount64()
                        
                        -- 快速失败条件检查
                        if monster.type ~= 1 or 
                        not monster.is_selectable or 
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
                        
                        -- 基础状态检查
                        if not (monster.life > 0 and monster.isActive) then
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
                            local time_thresholds = {30, 45, 120, 180}
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

                -- 更新黑板数据
                if self.stuck_monsters then
                    env.stuck_monsters = self.stuck_monsters
                    poe2_api.printTable(self.stuck_monsters)
                end

                -- 计算距离
                local distance = math.sqrt((valid_monsters.grid_x - player_info.grid_x)^2 + 
                                        (valid_monsters.grid_y - player_info.grid_y)^2)

                poe2_api.dbgp("++++++++++++++++++++++++++++++++++")
                poe2_api.dbgp(string.format("攻击 %s(稀有度:%d) | 距离: %.1f",valid_monsters.name_utf8 or "未知怪物", valid_monsters.rarity or 0, distance))
                -- poe2_api.dbgp("is_friendly: " .. tostring(valid_monsters.is_friendly))
                -- poe2_api.dbgp("hasLineOfSight: " .. tostring(valid_monsters.hasLineOfSight))
                -- poe2_api.dbgp("isActive: " .. tostring(valid_monsters.isActive))
                -- poe2_api.dbgp("rarity: " .. tostring(valid_monsters.rarity))
                -- poe2_api.dbgp("path_name_utf8: " .. tostring(valid_monsters.path_name_utf8))
                poe2_api.dbgp("obj: " .. tostring(string.format("%x",valid_monsters.obj)))
                -- poe2_api.dbgp("stateMachineList: " .. tostring(valid_monsters:GetStateMachineList()))
                -- poe2_api.dbgp("magicProperties: " .. tostring(valid_monsters:GetObjectMagicProperties()))
                poe2_api.dbgp("血量：" .. valid_monsters.life )
                poe2_api.print_log("type --> " .. type(valid_monsters))
                poe2_api.dbgp("++++++++++++++++++++++++++++++++++")
                
                -- 特殊Boss处理
                local special_bosses = {'巨蛇女王．瑪娜莎', '被遺忘的囚犯．帕拉薩'}
                if poe2_api.table_contains(valid_monsters.name_utf8, special_bosses) and distance > 50 and not valid_monsters.isActive then
                    poe2_api.dbgp("special_bosses,或者未激活")
                    _handle_special_boss_movement(valid_monsters, player_info)
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
                        -- 检查特殊词缀
                        local has_special_property = false
                        for _, prop in ipairs(my_game_info.first_magicProperties or {}) do
                            if poe2_api.table_contains(valid_monsters:GetObjectMagicProperties() or {}, prop) then
                                has_special_property = true
                                break
                            end
                        end
                        
                        if has_special_property then
                            poe2_api.dbgp("特殊词缀怪物,或者未激活")
                            env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                            return bret.FAIL
                        end
                    end
                    
                    if valid_monsters.name_utf8 ~= "骨之暴君．札瓦里" then
                        if distance > selected_skill.attack_range and distance > min_attack_range or not valid_monsters.isActive then
                            poe2_api.dbgp("移动到目标附近")
                            -- 拾取不移动
                            if need_item and not env.center_point and not center_radius then
                                return bret.SUCCESS
                            end
                            
                            env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                            return bret.FAIL
                        end
                    else
                        if distance > 80 then
                            env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                            return bret.FAIL
                        end
                    end
                    
                    _execute_skill(selected_skill, valid_monsters, player_info)
                    poe2_api.dbgp("技能序号",  selected_skill)
                end
                return bret.RUNNING
            end

            poe2_api.time_p("ReleaseSkillAction 耗时 --> ", api_GetTickCount64() - current_time_ms)
            return bret.SUCCESS
        end
    },

    -- 检查是否到达点
    Is_Arrive_Point = {
        run = function(self, env)
            poe2_api.print_log("检查是否到达目标点...")
            return bret.SUCCESS
        end
    },

    -- 进入异界地图节点
    Enter_Map = {
        name = "进入异界地图",
        run = function(self, env)
            local current_time = api_GetTickCount64()
            
            local player_info = env.player_info
            local is_map_complete = env.is_map_complete
            local one_other_map = env.one_other_map
            local not_enter_map = env.not_enter_map
            local click_counter = env.enter_map_click_counter or 0
            local error_other_map = env.error_other_map or {}
            local click_grid_pos = env.click_grid_pos
            
            
            -- 检查加载中状态
            if poe2_api.click_text_UI({UI_info = env.UI_info, text = "loading_screen_tip_label"}) then
                return bret.RUNNING
            end

            if poe2_api.find_text({UI_info = env.UI_info, text = "重組", add_x = 240, click = 2}) then
                return bret.RUNNING
            end
            
            -- 获取符合条件的非地图物品（传送点/异界之门除外）
            local function get_not_map(num)
                num = num or 1
                local valid_items = {}
                
                for _, item in ipairs(env.range_info) do
                    if item.type == 5 and item.name_utf8 ~= '' and item.name_utf8 ~= "傳送點" and item.name_utf8 ~= '異界之門' then
                        table.insert(valid_items, item)
                    end
                end
                
                -- 检查是否达到阈值数量
                if #valid_items < num then
                    return false
                end
                
                -- 按距离排序，返回最近的物品
                if #valid_items > 0 then
                    table.sort(valid_items, function(a, b)
                        a_dis = poe2_api.point_distance(a.grid_x, a.grid_y, player_info)
                        b_dis = poe2_api.point_distance(b.grid_x, b.grid_y, player_info)
                        if a_dis and b_dis then
                            return a_dis < b_dis
                        else
                            return false
                        end
                    end)
                    
                    -- -- 打印排序后的结果（调试用）
                    -- for i, item in ipairs(valid_items) do
                    --     local distance = poe2_api.point_distance(item.grid_x, item.grid_y, player_info)
                    --     poe2_api.dbgp(string.format("[DEBUG] #%d: %s 距离=%.2f", i, item.name_utf8, distance))
                    -- end
                    
                    return valid_items[1]
                end
                
                return false
            end
            
            -- 点击计数器检查
            if click_counter >= 5 then
                env.is_map_complete = true
                env.one_other_map = nil
                env.enter_map_click_counter = 0
                
                return bret.FAIL
            end
            
            -- 错误文本检查
            local error_text = {"錯誤：無法進入，原因：伺服器斷線。", "錯誤：無法進入。", "啟動失敗。地圖無法進入。"}
            for _, k in ipairs(error_text) do
                if poe2_api.find_text({UI_info = env.UI_info, text = k, min_x = 0}) then
                    if one_other_map then
                        table.insert(error_other_map, one_other_map)
                    end
                    env.one_other_map = nil
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "/clear", min_x = 0}) then
                        api_Sleep(1000)
                        poe2_api.click_keyboard("enter")
                        api_Sleep(500)
                        poe2_api.paste_text("/clear")
                        api_Sleep(500)
                        poe2_api.click_keyboard("enter")
                        api_Sleep(500)
                        self.bool = true
                        
                        return bret.RUNNING
                    end
                end
            end
            
            -- 检查是否在藏身处
            if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                -- poe2_api.dbgp("Enter_Map:is_map_complete ==> " .. tostring(is_map_complete))
                -- poe2_api.dbgp("Enter_Map:one_other_map ==> " .. (one_other_map and one_other_map.name_cn_utf8 or "nil"))
                
                if env.range_info then
                    local items = get_not_map()
                    
                    if items and not one_other_map and not is_map_complete and not poe2_api.table_contains({items.name_utf8}, not_enter_map) then
                        -- poe2_api.dbgp("items: " .. items.name_utf8)

                        
                        if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) or 
                        poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0}) then
                            poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0, click = 2, add_x = 216})
                            env.click_grid_pos = true
                            
                            return bret.RUNNING
                        end

                        dis = poe2_api.point_distance(items.grid_x, items.grid_y, player_info)
                        if dis and dis > 30 then
                            env.is_map_complete = false
                            env.end_point = {items.grid_x, items.grid_y}
                            return bret.SUCCESS
                        else
                            if env.target_point then
                                api_ClickMove(poe2_api.toInt(player_info.grid_x), poe2_api.toInt(player_info.grid_y),poe2_api.toInt(player_info.world_z), 9)
                            end
                            
                            env.enter_map_click_counter = click_counter + 1
                            if click_grid_pos then
                                api_ClickMove(poe2_api.toInt(items.grid_x), poe2_api.toInt(items.grid_y), poe2_api.toInt(items.world_z - 100), 1)
                                api_Sleep(1000)
                                return bret.RUNNING
                            end
                            
                            if player_info.isMoving then
                                poe2_api.dbgp("等待静止")
                                api_Sleep(1000)
                                return bret.RUNNING
                            end

                            poe2_api.find_text({UI_info = env.UI_info, text = items.name_utf8, click = 2, sorted = true})

                            api_Sleep(1000)
                            if not poe2_api.find_text({UI_info = env.UI_info, text = items.name_utf8, click = 2}) then
                                api_ClickMove(poe2_api.toInt(items.grid_x), poe2_api.toInt(items.grid_y), poe2_api.toInt(items.world_z - 100), 1)
                                api_Sleep(1000)
                            end
                            
                            return bret.RUNNING
                        end
                    end
                    
                    local not_map = get_not_map()
                    if one_other_map and not_map and not is_map_complete and not_map.name_utf8 == one_other_map.name_cn_utf8 and 
                    not poe2_api.table_contains({one_other_map.name_cn_utf8}, not_enter_map) then
                        poe2_api.dbgp("not_map: " .. not_map.name_utf8)

                        if not poe2_api.find_text({UI_info = env.UI_info, text = one_other_map.name_cn_utf8, min_x = 0}) and 
                        poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) then
                            poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0, click = 2, add_x = 216})
                            env.click_grid_pos = true
                            
                            return bret.RUNNING
                        end
                        
                        -- 记录地图开始时间和名称
                        env.map_start_time = api_GetTickCount64()
                        env.map_name = one_other_map.name_cn_utf8
                        env.map_recorded = false
                        
                        if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) or 
                        poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0}) then
                            poe2_api.click_position(1013, 25)
                            return bret.RUNNING
                        end
                        
                        dis = poe2_api.point_distance(not_map.grid_x, not_map.grid_y, player_info)
                        if dis and dis > 30 then
                            env.is_map_complete = false
                            env.end_point = {not_map.grid_x, not_map.grid_y}
                            
                            return bret.SUCCESS
                        else
                            if env.target_point then
                                api_ClickMove(poe2_api.toInt(player_info.grid_x), poe2_api.toInt(player_info.grid_y),poe2_api.toInt(player_info.world_z), 9)
                            end

                            env.enter_map_click_counter = click_counter + 1
                            if click_grid_pos then
                                api_ClickMove(poe2_api.toInt(not_map.grid_x), poe2_api.toInt(not_map.grid_y), poe2_api.toInt(not_map.world_z - 100), 1)
                                api_Sleep(1000)
                                
                                return bret.RUNNING
                            end
                            if player_info.isMoving then
                                poe2_api.dbgp("等待静止")
                                api_Sleep(1000)
                                return bret.RUNNING
                            end
                            
                            poe2_api.find_text({UI_info = env.UI_info, text = not_map.name_utf8, click = 2, sort = true})

                            api_Sleep(1000)
                            if not poe2_api.find_text({UI_info = env.UI_info, text = not_map.name_utf8, click = 2}) then
                                api_ClickMove(poe2_api.toInt(not_map.grid_x), poe2_api.toInt(not_map.grid_y), poe2_api.toInt(not_map.world_z - 100), 1)
                                api_Sleep(1000)
                            end
                            
                            return bret.RUNNING
                        end
                    end
                end
            end
            return bret.FAIL
        end
    },

    -- 放置异界地图节点
    Put_Map_In_Otherworld = {
        run = function(self, env)
            poe2_api.print_log("放置异界地图节点...")
            if not self.last_action_time then
                self.last_action_time = 0  -- 记录上次操作时间
                self.action_interval = 1  -- 操作间隔时间
                self.open_num = 0          -- 操作计数器
                self.add_num = 1           -- 方向计数器
                self.origin_point = {}    -- 原点坐标
                self.expansion_step = 1    -- 扩张步数
                self.spiral_round = 0      -- 螺线圈数
            end

            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            local otherworld_info = api_GetEndgameMapNodes()
            if not otherworld_info then
                poe2_api.dbgp("未找到异界地图节点信息")
                return bret.RUNNING
            end
            local one_other_map = env.one_other_map
            local bag_info = env.bag_info
            local user_map = env.user_map
            local not_use_map = env.not_use_map
            local sorted_map = env.sorted_map
            local not_enter_map = env.not_enter_map
            local priority_map = env.priority_map
            local error_other_map = env.error_other_map or {}
            local not_have_stackableCurrency = env.not_have_stackableCurrency
            local not_attack_mos = nil
            local entry_length = 0
            local color = 0
            
            -- 检查加载中状态
            if poe2_api.click_text_UI({UI_info = env.UI_info, text = "loading_screen_tip_label"}) then
                return bret.RUNNING
            end
            
            if not player_info then
                
                return bret.RUNNING
            end
            
            if not poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) then
                
                return bret.FAIL
            end
            
            -- 检查背包中的地图
            local function check_map_in_bag(bag_info, return_count)
                return_count = return_count or true
                local matches = {}
                
                if bag_info then
                    for _, item in ipairs(bag_info) do
                        if item.baseType_utf8 and string.find(item.baseType_utf8, "地圖鑰匙") then
                            table.insert(matches, item)
                        end
                    end
                end
                
                if return_count then
                    return #matches > 0 and #matches or false
                else
                    return #matches > 0 and matches or false
                end
            end
            
            if current_time - self.last_action_time >= self.action_interval then
                if otherworld_info == nil or #otherworld_info == 0 then
                    
                    return bret.RUNNING
                end
                
                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and 
                poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) then
                    
                    if not one_other_map or (not one_other_map.isMapAccessible and one_other_map.isCompleted) then
                        -- 获取地图信息
                        local map_info = poe2_api.get_map(
                            {otherworld_info = otherworld_info, sorted_map = sorted_map, not_enter_map = not_enter_map, bag_info = bag_info, 
                            key_level_threshold = user_map, not_use_map = not_use_map, 
                            priority_map = priority_map, error_other_map = error_other_map, 
                            not_have_stackableCurrency = not_have_stackableCurrency}
                        )
                        
                        if map_info then
                            poe2_api.dbgp("map_info.name_utf8: " .. map_info.name_cn_utf8)
                            poe2_api.dbgp("map_info.mapPlayModes: " .. tostring(map_info.mapPlayModes))
                        end
                        
                        if not map_info then
                            local point = api_GetEndgameMapNodes
                            if point then
                                if not self.origin_point then
                                    self.origin_point = {point[1], point[2]}
                                end
                                
                                -- 计算动态扩张因子
                                local dynamic_factor = 1 + (self.spiral_round * 0.2)
                                
                                -- 计算当前扩张距离
                                local base_offset = math.floor(4000 * self.expansion_step * dynamic_factor)
                                local diagonal_offset = math.floor(2000 * self.expansion_step * dynamic_factor)
                                
                                -- 定义四个方向的偏移
                                local move_directions = {
                                    {self.origin_point[1] + base_offset, self.origin_point[2] + base_offset},      -- 右上
                                    {self.origin_point[1] - base_offset, self.origin_point[2] + diagonal_offset},  -- 左上
                                    {self.origin_point[1] - base_offset, self.origin_point[2] - base_offset},      -- 左下
                                    {self.origin_point[1] + base_offset, self.origin_point[2] - diagonal_offset}   -- 右下
                                }
                                
                                -- 获取目标位置
                                local target_x, target_y = move_directions[self.add_num][1], move_directions[self.add_num][2]
                                
                                -- 执行移动
                                api_EndgameNodeMove(target_x, target_y)
                                
                                -- 更新方向和扩张参数
                                self.add_num = (self.add_num % 4) + 1
                                if self.add_num == 1 then
                                    self.expansion_step = self.expansion_step + 1
                                    self.spiral_round = self.spiral_round + 1
                                end
                                
                                poe2_api.dbgp("等待地图加载 (5s)")
                                api_Sleep(5000)
                            end
                            return bret.RUNNING
                        else
                            self.add_num = 1
                            self.expansion_step = 1
                            self.spiral_round = 0
                            self.origin_point = nil
                        end
                        
                        entry_length = 0
                        local vall = false
                        if map_info and map_info.mapPlayModes and poe2_api.table_contains(map_info.mapPlayModes, "腐化聖域") then
                            entry_length = 4
                            color = 2
                            vall = true
                        end
                        
                        local map_level = poe2_api.select_best_map_key({bag_info = bag_info,
                            key_level_threshold = user_map, not_use_map = not_use_map, priority_map = priority_map, color = color, entry_length = entry_length, vall = vall})
                        
                        if entry_length > 0 and map_level then
                            if entry_length > map_level.fixedSuffixCount then
                                env.entry_length_take_map = true
                                env.the_update_map = map_level
                                env.map_update_to = entry_length
                                env.map_up = true
                                return bret.RUNNING
                            else
                                env.entry_length_take_map = false
                                env.the_update_map = nil
                                env.map_update_to = 0
                                env.map_up = false
                            end
                        end
                        
                        if map_info then
                            api_EndgameNodeMove(map_info.position_x - 1900, map_info.position_y - 1900)
                            env.one_other_map = map_info
                            api_Sleep(1000)
                            
                            return bret.RUNNING
                        else
                            
                            return bret.RUNNING
                        end
                    end
                    
                    if one_other_map then
                        if poe2_api.find_text({UI_info = env.UI_info, text = "地區"}) and 
                        poe2_api.find_text({UI_info = env.UI_info, text = "私訊"}) and 
                        poe2_api.find_text({UI_info = env.UI_info, text = "公會"}) then
                            poe2_api.click_keyboard('esc')
                        end
                        
                        if type(one_other_map) == "boolean" then
                            self.last_action_time = current_time
                            
                            return bret.RUNNING
                        end
                        
                        if one_other_map.name_utf8 and not poe2_api.table_contains(my_game_info.trash_map, one_other_map.name_utf8) and 
                        one_other_map.isMapAccessible and not one_other_map.isCompleted then
                            
                            if not poe2_api.find_text({UI_info = env.UI_info, text = "穿越", min_x = 0}) then
                                if self.open_num > 5 and poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", max_y = 100, min_x = 0}) then
                                    poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", max_y = 100, min_x = 0, click = 2, add_x = 212})
                                    table.insert(error_other_map, one_other_map)
                                    env.one_other_map = nil
                                    api_Sleep(1000)
                                    self.open_num = 0
                                    
                                    return bret.RUNNING
                                end
                                
                                api_EndgameNodeMove(one_other_map.position_x - 1900, one_other_map.position_y - 1900)
                                api_Sleep(200)
                                
                                local one_other_map_refresh = api_GetEndgameMapNodes()
                                local window_client_x
                                local window_client_y
                                if one_other_map_refresh then
                                    for _, k1 in ipairs(one_other_map_refresh) do
                                        if k1.name_utf8 == one_other_map.name_utf8 and 
                                        k1.index_x == one_other_map.index_x and 
                                        k1.index_y == one_other_map.index_y then
                                            if k1.window_client_x == 0 or k1.window_client_y == 0 then
                                                env.need_SmallRetreat = true
                                                
                                                return bret.RUNNING
                                            end
                                            api_ClickScreen(k1.window_client_x, k1.window_client_y,0)
                                            window_client_x = k1.window_client_x
                                            window_client_y = k1.window_client_y
                                            api_Sleep(500)
                                        end
                                    end
                                end
                                
                                if poe2_api.find_text({UI_info = env.UI_info, text = one_other_map.name_cn_utf8, min_x = 0}) then
                                    api_ClickScreen(window_client_x, window_client_y,1)
                                    api_Sleep(500)
                                    api_EndgameNodeMove(one_other_map.position_x - 3900, one_other_map.position_y - 3900)
                                end
                                
                                self.last_action_time = current_time
                                self.open_num = self.open_num + 1
                                api_Sleep(100)
                                
                                return bret.RUNNING
                            end
                            
                            if not poe2_api.find_text({UI_info = env.UI_info, text = "背包"}) then
                                poe2_api.click_keyboard('i')
                                self.last_action_time = current_time
                                
                                return bret.RUNNING
                            end
                            
                            local k = poe2_api.find_text({UI_info = env.UI_info, text = "穿越", min_x = 0, position = 2})
                            if poe2_api.find_text({UI_info = env.UI_info, text = "背包"}) and k then
                                if k.text_utf8 == '穿越' then
                                    local center_x = math.floor((k.left + k.right) / 2)
                                    local center_y = math.floor((k.top + k.bottom) / 2)
                                    local count = api_Getinventorys(0xe,0)
                                    
                                    if count then
                                        entry_length = 0
                                        local map_level = nil
                                        local vall = false
                                        
                                        if one_other_map and one_other_map.mapPlayModes and 
                                        poe2_api.table_contains(one_other_map.mapPlayModes, "腐化聖域") then
                                            entry_length = 4
                                            vall = true
                                        end
                                    
                                        map_level = poe2_api.select_best_map_key(
                                            {count = count, inventory = bag_info, 
                                            key_level_threshold = user_map, not_use_map = not_use_map, 
                                            priority_map = priority_map, color = color, vall = vall}
                                        )
                                        
                                        if map_level and (#count > 1 or (entry_length > 0 and entry_length > map_level.fixedSuffixCount)) then
                                            for _, k in ipairs(count) do
                                                poe2_api.dbgp("22222")
                                                poe2_api.select_best_map_key(
                                                    {inventory = api_Getinventorys(0xe,0), index = 1, click = 1, 
                                                    type = 3, START_X = center_x - 47, START_Y = center_y - 125}
                                                )
                                                api_Sleep(500)
                                            end
                                            
                                            return bret.RUNNING
                                        elseif count and #count == 1 then
                                            need_put = false
                                        else
                                            need_put = true
                                        end
                                    end
                                end
                            end
                            
                            if need_put then
                                if not check_map_in_bag(bag_info) then
                                    if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", max_y = 100, min_x = 250}) then
                                        poe2_api.click_keyboard('space')
                                    end
                                    
                                    return bret.SUCCESS
                                end
                                
                                entry_length = 0
                                local vall = false
                                if one_other_map and one_other_map.mapPlayModes and 
                                poe2_api.table_contains(one_other_map.mapPlayModes, "腐化聖域") then
                                    entry_length = 4
                                    color = 2
                                    vall = true
                                end
                                
                                local map_level = poe2_api.select_best_map_key(
                                    {inventory = bag_info, 
                                    key_level_threshold = user_map, not_use_map = not_use_map, 
                                    priority_map = priority_map, color = color, vall = vall}
                                )
                                
                                if entry_length > 0 and map_level then
                                    if entry_length > map_level.fixedSuffixCount then
                                        env.entry_length_take_map = true
                                        env.the_update_map = map_level
                                        env.map_update_to = entry_length
                                        env.map_up = true
                                        return bret.RUNNING
                                    else
                                        env.entry_length_take_map = false
                                        env.the_update_map = nil
                                        env.map_update_to = 0
                                        env.map_up = false
                                    end
                                end

                                map_level = poe2_api.select_best_map_key(
                                    {inventory = bag_info, 
                                    click = 1, key_level_threshold = user_map, not_use_map = not_use_map, 
                                    priority_map = priority_map, entry_length = entry_length}
                                )

                                poe2_api.dbgp("map_level",map_level)

                                if map_level then
                                    local attack_distance = nil
                                    not_attack_mos = {}
                                    for _, config in ipairs(user_map) do
                                        if config["階級"] == map_level then
                                            attack_distance = config["搜怪距離"] or 100
                                            
                                            if config["不打Boss"] then
                                                table.insert(not_attack_mos, 3)
                                            end
                                            if config["不打黃怪"] then
                                                table.insert(not_attack_mos, 2)
                                            end
                                            if config["不打藍怪"] then
                                                table.insert(not_attack_mos, 1)
                                            end
                                            if config["不打白怪"] then
                                                table.insert(not_attack_mos, 0)
                                            end
                                            
                                            break
                                        end
                                    end
                                    env.map_level_dis = attack_distance
                                    if #not_attack_mos > 0 then
                                        table.sort(not_attack_mos)
                                        env.not_attack_mos = not_attack_mos
                                    else
                                        env.not_attack_mos = not_attack_mos
                                    end
                                else
                                    poe2_api.dbgp("背包没有合适的地图钥匙")
                                    env.map_level_dis = nil
                                    env.is_have_map = false
                                end
                                poe2_api.dbgp("2222222")
                                api_Sleep(500)
                                
                                return bret.RUNNING
                            else
                                local maps = api_Getinventorys(0xe,0)
                                if maps and #maps > 0 then
                                    poe2_api.dbgp("len(maps): " .. #maps)
                                    local map_level = poe2_api.extract_key_level(maps[1].baseType_utf8)
                                    
                                    local attack_distance = nil
                                    not_attack_mos = {}
                                    
                                    for _, config in ipairs(user_map) do
                                        if config["階級"] == map_level then
                                            attack_distance = config["搜怪距離"]
                                            
                                            if config["不打Boss"] then
                                                table.insert(not_attack_mos, 3)
                                            end
                                            if config["不打黃怪"] then
                                                table.insert(not_attack_mos, 2)
                                            end
                                            if config["不打藍怪"] then
                                                table.insert(not_attack_mos, 1)
                                            end
                                            if config["不打白怪"] then
                                                table.insert(not_attack_mos, 0)
                                            end
                                            
                                            break
                                        end
                                    end
                                    
                                    if attack_distance == nil then
                                        attack_distance = 100
                                    end
                                    
                                    env.map_level_dis = attack_distance
                                    env.not_attack_mos = not_attack_mos
                                    
                                    if maps and entry_length > 0 then
                                        local suffx = api_GetObjectSuffix(maps[1].mods_obj)
                                        if suffx and #suffx < entry_length then
                                            poe2_api.select_best_map_key(
                                                {inventory = api_Getinventorys(0xe,0), index = 1, 
                                                click = 1, type = 3, START_X = center_x - 47, START_Y = center_y - 125}
                                            )
                                            env.one_other_map = nil
                                            env.map_level_dis = nil
                                            
                                            return bret.RUNNING
                                        end
                                    end
                                    
                                    if poe2_api.find_text({UI_info = env.UI_info, text = "穿越", click = 2, min_x = 0}) then
                                        env.click_traverse = true
                                        poe2_api.dbgp("点击穿越成功")
                                        env.is_map_complete = false
                                        self.open_num = 0
                                        api_Sleep(3000)
                                        
                                        return bret.SUCCESS
                                    else
                                        env.one_other_map = nil
                                        env.map_level_dis = nil
                                        env.click_traverse = false
                                        
                                        return bret.RUNNING
                                    end
                                end
                            end
                        end
                    end
                    
                    
                    return bret.RUNNING
                end
            else
                
                return bret.RUNNING
            end
        end
    },

    -- 清除所有遮挡物节点
    Clear_All_Page = {
        run = function(self, env)
            poe2_api.print_log('清除遮挡物...')
            if not self.last_action_time then
                self.last_action_time = 0  -- 记录上次操作时间
                self.action_interval = 1.5 -- 操作间隔时间
                self.wait_num = 0          -- 等待计数器
            end

            local current_time = api_GetTickCount64()
            
            local one_other_map = env.one_other_map
            
            local click_traverse = env.click_traverse
            local error_other_map = env.error_other_map or {}
            
            if not click_traverse then
                env.one_other_map = nil
                env.is_map_complete = true
                
                return bret.RUNNING
            end

            if not one_other_map then
                return bret.RUNNING
            end
            
            -- 获取非地图物品（传送点/异界之门除外）
            local function get_not_map()
                for _, item in ipairs(env.range_info) do
                    if item.type == 5 and item.name_utf8 ~= '' and 
                    item.name_utf8 ~= "傳送點" and item.name_utf8 ~= '異界之門' then
                        return item
                    end
                end
                return false
            end
            
            local not_map = get_not_map()
            
            if one_other_map then
                local error_text = {
                    "錯誤：無法進入，原因：伺服器斷線。",
                    "錯誤：無法進入。",
                    "啟動失敗。地圖無法進入。"
                }
                
                for _, k in ipairs(error_text) do
                    if poe2_api.find_text({UI_info = env.UI_info, text = k, min_x = 0}) then
                        table.insert(error_other_map, one_other_map)
                        env.one_other_map = nil
                        env.is_map_complete = true
                        
                        if not poe2_api.find_text({UI_info = env.UI_info, text = "/clear", min_x = 0}) then
                            poe2_api.click_keyboard("enter")
                            api_Sleep(500)
                            poe2_api.paste_text("/clear")
                            api_Sleep(500)
                            poe2_api.click_keyboard("enter")
                            api_Sleep(1000)
                            self.bool = true
                            
                            return bret.RUNNING
                        end
                    end
                end
                
                env.enter_map_click_counter = 0
                env.is_map_complete = false
                
                if self.wait_num > 3 then
                    if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", max_y = 100, min_x = 250}) then
                        poe2_api.click_position(1013, 25)
                    end
                    
                    return bret.RUNNING
                end
                
                if not_map and not_map.name_utf8 ~= one_other_map.name_cn_utf8 then
                    api_Sleep(3000)
                    
                    return bret.RUNNING
                end
                
                if not poe2_api.find_text({UI_info = env.UI_info, text = one_other_map.name_cn_utf8, min_x = 0}) then
                    if poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", max_y = 100, min_x = 250}) then
                        poe2_api.click_position(1013, 25)
                        
                        return bret.RUNNING
                    end
                end
                
                api_Sleep(3000)
                self.wait_num = self.wait_num + 1
                
                return bret.RUNNING
            end
            
            
            return bret.FAIL
        end
    },

    -- 打开异界地图页面节点
    Open_The_Otherworld_Page = {
        run = function(self, env)
            poe2_api.print_log('打开异界地图页面...')

            if not self.last_action_time then 
                self.last_action_time = 0  -- 记录上次操作时间
                self.action_interval = 1   -- 操作间隔时间
                self.wait_start = 0        -- 等待开始时间
            end

            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            
            if current_time - self.last_action_time >= self.action_interval then
                if player_info and 
                poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and 
                not poe2_api.find_text({UI_info = env.UI_info, text = "世界地圖", min_x = 0}) then
                    poe2_api.dbgp("打开异界地图页面")
                    env.interactive = "MapDevice"
                    env.one_other_map = nil
                    
                    return bret.SUCCESS
                end
            end
            
            
            return bret.RUNNING
        end
    },

    -- 寻找精英怪怪物
    Find_Monster = {
        run = function(self, env)
            poe2_api.print_log("寻找怪物...")
            local nearest_distance_sq = math.huge
            local stuck_monsters = env.stuck_monsters
            local player_info = env.player_info
            local valid_monsters = nil
            if env.range_info then
                -- 先确定当前目标
                for _, monster in ipairs(env.range_info) do
                    if poe2_api.table_contains(stuck_monsters, monster.id) then
                        goto continue
                    end
                    
                    -- 快速失败条件检查
                    if monster.type ~= 1 or not monster.is_selectable then
                        goto continue
                    end
                    
                    if monster.is_friendly then
                        goto continue
                    end
                    
                    if not monster.isActive then
                        goto continue
                    end
                    
                    if monster.life <= 0 or monster.name_utf8 == "" then
                        goto continue
                    end
                    
                    if poe2_api.table_contains(my_game_info.not_attact_mons_path_name, monster.path_name_utf8) then
                        goto continue
                    end
                    
                    if not_attack_mos and poe2_api.table_contains(not_attack_mos, monster.rarity) then
                        goto continue
                    end
                    
                    if monster.rarity == 0 or monster.rarity == 1 then
                        goto continue
                    end
                    
                    -- if monster.hasLineOfSight then
                    --     goto continue
                    -- end
                    
                    -- 计算距离平方
                    local distance_sq = poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info)
                    
                    if distance_sq and distance_sq < nearest_distance_sq then
                        nearest_distance_sq = distance_sq
                        valid_monsters = monster
                    end
                    ::continue::
                end
            end
            
            if valid_monsters then
                env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                return bret.SUCCESS
            else
                return bret.FAIL
            end
            -- return bret.SUCCESS
        end
    },

    -- 检查是否在异界中
    Check_In_Otherworld_Map = {
        run = function(self, env)
            
            poe2_api.print_log("检查是否在异界中..." .. env.player_info.current_map_name_utf8)
            if poe2_api.table_contains(env.player_info.current_map_name_utf8,my_game_info.hideout) then
                return bret.FAIL
			end
            poe2_api.dbgp("异界中...")
            
            if not (poe2_api.find_text({UI_info = env.UI_info, text = 'Standard 聯盟',max_x=1800}) or poe2_api.find_text({UI_info = env.UI_info, text = 'Dawn of the Hunt 聯盟', max_x=1800})) and not poe2_api.table_contains(env.player_info.current_map_name_utf8,my_game_info.hideout) then
                if poe2_api.find_text({UI_info = env.UI_info, text = "繼續遊戲"}) then
                    poe2_api.find_text({UI_info = env.UI_info, text = "繼續遊戲",click = 2})
                    return bret.RUNNING
                end
                poe2_api.click_keyboard("tab")
                -- api_Sleep(1000)
                return bret.RUNNING
            end
            return bret.SUCCESS
        end
    },

    -- 检查目标点
    Check_Target_Point = {
        run = function(self, env)
            poe2_api.print_log("检查目标点...")
            -- 使用参数
            local no_mos_back = env.user_config["全局設置"]["刷图通用設置"]["是否全圖"]
            -- local no_mos_back = false
            local result = false
            local radius = 160
            
            local current_time = api_GetTickCount64()
            local player_info = env.player_info
            

            if not self.last_action_time then
                self.last_action_time = api_GetTickCount64()
                self.action_interval = 1
                self.false_times = 0
            end
            

            -- 主要逻辑
            if no_mos_back then
                result = poe2_api.monster_monitor(45)
            else
                result = true
            end

            if string.find(player_info.current_map_name_utf8 or "","Claimable") then
                result = poe2_api.monster_monitor(0)
                radius = 30
            end

            if current_time - self.last_action_time >= self.action_interval then
                point = api_GetUnexploredArea(radius)

                if point.x ~= -1 and point.y ~= -1 and env.have_ritual then
                    env.is_map_complete = false
                    env.end_point = {point.x, point.y}
                    env.is_arrive_end = false
                    return bret.SUCCESS
                end

                if point.x == -1 and point.y == -1 or (poe2_api.find_text({UI_info = env.UI_info, text = "地圖完成"}) and (result or poe2_api.find_text({UI_info = env.UI_info, text = "競技場",min_x=0,max_x=1600}))) or (poe2_api.find_text({UI_info = env.UI_info, text ="剩餘 0 隻怪物"}) and not poe2_api.table_contains(player_info.current_map_name_utf8,my_game_info.PRIORITY_MAPS)) then
                    poe2_api.dbgp("地圖完成")
                    
                    -- 提前结束迷雾状态
                    if poe2_api.click_text_UI({UI_info = env.UI_info, text = "delirium_skip_delay_button",click=2}) then
                        api_Sleep(1000)
                        return bret.RUNNING
                    end
                

                    -- Boss战Bug记录点回城
                    if player_info.isInBossBattle then
                        local list = poe2_api.get_sorted_list()
                        for _, item in ipairs(list) do
                            if item.name_utf8 == "記錄點" then
                                env.end_point = {item.grid_x, item.grid_y}
                                env.is_arrive_end = false
                                return bret.SUCCESS
                            end
                        end
                    end

                
                    env.is_map_complete = true
                    env.one_other_map = nil
                    if not string.find(player_info.current_map_name_utf8 or "", "town") and not poe2_api.table_contains(player_info.current_map_name_utf8, my_game_info.hideout) or poe2_api.table_contains(player_info.current_map_name_utf8, PRIORITY_MAPS) then
                        no = poe2_api.is_have_mos({range_info = env.range_info, player_info = player_info,dis = 80, not_sight = 1})
                        if no then
                            point = api_GetSafeAreaLocationNoMonsters(80)
                            if point then
                                env.end_point = point
                                env.is_arrive_end = false
                                return bret.SUCCESS
                            end
                            env.drop_items = true
                        end

                        -- 寻找传送门

                        if env.range_info then
                            for _, k in ipairs(env.range_info) do
                                if k.name_utf8 ~= '' and k.type == 5 and poe2_api.table_contains(k.name_utf8, my_game_info.hideout_CH) then
                                    dis = poe2_api.point_distance(k.grid_x, k.grid_y, player_info)
                                    if dis and dis < 25 then
                                        if not poe2_api.find_text({UI_info = env.UI_info, text = k.name_utf8, click = 2}) then
                                            api_ClickMove(poe2_api.toInt(k.grid_x), poe2_api.toInt(k.grid_y), poe2_api.toInt(k.world_z), 1)
                                        end
                                        api_Sleep(2000)
                                        env.false_times = 0
                                        return bret.RUNNING
                                    end
                                end
                            end
                        end

                        api_ClickMove(poe2_api.toInt(player_info.grid_x),poe2_api.toInt(player_info.grid_y),poe2_api.toInt(player_info.world_z),1)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 0)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(1500)
                        self.false_times = self.false_times + 1
                        env.false_times = self.false_times
                        self.last_action_time = current_time + 2
                        return bret.RUNNING
                    else
                        env.return_town = false
                        point = api_FindRandomWalkablePosition(player_info.grid_x,player_info.grid_y,50)
                        if point then
                            api_ClickMove(poe2_api.toInt(point.x), poe2_api.toInt(point.y),poe2_api.toInt(player_info.world_z), 3)
                        end
                        self.last_action_time = current_time 
                        return bret.RUNNING
                    end
                else
                    env.is_map_complete = false
                    env.end_point = {point.x, point.y}
                    env.is_arrive_end = false
                    return bret.SUCCESS
                end
            end
            return bret.FAIL
        end
    },


    -- 强化(通用)
    Strengthened = {
        run = function(self, env)
            poe2_api.print_log("执行强化操作...")
    
            return bret.SUCCESS
        end
    },

    -- 地图强化是否到点
    Is_Arrive_Point_FUHUASHENGYV = {
        run = function(self, env)
            poe2_api.print_log("强化地图(腐化圣域)...")
            local start_time = api_GetTickCount64()
            local player_info = env.player_info
            local bag_info = env.bag_info
            local current_map_info = env.current_map_info
            local is_insert_stone = env.is_insert_stone
            local entry_length_take_map = env.entry_length_take_map
            local the_update_map = env.the_update_map
            local map_update_to = env.map_update_to
            local user_map = env.user_map
            local map_up = env.map_up
            local priority_map = env.priority_map
            local not_have_stackableCurrency = env.not_have_stackableCurrency
            
            -- 检查是否在城镇或藏身处
            if not string.find(player_info.current_map_name_utf8, "town") and 
                not poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) or 
                not map then
                    poe2_api.dbgp("不在城镇或藏身处，或未找到地图装置")
                    env.entry_length_take_map = true
                    env.not_have_stackableCurrency = false
                    poe2_api.dbgp(string.format("节点执行耗时: %.2f 毫秒", (api_GetTickCount64() - start_time) * 1000))
                    return bret.SUCCESS
            end
            
            -- 检查地图强化条件
            if the_update_map then
                poe2_api.dbgp("检查地图强化条件...")
                local map_level = poe2_api.select_best_map_key({
                    inventory = bag_info,
                    key_level_threshold = user_map,
                    priority_map = priority_map,
                    vall = true
                })
                
                if map_level then
                    poe2_api.dbgp(string.format("找到地图: %s (颜色: %d, 词缀数: %d)", 
                        map_level.baseType_utf8, map_level.color, map_level.fixedSuffixCount))
                    
                    if map_level.color > 0 and map_level.fixedSuffixCount >= map_update_to then
                        poe2_api.dbgp("地图已满足强化条件，重置状态")
                        env.map_up = false
                        env.entry_length_take_map = false
                        env.the_update_map = nil
                        poe2_api.dbgp(string.format("节点执行耗时: %.2f 毫秒", (api_GetTickCount64() - start_time) * 1000))
                        return bret.SUCCESS
                    end
                end
            end
            
            -- 检查是否需要强化
            if not map_up or not entry_length_take_map then
                poe2_api.dbgp("不需要强化地图或未设置entry_length_take_map")
                env.not_have_stackableCurrency = false
                poe2_api.dbgp(string.format("节点执行耗时: %.2f 毫秒", (api_GetTickCount64() - start_time) * 1000))
                return bret.SUCCESS
            end
            
            local map = nil
            for _, item in ipairs(current_map_info) do
                if item.name_utf8 == "MapDevice" then
                    map = item
                    break
                end
            end
            
            if not the_update_map then
                poe2_api.dbgp("未设置the_update_map")
                env.not_have_stackableCurrency = false
                env.entry_length_take_map = true
                poe2_api.dbgp(string.format("节点执行耗时: %.2f 毫秒", (api_GetTickCount64() - start_time) * 1000))
                return bret.SUCCESS
            end
            
            if not_have_stackableCurrency then
                poe2_api.dbgp("没有可堆叠货币")
                poe2_api.dbgp(string.format("节点执行耗时: %.2f 毫秒", (api_GetTickCount64() - start_time) * 1000))
                return bret.SUCCESS
            end
            
            -- 移动逻辑部分
            poe2_api.dbgp("开始处理移动逻辑...")
            local function get_items_config_info()
                local config = env.user_config
                local item_filters = config["物品過濾"] or {}
                local processed_configs = {}
                
                for _, cfg in ipairs(item_filters) do
                    local item_type = cfg["類型"]
                    if type(item_type) == "string" then
                        item_type = {item_type}
                    end
                    
                    local processed_cfg = {
                        ["類型"] = item_type,
                        ["名稱模式"] = cfg["基礎類型名"] == "全部物品" and "all" or "specific",
                        ["匹配名稱"] = cfg["基礎類型名"] ~= "全部物品" and {cfg["基礎類型名"]} or {},
                        ["颜色"] = {}
                    }
                    
                    if cfg["白裝"] then table.insert(processed_cfg["颜色"], 0) end
                    if cfg["藍裝"] then table.insert(processed_cfg["颜色"], 1) end
                    if cfg["黃裝"] then table.insert(processed_cfg["颜色"], 2) end
                    if cfg["暗金"] then table.insert(processed_cfg["颜色"], 3) end
                    
                    table.insert(processed_configs, processed_cfg)
                end
                
                return processed_configs
            end
            
            local items_info = get_items_config_info()
            local unique_storage_pages = {}
            
            for _, item in ipairs(items_info) do
                if item["類型"] == "通貨" and item["存倉頁名"] and not item["工會倉庫"] then
                    unique_storage_pages[item["存倉頁名"]] = true
                end
            end
            
            local obj = nil
            local text = nil
            local warehouse = nil
            
            if next(unique_storage_pages) ~= nil then
                poe2_api.dbgp("使用个人仓库")
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == "StashPlayer" then
                        warehouse = item
                        break
                    end
                end
                obj = "StashPlayer"
                text = "公會倉庫"
            else
                poe2_api.dbgp("使用公会仓库")
                for _, item in ipairs(current_map_info) do
                    if item.name_utf8 == "StashGuild" then
                        warehouse = item
                        break
                    end
                end
                obj = "StashGuild"
                text = "倉庫"
                env.is_public_warehouse_plaque = false
            end
            
            if poe2_api.find_text({UI_info = env.UI_info, text = "強調物品", min_y = 700, min_x = 250}) and 
            not poe2_api.find_text({UI_info = env.UI_info, text = text, min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
                poe2_api.dbgp("已打开仓库界面")
                env.path_list = nil
                env.end_point = nil
                return bret.SUCCESS
            end
            
            if not warehouse then
                poe2_api.dbgp("未找到仓库对象")
                return bret.FAIL
            end
            
            local distance = poe2_api.point_distance(warehouse.grid_x, warehouse.grid_y, player_info)
            poe2_api.dbgp(string.format("与仓库的距离: %.2f", distance))
            
            if distance and distance > 25 then
                poe2_api.dbgp("距离仓库太远，设置交互对象")
                env.interactive = obj
                poe2_api.dbgp(string.format("节点执行耗时: %.2f 毫秒", (api_GetTickCount64() - start_time) * 1000))
                return bret.FAIL
            else
                poe2_api.dbgp("正在移动到仓库位置...")
                api_ClickMove(poe2_api.toInt(warehouse.grid_x), poe2_api.toInt(warehouse.grid_y), poe2_api.toInt(player_info.world_z - 70), 1)
                poe2_api.dbgp(string.format("节点执行耗时: %.2f 毫秒", (api_GetTickCount64() - start_time) * 1000))
                return bret.RUNNING
            end
        end
    },

    -- 更新牌匾
    Update_Plaque = {
        run = function(self, env)
            poe2_api.print_log("更新牌匾...")
            return bret.SUCCESS
        end
    },

    -- 插入牌匾
    Insert_The_Plaque = {
        run = function(self, env)
            poe2_api.print_log("插入牌匾...")
            return bret.SUCCESS
        end
    },

    -- 插入牌匾(动作)
    Insert_Plaque = {
        run = function(self, env)
            poe2_api.print_log("执行插入牌匾动作...")
            return bret.SUCCESS
        end
    },

    -- 是否需要交换
    Is_Need_Exchange = {
        run = function(self, env)
            poe2_api.dbgp("开始执行通货交换检查...")
            local current_time = api_GetTickCount64()  -- 获取的是毫秒数
            local config = env.user_config
            local bag_info = env.bag_info
            local player_info = env.player_info
            

            local exchaneg
            
            -- 基础条件检查
            if not config["刷圖設置"]["通貨交換設置"]["是否自動對換"] then
                poe2_api.dbgp("自动兑换未开启，跳过")
                env.exchange_status = true
                return bret.SUCCESS
            end
            
            -- 初始化执行时间
            if not env.last_execution_time then
                poe2_api.dbgp("初始化执行时间")
                env.last_execution_time = current_time
                return bret.RUNNING
            end
            
            -- 检查是否在藏身处
            if not poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                poe2_api.dbgp("不在藏身处，跳过")
                return bret.SUCCESS
            end
            
            -- 检查背包空间
            if bag_info then
                local point = poe2_api.get_space_point({width = 2, height = 4, info = bag_info})
                if not point then
                    poe2_api.dbgp("背包空间不足，跳过")
                    return bret.SUCCESS
                end
            end
            
            -- 检查仓库是否已满
            if env.warehouse_full then
                poe2_api.dbgp("仓库已满，跳过")
                return bret.SUCCESS
            end
            
            -- 冷却时间检查
            local cooldown_hours = config["刷圖設置"]["通貨交換設置"]["兌換間隔時間"] or 1
            local cooldown_ms = cooldown_hours * 3600 * 1000  -- 转换为毫秒
            local elapsed_time = current_time - env.last_execution_time  -- 毫秒数相减

            -- 毫秒转换为分钟和秒的字符串
            local function ms_to_min_sec(ms)
                local total_seconds = math.floor(ms / 1000)
                local minutes = math.floor(total_seconds / 60)
                local seconds = total_seconds % 60
                return string.format("%d分%d秒", minutes, seconds)
            end
            
            -- 使用转换函数显示更友好的时间格式
            poe2_api.dbgp(string.format("冷却时间检查: 已过 %s (需要 %s)", 
                ms_to_min_sec(elapsed_time), 
                ms_to_min_sec(cooldown_ms)))
            
            if elapsed_time < cooldown_ms and not env.warehouse_full then
                poe2_api.dbgp("冷却时间未到，跳过")
                return bret.SUCCESS
            end
            
            -- 取消遮挡
            if poe2_api.find_text({UI_info = env.UI_info, text = "繼續", click = 2}) then
                poe2_api.dbgp("发现遮挡，点击继续")
                return bret.RUNNING
            end
            
            poe2_api.dbgp("满足所有条件，执行兑换")
            return bret.FAIL
        end
    },

    -- 获取物品数量
    Obtain_The_Quantity_of_Items = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Obtain_The_Quantity_of_Items 节点")
            
            -- 检查仓库页面是否可用
            local function check_pages()
                poe2_api.dbgp("检查仓库页面是否可用...")
                local pages = api_GetRepositoryPages(0)
                if not pages then
                    poe2_api.dbgp("警告: 无法获取仓库页面信息")
                    return false
                end
                
                for _, page in ipairs(pages) do
                    if page.manage_index == 0 and page.type ~= 5 then
                        poe2_api.dbgp("发现无效仓库页面(manage_index=0且type≠5)")
                        return false
                    end
                end
                return true
            end
            
            -- 获取所有库存物品
            local function get_all_inventory_items()
                poe2_api.dbgp("开始获取所有库存物品...")
                local items = {}
                
                -- 获取常规背包物品
                local bag_items = api_Getinventorys(1, 0)
                if bag_items then
                    poe2_api.dbgp(string.format("获取到背包物品数量: %d", #bag_items))
                    for _, item in ipairs(bag_items) do
                        table.insert(items, item)
                    end
                else
                    poe2_api.dbgp("警告: 无法获取背包物品")
                end
                
                -- 检查特定槽位(0x7a 到 0x7a + 199)
                for offset = 0x7a, 0x7a + 199 do
                    local slot_data = api_Getinventorys(offset, 0)
                    if slot_data then
                        -- poe2_api.dbgp(string.format("槽位 0x%x 找到 %d 件物品", offset, #slot_data))
                        for _, item in ipairs(slot_data) do
                            table.insert(items, item)
                        end
                    end
                end
                
                poe2_api.dbgp(string.format("总共获取到 %d 件物品", #items))
                return items
            end
            
            -- 主逻辑开始
            if not check_pages() then
                poe2_api.dbgp("仓库页面不可用，返回FAILURE")
                return bret.FAIL
            end
            
            local config = env.user_config
            if not config then
                poe2_api.dbgp("错误: 用户配置为空")
                return bret.FAIL
            end
            
            -- 获取通货交换设置
            local exchange_config = config["刷圖設置"] and config["刷圖設置"]["通貨交換設置"] or {}
            poe2_api.dbgp("获取通货交换配置:", #exchange_config)
            poe2_api.printTable(exchange_config)

            -- 初始化拥有和需要的通货列表
            local owned_currencies = {}
            local needed_currencies = {}

            -- 检查是否存在物品表
            if exchange_config["物品表"] then
                for _, item in ipairs(exchange_config["物品表"]) do
                    -- 添加拥有的通货
                    if item["我擁有的"] and item["我擁有的"] ~= "" then
                        table.insert(owned_currencies, item["我擁有的"])
                    end
                    
                    -- 添加需要的通货
                    if item["我需要的"] and item["我需要的"] ~= "" then
                        table.insert(needed_currencies, item["我需要的"])
                    end
                end
            end

            poe2_api.dbgp("配置中的拥有通货:", #owned_currencies)
            poe2_api.printTable(owned_currencies)
            poe2_api.dbgp("配置中的需要通货:", #needed_currencies)
            poe2_api.printTable(needed_currencies)
            
            -- 初始化物品数量字典
            local item_nums_dict = {}
            local all_items = get_all_inventory_items()
            
            -- 检查是否存在"全部物品"需求
            local has_all_items = false
            for _, currency in ipairs(owned_currencies) do
                if currency == "全部物品" then
                    has_all_items = true
                    break
                end
            end
            
            poe2_api.dbgp("配置中包含'全部物品':", has_all_items)
            
            -- 通货类别列表
            local currency_categories = {}
            
            -- 合并所有通货类别
            local function merge_tables(...)
                local result = {}
                for _, tbl in ipairs({...}) do
                    for _, v in ipairs(tbl) do
                        table.insert(result, v)
                    end
                end
                return result
            end
            
            currency_categories = merge_tables(
                my_game_info.StackableCurrency_CN,
                my_game_info.Delirium_in_foreign_lands_CN,
                my_game_info.Crack_Alliance_CN,
                my_game_info.Fragment_CN,
                my_game_info.Dead_realm_exploration_CN,
                my_game_info.Essence_CN,
                my_game_info.Rune_CN,
                my_game_info.Sign_CN,
                my_game_info.SoulCore_CN,
                my_game_info.Sigil_CN
            )
            
            if has_all_items then
                poe2_api.dbgp("处理'全部物品'配置...")
                for _, currency in ipairs(currency_categories) do
                    item_nums_dict[currency] = 0
                    for _, item in ipairs(all_items) do
                        if item.baseType_utf8 == currency then
                            item_nums_dict[currency] = (item_nums_dict[currency] or 0) + (item.stackCount or 1)
                        end
                    end
                end
            else
                poe2_api.dbgp("处理特定通货配置...")
                for _, currency in ipairs(owned_currencies) do
                    if string.find(currency, "|") then
                        -- 处理分割的通货(如"混沌石|崇高石")
                        local currency_parts = {}
                        for part in string.gmatch(currency, "([^|]+)") do
                            table.insert(currency_parts, part)
                        end
                        
                        for _, part in ipairs(currency_parts) do
                            item_nums_dict[part] = 0
                            for _, item in ipairs(all_items) do
                                if item.baseType_utf8 == part then
                                    item_nums_dict[part] = (item_nums_dict[part] or 0) + (item.stackCount or 1)
                                end
                            end
                        end
                    else
                        item_nums_dict[currency] = 0
                        for _, item in ipairs(all_items) do
                            if item.baseType_utf8 == currency then
                                item_nums_dict[currency] = (item_nums_dict[currency] or 0) + (item.stackCount or 1)
                            end
                        end
                    end
                end
            end
            
            -- 过滤掉数量为0的通货
            local filtered_dict = {}
            for currency, count in pairs(item_nums_dict) do
                if count > 0 then
                    filtered_dict[currency] = count
                end
            end
            item_nums_dict = filtered_dict
            
            poe2_api.dbgp("过滤后的物品数量字典:", item_nums_dict)
            
            -- 检查兑换条件并过滤不满足的货币
            local valid_owned = {}
            local valid_needed = {}
            
            for i = 1, math.min(#owned_currencies, #needed_currencies) do
                local owned = owned_currencies[i]
                local needed = needed_currencies[i]
                
                if owned == "全部物品" then
                    if has_all_items then
                        for item, _ in pairs(item_nums_dict) do
                            if item ~= "神聖石" and 
                            not poe2_api.table_contains(owned_currencies, item) and 
                            item ~= needed then
                                table.insert(valid_owned, item)
                                table.insert(valid_needed, needed)
                            end
                        end
                    end
                    goto continue
                end
                
                -- 处理包含"|"的分割货币
                if string.find(owned, "|") then
                    for part in string.gmatch(owned, "([^|]+)") do
                        if item_nums_dict[part] then
                            table.insert(valid_owned, part)
                            table.insert(valid_needed, needed)
                        end
                    end
                    goto continue
                end
                
                if owned == needed then
                    goto continue
                end
                
                if not item_nums_dict[owned] then
                    goto continue
                end
                
                -- 检查货币数量是否>0且比例有效
                table.insert(valid_owned, owned)
                table.insert(valid_needed, needed)
                
                ::continue::
            end
            
            poe2_api.dbgp("有效的拥有通货:", #valid_owned)
            -- poe2_api.printTable(valid_owned)
            poe2_api.dbgp("有效的需要通货:", #valid_needed)
            -- poe2_api.printTable(valid_needed)
            
            -- 更新黑板参数
            if not env.owned_currencies and not env.needed_currencies then
                env.owned_currencies = valid_owned
                env.needed_currencies = valid_needed
                poe2_api.dbgp("首次设置黑板中的通货列表")
            end
            
            -- 转换为列表格式并更新黑板
            local item_nums_list = {}
            for _, currency in ipairs(valid_owned) do
                if item_nums_dict[currency] then
                    table.insert(item_nums_list, {currency, item_nums_dict[currency]})
                end
            end
            
            env.item_nums_list = item_nums_list
            poe2_api.dbgp("更新黑板中的物品数量列表:", item_nums_list)
            
            -- 检查是否有满足兑换条件的货币
            if #valid_owned > 0 then
                env.enough_currency = true
                poe2_api.dbgp("找到满足兑换条件的货币，返回FAILURE")
                return bret.FAIL
            end
            
            env.enough_currency = false
            poe2_api.dbgp("未找到满足兑换条件的货币，返回SUCCESS")
            return bret.SUCCESS
        end
    },

    -- 点击所有仓库页
    Click_All_Pages = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Click_All_Pages 节点")
            
            local current_time = api_GetTickCount64()
            
            
            -- 检查仓库页面是否可用
            local function _check_pages()
                poe2_api.dbgp("检查仓库页面可用性...")
                local pages = api_GetRepositoryPages(0)  -- 0表示个人仓库
                if not pages then
                    poe2_api.dbgp("获取仓库页面失败")
                    return false
                end
                
                for _, page in ipairs(pages) do
                    if page.manage_index == 0 and page.type ~= 5 then
                        poe2_api.dbgp(string.format("发现无效页面: 索引=%d, 类型=%d, 名称=%s", 
                            page.manage_index, page.type, page.name_utf8 or "未知"))
                        return false
                    end
                end
                return true
            end

            -- 主逻辑
            if _check_pages() then
                poe2_api.dbgp("所有仓库页面均可用，返回FAILURE")
                return bret.FAIL
            end

            -- 检查是否已打开仓库界面
            local emphasize_text = poe2_api.find_text({UI_info = env.UI_info, text = "強調物品", min_x = 250, min_y = 700})
            local warehouse_text = poe2_api.find_text({UI_info = env.UI_info, text = "倉庫", min_x = 0, min_y = 32, max_x = 381, max_y = 81})
            
            poe2_api.dbgp("仓库界面检查结果:", {
                emphasize_text = emphasize_text and "found" or "not found",
                warehouse_text = warehouse_text and "found" or "not found"
            })

            if not emphasize_text or not warehouse_text then
                poe2_api.dbgp("未打开仓库界面，返回SUCCESS")
                env.warehouse_type_interactive = "个仓"
                return bret.SUCCESS
            end

            api_Sleep(2000)  -- 等待2秒

            -- 获取仓库标签按钮
            local tab_list_button = poe2_api.click_text_UI({UI_info = env.UI_info, text = "tab_list_button", ret_data = true})
            poe2_api.dbgp("标签按钮状态:", tab_list_button and "found" or "not found")

            -- 获取仓库页面
            local item_pages = {}
            local pages = api_GetRepositoryPages(0)
            if pages then
                for _, page in ipairs(pages) do
                    if page.type ~= 5 then  -- 跳过地图页
                        table.insert(item_pages, page)
                        poe2_api.dbgp(string.format("添加仓库页: 名称=%s, 类型=%d, 索引=%d", 
                            page.name_utf8, page.type, page.manage_index))
                    end
                end
            else
                poe2_api.dbgp("警告: 无法获取仓库页面列表")
                return bret.RUNNING
            end

            if not tab_list_button then
                poe2_api.dbgp("未展开标签列表的情况")
                -- 未展开标签列表的情况
                for _, page in ipairs(item_pages) do
                    poe2_api.dbgp(string.format("尝试点击页面: %s", page.name_utf8))
                    poe2_api.find_text({UI_info = env.UI_info, 
                        text = page.name_utf8,
                        max_y = 90,
                        min_x = 0,
                        max_x = 550,
                        min_y = 0,
                        click = 2
                    })
                    api_Sleep(100)
                end
                poe2_api.dbgp("完成未展开标签列表的页面点击")
                return bret.RUNNING
            else
                poe2_api.dbgp("已展开标签列表的情况")
                -- 已展开标签列表的情况
                local lock = poe2_api.get_game_control_by_rect({
                    min_x = 549,
                    min_y = 34,
                    max_x = 584,
                    max_y = 74
                })
                
                local lock_button = nil
                for _, v in ipairs(lock) do
                    if v.left >= 549 and v.top >= 34 and v.right <= 584 and v.bottom <= 74 and v.name_utf8 ~= 'bottom_icons_layout' then
                        lock_button = v
                        break
                    end
                end

                if not lock_button then
                    poe2_api.dbgp("未找到锁定按钮，尝试点击标签列表")
                    poe2_api.natural_move(
                        (tab_list_button.left + tab_list_button.right) / 2,
                        (tab_list_button.top + tab_list_button.bottom) / 2
                    )
                    api_LeftClick()
                    api_Sleep(200)
                    return bret.RUNNING
                end

                -- 点击所有页面
                for _, page in ipairs(item_pages) do
                    poe2_api.dbgp(string.format("尝试点击展开列表中的页面: %s", page.name_utf8))
                    poe2_api.find_text({UI_info = env.UI_info, 
                        text = page.name_utf8,
                        max_y = 469,
                        min_x = 556,
                        min_y = 20,
                        max_x = 851,
                        click = 2
                    })
                    api_Sleep(100)
                end
                poe2_api.dbgp("完成已展开标签列表的页面点击")
                return bret.RUNNING
            end
        end
    },

    -- 打开交换界面
    Open_The_Exchange_Interface = {
        run = function(self, env)
            poe2_api.dbgp("打开交换界面...")
            
            
            local player_info = env.player_info

            if poe2_api.find_text({UI_info = env.UI_info, text = "重組", min_x = 0, max_y = 200, click = 2, add_x = 240}) then
                return bret.RUNNING
            end

            local function check_in_range(object)
                for _, k in ipairs(env.range_info) do
                    if object then
                        if k.name_utf8 == object or k.path_name_utf8 == object then
                            return k
                        end
                    end
                    if (k.name_utf8 == interactive_object or k.path_name_utf8 == interactive_object) and k.grid_x ~= 0 and k.grid_y ~= 0 and k.is_selectable then
                        return k
                    end
                end
                return nil
            end

            if not poe2_api.find_text({UI_info = env.UI_info, text = "通貨交換", min_x = 0, max_y = 200}) then
                local target = check_in_range("艾瓦")
                local distance = poe2_api.point_distance(target.grid_x, target.grid_y, env.player_info)
                if distance and distance > 25 then 
                    env.interactive = "艾瓦"
                    return bret.FAIL
                else
                    if player_info.isMoving then
                        poe2_api.dbgp("等待静止")
                        api_Sleep(500)
                        return bret.RUNNING
                    end
                    if not poe2_api.find_text({UI_info = env.UI_info, text = "通貨交換", min_x = 0}) then
                        api_Sleep(200)
                        poe2_api.find_text({UI_info = env.UI_info, text = "艾瓦", min_x = 0, click = 2, max_x = 1200})
                    else
                        poe2_api.find_text({UI_info = env.UI_info, text = "通貨交換", min_x = 0, click = 2, max_x = 1200})
                        api_Sleep(500)
                    end
                    return bret.RUNNING
                end
            else
                return bret.SUCCESS
            end
        end
    },

    -- 领取通货
    Click_All_Exchange = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Click_All_Exchange 节点")
            
            -- 查找"完成的訂單"文本
            local position = poe2_api.find_text({UI_info = env.UI_info, text = "完成的訂單", max_y = 540, position = 3, min_x = 0})
            if position then
                poe2_api.dbgp(string.format("找到'完成的訂單'文本，位置: x=%d, y=%d", position[1], position[2]))
                
                -- 点击左侧领取按钮
                poe2_api.dbgp("点击左侧领取按钮")
                poe2_api.click_position(position[1]-108, position[2]-37, 2)
                api_Sleep(200)
                
                -- 再次检查"完成的訂單"文本
                position = poe2_api.find_text({UI_info = env.UI_info, text = "完成的訂單", max_y = 540, position = 3})
                if position then
                    poe2_api.dbgp("找到第二个'完成的訂單'文本，点击右侧领取按钮")
                    poe2_api.click_position(position[1]+108, position[2]-37, 2)
                else
                    poe2_api.dbgp("未找到第二个'完成的訂單'文本")
                end
                
                poe2_api.dbgp("通货领取操作完成，返回RUNNING")
                return bret.RUNNING
            else
                poe2_api.dbgp("未找到'完成的訂單'文本")
            end
            
            poe2_api.dbgp("Click_All_Exchange 节点执行完成，返回SUCCESS")
            return bret.SUCCESS
        end
    },

    -- 訂單取消
    Click_All_Cancel = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Click_All_Cancel 节点")
            
            -- 查找"訂單取消"文本
            local position = poe2_api.find_text({UI_info = env.UI_info, text = "訂單取消", max_y = 540, position = 3, min_x = 0})
            if position then
                poe2_api.dbgp(string.format("找到'訂單取消'文本，位置: x=%d, y=%d", position[1], position[2]))
                
                -- 点击左侧取消按钮
                poe2_api.dbgp("点击左侧取消按钮")
                poe2_api.click_position(position[1]-108, position[2]-37, 2)
                api_Sleep(200)
                
                -- 再次检查"訂單取消"文本
                position = poe2_api.find_text({UI_info = env.UI_info, text = "訂單取消", max_y = 540, position = 3})
                if position then
                    poe2_api.dbgp("找到第二个'訂單取消'文本，点击右侧取消按钮")
                    poe2_api.click_position(position[1]+108, position[2]-37, 2)
                else
                    poe2_api.dbgp("未找到第二个'訂單取消'文本")
                end
                
                poe2_api.dbgp("订单取消操作完成，返回RUNNING")
                return bret.RUNNING
            else
                poe2_api.dbgp("未找到'訂單取消'文本")
            end
            
            poe2_api.dbgp("Click_All_Cancel 节点执行完成，返回SUCCESS")
            return bret.SUCCESS
        end
    },

    -- 清除旧的兑换
    Click_Old_Exchange = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Click_Old_Exchange 节点")
            poe2_api.dbgp(string.format("当前兑换索引: %d", env.current_pair_index or 0))
            
            -- 只在第一次执行时清除旧订单
            if (env.current_pair_index or 0) == 0 then
                poe2_api.dbgp("当前是第一次兑换，开始清除旧订单")
                
                -- 查找"關閉訂單"文本
                if poe2_api.find_text({UI_info = env.UI_info, text = "關閉訂單"}) then
                    poe2_api.dbgp("找到'關閉訂單'文本，点击'確定'按钮")
                    poe2_api.find_text({UI_info = env.UI_info, text = "確定", click = 2})
                    api_Sleep(200)
                    return bret.RUNNING
                end
                
                -- 查找"列出的訂單"文本
                local position = poe2_api.find_text({UI_info = env.UI_info, text = "列出的訂單", max_y = 540, position = 3, min_x = 0})
                if position then
                    poe2_api.dbgp(string.format("找到'列出的訂單'文本，位置: x=%d, y=%d", position[1], position[2]))
                    poe2_api.dbgp("点击右侧关闭按钮")
                    poe2_api.click_position(position[1]+145, position[2]-33)
                    api_Sleep(200)
                    return bret.RUNNING
                else
                    poe2_api.dbgp("未找到'列出的訂單'文本")
                end
            else
                poe2_api.dbgp("非首次兑换，跳过清除旧订单步骤")
            end
            
            poe2_api.dbgp("Click_Old_Exchange 节点执行完成，返回SUCCESS")
            return bret.SUCCESS
        end
    },

    -- 点击无状态兑换
    Click_Stateless_Exchange = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Click_Stateless_Exchange 节点")
            
            -- 检查是否存在任何订单状态文本
            local position1 = poe2_api.find_text({UI_info = env.UI_info, text = "列出的訂單", max_y = 540, min_x = 0})
            local position2 = poe2_api.find_text({UI_info = env.UI_info, text = "訂單取消", max_y = 540, min_x = 0})
            local position3 = poe2_api.find_text({UI_info = env.UI_info, text = "完成的訂單", max_y = 540, min_x = 0})
            
            poe2_api.dbgp(string.format("订单状态检查结果 - 列出的訂單: %s, 訂單取消: %s, 完成的訂單: %s", 
                tostring(position1), tostring(position2), tostring(position3)))
            
            if not position1 and not position2 and not position3 then
                poe2_api.dbgp("未找到任何订单状态文本，开始处理无状态订单")
                
                local stateless = api_GetCurrencyExchangeList()
                poe2_api.dbgp(string.format("获取无状态订单列表: %s", next(stateless) and "有数据" or "无数据"))
                
                if next(stateless) then
                    local position = poe2_api.find_text({UI_info = env.UI_info, text = "我需要的", max_y = 540, position = 3})
                    if position then
                        poe2_api.dbgp(string.format("找到'我需要的'文本，位置: x=%d, y=%d", position[1], position[2]))
                        
                        -- 点击左侧取消按钮
                        poe2_api.dbgp("点击左侧取消按钮")
                        poe2_api.click_position(position[1] - 68, position[2] + 192, 2)
                        api_Sleep(200)
                        
                        -- 点击右侧取消按钮
                        poe2_api.dbgp("点击右侧取消按钮")
                        poe2_api.click_position(position[1] + 150, position[2] + 192, 2)
                        api_Sleep(200)
                        
                        poe2_api.dbgp("无状态订单清除操作完成，返回RUNNING")
                        return bret.RUNNING
                    else
                        poe2_api.dbgp("未找到'我需要的'文本")
                    end
                else
                    poe2_api.dbgp("无状态订单列表为空")
                end
            else
                poe2_api.dbgp("存在有效订单状态，无需处理无状态订单")
            end
            
            poe2_api.dbgp("Click_Stateless_Exchange 节点执行完成，返回SUCCESS")
            return bret.SUCCESS
        end
    },

    -- 选择和交换
    Select_AND_Exhange = {
        new = function(self, name)
            local o = {}
            setmetatable(o, self)
            self.__index = self
            o.name = name or self.name
            return o
        end,
    
        run = function(self, env)
            poe2_api.dbgp("开始执行 Select_AND_Exhange 节点")
            
            -- 检查是否有低比率提示
            if poe2_api.find_text({UI_info = env.UI_info, text="你選擇的交易比率低於當下市集需求的標準。",refresh = true, min_x=0, match=2}) then
                poe2_api.dbgp("发现低比率提示，点击取消")
                poe2_api.find_text({UI_info = env.UI_info, text="取消",refresh = true, click=2})
                return bret.RUNNING
            end

            local function _select_currency(currency)
                poe2_api.dbgp("选择通货:", currency)
                -- 判断类型并点击对应分类
                if poe2_api.table_contains(my_game_info.StackableCurrency_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="通貨",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.Delirium_in_foreign_lands_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="譫妄異域",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.Crack_Alliance_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="裂痕聯盟",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.Fragment_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="碎片",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.Dead_realm_exploration_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="死境探險",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.Essence_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="精髓",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.Rune_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="符文",refresh = true, min_x=0, max_x=580, click=2})
                    if poe2_api.table_contains(my_game_info.High_Rune_CN, currency) then
                        poe2_api.find_text({UI_info = env.UI_info, text='高階符文',refresh = true, click=1, add_y=-128})
                        api_Sleep(1000)
                        api_WheelDown()
                        api_Sleep(1000)
                    end
                elseif poe2_api.table_contains(my_game_info.Sign_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="徵兆",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.SoulCore_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="靈魂核心",refresh = true, min_x=0, max_x=580, click=2})
                elseif poe2_api.table_contains(my_game_info.Sigil_CN, currency) then
                    poe2_api.find_text({UI_info = env.UI_info, text="魔符",refresh = true, min_x=0, max_x=580, click=2})
                else
                    poe2_api.dbgp("錯誤的設定:", currency)
                    return false, nil
                end
        
                api_Sleep(500)
                
                -- 尝试直接点击目标通货
                if poe2_api.find_text({UI_info = env.UI_info, text=currency,refresh = true, click=2, min_x=0}) then
                    api_Sleep(500)
                    return true, currency
                end
                
                return false, nil
            end

            local function _verify_left_currency(expected)
                poe2_api.dbgp("验证左边通货:", expected)
                
                local poesition_left = poe2_api.find_text({UI_info = env.UI_info, text="我需要的",refresh = true, min_x=0, position=1})
                if not poesition_left then
                    poe2_api.dbgp("未找到'我需要的'文本")
                    return false, nil
                end
                
                local ratio_area = {poesition_left[1] - 40, 174, poesition_left[3] + 40, 234}
                local current_left = poe2_api.find_text_position({UI_info = env.UI_info, 
                    min_x=ratio_area[1],
                    min_y=ratio_area[2],
                    max_x=ratio_area[3],
                    max_y=ratio_area[4],
                    lens=nil
                })
                
                -- 已经是目标通货
                if current_left and string.find(current_left, expected) then
                    poe2_api.dbgp("左边通货已经是目标通货:", expected)
                    return true, current_left
                end
                
                poe2_api.find_text({UI_info = env.UI_info, text="我需要的",refresh = true, min_x=0, add_y=30, click=2})
                api_Sleep(500)
                    
                -- 需要重新选择
                local a, currency = _select_currency(expected)
                return a, currency
            end
        
            local function _verify_right_currency(expected)
                poe2_api.dbgp("验证右边通货:", expected)
                local poesition_left = poe2_api.find_text({UI_info = env.UI_info, text="我擁有的",refresh = true, min_x=0, position=1})
                if not poesition_left then
                    poe2_api.dbgp("未找到'我擁有的'文本")
                    return false, nil
                end
                
                local ratio_area = {poesition_left[1] - 40, 174, poesition_left[3] + 40, 234}
                local current_right = poe2_api.find_text_position({UI_info = env.UI_info, 
                    min_x=ratio_area[1],
                    min_y=ratio_area[2],
                    max_x=ratio_area[3],
                    max_y=ratio_area[4],
                    lens=nil
                })
                
                -- 已经是目标通货
                if current_right and string.find(current_right, expected) then
                    poe2_api.dbgp("右边通货已经是目标通货:", expected)
                    return true, current_right
                end
                
                -- 左边输入（需要的数量）
                poe2_api.find_text({UI_info = env.UI_info, text="我需要的",refresh = true, min_x=0, add_x=132, add_y=37, click=2})
                api_Sleep(300)
                poe2_api.paste_text("1")
                api_Sleep(500)
        
                poe2_api.find_text({UI_info = env.UI_info, text="我擁有的",refresh = true, min_x=0, add_y=30, click=2})
                api_Sleep(500)
                    
                -- 需要重新选择
                local a, currency = _select_currency(expected)
                return a, currency
            end

        
            local function _get_currency_amount(currency_type)
                poe2_api.dbgp("获取通货数量:", currency_type)
                
                if not env.item_nums_list then
                    poe2_api.dbgp("item_nums_list为空")
                    return 0
                end
                
                for _, item in ipairs(env.item_nums_list) do
                    if item[1] == currency_type then  -- item格式: {'通货名称', 数量}
                        poe2_api.dbgp("找到通货数量:", item[2])
                        return item[2]
                    end
                end
                
                poe2_api.dbgp("未找到该通货")
                return 0
            end
        
        
            local function _get_live_ratio()
                poe2_api.dbgp("获取实时市场比例")
                
                local poesition_left = poe2_api.find_text({UI_info = env.UI_info, text="我需要的",refresh = true, min_x=0, position=1})
                if not poesition_left then
                    poe2_api.dbgp("未找到'我需要的'文本")
                    return nil
                end
                
                local ratio_area = {poesition_left[3], poesition_left[4] - 53, poesition_left[3] + 280, poesition_left[4] + 12}
                poe2_api.dbgp("文本区域:", poesition_left[3],",", poesition_left[4] - 53,",",  poesition_left[3] + 280,",",  poesition_left[4] + 12)
                local ratio_text = poe2_api.find_text_position({UI_info = env.UI_info, 
                    min_x=ratio_area[1],
                    min_y=ratio_area[2],
                    max_x=ratio_area[3],
                    max_y=ratio_area[4],
                    lens=4
                })
                poe2_api.dbgp("原始比例文本:", ratio_text)

                if ratio_text then
                    poe2_api.dbgp("原始比例文本:", ratio_text)
                    
                    -- 改进的文本解析逻辑，匹配<kalguurlightgrey>{数字}：<kalguurlightgrey>{数字}格式
                    local pattern = "<kalguurlightgrey>{(%d+%.?%d*)}：<kalguurlightgrey>{(%d+%.?%d*)}"
                    local need, have = string.match(ratio_text, pattern)
                    
                    if need and have then
                        need = tonumber(need)
                        have = tonumber(have)
                        if need > 0 and have > 0 then
                            poe2_api.dbgp("解析比例成功:", need, ":", have)
                            return {need, have}  -- (需要的, 拥有的)
                        end
                    end
                end
                
                poe2_api.dbgp("无法解析比例")
                return nil
            end
        
            local function _calculate_optimal_exchange(have_amount, current_ratio)
                poe2_api.dbgp("计算最优兑换量 - 当前数量:", have_amount, "市场比例:", current_ratio[1], ":", current_ratio[2])
                
                if not current_ratio or have_amount <= 0 then
                    poe2_api.dbgp("无效输入")
                    return {0, 0}, {0, 0}
                end
                
                local market_need, market_have = current_ratio[1], current_ratio[2]
                
                -- 计算最小精确整数倍兑换单位
                local function gcd(a, b)
                    while b ~= 0 do
                        a, b = b, a % b
                    end
                    return a
                end
                
                local rounded_need = math.floor(market_need * 10 + 0.5) / 10
                local rounded_have = math.floor(market_have * 10 + 0.5) / 10
                
                local factor = 10
                local int_need = math.floor(rounded_need * factor + 0.5)
                local int_have = math.floor(rounded_have * factor + 0.5)
                
                local common_divisor = gcd(int_need, int_have)
                local unit_need = int_need // common_divisor
                local unit_have = int_have // common_divisor
                
                poe2_api.dbgp("最小兑换单位:", unit_need, ":", unit_have)
                
                if have_amount < unit_have then
                    poe2_api.dbgp("持有量不足: 需要", unit_have, "当前", have_amount)
                    return {0, 0}, {unit_need, unit_have}
                end
                
                local max_trades = have_amount // unit_have
                local actual_trades = max_trades  -- 移除了限制
                
                poe2_api.dbgp("最大交易次数:", actual_trades)
                
                return {unit_need * actual_trades, unit_have * actual_trades},{unit_need, unit_have}
                
            end
        
            local function _execute_exchange(ratio)
                poe2_api.dbgp("执行兑换操作 - 比例:", ratio[1], ":", ratio[2])
                local need, give = ratio[1], ratio[2]
                
                -- 左边输入（需要的数量）
                poe2_api.find_text({UI_info = env.UI_info, text="我需要的",refresh = true, min_x=0, add_x=132, add_y=37, click=2})
                api_Sleep(300)
                poe2_api.paste_text(tostring(need))
                api_Sleep(300)
                
                -- 右边输入（给出的数量）
                poe2_api.find_text({UI_info = env.UI_info, text="我擁有的",refresh = true, add_x=-132, add_y=37, click=2})
                api_Sleep(300)
                poe2_api.paste_text(tostring(give))
                poe2_api.find_text({UI_info = env.UI_info, text="我擁有的",refresh = true, add_x=-132, add_y=37, click=2})
                
                -- 确认交易
                local i = 0
                while i < 3 do
                    poe2_api.find_text({UI_info = env.UI_info, text="下訂單",refresh = true, click=2})
                    api_Sleep(800)
                    
                    if poe2_api.find_text({UI_info = env.UI_info, text="你選擇的交易比率低於當下市集需求的標準。",refresh = true, min_x=0, match=2}) then
                        poe2_api.dbgp("检测到低比率提示")
                        poe2_api.find_text({UI_info = env.UI_info, text="取消",refresh = true, click=2})
                        return false
                    end
                    
                    if poe2_api.find_text({UI_info = env.UI_info, text="你選擇的交易比率低於當下市場市集需求的標準。",refresh = true, min_x=0}) then
                        poe2_api.dbgp("检测到低比率提示(变体)")
                        poe2_api.find_text({UI_info = env.UI_info, text="取消",refresh = true, click=2})
                        break
                    end
                    
                    i = i + 1
                end
                
                -- 根据数值位数调整延迟
                local delay = math.max(0.5, math.min(1.5, (string.len(tostring(need)) + string.len(tostring(give))) * 0.15))
                api_Sleep(poe2_api.toInt(delay * 1000))
                return true
            end
    
            -- 获取当前处理的通货对索引
            local current_pair_index = env.current_pair_index or 1
            poe2_api.dbgp("当前处理通货对索引:", current_pair_index)
            
            -- 获取拥有的和需要的通货列表
            local owned_currencies = env.owned_currencies or {}
            local needed_currencies = env.needed_currencies or {}
            poe2_api.dbgp("拥有的通货列表:", #owned_currencies)
            poe2_api.dbgp("需要的通货列表:", #needed_currencies)
    
            -- 检查通货对是否有效
            if #owned_currencies < current_pair_index + 1 or #needed_currencies < current_pair_index + 1 then
                poe2_api.dbgp("通货对处理完成，重置状态")
                env.last_execution_time = api_GetTickCount64()
                env.current_pair_index = 0
                env.exchange_status = true
                env.warehouse_full = false
                env.owned_currencies = nil
                env.needed_currencies = nil
                return bret.SUCCESS
            end
    
            -- 检查列表长度是否一致
            if #owned_currencies ~= #needed_currencies then
                poe2_api.dbgp("错误：'我擁有的'和'我需要的'列表长度不一致")
                return bret.FAIL
            end
    
            -- 1. 检查并修正左边通货（严格按索引匹配）
            local left_status, selected_currency_left = _verify_left_currency(needed_currencies[current_pair_index + 1])  -- Lua数组从1开始
            poe2_api.dbgp("left_status:", tostring(left_status), "selected_currency_left:", selected_currency_left)
            if not left_status then
                poe2_api.dbgp("左边通货选择失败，跳过当前对")
                env.current_pair_index = current_pair_index + 1
                return bret.RUNNING
            end
            poe2_api.dbgp("左左左左左左左左左左左左左左左左左左左左左左左左左左左左左左左")
            api_Sleep(1000)
            -- 2. 检查并修正右边通货（严格按索引匹配）
            local right_status, selected_currency_right = _verify_right_currency(owned_currencies[current_pair_index + 1])
            poe2_api.dbgp("right_status:", tostring(right_status), "selected_currency_right:", selected_currency_right)
            if not right_status then
                poe2_api.dbgp("右边通货选择失败，跳过当前对")
                env.current_pair_index = current_pair_index + 1
                return bret.RUNNING
            end
            poe2_api.dbgp("右右右右右右右右右右右右右右右右右右右右右右右右右右右右右右右")
            api_Sleep(1000)
    
            -- 3. 获取当前通货数量
            local have_amount = _get_currency_amount(selected_currency_right)
            poe2_api.dbgp("当前通货数量:", selected_currency_right, "=", have_amount)
            
            if have_amount == 0 then
                poe2_api.dbgp("通货数量为0，跳过当前对")
                env.current_pair_index = current_pair_index + 1
                return bret.RUNNING
            end
    
            -- 4. 获取实时市场比例（左边:需要的，右边:拥有的）
            local current_ratio = _get_live_ratio()
            poe2_api.dbgp("获取实时市场比例  ", current_ratio)
            if not current_ratio then
                poe2_api.dbgp("无法获取市场比例，跳过当前对")
                env.current_pair_index = current_pair_index + 1
                return bret.RUNNING
            end
            poe2_api.dbgp("当前市场比例:", current_ratio[1], ":", current_ratio[2])
    
            -- 5. 计算最优兑换量（使用当前比例）
            local adjusted_ratio, exact_units = _calculate_optimal_exchange(have_amount, current_ratio)
            poe2_api.dbgp("计算最优兑换量 - 调整后比例:", adjusted_ratio[1], ":", adjusted_ratio[2], " 最小单位:", exact_units[1], ":", exact_units[2])
            
            if adjusted_ratio[1] == 0 and adjusted_ratio[2] == 0 then
                poe2_api.dbgp("无法计算有效兑换比例，跳过当前对")
                env.current_pair_index = current_pair_index + 1
                return bret.RUNNING
            end
    
            -- 6. 执行兑换
            local exchange_result = _execute_exchange(adjusted_ratio)
            poe2_api.dbgp("兑换执行结果:", exchange_result and "成功" or "失败")
            
            env.current_pair_index = current_pair_index + 1
            return bret.RUNNING
        end
    },

    -- 点击交互文本
    Click_Item_Text = {
        run = function(self, env)
            local current_time = api_GetTickCount64()
            local interactive_object = env.interactive
            local player_info = env.player_info
            local current_map_info = env.current_map_info
            
            local path_list = env.path_list
            local need_item = env.need_item
            
            local is_click_z = false
            
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
            
            local function need_move(obj)
                local text = obj.baseType_utf8 or obj.name_utf8
                local x, y
                if text == "門" then
                    x, y = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y, 15, 1)
                    local ralet = api_findPath(player_info.grid_x, player_info.grid_y, x, y)
                    if not ralet then
                        x, y = api_FindRandomWalkablePosition(obj.grid_x, obj.grid_y, 15)
                    end
                else
                    if not need_item then
                        point = api_FindNearestReachablePoint(obj.grid_x, obj.grid_y, 50, 0)
                        x, y = point.x, point.y
                    else
                        x, y = obj.grid_x, obj.grid_y
                    end
                end
                local distance = poe2_api.point_distance(x, y, player_info)
                if distance and distance > 15 then
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
                
                if need_move(target_obj) then
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
            end
            return bret.RUNNING
        end
    },

    -- 对话鉴定NPC
    Dialogue_Appraisal_NPC = {
        run = function(self, env)
            poe2_api.print_log("对话鉴定NPC...")
            
            local player_info = env.player_info
            local attack_dis_map = env.map_level_dis
            local stuck_monsters = env.stuck_monsters
            local not_attack_mos = env.not_attack_mos
            local config = env.user_config
            
            local current_map_info = env.current_map_info
            
            local config_name = env.item_config_name
            local config_type = env.item_config_type
            
            if not poe2_api.table_contains(player_info.current_map_name_utf8, my_game_info.hideout) then
                return bret.SUCCESS
            end

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
                -- poe2_api.dbgp("开始转换配置类型...")
                
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
                
                -- poe2_api.dbgp("配置类型转换完成")
                return converted_dict
            end

            -- 转换配置类型
            -- poe2_api.dbgp("开始转换主配置类型...")
            config_type = convert_config_type(config_type)
            -- poe2_api.dbgp(string.format("转换后配置类型条目数: %d", table.count(config_type)))

            if poe2_api.find_text({UI_info = env.UI_info, text = "繼續遊戲", click = 2}) then
                poe2_api.dbgp("发现'繼續遊戲'文本，点击处理中...")
                return bret.RUNNING
            end

            local appraisal_item_list = {}

            local function need_appraisal(bag_info)
                if not bag_info then
                    poe2_api.dbgp("背包信息为空")
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
                                -- base_type, bag.baseType_utf8 or "nil"))
                
                            if bag.baseType_utf8 ~= base_type and base_type ~= "全部物品" then
                                -- poe2_api.dbgp("-> 基础类型不匹配，跳过")
                                goto continue
                            end
                            -- poe2_api.dbgp("-> 基础类型匹配通过")
                
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
                                -- poe2_api.dbgp("-> 品质不匹配，跳过")
                                goto continue
                            end
                            -- poe2_api.dbgp("-> 品质检查通过")
                
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
                                    -- poe2_api.dbgp("[词缀检查] 发现词缀配置")
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
                    -- poe2_api.dbgp("\n=== 开始名称配置匹配 ===")
                    if not config_name then
                        -- poe2_api.dbgp("[警告] config_name 配置表不存在")
                    else
                        for config_name, item_config in pairs(config_name) do
                            -- poe2_api.dbgp(string.format("\n[检查名称配置组] %s", config_name))
                            
                            for idx, item in ipairs(item_config) do
                                -- poe2_api.dbgp(string.format("[检查配置项] 序号: %d", idx))
                                
                                if type(item) == "table" then
                                    -- poe2_api.dbgp(string.format("[基础类型比较] 配置: %s | 物品: %s",
                                        -- item["基礎類型名"] or "nil", bag.baseType_utf8 or "nil"))
                                    
                                    if item["基礎類型名"] == bag.baseType_utf8 then
                                        -- poe2_api.dbgp("-> 基础类型匹配")
                                        
                                        local type_ok = true
                                        if item["類型"] and item["類型"][1] then
                                            type_ok = (item["類型"][1] == bag.category_utf8)
                                            -- poe2_api.dbgp(string.format("[类型比较] 配置: %s | 物品: %s | 结果: %s",
                                            --     item["類型"][1], bag.category_utf8 or "nil",
                                            --     type_ok and "匹配" or "不匹配"))
                                        end
                                        
                                        if type_ok then
                                            -- poe2_api.dbgp("-> 所有条件匹配，返回配置")
                                            -- poe2_api.dbgp(string.format("[匹配成功] 配置详情:\n%s", poe2_api.table_to_string(item)))
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
                -- poe2_api.dbgp("开始扫描背包物品...")
                
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
                        -- poe2_api.dbgp("特殊类别物品，直接加入鉴定列表")
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
                                    -- poe2_api.dbgp(string.format("发现有效词缀: %s", affix_name))
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
            local total_items_to_identify = poe2_api.items_not_identified(bag_info)

            -- poe2_api.dbgp("开始检查是否需要鉴定...",#items_to_identify,"-->",#total_items_to_identify)

            if not items_to_identify or (#items_to_identify ~= #total_items_to_identify) then
                poe2_api.dbgp("当前没有需要鉴定的物品 或者背包有不需要鉴定的物品")
                if poe2_api.find_text({UI_info = env.UI_info, text = "鑑定物品"}) and not env.is_shop then
                    poe2_api.dbgp("发现鑑定物品界面且不在商店，点击关闭")
                    poe2_api.find_text({UI_info = env.UI_info, text = "再會", click = 2})
                    api_Sleep(100)
                end
                return bret.SUCCESS
            else
                env.interactive = "多里亞尼"
                map_obj = poe2_api.check_in_map(current_map_info,env.interactive)
                range_obj = poe2_api.check_in_range(env.interactive)
                target_obj = map_obj or range_obj or nil
                poe2_api.dbgp(target_obj)
                if target_obj then
                    distance = poe2_api.point_distance(target_obj.grid_x,target_obj.grid_y,player_info)
                    poe2_api.dbgp("distance",distance)
                    if distance and distance > 25 then
                        poe2_api.dbgp("交互",env.interactive)
                        return bret.FAIL
                    else
                        api_Sleep(1000)
                        if not poe2_api.find_text({UI_info = env.UI_info, text = "鑑定物品",click=2}) then
                            poe2_api.find_text({UI_info = env.UI_info, text = "多里亞尼",click=2})
                            api_Sleep(500)
                            return bret.RUNNING
                        end
                    end
                else
                    poe2_api.dbgp("当前没有多里亞尼")
                    return bret.FAIL
                end
            end
        end
    },

    -- 是否需要合成
    Is_Need_Conflate = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Is_Need_Conflate 检查")
            local bag_info = env.bag_info
            local map_info = env.current_map_info
            local config = env.user_config
            local need_synthesis = config["全局設置"]["刷图通用設置"]["自動合成地圖"]
            
            poe2_api.dbgp("自动合成地图设置:", need_synthesis)
            
            if not need_synthesis then
                poe2_api.dbgp("自动合成未开启，返回FAIL")
                return bret.SUCCESS
            end
            
            -- 检查宝藏金锤是否激活
            local hammer_active = nil
            if map_info then
                for _, item in ipairs(map_info) do
                    if item.name_utf8 == "TreasureVaultHammerActive" and item.flagStatus1 == 1 then
                        hammer_active = item
                        break
                    end
                end
            end
            
            local function check_in_range(object)
                for _, k in ipairs(env.range_info) do
                    if object then
                        if k.name_utf8 == object or k.path_name_utf8 == object then
                            return k
                        end
                    end
                end
                return false
            end

            hammer_active_range = check_in_range("重鑄台")
            
            if not hammer_active and not hammer_active_range then
                poe2_api.dbgp("重铸台未激活")
                return bret.SUCCESS
            end
            
            -- 检查是否可以合成
            local function check_synthesis_possible(bag_info)
                poe2_api.dbgp("开始检查合成可能性")
                local item_counts = {}
                
                if bag_info then
                    for _, item in ipairs(bag_info) do
                        if item.baseType_utf8 and string.find(item.baseType_utf8, "地圖鑰匙") 
                           and not item.contaminated and not item.not_identified 
                           and item.baseType_utf8 ~= "地圖鑰匙（階級 15）" 
                           and item.baseType_utf8 ~= "地圖鑰匙（階級 16）" then
                            item_counts[item.baseType_utf8] = (item_counts[item.baseType_utf8] or 0) + 1
                        end
                    end
                end
                
                poe2_api.dbgp("地图钥匙统计:", item_counts)
                
                -- 检查是否有至少3个相同的物品
                for _, count in pairs(item_counts) do
                    if count >= 3 then
                        poe2_api.dbgp("找到可合成的地图钥匙")
                        return true
                    end
                end
                
                poe2_api.dbgp("未找到足够的地图钥匙进行合成")
                return false
            end
            
            if not check_synthesis_possible(bag_info) then
                if poe2_api.find_text({UI_info = env.UI_info, text = "重鑄台", min_x = 0}) 
                   and poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0}) then
                    poe2_api.dbgp("关闭重铸台界面")
                    poe2_api.click_keyboard("space")
                end
                return bret.SUCCESS
            end
            
            poe2_api.dbgp("满足合成条件，返回FAIL")
            return bret.FAIL
        end
    },

    -- 打开合成界面
    Open_Conflate_page = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Open_Conflate_page - 打开合成界面")
            local current_time = api_GetTickCount64()
            local bag_info = env.bag_info
            local map_info = env.current_map_info
            local player_info = env.player_info
            local config = env.user_config
            
            
            
            -- 检查重铸台是否激活
            local hammer_active = nil
            if map_info then
                for _, item in ipairs(map_info) do
                    if item.name_utf8 == "TreasureVaultHammerActive" and item.flagStatus1 == 1 then
                        hammer_active = item
                        break
                    end
                end
            end

            local function check_in_range(object)
                if not env.range_info then
                    return false
                end
                for _, k in ipairs(env.range_info) do
                    if object then
                        if k.name_utf8 == object or k.path_name_utf8 == object then
                            return k
                        end
                    end
                end
                return false
            end

            hammer_active_range = check_in_range("重鑄台")
            
            if not hammer_active and not hammer_active_range then
                poe2_api.dbgp("重铸台未激活")
                return bret.SUCCESS
            end
            
            -- 检查是否可以合成
            local function check_synthesis_possible(bag_info)
                poe2_api.dbgp("检查合成可能性")
                local item_counts = {}
                
                if bag_info then
                    for _, item in ipairs(bag_info) do
                        if item.baseType_utf8 and string.find(item.baseType_utf8, "地圖鑰匙") 
                        and not item.contaminated and not item.not_identified 
                        and item.baseType_utf8 ~= "地圖鑰匙（階級 15）" then
                            item_counts[item.baseType_utf8] = (item_counts[item.baseType_utf8] or 0) + 1
                        end
                    end
                end
                
                poe2_api.dbgp("地图钥匙统计:", item_counts)
                
                -- 检查是否有至少3个相同的物品
                for _, count in pairs(item_counts) do
                    if count >= 3 then
                        return true
                    end
                end
                return false
            end
            
            if not check_synthesis_possible(bag_info) then
                poe2_api.dbgp("未找到足够的地图钥匙进行合成")
                if poe2_api.find_text({UI_info = env.UI_info, text = "重鑄台", min_x = 0}) 
                and poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0}) then
                    poe2_api.dbgp("关闭重铸台界面")
                    poe2_api.find_text({UI_info = env.UI_info, 
                        text = "重鑄台",
                        click = 2,
                        add_x = 211,
                        min_x = 0
                    })
                end
                return bret.FAIL
            end
            
            -- 检查天赋重置界面
            if poe2_api.find_text({UI_info = env.UI_info, text = "重置天賦點數", min_x = 0}) 
            and poe2_api.find_text({UI_info = env.UI_info, text = "返還輿圖天賦", min_x = 0}) then
                poe2_api.dbgp("关闭天赋重置界面")
                poe2_api.find_text({UI_info = env.UI_info, text = "再會", click = 2})
                return bret.RUNNING
            end
            
            -- 尝试打开合成界面
            if not (poe2_api.find_text({UI_info = env.UI_info, text = "重鑄台", min_x = 0}) and poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0})) then
                poe2_api.dbgp("未找到合成界面，设置交互对象为重铸台")
                env.interactive = "重鑄台"
                return bret.SUCCESS
            else
                poe2_api.dbgp("合成界面已打开，返回")
                return bret.FAIL
            end
        end
    },

    -- 点击物品进行合成
    Click_On_The_Item_To_Synthesize = {
        run = function(self, env)
            poe2_api.dbgp("开始执行 Click_On_The_Item_To_Synthesize")
            local map_info = env.current_map_info
            local bag_info = env.bag_info
            

            if not (poe2_api.find_text({UI_info = env.UI_info, text = "重鑄台", min_x = 0}) and poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0})) then
                poe2_api.dbgp("未找到合成界面，返回")
                return bret.RUNNING
            end
            
            -- 检查是否可以合成
            local function check_synthesis_possible(bag_info)
                poe2_api.dbgp("检查合成可能性")
                local item_counts = {}
                
                if bag_info then
                    for _, item in ipairs(bag_info) do
                        if item.baseType_utf8 and string.find(item.baseType_utf8, "地圖鑰匙") 
                        and not item.contaminated and not item.not_identified 
                        and item.baseType_utf8 ~= "地圖鑰匙（階級 15）" then
                            item_counts[item.baseType_utf8] = (item_counts[item.baseType_utf8] or 0) + 1
                        end
                    end
                end
                
                poe2_api.dbgp("地图钥匙统计:", item_counts)
                -- 检查是否有至少3个相同的物品
                for _, count in pairs(item_counts) do
                    if count >= 3 then
                        return true
                    end
                end
                return false
            end
            
            if not check_synthesis_possible(bag_info) then
                poe2_api.dbgp("未找到足够的地图钥匙进行合成")
                if poe2_api.find_text({UI_info = env.UI_info, text = "重鑄台", min_x = 0}) 
                and poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0}) then
                    poe2_api.dbgp("关闭重铸台界面")
                    poe2_api.click_keyboard("space")
                end
                return bret.FAIL
            end
            
            -- 罗马数字验证函数
            local function is_valid_roman_numeral(s)
                local roman_to_int_map = {
                    I = 1, V = 5, X = 10, L = 50,
                    C = 100, D = 500, M = 1000
                }
                
                local total = 0
                for i = 1, #s do
                    if not roman_to_int_map[s:sub(i,i)] then
                        return false
                    end
                end
                
                local i = 1
                while i <= #s do
                    if i + 1 <= #s and roman_to_int_map[s:sub(i,i)] < roman_to_int_map[s:sub(i+1,i+1)] then
                        total = total + roman_to_int_map[s:sub(i+1,i+1)] - roman_to_int_map[s:sub(i,i)]
                        i = i + 2
                    else
                        total = total + roman_to_int_map[s:sub(i,i)]
                        i = i + 1
                    end
                end
                
                return total >= 1 and total <= 15
            end
            
            -- 获取所有物品名称并统计出现次数
            local item_counts = {}
            local item_counts_infos = {}
            if bag_info then
                for _, actor in ipairs(bag_info) do
                    if not actor.not_identified and actor.baseType_utf8 and string.find(actor.baseType_utf8, "地圖鑰匙") 
                    and not actor.contaminated and actor.baseType_utf8 ~= "地圖鑰匙（階級 15）" then
                        item_counts[actor.baseType_utf8] = (item_counts[actor.baseType_utf8] or 0) + 1
                        table.insert(item_counts_infos,actor)
                    end
                end
            end

            local ROMAN_NUMERALS = {
                "I", "II", "III", "IV", "V",
                "VI", "VII", "VIII", "IX", "X",
                "XI", "XII", "XIII", "XIV", "XV", "XVI"
            }
            -- 找到可以合成的物品名称
            for item_name, count in pairs(item_counts) do
                if count >= 3 then
                    poe2_api.dbgp("找到可合成的地图钥匙:", item_name, "数量:", count)
                    
                    -- 查找献祭按钮位置
                    local start_pos = poe2_api.find_text({UI_info = env.UI_info, text = "獻祭", position = 3})
                    if start_pos then
                        local start_x = start_pos[1] + 15
                        local start_y = start_pos[2] - 325
                        
                        poe2_api.find_text({UI_info = env.UI_info, text = ROMAN_NUMERALS, click = 4, min_x = start_x, min_y = start_y, max_y = 590, max_x = 1030})
                    end
                    
                    api_Sleep(80)
                    
                    -- 获取合成槽中的物品
                    local compositing_map = api_Getinventorys(0x48, 0)
                    if compositing_map then
                        -- 检查各个槽位并点击相应位置
                        for _, item in ipairs(compositing_map) do
                            if item.start_x == 0 and item.start_y == 0 then
                                poe2_api.find_text({UI_info = env.UI_info, 
                                    text = "獻祭", 
                                    click = 4,
                                    add_x = -107,
                                    add_y = -143
                                })
                                api_Sleep(80)
                            elseif item.start_x == 2 and item.start_y == 0 then
                                poe2_api.find_text({UI_info = env.UI_info, 
                                    text = "獻祭", 
                                    click = 4,
                                    add_y = -143
                                })
                                api_Sleep(80)
                            elseif item.start_x == 4 and item.start_y == 0 then
                                poe2_api.find_text({UI_info = env.UI_info, 
                                    text = "獻祭", 
                                    click = 4,
                                    add_x = 107,
                                    add_y = -143
                                })
                                api_Sleep(80)
                            end
                        end
                    end
                    
                    poe2_api.dbgp("准备合成:", item_name)

                    -- 筛选出名称相同的物品
                    if item_counts_infos then
                        local clicked_count = 0  -- 已点击计数器
                        
                        -- 遍历所有物品信息
                        for _, item_info in ipairs(item_counts_infos) do
                            -- 检查物品名称是否匹配
                            if item_info.baseType_utf8 == item_name then

                                center = poe2_api.get_center_position({item_info.start_x,item_info.start_y},{item_info.end_x,item_info.end_y})
                                
                                -- 点击物品（两种方式可选）
                                -- 方式1：使用坐标点击
                                poe2_api.dbgp("点击物品:", item_name, "位置:", center[1], center[2])
                                poe2_api.ctrl_left_click(center[1], center[2])
                                
                                clicked_count = clicked_count + 1
                                api_Sleep(50)  -- 短暂延迟
                                
                                -- 点击满3次就停止
                                if clicked_count >= 3 then
                                    break
                                end
                            end
                        end
                        
                        if clicked_count < 3 then
                            poe2_api.dbgp("警告: 只找到", clicked_count, "个", item_name, "无法完成合成")
                        end
                    end

                    api_Sleep(500)

                    if not poe2_api.find_text({UI_info = env.UI_info, text = '獻祭', click=2, min_x = 0}) then
                        return bret.RUNNING
                    end
                    
                    api_Sleep(1000)

                    -- 处理合成后的物品
                    poe2_api.find_text({UI_info = env.UI_info, 
                        text = "摧毀三個相似的物品，重鑄為一個新的物品",
                        click = 4,
                        add_y = 140,
                        min_x = 0
                    })
                    api_Sleep(100)
                    
                    poe2_api.dbgp("合成操作完成:", item_name)
                    return bret.SUCCESS
                end
            end
            
            -- 如果没有找到可合成的物品，关闭重铸台界面
            if poe2_api.find_text({UI_info = env.UI_info, text = "重鑄台", min_x = 0}) 
            and poe2_api.find_text({UI_info = env.UI_info, text = "摧毀三個相似的物品，重鑄為一個新的物品", min_x = 0}) then
                poe2_api.find_text({UI_info = env.UI_info, 
                    text = "重鑄台",
                    click = 2,
                    add_x = 211,
                    min_x = 0
                })
            end
            
            return bret.SUCCESS
        end
    },

    -- 存储物品(动作)
    Store_Items = {
        run = function(self, env)
            poe2_api.print_log("执行存储物品动作...")
            return bret.SUCCESS
        end
    },

    -- 购买地图
    Shop_maps = {
        run = function(self, env)
            poe2_api.print_log("购买地图...")
            return bret.SUCCESS
        end
    },

    -- 检查是否到达点(别名)
    Is_Arrive = {
        run = function(self, env)
            poe2_api.print_log("检查是否到达目标点(Is_Arrive)...")
            local player_info = env.player_info
            local is_arrive_end_dis = 15 -- 默认值

            if player_info.life == 0 then
                env.end_point = nil
                env.run_point = nil
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
            local path_list = env.path_list
            dis = poe2_api.point_distance(point[1], point[2], player_info)
            if point and dis and ( dis < is_arrive_end_dis ) then
                env.is_arrive_end = true
                env.end_point = nil
                env.run_point = nil
                if env.target_point then
                    api_ClickMove(poe2_api.toInt(env.target_point[1]), poe2_api.toInt(env.target_point[2]),poe2_api.toInt(player_info.world_z), 9)
                end
                return bret.RUNNING
            else
                env.is_arrive_end = false
                return bret.SUCCESS
            end
        end
    },

    -- 获取路径
    GET_Path = {
        initialize = function(self)
            self.last_point = nil
            self.FAIL_count = 0 -- 路径计算失败计数器
        end,

        run = function(self, env)
            poe2_api.print_log("获取路径...")
            local start_current_time = api_GetTickCount64()

            local player_info = env.player_info
            

            -- 辅助函数：检测祭坛
            -- local function get_altar(range_info)
            --     for _, entity in ipairs(env.range_info) do
            --         if entity.path_name_utf8 ==
            --             "Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable" and
            --             entity.stateMachineList.current_state == 2 and
            --             entity.stateMachineList.interaction_enabled == 0 then
            --             return entity
            --         end
            --     end
            --     return nil
            -- end
            
            -- 检查终点是否存在
            local point = env.end_point
            if not point then
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
                return bret.SUCCESS
            end
            
            -- 计算最近可到达的点
            point = api_FindNearestReachablePoint(point[1],point[2], 50, 0)
            poe2_api.dbgp("计算最近可到达的点")
            poe2_api.dbgp(point.x, point.y)
            poe2_api.dbgp("yuasnhi")
            poe2_api.dbgp(env.end_point[1],env.end_point[2])

            -- 计算起点
            player_position = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y, 50, 0)

            local result = api_FindPath(player_position.x, player_position.y, point.x, point.y)
            
            if result and #result > 0 then
                -- 处理路径结果
                result = poe2_api.extract_coordinates(result, 18)
                if #result > 1 then
                    table.remove(result, 1) -- 移除起点
                    poe2_api.dbgp("移除起点")
                    env.path_list = result
                    env.target_point = {result[1].x, result[1].y}
                    poe2_api.dbgp("[GET_Path] 路径计算成功，点数: " .. #result)
                end
                poe2_api.time_p("处理路径结果 耗时 -->", api_GetTickCount64() - start_current_time)
                return bret.SUCCESS
            else
                -- 路径计算失败处理
                -- local altar = get_altar()
                -- if altar then
                --     if poe2_api.point_distance(altar.grid_x, altar.grid_y,player_info) > 110 then
                --         poe2_api.af_api.api_RestoreOriginalMap()
                --     end
                -- else
                --     poe2_api.af_api.api_RestoreOriginalMap()
                -- end
                if self.FAIL_count == nil then
                    self.FAIL_count = 0
                end
                self.FAIL_count = self.FAIL_count + 1
                env.find_path_FAIL = self.FAIL_count
                poe2_api.dbgp("[GET_Path] 错误：找不到路径 --> " , point[1], ",", point[2])
                player_position = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y, 50, 0)
                api_ClickMove(poe2_api.toInt(player_position.x), poe2_api.toInt(player_position.y), poe2_api.toInt(player_info.world_z), 7)
                poe2_api.click_keyboard("space")
                poe2_api.time_p("错误：找不到路径 耗时 -->", api_GetTickCount64() - start_current_time)
                env.path_list = nil
                env.target_point = {}
                env.is_arrive_end = true
                env.end_point = {}
                return bret.RUNNING
            end
        end
    },

    -- 点击移动
    Move_To_Target_Point = {
        run = function(self, env)
            -- 初始化逻辑直接放在 run 函数开头
            
            if not self.last_move_time then
                poe2_api.dbgp("初始化 Move_To_Target_Point 节点...")
                self.last_move_time = api_GetTickCount64()
                self.last_point = nil
                return bret.RUNNING  -- 初始化后返回 RUNNING，等待下一帧继续执行
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
                    env.path_list = nil
                    env.target_point = {}
                    env.is_arrive_end = true
                    env.end_point = {}
                    return bret.RUNNING
                end
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
                    env.path_list = nil
                    env.target_point = {}
                    env.is_arrive_end = true
                    env.end_point = {}
                    return bret.RUNNING
                end
            end
            
            -- 执行移动（按时间间隔）
            if current_time - self.last_move_time >= move_interval * 1000 then
                if point then
                    local dis = poe2_api.point_distance(point[1], point[2], player_info)
                    if dis and dis > 70 then
                        env.path_list = nil
                        env.target_point = {}
                        env.is_arrive_end = true
                        env.end_point = {}
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
                if dis and dis < 20 then
                    if env.path_list and #env.path_list > 0 then
                        env.target_point = {env.path_list[1].x, env.path_list[1].y}
                        -- poe2_api.dbgp("len 5604 移除已使用的点")
                        table.remove(env.path_list, 1)
                    end
                    return bret.RUNNING
                end
            end
    
            return bret.RUNNING
        end
    }
}

local all_nodes = {}
for k, v in pairs(base_nodes) do all_nodes[k] = v end
for k, v in pairs(custom_nodes) do all_nodes[k] = v end

-- 注册自定义节点
local behavior_node = require 'behavior3.behavior_node'
behavior_node.process(all_nodes)

-- 创建行为树环境
local env_params = {
    -- 可以在这里添加需要的环境变量
    user_config = nil, -- 用户配置
    user_info = nil, -- 用户信息
    user_map = nil, -- 地图
    player_class = nil, -- 職業
    player_spec = nil, -- 专精
    space = nil, -- 躲避
    space_monster = nil, -- 躲避怪物
    space_time = nil, -- 躲避时间
    protection_settings = nil, -- 普通保護設置
    emergency_settings = nil, -- 紧急設置
    login_state = nil, -- 登录状态，初始值为nil
    speel_ip_number = 0, -- 設置当前IP地址的数量，初始值为0
    is_game_exe = false, -- 游戏是否正在执行，初始值为false
    shouting_number = 0, -- 喊话次数，初始值为0
    area_list = {}, -- 存储区域列表，初始值为空列表
    account_state = nil, -- 账户状态，初始值为nil
    switching_lines = 0, -- 线路切换状态，初始值为0
    time_out = 0, --  超时时间，初始值为0
    skill_name = nil, -- 当前技能名称，初始值为nil
    skill_pos = nil, -- 当前技能位置，初始值为nil
    is_need_check = false, -- 是否需要检查，初始值为false
    item_name = nil, -- 当前物品名称，初始值为nil
    item_pos = nil, -- 当前物品位置，初始值为nil
    -- blackboard.set("user_config", parser)  # 用户配置
    check_all_points = false, -- 是否检查所有点，初始值为false
    path_list = {}, -- 存储路径列表，初始值为空列表
    empty_path = false, -- 路径是否为空，初始值为false
    boss_name = my_game_info.boss_name,  -- 当前boss名称，初始值为nil
    map_name = nil, -- 当前地图名称，初始值为nil
    interaction_object = nil, -- 交互对象，初始值为nil
    item_move = false, -- 物品是否移动，初始值为false
    item_end_point = {0, 0}, -- 物品的终点位置，初始值为[0, 0]
    ok = false, -- 是否确认，初始值为false
    not_need_wear = false, -- 是否不需要装备，初始值为false
    currency_check = false, -- 是否进行货币检查，初始值为false
    sell_end_point = {0, 0}, -- 卖物品的终点位置，初始值为[0,0]
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
    no_item_wear = false,
    my_role = nil,
    is_set = false,
    end_point = {0,0},
    teleport_area = nil,
    teleport = nil,
    follow_role = nil,
    map_count = 0,
    task_name = nil,
    subtask_name = nil,
    special_map_point = nil, -- 第二章任务地圖特殊點
    mate_info = nil, -- 已死队员信息信息
    monster_info = nil, -- 怪物信息
    bag_info = nil, -- 背包信息
    range_item_info = nil, -- 周围装备信息
    shortcut_skill_info = nil, -- 快捷栏技能信息
    allskill_info = nil, -- 全部技能信息
    selectableskill_info = nil, -- 可选技能技能控件信息
    skill_gem_info = nil, -- 技能宝石列表信息
    team_info = nil, -- 获取队伍信息
    player_info = nil, -- 人物信息
    skill_number = 0, -- 放技能次数
    path_bool = false, -- 跟隨超距離判斷
    interaction_object_map_name = nil,
    not_need_active = false,
    target_point = {},
    grid_x = nil,
    grid_y = nil,
    target_point_follow = nil,
    is_timeout = false,
    special_relife_point = false,
    need_identify = false,
    one_other_map = nil,
    current_map_info = nil,
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
    last_exception_time = nil,
    need_ReturnToTown = false,
    need_SmallRetreat = false,
    -- waypoint = poe2_api.af_api.api_GetTeleportationPoints(),
    retry_count = 0,
    last_retreat_time = 0,
    is_arrive_end_dis = nil,
    map_level_dis = nil,
    is_have_map = nil,
    is_strengthened_map = true, -- 是否需要强化地图
    strengthened_map_obj = nil, -- 地图强化对象22
    chapter_name = nil, -- 章节名称
    target_chapter_name = nil, -- 传送地图名
    tar_clear_name = nil,

    -- 是否需要滴注
    dist_ls  = false, --- 是否需要滴注
    dizhu_end = false, -- 滴注操作
    is_need_strengthen = false, -- 是否需要合成
    priority_map = nil, -- 優先打地圖詞綴
    is_over = false , -- 是否完成滴注
    refining_list = {}, --精炼列表
    key_level = nil, -- 钥匙等级
    check_map_key = false, -- 点击地图钥匙
    exists_key = false, -- 存在地图钥匙
    map_key_name = nil, -- 地图钥匙名
    missing_refinement = {},-- # 缺少的精炼
    is_refinement = nil, --是否精炼
    key_ok = false, -- 钥匙是否可用
    warehouse_type = nil, -- 仓库类型（滴注）
    formula_list = {}, -- 配方列表（滴注）
    -- not_use_map = config['刷圖設置']["異界地圖"]["不打地圖詞綴"],
    -- -- 玩法優先級
    -- map_priority = config["刷圖設置"]["玩法優先級"],
    -- map_sorted_items = sorted((k, v) for k, v in map_priority.items() if v and type(v) == int),
    -- map_sorted_items_sort = sorted(map_sorted_items, key=lambda x: x[1]),
    -- map_sorted_keys = [item[0] for item in map_sorted_items_sort if item[1] > 0],
    -- -- 玩法順序是否開啓
    -- if map_priority.get('是否開啟') then
    --     blackboard.set("sorted_map",map_sorted_keys)
    -- else
    --     blackboard.set("sorted_map",nil)
    -- end
    sorted_map = nil,

    -- 碑牌順序
    -- play_priority = config["刷圖設置"]["碑牌優先級"],
    -- -- 根据值排序并排除值为0的元素
    -- sorted_items = sorted((k, v) for k, v in play_priority.items() if v and type(v) == int),
    -- sorted_items_sort = sorted(sorted_items, key=lambda x: x[1]),
    -- -- 只保留键,
    -- sorted_keys = [item[0] for item in sorted_items_sort],
    -- result = [my_game_info.map_type[key] for key in sorted_keys if key in my_game_info.map_type],
    -- -- 是否需要插入碑牌
    -- blackboard.set("is_insert_stone",play_priority.get('是否開啟')),
    -- -- 插牌顺序
    -- blackboard.set("stone_order",result),
    stone_order = nil,
    is_insert_stone = nil,

    not_exist_stone = nil, -- 不存在的碑牌
    is_have_stone = nil, -- 是否有可插入的塔
    stone_info = nil, -- 塔信息
    not_use_stone = {}, -- 无用之塔
    -- is_insert_stone = nil,
    enter_map_click_counter = 0,
    is_get_plaque = false, -- 是否需要取碑牌
    is_find_boss = false, -- 是否找到boss記錄點
    not_interactive = nil, -- 不交互對象
    afoot_altar = nil, -- 进行中的祭坛
    center_radius = 0, -- 半径
    center_point = {}, -- 中心点
    run_point = nil, -- 逃跑點
    valid_monsters = nil, -- 最近怪物
    stuck_monsters = nil,
    -- 人物自身装备 --
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
    pick_up_number = 0, -- 取碑牌数量
    is_public_warehouse = true, -- 共倉點金是否存儲
    is_get_plaque_node = true, -- 取碑牌节点，专用是否需要取碑牌
    launch_timeout = 0, -- 启动超时
    min_attack_range = nil,
    is_public_warehouse_plaque = true, -- 共倉點金碑牌是否存儲
    afoot_box = nil, -- 进行中的保险箱
    entry_length_take_map = false,
    the_update_map = nil,
    map_update_to = nil,
    amplification_use_count = 0, -- 增幅使用次数
    supreme_use_count = 0, -- 崇高使用次数
    map_up = false,
    sacrificial_refresh = 0,
    have_ritual = false,
    last_position_time = nil,
    last_position = nil,
    boss_drop = false, -- 等待boss掉落
    esc_click = 0,
    error_kill = false,
    error_other_map = {},
    available_oils = nil,
    missing_oils = nil,
    oil_map = nil,
    last_exp_check_move = 0,
    last_exp_value_move = 0,
    last_exception_time_move = 0,

    interactiontimeout = 0, -- 记录交互超时时间
    available_configs = nil,
    find_path_FAIL = 0,

    false_times = 0,
    not_have_stackableCurrency = false,
    is_update_plaque = false, -- 是否强化碑牌
    boss_drop_time = 0, -- 等待boss掉落时间
    is_dizhu = false,
    take_rest = false,
    minimap_info = nil, -- 小地图对象记录
    buy_items = false,
    kill_process = false,
    boss_id_list = {}, -- 已等bossID列表
    drop_items = false, -- 回城时丢弃
    exchange_ratio = nil, -- 通货兑换组
    currency_ratios = {}, -- 物品对应数量组
    enough_currency = true, -- 是否足够兑换
    -- 兑换列表
    owned_currencies = {}, -- 拥有
    needed_currencies = {}, -- 需要
    E_D_ratio = nil, -- E_D比例
    prestore_list = {}, -- 预存列表
    C_D_ratio = nil, -- C_E
    return_town = false, -- 回城
    map_start_time = nil, -- 地图开始时间

    error_back = false, -- 意外退出
    map_recorded = false, -- 地图状态记录
    mouse_check = false, -- 检查鼠标技能
    click_grid_pos = false, -- 补丁视角处理
    current_pair_index = 0, -- 初始化当前兑换索引
    last_execution_time = 0, -- 初始化当前兌換時間
    not_more_ritual = true, -- 取消后续祭坛
    warehouse_full = nil, -- 个仓某页是否已满
    exchange_status = false -- 是否兌換完成（存仓用）
}

-- 导出模块接口
local otherworld_bt = {}

-- 创建行为树
function otherworld_bt.create()
    -- 直接使用已定义的 env_params，并更新配置

    -- local bt = behavior_tree.new("out_id", env_params)
    -- local bt = behavior_tree.new("take_map", env_params)
    -- local bt = behavior_tree.new("attack_target", env_params)
    local bt = behavior_tree.new("attack_target", env_params)
    -- local bt = behavior_tree.new("moveTo", env_params)
    return bt
end

function sleep(n)
    if n > 0 then
        os.execute("ping -n " .. tonumber(n + 1) .. " localhost > NUL")
    end
end

-- -- 运行行为树
-- function otherworld_bt.run(bt)
--     poe2_api.dbgp("\n=== 游戏Tick开始 ===")
--     i = 0
--     while true do
--         poe2_api.dbgp("\n=== 游戏Tick", i, "===")
--         bt.run()
--         -- 模拟延迟
--         sleep(0.5)
--         i = i + 1
--     end
-- end

return otherworld_bt
