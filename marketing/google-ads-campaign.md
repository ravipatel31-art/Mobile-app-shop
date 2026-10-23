# Google Ads runner — Cafe POS (pan-India, ₹300/day)

Two campaigns, built in this order: **Search first** (catches people already
searching for what you sell), **Video second** (shows the demo to café owners
who aren't searching yet). Everything below is paste-ready.

**Your situation:** brand-new Google Ads account, ₹300/day for 14 days
(₹4,200 total), pan-India online sales, conversions = WhatsApp taps.

---

## 0. The honest math (read this first)

| Stage | Realistic rate | On ₹4,200 |
|---|---|---|
| Search clicks @ ₹10–20 CPC | ~200–300 clicks | ₹200/day ≈ 10–20 clicks/day |
| Click → WhatsApp tap | 4–8% | ~10–20 WhatsApp conversations |
| Demo → trial | ~1 in 3 | ~3–6 trials |
| Trial → paying | ~1 in 3 | **1–3 paying cafés** |

If zero WhatsApp taps after ₹1,000 of search spend → **stop and fix the
landing page or offer before spending more.** Ads amplify what works; they
don't fix what doesn't.

---

## 1. One-time setup (~30 min, before any campaign)

### a. Create the Ads account (don't let it start a campaign)
1. `ads.google.com` → sign in with your Google account.
2. Click **"Switch to expert mode"** (bottom of the guided screen).
3. Choose **"Create an account without a campaign"** — this skips the
   wizard that would force a bad campaign on day one.
4. Set: Country **India**, currency **INR**, time zone (your city's).
5. Skip billing for now — you'll add it at launch (step 5).

### b. Turn on tracking (do this BEFORE spending — it's free and takes 10 min)
Follow the comment block at the top of `docs/index.html` (also summarized in
the README): create the GA4 property → paste the `G-XXXXXXXXXX` ID into
`docs/index.html` (2 spots) → push → mark `generate_lead` as a key event →
link GA4 to Google Ads → import the conversion.

**Test it:** open your live site, tap either WhatsApp button once. GA4 →
*Reports → Realtime* should show the `generate_lead` event within seconds.
Until this works, every rupee is unmeasurable.

### c. Upload the two videos to YouTube
Your channel is the ad library. Upload both files from this repo:
- `marketing/demo-60s.mp4` (9:16) → title: **"Café POS — billing, kitchen & daily sales in 60 seconds"**
- `docs/demo.mp4` (16:9) → same title.

**In the description, paste the music credit** (CC BY requires it — see
`marketing/MUSIC-CREDITS.md`). Then: Google Ads → **Tools → Linked accounts →
YouTube** → link your channel.

### d. Billing
**Tools → Billing → Make payments.** In India you can use UPI autopay
(e-NACH), card, or net banking. For a ₹300/day test, a card or UPI autopay
is fine.

💡 **Check the Ads home banner right after setup** — new advertiser offers
(often "spend ₹2,000 in 60 days, get up to ₹20,000 ad credit") appear there.
Accept it before funding if it's showing; it's free money.

---

## 2. Campaign A — Search (₹200/day) ← build this first

**Goal:** show up when someone types "cafe billing software" at 11pm.

### Settings
| Setting | Value |
|---|---|
| Campaign type | **Search** |
| Goal | *Create a campaign without a goal's guidance* (avoids smart bidding) |
| Budget | **₹200/day** |
| Bidding | **Maximize clicks**, set a max CPC bid limit of **₹20** |
| Locations | **India** (entire country — pan-India online sales) |
| Languages | **English** |
| Ad schedule | All days, **09:00–23:00** (owners browse after rush hours) |
| Ad rotation | Do not optimise (let Google test) |
| Final URL | `https://ravipatel31-art.github.io/Mobile-app-shop/` |

### Ad groups & keywords (one theme per group)

**Group 1 — Café POS**
```
Exact:  [cafe pos software]
Exact:  [cafe pos]
Exact:  [coffee shop pos system]
Phrase: "cafe pos software india"
Phrase: "cafe pos price"
```

**Group 2 — Billing**
```
Exact:  [cafe billing software]
Exact:  [billing app for cafe]
Exact:  [upi billing software]
Phrase: "cafe billing app"
Phrase: "coffee shop billing software"
```

**Group 3 — Management**
```
Exact:  [cafe management software]
Exact:  [pos software for small business]
Phrase: "restaurant pos small business"
Phrase: "cafe sales tracking app"
```

### Negative keywords (campaign level — paste the whole block)
Tools → Keywords → Negative keywords → campaign level:
```
free
apk
download
cracked
crack
pirated
open source
github
jobs
hiring
career
internship
salary
course
training
tutorial
meaning
definition
zomato
swiggy
dineout
franchise
loan
interior
menu design
```
(Yes, "free" is on the list — people searching "free pos software" rarely
become paying customers. You still show *Free 14-day trial* in the ad.)

### Responsive search ad (paste into the ad group)
**Headlines** (≤30 chars each — pin H1 to position 1):
```
POS built only for cafés
UPI, GPay & cash billing
Free 14-day trial
No card needed
Kitchen display included
Bill print & UPI QR
Track dues automatically
Know today's sales tonight
Set up in 10 minutes
Works on your iPhone
GST-ready café billing
Customers order by QR
Made for cafés, not hotels
Free trial, no card
WhatsApp demo in 10 min
```
**Descriptions** (≤90 chars each):
```
Billing, kitchen screen, dues & sales in one app. UPI, GPay & cash. Free for 14 days.
Built for cafés, not bulky restaurant software. Set up in 10 minutes — no card needed.
See what you earned today: sales, best-sellers & payment mix — tallied automatically.
Customers scan & order from their own phone. Book a free demo on WhatsApp.
```
Pin: **headline 1** → position 1. Leave everything else unpinned so Google
mixes the rest by performance.

### Ad assets (Ads → Assets → add all four to the campaign)
- **Sitelinks** (point at your page's real anchors):
  | Title | Line 1 | URL |
  |---|---|---|
  | Watch 60-sec demo | See billing, kitchen & sales | `https://ravipatel31-art.github.io/Mobile-app-shop/#video` |
  | Features | UPI billing, KFT, dues & more | `https://ravipatel31-art.github.io/Mobile-app-shop/#features` |
  | Free 14-day trial | No card needed | `https://ravipatel31-art.github.io/Mobile-app-shop/#pricing` |
  | How it works | Order → kitchen → bill | `https://ravipatel31-art.github.io/Mobile-app-shop/#how` |
- **Callouts:** `Free 14-day trial` · `No card needed` · `GST-ready` · `WhatsApp support`
- **Call extension:** `+91 63517 70056`
- **Structured snippet** — Types: `Café POS` · `Kitchen display` · `UPI billing` · `Dues tracker`

---

## 3. Campaign B — Video (₹100/day)

**Goal:** put the demo in front of café owners on YouTube/Shorts, even if
they never search. Your 9:16 video already opens with the hook
(*"Still running your café on paper chits?"*) — it's built for this.

### Settings
| Setting | Value |
|---|---|
| Campaign type | **Video → Video views** |
| Budget | **₹100/day** |
| Bidding | **Maximize views**, set a max **CPV limit ₹1.00** (Indian CPVs are usually ₹0.20–0.80) |
| Locations | **India**, English |
| Ad schedule | All days, 09:00–23:00 |
| Content suitability | **Standard inventory** |
| Exclusions | Exclude videos for kids; sensitive categories |

**Ad combinations:**
1. **Skippable in-stream** → the 16:9 (`docs/demo.mp4`). Viewers can skip at
   5s; you pay only for 30s+ views. Your hook covers the first 5s.
2. **In-feed / Shorts** → the 9:16 (`marketing/demo-60s.mp4`) — cheapest
   views, native full-screen.

### Ad copy
```
Headline (≤40):   Café billing in 10 minutes
Description:      UPI billing, kitchen display & daily sales. Free 14-day trial — book a demo on WhatsApp.
CTA button:       Learn more
Final URL:        https://ravipatel31-art.github.io/Mobile-app-shop/
```

### Targeting
- **Audiences:** In-market *Business software* + Affinity *Small business owners*
- **Demographics:** 24–55, all genders, all household incomes
- Keywords (content targeting): `cafe business`, `restaurant owner`, `small business india`

---

## 4. Launch checklist

- [ ] GA4 live on the landing page; `generate_lead` shows in Realtime after a WhatsApp tap
- [ ] GA4 ↔ Google Ads linked; conversion imported and set **Primary**
- [ ] Both videos uploaded to YouTube with the music credit; channel linked
- [ ] Billing + any new-advertiser credit offer added
- [ ] Campaign A live (Search, ₹200/day) — check impressions appear within ~1 hour
- [ ] Campaign B live (Video, ₹100/day)
- [ ] **Turn on auto-tagging:** Tools → Campaign settings →
      *Campaign URL options* → Auto-tagging = On (lets Ads see which click
      became a WhatsApp tap)

---

## 5. The 14-day routine (10 min/day max)

**Every 2–3 days — Search terms report** (Campaign A → Insights → Search
terms): any searched phrase that got 3+ clicks and cost you ₹50+ with zero
WhatsApp taps → add it as an exact-match negative.

**Day 3:** if a headline set shows under 2% CTR after ~1,000 impressions,
rewrite the worst 3 headlines (keep the winners). RSAs learn — don't touch
them every day.

**Day 7:** pause any keyword that spent ₹150+ with zero WhatsApp taps.
Keep spending what's left on the winners.

**Day 14 — decide:**
- ≥2 trials → keep budget, consider +₹100/day to the better campaign
- 1 trial → another 14 days, same budget
- 0 trials, 10+ WhatsApp conversations → **your sales follow-up is the
  bottleneck, not the ads**
- 0 WhatsApp conversations after ~₹2,000 search spend → fix landing page /
  offer first (cheaper than more clicks)

⚠️ Google Ads conversion numbers lag GA4 by ~24–48h. Trust GA4 Realtime for
same-day truth.

---

## 6. When a lead taps WhatsApp

Reply within 5 minutes in business hours. The 10-minute demo script:
1. Show a bill being created (₹0 setup cost, UPI/QR)
2. Show the kitchen screen receiving it
3. Show end-of-day: *"here's exactly what you earned today"*
4. Then: *"I'll put you on the free 14-day trial — no card."*

**Trial delivery today = iPhone** (your build is IPA-only). For remote
trials: WhatsApp them the IPA + iLoader instructions, or meet for a 15-min
install. If demand for Android trials appears, adding an Android build to
GitHub Actions is ~15 min of work and **doubles your addressable market** —
then swap the "Works on your iPhone" headline for "Works on any phone".

---

## 7. Optional upgrades (not blockers)

- **Custom domain** (~₹100–900/yr): `cafepos.in` or similar → GitHub Pages
  CNAME. A real domain lifts ad CTR and trust; do it by month 2.
- **YouTube channel polish:** banner + 2-line description = free credibility
  when people click through to your channel from the video ad.
