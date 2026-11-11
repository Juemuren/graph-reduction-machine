import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import { parse } from "@std/csv";
import rehypeKatex from "rehype-katex";
import rehypeSlug from "rehype-slug";
import rehypeStringify from "rehype-stringify";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import { unified } from "unified";
import { exampleOrder, referenceDocs, root } from "../config";
import { sitePath } from "./urls";

export interface Example {
  slug: string;
  label: string;
  files: string[];
  sources: string[];
  images: string[];
  data: string[];
  compare: boolean;
}

export interface TocEntry {
  id: string;
  text: string;
  level: number;
}

interface HeadingNode {
  type: string;
  tagName?: string;
  value?: string;
  properties?: { id?: string };
  children?: HeadingNode[];
}

interface MarkdownNode {
  type: string;
  url?: string;
  value?: string;
  children?: MarkdownNode[];
  data?: { hProperties?: { dataCsvRows: number } };
}

interface HtmlNode {
  type: string;
  tagName?: string;
  properties?: { dataCsvRows?: number; className?: string[] };
  children?: HtmlNode[];
  value?: string;
}

function collapseCsvTables() {
  return (tree: HtmlNode) => {
    const visit = (node: HtmlNode) => {
      if (!node.children) return;
      node.children = node.children.map((child) => {
        visit(child);
        const rows = child.properties?.dataCsvRows;
        if (child.tagName !== "table" || typeof rows !== "number") return child;
        delete child.properties?.dataCsvRows;
        return {
          type: "element",
          tagName: "details",
          properties: { className: ["csv-table-details"] },
          children: [
            {
              type: "element",
              tagName: "summary",
              properties: {},
              children: [{ type: "text", value: `查看表格（${rows} 行）` }],
            },
            child,
          ],
        };
      });
    };
    visit(tree);
  };
}

function renderCsvLinks(sourcePath: string) {
  return () => async (tree: MarkdownNode) => {
    const visit = async (node: MarkdownNode) => {
      if (!node.children) return;
      const children: MarkdownNode[] = [];
      for (const child of node.children) {
        await visit(child);
        children.push(child);
        if (child.type !== "paragraph") continue;
        for (const link of child.children ?? []) {
          if (
            link.type !== "link" ||
            !link.url ||
            /^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(link.url)
          )
            continue;
          const target = link.url.split(/[?#]/, 1)[0];
          if (!target.toLowerCase().endsWith(".csv")) continue;
          const resolved = path.posix.normalize(
            path.posix.join(
              path.posix.dirname(sourcePath),
              decodeURIComponent(target),
            ),
          );
          if (resolved.startsWith("../") || path.posix.isAbsolute(resolved))
            throw new Error(`链接越过仓库: ${sourcePath} -> ${link.url}`);
          const rows = parse(
            (await readSource(resolved)).replace(/^\uFEFF/, ""),
            {
              fieldsPerRecord: 0,
            },
          );
          if (rows.length === 0) continue;
          children.push({
            type: "table",
            data: { hProperties: { dataCsvRows: rows.length - 1 } },
            children: rows.map((cells) => ({
              type: "tableRow",
              children: cells.map((value) => ({
                type: "tableCell",
                children: [{ type: "text", value }],
              })),
            })),
          });
        }
      }
      node.children = children;
    };
    await visit(tree);
  };
}

function headingText(node: HeadingNode): string {
  if (node.type === "text") return node.value ?? "";
  return (node.children ?? []).map(headingText).join("");
}

function collectHeadings(headings: TocEntry[]) {
  return () => (tree: HeadingNode) => {
    const visit = (node: HeadingNode) => {
      const match = /^h([2-6])$/.exec(node.tagName ?? "");
      const id = node.properties?.id;
      if (match && id) {
        headings.push({ id, text: headingText(node), level: Number(match[1]) });
      }
      node.children?.forEach(visit);
    };
    visit(tree);
  };
}

const scan = async (relative: string) =>
  (await readdir(path.join(root, relative), { withFileTypes: true }))
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name)
    .sort();

export async function examples(): Promise<Example[]> {
  const entries = await readdir(path.join(root, "examples"), {
    withFileTypes: true,
  });
  const available = entries.filter((entry) => entry.isDirectory());
  return Promise.all(
    available.map(async ({ name }) => {
      const files = await scan(`examples/${name}`);
      if (!files.includes("README.md")) return null;
      return {
        slug: name,
        label: titleOf(await readSource(`examples/${name}/README.md`)),
        files,
        sources: files.filter((file) => /\.(lambda|ski)$/.test(file)),
        images: files.filter((file) => file.endsWith(".png")),
        data: files.filter((file) => file.endsWith(".csv")),
        compare: files.includes("compare.json"),
      };
    }),
  ).then((items) =>
    items
      .filter((item): item is Example => item !== null)
      .sort((a, b) => {
        const position = (slug: string) => {
          const index = exampleOrder.indexOf(slug);
          return index === -1 ? Number.MAX_SAFE_INTEGER : index;
        };
        return (
          position(a.slug) - position(b.slug) || a.slug.localeCompare(b.slug)
        );
      }),
  );
}

export async function librarySources() {
  return (await scan("lib")).filter((file) => file.endsWith(".lambda"));
}

export async function assetFiles() {
  const all = (await examples()).flatMap((example) =>
    example.files
      .filter((file) => /\.(lambda|ski|png|csv|json)$/.test(file))
      .map((file) => `examples/${example.slug}/${file}`),
  );
  all.push(...(await librarySources()).map((file) => `lib/${file}`));
  all.push(
    ...(await scan("grammar"))
      .filter((file) => file.endsWith(".cf"))
      .map((file) => `grammar/${file}`),
  );
  return all;
}

export function readSource(relative: string) {
  return readFile(path.join(root, relative), "utf8");
}

export function titleOf(markdown: string) {
  return markdown.match(/^#\s+(.+)$/m)?.[1] || "文档";
}

export function routeFor(relative: string) {
  const normalized = relative.replaceAll("\\", "/");
  if (/^examples\/[^/]+\/README\.md$/.test(normalized))
    return `/${normalized.replace(/\/README\.md$/, "")}/`;
  if (/^examples\/[^/]+\/[^/]+\.(lambda|ski)$/.test(normalized))
    return `/${normalized}/`;
  if (/^docs\/[^/]+\.md$/.test(normalized))
    return `/docs/${path.posix.basename(normalized, ".md")}/`;
  if (/^lib\/[^/]+\.lambda$/.test(normalized)) return `/${normalized}/`;
  return `/assets/${normalized}`;
}

function rewriteLinks(sourcePath: string) {
  return () => async (tree: { type: string; children?: unknown[] }) => {
    const visit = async (node: {
      type: string;
      url?: string;
      children?: unknown[];
    }) => {
      if (
        (node.type === "link" || node.type === "image") &&
        node.url &&
        !/^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(node.url)
      ) {
        const [beforeHash, fragment = ""] = node.url.split("#", 2);
        const [target, query = ""] = beforeHash.split("?", 2);
        const resolved = path.posix.normalize(
          path.posix.join(
            path.posix.dirname(sourcePath),
            decodeURIComponent(target),
          ),
        );
        if (resolved.startsWith("../") || path.posix.isAbsolute(resolved))
          throw new Error(`链接越过仓库: ${sourcePath} -> ${node.url}`);
        try {
          await stat(path.join(root, resolved));
        } catch {
          throw new Error(`断链: ${sourcePath} -> ${node.url}`);
        }
        if (
          resolved.startsWith("docs/") &&
          resolved.endsWith(".md") &&
          !referenceDocs.includes(path.posix.basename(resolved, ".md"))
        )
          throw new Error(`文档尚未纳入站点: ${sourcePath} -> ${node.url}`);
        node.url =
          sitePath(routeFor(resolved)) +
          (query ? `?${query}` : "") +
          (fragment ? `#${fragment}` : "");
      }
      if (node.children)
        await Promise.all(
          node.children.map((child) => visit(child as typeof node)),
        );
    };
    await visit(tree);
  };
}

export async function renderMarkdown(sourcePath: string) {
  const markdown = await readSource(sourcePath);
  const toc: TocEntry[] = [];
  const result = await unified()
    .use(remarkParse)
    .use(remarkGfm)
    .use(remarkMath)
    .use(renderCsvLinks(sourcePath))
    .use(rewriteLinks(sourcePath))
    .use(remarkRehype)
    .use(collapseCsvTables)
    .use(rehypeSlug)
    .use(collectHeadings(toc))
    .use(rehypeKatex)
    .use(rehypeStringify)
    .process(markdown);
  return { title: titleOf(markdown), html: String(result), toc };
}
