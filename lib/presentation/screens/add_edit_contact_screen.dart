import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../providers/contact_provider.dart';
import '../../domain/entities/contact.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/color_utils.dart';
import '../../core/theme/app_theme.dart';

class AddEditContactScreen extends ConsumerStatefulWidget {
  final Contact? contact;

  const AddEditContactScreen({super.key, this.contact});

  @override
  ConsumerState<AddEditContactScreen> createState() =>
      _AddEditContactScreenState();
}

class _AddEditContactScreenState extends ConsumerState<AddEditContactScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  Color? _dominantColor;
  bool _isExtractingColor = false;
  late AnimationController _fadeController;
  late AnimationController _lottieController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool get _isFormValid {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _firstNameController.text = widget.contact!.firstName;
      _lastNameController.text = widget.contact!.lastName;
      _phoneController.text = widget.contact!.phoneNumber;
      // Load dominant color from existing contact image
      _loadDominantColorFromContact();
    }

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );

    _firstNameController.addListener(_updateFormValidity);
    _lastNameController.addListener(_updateFormValidity);
    _phoneController.addListener(_updateFormValidity);
  }

  void _updateFormValidity() {
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _fadeController.dispose();
    _lottieController.dispose();
    super.dispose();
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

  Future<void> _loadDominantColorFromContact() async {
    if (widget.contact?.photoUrl == null ||
        widget.contact!.photoUrl!.isEmpty ||
        _isExtractingColor) {
      return;
    }

    setState(() {
      _isExtractingColor = true;
    });

    try {
      Color? color;

      if (widget.contact!.photoUrl!.startsWith('http')) {
        color = await ColorUtils.getDominantColorFromNetwork(
          widget.contact!.photoUrl!,
        );
      } else {
        color = await ColorUtils.getDominantColor(widget.contact!.photoUrl!);
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
        await ref
            .read(contactsProvider.notifier)
            .createContact(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              imageFile: _selectedImage,
            );
      } else {
        // Update existing contact
        await ref
            .read(contactsProvider.notifier)
            .updateContact(
              id: widget.contact!.id!,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              imageFile: _selectedImage,
            );
      }

      setState(() {
        _isLoading = false;
      });

      await _showSuccessOverlay();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

                                const SizedBox(height: 36),
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
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter first name';
                                        }
                                        return null;
                                      },
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
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter last name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
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
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 32),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
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
            child: Center(
              child: Text(
                widget.contact == null ? 'New Contact' : 'Edit Contact',
                style: const TextStyle(
                  color: AppTheme.darkGray,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _isFormValid && !_isLoading ? _saveContact : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              minimumSize: const Size(64, 40),
              alignment: Alignment.centerRight,
            ),
            child: Text(
              'Done',
              style: TextStyle(
                color: _isFormValid && !_isLoading
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
                  onTap: () {}, // absorb taps on the sheet itself
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

  Future<void> _showSuccessOverlay() async {
    final rootNav = Navigator.of(context, rootNavigator: true);

    _lottieController.reset();
    _fadeController.reset();
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _lottieController.forward();

    final completer = Completer<void>();
    late AnimationStatusListener statusListener;
    statusListener = (status) {
      if (status == AnimationStatus.completed) {
        _lottieController.removeStatusListener(statusListener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    };
    _lottieController.addStatusListener(statusListener);

    if (_lottieController.status == AnimationStatus.completed) {
      _lottieController.removeStatusListener(statusListener);
      completer.complete();
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'success',
      barrierColor: Colors.white,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Lottie.asset(
                        'Done.json',
                        controller: _lottieController,
                        fit: BoxFit.contain,
                        repeat: false,
                        animate: true,
                        options: LottieOptions(enableMergePaths: true),
                        onLoaded: (composition) {
                          _lottieController.duration = composition.duration;
                          if (_lottieController.status ==
                              AnimationStatus.completed) {
                            _lottieController.reset();
                            _lottieController.forward();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'All Done!',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E), // Dark gray/black
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.contact == null
                            ? 'New contact saved'
                            : 'Contact updated',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('🎉', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await completer.future;
    await Future.delayed(const Duration(milliseconds: 300));
    await _fadeController.reverse();

    if (rootNav.canPop()) {
      rootNav.pop();
    }
  }

  bool get _hasPhoto =>
      _selectedImage != null || (widget.contact?.photoUrl?.isNotEmpty ?? false);

  Widget _buildAvatar() {
    final imageProvider = _selectedImage != null
        ? FileImage(_selectedImage!)
        : (widget.contact?.photoUrl != null &&
                  widget.contact!.photoUrl!.isNotEmpty
              ? NetworkImage(widget.contact!.photoUrl!) as ImageProvider
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
      return Container(
        width: 122,
        height: 122,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.emptyStateIconGray,
        ),
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
