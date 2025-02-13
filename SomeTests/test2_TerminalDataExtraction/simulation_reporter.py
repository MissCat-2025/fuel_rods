"""
MOOSE仿真数据采集与报告生成一体化工具
版本：2.1
功能：实时监控、性能分析、自动生成对齐格式报告
"""

import subprocess
import re
import time
import numpy as np
from collections import defaultdict

class MooseAnalyzer:
    def __init__(self, input_file):
        self.input_file = input_file
        self.data = {
            'timesteps': defaultdict(dict),
            'performance': {'max_memory': 0, 'memory_history': []},
            'mesh': {'nodes': 0, 'elements': 0},
            'summary': {'total_time': 0, 'time_per_step': []}
        }
        self.current_step = 0
        self.step_start = 0
        self.start_time = time.time()

        # 增强型正则表达式
        self.patterns = {
            'mesh': re.compile(
                r'Nodes:.*?Total:\s*(\d+).*?Elems:.*?Total:\s*(\d+)', 
                re.DOTALL
            ),
            'timestep': re.compile(r'Time Step\s+(\d+),\s+time\s*=\s*([\d\.]+),\s+dt\s*=\s*([\d\.]+)'),
            'memory': re.compile(
                r'\[\s*([\d\.]+)\s+(MB|mb)\]|Memory:\s+([\d\.]+)\s+(MB|mb)',
                re.IGNORECASE
            ),
            'nonlinear': re.compile(r'Nonlinear\s+\|R\|\s*=\s*([\d\.E+-]+)\s+'),
            'linear': re.compile(r'Linear\s+\|R\|\s*=\s*([\d\.E+-]+)\s+'),
            'converged': re.compile(r'Solve\s+Converged!'),
            'timing': re.compile(r'Time\s+Step\s+\d+,\s+time\s*=\s*[\d\.]+\s*,\s+dt\s*=\s*[\d\.]+\s*\n\s*(\d+)\s+Nonlinear\s+'),
            'step_time': re.compile(
                r'Finished Solving\s+\[\s*([\d\.]+)\s+s\]'
            ),
        }

    def _parse_line(self, line):
        """增强型日志解析"""
        try:
            # 网格信息解析
            if 'Nodes:' in line and 'Elems:' in line:
                if match := self.patterns['mesh'].search(line.replace('\n', ' ')):
                    self.data['mesh'].update({
                        'nodes': int(match.group(1)),
                        'elements': int(match.group(2))
                    })

            # 时间步开始
            elif 'Time Step' in line and 'time =' in line:
                if match := self.patterns['timestep'].search(line):
                    self.current_step = int(match.group(1))
                    self.step_start = time.time()
                    self.data['timesteps'][self.current_step] = {
                        'time': float(match.group(2)),
                        'dt': float(match.group(3)),
                        'nonlinear_iters': [],
                        'linear_iters': [],
                        'converged': False,
                        'step_time': 0,
                        'max_memory': 0
                    }
                    self.data['timesteps'][self.current_step]['max_memory'] = 0  # 重置内存记录

            # 内存记录（兼容多种格式）
            if any(x in line for x in ['Finished Solving', 'Computing']):
                if mem_match := self.patterns['memory'].search(line):
                    current_mem = float(mem_match.group(1) or mem_match.group(3))
                    # 确保记录到当前时间步
                    if self.current_step in self.data['timesteps']:
                        self.data['timesteps'][self.current_step]['max_memory'] = max(
                            self.data['timesteps'][self.current_step]['max_memory'],
                            current_mem
                        )
                    # 更新全局最大值
                    self.data['performance']['max_memory'] = max(
                        self.data['performance']['max_memory'],
                        current_mem
                    )

            # 迭代残差记录
            elif 'Nonlinear |R|' in line:
                if match := self.patterns['nonlinear'].search(line):
                    self.data['timesteps'][self.current_step]['nonlinear_iters'].append(
                        float(match.group(1))
                    )
            elif 'Linear |R|' in line:
                if match := self.patterns['linear'].search(line):
                    self.data['timesteps'][self.current_step]['linear_iters'].append(
                        float(match.group(1))
                    )

            # 收敛状态
            elif 'Solve Converged!' in line:
                self.data['timesteps'][self.current_step]['converged'] = True
                self.data['timesteps'][self.current_step]['step_time'] = time.time() - self.step_start
                self.data['summary']['time_per_step'].append(
                    self.data['timesteps'][self.current_step]['step_time']
                )

        except Exception as e:
            print(f"解析错误: {str(e)}")

    def run_simulation(self):
        """运行仿真并采集数据"""
        cmd = f'mpiexec -n 4 ../../fuel_rods-opt -i {self.input_file} --timing --track_memory'
        process = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        try:
            while True:
                line = process.stdout.readline()
                if not line and process.poll() is not None:
                    break
                if line:
                    print(line.strip())
                    self._parse_line(line)
        finally:
            self.data['summary']['total_time'] = sum(
                ts['step_time'] for ts in self.data['timesteps'].values()
            )

    def generate_report(self, filename='simulation_report.txt'):
        """生成对齐格式的文本报告"""
        with open(filename, 'w', encoding='utf-8') as f:
            # 报告头
            f.write("="*80 + "\n")
            f.write(f"MOOSE仿真分析报告（{time.strftime('%Y-%m-%d %H:%M')}）\n")
            f.write("="*80 + "\n\n")

            # 基础信息表格
            f.write("[基础信息]\n")
            f.write(f"输入文件: {self.input_file}\n")
            f.write(f"总计算时间: {self.data['summary']['total_time']:.2f} 秒\n")
            f.write(f"最大内存使用: {self.data['performance']['max_memory']:.1f} MB\n")
            f.write(f"网格规模: 节点数={self.data['mesh']['nodes']}  单元数={self.data['mesh']['elements']}\n\n")

            # 时间步详细表格
            f.write("[时间步性能]\n")
            header = ("{:<6} {:<12} {:<12} {:<10} {:<10} {:<14} {:<16} {:<10}"
                     ).format(
                         "步数", "物理时间", "时间步长", "非线性迭代", "线性迭代", 
                         "耗时(s)", "最大内存(MB)", "收敛状态"
                     )
            f.write(header + "\n")
            f.write("-"*95 + "\n")

            for step in sorted(self.data['timesteps']):
                ts = self.data['timesteps'][step]
                row = ("{:<6} {:<12.1f} {:<12.1f} {:<10} {:<10} {:<14.2f} {:<16.1f} {:<10}"
                      ).format(
                          step,
                          ts['time'],
                          ts['dt'],
                          len(ts['nonlinear_iters']),
                          len(ts['linear_iters']),
                          ts['step_time'],
                          ts['max_memory'] if ts['max_memory'] > 0 else self.data['performance']['max_memory'],
                          '是' if ts['converged'] else '否'
                      )
                f.write(row + "\n")

            # 性能统计
            f.write("\n[性能统计]\n")
            time_steps = self.data['summary']['time_per_step']
            if time_steps:
                f.write(f"总时间步数: {len(time_steps)}\n")
                f.write(f"平均步耗时: {np.mean(time_steps):.2f} ± {np.std(time_steps):.2f} 秒\n")
                f.write(f"最长单步耗时: {np.max(time_steps):.2f} 秒\n")
                f.write(f"最短单步耗时: {np.min(time_steps):.2f} 秒\n")
            
            if self.data['performance']['memory_history']:
                mem_values = [m[1] for m in self.data['performance']['memory_history']]
                f.write(f"内存波动范围: {np.ptp(mem_values):.1f} MB\n")
                f.write(f"平均内存使用: {np.mean(mem_values):.1f} MB\n")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("使用方法: python simulation_final.py <输入文件>")
        sys.exit(1)

    analyzer = MooseAnalyzer(sys.argv[1])
    try:
        analyzer.run_simulation()
    except Exception as e:
        print(f"运行错误: {str(e)}")
    finally:
        analyzer.generate_report()
    
    print(f"\n报告已生成: simulation_report.txt")