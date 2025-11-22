# 📖 شرح تفصيلي لكل الميزات - Phone Book Flutter Application

هذا الملف يشرح **كل ميزة** في التطبيق بشكل مفصل جداً مع أمثلة من الكود الفعلي.

---

## 📋 جدول المحتويات

1. [CRUD Operations (Create, Read, Update, Delete)](#1-crud-operations)
2. [Image Upload - خطوات رفع الصورة](#2-image-upload)
3. [Lottie Animation](#3-lottie-animation)
4. [Alphabetical Grouping - التجميع الأبجدي](#4-alphabetical-grouping)
5. [Swipe Actions](#5-swipe-actions)
6. [Search with History - البحث مع التاريخ](#6-search-with-history)
7. [SharedPreferences vs Hive - الفرق والاستخدام](#7-sharedpreferences-vs-hive)
8. [Dominant Color Extraction](#8-dominant-color-extraction)
9. [Device Contacts Integration](#9-device-contacts-integration)
10. [Local Caching with Hive](#10-local-caching-with-hive)

---

## 1. CRUD Operations

### ما هي CRUD؟

**CRUD** هي اختصار لـ:
- **C**reate: إنشاء
- **R**ead: قراءة
- **U**pdate: تحديث
- **D**elete: حذف

### كيف تم تنفيذ CRUD في التطبيق؟

#### 1.1 CREATE (إنشاء جهة اتصال)

**الملف**: `lib/data/datasources/contact_api_service.dart`

```dart
Future<ContactModel> createContact(
  ContactModel contact, {
  File? imageFile,
}) async {
  try {
    // الخطوة 1: إذا كانت هناك صورة، ارفعها أولاً
    String? photoUrl = contact.photoUrl;
    if (imageFile != null) {
      photoUrl = await _uploadImage(imageFile);
      print('✅ Image uploaded, URL: $photoUrl');
    }

    // الخطوة 2: إعداد بيانات جهة الاتصال
    final contactData = {
      'firstName': contact.firstName,
      'lastName': contact.lastName,
      'phoneNumber': contact.phoneNumber,
      if (photoUrl != null) 'profileImageUrl': photoUrl,  // مهم: profileImageUrl وليس photoUrl
    };

    print('📤 Creating contact with data: $contactData');

    // الخطوة 3: إرسال POST request
    final response = await _dio.post(
      ApiConstants.createContact,  // '/api/User'
      data: contactData,
    );

    // الخطوة 4: التحقق من النجاح
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('📦 Create response data: ${response.data}');
      final data = response.data;

      // الخطوة 5: Parse Response
      // البنية المتوقعة: {success: true, data: {...}}
      if (data is Map) {
        if (data.containsKey('data') && data['data'] is Map) {
          final dataMap = data['data'] as Map<String, dynamic>;
          // البيانات مباشرة في data، وليس في data.user
          if (dataMap.containsKey('firstName') || dataMap.containsKey('id')) {
            print('✅ Found user data directly in data object');
            return ContactModel.fromJson(dataMap);
          }
        }
      }
      
      return ContactModel.fromJson(response.data);
    }
    
    throw Exception('Failed to create contact: ${response.statusCode}');
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
```

**الملف**: `lib/presentation/providers/contact_provider.dart`

```dart
Future<void> createContact({
  required String firstName,
  required String lastName,
  required String phoneNumber,
  File? imageFile,
}) async {
  try {
    // إنشاء Contact entity
    final contact = Contact(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
    
    // استدعاء Repository
    await _repository.createContact(contact, imageFile: imageFile);
    
    // تحديث القائمة
    await loadContacts();
  } catch (e) {
    state = state.copyWith(error: e.toString());
    rethrow;
  }
}
```

**Flow كامل**:
```
1. المستخدم يضغط "Add Contact"
   ↓
2. AddEditContactScreen._saveContact()
   ↓
3. ContactsNotifier.createContact()
   ↓
4. ContactRepository.createContact()
   ↓
5. ContactApiService.createContact()
   ├─ إذا كانت هناك صورة: _uploadImage()
   └─ POST /api/User مع profileImageUrl
   ↓
6. Parse Response → ContactModel
   ↓
7. حفظ في Cache (Hive)
   ↓
8. تحديث State → UI يتحدث تلقائياً
```

---

#### 1.2 READ (قراءة جهات الاتصال)

**الملف**: `lib/data/datasources/contact_api_service.dart`

```dart
Future<List<ContactModel>> getAllContacts() async {
  try {
    print('🔍 Fetching all contacts...');
    
    // إرسال GET request
    final response = await _dio.get(ApiConstants.getAllContacts);  // '/api/User/GetAll'
    
    print('📦 Response data type: ${response.data.runtimeType}');
    print('📦 Response data: ${response.data}');
    
    final data = response.data;
    
    // Parse Response
    // البنية المتوقعة: {success: true, data: {users: [...]}}
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map) {
        final dataMap = data['data'] as Map<String, dynamic>;
        
        // البيانات في data.users
        if (dataMap.containsKey('users') && dataMap['users'] is List) {
          final usersList = dataMap['users'] as List;
          print('✅ Found users array in data.users with ${usersList.length} items');
          
          // تحويل كل JSON object إلى ContactModel
          return usersList
              .map((json) => ContactModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
    }
    
    throw Exception('Invalid response format');
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
```

**الملف**: `lib/data/repositories/contact_repository_impl.dart`

```dart
@override
Future<List<Contact>> getAllContacts() async {
  try {
    // الخطوة 1: جلب من API
    final contacts = await _apiService.getAllContacts();
    
    // الخطوة 2: فحص إذا كانت موجودة في device contacts
    final contactsWithDeviceStatus = await Future.wait(
      contacts.map((contact) async {
        final isInDevice = await _deviceContactsService.isContactInDevice(
          contact.phoneNumber,
        );
        return contact.copyWith(isInDeviceContacts: isInDevice);
      }),
    );

    // الخطوة 3: حفظ في Cache
    await ContactLocalService.cacheContacts(
      contactsWithDeviceStatus.map((c) => ContactModel(
        id: c.id,
        firstName: c.firstName,
        lastName: c.lastName,
        phoneNumber: c.phoneNumber,
        photoUrl: c.photoUrl,
        isInDeviceContacts: c.isInDeviceContacts,
      )).toList(),
    );

    return contactsWithDeviceStatus;
  } catch (e) {
    // إذا فشل API، جلب من Cache
    print('⚠️ API failed, using cache: $e');
    final cached = ContactLocalService.getCachedContacts();
    if (cached.isNotEmpty) {
      return cached;
    }
    rethrow;
  }
}
```

---

#### 1.3 UPDATE (تحديث جهة اتصال)

**الملف**: `lib/data/datasources/contact_api_service.dart`

```dart
Future<ContactModel> updateContact(
  ContactModel contact, {
  File? imageFile,
}) async {
  try {
    if (contact.id == null) {
      throw Exception('Contact ID is required for update');
    }

    // الخطوة 1: إذا كانت هناك صورة جديدة، ارفعها
    String? photoUrl = contact.photoUrl;
    if (imageFile != null) {
      photoUrl = await _uploadImage(imageFile);
    }

    // الخطوة 2: إعداد بيانات التحديث
    final updateData = {
      'firstName': contact.firstName,
      'lastName': contact.lastName,
      'phoneNumber': contact.phoneNumber,
      if (photoUrl != null) 'profileImageUrl': photoUrl,
    };

    // الخطوة 3: إرسال PUT request
    final response = await _dio.put(
      '${ApiConstants.updateContact}/${contact.id}',  // '/api/User/{id}'
      data: updateData,
    );

    // الخطوة 4: Parse Response
    if (response.statusCode == 200) {
      final data = response.data;
      print('📦 Update response: $data');
      
      if (data is Map) {
        if (data.containsKey('data') && data['data'] is Map) {
          final dataMap = data['data'] as Map<String, dynamic>;
          if (dataMap.containsKey('firstName') || dataMap.containsKey('id')) {
            return ContactModel.fromJson(dataMap);
          }
        }
      }
      
      return ContactModel.fromJson(response.data);
    }
    
    throw Exception('Failed to update contact: ${response.statusCode}');
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
```

---

#### 1.4 DELETE (حذف جهة اتصال)

**الملف**: `lib/data/datasources/contact_api_service.dart`

```dart
Future<void> deleteContact(String id) async {
  try {
    // إرسال DELETE request
    final response = await _dio.delete('${ApiConstants.deleteContact}/$id');  // '/api/User/{id}'

    // التحقق من النجاح
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete contact: ${response.statusCode}');
    }
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
```

**الملف**: `lib/presentation/providers/contact_provider.dart`

```dart
Future<void> deleteContact(String id) async {
  try {
    await _repository.deleteContact(id);
    await loadContacts(); // تحديث القائمة تلقائياً
  } catch (e) {
    state = state.copyWith(error: e.toString());
  }
}
```

---

## 2. Image Upload - خطوات رفع الصورة

### الخطوات الكاملة لرفع الصورة

#### الخطوة 1: اختيار الصورة من المعرض

**الملف**: `lib/presentation/screens/add_edit_contact_screen.dart`

```dart
Future<void> _pickImage() async {
  final picker = ImagePicker();
  
  // فتح معرض الصور
  final pickedFile = await picker.pickImage(
    source: ImageSource.gallery,  // من المعرض
    imageQuality: 85,  // جودة الصورة (0-100)
  );

  if (pickedFile != null) {
    final file = File(pickedFile.path);
    
    // التحقق من نوع الملف
    if (!ImageUtils.isValidImage(file.path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PNG or JPG image')),
      );
      return;
    }

    // ضغط الصورة (اختياري)
    final compressed = await ImageUtils.compressImage(file);
    setState(() {
      _selectedImage = compressed ?? file;
    });
  }
}
```

#### الخطوة 2: ضغط الصورة (Image Compression)

**الملف**: `lib/core/utils/image_utils.dart`

```dart
static Future<File?> compressImage(File imageFile, {int quality = 85, int maxSize = 1024}) async {
  try {
    // قراءة الملف
    final bytes = await imageFile.readAsBytes();
    final originalSize = bytes.length / 1024; // KB

    // إذا كانت الصورة صغيرة، لا حاجة للضغط
    if (originalSize <= maxSize) {
      return imageFile;
    }

    // فك تشفير الصورة
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // حساب الأبعاد الجديدة
    double scale = 1.0;
    if (originalSize > maxSize) {
      scale = (maxSize / originalSize).clamp(0.5, 1.0);
    }

    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();

    // تصغير الصورة
    final resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    // ضغط الصورة
    final compressedBytes = img.encodeJpg(resized, quality: quality);

    // حفظ في مجلد مؤقت
    final tempDir = await getTemporaryDirectory();
    final fileName = path.basename(imageFile.path);
    final compressedFile = File(path.join(tempDir.path, 'compressed_$fileName'));

    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  } catch (e) {
    return imageFile; // إرجاع الأصل إذا فشل الضغط
  }
}
```

**لماذا الضغط؟**
- تقليل حجم الملف (توفير bandwidth)
- تسريع الرفع
- توفير مساحة على الخادم

#### الخطوة 3: رفع الصورة إلى الخادم

**الملف**: `lib/data/datasources/contact_api_service.dart`

```dart
Future<String> _uploadImage(File imageFile) async {
  // قائمة بأسماء الحقول المحتملة (API قد يتوقع أي منها)
  final List<String> fieldNames = ['image', 'photo', 'file', 'upload'];
  DioException? lastError;

  // جرب كل اسم حقل حتى ينجح واحد
  for (String fieldName in fieldNames) {
    try {
      print('🔍 Trying to upload image with field name: $fieldName');
      
      // تحديد نوع الملف (MIME type)
      final String fileExtension = ImageUtils.getImageExtension(imageFile.path);
      final String mimeType = fileExtension == '.png' ? 'image/png' : 'image/jpeg';

      // إنشاء FormData (مطلوب لرفع الملفات)
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
          contentType: MediaType.parse(mimeType),
        ),
      });

      print('📤 Uploading file: ${imageFile.path.split('/').last} ($mimeType)');
      
      // إرسال POST request
      final response = await _dio.post(
        ApiConstants.uploadImage,  // '/api/User/UploadImage'
        data: formData,
        options: Options(
          headers: ApiConstants.headersWithoutContentType,  // Dio يضيف Content-Type تلقائياً
        ),
      );

      // التحقق من النجاح
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Image uploaded successfully with field: $fieldName');
        print('📦 Upload response: ${response.data}');

        final data = response.data;
        
        // استخراج imageUrl من Response
        // البنية المتوقعة: {success: true, data: {imageUrl: "..."}}
        if (data is Map) {
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('imageUrl')) {
              print('✅ Extracted imageUrl: ${dataMap['imageUrl']}');
              return dataMap['imageUrl'] as String;
            } else if (dataMap.containsKey('url')) {
              return dataMap['url'] as String;
            } else if (dataMap.containsKey('photoUrl')) {
              return dataMap['photoUrl'] as String;
            }
          }
          // محاولات أخرى
          if (data.containsKey('imageUrl')) {
            return data['imageUrl'] as String;
          }
        } else if (data is String) {
          // إذا كان Response مباشرة URL
          return data;
        }
        
        throw Exception('Invalid response format from upload image: $data');
      }
    } on DioException catch (e) {
      lastError = e;
      final statusCode = e.response?.statusCode;
      print('❌ Field name $fieldName failed with $statusCode, trying next...');
      
      // إذا كان الخطأ 400 (InvalidFile) أو 404، جرب الحقل التالي
      if (statusCode == 400 || statusCode == 404) {
        continue;  // جرب الحقل التالي
      } else {
        rethrow;  // خطأ آخر، أرجعه
      }
    }
  }
  
  // إذا فشلت كل المحاولات
  if (lastError != null) {
    throw _handleError(lastError);
  }
  throw Exception('Failed to upload image: No valid field name found or unknown error.');
}
```

**لماذا نجرب عدة أسماء حقول؟**
- لأن API قد يتوقع `image` أو `photo` أو `file`
- لا نعرف مسبقاً ما هو الصحيح
- نجرب كل واحد حتى ينجح

**ما هو FormData؟**
- **FormData**: نوع خاص من البيانات لرفع الملفات
- **Multipart**: يعني البيانات مقسمة إلى أجزاء (text + binary)
- **MultipartFile**: يمثل الملف في FormData

#### الخطوة 4: استخدام imageUrl في Create/Update

```dart
// بعد رفع الصورة، نحصل على imageUrl
final imageUrl = await _uploadImage(imageFile);

// نستخدمه في بيانات جهة الاتصال
final contactData = {
  'firstName': contact.firstName,
  'lastName': contact.lastName,
  'phoneNumber': contact.phoneNumber,
  'profileImageUrl': imageUrl,  // هنا!
};
```

---

## 3. Lottie Animation

### ما هو Lottie؟

**Lottie** هو تنسيق ملفات للرسوم المتحركة (animations). بدلاً من استخدام GIF أو فيديو، نستخدم ملف JSON صغير يحتوي على animation.

### كيف تم استخدام Lottie في التطبيق؟

**الملف**: `lib/presentation/screens/add_edit_contact_screen.dart`

```dart
class _AddEditContactScreenState extends ConsumerState<AddEditContactScreen> {
  bool _showSuccessAnimation = false;  // متغير لتتبع حالة Animation

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // إنشاء أو تحديث جهة الاتصال
      if (widget.contact == null) {
        await ref.read(contactsProvider.notifier).createContact(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              imageFile: _selectedImage,
            );
      } else {
        await ref.read(contactsProvider.notifier).updateContact(
              id: widget.contact!.id!,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              imageFile: _selectedImage,
            );
      }

      // الخطوة 1: إخفاء Loading indicator
      setState(() {
        _isLoading = false;
        _showSuccessAnimation = true;  // إظهار Animation
      });

      // الخطوة 2: انتظار Animation حتى يكتمل (2 ثانية)
      await Future.delayed(const Duration(seconds: 2));

      // الخطوة 3: العودة للشاشة السابقة
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
    // إذا كان يجب إظهار Animation، اعرضه
    if (_showSuccessAnimation) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Lottie.asset(
            'Done.json',  // ملف Lottie في assets
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    // وإلا، اعرض النموذج العادي
    return Scaffold(
      // ... باقي الكود
    );
  }
}
```

**إعداد Lottie في `pubspec.yaml`**:

```yaml
flutter:
  assets:
    - Done.json  # ملف Lottie
```

**Flow كامل**:
```
1. المستخدم يضغط "Add Contact"
   ↓
2. _saveContact() يتم استدعاؤها
   ↓
3. إنشاء/تحديث جهة الاتصال
   ↓
4. إذا نجح:
   - _showSuccessAnimation = true
   - setState() → rebuild
   ↓
5. build() يعرض Lottie.asset('Done.json')
   ↓
6. انتظار 2 ثانية
   ↓
7. Navigator.pop() → العودة للقائمة
```

---

## 4. Alphabetical Grouping - التجميع الأبجدي

### كيف تم تجميع القائمة أبجدياً؟

**الملف**: `lib/presentation/providers/contact_provider.dart`

```dart
class ContactsState {
  final List<Contact> contacts;
  final Map<String, List<Contact>> groupedContacts;  // القائمة المجمعة

  ContactsState({
    this.contacts = const [],
    Map<String, List<Contact>>? groupedContacts,
  }) : groupedContacts = groupedContacts ?? _groupContacts(contacts);

  // دالة التجميع
  static Map<String, List<Contact>> _groupContacts(List<Contact> contacts) {
    final grouped = <String, List<Contact>>{};
    
    // الخطوة 1: ترتيب القائمة أبجدياً
    final sorted = List<Contact>.from(contacts)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    // الخطوة 2: التجميع حسب الحرف الأول
    for (var contact in sorted) {
      final firstLetter = contact.firstLetter;  // 'A', 'B', 'C', etc.
      
      // إذا كان المفتاح غير موجود، أنشئ قائمة جديدة
      // وإلا، أضف للقائمة الموجودة
      grouped.putIfAbsent(firstLetter, () => []).add(contact);
    }

    return grouped;
  }
}
```

**الملف**: `lib/domain/entities/contact.dart`

```dart
class Contact {
  // ...
  
  String get fullName => '$firstName $lastName'.trim();

  String get firstLetter {
    if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();  // الحرف الأول من الاسم الأول
    }
    return '#';  // إذا لم يكن هناك اسم
  }
}
```

**الملف**: `lib/presentation/screens/contacts_screen.dart`

```dart
Widget _buildGroupedContacts(ContactsState contactsState) {
  if (contactsState.contacts.isEmpty) {
    return const Center(child: Text('No contacts yet. Add one!'));
  }

  final grouped = contactsState.groupedContacts;
  
  // ترتيب المفاتيح (A, B, C, ...)
  final sortedKeys = grouped.keys.toList()..sort();

  return ListView.builder(
    itemCount: sortedKeys.length,
    itemBuilder: (context, index) {
      final letter = sortedKeys[index];  // 'A', 'B', 'C', etc.
      final contacts = grouped[letter]!;  // قائمة جهات الاتصال لهذا الحرف

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس القسم (A, B, C, ...)
          ContactSectionHeader(letter: letter),
          
          // قائمة جهات الاتصال
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
```

**مثال على النتيجة**:

```dart
{
  'A': [Contact('Ahmed'), Contact('Ali')],
  'B': [Contact('Bassem')],
  'C': [Contact('Cairo')],
  'M': [Contact('Mohammed')],
}
```

**Flow**:
```
1. getAllContacts() → List<Contact>
   ↓
2. _groupContacts() → Map<String, List<Contact>>
   ├─ ترتيب أبجدي
   └─ تجميع حسب الحرف الأول
   ↓
3. _buildGroupedContacts() → Widget
   ├─ عرض رأس القسم (A, B, C, ...)
   └─ عرض قائمة جهات الاتصال
```

---

## 5. Swipe Actions

### ما هي Swipe Actions؟

**Swipe Actions** هي أزرار تظهر عند سحب العنصر (swipe left/right). في التطبيق، عند سحب جهة اتصال لليسار، تظهر أزرار Edit و Delete.

### كيف تم تنفيذ Swipe Actions؟

**الملف**: `lib/presentation/widgets/contact_list_item.dart`

```dart
import 'package:flutter_slidable/flutter_slidable.dart';

class ContactListItem extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(contact.id),
      
      // ActionPane: الأزرار التي تظهر عند السحب
      endActionPane: ActionPane(
        motion: const StretchMotion(),  // نوع الحركة (Stretch = تمطيط)
        children: [
          // زر Edit
          SlidableAction(
            onPressed: (_) => onEdit(),  // عند الضغط، استدعاء onEdit
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          
          // زر Delete
          SlidableAction(
            onPressed: (_) => onDelete(),  // عند الضغط، استدعاء onDelete
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      
      // المحتوى الأساسي (ListTile)
      child: ListTile(
        leading: CircleAvatar(
          // ... صورة جهة الاتصال
        ),
        title: Text(contact.fullName),
        subtitle: Text(contact.phoneNumber),
        onTap: onTap,
      ),
    );
  }
}
```

**الملف**: `lib/presentation/screens/contacts_screen.dart`

```dart
// استخدام ContactListItem
ContactListItem(
  contact: contact,
  onTap: () => _navigateToProfile(contact),
  onEdit: () => _navigateToEdit(contact),  // فتح شاشة التعديل
  onDelete: () => _deleteContact(contact.id!),  // حذف جهة الاتصال
)
```

**Package المستخدم**: `flutter_slidable: ^3.0.1`

**أنواع الحركة (Motion)**:
- `StretchMotion`: تمطيط
- `DrawerMotion`: سحب
- `ScrollMotion`: تمرير

---

## 6. Search with History - البحث مع التاريخ

### كيف يعمل البحث؟

**الملف**: `lib/presentation/providers/contact_provider.dart`

```dart
// Search State
class SearchState {
  final List<Contact> filteredContacts;  // نتائج البحث
  final String query;  // نص البحث
  final List<String> searchHistory;  // تاريخ البحث
  final bool isSearching;  // هل البحث قيد التنفيذ؟

  SearchState({
    this.filteredContacts = const [],
    this.query = '',
    this.searchHistory = const [],
    this.isSearching = false,
  });
}

// Search Notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final ContactRepository _repository;

  SearchNotifier(this._repository) : super(SearchState()) {
    _loadSearchHistory();  // تحميل تاريخ البحث عند البدء
  }

  // تحميل تاريخ البحث من Hive
  void _loadSearchHistory() async {
    await ContactLocalService.init();
    final history = ContactLocalService.getSearchHistory();
    state = state.copyWith(searchHistory: history);
  }

  // دالة البحث
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(
        query: '',
        filteredContacts: [],
        isSearching: false,
      );
      return;
    }

    // تحديث State: البحث قيد التنفيذ
    state = state.copyWith(isSearching: true, query: query);
    
    try {
      // البحث في جهات الاتصال
      final results = await _repository.searchContacts(query);
      
      // حفظ البحث في التاريخ
      await ContactLocalService.addSearchToHistory(query);
      
      // تحديث State: النتائج جاهزة
      state = state.copyWith(
        filteredContacts: results,
        isSearching: false,
        searchHistory: ContactLocalService.getSearchHistory(),  // تحديث التاريخ
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
```

**الملف**: `lib/data/repositories/contact_repository_impl.dart`

```dart
@override
Future<List<Contact>> searchContacts(String query) async {
  // جلب جميع جهات الاتصال
  final allContacts = await getAllContacts();
  if (query.trim().isEmpty) return allContacts;

  // تطبيع نص البحث (إزالة المسافات الزائدة، تحويل لحروف صغيرة)
  final normalizedQuery = StringUtils.normalizeForSearch(query);
  
  // فلترة جهات الاتصال
  return allContacts.where((contact) {
    final fullName = contact.fullName;
    return StringUtils.matchesSearch(fullName, normalizedQuery);
  }).toList();
}
```

**الملف**: `lib/core/utils/string_utils.dart`

```dart
class StringUtils {
  /// تطبيع نص البحث
  static String normalizeForSearch(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// التحقق من تطابق البحث
  static bool matchesSearch(String name, String query) {
    final normalizedName = normalizeForSearch(name);
    final normalizedQuery = normalizeForSearch(query);
    
    // التحقق إذا كان query موجود في name
    return normalizedName.contains(normalizedQuery);
  }
}
```

**مثال**:
- البحث: `"ahmed ali"` → يجد `"Ahmed Ali"` و `"Ahmed Ali Mohammed"`
- البحث: `"ahmed"` → يجد جميع الأسماء التي تحتوي على "ahmed"

### عرض تاريخ البحث

**الملف**: `lib/presentation/screens/contacts_screen.dart`

```dart
Widget _buildSearchHistory(SearchState searchState) {
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
              // عند الضغط على عنصر من التاريخ، استخدمه كبحث
              _searchController.text = query;
              _onSearchChanged(query);
            },
          );
        },
      ),
    ],
  );
}
```

**Flow**:
```
1. المستخدم يكتب في search box
   ↓
2. _onSearchChanged() → SearchNotifier.search()
   ↓
3. ContactRepository.searchContacts()
   ├─ جلب جميع جهات الاتصال
   └─ فلترة حسب query
   ↓
4. ContactLocalService.addSearchToHistory()
   ├─ إضافة للتاريخ
   └─ حفظ في Hive
   ↓
5. تحديث State → عرض النتائج
```

---

## 7. SharedPreferences vs Hive - الفرق والاستخدام

### ما هو SharedPreferences؟

**SharedPreferences** هو طريقة بسيطة لحفظ البيانات البسيطة (strings, ints, bools) في Android/iOS.

**الاستخدام**:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('key', 'value');
final value = prefs.getString('key');
```

**المميزات**:
- ✅ بسيط جداً
- ✅ مناسب للبيانات البسيطة

**العيوب**:
- ❌ بطيء مع البيانات الكبيرة
- ❌ لا يدعم Objects مباشرة (يحتاج serialization)
- ❌ لا يدعم Queries

### ما هو Hive?

**Hive** هو NoSQL database محلي سريع جداً.

**الاستخدام**:
```dart
await Hive.initFlutter();
final box = await Hive.openBox('myBox');
await box.put('key', {'name': 'Ahmed', 'age': 25});
final data = box.get('key');
```

**المميزات**:
- ✅ سريع جداً (أسرع من SQLite)
- ✅ يدعم Objects مباشرة
- ✅ بسيط (لا يحتاج SQL)
- ✅ Type-safe مع code generation

**العيوب**:
- ❌ يحتاج تهيئة
- ❌ أكثر تعقيداً قليلاً من SharedPreferences

### أين استخدمنا كل واحد؟

#### Hive - للبيانات المعقدة

**الملف**: `lib/data/datasources/contact_local_service.dart`

```dart
class ContactLocalService {
  static Box<Map>? _contactsBox;  // Hive Box لجهات الاتصال
  static Box<List<String>>? _searchHistoryBox;  // Hive Box لتاريخ البحث

  // حفظ جهات الاتصال (Objects معقدة)
  static Future<void> cacheContacts(List<ContactModel> contacts) async {
    if (!_initialized) await init();
    if (_contactsBox == null) return;
    
    await _contactsBox!.clear();
    for (var contact in contacts) {
      if (contact.id != null) {
        // حفظ كـ Map (Object)
        await _contactsBox!.put(contact.id!, contact.toJson());
      }
    }
  }

  // حفظ تاريخ البحث (List of Strings)
  static Future<void> addSearchToHistory(String query) async {
    if (!_initialized) await init();
    if (_searchHistoryBox == null) return;
    
    if (query.trim().isEmpty) return;
    
    // جلب التاريخ الحالي
    final history = _searchHistoryBox!.get('history', defaultValue: <String>[]) ?? [];
    
    // إزالة إذا كان موجود (لتجنب التكرار)
    history.remove(query.trim());
    
    // إضافة في البداية
    history.insert(0, query.trim());
    
    // تحديد الحد الأقصى (مثلاً: 10 عناصر)
    if (history.length > AppConstants.maxSearchHistoryItems) {
      history.removeRange(AppConstants.maxSearchHistoryItems, history.length);
    }
    
    // حفظ
    await _searchHistoryBox!.put('history', history);
  }
}
```

**لماذا Hive هنا؟**
- جهات الاتصال: Objects معقدة (Map)
- تاريخ البحث: List of Strings
- نحتاج سرعة (قراءة/كتابة متكررة)

#### SharedPreferences - لم نستخدمه

في هذا التطبيق، استخدمنا **Hive فقط** لأن:
- البيانات معقدة (Contacts Objects)
- نحتاج سرعة
- Hive يدعم كل ما نحتاجه

**متى نستخدم SharedPreferences؟**
- إعدادات بسيطة (theme, language)
- Flags بسيطة (isFirstLaunch)
- Strings بسيطة

**مثال على SharedPreferences**:
```dart
// حفظ إعدادات بسيطة
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('isDarkMode', true);
await prefs.setString('language', 'ar');
```

---

## 8. Dominant Color Extraction

### ما هو Dominant Color?

**Dominant Color** هو اللون السائد في الصورة. نستخدمه كظل للصورة في Profile Screen.

### كيف تم استخراج Dominant Color?

**الملف**: `lib/core/utils/color_utils.dart`

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ColorUtils {
  /// استخراج اللون السائد من صورة محلية
  static Future<Color> getDominantColor(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return Colors.grey;  // لون افتراضي
      }

      // الخطوة 1: قراءة الصورة
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return Colors.grey;
      }

      // الخطوة 2: تصغير الصورة (للسرعة)
      // بدلاً من معالجة كل pixel، نعالج صورة صغيرة
      final resized = img.copyResize(image, width: 100);
      
      // الخطوة 3: حساب متوسط الألوان
      int r = 0, g = 0, b = 0;
      int pixelCount = 0;

      // أخذ عينة من Pixels (كل 5 pixels)
      // لماذا؟ لتسريع العملية
      for (int y = 0; y < resized.height; y += 5) {
        for (int x = 0; x < resized.width; x += 5) {
          final pixel = resized.getPixel(x, y);
          
          // جمع قيم RGB
          r += pixel.r.toInt();
          g += pixel.g.toInt();
          b += pixel.b.toInt();
          pixelCount++;
        }
      }

      if (pixelCount == 0) {
        return Colors.grey;
      }

      // الخطوة 4: حساب المتوسط
      r = (r / pixelCount).round();
      g = (g / pixelCount).round();
      b = (b / pixelCount).round();

      // الخطوة 5: إنشاء Color
      return Color.fromRGBO(r, g, b, 1.0);
    } catch (e) {
      return Colors.grey;
    }
  }

  /// الحصول على لون الظل من اللون السائد
  static Color getShadowColor(Color dominantColor) {
    // جعل اللون أغمق قليلاً للظل
    return dominantColor.withOpacity(0.3);
  }
}
```

**الملف**: `lib/presentation/screens/profile_screen.dart`

```dart
class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Color? _dominantColor;  // اللون السائد

  Future<void> _loadContact() async {
    try {
      final repository = ref.read(contactRepositoryProvider);
      final contact = await repository.getContactById(widget.contactId);
      
      setState(() {
        _contact = contact;
        _isLoading = false;
      });

      // استخراج اللون السائد إذا كانت هناك صورة
      if (contact?.photoUrl != null && contact!.photoUrl!.isNotEmpty) {
        // التحقق إذا كانت صورة محلية (تبدأ بـ /)
        if (contact.photoUrl!.startsWith('/')) {
          try {
            _dominantColor = await ColorUtils.getDominantColor(contact.photoUrl!);
            setState(() {});
          } catch (e) {
            _dominantColor = Colors.grey;
            setState(() {});
          }
        } else {
          // للصور من الشبكة، نستخدم لون افتراضي
          _dominantColor = Colors.blue;
          setState(() {});
        }
      }
    } catch (e) {
      // ...
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدام اللون السائد كظل
    final shadowColor = _dominantColor ?? Colors.grey;
    final shadow = ColorUtils.getShadowColor(shadowColor);

    return Scaffold(
      body: Column(
        children: [
          // صورة الملف الشخصي مع ظل
          Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadow,  // اللون السائد كظل
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
            ),
          ),
        ],
      ),
    );
  }
}
```

**الخوارزمية**:
```
1. قراءة الصورة
   ↓
2. تصغير الصورة (100x100) لتسريع العملية
   ↓
3. أخذ عينة من Pixels (كل 5 pixels)
   ↓
4. جمع قيم RGB
   ↓
5. حساب المتوسط
   ↓
6. إنشاء Color من المتوسط
```

**لماذا نأخذ عينة (كل 5 pixels)؟**
- لتسريع العملية
- لا نحتاج كل pixel للحصول على اللون السائد
- العينة كافية للحصول على نتيجة جيدة

---

## 9. Device Contacts Integration

### كيف يتم فحص إذا كانت جهة الاتصال موجودة في الجهاز؟

**الملف**: `lib/data/datasources/device_contacts_service.dart`

```dart
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceContactsService {
  /// فحص إذا كانت جهة الاتصال موجودة في device contacts
  Future<bool> isContactInDevice(String phoneNumber) async {
    try {
      // الخطوة 1: طلب الإذن
      final hasPermission = await _requestPermission();
      if (!hasPermission) return false;

      // الخطوة 2: جلب جميع جهات الاتصال من الجهاز
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,  // مع الأرقام
        withThumbnail: false,  // بدون الصور (للسرعة)
      );
      
      // الخطوة 3: تطبيع رقم الهاتف للمقارنة
      final normalizedPhone = _normalizePhone(phoneNumber);

      // الخطوة 4: البحث في جهات الاتصال
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          // تطبيع رقم الهاتف من الجهاز
          if (_normalizePhone(phone.number) == normalizedPhone) {
            return true;  // موجود!
          }
        }
      }
      
      return false;  // غير موجود
    } catch (e) {
      return false;
    }
  }

  /// تطبيع رقم الهاتف (إزالة كل شيء ما عدا الأرقام)
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');  // \D = كل شيء ما عدا الأرقام
  }

  /// طلب الإذن للوصول لجهات الاتصال
  Future<bool> _requestPermission() async {
    final status = await Permission.contacts.status;
    
    // إذا كان الإذن ممنوح، رجع true
    if (status.isGranted) return true;

    // إذا كان مرفوض، اطلب الإذن
    if (status.isDenied) {
      final result = await Permission.contacts.request();
      return result.isGranted;
    }

    return false;
  }
}
```

**مثال على التطبيع**:
- `"+905551234567"` → `"905551234567"`
- `"0555 123 45 67"` → `"05551234567"`
- `"(0555) 123-45-67"` → `"05551234567"`

**لماذا التطبيع؟**
- لأن المستخدم قد يدخل الرقم بصيغ مختلفة
- `"+905551234567"` و `"05551234567"` نفس الرقم

### كيف يتم حفظ جهة الاتصال في الجهاز؟

**الملف**: `lib/data/datasources/device_contacts_service.dart`

```dart
/// حفظ جهة الاتصال في device contacts
Future<bool> saveContactToDevice({
  required String firstName,
  required String lastName,
  required String phoneNumber,
}) async {
  try {
    // الخطوة 1: طلب الإذن
    final hasPermission = await _requestPermission();
    if (!hasPermission) return false;

    // الخطوة 2: إنشاء Contact object
    final contact = Contact()
      ..name.first = firstName
      ..name.last = lastName
      ..phones = [Phone(phoneNumber)];

    // الخطوة 3: حفظ في الجهاز
    await contact.insert();
    return true;
  } catch (e) {
    return false;
  }
}
```

**الملف**: `lib/presentation/screens/profile_screen.dart`

```dart
Future<void> _saveToDevice() async {
  if (_contact == null) return;

  try {
    final repository = ref.read(contactRepositoryProvider);
    
    // حفظ في الجهاز
    await repository.saveContactToDevice(_contact!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact saved to device')),
      );
      
      // تحديث جهة الاتصال (لتحديث isInDeviceContacts)
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
```

### كيف يتم إظهار الأيقونة؟

**الملف**: `lib/presentation/widgets/contact_list_item.dart`

```dart
ListTile(
  // ...
  trailing: contact.isInDeviceContacts
      ? const Icon(
          Icons.phone_android,
          color: Colors.green,
          size: 20,
        )
      : null,
  // ...
)
```

**الملف**: `lib/presentation/screens/profile_screen.dart`

```dart
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
```

**Flow كامل**:
```
1. getAllContacts() من API
   ↓
2. لكل جهة اتصال:
   - isContactInDevice(phoneNumber)
   ├─ طلب الإذن
   ├─ جلب جهات الاتصال من الجهاز
   ├─ تطبيع الأرقام
   └─ المقارنة
   ↓
3. copyWith(isInDeviceContacts: true/false)
   ↓
4. عرض الأيقونة في UI
```

---

## 10. Local Caching with Hive

### ما هو Caching?

**Caching** هو حفظ البيانات محلياً لتسريع الوصول إليها وتقليل استخدام الشبكة.

### كيف تم تنفيذ Caching?

**الملف**: `lib/data/datasources/contact_local_service.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';

class ContactLocalService {
  static Box<Map>? _contactsBox;  // Hive Box
  static bool _initialized = false;

  /// التهيئة (مرة واحدة عند بدء التطبيق)
  static Future<void> init() async {
    if (_initialized) return;  // تجنب التهيئة المتعددة
    
    // تهيئة Hive
    await Hive.initFlutter();
    
    // فتح Box (مثل جدول في Database)
    _contactsBox = await Hive.openBox<Map>('contacts');
    
    _initialized = true;
  }

  /// حفظ جهات الاتصال في Cache
  static Future<void> cacheContacts(List<ContactModel> contacts) async {
    if (!_initialized) await init();
    if (_contactsBox == null) return;
    
    // مسح Cache القديم
    await _contactsBox!.clear();
    
    // حفظ كل جهة اتصال
    for (var contact in contacts) {
      if (contact.id != null) {
        // المفتاح: contact.id
        // القيمة: contact.toJson() (Map)
        await _contactsBox!.put(contact.id!, contact.toJson());
      }
    }
  }

  /// جلب جهات الاتصال من Cache
  static List<ContactModel> getCachedContacts() {
    if (_contactsBox == null) return [];
    
    // جلب جميع القيم
    return _contactsBox!.values
        .map((json) => ContactModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
```

**الملف**: `lib/data/repositories/contact_repository_impl.dart`

```dart
@override
Future<List<Contact>> getAllContacts() async {
  try {
    // Strategy: Network-first
    // الخطوة 1: محاولة من API
    final contacts = await _apiService.getAllContacts();
    
    // الخطوة 2: حفظ في Cache
    await ContactLocalService.cacheContacts(
      contacts.map((c) => ContactModel(...)).toList(),
    );

    return contacts;
  } catch (e) {
    // Strategy: Fallback to Cache
    // إذا فشل API، جلب من Cache
    print('⚠️ API failed, using cache: $e');
    final cached = ContactLocalService.getCachedContacts();
    if (cached.isNotEmpty) {
      return cached;
    }
    rethrow;
  }
}
```

**الاستراتيجية (Strategy)**:

1. **Network-first**:
   - جرب API أولاً
   - إذا نجح، احفظ في Cache
   - إذا فشل، استخدم Cache

2. **Cache-first** (بديل):
   - جرب Cache أولاً
   - إذا لم يكن موجود، جرب API
   - احفظ في Cache بعد النجاح

**متى يتم تحديث Cache؟**
- بعد `getAllContacts()` (نجاح API)
- بعد `createContact()`
- بعد `updateContact()`
- بعد `deleteContact()`

**الملف**: `lib/data/repositories/contact_repository_impl.dart`

```dart
@override
Future<Contact> createContact(Contact contact, {File? imageFile}) async {
  final created = await _apiService.createContact(contactModel, imageFile: imageFile);
  
  // تحديث Cache
  await getAllContacts();  // يجلب من API ويحدث Cache
  
  return created;
}

@override
Future<Contact> updateContact(Contact contact, {File? imageFile}) async {
  final updated = await _apiService.updateContact(contactModel, imageFile: imageFile);
  
  // تحديث Cache
  await getAllContacts();
  
  return updated;
}

@override
Future<void> deleteContact(String id) async {
  await _apiService.deleteContact(id);
  
  // تحديث Cache
  await getAllContacts();
}
```

**الفوائد**:
- ✅ سرعة: قراءة من Cache أسرع من API
- ✅ Offline: التطبيق يعمل بدون إنترنت
- ✅ تقليل استخدام البيانات
- ✅ تجربة أفضل للمستخدم

---

## 🎯 الخلاصة

### ما تعلمناه:

1. **CRUD**: Create, Read, Update, Delete - العمليات الأساسية
2. **Image Upload**: اختيار → ضغط → رفع → استخدام imageUrl
3. **Lottie Animation**: عرض animation عند النجاح
4. **Alphabetical Grouping**: ترتيب وتجميع أبجدي
5. **Swipe Actions**: أزرار Edit/Delete عند السحب
6. **Search with History**: بحث مع حفظ التاريخ في Hive
7. **SharedPreferences vs Hive**: Hive للبيانات المعقدة
8. **Dominant Color**: استخراج اللون السائد من الصورة
9. **Device Contacts**: فحص وحفظ في جهات الاتصال
10. **Local Caching**: حفظ محلي لتسريع الوصول

### أفضل الممارسات:

1. ✅ استخدم try-catch لكل API call
2. ✅ ضغط الصور قبل الرفع
3. ✅ Cache البيانات المحلية
4. ✅ Fallback إلى Cache عند فشل API
5. ✅ تحديث Cache بعد كل عملية

---

**تم إنشاء هذا الشرح التفصيلي بتاريخ: 2025-11-22**

