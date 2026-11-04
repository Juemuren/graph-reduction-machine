# 图归约机语法高亮

## 功能

此 VS Code 扩展为仓库中的两种语言提供语法高亮：

- `.lambda`：核心 λ，支持模块指令、定义、λ 抽象、内置函数、字符串和 `#` 注释。语法定义见 [grammar/CoreLambda.cf](../grammar/CoreLambda.cf)
- `.ski`：SKI 图，支持节点定义、节点引用、组合子和 `--` 注释。语法定义见 [grammar/Ski.cf](../grammar/Ski.cf)

## 安装

在本目录运行：

```sh
npm ci
npm run package
code --install-extension *.vsix
```
