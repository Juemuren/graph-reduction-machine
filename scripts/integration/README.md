# 集成辅助函数

所有使用示例都是在仓库根目录运行。

## functions.ps1

运行：

```pwsh
. ./scripts/integration/functions.ps1
```

该命令会把脚本中定义的函数提升到当前 PowerShell 会话，包括：

- `Invoke-Compiler`
- `Invoke-Interpreter`
- `Invoke-IntegrationStage`
- `Invoke-IntegrationSequence`

并且脚本为这些函数的参数提供了补全。

### Invoke-Compiler

`Invoke-Compiler` 调用编译器。

各参数为：

- `-File` 文件路径
- `-Source` 源代码内容，也可以通过管道传入
- `--` 后为编译器选项，也可以通过 `-Options` 传入参数数组。具体选项请参考 [compiler.md#编译器选项](../../docs/compiler.md#编译器选项)。其中 `--encode-natural=` 和 `--encode-string=` 参数提供补全

使用示例：

```pwsh
'@! ONE;' | Invoke-Compiler -- --stop-after=reduce --reduce=both
Invoke-Compiler -Source '@! ONE;' -- --encode-natural=scott
Invoke-Compiler -File "examples/e/factorial.lambda"
```

### Invoke-Interpreter

`Invoke-Interpreter` 调用解释器。

各参数为：

- `-File` 文件路径
- `-Source` 源代码内容，也可以通过管道传入
- `--` 后为解释器选项，也可以通过 `-Options` 传入参数数组。具体选项请参考 [interpreter.md#解释器选项](../../docs/interpreter.md#解释器选项)。其中 `--decode=` 参数提供补全

使用示例：

```pwsh
'#0 = I;' | Invoke-Interpreter -- --show-steps --decode=natural
Invoke-Interpreter -Source '#0 = I;'
Invoke-Interpreter -File "examples/ski/church.ski" -- --decode=natural
```

### Invoke-IntegrationStage

`Invoke-IntegrationStage` 调用编译器和解释器至指定的阶段后停止。

使用示例：

```pwsh
'@! ONE;' | Invoke-IntegrationStage -Stage expand
Invoke-IntegrationStage -Source '@! ONE;' -Stage expand
Invoke-IntegrationStage -File "examples/e/factorial.lambda" -Stage decode -Decode real
```

各参数为：

- `-File` 文件路径
- `-Source` 源代码内容，也可以通过管道传入
- `-Stage` 指定的一个阶段。可以为 `expand` / `reduce` / `compile` / `interpret` / `decode`。无默认值
- `-EncodeNatural` 编译器的自然数字面量编码方式，默认为 `church`。详见 [compiler.md#编译器选项](../../docs/compiler.md#编译器选项)
- `-EncodeString` 编译器的字符串字面量编码方式，默认为 `church<binary>`。详见 [compiler.md#编译器选项](../../docs/compiler.md#编译器选项)
- `-Decode` 解释器的解码方式，默认为 `natural`。详见 [interpreter.md#解释器选项](../../docs/interpreter.md#解释器选项)

### Invoke-IntegrationSequence

使用示例：

```pwsh
'@! ONE;' | Invoke-IntegrationSequence -Stages expand,reduce,decode
Invoke-IntegrationSequence -Source '@! ONE;' -Stages compile,decode
Invoke-IntegrationSequence -File "examples/e/factorial.lambda" -Stages decode -Decode real
```

`Invoke-IntegrationSequence` 按 `expand` / `reduce` / `compile` / `interpret` / `decode` 的顺序依次运行选中的阶段。

参数为：

- `-File` 文件路径
- `-Source` 源代码内容，也可以通过管道传入
- `-Stages` 指定的一个或多个阶段，默认为 `decode`。各阶段用 `,` 连接，可选的阶段见 [Invoke-IntegrationStage](#invoke-integrationstage) 中的 `-Stage` 参数
- `-EncodeNatural` / `-EncodeString` / `-Decode` 与 [Invoke-IntegrationStage](#invoke-integrationstage) 中的同名参数一致

## functions.sh

运行：

```sh
source ./scripts/integration/functions.sh
```

该命令会把脚本中定义的函数加载到当前 Bash 会话，包括：

- `invoke_compiler`
- `invoke_interpreter`
- `invoke_integration_stage`
- `invoke_integration_sequence`

并且脚本为这些函数的参数提供了补全。

### invoke_compiler

`invoke_compiler` 调用编译器。

各参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容，也可以通过管道传入
- `--` 后为编译器选项。具体选项请参考 [compiler.md#编译器选项](../../docs/compiler.md#编译器选项)。其中 `--encode-natural=` 和 `--encode-string=` 参数提供补全

使用示例：

```sh
echo '@! ONE;' | invoke_compiler -- --stop-after=reduce --reduce=both
invoke_compiler -s '@! ONE;'
invoke_compiler -f examples/e/factorial.lambda
```

### invoke_interpreter

`invoke_interpreter` 调用解释器。

各参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容，也可以通过管道传入
- `--` 后为解释器选项。具体选项请参考 [interpreter.md#解释器选项](../../docs/interpreter.md#解释器选项)。其中 `--decode=` 参数提供补全

使用示例：

```sh
printf '%s\n' '#0 = I;' | invoke_interpreter -- --show-steps --decode=natural
invoke_interpreter -s '#0 = I;'
invoke_interpreter -f examples/ski/church.ski -- --decode=natural
```

### invoke_integration_stage

`invoke_integration_stage` 调用编译器和解释器至指定的阶段后停止。

使用示例：

```sh
printf '%s\n' '@! ONE;' | invoke_integration_stage -t expand
invoke_integration_stage -s '@! ONE;' -t expand
invoke_integration_stage -f examples/e/factorial.lambda -t decode -d real
```

各参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容，也可以通过管道传入
- `-t` / `--stage` 指定的一个阶段。可以为 `expand` / `reduce` / `compile` / `interpret` / `decode`。无默认值
- `-en` / `--encode-natural` 编译器的自然数字面量编码方式，默认为 `church`。详见 [compiler.md#编译器选项](../../docs/compiler.md#编译器选项)
- `-es` / `--encode-string` 编译器的字符串字面量编码方式，默认为 `church<binary>`。详见 [compiler.md#编译器选项](../../docs/compiler.md#编译器选项)
- `-d` / `--decode` 解释器的解码方式，默认为 `natural`。详见 [interpreter.md#解释器选项](../../docs/interpreter.md#解释器选项)

### invoke_integration_sequence

使用示例：

```sh
printf '%s\n' '@! ONE;' | invoke_integration_sequence -t expand,reduce,decode
invoke_integration_sequence -s '@! ONE;' -t compile,decode
invoke_integration_sequence -f examples/e/factorial.lambda -t decode -d real
```

`invoke_integration_sequence` 按 `expand` / `reduce` / `compile` / `interpret` / `decode` 的顺序依次运行选中的阶段。

参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容，也可以通过管道传入
- `-t` / `--stages` 指定的一个或多个阶段，默认为 `decode`。各阶段用 `,` 连接，可选的阶段见 [invoke_integration_stage](#invoke_integration_stage) 中的 `-stage` 参数
- `-en` / `--encode-natural`、`-es` / `--encode-string`、`-d` / `--decode` 与 [invoke_integration_stage](#invoke_integration_stage) 中的同名参数一致
