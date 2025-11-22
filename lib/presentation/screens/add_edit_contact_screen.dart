import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../providers/contact_provider.dart';
import '../widgets/responsive_wrapper.dart';
import '../../domain/entities/contact.dart';
import '../../core/utils/image_utils.dart';

class AddEditContactScreen extends ConsumerStatefulWidget {
  final Contact? contact;

  const AddEditContactScreen({super.key, this.contact});

  @override
  ConsumerState<AddEditContactScreen> createState() => _AddEditContactScreenState();
}

class _AddEditContactScreenState extends ConsumerState<AddEditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _firstNameController.text = widget.contact!.firstName;
      _lastNameController.text = widget.contact!.lastName;
      _phoneController.text = widget.contact!.phoneNumber;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      
      // Validate image
      if (!ImageUtils.isValidImage(file.path)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a PNG or JPG image')),
          );
        }
        return;
      }

      // Compress image
      final compressed = await ImageUtils.compressImage(file);
      setState(() {
        _selectedImage = compressed ?? file;
      });
    }
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.contact == null) {
        // Create new contact
        await ref.read(contactsProvider.notifier).createContact(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              imageFile: _selectedImage,
            );
      } else {
        // Update existing contact
        await ref.read(contactsProvider.notifier).updateContact(
              id: widget.contact!.id!,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              imageFile: _selectedImage,
            );
      }

      // Show success animation
      setState(() {
        _isLoading = false;
        _showSuccessAnimation = true;
      });

      // Wait for animation to complete
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccessAnimation) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Lottie.asset(
            'Done.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact == null ? 'Add Contact' : 'Edit Contact'),
      ),
      body: ResponsiveWrapper(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Picture
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (widget.contact?.photoUrl != null &&
                                    widget.contact!.photoUrl!.isNotEmpty
                                ? NetworkImage(widget.contact!.photoUrl!)
                                : null) as ImageProvider?,
                        child: _selectedImage == null &&
                                (widget.contact?.photoUrl == null ||
                                    widget.contact!.photoUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 20),
                            color: Colors.white,
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // First Name
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Save Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveContact,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.contact == null ? 'Add Contact' : 'Update Contact'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

