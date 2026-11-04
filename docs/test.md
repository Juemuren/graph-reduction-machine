# 测试

项目使用 Cabal 进行测试。

测试所有用例

```sh
cabal test
```

所有测试用例使用静态文件对，放置在 `test/cases` 目录下。

基础测试是新增特性时需要同步实现的测试。

## 测试编译器

测试所有编译器用例

```sh
cabal test compiler-tests
```

编译器测试用例放在 `test/cases/compiler` 下。

测试用例使用静态文件对：

- `precedence` 比较核心 λ 输入与补全括号后的语法树
- `encode` 比较带内置函数的核心 λ 与展开得到的纯 λ
- `reduce` / `reduce-no-beta` / `reduce-no-eta` / `reduce-no-reduce` 分别比较纯 λ 表达式与启用 β 规约和 η 规约、禁用 β 规约、禁用 η 规约、禁用所有规约后规约得到的纯 λ 表达式
- `compile` / `compile-no-beta` / `compile-no-eta` / `compile-no-reduce` 分别比较纯 λ 表达式与启用 β 规约和 η 规约、禁用 β 规约、禁用 η 规约、禁用所有规约后编译得到的 SKI 图
- `errors` 比较编译器错误信息

基础测试：

- 对于一个内置函数，在 `test/cases/compiler/encode` 中用一个用例测试编码。测试文件名使用内置函数名的小写

核心 λ 的应用与抽象优先级在 `test/cases/compiler/precedence` 中覆盖。

核心 λ 不含语法糖。加入 JavaScript 前端后，在前端测试中覆盖脱糖规则。

## 测试解释器

测试所有解释器用例

```sh
cabal test interpreter-tests
```

编译器测试用例放在 `test/cases/interpreter` 下。

测试用例使用静态文件对：

- `reduce` 比较 SKI 图与归约后的 SKI 图
- `errors` 比较解释器错误信息
- `limit-errors` 比较归约步数超限时的错误信息和退出码
- `decode-limit-errors` 比较解码步数超限时的错误信息和退出码
- `decode-natural-errors` 比较非自然数编码解码时的错误信息和退出码
- `decode-boolean-errors` 比较非布尔值解码时的错误信息和退出码
- `decode-integer-errors` 比较非整数编码解码时的错误信息和退出码
- `decode-rational-errors` 比较无效有理数编码解码时的错误信息和退出码

## 集成测试

从核心 λ 到规约后 SKI 图的集成测试

```sh
cabal test integration-tests
```

编译器测试用例放在 `test/cases/integration` 下。

测试用例使用静态文件对：

- `undecode` 比较核心 λ 与经过展开、编译、规约后得到的 SKI 图
- `decode-natural` / `decode-boolean` / `decode-integer` / `decode-rational` 分别比较核心 λ 与经过展开、编译、规约、解码后得到的十进制自然数、布尔值、十进制整数、约分后的有理数
- `operation-natural` /`operation-boolean` / `operation-integer` 分别验证核心 λ 在自然数、布尔值、整数中的运算。结果按对应的类型解码
- `operation-pair` 验证有序对相关运算的结果。结果按自然数解码
- `control-if` 验证条件控制结构的行为。结果按自然数解码
- `control-loop` 验证循环控制结构的行为。结果按自然数解码
- `control-loop-limit` 验证禁用编译期规约后无限循环会超过图归约机的步数限制

基础测试：

- 对于一个数据类型，在 `decode-*` 中用一个或多个用例测试解码。如果数据类型中有无穷多的值，则只测试典型值的解码。测试文件名使用内置函数名的小写；数字使用英文小写
- 对于一个运算，在 `operation-*` 中用一个或多个用例测试结果。只有运算存在不同的边界行为，才使用多个用例。测试文件名使用内置函数名的小写；多用例时使用后缀说明覆盖的边界
- 对于一个控制结构，在 `control-*` 中用一个用例或多个用例测试行为。用最少的用例覆盖不同分支。测试文件名应当说明覆盖的分支
