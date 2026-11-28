import { completeDecode, type DecodeCompletion } from "./decode-type";

export function bindDecodeCombobox(input: HTMLInputElement, list: HTMLElement) {
  let options: DecodeCompletion[] = [];
  let active = -1;

  function select(index: number) {
    list.children[active]?.setAttribute("aria-selected", "false");
    active = index;
    const item = list.children[active];
    if (item) {
      item.setAttribute("aria-selected", "true");
      input.setAttribute("aria-activedescendant", item.id);
      item.scrollIntoView({ block: "nearest" });
    } else {
      input.removeAttribute("aria-activedescendant");
    }
  }

  function render(next: DecodeCompletion[]) {
    options = next;
    select(-1);
    list.replaceChildren(
      ...options.map(({ label }, index) => {
        const item = document.createElement("li");
        item.id = `${list.id}-${index}`;
        item.setAttribute("role", "option");
        item.setAttribute("aria-selected", "false");
        item.textContent = label;
        item.addEventListener("mousedown", (event) => event.preventDefault());
        item.addEventListener("click", () => apply(index));
        return item;
      }),
    );
    list.hidden = !options.length;
    input.setAttribute("aria-expanded", String(!list.hidden));
  }

  function refresh() {
    const cursor = input.selectionStart;
    render(
      cursor !== null && cursor === input.selectionEnd
        ? completeDecode(input.value, cursor)
        : [],
    );
  }

  function apply(index: number) {
    const option = options[index];
    if (!option) return;
    input.setRangeText(option.text, option.start, option.end, "end");
    input.setSelectionRange(option.cursor, option.cursor);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    if (option.cursor === option.start + option.text.length) render([]);
  }

  input.addEventListener("input", (event) => {
    if (!(event instanceof InputEvent && event.isComposing)) refresh();
  });
  input.addEventListener("compositionstart", () => render([]));
  input.addEventListener("compositionend", refresh);
  input.addEventListener("click", refresh);
  input.addEventListener("blur", () => render([]));
  input.addEventListener("keyup", (event) => {
    if (
      !list.hidden &&
      ["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)
    ) {
      refresh();
    }
  });
  input.addEventListener("keydown", (event) => {
    if (event.isComposing) return;
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (list.hidden) refresh();
      if (!options.length) return;
      event.preventDefault();
      const step = event.key === "ArrowDown" ? 1 : -1;
      const next = active < 0 && step < 0 ? options.length - 1 : active + step;
      select((next + options.length) % options.length);
    } else if (event.key === "Escape" && !list.hidden) {
      event.preventDefault();
      render([]);
    } else if (event.key === "Enter" && active >= 0) {
      event.preventDefault();
      apply(active);
    }
  });
}
