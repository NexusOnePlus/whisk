import 'dart:convert';

class InviteCodec {
  static String encode({
    required String ticket,
    required String hostName,
    String? sessionId,
  }) {
    final payload = {
      'v': 1,
      't': ticket,
      'h': hostName,
      's': ?sessionId,
    };
    return 'whisk:${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
  }

  static InvitePayload? decode(String raw) {
    try {
      final trimmed = raw.trim();
      final prefix = 'whisk:';
      if (!trimmed.startsWith(prefix)) {
        return InvitePayload(ticket: trimmed, hostName: '');
      }
      final encoded = trimmed.substring(prefix.length);
      final json = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      return InvitePayload(
        ticket: json['t'] as String? ?? '',
        hostName: json['h'] as String? ?? '',
        sessionId: json['s'] as String?,
      );
    } catch (_) {
      return InvitePayload(ticket: raw.trim(), hostName: '');
    }
  }
}

class InvitePayload {
  const InvitePayload({
    required this.ticket,
    required this.hostName,
    this.sessionId,
  });

  final String ticket;
  final String hostName;
  final String? sessionId;
}
