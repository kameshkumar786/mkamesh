class User {
  final String userId;
  final String username;
  final bool isOnline;
  final String profileImage;
  final String statusMessage;
  final String
      profilePicture; // This field holds the URL or path to the user's profile picture

  User({
    required this.userId,
    required this.username,
    this.isOnline = false,
    required this.profileImage,
    required this.statusMessage,
    required this.profilePicture,
  });
}
