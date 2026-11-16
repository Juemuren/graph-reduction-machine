# 有序列表编码

## Church 有序列表

Church 有序列表通过折叠操作来表示数据，适合对列表进行遍历。

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
[] &= \mathrm{NIL}_C \\
[i_1] &= \mathrm{CONS}_C\ i_1\ \mathrm{NIL} \\
[i_2,i_1] &= \mathrm{CONS}_C\ i_2\ [i_1] \\
[i_3,i_2,i_1] &= \mathrm{CONS}_C\ i_3\ [i_2,i_1]
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

## Scott 有序列表

Scott 有序列表通过选择空列表或非空列表对应的分支来表示数据，适合对列表进行模式匹配和解构。

Scott 有序列表需要两个基本定义：

$$
\boxed{
\begin{aligned}
\mathrm{NIL}_S &= \lambda c.\lambda n.n \\
\mathrm{CONS}_S &= \lambda h.\lambda t.\lambda c.\lambda n.c\ h\ t
\end{aligned}
}
$$

二者分别表示空列表和在列表开头插入元素：

$$
\begin{aligned}
\mathrm{NIL}_S &\to [] \\
\mathrm{CONS}_S\ h\ t &\to [h, \ldots t]
\end{aligned}
$$

由此可以递归构造出任意列表：

$$
\begin{aligned}
[] &= \mathrm{NIL}_S \\
[i_1] &= \mathrm{CONS}_S\ i_1\ \mathrm{NIL}_S \\
[i_2,i_1] &= \mathrm{CONS}_S\ i_2\ [i_1] \\
[i_3,i_2,i_1] &= \mathrm{CONS}_S\ i_3\ [i_2,i_1]
\end{aligned}
$$

Scott 有序列表可用于表示模式匹配：

- 当 $l=\mathrm{NIL}_S$ 时，$l\ a\ b$ 被归约为

    $$
    \begin{aligned}
    \mathrm{NIL}_S\ a\ b
    &= (\lambda c.\lambda n.n)\ a\ b \\
    &\to b
    \end{aligned}
    $$

- 当 $l=\mathrm{CONS}_S\ i_1\ i_{2:k}$ 时，$l\ a\ b$ 被归约为

    $$
    \begin{aligned}
    (\mathrm{CONS}_S\ i_1\ i_{2:k})\ a\ b
    &= ((\lambda h.\lambda t.\lambda c.\lambda n.c\ h\ t)\ i_1\ i_{2:k})\ a\ b \\
    &\to (\lambda c.\lambda n.c\ i_1\ i_{2:k})\ a\ b \\
    &\to a\ i_1\ i_{2:k}
    \end{aligned}
    $$

综上可知：

$$
\boxed{
l\ a\ b
=
\begin{cases}
  b & l = [] \\
  a\ i_1\ i_{2:k} & l = [i_1,\ldots i_{2:k}]
\end{cases}
}
$$

即 $l\ a\ b$ 表示：

- 当 $l$ 为空列表时执行 $b$
- 当 $l$ 非空列表时执行 $a\ i_1\ i_{2:k}$，其中 $i_1$ 是首元素而 $i_{2:k}$ 是去除首元素得到的尾列表
