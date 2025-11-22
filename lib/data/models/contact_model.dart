import '../../domain/entities/contact.dart';

class ContactModel extends Contact {
  ContactModel({
    super.id,
    required super.firstName,
    required super.lastName,
    required super.phoneNumber,
    super.photoUrl,
    super.isInDeviceContacts,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id']?.toString(),
      firstName: json['firstName'] ?? json['first_name'] ?? '',
      lastName: json['lastName'] ?? json['last_name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      photoUrl: json['profileImageUrl'] ?? 
                json['photoUrl'] ?? 
                json['photo_url'] ?? 
                json['imageUrl'],
      isInDeviceContacts: json['isInDeviceContacts'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }

  ContactModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? photoUrl,
    bool? isInDeviceContacts,
  }) {
    return ContactModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isInDeviceContacts: isInDeviceContacts ?? this.isInDeviceContacts,
    );
  }
}

