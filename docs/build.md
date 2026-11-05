# 构建

项目使用 Cabal 进行构建。

构建整个项目

```sh
cabal build
```

## 构建的组织结构

项目能够构建的可执行文件包含：

- 编译器
- 解释器
- 语言服务器

解析器不单独提供可执行文件。运行任意构建前，[Setup.hs](../Setup.hs) 会调用 `bnfc` 生成解析器的源码。

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

## 构建语言服务器

构建语言服务器及其依赖

```sh
cabal build exe:graph-reduction-machine-lsp
```

<!-- TODO ## 构建处理器

首先在项目中安装安装 Clash

```sh
cabal build clash-ghc
cabal exec -- clash --version
```

-->
