from pathlib import Path

path = Path('lib/v13_app.dart')
text = path.read_text()
old = """    final stale = saved.where((e) => now.difference(e.checkedAt).inHours >= 24).toList();
    final oldest = saved.first;
    final freshCount = saved.length - stale.length;
"""
new = """    final stale = saved.where((e) => now.difference(e.checkedAt).inHours >= 24).toList()
      ..sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
    final oldest = stale.isEmpty ? saved.first : stale.first;
    final freshCount = saved.length - stale.length;
"""
if new in text:
    print('Watchlist stale ordering already applied.')
elif old in text:
    path.write_text(text.replace(old, new, 1))
    print('Applied watchlist stale ordering fix.')
else:
    raise SystemExit('Guard failed: expected watchlist recheck queue block not found.')
