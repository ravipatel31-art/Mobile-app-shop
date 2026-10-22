# Cafe POS — Marketing kit

Everything you need to sell to local cafés, for ₹0.

| File | What it is | Use it for |
|------|-----------|------------|
| [`docs/index.html`](../docs/index.html) | **Landing page** — one self-contained file | The link you send after every conversation. Host it free on GitHub Pages. |
| [`marketing/one-pager.html`](one-pager.html) | **One-pager** — print-ready A4 | Open → `Ctrl+P` → *Save as PDF*. Print it + email it. |
| [`demo-60s.mp4`](demo-60s.mp4) | **60-sec demo video (9:16)** — rendered, ready to post | WhatsApp status, Reels, in-person demos. Add free music on upload. |
| [`demo-video-script.md`](demo-video-script.md) | **Storyboard** behind the video | Re-render any time with `tools/build_demo_video.sh` (ffmpeg). Canva optional. |

---

## 1. Fill in these 5 placeholders (do this first)

All three files have a comment block at the top listing exactly what to replace.
The recurring ones:

| Placeholder | Where | Replace with |
|-------------|-------|--------------|
| `wa.me/910000000000` | landing + one-pager | your WhatsApp (country code, no `+`) |
| `+91 00000 00000` | landing + one-pager | your phone number |
| `hello@cafepos.app` | landing + one-pager | your email |
| `₹499` | landing + one-pager | your real launch price |
| `screens/*.png`, `demo.mp4` | landing | ✅ already rendered — `docs/screens/*.png` + `docs/demo.mp4` |

---

## 2. Publish the landing page (free, ~2 min)

```bash
git add docs marketing
git commit -m "Add landing page + marketing kit"
git push
```

Then on GitHub:
**Settings → Pages → Source: "Deploy from a branch" → Branch: `main`, folder `/docs` → Save**

Your link will be:
`https://ravipatel31-art.github.io/Mobile-app-shop/`

The video is already at `docs/demo.mp4` (16:9) and `marketing/demo-60s.mp4` (9:16) —
rebuild with `tools/build_demo_video.sh` after UI changes. To use YouTube instead,
open `docs/index.html`, find the commented-out `<iframe>` in the video section and swap it in.

---

## 3. The video (done — music baked in)

`marketing/demo-60s.mp4` (9:16) and `docs/demo.mp4` (16:9) are rendered from the
generated screenshots by `tools/build_demo_video.sh` — storyboard in
[`demo-video-script.md`](demo-video-script.md). Background music (Satie's
*Gymnopédie No. 1*, Kevin MacLeod, CC BY) is mixed in — **paste the credit line
from [`MUSIC-CREDITS.md`](MUSIC-CREDITS.md) in your caption/description.**

Want a **15s** or **6s** cut for ads? Cut it from the same file in CapCut, or ask:
the scene timings are in the storyboard.

---

## 4. The free sales loop (how the assets fit together)

```
  Walk into a café / IG DM
            │
            ▼
   Show the 60-sec video on your phone   ← demo-video-script.md
            │
            ▼
   Send the landing-page link            ← docs/index.html
   ("forward it to your partner")
            │
            ▼
   Leave the printed one-pager           ← one-pager.html
            │
            ▼
   Free 14-day trial on their device
            │
            ▼
   Ask for 2 introductions  ──────────────►  repeat
```

**Track only 3 numbers:** conversations → trials → paying.

---

## 5. When you're ready to run Google Ads

You now have all three pieces a Google Video campaign needs:
- **Video:** the 9:16 (Reels/in-feed) + 16:9 (YouTube in-stream) cuts
- **Destination:** the landing page (it has the demo + a WhatsApp CTA)
- **Conversion:** the *“Book a demo”* WhatsApp click

Suggested first campaign (small budget, ~₹300/day for 2 weeks):
- **Goal:** Website traffic (or Leads once you have conversion tracking)
- **Networks:** YouTube feed + Shorts
- **Target:** your city, interests = *restaurants / café owners / small business*
- **Audience:** 25–55, business owners
- **Keywords to bid on:** “cafe POS software”, “billing app for café”, “restaurant POS small business”, “UPI billing app”

**But first:** get 3–5 paying cafés by hand. Ads scale a message that already works —
they won't create one.

---

## 6. Brand note

The app, site and one-pager are all branded **“Cafe POS”** (matches the app title and
UPI merchant name in `mobile/lib/config.dart`). If you want a catchier product name,
change it in one place and search these files for the old name — they're plain text.
