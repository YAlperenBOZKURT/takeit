// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transfer_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TransferRecord _$TransferRecordFromJson(Map<String, dynamic> json) {
  return _TransferRecord.fromJson(json);
}

/// @nodoc
mixin _$TransferRecord {
  String get id => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  int get fileSize => throw _privateConstructorUsedError;
  String get peerAlias => throw _privateConstructorUsedError;
  String get direction =>
      throw _privateConstructorUsedError; // 'sent' or 'received'
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get fileMimeType => throw _privateConstructorUsedError;
  String? get savePath => throw _privateConstructorUsedError;

  /// Serializes this TransferRecord to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TransferRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransferRecordCopyWith<TransferRecord> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransferRecordCopyWith<$Res> {
  factory $TransferRecordCopyWith(
    TransferRecord value,
    $Res Function(TransferRecord) then,
  ) = _$TransferRecordCopyWithImpl<$Res, TransferRecord>;
  @useResult
  $Res call({
    String id,
    String fileName,
    int fileSize,
    String peerAlias,
    String direction,
    DateTime timestamp,
    String? fileMimeType,
    String? savePath,
  });
}

/// @nodoc
class _$TransferRecordCopyWithImpl<$Res, $Val extends TransferRecord>
    implements $TransferRecordCopyWith<$Res> {
  _$TransferRecordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TransferRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? fileSize = null,
    Object? peerAlias = null,
    Object? direction = null,
    Object? timestamp = null,
    Object? fileMimeType = freezed,
    Object? savePath = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            fileName: null == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                      as String,
            fileSize: null == fileSize
                ? _value.fileSize
                : fileSize // ignore: cast_nullable_to_non_nullable
                      as int,
            peerAlias: null == peerAlias
                ? _value.peerAlias
                : peerAlias // ignore: cast_nullable_to_non_nullable
                      as String,
            direction: null == direction
                ? _value.direction
                : direction // ignore: cast_nullable_to_non_nullable
                      as String,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            fileMimeType: freezed == fileMimeType
                ? _value.fileMimeType
                : fileMimeType // ignore: cast_nullable_to_non_nullable
                      as String?,
            savePath: freezed == savePath
                ? _value.savePath
                : savePath // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransferRecordImplCopyWith<$Res>
    implements $TransferRecordCopyWith<$Res> {
  factory _$$TransferRecordImplCopyWith(
    _$TransferRecordImpl value,
    $Res Function(_$TransferRecordImpl) then,
  ) = __$$TransferRecordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String fileName,
    int fileSize,
    String peerAlias,
    String direction,
    DateTime timestamp,
    String? fileMimeType,
    String? savePath,
  });
}

/// @nodoc
class __$$TransferRecordImplCopyWithImpl<$Res>
    extends _$TransferRecordCopyWithImpl<$Res, _$TransferRecordImpl>
    implements _$$TransferRecordImplCopyWith<$Res> {
  __$$TransferRecordImplCopyWithImpl(
    _$TransferRecordImpl _value,
    $Res Function(_$TransferRecordImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TransferRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileName = null,
    Object? fileSize = null,
    Object? peerAlias = null,
    Object? direction = null,
    Object? timestamp = null,
    Object? fileMimeType = freezed,
    Object? savePath = freezed,
  }) {
    return _then(
      _$TransferRecordImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        fileName: null == fileName
            ? _value.fileName
            : fileName // ignore: cast_nullable_to_non_nullable
                  as String,
        fileSize: null == fileSize
            ? _value.fileSize
            : fileSize // ignore: cast_nullable_to_non_nullable
                  as int,
        peerAlias: null == peerAlias
            ? _value.peerAlias
            : peerAlias // ignore: cast_nullable_to_non_nullable
                  as String,
        direction: null == direction
            ? _value.direction
            : direction // ignore: cast_nullable_to_non_nullable
                  as String,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        fileMimeType: freezed == fileMimeType
            ? _value.fileMimeType
            : fileMimeType // ignore: cast_nullable_to_non_nullable
                  as String?,
        savePath: freezed == savePath
            ? _value.savePath
            : savePath // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TransferRecordImpl implements _TransferRecord {
  const _$TransferRecordImpl({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.peerAlias,
    required this.direction,
    required this.timestamp,
    this.fileMimeType,
    this.savePath,
  });

  factory _$TransferRecordImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransferRecordImplFromJson(json);

  @override
  final String id;
  @override
  final String fileName;
  @override
  final int fileSize;
  @override
  final String peerAlias;
  @override
  final String direction;
  // 'sent' or 'received'
  @override
  final DateTime timestamp;
  @override
  final String? fileMimeType;
  @override
  final String? savePath;

  @override
  String toString() {
    return 'TransferRecord(id: $id, fileName: $fileName, fileSize: $fileSize, peerAlias: $peerAlias, direction: $direction, timestamp: $timestamp, fileMimeType: $fileMimeType, savePath: $savePath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransferRecordImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileSize, fileSize) ||
                other.fileSize == fileSize) &&
            (identical(other.peerAlias, peerAlias) ||
                other.peerAlias == peerAlias) &&
            (identical(other.direction, direction) ||
                other.direction == direction) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.fileMimeType, fileMimeType) ||
                other.fileMimeType == fileMimeType) &&
            (identical(other.savePath, savePath) ||
                other.savePath == savePath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    fileName,
    fileSize,
    peerAlias,
    direction,
    timestamp,
    fileMimeType,
    savePath,
  );

  /// Create a copy of TransferRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransferRecordImplCopyWith<_$TransferRecordImpl> get copyWith =>
      __$$TransferRecordImplCopyWithImpl<_$TransferRecordImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TransferRecordImplToJson(this);
  }
}

abstract class _TransferRecord implements TransferRecord {
  const factory _TransferRecord({
    required final String id,
    required final String fileName,
    required final int fileSize,
    required final String peerAlias,
    required final String direction,
    required final DateTime timestamp,
    final String? fileMimeType,
    final String? savePath,
  }) = _$TransferRecordImpl;

  factory _TransferRecord.fromJson(Map<String, dynamic> json) =
      _$TransferRecordImpl.fromJson;

  @override
  String get id;
  @override
  String get fileName;
  @override
  int get fileSize;
  @override
  String get peerAlias;
  @override
  String get direction; // 'sent' or 'received'
  @override
  DateTime get timestamp;
  @override
  String? get fileMimeType;
  @override
  String? get savePath;

  /// Create a copy of TransferRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransferRecordImplCopyWith<_$TransferRecordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
