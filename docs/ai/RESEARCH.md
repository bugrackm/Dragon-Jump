# Dragon Jump — Research

**Tarih:** 6 Ağustos 2026
**Kaynaklar:** 2 paralel Hermes sub-agent (Kimi K2.7 Code), 50+ ham kaynak dosyası `research_raw/` altında

---

## 1. Oyun Motoru Karşılaştırması

### Karşılaştırma Tablosu

| Motor + Dil | Mobil Performans | AI ile Geliştirme | Asset Store | Plugin Ekosistemi | Reklam SDK | Bakım Maliyeti | WebGL Export |
|---|---|---|---|---|---|---|---|
| **Unity 6 (C#)** | İyi–Mükemmel (URP 2D); APK 15–40 MB | Mükemmel: C# LLM eğitiminde çok yer alır, API zengin ama boilerplate fazla | Mükemmel: en büyük asset store | Mükemmel: binlerce plugin | Mükemmel: AdMob, Unity Ads, AppLovin, Meta hepsi olgun | Yüksek: sık major release, lisans tartışmaları, breaking changes | İyi ama büyük wasm + data |
| **Godot 4 (GDScript)** | İyi: Compatibility renderer düşük uçta iyi; APK 10–25 MB | Mükemmel: GDScript Python benzeri, Node/Signal modeli tutarlı ve küçük, az boilerplate | Orta–İyi: Asset Library büyüyor ama Unity'den küçük | Orta: GDExtension ve addon var ama polish'li commercial plugin az | Orta: dahili reklam yok; AdMob topluluk plugin gerek | Düşük: MIT açık kaynak, royalty yok, stabil LTS | İyi: dahili web export template |
| **Defold (Lua)** | Mükemmel: 2D-first, küçük runtime; APK 1–5 MB | İyi: Lua yaygın ama component/message modeli az biliniyor | Orta: Asset Portal var | Orta–İyi: native extension var | İyi: resmi/topluluk AdMob extension | Düşük: Defold Foundation, ücretsiz | Mükemmel: HTML5 first-class |
| **Cocos Creator (TS/JS)** | İyi ama Cocos2d-x C++ maintenance modunda | Orta: TS/JS agent dostu ama docs az | Orta: Cocos Store küçük | Orta: SDKBox var | Orta: SDKBox ile ama turn-key değil | Orta: Creator aktif ama upgrade kırılmaları | Mükemmel: web first-class |
| **Flame + Flutter (Dart)** | İyi ama oyun motoru değil; APK 8–15 MB | İyi: Dart okunaklı ama LLM'de az temsil | Düşük: oyun asset store yok | İyi: Flutter plugin geniş | İyi: Google Mobile Ads Flutter plugin | Orta: Flutter stabil ama Flame bağımlı | Orta: CanvasKit/HTML renderer |
| **Phaser 3/4 (JS/TS)** | Orta: browser; Android için Cordova/Capacitor wrapper | Mükemmel: JS/TS LLM'de en yaygın | Düşük: resmi store yok | İyi: topluluk plugin | Orta: web reklam; mobile wrapper gerek | Düşük: açık kaynak | Mükemmel: Canvas/WebGL |

### Birincil Öneri: Godot 4 + GDScript

**Gerekçe:**
- AI ile geliştirme dostu: GDScript kısa, tutarlı, az boilerplate. Codex/Claudeç çalışan script üretiyor.
- Mobil performans: 2D-first, Compatibility renderer düşük uçta iyi, APK küçük.
- Android + WebGL export: resmi template, wrapper gerekmez.
- Bakım maliyeti: MIT lisans, royalty yok, stabil release, lisans sürprizi yok.
- Asset/plugin trade-off: Asset Library Unity'den küçük ama vertical platformer az asset gerektirir.

### Alternatif: Unity 6 + C#
Reklam mediasyon ve asset/plugin ekosistemi birinci öncelikse Unity seçilir. Daha büyük APK, daha yüksek bakım riski.

### Kurulum Listesi (Linux / Ubuntu) — Godot 4

| Kategori | Ne kurulacak | Not |
|---|---|---|
| İşletim sistemi | Ubuntu 22.04 LTS / 24.04 LTS | Android toolchain için en stabil |
| Oyun motoru | Godot 4.x editor (Linux x86_64) + export template'ler | godotengine.org'dan indir, extract et, template'leri Editor → Manage Export Templates |
| Android SDK | cmdline-tools, platform-tools, platforms (API 33–35), build-tools | Android Studio veya sdkmanager |
| Android NDK | NDK r23c+ | Özel Android plugin / AdMob plugin için |
| JDK | OpenJDK 17 | Gradle ve Android build için |
| Versiyon kontrol | Git | Zorunlu |
| Kod editörü | VS Code + GDScript extension | Godot built-in de yeter |
| Reklam SDK | Godot AdMob plugin (topululuk Android plugin) | res://android/plugins/ altına eklenir |
| Web test | Python 3 (http.server) | Web export testi için |
| Sanat araçları | GIMP, Krita, Inkscape, Aseprite (opsiyonel) | 2D sprite, animasyon, UI |

---

## 2. Doodle Jump Mekanikleri Analizi

### Çekirdek Döngü
- Otomatik zıplama: platforma değince otomatik zıplar
- Yatay kontrol: tilt / ok tuşları
- Wrap-around: ekran kenarından çıkınca diğer taraftan girer
- Skor = ulaşılan yükseklik (altitude)

### Platform Türleri
1. Statik (sabit)
2. Hareketli (yatay ileri-geri)
3. Kırılabilir (değince parçalanır, tek kullanım)
4. Kaybolan (değince bir süre sonra yok olur)
5. Zıplatıcı (spring/trampoline — ekstra yüksek zıplama)

### Güçlendirmeler
- Propeller şapka — kısa süre yukarı uçuş
- Jetpack — daha uzun yukarı itki
- Spring shoes — birkaç zıplamada daha yüksek
- Rocket/trampoline pad — tek seferlik çok yüksek zıplama

### Düşmanlar
- Sabit canavar (temas = ölüm)
- Hareketli canavar (yatay hareket)
- Kara delik (temas = oyun sonu)
- UFO (uçan düşman)
- Boss canavar (nadir)

### Ateş Etme
- Ekrana dokunarak yukarıya ateş etme (düşmanları yok etmek için)

### Bağımlılık Yapıcı Unsurlar
- Tek buton hissi: karmaşık kontrol yok
- "Bir kez daha" döngüsü: hızlı ölüm, hızlı yeniden başlama
- Skor kovalamacası: high score'a yakın ölünce tekrar denme güdüsü
- Zorluk eğrisi: ~30,000 skor civarında belirgin zorlaşma
- Hızlı session: 30 saniye – 2 dakika tipik oturum
- Hızlı failure recovery: ölüm sonrası anında yeniden oyna

### Başarısızlık ve Yeniden Denme
- Ölüm = ekranın altından düşme
- Hemen "yeni oyun" butonu
- Skor anlık gösterilir, high score kıyaslanır
- Ceza yok, bekleme yok → anında retry

---

## 3. Karşılaştırılabilir Vertical Platformer Analizi

### Doodle Jump
- **Döngü:** auto-jump + tilt + wrap-around
- **Farkı:** genre'i tanımlayan oyun
- **Başarı:** basitlik + hızlı retry + skor kovalamacası
- **Para kazanma:** premium + IAP (orijinal), reklam (ücretsiz versiyon)

### Leap Day
- **Döngü:** günlük prosedürel seviye, autorun + tap jump, meyce toplama
- **Farkı:** günlük content tazeleme, seviye yapısı (sonsuz değil)
- **Başarı:** günlük geri dönüş alışkanlığı, pixel art charm
- **Para kazanma:** free + reklam, rewarded video replay

### Downwell
- **Döngü:** aşağı yön roguelike, Gunboots ile aşağı ateş, shop upgrade
- **Farkı:** aşağı yön (yukarı değil), roguelike yapı, silah mekaniği
- **Başarı:** mekanik derinlik, tematik tutarlılık, premium positioning
- **Para kazanma:** premium ($2.99), reklam yok

### Mega Jump
- **Döngü:** coin toplamalı vertical jumper
- **Farkı:** para/coin ekonomisi, karakter çeşitliliği
- **Başarı:** coin koleksiyon gamifikasyonu
- **Para kazanma:** free + reklam + IAP

### PapiJump
- **Döngü:** tilt ile kırmızı top yukarı zıplama
- **Farkı:** minimal (sadece platform + tilt)
- **Başarı:** minimalizm, ilk örneklerden
- **Para kazanma:** free

### Ortak Özellikler (başarılı olanlar)
- Basit tek-el kontrol
- Hızlı session, hızlı retry
- Skor / yükseklik kıyaslaması
- Prosedürel üretim (her oyun farklı)
- Artan zorluk
- Power-up / boost anları
- Düşmanı hohe geçme / yok etme seçeneği

### Farklılaşma Noktaları
- Doodle Jump: saf minimalist sonsuz
- Leap Day: günlük seviye + meyve
- Downwell: aşağı yön + roguelike + silah
- Mega Jump: coin ekonomisi + karakter

### Para Kazanma Kalıpları
- **Sonsuz / casual:** reklam (interstitial + rewarded) + ufak IAP
- **Roguelike / premium定位:** tek seferlik satın alma
- **Sürdürülebilir:** rewarded video "devam et" en güçlü

---

## 4. Karakter ve Sanat Yaklaşımı

### Seçenekler

| Yöntem | Artı | Eksi | Mobil Uygunluk |
|---|---|---|---|
| 2D Sprite Sheet | basit, her motora destek, küçük dosya | çok animasyon = çok frame = büyük dosya | İyi |
| Skeletal (Spine) | smooth animasyon, küçük dosya, runtime efekt | lisans maliyeti, ek export adımı | İyi (lisans dikkat) |
| Godot Skeleton2D | lisans yok, motor içi, küçük dosya | kurulum sık, kalite sınırlı | İyi |
| DragonBones | ücretsiz, açık kaynak | ekosistem küçük | Orta |
| Veköır / Shape | minimalist, çok küçük | sınırlı animasyon | İyi (tarz uymuyorsa hayır) |

### Öneri
- **Başlangıç:** 2D sprite sheet (prototip hızlı)
- **Sonra:** Godot Skeleton2D veya özel çizim sprite atlas (Gemini handoff ile)
- Ejderha için cartoon tarz, ciddi/cesaretli duruş

### Asset Sourcing Önerisi
1. Prototip: Kenney / OpenGameArt / itch.io free 2D asset pack
2. Özel üretim: Gemini/Nano Banana handoff — ben prompt hazırlarım, Xaden üretir, dosyayı assets/inbox/ altına koyar
3. Asset store: Godot Asset Library küçük; itch.io'da cartoon dragon pack'ler mevcut

---

## 5. Para Kazanma Değerlendirme

### Model Karşılaştırma

| Model | Gelir | Oyuncu Rahatsızlığı | Casual Sonsuz Uygunluk |
|---|---|---|---|
| Banner | Düşük (sürekli) | Düşük | İyi (menüde) |
| Interstitial | Orta–Yüksek | Orta (frekansa bağlı) | İyi (ölüm sonrası) |
| Rewarded video | Yüksek | Düşük (gönüllü) | Çok iyi (revive) |
| IAP (skin/character) | Orta | Yok | İyi (ek gelir) |
| IAP (remove ads) | Tek seferlik | Yok | İyi |
| Premium | Tek seferlik | Yok | Zor (casual'da zor başarır) |

### Öneri: Reklam Ağırlıklı Hibrit
- **Interstitial:** her 3–5 ölümden sonra bir tam ekran
- **Rewarded video:** ölünce "devam et" (revive) + "2x puan" ödül
- **Banner:** ana menüde sadece
- **Küçük IAP:** "reklamları kaldır" + 2–3 skin paketi

### Play Store Politika Bazları (kısa)
- Reklam içeriği uygun olmalı ( yaş kısıtı, içerikPolitical)
- Interstitial: uygun yerde göster (oyun akışını bölme)
- Rewarded: ödül gerçekten vermeliZ
- IAP: Google Play Billing kullanffi zorunlu
- Gizlilik politikası ve SDK disclosure gereki

---

## 6. Mekanik İçerik Önerisi — Dragon Jump için

### Platform Türleri
1. Statik (normal)
2. Hareketli (yatay)
3. Kırılabilir (tek kullanım)
4. Kaybolan (gecikmeli yok olma)
5. Zıplatıcı (spring — ekstra zıplama)
6. (V2) Buz platformu (kaygan)

### Güçlendirmeler
- Propeller — kısa süre yukarı
- Jetpack — uzun süre yukarı itki
- Spring shoes — yükseğe zıplama (birkaç kez)
- Dragon-specific: **Ateş kırbaçı** — kısa süre tüm düşmanları yok eder aşağıda/yukarıda

### Düşmanlar
- Sabit canavar (ateşle yok edilir)
- Hareketli canavar (yatay)
- Kara delik (kaçınılmaz, ateş işe yaramaz)
- UFO (uçar, ateşle vurulabilir)

### Ejderha Yetenekleri
- **Ateş püskürtme (tap to shoot):** yukarıya ateş, düşman yok et. Cooldown'lı (detail OQ-11)
- **Kanat çırpma (double jump):** havada bir ekstra zıplama. Cooldown'lı
- **Süzülme (glide):** düşüş hızını yavaşlatma, yatay menzil artırma. Hold-to-glide

### Skor ve İlerleme
- Skor = ulaşılan yükseklik
- Zorluk arttıkça platform sıklığı azalır, düşman sıklığı artar
- (V2) Milestone yükseklikler = tema değişimi / bonus

### Çevre Temaları (ilk sürüm)
- Tek tema: gökyüzü / bulutlar
- Renk/eefekt değişimiyle yükseklik hissi
- (V2) gökyüzü → stratosfer → uzay → mağara

---

## Kaynak Listesi

### Motor Araştırması (Lane A)
- https://docs.unity3d.com/Manual/android.html — Unity Android
- https://docs.unity3d.com/Manual/webgl.html — Unity WebGL
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html — Godot Android
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html — Godot Web
- https://godotengine.org/download/linux/ — Godot Linux
- https://godotengine.org/asset-library/asset — Godot Asset Library
- https://defold.com/about/ — Defold
- https://defold.com/manuals/android/ — Defold Android
- https://defold.com/manuals/html5/ — Defold HTML5
- https://defold.com/assets/admob/ — Defold AdMob
- https://docs.cocos.com/creator/manual/en/editor/publish/android/index.html — Cocos Android
- https://docs.flutter.dev/get-started/install/linux — Flutter Linux
- https://phaser.io/tutorials/getting-started-phaser3 — Phaser

### Oyun Tasarım Araştırması (Lane B)
- https://en.wikipedia.org/wiki/Doodle_Jump — Doodle Jump
- https://dinogame.gg/blog/doodle-jump-strategy-tips/ — Doodle Jump strateji
- https://www.pocketgamer.biz/feature/15412/ — Making of Doodle Jump
- https://en.wikipedia.org/wiki/Leap_Day_(video_game) — Leap Day
- https://en.wikipedia.org/wiki/Downwell_(video_game) — Downwell
- iTunes Search API (Doodle Jump 2, Leap Day, Downwell, Mega Jump, PapiJump)
- https://esotericsoftware.com/spine-godot — Spine for Godot
- https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html — Godot Skeleton2D
- https://support.google.com/googleplay/android-developer/answer/9857753 — Google Play Ads Policy
- https://developer.android.com/google/play/billing — Google Play Billing