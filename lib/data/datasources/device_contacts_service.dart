import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceContactsService {
  static Set<String>? _cachedDevicePhoneNumbers;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Get all device phone numbers (cached)
  Future<Set<String>> getDevicePhoneNumbers() async {
    try {
      final hasPermission = await _requestPermission();
      if (!hasPermission) return {};

      // Use cache if available and not expired
      if (_cachedDevicePhoneNumbers != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedDevicePhoneNumbers!;
      }

      // Fetch contacts from device
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
      );

      // Create set of normalized phone numbers for fast lookup
      final phoneNumbers = <String>{};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          final normalized = _normalizePhone(phone.number);
          if (normalized.isNotEmpty) {
            phoneNumbers.add(normalized);
          }
        }
      }

      // Cache the result
      _cachedDevicePhoneNumbers = phoneNumbers;
      _cacheTime = DateTime.now();

      return phoneNumbers;
    } catch (e) {
      return {};
    }
  }

  /// Check if contact exists in device contacts by phone number
  Future<bool> isContactInDevice(String phoneNumber) async {
    try {
      final devicePhones = await getDevicePhoneNumbers();
      final normalizedPhone = _normalizePhone(phoneNumber);
      return devicePhones.contains(normalizedPhone);
    } catch (e) {
      return false;
    }
  }

  /// Clear cache (call after saving contact to device)
  void clearCache() {
    _cachedDevicePhoneNumbers = null;
    _cacheTime = null;
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

      // Clear cache to force refresh on next check
      clearCache();

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
