# 图归约机语言服务

此 VS Code 扩展为仓库中的两种语言提供语言服务。

## 功能

### 核心 λ

语法定义见 `grammar/CoreLambda.cf`。

文件扩展名为 `.lambda`。提供的功能包括

- 语法高亮：支持模块指令、定义、λ 抽象、内置函数、字符串和 `#` 注释
- 语义高亮：支持区分定义和参数并分别高亮
- 补全：提示当前文件的定义、导入的名称，以及当前函数体内可见的参数；暂不提示内置函数
- 悬停：显示当前文件中名称的定义，或显示导入该名称的路径

### SKI 图

语法定义见 `grammar/Ski.cf`。

文件扩展名为 `.ski`。提供的功能包括

- 语法高亮：支持节点定义、节点引用、组合子和 `--` 注释
- 补全：输入 `#` 后会提示当前文件中已定义的节点编号
- 悬停：将鼠标悬停在节点编号上会显示该节点的定义

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

## 测试

在仓库根目录运行：

```sh
cabal test language-server-tests
```

## 代码质量

在本目录运行：

```sh
# 类型检查
npm run typecheck
# 格式化
npm run format
# 静态检查
npm run lint
# 格式化 + 静态检查
npm run check
```
