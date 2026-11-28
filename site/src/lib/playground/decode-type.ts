type Slot =
  | "root"
  | "type"
  | "list-encoding"
  | "character-encoding"
  | ","
  | ">";

const scalarTypes = [
  "natural",
  "scott-natural",
  "binary-natural",
  "boolean",
  "integer",
  "rational",
  "string",
];

function choices(slot: Slot): string[] {
  switch (slot) {
    case "root":
      return [...choices("type"), "real"];
    case "type":
      return [...scalarTypes, "list<", "scott-list<", "pair<", "string<"];
    case "list-encoding":
      return ["church<", "scott<"];
    case "character-encoding":
      return ["church", "scott", "binary"];
    default:
      return [slot];
  }
}

function consume(expected: Slot[], token: string) {
  const slot = expected.pop();
  if (!slot || !choices(slot).includes(token)) return false;
  switch (token) {
    case "pair<":
      expected.push(">", "type", ",", "type");
      break;
    case "list<":
    case "scott-list<":
      expected.push(">", "type");
      break;
    case "string<":
      expected.push(">", "list-encoding");
      break;
    case "church<":
    case "scott<":
      expected.push(">", "character-encoding");
      break;
  }
  return true;
}

function parsePrefix(value: string) {
  const expected: Slot[] = ["root"];
  const token = /\s*([a-z-]+<?|[,>])/y;
  let offset = 0;
  while (offset < value.length) {
    const match = token.exec(value);
    if (!match) return /\S/.test(value.slice(offset)) ? undefined : expected;
    if (expected.at(-1) === "list-encoding" && match[0] !== match[1]) {
      return undefined;
    }
    if (!consume(expected, match[1])) return undefined;
    offset = token.lastIndex;
  }
  return expected;
}

export function validDecode(value: string) {
  // Preserve the preset format's requirement for an exact top-level real.
  if (value.trim() === "real") return value === "real";
  return !/\s$/.test(value) && parsePrefix(value)?.length === 0;
}

export interface DecodeCompletion {
  label: string;
  text: string;
  start: number;
  end: number;
  cursor: number;
}

export function completeDecode(
  value: string,
  cursor: number,
): DecodeCompletion[] {
  const prefix = value.slice(0, cursor).match(/[a-z-]*$/)?.[0] ?? "";
  const start = cursor - prefix.length;
  const suffix = value.slice(cursor).match(/^[a-z-]*/)?.[0] ?? "";
  const end = cursor + suffix.length;
  const slot = parsePrefix(value.slice(0, start))?.at(-1);
  if (!slot) return [];
  const rest = value.slice(end);
  const hasOpener = rest.startsWith("<");
  return choices(slot).flatMap((token) => {
    const opens = token.endsWith("<");
    const name = opens ? token.slice(0, -1) : token;
    if (!name.startsWith(prefix) || (hasOpener && !opens)) return [];
    if (token === "," || token === ">") {
      if (suffix || rest.trimStart().startsWith(token)) return [];
    }
    let insertion = token;
    if (opens) {
      insertion = token === "pair<" ? "pair<, >" : `${token}>`;
    } else if (token === ",") {
      insertion = ", ";
    }
    return [
      {
        label: insertion.trimEnd(),
        text: opens && hasOpener ? name : insertion,
        start,
        end,
        cursor: start + (opens ? token.length : insertion.length),
      },
    ];
  });
}
