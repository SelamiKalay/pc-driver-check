# Changelog

[English](#english) below · Türkçesi her sürümün ilk bölümünde.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-30

### Türkçe

**Yeni**
- Donanım sağlığı: RAM (boyut, tür, yuva, hız; XMP/EXPO ve tek kanal uyarısı), disk/SSD (sağlık, aşınma, sıcaklık, firmware) ve Aygıt Yöneticisi'nde sorunlu aygıtlar
- Kurulumdan önce sürücü yedeği (`pnputil`), sadece SYSTEM ve Administrators erişebilen `%ProgramData%\PC-Driver-Check` klasörüne; `-NoBackup`
- AMD Radeon: kurulu Adrenalin sürümü amd.com'daki en son sürümle karşılaştırılır (sadece bilgi)
- `-NvidiaStudio`: Game Ready yerine NVIDIA Studio sürücüleri
- Gözetimsiz kullanım: `-All`, `-Install 1,3`, `-Yes`
- Yoksayma listesi: `PC-Driver-Check.config.json`
- `-Report json|html`
- Açılışta GitHub'da yeni sürüm kontrolü (sadece haber verir); `-NoUpdateCheck`
- Çıkış kodları: `0`, `1`, `2`, `3010`

**Düzeltmeler**
- Türkçe Windows'ta büyük/küçük harf duyarsız eşleştirme (`I` → `ı`): telefon/USB aksesuar filtresi büyük harfli başlıkları kaçırıyordu
- Windows 11'de NVIDIA servisine Windows 10 kimliği gönderiliyordu
- Windows Update indirmesi başarısız olsa da kurulum deneniyordu
- Sürücü sürümü okunamayınca "NVIDIA servisine ulaşılamadı" deniyordu
- `Check-Drivers.bat`, adında `'` olan klasörlerde yönetici izni isterken bozuluyordu

### English

**Added**
- Hardware health: RAM (size, type, slots, speed; XMP/EXPO and single-channel hints), disks/SSDs (health, wear, temperature, firmware) and problem devices in Device Manager
- Driver backup before installing (`pnputil`), to `%ProgramData%\PC-Driver-Check`, accessible only to SYSTEM and Administrators; `-NoBackup`
- AMD Radeon: installed Adrenalin version compared with the latest one on amd.com (information only)
- `-NvidiaStudio`: NVIDIA Studio drivers instead of Game Ready
- Unattended use: `-All`, `-Install 1,3`, `-Yes`
- Ignore list: `PC-Driver-Check.config.json`
- `-Report json|html`
- Check for a newer version on GitHub at start-up (information only); `-NoUpdateCheck`
- Exit codes: `0`, `1`, `2`, `3010`

**Fixed**
- Case-insensitive matching on Turkish Windows (`I` → `ı`): the phone/USB accessory filter missed upper-case titles
- The Windows 10 OS id was sent to NVIDIA's service on Windows 11
- An install was attempted even when the Windows Update download failed
- An unreadable driver version was reported as "could not reach NVIDIA's service"
- `Check-Drivers.bat` broke when asking for administrator rights in folders with `'` in the name
