# 图归约机语言服务

此 VS Code 扩展为仓库中的两种语言提供语言服务。

## 功能

### 核心 λ

语法定义见 [grammar/CoreLambda.cf](../grammar/CoreLambda.cf)。

文件扩展名为 `.lambda`。提供的功能包括

- 语法高亮：支持模块指令、定义、λ 抽象、内置函数、字符串和 `#` 注释

### SKI 图

语法定义见 [grammar/Ski.cf](../grammar/Ski.cf)。

文件扩展名为 `.ski`。提供的功能包括

- 语法高亮：支持节点定义、节点引用、组合子和 `--` 注释
- 自动补全：输入 `#` 后会提示当前文件中已定义的节点编号
- 悬停文档：将鼠标悬停在节点编号上会显示该节点的定义

## 安装

在本目录运行：

```sh
npm ci
npm run package
code --install-extension *.vsix
```
