# 有序列表编码

## Church 有序列表

Church 有序列表需要两个基本定义：

$$
\boxed{
\begin{aligned}
\mathrm{NIL}_C &= \lambda c.\lambda n.n \\
\mathrm{CONS}_C &= \lambda h.\lambda t.\lambda c.\lambda n.c\ h\ (t\ c\ n)
\end{aligned}
}
$$

二者分别表示空列表和在列表开头插入元素：

$$
\begin{aligned}
\mathrm{NIL}_C &\to [] \\
\mathrm{CONS}_C\ h\ t &\to [h, \ldots t] \\
\end{aligned}
$$

由此可以递归构造出任意列表：

$$
\begin{aligned}
[] &= \mathrm{NIL} \\
[i_1] &= \mathrm{CONS}\ i_1\ \mathrm{NIL} \\
[i_2,i_1] &= \mathrm{CONS}\ i_2\ [i_1] \\
[i_3,i_2,i_1] &= \mathrm{CONS}\ i_3\ [i_2,i_1]
\end{aligned}
$$

Church 有序列表可用于表示折叠：

- 当 $l=\mathrm{NIL}_C$ 时，$l\ a\ b$ 被归约为

    $$
    \begin{aligned}
    \mathrm{NIL}_C\ a\ b
    &= (\lambda c.\lambda n.n)\ a\ b \\
    &\to b
    \end{aligned}
    $$

- 当 $l=\mathrm{CONS}_C\ i_1\ i_{2:k}$ 时，$l\ a\ b$ 被归约为

    $$
    \begin{aligned}
    (\mathrm{CONS}_C\ i_1\ i_{2:k})\ a\ b
    &= ((\lambda h.\lambda t.\lambda c.\lambda n.c\ h\ (t\ c\ n))\ i_1\ i_{2:k})\ a\ b \\
    &\to (\lambda c.\lambda n.c\ i_1\ (i_{2:k}\ c\ n))\ a\ b \\
    &\to a\ i_1\ (i_{2:k}\ a\ b)
    \end{aligned}
    $$

综上可知：

$$
\boxed{
l\ a\ b
=
\begin{cases}
  b & l = [] \\
  a\ i_1\ (i_{2:k}\ a\ b) & l = [i_1,\ldots i_{2:k}]
\end{cases}
}
$$

继续展开：

$$
i_{2:k}\ a\ b
=
\begin{cases}
  b & i_{2:k} = [] \\
  a\ i_2\ (i_{3:k}\ a\ b) & i_{2:k} = [i_2,\ldots i_{3:k}]
\end{cases}
$$

最终得到：

$$
\boxed{
[i_1,i_2,\ldots,i_k]\ a\ b
=
a\ i_1\ (a\ i_2\ (\cdots(a\ i_k\ b)\cdots))
}
$$

即 $l\ a\ b$ 表示对 $l$ 中的每个元素从右到左依次对当前元素和累计值应用 $a$。
