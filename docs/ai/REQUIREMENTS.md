# Dragon Jump — Requirements

**Tarih:** 6 Ağustos 2026
**Durum:** Updated per Codex review + Xaden control decisions
**Document precedence:** PROJECT_CONTEXT.md > ARCHITECTURE.md > REQUIREMENTS.md > IMPLEMENTATION_PLAN.md

---

## Fonksiyonel Gereksinimler

### FR-01: Çekirdek Oyun Döngüsü
- Oyuncu (ejderha) yukarı doğru otomatik zıplar
- Platformlara değdiğinde tekrar zıplar (auto-jump)
- Platformdan düşerse (ekranın altından çıkarsa) oyun biter
- Skor = ulaşılan maksimum yükseklik (max altitude)

### FR-02: Kontrol
- Tilt: telefonu sağa/sola yatır → yatay hareket (sürekli)
- Tek tap (sol/sağ ekran yarısı): o yöne yatay hareket
- Çift tap (havadayken, 300ms içinde): double jump (kanat çırpma)
- Çift tap + hold (havadayken): double jump sonra glide (süzülme)
- Hold bırakınca glide biter
- Ekran kenarından çıkınca diğer taraftan giriş (wrap-around)
- Tilt + tap aynı anda aktif, oyuncu ikisini birden kullanabilir
- Tilt dead-zone ve calibration ayarı (ayarlar menüsünden)
- Sensör yoksa (desktop test) tilt devre dışı, sadece tap + klavye

### FR-03: Platform Türleri (V1)
- Statik (sabit) platform
- Hareketli platform (yatayda ileri-geri)
- Kırılabilir platform (değince parçalanır, tek kullanım)
- Kaybolan platform (değince bir süre sonra yok olur)
- Zıplatıcı platform (spring — ekstra yüksek zıplama)
- Platform fiziği: one-way StaticBody2D (altından geçilebilir, üstten landing)
- Collision layers/masks: player sadece yukarı düşüşte platforma değer

### FR-04: Ejderha Yetenekleri (power-up yok)
- Ateş püskürtme — sağ-alt köşede yüzen buton, basınca yukarı ateş
- Mermi limitli, coin ile geliştirilebilir (daha çok mermi)
- Double jump (kanat çırpma) — çift tap (havadayken), coin ile unlock
- Süzülme (glide) — çift tap + hold (havadayken), coin ile unlock
- Yetenekler ana karakter kabiliyeti, power-up (süreli boost) yok
- Cooldown test sırasında belirlenecek

### FR-05: Düşmanlar (V1, 2 tip)
- Wyvern (uçan düşman, hareketli, ateşle yok edilir)
- Sabit canavar (temas = ölüm, ateşle yok edilir)
- V2'de daha fazla tip

### FR-06: Skor ve İlerleme
- Skor = ulaşılan maksimum yükseklik (max altitude, current position değil)
- Local high score kaydı (cihaz üzerinde)
- Zorluk arttıkça platform sıklığı azalır, düşman sıklığı artar
- Prosedürel üretim: her platform önceskine ulaşılabilir olmalı (reachability guarantee)
- Seeded RNG (deterministic generation, test için)

### FR-07: Para Kazanma
- Interstitial reklam: her N ölümden sonra
- Rewarded video: revive + 2x puan
- Banner: ana menüde
- IAP: reklamları kaldır + skin paketleri
- BillingManager: purchase acknowledge, restore, refund handling
- Consent/privacy flow (GDPR/CCPA)
- Ad failure handling: no-fill, offline, cancelled

### FR-08: UI / Menü
- Ana menü: Oyna, High Score, Ayarlar
- Oyun içi HUD: yükseklik/skor, high score, coin, ability icons, ateş butonu, pause butonu
- Ölüm ekranı: skor, high score, "devam et" (rewarded), "yeniden oyna"
- Ayarlar: ses aç/kapa, tilt/tap/ikisi, tilt calibration
- Pause butonu: sağ-üst köşe
- Ateş butonu: sağ-alt köşe (yüzen, yarı saydam)

### FR-09: Ses
- Zıplama, ölüm, ateş, coin, double jump, glide efekt sesleri
- Background music (loop, cartoon uyumlu)
- Ayarlardan ses kapatma

## Teknik Gereksinimler

### TR-01: Hedef Platform
- Android (min API level 24 / Android 7.0)
- APK boyutu < 25 MB

### TR-02: Motor
- Godot 4.7.1
- Compatibility renderer (mobil)

### TR-03: Performans
- 60 FPS hedef (orta seviye cihazlarda, 4GB+ RAM)
- 30 FPS minimum (düşük uç cihazlarda)
- Draw calls < 50, physics objects < 30, memory < 150MB
- Startup < 3 saniye

### TR-04: State Yönetimi
- RunSession: run score, max altitude, ammo, difficulty, RNG seed
- ProfileStore: high score, wallet (coins), unlocks, settings (persistent)
- PlatformServices: ads + billing entitlements
- Run states: READY, PLAYING, PAUSED, REVIVE_PENDING, GAME_OVER
- Persistent unlocks Player node'unda değil, ProfileStore'da

### TR-05: Kayıt
- ConfigFile — user://profile.cfg (INI format, .cfg uzantısı)
- Schema version + migration
- Defaults + validation + corrupt-file recovery
- Base64 YOK (gereksiz karmaşıklık)

### TR-06: Çevrim Dışı
- Oyun çevrim dışı çalışır (gameplay)
- Reklam + IAP networked platform services (ayrı boundary)
- İnternet izni: reklam SDK için gerekli

### TR-07: Android Build
- M1 sonrası erken Android smoke build (M0.5)
- Debug keystore, APK install, touch + sensor test
- Godot Android plugin v2 (v1 deprecated)

## Kısıtlar

- AI ile geliştirme (Codex / Claude)
- Zero-overage spending
- Linux (Ubuntu) geliştirme ortamı
- Çizim üretimi: manuel Gemini/Nano Banana handoff
- docs/ Git'te versiyonlanacak (Codex review önerisi)