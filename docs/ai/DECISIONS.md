# Dragon Jump — Decisions

**Tarih:** 6 Ağustos 2026
**Updated:** Codex review + Xaden control decisions

---

## D-01: Oyun Motoru — Godot 4.7.1
**Karar:** Godot 4.7.1 + GDScript
**Gerekçe:** AI dostu, hafif mobil 2D, MIT lisans, düşük öğrenme eğrisi
**Onay:** Xaden

## D-02: Programlama Dili — GDScript
**Karar:** GDScript
**Onay:** Xaden

## D-03: Platform Önceliği — Android
**Karar:** Android ilk hedef, iOS sonra, WebGL sonra
**Onay:** Xaden

## D-04: Min Android API — 24
**Karar:** API 24 (Android 7.0)
**Gerekçe:** %99+ cihaz kapsamı
**Onay:** Xaden

## D-05: Performans Hedefi — Orta+
**Karar:** 4GB+ RAM hedef, düşük uçta çalışır ama optimize değil
**Onay:** Xaden

## D-06: Backend — Yok (V1)
**Karar:** Çevrim dışı, local high score
**Onay:** Xaden

## D-07: Sanat Tarzı — Cartoon
**Karar:** Cartoon/karton, ejderha ciddi/cesaretli
**Onay:** Xaden

## D-08: Kontrol — Tap + Tilt
**Karar:** Tilt (yatay) + tek tap (yatay) + çift tap (double jump) + çift tap+hold (glide)
**Onay:** Xaden

## D-09: Oturum — Sonsuz/High-Score
**Karar:** Sonsuz prosedürel, max altitude score
**Onay:** Xaden

## D-10: Para Kazanma — Hibrit Reklam + IAP
**Karar:** Interstitial + rewarded + banner + IAP
**Onay:** Xaden

## D-11: Ejderha Yetenekleri — Power-up YOK
**Karar:** Ateş (buton, ammo limitli, coin upgrade), double jump (çift tap, coin unlock), glide (çift tap+hold, coin unlock)
**Reddedilen:** Power-up mekaniği (propeller/jetpack/spring shoes) — V1'de yok, V2'de maybe
**Onay:** Xaden

## D-12: Düşmanlar — 2 Tip
**Karar:** Wyvern + sabit canavar (V1), V2'de daha fazla
**Onay:** Xaden

## D-13: Tema — Gökyüzü
**Karar:** Tek tema (gökyüzü), V2'de çeşitlilik + gece/gündüz
**Onay:** Xaden

## D-14: UI Dili — İngilizce
**Karar:** İlk sürüm İngilizce, Türkçe V2
**Onay:** Xaden

## D-15: Asset — Free Pack → Gemini Handoff
**Karar:** Prototip free asset pack, sonra Gemini ile özel üretim
**Onay:** Xaden

## D-16: Sanat Aracı — Photopea
**Karar:** Xaden Photopea kullanır, GIMP yok
**Onay:** Xaden

## D-17: VS Code Extension — geequlim.godot-tools
**Karar:** geequlim.godot-tools v2.7.1
**Onay:** Xaden

## D-18: JDK — 17 + 21
**Karar:** JDK 17 (Godot Android export), JDK 21 backup
**Onay:** Xaden

## D-19: Kontrol Şeması (Codex review C2 fix)
**Karar:**
- Tilt: yatay hareket (sürekli, dead-zone + calibration)
- Tek tap: yatay hareket (sol/sağ ekran yarısı)
- Çift tap (havadayken, 300ms içinde): double jump
- Çift tap + hold (havadayken): double jump sonra glide
- Ateş: sağ-alt yüzen buton
- Pause: sağ-üst buton
- Keyboard fallback (desktop): arrows + space + F + Escape
**Onay:** Xaden

## D-20: Platform Fiziği (Codex review C3 fix)
**Karar:** One-way StaticBody2D (solid), AnimatableBody2D (moving), Area2D child (trigger)
**Reddedilen:** Area2D as platform (durmaz)
**Onay:** Technical decision

## D-21: State Yönetimi (Codex review C4 fix)
**Karar:** RunSession + ProfileStore + PlatformServices ayrımı
**Reddedilen:** Player-owned persistent unlocks, GameManager-only state
**Onay:** Technical decision

## D-22: Prosedürel Üretim (Codex review C5 fix)
**Karar:** Seeded RNG, reachability guarantee, max gap, safe start region, enemy exclusion
**Onay:** Technical decision

## D-23: Persistence (Codex review moderate fix)
**Karar:** ConfigFile → user://profile.cfg (INI), schema version, no base64
**Reddedilen:** base64 obfuscation, .json extension
**Onay:** Technical decision

## D-24: Object Pooling (Codex review moderate fix)
**Karar:** Instantiate/free ile başla, pool sadece profiler gerekince
**Onay:** Technical decision

## D-25: Android Build Timing (Codex review C7 fix)
**Karar:** M1.5 erken Android smoke build (M4 değil)
**Onay:** Technical decision

## D-26: docs/ Git versiyonlama (Codex review önerisi)
**Karar:** docs/ .gitignore'dan çıkarıldı, versiyonlanacak
**Onay:** Technical decision