# 脚本

## compare_real.py

使用示例：

```sh
uv run scripts/compare_real.py examples/pi \
  --exact-value 3.1415926535897932384626433832795028841971693993751 \
  --max-index 2 --max-steps 20000000
```

脚本会

1. 将指定目录中的每个 `.lambda` 文件编译一次
2. 逐一解码从零到超过指定最大步数或超过指定最大索引的实数项
3. 根据传入的精确值计算误差
4. 写入 CSV 表格。表格包含 `method,n,steps,value,abs_error` 五列
5. 绘制 PNG 图片。图片使用对数坐标，包含各算法的收敛曲线、散点图和帕累托前沿

各参数为：

- `directory` 指定目录。是位置参数，无默认值
- `--max-index` 设置最大索引。默认为 `10`
- `--max-steps` 设置最大步数。默认为 `10000000`
- `--csv PATH` 指定输出的 CSV 文件。默认为 `directory/steps-vs-error.csv`
- `--plot PATH` 指定输出的 PNG 文件。默认为 `directory/steps-vs-error.png`
