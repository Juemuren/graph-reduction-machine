# 图归约机演示站点

这是项目的静态阅读站点，用于展示示例、参考文档和源代码。

站点的完整计划见 [website.md](../docs/website.md)。

## 文件依赖

此处的目录均为仓库根目录：

- 示例来自 `examples/`
- 文档来自 `docs/`
- 标准库实现来自 `lib/`
- 语法定义来自 `grammar/`
- 代码高亮来自 `vscode-extension/syntaxes/`

站点不需要 Haskell 运行环境，也不维护这些内容的副本。

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

### 构建

```sh
deno task build
```

该任务会将生成的站点文件保存在 `dist/` 中。

构建完成后会自动检查页面中的链接和锚点。

### 测试

```sh
deno task test
```

该任务会读取 `dist/` 中的文件。

因此运行测试前需要先完成构建。

### 类型检查

```sh
deno task typecheck
```

该任务会同时运行 Astro 和 Deno 的类型检查

- Astro 检查 `src/` 中的代码
- Deno 检查 `src/`、`scripts/`、`test/` 中的代码

### 静态检查和格式化

```sh
deno task check
```

该任务会同时运行 Biome 和 Deno 的静态检查和格式化

- Biome 检查 `src/`、`astro.config.ts`、`biome.json`、`tsconfig.json` 中的代码，格式化 `src/`、`astro.config.ts`、`biome.json`、`tsconfig.json` 中的代码
- Deno 检查 `src/`、`scripts/`、`test/`、`deno.json` 中的代码，格式化 `scripts/`、`test/`、`deno.json` 中的代码

### 完整验证

```sh
deno task verify
```

该任务会依次运行类型检查、静态检查和格式化、构建、测试。

## 内容

参考文档列表和示例顺序在 `src/config.ts` 中配置。

新增示例目录只要包含 `README.md`，构建时就会生成对应页面。

## 样式

Catppuccin Latte / Mocha 色板和可复用的 CSS 变量放在 `src/styles/theme.css`。公共样式放在 `src/styles/global.css`，由它引入主题变量；`src/layouts/Base.astro` 只需引入全局样式。亮暗模式跟随系统的 `prefers-color-scheme`。页面或组件的局部布局仍可写在各自的 `<style>` 中，颜色优先引用主题变量。

## 部署

GitHub Pages 工作流在 PR 中运行检查，在推送到 `main` 时构建并部署到 `https://Juemuren.github.io/graph-reduction-machine/`。

启用前，需要在仓库的 **Settings → Pages → Build and deployment → Source** 中选择 **GitHub Actions**。

部署时设置 `SITE_BASE=/graph-reduction-machine`，用于生成带仓库前缀的链接。

依赖版本在 `deno.json` 中配置；修改依赖时同步提交 `deno.lock`。CI 使用 `deno ci` 从锁文件安装。
