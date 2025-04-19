import os
import shutil
import glob
#将raccoon中的模型文件同步回fuel_rods
def sync_to_fuelrods():
    # 路径配置
    source_base = "/home/yp/projects/raccoon"
    target_base = "/home/yp/projects/fuel_rods"
    
    # 创建目标根目录
    target_include = f"{target_base}/include/MyFiles"
    target_src = f"{target_base}/src/MyFiles"
    os.makedirs(target_include, exist_ok=True)
    os.makedirs(target_src, exist_ok=True)

    # 复制include目录及其所有子目录和文件
    def copy_with_content_replace(src_dir, dst_dir):
        if not os.path.exists(dst_dir):
            os.makedirs(dst_dir)
            
        for item in os.listdir(src_dir):
            src_path = os.path.join(src_dir, item)
            dst_path = os.path.join(dst_dir, item)
            
            if os.path.isdir(src_path):
                # 递归复制子目录
                copy_with_content_replace(src_path, dst_path)
            else:
                # 复制文件并替换内容
                shutil.copy2(src_path, dst_path)
                if src_path.endswith(('.h', '.C')):
                    with open(dst_path, 'r+', encoding='utf-8') as f:
                        content = f.read().replace('raccoonApp', 'FuelRodsApp')
                        f.seek(0)
                        f.write(content)
                        f.truncate()
    
    # 复制include目录
    source_include = f"{source_base}/include/MyFiles"
    copy_with_content_replace(source_include, target_include)
    
    # 复制src目录
    source_src = f"{source_base}/src/MyFiles"
    copy_with_content_replace(source_src, target_src)

    print("反向同步完成！文件及子目录已更新回fuel_rods")

if __name__ == "__main__":
    sync_to_fuelrods() 