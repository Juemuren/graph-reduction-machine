# 图归约机

实现一个可运行 λ 演算的图归约机。

## 架构

整个图归约机分为两部分：

1. 编译器，负责把 λ 表达式编译成 SKI 组合子图，运行在 PC 上。
2. 处理器，负责执行 SKI 图归约，运行在 FPGA 上。

### 编译器

使用 Haskell 编写编译器，先把算术语法糖展开为纯 λ 表达式，再编译成 SKI 组合子图。

### 软件解释器

使用 Haskell 编写 SKI 图归约解释器，用于开发、测试和验证，并作为硬件处理器的参考实现。

### 硬件处理器

使用的 FPGA 为 [iCESugar](https://github.com/wuxx/icesugar)。

可以复用 Haskell 软件解释器的部分逻辑，用 [Clash](https://github.com/clash-lang/clash-compiler) 编写硬件实现，并编译到 Verilog。

最后根据 iCESugar 的说明 <https://github.com/wuxx/icesugar> 进行综合、布局布线、烧写。

## 文档

- 语法文档为 [syntax.md](docs/syntax.md)
- 构建文档为 [build.md](docs/build.md)
- 测试文档为 [test.md](docs/test.md)

## 使用

### 编译 λ 表达式

把 λ 表达式编译为 SKI 图

```sh
cabal exec -- lambda-to-graph example.lambda
```

不提供文件名时从标准输入读取，结果写到标准输出。
