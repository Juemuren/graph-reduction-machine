# 测试

项目使用 Cabal 进行测试。

测试所有用例

```sh
cabal test
```

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

## 用例组织

所有测试用例放置在 `test/cases` 目录下。

测试内容为：

- `compiler`：编译器测试
- `interpreter`：解释器测试
- `integration`：集成测试

## 测试编译器

测试所有编译器用例

```sh
cabal test compiler-tests
```

编译器测试用例放在 `test/cases/compiler` 下。

测试用例按以下类别组织：

- `parse` 比较两个核心 λ 表达式解析后是否相同
- `expand` 比较两个核心 λ 表达式展开后是否相同（未实现）
- `reduce` / `reduce-no-beta` / `reduce-no-eta` / `reduce-no-reduce` 分别验证启用 β 规约和 η 规约 / 禁用 β 规约 / 禁用 η 规约 / 禁用所有规约后规约得到的纯 λ 表达式
- `compile` / `compile-no-beta` / `compile-no-eta` / `compile-no-reduce` 分别验证启用 β 规约和 η 规约 / 禁用 β 规约 / 禁用 η 规约 / 禁用所有规约后编译得到的 SKI 图
- `errors` 验证编译器错误行为

核心 λ 的应用与抽象优先级在 `test/cases/compiler/precedence` 中覆盖。

核心 λ 不含语法糖。加入 JavaScript 前端后，在前端测试中覆盖脱糖规则。

## 测试解释器

测试所有解释器用例

```sh
cabal test interpreter-tests
```

解释器测试用例放在 `test/cases/interpreter` 下。

测试用例按以下类别组织：

- `reduce` 比较 SKI 图与归约后的 SKI 图
- `errors` 验证解释器错误行为
- `limit-errors` / `decode-limit-errors` / `decode-boolean-errors` / `decode-natural-errors` / `decode-integer-errors` / `decode-rational-errors` / `decode-real-errors` 验证归约步数超限 / 比较解码步数超限 / 布尔值解码失败 / 自然数解码失败 / 有理数解码失败 / 实数解码失败时的错误行为

## 集成测试

从核心 λ 到规约后 SKI 图的集成测试

```sh
cabal test integration-tests
```

集成测试用例放在 `test/cases/integration` 下。

测试用例按以下类别组织：

- `undecode` 比较核心 λ 与经过展开、编译、规约后得到的 SKI 图
- `decode-natural` / `decode-boolean` / `decode-integer` / `decode-rational` / `decode-real` 分别比较核心 λ 与经过展开、编译、规约、解码后得到的十进制自然数、布尔值、十进制整数、约分后的有理数、指定下标处的有理数
- `operation` 验证内置函数的通用函数行为。结果按自然数解码
- `construction-boolean` / `operation-boolean` 分别验证布尔值的构造 / 布尔值相关的运算。结果按布尔值解码
- `construction-pair` / `operation-pair` 分别验证有序对的构造 / 有序对的运算。结果按布尔值解码
- `construction-natural` / `operation-natural` / `comparison-natural` 分别验证自然数的构造（自然数解码） / 自然数的运算（自然数解码） / 自然数的比较（布尔值解码）
- `construction-integer` / `operation-integer` / `comparison-integer` / `deconstruction-integer` 分别验证整数的构造（整数解码） / 整数的运算（整数解码） / 整数的比较（布尔值解码） / 整数的解构（自然数解码）
- `construction-rational` / `operation-rational` / `comparison-rational` / `deconstruction-rational` 分别验证有理数的构造（有理数解码） / 有理数的运算（有理数解码） / 有理数的比较（布尔值解码） / 有理数的解构（整数解码）
- `construction-real` / `operation-real` / `comparison-real` / `deconstruction-real` 分别验证实数的构造（实数解码） / 实数的运算（实数解码） / 实数的比较（布尔值解码） / 实数的解构（有理数解码）
- `control-if` 验证条件控制结构的行为。结果按自然数解码
- `control-loop` 验证循环控制结构的行为。结果按自然数解码
- `control-loop-limit` 验证禁用编译期规约后无限循环会超过图归约机的步数限制

基础测试是新增特性时需要同步实现的测试：

- 对于一个数据类型，在 `decode-*` 中用一个或多个用例测试解码。如果数据类型中有无穷多的值，则只测试典型值的解码。用例名使用内置函数名的小写；数字使用英文小写
- 对于一个运算，在 `operation-*` 中用一个或多个用例测试结果。只有运算存在不同的边界行为，才使用多个用例。用例名使用内置函数名的小写；多用例时使用后缀说明覆盖的边界
- 对于一个控制结构，在 `control-*` 中用一个用例或多个用例测试行为。用最少的用例覆盖不同分支。用例名应当说明覆盖的分支
