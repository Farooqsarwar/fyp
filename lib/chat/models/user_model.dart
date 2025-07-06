class UserModel {
  String id;
  String name;
  String email;

  UserModel({this.id = '', this.name = 'Unknown', this.email = ''});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString() ?? '',
    );
  }
}