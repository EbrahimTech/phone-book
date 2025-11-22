import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/contact_model.dart';

class ContactLocalService {
  static Box<Map>? _contactsBox;
  static Box<List<String>>? _searchHistoryBox;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    
    await Hive.initFlutter();
    
    _contactsBox = await Hive.openBox<Map>(AppConstants.contactsBoxName);
    _searchHistoryBox = await Hive.openBox<List<String>>(AppConstants.searchHistoryBoxName);
    
    _initialized = true;
  }

  /// Cache contacts locally
  static Future<void> cacheContacts(List<ContactModel> contacts) async {
    if (!_initialized) await init();
    if (_contactsBox == null) return;
    
    await _contactsBox!.clear();
    for (var contact in contacts) {
      if (contact.id != null) {
        await _contactsBox!.put(contact.id!, contact.toJson());
      }
    }
  }

  /// Get cached contacts
  static List<ContactModel> getCachedContacts() {
    if (_contactsBox == null) return [];
    return _contactsBox!.values
        .map((json) => ContactModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Add search to history
  static Future<void> addSearchToHistory(String query) async {
    if (!_initialized) await init();
    if (_searchHistoryBox == null) return;
    
    if (query.trim().isEmpty) return;
    
    final history = _searchHistoryBox!.get('history', defaultValue: <String>[]) ?? [];
    
    // Remove if already exists
    history.remove(query.trim());
    
    // Add to beginning
    history.insert(0, query.trim());
    
    // Limit history size
    if (history.length > AppConstants.maxSearchHistoryItems) {
      history.removeRange(AppConstants.maxSearchHistoryItems, history.length);
    }
    
    await _searchHistoryBox!.put('history', history);
  }

  /// Get search history
  static List<String> getSearchHistory() {
    if (_searchHistoryBox == null) return [];
    return _searchHistoryBox!.get('history', defaultValue: <String>[]) ?? [];
  }

  /// Clear search history
  static Future<void> clearSearchHistory() async {
    if (!_initialized) await init();
    if (_searchHistoryBox == null) return;
    await _searchHistoryBox!.delete('history');
  }
}

