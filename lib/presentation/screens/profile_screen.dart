import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/contact_provider.dart';
import '../../domain/entities/contact.dart';
import '../../core/utils/color_utils.dart';
import 'add_edit_contact_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String contactId;

  const ProfileScreen({super.key, required this.contactId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Contact? _contact;
  Color? _dominantColor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    try {
      final repository = ref.read(contactRepositoryProvider);
      final contact = await repository.getContactById(widget.contactId);
      
      setState(() {
        _contact = contact;
        _isLoading = false;
      });

      // Extract dominant color from image if it's a local file
      // For network images, we'll use a simpler approach
      if (contact?.photoUrl != null && contact!.photoUrl!.isNotEmpty) {
        // Check if it's a local file path
        if (contact.photoUrl!.startsWith('/')) {
          try {
            _dominantColor = await ColorUtils.getDominantColor(contact.photoUrl!);
            setState(() {});
          } catch (e) {
            // Use default if extraction fails
            _dominantColor = Colors.grey;
            setState(() {});
          }
        } else {
          // For network images, use a default color
          _dominantColor = Colors.blue;
          setState(() {});
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contact: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveToDevice() async {
    if (_contact == null) return;

    try {
      final repository = ref.read(contactRepositoryProvider);
      await repository.saveContactToDevice(_contact!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved to device')),
        );
        // Refresh contact to update isInDeviceContacts status
        await _loadContact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteContact() async {
    if (_contact == null) return;

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
      try {
        await ref.read(contactsProvider.notifier).deleteContact(_contact!.id!);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact')),
        body: const Center(child: Text('Contact not found')),
      );
    }

    final shadowColor = _dominantColor ?? Colors.grey;
    final shadow = ColorUtils.getShadowColor(shadowColor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditContactScreen(contact: _contact),
                ),
              );
              if (result == true) {
                await _loadContact();
                ref.read(contactsProvider.notifier).refreshContacts();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteContact,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Picture with Shadow
            Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: shadow,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 80,
                backgroundImage: _contact!.photoUrl != null &&
                        _contact!.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(_contact!.photoUrl!)
                    : null,
                child: _contact!.photoUrl == null ||
                        _contact!.photoUrl!.isEmpty
                    ? Text(
                        _contact!.firstLetter,
                        style: const TextStyle(fontSize: 60),
                      )
                    : null,
              ),
            ),

            // Contact Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    _contact!.fullName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _contact!.phoneNumber,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  if (_contact!.isInDeviceContacts) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_android, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Saved in device',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Save to Device Button
            if (!_contact!.isInDeviceContacts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton.icon(
                  onPressed: _saveToDevice,
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Rehbere kaydet'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

