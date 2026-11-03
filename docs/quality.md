# 代码质量

## 格式化

Haskell 代码使用 fourmolu 进行格式化

```sh
cabal run fourmolu -- -i $(git ls-files '*.hs')
```

BNFC 文法规则中的 `::=` 可用项目脚本对齐。脚本使用 awk，预览功能需要 delta 和 gum

```sh
# 对齐
sh scripts/align-bnfc.sh
# 先预览再写入
sh scripts/align-bnfc.sh -p
```

## 静态检查

使用 hlint 进行静态检查

```sh
cabal run hlint -- $(git ls-files '*.hs')
```
