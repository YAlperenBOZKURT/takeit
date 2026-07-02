// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RoomMember {
  String get fingerprint => throw _privateConstructorUsedError;
  String get alias => throw _privateConstructorUsedError;
  String get ip => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;
  String get deviceType => throw _privateConstructorUsedError;
  MemberStatus get status => throw _privateConstructorUsedError;

  /// Create a copy of RoomMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RoomMemberCopyWith<RoomMember> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoomMemberCopyWith<$Res> {
  factory $RoomMemberCopyWith(
    RoomMember value,
    $Res Function(RoomMember) then,
  ) = _$RoomMemberCopyWithImpl<$Res, RoomMember>;
  @useResult
  $Res call({
    String fingerprint,
    String alias,
    String ip,
    int port,
    String deviceType,
    MemberStatus status,
  });
}

/// @nodoc
class _$RoomMemberCopyWithImpl<$Res, $Val extends RoomMember>
    implements $RoomMemberCopyWith<$Res> {
  _$RoomMemberCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RoomMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fingerprint = null,
    Object? alias = null,
    Object? ip = null,
    Object? port = null,
    Object? deviceType = null,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            fingerprint: null == fingerprint
                ? _value.fingerprint
                : fingerprint // ignore: cast_nullable_to_non_nullable
                      as String,
            alias: null == alias
                ? _value.alias
                : alias // ignore: cast_nullable_to_non_nullable
                      as String,
            ip: null == ip
                ? _value.ip
                : ip // ignore: cast_nullable_to_non_nullable
                      as String,
            port: null == port
                ? _value.port
                : port // ignore: cast_nullable_to_non_nullable
                      as int,
            deviceType: null == deviceType
                ? _value.deviceType
                : deviceType // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as MemberStatus,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RoomMemberImplCopyWith<$Res>
    implements $RoomMemberCopyWith<$Res> {
  factory _$$RoomMemberImplCopyWith(
    _$RoomMemberImpl value,
    $Res Function(_$RoomMemberImpl) then,
  ) = __$$RoomMemberImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String fingerprint,
    String alias,
    String ip,
    int port,
    String deviceType,
    MemberStatus status,
  });
}

/// @nodoc
class __$$RoomMemberImplCopyWithImpl<$Res>
    extends _$RoomMemberCopyWithImpl<$Res, _$RoomMemberImpl>
    implements _$$RoomMemberImplCopyWith<$Res> {
  __$$RoomMemberImplCopyWithImpl(
    _$RoomMemberImpl _value,
    $Res Function(_$RoomMemberImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RoomMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fingerprint = null,
    Object? alias = null,
    Object? ip = null,
    Object? port = null,
    Object? deviceType = null,
    Object? status = null,
  }) {
    return _then(
      _$RoomMemberImpl(
        fingerprint: null == fingerprint
            ? _value.fingerprint
            : fingerprint // ignore: cast_nullable_to_non_nullable
                  as String,
        alias: null == alias
            ? _value.alias
            : alias // ignore: cast_nullable_to_non_nullable
                  as String,
        ip: null == ip
            ? _value.ip
            : ip // ignore: cast_nullable_to_non_nullable
                  as String,
        port: null == port
            ? _value.port
            : port // ignore: cast_nullable_to_non_nullable
                  as int,
        deviceType: null == deviceType
            ? _value.deviceType
            : deviceType // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as MemberStatus,
      ),
    );
  }
}

/// @nodoc

class _$RoomMemberImpl implements _RoomMember {
  const _$RoomMemberImpl({
    required this.fingerprint,
    required this.alias,
    required this.ip,
    required this.port,
    required this.deviceType,
    this.status = MemberStatus.pending,
  });

  @override
  final String fingerprint;
  @override
  final String alias;
  @override
  final String ip;
  @override
  final int port;
  @override
  final String deviceType;
  @override
  @JsonKey()
  final MemberStatus status;

  @override
  String toString() {
    return 'RoomMember(fingerprint: $fingerprint, alias: $alias, ip: $ip, port: $port, deviceType: $deviceType, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoomMemberImpl &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint) &&
            (identical(other.alias, alias) || other.alias == alias) &&
            (identical(other.ip, ip) || other.ip == ip) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.deviceType, deviceType) ||
                other.deviceType == deviceType) &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    fingerprint,
    alias,
    ip,
    port,
    deviceType,
    status,
  );

  /// Create a copy of RoomMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RoomMemberImplCopyWith<_$RoomMemberImpl> get copyWith =>
      __$$RoomMemberImplCopyWithImpl<_$RoomMemberImpl>(this, _$identity);
}

abstract class _RoomMember implements RoomMember {
  const factory _RoomMember({
    required final String fingerprint,
    required final String alias,
    required final String ip,
    required final int port,
    required final String deviceType,
    final MemberStatus status,
  }) = _$RoomMemberImpl;

  @override
  String get fingerprint;
  @override
  String get alias;
  @override
  String get ip;
  @override
  int get port;
  @override
  String get deviceType;
  @override
  MemberStatus get status;

  /// Create a copy of RoomMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RoomMemberImplCopyWith<_$RoomMemberImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
