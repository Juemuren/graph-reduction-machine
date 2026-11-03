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

- `test/cases/compiler/precedence` 比较输入与补全括号后的语法树，测试运算优先级
- `test/cases/compiler/desugar` 比较带糖的 λ 表达式与脱糖的 λ 表达式
- `test/cases/compiler/encode` 比较带内置函数的 λ 表达式与展开得到的纯 λ 表达式
- `test/cases/compiler/compile` 比较纯 λ 表达式与编译得到的 SKI 图
- `test/cases/compiler/errors` 比较错误信息

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

从带糖 λ 演算到规约后 SKI 图的集成测试

```sh
cabal test integration-tests
```

测试用例使用静态文件对：

- `test/cases/integration/undecode` 比较带糖的 λ 表达式经过脱糖、展开、编译、规约后得到的 SKI 图
- `test/cases/integration/decode-natural` 比较带糖的 λ 表达式经过脱糖、展开、编译、规约、解码后得到的十进制自然数
- `test/cases/integration/decode-boolean` 比较带糖的 λ 表达式经过脱糖、展开、编译、规约、解码后得到的布尔值
- `test/cases/integration/decode-integer` 比较带糖的 λ 表达式经过脱糖、展开、编译、规约、解码后得到的十进制整数
