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

所有测试用例使用 JSON 文件，示例为

```json
{
  "cases": [
    {
      "name": "sequence-at-two",
      "input": {
        "language": "lambda",
        "source": "@! \\n -> NTOQ n;"
      },
      "run": {
        "stage": "decode",
        "type": "real",
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

- `input`
  - `input.language` 是 `lambda` 或 `ski`
  - `input.source` 是完整源码
  - `input.modules` 是 JSON 对象，形如 `{ "defs.lambda": "@> f = \\x -> x;" }`
- `run`
  - `run.stage` 可以是 `parse` / `reduce` / `compile` / `interpret` / `undecode` / `decode`
  - `run.type` 仅用于 `decode`，可以是 `natural` / `boolean` / `integer` / `rational` / `real`
  - `run.precisionReal` 指定实数解码精度，是非负整数
  - `run.maxSteps` 指定归约步数上限
  - `run.disableReduce` 可取 `beta` / `eta` / `both`
- `expect` 必须且只能是 `value` / `graph` / `error` 之一
  - `expect.value` 对于 `parse` 和 `reduce` 按语法树比较，对于 `decode` 按文本比较
  - `expect.graph` 按图的输出行比较
  - `expect.error` 比较错误消息

完整字段及允许的组合见 [JSON Schema](../test/cases/schema.json)。

## 编译器测试

测试所有编译器用例

```sh
cabal test compiler-tests
```

编译器测试用例放在 `test/cases/compiler` 下。

测试用例按以下类别组织：

- `parse/`
  - `precedence.json` 验证两个核心 λ 表达式解析后是否相同
  - `errors.json` 验证解析错误
- `expand` 验证两个核心 λ 表达式展开后是否相同（暂无用例）
- `reduce/` 验证规约得到的纯 λ 表达式
  - `default.json` 启用 β 规约和 η 规约
  - `no-beta.json` 禁用 β 规约
  - `no-eta.json` 禁用 η 规约
  - `no-reduce.json` 禁用所有规约
- `compile/` 验证编译得到的 SKI 图
  - `default.json` 启用 β 规约和 η 规约
  - `no-beta.json` 禁用 β 规约
  - `no-eta.json` 禁用 η 规约
  - `no-reduce.json` 禁用所有规约
  - `errors.json` 验证编译错误
- `module/`
  - `definitions.json` 验证定义行为
  - `exports.json` 验证导入和导出行为
  - `errors.json` 验证导入、导出、定义错误

## 解释器测试

测试所有解释器用例

```sh
cabal test interpreter-tests
```

解释器测试用例放在 `test/cases/interpreter` 下。

测试用例按以下类别组织：

- `reduce/`
  - `normal.json` 验证 SKI 图与归约后的 SKI 图是否相同
  - `errors.json` 验证归约错误
- `limit/`
  - `reduce.json` 验证规约的步数限制
  - `decode.json` 验证解码的步数限制
- `decode/*-errors.json` 验证各类型解码失败时的错误行为

## 集成测试

从核心 λ 到规约后 SKI 图的集成测试

```sh
cabal test integration-tests
```

集成测试用例放在 `test/cases/integration` 下。

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

## 语言服务器测试

语言服务器的测试用例为静态文件，位于 `test/cases/lsp`，不是自定义的 JSON 用例格式。

测试所有语言服务器用例

```sh
cabal test language-server-tests
```

语言服务测试使用 `lsp-test` 启动真实语言服务器进程。
