from pathlib import Path

p = Path('lib/v10_app.dart')
text = p.read_text()
start = text.find('class _MissingValueCard extends StatelessWidget {')
end = text.find('class _QuickCompareSection extends StatelessWidget {', start)
if start < 0 or end < 0:
    raise RuntimeError('Could not locate obsolete MissingValueCard block')
p.write_text(text[:start] + text[end:])
print('Removed obsolete V0.12 MissingValueCard and preserved QuickCompare.')
