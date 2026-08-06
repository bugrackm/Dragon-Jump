# Dragon Jump — Open Questions

**Tarih:** 6 Ağustos 2026
**Xaden'in cevapladığı kısımlar ✓ işaretli**

---

## ✓ Çözülen Sorular

### OQ-01: Sanat tarzı — ✓ Cartoon/karton
### OQ-02: Kontrol yöntemi — ✓ Sol/sağ tap + tilt birlikte
### OQ-03: Ejderha karakteri — ✓ Ciddi/cesaretli, ateş+kanat+süzülme yetenekleri olsun
### OQ-04: Platform kapsamı — ✓ Android ilk hedef, iOS sonra, WebGL sonra
### OQ-05: Oturum yapışı — ✓ Sonsuz / high score
### OQ-06: Oyun adı — ✓ "Dragon Jump" kod adıyla gidyoruz, çakışma olursa alternatif ararız

---

## Açık Sorular (Xaden kararı bekliyor)

### OQ-07: Para kazanma modeli kesinleşmedi
Xaden "reklam ağırlıklı" dedi. Benim önerim: interstitial + rewarded video + banner + küçük IAP (reklam kaldır + skin).
Soru: İlk sürümde IAP olsun mu, yoksa sadece reklam mı kalalım?

### OQ-08: Minimum Android API seviyesi
Araştırma bittikten sonra karar verilecek. Önerilen: API 24 (Android 7.0) — en geniş cihaz kapsamı, düşük kırılma riski. Xaden'in onayı gerekiyor.

### OQ-09: Düşük uç cihaz kapsamı
Önerilen: Orta ve üstü cihaz hedefi (4GB+ RAM). Düşük uçta çalışır ama kusursuz optimize edilmez. Xaden onayı?

### OQ-10: Backend ihtiyacı
İlk sürüm çevrim dışı. Global leaderboard V2'ye bırakıldı. Xaden onayı?

### OQ-11: Ejderha yeteneklerinin detayı
- Ateş püskürtme: sürekli mi, cooldown'lı mı, mermi limiti var mı?
- Kanat çırpma: double jump mu, airborne sonra ek zıplama mı?
- Süzülme: otomatik mi (düşüşte), buton mu, tilt-activated mi?
- Bu yetenekler power-up mı (süreli), yokta ana karakter kabiliyeti mi (her zaman var ama cooldown'lı)?

### OQ-12: Tema / ortam variety
İlk sürümde tek tema mı (örn. gökyüzü / bulutlar), yoksa yüksekliğe göre değişen temalar mı (gökyüzü → uzay → mağara)?
Önerim: İlk sürümde tek tema (gökyüzü), renk/eefekt değişimiyle çeşitlilik. Tema çeşitliliği V2.

### OQ-13:ç Ses ve müzik
Freesound / opengameart gibi ücretsiz kaynaklardan mı, özel üretim mi? MIDI / chiptune mu, modern ambient mi? Cartoon tarza uygun kaçacak tür?

### OQ-14: Dil / localization
İlk sürüm Türkçe mi, İngilizce mi, ikisi mi? Oyun metni az (UI labels) ama ayarlar/menüler için karar gerek.
Önerim: İlk sürüm İngilizce (geniş kitle), Türkçe V2.

### OQ-15: Asset üretim yaklaşımı
- Ejderha: free/asset store sprite mı, özel çizim (Gemini handoff ile) mi?
- Platform, background, UI: ücretsiz asset pack mi, Gemini ile üretülüp temiz mi?
Önerim: Başlangıçta Kenney/GameArt Gaff/iTch.io free asset pack ile prototip, sonra Gemini ile özel karton tarz ejderha üretimi.

### OQ-16: Düşman sayısı ilk sürümde
Araştırmada 4 tip düsman önerildi (fixed, moving, black hole, UFO). İlk sürümde hepsi mi, 2-3 tip mi?

### OQ-17: Google Play'de "Dragon Jump" isim çakışması
İsim çakışması var mı ve alternatif isim gerekecek mi? Araştırma sırasında kontrol edilecek.