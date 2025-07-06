import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controller/chat_controller.dart';
import '../controller/user_controller.dart';
import '../models/message.dart';
import '../models/user_model.dart';
import 'full_screen_image.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatController chatController = Get.find();
  final UserController userController = Get.find();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await userController.fetchUserData();
    await chatController.fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Chats",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.yellowAccent),
      ),
      body: Obx(() {
        if (chatController.isLoading.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.yellowAccent,
                ),
                SizedBox(height: 16),
                Text(
                  "Loading users...",
                  style: TextStyle(color: Colors.white),
                )
              ],
            ),
          );
        }
        if (chatController.users.isEmpty) {
          return const Center(
            child: Text(
              "No users available",
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        return ListView.separated(
          itemCount: chatController.users.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            color: Colors.grey,
          ),
          itemBuilder: (context, index) {
            final user = chatController.users[index];
            return UserListItem(user: user);
          },
        );
      }),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Confirm Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.yellowAccent),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(
            color: Colors.yellowAccent,
          ),
        ),
        barrierDismissible: false,
      );

      await Supabase.instance.client.auth.signOut();
      Get.offAll(() => const ChatScreen());
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Logout failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

class UserListItem extends StatelessWidget {
  final UserModel user;

  const UserListItem({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.yellowAccent.shade700,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        user.email,
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: const Icon(
        Icons.chat_bubble_outline,
        color: Colors.yellowAccent,
      ),
      onTap: () => Get.to(
            () => ChatDetailScreen(
          receiverId: user.id,
          receiverName: user.name,
        ),
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? itemId;
  final String? itemType;

  const ChatDetailScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.itemId,
    this.itemType,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatController chatController = Get.find();
  final UserController userController = Get.find();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    chatController.initializeChat(
      receiverId: widget.receiverId,
      receiverName: widget.receiverName,
      senderId: userController.getUserId(),
    );

    if (widget.itemId != null && widget.itemType != null) {
      chatController.markAllMessagesAsRead(
        itemId: widget.itemId,
        itemType: widget.itemType,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.yellowAccent.shade700,
              radius: 16,
              child: Text(
                widget.receiverName.isNotEmpty
                    ? widget.receiverName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.receiverName,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.yellowAccent),
      ),
      body: Column(
        children: [
          Expanded(
            child: _MessageList(
              controller: scrollController,
              itemId: widget.itemId,
              itemType: widget.itemType,
            ),
          ),
          _ChatInput(
            itemId: widget.itemId,
            itemType: widget.itemType,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController controller;
  final String? itemId;
  final String? itemType;

  const _MessageList({
    required this.controller,
    this.itemId,
    this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();

    return StreamBuilder<List<Message>>(
      stream: chatController.getMessages(
        itemId: itemId,
        itemType: itemType,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.yellowAccent,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.yellowAccent.shade700,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Start a conversation!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.hasClients) {
            controller.jumpTo(controller.position.maxScrollExtent);
          }
        });

        return ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final message = snapshot.data![index];
            return MessageWidget(message: message);
          },
        );
      },
    );
  }
}

class MessageWidget extends StatelessWidget {
  final Message message;

  const MessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final isSender = message.senderId == chatController.senderId.value;
    final formattedTime = DateFormat('h:mm a').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSender) ...[
            CircleAvatar(
              backgroundColor: Colors.yellowAccent.shade700,
              radius: 16,
              child: Text(
                chatController.receiverName.value.isNotEmpty
                    ? chatController.receiverName.value[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSender
                    ? Colors.yellowAccent.shade700
                    : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isSystemMessage)
                    Text(
                      'System: ${message.content}',
                      style: TextStyle(
                        color: isSender ? Colors.black : Colors.yellowAccent,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    _buildMessageContent(context, isSender),
                  const SizedBox(height: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSender ? Colors.black54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isSender) {
    if (message.photoUrl != null) {
      return InkWell(
        onTap: () => Get.to(
              () => FullScreenChatImage(photoUrl: message.photoUrl!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.photoUrl!,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade700,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.yellowAccent,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade700,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image failed to load',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
    return Text(
      message.content,
      style: TextStyle(
        color: isSender ? Colors.black : Colors.white,
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final String? itemId;
  final String? itemType;

  const _ChatInput({this.itemId, this.itemType});

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          PopupMenuButton<ImageSource>(
            icon: const Icon(
              Icons.camera_alt,
              color: Colors.yellowAccent,
            ),
            color: Colors.grey.shade800,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ImageSource.gallery,
                child: Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: ImageSource.camera,
                child: Text(
                  'Take a photo',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            onSelected: (source) => chatController.pickImage(
              source,
              itemId: itemId,
              itemType: itemType,
            ),
          ),
          Expanded(
            child: TextField(
              controller: chatController.messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade800,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => chatController.isSending.value
              ? Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            child: const CircularProgressIndicator(
              color: Colors.yellowAccent,
            ),
          )
              : Material(
            color: Colors.yellowAccent.shade700,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => chatController.onMessageSend(
                itemId: itemId,
                itemType: itemType,
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}