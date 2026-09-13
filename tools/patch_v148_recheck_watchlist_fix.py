from pathlib import Path

path = Path('lib/v13_app.dart')
app = path.read_text()

# The generic field insertion in the first patch can hit V13Shell first.
wrong_shell = """  final ValueChanged<String> onHistory;
  final ValueChanged<V13Flip> onAddFlip;
  final V13Flip? existingSnapshot;
  final ValueChanged<V13Flip>? onUpdateFlip;
  final ValueChanged<V13Flip> onUpdateFlip;
  final ValueChanged<String> onDeleteFlip;
"""
right_shell = """  final ValueChanged<String> onHistory;
  final ValueChanged<V13Flip> onAddFlip;
  final ValueChanged<V13Flip> onUpdateFlip;
  final ValueChanged<String> onDeleteFlip;
"""
if wrong_shell in app:
    app = app.replace(wrong_shell, right_shell, 1)

check_anchor = """class V13CheckPage extends StatefulWidget {
  final bool english;
  final V13SearchInput input;
  final String backendBase;
  final Future<SharedListingMeta?> Function(String raw)? listingResolver;
  final double targetRoi;
  final double minProfit;
  final UserPlan plan;
  final V13TaxMode taxMode;
  final List<PriceSource> sources;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<String> onHistory;
  final ValueChanged<V13Flip> onAddFlip;
"""
check_replacement = check_anchor + """  final V13Flip? existingSnapshot;
  final ValueChanged<V13Flip>? onUpdateFlip;
"""
if check_anchor in app and 'class V13CheckPage' in app:
    segment = app[app.index('class V13CheckPage'):app.index('class _V13CheckPageState')]
    if 'final V13Flip? existingSnapshot;' not in segment:
        app = app.replace(check_anchor, check_replacement, 1)

old_menu = """  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'listing':
        await _openListing();
      case 'archive':
        onUpdate(flip.copyWith(status: 'Archived'));
      case 'restore':
        onUpdate(flip.copyWith(status: 'Saved'));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t('Deal löschen?', 'Delete deal?')),
            content: Text(t('Der gespeicherte Snapshot wird dauerhaft von diesem Gerät entfernt.', 'The saved snapshot will be permanently removed from this device.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('Löschen', 'Delete'))),
            ],
          ),
        );
        if (ok == true) onDelete(flip.id);
    }
  }
"""
new_menu = """  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'listing':
        await _openListing();
        return;
      case 'archive':
        onUpdate(flip.copyWith(status: 'Archived'));
        return;
      case 'restore':
        onUpdate(flip.copyWith(status: 'Saved'));
        return;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t('Deal löschen?', 'Delete deal?')),
            content: Text(t('Der gespeicherte Snapshot wird dauerhaft von diesem Gerät entfernt.', 'The saved snapshot will be permanently removed from this device.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('Löschen', 'Delete'))),
            ],
          ),
        );
        if (ok == true) onDelete(flip.id);
        return;
    }
  }
"""
if old_menu in app:
    app = app.replace(old_menu, new_menu, 1)

path.write_text(app)
print('V0.14.8 patch target fixes applied')
