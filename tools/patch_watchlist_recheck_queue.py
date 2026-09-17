from pathlib import Path

path = Path('lib/v13_app.dart')
text = path.read_text()

old = """    final oldest = saved.first;\n    final title = stale.isEmpty\n        ? t('Merkliste aktuell', 'Watchlist up to date')\n        : t('${stale.length} Deal${stale.length == 1 ? '' : 's'} neu prüfen', '${stale.length} deal${stale.length == 1 ? '' : 's'} to recheck');\n    final subtitle = stale.isEmpty\n        ? t('Alle gespeicherten Deals wurden in den letzten 24 Std. geprüft.', 'All saved deals were checked within the last 24h.')\n        : t('Ältester Check ${v147AgeLabel(oldest.checkedAt, false)}.', 'Oldest check ${v147AgeLabel(oldest.checkedAt, true)}.');\n"""
new = """    final oldest = saved.first;\n    final freshCount = saved.length - stale.length;\n    final title = stale.isEmpty\n        ? t('Merkliste aktuell', 'Watchlist up to date')\n        : t('${stale.length} Deal${stale.length == 1 ? '' : 's'} neu prüfen', '${stale.length} deal${stale.length == 1 ? '' : 's'} to recheck');\n    final subtitle = stale.isEmpty\n        ? t('Alle gespeicherten Deals wurden in den letzten 24 Std. geprüft.', 'All saved deals were checked within the last 24h.')\n        : t('$freshCount von ${saved.length} aktuell · ältester Check ${v147AgeLabel(oldest.checkedAt, false)}.', '$freshCount of ${saved.length} current · oldest check ${v147AgeLabel(oldest.checkedAt, true)}.');\n"""
if new not in text:
    if old not in text:
        raise SystemExit('watchlist attention anchor changed; refusing unsafe patch')
    text = text.replace(old, new, 1)

old_button = """            child: Text(t('PRÜFEN', 'CHECK')),\n"""
new_button = """            child: Text(t(stale.length > 1 ? 'NÄCHSTEN PRÜFEN' : 'PRÜFEN', stale.length > 1 ? 'CHECK NEXT' : 'CHECK')),\n"""
if new_button not in text:
    if old_button not in text:
        raise SystemExit('recheck button anchor changed; refusing unsafe patch')
    text = text.replace(old_button, new_button, 1)

path.write_text(text)
