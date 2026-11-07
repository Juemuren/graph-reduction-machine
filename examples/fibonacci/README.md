# 斐波那契数列构造算法比较

## 迭代构造

迭代过程表示为：

$$
\boxed{
\begin{cases}
    P_0=(0,1) \\
    P_{n+1}=T(P_n) \\
    T(a,b)=(b,a+b) \\
    \operatorname{fib}(n) = \pi_1(P_n)
\end{cases}
}
$$

实现在 [loop.lambda](loop.lambda) 中。

## 递归构造

递归过程表示为：

$$
\boxed{
\operatorname{fib}(n) = \begin{cases}
    1 & n = 0 \\
    1 & n = 1 \\
    \operatorname{fib}(n-1) + \operatorname{fib}(n-2) & n \ge 2 \\
\end{cases}
}
$$

实现在 [recursive.lambda](recursive.lambda) 中。
