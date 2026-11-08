# 符号微积分

## 符号微分

符号微分的示例为 [differential.lambda](differential.lambda)。

示例定义了四种表达式节点：

- 常量 `constant`
- 变量 `variable`
- 加法 `add`
- 乘法 `mul`

此外 `evaluate e n` 把表达式 `e` 代入自然数 `n` 求值。

`differentiate` 表示微分算子，`differentiate f` 返回 `f` 的符号导数 $f'$。

符号导数通过常量、变量、加法和乘法的求导规则进行定义：

- 对于常量 `differentiate constant` 返回 `ZERO`
    $$
    \frac{\mathrm{d}c}{\mathrm{d}x} = 0
    $$
- 对于变量 `differentiate variable` 返回 `ONE`
    $$
    \frac{\mathrm{d}x}{\mathrm{d}x} = 0
    $$
- 对于加法 `differentiate (add a b)` 返回 `add (differentiate a) (differentiate b)`
    $$
    \frac{\mathrm{d}(f+g)}{\mathrm{d}x} = \frac{\mathrm{d}f}{\mathrm{d}x} + \frac{\mathrm{d}g}{\mathrm{d}x}
    $$
- 对于乘法 `differentiate (mul a b)` 返回 `add (mul (differentiate a) b) (mul a (differentiate b))`
    $$
    \frac{\mathrm{d}(f\cdot g)}{\mathrm{d}x} = \frac{\mathrm{d}f}{\mathrm{d}x}g \cdot f\frac{\mathrm{d}g}{\mathrm{d}x}
    $$

示例构造的函数 `polynomial` 为

$$
f(x)=x^2+3x+2
$$

`differentiate polynomial` 返回其导数

$$
f'(x) = 2x + 3
$$

`evaluate (differentiate polynomial) FIVE` 让导数在 $x=5$ 处求值，得到

$$
f'(5) = 13
$$

因此在仓库根目录运行：

```sh
lambda-compiler examples/calculus/differential.lambda | ski-interpreter --decode=natural
```

预期输出为 `13`。

## 符号积分

符号积分的示例为 [integral.lambda](integral.lambda)。

示例定义了两种表达式节点

- `monomial` 表示有理数系数的单项式。`monomial c n` 返回系数为 `c` 指数为 `n` 的幂函数 $c x^n$
- `add` 表示多项式的加法

`integrate` 表示不定积分算子，`integrate f` 返回 `f` 的符号原函数 $\int f$。该原函数省略了积分常数 $C$。

符号原函数通过加法和幂函数的反求导规则进行定义：

- 对于加法 `integrate (add f g)` 返回 `add (integrate f) (integrate g)`
    $$
    \int (f + g) = \int f + \int g
    $$
- 对于幂函数 `integrate (monomial c n)` 返回 `monomial (QDIV c (NTOQ (SUCC n))) (SUCC n)`
    $$
    \int c x^n = \frac{c}{n+1}x^{n+1}
    $$

示例构造的函数 `polynomial` 为

$$
f(x)=x^2+x+1
$$

`integrate polynomial` 返回其原函数

$$
F(x)=\frac{x^3}{3}+\frac{x^2}{2}+x
$$

`evaluate (integrate polynomial) TWO` 让原函数在 $x=2$ 处求值，得到

$$
F(2)=20/3
$$

因此在仓库根目录运行：

```sh
lambda-compiler examples/calculus/integral.lambda | ski-interpreter --decode=rational
```

预期输出为 `20/3`。
