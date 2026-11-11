# Graph Reduction Machine 站点

第一版是纯静态阅读站点。页面直接从仓库根目录的 `examples/`、`docs/`、`lib/` 和 `grammar/` 读取内容；不需要 Haskell 编译器或解释器。不要在 `site/` 另建手工维护的示例副本。

```sh
cd site
deno install
deno task dev
```

生成可部署到静态文件托管服务的文件：

```sh
deno task build
deno task test
```

输出位于 `site/dist/`。构建会检查 Markdown 相对链接，随后检查生成页面的站内链接与锚点。内容来源路径、参考文档列表和示例名称在 `src/config.ts` 中配置；增加示例目录后，只要包含 `README.md`，页面会按路径自动生成。源码页的语法高亮直接使用 `../vscode-extension/syntaxes/` 下的 TextMate 语法。

GitHub Pages 从 `main` 分支的推送自动部署到 `https://Juemuren.github.io/graph-reduction-machine/`。先在仓库的 **Settings → Pages → Build and deployment → Source** 选择 **GitHub Actions**。PR 只运行检查；部署构建使用 `SITE_BASE=/graph-reduction-machine`，以生成带仓库前缀的内部链接。

修改站点代码后，运行 `deno task verify` 完成类型检查、Biome 检查、构建和测试；`deno task format` 格式化站点代码。依赖版本统一在 `deno.json` 中配置；提交依赖变更时同步提交 `deno.lock`。CI 使用 `deno ci` 从锁文件安装。
