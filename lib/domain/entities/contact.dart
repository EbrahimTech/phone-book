class Contact {
  final String? id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? photoUrl;
  final bool isInDeviceContacts;

  Contact({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.photoUrl,
    this.isInDeviceContacts = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get firstLetter {
    if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    return '#';
  }

  Contact copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? photoUrl,
    bool? isInDeviceContacts,
  }) {
    return Contact(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isInDeviceContacts: isInDeviceContacts ?? this.isInDeviceContacts,
    );
  }
}

