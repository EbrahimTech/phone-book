import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contact_provider.dart';
import '../widgets/contact_list_item.dart';
import 'add_edit_contact_screen.dart';
import 'profile_screen.dart';
import '../../data/datasources/contact_local_service.dart';
import '../../domain/entities/contact.dart';
import '../../core/theme/app_theme.dart';

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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        title: Align(
          alignment: Alignment.centerLeft,
          child: const Text(
            'Contacts',
            style: TextStyle(
              color: AppTheme.darkGray,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        actions: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _openAddContactSheet,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 25),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(contactsProvider.notifier).refreshContacts(),
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),

              // Body Content
              Expanded(child: _buildBody(contactsState, searchState)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddContactSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {}, // absorb taps on the sheet itself
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: FractionallySizedBox(
                      heightFactor: 0.94,
                      child: const AddEditContactScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == true && mounted) {
      ref.read(contactsProvider.notifier).refreshContacts();
    }
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading contacts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                contactsState.error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(contactsProvider.notifier).loadContacts(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  // Open Swagger in browser
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please check Swagger: http://146.59.52.68:11235/swagger',
                      ),
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: searchState.filteredContacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildContactResultCard(searchState.filteredContacts[index]),
    );
  }

  Widget _buildSearchHistory(searchState) {
    if (searchState.searchHistory.isEmpty) {
      return const Center(child: Text('No search history'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Searches',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
              Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE8E8E8).withOpacity(0.5),
              ),
              ...List.generate(searchState.searchHistory.length, (index) {
                final query = searchState.searchHistory[index];
                final isLast = index == searchState.searchHistory.length - 1;

                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.history,
                        color: AppTheme.lightGray,
                      ),
                      title: Text(
                        query,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      onTap: () {
                        _searchController.text = query;
                        _onSearchChanged(query);
                      },
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 56,
                        color: Color(0xFFE8E8E8).withOpacity(0.5),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedContacts(ContactsState contactsState) {
    if (contactsState.contacts.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = contactsState.groupedContacts;
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: sortedKeys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final letter = sortedKeys[index];
        final contacts = grouped[letter]!;

        return _buildContactGroupCard(letter, contacts);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact deleted')));
      }
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name',
          hintStyle: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(Icons.search, color: AppTheme.lightGray),
          filled: true,
          fillColor: AppTheme.cardBackground,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppTheme.lightGray.withOpacity(0.25),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.primaryBlue,
              width: 1.2,
            ),
          ),
        ),
        style: const TextStyle(color: AppTheme.darkGray, fontSize: 16),
        onChanged: (value) {
          if (value.isNotEmpty) {
            setState(() => _isSearching = true);
            _onSearchChanged(value);
          } else {
            setState(() => _isSearching = false);
            ref.read(searchProvider.notifier).clearSearch();
          }
        },
      ),
    );
  }

  Widget _buildContactGroupCard(String letter, List<Contact> contacts) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB0B0B0),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE8E8E8).withOpacity(0.5),
          ),
          ...contacts.asMap().entries.map((entry) {
            final contact = entry.value;
            final isLast = entry.key == contacts.length - 1;

            return Column(
              children: [
                _buildContactTile(contact),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 72,
                    endIndent: 16,
                    color: Color(0xFFE8E8E8).withOpacity(0.5),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContactResultCard(Contact contact) {
    return Container(
      decoration: _cardDecoration(),
      child: _buildContactTile(contact),
    );
  }

  Widget _buildContactTile(Contact contact) {
    return Theme(
      data: Theme.of(context).copyWith(
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
      ),
      child: ContactListItem(
        contact: contact,
        onTap: () => _navigateToProfile(contact),
        onEdit: () => _navigateToEdit(contact),
        onDelete: () => _deleteContact(contact.id!),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty State Icon
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: AppTheme.emptyStateIconGray,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 58,
                color: Color(0xFFB9B9BE),
              ),
            ),
            const SizedBox(height: 24),

            // "No Contacts" Title
            const Text(
              'No Contacts',
              style: TextStyle(
                color: AppTheme.darkGray,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            const Text(
              'Contacts you\'ve added will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4A4A4A), fontSize: 15),
            ),
            const SizedBox(height: 22),

            // Create New Contact Link
            GestureDetector(
              onTap: _openAddContactSheet,
              child: const Text(
                'Create New Contact',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
