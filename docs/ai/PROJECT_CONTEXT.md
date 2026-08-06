# Dragon Jump — Project Context

**Tarih:** 6 Ağustos 2026
**Durum:** Araştırma tamam, kurulım devam ediyor

---

## Proje Özeti

Dragon Jump — Doodle Jump tarzı 2D mobil vertical platformer. Ejderha karakteri ile yukarı tırmanma, sonsuz/prosedürel, high score. Android hedefi (Google Play).

## Konfigürasyon Kararları

| Karar | Değer | Durum |
|---|---|---|
| Motor | Godot 4.7.1 | Kuruldu |
| Dil | GDScript | — |
| Platform ilk hedef | Android (Play Store) | — |
| Platform ikinci | iOS (Mac gerek) | Beklemede |
| Platform üçüncü | WebGL | Oyun bitince |
| Min Android API | 24 (Android 7.0) | Onaylandı |
| Performans hedefi | Orta+ (4GB+ RAM) | Onaylandı |
| Backend | Yok (ilk sürüm çevrim dışı) | Onaylandı |
| Oturum | Sonsuz/high-score | Onaylandı |
| Sanat tarzı | Cartoon | Onaylandı |
| Kontrol | Tap + Tilt | Onaylandı |
| Ejderha | Ciddi/cesaretli | Onaylandı |
| Para kazanma | Reklam + IAP (hibrit) | Onaylandı |
| Dil (UI) | İngilizce | Onaylandı |
| Ses | Free müzik (cartoon uyumlu) | Onaylandı |
| Asset prototip | Free asset pack | Onaylandı |
| Düşman tipi | 2-3 tip (wyvern dahil) | Onaylandı |
| Tema | Gökyüzü (V2'de çeşitlilik) | Onaylandı |

## Ejderha Yetenekleri (Xaden onayladı)

- **Ateş püskürtme:** mermi limitli, coin ile geliştirilebilir
- **Double jump (kanat çırpma):** coin ile açılır
- **Süizülme (glide):** hold-to-glide, coin ile açılır
- **Power-up mekaniği yok** — yetenekler ana karakter kabiliyeti, cooldown test edilecek
- Cooldown olayını test edip ekleriz

## Para Kazanma Detayı

- Interstitial: ölüm sonrası belirli aralıklarla
- Rewarded video: revive + 2x puan
- Banner: ana menüde
- IAP: reklamları kaldır + skin paketleri
- Coin ekonomisi: yetenek geliştirme + unlock

## Düşmanlar (ilk sürüm, 2-3 tip)

1. Wyvern (uçan düşman)
2. Sabit canavar (temas = ölüm, ateşle yok edilir)
3. (V2'de daha fazla tip)

## Geliştirme Ortamı

### Kurulu (✓)

| Bileşen | Sürüm | Yol |
|---|---|---|
| Godot Engine | 4.7.1 stable | ~/Godot/Godot_v4.7.1-stable_linux.x86_64 |
| Android SDK | build-tools 35/36, platforms 36 | ~/Android/Sdk |
| ADB | 1.0.41 | ~/Android/Sdk/platform-tools/adb |
| Android NDK | r27 (27.0.12077973) | ~/Android/Sdk/ndk/27.0.12077973 |
| OpenJDK 17 | 17.0.19 | /usr/lib/jvm/java-17-openjdk-amd64 |
| OpenJDK 21 | 21.0.11 | /usr/lib/jvm/java-21-openjdk-amd64 |
| Git | var | /usr/bin/git |
| Python | 3.12.3 | /usr/bin/python3 |
| VS Code | snap | /snap/bin/code |
| VS Code GDScript ext | geequlim.godot-tools v2.7.1 | — |
| sdkmanager | var | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager |

### Kuruluyor (bekleniyor)

| Bileşen | Durum |
|---|---|
| Godot export template'leri | İndiriliyor (~700MB) |

### Kurulmayacak (şimdilik)

| Bileşen | Sebep |
|---|---|
| GIMP/Krita | Xaden Photopea kullanıyor |
| AdMob plugin | Oyun implementasyon aşamasına gelince |

## Önemli Komutlar

```bash
# Godot editor aç
~/Godot/Godot_v4.7.1-stable_linux.x86_64

# Godot version
~/Godot/Godot_v4.7.1-stable_linux.x86_64 --version

# ADB cihaz kontrol
~/Android/Sdk/platform-tools/adb devices

# sdkmanager
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --list_installed
```

## Repository

- Repo: /home/xaden/Desktop/Dragon-Jump
- Git initialized: ✓
- Branch stratejisi: main + feature/fix/experiment
- .gitignore: Prompts.txt, docs klasörü exclueded

## Doküman Yapısı

```
docs/ai/
  PROJECT_BRIEF.md      — Oyun konsepti
  REQUIREMENTS.md        — Fonksiyonel + teknik gereksinimler
  OPEN_QUESTIONS.md      — Açık/kapalı sorular
  RESEARCH.md            — Motor + mekanik + para kazanma araştırması
  PROJECT_CONTEXT.md    — Bu dosya (compact source of truth)
  ARCHITECTURE.md        — (yazılacak)
  DECISIONS.md           — (yazılacak)
  IMPLEMENTATION_PLAN.md — (yazılacak)
```

## Sonraki Adımlar

1. Export template kurulumunu tamamla
2. ARCHITECTURE.md yaz
3. IMPLEMENTATION_PLAN.md yaz
4. Codex read-only architecture review
5. Xaden onayı
6. Codex (5.6 high) ile implementation başlat

## Riskler

- Export template indirme süresi (~700MB)
- AdMob plugin entegrasyonu henüz test edilmedi
- Godot Android export ayarları ilk kez yapılacak (debug keystore oluşturma gerekli)