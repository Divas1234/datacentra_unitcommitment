import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

# 设置中文字体 - 尝试使用系统可用的中文字体
import matplotlib
matplotlib.rcParams['font.sans-serif'] = ['Arial Unicode MS', 'PingFang SC', 'STHeiti', 'SimHei', 'DejaVu Sans']
matplotlib.rcParams['axes.unicode_minus'] = False
# 禁用字体警告
import warnings
warnings.filterwarnings('ignore', category=UserWarning, module='matplotlib')

def visualize_sos1_constraint():
    """
    可视化 SOS1 约束的原理
    SOS1: 在一组有序变量中，最多只有一个变量可以取非零值
    """
    
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('SOS1 约束原理可视化', fontsize=16, fontweight='bold')
    
    # 定义变量组
    variables = ['x₁', 'x₂', 'x₃', 'x₄', 'x₅']
    n = len(variables)
    
    # 场景1: 所有变量都为0
    ax1 = axes[0, 0]
    values1 = [0, 0, 0, 0, 0]
    colors1 = ['lightgray'] * n
    bars1 = ax1.bar(variables, values1, color=colors1, edgecolor='black', linewidth=1.5)
    ax1.set_ylim(0, 10)
    ax1.set_title('场景1: 所有变量都为0 (允许)', fontsize=12, fontweight='bold')
    ax1.set_ylabel('变量值', fontsize=10)
    ax1.grid(axis='y', alpha=0.3)
    ax1.text(0.5, 0.95, '✓ 符合SOS1约束', transform=ax1.transAxes, 
             ha='center', va='top', fontsize=10, color='green', fontweight='bold')
    
    # 场景2: x₃ 取非零值（符合SOS1）
    ax2 = axes[0, 1]
    values2 = [5, 5, 7, 0, 0]  # x₁和x₂取上界，x₃非零，x₄和x₅为0
    colors2 = ['orange', 'orange', 'red', 'lightgray', 'lightgray']
    bars2 = ax2.bar(variables, values2, color=colors2, edgecolor='black', linewidth=1.5)
    ax2.set_ylim(0, 10)
    ax2.set_title('场景2: x₃ 取非零值 (符合SOS1)', fontsize=12, fontweight='bold')
    ax2.set_ylabel('变量值', fontsize=10)
    ax2.grid(axis='y', alpha=0.3)
    ax2.text(0.5, 0.95, '✓ 符合SOS1约束', transform=ax2.transAxes, 
             ha='center', va='top', fontsize=10, color='green', fontweight='bold')
    # 添加标注
    ax2.annotate('x₁, x₂ 取上界', xy=(1, 5), xytext=(1.5, 8),
                arrowprops=dict(arrowstyle='->', color='blue', lw=1.5),
                fontsize=9, color='blue')
    ax2.annotate('x₃ 非零', xy=(2, 7), xytext=(2.5, 9),
                arrowprops=dict(arrowstyle='->', color='red', lw=2),
                fontsize=9, color='red', fontweight='bold')
    ax2.annotate('x₄, x₅ 为0', xy=(3, 0), xytext=(3.5, 3),
                arrowprops=dict(arrowstyle='->', color='gray', lw=1.5),
                fontsize=9, color='gray')
    
    # 场景3: 两个变量都非零（违反SOS1）
    ax3 = axes[1, 0]
    values3 = [3, 4, 0, 0, 0]
    colors3 = ['red', 'red', 'lightgray', 'lightgray', 'lightgray']
    bars3 = ax3.bar(variables, values3, color=colors3, edgecolor='black', linewidth=1.5)
    ax3.set_ylim(0, 10)
    ax3.set_title('场景3: x₁ 和 x₂ 都非零 (违反SOS1)', fontsize=12, fontweight='bold')
    ax3.set_ylabel('变量值', fontsize=10)
    ax3.grid(axis='y', alpha=0.3)
    ax3.text(0.5, 0.95, '✗ 违反SOS1约束', transform=ax3.transAxes, 
             ha='center', va='top', fontsize=10, color='red', fontweight='bold')
    ax3.text(0.5, 0.85, '最多只能有一个非零', transform=ax3.transAxes, 
             ha='center', va='top', fontsize=9, color='red', style='italic')
    
    # 场景4: SOS1约束的几何解释
    ax4 = axes[1, 1]
    # 绘制允许的区域（最多一个非零）
    x = np.linspace(0, 10, 100)
    
    # 绘制允许区域：x₁=0 或 x₂=0
    # 这里用一个简化的2D示例
    x1 = np.linspace(0, 10, 100)
    x2 = np.linspace(0, 10, 100)
    
    # 绘制边界线
    ax4.plot([0, 10], [0, 0], 'g-', linewidth=2, label='x₂ = 0 (允许)')
    ax4.plot([0, 0], [0, 10], 'g-', linewidth=2, label='x₁ = 0 (允许)')
    ax4.plot([0, 10], [10, 0], 'r--', linewidth=2, alpha=0.5, label='x₁ + x₂ = 10')
    
    # 填充允许区域（坐标轴）
    ax4.fill_between([0, 10], [0, 0], alpha=0.2, color='green', label='允许区域')
    ax4.fill_betweenx([0, 10], [0, 0], alpha=0.2, color='green')
    
    # 标记允许的点
    ax4.scatter([0, 5, 10], [0, 0, 0], color='green', s=100, zorder=5, marker='o', label='允许的点')
    ax4.scatter([0, 0, 0], [0, 5, 10], color='green', s=100, zorder=5, marker='o')
    
    # 标记不允许的点
    ax4.scatter([3, 5, 7], [4, 3, 2], color='red', s=100, zorder=5, marker='X', label='不允许的点')
    
    ax4.set_xlabel('x₁', fontsize=11)
    ax4.set_ylabel('x₂', fontsize=11)
    ax4.set_title('SOS1 约束的几何解释 (2D示例)', fontsize=12, fontweight='bold')
    ax4.set_xlim(-0.5, 10.5)
    ax4.set_ylim(-0.5, 10.5)
    ax4.grid(True, alpha=0.3)
    ax4.legend(fontsize=8, loc='upper right')
    
    plt.tight_layout()
    return fig

def create_sos1_explanation_diagram():
    """创建 SOS1 约束的详细解释图"""
    fig, ax = plt.subplots(1, 1, figsize=(12, 8))
    
    # 创建流程图风格的说明
    ax.axis('off')
    
    # 标题
    ax.text(0.5, 0.95, 'SOS1 约束详解', transform=ax.transAxes,
            ha='center', fontsize=18, fontweight='bold')
    
    # 定义
    definition_text = """
定义：Special Ordered Set of type 1 (SOS1)

在一组有序变量 {x₁, x₂, ..., xₙ} 中，最多只有一个变量可以取非零值。

数学表达：
    • 最多只有一个 xᵢ ≠ 0 (i = 1, 2, ..., n)
    • 如果 xⱼ ≠ 0，则：
      - 所有 xᵢ = 0 (i > j)
      - 所有 xᵢ = 上界ᵢ (i < j，如果定义了上界)
    """
    
    ax.text(0.1, 0.8, definition_text, transform=ax.transAxes,
            fontsize=11, verticalalignment='top', family='monospace',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    # 示例
    example_text = """
示例：变量组 {x₁, x₂, x₃, x₄}，上界都是 5

✓ 允许的情况：
  情况1: x₁=0, x₂=0, x₃=0, x₄=0  (全为0)
  情况2: x₁=5, x₂=5, x₃=3, x₄=0  (x₃非零，前面取上界)
  情况3: x₁=0, x₂=4, x₃=0, x₄=0  (x₂非零)

✗ 不允许的情况：
  情况1: x₁=2, x₂=3, x₃=0, x₄=0  (两个非零)
  情况2: x₁=1, x₂=0, x₃=2, x₄=0  (两个非零)
    """
    
    ax.text(0.55, 0.8, example_text, transform=ax.transAxes,
            fontsize=11, verticalalignment='top', family='monospace',
            bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.5))
    
    # 应用场景
    application_text = """
应用场景：
• 分段线性函数：选择激活哪个分段
• 选择问题：从多个选项中选择一个
• 网络流问题：选择路径
• 资源分配：选择分配方案
    """
    
    ax.text(0.1, 0.4, application_text, transform=ax.transAxes,
            fontsize=11, verticalalignment='top', family='monospace',
            bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.5))
    
    # 与其他约束的区别
    comparison_text = """
与其他约束的区别：

SOS1 vs 二进制变量：
• SOS1: 连续变量，但最多一个非零
• 二进制: 离散变量 (0或1)

SOS1 vs 互斥约束：
• SOS1: 允许全为0
• 互斥: 必须恰好一个非零
    """
    
    ax.text(0.55, 0.4, comparison_text, transform=ax.transAxes,
            fontsize=11, verticalalignment='top', family='monospace',
            bbox=dict(boxstyle='round', facecolor='lightcoral', alpha=0.5))
    
    # 可视化规则
    rule_text = """
可视化规则（以 x₃ 非零为例）：
        
    x₁  x₂  x₃  x₄  x₅
    ──  ──  ──  ──  ──
    5   5   3   0   0
    ↑   ↑   ↑   ↑   ↑
    │   │   │   │   └─ 后面的变量必须为0
    │   │   │   └───── 后面的变量必须为0
    │   │   └───────── 这个变量可以非零
    │   └───────────── 前面的变量取上界
    └───────────────── 前面的变量取上界
    """
    
    ax.text(0.1, 0.05, rule_text, transform=ax.transAxes,
            fontsize=10, verticalalignment='top', family='monospace',
            bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.5))
    
    plt.tight_layout()
    return fig

# 创建可视化
if __name__ == "__main__":
    # 创建第一个图：场景示例
    fig1 = visualize_sos1_constraint()
    fig1.savefig('sos1_scenarios.png', dpi=300, bbox_inches='tight')
    print("已保存: sos1_scenarios.png")
    
    # 创建第二个图：详细解释
    fig2 = create_sos1_explanation_diagram()
    fig2.savefig('sos1_explanation.png', dpi=300, bbox_inches='tight')
    print("已保存: sos1_explanation.png")
    
    plt.show()

