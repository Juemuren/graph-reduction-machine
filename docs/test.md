# 测试

## 测试编译器

测试所有编译器用例

```sh
cabal test compiler-tests
```

测试用例使用静态文件对：

- `test/cases/syntax` 比较输入与补全括号后的语法树
- `test/cases/desugar` 比较带糖表达式与纯 λ 表达式
- `test/cases/valid` 比较最终 SKI 图
- `test/cases/errors` 比较错误信息。
