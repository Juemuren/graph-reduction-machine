# 代码质量

## 格式化

Haskell 代码使用 fourmolu 进行格式化

```sh
cabal run fourmolu -- -i $(git ls-files '*.hs')
```

BNFC 文法规则中的 `::=` 可用脚本 [align-bnfc.py](../scripts/align-bnfc.py) 对齐

```sh
# 对齐
python scripts/align-bnfc.py
# 先预览再写入
python scripts/align-bnfc.py -p
```

## 静态检查

使用 hlint 进行静态检查

```sh
cabal run hlint -- $(git ls-files '*.hs')
```
