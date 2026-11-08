# 符号微积分

## 符号微分

符号微分示例 [derivative.lambda](derivative.lambda) 用四种表达式节点表示自然数多项式：

- 常量 `constant`
- 变量 `variable`
- 加法 `add`
- 乘法 `mul`

此外 `evaluate e n` 把表达式 `e` 代入自然数 `n` 求值。

微分算子 `differentiate` 接收表达式并返回新的表达式。`differentiate f` 返回 `f` 的符号导数，这通过常量、变量、加法和乘法的求导规则进行定义：

- 对于常量 `differentiate constant` 返回 `ZERO`
- 对于变量 `differentiate variable` 返回 `ONE`
- 对于加法 `differentiate add a b` 返回 `add (differentiate a) (differentiate b)`
- 对于乘法 `differentiate mul a b` 返回 `add (mul (differentiate a) b) (mul a (differentiate b))`

示例构造的函数为

$$
f(x)=x^2+3x+2
$$

其一阶导数为

$$
f'(x) = 2x + 3
$$

在 $x=5$ 处求值得到

$$
f'(5) = 13
$$

因此在仓库根目录运行：

```sh
cabal install exe:lambda-compiler exe:ski-interpreter
lambda-compiler examples/calculus/derivative.lambda | ski-interpreter --decode=natural
```

预期输出 `13`。

若把入口改为 `@! evaluate (differentiate (differentiate polynomial)) FIVE;` 则预期输出 `2`，因为其二阶导数为

$$
f''(x) = 2
$$
