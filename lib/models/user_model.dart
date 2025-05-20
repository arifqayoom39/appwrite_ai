class UserModel {
  final String id;
  final String name;
  final String email;
  final String? occupation;
  final int? age;
  final String createdAt;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.occupation,
    this.age,
    required this.createdAt,
    this.photoUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['userId'] ?? map['\$id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      occupation: map['occupation'],
      age: map['age'] != null ? int.tryParse(map['age'].toString()) : null,
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      photoUrl: map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': id,
      'name': name,
      'email': email,
      'occupation': occupation,
      'age': age,
      'createdAt': createdAt,
      'photoUrl': photoUrl,
    };
  }
}
