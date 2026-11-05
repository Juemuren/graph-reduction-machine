# 架构

项目包含四个主要模块：

1. 解析器，负责核心 λ、纯 λ、SKI 图的解析。
2. 语言服务器，负责提供核心 λ 和 SKI 图的语言服务。
3. 编译器，负责把核心 λ 编译成 SKI 图。
4. 解释器，负责解释 SKI 图。

## 解析器

使用 BNFC 定义语法并自动生成 Haskell 源代码。

生成的源码不手工修改，也不提交仓库。

各语法文件及其对应的解析器源码目录分别为：

- `grammar/CoreLambda.cf`：`src/CoreLambda`
- `grammar/PureLambda.cf`：`src/PureLambda`
- `grammar/Ski.cf`：`src/Ski`

## 语言服务器

使用 Haskell 编写语言服务器。

语言服务的完整功能见 [lsp.md#功能](lsp.md#功能)。

语言服务器的目录结构为：

- 命令行入口位于 `app/LanguageServerMain.hs`
- 模块入口位于 `src/LanguageServer.hs`
- 各模块位于 `src/LanguageServer/`

语言服务器的模块拆分为：

- `LanguageServer`：配置并启动 `lsp` 服务，注册核心 λ 与 SKI 图的请求处理函数，获取文档内容，并协调导入文件的读取
- `LanguageServer.Lambda`：核心 λ 的词法与语法分析、名称解析、补全、悬停和导入导出信息
- `LanguageServer.Ski`：SKI 图的词法与语法分析、节点补全和悬停

## 编译器

使用 Haskell 编写核心 λ 编译器。

编译的完整步骤见 [syntax.md#表达式编译](syntax.md#表达式编译)。

编译器的目录结构为：

- 命令行入口位于 `app/CompilerMain.hs`
- 模块入口位于 `src/Compiler.hs`
- 各模块位于 `src/Compiler/`

编译器的模块拆分为：

- `Compiler` 是编译和规约的入口
- `Compiler.Expand` 解析模块、展开定义及内置函数
- `Compiler.ModuleSource` 解析和校验模块结构
- `Compiler.ModuleLoader` 加载导入的源码文件
- `Compiler.LibrarySource` 在构建时嵌入标准库源码

## 解释器

使用 Haskell 编写 SKI 图解释器。

解释器会进行规约和解码：

- 规约的完整步骤见 [syntax.md#图规约](syntax.md#图规约)
- 解码的完整步骤见 [syntax.md#丘奇解码](syntax.md#丘奇解码)

解释器的目录结构为：

- 命令行入口位于 `app/InterpreterMain.hs`
- 模块入口位于 `src/Interpreter.hs`
- 各模块位于 `src/Interpreter/`

解释器的模块拆分为：

- `Interpreter` 是图规约和丘奇值解码的对外入口
- `Interpreter.Machine` 加载 SKI 图、维护共享堆并执行图规约
- `Interpreter.Church` 使用符号探针解码丘奇布尔值、自然数、整数、有理数和实数

<!--TODO ## 处理器

使用的 FPGA 为 iCESugar。

处理器暂未实现。

实现计划为：

1. 由 Clash 把 Haskell 编译到 Verilog。可以复用解释器的部分逻辑。Clash 的说明 <https://github.com/clash-lang/clash-compiler>
2. 对 iCESugar 进行综合、布局布线、烧写。需要参考 iCESugar 的说明 <https://github.com/wuxx/icesugar>

-->
