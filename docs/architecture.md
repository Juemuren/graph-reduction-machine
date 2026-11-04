# 架构

整个图归约机分为两部分：

1. 编译器，负责把 λ 表达式编译成 SKI 组合子图，运行在 PC 上。
2. 处理器，负责执行 SKI 图归约，运行在 FPGA 上。

## 编译器

使用 Haskell 编写 λ 表达式编译器。

编译的完整步骤见 [syntax.md#表达式编译](syntax.md#表达式编译)。

编译器目录结构为：

- 命令行入口位于 `app/CompilerMain.hs`
- 编译器实现位于 `src/Compiler.hs` 和 `src/Compiler/`
- 自动生成的语法模块位于 `src/CoreLambda/` / `src/PureLambda/` / `src/Graph/`

编译器的模块为：

- `Compiler` 是编译和规约的入口
- `Compiler.Expand` 解析模块、展开定义及内置函数
- `Compiler.ModuleSource` 解析和校验模块结构；`Compiler.ModuleLoader` 加载导入的源码文件。
- `Compiler.LibrarySource` 在构建时嵌入标准库源码

## 软件解释器

使用 Haskell 编写 SKI 图归约解释器。

规约的完整步骤见 [syntax.md#图规约](syntax.md#图规约)。

软件解释器用于开发、测试和验证，并作为硬件处理器的参考实现。

## 硬件处理器

使用的 FPGA 为 iCESugar。

先由 Clash 把 Haskell 编译到 Verilog，再对 iCESugar 进行综合、布局布线、烧写。

Clash 部分可以复用 Haskell 软件解释器的相同逻辑，iCESugar 部分需要参考硬件说明。

相关链接：

- Clash：<https://github.com/clash-lang/clash-compiler>
- iCESugar：<https://github.com/wuxx/icesugar>
