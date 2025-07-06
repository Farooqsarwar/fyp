import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../controller/chat_controller.dart';
import '../services/notification_service.dart';

class UserController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  var currentUser = UserModel().obs;
  var user = Rx<User?>(null);

  Future<void> fetchUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();
      currentUser.value = UserModel.fromJson(data);

      // Fixed: Get user ID from current user and pass to NotificationService
      await Get.find<NotificationService>().storePlayerId(user.id);
    }
  }

  String getUserId() {
    return _supabase.auth.currentUser?.id ?? '';
  }
}