# 脚本

## compare_real.py

使用示例（在仓库根目录运行）：

```sh
uv run scripts/compare_real.py examples/pi \
  --exact-value 3.1415926535897932384626433832795028841971693993751 \
  --max-index 10 --max-steps 1000000
```

脚本会：

1. 将指定目录中的每个 `.lambda` 文件编译一次
2. 为从零到最大索引且不超过最大步数的每个索引作为自然数下标解码实数
3. 根据传入的精确值计算误差
4. 写入 CSV 表格
5. 绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value,abs_error` 五列
- 图片使用对数坐标，以归约步数作为对数横轴，误差作为对数纵轴。图片包含各算法的收敛曲线、散点图和帕累托前沿

各参数为：

- `directory` 指定目录。是位置参数，必填
- `--exact-value` 指定精确值。必填
- `--max-index` 设置最大索引。默认为 `10`
- `--max-steps` 设置最大步数。默认为 `1000000`
- `--csv PATH` 指定输出的 CSV 文件。默认为 `directory/steps-vs-error.csv`
- `--plot PATH` 指定输出的 PNG 文件。默认为 `directory/steps-vs-error.png`

## compare_index.py

使用示例（在仓库根目录运行）：

```sh
uv run scripts/compare_index.py examples/fibonacci \
  --function fib --decode natural \
  --max-index 10 --max-steps 1000000
```

脚本会：

1. 逐个导入指定目录中每个 `.lambda` 文件导出的指定函数
2. 为从零到最大索引且不超过最大步数的每个索引生成程序入口并编译和解码
3. 写入 CSV 表格
4. 绘制 PNG 图片

各输出为：

- 表格包含 `method,n,steps,value` 四列
- 图片使用半对数坐标，以索引为线性横轴，归约步数为对数纵轴。图片包含各算法的收敛曲线和散点图

各参数为：

- `directory` 指定目录。是位置参数，必填
- `--function NAME` 指定各算法共同导出的函数名，必填
- `--decode MODE` 指定解码方式，默认为 `natural`
- `--max-index` 设置最大索引，默认为 `10`
- `--max-steps` 设置每次解码的最大归约步数，默认为 `1000000`
- `--csv PATH` 指定输出的 CSV 文件。默认为 `directory/index-vs-error.csv`
- `--plot PATH` 指定输出的 PNG 文件。默认为 `directory/index-vs-error.png`
