package.path = package.path .. ';lualib/?.lua'
local bret = require 'behavior3.behavior_ret'

local M = {}
M.__index = M

-- 辅助函数: 计算两点距离
local function point_distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx*dx + dy*dy)
end

-- 带记忆功能的序列节点
function M.create_sequence(name, children, memory)
    return {
        name = name,
        type = "Sequence",
        desc = "带记忆的序列节点",
        memory = memory or false,
        children = children,
        running_child = nil,
        
        run = function(self, env)
            if not self._initialized then
                self.running_child = nil
                self._initialized = true
            end
            
            local start_index = 1
            if self.memory and self.running_child then
                for i, child in ipairs(self.children) do
                    if child == self.running_child then
                        start_index = i
                        break
                    end
                end
            end
            
            for i = start_index, #self.children do
                local child = self.children[i]
                local status = child.run(child, env)
                
                if status == bret.RUNNING then
                    self.running_child = child
                    return bret.RUNNING
                elseif status == bret.FAILURE then
                    self.running_child = nil
                    return bret.FAILURE
                end
            end
            
            self.running_child = nil
            return bret.SUCCESS
        end
    }
end

-- 带超时的装饰器
function M.wrap_with_timeout(child, timeout)
    return {
        name = "Timeout_" .. child.name,
        type = "Decorator",
        desc = "带超时的装饰器",
        child = child,
        timeout = timeout,
        start_time = nil,
        
        run = function(self, env)
            if not self.start_time then
                self.start_time = os.time()
            end
            
            if os.time() - self.start_time > self.timeout then
                self.start_time = nil
                return bret.FAILURE
            end
            
            local status = self.child.run(self.child, env)
            
            if status ~= bret.RUNNING then
                self.start_time = nil
            end
            
            return status
        end
    }
end

-- 基础行为节点
M.IsArrive = {
    name = "IsArrive",
    type = "Action",
    desc = "是否在终点",
    
    run = function(self, env)
        local blackboard = env.blackboard
        local player = env.owner
        
        local point = blackboard.end_point
        local path_list = blackboard.path_list
        
        if blackboard.empty_path then
            blackboard.is_arrive_end = true
            blackboard.empty_path = false
            return bret.SUCCESS
        end
        
        if point and point_distance(player.x, player.y, point[1], point[2]) < 15 then
            blackboard.is_arrive_end = true
            blackboard.end_point = nil
            return bret.SUCCESS
        else
            blackboard.is_arrive_end = false
            return bret.SUCCESS
        end
    end
}

M.MoveToTargetPoint = {
    name = "MoveToTargetPoint",
    type = "Action",
    desc = "移动到指定地点",
    
    run = function(self, env)
        local blackboard = env.blackboard
        local player = env.owner
        
        local point = blackboard.target_point
        if not point then
            return bret.SUCCESS
        end
        
        local path_list = blackboard.path_list
        
        if point_distance(player.x, player.y, point[1], point[2]) < 20 then
            if path_list and #path_list > 0 then
                table.remove(path_list, 1)
                if #path_list > 0 then
                    blackboard.target_point = {path_list[1].x, path_list[1].y}
                end
            end
            return bret.SUCCESS
        else
            player.x = player.x + (point[1] > player.x and 1 or -1)
            player.y = player.y + (point[2] > player.y and 1 or -1)
            return bret.RUNNING
        end
    end
}

M.GetPath = {
    name = "GetPath",
    type = "Action",
    desc = "计算路径",
    
    run = function(self, env)
        local blackboard = env.blackboard
        local player = env.owner
        
        local point = blackboard.end_point
        if not point then
            return bret.FAILURE
        end
        
        local path_list = blackboard.path_list
        
        if path_list and #path_list > 1 then
            blackboard.target_point = {path_list[1].x, path_list[1].y}
            table.remove(path_list, 1)
            return bret.SUCCESS
        end
        
        local result = {}
        for i = 1, 10 do
            table.insert(result, {
                x = player.x + (point[1] - player.x) * i / 10,
                y = player.y + (point[2] - player.y) * i / 10
            })
        end
        
        if #result > 0 then
            blackboard.path_list = result
            blackboard.target_point = {result[1].x, result[1].y}
            return bret.SUCCESS
        else
            return bret.FAILURE
        end
    end
}

-- 创建移动序列
function M.create_move_to()
    local is_arrive_node = M.wrap_with_timeout(M.IsArrive, 90)
    local move_to_target_point_node = M.wrap_with_timeout(M.MoveToTargetPoint, 6)
    
    local root = M.create_sequence("move_to", {
        is_arrive_node,
        M.GetPath,
        move_to_target_point_node
    }, true)
    
    return root
end

return M