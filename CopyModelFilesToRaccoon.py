import os
import shutil
import glob
#将fuel_rods中的模型文件同步到raccoon
def sync_to_raccoon():
    # 路径配置
    source_base = "/home/yp/projects/fuel_rods"
    target_base = "/home/yp/projects/raccoon"
    
    # 创建目标目录
    target_include = f"{target_base}/include/MyFiles"
    target_src = f"{target_base}/src/MyFiles"
    os.makedirs(target_include, exist_ok=True)
    os.makedirs(target_src, exist_ok=True)

    # 处理include头文件
    for h_file in glob.glob(f"{source_base}/include/MyFiles/*.h"):
        dest = os.path.join(target_include, os.path.basename(h_file))
        shutil.copy2(h_file, dest)
        with open(dest, 'r+', encoding='utf-8') as f:
            content = f.read().replace('FuelRodsApp', 'raccoonApp')
            f.seek(0)
            f.write(content)
            f.truncate()

    # 处理src源文件
    for src_file in glob.glob(f"{source_base}/src/MyFiles/*"):
        if src_file.endswith(('.h', '.C')):
            dest = os.path.join(target_src, os.path.basename(src_file))
            shutil.copy2(src_file, dest)
            with open(dest, 'r+', encoding='utf-8') as f:
                content = f.read().replace('FuelRodsApp', 'raccoonApp')
                f.seek(0)
                f.write(content)
                f.truncate()

    print("正向同步完成！文件已更新至raccoon")

if __name__ == "__main__":
    sync_to_raccoon() 