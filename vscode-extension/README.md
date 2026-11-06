# 图归约机语言服务

此 VS Code 扩展为仓库中的两种语言提供语言服务。

## 功能

### 核心 λ

语法定义见 `grammar/CoreLambda.cf`。

文件扩展名为 `.lambda`。提供的功能包括

- 语法高亮：识别导入、导出、程序入口、定义、参数、内置函数、字符串和注释
- 语义高亮：识别定义和参数并分别高亮
- 补全：支持补全可见参数、本地定义、导入名称和标准库名称
- 悬停：支持显示本地、导入和标准库名称的定义
- 导航：支持跳转到定义、查找引用和文档符号
- 重构：支持对定义和参数进行重命名
- 诊断：提示语法错误、重复名称和未定义名称

### SKI 图

语法定义见 `grammar/Ski.cf`。

文件扩展名为 `.ski`。提供的功能包括

- 语法高亮：识别节点定义、节点引用、组合子和注释
- 补全：支持补全当前文件中已定义的节点编号
- 悬停：支持显示节点的定义
- 导航：支持跳转到定义、查找引用和文档符号
- 重构：支持对节点进行重命名
- 诊断：提示语法错误、重复节点、未定义节点和缺失根节点

## 安装

先在仓库根目录安装语言服务器：

```sh
cabal install exe:graph-reduction-machine-lsp
```

然后重启 VS Code 编辑器，确保 `graph-reduction-machine-lsp` 位于 VS Code 集成终端的 `PATH` 中：

```sh
# bash
which graph-reduction-machine-lsp
# pwsh
gcm graph-reduction-machine-lsp
```

最后在本目录打包并安装编辑器扩展：

```sh
npm ci
npm run package
code --install-extension graph-reduction-machine-syntax-0.3.0.vsix
```

如果在 `PATH` 中找不到 `graph-reduction-machine-lsp`，那么扩展只提供语法高亮功能。
