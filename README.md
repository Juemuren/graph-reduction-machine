# 图归约机

实现一个可运行 λ 演算的图归约机。

## 文档

- 架构文档为 [architecture.md](docs/architecture.md)
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

默认进行完整编译。可以指定完成后停止的阶段。

- 用 `--desugar` 在脱糖后停止

    ```sh
    cabal exec -- lambda-to-graph --desugar example.lambda
    ```

- 用 `--expand` 在展开后停止

    ```sh
    cabal exec -- lambda-to-graph --expand example.lambda
    ```

编译的完整步骤请参考 [syntax.md#表达式编译](docs/syntax.md#表达式编译)。

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

- 用 `--decode-integer` 尝试解码并输出十进制整数

    ```sh
    cabal exec -- ski-interpreter --decode-integer example.ski
    ```

若无法识别为指定类型，则解码失败，解释器报错。

解码过程也受 `--max-steps` 限制。

解码选项不能同时使用。

解码的详细操作请参考 [syntax.md#丘奇解码](docs/syntax.md#丘奇解码)。
