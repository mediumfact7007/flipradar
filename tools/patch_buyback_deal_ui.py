from pathlib import Path

p = Path('lib/v13_app.dart')
s = p.read_text()

def once(old, new):
    global s
    if new in s:
        return
    if s.count(old) != 1:
        raise SystemExit(f'guard failed: expected exactly one match, got {s.count(old)} for {old[:80]!r}')
    s = s.replace(old, new, 1)

once("import 'recheck_delta.dart';\n", "import 'buyback.dart';\nimport 'buyback_client.dart';\nimport 'buyback_summary.dart';\nimport 'buyback_summary_card.dart';\nimport 'recheck_delta.dart';\n")

once("  bool listingResolveFailed = false;\n  int token = 0;", "  bool listingResolveFailed = false;\n  BuybackCondition? buybackCondition;\n  List<BuybackOffer> buybackOffers = const [];\n  bool buybackLoading = false;\n  int buybackToken = 0;\n  int token = 0;")

once("      savedBought = false;\n      savedWatch = false;\n    });", "      savedBought = false;\n      savedWatch = false;\n      buybackOffers = const [];\n      buybackLoading = false;\n    });")

anchor = "  void _retryFailed() {\n"
method = """  Future<void> _loadBuyback(BuybackCondition condition) async {
    final q = normalizeV13Search(query.text).query;
    if (q.isEmpty) return;
    final myToken = ++buybackToken;
    setState(() {
      buybackCondition = condition;
      buybackOffers = const [];
      buybackLoading = true;
    });
    final base = widget.backendBase.trim().isEmpty
        ? SourceRegistry.defaultBackend
        : widget.backendBase;
    final offers = await BuybackClient(backendBase: base).search(
      q,
      condition: condition,
    );
    if (!mounted || myToken != buybackToken) return;
    setState(() {
      buybackOffers = offers;
      buybackLoading = false;
    });
  }

  String _buybackConditionLabel(BuybackCondition condition) => switch (condition) {
        BuybackCondition.newSealed => t('Neu & OVP', 'New & sealed'),
        BuybackCondition.likeNew => t('Wie neu', 'Like new'),
        BuybackCondition.veryGood => t('Sehr gut', 'Very good'),
        BuybackCondition.usedGood => t('Gebraucht', 'Used'),
        BuybackCondition.acceptable => t('Akzeptabel', 'Acceptable'),
        BuybackCondition.defective => t('Defekt', 'Defective'),
      };

  BuybackComparisonSummary? get buybackSummary {
    final condition = buybackCondition;
    final privateValue = expectedSale;
    if (condition == null || privateValue == null || privateValue <= 0 || buyPrice <= 0) {
      return null;
    }
    return buildBuybackComparisonSummary(
      buybackOffers,
      condition: condition,
      purchasePrice: buyPrice + extraCosts,
      privateMarketValue: privateValue,
    );
  }

"""
once(anchor, method + anchor)

ui_anchor = """          if (widget.existingSnapshot?.isSaved == true && expectedSale != null && (widget.existingSnapshot!.maxBuyAtCheck > 0 || widget.existingSnapshot!.profitAtCheck != 0 || widget.existingSnapshot!.roiAtCheck != 0)) ...[
"""
ui = """          if (expectedSale != null) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<BuybackCondition>(
              key: const ValueKey('v151-buyback-condition'),
              initialValue: buybackCondition,
              decoration: InputDecoration(
                labelText: t('Zustand für Sofortankauf', 'Condition for instant buyback'),
                prefixIcon: const Icon(Icons.recycling_rounded),
                helperText: t('Nur wählen, wenn du echte Ankaufangebote vergleichen willst.', 'Choose only when you want to compare real buyback offers.'),
              ),
              items: BuybackCondition.values
                  .map((condition) => DropdownMenuItem(
                        value: condition,
                        child: Text(_buybackConditionLabel(condition)),
                      ))
                  .toList(),
              onChanged: (condition) {
                if (condition != null) unawaited(_loadBuyback(condition));
              },
            ),
            if (buybackLoading) ...[
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text(t('Ankaufangebote werden geprüft …', 'Checking buyback offers …'), style: const TextStyle(fontSize: 11, color: Color(0xFF707483))),
              ]),
            ] else if (buybackCondition != null && buybackOffers.isEmpty) ...[
              const SizedBox(height: 7),
              Text(t('Für diesen Zustand ist aktuell kein verifiziertes Ankaufangebot verfügbar.', 'No verified buyback offer is currently available for this condition.'), style: const TextStyle(fontSize: 10.8, color: Color(0xFF707483))),
            ],
            if (buybackSummary != null) ...[
              const SizedBox(height: 8),
              BuybackComparisonCard(summary: buybackSummary!, locale: widget.english ? 'en' : 'de'),
            ],
          ],
"""
once(ui_anchor, ui + ui_anchor)

p.write_text(s)
