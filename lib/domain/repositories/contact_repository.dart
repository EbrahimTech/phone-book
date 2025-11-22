import 'dart:io';
import '../entities/contact.dart';

abstract class ContactRepository {
  Future<List<Contact>> getAllContacts();
  Future<Contact?> getContactById(String id);
  Future<Contact> createContact(Contact contact, {File? imageFile});
  Future<Contact> updateContact(Contact contact, {File? imageFile});
  Future<void> deleteContact(String id);
  Future<List<Contact>> searchContacts(String query);
  Future<bool> isContactInDevice(String phoneNumber);
  Future<void> saveContactToDevice(Contact contact);
}

