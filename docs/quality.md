# 代码质量

## BNFC

BNFC 文法规则中的 `::=` 可用脚本 [align-bnfc.py](../scripts/grammar/align-bnfc.py) 对齐

```sh
python scripts/grammar/align-bnfc.py -g grammar/CoreLambda.cf
```

## Haskell

Haskell 代码使用 fourmolu 进行格式化

```sh
cabal run fourmolu -- -i $(git ls-files '*.hs')
```

Haskell 代码使用 hlint 进行静态检查

```sh
cabal run hlint -- $(git ls-files '*.hs')
```

## Web

`site` 下的代码使用 Deno + Astro 进行类型检查

```sh
cd site; deno task typecheck
```

`site` 下的代码使用 Deno + Biome 进行静态检查和格式化

```sh
cd site; deno task check
```

