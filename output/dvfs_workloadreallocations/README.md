# SOS1 约束可视化

这个项目包含了用于可视化解释 SOS1 (Special Ordered Set of type 1) 约束原理的 Python 脚本。

## 什么是 SOS1 约束？

SOS1 约束是混合整数规划中的一个重要概念：

- **定义**：在一组有序变量 {x₁, x₂, ..., xₙ} 中，最多只有一个变量可以取非零值
- **规则**：如果某个变量 xⱼ 非零，则：
  - 所有 xᵢ = 0 (i > j，后面的变量必须为0)
  - 所有 xᵢ = 上界ᵢ (i < j，前面的变量取上界，如果定义了上界)

## 文件说明

- `sos1_visualization.py` - 主脚本，生成可视化图片
- `sos1_scenarios.png` - 场景示例图（4个场景对比）
- `sos1_explanation.png` - 详细解释图（定义、示例、应用场景）
- `requirements.txt` - 依赖包列表

## 使用方法

### 1. 安装依赖

```bash
# 创建虚拟环境（推荐）
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

### 2. 运行脚本

```bash
python3 sos1_visualization.py
```

脚本会生成两个 PNG 图片文件：
- `sos1_scenarios.png` - 展示不同场景的对比
- `sos1_explanation.png` - 详细的理论解释

## 可视化内容

### sos1_scenarios.png 包含：

1. **场景1**：所有变量都为0（允许）
2. **场景2**：x₃ 取非零值（符合SOS1约束）
3. **场景3**：x₁ 和 x₂ 都非零（违反SOS1约束）
4. **场景4**：SOS1约束的几何解释（2D示例）

### sos1_explanation.png 包含：

- SOS1 约束的定义和数学表达
- 允许和不允许的示例
- 应用场景（分段线性函数、选择问题等）
- 与其他约束类型的区别
- 可视化规则说明

## SOS1 约束的核心要点

1. ✅ **最多只有一个变量可以取非零值**
2. ✅ **允许所有变量都为0**
3. ✅ **如果某个变量非零，前面的变量应取上界，后面的变量必须为0**
4. ❌ **不允许两个或更多变量同时非零**

## 应用场景

- 分段线性函数的建模
- 选择问题（从多个选项中选择一个）
- 网络流问题中的路径选择
- 资源分配问题

## 依赖

- Python 3.6+
- matplotlib >= 3.5.0
- numpy >= 1.21.0


