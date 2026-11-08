# 脚本

所有使用示例都是在仓库根目录运行。

## functions.ps1

运行：

```pwsh
. ./scripts/functions.ps1
```

该命令会把脚本中定义的函数提升到当前 PowerShell 会话，包括：

- `Invoke-Compiler`
- `Invoke-Interpreter`
- `Invoke-LambdaStage`

并且脚本为这些函数的参数提供了补全。

### Invoke-Compiler

`Invoke-Compiler` 调用编译器。

各参数为：

- `-File` 文件路径
- `-Source` 源代码内容
- `-Options` 编译器选项。具体选项请参考 [compiler.md#编译器选项](../docs/compiler.md#编译器选项)

使用示例：

```pwsh
'@! ONE;' | Invoke-Compiler -Options @("--stop-after=reduce", "--enable-reduce=both")
Invoke-Compiler -Source '@! ONE;'
Invoke-Compiler -File "examples/e/factorial.lambda"
```

### Invoke-Interpreter

`Invoke-Interpreter` 调用解释器。

各参数为：

- `-File` 文件路径
- `-Source` 源代码内容
- `-Options` 解释器选项。具体选项请参考 [interpreter.md#解释器选项](../docs/interpreter.md#解释器选项)

使用示例：

```pwsh
'#0 = I;' | Invoke-Interpreter -Options @("--show-steps", "--decode=natural")
Invoke-Interpreter -Source '#0 = I;'
Invoke-Interpreter -File "examples/encoding/church.ski" -Options @("--decode=natural")
```

### Invoke-LambdaStage

`Invoke-LambdaStage` 调用编译器和解释器至指定的阶段后停止。

使用示例：

```pwsh
'@! ONE;' | Invoke-LambdaStage -Stage expand
Invoke-LambdaStage -Source '@! ONE;' -Stage expand
Invoke-LambdaStage -File "examples/e/factorial.lambda" -Stage decode -Decode real
```

各参数为：

- `-File` 文件路径
- `-Source` 源代码内容
- `-Stage` 指定的一个阶段。可以为 `expand` / `reduce` / `compile` / `interpret` / `decode`。无默认值
- `-Encode` 编译器编码方式。可以为 `church` / `scott`。默认为 `church`
- `-Decode` 解释器解码方式。可以为 `natural` / `scott-natural` / `boolean` / `integer` / `rational` / `real`。默认为 `natural`

## run.ps1

使用示例：

```pwsh
'@! ONE;' | ./scripts/run.ps1 -Stages expand,reduce,decode
./scripts/run.ps1 -File "examples/e/factorial.lambda" -Stages decode -Decode real
```

脚本会按 `expand` / `reduce` / `compile` / `interpret` / `decode` 的顺序依次运行至选中的阶段。

参数为：

- `-File` 文件路径
- `-Stages` 指定的一个或多个阶段，用 `,` 连接。默认为 `decode`
- `-Encode` 编译器编码方式。可以为 `church` / `scott`。默认为 `church`
- `-Decode` 解释器解码方式。可以为 `natural` / `scott-natural` / `boolean` / `integer` / `rational` / `real`。默认为 `natural`

## functions.sh

运行：

```sh
source ./scripts/functions.sh
```

该命令会把脚本中定义的函数加载到当前 Bash 会话，包括：

- `invoke_compiler`
- `invoke_interpreter`
- `invoke_lambda_stage`

并且脚本为这些函数的参数提供了补全。

### invoke_compiler

`invoke_compiler` 调用编译器。

各参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容
- `--` 后为编译器选项。具体选项请参考 [compiler.md#编译器选项](../docs/compiler.md#编译器选项)

使用示例：

```sh
echo '@! ONE;' | invoke_compiler -- --stop-after=reduce --enable-reduce=both
invoke_compiler -s '@! ONE;'
invoke_compiler -f examples/e/factorial.lambda
```

### invoke_interpreter

`invoke_interpreter` 调用解释器。

各参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容
- `--` 后为解释器选项。具体选项请参考 [interpreter.md#解释器选项](../docs/interpreter.md#解释器选项)

使用示例：

```sh
printf '%s\n' '#0 = I;' | invoke_interpreter -- --show-steps --decode=natural
invoke_interpreter -s '#0 = I;'
invoke_interpreter -f examples/encoding/church.ski -- --decode=natural
```

### invoke_lambda_stage

`invoke_lambda_stage` 调用编译器和解释器至指定的阶段后停止。

使用示例：

```sh
printf '%s\n' '@! ONE;' | invoke_lambda_stage -t expand
invoke_lambda_stage -s '@! ONE;' -t expand
invoke_lambda_stage -f examples/e/factorial.lambda -t decode -d real
```

各参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容
- `-t` / `--stage` 指定的一个阶段。可以为 `expand` / `reduce` / `compile` / `interpret` / `decode`。无默认值
- `-e` / `--encode` 编译器编码方式。可以为 `church` / `scott`。默认为 `church`
- `-d` / `--decode` 解释器解码方式。可以为 `natural` / `scott-natural` / `boolean` / `integer` / `rational` / `real`。默认为 `natural`

## run.sh

使用示例：

```sh
printf '%s\n' '@! ONE;' | ./scripts/run.sh -t expand,reduce,decode
./scripts/run.sh -f examples/e/factorial.lambda -t decode -d real
./scripts/run.sh -s '@! ONE;' -t compile,decode
```

脚本会按 `expand` / `reduce` / `compile` / `interpret` / `decode` 的顺序依次运行至选中的阶段。

参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容
- `-t` / `--stages` 指定的一个或多个阶段，用 `,` 连接。默认为 `decode`
- `-e` / `--encode` 编译器编码方式。可以为 `church` / `scott`。默认为 `church`
- `-d` / `--decode` 解释器解码方式。可以为 `natural` / `scott-natural` / `boolean` / `integer` / `rational` / `real`。默认为 `natural`

## compare_real.py

使用示例：

```sh
uv run scripts/compare_real.py examples/pi \
  --exact-value 3.1415926535897932384626433832795028841971693993751 \
  --max-index 10 --max-steps 1000000
```

脚本会：

1. 将指定目录中的每个 `.lambda` 文件编译一次
2. 为从零到最大索引且不超过最大步数的每个索引作为自然数下标解码实数
3. 根据传入的精确值计算误差
4. 写入 CSV 表格
5. 绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value,abs_error` 五列
- 图片使用对数坐标，以归约步数作为对数横轴，误差作为对数纵轴。图片包含各算法的收敛曲线、散点图和帕累托前沿

各参数为：

- `directory` 指定目录。是位置参数，必填
- `--exact-value` 指定精确值。必填
- `--max-index` 设置最大索引。默认为 `10`
- `--max-steps` 设置最大步数。默认为 `1000000`
- `--csv` 指定输出的 CSV 文件。默认为 `directory/steps-vs-error.csv`
- `--plot` 指定输出的 PNG 文件。默认为 `directory/steps-vs-error.png`

## compare_index.py

使用示例：

```sh
uv run scripts/compare_index.py examples/fibonacci \
  --function fib --decode natural \
  --max-index 10 --max-steps 1000000
```

脚本会：

1. 逐个导入指定目录中每个 `.lambda` 文件导出的指定函数
2. 为从零到最大索引且不超过最大步数的每个索引生成程序入口并编译和解码
3. 写入 CSV 表格
4. 绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value` 四列
- 图片使用半对数坐标，以索引为线性横轴，归约步数为对数纵轴。图片包含各算法的收敛曲线和散点图

各参数为：

- `directory` 指定目录。是位置参数，必填
- `--function` 指定各算法共同导出的函数名，必填
- `--decode` 指定解码方式，默认为 `natural`
- `--max-index` 设置最大索引，默认为 `10`
- `--max-steps` 设置每次解码的最大归约步数，默认为 `1000000`
- `--csv` 指定输出的 CSV 文件。默认为 `directory/index-vs-error.csv`
- `--plot` 指定输出的 PNG 文件。默认为 `directory/index-vs-error.png`

## align-bnfc.py

使用示例：

```sh
python scripts/align-bnfc.py -g grammar/CoreLambda.cf
python scripts/align-bnfc.py -g grammar/CoreLambda.cf -p
```

脚本会：

1. 对齐 BNFC 文法规则中的标签、类别和 `::=`
2. 若启用预览且内容发生变化，则显示差异并等待确认
3. 将结果写回文件

各参数为：

- `-g` / `--grammar` 指定要对齐的文件
- `-p` / `--preview` 启用预览。默认不启用
