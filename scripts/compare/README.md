# 运行结果比较

所有使用示例都是在仓库根目录运行。

## compare_real.py

使用示例：

```sh
uv run scripts/compare/compare_real.py examples/pi/compare.json
```

脚本会：

1. 读取配置文件 `cases` 中的每个用例
2. 为从零到用例 `maxIndex` 的每个索引生成实数解码的自然数下标
3. 将用例 `methods` 中的每个方法对应的文件编译一次，并对每个下标分别解码
4. 记录步数和解码的结果；超出步数上限会停止测量后续输入
5. 根据用例的 `exactValue` 计算误差
6. 为每个用例写入 CSV 表格
7. 为每个用例绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value,abs_error` 五列
- 图片使用对数坐标，以归约步数作为对数横轴，误差作为对数纵轴。图片包含各方法的收敛曲线、散点图和帕累托前沿

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
uv run scripts/compare/compare_index.py examples/fibonacci/compare.json
```

脚本会：

1. 读取配置文件 `cases` 中的每个用例
2. 为从零到用例 `maxIndex` 的每个索引生成输入
3. 为用例 `methods` 中的每个方法导入指定文件中的指定函数，并对每个输入分别编译和解码
4. 记录步数和解码的结果；超出步数上限会停止测量后续输入
5. 检查同一索引下各方法解码的结果是否一致
6. 为每个用例写入 CSV 表格
7. 为每个用例绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value` 四列
- 图片使用半对数坐标，以索引为线性横轴，归约步数为对数纵轴。图片包含各方法的折线

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
uv run scripts/compare/compare_binary.py examples/encoding/compare.json
```

脚本会：

1. 读取配置文件 `cases` 中的每个用例
2. 按用例的 `input` 生成二元自然数输入
3. 为用例 `methods` 中的每个方法导入指定文件中的指定函数，并对每个输入分别编译和解码
4. 记录步数和解码的结果；超出步数上限会继续测量后续输入
5. 检查同一输入下各方法解码的结果是否一致
6. 为每个用例写入 CSV 表格
7. 为每个用例绘制 PNG 图片

各输出为：

- 表格包含 `method,m,n,steps,value,status` 六列；达到步数上限时 `status` 为 `limit`，`steps` 和 `value` 为空
- 图片依据采用方式分为两种
  - 对角线取样和固定参数取样生成半对数折线图
  - 网格取样生成热力图；达到步数上限的部分用灰色标出

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

## compare_list.py

使用示例：

```sh
uv run scripts/compare/compare_list.py examples/list/compare.json
```

脚本会：

1. 读取配置文件 `cases` 中的每个用例
2. 按用例的 `generator` 为从零到用例 `maxLength` 的每个长度生成列表元素
3. 对用例 `methods` 中的每个方法导入指定文件中的 `nil`、`cons` 和指定函数，根据用例的 `expression` 生成入口表达式，并对每个长度分别编译和解码
4. 记录步数和解码结果；超出步数上限会继续测量后续长度
5. 检查同一长度下各方法解码的结果是否一致
6. 为每个用例写入 CSV 表格
7. 为每个用例绘制 PNG 图片

各输出为：

- 表格包含 `method,length,steps,value,status` 五列；达到步数上限时 `status` 为 `limit`，`steps` 和 `value` 为空
- 图片使用半对数坐标，以列表长度为线性横轴，归约步数为对数纵轴。图片包含各方法的折线

参数为：

- `config` 指定 JSON 配置文件路径。是位置参数，必填

配置示例为：

```json
{
  "cases": [
    {
      "name": "sort-random",
      "expression": "{function} {list}",
      "generator": {
        "kind": "random",
        "min": 1,
        "max": 8,
        "seed": 20261117
      },
      "methods": [
        {
          "name": "church",
          "file": "church.lambda",
          "function": "sort",
          "encoding": "church",
          "decode": "list<binary-natural>"
        },
        {
          "name": "scott",
          "file": "scott.lambda",
          "function": "sort",
          "encoding": "scott",
          "decode": "scott-list<binary-natural>"
        }
      ],
      "maxLength": 8,
      "maxSteps": 1000000,
      "csv": "sort-random.csv",
      "png": "sort-random.png"
    }
  ]
}
```

其中：

- `cases` 为要运行的用例数组。对每个用例：
  - `name` 是用例名称，也是图片标题
  - `expression` 是函数调用的表达式模板；可使用 `{function}`、`{list}`、`{length}`、`{first}`、`{middle}`、`{last}`、`{firstIndex}`、`{middleIndex}`、`{lastIndex}`。对于空列表，`{first}`、`{middle}`、`{last}`、`{firstIndex}`、`{middleIndex}`、`{lastIndex}` 的值均为 `0`
  - `maxLength` 是最大列表长度
  - `maxSteps` 是步数上限
  - `csv` / `png` 分别为表格和图片的相对路径，以配置文件所在目录为基准
- `methods` 为待比较的方法数组。对每个方法：
  - `name` 是方法名称，同一用例内不能重复
  - `file` 是 `.lambda` 文件的相对路径，以配置文件所在目录为基准
  - `function` 是导入的函数名，供 `{function}` 使用
  - `encoding` 是列表的编码方式，可为 `church` / `scott`
  - `decode` 是列表的解码方式，可为 `list<T>` / `scott-list<T>`
- `generator` 为列表元素的生成方式。包含以下类型：
  - `{ "kind": "ascending-cycle", "min": 1, "max": 3 }`：生成升序循环 `1,2,3,1,2,3,...`
  - `{ "kind": "descending-cycle", "min": 1, "max": 3 }`：生成降序循环 `3,2,1,3,2,1,...`
  - `{ "kind": "constant", "value": 1 }`：生成常值序列 `1,1,1,...`
  - `{ "kind": "random", "min": 1, "max": 8, "seed": 114514 }`：生成最小值为 `1`、最大值为 `8`、种子为 `114514` 的随机序列

完整的 JSON Schema 见 [compare_list.schema.json](compare_list.schema.json)。
