# Dragon Jump — Architecture

**Tarih:** 6 Ağustos 2026
**Durum:** Updated per Codex review + Xaden control decisions
**Document precedence:** PROJECT_CONTEXT.md > ARCHITECTURE.md > REQUIREMENTS.md > IMPLEMENTATION_PLAN.md

---

## 1. Stack

| Katman | Teknoloji |
|---|---|
| Motor | Godot 4.7.1 |
| Dil | GDScript |
| Renderer | Compatibility (mobil) |
| Fizik | Godot 2D physics (CharacterBody2D, StaticBody2D, AnimatableBody2D) |
| Animasyon | AnimatedSprite2D (sprite sheet), Skeleton2D (V2) |
| Ses | Godot AudioServer (bus) |
| Para kazanma | AdMob plugin v2 + Google Play Billing |
| Kayıt | ConfigFile — user://profile.cfg |
| Export | Android (ilk), WebGL (sonra), iOS (Mac gerek) |

## 2. Karar Gerekçesi

- GDScript az boilerplate = AI hızlı kod üretir
- Godot 2D-first = hafif mobil performans, küçük APK
- MIT lisans = royalty yok, lisans riski sıfır
- Compatibility renderer = düşük uç cihazlarda iyi

## 3. Modül Sınırları

### Scene Tree (Godot)

```
Main (Node2D) — Root
├── RunSession (Node)
│   ├── Run state: READY → PLAYING → PAUSED → REVIVE_PENDING → GAME_OVER
│   ├── Run score (max altitude)
│   ├── Ammo count
│   ├── Difficulty multiplier
│   └── RNG seed
├── ProfileStore (Node)
│   ├── High score
│   ├── Wallet (coins)
│   ├── Ability unlocks (double_jump, glide, fire_breath_level)
│   ├── Settings (sound, control_pref, tilt_calibration)
│   ├── Schema version + migration
│   └── Save/load (ConfigFile → user://profile.cfg)
├── World (Node2D)
│   ├── Camera2D — follows dragon vertically
│   ├── PlatformManager (Node)
│   │   ├── Procedural platform spawner (seeded RNG)
│   │   ├── Reachability guarantee (max gap, guaranteed landing)
│   │   ├── Platform types: static, moving, breakable, disappearing, spring
│   │   ├── One-way StaticBody2D (solid, altından geçilebilir)
│   │   ├── AnimatableBody2D (moving platforms)
│   │   └── Spawn/despawn (instantiate/free — pool later if profiler says)
│   ├── EnemyManager (Node)
│   │   ├── Enemy spawner (wyvern, static monster)
│   │   ├── Enemy exclusion around mandatory landings
│   │   └── Spawn/despawn
│   ├── Background (ParallaxBackground)
│   │   └── Sky/cloud layers
│   └── CoinManager (Node)
│       └── Coin spawner + collection
├── Player (CharacterBody2D) — Dragon
│   ├── AnimatedSprite2D
│   ├── CollisionShape2D
│   ├── FireBreath (Node2D) — projectile system, limited ammo
│   ├── AbilityController (Node)
│   │   ├── DoubleJump (çiift tap, havadayken, unlock gerekir)
│   │   ├── Glide (çift tap + hold, havadayken, unlock gerekir)
│   │   └── FireBreath (buton, ammo limited, cooldown)
│   └── InputController (Node)
│       ├── Touch: tap (horizontal + double jump), hold (glide)
│       ├── Tilt: accelerometer → horizontal (Input singleton)
│       ├── Keyboard fallback (desktop test: arrows + space)
│       ├── Tilt dead-zone + calibration + smoothing
│       └── Sensor-unavailable fallback
├── HUD (CanvasLayer)
│   ├── ScoreLabel (max altitude)
│   ├── HighScoreLabel
│   ├── CoinLabel
│   ├── AbilityIcons
│   ├── FireButton (sağ-alt, yüzen, yarı saydam)
│   └── PauseButton (sağ-üst)
├── AudioManager (Node)
│   ├── SFX bus
│   ├── Music bus
│   └── Master bus
└── PlatformServices (Node) — M4
    ├── AdManager (banner, interstitial, rewarded)
    ├── BillingManager (IAP, restore, acknowledge)
    └── ConsentFlow (GDPR/CCPA)
```

## 4. State Yönetimi

### Runtime State (RunSession)
- Run states: READY, PLAYING, PAUSED, REVIVE_PENDING, GAME_OVER
- Run score = max altitude reached
- Ammo count (current run)
- Difficulty multiplier
- RNG seed (deterministic)

### Persistent State (ProfileStore)
- High score
- Wallet (total coins)
- Ability unlocks: double_jump_unlocked, glide_unlocked, fire_breath_level
- Settings: sound_enabled, control_preference, tilt_calibration
- Schema version + migration
- Corrupt-file recovery + defaults

### Platform Services (PlatformServices)
- Ad entitlements (remove-ads purchased?)
- Billing entitlements (purchased skins)
- Ad states: idle, loading, showing, no-fill, offline, cancelled
- Billing states: idle, purchasing, restoring, acknowledged

## 5. Input Mimarisi

### Action Map

```
Action           | Touch                    | Tilt              | Keyboard (desktop)
-----------------|--------------------------|-------------------|-------------------
move_left        | tap left half            | tilt left         | left arrow
move_right       | tap right half           | tilt right        | right arrow
double_jump      | çift tap (havadayken)    | —                 | space (çift press)
glide            | çift tap + hold          | —                 | space (hold)
fire             | fire button (sağ-alt)    | —                 | F key
pause            | pause button (sağ-üst)   | —                 | Escape
```

### Touch Detection Logic
- Tek tap: 200ms'den kısa dokunuş, ekrandan parmak kalktı
- Çift tap: iki tap arası 300ms'den kısa
- Hold: parmak ekranda 200ms'den uzun
- Çift tap + hold: ikinci tap'ten sonra parmak ekranda kalır
- Tap yeri: sol yarı = sol hareket, sağ yarı = sağ hareket (ateş butonu ve pause butonu alanı hariç)

### Tilt
- Input singleton: Input.get_accelerometer()
- Dead-zone: small threshold (settings'ten ayarlanır)
- Calibration: sıfır noktası ayarı
- Smoothing: lerp ile yumuşatma
- Sensor yoksa (desktop): devre dışı, keyboard fallback

### Platform Fiziği
- Platformlar: one-way StaticBody2D (solid surface)
- Moving platforms: AnimatableBody2D
- Collision: player sadece yukarı düşüşte platforma değer (alttan geçiş serbest)
- Spring/break/disappear: Area2D child as trigger
- Collision layers: player (layer 1), platforms (layer 2), enemies (layer 3), coins (layer 4)

## 6. Prosedürel Üretim

- Seeded RNG (deterministic, test edilebilir)
- Each platform spawn from previous reachable landing envelope
- Max vertical gap = jump height * 0.8 (safety margin)
- Max horizontal gap = screen width * 0.7
- Guaranteed recovery platform every N platforms
- Enemy exclusion around mandatory landings
- Safe starting region (first 10 platforms, no enemies)
- Score = max altitude (not current position)

## 7. Asset Organizasyonu

```
res://
├── scenes/
│   ├── Main.tscn
│   ├── Player.tscn
│   ├── Platform.tscn
│   ├── Enemy.tscn
│   └── HUD.tscn
├── scripts/
│   ├── RunSession.gd
│   ├── ProfileStore.gd
│   ├── Player.gd
│   ├── PlatformManager.gd
│   ├── EnemyManager.gd
│   ├── CoinManager.gd
│   ├── InputController.gd
│   ├── AbilityController.gd
│   ├── FireBreath.gd
│   └── AudioManager.gd
├── assets/
│   ├── sprites/
│   │   ├── player/dragon_*.png
│   │   ├── platforms/*.png
│   │   └── enemies/*.png
│   ├── audio/
│   │   ├── sfx/*.wav
│   │   └── music/*.ogg
│   └── ui/*.png
├── data/
│   └── game_data.tres
└── project.godot
```

## 8. Persistence

- ConfigFile → user://profile.cfg (INI format)
- Schema version + migration
- Defaults + validation
- Corrupt-file recovery (backup + reset)
- No base64 (gereksiz)
- Separation: run coins vs wallet coins

## 9. Testing

| Layer | Yöntem |
|---|---|
| Unit | GUT (Godot Unit Test) — spawn logic, score, save/load |
| Integration | Scene-level — platform landing, enemy collision, ability chaining |
| Generator | Headless seed test (1000 seeds, reachability validation) |
| Manual | Godot editor F5 + Android emulator + device |
| Performance | Godot profiler + 10-min thermal soak |
| Build | Android APK export + install + run |
| Edge cases | Wrap-around, underside pass-through, tilt dead-zone, save corruption |

## 10. Performance Budget

| Metrik | Hedef |
|---|---|
| FPS | 60 (orta), 30 (düşük uç) |
| Draw calls | < 50 per frame |
| Physics objects | < 30 active |
| Memory | < 150MB |
| APK size | < 25MB |
| Startup | < 3 saniye |

## 11. Security / Trust Boundaries

- Client authoritative (offline, no leaderboard V1) — tamper riski kabul
- Save: ConfigFile, no obfuscation
- Ads + Billing: networked platform services (separate boundary)
- BillingManager: server-side validation (Google Play)
- No PII collection (gameplay)
- Consent flow for ads (GDPR/CCPA)
- V2 leaderboard: server-side score validation

## 12. Deployment

1. Godot Editor → Android export preset
2. Debug keystore (M0.5)
3. Export → APK (debug)
4. ADB install → test cihazı/emulator
5. Release build → signed APK → Play Store