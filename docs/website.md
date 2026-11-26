# 网站

## 当前状态

见 [site/README.md](../site/README.md)。

## 完整计划

| 阶段                                 | 状态   | 内容                                   |
| ------------------------------------ | ------ | -------------------------------------- |
| 第一版：Examples + Documents + Codes | 已实现 | 在网页中展示文档、源码、图表和数据     |
| 第二版：Playground                   | 已实现 | 在网页编辑和运行核心 λ 和 SKI 图       |
| 第三版：LSP                          | 已实现 | 在网页中使用核心 λ 和 SKI 图的语言服务 |
| 第四版：Benchmark                    | 暂缓   | 在网页中运行比较和绘图                 |

## 第一版：Examples + Documents + Codes（已实现）

见 [README.md#内容](../site/README.md#内容)。

## 第二版：Playground（已实现）

见 [README.md#演练](../site/README.md#演练)。

## 第三版：LSP（已实现）

见 [README.md#演练](../site/README.md#演练)。

## 第四版：Benchmark（暂缓）

### 第四版暂缓原因

- 现有的 Python 比较脚本不能直接放到静态网站运行，需要用 TypeScript 或 JavaScript 重写
- 现有的比较图表和数据第一版已经实现了展示，因此在线 Benchmark 的重要性偏低

### 第四版预计路线

把现有的 Python 比较脚本的主要功能用 TypeScript 重写：

- 读取并解析 JSON 配置：Web 侧要使用相同的 JSON Schema
- 生成入口表达式、逐点测量、检查同一输入的结果是否一致：Web 侧按原有语义重新实现
- 子进程调用、磁盘读写、Matplotlib 绘图：Web 侧要改用 Playground 的运行接口、浏览器下载、JavaScript 绘图库
