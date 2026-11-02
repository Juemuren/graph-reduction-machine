# 构建

项目使用 Cabal 进行构建。

构建整个项目

```sh
cabal build
```

## 构建解析器

解析器不支持单独构建

```sh
cabal build
```

Cabal 会调用 BNFC、Alex 和 Happy，根据 `grammar/Lambda.cf` 和 `grammar/Graph.cf` 分别生成并编译 Haskell 解析器。

生成的源码分别保存在 `src/Lambda` 和 `src/Graph` 下，不需要进行手工修改，也不提交仓库。

## 构建编译器

构建编译器及其依赖

```sh
cabal build exe:lambda-to-graph
```

测试所有用例

```sh
cabal test compiler-tests
```