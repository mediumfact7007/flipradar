from pathlib import Path

path = Path('lib/v13_app.dart')
app = path.read_text()

old = """          controller: query,
          autofocus: true,
          onChanged: _changed,
          onSubmitted: _submit,
          textInputAction: TextInputAction.search,
"""
new = """          controller: query,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          onChanged: _changed,
          onSubmitted: _submit,
          textInputAction: TextInputAction.search,
"""

if old in app:
    app = app.replace(old, new, 1)
elif 'maxLines: 3' not in app:
    raise SystemExit('V13Home search field marker not found')

assert 'minLines: 1' in app
assert 'maxLines: 3' in app
path.write_text(app)
print('V0.14.5 multiline marketplace paste fix applied')
