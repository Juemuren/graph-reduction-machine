# SKI 组合子

SKI 组合子是图灵完备的，即只用 SKI 三个组合子以及函数应用就可以表示任意可计算程序。

SKI 组合子和 λ 演算都可以模拟任意图灵机。因此可以把由 λ 演算组成的表达式编译为由 SKI 组合子组成的图。

## S 组合子

S 组合子用 λ 演算表示为

$$
S
=
\lambda f.\lambda g. \lambda x.f\ x\ (g\ x)
$$

函数应用的规则为

$$
\boxed{
S\ x\ y\ z
\longrightarrow
x\ z\ (y\ z)
}
$$

## K 组合子

K 组合子用 λ 演算表示为

$$
K
=
\lambda x. \lambda y.x
$$

函数应用的规则为

$$
\boxed{
K\ x\ y
\longrightarrow
x
}
$$

## I 组合子

I 组合子用 λ 演算表示为

$$
I
=
\lambda x.x
$$

函数应用的规则为

$$
\boxed{
I\ x
\longrightarrow
x
}
$$

并且有

$$
S\ K\ K\ x
\longrightarrow K\ x\ (K\ x)
\longrightarrow x
$$

即

$$
\boxed{
S K K = I
}
$$

## 比较编译结果

比较不同自然数编码在编译后得到的 SKI 图

```sh
echo "@! \f -> \x -> f x;" | lambda-compiler > examples/ski/church.ski
echo "@! \z -> \s -> z;" | lambda-compiler > examples/ski/scott.ski
```

比较表达式归约后再编译得到的 SKI 图

```sh
echo "@! \f -> \x -> f x;" | lambda-compiler --enable-reduce=beta > examples/ski/church-beta.ski
echo "@! \f -> \x -> f x;" | lambda-compiler --enable-reduce=eta > examples/ski/church-eta.ski
echo "@! \f -> \x -> f x;" | lambda-compiler --enable-reduce=both > examples/ski/church-both.ski
echo "@! \z -> \s -> z;" | lambda-compiler --enable-reduce=beta > examples/ski/scott-beta.ski
echo "@! \z -> \s -> z;" | lambda-compiler --enable-reduce=eta > examples/ski/scott-eta.ski
echo "@! \z -> \s -> z;" | lambda-compiler --enable-reduce=both > examples/ski/scott-both.ski
```
