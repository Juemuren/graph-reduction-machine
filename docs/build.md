# 构建

项目使用 Cabal 进行构建。

构建整个项目

```sh
cabal build
```

安装所有可执行文件

```sh
cabal install
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
cabal build exe:lambda-compiler
```

安装编译器可执行文件

```sh
cabal install exe:lambda-compiler
```

## 构建解释器

构建解释器及其依赖

```sh
cabal build exe:ski-interpreter
```

安装解释器可执行文件

```sh
cabal install exe:ski-interpreter
```

## 构建语言服务器

构建语言服务器及其依赖

```sh
cabal build exe:graph-reduction-machine-lsp
```

安装语言服务器可执行文件

```sh
cabal install exe:graph-reduction-machine-lsp
```
