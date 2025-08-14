-- 纯Lua实现（不依赖外部库）的更新脚本
local all_path = "."  -- 当前目录
local test_mode = false

-- 检查文件是否存在
local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- 创建目录（跨平台）
local function create_dir(path)
    -- Windows使用反斜杠，其他系统使用正斜杠
    local sep = package.config:sub(1,1)
    path = path:gsub("/", sep):gsub("\\", sep)
    
    -- 递归创建目录
    local cmd
    if sep == '\\' then  -- Windows
        cmd = string.format('mkdir "%s" 2>nul', path)
    else  -- Unix-like
        cmd = string.format('mkdir -p "%s"', path)
    end
    return os.execute(cmd) == 0
end

-- 下载文件（简单实现，无进度显示）
local function download_file(url, filename)
    local cmd
    if os.execute("curl --version 2>nul") == 0 then
        cmd = string.format('curl -L -o "%s" "%s"', filename, url)
    elseif os.execute("wget --version 2>nul") == 0 then
        cmd = string.format('wget -O "%s" "%s"', filename, url)
    else
        return false, "需要curl或wget工具"
    end
    
    local result = os.execute(cmd)
    return result == 0 or result == true
end

-- 解压文件
local function unzip_file(zipfile, target_dir)
    local cmd
    if os.execute("unzip -v 2>nul") == 0 then
        cmd = string.format('unzip -o "%s" -d "%s"', zipfile, target_dir)
    elseif os.execute("7z 2>nul") == 0 then
        cmd = string.format('7z x "%s" -o"%s" -y', zipfile, target_dir)
    else
        return false, "需要unzip或7z工具"
    end
    
    local result = os.execute(cmd)
    return result == 0 or result == true
end

-- 删除文件
local function delete_file(path)
    if file_exists(path) then
        os.remove(path)
        print("文件删除成功: " .. path)
    else
        print("文件不存在: " .. path)
    end
end

-- 主更新逻辑
if not test_mode then
    print("开始更新脚本")
    local current_dir = all_path
    local url = "http://47.108.255.112:8080/SCRIPT.zip"
    local local_filename = "POE.zip"
    
    -- 下载文件
    print("[info] 正在下载更新文件...")
    local ok, err = download_file(url, local_filename)
    if not ok then
        print("[error] 下载失败: " .. err)
        delete_file(local_filename)
        os.exit(1)
    end
    
    -- 创建目录
    if not create_dir(current_dir) then
        print("[error] 无法创建目录: " .. current_dir)
        delete_file(local_filename)
        os.exit(1)
    end
    
    -- 解压文件
    print("[info] 解压至文件夹 " .. current_dir)
    ok, err = unzip_file(local_filename, current_dir)
    if not ok then
        print("[error] 解压失败: " .. err)
        delete_file(local_filename)
        os.exit(1)
    end
    
    -- 检查关键文件
    local required_files = {
        ["start.py"] = all_path .. "/resource/scripts"
    }
    
    for file, relative_path in pairs(required_files) do
        local path = current_dir .. "/" .. relative_path .. "/" .. file
        if not file_exists(path) then
            print("[error] 缺少必要文件: " .. path)
            delete_file(local_filename)
            os.exit(1)
        end
    end
    
    print("解压验证完成，所有文件已完整解压")
    delete_file(local_filename)
    print("脚本更新完成")
else
    print("[info] 测试模式，跳过更新")
end