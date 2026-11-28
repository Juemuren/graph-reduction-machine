# 图归约机

实现一个可运行 λ 演算的图归约机。

## 使用

### 编译 λ 表达式

把 `.lambda` 文件中的 λ 表达式编译为 SKI 图

```sh
cabal exec -- lambda-compiler example.lambda
```

编译器的所有选项请参考 [compiler.md#编译器选项](docs/compiler.md#编译器选项)。

### 运行 SKI 图

将 `.ski` 文件中的 SKI 图归约为完整范式，结果仍是可解析的 `.ski` 图

```sh
cabal exec -- ski-interpreter example.ski
```

解释器的所有选项请参考 [interpreter.md#解释器选项](docs/interpreter.md#解释器选项)。

## 示例

见 <https://juemuren.github.io/graph-reduction-machine/examples/>。

## 文档

- 架构文档为 [architecture.md](docs/architecture.md)
- 语法文档为 [syntax.md](docs/syntax.md)
- 构建文档为 [build.md](docs/build.md)
- 测试文档为 [test.md](docs/test.md)
- 代码质量文档为 [quality.md](docs/quality.md)
- VSCode 扩展文档为 [vscode-extension/README.md](vscode-extension/README.md)
- Web 站点文档为 [site/README.md](site/README.md)
