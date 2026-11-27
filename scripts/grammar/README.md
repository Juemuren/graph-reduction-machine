# 文法格式化

所有使用示例都是在仓库根目录运行。

## align-bnfc.py

使用示例：

```sh
python scripts/grammar/align-bnfc.py -g grammar/CoreLambda.cf
python scripts/grammar/align-bnfc.py -g grammar/CoreLambda.cf -p
```

脚本会：

1. 对齐 BNFC 文法规则中的标签、类别和 `::=`
2. 若启用预览且内容发生变化，则显示差异并等待确认
3. 将结果写回文件

各参数为：

- `-g` / `--grammar` 指定要对齐的文件
- `-p` / `--preview` 启用预览。默认不启用
