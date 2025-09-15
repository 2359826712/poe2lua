-- API 函数详细文档
-- ================
-- 所有函数均通过 api_ 前缀调用

-- 时间控制
-- api_Sleep(ms) - 延迟执行指定毫秒数
--   @param ms 延迟的毫秒数（非负整数）
--   @return nil

-- api_GetTickCount64() - 获取系统启动后的毫秒时间戳
--   @return number 毫秒级时间戳（64位整数）


-- 玩家与环境
-- api_GetLocalPlayer() - 获取本地玩家信息
--   @return table 包含玩家属性的表格，字段可能包括：
--     {
--       world_x, world_y, world_z = 坐标信息,
--       life, max_life = 生命值相关,
--       mana, max_mana = 魔力值相关,
--       level = 玩家等级,
--       isMoving = 是否移动中（boolean）
--     }

-- api_GetMinimapActorInfo() - 获取小地图周围对象信息
--   @return table 包含周围对象的表格数组，每个元素可能包含：
--     { id, name, world_x, world_y, type, is_friendly }

-- api_GetUiElements() - 获取UI元素信息
--   @return table 包含UI元素的表格数组，每个元素可能包含：
--     { name, x, y, width, height, is_visible }


-- 移动控制
-- api_ClickMove(x, y, world_z, mode) - 点击移动到指定坐标
--   @param x 游戏世界X坐标（浮点型）
--   @param y 游戏世界Y坐标（浮点型）
--   @param world_z 游戏世界高度坐标（浮点型）
--   @param mode 移动模式：
--     0=只移动
--     1=移动+左键点击, 2=移动+右键点击,
--     3=移动+左键按下, 4=移动+左键释放,
--     5=移动+右键按下, 6=移动+右键释放 ,
--     7=移动+中键点击, 8=移动+中键按下 ,
--     9=移动+中键释放
--   @return nil

-- api_FindPath(start_x, start_y, end_x, end_y) - 查找两点间路径
--   @param start_x 起点X坐标（浮点型）
--   @param start_y 起点Y坐标（浮点型）
--   @param end_x 终点X坐标（浮点型）
--   @param end_y 终点Y坐标（浮点型）
--   @return table 路径点数组，每个元素为 {x, y}

-- api_FindRandomWalkablePosition(x, y, radius) - 获取半径内随机可行走坐标
--   @param x 中心X坐标（浮点型）
--   @param y 中心Y坐标（浮点型）
--   @param radius 搜索半径（非负整数）
--   @return table 坐标点 {x, y}

-- api_FindNearestReachablePoint(dx, dy, radius, mode) - 查找最近可到达点
--   @param dx 目标X坐标（浮点型）
--   @param dy 目标Y坐标（浮点型）
--   @param radius 搜索半径（非负整数）
--   @param mode 模式：
--     0=以(dx, dy)为中心，找离目标最近的点,
--     1=以(dx, dy)为中心，找离玩家最近的点
--   @return table 坐标点 {x, y}

-- api_GetSafeAreaLocation() - 获取一个安全位置
--   @return table 安全坐标点 {x, y, z}

-- api_GetSafeAreaLocationNoMonsters(range) - 获取指定范围内无怪物的安全位置
--   @param range 搜索范围（非负整数）
--   @return table 安全坐标点 {x, y, z}


-- 物品与技能
-- api_Getinventorys(index, type) - 获取背包物品
--   @param index 背包索引（从0开始的整数）
--   @param type 物品类型（整数，0=全部类型）
--   @return table 物品数组，每个元素可能包含：
--     { id, name, quality, stackCount, is_usable }

-- api_GetSkillSlots() - 获取技能槽信息
--   @return table 技能槽数组，每个元素可能包含：
--     { slot_id, skill_id, cooldown, is_ready }

-- api_GetSelectableSkillControls() - 获取可选技能控件
--   @return table 可选技能控件数组，每个元素可能包含：
--     { control_id, skill_name, hotkey }

-- api_GetAllSkill() - 获取所有技能
--   @return table 所有技能数组，每个元素可能包含：
--     { id, name, level, mana_cost, description }

-- api_GetObjectSuffix(obj) - 根据物品对象获取词缀
--   @param obj 物品对象（通过其他API获取的物品引用）
--   @return table 词缀数组，每个元素为字符串（如 "+5% 暴击率"）


-- 地图与导航
-- api_GetTeleportationPoint() - 获取传送点信息
--   @return table 传送点数组，每个元素可能包含：
--     { id, name, x, y, is_unlocked }

-- api_GetNextCirclePosition(bossX, bossY, playerX, playerY, radius, angleStep, direction) - 获取下一个绕圈位置
--   @param bossX 首领X坐标（浮点型）
--   @param bossY 首领Y坐标（浮点型）
--   @param playerX 玩家当前X坐标（浮点型）
--   @param playerY 玩家当前Y坐标（浮点型）
--   @param radius 绕圈半径（非负浮点数）
--   @param angleStep 角度步长（正整数，单位：度）
--   @param direction 方向（0=顺时针，1=逆时针）
--   @return table 坐标点 {x, y}

-- api_GetUnexploredArea(radius) - 获取未探索的区域
--   @param radius 搜索半径（非负整数）
--   @return table 未探索区域坐标点 {x, y}

-- api_UpdateMapInfo() - 刷新地图信息
--   @return nil
-- api_InitExplorationArea() - 初始化探索地图
--   @return nil
-- api_UpdateMapObstacles(range) - 更新地图障碍点
--   @param range 更新范围（非负整数）
--   @return nil

-- api_RestoreOriginalMap() - 恢复原始地图数据
--   @return nil

-- api_GetCalculateCircleGridPoints(grid_x, grid_y, radius, gridWidth) - 获取圆形范围内均匀分布的网格点
--   @param grid_x 中心网格X坐标（整数）
--   @param grid_y 中心网格Y坐标（整数）
--   @param radius 圆形半径（网格数，非负整数）
--   @param gridWidth 单个网格宽度（浮点型）
--   @return table 坐标点数组，每个元素为 {x, y}


-- 任务与队伍
-- api_GetQuestList(index) - 获取任务列表
--   @param index 任务索引（0=所有任务，1=主线，2=支线）
--   @return table 任务数组，每个元素可能包含：
--     { id, title, progress, is_completed, rewards }

-- api_GetTeamInfo() - 获取队伍信息
--   @return table 队伍成员数组，每个元素可能包含：
--     { player_id, name, level, class, is_leader }


-- 高级功能
-- api_GetcurrentEndgameNodePoints() - 获取当前异界地图位置
--   @return number, number X坐标和Y坐标（浮点型）

-- api_HasObstacleBetween(grid_x, grid_y) - 检测两点间是否有障碍物
--   @param grid_x 目标点X坐标（网格坐标，整数）
--   @param grid_y 目标点Y坐标（网格坐标，整数）
--   @return boolean true=无障碍物，false=有障碍物

-- api_InitGameWindow() - 初始化游戏窗口（获取句柄、尺寸等）
--   @return nil

-- api_GetSacrificeItems() - 获取祭祀物品列表及状态
--   @return table 祭祀数据表格：
--     {
--       items = 祭祀物品数组（每个元素包含id, name, quality等）,
--       maxCount = 单次最大可完成数量,
--       finishedCount = 已完成数量,
--       leftGifts = 剩余奖励次数,
--       refreshCost = 刷新消耗,
--       MaxRefreshCount = 最大刷新次数,
--       CurrentRefreshCount = 当前已刷新次数
--     }

-- api_AddMonitoringSkills(type, path_name, radius) - 增加技能监测
--   @param type 监测类型（整数，0=范围监测，1=目标监测）
--   @param path_name 技能路径名称（字符串）
--   @param radius 监测半径（非负整数）
--   @return nil

-- api_InitExplorationArea() - 更新探索地图数据
--   @return nil

-- api_EndgameNodeMove(position_x, position_y) - 异界地图节点移动
--   @param position_x 目标X坐标（整数）
--   @param position_y 目标Y坐标（整数）
--   @return nil

-- api_GetRepositoryPages(type) - 获取仓库页数组
--   @param type 仓库类型（0=普通，1=特殊，2=通货）
--   @return table 仓库页数组，每个元素为整数（页码）

-- api_GetCurrencyExchangeList(grid_x, grid_y) - 获取通货兑换列表
--   @param grid_x 兑换NPC的X坐标（网格坐标）
--   @param grid_y 兑换NPC的Y坐标（网格坐标）
--   @return table 通货兑换数组，每个元素包含兑换比例信息

-- api_EnumProcess(name) - 枚举指定名称的进程
--   @param name 进程名称（字符串，如"Game.exe"，为空则枚举所有）
--   @return table 进程ID数组（整数）

-- api_FindWindowByProcess(class_name, title, process_name, Pid) - 通过进程信息查找窗口句柄
--   @param class_name 窗口类名（字符串，nil=不限制）
--   @param title 窗口标题（字符串，nil=不限制）
--   @param process_name 进程名（字符串，nil=不限制）
--   @param Pid 进程ID（整数，0=不限制）
--   @return number 窗口句柄（0=未找到）

-- api_ClickScreen(ScreenX, ScreenY, mode) - 点击屏幕指定位置
--   @param ScreenX 屏幕X坐标（像素，整数）
--   @param ScreenY 屏幕Y坐标（像素，整数）
--   @param mode 点击模式：
--     1=左键点击, 2=右键点击, 3=左键按下,
--     4=左键释放, 5=右键按下, 6=右键释放
--   @return nil

-- api_Keyboard(keyCode, action) - 模拟键盘操作
--   @param keyCode 虚拟键码（整数，如0x41=A键，0x20=空格键）
--   @param action 操作类型：
--     0=按下, 1=抬起, 2=按下并抬起
--   @return nil

-- api_InitExplorationArea() - 更新探索地图
--   @return nil

-- api_EndgameNodeMove(position_x, position_y) - 异界地图节点移动
--   @param position_x X坐标（整数）
--   @param position_y Y坐标（整数）
--   @return nil

-- api_GetRepositoryPages(type) - 获取仓库页数组
--   @param type 0代表倉庫，1代表工會倉庫
--   @return table 仓库页数组（每个元素为页码整数）

-- api_GetCurrencyExchangeList(grid_x, grid_y) - 获取通货兑换列表
--   @param grid_x 兑换点X坐标（网格坐标）
--   @param grid_y 兑换点Y坐标（网格坐标）
--   @return table 通货兑换数组，每个元素包含兑换规则


-- api_CheckMapStatus() - 查询地图状态
--   @return table 地图状态
--   { isCompleted, monsterCount} isCompleted代表该地图是否完成，monsterCount代表当前怪物剩余数量


-- api_GetEndgameMapNodes() - 获取 endgame map nodes information


-- 功能：获取终章地图所有节点的详细信息
-- 返回值：包含所有节点数据的数组（索引从1开始）[{ui_obj,name_cn_utf8...}]


-- 每个节点包含的字段：
-- - ui_obj: 节点UI对象引用
-- - name_cn_utf8: 节点中文名称（UTF8编码）
-- - name_utf8: 节点名称（UTF8编码）
-- - type_name_utf8: 节点类型名称（UTF8编码）
-- - isMapAccessible: 是否可访问（布尔值）
-- - window_client_x: 窗口客户端X坐标
-- - window_client_y: 窗口客户端Y坐标
-- - index_x: 索引X坐标
-- - index_y: 索引Y坐标
-- - position_x: 位置X坐标
-- - position_y: 位置Y坐标
-- - nodeStatus: 节点状态（数值）
-- - isCompleted: 是否已完成（布尔值）
-- - monumentUnlockCount: 纪念碑解锁数量
-- - requiredMapLevel: 所需地图等级
-- - mapPlayModes: 游戏模式数组（索引从1开始）

--[[
============================================================
 SkillMonitor Lua API 简易说明文档
============================================================


1. api_IsPointInAnyActive(gx, gy [, expand])
   功能：
       判定某个格子是否处于当前「未过期技能」的覆盖范围内。
   参数：
       gx (int)          - 网格坐标 X
       gy (int)          - 网格坐标 Y
       expand (float?)   - 可选，判定范围扩展，默认 2.0
   返回：
       bool              - true 表示危险，false 表示安全


   示例：
       if api_IsPointInAnyActive(100, 200, 1.0) then
           print("当前位置危险！")
       end


------------------------------------------------------------


2. api_FindNearestSafeTile(playerX, playerY [, searchRadius, aoeExpand])
   功能：
       在玩家附近寻找最近的可站立安全点。
       条件：必须不是障碍，且不在任何「未过期技能」范围内。
   参数：
       playerX (int)     - 玩家所在格 X
       playerY (int)     - 玩家所在格 Y
       searchRadius (int?)- 可选，搜索半径，默认 50
       aoeExpand (float?)- 可选，AoE 扩展，默认 2.0
   返回：
       table { x = int, y = int } - 安全点坐标


   示例：
       local safe = api_FindNearestSafeTile(120, 250, 30, 1.5)
       print("安全点:", safe.x, safe.y)


------------------------------------------------------------


3. api_RegisterCircle(name, centerX, centerY, radius [, offsetX, offsetY, defaultTTL])
   功能：
       注册一个「圆形技能」的默认属性（只有注册过的技能才会被监测）。
   参数：
       name (wstring)    - 技能名
       centerX, centerY  - 默认圆心坐标
       radius (float)    - 半径（格）
       offsetX, offsetY? - 可选，偏移，默认 0
       defaultTTL? (sec) - 可选，默认存活时长，<=0 表示永久
   返回：
       bool              - 是否注册成功


------------------------------------------------------------


4. api_RegisterSector(name, centerX, centerY, angleRad, fovDeg, radius [, offsetX, offsetY, defaultTTL])
   功能：
       注册一个「扇形技能」的默认属性。
   参数：
       name (wstring)    - 技能名
       centerX, centerY  - 默认顶点坐标
       angleRad (float)  - 朝向角（弧度，逆时针 [0,2π)）
       fovDeg (float)    - 总张角（度，例如 40 表示 40°）
       radius (float)    - 半径（格）
       offsetX, offsetY? - 可选，偏移，默认 0
       defaultTTL? (sec) - 可选，默认存活时长，<=0 表示永久
   返回：
       bool              - 是否注册成功


------------------------------------------------------------


5. api_RegisterRect(name, centerX, centerY, angleRad, length, width [, offsetX, offsetY, defaultTTL])
   功能：
       注册一个「矩形技能」的默认属性。
   参数：
       name (wstring)    - 技能名
       centerX, centerY  - 默认几何中心坐标
       angleRad (float)  - 朝向角（弧度）
       length (float)    - 长度（格）
       width (float)     - 宽度（格）
       offsetX, offsetY? - 可选，偏移，默认 0
       defaultTTL? (sec) - 可选，默认存活时长，<=0 表示永久
   返回：
       bool              - 是否注册成功

--- 获取指定矩形范围内的仓库物品表
-- @function api_GetMapRepositoryItems
-- @param rectStartX number 矩形起始点 X 坐标（左上角）
-- @param rectStartY number 矩形起始点 Y 坐标（左上角）
-- @param rectEndX   number 矩形结束点 X 坐标（右下角）
-- @param rectEndY   number 矩形结束点 Y 坐标（右下角）
-- @return table 返回一个物品表（数组），每个元素是一个物品对象，包含字段：
    item_table["RectSart_x"] = item->RectSart_x;
    item_table["RectSart_y"] = item->RectSart_y;
    item_table["RectEnd_x"] = item->RectEnd_x;
    item_table["RectEnd_y"] = item->RectEnd_y;
============================================================
--]]

-- ---------------------------- 全局数组类型 ----------------------------
-- Actors 周围对象数组
-- Actors:GetStateMachineList() 获取状态数组
-- 返回值:map表{k:v}


-- Actors:GetObjectMagicProperties() 获取魔法属性数组
-- 返回值:字符串数组{"",""...}


-- WorldItems 地面物品数组


-- UiElements UI数组


-- api_SetExplorationArea(radius)
-- 设置探索区域
-- radius: 探索范围


-- api_UpdateMapObstacles