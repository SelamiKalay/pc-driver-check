# PC Driver Check

[English](README.md) | **Türkçe**

Bilgisayarının sürücülerinin güncel olup olmadığını kontrol eden, güncellenebilecekleri listeleyen ve **sadece onayladıklarını** kuran küçük bir Windows aracı. Hangi donanım olursa olsun her bilgisayarda çalışır.

- Kurulum, arka plan servisi ya da üçüncü parti indirme yok: sadece Windows'ta hazır gelen bileşenleri kullanır.
- Onayın olmadan hiçbir şey kurulmaz.
- Bir şey değişmeden önce Sistem Geri Yükleme noktası oluşturulur.
- Windows Türkçeyse mesajlar **Türkçe**, değilse **İngilizce** gösterilir.

---

## İçindekiler

- [Ne yapar](#ne-yapar)
- [Gereksinimler](#gereksinimler)
- [Kullanım](#kullanım)
- [Seçenekler](#seçenekler)
- [Örnek çıktı](#örnek-çıktı)
- [Güncellemeler nereden geliyor](#güncellemeler-nereden-geliyor)
- [Güvenlik](#güvenlik)
- [Güncellemeyi geri alma](#güncellemeyi-geri-alma)
- [Neler yapmaz](#neler-yapmaz)
- [SSS](#sss)
- [Testler](#testler)
- [Lisans](#lisans)

---

## Ne yapar

1. **Bilgisayarı tanır**: model, Windows sürümü, işlemci, ekran kart(lar)ı ve kurulu sürücü sürümleri. Hiçbir şey koda sabit yazılmamıştır; aynı araç her makinede çalışır.
2. **NVIDIA ekran kartlarını** NVIDIA'nın resmi sürücü servisinden kontrol eder. Bu genelde Windows Update'tekinden daha yenidir.
3. **Windows Update'i tarar**: Microsoft'un tam olarak bu donanım için sunduğu tüm sürücüleri bulur.
4. **Gereksizleri ayıklar**: bir kez takılan telefon ve USB aksesuarlarının sürücüleri (Android, iPhone, MTP, …) gizlenir.
5. **Güncellemeleri listeler**: numara, kaynak, aygıt sınıfı, tarih ve boyutla.
6. **Sana sorar**: hangilerinin kurulacağını sen seçersin.
7. **Geri yükleme noktası oluşturur**, sonra seçtiklerini indirip kurar.
8. **Özet gösterir**: yeniden başlatma gerekip gerekmediğini söyler ve bir kayıt dosyası tutar.

## Gereksinimler

| | |
|---|---|
| İşletim sistemi | Windows 10 ya da Windows 11 (64-bit) |
| Yetki | Yönetici (`.bat` bunu otomatik ister) |
| Ağ | İnternet bağlantısı |
| PowerShell | Windows PowerShell 5.1 (Windows'la birlikte gelir) |

## Kullanım

1. Depoyu indir: **Code → Download ZIP**, sonra ZIP'i aç.
   > Windows dosyaları engellerse: ZIP'e sağ tıkla → **Özellikler** → **Engellemeyi kaldır** kutusunu işaretle → Tamam, sonra tekrar aç.
2. **`Check-Drivers.bat`** dosyasına çift tıkla.
3. Yönetici izni penceresinde **Evet**'e tıkla.
4. Taramayı bekle (Windows Update 1-2 dakika sürebilir).
5. Kurmak istediklerinin numaralarını yaz ve Enter'a bas:

| Giriş | Anlamı |
|---|---|
| `1,3` | 1 ve 3 numarayı kur |
| `1-4` | 1'den 4'e kadar kur |
| `T` (Türkçe) / `A` (İngilizce) | hepsini kur |
| *(boş)* + Enter | hiçbir şey kurma, çık |

6. Araç söylerse bilgisayarı yeniden başlat.

## Seçenekler

Aracın klasöründe bir terminal açıp:

```bat
Check-Drivers.bat -ScanOnly          :: sadece listele, hiçbir şey kurma
Check-Drivers.bat -IncludeDevices    :: telefon / USB aksesuar sürücülerini de göster
```

Ya da script'i doğrudan çalıştır:

```powershell
powershell -ExecutionPolicy Bypass -File .\PC-Driver-Check.ps1 -ScanOnly
```

### Çıkış kodları

Araç başka bir script'ten ya da Görev Zamanlayıcı'dan çağrıldığında işe yarar:

| Kod | Anlamı |
|---|---|
| `0` | Tamamlandı ya da güncellenecek / seçilen bir şey yok |
| `1` | Hata: yönetici olarak çalıştırılmadı ya da bir tarama (Windows Update / NVIDIA) başarısız oldu |
| `2` | Seçilen sürücülerden en az biri kurulamadı |
| `3010` | Kuruldu, yeniden başlatma gerekli (Windows'un standart kodu) |

## Örnek çıktı

```
PC-Driver-Check - sürücü güncelleme kontrolü

==== Bilgisayar ====
Model        Örnek Laptop 15
Windows      Microsoft Windows 11 Pro (build 26100)
İşlemci      Intel(R) Core(TM) Ultra 7 155H
Ekran kartı  NVIDIA GeForce RTX 4070 Laptop GPU  [32.0.15.5222]
[--] NVIDIA sürücüsü kontrol ediliyor: NVIDIA GeForce RTX 4070 Laptop GPU
[--] Windows Update taranıyor (1-2 dakika sürebilir)...
[--] 3 telefon/USB aygıtı sürücüsü gizlendi (göstermek için -IncludeDevices).

==== Bulunan güncellemeler ====
[1] NVIDIA GeForce RTX 4070 Laptop GPU  552.22 -> 621.01
     NVIDIA | Display | Wed Oct 21, 2026 | 1.04 GB
[2] Intel Corporation ComputeAccelerator Driver Update (32.0.100.5541)
     WU | ComputeAccelerator | 2026-08-20 | 30,3 MB

Kurulacakların numaraları (örnek: 1,3 veya 1-3)  T = tümü  Enter = hiçbiri: 1,2
[--] Sistem geri yükleme noktası oluşturuluyor...
[OK] Geri yükleme noktası oluşturuldu: "PC-Driver-Check 2026-10-29 19:20"
...
==== Özet ====
[OK] Kurulan: 2

Bilgisayarı YENİDEN BAŞLATIN.
```

## Güncellemeler nereden geliyor

| Kaynak | Kapsam | Not |
|---|---|---|
| **Windows Update** | Tüm aygıtlar: yonga seti, ses, ağ, Bluetooth, depolama, ekran kartları, … | Windows'un kendi Windows Update Agent'ını kullanır. Sadece Microsoft'un *senin* donanım kimliklerin için yayınladığı sürücüler gelir. |
| **NVIDIA resmi servisi** | NVIDIA GeForce ekran kartları (masaüstü ve laptop) | Tam ekran kartı modelini nvidia.com'da arar ve kurulu sürümle karşılaştırır. Sadece **daha yeni** sürüm önerilir. Bu kontrol başarılı olursa Windows Update'teki NVIDIA ekran sürücüsü gizlenir; böylece sürücün asla eski sürüme düşürülmez. |

**AMD ve Intel ekran kartları** Windows Update üzerinden kontrol edilir. Kendi araçlarında genelde daha yeni sürümler bulunur:
[AMD Software: Adrenalin Edition](https://www.amd.com/en/support/download/drivers.html) · [Intel Driver & Support Assistant](https://www.intel.com/content/www/us/en/support/detect.html).

## Güvenlik

- **Seçmediğin hiçbir şey kurulmaz.** `-ScanOnly` hiçbir şey kurmaz.
- **Önce geri yükleme noktası.** Oluşturulamazsa (örneğin Sistem Koruması kapalıysa) devam edilsin mi diye sorulur.
- **NVIDIA dosyaları doğrulanır.** İndirme adresi `nvidia.com` üzerinde olmalı, kurulum dosyasının dijital imzası geçerli ve *NVIDIA Corporation* adına olmalı. Değilse dosya çalıştırılmaz.
- **Eski sürüme düşürme yok.** NVIDIA güncellemesi sadece kurulu sürücüden daha yeniyse önerilir.
- **Ayarlar korunur.** NVIDIA sürücüsü temiz kurulum olarak değil, yükseltme olarak kurulur; NVIDIA Denetim Masası ayarların kalır.
- **Başarı varsayılmaz, kontrol edilir.** NVIDIA kurulumundan sonra kurulum programının çıkış koduna güvenilmez; kurulu sürüm yeniden okunur.
- **Her şey kaydedilir:** script'in yanındaki `logs\PC-Driver-Check_<tarih>.log` dosyasına.

## Güncellemeyi geri alma

1. **Win + R**'ye bas, `rstrui` yaz, Enter.
2. **"PC-Driver-Check <tarih>"** adlı geri yükleme noktasını seç.
3. Sihirbazı takip et; bilgisayar yeniden başlar.

Tek bir aygıt için: **Aygıt Yöneticisi → aygıt → Özellikler → Sürücü → Sürücüyü Geri Al**.

## Neler yapmaz

- BIOS / UEFI ya da firmware güncellemesi
- Üretici yazılımları (laptop kontrol merkezleri, RGB yazılımları vb.)
- Windows özellik ya da güvenlik güncellemeleri (onlar için Windows Update'i kullan)
- Arka planda ya da zamanlanmış çalışma: sadece sen başlattığında çalışır

## SSS

**Tarama neden 1-2 dakika sürüyor?**
Windows Update bilgisayardaki her aygıtı Microsoft'un kataloğuyla karşılaştırıyor. Yeniden başlatmadan sonraki ilk tarama en yavaşıdır.

**Telefon sürücüleri neden gizli?**
Windows, *bir kez bile* bağlanmış her aygıt için sürücü önerir; örneğin bir kez şarj ettiğin telefon. Bilgisayarda nadiren işe yararlar, bu yüzden varsayılan olarak gizlenirler. Görmek için `-IncludeDevices` kullan.

**Windows "Windows kişisel bilgisayarınızı korudu" diyor.**
Bu, internetten indirilen bir script'e SmartScreen'in tepkisi. **Ek bilgi → Yine de çalıştır**'a tıkla ya da ZIP'i açmadan önce engellemesini kaldır (bkz. [Kullanım](#kullanım)). Çalıştırmadan önce tüm kodu `PC-Driver-Check.ps1` içinde okuyabilirsin.

**NVIDIA kartım için "model bulunamadı" diyor.**
Bazı OEM ya da çok yeni modellerin NVIDIA listesindeki adı farklı olabiliyor. [nvidia.com/drivers](https://www.nvidia.com/drivers) adresinden elle kontrol et. Windows Update yine taranır.

**Bir yere veri gönderiliyor mu?**
Sadece Windows Update'in standart istekleri ve ekran kartı modelinle nvidia.com'a yapılan bir sorgu. Başka hiçbir şey toplanmaz ya da gönderilmez.

## Testler

Çevrimdışı birim testleri (sürüm dönüşümü, ekran kartı adı eşleştirme, aksesuar filtresi,
seçim girişi, örnek servis yanıtlarıyla NVIDIA sorgusu, TR/EN mesaj anahtarları ve yer
tutucuları) yönetici izni, internet ya da Windows Update gerektirmez:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\PC-Driver-Check.Tests.ps1
```

Her push ve pull request'te GitHub Actions ile Windows PowerShell 5.1 ve PowerShell 7 üzerinde
çalışır, ardından [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) kontrolü
yapılır (kurallar `PSScriptAnalyzerSettings.psd1` içinde).

## Lisans

[MIT](LICENSE)
