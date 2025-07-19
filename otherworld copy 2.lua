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
            -- local size = Actors:Update()
            -- if size > 0 then
            --     print("发现角色数量: " .. size .. "\n")
            --     env.range_info = size
            -- end
            return bret.SUCCESS
        end
    },

    -- 清理
    Clear = {
        run = function(node, env)
            print("执行清理...")
            return bret.SUCCESS
        end
    },

    -- 休息控制
    RestController = {
        run = function(node, env)
            print("执行休息控制...")
            return bret.SUCCESS
        end
    },

    -- 小撤退
    SmallRetreat = {
        run = function(node, env)
            print("执行小撤退...")
            return bret.SUCCESS
        end
    },

    -- 返回城镇
    ReturnToTown = {
        run = function(node, env)
            print("返回城镇...")
            return bret.SUCCESS
        end
    },

    -- 检查长时间经验加成
    Check_LongTime_EXP_Add = {
        run = function(node, env)
            print("检查长时间经验加成...")
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
        run = function(node, env)
            print("设置基础技能...")
            return bret.SUCCESS
        end
    },

    -- 使用任务道具
    Use_Task_Props = {
        run = function(node, env)
            print("使用任务道具...")
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

    -- 鉴定指定装备
    Identify_designated_equipment = {
        run = function(node, env)
            print("鉴定指定装备...")
            return bret.SUCCESS
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

    -- 游戏阻挡
    Game_Block = {
        run = function(node, env)
            print("检测游戏阻挡...")
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
            print("点击所有仓库页...")
            return bret.SUCCESS
        end
    },

    -- 点击交互文本
    Click_Item_Text = {
        run = function(node, env)
            print("点击交互文本...")
            return bret.SUCCESS
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

            -- 初始化开始时间
            if not self.current_time then
                self.current_time = current_time
                env.out_of_move = current_time
            end

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
            if env.poe2_api.find_png("setting\\check_points.bmp") then
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
function sleep(n)
    if n > 0 then
        os.execute("ping -n " .. tonumber(n + 1) .. " localhost > NUL")
    end
end
-- 运行行为树
function otherworld_bt.run(bt)
    print("\n=== 游戏Tick===")
    -- while true do
    bt.run()
    -- 模拟延迟
    sleep(0.5)
    -- end
end

return otherworld_bt

-- -- 加载otherworld行为树
-- local bt = behavior_tree.new("otherworld", env_params)

-- print("检查节点定义...")
-- local function check_nodes(node)
--     if not all_nodes[node.name] then
--         print("未定义的节点:", node.name, "ID:", node.id)
--     end
--     for _, child in ipairs(node.children or {}) do
--         check_nodes(child)
--     end
-- end
-- check_nodes(bt.tree.root)

-- -- 模拟游戏循环

-- for i = 1, 10 do
--     print("\n=== 游戏Tick", i, "===")
--     bt.run()
--     sleep(0.5)
-- end
