# λ 演算

λ 演算是图灵完备的，即只用函数抽象以及函数应用就可以表示任意可以计算程序。

## 函数抽象

用 $\lambda x.M$ 表示以 $x$ 为参数，以 $M$ 为返回值的函数。

不同于图灵机，λ 演算不区别程序和数据，将一切都表示为函数。因此参数是函数，返回值是函数。这些函数的实际意义则取决于编码方式。

比如恒等函数直接返回传入的参数：

$$
I
=
\lambda x.x
$$

比如常值函数接受两个参数，但只返回第一个参数而忽略第二个参数：

$$
K
=
\lambda x.\lambda y.x
$$

比如代换函数接受三个参数，返回第三个参数分别应用于前两个参数后组合得到的结果：

$$
S
=
\lambda f.\lambda g. \lambda x.f\ x\ (g\ x)
$$

## 函数应用

用 $M\ N$ 表示将函数 $M$ 应用到参数 $N$ 上。

函数应用从左向右结合。

因此 $K\ a\ b$ 等价于 $(K\ a)\ b$，即先将 $K$ 应用于 $a$，再将结果 $K\ a$ 应用于 $b$。

参数和返回值都可以是函数。

因此 $I\ (\lambda y.y)$ 表示恒等函数应用到函数 $\lambda y.y$ 上，得到函数 $\lambda y.y$ 作为返回值。

## 归约

**β 归约** 是函数应用的规则，把函数体中的参数替换为传入的表达式：

$$
\boxed{
(\lambda x.M)\ N
\longrightarrow_{\beta}
M[x := N]
}
$$

例如，$K$ 先接收 $a$ 再接收 $b$：

$$
(\lambda x.\lambda y.x)\ a\ b
\longrightarrow_{\beta}
(\lambda y.a)\ b
\longrightarrow_{\beta}
a
$$

**η 归约** 是函数化简的规则，如果函数只是把接收参数 $x$ 并直接传给另一个函数 $M$，那么就可以去掉外层的函数抽象，前提是 $x$ 不出现在 $M$ 的自由变量中：

$$
\boxed{
\lambda x.M\ x
\longrightarrow_{\eta}
M
\qquad
x\notin FV(M)
}
$$

例如，$\lambda x.I\ x$ 可以去掉外层的函数抽象从而进行化简：

$$
\lambda x.I\ x
\longrightarrow_{\eta}
I
$$

## 示例

比较函数应用前和函数应用后的结果

```sh
echo "@! S K K;" | lambda-compiler --stop-after=expand > examples/lambda/apply.lambda
echo "@! S K K;" | lambda-compiler --stop-after=reduce --enable-reduce=beta > examples/lambda/apply-beta.lambda
echo "@! S K K;" | lambda-compiler --stop-after=reduce --enable-reduce=eta > examples/lambda/apply-eta.lambda
```

比较函数化简前和函数化简后的结果

```sh
echo "@! ONE;" | lambda-compiler --stop-after=expand > examples/lambda/simplify.lambda
echo '@! ONE;' | lambda-compiler --stop-after=reduce --enable-reduce=beta > examples/lambda/simplify-beta.lambda
echo '@! ONE;' | lambda-compiler --stop-after=reduce --enable-reduce=eta > examples/lambda/simplify-eta.lambda
```
