import 'dart:typed_data';

import '../core/network/api_client.dart';

class RiderMessage {
  const RiderMessage({
    required this.id,
    required this.mine,
    required this.senderType,
    required this.body,
    required this.createdAt,
    required this.time,
    required this.dayLabel,
    this.isRead = false,
    this.deleted = false,
    this.attachments = const [],
  });
  final int id;
  final bool mine;
  final String senderType;
  final String body;
  final String createdAt;
  final String time;
  final String dayLabel;
  final bool isRead;
  final bool deleted;
  final List<MessageAttachment> attachments;
  factory RiderMessage.fromJson(Map<String, dynamic> j) => RiderMessage(
        id: (j['id'] as num?)?.toInt() ?? 0,
        mine: j['mine'] as bool? ?? false,
        senderType: j['sender_type'] as String? ?? 'rider',
        body: j['body'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
        time: j['time'] as String? ?? '',
        dayLabel: j['dayLabel'] as String? ?? '',
        isRead: j['is_read'] as bool? ?? false,
        deleted: j['deleted'] as bool? ?? false,
        attachments: (j['attachments'] as List? ?? []).whereType<Map<String, dynamic>>().map(MessageAttachment.fromJson).toList(),
      );
}

class MessageAttachment {
  const MessageAttachment({required this.id, required this.name, required this.size, required this.url, this.isImage = false});
  final int id;
  final String name;
  final String size;
  final String url;
  final bool isImage;
  factory MessageAttachment.fromJson(Map<String, dynamic> j) => MessageAttachment(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        size: j['size'] as String? ?? '',
        url: j['url'] as String? ?? '',
        isImage: j['is_image'] as bool? ?? false,
      );
}

class MessageService {
  MessageService(this._api);
  final ApiClient _api;

  Future<List<RiderMessage>> getMessages() async {
    final data = await _api.get('/rider/messages');
    final list = data['messages'] as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(RiderMessage.fromJson).toList();
  }

  Future<List<RiderMessage>> poll({int? after}) async {
    final data = await _api.get('/rider/messages/poll', query: after != null ? {'after': after.toString()} : null);
    final list = data['messages'] as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(RiderMessage.fromJson).toList();
  }

  Future<RiderMessage> send({required String body, Uint8List? fileBytes, String? filename}) async {
    if (fileBytes != null && filename != null) {
      final data = await _api.postMultipart('/rider/messages', fileField: 'attachment', fileBytes: fileBytes, filename: filename, fields: {'body': body});
      return RiderMessage.fromJson(Map<String, dynamic>.from(data['data'] as Map));
    }
    final data = await _api.post('/rider/messages', body: {'body': body});
    return RiderMessage.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }
}
