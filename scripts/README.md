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
- `-Source` 源代码内容，也可以通过管道传入
- `--` 后为编译器选项，也可以通过 `-Options` 传入参数数组。具体选项请参考 [compiler.md#编译器选项](../docs/compiler.md#编译器选项)

使用示例：

```pwsh
'@! ONE;' | Invoke-Compiler -- --stop-after=reduce --enable-reduce=both
Invoke-Compiler -Source '@! ONE;' -- --encode=scott
Invoke-Compiler -File "examples/e/factorial.lambda"
```

### Invoke-Interpreter

`Invoke-Interpreter` 调用解释器。

各参数为：

- `-File` 文件路径
- `-Source` 源代码内容，也可以通过管道传入
- `--` 后为解释器选项，也可以通过 `-Options` 传入参数数组。具体选项请参考 [interpreter.md#解释器选项](../docs/interpreter.md#解释器选项)

使用示例：

```pwsh
'#0 = I;' | Invoke-Interpreter -- --show-steps --decode=natural
Invoke-Interpreter -Source '#0 = I;'
Invoke-Interpreter -File "examples/ski/church.ski" -- --decode=natural
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
- `-Source` 源代码内容，也可以通过管道传入
- `-Stage` 指定的一个阶段。可以为 `expand` / `reduce` / `compile` / `interpret` / `decode`。无默认值
- `-Encode` 编译器编码方式。可以为 `church` / `scott`。默认为 `church`
- `-Decode` 解释器解码方式。可以为 `natural` / `scott-natural` / `boolean` / `integer` / `rational` / `real`。默认为 `natural`

## run.ps1

使用示例：

```pwsh
'@! ONE;' | ./scripts/run.ps1 -Stages expand,reduce,decode
./scripts/run.ps1 -Source '@! ONE;' -Stages compile,decode
./scripts/run.ps1 -File "examples/e/factorial.lambda" -Stages decode -Decode real
```

脚本会按 `expand` / `reduce` / `compile` / `interpret` / `decode` 的顺序依次运行至选中的阶段。

参数为：

- `-File` 文件路径
- `-Source` 源代码内容，也可以通过管道传入
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
- `-s` / `--source` 源代码内容，也可以通过管道传入
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
- `-s` / `--source` 源代码内容，也可以通过管道传入
- `--` 后为解释器选项。具体选项请参考 [interpreter.md#解释器选项](../docs/interpreter.md#解释器选项)

使用示例：

```sh
printf '%s\n' '#0 = I;' | invoke_interpreter -- --show-steps --decode=natural
invoke_interpreter -s '#0 = I;'
invoke_interpreter -f examples/ski/church.ski -- --decode=natural
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
- `-s` / `--source` 源代码内容，也可以通过管道传入
- `-t` / `--stage` 指定的一个阶段。可以为 `expand` / `reduce` / `compile` / `interpret` / `decode`。无默认值
- `-e` / `--encode` 编译器编码方式。可以为 `church` / `scott`。默认为 `church`
- `-d` / `--decode` 解释器解码方式。可以为 `natural` / `scott-natural` / `boolean` / `integer` / `rational` / `real`。默认为 `natural`

## run.sh

使用示例：

```sh
printf '%s\n' '@! ONE;' | ./scripts/run.sh -t expand,reduce,decode
./scripts/run.sh -s '@! ONE;' -t compile,decode
./scripts/run.sh -f examples/e/factorial.lambda -t decode -d real
```

脚本会按 `expand` / `reduce` / `compile` / `interpret` / `decode` 的顺序依次运行至选中的阶段。

参数为：

- `-f` / `--file` 文件路径
- `-s` / `--source` 源代码内容，也可以通过管道传入
- `-t` / `--stages` 指定的一个或多个阶段，用 `,` 连接。默认为 `decode`
- `-e` / `--encode` 编译器编码方式。可以为 `church` / `scott`。默认为 `church`
- `-d` / `--decode` 解释器解码方式。可以为 `natural` / `scott-natural` / `boolean` / `integer` / `rational` / `real`。默认为 `natural`

## compare_real.py

使用示例：

```sh
uv run scripts/compare_real.py examples/pi/compare.json
```

脚本会：

1. 读取配置文件 `cases` 中的每个用例
2. 为从零到用例 `maxIndex` 的每个索引生成实数解码的自然数下标
3. 将用例 `methods` 中的每个算法文件编译一次并对每个下标分别解码
4. 记录步数和解码的结果；超出步数上限会停止当前算法的记录
5. 根据用例的 `exactValue` 计算误差
6. 为每个用例写入 CSV 表格
7. 为每个用例绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value,abs_error` 五列
- 图片使用对数坐标，以归约步数作为对数横轴，误差作为对数纵轴。图片包含各算法的收敛曲线、散点图和帕累托前沿

参数为：

- `config` 指定 JSON 配置文件路径。是位置参数，必填

配置示例为：

```json
{
  "cases": [
    {
      "name": "Pi approximation",
      "methods": [
        {
          "name": "arctan",
          "file": "arctan.lambda"
        },
        {
          "name": "leibniz",
          "file": "leibniz.lambda"
        }
      ],
      "exactValue": "3.1415926535897932384626433832795028841971693993751",
      "maxIndex": 10,
      "maxSteps": 1000000,
      "csv": "steps-vs-error.csv",
      "png": "steps-vs-error.png"
    }
  ]
}
```

其中：

- `cases` 为要运行的用例数组。对每个用例：
  - `name` 是用例名称，也是图片标题
  - `exactValue` 是精确值，使用十进制字符串避免 JSON 浮点数损失精度
  - `maxIndex` 是最大实数解码精度，输入范围为 `0..maxIndex`
  - `maxSteps` 是步数上限
  - `csv` / `png` 分别为表格和图片的相对路径，以配置文件所在目录为基准
- `methods` 为待比较的方法数组。对每个方法：
  - `name` 是方法名称
  - `file` 是包含实数入口表达式的 `.lambda` 文件的相对路径，以配置文件所在目录为基准

完整的 JSON Schema 见 [compare_real.schema.json](compare_real.schema.json)。

## compare_index.py

使用示例：

```sh
uv run scripts/compare_index.py examples/fibonacci/compare.json
```

脚本会：

1. 读取配置文件 `cases` 中的每个用例
2. 为从零到用例 `maxIndex` 的每个索引生成输入
3. 为用例 `methods` 中的每个算法导入指定文件中的指定函数并对每个输入分别编译和解码
4. 记录步数和解码的结果；超出步数上限会停止当前算法的记录
5. 检查同一索引下各算法解码的结果是否一致
6. 为每个用例写入 CSV 表格
7. 为每个用例绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value` 四列
- 图片使用半对数坐标，以索引为线性横轴，归约步数为对数纵轴。图片包含各算法的折线和散点

参数为：

- `config` 指定 JSON 配置文件路径。是位置参数，必填

配置示例为：

```json
{
  "cases": [
    {
      "name": "fibonacci",
      "methods": [
        {
          "name": "loop",
          "file": "loop.lambda",
          "function": "fib",
          "encode": "church",
          "decode": "natural"
        },
        {
          "name": "recursive-theta",
          "file": "recursive-theta.lambda",
          "function": "fib",
          "encode": "church",
          "decode": "natural"
        }
      ],
      "maxIndex": 10,
      "maxSteps": 1000000,
      "csv": "index-vs-steps.csv",
      "png": "index-vs-steps.png"
    }
  ]
}
```

其中：

- `cases` 为要运行的用例数组。对每个用例：
  - `name` 是用例名称
  - `maxIndex` 是最大索引，输入范围为 `0..maxIndex`
  - `maxSteps` 是步数上限
  - `csv` / `png` 分别为表格和图片的相对路径，以配置文件所在目录为基准
- `methods` 为待比较的方法数组。对每个方法：
  - `name` 是方法名称
  - `file` 是 `.lambda` 文件的相对路径，以配置文件所在目录为基准
  - `function` 是函数名
  - `encode` 是输入的编码方式，可为 `church` / `scott`
  - `decode` 是输出的解码方式，可为 `natural` / `scott-natural` / `integer` / `rational` / `boolean`

完整的 JSON Schema 见 [compare_index.schema.json](compare_index.schema.json)。

## compare_binary.py

使用示例：

```sh
uv run scripts/compare_binary.py examples/encoding/compare.json
```

脚本会：

1. 读取配置文件 `cases` 中的每个用例
2. 按用例的 `input` 生成二元自然数输入
3. 为用例 `methods` 中的每个算法导入指定文件中的指定函数并对每个输入分别编译和解码
4. 记录步数和解码的结果；超出步数上限会继续当前算法的记录
5. 检查同一输入下各算法解码的结果是否一致
6. 为每个用例写入 CSV 表格
7. 为每个用例绘制 PNG 图片

各输出为：

- 表格包含 `method,m,n,steps,value,status` 六列
- 图片依据采用方式分为两种
  - 对角线取样和固定参数取样生成半对数折线图
  - 网格取样生成热力图

参数为：

- `config` 指定 JSON 配置文件路径。是位置参数，必填

配置示例为：

```json
{
  "cases": [
    {
      "name": "church-vs-scott-add",
      "methods": [
        {
          "name": "church-add",
          "file": "church.lambda",
          "function": "add",
          "encode": "church",
          "decode": "natural"
        },
        {
          "name": "scott-add",
          "file": "scott.lambda",
          "function": "add",
          "encode": "scott",
          "decode": "scott-natural"
        }
      ],
      "input": { "kind": "diagonal", "maxIndex": 10 },
      "maxSteps": 10000,
      "csv": "add.csv",
      "png": "add.png"
    }
  ]
}
```

其中：

- `cases` 为要运行的用例数组。对每个用例：
  - `name` 是用例名称
  - `maxSteps` 是步数上限
  - `csv` / `png` 分别为表格和图片的相对路径，以配置文件所在目录为基准
- `methods` 为待比较的方法数组。对每个方法：
  - `name` 是方法名称
  - `file` 是 `.lambda` 文件的相对路径，以配置文件所在目录为基准
  - `function` 是函数名
  - `encode` 是输入的编码方式，可为 `church` / `scott`
  - `decode` 是输出的解码方式，可为 `natural` / `scott-natural` / `integer` / `rational` / `boolean`
- `input` 为输入的取样方式。包含以下类型：
  - `{ "kind": "diagonal", "maxIndex": 10 }`：从 `(0,0)` 至 `(10,10)`
  - `{ "kind": "fixed-m", "fixed": 3, "maxIndex": 10 }`：`m` 固定为 `3`，`n` 为 `0..10`
  - `{ "kind": "fixed-n", "fixed": 3, "maxIndex": 10 }`：`n` 固定为 `3`，`m` 为 `0..10`
  - `{ "kind": "grid", "maxM": 3, "maxN": 4 }`：计算 `0..3` 和 `0..4` 的笛卡尔积

完整的 JSON Schema 见 [compare_binary.schema.json](compare_binary.schema.json)。

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
