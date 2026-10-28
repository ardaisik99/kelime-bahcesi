# Content review — chain data (TR / EN)

Scope: `data/levels_tr.json` and `data/levels_en.json`. Both files hold **18 chains**
(6 `kitchen`, 6 `nature`, 6 `daily`), 4–5 words each, one hint per word and one link per
gap. This document records a hand review of every chain plus the Turkish fixes made in
this pass. It is a product content review, not an external linguistic certification.

## Roots vs. inflected links

- `words[]` are uppercase, uninflected **roots**: single tokens, Turkish letters only
  (checked by `core/content.gd` against the TR alphabet).
- `links[]` are the full natural expression joining two adjacent roots. The right-hand
  element carries whatever inflection the compound needs: possessive `-ı/-i/-u/-ü`,
  buffer `-s-`/`-n-`, or a stem change — `BARDAK → bardak altlığı`,
  `KORUYUCU → ekran koruyucusu`, `KAPI → giriş kapısı`, `AY → ocak ayı`,
  `AĞAÇ → sakız ağacı`, `KAPAK → kavanoz kapağı`.
- Therefore a link does **not** have to contain the right-hand root verbatim
  (`altlık` → `altlığı`, `koruyucu` → `koruyucusu`). The loader only requires each link
  to start with its left-hand root, so these stem changes are intentional, not errors.
- Hints describe the **root's meaning**, not the finished link. A hint may therefore
  cover the sense the compound uses even when the literal gloss differs; it never has to
  repeat the link's word order.
- English links work the same way with noun + noun compounds; English has no possessive
  suffix, so roots and link words match except for ordinary spelling
  (`potato → potato chip`).

## Turkish changes in this pass

All 18 Turkish chain ids are unchanged — backend, clients and existing saves key on
`id`, so only words, hints, links and one title moved.

1. **`tr_kitchen_lemon_water`** — last root `ALT` → `ALTLIK`. The old tail
   `bardak altı` was a spatial phrase (“under the glass”), not a compound noun; the
   object is `bardak altlığı`. Hint is now
   “Bardağın altına konan küçük koruyucu parça”; link `bardak altlığı`.
   Chain: `LİMON SU BARDAK ALTLIK` → limon suyu / su bardağı / bardak altlığı.
2. **`tr_kitchen_fish_bread`** — `balık ekmek` is a lexicalised food name (fish served in
   bread), not an `isim tamlaması`, so the chain no longer starts there. Id kept,
   title changed to **“Fırın hazırlığı”**, words
   `["BUĞDAY", "EKMEK", "FIRIN", "KÜREK"]`, links
   `buğday ekmeği / ekmek fırını / fırın küreği`. First hint rewritten for the grain
   (“Un yapımında kullanılan tahıl tanesi”); the other three hints already described
   `EKMEK`, `FIRIN`, `KÜREK` and were kept.
3. **`tr_daily_phone_screen`** — final link `ekran koruyucu` → `ekran koruyucusu`
   (third-person possessive is required in the compound). Root `KORUYUCU` stays, hint and
   the first two links are untouched.
4. **`tr_kitchen_tea_time`** — the `HAVA` hint described weather only, which does not
   explain `oyun havası`. It is now
   “Oyun oynarken çalınan ezgi; atmosfer anlamı da vardır”, covering the tune sense and
   the atmosphere sense. Words and links (`çay kaşığı / kaşık oyunu / oyun havası`) are
   unchanged.

## Turkish chains — all links are natural compounds

| id | chain |
| --- | --- |
| `tr_kitchen_tea_time` | ÇAY KAŞIK OYUN HAVA → çay kaşığı, kaşık oyunu, oyun havası |
| `tr_kitchen_lemon_water` | LİMON SU BARDAK ALTLIK → limon suyu, su bardağı, bardak altlığı |
| `tr_kitchen_fish_bread` | BUĞDAY EKMEK FIRIN KÜREK → buğday ekmeği, ekmek fırını, fırın küreği |
| `tr_kitchen_flower_honey` | ÇİÇEK BAL KAVANOZ KAPAK → çiçek balı, bal kavanozu, kavanoz kapağı |
| `tr_kitchen_dinner_table` | YEMEK MASA LAMBA IŞIK → yemek masası, masa lambası, lamba ışığı |
| `tr_kitchen_tea_house` | ÇAY OCAK AY TAKVİM YAPRAK → çay ocağı, ocak ayı, ay takvimi, takvim yaprağı |
| `tr_nature_rain_drop` | YAĞMUR DAMLA SAKIZ AĞAÇ KABUK → yağmur damlası, damla sakızı, sakız ağacı, ağaç kabuğu |
| `tr_nature_bee_hive` | BAL ARI KOVAN GİRİŞ KAPI → bal arısı, arı kovanı, kovan girişi, giriş kapısı |
| `tr_nature_sea_star` | DENİZ YILDIZ ÇİÇEK BAHÇE KAPI → deniz yıldızı, yıldız çiçeği, çiçek bahçesi, bahçe kapısı |
| `tr_nature_forest_fire` | ORMAN YANGIN KULE SAAT → orman yangını, yangın kulesi, kule saati |
| `tr_nature_sea_lantern` | DENİZ FENER BALIK AĞ → deniz feneri, fener balığı, balık ağı |
| `tr_nature_river_bed` | NEHİR YATAK ODA MÜZİK → nehir yatağı, yatak odası, oda müziği |
| `tr_daily_book_cover` | KİTAP KAPAK RESİM DEFTER YAPRAK → kitap kapağı, kapak resmi, resim defteri, defter yaprağı |
| `tr_daily_coffee_machine` | KAHVE MAKİNE MÜHENDİSLİK FAKÜLTE → kahve makinesi, makine mühendisliği, mühendislik fakültesi |
| `tr_daily_bus_ticket` | OTOBÜS BİLET GİŞE MEMUR → otobüs bileti, bilet gişesi, gişe memuru |
| `tr_daily_phone_screen` | CEP TELEFON EKRAN KORUYUCU → cep telefonu, telefon ekranı, ekran koruyucusu |
| `tr_daily_cinema_garden` | SİNEMA SALON BİTKİ ÇAY BAHÇE → sinema salonu, salon bitkisi, bitki çayı, çay bahçesi |
| `tr_daily_wall_clock` | DUVAR SAAT KULE KAPI → duvar saati, saat kulesi, kule kapısı |

Every Turkish link is a two-noun `isim tamlaması` with the correct possessive; no link is
a bare phrase, an adjective + noun, or a lexicalised dish name. Hints are distinct within
each chain and each one identifies its root without spelling out the compound.

## English chains — all links are natural compounds

| id | chain |
| --- | --- |
| `en_kitchen_ice_cream_soda` | ICE CREAM SODA POP → ice cream, cream soda, soda pop |
| `en_kitchen_jacket_potato` | JACKET POTATO SALAD DRESSING → jacket potato, potato salad, salad dressing |
| `en_kitchen_rice_noodle_soup` | RICE NOODLE SOUP BOWL → rice noodle, noodle soup, soup bowl |
| `en_kitchen_sugar_cookie` | SUGAR COOKIE JAR OPENER → sugar cookie, cookie jar, jar opener |
| `en_kitchen_pot_roast` | POT ROAST BEEF SANDWICH → pot roast, roast beef, beef sandwich |
| `en_kitchen_potato_chip` | POTATO CHIP DIP BOWL → potato chip, chip dip, dip bowl |
| `en_nature_pine_tree` | PINE TREE HOUSE PLANT → pine tree, tree house, house plant |
| `en_nature_water_lily` | WATER LILY POND SKATER → water lily, lily pond, pond skater |
| `en_nature_sand_dune` | SAND DUNE BUGGY WHIP → sand dune, dune buggy, buggy whip |
| `en_nature_flower_pot` | FLOWER POT PLANT FOOD → flower pot, pot plant, plant food |
| `en_nature_food_chain` | PLANT FOOD CHAIN LINK → plant food, food chain, chain link |
| `en_nature_winter_storm` | WINTER STORM FRONT DOOR → winter storm, storm front, front door |
| `en_daily_book_club` | BOOK CLUB SANDWICH BOARD GAME → book club, club sandwich, sandwich board, board game |
| `en_daily_lift_ticket` | LIFT TICKET OFFICE PARTY LINE → lift ticket, ticket office, office party, party line |
| `en_daily_garage_sale` | GARAGE SALE PRICE TAG → garage sale, sale price, price tag |
| `en_daily_school_bus` | SCHOOL BUS STOP SIGN → school bus, bus stop, stop sign |
| `en_daily_coffee_break` | COFFEE BREAK ROOM KEY → coffee break, break room, room key |
| `en_daily_fire_alarm` | FIRE ALARM CLOCK TOWER → fire alarm, alarm clock, clock tower |

Each English link is an established noun + noun compound, so the set stays consistent
with the Turkish `isim tamlaması` rule. Two known weak spots were rejected rather than
shipped:

- **`ICE CREAM CONE HEAD`** (ice cream → cream cone → cone head) — `cream cone` is not an
  idiomatic compound; the kitchen entry keeps `ICE CREAM SODA POP` instead.
- **`BALIK EKMEK`** — a dish name, not a possessive compound (see fix 2 above).

The `LINE` hint was also refined to “A shared telephone connection; also a long narrow
mark”, so its meaning now fits `party line` while retaining the root's general sense.

## Verification

- Structure per language: 18 chains, 6 per category, 4–5 roots, hints = words,
  links = words − 1, unique ids and unique ordered chains, all links start with their
  left-hand root.
- `godot --headless --path . --script tests/test_content.gd` (Godot 4.5.2 stable,
  `Godot_v4.5.2-stable_win64_console.exe`) → **PASS (1255 checks)**, exit code 0.
  The suite loads the JSON through `I18n`/`Content` without starting the UI, so it covers
  both language files, the alphabet check, prefix rules and random selection.
- No chain ids changed in either language file.
