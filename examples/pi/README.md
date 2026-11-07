# PI 构造算法比较

## Machin 构造

第 $n$ 项为：

$$
\boxed{
a_n=
16\sum_{k=0}^{n}\frac{(-1)^k}{(2k+1)5^{2k+1}}
-
4\sum_{k=0}^{n}\frac{(-1)^k}{(2k+1)239^{2k+1}}
}
$$

实现在 [arctan.lambda](arctan.lambda) 中。

## Leibniz 构造

第 $n$ 项为：

$$
\boxed{
a_n=4\sum_{k=0}^{n}\frac{(-1)^k}{2k+1}
}
$$

实现在 [leibniz.lambda](leibniz.lambda) 中。

## 正多边形构造

第 $n$ 项为：

$$
\boxed{
a_n=2^n\sin\frac{\pi}{2^n}
}
$$

实现在 [polygon.lambda](polygon.lambda) 中。

## 比较并绘图

在仓库根目录运行：

```sh
uv run scripts/compare_real.py examples/pi \
  --exact-value 3.1415926535897932384626433832795028841971693993751 \
  --max-index 10 --max-steps 1000000
```
