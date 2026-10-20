class AppUser {
  const AppUser({
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
  });

  final String username;
  final String email;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory AppUser.fromMap(Map<dynamic, dynamic> m) => AppUser(
        username: m['username'] as String,
        email: m['email'] as String,
        passwordHash: m['passwordHash'] as String,
        salt: m['salt'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}
