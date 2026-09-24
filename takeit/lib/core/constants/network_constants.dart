/// Default port used by TakeIt protocol for HTTP server and multicast.
const kDefaultPort = 53317;

/// Value of the `protocol` field in TakeIt multicast announcements.
///
/// LocalSend uses the same multicast group and port with a near-identical
/// payload; its `protocol` is always "http" or "https", which is how the two
/// are told apart.
const kProtocolId = 'takeit';
