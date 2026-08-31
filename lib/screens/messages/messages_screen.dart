import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/message_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<RiderMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollNew());
  }

  MessageService _svc() {
    final auth = context.read<AuthProvider>();
    final api = ApiClient();
    api.setToken(auth.api.toString().isEmpty ? null : null);
    // Use auth's api which already has token set
    return MessageService(auth.api);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = _svc();
      final list = await svc.getMessages();
      if (mounted) setState(() { _messages = list; _loading = false; });
      _jump();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pollNew() async {
    if (_messages.isEmpty) return;
    try {
      final svc = _svc();
      final after = _messages.isNotEmpty ? _messages.last.id : null;
      final more = await svc.poll(after: after);
      if (more.isNotEmpty && mounted) {
        setState(() => _messages.addAll(more));
        _jump();
      }
    } catch (_) {}
  }

  void _jump() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  Future<void> _send({Uint8List? bytes, String? name}) async {
    final text = _input.text.trim();
    if (text.isEmpty && bytes == null) return;
    setState(() => _sending = true);
    try {
      final svc = _svc();
      final msg = await svc.send(body: text.isEmpty ? '(attachment)' : text, fileBytes: bytes, filename: name);
      _input.clear();
      if (mounted) setState(() => _messages.add(msg));
      _jump();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _send(bytes: bytes, name: file.name);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), centerTitle: true),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('No messages yet. Start a conversation with Logistics.'))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final showDay = i == 0 || _messages[i - 1].dayLabel != m.dayLabel;
                        return Column(children: [
                          if (showDay) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(m.dayLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3AF)))),
                          Align(
                            alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: m.mine ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: m.mine ? AppTheme.primary : const Color(0xFFE6E9EF)),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (m.deleted) const Text('This message was deleted', style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF9AA3AF))),
                                if (!m.deleted) Text(m.body, style: TextStyle(color: m.mine ? Colors.white : const Color(0xFF1B1F24))),
                                if (m.attachments.isNotEmpty) ...m.attachments.map((a) => Padding(padding: const EdgeInsets.only(top: 6), child: Text('📎 ${a.name} (${a.size})', style: TextStyle(fontSize: 12, color: m.mine ? Colors.white70 : AppTheme.primary)))),
                                const SizedBox(height: 4),
                                Text(m.time, style: TextStyle(fontSize: 10, color: m.mine ? Colors.white70 : const Color(0xFF9AA3AF))),
                              ]),
                            ),
                          ),
                        ]);
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE6E9EF)))),
          child: Row(children: [
            IconButton(onPressed: _sending ? null : _pickAttachment, icon: const Icon(Icons.attach_file_outlined)),
            Expanded(child: TextField(controller: _input, decoration: InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), onSubmitted: (_) => _send())),
            const SizedBox(width: 8),
            CircleAvatar(backgroundColor: AppTheme.primary, child: IconButton(icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_outlined, color: Colors.white, size: 18), onPressed: _sending ? null : () => _send())),
          ]),
        ),
      ]),
    );
  }
}
