import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/contact_provider.dart';
import '../../domain/entities/contact.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String contactId;
  final Contact? contact;
  final bool initialEditMode;

  const ProfileScreen({
    super.key,
    required this.contactId,
    this.contact,
    this.initialEditMode = false,
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
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _dominantColor = null;
    _isEditing = widget.initialEditMode;

    if (widget.contact != null) {
      setState(() {
        _contact = widget.contact;
        _isLoading = false;
        _firstNameController.text = widget.contact!.firstName;
        _lastNameController.text = widget.contact!.lastName;
        _phoneController.text = widget.contact!.phoneNumber;
      });

      if (widget.contact!.photoUrl != null &&
          widget.contact!.photoUrl!.isNotEmpty) {
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
        SnackBarUtils.showError(
          context,
          'Error loading contact: ${e.toString()}',
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
        color = await ColorUtils.getDominantColorFromNetwork(
          _contact!.photoUrl!,
        );
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

      if (!ImageUtils.isValidImage(file.path)) {
        if (mounted) {
          SnackBarUtils.showError(context, 'Please select a PNG or JPG image');
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

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(contactsProvider.notifier)
          .updateContact(
            id: _contact!.id!,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            imageFile: _hasImageChanged ? _selectedImage : null,
          );

      if (mounted) {
        ref.read(contactsProvider.notifier).refreshContacts();
        SnackBarUtils.showSuccess(context, 'User is updated!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        SnackBarUtils.showError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteContact() async {
    if (_contact == null) return;

    final confirmed = await showModalBottomSheet<bool>(
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
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7E7E7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Text(
                            'Delete Contact',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Are you sure you want to delete this contact?',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.black,
                                      width: 1.4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    'No',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    backgroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    'Yes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                              ),
                            ],
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

    if (confirmed == true) {
      try {
        await ref.read(contactsProvider.notifier).deleteContact(_contact!.id!);
        if (mounted) {
          Navigator.pop(context, 'deleted');
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, 'Error: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _saveToDevice() async {
    if (_contact == null) return;

    try {
      final repository = ref.read(contactRepositoryProvider);
      await repository.saveContactToDevice(_contact!);

      if (mounted) {
        setState(() {
          _contact = _contact!.copyWith(isInDeviceContacts: true);
        });
        SnackBarUtils.showSuccess(context, 'User is added to your phone!');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: ${e.toString()}');
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
                                      if (_isEditing)
                                        GestureDetector(
                                          onTap: _showPhotoSourceSheet,
                                          child: Text(
                                            _hasPhoto
                                                ? 'Change Photo'
                                                : 'Add Photo',
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

                                const SizedBox(height: 33),

                                Column(
                                  children: [
                                    TextFormField(
                                      controller: _firstNameController,
                                      decoration: _inputDecoration(
                                        'First Name',
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF202020),
                                        fontSize: 16,
                                      ),
                                      enabled: _isEditing,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter first name';
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _lastNameController,
                                      decoration: _inputDecoration('Last Name'),
                                      style: const TextStyle(
                                        color: Color(0xFF202020),
                                        fontSize: 16,
                                      ),
                                      enabled: _isEditing,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter last name';
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: _inputDecoration(
                                        'Phone Number',
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF202020),
                                        fontSize: 16,
                                      ),
                                      enabled: _isEditing,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter phone number';
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ],
                                ),

                                if (!_isEditing) ...[
                                  const SizedBox(height: 48),

                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: _contact!.isInDeviceContacts
                                            ? const Color(0xFFD1D1D1)
                                            : Colors.black,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _contact!.isInDeviceContacts
                                            ? null
                                            : _saveToDevice,
                                        borderRadius: BorderRadius.circular(28),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.bookmark_border,
                                                color:
                                                    _contact!.isInDeviceContacts
                                                    ? const Color(0xFFD1D1D1)
                                                    : AppTheme.darkGray,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Save to My Phone Contact',
                                                style: TextStyle(
                                                  color:
                                                      _contact!
                                                          .isInDeviceContacts
                                                      ? const Color(0xFFD1D1D1)
                                                      : AppTheme.darkGray,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  if (_contact!.isInDeviceContacts)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF6D6D6D),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: const Text(
                                                'i',
                                                style: TextStyle(
                                                  color: Color(0xFF6D6D6D),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'This contact is already saved your phone.',
                                            style: TextStyle(
                                              color: Color(0xFF6D6D6D),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],

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
    if (_isEditing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _selectedImage = null;
                  _hasImageChanged = false;
                  if (_contact != null) {
                    _firstNameController.text = _contact!.firstName;
                    _lastNameController.text = _contact!.lastName;
                    _phoneController.text = _contact!.phoneNumber;
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                minimumSize: const Size(64, 40),
                alignment: Alignment.centerLeft,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.primaryBlue, fontSize: 17),
              ),
            ),
            Expanded(
              child: const Center(
                child: Text(
                  'Edit Contact',
                  style: TextStyle(
                    color: AppTheme.darkGray,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _hasChanges && !_isSaving ? _saveContact : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                minimumSize: const Size(64, 40),
                alignment: Alignment.centerRight,
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
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          const SizedBox(width: 64),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.darkGray),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 8,
            offset: const Offset(-20, 24),
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
            onSelected: (value) {
              if (value == 'edit') {
                setState(() {
                  _isEditing = true;
                });
              } else if (value == 'delete') {
                _deleteContact();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit',
                      style: TextStyle(
                        color: AppTheme.darkGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppTheme.darkGray,
                        ),
                        const SizedBox(height: 1),
                        Container(
                          width: 16,
                          height: 1,
                          color: AppTheme.darkGray,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1, thickness: 1),
              PopupMenuItem(
                value: 'delete',
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
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
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Center(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 3),
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
