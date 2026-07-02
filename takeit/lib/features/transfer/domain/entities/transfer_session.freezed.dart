// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transfer_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TransferSession {
  String get sessionId => throw _privateConstructorUsedError;
  String get fileId => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  int get fileSize => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get senderAlias => throw _privateConstructorUsedError;
  TransferDirection get direction => throw _privateConstructorUsedError;
  TransferStatus get status => throw _privateConstructorUsedError;
  int get bytesTransferred => throw _privateConstructorUsedError;
  String? get fileMimeType => throw _privateConstructorUsedError;
  String? get token => throw _privateConstructorUsedError;
  String? get savePath => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;

  /// Create a copy of TransferSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransferSessionCopyWith<TransferSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransferSessionCopyWith<$Res> {
  factory $TransferSessionCopyWith(
    TransferSession value,
    $Res Function(TransferSession) then,
  ) = _$TransferSessionCopyWithImpl<$Res, TransferSession>;
  @useResult
  $Res call({
    String sessionId,
    String fileId,
    String fileName,
    int fileSize,
    String senderId,
    String senderAlias,
    TransferDirection direction,
    TransferStatus status,
    int bytesTransferred,
    String? fileMimeType,
    String? token,
    String? savePath,
    DateTime? startedAt,
  });
}

/// @nodoc
class _$TransferSessionCopyWithImpl<$Res, $Val extends TransferSession>
    implements $TransferSessionCopyWith<$Res> {
  _$TransferSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TransferSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? fileId = null,
    Object? fileName = null,
    Object? fileSize = null,
    Object? senderId = null,
    Object? senderAlias = null,
    Object? direction = null,
    Object? status = null,
    Object? bytesTransferred = null,
    Object? fileMimeType = freezed,
    Object? token = freezed,
    Object? savePath = freezed,
    Object? startedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            fileId: null == fileId
                ? _value.fileId
                : fileId // ignore: cast_nullable_to_non_nullable
                      as String,
            fileName: null == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                      as String,
            fileSize: null == fileSize
                ? _value.fileSize
                : fileSize // ignore: cast_nullable_to_non_nullable
                      as int,
            senderId: null == senderId
                ? _value.senderId
                : senderId // ignore: cast_nullable_to_non_nullable
                      as String,
            senderAlias: null == senderAlias
                ? _value.senderAlias
                : senderAlias // ignore: cast_nullable_to_non_nullable
                      as String,
            direction: null == direction
                ? _value.direction
                : direction // ignore: cast_nullable_to_non_nullable
                      as TransferDirection,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TransferStatus,
            bytesTransferred: null == bytesTransferred
                ? _value.bytesTransferred
                : bytesTransferred // ignore: cast_nullable_to_non_nullable
                      as int,
            fileMimeType: freezed == fileMimeType
                ? _value.fileMimeType
                : fileMimeType // ignore: cast_nullable_to_non_nullable
                      as String?,
            token: freezed == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String?,
            savePath: freezed == savePath
                ? _value.savePath
                : savePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransferSessionImplCopyWith<$Res>
    implements $TransferSessionCopyWith<$Res> {
  factory _$$TransferSessionImplCopyWith(
    _$TransferSessionImpl value,
    $Res Function(_$TransferSessionImpl) then,
  ) = __$$TransferSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sessionId,
    String fileId,
    String fileName,
    int fileSize,
    String senderId,
    String senderAlias,
    TransferDirection direction,
    TransferStatus status,
    int bytesTransferred,
    String? fileMimeType,
    String? token,
    String? savePath,
    DateTime? startedAt,
  });
}

/// @nodoc
class __$$TransferSessionImplCopyWithImpl<$Res>
    extends _$TransferSessionCopyWithImpl<$Res, _$TransferSessionImpl>
    implements _$$TransferSessionImplCopyWith<$Res> {
  __$$TransferSessionImplCopyWithImpl(
    _$TransferSessionImpl _value,
    $Res Function(_$TransferSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TransferSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? fileId = null,
    Object? fileName = null,
    Object? fileSize = null,
    Object? senderId = null,
    Object? senderAlias = null,
    Object? direction = null,
    Object? status = null,
    Object? bytesTransferred = null,
    Object? fileMimeType = freezed,
    Object? token = freezed,
    Object? savePath = freezed,
    Object? startedAt = freezed,
  }) {
    return _then(
      _$TransferSessionImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        fileId: null == fileId
            ? _value.fileId
            : fileId // ignore: cast_nullable_to_non_nullable
                  as String,
        fileName: null == fileName
            ? _value.fileName
            : fileName // ignore: cast_nullable_to_non_nullable
                  as String,
        fileSize: null == fileSize
            ? _value.fileSize
            : fileSize // ignore: cast_nullable_to_non_nullable
                  as int,
        senderId: null == senderId
            ? _value.senderId
            : senderId // ignore: cast_nullable_to_non_nullable
                  as String,
        senderAlias: null == senderAlias
            ? _value.senderAlias
            : senderAlias // ignore: cast_nullable_to_non_nullable
                  as String,
        direction: null == direction
            ? _value.direction
            : direction // ignore: cast_nullable_to_non_nullable
                  as TransferDirection,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TransferStatus,
        bytesTransferred: null == bytesTransferred
            ? _value.bytesTransferred
            : bytesTransferred // ignore: cast_nullable_to_non_nullable
                  as int,
        fileMimeType: freezed == fileMimeType
            ? _value.fileMimeType
            : fileMimeType // ignore: cast_nullable_to_non_nullable
                  as String?,
        token: freezed == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String?,
        savePath: freezed == savePath
            ? _value.savePath
            : savePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$TransferSessionImpl extends _TransferSession {
  const _$TransferSessionImpl({
    required this.sessionId,
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.senderId,
    required this.senderAlias,
    required this.direction,
    this.status = TransferStatus.pending,
    this.bytesTransferred = 0,
    this.fileMimeType,
    this.token,
    this.savePath,
    this.startedAt,
  }) : super._();

  @override
  final String sessionId;
  @override
  final String fileId;
  @override
  final String fileName;
  @override
  final int fileSize;
  @override
  final String senderId;
  @override
  final String senderAlias;
  @override
  final TransferDirection direction;
  @override
  @JsonKey()
  final TransferStatus status;
  @override
  @JsonKey()
  final int bytesTransferred;
  @override
  final String? fileMimeType;
  @override
  final String? token;
  @override
  final String? savePath;
  @override
  final DateTime? startedAt;

  @override
  String toString() {
    return 'TransferSession(sessionId: $sessionId, fileId: $fileId, fileName: $fileName, fileSize: $fileSize, senderId: $senderId, senderAlias: $senderAlias, direction: $direction, status: $status, bytesTransferred: $bytesTransferred, fileMimeType: $fileMimeType, token: $token, savePath: $savePath, startedAt: $startedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransferSessionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.fileId, fileId) || other.fileId == fileId) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileSize, fileSize) ||
                other.fileSize == fileSize) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.senderAlias, senderAlias) ||
                other.senderAlias == senderAlias) &&
            (identical(other.direction, direction) ||
                other.direction == direction) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.bytesTransferred, bytesTransferred) ||
                other.bytesTransferred == bytesTransferred) &&
            (identical(other.fileMimeType, fileMimeType) ||
                other.fileMimeType == fileMimeType) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.savePath, savePath) ||
                other.savePath == savePath) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    fileId,
    fileName,
    fileSize,
    senderId,
    senderAlias,
    direction,
    status,
    bytesTransferred,
    fileMimeType,
    token,
    savePath,
    startedAt,
  );

  /// Create a copy of TransferSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransferSessionImplCopyWith<_$TransferSessionImpl> get copyWith =>
      __$$TransferSessionImplCopyWithImpl<_$TransferSessionImpl>(
        this,
        _$identity,
      );
}

abstract class _TransferSession extends TransferSession {
  const factory _TransferSession({
    required final String sessionId,
    required final String fileId,
    required final String fileName,
    required final int fileSize,
    required final String senderId,
    required final String senderAlias,
    required final TransferDirection direction,
    final TransferStatus status,
    final int bytesTransferred,
    final String? fileMimeType,
    final String? token,
    final String? savePath,
    final DateTime? startedAt,
  }) = _$TransferSessionImpl;
  const _TransferSession._() : super._();

  @override
  String get sessionId;
  @override
  String get fileId;
  @override
  String get fileName;
  @override
  int get fileSize;
  @override
  String get senderId;
  @override
  String get senderAlias;
  @override
  TransferDirection get direction;
  @override
  TransferStatus get status;
  @override
  int get bytesTransferred;
  @override
  String? get fileMimeType;
  @override
  String? get token;
  @override
  String? get savePath;
  @override
  DateTime? get startedAt;

  /// Create a copy of TransferSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransferSessionImplCopyWith<_$TransferSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
