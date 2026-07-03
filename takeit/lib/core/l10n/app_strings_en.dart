// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_strings.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppStringsEn extends AppStrings {
  AppStringsEn([String locale = 'en']) : super(locale);

  @override
  String get chooseNickname => 'Choose your nickname';

  @override
  String get nicknamePlaceholder => 'e.g.';

  @override
  String get leaveEmptyHint =>
      'Leave empty for a random name. Your nickname will be saved.';

  @override
  String get continueBtn => 'Continue';

  @override
  String get nearbyDevices => 'Nearby Devices';

  @override
  String get nearbyTab => 'Nearby';

  @override
  String get settings => 'Settings';

  @override
  String get transferHistory => 'Transfer History';

  @override
  String get newRoom => 'New Room';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String get makeOthersOpen =>
      'Make sure others have TakeIt open\non the same network.';

  @override
  String get scanning => 'Scanning...';

  @override
  String devicesOnNetwork(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices on this network',
      one: '1 device on this network',
    );
    return '$_temp0';
  }

  @override
  String get chatRoom => 'Chat Room';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get fileTransfer => 'File Transfer';

  @override
  String get transferring => 'Transferring files...';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String wantsToSend(String name) {
    return '$name wants to send you a file';
  }

  @override
  String get all => 'All';

  @override
  String get files => 'Files';

  @override
  String get noTransfersYet => 'No transfers yet';

  @override
  String get historyWillAppear =>
      'Your file transfer history will appear here.';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryConfirm => 'Clear history?';

  @override
  String get clearHistoryMsg => 'This will remove all transfer records.';

  @override
  String get clear => 'Clear';

  @override
  String get clearAll => 'Clear All';

  @override
  String get preparingFiles => 'Preparing files…';

  @override
  String get cancel => 'Cancel';

  @override
  String get filePathNotAvailable => 'File path not available';

  @override
  String get profile => 'Profile';

  @override
  String get nickname => 'Nickname';

  @override
  String get changeNickname => 'Change nickname';

  @override
  String get enterNewNickname => 'Enter new nickname';

  @override
  String get resetToRandom => 'Reset to random name';

  @override
  String nicknameRandomized(String name) {
    return 'Nickname set to \"$name\"';
  }

  @override
  String get save => 'Save';

  @override
  String get appearance => 'Appearance';

  @override
  String get systemDefault => 'System default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get modern => 'Modern';

  @override
  String get network => 'Network';

  @override
  String get restartServer => 'Restart server';

  @override
  String get restartServerDesc => 'Restart HTTP server & re-discover devices';

  @override
  String get serverRestarted => 'Server restarted successfully';

  @override
  String restartFailed(String error) {
    return 'Restart failed: $error';
  }

  @override
  String get about => 'About';

  @override
  String get appDesc => 'Local network file sharing';

  @override
  String get language => 'Language';

  @override
  String nicknameChanged(String name) {
    return 'Nickname changed to \"$name\"';
  }

  @override
  String get downloadLocation => 'Download Location';

  @override
  String get downloadLocationDesc => 'Folder where files will be saved';

  @override
  String get defaultLocation => 'Default (Downloads)';

  @override
  String get changeFolder => 'Change Folder';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get folderNotFound => 'Folder not found';

  @override
  String get wifiWarning =>
      'Please make sure you are on the same WiFi network as the target device.';

  @override
  String get dropFilesHere => 'Drop files here';

  @override
  String get clipboardShared => 'Clipboard shared';

  @override
  String get copy => 'Copy';

  @override
  String get close => 'Close';

  @override
  String clipboardFrom(String name) {
    return 'Clipboard from $name';
  }

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get quickSend => 'Quick Send';

  @override
  String get quickSendTitle => 'Quick Send';

  @override
  String quickSendFrom(String name) {
    return '$name wants to send you a file';
  }

  @override
  String quickTextFrom(String name) {
    return 'Message from $name';
  }

  @override
  String get selectRecipients => 'Select recipients';

  @override
  String get quickTextHint => 'Type the text you want to send...';

  @override
  String get sendText => 'Send Text';

  @override
  String get sendFile => 'Send File';

  @override
  String get file => 'File';

  @override
  String get text => 'Text';

  @override
  String get inRoom => 'In a room';

  @override
  String get userInRoom => 'This person is currently in a room';

  @override
  String get dropOrAddFiles => 'Drop or add files';

  @override
  String get addFile => 'Add File';

  @override
  String get paste => 'Paste';

  @override
  String get itemsReady => 'item(s) ready';

  @override
  String get selectRecipientsBtn => 'Select Recipients';

  @override
  String get send => 'Send';

  @override
  String get addButton => 'Add';

  @override
  String get nothingAddedYet => 'Nothing added yet';

  @override
  String get sendingFiles => 'Sending files…';

  @override
  String get filesSent => 'Files sent';

  @override
  String get switchRoomTitle => 'Switch Room';

  @override
  String switchRoomMsg(String members) {
    return 'You have an active room with \"$members\". Creating a new room will close the current one.';
  }

  @override
  String get activeTransferWarning =>
      'Active file transfers will be cancelled!';

  @override
  String get switchRoom => 'Switch Room';

  @override
  String get createRoom => 'Create Room';

  @override
  String get roomInvite => 'Room Invite';

  @override
  String invitesYou(String name) {
    return '$name invites you to a room';
  }

  @override
  String get join => 'Join';

  @override
  String get leaveRoom => 'Leave Room';

  @override
  String get leaveRoomConfirm => 'Are you sure you want to leave this room?';

  @override
  String get noMessages => 'No messages yet.\nSay hello!';

  @override
  String get activeRoom => 'Active Room';

  @override
  String get tapToReturn => 'Tap to return to chat';

  @override
  String get sessionTransfersTitle => 'Transfers';

  @override
  String get transfers => 'Transfers';

  @override
  String get activeSection => 'ACTIVE';

  @override
  String get completedSection => 'COMPLETED';

  @override
  String get failedSection => 'FAILED';

  @override
  String get sending => 'Sending';

  @override
  String get receiving => 'Receiving';

  @override
  String unreachableDevices(String names) {
    return 'Could not reach $names';
  }

  @override
  String get selectUpTo4 => 'Select up to 4 people';

  @override
  String get roomCreated => 'Room created';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusDeclined => 'Declined';

  @override
  String get statusOffline => 'Offline';

  @override
  String get waitingForResponses => 'Waiting for responses...';

  @override
  String get roomSource => 'Room';

  @override
  String get quickSendSource => 'Quick Send';

  @override
  String filesQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return '+$count $_temp0 queued';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get selectNone => 'Select none';

  @override
  String acceptSelected(int count) {
    return 'Accept selected ($count)';
  }

  @override
  String get retry => 'Retry';

  @override
  String get fileNotFoundRetry => 'Source file no longer exists';

  @override
  String get openFile => 'Open File';

  @override
  String get openFileLocation => 'Open File Location';

  @override
  String get info => 'Info';

  @override
  String get deleteFromHistory => 'Delete from History';

  @override
  String get deleteRecordConfirm => 'Delete this record from history?';

  @override
  String get delete => 'Delete';

  @override
  String get recordDeleted => 'Record deleted';

  @override
  String get transferDate => 'Date';

  @override
  String get transferSize => 'Size';

  @override
  String get transferPeer => 'Peer';

  @override
  String get transferDirection => 'Direction';

  @override
  String get transferSavePath => 'Save Location';

  @override
  String get directionSent => 'Sent';

  @override
  String get directionReceived => 'Received';

  @override
  String get filterSent => 'Sent';

  @override
  String get filterReceived => 'Received';

  @override
  String get filterAll => 'All';

  @override
  String get textFilter => 'Text';

  @override
  String get portBusyTitle => 'Port In Use';

  @override
  String get portBusyMessage =>
      'Port 53317 is already in use by another application. Please close the other application and try again.';

  @override
  String get ok => 'OK';

  @override
  String get quickRoom => 'Quick Room';

  @override
  String get trustDevice => 'Trust';

  @override
  String get untrustDevice => 'Remove Trust';

  @override
  String get blockDevice => 'Block';

  @override
  String get unblockDevice => 'Unblock';

  @override
  String deviceTrusted(String name) {
    return '$name is now trusted';
  }

  @override
  String deviceUntrusted(String name) {
    return '$name is no longer trusted';
  }

  @override
  String deviceBlocked(String name) {
    return '$name is now blocked';
  }

  @override
  String deviceUnblocked(String name) {
    return '$name is now unblocked';
  }

  @override
  String get notificationSound => 'Notification sound';

  @override
  String get notificationSoundDesc => 'Play sound when a file arrives';

  @override
  String get notificationVibration => 'Vibration';

  @override
  String get notificationVibrationDesc => 'Vibrate when a file arrives';

  @override
  String get noConnection => 'No network connection';

  @override
  String get connectionRestored => 'Connection restored';

  @override
  String get clearTempFiles => 'Clear temp files';

  @override
  String get clearTempFilesDesc =>
      'Delete leftover files from incomplete transfers';

  @override
  String tempFilesCleared(int count) {
    return 'Temp files cleared ($count)';
  }

  @override
  String get noTempFiles => 'No temp files to clear';

  @override
  String get chat => 'Chat';

  @override
  String get noActiveRoom => 'No active room';

  @override
  String get copied => 'Copied';

  @override
  String get developer => 'Developer';

  @override
  String wantsToSendFile(String fileName) {
    return 'Wants to send: $fileName';
  }

  @override
  String get roomInviteNotif => 'Room Invite';

  @override
  String invitesYouToRoom(String name) {
    return '$name invites you to a room';
  }

  @override
  String get fileDeclined => 'Declined';

  @override
  String get transferDeclinedToast => 'Your transfer was declined';

  @override
  String get transferFailedToast => 'Transfer failed';
}
