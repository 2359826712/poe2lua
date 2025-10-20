-- 选择最优地图钥匙
_M.select_best_map_key = function(params)
    -- 解析参数表
    local inventory = params.inventory
    local click = params.click or 0
    local key_level_threshold = params.key_level_threshold
    local type_map = params.type or 0
    local index = params.index or 0
    local score = params.score or 0
    local no_categorize_suffixes = params.no_categorize_suffixes or 0
    local min_level = params.min_level
    local not_use_map = params.not_use_map or {}
    local trashest = params.trashest or false
    local page_type = params.page_type
    local entry_length = params.entry_length or 0
    local START_X = params.START_X or 0
    local START_Y = params.START_Y or 0
    local color = params.color or 0
    local vall = params.vall or false
    local instill = params.instill or false

    -- 新增：优先打词缀配置
    local priority_map = params.priority_map or {}
    local priority_enabled = params.priority_enabled or false

    if not inventory or #inventory == 0 then
        _M.dbgp("背包为空")
        return nil
    end

    -- UTF-8优化的词缀分类
    local function categorize_suffixes_utf8(suffixes)
        local categories = {
            ['譫妄'] = {},
            ['其他'] = {},
            ['不打'] = {},
            ['无效'] = {},
            ['优先'] = {}  -- 新增：优先词缀分类
        }

        if not suffixes or #suffixes == 0 then
            categories['无效'][1] = '空词条列表'
            return categories
        end

        -- UTF-8安全的排除列表处理
        local processed_not_use_map = {}
        for _, excl in ipairs(not_use_map or {}) do
            if excl then
                local processed = string.gsub(excl, "<rgb%(255,0,0%)>", "")
                processed = _M.clean_utf8(processed)
                processed = _M.extract_utf8_text(processed)
                processed = string.gsub(processed, "[%d%%%s]", "")
                table.insert(processed_not_use_map, processed)
            end
        end

        -- UTF-8安全的优先词缀处理
        local processed_priority_map = {}
        if priority_enabled and priority_map then
            for _, priority in ipairs(priority_map) do
                if priority then
                    local processed = string.gsub(priority, "<rgb%(255,0,0%)>", "")
                    processed = _M.clean_utf8(processed)
                    processed = _M.extract_utf8_text(processed)
                    processed = string.gsub(processed, "[%d%%%s]", "")
                    table.insert(processed_priority_map, processed)
                end
            end
        end

        for i, suffix in ipairs(suffixes) do
            local suffix_name = suffix.name_utf8 or ""

            -- 1. 移除RGB标签
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>", "")
            
            -- 2. UTF-8安全清理
            cleaned_suffix = _M.clean_utf8(cleaned_suffix)
            
            -- 3. UTF-8文本提取
            cleaned_suffix = _M.extract_utf8_text(cleaned_suffix)

            if cleaned_suffix == "" then
                table.insert(categories['无效'], suffix_name)
                goto continue
            end

            -- UTF-8安全的词条处理
            local processed_suffix = string.gsub(cleaned_suffix, "[%d%%%s]", "")

            -- 优先检查优先词缀（如果启用）
            if priority_enabled then
                for _, processed_priority in ipairs(processed_priority_map) do
                    if string.find(processed_suffix, processed_priority, 1, true) then
                        table.insert(categories['优先'], cleaned_suffix)
                        goto continue
                    end
                end
            end

            -- UTF-8安全的排除检查
            for _, processed_excl in ipairs(processed_not_use_map) do
                if string.find(processed_suffix, processed_excl, 1, true) then
                    table.insert(categories['不打'], cleaned_suffix)
                    goto continue
                end
            end

            -- UTF-8安全的疯癫词条检查
            if string.find(processed_suffix, "譫妄", 1, true) then
                table.insert(categories['譫妄'], cleaned_suffix)
                goto continue
            end

            -- 其他UTF-8词条
            table.insert(categories['其他'], cleaned_suffix)

            ::continue::
        end

        return categories
    end

    -- 优先词缀匹配检查函数
    local function has_priority_suffixes(suffixes)
        if not priority_enabled or not priority_map or #priority_map == 0 then
            return false
        end

        if not suffixes or #suffixes == 0 then
            return false
        end

        -- 处理优先词缀列表
        local processed_priority_map = {}
        for _, priority in ipairs(priority_map) do
            if priority then
                local processed = string.gsub(priority, "<rgb%(255,0,0%)>", "")
                processed = _M.clean_utf8(processed)
                processed = _M.extract_utf8_text(processed)
                processed = string.gsub(processed, "[%d%%%s]", "")
                table.insert(processed_priority_map, processed)
            end
        end

        -- 检查是否有匹配的优先词缀
        for _, suffix in ipairs(suffixes) do
            local suffix_name = suffix.name_utf8 or ""
            local cleaned_suffix = string.gsub(suffix_name, "<rgb%(255,0,0%)>", "")
            cleaned_suffix = _M.clean_utf8(cleaned_suffix)
            cleaned_suffix = _M.extract_utf8_text(cleaned_suffix)
            local processed_suffix = string.gsub(cleaned_suffix, "[%d%%%s]", "")

            for _, processed_priority in ipairs(processed_priority_map) do
                if string.find(processed_suffix, processed_priority, 1, true) then
                    return true
                end
            end
        end

        return false
    end

    local best_key = nil
    local max_score = -math.huge
    local min_score = math.huge
    local processed_keys = 0

    -- 预处理key_level_threshold，同时解析优先词缀配置
    local white, blue, gold, valls, level = {}, {}, {}, {}, {}
    local priority_config_by_level = {}  -- 新增：按等级存储优先词缀配置

    if key_level_threshold then
        for _, user_map in ipairs(key_level_threshold) do
            local tier_value = user_map['階級']
            local level_list = {}
            
            if type(tier_value) == "string" and string.find(tier_value, "-") then
                local min_tier, max_tier = tier_value:match("(%d+)-(%d+)")
                min_tier = tonumber(min_tier)
                max_tier = tonumber(max_tier)
                
                if min_tier and max_tier then
                    for t = min_tier, max_tier do
                        table.insert(level_list, t)
                    end
                end
            else
                local tier_num = tonumber(tier_value)
                if tier_num then
                    table.insert(level_list, tier_num)
                end
            end
            
            for _, lvl in ipairs(level_list) do
                table.insert(level, lvl)
                
                -- 存储该等级的优先词缀配置
                priority_config_by_level[lvl] = {
                    priority_map = user_map['优先打词缀'] and user_map['优先打词缀']['詞綴'] or {},
                    priority_enabled = user_map['优先打词缀'] and user_map['优先打词缀']['是否開啟'] or false
                }
                
                if user_map['白'] then
                    if not _M.table_contains(white, lvl) then
                        table.insert(white, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
                
                if user_map['藍'] then
                    if not _M.table_contains(blue, lvl) then
                        table.insert(blue, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
                
                if user_map['黃'] then
                    if not _M.table_contains(gold, lvl) then
                        table.insert(gold, lvl)
                    end
                    if user_map['已污染'] then
                        if not _M.table_contains(valls, lvl) then
                            table.insert(valls, lvl)
                        end
                    end
                end
            end
        end
    end

    -- 处理物品 - 第一阶段：过滤
    local valid_items = {}  -- 存储所有有效的物品

    for i, item in ipairs(inventory) do
        -- 检查是否为地图钥匙
        if not string.find(item.baseType_utf8 or "", "地圖鑰匙") then
            goto continue
        end

        -- 颜色过滤
        if color > 0 then
            if (item.color or 0) < color then
                goto continue
            end
        end

        local key_level = item.mapLevel

        -- 污染过滤
        if vall then
            if item.contaminated then
                goto continue
            end
        end

        -- 等级过滤
        if min_level and key_level < min_level then
            goto continue
        end

        -- 钥匙等级阈值检查
        if key_level_threshold then
            local valid = false
            if item.color == 0 and #white > 0 and _M.table_contains(white, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end
            if item.color == 1 and #blue > 0 and _M.table_contains(blue, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end
            if item.color == 2 and #gold > 0 and _M.table_contains(gold, key_level) then
                if item.contaminated and #valls > 0 and _M.table_contains(valls, key_level) then
                    valid = true
                end
                valid = true
            end

            if not valid then
                goto continue
            end
        end

        -- 词缀长度检查
        if entry_length > 0 then
            if (item.fixedSuffixCount or 0) < entry_length and item.contaminated then
                goto continue
            end
        end

        local suffixes = nil
        if (item.color or 0) > 0 then
            suffixes = api_GetObjectSuffix(item.mods_obj)
            if suffixes and #suffixes > 0 then
                -- 排除词缀检查
                if #not_use_map > 0 then
                    if _M.match_item_suffixes(suffixes, not_use_map, true) then
                        if trashest then
                            best_key = item
                            break
                        end
                        goto continue
                    end
                end
            end
        end

        -- 通过所有过滤条件，添加到有效物品列表
        table.insert(valid_items, item)
        
        ::continue::
    end

    -- 如果是trashest模式，直接返回第一个匹配的垃圾物品
    if trashest and best_key then
        _M.dbgp("trashest模式：选择第一个匹配的垃圾物品")
        if click == 1 then
            if page_type == 7 then
                local pos =  _M.get_center_position_store_max(
                    {best_key.start_x or 0, best_key.start_y or 0},
                    {best_key.end_x or 0, best_key.end_y or 0},
                    15, 100, 22, 22)
                _M.ctrl_left_click(pos[1], pos[2])
                return best_key.mapLevel
            end
            if type_map == 1 then
                _M.ctrl_left_click_store_items(best_key.obj or nil, inventory)
                return best_key.mapLevel
            end
            if type_map == 3 then
                _M.return_more_map(best_key.obj or nil, inventory, START_X, START_Y)
                return best_key.mapLevel
            end
            _M.ctrl_left_click_bag_items(best_key.obj or nil, inventory)
            return best_key.mapLevel
        end
        return best_key
    end

    -- 强满足版本：每个阶级单独处理
    local best_priority_key = nil
    local best_priority_score = -math.huge
    local best_priority_reason = ""
    local found_items = {}  -- 存储找到的物品

    -- 辅助函数：根据词条名称获取物品属性值
    local function get_item_priority_value(item, priority_name)
        if priority_name == "怪物群大小" then
            return item.monsterPackSize
        elseif priority_name == "稀有怪物" then
            return item.rareMonster
        elseif priority_name == "物品稀有度" then
            return item.itemRarity
        elseif priority_name == "地图掉落机率" then
            return item.mapDropChance
        elseif priority_name == "换届石掉落几率" then
            return item.mapDropChance  -- 假设换届石掉落几率使用mapDropChance属性
        else
            _M.dbgp("未知优先词条: " .. tostring(priority_name))
            return nil
        end
    end

    local items_by_tier = {}
    if #valid_items > 0 then
        -- 按阶级分组物品
        for i, item in ipairs(valid_items) do
            local tier = item.mapLevel
            if not items_by_tier[tier] then
                items_by_tier[tier] = {}
            end
            table.insert(items_by_tier[tier], item)
        end
        
        -- 对每个阶级单独处理
        for tier, tier_items in pairs(items_by_tier) do
            local level_config = priority_config_by_level[tier] or {}
            local level_priority_enabled = level_config.priority_enabled or false
            local level_priority_map = level_config.priority_map or {}

            -- 如果该阶级没有开启优先词缀配置，跳过
            if not level_priority_enabled or #level_priority_map == 0 then
                goto continue_tier
            end
            
            -- 第一轮：处理第一个优先词条
            local first_priority_items = {}
            for i, item in ipairs(tier_items) do
                local first_priority_name = level_priority_map[1]  -- 第一个词条
                if first_priority_name then
                    local item_value = get_item_priority_value(item, first_priority_name)
                    
                    -- 检查第一个优先词条
                    if item_value and item_value > 0 then
                        local score = item_value
                        local reason = string.format("阶级%d-第1词条-%s:%d", tier, first_priority_name, score)
                        
                        table.insert(first_priority_items, {
                            item = item,
                            score = score,
                            reason = reason,
                            priority_index = 1,
                            tier = tier
                        })
                    end
                end
            end
            
            if #first_priority_items == 0 then
                best_priority_key = nil
                best_priority_score = -math.huge
                break  -- 该阶级没有满足条件的物品，整个函数返回nil
            end
            
            -- 第二轮：在满足第一个词条的物品中检查第二个词条
            local second_priority_items = {}
            for i, data in ipairs(first_priority_items) do
                local item = data.item
                
                if #level_priority_map >= 2 then
                    local second_priority_name = level_priority_map[2]  -- 第二个词条
                    if second_priority_name then
                        local item_value = get_item_priority_value(item, second_priority_name)
                        
                        -- 检查第二个优先词条
                        if item_value and item_value > 0 then
                            local total_score = data.score + item_value * 0.8  -- 第二个词条权重降低
                            local reason = data.reason .. string.format("+第2词条-%s:%d", second_priority_name, item_value)
                            
                            table.insert(second_priority_items, {
                                item = item,
                                score = total_score,
                                reason = reason,
                                priority_index = 2,
                                tier = tier
                            })
                        end
                    end
                end
                
                -- 如果没有第二个词条，保留第一个词条的数据
                if #level_priority_map < 2 then
                    table.insert(second_priority_items, data)
                end
            end
            
            if #second_priority_items > 0 then
                -- 第三轮：在满足前两个词条的物品中检查第三个词条
                local third_priority_items = {}
                for i, data in ipairs(second_priority_items) do
                    local item = data.item
                    
                    if #level_priority_map >= 3 then
                        local third_priority_name = level_priority_map[3]  -- 第三个词条
                        if third_priority_name then
                            local item_value = get_item_priority_value(item, third_priority_name)
                            
                            -- 检查第三个优先词条
                            if item_value and item_value > 0 then
                                local total_score = data.score + item_value * 0.6  -- 第三个词条权重进一步降低
                                local reason = data.reason .. string.format("+第3词条-%s:%d", third_priority_name, item_value)
                                
                                table.insert(third_priority_items, {
                                    item = item,
                                    score = total_score,
                                    reason = reason,
                                    priority_index = 3,
                                    tier = tier
                                })
                            end
                        end
                    end
                    
                    -- 如果没有第三个词条，保留之前的数据
                    if #level_priority_map < 3 then
                        table.insert(third_priority_items, data)
                    end
                end
                
                if #third_priority_items > 0 then
                    -- 第四轮：在满足前三个词条的物品中检查第四个词条
                    local fourth_priority_items = {}
                    for i, data in ipairs(third_priority_items) do
                        local item = data.item
                        
                        if #level_priority_map >= 4 then
                            local fourth_priority_name = level_priority_map[4]  -- 第四个词条
                            if fourth_priority_name then
                                local item_value = get_item_priority_value(item, fourth_priority_name)
                                
                                -- 检查第四个优先词条
                                if item_value and item_value > 0 then
                                    local total_score = data.score + item_value * 0.4  -- 第四个词条权重最低
                                    local reason = data.reason .. string.format("+第4词条-%s:%d", fourth_priority_name, item_value)

                                    table.insert(fourth_priority_items, {
                                        item = item,
                                        score = total_score,
                                        reason = reason,
                                        priority_index = 4,
                                        tier = tier
                                    })
                                end
                            end
                        end
                        
                        -- 如果没有第四个词条，保留之前的数据
                        if #level_priority_map < 4 then
                            table.insert(fourth_priority_items, data)
                        end
                    end
                    
                    found_items = fourth_priority_items
                else
                    found_items = second_priority_items
                end
            else
                found_items = first_priority_items
            end
            
            -- 从该阶级最终筛选出的物品中选择分数最高的
            local tier_best_score = -math.huge
            local tier_best_item = nil
            local tier_best_reason = ""
            
            for i, data in ipairs(found_items) do
                if data.score > tier_best_score then
                    tier_best_score = data.score
                    tier_best_item = data.item
                    tier_best_reason = data.reason
                end
            end
            
            -- 更新全局最优
            if tier_best_score > best_priority_score then
                best_priority_score = tier_best_score
                best_priority_key = tier_best_item
                best_priority_reason = tier_best_reason
            end
            
            ::continue_tier::
        end
    end

    -- 第三阶段：确定最终选择
    if not trashest then
        if best_priority_key then
            -- 优先选择有优先词缀的物品
            _M.dbgp("选择优先词缀数值最高的物品: " .. best_priority_reason .. "总分数: " .. tostring(best_priority_score))
            best_key = best_priority_key
            max_score = best_priority_score
        else
            -- 如果有任何阶级开启了优先配置但没有找到匹配物品，返回nil
            local any_priority_enabled = false
            for tier, items in pairs(items_by_tier or {}) do
                local level_config = priority_config_by_level[tier] or {}
                if level_config.priority_enabled and #(level_config.priority_map or {}) > 0 then
                    any_priority_enabled = true
                    break
                end
            end
            
            if any_priority_enabled then
                _M.dbgp("有阶级开启了优先词缀配置但未找到匹配物品，返回nil")
                return nil
            elseif #valid_items > 0 then
                -- 如果没有阶级开启优先配置，使用原来的评分逻辑
                _M.dbgp("没有阶级开启优先词缀配置，使用普通评分逻辑")
                
                for i, item in ipairs(valid_items) do
                    local suffixes = nil
                    if (item.color or 0) > 0 then
                        suffixes = api_GetObjectSuffix(item.mods_obj)
                    end
        
                    -- 词缀分类和评分
                    local categories = categorize_suffixes_utf8(suffixes or {})
        
                    local key_level = item.mapLevel
                    -- 计算评分
                    local level_weight = key_level * 5
                    local suffix_score = 0
                    local color_score = 25 * (item.color or 0)
                    if item.contaminated then
                        color_score = color_score + 100
                    end
        
                    local additional_score = 0
                    -- 基于优先级逆序的四个参数加分 (item.itemRarity最重要)
                    if item.itemRarity then
                        local rarity_score = item.itemRarity * 4.0
                        if item.itemRarity >= 90 then
                            rarity_score = rarity_score + 100
                        elseif item.itemRarity >= 70 then
                            rarity_score = rarity_score + 50
                        elseif item.itemRarity >= 50 then
                            rarity_score = rarity_score + 25
                        end
                        additional_score = additional_score + math.min(rarity_score, 300)
                    end

                    if item.rareMonster then
                        local rare_score = item.rareMonster * 3.0
                        if item.rareMonster >= 25 then
                            rare_score = rare_score + 75
                        elseif item.rareMonster >= 15 then
                            rare_score = rare_score + 40
                        elseif item.rareMonster >= 8 then
                            rare_score = rare_score + 20
                        end
                        additional_score = additional_score + math.min(rare_score, 250)
                    end

                    if item.monsterPackSize then
                        local pack_score = item.monsterPackSize * 2.0
                        if item.monsterPackSize >= 35 then
                            pack_score = pack_score + 50
                        elseif item.monsterPackSize >= 25 then
                            pack_score = pack_score + 25
                        elseif item.monsterPackSize >= 15 then
                            pack_score = pack_score + 10
                        end
                        additional_score = additional_score + math.min(pack_score, 180)
                    end

                    if item.mapDropChance then
                        local map_score = item.mapDropChance * 1.5
                        if item.mapDropChance >= 85 then
                            map_score = map_score + 30
                        elseif item.mapDropChance >= 65 then
                            map_score = map_score + 15
                        elseif item.mapDropChance >= 45 then
                            map_score = map_score + 8
                        end
                        additional_score = additional_score + math.min(map_score, 150)
                    end
        
                    local total_score
                    if no_categorize_suffixes == 0 then
                        total_score = level_weight + suffix_score + color_score + additional_score
                    else
                        total_score = level_weight + color_score + additional_score
                    end
        
                    -- 记录最优
                    if index == 0 then
                        if total_score > max_score and total_score > 0 then
                            max_score = total_score
                            best_key = item
                        end
                    else
                        if total_score < min_score then
                            min_score = total_score
                            best_key = item
                        end
                    end
                end
            else
                _M.dbgp("没有找到任何有效的物品")
                best_key = nil
            end
        end
    else
        -- trashest模式：选择最垃圾的物品（评分最低的）
        _M.dbgp("trashest模式：选择评分最低的物品")
        local worst_score = math.huge
        local worst_key = nil
        
        for i, item in ipairs(valid_items) do
            local suffixes = nil
            if (item.color or 0) > 0 then
                suffixes = api_GetObjectSuffix(item.mods_obj)
            end

            -- 词缀分类和评分
            local categories = categorize_suffixes_utf8(suffixes or {})

            local key_level = item.mapLevel
            -- 计算评分（与正常模式相同）
            local level_weight = key_level * 5
            local suffix_score = 0
            local color_score = 25 * (item.color or 0)
            if item.contaminated then
                color_score = color_score + 100
            end

            local additional_score = 0
            if item.itemRarity then
                local rarity_score = item.itemRarity * 4.0
                additional_score = additional_score + math.min(rarity_score, 300)
            end
            if item.rareMonster then
                local rare_score = item.rareMonster * 3.0
                additional_score = additional_score + math.min(rare_score, 250)
            end
            if item.monsterPackSize then
                local pack_score = item.monsterPackSize * 2.0
                additional_score = additional_score + math.min(pack_score, 180)
            end
            if item.mapDropChance then
                local map_score = item.mapDropChance * 1.5
                additional_score = additional_score + math.min(map_score, 150)
            end

            local total_score
            if no_categorize_suffixes == 0 then
                total_score = level_weight + suffix_score + color_score + additional_score
            else
                total_score = level_weight + color_score + additional_score
            end

            -- 选择评分最低的物品
            if total_score < worst_score then
                worst_score = total_score
                worst_key = item
            end
        end
        
        best_key = worst_key
        max_score = worst_score
    end

    -- 后续处理逻辑
    if best_key then
        if score ~= 0 then
            local final_score = 0
            if index == 0 then
                final_score = max_score or 0
            else
                final_score = min_score or 0
            end
            return best_key, final_score
        end
    else
        _M.dbgp("警告: best_key 为 nil")
    end

    -- 执行选择
    if best_key then
        if score == 1 then
            return best_key, best_key.mapLevel
        end
        if click == 1 then
            if page_type == 7 then
                local pos =  _M.get_center_position_store_max(
                    {best_key.start_x or 0, best_key.start_y or 0},
                    {best_key.end_x or 0, best_key.end_y or 0},
                    15, 100, 22, 22)
                _M.ctrl_left_click(pos[1], pos[2])
                return best_key.mapLevel
            end
            if type_map == 1 then
                _M.ctrl_left_click_store_items(best_key.obj or nil, inventory)
                return best_key.mapLevel
            end
            if type_map == 3 then
                _M.return_more_map(best_key.obj or nil, inventory, START_X, START_Y)
                return best_key.mapLevel
            end

            _M.ctrl_left_click_bag_items(best_key.obj or nil, inventory)
            return best_key.mapLevel
        end
        return best_key
    else
        return nil
    end

    return best_key
end