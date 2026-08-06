# Dragon Jump — Implementation Plan

**Tarih:** 6 Ağustos 2026
**Durum:** Updated per Codex review + Xaden control decisions
**Document precedence:** PROJECT_CONTEXT.md > ARCHITECTURE.md > REQUIREMENTS.md > IMPLEMENTATION_PLAN.md

---

## Genel Yaklaşım

- Milestone'lar küçük vertical slice'lara bölünmüştür (Codex review C7)
- Her slice bir Codex görevidir
- Her görevde: diff review + test + rapor
- Object pooling premature — instantiate/free ile başla, profiler gerekince pool ekle
- Power-up'lar (propeller/jetpack/spring shoes) V1'de YOK

---

## M1 — Core Prototype

**Süreç:** Codex high reasoning
**Brief:** docs/codex-briefs/TASK-001.md

### Hedef
Oynanabilir minimal prototip: ejderha yukarı zıplar, one-way platformlar prosedürel spawn olur, skor yükselir, düşince oyun biter.

### Görevler
1. Godot project oluştur (res:// yapısı, project.godot)
2. RunSession.gd — state (READY→PLAYING→GAME_OVER), score = max altitude, RNG seed
3. ProfileStore.gd — ConfigFile save/load, high score, schema version
4. Player.tscn — CharacterBody2D + AnimatedSprite2D (placeholder) + CollisionShape2D
5. Player.gd — auto-jump (platform contact), horizontal move (tap + keyboard), wrap-around
6. Platform.tscn — one-way StaticBody2D + Sprite2D + CollisionShape2D
7. PlatformManager.gd — procedural spawn (seeded RNG), reachability guarantee, instantiate/free
8. Camera2D — follows player upward
9. HUD.tscn — score label + high score label
10. Main.tscn — root scene

### Kabul Kriterleri
- Oyun Godot editor'de F5 ile çalışıyor
- Ejderha zıplayarak yukarı çıkıyor
- One-way platformlar prosedürel spawn oluyor (alttan geçilebilir, üstten landing)
- Skor = max altitude (current position değil)
- Düşünce game over
- Tap ile sol/sağ hareket (keyboard fallback: arrows)
- Wrap-around çalışıyor
- High score save/load çalışıyor
- Seeded RNG deterministic (aynı seed = aynı platform layout)

### Test
- Editor içi manuel test (F5)
- GUT unit test: spawn logic, score calculation, save/load
- Headless seed test: 100 seeds, reachability validation

---

## M1.5 — Android Smoke Build

**Brief:** docs/codex-briefs/TASK-002.md

### Hedef
Android export pipeline çalışır durumda, tilt + touch test edilmiş.

### Görevler
1. Android export preset oluştur
2. Debug keystore oluştur
3. APK export (debug)
4. Emulator install + launch
5. Touch input test (emulator)
6. Sensor read test (emulator)
7. Pause/resume test
8. Audio focus test

### Kabul Kriterleri
- Debug APK üretiliyor
- Emulator'de açılıyor
- Touch çalışıyor
- Pause/resume çalışıyor

---

## M2 — Core Gameplay (slice'lara bölünmüş)

### M2a — Platform Türleri
**Brief:** docs/codex-briefs/TASK-003.md
- Moving platform (AnimatableBody2D)
- Breakable platform (Area2D trigger + delete)
- Disappearing platform (Area2D trigger + timer)
- Spring platform (Area2D trigger + boost velocity)
- Test: her tür landing, underside pass-through, break/disappear timing

### M2b — Düşmanlar
**Brief:** docs/codex-briefs/TASK-004.md
- Wyvern (uçan, hareketli, ateşle yok edilir)
- Sabit canavar (temas = ölüm, ateşle yok edilir)
- EnemyManager — spawn, enemy exclusion around mandatory landings
- Test: collision matrix, ateş ile yok edilme, düşman spawn safety

### M2c — Ejderha Yetenekleri + Input
**Brief:** docs/codex-briefs/TASK-005.md
- InputController.gd — touch (tap/çift tap/hold/çift tap+hold) + tilt + keyboard
- Tilt dead-zone + calibration + smoothing
- Double jump (çift tap havadayken, unlock gerekir)
- Glide (çift tap + hold, unlock gerekir)
- Fire breath (sağ-alt buton, limited ammo, yukarı ateş)
- AbilityController.gd — cooldown management
- CoinManager — coin spawn + collection
- Test: ability chaining, cooldown boundaries, ammo limits, tilt dead-zone

### M2d — Difficulty + Economy
**Brief:** docs/codex-briefs/TASK-006.md
- Difficulty scaling (platform frequency, enemy frequency, gap size)
- Coin economy tuning (ability upgrade costs)
- ProfileStore — ability unlock + upgrade persistence
- AnimatedSprite2D — dragon animasyon (idle, jump, fire, glide, double_jump)
- Test: economy balance, difficulty curve, 10-min performance soak

---

## M3 — Polish + Meta

**Brief:** docs/codex-briefs/TASK-007.md

### Görevler
1. ParallaxBackground — sky/cloud layers
2. Sound effects — jump, fire, coin, death, double jump, glide
3. Background music — cartoon uyumlu loop
4. AudioManager.gd — bus management, mute toggle
5. MainMenu.tscn — Play, High Score, Settings
6. GameOverScreen.tscn — score, high score, retry
7. SettingsMenu.tscn — sound, control preference, tilt calibration
8. Particles — jump dust, fire breath, coin sparkle
9. Screen shake on death
10. Safe-area + orientation + aspect ratio handling

### Test
- Full playthrough
- Save/load corruption + migration
- Multiple aspect ratios
- 10-min thermal soak

---

## M4 — Monetization + Release Prep

**Brief:** docs/codex-briefs/TASK-008.md

### Görevler
1. PlatformServices — AdManager + BillingManager + ConsentFlow
2. AdMob plugin v2 kurulumu
3. Banner — main menu
4. Interstitial — game over (every N deaths)
5. Rewarded video — revive + 2x score
6. Google Play Billing — remove ads + skin packs
7. Purchase acknowledge, restore, refund handling
8. Consent/privacy flow (GDPR/CCPA)
9. Ad failure: no-fill, offline, cancelled
10. Skin inventory/equip UI
11. Release keystore (Xaden sağlar)
12. Signed APK build
13. Play Store listing — title, description, screenshots, icon
14. Privacy policy (ads + SDK disclosure)

### Test
- AdMob test ads
- IAP test purchase + restore
- No-fill/offline/cancelled ad handling
- APK install + run

---

## M5 — WebGL Export (Post-launch)

**Brief:** docs/codex-briefs/TASK-009.md (post-launch)
- Web export preset
- Feature gating: ads, billing, sensors disabled on web
- Touch + keyboard kontrol
- Browser test
- Deploy (itch.io veya kendi site)

---

## Codex Kullanım Stratejisi

| Milestone | Reasoning | Lane |
|---|---|---|
| M1 | high | 1 |
| M1.5 | medium | 1 |
| M2a-d | high | 1 (sıralı) |
| M3 | medium-high | 1 |
| M4 | high | 1 |
| M5 | medium | 1 |

---

## Dependency Manifest (Codex review önerisi)

| Dependency | Version | License | Engine Compat |
|---|---|---|---|
| Godot | 4.7.1 | MIT | — |
| GUT | latest | MIT | Godot 4.x |
| AdMob plugin | TBD (v2) | TBD | Godot 4.2+ |
| Google Play Billing | TBD | Apache 2.0 | Godot 4.2+ |
| Free sprites | Kenney/itch.io | CC0/CC-BY | — |
| Free music | freesound/opengameart | CC0/CC-BY | — |

---

## Risk ve Mitigasyon

| Risk | Mitigasyon |
|---|---|
| Godot Android export ilk kez | M1.5 erken smoke build |
| AdMob plugin v2 uyumsuzluğu | M4 öncesi plugin sürüm pin |
| AI ürettiği GDScript hatalı | Her slice'da diff review + test |
| Asset eksikliği | Placeholder sprite, sonra Gemini handoff |
| Performans düşük | M2d sonrası profiler check |
| Coin ekonomisi dengesiz | M2d playtest + tuning |
| Tilt feel across devices | M1.5 calibration test |
| Procedural unfairness | Headless seed test (1000 seeds) |