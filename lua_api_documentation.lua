-- Lua API 函数文档（极简版）

-- 基础控制类
-- api_Sleep(ms) - 暂停脚本执行(ms毫秒)

-- 路径与移动类
-- api_FindPath(start_x, start_y, end_x, end_y) - 计算起点到终点路径
-- api_ClickMove(x, y, world_z, mode) - 模拟点击移动(1=左键,2=右键)

-- 玩家与实体信息类
-- api_GetLocalPlayer() - 获取本地玩家信息

-- 物品与技能类
-- api_Getinventorys(index, type) - 获取存储物品列表
-- api_GetSkillSlots() - 获取当前技能槽信息

-- 地图与传送类
-- api_GetTeleportationPoint() - 获取所有传送点信息
-- api_GetNextCirclePosition(bossX, bossY, playerX, playerY, radius, angleStep, direction) - 计算绕Boss的下一个位置

-- 队伍与社交类
-- api_GetTeamInfo() - 获取队伍信息

-- 物品词缀类
-- api_GetObjectSuffix(obj) - 获取物品的词缀信息

-- 全局数组
-- Actors - 游戏中所有角色的引用
-- WorldItems - 游戏世界中的所有物品
-- UiElements - 游戏界面中的所有UI元素    