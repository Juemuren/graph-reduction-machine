# 图归约机演示站点

这是项目的静态站点，目前包含以下功能：

1. 在线阅读示例、参考文档和源代码
2. 在线编辑、编译和解释核心 λ 与 SKI 图源码
3. 在线编辑器提供核心 λ 和 SKI 图的语言服务

站点的完整计划见 [website.md](../docs/website.md)。

## 任务

此处的命令均在本目录运行。

先完成依赖的安装：

```sh
deno install
```

### 开发

```sh
deno task dev
```

该任务会启动本地开发服务器。

### 预览

```sh
deno task preview
```

该任务会启动本地预览服务器。

### 构建

```sh
deno task build
```

该任务会将生成的站点文件和索引文件保存在 `dist/` 中。

索引文件可以单独构建

```sh
deno task build:search
```

本地验证搜索功能需要先完成构建，再运行 `deno task preview`；运行 `deno task dev` 不会构建搜素索引。

WASM 需要另外准备工具链，详见 [#演练](#演练) 。准备完成后运行

```sh
deno task build:wasm
```

WASM 文件会生成到 `public/playground/` 中。

### 测试

```sh
deno task test
```

该任务会读取 `dist/` 中的文件，检查生成页面的内容、链接和锚点。

因此运行测试前需要先完成构建。

### 类型检查

```sh
deno task typecheck
```

该任务会同时运行 Astro 和 Deno 的类型检查

- Astro 检查 `src/` 中的代码
- Deno 检查 `src/`、`test/` 中的代码

### 静态检查和格式化

```sh
deno task check
```

该任务会同时运行 Biome 和 Deno 的静态检查和格式化

- Biome 检查 `src/`、`astro.config.ts`、`biome.json`、`tsconfig.json` 中的代码，格式化 `src/`、`astro.config.ts`、`biome.json`、`tsconfig.json` 中的代码
- Deno 检查 `src/`、`test/`、`deno.json` 中的代码，格式化 `test/`、`deno.json` 中的代码

### 完整验证

```sh
deno task verify
```

该任务会依次运行类型检查、静态检查和格式化、构建、测试。

## 内容

站点内容来自：

- 示例来自 `examples/`
- 文档来自 `docs/`
- 标准库实现来自 `lib/`
- 语法定义来自 `grammar/`
- 代码高亮来自 `vscode-extension/syntaxes/`

参考文档列表和示例顺序在 `src/config.ts` 中配置。

新增示例目录只要包含 `README.md`，构建时就会生成对应页面。

## 演练

关于构建：

1. 安装 <https://github.com/haskell-wasm/ghc-wasm-meta> 和 `bnfc` / `alex` / `happy`
2. 运行 `deno task build:wasm`。

关于会话：

1. 演练的当前文件是运行入口，可以添加文件到同一会话中，以进行导入和导出
2. 会话保存在当前页面内，打开示例会开始一个新的会话

关于限制：

1. 单次运行和单个语言服务请求的时限均为 10 秒，含加载运行时的时间
2. 每个 WebAssembly 实例的线性内存上限为 256 MiB；GHC 堆上限为 128 MiB，栈上限为 32 MiB
3. 会话源码总量上限为 1 MiB，单个命令的标准输出和标准错误各有 2 MiB 上限

## 样式

- 主题变量放在 `src/styles/theme.css`，颜色优先引用主题变量
- 全局样式放在 `src/styles/global.css`，由 `src/layouts/Base.astro` 引入
- 页面或组件的局部样式仍写在各自的 `<style>` 中

## 部署

持续集成时用 `deno ci` 从锁文件 `deno.lock` 中安装依赖。

GitHub Pages 工作流在 PR 中运行检查，在推送到 `main` 时构建并部署到 `https://Juemuren.github.io/graph-reduction-machine/`。部署时设置 `SITE_BASE=/graph-reduction-machine` 以生成带仓库前缀的链接。
