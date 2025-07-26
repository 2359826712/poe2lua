---@diagnostic disable: undefined-global
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
            env.not_use_map = config['刷圖設置']["異界地圖"]["不打地圖詞綴"]
            env.stone_order = result
            env.is_insert_stone = play_priority["是否開啟"]
            -- 滴注操作
            local map_cfg = config['刷圖設置']
            poe2_api.process_void_maps(map_cfg)
            env.dist_ls = config['刷圖設置']['異界地圖索引']['涂油设置']
            env.user_map = config['刷圖設置']['異界地圖']['地圖鑰匙']
            env.priority_map = config['刷圖設置']['異界地圖']['優先打地圖詞綴']
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
            local UI_info = {}
            local size =  UiElements:Update()
            -- poe2_api.print_log(size .. "\n")
            if size > 0 then
                local sum = 0;
                for i = 0, size - 1, 1 do
                    sum = sum + 1
                    table.insert(UI_info, UiElements[i])
                end
            else
                poe2_api.print_log("未发现UI信息\n")
                return bret.RUNNING
            end
            env.UI_info = UI_info
            return bret.SUCCESS
        end
    },

    -- 获取信息
    Get_Info = {
        run = function(self, env)

            -- 人物信息
            poe2_api.print_log("获取游戏信息...")
            local player_info = api_GetLocalPlayer()
            if not player_info then
                poe2_api.print_log("空人物信息")
                return bret.RUNNING
            end
            env.player_info = player_info

            -- 周围实体信息
            local size = Actors:Update()
            local range_info = {}
            if size > 0 then
                -- poe2_api.print_log(size .. "\n")
                local sum = 0;
                for i = 0, size - 1, 1 do
                    sum = sum + 1
                    table.insert(range_info, Actors[i])
                end
                env.range_info = range_info
            else
                poe2_api.print_log("未发现周围对象\n")
            end

            -- 周围装备信息
            local size = WorldItems:Update()
            local range_items = {}
            if size > 0 then
                -- poe2_api.print_log(size .. "\n")
                local sum = 0;
                for i = 0, size - 1, 1 do
                    sum = sum + 1
                    table.insert(range_items, WorldItems[i])
                end
                env.range_item_info = range_items
            else
                poe2_api.print_log("未发现周围装备信息\n")
            end
            
            -- 背包信息（主背包）
            local inventory = api_Getinventorys(1,0)
            env.bag_info = inventory
            if not self.wear_items then 
                self.wear_items = true
            end
            -- 其他物品栏信息（批量处理）
            if not self.wear_items then
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
                self.wear_items = true
            end

            -- 小地图信息
            local current_map_info = api_GetMinimapActorInfo()
            env.current_map_info = current_map_info

            return bret.SUCCESS
        end
    },
    -- 清除聊天信息
    Clear = {
        name = "清除聊天信息",
        last_move_time = 0,
        move_interval = math.random(1, 2),  -- 随机间隔初始化
        time = 0,
        bool = false,
        
        run = function(self, env)
            local current_time = os.time()
            if self.time == 0 then
                self.time = current_time
            end
            
            local player_info = env.player_info
            if not player_info then
                return bret.RUNNING
            end
            
            local current_map_info_copy = env.current_map_info_copy or {}
            
            -- Find MapDevice in current map
            local map_device = nil
            for _, item in ipairs(current_map_info_copy) do
                if item.name_utf8 == "MapDevice" then
                    map_device = item
                    break
                end
            end
            
            -- Check if in town or hideout with MapDevice
            if not string.find(player_info.current_map_name_utf8, "town") and 
            (not my_game_info.hideout[player_info.current_map_name_utf8] or not map_device) then
                self.bool = false
                
                return bret.SUCCESS
            end
            
            if not self.bool and player_info.life ~= 0 and not env.poe2_api.click_text_UI_by_time("respawn_at_checkpoint_button") then
                if not env.poe2_api.find_text("/clear", 0) then
                    sleep(1)
                    env.poe2_api.click_keyboard("enter")
                    sleep(0.5)
                    env.poe2_api.paste_text("/clear")
                    sleep(0.5)
                    env.poe2_api.click_keyboard("enter")
                    sleep(0.5)
                    self.bool = true
                    
                    return bret.RUNNING
                end
                
                self.time = current_time
            end
            
            
            return bret.SUCCESS
        end
    },

    -- 休息控制
    RestController = {
        name = "休息控制",
        is_initialized = false,
        is_resting = false,
        next_state_change_time = 0,
        last_update_time = 0,
        work_duration = 0,
        rest_duration = 0,
        is_open = false,
        is_kill_game = false,
        
        init = function(self, env)
            -- 初始化计时器
            local config = env.user_config["全局設置"]["刷图通用設置"]["定時休息"] or {}
            
            -- 工作时间配置
            local base_work = config["運行時間"] or 1  -- 默认1小时
            local work_random_range = config["工作時間隨機範圍"] or 0.1
            self.work_duration = math.floor(base_work * (1 + math.random() * work_random_range * 2 - work_random_range) * 3600)
            
            -- 休息时间配置
            local base_rest = config["休息時間"] or (10/60)  -- 默认10分钟
            local rest_random_range = config["休息時間隨機範圍"]  or 0.1
            self.rest_duration = math.floor(base_rest * (1 + math.random() * rest_random_range * 2 - rest_random_range) * 3600)
            
            -- 功能开关
            self.is_open = config["是否開啟"]  or false
            self.is_kill_game = config["休息时是否关闭游戏"] or false
            
            -- 初始化状态
            self.is_resting = false
            self.next_state_change_time = os.time() + self.work_duration
            self.last_update_time = os.time()
            self.is_initialized = true
            
            env.feedback_message = string.format("开始工作周期，将在 %d 分钟后休息", self.work_duration/60)
            return bret.RUNNING
        end,
        
        handle_state_transition = function(self, env, current_time)
            self.is_resting = not self.is_resting
            local duration = self.is_resting and self.rest_duration or self.work_duration
            self.next_state_change_time = current_time + duration
            
            -- 更新环境状态
            env.take_rest = self.is_resting
            
            if self.is_resting then
                if not my_game_info.hideout[env.player_info.current_map_name_utf8] then
                    env.need_ReturnToTown = true
                    return bret.SUCCESS
                end
                
                -- 进入休息状态
                if self.is_kill_game then
                    env.error_kill = true
                end
                self:perform_rest_actions(env)
                env.feedback_message = string.format("工作时间到，开始休息 (%d分钟)", self.rest_duration/60)
                return bret.RUNNING
            else
                -- 返回工作状态
                env.error_kill = false
                env.feedback_message = string.format("休息结束，开始工作 (%d分钟)", self.work_duration/60)
                self.is_initialized = false
                return bret.SUCCESS
            end
        end,
        
        update_status = function(self, env, current_time)
            local time_remaining = math.max(0, self.next_state_change_time - current_time)
            
            if self.is_resting then
                if not my_game_info.hideout[env.player_info.current_map_name_utf8] then
                    env.need_ReturnToTown = true
                    return bret.SUCCESS
                end
                
                -- 休息状态更新（每分钟）
                self.last_update_time = current_time
                local mins = math.floor(time_remaining / 60)
                local secs = math.floor(time_remaining % 60)
                print(string.format("休息中... 剩余时间: %d分%d秒", mins, secs))
                env.take_rest = true
                
                local UI_info = nil
                if not (poe2_api.find_text("回到角色選擇畫面", UI_info) or 
                    poe2_api.click_text_UI("exit_to_character_selection", UI_info)) and
                    poe2_api.click_text_UI("life_orb", UI_info) and
                    poe2_api.click_text_UI("mana_orb", UI_info) then
                    poe2_api.click_keyboard("esc")
                end
                sleep(1)
                return bret.RUNNING
            else
                -- 工作状态更新（每5分钟）
                self.last_update_time = current_time
                local mins = math.floor(time_remaining / 60)
                local secs = math.floor(time_remaining % 60)
                print(string.format("工作中... 距离休息还有: %d分%d秒", mins, secs))
                env.take_rest = false
                return bret.SUCCESS
            end
        end,
        
        perform_rest_actions = function(self, env)
            -- 执行休息相关操作
            local success, err = pcall(function()
                local UI_info = nil
                if not (poe2_api.find_text("回到角色選擇畫面", UI_info) or 
                    env.poe2_api.click_text_UI("exit_to_character_selection", UI_info)) then
                    if env.poe2_api.click_text_UI("life_orb", UI_info) and
                    env.poe2_api.click_text_UI("mana_orb", UI_info) then
                        env.poe2_api.click_keyboard("esc")
                    end
                end
                sleep(1)
            end)
            
            if not success then
                env.feedback_message = "执行休息操作时出错: " .. tostring(err)
            end
        end,
        
        run = function(self, env)
            if not self.is_initialized then
                return self:init(env)
            end
            
            if not self.is_open then
                return bret.SUCCESS
            end
            
            local current_time = os.time()
            
            -- 状态切换检查
            if current_time >= self.next_state_change_time then
                return self:handle_state_transition(env, current_time)
            end
                
            -- 状态更新
            return self:update_status(env, current_time)
        end
    },

    -- 小撤退
    SmallRetreat = {
        name = "执行小撤退",
        last_action_time = 0,  -- 记录上次操作时间
        action_interval = 2,   -- 操作间隔时间
        error_kill_start_time = nil,  -- 超时计时器
        
        reset_states = function(self, env)
            -- 统一状态重置方法
            local current_time = os.time()
            env.last_exception_time = 0
            env.last_exp_check = current_time
            env.last_exp_value = env.player_info.currentExperience
            -- logger.debug("已重置所有监控状态")
        end,
        
        run = function(self, env)
            local current_time = os.time()
            local esc_click = env.esc_click

            -- 超时判断（10次点击约15秒）
            if self.error_kill_start_time and (current_time - self.error_kill_start_time) > 30 then
                print("小退超时")
                env.error_kill = true
                self.error_kill_start_time = nil  -- 重置计时器
                env.need_SmallRetreat = false
                
                return bret.RUNNING
            else
                env.error_kill = false
            end

            if env.need_SmallRetreat then
                local success, err = pcall(function()
                    env.path_list = nil
                    if current_time - self.last_action_time >= self.action_interval then
                        -- 点击返回
                        if env.poe2_api.find_text("回到角色選擇畫面", nil, 2) then
                            if not self.error_kill_start_time then
                                self.error_kill_start_time = current_time  -- 开始计时
                            end
                            sleep(6)
                            
                            return bret.RUNNING
                        
                        elseif poe2_api.click_text_UI("exit_to_character_selection", nil, 2) then
                            if not self.error_kill_start_time then
                                self.error_kill_start_time = current_time
                            end
                            sleep(6)
                            
                            return bret.RUNNING
                        end
                        -- 打开选项菜单
                        if not (poe2_api.find_text("回到角色選擇畫面", nil) or 
                            env.poe2_api.click_text_UI("exit_to_character_selection", nil)) and
                            env.poe2_api.click_text_UI("life_orb", nil) and
                            env.poe2_api.click_text_UI("mana_orb", nil) then
                            if not self.error_kill_start_time then
                                self.error_kill_start_time = current_time
                            end
                            env.poe2_api.click_keyboard("esc")
                            self.last_action_time = current_time + 2
                            
                            return bret.RUNNING
                        end

                        -- 成功执行后重置超时计时器
                        self.error_kill_start_time = nil
                        env.last_exp_check = current_time
                        env.last_exception_time = 0
                        env.need_SmallRetreat = false
                        self:reset_states(env)
                        
                        return bret.RUNNING
                    else
                        
                        return bret.RUNNING  -- 仍在运行状态，等待间隔
                    end
                end)
                
                if not success then
                    self.error_kill_start_time = nil  -- 异常时重置计时器
                    env.need_SmallRetreat = false
                    
                    return bret.FAILURE
                end
            else
                self.error_kill_start_time = nil  -- 不需要小退时重置计时器
                
                return bret.SUCCESS
            end
        end
    },

    -- 返回城镇
    ReturnToTown = {
        name = "返回城镇",
        timeout = 20,  -- 超时时间（秒）
        current_time = nil,  -- 行为开始时间
        
        reset_states = function(self, env)
            -- 统一状态重置方法
            local current_time = os.time()
            env.last_exception_time_move = 0
            env.last_exp_check_move = current_time
            env.last_exp_value_move = env.player_info.currentExperience
            -- logger.debug("已重置所有经验监控状态")
        end,
        
        spcify_monsters = function(self, range_info)
            if range_info then
                for _, monster in ipairs(range_info) do
                    if monster.name_utf8 == '巨蛇女王．瑪娜莎' and monster.life > 0 then
                        return true
                    end
                end
            end
            return false
        end,
        
        run = function(self, env)
            local current_time = os.time()
            local player_info = env.player_info
            local range_info = env.range_info
            local find_path_failure = env.find_path_failure or 0
            
            -- 初始化时间
            if not self.current_time then
                self.current_time = current_time
            end
            
            -- 检查是否超时
            if (current_time - self.current_time) > self.timeout then
                env.need_ReturnToTown = false
                env.need_SmallRetreat = true
                
                return bret.FAILURE
            end
            
            if my_game_info.hideout[player_info.current_map_name_utf8] then
                env.need_ReturnToTown = false
                env.find_path_failure = 0
            end
            
            if env.need_ReturnToTown or find_path_failure > 10 then
                env.path_list = nil
                if find_path_failure > 10 then
                    env.is_map_complete = true
                end
                
                local success, status = pcall(function()
                    if env.poe2_api.find_text("你無法在遊戲暫停時使用該道具。", nil, 0, 0) then
                        env.poe2_api.click_keyboard("space")
                        sleep(0.5)
                        if not env.poe2_api.find_text("/clear", 0) then
                            env.poe2_api.click_keyboard("enter")
                            sleep(0.5)
                            env.poe2_api.paste_text("/clear")
                            sleep(0.5)
                            env.poe2_api.click_keyboard("enter")
                            sleep(1)
                            
                            return bret.RUNNING
                        end
                    end
                    
                    if env.poe2_api.find_text("恩賜之物", nil, 0, 0) then
                        env.poe2_api.find_text("恩賜之物", nil, 0, 0, 2, 272)
                        
                        return bret.RUNNING
                    end
                    
                    if player_info.isInBossBattle then
                        env.need_ReturnToTown = false
                        env.need_SmallRetreat = true
                        
                        return bret.RUNNING
                    end
                    
                    if env.poe2_api.is_have_mos(range_info, player_info) or self:spcify_monsters(range_info) then
                        
                        return bret.SUCCESS
                    end
                    
                    if not string.find(player_info.current_map_name_utf8, "town") and not my_game_info.hideout[player_info.current_map_name_utf8] then
                        if env.poe2_api.find_text("傳送", 0, 700, 40, 830) then
                            env.poe2_api.click_keyboard("space")
                            
                            return bret.RUNNING
                        end
                        
                        for _, k in ipairs(range_info) do
                            if k.name_utf8 ~= '' and k.type == 5 and my_game_info.hideout_CH[k.name_utf8] then
                                if env.poe2_api.point_distance(k.grid_x, k.grid_y, player_info) < 25 then
                                    if not env.poe2_api.find_text(k.name_utf8, nil, 0, 0, 2) then
                                        env.poe2_api.af_api.api_click_move(k.grid_x, k.grid_y, k.world_z-100, 1)
                                    end
                                    
                                    return bret.RUNNING
                                end
                            end
                        end
                        
                        -- 点击传送
                        env.poe2_api.af_api.api_click_move(player_info.grid_x, player_info.grid_y, player_info.world_z, 3)
                        sleep(0.5)
                        env.poe2_api.natural_move(1230, 815, 25, 25)
                        sleep(0.2)
                        env.poe2_api.af_api.api_LeftClick()
                        sleep(1)
                        
                        return bret.RUNNING
                    else
                        local x, y = env.poe2_api.af_api.api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                        if x and y then
                            env.poe2_api.af_api.api_click_move(x, y, player_info.world_z - 70, 2)
                        end
                        
                        -- 仅在完全回城后重置状态
                        if string.find(player_info.current_map_name_utf8, "town") or my_game_info.hideout[player_info.current_map_name_utf8] then
                            env.last_exp_check = os.time()
                            env.last_exception_time = 0
                            env.need_ReturnToTown = false
                            self:reset_states(env)
                            
                            return bret.SUCCESS
                        end
                        
                        
                        return bret.RUNNING
                    end
                end)
                
                if not success then
                    
                    return bret.RUNNING
                else
                    return status
                end
            else
                
                return bret.SUCCESS
            end
        end
    },


    -- 检查长时间经验加成
    Check_LongTime_EXP_Add = {
        name = "检查长时间经验加成",
        run = function(self, env)
            local config = env.user_config or {}
            if not self.is_initialized then
                self.last_check = 0  -- 初始化时间戳
                self.last_alt_press_time = 0
                self.movement_threshold = 15
                self.is_initialized = false
            end
            reset_states_exp = function()
                -- 统一状态重置方法
                local current_time = os.time()
                local current = env.player_info
                env.last_exception_time = 0
                env.last_exp_check = current_time
                env.last_exp_value = env.player_info.currentExperience
                env.last_position = {current.grid_x, current.grid_y}
                -- logger.debug("已重置所有经验监控状态")
            end
            reset_states_move = function()
                -- 统一状态重置方法
                local current_time = os.time()
                local current = env.player_info
                env.last_exception_time_move = 0
                env.last_exp_check_move = current_time
                env.last_exp_value_move = env.player_info.currentExperience
                env.last_position = {current.grid_x, current.grid_y}
                -- logger.debug("已重置所有经验监控状态")
            end
            
            _check_stagnant_movement = function()
                -- 检查是否处于停滞移动状态
                local current = env.player_info
                local last_pos = env.last_position or {0, 0}
                local distance = env.poe2_api.point_distance(last_pos[1], last_pos[2], current)
                -- 更新位置记录
                env.last_position = {current.grid_x, current.grid_y}
                return distance < self.movement_threshold
            end
            
            _check_feature_enabled = function()
                -- 检查至少有一个異常處理功能启用
                -- 经验相关功能
                local exp_town_enabled = config["全局設置"]["異常處理"]["沒有經驗回城"]["是否開啟"] or false
                local exp_retreat_enabled = config["全局設置"]["異常處理"]["沒有經驗小退"]["是否開啟"] or false
                
                -- 移动相关功能
                local move_town_enabled = config["全局設置"]["異常處理"]["不動回城"]["是否開啟"] or false
                local move_retreat_enabled = config["全局設置"]["異常處理"]["不動小退"]["是否開啟"] or false
                
                -- 任一功能启用即为true
                return exp_town_enabled or exp_retreat_enabled or move_town_enabled or move_retreat_enabled
            end
            
            get_range = function(range_info, player_info)
                if range_info then
                    local range = env.poe2_api.get_sorted_list1(range_info)
                    for _, i in ipairs(range) do
                        if i.name_utf8 and 
                        (i.name_utf8 == "甕" or i.name_utf8 == "壺" or i.name_utf8 == "屍體" or 
                            i.name_utf8 == "巢穴" or i.name_utf8 == "籃子" or i.name_utf8 == "小雕像" or
                            i.name_utf8 == "石塊" or i.name_utf8 == "鬆動碎石" or i.name_utf8 == "瓶子" or
                            i.name_utf8 == "盒子" or i.name_utf8 == "腐爛木材" or i.name_utf8 == "保險箱") and
                        i.isActive and i.is_selectable and 
                        env.poe2_api.point_distance(i.grid_x, i.grid_y, player_info) <= 20 and
                        i.grid_x and i.grid_y then
                            return i
                        end
                    end
                end
                return false
            end
            local current_time = os.time()
            local take_rest = env.take_rest or false
            local buy_items = env.buy_items or false
            
            -- 节流控制
            if current_time - self.last_check < 0.5 then
                
                return bret.SUCCESS
            end
            self.last_check = current_time
            
            local player = env.player_info
            if not player then
                
                return bret.SUCCESS
            end
            
            local config = env.user_config or {}
            if take_rest then
                -- logger.info("正在休息，跳过异常处理")
                return bret.SUCCESS
            end
            
            -- 检查移动状态
            local is_moving = _check_stagnant_movement(env)
            
            -- 获取配置
            local no_exp_to_town = config["全局設置"]["異常處理"]["沒有經驗回城"]["是否開啟"] or false
            local no_exp_to_town_time = (config["全局設置"]["異常處理"]["沒有經驗回城"]["閾值"] or 0) * 60
            local no_exp_to_change = config["全局設置"]["異常處理"]["沒有經驗小退"]["是否開啟"] or false
            local no_exp_to_change_time = (config["全局設置"]["異常處理"]["沒有經驗小退"]["閾值"] or 0) * 60
            
            local no_move_to_town = config["全局設置"]["異常處理"]["不動回城"]["是否開啟"] or false
            local no_move_to_town_time = (config["全局設置"]["異常處理"]["不動回城"]["閾值"] or 0) * 60
            local no_move_to_change = config["全局設置"]["異常處理"]["不動小退"]["是否開啟"] or false
            local no_move_to_change_time = (config["全局設置"]["異常處理"]["不動小退"]["閾值"] or 0) * 60
            
            -- 经验增长时重置状态
            if player.currentExperience ~= env.last_exp_value then
                reset_states_exp(env)
            end
            
            if not is_moving then
                reset_states_move(env)
            end
            
            -- 计算真实停滞时间
            local real_stagnation_time = current_time - (env.last_exp_check or 0)
            local real_stagnation_time_move = current_time - (env.last_exp_check_move or 0)
            
            -- 定期按alt键
            if current_time - self.last_alt_press_time >= 20 then
                env.poe2_api.click_keyboard("alt",0)
                self.last_alt_press_time = current_time
            end
            
            local map_strenght = env.strengthened_map_obj
            local space_time = 8
            local return_town = env.return_town or false
            
            if my_game_info.hideout[player.current_map_name_utf8] then
                if env.poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info,click = 0}) then
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
            
            -- 移动检查
            if is_moving and real_stagnation_time_move then
                print(string.format("未移动时间：%.2f秒", real_stagnation_time_move))
                if real_stagnation_time_move > 6 then
                    env.mouse_check = true
                else
                    env.mouse_check = false
                end
            end
            
            -- 处理长时间未移动
            if is_moving and real_stagnation_time_move > space_time then
                if not env.need_SmallRetreat and not env.need_ReturnToTown and not take_rest then
                    env.end_point = nil
                    env.target_point = nil
                    env.path_list = nil
                    env.is_arrive_end = true
                    
                    -- if env.poe2_api.find_text("繼續遊戲", nil, 0, 0, 2) then
                        
                    --     return bret.SUCCESS
                    -- end
                    
                    -- if env.poe2_api.find_text("恩賜之物", nil, 0, 0) then
                    --     env.poe2_api.click_position(1570, 57)
                        
                    --     return bret.SUCCESS
                    -- end
                    
                    -- local player_info = env.poe2_api.af_api.api_GetLocalPlayer()
                    -- local range_info = env.poe2_api.af_api.api_getRangeActors()
                    env.poe2_api.click_keyboard('space',0)
                    
                    -- if range_info and player_info then
                    --     local target = get_range(range_info, player_info)
                    --     if target then
                    --         env.poe2_api.af_api.api_click_move(target.grid_x, target.grid_y, player_info.world_z, 1)
                    --         sleep(0.1)
                    --         env.poe2_api.find_text(target.name_utf8, nil, 0, 0, 2)
                    --         sleep(0.3)
                    --     end
                        
                    --     local x, y = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                    --     if x and y then
                    --         api_ClickMove(x, y, player_info.world_z - 70,8)
                    --         sleep(0.3)
                    --         env.poe2_api.click_keyboard('space')
                    --         sleep(0.1)
                    --     end
                    -- end
                    
                    -- if my_game_info.hideout[player.current_map_name_utf8] then
                    --     local x, y = api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                    --     if x and y then
                    --         api_ClickMove(x, y, player_info.world_z - 70,8)
                    --         sleep(0.5)
                    --         env.poe2_api.click_keyboard('space')
                    --         sleep(0.5)
                    --         env.poe2_api.click_keyboard('space')
                    --     end
                    -- end
                end
            end
            
            -- 功能未启用时直接返回
            if not _check_feature_enabled(config) then
                
                return bret.SUCCESS
            end
            
            -- 初始化首次检查
            if env.last_exp_check == 0 then
                env.last_exp_value = player.currentExperience
                env.last_exp_check = current_time
                
                return bret.SUCCESS
            end
            
            -- 检查触发条件
            local trigger_town = no_exp_to_town and real_stagnation_time >= no_exp_to_town_time
            local trigger_retreat = no_exp_to_change and real_stagnation_time >= no_exp_to_change_time
            local trigger_town_move = no_move_to_town and real_stagnation_time_move >= no_move_to_town_time
            local trigger_retreat_move = no_move_to_change and real_stagnation_time_move >= no_move_to_change_time
            
            -- 处理触发事件
            if trigger_town or trigger_retreat or trigger_town_move or trigger_retreat_move then
                if real_stagnation_time > no_exp_to_change_time then
                    env.is_map_complete = true
                    env.need_SmallRetreat = true
                    
                    return bret.SUCCESS
                end
                
                if (trigger_town and no_exp_to_town) or (trigger_town_move and no_move_to_town) then
                    env.is_map_complete = true
                    if not my_game_info.hideout[player.current_map_name_utf8] then
                        env.need_ReturnToTown = true
                    end
                    
                    return bret.SUCCESS
                elseif (trigger_retreat and no_exp_to_change) or (trigger_retreat_move and no_move_to_change) then
                    env.is_map_complete = true
                    env.need_SmallRetreat = true
                    
                    return bret.SUCCESS
                end
            end
            
            
            return bret.SUCCESS
        end
    },


    -- 检查异界死亡
    Is_Deth_Otherworld = {
        run = function(self, env)
            poe2_api.print_log("检查是否在异界死亡...")
            return bret.SUCCESS
        end
    },

    -- 检查低血量/蓝量
    CheckLowHpMp_Otherworld = {
        run = function(self, env)
            poe2_api.print_log("检查低血量/蓝量...")
            return bret.SUCCESS
        end
    },

    -- 逃跑
    Escape = {
        run = function(self, env)
            poe2_api.print_log("尝试逃跑...")
            return bret.SUCCESS
        end
    },

    -- 路径移动
    Path_Move = {
        run = function(self, env)
            poe2_api.print_log("沿路径移动...")
            return bret.SUCCESS
        end
    },

    -- 检查是否在主页面
    Not_Main_Page_Otherworld = {
        run = function(self, env)
            poe2_api.print_log("检查是否不在主页面...")
            return bret.SUCCESS
        end
    },

    -- 设置基础技能
    Set_Base_Skill = {
        name = "设置基础技能",
        
        run = function(self, env)
            local config = env.user_config or {}
            if not self.is_initialized then
                self.bool = false  -- 初始化时间戳
                self.bool1 = false
                self.is_initialized = true
            end
            skill_location = function(skill_name, skill_pos, selectable_skills)
                if not selectable_skills then
                    return false
                end
                -- 获取指定位置
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
            get_move_skill = function(selectable_skills)
                if not skill_location("", "MIDDLE", selectable_skills) then
                    return false
                end
                return true
            end
            
            set_pos = function(skill_name, rom_x, rom_y, selectable_skills)
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
            
            cancel_left_skill = function(selectable_skills)
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
            local start_time = os.time()
            local mouse_check = env.mouse_check or false
            
            if not mouse_check then
                return bret.SUCCESS
            end
            
            -- if not (env.poe2_api.click_text_UI("life_orb", nil) or env.poe2_api.click_text_UI("resume_game", nil) or env.poe2_api.find_text("清單", nil, 0, 0, 400)) then
            --     return bret.RUNNING
            -- end
            local selectable_skills = api_GetSelectableSkillControls()
            local allskill_info = api_GetAllSkill()
            local skill_slots = api_GetSkillSlots()
            
            if not selectable_skills then
                print("获取可选技能技能控件信息失败")
                return bret.RUNNING
            end
            if not allskill_info then
                print("获取全部技能信息失败")
                return bret.RUNNING
            end
            if not skill_slots then
                print("获取快捷栏技能信息失败")
                return bret.RUNNING
            end
            self.bool =cancel_left_skill( selectable_skills)
            self.bool1 = get_move_skill(selectable_skills)
            print("self.bool",self.bool)
            if not self.bool1 then
                -- if env.poe2_api.find_text("繼續遊戲", nil, 0, 0, 2) then
                --     
                --     return bret.RUNNING
                -- end
                if not set_pos("", 0, 0, selectable_skills) then
                    local point = my_game_info.skill_pos["MIDDLE"]
                    api_ClickScreen(math.floor(point[1]), math.floor(point[2]),1)
                    api_Sleep(500)
                end
                return bret.RUNNING
            end
            
            if self.bool then
                -- if env.poe2_api.find_text("繼續遊戲", nil, 0, 0, 2) then
                    
                --     return bret.RUNNING
                -- end
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
        name = "使用任務道具",
        
        is_props = function(self, bag)
            for _, item in ipairs(bag) do
                if item.baseType_utf8 and string.find(item.baseType_utf8, "知識之書") and item.category == "QuestItem" then
                    return item
                end
            end
            
            for _, item in ipairs(bag) do
                if item.baseType_utf8 and string.find(item.baseType_utf8, "知識之結晶核心") and item.category == "QuestItem" then
                    return item
                end
            end
            
            return false
        end,
        
        run = function(self, env)
            local current_time = os.time()
            local bag = env.bag_info or {}
            local player_info = env.player_info
            local current_map_info_copy = env.current_map_info_copy or {}
            
            if not player_info then
                
                return bret.RUNNING
            end
            
            -- Find MapDevice in current map
            local map_device = nil
            for _, item in ipairs(current_map_info_copy) do
                if item.name_utf8 == "MapDevice" then
                    map_device = item
                    break
                end
            end
            
            -- Check if in town or hideout with MapDevice
            if not string.find(player_info.current_map_name_utf8, "town") and 
            (not my_game_info.hideout[player_info.current_map_name_utf8] or not map_device) then
                
                return bret.SUCCESS
            end
            
            -- Check for quest items
            local props = is_props(bag)
            if props then
                -- Open inventory if not visible
                if not env.poe2_api.find_text(nil, "背包", 1000, 32, 1600, 81) then
                    env.poe2_api.click_keyboard("i")
                    sleep(1)
                    
                    return bret.RUNNING
                end
                
                -- Calculate center position and right click
                local point = env.poe2_api.get_center_position(
                    {props.start_x, props.start_y},
                    {props.end_x, props.end_y}
                )
                env.poe2_api.right_click(point[1], point[2])
                
                return bret.RUNNING
            end
            
            return bret.SUCCESS
        end
    },

    -- 合成或鉴定
    Conflate_Or_Identify = {
        run = function(self, env)
            poe2_api.print_log("执行合成或鉴定...")
            return bret.SUCCESS
        end
    },

    -- 分解对话
    Dialogue_Break_Down_NPC = {
        run = function(self, env)
            poe2_api.print_log("与分解NPC对话...")
            return bret.SUCCESS
        end
    },

    -- 交互
    Interactive = {
        run = function(self, env)
            poe2_api.print_log("执行交互操作...")
            return bret.SUCCESS
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
            local UI_info = env.UI_info
            -- 非藏身处不滴注
            if not poe2_api.table_contains(player_info.current_map_name_utf8,my_game_info.hideout)then
                env.dizhu_end = false
                return bret.SUCCESS
            end
            if env.one_other_map then
                return bret.SUCCESS
            end
            local function shut_down_pages()
                if poe2_api.find_text({text="滴注中",UI_info=UI_info,min_x=200,max_x=1050,max_y=300})then
                    local a = api_Getinventorys(0x25,0)
                    if a then
                        if not poe2_api.find_text({UI_info=UI_info,text="背包",min_x=1000,min_y=32,max_x=1600,max_y=81}) then
                            poe2_api.click_keyboard("i")
                            api_Sleep(100)
                            return bret.RUNNING
                        end
                        poe2_api.find_text({text = "滴注中",UI_info=UI_info,min_x=200,max_x=1050,max_y=300,click=4,add_y=130})
                        api_Sleep(200)
                        poe2_api.find_text({text = "滴注中",UI_info=UI_info,min_x=200,max_x=1050,max_y=300,click=4,add_y=240,add_x=-75})
                        api_Sleep(200)
                        poe2_api.find_text({text = "滴注中",UI_info=UI_info,min_x=200,max_x=1050,max_y=300,click=4,add_y=240})
                        api_Sleep(200)
                        poe2_api.find_text({text = "滴注中",UI_info=UI_info,min_x=200,max_x=1050,max_y=300,click=4,add_y=240,add_x=75})
                        api_Sleep(200)
                        return bret.RUNNING
                    end
                    poe2_api.find_text({text = "滴注中",UI_info=UI_info,min_x=200,max_x=1050,max_y=300,click=2,add_y=-10,add_x=156})
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
                                    if poe2_api.find_text({min_x = 1040, min_y = 46, max_x = 1090, max_y = 70, text = "背包" , UI_info=UI_info}) then
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
            poe2_api.dbgp("检查背包")
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

    Open_Warehouse = {
        run = function(self, env)
            if not self.bool then
                self.nubmer_index = 0
                self.bool = true
                return bret.RUNNING
            end
            poe2_api.dbgp("打开仓库...")
            local obj = nil
            local text = nil 
            local warehouse = nil
            local current_map_info = env.current_map_info
            local range_info = env.range_info
            local player_info = env.player_info
            local warehouse_type_interactive = env.warehouse_type_interactive
            -- local UI_info = env.UI_info
            local function get_object(name,data_list)
                if not data_list or not next(data_list) then
                    return false
                end
                poe2_api.dbgp("开始寻找"..name)
                for _, v in ipairs(data_list) do
                    if v.name_utf8 == name and v.grid_x ~= 0 and v.grid_y ~= 0 then
                        
                        if v.flagStatus  and v.flagStatus == 0 and v.flagStatus1 == 1 then
                            return v
                        end
                        if v.life and v.is_selectable then
                            return v
                        end
                    end
                end
                return false
            end
            if warehouse_type_interactive == "个仓" then
                local warehouse_obj = get_object("StashPlayer",current_map_info)
                if warehouse_obj then
                    obj = 'StashPlayer'
                    text = "公會倉庫"
                    warehouse = warehouse_obj
                else
                    local warehouse_obj1 = get_object("倉庫",range_info)
                    if warehouse_obj1 then
                        obj = '倉庫'
                        text = "公會倉庫"
                        warehouse = warehouse_obj1
                    end
                end


            elseif warehouse_type_interactive == "公仓" then
                local warehouse_obj = get_object("StashGuild",current_map_info)
                if warehouse_obj then
                    obj = 'StashGuild'
                    text = "倉庫"
                    warehouse = warehouse_obj
                else
                    local warehouse_obj1 = get_object("公會倉庫",range_info)
                    if warehouse_obj1 then
                        obj = '公會倉庫'
                        text = "倉庫"
                        warehouse = warehouse_obj1
                    end
                end
            else
                error("在配置物品过滤中,有物品的存仓页未配置")
            end
            if not warehouse then
                error("找不到仓库或者公会仓库")
            end
            if poe2_api.find_text({text = "強調物品",UI_info = env.UI_info,min_x = 250,min_y = 700}) 
            and not poe2_api.find_text({text = text,UI_info = env.UI_info,min_x=0,min_y=32,max_x=381,max_y=81}) then
                return bret.SUCCESS
            end
            local distance = poe2_api.point_distance(warehouse.grid_x,warehouse.grid_y,player_info)
            if distance > 25 then
                env.interactive = obj
                return bret.FAIL
            else
                if poe2_api.find_text({text = "繼續遊戲",UI_info = env.UI_info,click = 2}) then
                    return bret.RUNNING
                end
                if env.target_point and env.end_point then
                    poe2_api.dbgp("取消按键")
                    api_ClickMove(poe2_api.toExactInt(env.target_point[1]), poe2_api.toExactInt(env.target_point[2]),poe2_api.toExactInt(player_info.world_z), 7)
                    api_Sleep(100)
                end
                api_ClickMove(poe2_api.toExactInt(warehouse.grid_x),poe2_api.toExactInt(warehouse.grid_y),poe2_api.toExactInt(player_info.world_z),1)
                if self.nubmer_index >= 10 then
                    poe2_api.click_keyboard("esc")
                    api_Sleep(500)
                    self.nubmer_index = 0
                end 
                self.nubmer_index = self.nubmer_index + 1
                api_Sleep(500)
                return bret.RUNNING
            end
        end
    },

    -- 仓库取物品
    Warehouse_pickup_items = {
        run = function(self, env)
            local text = ""
            if env.warehouse_type == "倉庫" then
                text = "倉庫"
            else
                text = "公會倉庫"
            end
            -- 确认打开仓库
            if not poe2_api.find_text({text = "強調物品",UI_info = env.UI_info,min_x = 250,min_y = 700})
                and poe2_api.find_text({text = text,UI_info = env.UI_info,min_x=0,min_y=32,max_x=381,max_y=81})  then
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
            local UI_info = env.UI_info
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
                        if poe2_api.find_text({UI_info = UI_info, text = aj["仓库页"], max_y = 90, min_x = 0, max_x = 500, min_y = 0, click = 2}) then
                            api_Sleep(200)
                        elseif poe2_api.find_text({UI_info = UI_info, text = aj["仓库页"], max_y = 469, min_x = 556, min_y = 20, max_x = 851, click = 2}) then
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
                poe2_api.print_log("【倉庫類型】 错误！")
                return bret.FAILURE
            end
            
            -- 獲取列表按鈕
            local tab_list_button = poe2_api.click_text_UI({text = "tab_list_button", ui_info = UI_info,ret_data = true})

            -- 獲取鎖定按鈕
            local lock = poe2_api.get_game_control_by_rect({ui_info = env.UI_info,min_x = 549,min_y = 34,max_x = 584,max_y = 74})
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
                        if poe2_api.find_text({UI_info=UI_info, text=page.name_utf8, max_y=90, min_x=0, max_x=500, min_y=0, click=2}) then
                            api_Sleep(200)
                        else
                            goto continue
                        end
                    else
                        if not lock_button or not next(lock_button) then
                            api_ClickScreen(poe2_api.toExactInt((tab_list_button.left+tab_list_button.right)/2),poe2_api.toExactInt((tab_list_button.top+tab_list_button.bottom)/2),1)
                            api_Sleep(2000)
                            api_ClickScreen(poe2_api.toExactInt((tab_list_button.left+tab_list_button.right)/2 + 30),poe2_api.toExactInt((tab_list_button.top+tab_list_button.bottom)/2 - 30),1)
                            api_Sleep(5000)
                            return bret.RUNNING
                        end
                        if poe2_api.find_text({UI_info=UI_info, text=page.name_utf8, max_y=469, min_x=556, min_y=20, max_x=851, click=2}) then
                            api_Sleep(500)
                        else
                            goto continue
                        end
                    end
            
                    -- 仓库
                    if env.warehouse_type == "倉庫" then
                        -- 检查仓库类型
                        if not poe2_api.find_text({text = '倉庫', UI_info = UI_info, min_x = 0, min_y = 32, max_x = 381, max_y = 81}) then
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
                        if not poe2_api.find_text({text = '公會倉庫', UI_info=UI_info, min_x=0, min_y=32, max_x=381, max_y=81}) then
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
            poe2_api.dbgp("是否已打开背包")
            local UI_info = env.UI_info
            -- # 清除页面
            if poe2_api.find_text({text = '購買或販賣', UI_info = UI_info, min_x = 0, max_x = 800}) then
                api_ClickScreen(792,169,1)
                api_Sleep(200)
            end

            if poe2_api.find_text({text = '重鑄台', UI_info = UI_info, min_x = 0}) and poe2_api.find_text({text = '摧毀三個相似的物品，重鑄為一個新的物品', UI_info = UI_info, min_x = 0}) then
                api_ClickScreen(1010,153,1)
                api_Sleep(200)
            end

            if not poe2_api.find_text({text = "背包", UI_info = UI_info , min_x = 1040, min_y = 46, max_x = 1090, max_y = 70}) then
                poe2_api.click_keyboard("i",0)
                api_Sleep(300)
            end

            return bret.FAIL
        end
    },

    -- 重置物品
    res_item = {
        run = function(self, env)
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
                if poe2_api.find_text({text ="強調物品" , UI_info = env.UI_info, min_x = 280,min_y = 730, max_x = 342, max_y = 758}) then
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
            if poe2_api.find_text({text = "滴注中", UI_info = env.UI_info, min_x = 240, min_y = 210, max_x = 305, max_y = 231}) then
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
            poe2_api.dbgp("放置地图钥匙")
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
            poe2_api.dbgp("放置精炼")
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
            return bret.SUCCESS
        end
    },

    -- 拿地图
    Take_Map = {
        run = function(self, env)
            poe2_api.print_log("从仓库拿地图...")
            return bret.SUCCESS
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
    -- 城外鉴定
    Identify_designated_equipment = {
        name = "城外鉴定",
        
        convert_key = function(self, key)
            -- 根据输入的中文或英文关键字返回对应的翻译
            return my_game_info.type_conversion[key] or 
                (function()
                    for k, v in pairs(my_game_info.type_conversion) do
                        if v == key then return k end
                    end
                    return nil
                end)()
        end,
        
        convert_config_type = function(self, config_type_dict)
            -- 将配置字典中的中文类型键转换为对应的英文类型键
            if not config_type_dict then return {} end
            
            local converted_dict = {}
            for chinese_type, info_list in pairs(config_type_dict) do
                local english_type = my_game_info.type_conversion[chinese_type]
                if english_type then
                    -- 处理内嵌'類型'字段
                    if type(info_list) == "table" and info_list['類型'] then
                        if type(info_list['類型']) == "table" then
                            -- 处理数组中的每个元素
                            local converted_types = {}
                            for _, t in ipairs(info_list['類型']) do
                                table.insert(converted_types, my_game_info.type_conversion[t] or t)
                            end
                            info_list['類型'] = converted_types
                        else
                            -- 处理单个值
                            info_list['類型'] = {my_game_info.type_conversion[info_list['類型']] or info_list['類型']}
                        end
                    end
                    converted_dict[english_type] = info_list
                else
                    poe2_api.print_log("警告: 未找到类型 '"..chinese_type.."' 的英文转换")
                end
            end
            return converted_dict
        end,
        
        get_matched_config = function(self, bag, config_type)
            -- 智能获取匹配的配置
            for _, item_config in pairs(config_type) do
                for _, item in ipairs(item_config) do
                    if type(item) == "table" then
                        local item_type = item['類型']
                        
                        -- 处理类型匹配
                        if type(item_type) == "table" and #item_type > 0 then
                            if item_type[1] ~= self:convert_key(bag.category) then
                                goto continue
                            end
                        elseif type(item_type) == "string" then
                            if item_type ~= self:convert_key(bag.category) then
                                goto continue
                            end
                        end
                        
                        -- 检查基础类型名
                        if bag.baseType_utf8 ~= item['基礎類型名'] and item['基礎類型名'] ~= '全部物品' then
                            goto continue
                        end
                        
                        -- 检查颜色条件
                        if item['白裝'] and bag.color == 0 then
                            goto continue
                        end
                        if not ((item['藍裝'] and bag.color == 1) or
                            (item['黃裝'] and bag.color == 2) or
                            (item['暗金'] and bag.color == 3)) then
                            goto continue
                        end
                        
                        -- 检查名称匹配
                        if item['名稱'] then
                            if item['名稱'] == bag.name_utf8 then
                                return item
                            end
                        else
                            -- 检查词缀
                            if item['物品詞綴'] then
                                local affix_dict = item['物品詞綴']
                                if type(affix_dict) == "table" then
                                    for _, v in pairs(affix_dict) do
                                        if type(v) == "table" and v['詞綴'] then
                                            return item
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- 基础类型名匹配
                        if item['基礎類型名'] == bag.baseType_utf8 or item['基礎類型名'] == '全部物品' then
                            return item
                        end
                    end
                    ::continue::
                end
            end
            return nil
        end,
        
        need_appraisal = function(self, bag_info, config_name, config_type)
            if not bag_info then return false end
            
            local items_to_identify = {}
            
            for _, bag in ipairs(bag_info) do
                -- 基础条件：未鉴定、未污染、不在排除列表
                if not (bag.not_identified and 
                    not my_game_info.not_need_identify[bag.category]) then
                    goto continue
                end
                
                -- 特殊类别直接加入鉴定列表
                if bag.category == "Map" or bag.category == "TowerAugmentation" then
                    table.insert(items_to_identify, bag)
                    goto continue
                end
                
                -- 获取匹配的配置
                local matched_config = self:get_matched_config(bag, config_type)
                
                -- 检查物品詞綴配置
                if matched_config and matched_config['物品詞綴'] then
                    local affix_dict = matched_config['物品詞綴']
                    if type(affix_dict) == "table" then
                        for _, value in pairs(affix_dict) do
                            if type(value) == "table" and value['詞綴'] then
                                table.insert(items_to_identify, bag)
                                goto continue
                            end
                        end
                    end
                end
                
                ::continue::
            end
            
            if #items_to_identify > 0 then
                return items_to_identify
            end
            return false
        end,
        
        use_items = function(self, bag_info, click)
            if not bag_info then return false end
            
            for _, actor in ipairs(bag_info) do
                if actor.baseType_utf8 == "知識卷軸" then
                    if click == 1 then
                        -- 计算中心坐标
                        local start_cell = {actor.start_x, actor.start_y}
                        local end_cell = {actor.end_x, actor.end_y}
                        local center_position = poe2_api.get_center_position(start_cell, end_cell)
                        
                        if not poe2_api.find_text(nil, "背包", 1000, 32, 1600, 81) then
                            poe2_api.click_keyboard("i")
                            sleep(500)
                        end
                        
                        poe2_api.natural_move(center_position[1], center_position[2])
                        sleep(500)
                        poe2_api.af_api.api_RightClick()
                        sleep(500)
                    end
                    return true
                end
            end
            return false
        end,
        
        run = function(self, env)
            local current_time = os.time()
            
            local bag_info = env.bag_info
            local range_info = env.range_info
            local player_info = env.player_info
            local attack_dis_map = env.map_level_dis
            local stuck_monsters = env.stuck_monsters
            local not_attack_mos = env.not_attack_mos
            local config = env.user_config or {}
            
            local config_name = config['物品過濾索引']['按名称'] or {}
            local config_type = config['物品過濾索引']['按类型'] or {}
            
            -- 转换配置类型
            config_type = self:convert_config_type(config_type)
            
            if poe2_api.find_text(nil, "繼續遊戲", 0, 0, 2) then
                
                return bret.RUNNING
            end
            
            -- 判断是否需要鉴定
            local items_to_identify = self:need_appraisal(bag_info, config_name, config_type)
            if not items_to_identify then
                
                return bret.SUCCESS
            end
            
            if player_info.isInDangerArea then
                
                return bret.SUCCESS
            end
            
            if poe2_api.is_have_mos(range_info, player_info, attack_dis_map, stuck_monsters, not_attack_mos) then
                
                return bret.SUCCESS
            end
            
            -- 使用鉴定卷轴
            if not self:use_items(bag_info) or 
            (poe2_api.is_have_mos(range_info, player_info) and 
                (my_game_info.hideout_CH[player_info.current_map_name_utf8] or 
                string.find(player_info.current_map_name_utf8, "town"))) then
                
                return bret.SUCCESS
            end
            
            -- 获取背包信息并鉴定物品
            bag_info = poe2_api.af_api.api_Getinventorys(1)
            if bag_info then
                items_to_identify = self:need_appraisal(bag_info, config_name, config_type)
                if not items_to_identify then
                    
                    return bret.SUCCESS
                end
                
                if self:use_items(bag_info, 1) then
                    for _, items in ipairs(bag_info) do
                        for _, k in ipairs(items_to_identify) do
                            if items.obj == k.obj then
                                if not poe2_api.find_text(nil, "背包", 1000, 32, 1600, 81) then
                                    poe2_api.click_keyboard("i")
                                    sleep(500)
                                end
                                
                                local start_cell = {items.start_x, items.start_y}
                                local end_cell = {items.end_x, items.end_y}
                                local center_position = poe2_api.get_center_position(start_cell, end_cell)
                                
                                poe2_api.natural_move(center_position[1], center_position[2])
                                sleep(200)
                                poe2_api.af_api.api_LeftClick()
                                sleep(200)
                                
                                return bret.RUNNING
                            end
                        end
                    end
                end
            else
                
                return bret.SUCCESS
            end
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
            local UI_info  = env.UI_info
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
                poe2_api.print_log("所有存在的配置物品: " .. table.concat(mapped_items, ", "))
            
                return all_config_items, all_config_items_no_price, not_appeared_items
            end
            if not poe2_api.click_text_UI({text = "ritual_open_shop_button" , ui_info = UI_info }) then
                return bret.SUCCESS
            end
            
            local SacrificeItems = api_GetSacrificeItems()
            if not (0 < SacrificeItems.maxCount and SacrificeItems.maxCount < 10) or not (0 < SacrificeItems.finishedCount and SacrificeItems.finishedCount < 10) or #SacrificeItems.items == 0 then
                if poe2_api.click_text_UI({text = "ritual_open_shop_button" , ui_info = UI_info ,click = 1 }) then
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
                if poe2_api.find_text({text = "恩賜之物" , UI_info = UI_info }) then
                    poe2_api.find_text({text = "恩賜之物" , UI_info = UI_info, min_x = 0 , add_x = 272})
                    return bret.SUCCESS
                end
                return bret.SUCCESS
            end
            
            poe2_api.print_log("祭坛总数:", SacrificeItems.maxCount, " 已完成数量:", SacrificeItems.finishedCount, " 当前贡礼:", SacrificeItems.leftGifts)
            poe2_api.print_log("祭坛可刷新总数:", SacrificeItems.MaxRefreshCount, " 祭坛已刷新数:", SacrificeItems.CurrentRefreshCount)
            
            local life = player_info.remainingPortalCount
            poe2_api.print_log("剩余重生机会:", life, "次")
            
            if #all_items == 0 then
                poe2_api.print_log("没有可购买物品或者暂缓物品")
                if SacrificeItems.leftGifts > SacrificeItems.refreshCost and SacrificeItems.MaxRefreshCount > SacrificeItems.CurrentRefreshCount and #not_appeared_items == 0 then
                    if not poe2_api.find_text({text = "恩賜之物" , UI_info = UI_info, min_x = 0}) then
                        env.buy_items = true
                        poe2_api.click_text_UI({text ="ritual_open_shop_button", ui_info = UI_info, click = 1})
                        api_Sleep(2000)
                        return bret.RUNNING
                    end
                    poe2_api.print_log("第" .. SacrificeItems.CurrentRefreshCount .. "次刷新贡礼")
                    poe2_api.find_text({text = "恩賜之物" , UI_info = UI_info, click = 2 ,min_x = 0 , add_x = 203, add_y = 53})
                    api_Sleep(2000)
                    return bret.RUNNING
                end
                
                if poe2_api.find_text({text ="恩賜之物", UI_info = UI_info}) then
                    poe2_api.find_text({text = "恩賜之物" , UI_info = UI_info, min_x = 0 , add_x = 272})
                    env.buy_items =  false
                    return bret.SUCCESS
                end
                
                env.buy_items =  false
                return bret.SUCCESS
            end
            
            if SacrificeItems.finishedCount < SacrificeItems.maxCount and #all_items_no_price > 0 and life >= 2 then
                env.have_ritual = true
                env.buy_items =  false
                if poe2_api.find_text({text ="恩賜之物", UI_info = UI_info}) then
                    poe2_api.find_text({text = "恩賜之物" , UI_info = UI_info, min_x = 0 , add_x = 272})
                    env.buy_items =  false
                end
                return bret.SUCCESS
            else
                env.have_ritual = false
            end
            env.buy_items =  true
            if not poe2_api.find_text({text ="恩賜之物", UI_info = UI_info}) then
                poe2_api.click_text_UI({text ="ritual_open_shop_button", ui_info = UI_info, click = 1})
                api_Sleep(1000)
                return bret.RUNNING
            end
            
            -- Buy affordable items
            local function buy_affordable(item)
                if not poe2_api.find_text({text = "暫緩道具", UI_info = UI_info}) then
                    poe2_api.find_text({text ="取消", UI_info = UI_info, click = 2})
                    api_Sleep(1000)
                    return bret.RUNNING
                end
                
                poe2_api.print_log("正在购买 " .. item.baseType_utf8)
                if poe2_api.ctrl_left_click_altar_items(item.obj, all_items) then
                    api_Sleep(500)
                end
            end
            local function refresh_UI()
                UI_info = {}
                local size =  UiElements:Update()
                -- poe2_api.print_log(size .. "\n")
                if size > 0 then
                    local sum = 0;
                    for i = 0, size - 1, 1 do
                        sum = sum + 1
                        table.insert(UI_info, UiElements[i])
                    end
                else
                    poe2_api.print_log("未发现UI信息\n")
                    api_Sleep(4000)
                    return bret.RUNNING
                end
                env.UI_info = UI_info
            end
            -- Defer items
            local function deferred(item)
                if poe2_api.find_text({text = "暫緩道具", UI_info = UI_info}) then
                    poe2_api.find_text({text = "暫緩道具", UI_info = UI_info, click = 2})
                    api_Sleep(1000)
                    return bret.RUNNING
                end
                
                if poe2_api.find_text({text = "確認", UI_info = UI_info}) then
                    poe2_api.find_text({text = "恩賜之物" , UI_info = UI_info ,click = 2 , min_x = 0 , add_x = 272})
                    api_Sleep(500)
                    return bret.RUNNING
                end
                
                poe2_api.print_log("暫緩 " .. item.baseType_utf8)
                if poe2_api.ctrl_left_click_altar_items(item.obj, all_items, 2) then
                    api_Sleep(500)
                end
                refresh_UI()
                poe2_api.find_text({text = "確認", UI_info = UI_info, click = 2})
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

    -- 检查是否交互
    Is_Interactive = {
        run = function(self, env)
            poe2_api.print_log("检查是否需要交互...")
            return bret.SUCCESS
        end
    },

    -- 躲避技能
    DodgeAction = {
        name = "躲避",
        run = function(self, env)
            if not self.is_initialized then
                self.last_space_time = 0.0 -- 上次按下空格的时间
                self.space_cooldown = 1.5  -- 空格键冷却时间（秒）
                self.last_space_time1 = 0.0
                self.is_initialized = true
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
                os.time() - self.last_space_time >= space_time then
                    local result = api_GetNextCirclePosition(
                        monster.grid_x, monster.grid_y, 
                        player_info.grid_x, player_info.grid_y, 50,20,0
                    )
                    api_ClickMove(poe2_api.toExactInt(result.x), poe2_api.toExactInt(result.y), poe2_api.toExactInt(player_info.world_z), 0)
                    api_Sleep(200)
                    poe2_api.click_keyboard('space')
                    self.last_space_time = os.time() + (math.random(-5, 5)* 0.01)
                end
            end    
            local _handle_space_action_path_name = function(player_info, space_time)
                -- 处理空格键操作（添加20单位距离限制）
                space_time = space_time or 1.5
                if player_info.isInDangerArea then
                    local ret = api_GetSafeAreaLocationNoMonsters(40)
                    if ret and ret.x ~= -1 and ret.y ~= -1 then
                        api_ClickMove(poe2_api.toExactInt(ret.x), poe2_api.toExactInt(ret.y) , poe2_api.toExactInt(player_info.world_z - 70), 0)
                        api_Sleep(200)
                        poe2_api.click_keyboard('space')
                        return true
                    else
                        local rct = api_GetSafeAreaLocation()
                        api_ClickMove(poe2_api.toExactInt(rct.x),poe2_api.toExactInt(rct.y), poe2_api.toExactInt(player_info.world_z - 70), 0)
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
                    if monster.life > 0 and monster.isActive and monster.type == 1 and 
                    poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info) < min_attack_range and 
                    not monster.is_friendly then
                        if has_common_element(my_game_info.first_magicProperties, monster.magicProperties) then
                            poe2_api.print_log("特殊词缀怪物"..monster.magicProperties.."不闪避")
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

    -- 游戏阻挡处理模块
    Game_Block = {
        run = function(self, env)
            poe2_api.print_log("游戏阻挡处理模块...")
            local current_time = os.time()
            local UI_info = env.UI_info
            local player_info = env.player_info
            if not UI_info then
                poe2_api.print_log("空UI信息...")
                return bret.RUNNING
            end

            local function cancel_move()
                if env.target_point and env.end_point then
                    poe2_api.print_log("取消按键")
                    api_ClickMove(poe2_api.toExactInt(env.target_point[1]), poe2_api.toExactInt(env.target_point[2]),poe2_api.toExactInt(player_info.world_z), 7)
                    api_Sleep(100)
                end
            end
            
            -- 检测地图启动失败情况
            if poe2_api.find_text({text = "啟動失敗。地圖無法進入。",UI_info = UI_info}) then
                env.need_SmallRetreat = true
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "繼續遊戲",UI_info = UI_info}) then
                cancel_move()
                poe2_api.find_text({text = "繼續遊戲",UI_info = UI_info,click = 2})
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "寶石切割",UI_info = UI_info,add_x = 280, add_y = 17}) then
                cancel_move()
                poe2_api.find_text({text = "寶石切割",UI_info = UI_info,click = 2,add_x = 280, add_y = 17})
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "購買或販賣",UI_info = UI_info,add_x = 270, add_y = -9}) then
                cancel_move()
                poe2_api.find_text({text = "購買或販賣",UI_info = UI_info,click = 2,add_x = 270, add_y = -9})
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "選擇藏身處",UI_info = UI_info,add_x = 516}) then
                cancel_move()
                poe2_api.find_text({text = "選擇藏身處",UI_info = UI_info,click = 2,add_x = 516})
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "通貨交換",UI_info = UI_info,add_x = 300}) then
                cancel_move()
                poe2_api.find_text({text = "通貨交換",UI_info = UI_info,click = 2,add_x = 300})
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "重組",UI_info = UI_info,add_x = 210, add_y = -50}) then
                cancel_move()
                poe2_api.find_text({text = "重組",UI_info = UI_info,click = 2,add_x = 210, add_y = -50})
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "摧毀三個相似的物品，重鑄為一個新的物品",UI_info = UI_info,add_x = 240,min_x = 0}) then
                cancel_move()
                poe2_api.find_text({text = "摧毀三個相似的物品，重鑄為一個新的物品",UI_info = UI_info,click = 2,add_x = 240,min_x = 0})
                return bret.RUNNING
            end

            if poe2_api.find_text({text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片",UI_info = UI_info,add_x = 160,add_y = -60,min_x = 0}) then
                cancel_move()
                poe2_api.find_text({text = "回收具有品質或插槽的裝備，以獲得品質通貨和工匠碎片",UI_info = UI_info,click = 2,add_x = 160,add_y = -60,min_x = 0})
                return bret.RUNNING
            end

            top_mid_page = {"傳送", "天賦技能", "世界地圖", "重置天賦點數", "Checkpoints"}
            if poe2_api.find_text({text = top_mid_page, UI_info = UI_info,min_x = 0,add_x = 215}) then
                poe2_api.find_text({text = top_mid_page, UI_info = UI_info,min_x = 0,click = 2,add_x = 215})
                cancel_move()
                return bret.RUNNING
            end

            warehouse_page = {"倉庫","聖域鎖櫃","公會倉庫"}
            if poe2_api.find_text({text = small_page, UI_info = UI_info, min_x = 0, add_x = 253, min_x = 0}) and poe2_api.find_text({text = "强調物品", UI_info = UI_info, min_x = 0,min_x = 0}) then
                cancel_move()
                poe2_api.find_text({text = small_page, UI_info = UI_info, min_x = 0, click = 2, add_x = 253, min_x = 0})
                return bret.RUNNING
            end

            small_page = {"背包","技能", "社交", "角色", "活動", "選項"}
            if poe2_api.find_text({text = small_page, UI_info = UI_info, min_x = 0, add_x = 253, min_x = 0}) then
                cancel_move()
                poe2_api.find_text({text = small_page, UI_info = UI_info, min_x = 0, click = 2, add_x = 253, min_x = 0})
                return bret.RUNNING
            end
            
            refuse_click = {"等待玩家接受交易請求...",}
            if poe2_api.find_text({text = refuse_click, UI_info = UI_info, min_x = 0, add_x = 253}) then
                cancel_move()
                poe2_api.find_text({text = "拒絕", UI_info = UI_info, min_x = 0, click = 2})
                return bret.RUNNING
            end

            save_click = {"你無法將此背包丟置於此。請問要摧毀它嗎？"}
            if poe2_api.find_text({text = save_click, UI_info = UI_info, min_x = 0}) then
                cancel_move()
                poe2_api.find_text({text = "保留", UI_info = UI_info, min_x = 0, click = 2})
                return bret.RUNNING
            end
            
            -- 检查当前地图是否在藏身处且map为真
            if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and map then
                -- 获取背包物品(0xd可能是背包标识)
                local item = api_Getinventorys(0xd,0)
                
                if item then
                    -- 计算物品空间点(注意Lua数组通常从1开始)
                    local width = item[1].end_x - item[1].start_x
                    local height = item[1].end_y - item[1].start_y
                    local point = poe2_api.get_space_point(width, height)
                    
                    if point then
                        -- 查找"背包"文字
                        if poe2_api.find_text("背包") then
                            -- 移动到指定位置并点击
                            api_ClickScreen(point[1], point[2])
                            api_Sleep(100)
                            api_ClickScreen(point[1], point[2],1)

                            api_Sleep(500)
                            return bret.RUNNING
                        else
                            -- 按I键打开背包
                            poe2_api.click_keyboard("i")
                            return bret.RUNNING
                        end
                    end
                end
            end

            return bret.SUCCESS
        end
    },

    -- 检查是否需要攻击
    Check_Is_Need_Attack = {
        run = function(self, env)
            poe2_api.print_log("检查是否需要攻击...")
            range_info = env.range_info
            player_info = env.player_info

            local is_active = true
            local not_sight = 0
            
            if not player_info then
                poe2_api.print_log("玩家信息不存在")
                return bret.RUNNING
            end
            
            if string.find(player_info.current_map_name_utf8, "Claimable") then
                is_active = false
                not_sight = 1
            end
            -- 特殊怪物檢查

            local function spcify_monsters()
                local spcify_monsters_name_list = {"巨蛇女王．瑪娜莎"}
                for _, monster in ipairs(range_info) do
                    for _, name in ipairs(spcify_monsters_name_list) do
						if monster.name_utf8 == name then
							return true
						end
					end
                end
                return false
            end
            
            nomarl_monster = poe2_api.is_have_mos({mos = range_info, player_info = player_info,is_active = is_active, not_sight = not_sight})

            Boss_monster = poe2_api.is_have_mos_boss(range_info,my_game_info.boss_name)

            if nomarl_monster or Boss_monster or spcify_monsters() then
                poe2_api.print_log("需要攻击")
                return bret.SUCCESS
            else
                poe2_api.print_log("不需要攻击")
                return bret.FAIL
            end
        end
    },

    -- 释放技能动作
    ReleaseSkillAction = {
        run = function(self, env)

            --- 辅助函数
            -- 根据稀有度获取可释放的技能
            local function _get_available_skills(monster_rarity)
                -- 根据怪物稀有度获取可用技能
                local current_time = os.time()
                local available_skills = {}

                for _, skill in ipairs(self.skills) do
                    -- 检查冷却
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
                local current_time = os.time()
                
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
                local current_time = os.time()
                
                -- 确保skill_cooldowns表存在
                if not self.skill_cooldowns then
                    self.skill_cooldowns = {}
                end
                
                -- 遍历技能设置
                for key, skill_data in pairs(skill_setting) do
                    -- 只处理攻击技能
                    if skill_data["技能屬性"] == "攻击技能" then
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
                local current_time = os.time()
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
                local current_time = os.time()
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
                    move_z = player_info.world_z
                    
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
                
                -- poe2_api.print_log(777777777777777777)
                -- 
                return move_x, move_y, move_z
            end

            -- 释放技能
            local function _execute_skill(skill, monster, player_info)
                local current_time = os.time()
                
                -- 计算移动位置
                local move_x, move_y, move_z = _calculate_movement(skill, monster, player_info)
                
                -- 执行移动（假设poe2_api有对应的Lua接口）
                api_ClickMove(math.floor(move_x), math.floor(move_y), move_z, 0)
                
                -- 设置冷却时间
                local skill_start = os.time()
                local base_cd = skill.interval
                local actual_cd = math.max(base_cd * (0.9 + math.random() * 0.2), 0.1)
                self.skill_cooldowns[skill.name] = skill_start + actual_cd
                
                -- 释放技能
                poe2_api.click_keyboard(skill.key)
            end
            
            -- 特殊boss处理
            local function _handle_special_boss_movement(boss, player_info)
                local current_time = os.time()
                
                -- 使用pcall进行错误处理（替代try-catch）
                local status, err = pcall(function()
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
                end)
            
            end

            --- 主要动作
            poe2_api.print_log("释放技能...")
            nearest_distance_sq = math.huge

            -- 加载技能设置
            if not self.skills then
                poe2_api.print_log("加载技能设置...")
                parse_skill_config()
                return bret.RUNNING
            end
            
            -- 怪物筛选和处理逻辑
            for _, monster in ipairs(env.range_info) do
                -- 快速失败条件检查（按计算成本从低到高排序）
                if monster.type ~= 1 or                  -- 类型检查
                not monster.is_selectable or          -- 可选性检查
                monster.is_friendly or                -- 友方检查
                monster.life <= 0 or                  -- 生命值检查
                not monster.name_utf8 or              -- 名称检查
                my_game_info.not_attact_mons_CN_name[monster.name_utf8] or
                my_game_info.not_attact_mons_path_name[monster.path_name_utf8] then  -- 路径名检查
                    goto continue
                end

                if self.stuck_monsters and self.stuck_monsters[monster.id] then
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
                if env.center_point > 0 and env.center_radius then
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
                -- poe2_api.print_log("当前怪物：" .. monster.name_utf8 .. "，距离：" .. distance_sq .. "米")

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

            -- 获取当前目标ID
            local current_target_id = valid_monsters and valid_monsters.id or nil

            if not env.center_point and not center_radius then
                -- 第二次遍历进行卡住检测和其他处理
                for _, monster in ipairs(monsters) do
                    local current_time = os.time()
                    
                    -- 快速失败条件检查
                    if monster.type ~= 1 or 
                    not monster.is_selectable or 
                    self.stuck_monsters[monster.id] or 
                    monster.is_friendly then
                        goto continue_second
                    end

                    -- 黑名单检查
                    if my_game_info.not_attact_mons_path_name[monster.path_name_utf8] or
                    my_game_info.not_attact_mons_CN_name[monster.name_utf8] or
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
                        self.stuck_monsters[monster.id] = nil
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
                        local time_threshold = time_thresholds[rarity_index]

                        -- 综合判断条件
                        if time_elapsed > time_threshold and life_ratio > 0.95 then
                            self.stuck_monsters[monster.id] = true
                            poe2_api.print_log(string.format("%s 卡住（%.1f秒未击杀）", monster.name_utf8 or "未知怪物", time_elapsed))
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
                poe2_api.print_log(self.stuck_monsters)
            end

            env.valid_monsters = valid_monsters

            if valid_monsters then
                local status, err = pcall(function()
                    -- 计算距离
                    local distance = math.sqrt((valid_monsters.grid_x - player_info.grid_x)^2 + 
                                            (valid_monsters.grid_y - player_info.grid_y)^2)
                    
                    poe2_api.print_log(string.format("攻击 %s(稀有度:%d) | 距离: %.1f", 
                        valid_monsters.name_utf8 or "未知怪物", valid_monsters.rarity or 0, distance))
                    poe2_api.print_log("血量：" .. valid_monsters.life )
                    
                    -- 特殊Boss处理
                    local special_bosses = {'巨蛇女王．瑪娜莎', '被遺忘的囚犯．帕拉薩'}
                    if poe2_api.table_contains(valid_monsters.name_utf8, special_bosses) and distance > 50 and not valid_monsters.isActive then
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
                                if poe2_api.table_contains(valid_monsters.magicProperties or {}, prop) then
                                    has_special_property = true
                                    break
                                end
                            end
                            
                            if has_special_property then
                                poe2_api.print_log("特殊词缀怪物,或者未激活")
                                env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                                return bret.FAIL
                            end
                        end
                        
                        if valid_monsters.name_utf8 ~= "骨之暴君．札瓦里" then
                            if distance > selected_skill.attack_range and distance > min_attack_range or not valid_monsters.isActive then
                                poe2_api.print_log("移动到目标附近")
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
                    else
                        return bret.RUNNING
                    end
                end)
            end
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
            local current_time = os.time()
            local range_info = env.range_info
            local player_info = env.player_info
            local is_map_complete = env.is_map_complete
            local one_other_map = env.one_other_map
            local not_enter_map = env.not_enter_map
            local click_counter = env.enter_map_click_counter or 0
            local error_other_map = env.error_other_map or {}
            local click_grid_pos = env.click_grid_pos
            
            if not player_info or not range_info then
                
                return bret.RUNNING
            end
            
            -- 检查加载中状态
            -- if poe2_api.click_text_UI_by_time("loading_screen_tip_label") then
            --     if not poe2_api.click_text_UI_by_time("loading_screen_tip_label") then
            --         api_Sleep(5000)
            --     end
            --     
            --     return bret.RUNNING
            -- end
            
            -- 获取符合条件的非地图物品（传送点/异界之门除外）
            local function get_not_map(range_info, num)
                num = num or 1
                local valid_items = {}
                
                for _, item in ipairs(range_info) do
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
                        return poe2_api.point_distance(a.grid_x, a.grid_y, player_info) < poe2_api.point_distance(b.grid_x, b.grid_y, player_info)
                    end)
                    
                    -- 打印排序后的结果（调试用）
                    for i, item in ipairs(valid_items) do
                        local distance = poe2_api.point_distance(item.grid_x, item.grid_y, player_info)
                        poe2_api.print_log(string.format("[DEBUG] #%d: %s 距离=%.2f", i, item.name_utf8, distance))
                    end
                    
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
                if poe2_api.find_text({text = k, UI_info = env.UI_info, min_x = 0}) then
                    if one_other_map then
                        table.insert(error_other_map, one_other_map)
                    end
                    env.one_other_map = nil
                    if not poe2_api.find_text({text = "/clear", min_x = 0}) then
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
                poe2_api.print_log("Enter_Map:is_map_complete ==> " .. tostring(is_map_complete))
                poe2_api.print_log("Enter_Map:one_other_map ==> " .. (one_other_map and one_other_map.name_cn_utf8 or "nil"))
                
                if range_info then
                    local items = get_not_map(range_info)
                    
                    if items and not one_other_map and not is_map_complete and not poe2_api.table_contains({items.name_utf8}, not_enter_map) then
                        poe2_api.print_log("items: " .. items.name_utf8)
                        
                        if poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0}) or 
                        poe2_api.find_text({text = "摧毀三個相似的物品，重鑄為一個新的物品", UI_info = env.UI_info, min_x = 0}) then
                            poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0, click = 2, add_x = 216})
                            env.click_grid_pos = true
                            
                            return bret.RUNNING
                        end
                        
                        if poe2_api.point_distance(items.grid_x, items.grid_y, player_info) > 30 then
                            env.is_map_complete = false
                            env.end_point = {items.grid_x, items.grid_y}
                            
                            return bret.SUCCESS
                        else
                            env.enter_map_click_counter = click_counter + 1
                            if click_grid_pos then
                                api_ClickMove(items.grid_x, items.grid_y, items.world_z - 100, 1)
                                api_Sleep(1000)
                                
                                return bret.RUNNING
                            end
                            
                            poe2_api.find_text_sort({text = items.name_utf8, click = 2})
                            api_Sleep(1000)
                            if not poe2_api.find_text({text = items.name_utf8, UI_info = env.UI_info, click = 2}) then
                                api_ClickMove(items.grid_x, items.grid_y, items.world_z - 100, 1)
                                api_Sleep(1000)
                            end
                            
                            return bret.RUNNING
                        end
                    end
                    
                    local not_map = get_not_map(range_info)
                    if one_other_map and not_map and not is_map_complete and not_map.name_utf8 == one_other_map.name_cn_utf8 and 
                    not poe2_api.table_contains({one_other_map.name_cn_utf8}, not_enter_map) then
                        poe2_api.print_log("not_map: " .. not_map.name_utf8)
                        
                        if not poe2_api.find_text({text = one_other_map.name_cn_utf8, UI_info = env.UI_info, min_x = 0}) and 
                        poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0}) then
                            poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0, click = 2, add_x = 216})
                            env.click_grid_pos = true
                            
                            return bret.RUNNING
                        end
                        
                        -- 记录地图开始时间和名称
                        env.map_start_time = os.time()
                        env.map_name = one_other_map.name_cn_utf8
                        env.map_recorded = false
                        
                        if poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0}) or 
                        poe2_api.find_text({text = "摧毀三個相似的物品，重鑄為一個新的物品", UI_info = env.UI_info, min_x = 0}) then
                            poe2_api.click_position(1013, 25)
                            
                            return bret.RUNNING
                        end
                        
                        if poe2_api.point_distance(not_map.grid_x, not_map.grid_y, player_info) > 30 then
                            env.is_map_complete = false
                            env.end_point = {not_map.grid_x, not_map.grid_y}
                            
                            return bret.SUCCESS
                        else
                            env.enter_map_click_counter = click_counter + 1
                            if click_grid_pos then
                                api_ClickMove(not_map.grid_x, not_map.grid_y, not_map.world_z - 100, 1)
                                api_Sleep(1000)
                                
                                return bret.RUNNING
                            end
                            
                            poe2_api.find_text_sort({text = not_map.name_utf8, click = 2})
                            api_Sleep(1000)
                            if not poe2_api.find_text({text = not_map.name_utf8, UI_info = env.UI_info, click = 2}) then
                                api_ClickMove(not_map.grid_x, not_map.grid_y, not_map.world_z - 100, 1)
                                api_Sleep(1000)
                            end
                            
                            return bret.RUNNING
                        end
                    end
                end
            end
            
            poe2_api.print_log(player_info.current_map_name_utf8)
            
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

            local current_time = os.time()
            local player_info = env.player_info
            local otherworld_info = api_GetEndgameMapNodes()
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
            -- if poe2_api.click_text_UI_by_time("loading_screen_tip_label") then
            --     if not poe2_api.click_text_UI_by_time("loading_screen_tip_label") then
            --         api_Sleep(5000)
            --     end
            --     
            --     return bret.RUNNING
            -- end
            
            if not player_info then
                
                return bret.RUNNING
            end
            
            if not poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0}) then
                
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
                poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0}) then
                    
                    if not one_other_map or (not one_other_map.isMapAccessible and one_other_map.isCompleted) then
                        -- 获取地图信息
                        local map_info = poe2_api.get_map(
                            otherworld_info, sorted_map, not_enter_map, bag_info, 
                            {key_level_threshold = user_map, not_use_map = not_use_map, 
                            priority_map = priority_map, error_other_map = error_other_map, 
                            not_have_stackableCurrency = not_have_stackableCurrency}
                        )
                        
                        if map_info then
                            poe2_api.print_log("map_info.name_utf8: " .. map_info.name_cn_utf8)
                            poe2_api.print_log("map_info.mapPlayModes: " .. tostring(map_info.mapPlayModes))
                        end
                        
                        if not map_info then
                            local point = poe2_api.af_api.api_GetcurrentEndgameNodePoints()
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
                                poe2_api.af_api.api_EndgameNodeMove(target_x, target_y)
                                
                                -- 更新方向和扩张参数
                                self.add_num = (self.add_num % 4) + 1
                                if self.add_num == 1 then
                                    self.expansion_step = self.expansion_step + 1
                                    self.spiral_round = self.spiral_round + 1
                                end
                                
                                poe2_api.print_log("等待地图加载 (5s)")
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
                        if map_info and map_info.mapPlayModes and string.find(map_info.mapPlayModes, "腐化聖域") then
                            entry_length = 4
                            color = 2
                            vall = true
                        end
                        
                        local map_level = poe2_api.select_best_map_key(
                            bag_info, 
                            {key_level_threshold = user_map, not_use_map = not_use_map, 
                            priority_map = priority_map, color = color, entry_length = entry_length, vall = vall}
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
                        
                        if map_info then
                            poe2_api.af_api.api_EndgameNodeMove(map_info.position_x - 1900, map_info.position_y - 1900)
                            env.one_other_map = map_info
                            api_Sleep(1000)
                            
                            return bret.RUNNING
                        else
                            
                            return bret.RUNNING
                        end
                    end
                    
                    if one_other_map then
                        if poe2_api.find_text({text = "地區", UI_info = env.UI_info}) and 
                        poe2_api.find_text({text = "私訊", UI_info = env.UI_info}) and 
                        poe2_api.find_text({text = "公會", UI_info = env.UI_info}) then
                            poe2_api.click_keyboard('esc')
                        end
                        
                        if type(one_other_map) == "boolean" then
                            self.last_action_time = current_time
                            
                            return bret.RUNNING
                        end
                        
                        if one_other_map.name_utf8 and not poe2_api.table_contains(my_game_info.trash_map, one_other_map.name_utf8) and 
                        one_other_map.isMapAccessible and not one_other_map.isCompleted then
                            
                            if not poe2_api.find_text({text = "穿越", UI_info = env.UI_info, min_x = 0}) then
                                if self.open_num > 5 and poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, max_y = 100, min_x = 0}) then
                                    poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, max_y = 100, min_x = 0, click = 2, add_x = 212})
                                    table.insert(error_other_map, one_other_map)
                                    env.one_other_map = nil
                                    api_Sleep(1000)
                                    self.open_num = 0
                                    
                                    return bret.RUNNING
                                end
                                
                                poe2_api.af_api.api_EndgameNodeMove(one_other_map.position_x - 1900, one_other_map.position_y - 1900)
                                api_Sleep(200)
                                
                                local one_other_map_refresh = poe2_api.af_api.api_GetEndgameMapNodes()
                                if one_other_map_refresh then
                                    for _, k1 in ipairs(one_other_map_refresh) do
                                        if k1.name_utf8 == one_other_map.name_utf8 and 
                                        k1.index_x == one_other_map.index_x and 
                                        k1.index_y == one_other_map.index_y then
                                            if k1.window_client_x == 0 or k1.window_client_y == 0 then
                                                env.need_SmallRetreat = true
                                                
                                                return bret.RUNNING
                                            end
                                            poe2_api.natural_move(k1.window_client_x, k1.window_client_y)
                                            api_Sleep(500)
                                        end
                                    end
                                end
                                
                                if poe2_api.find_text({text = one_other_map.name_cn_utf8, UI_info = env.UI_info, min_x = 0}) then
                                    poe2_api.af_api.api_LeftClick()
                                    api_Sleep(500)
                                    poe2_api.af_api.api_EndgameNodeMove(one_other_map.position_x - 3900, one_other_map.position_y - 3900)
                                end
                                
                                self.last_action_time = current_time
                                self.open_num = self.open_num + 1
                                api_Sleep(100)
                                
                                return bret.RUNNING
                            end
                            
                            if not poe2_api.find_text({text = "背包", UI_info = env.UI_info}) then
                                poe2_api.click_keyboard('i')
                                self.last_action_time = current_time
                                
                                return bret.RUNNING
                            end
                            
                            local k = poe2_api.find_text({text = "穿越", min_x = 0, position = 2})
                            if poe2_api.find_text({text = "背包"}) and k then
                                if k.text_utf8 == '穿越' then
                                    local center_x = math.floor((k.left + k.right) / 2)
                                    local center_y = math.floor((k.top + k.bottom) / 2)
                                    local count = poe2_api.af_api.api_Getinventorys(0xe)
                                    
                                    if count then
                                        entry_length = 0
                                        local map_level = nil
                                        local vall = false
                                        
                                        if one_other_map and one_other_map.mapPlayModes and 
                                        string.find(one_other_map.mapPlayModes, "腐化聖域") then
                                            entry_length = 4
                                            vall = true
                                        end
                                        
                                        map_level = poe2_api.select_best_map_key(
                                            count, 
                                            {key_level_threshold = user_map, not_use_map = not_use_map, 
                                            priority_map = priority_map, color = color, vall = vall}
                                        )
                                        
                                        if map_level and (#count > 1 or (entry_length > 0 and entry_length > map_level.fixedSuffixCount)) then
                                            for _, k in ipairs(count) do
                                                poe2_api.select_best_map_key(
                                                    {inventory = poe2_api.af_api.api_Getinventorys(0xe), index = 1, click = 1, 
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
                                    if poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, max_y = 100, min_x = 250}) then
                                        poe2_api.click_keyboard('space')
                                    end
                                    
                                    return bret.SUCCESS
                                end
                                
                                entry_length = 0
                                local vall = false
                                if one_other_map and one_other_map.mapPlayModes and 
                                string.find(one_other_map.mapPlayModes, "腐化聖域") then
                                    entry_length = 4
                                    color = 2
                                    vall = true
                                end
                                
                                local map_level = poe2_api.select_best_map_key(
                                    bag_info, 
                                    {key_level_threshold = user_map, not_use_map = not_use_map, 
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
                                    bag_info, 
                                    {click = 1, key_level_threshold = user_map, not_use_map = not_use_map, 
                                    priority_map = priority_map, entry_length = entry_length}
                                )
                                
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
                                    poe2_api.print_log("背包没有合适的地图钥匙")
                                    env.map_level_dis = nil
                                    env.is_have_map = false
                                end
                                
                                api_Sleep(500)
                                
                                return bret.RUNNING
                            else
                                local maps = poe2_api.af_api.api_Getinventorys(0xe)
                                if maps and #maps > 0 then
                                    poe2_api.print_log("len(maps): " .. #maps)
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
                                        local suffx = poe2_api.af_api.api_GetObjectSuffix(maps[1].mods_obj)
                                        if suffx and #suffx < entry_length then
                                            poe2_api.select_best_map_key(
                                                {inventory = poe2_api.af_api.api_Getinventorys(0xe), index = 1, 
                                                click = 1, type = 3, START_X = center_x - 47, START_Y = center_y - 125}
                                            )
                                            env.one_other_map = nil
                                            env.map_level_dis = nil
                                            
                                            return bret.RUNNING
                                        end
                                    end
                                    
                                    if poe2_api.find_text({text = "穿越", UI_info = env.UI_info, click = 2, min_x = 0}) then
                                        env.click_traverse = true
                                        poe2_api.print_log("点击穿越成功")
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

            local current_time = os.time()
            local UI_info = env.UI_info
            local one_other_map = env.one_other_map
            local range_info = env.range_info
            local click_traverse = env.click_traverse
            local error_other_map = env.error_other_map or {}
            
            if not click_traverse then
                env.one_other_map = nil
                env.is_map_complete = true
                
                return bret.RUNNING
            end

            if not range_info or not one_other_map then
                
                return bret.RUNNING
            end
            
            -- 获取非地图物品（传送点/异界之门除外）
            local function get_not_map(range_info)
                for _, item in ipairs(range_info) do
                    if item.type == 5 and item.name_utf8 ~= '' and 
                    item.name_utf8 ~= "傳送點" and item.name_utf8 ~= '異界之門' then
                        return item
                    end
                end
                return false
            end
            
            local not_map = get_not_map(range_info)
            
            if one_other_map then
                local error_text = {
                    "錯誤：無法進入，原因：伺服器斷線。",
                    "錯誤：無法進入。",
                    "啟動失敗。地圖無法進入。"
                }
                
                for _, k in ipairs(error_text) do
                    if poe2_api.find_text({text = k, UI_info = env.UI_info, min_x = 0}) then
                        table.insert(error_other_map, one_other_map)
                        env.one_other_map = nil
                        env.is_map_complete = true
                        
                        if not poe2_api.find_text({text = "/clear", min_x = 0}) then
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
                    if poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, max_y = 100, min_x = 250}) then
                        poe2_api.click_position(1013, 25)
                    end
                    
                    return bret.RUNNING
                end
                
                if not_map and not_map.name_utf8 ~= one_other_map.name_cn_utf8 then
                    api_Sleep(3000)
                    
                    return bret.RUNNING
                end
                
                if not poe2_api.find_text({text = one_other_map.name_cn_utf8, UI_info = env.UI_info, min_x = 0}) then
                    if poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, max_y = 100, min_x = 250}) then
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

            local current_time = os.time()
            local player_info = env.player_info
            
            if current_time - self.last_action_time >= self.action_interval then
                if player_info and 
                poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and 
                not poe2_api.find_text({text = "世界地圖", UI_info = env.UI_info, min_x = 0}) then
                    
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
            nearest_distance_sq = math.huge
            monsters = env.range_info
            if monsters then
                -- 先确定当前目标
                for _, monster in ipairs(monsters) do
                    if stuck_monsters then
                        if stuck_monsters[monster.id] then
                            goto continue
                        end
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
                    
                    if my_game_info.not_attact_mons_path_name[monster.path_name_utf8] then
                        goto continue
                    end
                    
                    if not_attack_mos and not_attack_mos[monster.rarity] then
                        goto continue
                    end
                    
                    if monster.rarity == 0 or monster.rarity == 1 then
                        goto continue
                    end
                    
                    if monster.hasLineOfSight then
                        goto continue
                    end
                    
                    -- 计算距离平方
                    local distance_sq = poe2_api.point_distance(monster.grid_x, monster.grid_y, player_info)
                    
                    if distance_sq < nearest_distance_sq then
                        nearest_distance_sq = distance_sq
                        valid_monsters = monster
                    end
                    ::continue::
                end
            end
            
            if valid_monsters then
                if end_point and path_list then
                    local dis = poe2_api.point_distance(valid_monsters.grid_x, valid_monsters.grid_y,{end_point[1], end_point[2]})
                    if dis > 25 then
                        env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                    end
                else
                    env.end_point = {valid_monsters.grid_x, valid_monsters.grid_y}
                end
                return bret.FAIL
            else
                return bret.SUCCESS
            end
            -- return bret.SUCCESS
        end
    },

    -- 检查是否在异界中
    Check_In_Otherworld_Map = {
        run = function(self, env)
            poe2_api.print_log("检查是否在异界中...")
            if poe2_api.table_contains(env.player_info.current_map_name_utf8,my_game_info.hideout) then
                return bret.FAIL
			end
            if not (poe2_api.find_text({text = 'Standard 聯盟',UI_info=env.UI_info,max_x=1800}) or poe2_api.find_text({text = 'Dawn of the Hunt 聯盟', UI_info = env.UI_info, max_x=1800})) and not poe2_api.table_contains(env.player_info.current_map_name_utf8,my_game_info.hideout) then
                poe2_api.click_keyboard("tab")
                api_Sleep(1000)
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
            local result = false
            local radius = 160
            UI_info = env.UI_info
            current_time = os.time()
            player_info = env.player_info
            range_indfo = env.range_info

            if not self.last_action_time then
                self.last_action_time = os.time()
                self.action_interval = 1
                self.false_times = 0
            end
            

            -- 主要逻辑
            if no_mos_back then
                result = poe2_api.monster_monitor(45,UI_info)
            else
                result = true
            end

            if string.find(player_info.current_map_name_utf8 or "","Claimable") then
                result = poe2_api.monster_monitor(0,UI_info)
                radius = 30
            end

            if current_time - self.last_action_time >= self.action_interval then
                point = api_GetUnexploredArea(radius)
                if point and env.have_ritual then
                    env.is_map_complete = false
                    env.end_point = {point.x, point.y}
                    env.is_arrive_end = false
                    return bret.SUCCESS
                end

                poe2_api.print_log("地圖完成")

                if not point or (poe2_api.find_text({text = "地圖完成",UI_info = UI_info}) and (result or poe2_api.find_text({text = "競技場",UI_info = UI_info,min_x=0,max_x=1600}))) or (poe2_api.find_text({text ="剩餘 0 隻怪物",UI_info = UI_info}) and not poe2_api.table_contains(player_info.current_map_name_utf8,my_game_info.PRIORITY_MAPS)) then
                    -- 提前结束迷雾状态
                    -- if poe2_api.click_text_UI({text = "delirium_skip_delay_button",UI_info = UI_info,click=2}) then
                    --     api_Sleep(1000)
                    --     return bret.RUNNING
                    -- end
                

                    -- Boss战Bug记录点回城
                    if player_info.isInBossBattle then
                        local list = poe2_api.get_sorted_list(range_info)
                        for _, item in ipairs(list) do
                            if item.name_utf8 == "記錄點" then
                                env.end_point = {item.grid_x, item.grid_y}
                                env.is_arrive_end = false
                                return bret.SUCCESS
                            end
                        end
                    end

                    env.is_map_complete = true
                    env.one_other_map = None
                    if not string.find(player_info.current_map_name_utf8 or "", "town") and not poe2_api.table_contains(player_info.current_map_name_utf8, my_game_info.hideout) or poe2_api.table_contains(player_info.current_map_name_utf8, PRIORITY_MAPS) then
                        -- 寻找传送门
                        for _, k in ipairs(range_info) do
                            if k.name_utf8 ~= '' and k.type == 5 and poe2_api.table_contains(k.name_utf8, my_game_info.hideout_CH) then
                                dis = poe2_api.point_distance(k.grid_x, k.grid_y, player_info)
                                poe2_api.print_log(dis)
                                if dis < 25 then
                                    if not poe2_api.find_text({text = k.name_utf8, UI_info = UI_info, click = 2}) then
                                        api_ClickMove(k.grid_x, k.grid_y, k.world_z-100, 1)
                                    end
                                    api_Sleep(200)
                                    env.false_times = 0
                                    return bret.RUNNING
                                end
                            end
                        end
                        api_ClickMove(player_info.grid_x,player_info.grid_y,player_info.world_z,1)
                        api_Sleep(200)
                        api_ClickMove(player_info.grid_x,player_info.grid_y,player_info.world_z,7)
                        api_Sleep(500)
                        api_ClickScreen(1230, 815, 1)
                        api_Sleep(500)
                        self.false_times = self.false_times + 1
                        env.false_times = self.false_times
                        self.last_action_time = current_time + 2

                        no = poe2_api.is_have_mos({range_info = range_info, player_info = player_info,dis = 80, not_sight = 1})
                        if no then
                            point = api_GetSafeAreaLocationNoMonsters(80)
                            if point then
                                env.end_point = point
                                env.is_arrive_end = false
                                return bret.SUCCESS
                            end
                            env.drop_items = true
                        end
                        return bret.RUNNING
                    else
                        env.return_town = false
                        point = api_FindRandomWalkablePosition(player_info.grid_x,player_info.grid_y,50)
                        if point then
                            api_ClickMove(point.x, point.y, player_info.world_z - 70, 3)
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

    -- 地图强化
    Map_Strengthened = {
        run = function(self, env)
            poe2_api.print_log("强化地图...")
            return bret.SUCCESS
        end
    },

    -- 强化(通用)
    Strengthened = {
        run = function(self, env)
            poe2_api.print_log("执行强化操作...")
            return bret.SUCCESS
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

    -- 获取物品数量
    Obtain_The_Quantity_of_Items = {
        run = function(self, env)
            poe2_api.print_log("获取物品数量...")
            return bret.SUCCESS
        end
    },

    -- 点击所有仓库页
    Click_All_Pages = {
        run = function(self, env)
            local current_time = os.time()
            
            -- 检查仓库页面是否可用
            local function check_pages()
                local pages = poe2_api.af_api.api_GetRepositoryPages()
                for _, page in ipairs(pages) do
                    if page.manage_index == 0 and page.type ~= 5 then
                        return false
                    end
                end
                return true
            end

            -- 主逻辑
            if check_pages() then
                poe2_api.infos_time(current_time, "点击所有仓库页")
                return bret.FAIL
            end

            -- 检查是否在正确界面
            if not poe2_api.find_text(nil, "強調物品", 250, 700) or 
            not poe2_api.find_text(nil, "倉庫", 0, 32, 381, 81) then
                poe2_api.infos_time(current_time, "点击所有仓库页")
                return bret.SUCCESS
            end

            sleep(2)

            -- 获取仓库页面和控制元素
            local list_button = poe2_api.af_api.get_game_control_by_rect(499, 36, 582, 125)
            local tab_list_button = nil
            for _, control in ipairs(list_button) do
                if control.name_utf8 == "tab_list_button" then
                    tab_list_button = control
                    break
                end
            end

            local item_pages = {}
            local pages = poe2_api.af_api.api_GetRepositoryPages()
            if pages then
                for _, page in ipairs(pages) do
                    if page.type ~= 5 then
                        table.insert(item_pages, page)
                    end
                end
            end

            -- 处理不同界面状态
            if not tab_list_button then
                -- 未展开标签列表的情况
                for _, page in ipairs(item_pages) do
                    if keyboard.is_pressed('down') then break end
                    poe2_api.find_text(nil, page.name_utf8, 0, 0, 550, 90, 2)
                    sleep(0.1)
                end
            else
                -- 已展开标签列表的情况
                local lock = poe2_api.af_api.get_game_control_by_rect(546, 32, 589, 76)
                local lock_button = nil
                for _, control in ipairs(lock) do
                    if control.left >= 549 and control.top >= 34 and 
                    control.right <= 584 and control.bottom and 
                    control.name_utf8 ~= 'bottom_icons_layout' then
                        lock_button = control
                        break
                    end
                end

                if not lock_button then
                    -- 需要先展开列表
                    poe2_api.natural_move(
                        (tab_list_button.left + tab_list_button.right) / 2,
                        (tab_list_button.top + tab_list_button.bottom) / 2
                    )
                    poe2_api.af_api.api_LeftClick()
                    sleep(0.2)
                else
                    -- 直接点击各页面
                    for _, page in ipairs(item_pages) do
                        if keyboard.is_pressed('down') then break end
                        poe2_api.find_text(nil, page.name_utf8, 556, 20, 851, 469, 2)
                        sleep(0.1)
                    end
                end
            end

            poe2_api.infos_time(current_time, "点击所有仓库页")
            return bret.RUNNING
        end
    },

    -- 点击交互文本
    Click_Item_Text = {
        run = function(self, env)
            local current_time = os.time()
            local interactive_object = env.interactive
            local player_info = env.player_info
            local current_map_info = env.current_map_info
            local range_info = env.range_info
            local path_list = env.path_list
            local need_item = env.need_item
            local UI_info = env.UI_info
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
                if not range_info then
                    return nil
                end
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
                    local ralet = api_FindPath(player_info.grid_x, player_info.grid_y, x, y)
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
                    poe2_api.print_log("未找到对象")
                    return bret.FAIL
                end
                
                local distance = poe2_api.point_distance(target_obj.grid_x, target_obj.grid_y, player_info)
                poe2_api.print_log("交互对象: "..target_obj.name_utf8.." | 位置: "..target_obj.grid_x..","..target_obj.grid_y.." | 距离: "..distance)
                
                if need_move(target_obj) then
                    poe2_api.print_log("移动交互对象")
                    return bret.FAIL
                end

                poe2_api.print_log("点击交互对象")

                if env.target_point and env.end_point then
                    poe2_api.print_log("取消按键")
                    -- api_ClickMove(env.target_point[1], env.target_point[2], player_info.world_z, 9)
                    api_ClickMove(env.target_point[1], env.target_point[2], player_info.world_z, 7)
                    api_Sleep(100)
                end
                
                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                    api_Sleep(500)
                end
                
                if target_obj.name_utf8 == "MapDevice" then
                    local m_list = {"黃金製圖儀", "地圖裝置"}
                    api_Sleep(800)
                    local maps = check_in_range('Metadata/Terrain/Missions/Hideouts/Objects/MapDeviceVariants/ZigguratMapDevice')
                    if poe2_api.find_text({UI_info = UI_info, text = '地圖裝置', click = 2}) then
                        api_Sleep(100)
                        return bret.RUNNING
                    end
                    if maps then
                        api_ClickMove(maps.grid_x, maps.grid_y, maps.world_z - 70, 0)
                        api_Sleep(800)
                    end
                    for _, i in ipairs(m_list) do
                        if poe2_api.find_text({UI_info = UI_info, text = i, click = 2}) then
                            api_Sleep(100)
                            return bret.RUNNING
                        end
                    end
                end
                
                if poe2_api.table_contains(my_game_info.hideout, player_info.current_map_name_utf8) and target_obj.name_utf8 ~= '傳送點' and not map_obj then
                    poe2_api.find_text({UI_info = UI_info, text = interactive_object, click = 2})
                    api_Sleep(100)
                    return bret.RUNNING
                end
                
                if player_info.isMoving then
                    poe2_api.print_log("等待静止")
                    api_Sleep(200)
                    return bret.RUNNING
                end
                
                if not poe2_api.find_text({UI_info = UI_info, text = interactive_object, click = 2}) then
                    api_ClickMove(target_obj.grid_x, target_obj.grid_y, player_info.world_z - 70, 1)
                end
                api_Sleep(100)
            end
            return bret.RUNNING
        end
    },

    -- 打开交换界面
    Open_The_Exchange_Interface = {
        run = function(self, env)
            poe2_api.print_log("打开交换界面...")
            return bret.SUCCESS
        end
    },

    -- 点击所有取消
    Click_All_Cancel = {
        run = function(self, env)
            poe2_api.print_log("点击所有取消按钮...")
            return bret.SUCCESS
        end
    },

    -- 点击旧的兑换
    Click_Old_Exchange = {
        run = function(self, env)
            poe2_api.print_log("点击旧的兑换...")
            return bret.SUCCESS
        end
    },

    -- 点击所有兑换
    Click_All_Exchange = {
        run = function(self, env)
            poe2_api.print_log("点击所有兑换...")
            return bret.SUCCESS
        end
    },

    -- 点击无状态兑换
    Click_Stateless_Exchange = {
        run = function(self, env)
            poe2_api.print_log("点击无状态兑换...")
            return bret.SUCCESS
        end
    },

    -- 选择和交换
    Select_AND_Exhange = {
        run = function(self, env)
            poe2_api.print_log("选择和交换物品...")
            return bret.SUCCESS
        end
    },

    -- 对话鉴定NPC
    Dialogue_Appraisal_NPC = {
        run = function(self, env)
            poe2_api.print_log("对话鉴定NPC...")
            return bret.SUCCESS
        end
    },

    -- 是否需要鉴定
    is_need_identify = {
        run = function(self, env)
            poe2_api.print_log("检查是否需要鉴定...")
            return bret.SUCCESS
        end
    },

    -- 打开合成界面
    Synthesis_Interface = {
        run = function(self, env)
            poe2_api.print_log("打开合成界面...")
            return bret.SUCCESS
        end
    },

    -- 点击物品合成
    Click_On_The_Item_To_Synthesize = {
        run = function(self, env)
            poe2_api.print_log("点击物品合成...")
            return bret.SUCCESS
        end
    },

    -- 地租页面
    dizhu_page = {
        run = function(self, env)
            poe2_api.print_log("处理地租页面...")
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
                return bret.FAIL
                -- poe2_api.print_log("正在前往目标点...111222")
                -- return bret.RUNNING
            end
            
            -- 检查空路径
            if env.empty_path then
                env.is_arrive_end = true
                env.empty_path = false
                return bret.SUCCESS
                -- poe2_api.print_log("正在前往目标点...111111")
                -- return bret.RUNNING
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
                    poe2_api.print_log("yidongdaodianzant")
                    api_ClickMove(poe2_api.toExactInt(env.target_point[1]), poe2_api.toExactInt(env.target_point[2]),poe2_api.toExactInt(player_info.world_z), 9)
                end
                return bret.FAIL
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
            local player_info = env.player_info
            local range_info = env.range_info
            

            -- 辅助函数：检测祭坛
            -- local function get_altar(range_info)
            --     for _, entity in ipairs(range_info) do
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
                poe2_api.print_log("[GET_Path] 错误：未设置终点")
                return bret.FAIL
            end

            -- 如果已有路径，使用下一个路径点
            local path_list = env.path_list
            -- poe2_api.print_log("路径点数env.path_list: " .. #path_list)

            if path_list and #path_list > 1 then
                local dis = poe2_api.point_distance(path_list[1].x, path_list[1].y, player_info)
                if dis and dis < 20 then
                    env.target_point = {path_list[1].x, path_list[1].y}
                    table.remove(path_list, 1) -- 移除已使用的点
                end
                return bret.SUCCESS
            end
            
            -- 计算最近可到达的点
            point = api_FindNearestReachablePoint(point[1],point[2], 50, 0)
            -- poe2_api.print_log(point)
            
            -- 计算起点
            player_position = api_FindNearestReachablePoint(player_info.grid_x, player_info.grid_y, 50, 0)

            local result = api_FindPath(player_position.x, player_position.y, point.x, point.y)
            
            if result and #result > 0 then
                -- 处理路径结果
                result = poe2_api.extract_coordinates(result, 15)
                if #result > 1 then
                    table.remove(result, 1) -- 移除起点
                    env.path_list = result
                    env.target_point = {result[1].x, result[1].y}
                    poe2_api.print_log("[GET_Path] 路径计算成功，点数: " .. #result)
                end
                return bret.SUCCESS
            else
                -- 路径计算失败处理
                -- local altar = get_altar(range_info)
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
                poe2_api.print_log("[GET_Path] 错误：找不到路径")
                return bret.FAIL
            end
        end
    },

    Move_To_Target_Point = {
        run = function(self, env)
            -- 初始化逻辑直接放在 run 函数开头
            
            if not self.last_move_time then
                poe2_api.print_log("初始化 Move_To_Target_Point 节点...")
                self.last_move_time = os.time()
                self.last_point = nil
                return bret.RUNNING  -- 初始化后返回 RUNNING，等待下一帧继续执行
            end
    
            -- 正常执行移动逻辑
            poe2_api.print_log("移动到目标点...")
            local point = env.target_point
            if not point then 
                poe2_api.print_log("[Move_To_Target_Point] 错误：未设置目标点")
                return bret.SUCCESS
            end
    
            local player_info = env.player_info
            if not player_info then
                poe2_api.print_log("[Move_To_Target_Point] 错误：未设置玩家信息")
                return bret.FAIL
            end
            -- 检查终点是否变化
            local end_point = env.end_point
            if not self.last_point and end_point then
                poe2_api.print_log("设置last_point")
                self.last_point = end_point
            end
            self.current_time = os.time()
            self.move_interval = math.random() * 0.0001 + 0.00001  -- 随机间隔 0.1~0.2 秒
            
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
                    return bret.RUNNING
                end
            end
            
            -- 执行移动（按时间间隔）
            if self.current_time - self.last_move_time >= 0.00000001 then
                if point then
                    local dis = poe2_api.point_distance(point[1], point[2], player_info)
                    if dis and dis > 70 then
                        env.path_list = nil
                        env.target_point = {}
                        env.is_arrive_end = true
                        return bret.RUNNING
                    end
                    api_ClickMove(poe2_api.toExactInt(point[1]), poe2_api.toExactInt(point[2]), poe2_api.toExactInt(player_info.world_z), 8)
                    self.last_move_time = self.current_time
                end
            end
    
            -- 检查是否到达目标点
            if point then
                local dis = poe2_api.point_distance(point[1], point[2], player_info)
                -- poe2_api.print_log("距离：" .. dis)
                if dis and dis < 20 then
                    if env.path_list and #env.path_list > 0 then
                        env.target_point = {env.path_list[1].x, env.path_list[1].y}
                        table.remove(env.path_list, 1)
                    end
                    return bret.SUCCESS
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
    login_state = nil, -- 登录状态，初始值为None
    speel_ip_number = 0, -- 設置当前IP地址的数量，初始值为0
    is_game_exe = false, -- 游戏是否正在执行，初始值为false
    shouting_number = 0, -- 喊话次数，初始值为0
    area_list = {}, -- 存储区域列表，初始值为空列表
    account_state = nil, -- 账户状态，初始值为None
    switching_lines = 0, -- 线路切换状态，初始值为0
    time_out = 0, --  超时时间，初始值为0
    skill_name = nil, -- 当前技能名称，初始值为None
    skill_pos = nil, -- 当前技能位置，初始值为None
    is_need_check = false, -- 是否需要检查，初始值为false
    item_name = nil, -- 当前物品名称，初始值为None
    item_pos = nil, -- 当前物品位置，初始值为None
    -- blackboard.set("user_config", parser)  # 用户配置
    check_all_points = false, -- 是否检查所有点，初始值为false
    path_list = {}, -- 存储路径列表，初始值为空列表
    empty_path = false, -- 路径是否为空，初始值为false
    boss_name = my_game_info.boss_name,  -- 当前boss名称，初始值为None
    map_name = nil, -- 当前地图名称，初始值为None
    interaction_object = nil, -- 交互对象，初始值为None
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
    end_point = {636,1214},
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
    range_info = nil, -- 周围信息
    range_item_info = nil, -- 周围装备信息
    shortcut_skill_info = nil, -- 快捷栏技能信息
    allskill_info = nil, -- 全部技能信息
    selectableskill_info = nil, -- 可选技能技能控件信息
    skill_gem_info = nil, -- 技能宝石列表信息
    team_info = nil, -- 获取队伍信息
    player_info = nil, -- 人物信息
    UI_info = UI_info, -- UI信息
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
    start_time = nil, -- 設置黑板变量 开始时间，初始化为 None
    life_time = nil, -- 設置黑板变量 復活时间，初始化为 None
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
    center_point = 0, -- 半径
    center_radius = {}, -- 中心点
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
    
    local bt = behavior_tree.new("shop", env_params)
    -- local bt = behavior_tree.new("gongji", env_params)
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
--     poe2_api.print_log("\n=== 游戏Tick开始 ===")
--     i = 0
--     while true do
--         poe2_api.print_log("\n=== 游戏Tick", i, "===")
--         bt.run()
--         -- 模拟延迟
--         sleep(0.5)
--         i = i + 1
--     end
-- end

return otherworld_bt
