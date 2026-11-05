import {
  type CompletionItem,
  CompletionItemKind,
  type Hover,
  MarkupKind,
  type Position,
} from 'vscode-languageserver/node';
import type { TextDocument } from 'vscode-languageserver-textdocument';

type Token = { kind: 'name' | 'string' | 'symbol'; text: string; start: number; end: number };
type Span = { start: number; end: number };
type Declaration = {
  name: string;
  token: Token;
  description: string;
  kind: 'definition' | 'import';
};
type Parameter = { name: string; token: Token; bodyStart: number; bodyEnd: number };
type Analysis = {
  tokens: Token[];
  excluded: Span[];
  declarations: Declaration[];
  parameters: Parameter[];
  expressions: Span[];
};

function scan(source: string): Pick<Analysis, 'tokens' | 'excluded'> {
  const tokens: Token[] = [];
  const excluded: Span[] = [];
  let index = 0;

  while (index < source.length) {
    const start = index;
    const character = source[index];
    if (character === '#') {
      while (index < source.length && source[index] !== '\r' && source[index] !== '\n') index++;
      excluded.push({ start, end: index });
    } else if (character === '"') {
      index++;
      while (index < source.length) {
        if (source[index] === '\\') index += 2;
        else if (source[index++] === '"') break;
      }
      index = Math.min(index, source.length);
      tokens.push({ kind: 'string', text: source.slice(start, index), start, end: index });
      excluded.push({ start, end: index });
    } else if (/[A-Za-z]/.test(character)) {
      index++;
      while (index < source.length && /[A-Za-z0-9_]/.test(source[index])) index++;
      tokens.push({ kind: 'name', text: source.slice(start, index), start, end: index });
    } else {
      const directive = source.slice(index, index + 2);
      if (directive === '@<' || directive === '@>' || directive === '@!' || directive === '->') {
        index += 2;
      } else if ('=;(),\\'.includes(character)) {
        index++;
      } else {
        index++;
        continue;
      }
      tokens.push({ kind: 'symbol', text: source.slice(start, index), start, end: index });
    }
  }
  return { tokens, excluded };
}

function analyze(document: TextDocument): Analysis {
  const source = document.getText();
  const { tokens, excluded } = scan(source);
  const declarations: Declaration[] = [];
  const expressions: Span[] = [];
  let statementStart = 0;

  function statement(statementTokens: Token[], end: number, expressionEnd: number): void {
    if (statementTokens.length === 0) return;
    const first = statementTokens[0];
    if (first.text === '@<') {
      const path = statementTokens[1];
      const open = statementTokens.findIndex((token) => token.text === '(');
      const close = statementTokens.findIndex((token, index) => index > open && token.text === ')');
      if (path?.kind === 'string' && open >= 0 && close > open) {
        for (const token of statementTokens.slice(open + 1, close)) {
          if (token.kind === 'name') {
            declarations.push({
              name: token.text,
              token,
              description: `Imported ${token.text} from ${path.text}`,
              kind: 'import',
            });
          }
        }
      }
      return;
    }

    const directive = first.text === '@>' || first.text === '@!';
    const head = directive ? statementTokens[1] : first;
    const equals = directive ? statementTokens[2] : statementTokens[1];
    if (head?.kind === 'name' && equals?.text === '=') {
      declarations.push({
        name: head.text,
        token: head,
        description: source.slice(first.start, end).trim(),
        kind: 'definition',
      });
      expressions.push({ start: equals.end, end: expressionEnd });
    } else if (first.text === '@!') {
      expressions.push({ start: first.end, end: expressionEnd });
    } else if (first.text !== '@>') {
      expressions.push({ start: first.start, end: expressionEnd });
    }
  }

  for (let index = 0; index < tokens.length; index++) {
    if (tokens[index].text === ';') {
      statement(tokens.slice(statementStart, index), tokens[index].end, tokens[index].start);
      statementStart = index + 1;
    }
  }
  statement(tokens.slice(statementStart), source.length, source.length);

  const parameters: Parameter[] = [];
  for (const expression of expressions) {
    const expressionTokens = tokens.filter(
      (token) => expression.start <= token.start && token.start < expression.end,
    );
    for (let index = 0; index + 2 < expressionTokens.length; index++) {
      const slash = expressionTokens[index];
      const name = expressionTokens[index + 1];
      const arrow = expressionTokens[index + 2];
      if (
        slash.text !== '\\' ||
        name.kind !== 'name' ||
        !/^[a-z]/.test(name.text) ||
        arrow.text !== '->'
      )
        continue;

      let depth = 0;
      let bodyEnd = expression.end;
      for (const token of expressionTokens.slice(index + 3)) {
        if (token.text === '(') depth++;
        else if (token.text === ')') {
          if (depth === 0) {
            bodyEnd = token.start;
            break;
          }
          depth--;
        }
      }
      parameters.push({ name: name.text, token: name, bodyStart: arrow.end, bodyEnd });
    }
  }

  return { tokens, excluded, declarations, parameters, expressions };
}

function activeParameters(parameters: Parameter[], offset: number): Parameter[] {
  return parameters
    .filter((parameter) => parameter.bodyStart <= offset && offset <= parameter.bodyEnd)
    .sort((left, right) => right.token.start - left.token.start);
}

export function completeCoreLambda(document: TextDocument, position: Position): CompletionItem[] {
  const source = document.getText();
  const offset = document.offsetAt(position);
  const analysis = analyze(document);
  if (analysis.excluded.some((span) => span.start <= offset && offset < span.end)) return [];
  if (!analysis.expressions.some((span) => span.start <= offset && offset <= span.end)) return [];

  let start = offset;
  let end = offset;
  while (start > 0 && /[A-Za-z0-9_]/.test(source[start - 1])) start--;
  while (end < source.length && /[A-Za-z0-9_]/.test(source[end])) end++;
  const prefix = source.slice(start, offset);
  if (prefix && !/^[A-Za-z][A-Za-z0-9_]*$/.test(prefix)) return [];
  const range = { start: document.positionAt(start), end: document.positionAt(end) };

  const seen = new Set<string>();
  const items: CompletionItem[] = [];
  function add(name: string, description: string): void {
    if (seen.has(name) || !name.startsWith(prefix)) return;
    seen.add(name);
    items.push({
      label: name,
      kind: CompletionItemKind.Variable,
      detail: description,
      textEdit: { range, newText: name },
    });
  }
  for (const parameter of activeParameters(analysis.parameters, offset))
    add(parameter.name, 'Parameter');
  for (const declaration of analysis.declarations) add(declaration.name, declaration.description);
  return items;
}

function hoverTemplate(
  description: string,
  line: number,
  kind: Declaration['kind'] | 'parameter',
): string {
  switch (kind) {
    case 'definition':
      return `
~~~core-lambda
${description}
~~~

Defined on line ${line}
`;
    case 'import':
      return `
${description}

Imported on line ${line}
`;
    case 'parameter':
      return `
${description}

Defined on line ${line}
`;
  }
}

export function hoverCoreLambda(document: TextDocument, position: Position): Hover | null {
  const offset = document.offsetAt(position);
  const analysis = analyze(document);
  const token = analysis.tokens.find(
    (candidate) => candidate.kind === 'name' && candidate.start <= offset && offset < candidate.end,
  );
  if (!token) return null;

  const ownDeclaration = analysis.declarations.find(
    (declaration) => declaration.token.start === token.start,
  );
  const ownParameter = analysis.parameters.find(
    (parameter) => parameter.token.start === token.start,
  );
  const parameter = activeParameters(analysis.parameters, token.start).find(
    (item) => item.name === token.text,
  );
  const declaration = analysis.declarations.find((item) => item.name === token.text);
  const resolvedDeclaration = ownDeclaration ?? declaration;
  const resolvedParameter = ownParameter ?? parameter;
  const description =
    ownDeclaration?.description ??
    (resolvedParameter ? `Parameter ${token.text}` : resolvedDeclaration?.description);
  if (!description) return null;
  const definitionToken =
    ownDeclaration?.token ?? resolvedParameter?.token ?? resolvedDeclaration?.token;
  if (!definitionToken) return null;
  const line = document.positionAt(definitionToken.start).line + 1;
  const kind =
    ownDeclaration?.kind ?? (resolvedParameter ? 'parameter' : resolvedDeclaration?.kind);
  if (!kind) return null;
  return {
    contents: { kind: MarkupKind.Markdown, value: hoverTemplate(description, line, kind) },
    range: { start: document.positionAt(token.start), end: document.positionAt(token.end) },
  };
}
