// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_strings.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppStringsTr extends AppStrings {
  AppStringsTr([String locale = 'tr']) : super(locale);

  @override
  String get chooseNickname => 'Takma adını seç';

  @override
  String get nicknamePlaceholder => 'örn.';

  @override
  String get leaveEmptyHint =>
      'Boş bırakırsan rastgele isim verilir. İsmin kaydedilecek.';

  @override
  String get continueBtn => 'Devam';

  @override
  String get nearbyDevices => 'Yakındaki Cihazlar';

  @override
  String get nearbyTab => 'Cihazlar';

  @override
  String get settings => 'Ayarlar';

  @override
  String get transferHistory => 'Transfer Geçmişi';

  @override
  String get newRoom => 'Yeni Oda';

  @override
  String get noDevicesFound => 'Cihaz bulunamadı';

  @override
  String get makeOthersOpen =>
      'Diğerlerinin TakeIt\'i aynı ağda\naçık olduğundan emin ol.';

  @override
  String get scanning => 'Taranıyor...';

  @override
  String devicesOnNetwork(int count) {
    return 'Bu ağda $count cihaz';
  }

  @override
  String get chatRoom => 'Sohbet Odası';

  @override
  String get typeMessage => 'Mesaj yaz...';

  @override
  String get fileNotFound => 'Dosya bulunamadı';

  @override
  String get fileTransfer => 'Dosya Transferi';

  @override
  String get transferring => 'Dosya aktarılıyor...';

  @override
  String get accept => 'Kabul Et';

  @override
  String get decline => 'Reddet';

  @override
  String wantsToSend(String name) {
    return '$name dosya göndermek istiyor';
  }

  @override
  String get all => 'Tümü';

  @override
  String get files => 'Dosyalar';

  @override
  String get noTransfersYet => 'Henüz transfer yok';

  @override
  String get historyWillAppear => 'Dosya transfer geçmişin burada görünecek.';

  @override
  String get clearHistory => 'Geçmişi temizle';

  @override
  String get clearHistoryConfirm => 'Geçmişi temizle?';

  @override
  String get clearHistoryMsg => 'Tüm transfer kayıtları silinecek.';

  @override
  String get clear => 'Temizle';

  @override
  String get cancel => 'İptal';

  @override
  String get filePathNotAvailable => 'Dosya yolu bulunamadı';

  @override
  String get profile => 'Profil';

  @override
  String get nickname => 'Takma Ad';

  @override
  String get changeNickname => 'Takma adı değiştir';

  @override
  String get enterNewNickname => 'Yeni takma ad gir';

  @override
  String get resetToRandom => 'Rastgele isim ver';

  @override
  String nicknameRandomized(String name) {
    return 'Takma ad \"$name\" olarak ayarlandı';
  }

  @override
  String get save => 'Kaydet';

  @override
  String get appearance => 'Görünüm';

  @override
  String get systemDefault => 'Sistem varsayılanı';

  @override
  String get light => 'Açık';

  @override
  String get dark => 'Koyu';

  @override
  String get modern => 'Modern';

  @override
  String get network => 'Ağ';

  @override
  String get restartServer => 'Sunucuyu yeniden başlat';

  @override
  String get restartServerDesc =>
      'HTTP sunucusunu ve cihaz taramasını yeniden başlat';

  @override
  String get serverRestarted => 'Sunucu yeniden başlatıldı';

  @override
  String restartFailed(String error) {
    return 'Yeniden başlatma başarısız: $error';
  }

  @override
  String get about => 'Hakkında';

  @override
  String get appDesc => 'Yerel ağda dosya paylaşımı';

  @override
  String get language => 'Dil';

  @override
  String nicknameChanged(String name) {
    return 'Takma ad \"$name\" olarak değiştirildi';
  }

  @override
  String get downloadLocation => 'İndirme Konumu';

  @override
  String get downloadLocationDesc => 'Dosyaların kaydedileceği klasör';

  @override
  String get defaultLocation => 'Varsayılan (İndirilenler)';

  @override
  String get changeFolder => 'Klasörü Değiştir';

  @override
  String get resetToDefault => 'Varsayılana Sıfırla';

  @override
  String get openFolder => 'Klasörü Aç';

  @override
  String get folderNotFound => 'Klasör bulunamadı';

  @override
  String get wifiWarning =>
      'Lütfen hedef cihaz ile aynı WiFi ağında olduğunuzdan emin olun.';

  @override
  String get dropFilesHere => 'Dosyaları buraya bırak';

  @override
  String get clipboardShared => 'Pano paylaşıldı';

  @override
  String get copy => 'Kopyala';

  @override
  String get close => 'Kapat';

  @override
  String clipboardFrom(String name) {
    return '$name\'\'den pano içeriği';
  }

  @override
  String get copiedToClipboard => 'Panoya kopyalandı';

  @override
  String get clipboardEmpty => 'Pano boş';

  @override
  String get quickSend => 'Hızlı Gönderim';

  @override
  String get quickSendTitle => 'Hızlı Gönderim';

  @override
  String quickSendFrom(String name) {
    return '$name sana dosya göndermek istiyor';
  }

  @override
  String quickTextFrom(String name) {
    return '$name\'\'den mesaj';
  }

  @override
  String get selectRecipients => 'Alıcıları seç';

  @override
  String get quickTextHint => 'Göndermek istediğin metni yaz...';

  @override
  String get sendText => 'Metin Gönder';

  @override
  String get sendFile => 'Dosya Gönder';

  @override
  String get file => 'Dosya';

  @override
  String get text => 'Metin';

  @override
  String get inRoom => 'Odada';

  @override
  String get userInRoom => 'Bu kişi şu an bir odada';

  @override
  String get dropOrAddFiles => 'Dosyaları sürükle veya ekle';

  @override
  String get addFile => 'Dosya Ekle';

  @override
  String get paste => 'Yapıştır';

  @override
  String get itemsReady => 'öğe hazır';

  @override
  String get selectRecipientsBtn => 'Alıcıları Seç';

  @override
  String get send => 'Gönder';

  @override
  String get addButton => 'Ekle';

  @override
  String get nothingAddedYet => 'Henüz bir şey eklenmedi';

  @override
  String get sendingFiles => 'Dosyalar gönderiliyor…';

  @override
  String get filesSent => 'Dosyalar gönderildi';

  @override
  String get switchRoomTitle => 'Oda Değiştir';

  @override
  String switchRoomMsg(String members) {
    return 'Şu an \"$members\" ile aktif bir odanız var. Yeni oda kurarsanız mevcut oda kapanacak.';
  }

  @override
  String get activeTransferWarning => 'Aktif dosya transferi iptal olacak!';

  @override
  String get switchRoom => 'Oda Değiştir';

  @override
  String get createRoom => 'Oda Oluştur';

  @override
  String get roomInvite => 'Oda Daveti';

  @override
  String invitesYou(String name) {
    return '$name seni bir odaya davet ediyor';
  }

  @override
  String get join => 'Katıl';

  @override
  String get leaveRoom => 'Odadan Ayrıl';

  @override
  String get leaveRoomConfirm => 'Bu sohbetten ayrılmak istediğine emin misin?';

  @override
  String get noMessages => 'Henüz mesaj yok.\nMerhaba de!';

  @override
  String get activeRoom => 'Aktif Sohbet';

  @override
  String get tapToReturn => 'Sohbete dönmek için dokun';

  @override
  String get sessionTransfersTitle => 'Transferler';

  @override
  String get transfers => 'Transferler';

  @override
  String get activeSection => 'AKTİF';

  @override
  String get completedSection => 'TAMAMLANAN';

  @override
  String get failedSection => 'BAŞARISIZ';

  @override
  String get sending => 'Gönderiliyor';

  @override
  String get receiving => 'Alınıyor';

  @override
  String unreachableDevices(String names) {
    return '$names ulaşılamadı';
  }

  @override
  String get selectUpTo4 => 'En fazla 4 kişi seç';

  @override
  String get roomCreated => 'Oda oluşturuldu';

  @override
  String get statusPending => 'Bekliyor';

  @override
  String get statusAccepted => 'Kabul etti';

  @override
  String get statusDeclined => 'Reddetti';

  @override
  String get statusOffline => 'Çevrimdışı';

  @override
  String get waitingForResponses => 'Yanıtlar bekleniyor...';

  @override
  String get roomSource => 'Oda';

  @override
  String get quickSendSource => 'Hızlı Gönderim';

  @override
  String filesQueued(int count) {
    return '+$count dosya sırada bekliyor';
  }

  @override
  String get selectAll => 'Tümünü seç';

  @override
  String get selectNone => 'Hiçbirini seçme';

  @override
  String acceptSelected(int count) {
    return 'Seçilenleri kabul et ($count)';
  }

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get fileNotFoundRetry => 'Kaynak dosya artık mevcut değil';

  @override
  String get openFile => 'Dosyayı Aç';

  @override
  String get openFileLocation => 'Dosya Konumunu Aç';

  @override
  String get info => 'Bilgi';

  @override
  String get deleteFromHistory => 'Geçmişten Sil';

  @override
  String get deleteRecordConfirm => 'Bu kayıt geçmişten silinsin mi?';

  @override
  String get delete => 'Sil';

  @override
  String get recordDeleted => 'Kayıt silindi';

  @override
  String get transferDate => 'Tarih';

  @override
  String get transferSize => 'Boyut';

  @override
  String get transferPeer => 'Kişi';

  @override
  String get transferDirection => 'Yön';

  @override
  String get transferSavePath => 'Kayıt Konumu';

  @override
  String get directionSent => 'Gönderildi';

  @override
  String get directionReceived => 'Alındı';

  @override
  String get filterSent => 'Gönderdiklerim';

  @override
  String get filterReceived => 'Aldıklarım';

  @override
  String get filterAll => 'Hepsi';

  @override
  String get textFilter => 'Metin';

  @override
  String get portBusyTitle => 'Port Kullanımda';

  @override
  String get portBusyMessage =>
      'Port 53317 başka bir uygulama tarafından kullanılıyor. Lütfen diğer uygulamayı kapatıp tekrar deneyin.';

  @override
  String get ok => 'Tamam';

  @override
  String get quickRoom => 'Hızlı Oda';

  @override
  String get trustDevice => 'Güven';

  @override
  String get untrustDevice => 'Güveni Kaldır';

  @override
  String get blockDevice => 'Engelle';

  @override
  String get unblockDevice => 'Engeli Kaldır';

  @override
  String deviceTrusted(String name) {
    return '$name artık güvenilir';
  }

  @override
  String deviceUntrusted(String name) {
    return '$name güvenilir listesinden çıkarıldı';
  }

  @override
  String deviceBlocked(String name) {
    return '$name engellendi';
  }

  @override
  String deviceUnblocked(String name) {
    return '$name engeli kaldırıldı';
  }

  @override
  String get notificationSound => 'Bildirim sesi';

  @override
  String get notificationSoundDesc => 'Dosya geldiğinde ses çal';

  @override
  String get notificationVibration => 'Titreşim';

  @override
  String get notificationVibrationDesc => 'Dosya geldiğinde titreşim';

  @override
  String get noConnection => 'Ağ bağlantısı yok';

  @override
  String get connectionRestored => 'Bağlantı sağlandı';

  @override
  String get clearTempFiles => 'Geçici dosyaları temizle';

  @override
  String get clearTempFilesDesc => 'Yarım kalan transferlerin dosyalarını sil';

  @override
  String tempFilesCleared(int count) {
    return 'Geçici dosyalar temizlendi ($count)';
  }

  @override
  String get noTempFiles => 'Temizlenecek geçici dosya yok';

  @override
  String get chat => 'Sohbet';

  @override
  String get noActiveRoom => 'Aktif oda yok';

  @override
  String get copied => 'Kopyalandı';

  @override
  String get developer => 'Geliştirici';

  @override
  String wantsToSendFile(String fileName) {
    return 'Göndermek istiyor: $fileName';
  }

  @override
  String get roomInviteNotif => 'Oda Daveti';

  @override
  String invitesYouToRoom(String name) {
    return '$name seni odaya davet ediyor';
  }

  @override
  String get fileDeclined => 'Reddedildi';

  @override
  String get transferDeclinedToast => 'Transferiniz reddedildi';

  @override
  String get transferFailedToast => 'Transfer başarısız';
}
