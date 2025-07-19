-- 根据otherworld.json实现的完整行为树系统
package.path = package.path .. ';lualib/?.lua'
local behavior_tree = require 'behavior3.behavior_tree'
local bret = require 'behavior3.behavior_ret'
-- 加载基础节点类型
local base_nodes = require 'behavior3.sample_process'

-- 自定义节点实现
local custom_nodes = {
    -- 获取用户配置信息
    Get_User_Config_Info = {
        run = function(node, env)
            print("获取用户配置信息...")
            return bret.SUCCESS
        end
    },

    -- 加入游戏异界
    Join_Game_Otherworld = {
        run = function(node, env)
            print("加入异界游戏...")
            return bret.SUCCESS
        end
    },

    -- 官方加入游戏
    Official_Join_Game = {
        run = function(node, env)
            print("通过官方渠道加入游戏...")
            return bret.SUCCESS
        end
    },

    -- 通过Steam启动游戏
    Launch_Game_Steam = {
        run = function(node, env)
            print("通过Steam启动游戏...")
            return bret.SUCCESS
        end
    },

    -- 获取信息
    Get_Info = {
        run = function(node, env)
            print("获取游戏信息...")
            local size = Actors:Update()
            if size > 0 then
                print("发现对象数量: " .. size .. "\n")
                env.range_info = size
            end
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
                env.poe2_api.infos_time(current_time, self.name)
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
                    env.poe2_api.infos_time(current_time, self.name)
                    return bret.RUNNING
                end
                
                self.time = current_time
            end
            
            env.poe2_api.infos_time(current_time, self.name)
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
                env.poe2_api.api_print("小退超时")
                env.error_kill = true
                self.error_kill_start_time = nil  -- 重置计时器
                env.need_SmallRetreat = false
                env.poe2_api.infos_time(current_time, self.name)
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
                            env.poe2_api.infos_time(current_time, self.name)
                            return bret.RUNNING
                        
                        elseif poe2_api.click_text_UI("exit_to_character_selection", nil, 2) then
                            if not self.error_kill_start_time then
                                self.error_kill_start_time = current_time
                            end
                            sleep(6)
                            env.poe2_api.infos_time(current_time, self.name)
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
                            env.poe2_api.infos_time(current_time, self.name)
                            return bret.RUNNING
                        end

                        -- 成功执行后重置超时计时器
                        self.error_kill_start_time = nil
                        env.last_exp_check = current_time
                        env.last_exception_time = 0
                        env.need_SmallRetreat = false
                        self:reset_states(env)
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.RUNNING
                    else
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.RUNNING  -- 仍在运行状态，等待间隔
                    end
                end)
                
                if not success then
                    self.error_kill_start_time = nil  -- 异常时重置计时器
                    env.need_SmallRetreat = false
                    env.poe2_api.infos_time(current_time, self.name)
                    return bret.FAILURE
                end
            else
                self.error_kill_start_time = nil  -- 不需要小退时重置计时器
                env.poe2_api.infos_time(current_time, self.name)
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
                env.poe2_api.infos_time(current_time, self.name)
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
                            env.poe2_api.infos_time(current_time, self.name)
                            return bret.RUNNING
                        end
                    end
                    
                    if env.poe2_api.find_text("恩賜之物", nil, 0, 0) then
                        env.poe2_api.find_text("恩賜之物", nil, 0, 0, 2, 272)
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.RUNNING
                    end
                    
                    if player_info.isInBossBattle then
                        env.need_ReturnToTown = false
                        env.need_SmallRetreat = true
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.RUNNING
                    end
                    
                    if env.poe2_api.is_have_mos(range_info, player_info) or self:spcify_monsters(range_info) then
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.SUCCESS
                    end
                    
                    if not string.find(player_info.current_map_name_utf8, "town") and not my_game_info.hideout[player_info.current_map_name_utf8] then
                        if env.poe2_api.find_text("傳送", 0, 700, 40, 830) then
                            env.poe2_api.click_keyboard("space")
                            env.poe2_api.infos_time(current_time, self.name)
                            return bret.RUNNING
                        end
                        
                        for _, k in ipairs(range_info) do
                            if k.name_utf8 ~= '' and k.type == 5 and my_game_info.hideout_CH[k.name_utf8] then
                                if env.poe2_api.point_distance(k.grid_x, k.grid_y, player_info) < 25 then
                                    if not env.poe2_api.find_text(k.name_utf8, nil, 0, 0, 2) then
                                        env.poe2_api.af_api.api_click_move(k.grid_x, k.grid_y, k.world_z-100, 1)
                                    end
                                    env.poe2_api.infos_time(current_time, self.name)
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
                        env.poe2_api.infos_time(current_time, self.name)
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
                            env.poe2_api.infos_time(current_time, self.name)
                            return bret.SUCCESS
                        end
                        
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.RUNNING
                    end
                end)
                
                if not success then
                    env.poe2_api.infos_time(current_time, self.name)
                    return bret.RUNNING
                else
                    return status
                end
            else
                env.poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
        end
    },

    -- 检查长时间经验加成
    Check_LongTime_EXP_Add = {
        name = "检查长时间经验加成",
        last_check = 0,  -- 节流控制变量
        last_alt_press_time = 0,
        movement_threshold = 15,  -- 移动阈值（像素）
        
        reset_states_exp = function(self, env)
            -- 统一状态重置方法
            local current_time = os.time()
            local current = env.player_info
            env.last_exception_time = 0
            env.last_exp_check = current_time
            env.last_exp_value = env.player_info.currentExperience
            env.last_position = {current.grid_x, current.grid_y}
            -- logger.debug("已重置所有经验监控状态")
        end,
        
        reset_states_move = function(self, env)
            -- 统一状态重置方法
            local current_time = os.time()
            local current = env.player_info
            env.last_exception_time_move = 0
            env.last_exp_check_move = current_time
            env.last_exp_value_move = env.player_info.currentExperience
            env.last_position = {current.grid_x, current.grid_y}
            -- logger.debug("已重置所有经验监控状态")
        end,
        
        _check_stagnant_movement = function(self, env)
            -- 检查是否处于停滞移动状态
            local current = env.player_info
            local last_pos = env.last_position or {0, 0}
            local distance = env.poe2_api.point_distance(last_pos[1], last_pos[2], current)
            -- 更新位置记录
            env.last_position = {current.grid_x, current.grid_y}
            return distance < self.movement_threshold
        end,
        
        _check_feature_enabled = function(self, config)
            -- 检查至少有一个異常處理功能启用
            -- 经验相关功能
            local exp_town_enabled = config["全局設置"]["異常處理"]["沒有經驗回城"]["是否開啟"] or false
            local exp_retreat_enabled = config["全局設置"]["異常處理"]["沒有經驗小退"]["是否開啟"] or false
            
            -- 移动相关功能
            local move_town_enabled = config["全局設置"]["異常處理"]["不動回城"]["是否開啟"] or false
            local move_retreat_enabled = config["全局設置"]["異常處理"]["不動小退"]["是否開啟"] or false
            
            -- 任一功能启用即为true
            return exp_town_enabled or exp_retreat_enabled or move_town_enabled or move_retreat_enabled
        end,
        
        get_range = function(self, range_info, player_info)
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
        end,
        
        run = function(self, env)
            local current_time = os.time()
            local take_rest = env.take_rest or false
            local buy_items = env.buy_items or false
            
            -- 节流控制
            if current_time - self.last_check < 0.5 then
                env.poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            self.last_check = current_time
            
            local player = env.player_info
            if not player then
                env.poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            
            local config = env.user_config or {}
            if take_rest then
                -- logger.info("正在休息，跳过异常处理")
                return bret.SUCCESS
            end
            
            -- 检查移动状态
            local is_moving = self:_check_stagnant_movement(env)
            
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
                self:reset_states_exp(env)
            end
            
            if not is_moving then
                self:reset_states_move(env)
            end
            
            -- 计算真实停滞时间
            local real_stagnation_time = current_time - (env.last_exp_check or 0)
            local real_stagnation_time_move = current_time - (env.last_exp_check_move or 0)
            
            -- 定期按alt键
            if current_time - self.last_alt_press_time >= 20 then
                env.poe2_api.click_keyboard("alt")
                env.poe2_api.af_api.api_KeyUp("alt")
                env.poe2_api.af_api.api_KeyUp("alt")
                sleep(0.1)
                self.last_alt_press_time = current_time
            end
            
            local map_strenght = env.strengthened_map_obj
            local space_time = 8
            local return_town = env.return_town or false
            
            if my_game_info.hideout[player.current_map_name_utf8] then
                if env.poe2_api.find_text("世界地圖", nil, 0) then
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
                env.poe2_api.api_print(string.format("未移动时间：%.2f秒", real_stagnation_time_move))
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
                    
                    if env.poe2_api.find_text("繼續遊戲", nil, 0, 0, 2) then
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.SUCCESS
                    end
                    
                    if env.poe2_api.find_text("恩賜之物", nil, 0, 0) then
                        env.poe2_api.click_position(1570, 57)
                        env.poe2_api.infos_time(current_time, self.name)
                        return bret.SUCCESS
                    end
                    
                    local player_info = env.poe2_api.af_api.api_GetLocalPlayer()
                    local range_info = env.poe2_api.af_api.api_getRangeActors()
                    env.poe2_api.click_keyboard('space')
                    
                    if range_info and player_info then
                        local target = self:get_range(range_info, player_info)
                        if target then
                            env.poe2_api.af_api.api_click_move(target.grid_x, target.grid_y, player_info.world_z, 1)
                            sleep(0.1)
                            env.poe2_api.find_text(target.name_utf8, nil, 0, 0, 2)
                            sleep(0.3)
                        end
                        
                        local x, y = env.poe2_api.af_api.api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                        if x and y then
                            env.poe2_api.af_api.api_click_move(x, y, player_info.world_z - 70, 2)
                            sleep(0.3)
                            env.poe2_api.click_keyboard('space')
                            sleep(0.1)
                        end
                    end
                    
                    if my_game_info.hideout[player.current_map_name_utf8] then
                        local x, y = env.poe2_api.af_api.api_FindRandomWalkablePosition(player_info.grid_x, player_info.grid_y, 50)
                        if x and y then
                            env.poe2_api.af_api.api_click_move(x, y, player_info.world_z - 70, 2)
                            sleep(0.5)
                            env.poe2_api.click_keyboard('space')
                            sleep(0.5)
                            env.poe2_api.click_keyboard('space')
                        end
                    end
                end
            end
            
            -- 功能未启用时直接返回
            if not self:_check_feature_enabled(config) then
                env.poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            
            -- 初始化首次检查
            if env.last_exp_check == 0 then
                env.last_exp_value = player.currentExperience
                env.last_exp_check = current_time
                env.poe2_api.infos_time(current_time, self.name)
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
                    env.poe2_api.infos_time(current_time, self.name)
                    return bret.SUCCESS
                end
                
                if (trigger_town and no_exp_to_town) or (trigger_town_move and no_move_to_town) then
                    env.is_map_complete = true
                    if not my_game_info.hideout[player.current_map_name_utf8] then
                        env.need_ReturnToTown = true
                    end
                    env.poe2_api.infos_time(current_time, self.name)
                    return bret.SUCCESS
                elseif (trigger_retreat and no_exp_to_change) or (trigger_retreat_move and no_move_to_change) then
                    env.is_map_complete = true
                    env.need_SmallRetreat = true
                    env.poe2_api.infos_time(current_time, self.name)
                    return bret.SUCCESS
                end
            end
            
            env.poe2_api.infos_time(current_time, self.name)
            return bret.SUCCESS
        end
    },

    -- 检查异界死亡
    Is_Deth_Otherworld = {
        run = function(node, env)
            print("检查是否在异界死亡...")
            return bret.SUCCESS
        end
    },

    -- 检查低血量/蓝量
    CheckLowHpMp_Otherworld = {
        run = function(node, env)
            print("检查低血量/蓝量...")
            return bret.SUCCESS
        end
    },

    -- 逃跑
    Escape = {
        run = function(node, env)
            print("尝试逃跑...")
            return bret.SUCCESS
        end
    },

    -- 路径移动
    Path_Move = {
        run = function(node, env)
            print("沿路径移动...")
            return bret.SUCCESS
        end
    },

    -- 检查是否在主页面
    Not_Main_Page_Otherworld = {
        run = function(node, env)
            print("检查是否不在主页面...")
            return bret.SUCCESS
        end
    },

    -- 设置基础技能
    Set_Base_Skill = {
        name = "设置基础技能",
        bool = false,
        
        skill_location = function(self, env, skill_name, skill_pos, selectable_skills)
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
        end,
        
        get_move_skill = function(self, env, selectable_skills)
            if not self:skill_location(env, "", "MIDDLE", selectable_skills) then
                return false
            end
            return true
        end,
        
        set_pos = function(self, env, skill_name, rom_x, rom_y, selectable_skills)
            if not selectable_skills then
                return false
            end
            for _, k in ipairs(selectable_skills) do
                if 1104 <= k.left and k.left <= 1597 and k.bottom <= 770 and skill_name == k.text_utf8 then
                    local center_x = (k.left + k.right) / 2 + rom_x
                    local center_y = (k.top + k.bottom) / 2 + rom_y
                    env.poe2_api.natural_move(math.floor(center_x), math.floor(center_y))
                    env.poe2_api.af_api.api_LeftClick()
                    sleep(0.5)
                    return true
                end
            end
            return false
        end,
        
        cancel_left_skill = function(self, env, selectable_skills)
            if not selectable_skills then
                return false
            end
            for _, k in ipairs(selectable_skills) do
                if 1277 <= k.left and k.left <= 1280 and k.top > 793 and k.bottom <= 831 and k.right < 1315 then
                    return true
                end
            end
            return false
        end,
        
        run = function(self, env)
            local start_time = os.time()
            local mouse_check = env.mouse_check or false
            
            if not mouse_check then
                return bret.SUCCESS
            end
            
            if not (env.poe2_api.click_text_UI("life_orb", nil) or env.poe2_api.click_text_UI("resume_game", nil) or env.poe2_api.find_text("清單", nil, 0, 0, 400)) then
                return bret.RUNNING
            end
            
            local selectable_skills = api_GetSelectableSkillControls()
            local allskill_info = api_GetAllSkill()
            local skill_slots = api_GetSkillSlots()
            
            if not selectable_skills then
                env.poe2_api.api_print("获取可选技能技能控件信息失败")
                return bret.RUNNING
            end
            if not allskill_info then
                env.poe2_api.api_print("获取全部技能信息失败")
                return bret.RUNNING
            end
            if not skill_slots then
                env.poe2_api.api_print("获取快捷栏技能信息失败")
                return bret.RUNNING
            end
            
            local bool = self:cancel_left_skill(env, selectable_skills)
            local bool1 = self:get_move_skill(env, selectable_skills)
            
            if not bool1 then
                if env.poe2_api.find_text("繼續遊戲", nil, 0, 0, 2) then
                    env.poe2_api.infos_time(start_time, self.name)
                    return bret.RUNNING
                end
                if not self:set_pos(env, "", 0, 0, selectable_skills) then
                    local point = my_game_info.skill_pos["MIDDLE"]
                    env.poe2_api.natural_move(math.floor(point[1]), math.floor(point[2]))
                    env.poe2_api.af_api.api_LeftClick()
                    sleep(0.5)
                end
                return bret.RUNNING
            end
            
            if bool then
                if env.poe2_api.find_text("繼續遊戲", nil, 0, 0, 2) then
                    env.poe2_api.infos_time(start_time, self.name)
                    return bret.RUNNING
                end
                if not self:set_pos(env, '', 50, 0, selectable_skills) then
                    local point = my_game_info.skill_pos["P"]
                    env.poe2_api.natural_move(math.floor(point[1]), math.floor(point[2]))
                    env.poe2_api.af_api.api_LeftClick()
                    sleep(0.5)
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
                env.poe2_api.infos_time(current_time, self.name)
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
                env.poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            
            -- Check for quest items
            local props = self:is_props(bag)
            if props then
                -- Open inventory if not visible
                if not env.poe2_api.find_text(nil, "背包", 1000, 32, 1600, 81) then
                    env.poe2_api.click_keyboard("i")
                    sleep(1)
                    env.poe2_api.infos_time(current_time, self.name)
                    return bret.RUNNING
                end
                
                -- Calculate center position and right click
                local point = env.poe2_api.get_center_position(
                    {props.start_x, props.start_y},
                    {props.end_x, props.end_y}
                )
                env.poe2_api.right_click(point[1], point[2])
                env.poe2_api.infos_time(current_time, self.name)
                return bret.RUNNING
            end
            
            return bret.SUCCESS
        end
    },

    -- 合成或鉴定
    Conflate_Or_Identify = {
        run = function(node, env)
            print("执行合成或鉴定...")
            return bret.SUCCESS
        end
    },

    -- 分解对话
    Dialogue_Break_Down_NPC = {
        run = function(node, env)
            print("与分解NPC对话...")
            return bret.SUCCESS
        end
    },

    -- 交互
    Interactive = {
        run = function(node, env)
            print("执行交互操作...")
            return bret.SUCCESS
        end
    },

    -- 检查是否获得牌匾
    Is_Get_Plaque = {
        run = function(node, env)
            print("检查是否获得牌匾...")
            return bret.SUCCESS
        end
    },

    -- 检查背包
    check_bag = {
        run = function(node, env)
            print("检查背包...")
            return bret.SUCCESS
        end
    },

    -- 打开仓库
    Open_Warehouse = {
        run = function(node, env)
            print("打开仓库...")
            return bret.SUCCESS
        end
    },

    -- 仓库退出
    cangku_out = {
        run = function(node, env)
            print("退出仓库...")
            return bret.SUCCESS
        end
    },

    -- 检查背包页面
    is_bag_page = {
        run = function(node, env)
            print("检查是否在背包页面...")
            return bret.SUCCESS
        end
    },

    -- 重置物品
    res_item = {
        run = function(node, env)
            print("重置物品...")
            return bret.SUCCESS
        end
    },

    -- 检查地租页面
    is_dizhu_page = {
        run = function(node, env)
            print("检查是否在地租页面...")
            return bret.SUCCESS
        end
    },

    -- 打开地租
    open_dizhu = {
        run = function(node, env)
            print("打开地租页面...")
            return bret.SUCCESS
        end
    },

    -- 放置钥匙
    place_key = {
        run = function(node, env)
            print("放置钥匙...")
            return bret.SUCCESS
        end
    },

    -- 放置精炼
    place_jinglian = {
        run = function(node, env)
            print("放置精炼物品...")
            return bret.SUCCESS
        end
    },

    -- 存储物品
    Store_items = {
        run = function(node, env)
            print("存储物品...")
            return bret.SUCCESS
        end
    },

    -- 商店地图
    Shop_Map = {
        run = function(node, env)
            print("访问商店地图...")
            return bret.SUCCESS
        end
    },

    -- 更新地图石
    Update_Map_Stone = {
        run = function(node, env)
            print("更新地图石...")
            return bret.SUCCESS
        end
    },

    -- 检查是否需要拿地图
    Is_Need_Take_Map = {
        run = function(node, env)
            print("检查是否需要拿地图...")
            return bret.SUCCESS
        end
    },

    -- 拿地图
    Take_Map = {
        run = function(node, env)
            print("从仓库拿地图...")
            return bret.SUCCESS
        end
    },

    -- 可堆叠货币丢弃
    StackableCurrency_Discard = {
        run = function(node, env)
            print("丢弃可堆叠货币...")
            return bret.SUCCESS
        end
    },

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
                    poe2_api.api_print("警告: 未找到类型 '"..chinese_type.."' 的英文转换")
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
                poe2_api.infos_time(current_time, self.name)
                return bret.RUNNING
            end
            
            -- 判断是否需要鉴定
            local items_to_identify = self:need_appraisal(bag_info, config_name, config_type)
            if not items_to_identify then
                poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            
            if player_info.isInDangerArea then
                poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            
            if poe2_api.is_have_mos(range_info, player_info, attack_dis_map, stuck_monsters, not_attack_mos) then
                poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            
            -- 使用鉴定卷轴
            if not self:use_items(bag_info) or 
            (poe2_api.is_have_mos(range_info, player_info) and 
                (my_game_info.hideout_CH[player_info.current_map_name_utf8] or 
                string.find(player_info.current_map_name_utf8, "town"))) then
                poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
            
            -- 获取背包信息并鉴定物品
            bag_info = poe2_api.af_api.api_Getinventorys(1)
            if bag_info then
                items_to_identify = self:need_appraisal(bag_info, config_name, config_type)
                if not items_to_identify then
                    poe2_api.infos_time(current_time, self.name)
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
                                poe2_api.infos_time(current_time, self.name)
                                return bret.RUNNING
                            end
                        end
                    end
                end
            else
                poe2_api.infos_time(current_time, self.name)
                return bret.SUCCESS
            end
        end
    },

    -- 检查是否拾取
    Is_Pick_UP = {
        run = function(node, env)
            print("检查是否需要拾取...")
            return bret.SUCCESS
        end
    },

    -- 商店祭祀物品
    Shop_Sacrifice_Items = {
        run = function(node, env)
            print("访问商店祭祀物品...")
            return bret.SUCCESS
        end
    },

    -- 游戏保险箱
    Gameplay_Safe_Box = {
        run = function(node, env)
            print("访问游戏保险箱...")
            return bret.SUCCESS
        end
    },

    -- 检查是否交互
    Is_Interactive = {
        run = function(node, env)
            print("检查是否需要交互...")
            return bret.SUCCESS
        end
    },

    -- 闪避动作
    DodgeAction = {
        run = function(node, env)
            print("执行闪避动作...")
            return bret.SUCCESS
        end
    },

    -- 游戏阻挡处理模块
    Game_Block = {
        run = function(node, env)
            local current_time = os.time()
            
            -- 检测地图启动失败情况
            if env.poe2_api.find_text(nil, "啟動失敗。地圖無法進入。", 0) then
                env.need_SmallRetreat = true
                env.poe2_api.infos_time(current_time, "遮挡处理")
                return bret.RUNNING
            end

            -- 定义所有阻挡条件及其处理函数
            local blockers = {
                -- 简单点击类
                {"繼續遊戲", nil, 2},
                {"傳送", function() env.poe2_api.click_position(1013, 25) end},
                {"技能", function() env.poe2_api.click_position(523, 57) end},
                {"倉庫", function() env.poe2_api.click_position(523, 57) end},
                {"背包", function() env.poe2_api.click_position(1571, 56) end},
                {"重组", function() env.poe2_api.click_position(1345, 56) end},
                {"社交", function() env.poe2_api.click_position(523, 57) end},
                {"角色", function() env.poe2_api.click_position(523, 57) end},
                {"活動", function() env.poe2_api.click_position(523, 57) end},
                {"選項", function() env.poe2_api.click_position(523, 57) end},
                {"天賦技能", function() env.poe2_api.click_position(1013, 25) end},
                {"精選", function() env.poe2_api.click_position(1573, 33) end},
                {"世界地圖", function() env.poe2_api.click_position(1013, 25) end},
                {"寶石切割", function() env.poe2_api.click_position(1081, 67) end},
                
                -- 需要特殊处理的
                {"等待玩家接受交易請求...", function() env.poe2_api.find_text("取消", nil, 2) end},
                {"Checkpoints", function() env.poe2_api.find_text("Checkpoints", 0, 30, 220, 2) end},
                {"聖域鎖櫃", function() 
                    if env.poe2_api.find_text(nil, "強調物品", 0, 32, 381, 81) then
                        env.poe2_api.click_position(523, 57)
                    end
                end},
                {"回收具有品質或插槽的裝備", function() env.poe2_api.click_position(960, 319) end},
                {"私訊", function() env.poe2_api.click_position(570, 340) end},
                {"清單", function() env.poe2_api.click_position(1573, 33) end},
                {"重鑄台", function() 
                    if env.poe2_api.find_text(nil, "摧毀三個相似的物品", 0) then
                        env.poe2_api.click_position(1010, 153)
                    end
                end},
                {"重置天賦點數", function() env.oe2_api.click_position(1013, 25) end},
                {"通貨交換", function() env.poe2_api.click_position(1100, 112) end},
                {"選擇藏身處", function() env.poe2_api.click_position(1312, 102) end},
                {"購買或販賣", function() env.poe2_api.click_position(792, 169) end}
            }

            -- 检查所有阻挡条件
            for _, blocker in ipairs(blockers) do
                local text, action, click = blocker[1], blocker[2], blocker[3]
                if env.poe2_api.find_text(nil, text, 0) then
                    if type(action) == "function" then 
                        action()
                    elseif click then
                        env.poe2_api.find_text(text, nil, click)
                    end
                    env.poe2_api.infos_time(current_time, "遮挡处理")
                    return bret.RUNNING
                end
            end
            return bret.SUCCESS
        end
    },

    -- 释放技能动作
    ReleaseSkillAction = {
        run = function(node, env)
            print("释放技能...")
            return bret.SUCCESS
        end
    },

    -- 检查是否到达点
    Is_Arrive_Point = {
        run = function(node, env)
            print("检查是否到达目标点...")
            return bret.SUCCESS
        end
    },

    -- 进入地图
    Enter_Map = {
        run = function(node, env)
            print("进入地图...")
            return bret.SUCCESS
        end
    },

    -- 在异界放置地图
    Put_Map_In_Otherworld = {
        run = function(node, env)
            print("在异界放置地图...")
            return bret.SUCCESS
        end
    },

    -- 清除所有页面
    Clear_All_Page = {
        run = function(node, env)
            print("清除所有页面...")
            return bret.SUCCESS
        end
    },

    -- 打开异界页面
    Open_The_Otherworld_Page = {
        run = function(node, env)
            print("打开异界页面...")
            return bret.SUCCESS
        end
    },

    -- 寻找怪物
    Find_Monster = {
        run = function(node, env)
            print("寻找怪物...")
            return bret.SUCCESS
        end
    },

    

    -- 检查目标点
    Check_Target_Point = {
        run = function(node, env)
            print("检查目标点...")
            return bret.SUCCESS
        end
    },

    -- 地图强化
    Map_Strengthened = {
        run = function(node, env)
            print("强化地图...")
            return bret.SUCCESS
        end
    },

    -- 强化(通用)
    Strengthened = {
        run = function(node, env)
            print("执行强化操作...")
            return bret.SUCCESS
        end
    },

    -- 更新牌匾
    Update_Plaque = {
        run = function(node, env)
            print("更新牌匾...")
            return bret.SUCCESS
        end
    },

    -- 插入牌匾
    Insert_The_Plaque = {
        run = function(node, env)
            print("插入牌匾...")
            return bret.SUCCESS
        end
    },

    -- 插入牌匾(动作)
    Insert_Plaque = {
        run = function(node, env)
            print("执行插入牌匾动作...")
            return bret.SUCCESS
        end
    },

    -- 获取物品数量
    Obtain_The_Quantity_of_Items = {
        run = function(node, env)
            print("获取物品数量...")
            return bret.SUCCESS
        end
    },

    -- 点击所有仓库页
    Click_All_Pages = {
        run = function(node, env)
            local current_time = os.time()
            
            -- 检查仓库页面是否可用
            local function check_pages()
                local pages = env.poe2_api.af_api.api_GetRepositoryPages()
                for _, page in ipairs(pages) do
                    if page.manage_index == 0 and page.type ~= 5 then
                        return false
                    end
                end
                return true
            end

            -- 主逻辑
            if check_pages() then
                env.poe2_api.infos_time(current_time, "点击所有仓库页")
                return bret.FAILURE
            end

            -- 检查是否在正确界面
            if not env.poe2_api.find_text(nil, "強調物品", 250, 700) or 
            not env.poe2_api.find_text(nil, "倉庫", 0, 32, 381, 81) then
                env.poe2_api.infos_time(current_time, "点击所有仓库页")
                return bret.SUCCESS
            end

            sleep(2)

            -- 获取仓库页面和控制元素
            local list_button = env.poe2_api.af_api.get_game_control_by_rect(499, 36, 582, 125)
            local tab_list_button = nil
            for _, control in ipairs(list_button) do
                if control.name_utf8 == "tab_list_button" then
                    tab_list_button = control
                    break
                end
            end

            local item_pages = {}
            local pages = env.poe2_api.af_api.api_GetRepositoryPages()
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
                    env.poe2_api.find_text(nil, page.name_utf8, 0, 0, 550, 90, 2)
                    sleep(0.1)
                end
            else
                -- 已展开标签列表的情况
                local lock = env.poe2_api.af_api.get_game_control_by_rect(546, 32, 589, 76)
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
                    env.poe2_api.natural_move(
                        (tab_list_button.left + tab_list_button.right) / 2,
                        (tab_list_button.top + tab_list_button.bottom) / 2
                    )
                    env.poe2_api.af_api.api_LeftClick()
                    sleep(0.2)
                else
                    -- 直接点击各页面
                    for _, page in ipairs(item_pages) do
                        if keyboard.is_pressed('down') then break end
                        env.poe2_api.find_text(nil, page.name_utf8, 556, 20, 851, 469, 2)
                        sleep(0.1)
                    end
                end
            end

            env.poe2_api.infos_time(current_time, "点击所有仓库页")
            return bret.RUNNING
        end
    },

    -- 点击交互文本
    Click_Item_Text = {
        run = function(node, env)
            local current_time = os.time()
            local interactive_object = env.interactive
            local player_info = env.player_info
            local current_map_info_copy = env.current_map_info_copy
            local range_info = env.range_info
            local path_list = env.path_list
            local need_item = env.need_item
            local is_click_z = false
            
            -- 辅助函数定义
            local function check_in_map()
                if not current_map_info_copy then
                    return nil
                end
                for _, k in ipairs(current_map_info_copy) do
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
                    x, y = af_api.FindNearestReachablePoint(obj.grid_x, obj.grid_y, 15, 1)
                    local ralet = af_api.api_findPath(player_info.grid_x, player_info.grid_y, x, y)
                    if not ralet then
                        x, y = af_api.api_FindRandomWalkablePosition(obj.grid_x, obj.grid_y, 15)
                    end
                else
                    if not need_item then
                        x, y = af_api.FindNearestReachablePoint(obj.grid_x, obj.grid_y, 50, 0)
                    else
                        x, y = obj.grid_x, obj.grid_y
                    end
                end
                local distance = point_distance(x, y, player_info)
                if distance > 15 then
                    env.end_point = {x, y}
                    return {x, y}
                end
                return false
            end
            
            -- 主逻辑
            if not player_info then
                return bret.RUNNING
            end
            
            if not interactive_object then
                return bret.RUNNING
            end
            
            if type(interactive_object) == "string" then
                local map_obj = check_in_map()
                local range_obj = check_in_range()
                
                local target_obj = map_obj or range_obj
                if not target_obj then
                    print("未找到对象")
                    return bret.FAILURE
                end
                
                local distance = point_distance(target_obj.grid_x, target_obj.grid_y, player_info)
                print("交互对象: "..target_obj.name_utf8.." | 位置: "..target_obj.grid_x..","..target_obj.grid_y.." | 距离: "..distance)
                
                if need_move(target_obj) then
                    return bret.FAILURE
                end
                
                if table.contains(my_game_info.hideout, player_info.current_map_name_utf8) then
                    sleep(0.5)
                end
                
                if target_obj.name_utf8 == "MapDevice" then
                    local m_list = {"黃金製圖儀", "地圖裝置"}
                    sleep(0.8)
                    local maps = check_in_range('Metadata/Terrain/Missions/Hideouts/Objects/MapDeviceVariants/ZigguratMapDevice')
                    if find_text(nil, '地圖裝置', 2) then
                        sleep(0.1)
                        return bret.RUNNING
                    end
                    if maps then
                        af_api.api_click_move(maps.grid_x, maps.grid_y, maps.world_z - 110, 0)
                        sleep(0.5)
                    end
                    for _, i in ipairs(m_list) do
                        if find_text(nil, i, 2) then
                            sleep(0.1)
                            return bret.RUNNING
                        end
                    end
                end
                
                if table.contains(my_game_info.hideout, player_info.current_map_name_utf8) and target_obj.name_utf8 ~= '傳送點' and not map_obj then
                    find_text(nil, interactive_object, 2)
                    sleep(0.1)
                    return bret.RUNNING
                end
                
                if player_info.isMoving then
                    print("等待静止")
                    sleep(0.2)
                    return bret.RUNNING
                end
                
                if not find_text(nil, interactive_object, 2) then
                    af_api.api_click_move(target_obj.grid_x, target_obj.grid_y, player_info.world_z - 70, 1)
                end
                sleep(0.1)
                return bret.RUNNING
            else
                local text = interactive_object.baseType_utf8 or interactive_object.name_utf8
                local point = need_move(interactive_object)
                
                if point then
                    if path_list and #path_list > 0 and point_distance(path_list[#path_list].x, path_list[#path_list].y, point[1], point[2], nil) > 20 and text ~= "門" then
                        env.path_list = nil
                    end
                    return bret.FAILURE
                end
                
                if player_info.isMoving then
                    print("等待静止")
                    sleep(0.2)
                    return bret.RUNNING
                end
                
                if interactive_object and (not text or text == "門" or text == "聖潔神殿" or not find_text_sort(text, 200, 750, 1, 1200, 2)) then
                    if text == "門" or text == "聖潔神殿" then
                        if text == "門" and find_text_sort("出土遺物", 200, 750, 1, 1200) then
                            click_keyboard("z")
                            is_click_z = true
                            return bret.RUNNING
                        end
                        af_api.api_click_move(interactive_object.grid_x, interactive_object.grid_y, player_info.world_z - 70, 1)
                    else
                        if need_item and need_item == interactive_object then
                            af_api.api_click_move(interactive_object.grid_x, interactive_object.grid_y, player_info.world_z, 1)
                        else
                            if interactive_object.path_name_utf8 then
                                if interactive_object.path_name_utf8 == "Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable" then
                                    find_text_sort("點擊以開始祭祀", 200, 750, 1, 1200, 2)
                                else
                                    af_api.api_click_move(interactive_object.grid_x, interactive_object.grid_y, player_info.world_z - 250, 1)
                                end
                            else
                                af_api.api_click_move(interactive_object.grid_x, interactive_object.grid_y, player_info.world_z - 250, 1)
                            end
                        end
                    end
                end
                
                if text == "門" then
                    sleep(0.4)
                    if is_click_z then
                        click_keyboard("z")
                        is_click_z = false
                    end
                    af_api.api_UpdateMapObstacles()
                end
                
                if text == "水閘門控制桿" or text == "把手" then
                    env.wait_target = true
                end
                
                if interactive_object.path_name_utf8 then
                    if interactive_object.path_name_utf8 == "Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable" then
                        env.afoot_altar = interactive_object
                    end
                end
                
                env.path_list = nil
                env.need_item = nil
                env.interactive = nil
                env.interaction_object = nil
                env.interactiontimeout = os.time()
                
                return bret.RUNNING
            end
        end
    },

    -- 打开交换界面
    Open_The_Exchange_Interface = {
        run = function(node, env)
            print("打开交换界面...")
            return bret.SUCCESS
        end
    },

    -- 点击所有取消
    Click_All_Cancel = {
        run = function(node, env)
            print("点击所有取消按钮...")
            return bret.SUCCESS
        end
    },

    -- 点击旧的兑换
    Click_Old_Exchange = {
        run = function(node, env)
            print("点击旧的兑换...")
            return bret.SUCCESS
        end
    },

    -- 点击所有兑换
    Click_All_Exchange = {
        run = function(node, env)
            print("点击所有兑换...")
            return bret.SUCCESS
        end
    },

    -- 点击无状态兑换
    Click_Stateless_Exchange = {
        run = function(node, env)
            print("点击无状态兑换...")
            return bret.SUCCESS
        end
    },

    -- 选择和交换
    Select_AND_Exhange = {
        run = function(node, env)
            print("选择和交换物品...")
            return bret.SUCCESS
        end
    },

    -- 对话鉴定NPC
    Dialogue_Appraisal_NPC = {
        run = function(node, env)
            print("对话鉴定NPC...")
            return bret.SUCCESS
        end
    },

    -- 是否需要鉴定
    is_need_identify = {
        run = function(node, env)
            print("检查是否需要鉴定...")
            return bret.SUCCESS
        end
    },

    -- 打开合成界面
    Synthesis_Interface = {
        run = function(node, env)
            print("打开合成界面...")
            return bret.SUCCESS
        end
    },

    -- 点击物品合成
    Click_On_The_Item_To_Synthesize = {
        run = function(node, env)
            print("点击物品合成...")
            return bret.SUCCESS
        end
    },

    -- 地租页面
    dizhu_page = {
        run = function(node, env)
            print("处理地租页面...")
            return bret.SUCCESS
        end
    },

    -- 存储物品(动作)
    Store_Items = {
        run = function(node, env)
            print("执行存储物品动作...")
            return bret.SUCCESS
        end
    },

    -- 购买地图
    Shop_maps = {
        run = function(node, env)
            print("购买地图...")
            return bret.SUCCESS
        end
    },

    -- 检查是否到达点(别名)
    Is_Arrive = {
        run = function(node, env)
            print("检查是否到达目标点(Is_Arrive)...")
            local current_time = os.time()

            local is_arrive_end_dis = 15 -- 默认值
            print("1111111111111111111111")
            print("player_info:"..player_info)
            print("1111111111111111111111")
            local player_info = env.player_info
            print("player_info:"..player_info)
            if player_info.life ~= 0 then
                env.end_point = nil
                env.run_point = nil
                env.is_arrive_end = false
                env.target_point = {}
                -- return bret.FAIL
                print("正在前往目标点...111222")
                return bret.RUNNING
            end
            
            -- 检查空路径
            if env.empty_path then
                env.is_arrive_end = true
                env.empty_path = false
                -- return bret.SUCCESS
                print("正在前往目标点...111111")
                return bret.RUNNING
            end
            print("333333333333333333")
            -- 检查是否到达终点
            local point = env.end_point
            local path_list = env.path_list
            if point and
                env.poe2_api.point_distance(point[1], point[2], player_info) <
                is_arrive_end_dis and
                env.poe2_api.af_api.api_HasObstacleBetween(point[1], point[2]) then
                env.is_arrive_end = true
                env.end_point = nil
                env.run_point = nil
                blackboard.current_time = nil
                -- return bret.FAIL
                print("正在前往目标点...222222")
                return bret.RUNNING
            else
                env.is_arrive_end = false
                -- return bret.SUCCESS
                print("正在前往目标点...33333")
                return bret.RUNNING
            end
        end
    },

    -- 获取路径
    GET_Path = {
        initialize = function(self)
            self.last_point = nil
            self.failure_count = 0 -- 路径计算失败计数器
        end,

        run = function(self, node, env)
            print("获取路径...")
            local current_time = os.time()
            local player_info = env.player_info
            local range_info = env.range_info

            -- 辅助函数：检测祭坛
            local function get_altar(range_info)
                for _, entity in ipairs(range_info) do
                    if entity.path_name_utf8 ==
                        "Metadata/Terrain/Leagues/Ritual/RitualRuneInteractable" and
                        entity.stateMachineList.current_state == 2 and
                        entity.stateMachineList.interaction_enabled == 0 then
                        return entity
                    end
                end
                return nil
            end

            -- 检查终点是否存在
            local point = env.end_point
            if not point then
                print("[GET_Path] 错误：未设置终点")
                return bret.FAILURE
            end

            -- 寻找最近可达点
            point = {
                env.poe2_api.af_api.FindNearestReachablePoint(point[1],
                                                              point[2], 50, 0)
            }

            -- 如果已有路径，使用下一个路径点
            local path_list = env.path_list
            if path_list and #path_list > 1 then
                env.target_point = {path_list[1].x, path_list[1].y}
                table.remove(path_list, 1) -- 移除已使用的点
                return bret.SUCCESS
            end

            -- 计算新路径
            local start_x, start_y = env.poe2_api.af_api
                                         .FindNearestReachablePoint(
                                         player_info.grid_x, player_info.grid_y,
                                         50, 0)

            local result = env.poe2_api.af_api.api_findPath(start_x, start_y,
                                                            point[1], point[2])

            if result then
                -- 处理路径结果
                result = env.poe2_api.extract_coordinates(result, 15)
                table.remove(result, 1) -- 移除起点

                env.path_list = result
                env.target_point = {result[1].x, result[1].y}
                print("[GET_Path] 路径计算成功，点数: " .. #result)
                return bret.SUCCESS
            else
                -- 路径计算失败处理
                local altar = get_altar(range_info)
                if altar then
                    if env.poe2_api.point_distance(altar.grid_x, altar.grid_y,
                                                   player_info) > 110 then
                        env.poe2_api.af_api.api_RestoreOriginalMap()
                    end
                else
                    env.poe2_api.af_api.api_RestoreOriginalMap()
                end

                self.failure_count = self.failure_count + 1
                env.find_path_failure = self.failure_count
                print("[GET_Path] 错误：找不到路径 (失败次数: " ..
                          self.failure_count .. ")")
                return bret.FAILURE
            end
        end
    },

    -- 移动到目标点
    Move_To_Target_Point = {
        initialize = function(self)
            self.last_move_time = os.time()
            self.move_interval = math.random() * 0.1 + 0.1 -- 随机间隔0.1~0.2秒
            self.timeout = 3 -- 超时时间
            self.current_time = nil
            self.action_state = {
                random_delay = {last = 0, duration = 0.1},
                timeout_click = {active = false, start = 0}
            }
            self.last_action_time = 0
            self.action_interval = 1.5
            self.last_space_time = 0
            self.last_space_time1 = 0
            self.last_point = nil
        end,

        run = function(self, node, env)
            print("移动到目标点...")
            local current_time = os.time()

            local point = env.target_point
            if not point then return bret.SUCCESS end

            local player_info = env.player_info
            local range_info = env.range_info
            local path_list = env.path_list

            -- 检查终点是否变化
            local end_point = env.end_point
            if not self.last_point and end_point then
                self.last_point = end_point
            end

            if self.last_point and end_point and path_list then
                local last_path_point = path_list[#path_list]
                local dis = env.poe2_api.point_distance(self.last_point[1],
                                                        self.last_point[2], {
                    x = end_point[1],
                    y = end_point[2]
                })
                if dis > 25 then
                    self.last_point = end_point
                    env.path_list = nil
                    env.target_point = {}
                    env.is_arrive_end = true
                    return bret.RUNNING
                end
            end

            -- 执行移动
            if current_time - self.last_move_time >= self.move_interval then
                if point and current_time - self.action_state.random_delay.last >=
                    self.action_state.random_delay.duration then
                    local dis = env.poe2_api.point_distance(point[1], point[2],
                                                            player_info)

                    if dis > 70 then
                        env.path_list = nil
                        env.target_point = {}
                        env.is_arrive_end = true
                        return bret.RUNNING
                    end

                    -- 调用移动API
                    if not env.poe2_api.af_api.api_click_move(point[1],
                                                              point[2],
                                                              player_info.world_z,
                                                              3) then
                        env.end_point = nil
                        env.run_point = nil
                        env.path_list = nil
                        env.target_point = {}
                        return bret.RUNNING
                    end

                    self.last_move_time = current_time
                end
            end

            -- 检查特殊点位
            if env.poe2_api.find_text("Checkpoints") then
                env.poe2_api.click_keyboard('space')
                env.poe2_api.click_keyboard('space')
                table.remove(env.path_list, 1)
                return bret.RUNNING
            end

            -- 检查是否到达目标点
            if point then
                local dis = env.poe2_api.point_distance(point[1], point[2],
                                                        player_info)
                if dis < 20 then
                    if env.path_list and #env.path_list > 0 then
                        env.target_point = {
                            env.path_list[1].x, env.path_list[1].y
                        }
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
print(UI_info)
-- 创建行为树环境
local env_params = {
    poe2_api = require("poe2api"), -- 注入模块
    -- 可以在这里添加需要的环境变量
    user_config = parser, -- 用户配置
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
    is_game_exe = false, -- 游戏是否正在执行，初始值为False
    shouting_number = 0, -- 喊话次数，初始值为0
    area_list = {}, -- 存储区域列表，初始值为空列表
    account_state = nil, -- 账户状态，初始值为None
    switching_lines = 0, -- 线路切换状态，初始值为0
    time_out = 0, --  超时时间，初始值为0
    skill_name = nil, -- 当前技能名称，初始值为None
    skill_pos = nil, -- 当前技能位置，初始值为None
    is_need_check = false, -- 是否需要检查，初始值为False
    item_name = nil, -- 当前物品名称，初始值为None
    item_pos = nil, -- 当前物品位置，初始值为None
    -- blackboard.set("user_config", parser)  # 用户配置
    check_all_points = false, -- 是否检查所有点，初始值为False
    path_list = {}, -- 存储路径列表，初始值为空列表
    empty_path = false, -- 路径是否为空，初始值为False
    -- boss_name = my_game_info.boss_name,  -- 当前boss名称，初始值为None
    map_name = nil, -- 当前地图名称，初始值为None
    interaction_object = nil, -- 交互对象，初始值为None
    item_move = false, -- 物品是否移动，初始值为False
    item_end_point = {0, 0}, -- 物品的终点位置，初始值为[0, 0]
    ok = false, -- 是否确认，初始值为False
    not_need_wear = false, -- 是否不需要装备，初始值为False
    currency_check = false, -- 是否进行货币检查，初始值为False
    sell_end_point = {0, 0}, -- 卖物品的终点位置，初始值为[0,0]
    is_better = false, -- 是否更好，初始值为False
    mos_out = 0, -- 显示的数量，初始值为0
    is_arrive_end = false, -- 是否到达终点，初始值为False
    not_need_pick = false, -- 是否不需要拾取，初始值为False
    is_not_ui = false, -- 是否不是UI界面，初始值为False
    entrancelist = {}, -- 入口位置列表
    creat_new_role = false, -- 新角色
    Level_reach = false, -- 是否要刷级
    changer_leader = false, -- 是否要换队长
    send_message = false, -- 是否要发信息
    obtain_message = false, -- 是否要换接收信息
    no_item_wear = false,
    my_role = nil,
    is_set = false,
    end_point = nil,
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
    UI_info = nil, -- UI信息
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
    current_map_info_copy = nil,
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
    -- waypoint = env.poe2_api.af_api.api_GetTeleportationPoints(),
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

    dizhu_end = false, -- 滴注操作
    is_need_strengthen = false, -- 是否需要合成
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
    find_path_failure = 0,

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
    warehouse_type = nil, -- 仓库类型（滴注）
    formula_list = nil, -- 配方列表（滴注）
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
function otherworld_bt.create(config, my_game_info)
    -- 直接使用已定义的 env_params，并更新配置
    local env = env_params
    env.user_config = config
    env.user_map = my_game_info
    local bt = behavior_tree.new("otherworld", env_params)
    return bt
end


local function sleep(n)
    if n > 0 then
        os.execute("ping -n " .. tonumber(n + 1) .. " localhost > NUL")
    end
end

-- 运行行为树
function otherworld_bt.run(bt)
    print("\n=== 游戏Tick开始 ===")
    local i = 0
    while true do
        print("\n=== 游戏Tick", i, "===")
        bt.run()
        -- 模拟延迟
        sleep(0.5)
        i = i + 1
    end
end

return otherworld_bt
