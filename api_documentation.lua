-- API 函数详细文档
-- ================
-- 所有函数均通过 api_ 前缀调用

-- 时间控制
-- api_Sleep(ms) - 延迟执行指定毫秒数
--   @param ms 延迟的毫秒数
--   @return nil

-- api_GetTickCount64() - 获取系统启动后的毫秒时间戳
--   @return number 毫秒时间戳

-- 玩家与环境
-- api_GetLocalPlayer() - 获取本地玩家信息
--   @return table 包含玩家属性的表格

-- api_GetMinimapActorInfo() - 获取小地图周围对象信息
--   @return table 包含周围对象的表格

-- api_GetUiElements() - 获取UI元素
--   @return table 包含UI元素的表格

-- 移动控制
-- api_ClickMove(x, y, world_z, mode) - 点击移动到指定坐标
--   @param x 游戏坐标X
--   @param y 游戏坐标Y
--   @param world_z 高度
--   @param mode 移动模式
--   @return nil

-- api_FindPath(start_x, start_y, end_x, end_y) - 查找从起点到终点的路径
--   @param start_x 起点X
--   @param start_y 起点Y
--   @param end_x 终点X
--   @param end_y 终点Y
--   @return table 路径点数组

-- api_FindRandomWalkablePosition(x, y, radius) - 返回半径内随机可行走坐标
--   @param x 中心X坐标
--   @param y 中心Y坐标
--   @param radius 半径范围
--   @return table 坐标点

-- api_FindNearestReachablePoint(dx, dy, radius, mode) - 返回距离该点最近的可到达点
--   @param dx 目标X坐标
--   @param dy 目标Y坐标
--   @param radius 搜索半径
--   @param mode 模式(0:代表以dx,dy为中心，离dx,dy最近的点 1：代表 以dx,dy 为中心，离自身玩家最近的点)
--   @return table 坐标点

-- api_GetSafeAreaLocation() - 获得一个安全位置
--   @return table 安全坐标点

-- api_GetSafeAreaLocationNoMonsters(range) - 获得指定范围内无怪物的安全位置
--   @param range 搜索范围
--   @return table 安全坐标点

-- 物品与技能
-- api_Getinventorys(index, type) - 获取背包物品
--   @param index 背包索引
--   @param type 物品类型
--   @return table 物品数组

-- api_GetSkillSlots() - 获取技能槽信息
--   @return table 技能槽数组

-- api_GetSelectableSkillControls() - 获取可选技能控件
--   @return table 可选技能控件数组

-- api_GetAllSkill() - 获取所有技能
--   @return table 所有技能数组

-- api_GetObjectSuffix(obj) - 根据物品对象获取词缀
--   @param obj 物品对象
--   @return table 词缀数组

-- 地图与导航
-- api_GetTeleportationPoint() - 获取传送点信息
--   @return table 传送点数组

-- api_GetNextCirclePosition(bossX, bossY, playerX, playerY, radius, angleStep, direction) - 获取下一个绕圈位置
--   @param bossX 首领X坐标
--   @param bossY 首领Y坐标
--   @param playerX 玩家X坐标
--   @param playerY 玩家Y坐标
--   @param radius 绕圈半径
--   @param angleStep 角度步长
--   @param direction 方向(1顺时针,-1逆时针)
--   @return table 坐标点

-- api_GetUnexploredArea(radius) - 获取未探索的区域
--   @param radius 搜索半径
--   @return table 坐标点

-- api_UpdateMapInfo() - 刷新地图信息
--   @return nil

-- api_UpdateMapObstacles(range) - 更新地图障碍点
--   @param range 范围
--   @return nil

-- api_RestoreOriginalMap() - 恢复原始地图
--   @return nil

-- api_GetCalculateCircleGridPoints(grid_x, grid_y, radius, gridWidth) - 获取圆形范围内均匀分布的网格点
--   @param grid_x 中心X坐标
--   @param grid_y 中心Y坐标
--   @param radius 半径
--   @param gridWidth 网格宽度
--   @return table 坐标点数组

-- 任务与队伍
-- api_GetQuestList(index) - 获取任务列表
--   @param index 任务索引
--   @return table 任务数组

-- api_GetTeamInfo() - 获取队伍信息
--   @return table 队伍成员数组

-- 高级功能
-- api_GetcurrentEndgameNodePoints() - 获得当前异界地图位置
--   @return number, number X坐标, Y坐标

-- api_HasObstacleBetween(grid_x, grid_y) - 射线检测两点之间是否有障碍物
--   @param grid_x 目标点X坐标
--   @param grid_y 目标点Y坐标
--   @return boolean true表示无障碍物

-- api_InitGameWindow() - 初始化游戏窗口
--   @return nil

-- api_GetSacrificeItems() - 获得祭祀物品列表
--   @return table 祭祀物品数组

-- api_AddMonitoringSkills(type, path_name, radius) - 增加技能监测
--   @param type 监测类型
--   @param path_name 路径名称
--   @param radius 监测半径
--   @return nil

-- api_InitExplorationArea() - 更新探索地图
--   @return nil

-- api_EndgameNodeMove(position_x, position_y) - 异界地图节点移动
--   @param position_x X坐标
--   @param position_y Y坐标
--   @return nil

-- api_GetRepositoryPages(type) - 获取仓库页数组
--   @param type 仓库类型
--   @return table 仓库页数组

-- api_GetCurrencyExchangeList(grid_x, grid_y) - 获得通货兑换数组
--   @param grid_x X坐标
--   @param grid_y Y坐标
--   @return table 通货兑换数组    


-- api_EnumProcess(name) - 枚举进程
--   @return table 进程id数组    


-- api_FindWindowByProcess(class_name, title , process_name , Pid) - 获得通货兑换数组
--   @param class_name      窗口类名
--   @param title           窗口标题
--   @param process_name    进程名
--   @param Pid             进程id
--   @return number 窗口句柄    