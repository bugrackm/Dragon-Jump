# Dragon Jump — Project Brief

**Tarih:** 6 Ağustos 2026
**Durum:** Tasarım aşaması, implementation öncesi

---

## Oyun Konsepti

Dragon Jump, Doodle Jump'tan ilham alan bir 2D mobil vertical platformer'dır. Oyuncu, yukarı doğru sürekli zıplayan bir ejderhayı kontrol eder. Amaç: mümkün olan en yükseğe çıkmak, yüksek skor (high score) kıyaslaması yapmak.

## Ana Fantezi

Cesur bir ejderhayla yukarı doğru tırmanırken farklı platform türleri, güçlendirmeler (power-up), düşmanlar ve engeller arasında hayatta kalmak. Ejderhanın kendine has yetenekleri (ateş püskürtme, kanat çırpma, süzülme) oyuna derinlik katar.

## Hedef Kitle

Geniş yaş aralığı (her yaşa hitap eden), casual mobil oyuncular. Çocuk dostu olmak şart değil ama aşırı vahşet yok. Bağımlılık yapıcı, "bir kez daha" hissi veren sonsuz oyun deneyimi.

## Platform

- **İlk hedef:** Android (Google Play Store)
- **İkinci aşama:** iOS (Mac cihaz edindikten sonra)
- **Üçüncü aşama:** WebGL web export (oyun tamamlandıktan sonra)

## Teknoloji (araştırma sonucu, onay bekliyor)

- **Motor:** Godot 4 (önerilen) — alternatif: Unity 6
- **Dil:** GDScript (önerilen) — alternatif: C#
- **Gerekçe:** AI ile geliştirme dostu, hafif 2D mobil performans, MIT lisans (royalty yok), Android + WebGL export desteği, düşük bakım maliyeti

## Sanat Tarzı

Cartoon / karton tarz. Ejderha karakteri ciddi/cesaretli Stillrda modellenecek (sonradan değiştirilebilir).

## Kontrol

- Sol/sağ ekrana dokunma (tap)
- Telefonu sağa/sola yatırma (tilt / accelerometer)
- Her iki yöntem aynı anda aktif

## Oturum Yapısı

Sonsuz / prosedürel üretim. Tek high score hedefi.

## Para Kazanma (önerilen, onay bekliyor)

Reklam ağırlıklı hibrit model:
- Interstitial (tam ekran reklam) — ölüm sonrası belirli aralıklarla
- Rewarded video — "devam et" (revive), 2x puan
- Banner — ana menüde
- Küçük IAP — "reklamları kaldır" + birkaç skin

## Çevrim Dışı / Backend

İlk sürüm tamamen çevrim dışı, local high score. Backend (global leaderboard) V2'ye bırakıldı.

## Performans Hedefi

Orta seviye ve üstü Android cihazlar (4GB+ RAM). Düşük uç cihazlarda çalışsın ama kusursuz olmasın.