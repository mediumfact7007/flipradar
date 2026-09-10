import 'package:flutter/material.dart';

void main() => runApp(const FlipRadarApp());

class FlipRadarApp extends StatefulWidget {
  const FlipRadarApp({super.key});

  @override
  State<FlipRadarApp> createState() => _FlipRadarAppState();
}

class _FlipRadarAppState extends State<FlipRadarApp> {
  bool english = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlipRadar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: MainShell(
        english: english,
        onLanguageChanged: (value) => setState(() => english = value),
      ),
    );
  }
}

class FlipItem {
  final String name;
  final double buy;
  final double sell;
  final double costs;
  final String status;

  const FlipItem({
    required this.name,
    required this.buy,
    required this.sell,
    required this.costs,
    required this.status,
  });

  double get profit => sell - buy - costs;
  double get roi => buy <= 0 ? 0 : profit / buy * 100;
}

class MainShell extends StatefulWidget {
  final bool english;
  final ValueChanged<bool> onLanguageChanged;

  const MainShell({
    super.key,
    required this.english,
    required this.onLanguageChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final List<FlipItem> flips = [
    const FlipItem(name: 'iPhone 15 Pro 256 GB', buy: 420, sell: 549, costs: 44, status: 'Listed'),
    const FlipItem(name: 'PlayStation 5 Slim', buy: 250, sell: 379, costs: 57, status: 'Sold'),
    const FlipItem(name: 'MacBook Air M2', buy: 400, sell: 599, costs: 69, status: 'Listed'),
  ];

  String t(String de, String en) => widget.english ? en : de;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(english: widget.english, onAnalyze: () => setState(() => index = 1)),
      AnalyzePage(
        english: widget.english,
        onSaved: (item) {
          setState(() {
            flips.insert(0, item);
            index = 3;
          });
        },
      ),
      DealsPage(english: widget.english),
      FlipsPage(english: widget.english, flips: flips),
      ProfilePage(english: widget.english, onLanguageChanged: widget.onLanguageChanged),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t('Start', 'Home')),
          NavigationDestination(icon: const Icon(Icons.calculate_outlined), selectedIcon: const Icon(Icons.calculate), label: t('Analyse', 'Analyze')),
          NavigationDestination(icon: const Icon(Icons.local_fire_department_outlined), selectedIcon: const Icon(Icons.local_fire_department), label: t('Deals', 'Deals')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: t('Flips', 'Flips')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t('Profil', 'Profile')),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
      ],
    );
  }
}

class HomePage extends StatelessWidget {
  final bool english;
  final VoidCallback onAnalyze;
  const HomePage({super.key, required this.english, required this.onAnalyze});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: t('FlipRadar', 'FlipRadar'),
          subtitle: t('Finde profitable Reselling-Deals schneller.', 'Find profitable reselling deals faster.'),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Deine Performance', 'Your performance'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('1.284 €', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              Text(t('potenzieller Gewinn', 'potential profit'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _DarkStat(label: t('Investiert', 'Invested'), value: '3.420 €')),
                  Expanded(child: _DarkStat(label: t('Ø ROI', 'Avg. ROI'), value: '31,4 %')),
                  Expanded(child: _DarkStat(label: t('Verkauft', 'Sold'), value: '18')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAnalyze,
          icon: const Icon(Icons.auto_graph),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(t('Deal analysieren', 'Analyze deal')),
          ),
        ),
        const SizedBox(height: 24),
        Text(t('Top Deals', 'Top Deals'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const DealCard(name: 'MacBook Pro M2', buy: 420, sell: 620, costs: 55, score: 94),
        const DealCard(name: 'Sony A7 III', buy: 760, sell: 980, costs: 55, score: 87),
        const DealCard(name: 'Nintendo Switch OLED', buy: 180, sell: 249, costs: 27, score: 82),
      ],
    );
  }
}

class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  const _DarkStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class DealCard extends StatelessWidget {
  final String name;
  final double buy;
  final double sell;
  final double costs;
  final int score;

  const DealCard({
    super.key,
    required this.name,
    required this.buy,
    required this.sell,
    required this.costs,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final profit = sell - buy - costs;
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Text('$score')),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${buy.toStringAsFixed(0)} € → ${sell.toStringAsFixed(0)} €'),
        trailing: Text('+${profit.toStringAsFixed(0)} €', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class AnalyzePage extends StatefulWidget {
  final bool english;
  final ValueChanged<FlipItem> onSaved;
  const AnalyzePage({super.key, required this.english, required this.onSaved});

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  final product = TextEditingController(text: 'iPhone 15 Pro 256 GB');
  final buy = TextEditingController(text: '420');
  final sell = TextEditingController(text: '549');
  final fees = TextEditingController(text: '32');
  final shipping = TextEditingController(text: '7');
  final other = TextEditingController(text: '5');
  bool analyzed = false;
  double profit = 85;
  double roi = 20.2;
  int score = 86;

  String t(String de, String en) => widget.english ? en : de;
  double n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  void calculate() {
    final b = n(buy);
    final s = n(sell);
    final costs = n(fees) + n(shipping) + n(other);
    final p = s - b - costs;
    final r = b <= 0 ? 0 : p / b * 100;
    final rawScore = (50 + r * 1.7 + (p > 100 ? 12 : p > 50 ? 7 : 0)).round();
    setState(() {
      profit = p;
      roi = r;
      score = rawScore.clamp(0, 100);
      analyzed = true;
    });
  }

  @override
  void dispose() {
    product.dispose();
    buy.dispose();
    sell.dispose();
    fees.dispose();
    shipping.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: t('Deal analysieren', 'Analyze deal'),
          subtitle: t('Berechne Gewinn, ROI und Flip Score.', 'Calculate profit, ROI and Flip Score.'),
        ),
        const SizedBox(height: 18),
        _field(product, t('Produkt', 'Product')),
        Row(
          children: [
            Expanded(child: _field(buy, t('Einkauf €', 'Buy €'), numeric: true)),
            const SizedBox(width: 10),
            Expanded(child: _field(sell, t('Verkauf €', 'Sell €'), numeric: true)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field(fees, t('Gebühren €', 'Fees €'), numeric: true)),
            const SizedBox(width: 10),
            Expanded(child: _field(shipping, t('Versand €', 'Shipping €'), numeric: true)),
          ],
        ),
        _field(other, t('Sonstige Kosten €', 'Other costs €'), numeric: true),
        const SizedBox(height: 6),
        FilledButton(onPressed: calculate, child: Text(t('Jetzt berechnen', 'Calculate now'))),
        if (analyzed) ...[
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _Result(label: t('Gewinn', 'Profit'), value: '${profit.toStringAsFixed(2)} €')),
                      Expanded(child: _Result(label: 'ROI', value: '${roi.toStringAsFixed(1)} %')),
                      Expanded(child: _Result(label: 'Flip Score', value: '$score/100')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: score / 100),
                  const SizedBox(height: 12),
                  Text(
                    score >= 80
                        ? t('Starker Deal – gute Marge.', 'Strong deal – good margin.')
                        : score >= 65
                            ? t('Interessant, aber Risiken prüfen.', 'Interesting, but check the risks.')
                            : t('Eher vorsichtig sein.', 'Proceed cautiously.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              widget.onSaved(
                FlipItem(
                  name: product.text.trim().isEmpty ? 'Unnamed item' : product.text.trim(),
                  buy: n(buy),
                  sell: n(sell),
                  costs: n(fees) + n(shipping) + n(other),
                  status: 'Listed',
                ),
              );
            },
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(t('Zu Meine Flips speichern', 'Save to My Flips')),
          ),
        ],
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final String label;
  final String value;
  const _Result({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ],
    );
  }
}

class DealsPage extends StatelessWidget {
  final bool english;
  const DealsPage({super.key, required this.english});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: t('Deal Finder', 'Deal Finder'),
          subtitle: t('Demo-Treffer für die erste Testversion.', 'Demo results for the first test version.'),
        ),
        const SizedBox(height: 16),
        const DealCard(name: 'MacBook Pro M2', buy: 420, sell: 620, costs: 55, score: 94),
        const DealCard(name: 'Sony A7 III', buy: 760, sell: 980, costs: 55, score: 87),
        const DealCard(name: 'iPhone 14 Pro', buy: 390, sell: 525, costs: 45, score: 84),
        const DealCard(name: 'Nintendo Switch OLED', buy: 180, sell: 249, costs: 27, score: 82),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(t('Preisalarme', 'Price alerts')),
            subtitle: Text(t('Watchlists und echte Marktplatzdaten kommen in der nächsten Version.', 'Watchlists and live marketplace data are planned for the next version.')),
          ),
        ),
      ],
    );
  }
}

class FlipsPage extends StatelessWidget {
  final bool english;
  final List<FlipItem> flips;
  const FlipsPage({super.key, required this.english, required this.flips});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final total = flips.fold<double>(0, (sum, item) => sum + item.profit);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: t('Meine Flips', 'My Flips'),
          subtitle: t('Dein lokales Test-Inventar.', 'Your local test inventory.'),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(child: _Result(label: t('Artikel', 'Items'), value: '${flips.length}')),
                Expanded(child: _Result(label: t('Gesamtgewinn', 'Total profit'), value: '${total.toStringAsFixed(0)} €')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...flips.map(
          (item) => Card(
            elevation: 0,
            child: ListTile(
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${item.buy.toStringAsFixed(0)} € → ${item.sell.toStringAsFixed(0)} € · ROI ${item.roi.toStringAsFixed(1)} %'),
              trailing: Text('${item.profit >= 0 ? '+' : ''}${item.profit.toStringAsFixed(0)} €', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  final bool english;
  final ValueChanged<bool> onLanguageChanged;
  const ProfilePage({super.key, required this.english, required this.onLanguageChanged});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: t('Profil & Einstellungen', 'Profile & Settings'),
          subtitle: t('FlipRadar V0.2 Testversion', 'FlipRadar V0.2 test build'),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(t('Sprache', 'Language')),
                subtitle: Text(english ? 'English' : 'Deutsch'),
                trailing: Switch(value: english, onChanged: onLanguageChanged),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.euro),
                title: Text(t('Währung', 'Currency')),
                subtitle: const Text('EUR €'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('FlipRadar Pro'),
                subtitle: Text(t('Demo-Platzhalter – noch kein Abo nötig.', 'Demo placeholder – no subscription required yet.')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t(
                'Hinweis: Diese Testversion nutzt Demo-Marktdaten. Gewinn- und Preisangaben sind keine Garantie.',
                'Note: This test build uses demo market data. Profit and price estimates are not guaranteed.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
