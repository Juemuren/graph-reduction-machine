# 自然数编码

## Church 自然数

Church 自然数通过反复应用函数来表示数据，强调数据的迭代或折叠行为。

Church 自然数及相关运算实现在 [church.lambda](church.lambda) 中。

### Church 自然数的构造

Church 自然数 $n$ 表示为函数应用 $n$ 次：

$$
\begin{aligned}
0_C &= \lambda f.\lambda x.x \\
1_C &= \lambda f.\lambda x.f\ x \\
2_C &= \lambda f.\lambda x.f\ (f\ x) \\
3_C &= \lambda f.\lambda x.f\ (f\ (f\ x))
\end{aligned}
$$

因此按照皮亚诺公理，Church 自然数的零和后继分别为：

$$
\boxed{
\begin{aligned}
    \mathrm{ZERO}_C &= \lambda f.\lambda x.x \\
    \mathrm{SUCC}_C &= \lambda n.\lambda f.\lambda x.f\ (n\ f\ x)
\end{aligned}
}
$$

Church 自然数可用于表示迭代：

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

简记为：

$$
n\ a\ b = a^n (b)
$$

即 $n\ a\ b$ 表示对 $b$ 连续应用 $n$ 次 $a$。

### Church 自然数的运算

实现 Church 自然数运算的关键之处，就是将运算的结果表示为函数应用 $n$ 次。

#### Church 自然数的加法

Church 自然数的加法非常简单，$m+n$ 就是先执行函数 $n$ 次再执行函数 $m$ 次：

$$
\boxed{
\mathrm{ADD}_C
=
\lambda m.\lambda n.\lambda f.\lambda x.m\ f\ (n\ f\ x)
}
$$

#### Church 自然数的乘法

Church 自然数的乘法更加简单，$m\times n$ 就是把执行函数 $n$ 次的过程重复 $m$ 次：

$$
\boxed{
\mathrm{MUL}_C
=
\lambda m.\lambda n.\lambda f.m\ (n\ f)
}
$$

#### Church 自然数的前驱

Church 自然数的前驱较为麻烦。

首先需要三个辅助函数：

$$
\begin{aligned}
A &= \lambda g.\lambda h.h\ (g\ f) \\
B &= \lambda u.x \\
I &= \lambda u.u \\
\end{aligned}
$$

其中：

- $A\ g$ 返回 $\lambda h.h\ (g\ f)$
- $B\ f$ 返回 $x$
- $I\ u$ 返回 $u$

然后观察应用结果：

$$
n\ A\ B\ I
=
A^n(B)\ I
$$

对于 $A^1(B)$ 有：

$$
A\ B = \lambda h.h\ (B\ f) = \lambda h.h\ x
$$

对于 $A^2(B)$ 有：

$$
A\ (A\ B) = \lambda h.h\ ((A\ B)\ f) = \lambda h.h\ (f\ x)
$$

对于 $A^3(B)$ 有：

$$
A\ (A\ (A\ B)) = \lambda h.h\ ((A\ (A\ B))\ f) = \lambda h.h\ (f\ (f\ x))
$$

由数学归纳法，对于 $A^n(B)$ 有：

$$
A^n(B) = \lambda h.h\ (A^{n-1}(B)\ f) = \lambda h.h\ (f^{n-1}(x))
$$

于是：

$$
A^n(B)\ I = f^{n-1}(x)
$$

而 $n-1$ 是 $\lambda f. \lambda x. f^{n-1}(x)$，因此前驱可以表示为：

$$
\boxed{
\mathrm{PRED}_C
=
\lambda n.\lambda f.\lambda x.
n\ A\ B\ I
}
$$

#### Church 自然数的减法

Church 自然数的减法会麻烦一些，$m-n$ 可以表示为对 $m$ 连续应用 $n$ 次前驱：

$$
\boxed{
\mathrm{SUB}_C
=
\lambda m.\lambda n.n\ \mathrm{PRED}_C\ m
}
$$

#### Church 自然数的除法

Church 自然数的除法会更加复杂。

一种方法是用迭代。

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
\mathrm{div}(m,n)
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

另一种方法是用递归。不过这和 Scott 自然数中的除法基本相同，故不再重复。

## Scott 自然数

Scott 自然数通过选择构造器对应的分支来表示数据，强调模式匹配和数据结构的拆解。

Scott 自然数及相关运算实现在 [scott.lambda](scott.lambda) 中。

### Scott 自然数的构造

Scott 自然数需要两个基本定义：

$$
\boxed{
\begin{aligned}
\mathrm{ZERO}_S &= \lambda z.\lambda s.z \\
\mathrm{SUCC}_S &= \lambda n.\lambda z.\lambda s.s\ n
\end{aligned}
}
$$

这分别表示：

$$
\begin{aligned}
\mathrm{ZERO}_S &\to 0 \\
\mathrm{SUCC}_S\ n &\to n+1 \\
\end{aligned}
$$

由此可以按照皮亚诺公理递归定义所有自然数：

$$
\begin{aligned}
0_S &= \mathrm{ZERO}_S \\
1_S &= \mathrm{SUCC}_S(0_S) \\
2_S &= \mathrm{SUCC}_S(1_S) \\
3_S &= \mathrm{SUCC}_S(2_S)
\end{aligned}
$$

Scott 自然数可用于表示模式匹配：

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
\boxed{
n\ a\ b
=
\begin{cases}
  a & n = 0 \\
  b\ (n-1) & n \ge 1
\end{cases}
}
$$

即 $n\ a\ b$ 表示：

- 当 $n=0$ 时执行 $a$
- 当 $n\ge 1$ 时执行 $b\ (n-1)$

### Scott 自然数的运算

实现 Scott 自然数运算的关键之处，就是将运算的结果按情况进行分类：

- 对于 $n=0$ 的情形，需要将结果表示为常量
- 对于 $n\ge1$ 的情形，需要将结果表示为以 $n-1$ 为参数的函数

#### Scott 自然数的前驱

Scott 自然数的前驱利用模式匹配可以非常简单的实现：

$$
\boxed{
\mathrm{PRED}_S
=
\lambda n.
n\ \mathrm{ZERO}_S\ (\lambda p.p)
}
$$

#### Scott 自然数的加法

Scott 自然数的加法可以使用递归实现：

$$
\mathrm{add}(m, n)
=
\begin{cases}
    m & n = 0 \\
    \mathrm{add}(m,n-1)+1 & n \ge 1 \\
\end{cases}
$$

使用 Y 组合子构造递归：

$$
\boxed{
\begin{aligned}
\mathrm{ADD}_S
=&
\mathrm{Y}\ (\lambda r.\lambda m.\lambda n. \\
&\quad n \\
&\qquad m \\
&\qquad (\lambda p.\mathrm{SUCC}_S\ (r\ m\ p)) \\
& )
\end{aligned}
}
$$

#### Scott 自然数的减法

Scott 自然数的减法可以使用递归实现：

$$
\mathrm{sub}(m, n)
=
\begin{cases}
    m & n = 0 \\
    \mathrm{sub}(m,n-1)-1 & n \ge 1 \\
\end{cases}
$$

#### Scott 自然数的乘法

Scott 自然数的乘法可以使用递归实现：

$$
\mathrm{mul}(m, n)
=
\begin{cases}
    0 & n = 0 \\
    \mathrm{mul}(m,n-1)+m & n \ge 1 \\
\end{cases}
$$

#### Scott 自然数的除法

Scott 自然数的除法可以使用分段递归实现：

$$
\mathrm{div}(m, n)
=
\begin{cases}
0 & n = 0 \\
0 & n \ge 1 \land m < n \\
\mathrm{div}(m-n,n)+1 & n \ge 1 \land m\ge n
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

## Binary 自然数

皮亚诺公理可以认为是一种一进制编码：无论采用 Church 自然数还是 Scott 自然数，对于 $n$ 都需要 $O(n)$ 的表示长度。而二进制编码只需要 $O(\log n)$ 的表示长度。

二进制编码也存在不同的实现方式。一种是利用 Church 有序列表实现，另一种是利用 Scott 风格的递归实现。本示例采用后一种实现方式。

Binary 自然数及相关运算实现在 [binary.lambda](binary.lambda) 中。

### Binary 自然数的构造

Scott 风格的二进制编码需要三个基本定义：

$$
\boxed{
\begin{aligned}
\mathrm{ZERO}_B &= \lambda z.\lambda e.\lambda o.z \\
\mathrm{EVEN}_B &= \lambda n.\lambda z.\lambda e.\lambda o.e\ n\\
\mathrm{ODD}_B &= \lambda n.\lambda z.\lambda e.\lambda o.o\ n
\end{aligned}
}
$$

这分别表示：

$$
\begin{aligned}
\mathrm{ZERO}_B &\to 0 \\
\mathrm{EVEN}_B\ k &\to 2k \\
\mathrm{ODD}_B\ k &\to 2k+1
\end{aligned}
$$

由此可以递归定义所有自然数：

$$
\begin{aligned}
0_B &= \mathrm{ZERO}_B \\
1_B &= \mathrm{ODD}_B(\mathrm{ZERO}_B) \\
2_B &= \mathrm{EVEN}_B(1_B) \\
3_B &= \mathrm{ODD}_B(1_B) \\
4_B &= \mathrm{EVEN}_B(2_B) \\
5_B &= \mathrm{ODD}_B(2_B) \\
6_B &= \mathrm{EVEN}_B(3_B) \\
7_B &= \mathrm{ODD}_B(3_B) \\
\end{aligned}
$$

如果把 $\mathrm{EVEN}_B$ 换成 $\mathrm{BIT}_0$，把 $\mathrm{ODD}_B$ 换成 $\mathrm{BIT}_1$，就得到了更为熟悉的二进制编码：

$$
\begin{aligned}
0_B &= \mathrm{ZERO}_B \\
1_B &= \mathrm{BIT}_1(\mathrm{ZERO}_B) \\
2_B &= \mathrm{BIT}_0(1_B) = \mathrm{BIT}_0(\mathrm{BIT}_1(\mathrm{ZERO}_B)) \\
3_B &= \mathrm{BIT}_1(1_B) = \mathrm{BIT}_1(\mathrm{BIT}_1(\mathrm{ZERO}_B)) \\
4_B &= \mathrm{BIT}_0(2_B) = \mathrm{BIT}_0(\mathrm{BIT}_0(\mathrm{BIT}_1(\mathrm{ZERO}_B))) \\
5_B &= \mathrm{BIT}_1(2_B) = \mathrm{BIT}_1(\mathrm{BIT}_0(\mathrm{BIT}_1(\mathrm{ZERO}_B))) \\
6_B &= \mathrm{BIT}_0(3_B) = \mathrm{BIT}_0(\mathrm{BIT}_1(\mathrm{BIT}_1(\mathrm{ZERO}_B))) \\
7_B &= \mathrm{BIT}_1(3_B) = \mathrm{BIT}_1(\mathrm{BIT}_1(\mathrm{BIT}_1(\mathrm{ZERO}_B))) \\
\end{aligned}
$$

这是从最低有效位到最高有效位的二进制表示，即最外层构造器是最低有效位，最内层构造器是最高有效位。可以往最高位增加任意数量的前导零，因为

$$
\begin{aligned}
    \mathrm{ZERO}_B
    &= 0 \\
    &= 2 \times 0 \\
    &= 2 \times 2 \times 0 \\
    &= 2 \times 2 \times \cdots \times 0 \\
    &= \mathrm{BIT}_0\ (\mathrm{BIT}_0\ (\cdots (\mathrm{ZERO}_B)))
\end{aligned}
$$

Scott 风格的二进制自然数同样可用于表示模式匹配：

- 当 $n=\mathrm{ZERO}_B$ 时，$n\ a\ b\ c$ 被归约为

    $$
    \begin{aligned}
    \mathrm{ZERO}_B\ a\ b\ c
    &= (\lambda z.\lambda e.\lambda o.z)\ a\ b\ c\\
    &\to a
    \end{aligned}
    $$

- 当 $n=\mathrm{EVEN}_B\ k$ 时，$n\ a\ b\ c$ 被归约为

    $$
    \begin{aligned}
    (\mathrm{EVEN}_B\ k)\ a\ b\ c
    &=((\lambda n.\lambda z.\lambda e.\lambda o.e\ n)\ k)\ a\ b\ c\\
    &\to(\lambda z.\lambda e.\lambda o.e\ k)\ a\ b\ c\\
    &\to b\ k
    \end{aligned}
    $$

- 当 $n=\mathrm{ODD}_B\ k$ 时，$n\ a\ b\ c$ 被归约为

    $$
    \begin{aligned}
    (\mathrm{ODD}_B\ k)\ a\ b\ c
    &=((\lambda n.\lambda z.\lambda e.\lambda o.o\ n)\ k)\ a\ b\ c\\
    &\to(\lambda z.\lambda e.\lambda o.o\ k)\ a\ b\ c\\
    &\to c\ k
    \end{aligned}
    $$

综上可知：

$$
\boxed{
n\ a\ b\ c
=
\begin{cases}
a & n=0 \\
b\ \frac{n}{2} & n>0 \land 2 \mid n \\
c\ \frac{n-1}{2} & n>0 \land 2 \nmid n
\end{cases}
}
$$

即 $n\ a\ b\ c$ 表示：

- 当 $n=0$ 时执行 $a$
- 当 $n>0$ 且 $n$ 为偶数时执行 $b\ \frac{n}{2}$
- 当 $n>0$ 且 $n$ 为奇数时执行 $c\ \frac{n-1}{2}$

### Binary 自然数的运算

实现 Binary 自然数运算的关键之处，就是将运算的结果按情况进行分类：

- 对于 $n=0$ 的情形，需要将结果表示为常量
- 对于 $n>0 \land 2 \mid n$ 的情形，需要将结果表示为以 $\frac{n}{2}$ 为参数的函数
- 对于 $n>0 \land 2 \nmid n$ 的情形，需要将结果表示为以 $\frac{n-1}{2}$ 为参数的函数

#### Binary 自然数的后驱

后继运算可以通过递归处理进位实现：

$$
\mathrm{succ}(n)
=
\begin{cases}
    1 & n=0 \\
    2 \frac{n}{2} + 1 & n>0 \land 2 \mid n \\
    2 \mathrm{succ}(\frac{n-1}{2}) & n>0 \land 2 \nmid n
\end{cases}
$$

#### Binary 自然数的前驱

前驱运算也可以通过递归处理进位实现：

$$
\mathrm{pred}(n)
=
\begin{cases}
    0 & n=0 \lor n=1 \\
    2 \mathrm{pred}(\frac{n}{2}) + 1 & n>0 \land 2 \mid n \\
    2 \frac{n-1}{2} & n>0 \land 2 \nmid n
\end{cases}
$$

#### Binary 自然数的加法

加法可递归表示为：

$$
\mathrm{add}(m,n)=
\begin{cases}
n & m=0 \\
m & n=0 \\
2\mathrm{add}(\frac{m}{2},\frac{n}{2}) & 2 \mid m \land 2 \mid n \\
2\mathrm{add}(\frac{m}{2},\frac{n-1}{2})+1 & 2 \mid m \land 2 \nmid n \\
2\mathrm{add}(\frac{m-1}{2},\frac{n}{2})+1 & 2 \nmid m \land 2 \mid n \\
2(\mathrm{add}(\frac{m-1}{2},\frac{n-1}{2})+1) & 2 \nmid m \land 2 \nmid n
\end{cases}
$$

#### Binary 自然数的减法

减法可递归表示为：

$$
\mathrm{sub}(m,n)=
\begin{cases}
0 & m<n \\
m & n=0 \\
2\mathrm{sub}(\frac{m}{2},\frac{n}{2}) & 2 \mid m \land 2 \mid n \\
2\mathrm{sub}(\frac{m}{2},\frac{n-1}{2})-1 & 2 \mid m \land 2 \nmid n \\
2\mathrm{sub}(\frac{m-1}{2},\frac{n}{2})+1 & 2 \nmid m \land 2 \mid n \\
2\mathrm{sub}(\frac{m-1}{2},\frac{n-1}{2}) & 2 \nmid m \land 2 \nmid n
\end{cases}
$$

#### Binary 自然数的乘法

乘法可递归表示为：

$$
\mathrm{mul}(m,n)=
\begin{cases}
0 & n=0 \\
2\mathrm{mul}(m,\frac{n}{2}) & 2 \mid n \\
2\mathrm{mul}(m,\frac{n-1}{2})+m & 2 \nmid n
\end{cases}
$$

#### Binary 自然数的除法

除法可递归表示为：

$$
\mathrm{div}(m,n)=
\begin{cases}
0 & n=0 \lor m<n \\
\mathrm{div}(m-n,n)+1 & n>0 \land m\ge n
\end{cases}
$$

## 比较并绘图

在仓库根目录运行：

```sh
uv run scripts/compare_binary.py examples/encoding/compare.json
```

每种运算生成两个表格和两张图片，分别为对角线采样和网格采样。

### 加法比较结果

得到的表格为：

[add-diag.csv](add-diag.csv)

[add-grid.csv](add-grid.csv)

得到的图片为：

![add-diag](add-diag.png)

![add-grid](add-grid.png)

可知对于加法，Church 自然数的归约效率比 Scott 自然数更好。

对于较大的数字，Binary 自然数有明显的优势；并且 Binary 自然数的归约步数并不完全单调。在对角线采样中，存在轻微的波动；而在网格采样中，可以看到热力图非常杂乱。这种波动主要发生在二进制的位边界，即当一个数是 $2^k-1$ 时，归约步数通常相比 $2^k$ 会略微变多。

### 乘法比较结果

得到的表格为：

[mul-diag.csv](mul-diag.csv)

[mul-grid.csv](mul-grid.csv)

得到的图片为：

![mul-diag](mul-diag.png)

![mul-grid](mul-grid.png)

可知对于乘法，Church 自然数的归约效率比 Scott 自然数更好。

对于较大的数字，Binary 自然数有明显的优势；并且 Binary 自然数的归约步数并不完全单调。在对角线采样中，存在明显的波动；而在网格采样中，可以看到热力图比较杂乱。这种波动主要发生在二进制的位边界，即当一个数是 $2^k-1$ 时，归约通常步数相比 $2^k$ 会显著变多。

### 减法比较结果

得到的表格为：

[sub-diag.csv](sub-diag.csv)

[sub-grid.csv](sub-grid.csv)

得到的图片为：

![sub-diag](sub-diag.png)

![sub-grid](sub-grid.png)

可知对于减法，Scott 自然数的归约效率比 Church 自然数更好。

对于较大的数字，Binary 自然数有明显的优势。

### 除法比较结果

得到的表格为：

[div-diag.csv](div-diag.csv)

[div-grid.csv](div-grid.csv)

得到的图片为：

![div-diag](div-diag.png)

![div-grid](div-grid.png)

可知对于除法，Scott 自然数的归约效率比 Church 自然数更好。

对于较大的数字，Binary 自然数有明显的优势。
