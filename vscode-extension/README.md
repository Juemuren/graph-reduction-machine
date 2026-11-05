# 图归约机语言服务

此 VS Code 扩展为仓库中的两种语言提供语言服务。

## 功能

### 核心 λ

语法定义见 `grammar/CoreLambda.cf`。

文件扩展名为 `.lambda`。提供的功能包括

- 语法高亮：支持模块指令、定义、λ 抽象、内置函数、字符串和 `#` 注释
- 自动补全：提示当前文件的定义、导入的名称，以及当前函数体内可见的参数；暂不提示内置函数
- 悬停文档：显示当前文件中名称的定义，或显示导入该名称的路径

### SKI 图

语法定义见 `grammar/Ski.cf`。

文件扩展名为 `.ski`。提供的功能包括

- 语法高亮：支持节点定义、节点引用、组合子和 `--` 注释
- 自动补全：输入 `#` 后会提示当前文件中已定义的节点编号
- 悬停文档：将鼠标悬停在节点编号上会显示该节点的定义

## 安装

在本目录运行：

```sh
npm ci
npm run package
code --install-extension graph-reduction-machine-syntax-0.3.0.vsix
```

## 测试

在本目录运行：

```sh
npm test
```

测试只检查核心 λ 与 SKI 图的补全和悬停功能。

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
