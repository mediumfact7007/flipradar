# FlipRadar Market API

Small FastAPI proxy for marketplace integrations. Marketplace secrets stay on the server, never in the APK.

Environment variables:
- `EBAY_CLIENT_ID`
- `EBAY_CLIENT_SECRET`

Run:
```bash
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Build the app with the backend URL:
```bash
flutter build apk --release --dart-define=FLIPRADAR_API_URL=https://your-api.example.com
```

The eBay adapter targets `EBAY_DE` and uses the official Browse API. Production access remains subject to eBay's current API eligibility/approval requirements.

Kleinanzeigen automated access is intentionally not implemented here. The mobile app opens live Kleinanzeigen searches instead. Add an official/contracted adapter only if access is permitted.
