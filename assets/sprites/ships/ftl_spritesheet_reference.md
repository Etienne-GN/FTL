# FTL: Faster Than Light — Ship Spritesheet Reference

Source for all 10 files: ripped by "SuperFlomm" for The Spriters Resource, FTL (c) 2012 Subset Games.
All files are RGBA PNGs. There are **two layout templates** used across the set — figure out which one a
given file uses by checking the top-left corner alpha and the background fill color, then apply the
matching coordinate table below.

## The two templates

### Template A — "Labeled" (Kestrel, Engi, Federation, Zoltan)
- Fully transparent background (alpha = 0) except for a solid **orange** fill (RGB ≈ 208,126,10) used
  behind the bottom "cut-apart parts" section.
- Each of the 3 columns has a black rounded-rect **name badge** at the very top.
- Row order top→bottom: main ship sprite → collision mask (one per column) → interior floor-plan →
  effects row (shield bubble / wireframe hologram / credits box) → small ship-select icon cluster →
  cut-apart body-part thumbnails on orange tiles.

### Template B — "Unlabeled" (Mantis, Crystal, Lanius, Rock, Slug, Stealth)
- Background is a solid opaque **coral/red** fill (RGB ≈ 216,99,99), not transparent, except thin
  transparent margins at the outer edges.
- **No name badges** — variants are distinguished only by hull color.
- **No floor-plan row.**
- Row order top→bottom: 3 main ship sprites → only **2** collision-mask shapes (main hull + one detached
  appendage, e.g. claw/wing — shared across all 3 colors since the hull geometry doesn't change) →
  wireframe hologram outline + shield-bubble ellipse (2 panels) → 3 full-width rows of cut-apart
  body-part thumbnails, **one row per color variant**, each with several panels left-to-right.

All pixel coordinates below are derived from alpha/background connected-component analysis of the actual
files (not hand-measured) — treat them as reliable but do a quick visual sanity-crop before hardcoding
into production code, especially for the small sub-panels.

---

## 1. Kestrel Cruiser — Template A
**File:** `..._Kestrel_Cruiser.png` · **Size:** 2135 × 2660 px

| Column | Skin | x-range |
|---|---|---|
| 1 | The Kestrel — grey hull, orange-red stripes | 72–698 |
| 2 | Red-Tail — orange/copper hull, cyan pipes | 784–1410 |
| 3 | The Swallow — purple/grey camo hull | 1496–2122 |

| Band | y-range | Content |
|---|---|---|
| Header | 0–49 | Name badges |
| Main sprite | 74–465 | Top-down flight sprite |
| Collision mask | 582–840 | Grey silhouette (identical across columns) |
| Floor plan | 1026–1278 | Interior deck layout |
| Effects | 1430–1770 | Col1: shield bubble. Col2: wireframe hologram. Col3: credit box |
| Selector icons | ~1830–1970 | Lock icon + 3 small color thumbnails |
| Cut-apart parts | ~2110–2660 | Front / cockpit / engine / wing pieces on orange tiles, per column |

---

## 2. Engi Cruiser — Template A
**File:** `..._Engi_Cruiser.png` · **Size:** 1472 × 2676 px

| Column | Skin | x-range |
|---|---|---|
| 1 | The Torus — grey/white hull | 39–452 |
| 2 | The Vortex — dark maroon/red hull | 530–943 |
| 3 | Tetragon — blue-grey hull | 1021–1434 |

| Band | y-range | Content |
|---|---|---|
| Header | 0–49 | Name badges |
| Main sprite | 119–419 | Blocky, irregular Engi hull |
| Collision mask | 581–839 | Grey silhouette |
| Floor plan | 1025–1277 | Interior deck layout |
| Effects | 1370–1770 | Col1: shield bubble. Col2: wireframe hologram. Col3: credit box |
| Selector icons | ~1830–1970 | Lock icon + 3 small color thumbnails |
| Cut-apart parts | ~1990–2676 | Front section / detached piece / body-engine section / damaged-state hull, per column |

---

## 3. Federation Cruiser — Template A
**File:** `..._Federation_Cruiser.png` · **Size:** 2417 × 2774 px

| Column | Skin | x-range |
|---|---|---|
| 1 | The Osprey — grey/white hull, orange stripe | 90–771 |
| 2 | Nisos — dark olive/black hull, yellow stripe | 896–1577 |
| 3 | The Fregatidae — red/black hull, red camo pattern | 1702–2383 |

| Band | y-range | Content |
|---|---|---|
| Header | 0–49 | Name badges |
| Main sprite | 118–492 | Elongated cruiser with twin rear engine pods |
| Collision mask | 648–976 | Grey silhouette |
| Floor plan | 1161–1477 | Interior deck layout |
| Effects | 1568–~1970 | Col1: shield bubble. Col2: wireframe hologram. Col3: credit box + selector-icon cluster (lock icon + 3 thumbnails) |
| Cut-apart parts | ~1990–2774 | Front pod / rear engine block / mid-hull-with-stripe pieces, per column |

---

## 4. Zoltan Cruiser — Template A (compact variant)
**File:** `..._Zoltan_Cruiser.png` · **Size:** 1924 × 1862 px

Same row order as the other Template A ships, but noticeably more compact vertically: the collision-mask
band and the floor-plan band sit directly against each other with no gap between them, and the cut-apart
section is split into **3 stacked sub-rows of 2 pieces each** per column instead of one row of 4.

| Column | Skin | x-range |
|---|---|---|
| 1 | The Adjudicator — green hull, orange accent lights | 14–617 |
| 2 | Noether — dark olive/teal hull, white accent lights | 655–1258 |
| 3 | Cerenkov — black/maroon hull, white accent lights | 1306–1909 |

| Band | y-range | Content |
|---|---|---|
| Header | 1–49 | Name badges |
| Main sprite | 63–386 | Rounded, layered saucer-like Zoltan hull |
| Collision mask + floor plan (combined block) | 402–905 | Mask on top, floor-plan directly beneath, no separating gap |
| Effects | 906–1306 | Col1: shield bubble. Col2: wireframe hologram. Col3: credit box + selector-icon cluster |
| Cut-apart parts | 1307–1861 | 3 rows × 2 pieces per column (top saucer-cap piece + lower hull-body piece), one row-pair per y-band: 1307–1402/1403–1530, 1531–1701/1531–1690 (side pieces), 1702–1861/1702–1833 |

---

## 5. Mantis Cruiser — Template B
**File:** `..._Mantis_Cruiser.png` · **Size:** 1980 × 2069 px

| Panel | x-range | Hull color |
|---|---|---|
| 1 | 15–638 | Red |
| 2 | 666–1289 | Dark purple/slate with teal trim |
| 3 | 1317–1940 | Dark teal/black |

| Band | y-range | Content |
|---|---|---|
| Main sprites | 14–455 | 3 side-by-side panels |
| Collision masks | 474–836 | Panel A (2–434): body mask. Panel B (442–839): claw/pincer mask |
| Overlays | 842–1282 | Left (2–612): wireframe hologram. Right (614–1314): shield bubble |
| Parts row 1 (red) | 1298–1524 | 6 panels: x≈16–256, 287–597, 635–934, 972–1367, 1399–1719, 1761–1968 |
| Parts row 2 (purple/teal) | 1562–1788 | same x-columns as row 1 |
| Parts row 3 (dark teal) | 1826–2052 | same x-columns as row 1 |

---

## 6. Crystal Cruiser — Template B
**File:** `..._Crystal_Cruiser.png` · **Size:** 1457 × 2535 px

| Panel | x-range | Hull color |
|---|---|---|
| 1 | 13–708 | Pale teal/cyan crystalline hull |
| 2 | 735–1430 | Deep red crystalline hull |

(Only 2 color variants shown on this sheet, unlike the others' 3.)

| Band | y-range | Content |
|---|---|---|
| Main sprites | 13–444 | 2 side-by-side panels |
| Collision masks | 462–757 | Panel A (547–1049): larger body mask. Panel B (4–541): smaller mask |
| Overlays | 761–1245 | Wireframe hologram (2–684) + shield bubble (687–1457) |
| Parts row 1 (teal) | 1262–1511 | 3 panels: x≈15–463, 493–829, 866–1214 |
| Parts row 2 (teal, cont.) | 1547–1880 | 3 panels: x≈14–620, 653–1001, 1038–1319 |
| Parts row 3 (red) | 1910–2159 | mirrors row 1 x-columns |
| Parts row 4 (red, cont.) | 2195–2528 | mirrors row 2 x-columns |

---

## 7. Lanius Cruiser — Template B
**File:** `..._Lanius_Cruiser.png` · **Size:** 1247 × 2710 px

| Panel | x-range | Hull color |
|---|---|---|
| 1 | 14–586 | Grey/black mechanical spider-like hull |
| 2 | 615–1187 | Same hull, alternate dark colorway |

Sprite is a jagged, insectoid/mechanical claw-armed hull, consistent with the Lanius species theme.

| Band | y-range | Content |
|---|---|---|
| Main sprites | 14–592 | 2 side-by-side panels |
| Collision masks | 608–970 | Panel A (298–625): body mask. Panel B (2–294): claw-appendage mask |
| Overlays | 972–1541 | Wireframe hologram (3–561) + shield bubble (565–1247) |
| Parts row 1 | 1556–1821 | 3 panels: x≈14–386, 409–677, 704–1068 |
| Parts row 2 | 1845–2114 | 3 panels: x≈12–339, 368–698, 732–1164 |
| Parts row 3 | 2142–2407 | mirrors row 1 x-columns |
| Parts row 4 | 2431–2700 | mirrors row 2 x-columns |

---

## 8. Rock Cruiser — Template B
**File:** `..._Rock_Cruiser.png` · **Size:** 1919 × 1981 px

| Panel | x-range | Hull color |
|---|---|---|
| 1 | 14–536 | Rust-orange/brown blocky "X"-shaped hull |
| 2 | 565–1087 | Black hull with red glowing seams |
| 3 | 1116–1638 | Light blue-grey hull |

| Band | y-range | Content |
|---|---|---|
| Main sprites | 13–386 | 3 side-by-side panels |
| Collision masks | 406–663 | Panel A (4–331): body mask. Panel B (339–665): secondary mask |
| Overlays | 668–1104 | Wireframe hologram (29–540) + shield bubble (571–1225) |
| Parts row 1 (orange) | 1119–1384 | 6 panels: x≈18–268, 300–554, 588–900, 938–1235, 1275–1619, 1660–1894 |
| Parts row 2 (black) | 1413–1678 | same x-columns as row 1 |
| Parts row 3 (blue-grey) | 1707–1972 | same x-columns as row 1 |

---

## 9. Slug Cruiser — Template B
**File:** `..._Slug_Cruiser.png` · **Size:** 1800 × 2242 px

| Panel | x-range | Hull color |
|---|---|---|
| 1 | 18–582 | Dark olive-green rounded hull |
| 2 | 613–1177 | Dark grey/black hull |
| 3 | 1208–1772 | Warm brown/tan hull |

| Band | y-range | Content |
|---|---|---|
| Main sprites | 12–451 | 3 side-by-side panels |
| Collision masks | 468–832 | Panel A (3–295): body mask. Panel B (303–735): secondary mask |
| Overlays | 837–1289 | Wireframe hologram (30–583) + shield bubble (615–1269) |
| Parts row 1 (olive) | 1334–1613 | 6 panels: x≈14–263, 299–561, 597–941, 981–1152, 1184–1414, 1449–1784 |
| Parts row 2 (grey/black) | 1643–1922 | same x-columns as row 1 |
| Parts row 3 (tan) | 1952–2231 | same x-columns as row 1 |

---

## 10. Stealth Cruiser — Template B
**File:** `..._Stealth_Cruiser.png` · **Size:** 2229 × 1816 px

| Panel | x-range | Hull color |
|---|---|---|
| 1 | 21–582 | Black hull, dark blue cockpit panel |
| 2 | 617–1178 | Grey urban-camo pattern |
| 3 | 1213–1774 | Desert/orange-brown camo pattern |

Sleek dart/jet-shaped hull (swept wings, forward-pointed nose) — visually distinct from the other blocky cruisers.

| Band | y-range | Content |
|---|---|---|
| Main sprites | 12–426 | 3 side-by-side panels |
| Collision masks | 441–698 | Panel A (3–470): body mask. Panel B (479–911): wing mask |
| Overlays | 702–1194 | Wireframe hologram (26–585) + shield bubble (616–1316) |
| Parts row 1 (black/blue) | 1208–1360 | 6 panels: x≈18–320, 366–640, 679–1138, 1168–1490, 1532–1843, 1880–2212 |
| Parts row 2 (grey camo) | 1417–1569 | same x-columns as row 1 |
| Parts row 3 (desert camo) | 1626–1778 | same x-columns as row 1 |

---

## Practical notes for a generic loader
- Detect template first: sample a background pixel — alpha 0 with orange (208,126,10) tiles further down = Template A; opaque coral-red (216,99,99) fill = Template B.
- Template A: use alpha-based row/column gap detection (rows/cols where `alpha > 10` count drops near zero) to find panel boundaries automatically.
- Template B: alpha-gap detection won't work since the background is opaque — instead build a boolean mask of "not background color and not transparent" and run connected-component labeling (e.g. `scipy.ndimage.label`) to get each panel's bounding box directly.
- Every ship file's collision-mask shape is reusable across that ship's own color variants (paint doesn't change hull geometry), so you only need to load/cache one mask per ship, not one per skin.
