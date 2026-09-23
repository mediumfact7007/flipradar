import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BuybackProviderDestination {
  const BuybackProviderDestination({required this.id, required this.name, required this.url});

  final String id;
  final String name;
  final Uri url;
}

final buybackProviderDestinations = List<BuybackProviderDestination>.unmodifiable([
  BuybackProviderDestination(
    id: 'rebuy',
    name: 'reBuy',
    url: Uri.parse('https://www.rebuy.de/verkaufen'),
  ),
  BuybackProviderDestination(
    id: 'zoxs',
    name: 'ZOXS',
    url: Uri.parse('https://www.zoxs.de/'),
  ),
  BuybackProviderDestination(
    id: 'clevertronic',
    name: 'Clevertronic',
    url: Uri.parse('https://www.clevertronic.de/verkaufen'),
  ),
]);

/// Honest fallback while no approved provider price feed is configured.
///
/// These destinations never become price evidence inside FlipRadar. The
/// product query is copied so the user can paste it into each provider's own
/// condition flow and inspect the provider-controlled result directly.
class BuybackProviderLinksCard extends StatelessWidget {
  const BuybackProviderLinksCard({
    super.key,
    required this.query,
    this.english = false,
    this.launcher,
    this.copyQuery,
  });

  final String query;
  final bool english;
  final Future<bool> Function(Uri uri)? launcher;
  final Future<void> Function(String query)? copyQuery;

  String t(String de, String en) => english ? en : de;

  Future<void> _open(BuildContext context, BuybackProviderDestination provider) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isNotEmpty) {
      await (copyQuery?.call(normalized) ??
          Clipboard.setData(ClipboardData(text: normalized)));
    }
    final opened = await (launcher?.call(provider.url) ??
        launchUrl(provider.url, mode: LaunchMode.externalApplication));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened
          ? t('Suchbegriff kopiert – bei ${provider.name} einfügen und Zustand wählen.', 'Search copied — paste it at ${provider.name} and choose the condition.')
          : t('${provider.name} konnte nicht geöffnet werden.', '${provider.name} could not be opened.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('buyback-provider-links-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Preis direkt beim Anbieter prüfen', 'Check price at provider'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(
            t(
              'Ohne LIVE-Feed öffnet FlipRadar die offiziellen Ankaufsseiten. Das Ergebnis bleibt extern und wird nicht als LIVE-Preis ausgegeben.',
              'Without a LIVE feed, FlipRadar opens the official buyback sites. The result stays external and is not shown as a LIVE price.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 5,
            children: [
              for (final provider in buybackProviderDestinations)
                OutlinedButton.icon(
                  key: ValueKey('buyback-provider-${provider.id}'),
                  onPressed: () => _open(context, provider),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(provider.name),
                ),
            ],
          ),
          Text(
            t('Der Suchbegriff wird beim Öffnen kopiert.', 'The search term is copied when opening.'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}
