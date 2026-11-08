# 测试

项目使用 Cabal 进行测试。

测试所有用例

```sh
cabal test
```

## 测试的组织结构

所有测试用例放置在 `test/cases` 目录下。

各子目录及其测试内容分别为：

- `compiler`：编译器测试
- `interpreter`：解释器测试
- `integration`：集成测试

## 用例格式

测试用例分为：

- 语言用例
- 命令行用例

### 语言用例

所有语言测试用例使用 JSON 文件，示例为

```json
{
  "cases": [
    {
      "name": "sequence-at-two",
      "language": "lambda",
      "source": "@! \\n -> NTOQ n;",
      "stage": "decode",
      "options": {
        "decode": "real",
        "precisionReal": 2
      },
      "expect": {
        "value": "2/1"
      }
    }
  ]
}
```

其中：

- `name` 是用例的名称。同一 JSON 文件中的用例不能重名
- `language` 是要测试的语言。可以为 `lambda` / `ski`
- `source` 是完整源码
- `modules` 是核心 λ 的模块。格式为 `{ "文件名": "源码" }`
- `stage` 是要进行到的阶段。可以为 `parse` / `expand` / `reduce` / `compile` / `interpret` / `undecode` / `decode`
- `options`
  - `options.enableReduce` 是编译器启用的归约类型。可以为 `beta` / `eta` / `both`
  - `options.encode` 是字面量的编码。可以为 `church` / `scott`
  - `options.maxSteps` 是解释器的归约步数上限。为正整数
  - `options.decode` 是解释器的解码方式。可以为 `natural` / `boolean` / `integer` / `rational` / `real`
  - `options.precisionReal` 是实数解码精度。为非负整数
- `expect` 是预期的值。只能是 `value` / `error` 之一
  - `expect.value` 对于 `parse` / `expand` / `reduce` 比较语法树，对于 `compile / interpret / undecode` 比较图，对于 `decode` 比较文本
  - `expect.error` 比较错误消息

语言用例的完整 JSON Schema 见 [language.schema.json](../test/cases/language.schema.json)。

### 命令行用例

所有命令行测试用例使用 JSON 文件，示例为

```json
{
  "cases": [
    {
      "name": "zero-steps",
      "command": "ski-interpreter",
      "args": ["--show-steps"],
      "stdin": "#0 = I;\n",
      "expect": {
        "exitCode": 0,
        "stdout": "#0 = I;\n",
        "stderr": "steps: 0\n"
      }
    }
  ]
}
```

其中：

- `name` 是用例的名称，同一 JSON 文件中的用例不能重名
- `command` 可以是 `lambda-compiler` / `ski-interpreter`
- `args` 是传给程序的命令行参数数组
- `stdin` 是传给程序的标准输入
- `expect.exitCode`、`expect.stdout`、`expect.stderr` 分别比较退出码、标准输出和标准错误

命令行用例的完整 JSON Schema 见 [cli.schema.json](../test/cases/cli.schema.json)。

## 编译器测试

编译器测试用于测试把核心 λ 编译为 SKI 图的过程。

测试所有编译器测试用例

```sh
cabal test compiler-tests
```

编译器测试用例放在 `test/cases/compiler` 下，属于 [语言用例](#语言用例)。

测试用例按以下类别组织：

- `parse/`
  - `precedence.json` 验证两个核心 λ 表达式解析后是否相同
  - `errors.json` 验证解析错误
- `expand/` 验证展开得到的纯 λ 表达式
- `reduce/` 验证归约得到的纯 λ 表达式
  - `beta.json` 仅启用 β 归约
  - `eta.json` 仅启用 η 归约
  - `both.json` 启用 β 归约和 η 归约
  - `null.json` 不启用归约
- `compile/` 验证编译得到的 SKI 图
  - `beta.json` 仅启用 β 归约
  - `eta.json` 仅启用 η 归约
  - `both.json` 启用 β 归约和 η 归约
  - `null.json` 不启用归约
  - `errors.json` 验证编译错误
- `module/`
  - `definitions.json` 验证定义行为
  - `exports.json` 验证导入和导出行为
  - `errors.json` 验证导入、导出、定义错误

## 解释器测试

解释器测试用于测试解释 SKI 图的过程。

测试所有解释器测试用例

```sh
cabal test interpreter-tests
```

解释器测试用例放在 `test/cases/interpreter` 下，属于 [语言用例](#语言用例)。

测试用例按以下类别组织：

- `reduce/`
  - `normal.json` 验证 SKI 图与归约后的 SKI 图是否相同
  - `errors.json` 验证归约错误
- `limit/`
  - `reduce.json` 验证归约的步数限制
  - `decode.json` 验证解码的步数限制
  - `options.json` 验证步数相关命令行选项及输出
- `decode/*-errors.json` 验证各类型解码失败时的错误行为

## 集成测试

集成测试用于测试从编译核心 λ 到解释 SKI 图的完整过程。

测试所有集成测试用例

```sh
cabal test integration-tests
```

集成测试用例放在 `test/cases/integration` 下，属于 [语言用例](#语言用例)。

测试用例按以下类别组织：

- `undecode` 验证核心 λ 编译后得到的 SKI 图
- `high-order` 验证高阶函数的行为
- `boolean` 验证布尔值构造 / 布尔值运算 / 布尔值解码
- `pair` 验证有序对构造 / 有序对运算
- `natural` 验证自然数构造 / 自然数运算 / 自然数比较 / 自然数解码
- `integer` 验证整数构造 / 整数运算 / 整数比较 / 整数解码
- `rational` 验证有理数构造 / 有理数运算 / 有理数比较 / 有理数解码
- `real` 验证实数构造 / 实数运算 / 实数比较 / 实数解码
- `control` 验证条件 / 递归 / 循环控制结构的行为

基础测试是新增特性时需要同步实现的测试：

- 对于一个数据类型，在对应类型目录的 `decode.json` 中用一个或多个用例测试解码。如果数据类型中有无穷多的值，则只测试典型值的解码。用例名使用内置函数名的小写；数字使用英文小写
- 对于一个运算，在对应类型目录的 `operation.json` 中用一个或多个用例测试结果。只有运算存在不同的边界行为，才使用多个用例。用例名使用内置函数名的小写；多用例时使用后缀说明覆盖的边界
- 对于一个控制结构，在 `control` 目录中用一个或多个用例测试行为。用最少的用例覆盖不同分支。用例名应当说明覆盖的分支

## 命令行测试

命令行测试用于测试可执行程序的参数、退出码和输出。

测试所有命令行测试用例

```sh
cabal test cli-tests
```

命令行测试用例放在 `test/cases/cli` 下，属于 [命令行用例](#命令行用例)。

测试用例按以下类别组织：

- `compiler.json` 测试编译器的可执行程序
- `interpreter.json` 测试解释器的可执行程序

## 语言服务器测试

语言服务器测试用于测试语言服务器的功能。

测试所有语言服务器用例

```sh
cabal test language-server-tests
```

语言服务器测试用例放在 `test/cases/lsp` 下，不属于语言用例或命令行用例。

语言服务测试的完整说明见 [lsp.md#测试](lsp.md#测试)。
