import os
import shutil
import glob
#将raccoon中的FuelFracture目录同步回fuel_rods
def sync_fracture_back():
    # 配置路径
    source_root = "/home/yp/projects/raccoon/FuelFracture"
    target_root = "/home/yp/projects/fuel_rods/FuelFracture"
    exclude_ext = {'.e', '.xx'}  # 需要排除的扩展名

    # 自定义目录复制函数
    def copy_recursive(src, dst):
        for item in os.listdir(src):
            src_path = os.path.join(src, item)
            dst_path = os.path.join(dst, item)
            
            if os.path.isdir(src_path):
                if not os.path.exists(dst_path):
                    os.makedirs(dst_path, exist_ok=True)
                copy_recursive(src_path, dst_path)
            else:
                if os.path.splitext(src_path)[1] not in exclude_ext:
                    shutil.copy2(src_path, dst_path)
                    # 反向内容替换处理
                    if src_path.endswith(('.h', '.C', '.cpp', '.hpp')):
                        with open(dst_path, 'r+', encoding='utf-8') as f:
                            content = f.read().replace('raccoonApp', 'FuelRodsApp')
                            f.seek(0)
                            f.write(content)
                            f.truncate()

    # 执行同步
    copy_recursive(source_root, target_root)
    print(f"FuelFracture目录已同步回 {target_root}")

if __name__ == "__main__":
    sync_fracture_back() 