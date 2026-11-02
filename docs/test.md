# 测试

## 测试编译器

测试所有编译器用例

```sh
cabal test compiler-tests
```

测试用例使用静态文件对：

- `test/cases/syntax` 比较输入与补全括号后的语法树
- `test/cases/desugar` 比较带糖的 λ 表达式与展开后的纯 λ 表达式
- `test/cases/compile` 比较纯 λ 表达式与编译得到的 SKI 图
- `test/cases/integration` 比较带糖的 λ 表达式与展开并编译得到的 SKI 图
- `test/cases/errors` 比较错误信息

## 测试解释器

测试所有解释器用例

```sh
cabal test interpreter-tests
```

测试用例使用静态文件对：

- `test/cases/interpreter/reduce` 比较 SKI 图与归约后的 SKI 图
- `test/cases/interpreter/errors` 比较错误信息
- `test/cases/interpreter/step-limit` 比较归约步数超限时的错误信息
