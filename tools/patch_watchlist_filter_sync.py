from pathlib import Path

path = Path('lib/v13_app.dart')
text = path.read_text()
needle = """  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
"""
replacement = """  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant V13FlipsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      filter = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
"""
if replacement in text:
    print('Watchlist filter sync already applied')
elif text.count(needle) != 1:
    raise SystemExit(f'Expected exactly one V13FlipsPage initState anchor, found {text.count(needle)}')
else:
    path.write_text(text.replace(needle, replacement, 1))
    print('Applied watchlist filter sync')
