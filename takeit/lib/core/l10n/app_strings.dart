import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_strings_en.dart';
import 'app_strings_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppStrings
/// returned by `AppStrings.of(context)`.
///
/// Applications need to include `AppStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_strings.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppStrings.localizationsDelegates,
///   supportedLocales: AppStrings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppStrings.supportedLocales
/// property.
abstract class AppStrings {
  AppStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @chooseNickname.
  ///
  /// In en, this message translates to:
  /// **'Choose your nickname'**
  String get chooseNickname;

  /// No description provided for @nicknamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g.'**
  String get nicknamePlaceholder;

  /// No description provided for @leaveEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for a random name. Your nickname will be saved.'**
  String get leaveEmptyHint;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @nearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'Nearby Devices'**
  String get nearbyDevices;

  /// No description provided for @nearbyTab.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearbyTab;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @transferHistory.
  ///
  /// In en, this message translates to:
  /// **'Transfer History'**
  String get transferHistory;

  /// No description provided for @newRoom.
  ///
  /// In en, this message translates to:
  /// **'New Room'**
  String get newRoom;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noDevicesFound;

  /// No description provided for @makeOthersOpen.
  ///
  /// In en, this message translates to:
  /// **'Make sure others have TakeIt open\non the same network.'**
  String get makeOthersOpen;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @devicesOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device on this network} other{{count} devices on this network}}'**
  String devicesOnNetwork(int count);

  /// No description provided for @chatRoom.
  ///
  /// In en, this message translates to:
  /// **'Chat Room'**
  String get chatRoom;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @fileTransfer.
  ///
  /// In en, this message translates to:
  /// **'File Transfer'**
  String get fileTransfer;

  /// No description provided for @transferring.
  ///
  /// In en, this message translates to:
  /// **'Transferring files...'**
  String get transferring;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @wantsToSend.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to send you a file'**
  String wantsToSend(String name);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @noTransfersYet.
  ///
  /// In en, this message translates to:
  /// **'No transfers yet'**
  String get noTransfersYet;

  /// No description provided for @historyWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your file transfer history will appear here.'**
  String get historyWillAppear;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryConfirm;

  /// No description provided for @clearHistoryMsg.
  ///
  /// In en, this message translates to:
  /// **'This will remove all transfer records.'**
  String get clearHistoryMsg;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @preparingFiles.
  ///
  /// In en, this message translates to:
  /// **'Preparing files…'**
  String get preparingFiles;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @filePathNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'File path not available'**
  String get filePathNotAvailable;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @changeNickname.
  ///
  /// In en, this message translates to:
  /// **'Change nickname'**
  String get changeNickname;

  /// No description provided for @enterNewNickname.
  ///
  /// In en, this message translates to:
  /// **'Enter new nickname'**
  String get enterNewNickname;

  /// No description provided for @resetToRandom.
  ///
  /// In en, this message translates to:
  /// **'Reset to random name'**
  String get resetToRandom;

  /// No description provided for @nicknameRandomized.
  ///
  /// In en, this message translates to:
  /// **'Nickname set to \"{name}\"'**
  String nicknameRandomized(String name);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @modern.
  ///
  /// In en, this message translates to:
  /// **'Modern'**
  String get modern;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @restartServer.
  ///
  /// In en, this message translates to:
  /// **'Restart server'**
  String get restartServer;

  /// No description provided for @restartServerDesc.
  ///
  /// In en, this message translates to:
  /// **'Restart HTTP server & re-discover devices'**
  String get restartServerDesc;

  /// No description provided for @serverRestarted.
  ///
  /// In en, this message translates to:
  /// **'Server restarted successfully'**
  String get serverRestarted;

  /// No description provided for @restartFailed.
  ///
  /// In en, this message translates to:
  /// **'Restart failed: {error}'**
  String restartFailed(String error);

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appDesc.
  ///
  /// In en, this message translates to:
  /// **'Local network file sharing'**
  String get appDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @nicknameChanged.
  ///
  /// In en, this message translates to:
  /// **'Nickname changed to \"{name}\"'**
  String nicknameChanged(String name);

  /// No description provided for @downloadLocation.
  ///
  /// In en, this message translates to:
  /// **'Download Location'**
  String get downloadLocation;

  /// No description provided for @downloadLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Folder where files will be saved'**
  String get downloadLocationDesc;

  /// No description provided for @defaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Default (Downloads)'**
  String get defaultLocation;

  /// No description provided for @changeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change Folder'**
  String get changeFolder;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get openFolder;

  /// No description provided for @folderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Folder not found'**
  String get folderNotFound;

  /// No description provided for @wifiWarning.
  ///
  /// In en, this message translates to:
  /// **'Please make sure you are on the same WiFi network as the target device.'**
  String get wifiWarning;

  /// No description provided for @dropFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Drop files here'**
  String get dropFilesHere;

  /// No description provided for @clipboardShared.
  ///
  /// In en, this message translates to:
  /// **'Clipboard shared'**
  String get clipboardShared;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @clipboardFrom.
  ///
  /// In en, this message translates to:
  /// **'Clipboard from {name}'**
  String clipboardFrom(String name);

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @quickSend.
  ///
  /// In en, this message translates to:
  /// **'Quick Send'**
  String get quickSend;

  /// No description provided for @quickSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Send'**
  String get quickSendTitle;

  /// No description provided for @quickSendFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to send you a file'**
  String quickSendFrom(String name);

  /// No description provided for @quickTextFrom.
  ///
  /// In en, this message translates to:
  /// **'Message from {name}'**
  String quickTextFrom(String name);

  /// No description provided for @selectRecipients.
  ///
  /// In en, this message translates to:
  /// **'Select recipients'**
  String get selectRecipients;

  /// No description provided for @quickTextHint.
  ///
  /// In en, this message translates to:
  /// **'Type the text you want to send...'**
  String get quickTextHint;

  /// No description provided for @sendText.
  ///
  /// In en, this message translates to:
  /// **'Send Text'**
  String get sendText;

  /// No description provided for @sendFile.
  ///
  /// In en, this message translates to:
  /// **'Send File'**
  String get sendFile;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @inRoom.
  ///
  /// In en, this message translates to:
  /// **'In a room'**
  String get inRoom;

  /// No description provided for @userInRoom.
  ///
  /// In en, this message translates to:
  /// **'This person is currently in a room'**
  String get userInRoom;

  /// No description provided for @dropOrAddFiles.
  ///
  /// In en, this message translates to:
  /// **'Drop or add files'**
  String get dropOrAddFiles;

  /// No description provided for @addFile.
  ///
  /// In en, this message translates to:
  /// **'Add File'**
  String get addFile;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @itemsReady.
  ///
  /// In en, this message translates to:
  /// **'item(s) ready'**
  String get itemsReady;

  /// No description provided for @selectRecipientsBtn.
  ///
  /// In en, this message translates to:
  /// **'Select Recipients'**
  String get selectRecipientsBtn;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @nothingAddedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet'**
  String get nothingAddedYet;

  /// No description provided for @sendingFiles.
  ///
  /// In en, this message translates to:
  /// **'Sending files…'**
  String get sendingFiles;

  /// No description provided for @filesSent.
  ///
  /// In en, this message translates to:
  /// **'Files sent'**
  String get filesSent;

  /// No description provided for @switchRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Room'**
  String get switchRoomTitle;

  /// No description provided for @switchRoomMsg.
  ///
  /// In en, this message translates to:
  /// **'You have an active room with \"{members}\". Creating a new room will close the current one.'**
  String switchRoomMsg(String members);

  /// No description provided for @activeTransferWarning.
  ///
  /// In en, this message translates to:
  /// **'Active file transfers will be cancelled!'**
  String get activeTransferWarning;

  /// No description provided for @switchRoom.
  ///
  /// In en, this message translates to:
  /// **'Switch Room'**
  String get switchRoom;

  /// No description provided for @createRoom.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoom;

  /// No description provided for @roomInvite.
  ///
  /// In en, this message translates to:
  /// **'Room Invite'**
  String get roomInvite;

  /// No description provided for @invitesYou.
  ///
  /// In en, this message translates to:
  /// **'{name} invites you to a room'**
  String invitesYou(String name);

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave Room'**
  String get leaveRoom;

  /// No description provided for @leaveRoomConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this room?'**
  String get leaveRoomConfirm;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nSay hello!'**
  String get noMessages;

  /// No description provided for @activeRoom.
  ///
  /// In en, this message translates to:
  /// **'Active Room'**
  String get activeRoom;

  /// No description provided for @tapToReturn.
  ///
  /// In en, this message translates to:
  /// **'Tap to return to chat'**
  String get tapToReturn;

  /// No description provided for @sessionTransfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get sessionTransfersTitle;

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfers;

  /// No description provided for @activeSection.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get activeSection;

  /// No description provided for @completedSection.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completedSection;

  /// No description provided for @failedSection.
  ///
  /// In en, this message translates to:
  /// **'FAILED'**
  String get failedSection;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sending;

  /// No description provided for @receiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get receiving;

  /// No description provided for @unreachableDevices.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {names}'**
  String unreachableDevices(String names);

  /// No description provided for @selectUpTo4.
  ///
  /// In en, this message translates to:
  /// **'Select up to 4 people'**
  String get selectUpTo4;

  /// No description provided for @roomCreated.
  ///
  /// In en, this message translates to:
  /// **'Room created'**
  String get roomCreated;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAccepted;

  /// No description provided for @statusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get statusDeclined;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @waitingForResponses.
  ///
  /// In en, this message translates to:
  /// **'Waiting for responses...'**
  String get waitingForResponses;

  /// No description provided for @roomSource.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomSource;

  /// No description provided for @quickSendSource.
  ///
  /// In en, this message translates to:
  /// **'Quick Send'**
  String get quickSendSource;

  /// No description provided for @filesQueued.
  ///
  /// In en, this message translates to:
  /// **'+{count} {count, plural, =1{file} other{files}} queued'**
  String filesQueued(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @selectNone.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get selectNone;

  /// No description provided for @acceptSelected.
  ///
  /// In en, this message translates to:
  /// **'Accept selected ({count})'**
  String acceptSelected(int count);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @fileNotFoundRetry.
  ///
  /// In en, this message translates to:
  /// **'Source file no longer exists'**
  String get fileNotFoundRetry;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get openFile;

  /// No description provided for @openFileLocation.
  ///
  /// In en, this message translates to:
  /// **'Open File Location'**
  String get openFileLocation;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @deleteFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Delete from History'**
  String get deleteFromHistory;

  /// No description provided for @deleteRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this record from history?'**
  String get deleteRecordConfirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @recordDeleted.
  ///
  /// In en, this message translates to:
  /// **'Record deleted'**
  String get recordDeleted;

  /// No description provided for @transferDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get transferDate;

  /// No description provided for @transferSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get transferSize;

  /// No description provided for @transferPeer.
  ///
  /// In en, this message translates to:
  /// **'Peer'**
  String get transferPeer;

  /// No description provided for @transferDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get transferDirection;

  /// No description provided for @transferSavePath.
  ///
  /// In en, this message translates to:
  /// **'Save Location'**
  String get transferSavePath;

  /// No description provided for @directionSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get directionSent;

  /// No description provided for @directionReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get directionReceived;

  /// No description provided for @filterSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get filterSent;

  /// No description provided for @filterReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get filterReceived;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @textFilter.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textFilter;

  /// No description provided for @portBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'Port In Use'**
  String get portBusyTitle;

  /// No description provided for @portBusyMessage.
  ///
  /// In en, this message translates to:
  /// **'Port 53317 is already in use by another application. Please close the other application and try again.'**
  String get portBusyMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @quickRoom.
  ///
  /// In en, this message translates to:
  /// **'Quick Room'**
  String get quickRoom;

  /// No description provided for @trustDevice.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get trustDevice;

  /// No description provided for @untrustDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove Trust'**
  String get untrustDevice;

  /// No description provided for @blockDevice.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockDevice;

  /// No description provided for @unblockDevice.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockDevice;

  /// No description provided for @deviceTrusted.
  ///
  /// In en, this message translates to:
  /// **'{name} is now trusted'**
  String deviceTrusted(String name);

  /// No description provided for @deviceUntrusted.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer trusted'**
  String deviceUntrusted(String name);

  /// No description provided for @deviceBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is now blocked'**
  String deviceBlocked(String name);

  /// No description provided for @deviceUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is now unblocked'**
  String deviceUnblocked(String name);

  /// No description provided for @notificationSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get notificationSound;

  /// No description provided for @notificationSoundDesc.
  ///
  /// In en, this message translates to:
  /// **'Play sound when a file arrives'**
  String get notificationSoundDesc;

  /// No description provided for @notificationVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get notificationVibration;

  /// No description provided for @notificationVibrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate when a file arrives'**
  String get notificationVibrationDesc;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No network connection'**
  String get noConnection;

  /// No description provided for @connectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get connectionRestored;

  /// No description provided for @clearTempFiles.
  ///
  /// In en, this message translates to:
  /// **'Clear temp files'**
  String get clearTempFiles;

  /// No description provided for @clearTempFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Delete leftover files from incomplete transfers'**
  String get clearTempFilesDesc;

  /// No description provided for @tempFilesCleared.
  ///
  /// In en, this message translates to:
  /// **'Temp files cleared ({count})'**
  String tempFilesCleared(int count);

  /// No description provided for @noTempFiles.
  ///
  /// In en, this message translates to:
  /// **'No temp files to clear'**
  String get noTempFiles;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @noActiveRoom.
  ///
  /// In en, this message translates to:
  /// **'No active room'**
  String get noActiveRoom;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @wantsToSendFile.
  ///
  /// In en, this message translates to:
  /// **'Wants to send: {fileName}'**
  String wantsToSendFile(String fileName);

  /// No description provided for @roomInviteNotif.
  ///
  /// In en, this message translates to:
  /// **'Room Invite'**
  String get roomInviteNotif;

  /// No description provided for @invitesYouToRoom.
  ///
  /// In en, this message translates to:
  /// **'{name} invites you to a room'**
  String invitesYouToRoom(String name);

  /// No description provided for @fileDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get fileDeclined;

  /// No description provided for @transferDeclinedToast.
  ///
  /// In en, this message translates to:
  /// **'Your transfer was declined'**
  String get transferDeclinedToast;

  /// No description provided for @transferFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed'**
  String get transferFailedToast;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(lookupAppStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

AppStrings lookupAppStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppStringsEn();
    case 'tr':
      return AppStringsTr();
  }

  throw FlutterError(
    'AppStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
