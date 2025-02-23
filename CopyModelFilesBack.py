import os
import shutil
import glob
#将raccoon中的模型文件同步回fuel_rods
def sync_to_fuelrods():
    # 路径配置
    source_base = "/home/yp/projects/raccoon"
    target_base = "/home/yp/projects/fuel_rods"
    
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
            content = f.read().replace('raccoonApp', 'FuelRodsApp')
            f.seek(0)
            f.write(content)
            f.truncate()

    # 处理src源文件
    for src_file in glob.glob(f"{source_base}/src/MyFiles/*"):
        if src_file.endswith(('.h', '.C')):
            dest = os.path.join(target_src, os.path.basename(src_file))
            shutil.copy2(src_file, dest)
            with open(dest, 'r+', encoding='utf-8') as f:
                content = f.read().replace('raccoonApp', 'FuelRodsApp')
                f.seek(0)
                f.write(content)
                f.truncate()

    print("反向同步完成！文件已更新回fuel_rods")

if __name__ == "__main__":
    sync_to_fuelrods() 