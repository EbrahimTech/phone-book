import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/contact_api_service.dart';
import '../../data/datasources/contact_local_service.dart';
import '../../data/datasources/device_contacts_service.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';

// Repository Provider
final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepositoryImpl(
    apiService: ContactApiService(),
    deviceContactsService: DeviceContactsService(),
  );
});

// Contacts State
class ContactsState {
  final List<Contact> contacts;
  final bool isLoading;
  final String? error;
  final Map<String, List<Contact>> groupedContacts;

  ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
    Map<String, List<Contact>>? groupedContacts,
  }) : groupedContacts = groupedContacts ?? _groupContacts(contacts);

  static Map<String, List<Contact>> _groupContacts(List<Contact> contacts) {
    final grouped = <String, List<Contact>>{};
    
    // Sort contacts alphabetically
    final sorted = List<Contact>.from(contacts)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    for (var contact in sorted) {
      final firstLetter = contact.firstLetter;
      grouped.putIfAbsent(firstLetter, () => []).add(contact);
    }

    return grouped;
  }

  ContactsState copyWith({
    List<Contact>? contacts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Contacts Notifier
class ContactsNotifier extends StateNotifier<ContactsState> {
  final ContactRepository _repository;

  ContactsNotifier(this._repository) : super(ContactsState()) {
    loadContacts();
  }

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final contacts = await _repository.getAllContacts();
      state = state.copyWith(
        contacts: contacts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refreshContacts() async {
    await loadContacts();
  }

  Future<void> deleteContact(String id) async {
    try {
      await _repository.deleteContact(id);
      await loadContacts(); // Refresh list
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createContact({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    File? imageFile,
  }) async {
    try {
      final contact = Contact(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );
      
      await _repository.createContact(contact, imageFile: imageFile);
      await loadContacts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateContact({
    required String id,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    File? imageFile,
  }) async {
    try {
      final contact = Contact(
        id: id,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );
      
      await _repository.updateContact(contact, imageFile: imageFile);
      await loadContacts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  final repository = ref.watch(contactRepositoryProvider);
  return ContactsNotifier(repository);
});

// Search State
class SearchState {
  final List<Contact> filteredContacts;
  final String query;
  final List<String> searchHistory;
  final bool isSearching;

  SearchState({
    this.filteredContacts = const [],
    this.query = '',
    this.searchHistory = const [],
    this.isSearching = false,
  });

  SearchState copyWith({
    List<Contact>? filteredContacts,
    String? query,
    List<String>? searchHistory,
    bool? isSearching,
  }) {
    return SearchState(
      filteredContacts: filteredContacts ?? this.filteredContacts,
      query: query ?? this.query,
      searchHistory: searchHistory ?? this.searchHistory,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

// Search Notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final ContactRepository _repository;

  SearchNotifier(this._repository) : super(SearchState()) {
    _loadSearchHistory();
  }

  void _loadSearchHistory() async {
    await ContactLocalService.init();
    final history = ContactLocalService.getSearchHistory();
    state = state.copyWith(searchHistory: history);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(
        query: '',
        filteredContacts: [],
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(isSearching: true, query: query);
    
    try {
      final results = await _repository.searchContacts(query);
      await ContactLocalService.addSearchToHistory(query);
      
      state = state.copyWith(
        filteredContacts: results,
        isSearching: false,
        searchHistory: ContactLocalService.getSearchHistory(),
      );
    } catch (e) {
      state = state.copyWith(isSearching: false);
    }
  }

  void clearSearch() {
    state = state.copyWith(
      query: '',
      filteredContacts: [],
      isSearching: false,
    );
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final repository = ref.watch(contactRepositoryProvider);
  return SearchNotifier(repository);
});

