from pathlib import Path

p = Path('lib/v13_app.dart')
s = p.read_text()

marker = "v156-buyback-empty"
if marker in s:
    print('buyback empty state already applied')
    raise SystemExit(0)

old = """            ] else if (buybackCondition != null && buybackOffers.isEmpty) ...[
              const SizedBox(height: 7),
              Text(t('Für diesen Zustand ist aktuell kein verifiziertes Ankaufangebot verfügbar.', 'No verified buyback offer is currently available for this condition.'), style: const TextStyle(fontSize: 10.8, color: Color(0xFF707483))),
            ],
"""
new = """            ] else if (buybackCondition != null && buybackOffers.isEmpty) ...[
              const SizedBox(height: 7),
              Container(
                key: const ValueKey('v156-buyback-empty'),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0D79A)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF9A6700)),
                  const SizedBox(width: 7),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('Noch kein verifiziertes LIVE-Ankaufangebot', 'No verified LIVE buyback offer yet'), style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      t('Für diesen Artikel und Zustand liefert aktuell kein angebundenes Ankaufportal einen echten Preis. FlipRadar schätzt hier bewusst keinen Ankaufpreis.', 'No connected buyback provider currently returns a real price for this item and condition. FlipRadar deliberately does not estimate a buyback price here.'),
                      style: const TextStyle(fontSize: 9.8, color: Color(0xFF6F6250)),
                    ),
                  ])),
                ]),
              ),
            ],
"""
if old not in s:
    raise SystemExit('buyback empty-state anchor not found')
s = s.replace(old, new, 1)
p.write_text(s)
print('applied buyback empty state')
