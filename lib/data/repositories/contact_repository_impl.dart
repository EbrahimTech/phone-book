import 'dart:io';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/contact_api_service.dart';
import '../datasources/contact_local_service.dart';
import '../datasources/device_contacts_service.dart';
import '../models/contact_model.dart';
import '../../core/utils/string_utils.dart';

class ContactRepositoryImpl implements ContactRepository {
  final ContactApiService _apiService;
  final DeviceContactsService _deviceContactsService;

  ContactRepositoryImpl({
    required ContactApiService apiService,
    required DeviceContactsService deviceContactsService,
  })  : _apiService = apiService,
        _deviceContactsService = deviceContactsService;

  @override
  Future<List<Contact>> getAllContacts() async {
    try {
      // Try to get from API first
      final contacts = await _apiService.getAllContacts();
      
      // Update device contacts status
      final contactsWithDeviceStatus = await Future.wait(
        contacts.map((contact) async {
          final isInDevice = await _deviceContactsService.isContactInDevice(
            contact.phoneNumber,
          );
          return contact.copyWith(isInDeviceContacts: isInDevice);
        }),
      );

      // Cache contacts locally
      await ContactLocalService.cacheContacts(
        contactsWithDeviceStatus.map((c) => ContactModel(
          id: c.id,
          firstName: c.firstName,
          lastName: c.lastName,
          phoneNumber: c.phoneNumber,
          photoUrl: c.photoUrl,
          isInDeviceContacts: c.isInDeviceContacts,
        )).toList(),
      );

      return contactsWithDeviceStatus;
    } catch (e) {
      // If API fails, try to get from cache
      final cached = ContactLocalService.getCachedContacts();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<Contact?> getContactById(String id) async {
    try {
      final contact = await _apiService.getContactById(id);
      final isInDevice = await _deviceContactsService.isContactInDevice(
        contact.phoneNumber,
      );
      return contact.copyWith(isInDeviceContacts: isInDevice);
    } catch (e) {
      // Try cache
      final cached = ContactLocalService.getCachedContacts();
      final found = cached.firstWhere(
        (c) => c.id == id,
        orElse: () => throw Exception('Contact not found'),
      );
      // Check device contacts status even for cached contacts
      final isInDevice = await _deviceContactsService.isContactInDevice(
        found.phoneNumber,
      );
      return found.copyWith(isInDeviceContacts: isInDevice);
    }
  }

  @override
  Future<Contact> createContact(Contact contact, {File? imageFile}) async {
    final contactModel = ContactModel(
      firstName: contact.firstName,
      lastName: contact.lastName,
      phoneNumber: contact.phoneNumber,
      photoUrl: contact.photoUrl,
    );
    
    final created = await _apiService.createContact(contactModel, imageFile: imageFile);
    
    // Refresh cache
    await getAllContacts();
    
    return created;
  }

  @override
  Future<Contact> updateContact(Contact contact, {File? imageFile}) async {
    final contactModel = ContactModel(
      id: contact.id,
      firstName: contact.firstName,
      lastName: contact.lastName,
      phoneNumber: contact.phoneNumber,
      photoUrl: contact.photoUrl,
    );
    
    final updated = await _apiService.updateContact(contactModel, imageFile: imageFile);
    
    // Refresh cache
    await getAllContacts();
    
    return updated;
  }

  @override
  Future<void> deleteContact(String id) async {
    await _apiService.deleteContact(id);
    
    // Refresh cache
    await getAllContacts();
  }

  @override
  Future<List<Contact>> searchContacts(String query) async {
    final allContacts = await getAllContacts();
    if (query.trim().isEmpty) return allContacts;

    final normalizedQuery = StringUtils.normalizeForSearch(query);
    
    return allContacts.where((contact) {
      final fullName = contact.fullName;
      return StringUtils.matchesSearch(fullName, normalizedQuery);
    }).toList();
  }

  @override
  Future<bool> isContactInDevice(String phoneNumber) async {
    return await _deviceContactsService.isContactInDevice(phoneNumber);
  }

  @override
  Future<void> saveContactToDevice(Contact contact) async {
    await _deviceContactsService.saveContactToDevice(
      firstName: contact.firstName,
      lastName: contact.lastName,
      phoneNumber: contact.phoneNumber,
    );
  }
}

