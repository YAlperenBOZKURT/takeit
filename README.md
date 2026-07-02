<p align="center">
  <img src="takeit/assets/logo.png" alt="TakeIt" width="160" />
</p>

<h1 align="center">TakeIt</h1>

<p align="center">
  Yerel ağ üzerinden dosya paylaşımı ve grup sohbeti — internet gerekmez.<br/>
  Local network file sharing &amp; group chat — no internet required.
</p>

<p align="center">
  <a href="https://github.com/YAlperenBOZKURT/takeit/releases/latest">📥 İndir / Download</a>
</p>

---

🇹🇷 [Türkçe](#-türkçe) · 🇬🇧 [English](#-english)

---

## 🇹🇷 Türkçe

### TakeIt nedir?

TakeIt, aynı Wi-Fi ağındaki (veya kablolu yerel ağdaki) cihazlar arasında **dosya göndermenizi** ve **grup sohbeti kurmanızı** sağlayan bir uygulamadır. Veriler hiçbir sunucuya yüklenmez; her şey cihazdan cihaza, kendi ağınızın içinde taşınır. İnternet bağlantısı gerekmez.

- 📁 **Hızlı Gönder** — Yakındaki bir cihaza tek adımda dosya gönderin (masaüstünde sürükle-bırak desteklenir).
- 💬 **Sohbet Odaları** — Ağdaki cihazları seçip oda kurun; mesajlaşın, odaya dosya paylaşın.
- 📋 **Pano Paylaşımı** — Kopyaladığınız metni diğer cihaza anında aktarın.
- 🕘 **Geçmiş** — Gönderilen ve alınan dosyaların kaydını görün.
- 🌍 Türkçe ve İngilizce arayüz, açık/koyu tema.

### İndirme ve Kurulum

En güncel sürümü [Releases](https://github.com/YAlperenBOZKURT/takeit/releases/latest) sayfasından indirin:

| Platform | Dosya | Kurulum |
|---|---|---|
| Windows | `TakeIt-Setup-x.x.x.exe` | Kurulum sihirbazını çalıştırın; güvenlik duvarı izni otomatik eklenir. |
| Android | `TakeIt-x.x.x.apk` | APK'yı indirip yükleyin ("bilinmeyen kaynaklara" izin vermeniz gerekebilir). |
| macOS | `TakeIt-x.x.x.dmg` | DMG'yi açıp uygulamayı Applications klasörüne sürükleyin. |
| Linux | `TakeIt-x.x.x-linux-x64.tar.gz` | Arşivi açın ve `takeit` dosyasını çalıştırın. |

### Nasıl kullanılır?

1. **Aynı ağa bağlanın.** Dosya paylaşacağınız tüm cihazlar aynı Wi-Fi / yerel ağda olmalı.
2. **Takma ad seçin.** Uygulama ilk açılışta ağda görünecek adınızı sorar.
3. **Yakındakiler** sekmesinde ağdaki diğer TakeIt cihazları otomatik olarak listelenir.
4. **Dosya göndermek için** *Gönder* sekmesinden (veya cihazın üzerinden) dosyaları seçin — masaüstünde pencereye sürükleyip bırakmanız da yeterli. Karşı taraf transferi onayladığında aktarım başlar.
5. **Sohbet için** *Sohbet* sekmesinden bir oda oluşturun, ağdaki cihazları davet edin; mesaj ve dosya paylaşın.

> **Not:** TakeIt, cihaz keşfi ve aktarım için **53317** numaralı portu kullanır. Cihazlar birbirini göremiyorsa güvenlik duvarınızın bu porta (TCP/UDP) izin verdiğinden ve ağınızın istemciler arası iletişimi (AP/client isolation) engellemediğinden emin olun.

### Gizlilik

TakeIt hiçbir veri toplamaz. Dosyalar ve mesajlar yalnızca yerel ağınızdaki cihazlar arasında taşınır; harici sunucu, hesap veya internet bağlantısı yoktur.

---

## 🇬🇧 English

### What is TakeIt?

TakeIt lets you **send files** and **chat in groups** between devices on the same Wi-Fi (or wired LAN). Nothing is uploaded to any server — everything travels device-to-device inside your own network. No internet connection required.

- 📁 **Quick Send** — Send files to a nearby device in one step (drag &amp; drop on desktop).
- 💬 **Chat Rooms** — Pick devices on your network, create a room, message and share files in it.
- 📋 **Clipboard Sharing** — Instantly push copied text to another device.
- 🕘 **History** — Keep track of sent and received files.
- 🌍 Turkish &amp; English UI, light/dark themes.

### Download & Install

Grab the latest version from the [Releases](https://github.com/YAlperenBOZKURT/takeit/releases/latest) page:

| Platform | File | Install |
|---|---|---|
| Windows | `TakeIt-Setup-x.x.x.exe` | Run the installer; the firewall rule is added automatically. |
| Android | `TakeIt-x.x.x.apk` | Download and install the APK (you may need to allow "unknown sources"). |
| macOS | `TakeIt-x.x.x.dmg` | Open the DMG and drag the app into Applications. |
| Linux | `TakeIt-x.x.x-linux-x64.tar.gz` | Extract the archive and run the `takeit` binary. |

### How to use

1. **Join the same network.** All devices must be on the same Wi-Fi / LAN.
2. **Pick a nickname.** On first launch the app asks for the name you'll appear as on the network.
3. The **Nearby** tab automatically lists other TakeIt devices on your network.
4. **To send files**, pick them from the *Send* tab (or from a device card) — on desktop you can simply drag files onto the window. The transfer starts once the receiver accepts.
5. **To chat**, create a room from the *Chat* tab, invite devices on your network, and share messages and files.

> **Note:** TakeIt uses port **53317** for discovery and transfers. If devices can't see each other, make sure your firewall allows this port (TCP/UDP) and your network doesn't block client-to-client traffic (AP/client isolation).

### Privacy

TakeIt collects no data. Files and messages only move between devices on your local network — no external servers, no accounts, no internet.

---

## 🔧 Tech

For the technically curious and anyone who wants to contribute.

### How it works

Every TakeIt instance is both a client and a server. On launch, the app announces itself over **UDP broadcast** and listens for announcements from others — that's how the *Nearby* tab fills up without any central server. File transfers and chat messages go over a lightweight **embedded HTTP server** (built with [`shelf`](https://pub.dev/packages/shelf)) that each device runs locally; the sending side talks to it with `dio`. Both discovery and transfer use port `53317`, and nothing ever leaves the local network.

### Stack

| Layer | Choice |
|---|---|
| UI framework | [Flutter](https://flutter.dev) — single codebase for Android, Windows, macOS, and Linux |
| State management | [Riverpod](https://riverpod.dev) with code generation (`riverpod_generator`) |
| Navigation | `go_router` |
| HTTP server / client | `shelf` + `shelf_router` / `dio` |
| Data models | `freezed` + `json_serializable`, generated via `build_runner` |
| Error handling | Functional-style `Either` from `fpdart` |
| Localization | Flutter gen-l10n (English + Turkish, `lib/l10n/*.arb`) |

### Project structure

The codebase is organized by feature (`lib/features/discovery`, `transfer`, `chat`, `room`, `quick_send`, `clipboard`, `history`, …). Larger features follow a clean-architecture split into `domain` (entities, use cases), `data` (repositories, services), and `presentation` (pages, providers, widgets). Shared infrastructure — networking, theming, services, localization — lives in `lib/core`.

### CI/CD

GitHub Actions runs formatting, static analysis, and tests on every push. Pushing a `v*.*.*` tag builds all four platforms in parallel — an APK for Android, an Inno Setup installer for Windows, a DMG for macOS, and a tarball for Linux — and publishes them as a draft GitHub Release.

### Building from source

Requires Flutter `3.41.x` (see `.fvmrc`) with Dart SDK `^3.11`.

```bash
git clone https://github.com/YAlperenBOZKURT/takeit.git
cd takeit/takeit
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run            # run on a connected device
flutter build windows  # or: apk | macos | linux
```
