import io
from pathlib import Path
import sys
import traceback
import zipfile
import sys
import os
import importlib.util


sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
import requests

all_path = os.getcwd()

def download_file(url, local_filename):
    """
    下载HTTP文件到本地

    :param url: 要下载文件的URL
    :param local_filename: 本地文件名（包含路径）
    """
    try:
        with requests.get(url, stream=True) as r:
            r.raise_for_status()
            with open(local_filename, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        print(f"文件下载完成: {local_filename}")
    except requests.RequestException as e:
        print(f"下载文件时出错: {e}")

def unzip_file(zip_path, extract_dir):
    print(f"[debug] 解压文件至: {extract_dir}")
    extracted_files = []
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            # print("[debug] 压缩文件内容:", zip_ref.namelist())
            zip_ref.extractall(extract_dir)
            extracted_files = zip_ref.namelist()
            print(f"[debug] 解压完成，文件数: {len(extracted_files)}")
    except Exception as e:
        print(f"[error] 解压失败: {e}")
    return extracted_files

def delete_file(file_path):
    """
    删除指定路径的文件

    :param file_path: 要删除的文件的路径
    """
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"文件删除成功: {file_path}")
        else:
            print(f"文件不存在: {file_path}")
    except Exception as e:
        print(f"删除文件时出错: {e}")

def load_external_modules(module_dir):
    """动态加载外部模块文件夹"""
    sys.path.insert(0, module_dir)  # 将模块目录添加到 Python 路径
    
    # 遍历 module_dir 目录，动态导入所有子目录（模块）
    for module_name in os.listdir(module_dir):
        module_path = os.path.join(module_dir, module_name)
        
        # 确保是目录（模块文件夹）且包含 __init__.py
        if os.path.isdir(module_path) and os.path.exists(os.path.join(module_path, "__init__.py")):
            try:
                # 动态导入模块
                spec = importlib.util.spec_from_file_location(module_name, os.path.join(module_path, "__init__.py"))
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                print(f"Loaded module: {module_name}")
            except Exception as e:
                print(f"Failed to load module {module_name}: {e}")

test_mode = False
if not test_mode:  # 测试模式下不更新
    print("开始更新脚本")
    current_dir = all_path
    url = "http://47.108.255.112:8080/SCRIPT.zip"
    local_filename = "POE.zip"

    try:
        # 下载文件（添加30秒超时）
        print("[info] 正在下载更新文件...",flush=True)
        
        def download_with_progress(url, filename, timeout=300):
            response = requests.get(url, stream=True, timeout=timeout)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            block_size = 1024  # 1KB
            downloaded = 0
            
            with open(filename, 'wb') as f:
                for data in response.iter_content(block_size):
                    f.write(data)
                    downloaded += len(data)
                    # 计算下载百分比
                    percent = (downloaded / total_size) * 100 if total_size > 0 else 0
                    # 打印进度条和百分比
                    print(f"\r[下载进度] {percent:.1f}% ({downloaded}/{total_size} bytes)", end="", flush=True)
            
            print()  # 换行
        
        download_with_progress(url, local_filename, timeout=30)
        
        # 确保解压目录存在
        os.makedirs(current_dir, exist_ok=True)

        # 解压文件并验证
        print(f"[info] 解压至文件夹 {current_dir}",flush=True)
        extracted_files = unzip_file(local_filename, current_dir)  # 假设unzip_file返回解压的文件列表
        
        # 验证解压结果
        if not extracted_files:
            raise Exception("解压失败，未解压出任何文件")
        
        # 检查关键文件是否存在（精确路径匹配）
        required_files = {
            'start.py': all_path + "\\resource\\scripts",  # 使用os.path.join确保跨平台兼容
        }

        for file, relative_path in required_files.items():
            absolute_path = os.path.join(current_dir, relative_path, file)
            if not os.path.exists(absolute_path):
                missing_path = os.path.join(relative_path, file) if relative_path else file
                raise Exception(f"解压不完整，缺少必要文件: {missing_path}")
            # print(f"[验证] 找到关键文件: {os.path.join(relative_path, file)}",flush=True)

        
        print("解压验证完成，所有文件已完整解压",flush=True)
        
        # 确认解压成功后再删除压缩包
        delete_file(local_filename)
        print("脚本更新完成",flush=True)

    except requests.Timeout:
        print("\n[error] 下载超时，请检查网络连接或稍后再试",flush=True)
        delete_file(local_filename)  # 清理可能不完整的下载文件
        sys.exit(1)
    except requests.exceptions.RequestException as e:
        print(f"\n[error] 下载失败: {str(e)}",flush=True)
        delete_file(local_filename)
        sys.exit(1)
    except Exception as e:
        print(f"\n[error] 更新过程中出现错误: {str(e)}")
        if 'extracted_files' in locals() and not extracted_files:
            print("[warning] 检测到解压失败，请检查压缩包完整性",flush=True)
        delete_file(local_filename)
        sys.exit(1)
else:
    print("[info] 测试模式，跳过更新",flush=True)

