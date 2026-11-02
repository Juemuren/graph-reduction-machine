# 代码质量

## 格式化

使用 fourmolu 进行格式化

```sh
cabal run fourmolu -- -i $(git ls-files '*.hs')
```

## 静态检查

使用 hlint 进行静态检查

```sh
cabal run hlint -- $(git ls-files '*.hs')
```
