import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/contact_provider.dart';
import '../../domain/entities/contact.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/color_utils.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String contactId;
  final Contact? contact;

  const ProfileScreen({
    super.key,
    required this.contactId,
    this.contact,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Contact? _contact;
  Color? _dominantColor;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExtractingColor = false;
  bool _hasImageChanged = false;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _dominantColor = null;
    
    if (widget.contact != null) {
      setState(() {
        _contact = widget.contact;
        _isLoading = false;
        _firstNameController.text = widget.contact!.firstName;
        _lastNameController.text = widget.contact!.lastName;
        _phoneController.text = widget.contact!.phoneNumber;
      });
      
      if (widget.contact!.photoUrl != null && widget.contact!.photoUrl!.isNotEmpty) {
        Future.microtask(() {
          if (mounted && _contact != null) {
            _loadDominantColorFromContact();
          }
        });
      }
    } else {
      _loadContact();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    try {
      final repository = ref.read(contactRepositoryProvider);
      final contact = await repository.getContactById(widget.contactId);

      setState(() {
        _contact = contact;
        _isLoading = false;
        if (contact != null) {
          _firstNameController.text = contact.firstName;
          _lastNameController.text = contact.lastName;
          _phoneController.text = contact.phoneNumber;
        }
      });

      if (contact?.photoUrl != null && contact!.photoUrl!.isNotEmpty) {
        Future.microtask(() {
          if (mounted && _contact != null) {
            _loadDominantColorFromContact();
          }
        });
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

  Future<void> _loadDominantColorFromContact() async {
    if (_contact == null || _isExtractingColor) return;
    if (_contact!.photoUrl == null || _contact!.photoUrl!.isEmpty) return;

    setState(() {
      _isExtractingColor = true;
    });

    try {
      Color? color;
      if (_contact!.photoUrl!.startsWith('/')) {
        color = await ColorUtils.getDominantColor(_contact!.photoUrl!);
      } else {
        color = await ColorUtils.getDominantColorFromNetwork(_contact!.photoUrl!);
      }

      if (mounted) {
        setState(() {
          _dominantColor = color;
          _isExtractingColor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dominantColor = null;
          _isExtractingColor = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);

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
      final imageToUse = compressed ?? file;

      setState(() {
        _selectedImage = imageToUse;
        _hasImageChanged = true;
        _dominantColor = null; // Reset color while extracting
      });

      // Extract dominant color from the selected image
      _extractDominantColor(imageToUse);
    }
  }

  Future<void> _extractDominantColor(File imageFile) async {
    if (!mounted || _isExtractingColor) return;

    setState(() {
      _isExtractingColor = true;
    });

    try {
      final color = await ColorUtils.getDominantColor(imageFile.path);

      if (mounted) {
        setState(() {
          _dominantColor = color;
          _isExtractingColor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dominantColor = null;
          _isExtractingColor = false;
        });
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.85),
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
                  onTap: () {},
                  child: FractionallySizedBox(
                    heightFactor: 0.29,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          _buildPhotoOption(
                            icon: Icons.photo_camera_outlined,
                            label: 'Camera',
                            source: ImageSource.camera,
                          ),
                          const SizedBox(height: 12),
                          _buildPhotoOption(
                            icon: Icons.image_outlined,
                            label: 'Gallery',
                            source: ImageSource.gallery,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppTheme.primaryBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickImage(source);
    }
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black, width: 1.4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.darkGray, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.darkGray,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveContact() async {
    if (_contact == null) return;

    if (!_formKey.currentState!.validate()) return;

    // Save contact

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(contactsProvider.notifier).updateContact(
            id: _contact!.id!,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            imageFile: _hasImageChanged ? _selectedImage : null,
          );

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        Navigator.pop(context, true);
        ref.read(contactsProvider.notifier).refreshContacts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact updated')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteContact() async {
    if (_contact == null) return;

    // Delete contact
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

  Future<void> _saveToDevice() async {
    if (_contact == null) return;

    // Save to device
    try {
      final repository = ref.read(contactRepositoryProvider);
      await repository.saveContactToDevice(_contact!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved to device')),
        );
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

  bool get _hasPhoto =>
      _selectedImage != null || (_contact?.photoUrl?.isNotEmpty ?? false);

  bool get _hasChanges {
    if (_contact == null) return false;
    return _hasImageChanged ||
        _firstNameController.text.trim() != _contact!.firstName ||
        _lastNameController.text.trim() != _contact!.lastName ||
        _phoneController.text.trim() != _contact!.phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_contact == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Center(child: Text('Contact not found')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                const SizedBox(height: 32),

                                Center(
                                  child: Column(
                                    children: [
                                      _buildAvatar(),
                                      const SizedBox(height: 14),
                                      GestureDetector(
                                        onTap: _showPhotoSourceSheet,
                                        child: Text(
                                          _hasPhoto ? 'Change Photo' : 'Add Photo',
                                          style: const TextStyle(
                                            color: AppTheme.primaryBlue,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 36),

                                Column(
                                  children: [
                                    TextFormField(
                                      controller: _firstNameController,
                                      decoration: _inputDecoration('First Name'),
                                      style: const TextStyle(
                                        color: Color(0xFF202020),
                                        fontSize: 16,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter first name';
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _lastNameController,
                                      decoration: _inputDecoration('Last Name'),
                                      style: const TextStyle(
                                        color: Color(0xFF202020),
                                        fontSize: 16,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter last name';
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: _inputDecoration('Phone Number'),
                                      style: const TextStyle(
                                        color: Color(0xFF202020),
                                        fontSize: 16,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter phone number';
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                if (!_contact!.isInDeviceContacts)
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE4E4E6),
                                        width: 1,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _saveToDevice,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.bookmark_border,
                                                color: AppTheme.darkGray,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 10),
                                              const Text(
                                                'Save to My Phone Contact',
                                                style: TextStyle(
                                                  color: AppTheme.darkGray,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          if (_hasChanges || _hasImageChanged)
            TextButton(
              onPressed: _hasChanges && !_isSaving ? _saveContact : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                minimumSize: const Size(64, 40),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                'Done',
                style: TextStyle(
                  color: _hasChanges && !_isSaving
                      ? AppTheme.primaryBlue
                      : AppTheme.lightGray,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 64),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppTheme.darkGray,
            ),
            onSelected: (value) {
              if (value == 'edit') {
              } else if (value == 'delete') {
                _deleteContact();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20, color: AppTheme.darkGray),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final imageProvider = _selectedImage != null
        ? FileImage(_selectedImage!)
        : (_contact?.photoUrl != null && _contact!.photoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(_contact!.photoUrl!) as ImageProvider
                : null);

    final bool hasImage = imageProvider != null;

    if (!hasImage) {
      return Container(
        width: 122,
        height: 122,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.emptyStateIconGray,
        ),
        child: const Icon(Icons.person, size: 60, color: Colors.white),
      );
    }

    if (_dominantColor == null && hasImage) {
      if (_selectedImage != null && !_isExtractingColor) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _dominantColor == null && !_isExtractingColor) {
            _extractDominantColor(_selectedImage!);
          }
        });
      }
      
      return Container(
        width: 122,
        height: 122,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
        ),
      );
    }

    final baseGlowColor = _dominantColor!;
    final hsl = HSLColor.fromColor(baseGlowColor);
    final lighterGlowColor = hsl
        .withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0))
        .toColor();

    return Container(
      width: 122,
      height: 122,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lighterGlowColor.withValues(alpha: 0.25),
        boxShadow: hasImage
            ? [
                BoxShadow(
                  color: lighterGlowColor.withValues(alpha: 0.5),
                  blurRadius: 35,
                  spreadRadius: 10,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: lighterGlowColor.withValues(alpha: 0.3),
                  blurRadius: 25,
                  spreadRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasImage ? Colors.white : AppTheme.emptyStateIconGray,
            border: Border.all(
              color: hasImage ? Colors.white : const Color(0xFFE2E2E5),
              width: hasImage ? 3 : 2,
            ),
            image: hasImage
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: hasImage
              ? null
              : const Icon(Icons.person, size: 60, color: Colors.white),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.lightGray, fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: const Color(0xFFE4E4E6), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: const Color(0xFFE4E4E6), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF202020), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: AppTheme.cardBackground,
    );
  }
}
