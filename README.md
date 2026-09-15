# FlipRadar V0.14.8

Installierbare Android-Testversion von FlipRadar.

## Enthalten
- Deutsch und Englisch
- Deal-Analyse
- Gewinn- und ROI-Rechner
- Flip Score
- Demo Deal Finder und testbare Marketplace-Integration
- Marktqualitätsfilter gegen unpassende, defekte oder reine Reparatur-Angebote
- Recheck-Bewertung für Preis-, Gewinn- und ROI-Änderungen
- Kleinanzeigen-Share-Flow
- Meine Flips / lokales Test-Inventar
- Profil und Spracheinstellungen

## Sicherheits- und Integrationsgrenzen
- Marketplace-Sandbox und LIVE-Konfiguration bleiben getrennt.
- Marketplace-Credentials gehören nicht in den Android-Client.
- Billing wird lazy initialisiert, damit der App-Start nicht davon abhängt.
- AdMob bleibt vom kritischen Startpfad isoliert.
- Änderungen an Marktfiltern und Recheck-Logik werden mit Regressionstests abgesichert.

## Android Builds
Die Release-APK und das Android App Bundle werden automatisch mit GitHub Actions gebaut und geprüft.

Workflows:
- `.github/workflows/build-android-apk.yml`
- `.github/workflows/build-android-aab.yml`

Die APK-Pipeline führt zusätzlich statische Analyse, Tests und kritische Regressionstests aus. Eine APK sollte nur aus einem vollständig grünen Lauf als Teststand verwendet werden.

## Marketplace-Status
Die App ist weiterhin eine Testversion. Sandbox-/Testintegration ist kein LIVE-Marktplatzbetrieb. LIVE-Zugänge, echte Secrets und Production-Freigaben werden nicht im Repository hinterlegt oder automatisch aktiviert.
