import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceContactsService {
  /// Check if contact exists in device contacts by phone number
  Future<bool> isContactInDevice(String phoneNumber) async {
    try {
      final hasPermission = await _requestPermission();
      if (!hasPermission) return false;

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
      );
      final normalizedPhone = _normalizePhone(phoneNumber);

      for (var contact in contacts) {
        for (var phone in contact.phones) {
          if (_normalizePhone(phone.number) == normalizedPhone) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Save contact to device
  Future<bool> saveContactToDevice({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    try {
      final hasPermission = await _requestPermission();
      if (!hasPermission) return false;

      final contact = Contact()
        ..name.first = firstName
        ..name.last = lastName
        ..phones = [Phone(phoneNumber)];

      await contact.insert();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Request contacts permission
  Future<bool> _requestPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) return true;

    if (status.isDenied) {
      final result = await Permission.contacts.request();
      return result.isGranted;
    }

    return false;
  }

  /// Normalize phone number for comparison
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }
}

