#!/usr/bin/env python3
"""Apply the V0.15.0 home fast-start UX patch safely and idempotently.

This keeps the risky edit to lib/v13_app.dart deterministic: it refuses to
write if the expected anchors changed, so future automation cannot silently
rewrite an unexpected version of the large central file.
"""
from pathlib import Path

PATH = Path("lib/v13_app.dart")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count == 0 and new in text:
        print(f"{label}: already applied")
        return text
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one anchor, found {count}; refusing to write")
    print(f"{label}: applied")
    return text.replace(old, new, 1)


def main() -> None:
    original = PATH.read_text(encoding="utf-8")
    updated = original

    updated = replace_once(
        updated,
        "          autofocus: true,\n          minLines: 1,",
        "          autofocus: false,\n          minLines: 1,",
        "quiet-start",
    )

    old_paste = """  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    query.text = text.length > 500 ? text.substring(0, 500) : text;
    query.selection = TextSelection.collapsed(offset: query.text.length);
    _changed(query.text);
  }
"""
    new_paste = """  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    query.text = text.length > 500 ? text.substring(0, 500) : text;
    query.selection = TextSelection.collapsed(offset: query.text.length);
    _changed(query.text);
    _submit();
  }
"""
    updated = replace_once(updated, old_paste, new_paste, "paste-and-check")

    updated = replace_once(
        updated,
        "? IconButton(onPressed: _paste, tooltip: t('Einfügen', 'Paste'), icon: const Icon(Icons.content_paste_rounded))",
        "? IconButton(key: const ValueKey('v150-paste-and-check'), onPressed: _paste, tooltip: t('Einfügen & prüfen', 'Paste & check'), icon: const Icon(Icons.content_paste_rounded))",
        "paste-action-label",
    )

    if updated == original:
        print("No changes needed.")
        return
    PATH.write_text(updated, encoding="utf-8")
    print(f"Updated {PATH}")


if __name__ == "__main__":
    main()
