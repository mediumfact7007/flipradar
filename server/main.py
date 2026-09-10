import base64
import os
import time
from typing import Literal

import httpx
from fastapi import FastAPI, HTTPException, Query

app = FastAPI(title="FlipRadar Market API", version="0.3.0")

EBAY_CLIENT_ID = os.getenv("EBAY_CLIENT_ID", "")
EBAY_CLIENT_SECRET = os.getenv("EBAY_CLIENT_SECRET", "")
_token = {"value": "", "expires": 0.0}


async def ebay_token() -> str:
    if _token["value"] and _token["expires"] > time.time() + 60:
        return str(_token["value"])
    if not EBAY_CLIENT_ID or not EBAY_CLIENT_SECRET:
        raise HTTPException(503, "eBay credentials are not configured")
    basic = base64.b64encode(f"{EBAY_CLIENT_ID}:{EBAY_CLIENT_SECRET}".encode()).decode()
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.post(
            "https://api.ebay.com/identity/v1/oauth2/token",
            headers={"Authorization": f"Basic {basic}", "Content-Type": "application/x-www-form-urlencoded"},
            data={"grant_type": "client_credentials", "scope": "https://api.ebay.com/oauth/api_scope"},
        )
    if r.status_code != 200:
        raise HTTPException(r.status_code, "eBay OAuth failed")
    data = r.json()
    _token["value"] = data["access_token"]
    _token["expires"] = time.time() + int(data.get("expires_in", 7200))
    return str(_token["value"])


@app.get("/health")
async def health():
    return {"ok": True, "ebay_configured": bool(EBAY_CLIENT_ID and EBAY_CLIENT_SECRET)}


@app.get("/v1/market/search")
async def search_market(
    q: str = Query(min_length=2, max_length=120),
    source: Literal["ebay_de"] = "ebay_de",
):
    token = await ebay_token()
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            "https://api.ebay.com/buy/browse/v1/item_summary/search",
            params={"q": q, "limit": 20},
            headers={
                "Authorization": f"Bearer {token}",
                "X-EBAY-C-MARKETPLACE-ID": "EBAY_DE",
                "Accept-Language": "de-DE",
            },
        )
    if r.status_code != 200:
        raise HTTPException(r.status_code, "eBay Browse API request failed")
    raw = r.json()
    items = []
    for x in raw.get("itemSummaries", []):
        shipping_options = x.get("shippingOptions") or []
        shipping = 0.0
        if shipping_options:
            shipping = float((shipping_options[0].get("shippingCost") or {}).get("value", 0) or 0)
        items.append({
            "source": "eBay DE",
            "title": x.get("title", "eBay listing"),
            "price": float((x.get("price") or {}).get("value", 0) or 0),
            "shipping": shipping,
            "condition": x.get("condition", ""),
            "url": x.get("itemWebUrl", ""),
        })
    return {"items": items, "count": len(items), "source": source}
