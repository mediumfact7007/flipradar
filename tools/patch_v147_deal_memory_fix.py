from pathlib import Path

path = Path('lib/v13_app.dart')
app = path.read_text()
app = app.replace(
    r"RegExp(r'https?://[^\\\\s]+', caseSensitive: false)",
    r"RegExp(r'https?://[^\s]+', caseSensitive: false)",
)
app = app.replace(
    r"RegExp(r'https?://[^\\s]+', caseSensitive: false)",
    r"RegExp(r'https?://[^\s]+', caseSensitive: false)",
)
path.write_text(app)
print('V0.14.7 URL regex normalized')
