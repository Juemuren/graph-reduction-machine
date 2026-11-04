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

Cabal 会调用 BNFC、Alex 和 Happy，根据语法定义分别生成并编译 Haskell 解析器。生成的源码不需要进行手工修改，也不提交仓库。

其中各语法源码生成的源码分别位于

| 语法文件                      | 源码目录               |
| ----------------------------- | ---------------------- |
| `grammar/CoreLambda.cf`       | `src/CoreLambda`       |
| `grammar/PureLambda.cf`       | `src/PureLambda`       |
| `grammar/Graph.cf`            | `src/Graph`            |

## 构建编译器

构建编译器及其依赖

```sh
cabal build exe:lambda-to-graph
```

## 构建解释器

构建解释器及其依赖

```sh
cabal build exe:ski-interpreter
```

## 构建处理器

首先在项目中安装安装 Clash

```sh
cabal build clash-ghc
cabal exec -- clash --version
```

<!-- TODO 处理器 -->
