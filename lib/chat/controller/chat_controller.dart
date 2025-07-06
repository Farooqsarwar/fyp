import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';
import '../models/user_model.dart';
import 'package:path/path.dart' as path_lib;

class ChatController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final users = <UserModel>[].obs;
  final isLoading = true.obs;
  final isSending = false.obs;
  final receiverName = 'Loading...'.obs;
  final senderId = ''.obs;
  final receiverId = ''.obs;
  final TextEditingController messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    _verifyStorageBucket();
  }

  Future<void> _verifyStorageBucket() async {
    try {
      await _supabase.storage.from('chat-images').list();
    } catch (e) {
      _showError('Chat storage not ready. Please contact support.');
    }
  }

  void initializeChat({
    required String receiverId,
    required String receiverName,
    required String senderId,
  }) {
    this.receiverId.value = receiverId;
    this.receiverName.value = receiverName;
    this.senderId.value = senderId;
  }

  Future<void> fetchUsers() async {
    try {
      isLoading.value = true;
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await _supabase
          .from('users')
          .select()
          .neq('id', currentUserId);

      users.assignAll(
          (response as List).map((user) => UserModel.fromJson(user)).toList());
    } catch (e) {
      _showError('Failed to load users');
    } finally {
      isLoading.value = false;
    }
  }

  Stream<List<Message>> getMessages({String? itemId, String? itemType}) {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return Stream.value([]);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((events) {
      return events
          .where((e) {
        // Strictly filter messages between current user and the selected receiver
        final isBetweenCurrentParticipants =
            (e['sender_id'] == currentUserId && e['receiver_id'] == receiverId.value) ||
                (e['sender_id'] == receiverId.value && e['receiver_id'] == currentUserId);

        // Apply item filters if provided
        if (itemId != null && itemType != null) {
          return isBetweenCurrentParticipants &&
              e['item_id'] == itemId &&
              e['item_type'] == itemType;
        }

        return isBetweenCurrentParticipants;
      })
          .map((e) => Message.fromJson(e))
          .toList();
    });
  }  Future<void> onMessageSend({String? itemId, String? itemType}) async {
    final text = messageController.text.trim();
    if (text.isNotEmpty) {
      await sendMessage(
        text,
        'text',
        itemId: itemId,
        itemType: itemType,
      );
    }
  }

  Future<void> sendMessage(
      String content,
      String type, {
        String? imageUrl,
        String? itemId,
        String? itemType,
        bool isSystemMessage = false,
      }) async {
    try {
      if (content.isEmpty && type == 'text' && imageUrl == null) return;
      if (senderId.isEmpty || receiverId.isEmpty) {
        _showError('Please select a recipient first');
        return;
      }

      isSending.value = true;
      await _supabase.from('messages').insert({
        'sender_id': senderId.value,
        'receiver_id': receiverId.value,
        'type': type,
        'content': content,
        'photo_url': imageUrl,
        'item_id': itemId,
        'item_type': itemType,
        'is_system_message': isSystemMessage,
        'created_at': DateTime.now().toIso8601String(),
      });

      messageController.clear();
    } catch (e) {
      _showError('Failed to send message');
      print('Failed to send message$e');
    } finally {
      isSending.value = false;
    }
  }

  Future<void> pickImage(ImageSource source, {String? itemId, String? itemType}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image == null) return;

      isSending.value = true;
      final fileExtension = path_lib.extension(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final file = File(image.path);

      await _supabase.storage
          .from('chat-images')
          .upload(fileName, file);

      final imageUrl = _supabase.storage
          .from('chat-images')
          .getPublicUrl(fileName);

      await sendMessage(
        'Image',
        'image',
        imageUrl: imageUrl,
        itemId: itemId,
        itemType: itemType,
      );
    } catch (e) {
      _showError('Failed to upload image. Please try again.');
      print('Failed to upload image. Please try again.$e');
    } finally {
      isSending.value = false;
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('id', messageId)
          .eq('receiver_id', currentUserId);
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  Future<void> markAllMessagesAsRead({String? itemId, String? itemType}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('receiver_id', currentUserId)
          .eq('is_read', false)
          .eq('item_id', itemId ?? '')
          .eq('item_type', itemType ?? '');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}