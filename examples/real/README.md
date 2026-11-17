# 实数编码

实数可以基于自然数逐步构造出来。

数学上最经典的构造路线是：

1. 用自然数有序对表示整数
2. 用整数有序对表示有理数
3. 用有理数序列表示实数

## 整数

整数可以通过自然数有序对构造出来。

对于自然数有序对 $(a,b)$，认为其数值上等于 $a-b$。

所有自然数有序对组成的集合可以用笛卡尔积表示为：

$$
\mathbb N\times\mathbb N
=
\Set{
    (a,b)
    |
    a,b\in\mathbb N
}
$$

一个整数可能有多种等价的表示，其等价关系可表示为：

$$
(a,b)\sim(c,d)
\iff
a +_{\mathbb{N}} d = b +_{\mathbb{N}} c
$$

其中 $+_{\mathbb{N}}$ 表示自然数加法。

最终整数就是基于这种等价关系定义的商集：

$$
\mathbb Z
=
\frac{
    \mathbb N\times\mathbb N
}{
    \sim
}
$$

## 有理数

有理数可以通过整数有序对构造出来。

对于整数有序对 $(a,b)$，认为其数值上等于 $\frac{a}{b}$，并且额外规定 $b\ne 0$。

所有第二个整数不等于零的整数有序对组成的集合可以表示为：

$$
\mathbb Z\times (\mathbb Z\setminus\set{0})
=
\Set{
    (a,b)
    |
    a,b\in\mathbb Z,
    b\ne 0
}
$$

一个有理数可能有多种等价的表示，其等价关系可表示为：

$$
(a,b)\sim(c,d)
\iff
a \times_{\mathbb{Z}} d = b \times_{\mathbb{Z}} c
$$

其中 $\times_{\mathbb{Z}}$ 表示整数乘法。

最终有理数就是基于这种等价关系定义的商集：

$$
\mathbb Q
=
\frac{
    \mathbb Z\times(\mathbb Z\setminus\set{0})
}{
    \sim
}
$$

## 实数

实数可以通过有理数序列构造出来。

对于有理数序列 $a_0, a_1, a_2, \cdots$，认为其数值上等于 $\lim_{n\to\infty} a_n$，并且额外排除极限不存在的情况。

有理数序列可以简写为 $(a_n)$，所有有理数序列组成的集合可以表示为：

$$
\mathbb Q^{\mathbb N}
=
\Set{
    (a_n)
    \mid
    a_n\in\mathbb Q,
    n\in\mathbb N
}
$$

存在极限的有理数序列被称为柯西序列，所有柯西序列组成的集合可以表示为：

$$
\mathcal C
=
\Set{
    (a_n)\in \mathbb{Q}^\mathbb{N}
    |
    \forall\varepsilon\in\mathbb Q_{>0},
    \exists N\in\mathbb N,
    \forall m,n\ge N,
    \lvert a_m -_{\mathbb{Q}} a_n \rvert \lt \varepsilon
}
$$

其中 $-_{\mathbb{Q}}$ 表示有理数减法。

一个实数可能多种等价的表示，其等价关系可表示为：

$$
(a_n)\sim(b_n)
\iff
\forall\varepsilon\in\mathbb Q_{>0},
\exists N\in\mathbb N,
\forall n\ge N,
\lvert a_n -_{\mathbb{Q}} b_n \rvert \lt \varepsilon
$$

最终实数就是基于这种等价关系定义的商集：

$$
\mathbb{R}
=
\frac{
    \mathcal C
}
{
    \sim
}
$$

为了更方便计算，可以将有理数序列 $(a_n)$ 视为把自然数映射为有理数的函数 $a: \mathbb{N} \to \mathbb{Q}$，二者之间是一一对应的：

$$
\begin{aligned}
    a(0) &= a_0 \\
    a(1) &= a_1 \\
    \cdots &= \cdots
\end{aligned}
$$

从而有理数序列组成的集合，同构于把自然数映射为有理数的函数组成的集合：

$$
\mathbb{Q}^\mathbb{N}
\cong
\Set{f | f:\mathbb N\to\mathbb Q}
$$
