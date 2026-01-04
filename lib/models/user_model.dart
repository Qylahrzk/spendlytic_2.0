class UserModel {
  final String name;
  final String email;
  final String defaultCurrency;
  final String sorting;
  final String summary;
  final String? profilePicturePath;

  UserModel({
    required this.name,
    required this.email,
    required this.defaultCurrency,
    required this.sorting,
    required this.summary,
    this.profilePicturePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'defaultCurrency': defaultCurrency,
      'sorting': sorting,
      'summary': summary,
      'profilePicturePath': profilePicturePath,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      defaultCurrency: map['defaultCurrency'] ?? '',
      sorting: map['sorting'] ?? '',
      summary: map['summary'] ?? '',
      profilePicturePath: map['profilePicturePath'],
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? defaultCurrency,
    String? sorting,
    String? summary,
    String? profilePicturePath,
  }) {
    return UserModel(
      name: name ?? this.name,
      email: email ?? this.email,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      sorting: sorting ?? this.sorting,
      summary: summary ?? this.summary,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
    );
  }
}
