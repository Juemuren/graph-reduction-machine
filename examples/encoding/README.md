# 自然数编码方式比较

## 丘奇编码

丘奇编码通过反复应用函数来表示数据，强调数据的迭代或折叠行为。

<!-- TODO 尚未实现 -->

丘奇编码及相关运算实现在 [church.lambda](church.lambda) 中。

### 丘奇编码的自然数构造

丘奇编码将自然数 $n$ 表示为函数应用 $n$ 次：

$$
\begin{aligned}
0_C &= \lambda f.\lambda x.x \\
1_C &= \lambda f.\lambda x.f\ x \\
2_C &= \lambda f.\lambda x.f\ (f\ x) \\
3_C &= \lambda f.\lambda x.f\ (f\ (f\ x))
\end{aligned}
$$

因此按照皮亚诺公理，丘奇编码的零和后继分别为：

$$
\boxed{
\begin{aligned}
    \mathrm{ZERO}_C &= \lambda f.\lambda x.x \\
    \mathrm{SUCC}_C &= \lambda n.\lambda f.\lambda x.f\ (n\ f\ x)
\end{aligned}
}
$$

前驱可以表示为：

$$
\mathrm{PRED}_C
=
\lambda n.\lambda f.\lambda x.
n\
(\lambda g.\lambda h.h\ (g\ f))\
(\lambda u.x)\
(\lambda u.u)
$$

丘奇编码的自然数可用于表示迭代：

- 当 $n=\mathrm{ZERO}_C$ 时，$n\ a\ b$ 被归约为

    $$
    \begin{aligned}
    \mathrm{ZERO}_C\ a\ b
    &= (\lambda f.\lambda x.x)\ a\ b \\
    &\to b
    \end{aligned}
    $$

- 当 $n=\mathrm{SUCC}_C\ p$ 时，$n\ a\ b$ 被归约为

    $$
    \begin{aligned}
    (\mathrm{SUCC}_C\ p)\ a\ b
    &= ((\lambda n.\lambda f.\lambda x.f\ (n\ f\ x))\ p)\ a\ b \\
    &\to (\lambda f.\lambda x.f\ (p\ f\ x))\ a\ b \\
    &\to a\ (p\ a\ b)
    \end{aligned}
    $$

综上可知：

$$
n\ a\ b
=
\begin{cases}
  b & n = 0 \\
  a\ ((n-1)\ a\ b) & n \ge 1
\end{cases}
$$

继续展开：

$$
(n-1)\ a\ b
=
\begin{cases}
  b & n-1 = 0 \\
  a\ ((n-2)\ a\ b) & n-1 \ge 1
\end{cases}
$$

最终得到：

$$
\boxed{
n\ a\ b
=
\underbrace{a (a (\cdots a}_{n} (b)\cdots))
}
$$

即 $n\ a\ b$ 表示对 $b$ 连续应用 $n$ 次 $a$。

### 丘奇编码的自然数运算

#### 丘奇编码的加法

丘奇编码的加法非常简单，$m+n$ 就是先执行函数 $n$ 次再执行函数 $m$ 次：

$$
\boxed{
\mathrm{ADD}_C
=
\lambda m.\lambda n.\lambda f.\lambda x.m\ f\ (n\ f\ x)
}
$$

#### 丘奇编码的乘法

丘奇编码的乘法更加简单，$m\times n$ 就是把执行函数 $n$ 次的过程重复 $m$ 次：

$$
\boxed{
\mathrm{MUL}_C
=
\lambda m.\lambda n.\lambda f.m\ (n\ f)
}
$$

#### 丘奇编码的减法

丘奇编码的减法会麻烦一些，$m-n$ 可以表示为对 $m$ 连续应用 $n$ 次前驱：

$$
\boxed{
\mathrm{SUB}_C
=
\lambda m.\lambda n.n\ \mathrm{PRED}_C\ m
}
$$

#### 丘奇编码的除法

丘奇编码的除法会更加复杂。

一种方法是用递归：

$$
\mathrm{DIV}_C(m,n)=
\begin{cases}
    0 & n=0 \\
    0 & n \ge 1 \land m \lt n \\
    \mathrm{DIV}_C(m-n,n)+1 & n \ge 1 \land m\ge n
\end{cases}
$$

先表示递归的部分：

$$
\boxed{
\begin{aligned}
\mathrm{recur}
=&
\lambda r.\lambda m.\lambda n. \\
& \mathrm{IF}\ (\mathrm{ISZERO}_C\ n) \\
&\quad \mathrm{ZERO}_C \\
&\quad \mathrm{IF}\ (\mathrm{LT}_C\ m\ n) \\
&\qquad \mathrm{ZERO}_C \\
&\qquad (\mathrm{SUCC}_C\ (r\ (\mathrm{SUB}_C\ m\ n)\ n)) \\
\end{aligned}
}
$$

然后使用 Y 组合子构造递归：

$$
\boxed{
\mathrm{DIV}_C
=
\mathrm{Y}\ \mathrm{recur}
}
$$

另一种方法是用迭代。

把状态表示为一个有序对，第一个数是商，第二个数是余数：

$$
P = (q, r)
$$

初始状态为：

$$
P_0 = (0,m)
$$

状态转移为：

$$
T_n(q,r)
=
\begin{cases}
(q+1,r-n) & r\ge n \\
(q,r) & r<n
\end{cases}
$$

新状态为：

$$
P_{k+1} = T_n(P_k)
$$

从而除法表示为：

$$
\mathrm{DIV}_C(m,n)
=
\begin{cases}
    0 & n=0 \\
    \pi_1(P_m) & n\ge 1
\end{cases}
$$

先把状态转移表示成 λ 演算：

$$
\boxed{
\begin{aligned}
\mathrm{trans}
=&
\lambda n.\lambda p. \\
& \mathrm{IF}\ (\mathrm{GEQ_C}\ (\mathrm{SND}\ p)\ n) \\
&\quad (\mathrm{PAIR} \\
    &\qquad (\mathrm{SUCC}_C\ (\mathrm{FST}\ p)) \\
    &\qquad (\mathrm{SUB}_C\ (\mathrm{SND}\ p)\ n)
)\\
&\quad p
\end{aligned}
}
$$

再定义初始状态：

$$
\boxed{
\mathrm{init}
=
\mathrm{PAIR}\ \mathrm{ZERO}_C\ m
}
$$

最后定义除法：

$$
\boxed{
\begin{aligned}
\mathrm{DIV}_C
=&
\lambda m.\lambda n. \\
& \mathrm{IF}\ (\mathrm{ISZERO}_C\ n) \\
&\quad \mathrm{ZERO}_C\\
&\quad \mathrm{FST}\ (m\ (\mathrm{trans}\ n)\ \mathrm{init})
\end{aligned}
}
$$

## 斯科特编码

斯科特编码通过选择构造器对应的分支来表示数据，强调模式匹配和数据结构的拆解。

<!-- TODO 尚未实现 -->

斯科特编码及相关运算实现在 [scott.lambda](scott.lambda) 中。

### 斯科特编码的自然数构造

斯科特编码将自然数 $n$ 表示为函数递归 $n$ 次：

$$
\begin{aligned}
0_S &= \lambda z.\lambda s.z \\
1_S &= \lambda z.\lambda s.s\ 0_S \\
2_S &= \lambda z.\lambda s.s\ 1_S \\
3_S &= \lambda z.\lambda s.s\ 2_S
\end{aligned}
$$

因此按照皮亚诺公理，斯科特编码的零和后继分别为：

$$
\boxed{
\begin{aligned}
\mathrm{ZERO}_S &= \lambda z.\lambda s.z \\
\mathrm{SUCC}_S &= \lambda n.\lambda z.\lambda s.s\ n
\end{aligned}
}
$$

前驱可以表示为：

$$
\mathrm{PRED}_S=\lambda n.n\ \mathrm{ZERO}_S\ (\lambda p.p)
$$

斯科特编码的自然数可用于表示模式匹配：

- 当 $n=\mathrm{ZERO}_S$ 时，$n\ a\ b$ 被归约为

    $$
    \begin{aligned}
    \mathrm{ZERO}_S\ a\ b
    &= (\lambda z.\lambda s.z)\ a\ b \\
    &\to a
    \end{aligned}
    $$

- 当 $n=\mathrm{SUCC}_S\ p$ 时，$n\ a\ b$ 被归约为

    $$
    \begin{aligned}
    (\mathrm{SUCC}_S\ p)\ a\ b
    &= ((\lambda n.\lambda z.\lambda s.s\ n)\ p)\ a\ b \\
    &\to (\lambda z.\lambda s.s\ p)\ a\ b \\
    &\to b\ p
    \end{aligned}
    $$

综上可知：

$$
n\ a\ b
=
\begin{cases}
  a & n = 0 \\
  b\ (n-1) & n \ge 1
\end{cases}
$$

即 $n\ a\ b$ 表示当 $n=0$ 时执行 $a$，当 $n\ge 1$ 时执行 $b\ (n-1)$。

### 斯科特编码的自然数运算

#### 斯科特编码的加法

斯科特编码的加法可以使用递归实现：

$$
\mathrm{ADD}_S(m, n)
=
\begin{cases}
    m & n = 0 \\
    \mathrm{ADD}_S(m,n-1)+1 & n \ge 1 \\
\end{cases}
$$

先表示递归的部分：

$$
\boxed{
\begin{aligned}
\mathrm{recur}
=&
\lambda r.\lambda m.\lambda n. \\
& n \\
&\quad m \\
&\quad (\lambda p.\mathrm{SUCC}_S\ (r\ m\ p))
\end{aligned}
}
$$

然后使用 Y 组合子构造递归：

$$
\boxed{
\mathrm{ADD}_S
=
\mathrm{Y}\ \mathrm{recur}
}
$$

#### 斯科特编码的减法

斯科特编码的减法可以使用递归实现：

$$
\mathrm{SUB}_S(m, n)
=
\begin{cases}
    m & n = 0 \\
    \mathrm{SUB}_S(m,n-1)-1 & n \ge 1 \\
\end{cases}
$$

先表示递归的部分：

$$
\boxed{
\begin{aligned}
\mathrm{recur}
=&
\lambda r.\lambda m.\lambda n. \\
& n \\
&\quad m \\
&\quad (\lambda p.\mathrm{PRED}_S\ (r\ m\ p))
\end{aligned}
}
$$

然后使用 Y 组合子构造递归：

$$
\boxed{
\mathrm{SUB}_S
=
\mathrm{Y}\ \mathrm{recur}
}
$$

#### 斯科特编码的乘法

斯科特编码的乘法可以使用递归实现：

$$
\mathrm{MUL}_S(m, n)
=
\begin{cases}
    0 & n = 0 \\
    \mathrm{MUL}_S(m,n-1)+m & n \ge 1 \\
\end{cases}
$$

先表示递归的部分：

$$
\boxed{
\begin{aligned}
\mathrm{recur}
=&
\lambda r.\lambda m.\lambda n. \\
& n \\
&\quad \mathrm{ZERO}_S \\
&\quad (\lambda p.\mathrm{ADD}_S\ (r\ m\ p)\ m)
\end{aligned}
}
$$

然后使用 Y 组合子构造递归：

$$
\boxed{
\mathrm{MUL}_S
=
\mathrm{Y}\ \mathrm{recur}
}
$$

#### 斯科特编码的除法

斯科特编码的除法可以使用分段递归实现：

$$
\mathrm{DIV}_S(m, n)
=
\begin{cases}
0 & n = 0 \\
0 & n \ge 1 \land m < n \\
\mathrm{DIV}_S(m-n,n)+1 & n \ge 1 \land m\ge n
\end{cases}
$$

先表示递归的部分：

$$
\boxed{
\begin{aligned}
\mathrm{recur}
=&
\lambda r.\lambda m.\lambda n. \\
& \mathrm{IF}\ (\mathrm{ISZERO}_S\ n) \\
&\quad \mathrm{ZERO}_S \\
&\quad \mathrm{IF}\ (\mathrm{LT}_S\ m\ n) \\
&\qquad \mathrm{ZERO}_S \\
&\qquad (\mathrm{SUCC}_S\ (r\ (\mathrm{SUB}_S\ m\ n)\ n))
\end{aligned}
}
$$

然后使用 Y 组合子构造递归：

$$
\boxed{
\mathrm{DIV}_S
=
\mathrm{Y}\ \mathrm{recur}
}
$$

## 比较

比较编译得到的 SKI 图

```sh
echo "@! 1;" | lambda-compiler --encode=church
echo "@! 1;" | lambda-compiler --encode=scott
```
