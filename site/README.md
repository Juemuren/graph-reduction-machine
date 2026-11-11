# Graph Reduction Machine 站点

第一版是纯静态阅读站点。页面直接从仓库根目录的 `examples/`、`docs/`、`lib/` 和 `grammar/` 读取内容；不需要 Haskell 编译器或解释器。不要在 `site/` 另建手工维护的示例副本。

```sh
cd site
npm ci
npm run dev
```

生成可部署到静态文件托管服务的文件：

```sh
npm run build
npm test
```

输出位于 `site/dist/`。构建会检查 Markdown 相对链接，随后检查生成页面的站内链接与锚点。内容来源路径、参考文档列表和示例名称在 `src/config.ts` 中配置；增加示例目录后，只要包含 `README.md`，页面会按路径自动生成。源码页的语法高亮直接使用 `../vscode-extension/syntaxes/` 下的 TextMate 语法。

修改站点代码后，运行 `npm run check` 检查 TypeScript 和 Astro 类型，运行 `npm run lint` 检查 Biome；`npm run format` 格式化站点代码。
