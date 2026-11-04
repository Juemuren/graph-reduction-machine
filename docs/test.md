# 测试

项目使用 Cabal 进行测试。

测试所有用例

```sh
cabal test
```

所有测试用例使用静态文件对，放置在 `test/cases` 目录下。

## 测试编译器

测试所有编译器用例

```sh
cabal test compiler-tests
```

测试用例使用静态文件对：

- `test/cases/compiler/precedence` 比较核心 λ 输入与补全括号后的语法树
- `test/cases/compiler/encode` 比较带内置函数的核心 λ 与展开得到的纯 λ
- `test/cases/compiler/reduce` 比较纯 λ 表达式与 β 和 η 规约后得到的纯 λ 表达式
- `test/cases/compiler/reduce-no-beta` 比较禁用 β 规约后输出的纯 λ 表达式
- `test/cases/compiler/reduce-no-eta` 比较禁用 η 规约后输出的纯 λ 表达式
- `test/cases/compiler/reduce-no-reduce` 比较禁用所有规约后输出的纯 λ 表达式
- `test/cases/compiler/compile` 比较纯 λ 表达式与启用 β 和 η 规约时编译得到的 SKI 图
- `test/cases/compiler/compile-no-beta` 比较纯 λ 表达式与禁用 β 规约时编译得到的 SKI 图
- `test/cases/compiler/compile-no-eta` 比较纯 λ 表达式与禁用 η 规约时编译得到的 SKI 图
- `test/cases/compiler/compile-no-reduce` 比较纯 λ 表达式与禁用所有规约时编译得到的 SKI 图
- `test/cases/compiler/errors` 比较错误信息

基础测试：

- 对于一个新增的内置函数，在 `test/cases/compiler/encode` 中增加一个编码测试。测试文件名使用内置函数名的小写

核心 λ 的应用与抽象优先级在 `test/cases/compiler/precedence` 中覆盖。

核心 λ 不含语法糖。加入 JavaScript 前端后，在前端测试中覆盖脱糖规则。

## 测试解释器

测试所有解释器用例

```sh
cabal test interpreter-tests
```

测试用例使用静态文件对：

- `test/cases/interpreter/reduce` 比较 SKI 图与归约后的 SKI 图
- `test/cases/interpreter/errors` 比较错误信息
- `test/cases/interpreter/limit-errors` 比较归约步数超限时的错误信息和退出码
- `test/cases/interpreter/decode-limit-errors` 比较解码步数超限时的错误信息和退出码
- `test/cases/interpreter/decode-natural-errors` 比较非自然数编码解码时的错误信息和退出码
- `test/cases/interpreter/decode-boolean-errors` 比较非布尔值解码时的错误信息和退出码
- `test/cases/interpreter/decode-integer-errors` 比较非整数编码解码时的错误信息和退出码

## 集成测试

从核心 λ 到规约后 SKI 图的集成测试

```sh
cabal test integration-tests
```

测试用例使用静态文件对：

- `test/cases/integration/undecode` 比较核心 λ 经过展开、编译、规约后得到的 SKI 图
- `test/cases/integration/decode-natural` 比较核心 λ 经过展开、编译、规约、解码后得到的十进制自然数
- `test/cases/integration/decode-boolean` 比较核心 λ 经过展开、编译、规约、解码后得到的布尔值
- `test/cases/integration/decode-integer` 比较核心 λ 经过展开、编译、规约、解码后得到的整数

基础测试：

- 对于一个新增的数据类型，在 `test/cases/integration/decode-*` 中增加一个解码测试。如果数据类型中有无穷多的值，则只测试典型值的解码。测试文件名使用内置函数名的小写；数字使用英文小写
- 对于一个新增的运算，在 `test/cases/integration/decode-*` 中增加一个解码测试，测试文件名使用内置函数名的小写
