# 迭代

迭代器和列表的区别为：

- 列表是一种数据结构，关注数据如何组织
- 迭代器是一种行为抽象，关注数据如何遍历

区分列表和迭代器的核心目的，是将数据的存储结构与数据的访问逻辑解耦。

下面用一些例子展示二者的区别。

## 列表

标准库已经实现了 Church 列表和 Scott 列表。

### 范围

实现在 [range.lambda](range.lambda) 中。

`range a b` 返回从自然数 `a` 到自然数 `b` 的列表 $[a, b]$，如果 `a` 大于 `b` 则返回空列表。比如 `range 5 10` 返回 `[5, 6, 7, 8, 9, 10]`，而 `range 10 5` 返回空列表。

`range` 通过 `Y` 组合子构造递归来实现。每一步用 `CONS` 将当前值放到列表的头部，再用 `SUCC` 生成下一项。当前值超过上界时用 `NIL` 结束。

在仓库根目录运行：

```sh
lambda-compiler examples/iteration/range.lambda | ski-interpreter '--decode=list<natural>'
```

预期输出为 `[5, 6, 7, 8, 9, 10]`。

### 求和

实现在 [sum.lambda](sum.lambda) 中。

`sum a b` 返回从自然数 `a` 到自然数 `b` 的求和 $\sum_{n=a}^b n$，如果 `a` 大于 `b` 则返回零。比如 `sum 5 10` 返回 `45`，而 `sum 10 5` 返回 `0`。

`sum` 使用 `range` 生成列表，然后通过左折叠遍历列表进行求和。初始累计值是 `ZERO`，函数是 `ADD`。每一步都把累计值和当前元素传给 `ADD`，并把结果传给下一步。空列表直接返回初始值。

在仓库根目录运行：

```sh
lambda-compiler examples/iteration/sum.lambda | ski-interpreter --decode=natural
```

预期输出为 `45`。

## 迭代器

实现在 [iterator.lambda](iterator.lambda) 中。

迭代器包含两个接口：

- `iter list` 将 Church 列表转换为迭代器
- `next state onEnd onItem` 的返回值有两种情况：
  - 如果未到达迭代器末尾，则返回 `onItem item rest`，其中 `item` 是当前元素，`rest` 是剩余元素
  - 如果到达迭代器末尾，则返回 `onEnd`

其中：

- `iter` 使用 `FOLDR CONS_S NIL_S` 将 Church 列表转换为 Scott 列表。因为 Scott 列表直接表示了模式匹配，可以区分是否到达末尾，适合作为迭代器
- `next` 使用 `CASE_S` 处理空列表和非空列表，将首元素和尾列表传给调用方，调用方再把尾列表传给下一次 `next` 来推进遍历

### 点积

实现在 [dot.lambda](dot.lambda) 中。

`dot a b` 返回自然数有序列表 `a` 和自然数有序列表 `b` 的点积 $\vec{a} \cdot \vec{b}$。

`dot` 使用两个迭代器逐对取值并累加乘积。任一迭代器到达末尾时，剩余部分的点积为零。

在仓库根目录运行：

```sh
lambda-compiler examples/iteration/dot.lambda | ski-interpreter --decode=natural
```

预期输出为 `56`。

### 并集

实现在 [union.lambda](union.lambda) 中。

`union a b` 接收两个严格升序的自然数列表 `a` 和 `b`，然后返回 `a` 和 `b` 的并集 $a\cup b$，结果仍按升序排列。

`union` 比较两个迭代器的当前元素。两项不相等时，输出较小的元素并推进对应的一边。两项相等时，只输出一次并同时推进两边。任一边耗尽时，输出另一边的剩余元素。

在仓库根目录运行：

```sh
lambda-compiler examples/iteration/union.lambda | ski-interpreter '--decode=list<natural>'
```

预期输出为 `[1, 2, 3, 4, 5, 7]`。

### 交集

实现在 [intersection.lambda](intersection.lambda) 中。

`intersection a b` 接收两个严格升序的自然数列表 `a` 和 `b`，然后返回 `a` 和 `b` 的交集 $a\cap b$，结果仍按升序排列。

`intersection` 比较两个迭代器的当前元素。两项不相等时，只推进较小元素所在的一边。两项相等时，输出这个元素并同时推进两边。任一边耗尽时，交集的剩余部分为空列表。

在仓库根目录运行：

```sh
lambda-compiler examples/iteration/intersection.lambda | ski-interpreter '--decode=list<natural>'
```

预期输出为 `[4]`。
