import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contact_provider.dart';
import '../widgets/contact_list_item.dart';
import '../widgets/contact_section_header.dart';
import 'add_edit_contact_screen.dart';
import 'profile_screen.dart';
import '../../data/datasources/contact_local_service.dart';
import '../../domain/entities/contact.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      ref.read(searchProvider.notifier).clearSearch();
    } else {
      setState(() => _isSearching = true);
      ref.read(searchProvider.notifier).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('Contacts'),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                setState(() => _isSearching = false);
                ref.read(searchProvider.notifier).clearSearch();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(contactsProvider.notifier).refreshContacts(),
        child: _buildBody(contactsState, searchState),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditContactScreen(),
            ),
          );
          if (result == true) {
            ref.read(contactsProvider.notifier).refreshContacts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(ContactsState contactsState, searchState) {
    if (contactsState.isLoading && contactsState.contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contactsState.error != null && contactsState.contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error loading contacts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                contactsState.error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(contactsProvider.notifier).loadContacts(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  // Open Swagger in browser
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please check Swagger: http://146.59.52.68:11235/swagger'),
                      duration: Duration(seconds: 5),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open Swagger Documentation'),
              ),
            ],
          ),
        ),
      );
    }

    // Show search results if searching
    if (_isSearching) {
      return _buildSearchResults(searchState);
    }

    // Show grouped contacts
    return _buildGroupedContacts(contactsState);
  }

  Widget _buildSearchResults(searchState) {
    if (searchState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.query.isEmpty) {
      return _buildSearchHistory(searchState);
    }

    if (searchState.filteredContacts.isEmpty) {
      return const Center(child: Text('No contacts found'));
    }

    return ListView.builder(
      itemCount: searchState.filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = searchState.filteredContacts[index];
        return ContactListItem(
          contact: contact,
          onTap: () => _navigateToProfile(contact),
          onEdit: () => _navigateToEdit(contact),
          onDelete: () => _deleteContact(contact.id!),
        );
      },
    );
  }

  Widget _buildSearchHistory(searchState) {
    if (searchState.searchHistory.isEmpty) {
      return const Center(child: Text('No search history'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () async {
                  await ContactLocalService.clearSearchHistory();
                  ref.read(searchProvider.notifier).clearSearch();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: searchState.searchHistory.length,
          itemBuilder: (context, index) {
            final query = searchState.searchHistory[index];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(query),
              onTap: () {
                _searchController.text = query;
                _onSearchChanged(query);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildGroupedContacts(ContactsState contactsState) {
    if (contactsState.contacts.isEmpty) {
      return const Center(child: Text('No contacts yet. Add one!'));
    }

    final grouped = contactsState.groupedContacts;
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final letter = sortedKeys[index];
        final contacts = grouped[letter]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContactSectionHeader(letter: letter),
            ...contacts.map((contact) => ContactListItem(
                  contact: contact,
                  onTap: () => _navigateToProfile(contact),
                  onEdit: () => _navigateToEdit(contact),
                  onDelete: () => _deleteContact(contact.id!),
                )),
          ],
        );
      },
    );
  }

  void _navigateToProfile(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(contactId: contact.id!),
      ),
    ).then((_) {
      ref.read(contactsProvider.notifier).refreshContacts();
    });
  }

  void _navigateToEdit(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditContactScreen(contact: contact),
      ),
    ).then((result) {
      if (result == true) {
        ref.read(contactsProvider.notifier).refreshContacts();
      }
    });
  }

  Future<void> _deleteContact(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: const Text('Are you sure you want to delete this contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(contactsProvider.notifier).deleteContact(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact deleted')),
        );
      }
    }
  }
}

