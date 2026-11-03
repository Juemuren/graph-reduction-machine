# 图归约机

实现一个可运行 λ 演算的图归约机。

## 架构

整个图归约机分为两部分：

1. 编译器，负责把 λ 表达式编译成 SKI 组合子图，运行在 PC 上。
2. 处理器，负责执行 SKI 图归约，运行在 FPGA 上。

### 编译器

使用 Haskell 编写 λ 表达式编译器。

编译器先把带算术语法糖的 λ表达式展开为纯 λ 表达式，再编译成 SKI 组合子图。

### 软件解释器

使用 Haskell 编写 SKI 图归约解释器。

软件解释器用于开发、测试和验证，并作为硬件处理器的参考实现。

### 硬件处理器

使用的 FPGA 为 iCESugar。

先由 Clash 把 Haskell 编译到 Verilog，再对 iCESugar 进行综合、布局布线、烧写。

Clash 部分可以复用 Haskell 软件解释器的相同逻辑，iCESugar 部分需要参考硬件说明。

相关链接：

- Clash：<https://github.com/clash-lang/clash-compiler>
- iCESugar：<https://github.com/wuxx/icesugar>

## 文档

- 语法文档为 [syntax.md](docs/syntax.md)
- 构建文档为 [build.md](docs/build.md)
- 测试文档为 [test.md](docs/test.md)
- 代码质量文档为 [quality.md](docs/quality.md)

## 使用

### 编译 λ 表达式

把 `.lambda` 文件中的 λ 表达式编译为 SKI 图

```sh
cabal exec -- lambda-to-graph example.lambda
```

不提供文件名时从标准输入读取。成功时结果写到标准输出；错误信息写到标准错误。

### 运行 SKI 图

将 `.ski` 文件中的 SKI 图归约为完整范式，结果仍是可解析的 `.ski` 图

```sh
cabal exec -- ski-interpreter example.ski
```

不提供文件名时从标准输入读取。成功时结果写到标准输出；错误信息写到标准错误。

默认最多进行 100000 次归约。规约次数超过限制会报错。可用 `--max-steps N` 调整规约限制

```sh
cabal exec -- ski-interpreter --max-steps 1000000 example.ski
```

默认不对输出的 SKI 图进行解码。解码需要显式开启。

- 用 `--decode-natural` 尝试解码并输出十进制自然数

    ```sh
    cabal exec -- ski-interpreter --decode-natural example.ski
    ```

- 用 `--decode-boolean` 尝试解码并输出 `TRUE` 或 `FALSE`

    ```sh
    cabal exec -- ski-interpreter --decode-boolean example.ski
    ```

若无法识别为指定类型，则解码失败，解释器报错。

解码过程也受 `--max-steps` 限制。

解码选项不能同时使用。具体原因请参考 [syntax.md#丘奇解码](docs/syntax.md#丘奇解码)。
