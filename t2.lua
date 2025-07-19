local ffi = require("ffi")

-- 正确的Windows API声明
ffi.cdef[[
    int __stdcall GetAsyncKeyState(int vKey);
    void __stdcall Sleep(unsigned int dwMilliseconds);
]]

-- 虚拟键码
local VK_F12 = 0x7B  -- F12键码

-- 检查按键状态
local function is_key_pressed(vKey)
    local state = ffi.C.GetAsyncKeyState(vKey)
    return bit.band(state, 0x8000) ~= 0
end

-- 主程序
print("=== 脚本运行中 (按F12停止) ===")
local running = true

while running do
    -- 检测F12按键
    if is_key_pressed(VK_F12) then
        print("\n=== 检测到F12，停止脚本 ===")
        running = false
    end

    -- 执行主逻辑
    print("运行中... (按F12停止)")
    
    -- 延迟50毫秒
    ffi.C.Sleep(50)
end