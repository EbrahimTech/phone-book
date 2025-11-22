# 📖 شرح تفصيلي سطر بسطر - Phone Book Flutter Application

## 🎯 مقدمة

هذا الملف يشرح **كل جزء** في المشروع بشكل مفصل جداً، بحيث تفهم كيف يعمل كل سطر من الكود ولماذا كتبناه بهذه الطريقة.

---

## 📚 الجزء الأول: Clean Architecture - المفهوم الأساسي

### ما هي Clean Architecture؟

**Clean Architecture** هي طريقة لتنظيم الكود بحيث يكون:
- **منفصلاً**: كل جزء له مسؤولية واحدة
- **قابلاً للاختبار**: يمكن اختبار كل جزء لوحده
- **قابلاً للصيانة**: تغيير جزء لا يؤثر على الأجزاء الأخرى

### لماذا 3 طبقات؟

```
┌─────────────────────────────────────┐
│   Presentation Layer (UI)          │  ← ما يراه المستخدم
├─────────────────────────────────────┤
│   Domain Layer (Business Logic)     │  ← القواعد والمنطق
├─────────────────────────────────────┤
│   Data Layer (Data Sources)         │  ← من أين تأتي البيانات
└─────────────────────────────────────┘
```

#### 1. Presentation Layer (طبقة العرض)
**المسؤولية**: كل ما يتعلق بالواجهة
- الشاشات (Screens)
- الأزرار (Buttons)
- النصوص (Text)
- الألوان والتصميم

**مثال**: عندما يضغط المستخدم على زر "Add Contact"، هذه الطبقة تتعامل مع الضغطة.

#### 2. Domain Layer (طبقة المجال)
**المسؤولية**: القواعد والمنطق
- ما هي العمليات المتاحة؟ (Create, Read, Update, Delete)
- ما هي القواعد؟ (مثلاً: يجب أن يكون الاسم موجود)
- الكيانات (Entities) - ما هو Contact؟

**مثال**: "Contact يجب أن يحتوي على firstName و lastName" - هذه قاعدة منطقية.

#### 3. Data Layer (طبقة البيانات)
**المسؤولية**: من أين تأتي البيانات
- API (الخادم)
- Database (قاعدة البيانات المحلية)
- Device Contacts (جهات الاتصال في الجهاز)

**مثال**: جلب قائمة جهات الاتصال من الخادم عبر HTTP request.

---

## 🔍 الجزء الثاني: Domain Layer - شرح تفصيلي

### 1. Entities (الكيانات)

#### ما هو Entity؟

**Entity** هو كائن يمثل شيء في التطبيق. في حالتنا، `Contact` هو Entity.

```dart
// lib/domain/entities/contact.dart
class Contact {
  final String? id;                    // معرف فريد (قد يكون null إذا لم يُحفظ بعد)
  final String firstName;              // الاسم الأول (مطلوب)
  final String lastName;               // الاسم الأخير (مطلوب)
  final String phoneNumber;            // رقم الهاتف (مطلوب)
  final String? photoUrl;              // رابط الصورة (اختياري)
  final bool isInDeviceContacts;      // هل موجود في جهات الاتصال؟
}
```

#### شرح كل حقل:

1. **`id`**: 
   - نوعه `String?` (يعني قد يكون null)
   - لماذا؟ لأن جهة الاتصال الجديدة لا يوجد لها id حتى تُحفظ في الخادم
   - بعد الحفظ، الخادم يعيد id فريد

2. **`firstName`**:
   - نوعه `String` (مطلوب، لا يمكن أن يكون null)
   - لماذا مطلوب؟ لأن جهة الاتصال يجب أن يكون لها اسم

3. **`lastName`**:
   - نفس الشيء مثل firstName

4. **`phoneNumber`**:
   - مطلوب أيضاً
   - قد يكون بصيغة `+905551234567` أو `05551234567`

5. **`photoUrl`**:
   - نوعه `String?` (اختياري)
   - لماذا؟ لأن المستخدم قد لا يختار صورة
   - يحتوي على رابط الصورة من الخادم

6. **`isInDeviceContacts`**:
   - نوعه `bool` (true أو false)
   - يخبرنا إذا كانت جهة الاتصال موجودة في جهات الاتصال في الجهاز

#### لماذا Entity منفصل عن Model؟

- **Entity**: يمثل الكيان في منطق التطبيق (مستقل عن API)
- **Model**: يمثل الكيان في البيانات (يعرف كيف يقرأ من JSON)

**الفائدة**: إذا تغيرت بنية API، نغير Model فقط، وليس Entity.

---

### 2. Repository Interface (واجهة المستودع)

#### ما هو Repository؟

**Repository** هو طبقة تجمع بين مصادر البيانات المختلفة (API, Database, Device).

```dart
// lib/domain/repositories/contact_repository.dart
abstract class ContactRepository {
  Future<List<Contact>> getAllContacts();
  Future<Contact> getContact(String id);
  Future<Contact> createContact(Contact contact, {File? imageFile});
  Future<Contact> updateContact(String id, Contact contact, {File? imageFile});
  Future<void> deleteContact(String id);
}
```

#### شرح كل دالة:

1. **`getAllContacts()`**:
   - **الوظيفة**: جلب جميع جهات الاتصال
   - **النوع**: `Future<List<Contact>>` (يعيد قائمة من Contact)
   - **Future**: يعني العملية غير متزامنة (تأخذ وقت)
   - **متى تستخدم؟**: عند فتح شاشة القائمة

2. **`getContact(String id)`**:
   - **الوظيفة**: جلب جهة اتصال واحدة
   - **المعامل**: `id` - معرف جهة الاتصال
   - **متى تستخدم؟**: عند فتح شاشة Profile

3. **`createContact(Contact contact, {File? imageFile})`**:
   - **الوظيفة**: إنشاء جهة اتصال جديدة
   - **المعاملات**:
     - `contact`: جهة الاتصال المراد إنشاؤها
     - `imageFile`: الصورة (اختياري - بين `{}`)
   - **متى تستخدم؟**: عند الضغط على "Add Contact"

4. **`updateContact(String id, Contact contact, {File? imageFile})`**:
   - **الوظيفة**: تحديث جهة اتصال موجودة
   - **المعاملات**: نفس createContact + `id` لتحديد أي جهة اتصال
   - **متى تستخدم؟**: عند الضغط على "Update" في Profile

5. **`deleteContact(String id)`**:
   - **الوظيفة**: حذف جهة اتصال
   - **المعامل**: `id` فقط
   - **النوع**: `Future<void>` (لا يعيد شيء)
   - **متى تستخدم؟**: عند الضغط على "Delete"

#### لماذا Interface (واجهة) وليس Class؟

- **Interface**: تحدد **ماذا** نريد (العمليات)
- **Implementation**: تحدد **كيف** ننفذ (الكود الفعلي)

**الفائدة**: يمكن تغيير طريقة التنفيذ (مثلاً: من API إلى Database) دون تغيير الكود الذي يستخدم Repository.

---

## 🔍 الجزء الثالث: Data Layer - شرح تفصيلي

### 1. ContactModel (نموذج البيانات)

#### ما هو Model؟

**Model** هو نسخة من Entity تعرف كيف تتعامل مع JSON (البيانات من API).

```dart
// lib/data/models/contact_model.dart
class ContactModel extends Contact {
  ContactModel({
    super.id,
    required super.firstName,
    required super.lastName,
    required super.phoneNumber,
    super.photoUrl,
    super.isInDeviceContacts,
  });
}
```

#### لماذا `extends Contact`؟

- **`extends`**: يعني ContactModel **يرث** من Contact
- **الفائدة**: ContactModel **هو** Contact + وظائف إضافية (fromJson, toJson)

#### fromJson - تحويل من JSON إلى Model

```dart
factory ContactModel.fromJson(Map<String, dynamic> json) {
  return ContactModel(
    id: json['id']?.toString(),
    firstName: json['firstName'] ?? json['first_name'] ?? '',
    lastName: json['lastName'] ?? json['last_name'] ?? '',
    phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
    photoUrl: json['profileImageUrl'] ?? json['photoUrl'] ?? json['photo_url'],
    isInDeviceContacts: json['isInDeviceContacts'] ?? false,
  );
}
```

#### شرح سطر بسطر:

1. **`factory ContactModel.fromJson(...)`**:
   - **factory**: نوع خاص من constructor
   - **الوظيفة**: إنشاء ContactModel من JSON

2. **`id: json['id']?.toString()`**:
   - **`json['id']`**: جلب قيمة 'id' من JSON
   - **`?`**: إذا كان null، لا نستدعي toString
   - **`toString()`**: تحويل إلى String (قد يكون رقم في JSON)

3. **`firstName: json['firstName'] ?? json['first_name'] ?? ''`**:
   - **`json['firstName']`**: جرب هذا الحقل أولاً
   - **`??`**: إذا كان null، جرب التالي
   - **`json['first_name']`**: جرب هذا الحقل (صيغة مختلفة)
   - **`?? ''`**: إذا كان كلاهما null، استخدم string فارغ

**لماذا عدة أسماء؟** لأن API قد يستخدم `firstName` أو `first_name` أو `first-name`.

4. **`photoUrl: json['profileImageUrl'] ?? json['photoUrl'] ?? json['photo_url']`**:
   - نفس الفكرة: جرب عدة أسماء
   - **الأولوية**: `profileImageUrl` (الصحيح من API) ثم البدائل

#### toJson - تحويل من Model إلى JSON

```dart
Map<String, dynamic> toJson() {
  return {
    if (id != null) 'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'phoneNumber': phoneNumber,
    if (photoUrl != null) 'profileImageUrl': photoUrl,
  };
}
```

#### شرح سطر بسطر:

1. **`if (id != null) 'id': id`**:
   - **شرط**: إذا كان id موجود، أضفه
   - **لماذا؟** لأن جهة الاتصال الجديدة لا يوجد لها id

2. **`'profileImageUrl': photoUrl`**:
   - **مهم**: نرسل `profileImageUrl` وليس `photoUrl`
   - **لماذا؟** لأن API يتوقع `profileImageUrl`

---

### 2. ContactApiService - التواصل مع API

#### ما هو ApiService؟

**ApiService** هو المسؤول عن إرسال واستقبال البيانات من الخادم.

```dart
// lib/data/datasources/contact_api_service.dart
class ContactApiService {
  late final Dio _dio;
  
  ContactApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: ApiConstants.headers,
    ));
  }
}
```

#### شرح:

1. **`late final Dio _dio`**:
   - **`late`**: يعني سنقوم بتعيين القيمة لاحقاً (في constructor)
   - **`final`**: يعني لا يمكن تغييرها بعد التعيين
   - **`Dio`**: مكتبة لإرسال HTTP requests

2. **`_dio = Dio(BaseOptions(...))`**:
   - **`BaseOptions`**: إعدادات أساسية لجميع الطلبات
   - **`baseUrl`**: الرابط الأساسي (مثلاً: `http://146.59.52.68:11235`)
   - **`headers`**: رؤوس HTTP (مثلاً: ApiKey)

#### Interceptors - إضافة ApiKey تلقائياً

```dart
_dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      print('🚀 Request: ${options.method} ${options.path}');
      print('📤 Headers: ${options.headers}');
      
      // إضافة ApiKey إذا لم يكن موجوداً
      if (!options.headers.containsKey('ApiKey')) {
        options.headers['ApiKey'] = ApiConstants.apiKey;
      }
      
      handler.next(options);  // المتابعة
    },
    onResponse: (response, handler) {
      print('✅ Response: ${response.statusCode} ${response.requestOptions.path}');
      print('📦 Response data: ${response.data}');
      handler.next(response);
    },
    onError: (error, handler) {
      print('❌ Error: ${error.response?.statusCode} ${error.requestOptions.path}');
      handler.reject(error);
    },
  ),
);
```

#### شرح:

1. **`InterceptorsWrapper`**:
   - **الوظيفة**: اعتراض الطلبات قبل إرسالها وبعد استقبالها

2. **`onRequest`**:
   - **متى يتم استدعاؤه؟** قبل إرسال كل request
   - **`options`**: معلومات الطلب (URL, headers, body)
   - **`handler.next(options)`**: المتابعة مع الطلب المعدل

3. **`onResponse`**:
   - **متى يتم استدعاؤه؟** بعد استقبال response ناجح
   - **`response`**: البيانات المستقبلة
   - **الفائدة**: طباعة البيانات للمساعدة في debugging

4. **`onError`**:
   - **متى يتم استدعاؤه؟** عند حدوث خطأ
   - **`error`**: معلومات الخطأ
   - **`handler.reject(error)`**: رفض الطلب وإرجاع الخطأ

#### getAllContacts - جلب جميع جهات الاتصال

```dart
Future<List<ContactModel>> getAllContacts() async {
  try {
    print('🔍 Fetching all contacts...');
    
    final response = await _dio.get(ApiConstants.getAllContacts);
    
    print('📦 Response data type: ${response.data.runtimeType}');
    print('📦 Response data: ${response.data}');
    
    final data = response.data;
    
    // التحقق من نوع البيانات
    if (data is Map<String, dynamic>) {
      // البنية: {success: true, data: {users: [...]}}
      if (data.containsKey('data') && data['data'] is Map) {
        final dataMap = data['data'] as Map<String, dynamic>;
        
        if (dataMap.containsKey('users') && dataMap['users'] is List) {
          final usersList = dataMap['users'] as List;
          print('✅ Found users array in data.users with ${usersList.length} items');
          
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

#### شرح سطر بسطر:

1. **`Future<List<ContactModel>>`**:
   - **Future**: العملية غير متزامنة
   - **List<ContactModel>**: النتيجة ستكون قائمة من ContactModel

2. **`try { ... } catch { ... }`**:
   - **try**: جرب الكود
   - **catch**: إذا حدث خطأ، تعامل معه

3. **`final response = await _dio.get(...)`**:
   - **`await`**: انتظر حتى يكتمل الطلب
   - **`get`**: HTTP GET request
   - **`response`**: البيانات المستقبلة

4. **`if (data is Map<String, dynamic>)`**:
   - **`is`**: تحقق من النوع
   - **`Map<String, dynamic>`**: JSON object

5. **`data.containsKey('data')`**:
   - **`containsKey`**: تحقق إذا كان المفتاح موجود
   - نبحث عن مفتاح 'data'

6. **`dataMap['users'] as List`**:
   - **`as List`**: تحويل إلى List
   - نستخرج القائمة من `data.users`

7. **`.map((json) => ContactModel.fromJson(json))`**:
   - **`map`**: تحويل كل عنصر في القائمة
   - **`json`**: عنصر واحد من القائمة (JSON object)
   - **`ContactModel.fromJson(json)`**: تحويل JSON إلى ContactModel

8. **`.toList()`**:
   - تحويل النتيجة إلى List

9. **`on DioException catch (e)`**:
   - **DioException**: نوع خاص من الأخطاء من Dio
   - **`_handleError(e)`**: معالجة الخطأ وإرجاع رسالة واضحة

#### _uploadImage - رفع الصورة

```dart
Future<String> _uploadImage(File imageFile) async {
  final List<String> fieldNames = ['image', 'photo', 'file', 'upload'];
  DioException? lastError;

  for (String fieldName in fieldNames) {
    try {
      print('🔍 Trying to upload image with field name: $fieldName');
      
      final String fileExtension = ImageUtils.getImageExtension(imageFile.path);
      final String mimeType = fileExtension == '.png' ? 'image/png' : 'image/jpeg';

      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
          contentType: MediaType.parse(mimeType),
        ),
      });

      print('📤 Uploading file: ${imageFile.path.split('/').last} ($mimeType)');
      final response = await _dio.post(
        ApiConstants.uploadImage,
        data: formData,
        options: Options(
          headers: ApiConstants.headersWithoutContentType,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Image uploaded successfully with field: $fieldName');
        print('📦 Upload response: ${response.data}');

        final data = response.data;
        if (data is Map) {
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('imageUrl')) {
              print('✅ Extracted imageUrl: ${dataMap['imageUrl']}');
              return dataMap['imageUrl'] as String;
            }
            // ... محاولات أخرى
          }
        }
        throw Exception('Invalid response format from upload image: $data');
      }
    } on DioException catch (e) {
      lastError = e;
      final statusCode = e.response?.statusCode;
      print('❌ Field name $fieldName failed with $statusCode, trying next...');
      if (statusCode == 400 || statusCode == 404) {
        continue;  // جرب الحقل التالي
      } else {
        rethrow;  // خطأ آخر، أرجعه
      }
    }
  }
  
  if (lastError != null) {
    throw _handleError(lastError);
  }
  throw Exception('Failed to upload image: No valid field name found or unknown error.');
}
```

#### شرح سطر بسطر:

1. **`final List<String> fieldNames = ['image', 'photo', 'file', 'upload']`**:
   - **السبب**: لا نعرف اسم الحقل الصحيح
   - **الحل**: نجرب كل اسم حتى ينجح واحد

2. **`for (String fieldName in fieldNames)`**:
   - **Loop**: لكل اسم في القائمة

3. **`final String mimeType = fileExtension == '.png' ? 'image/png' : 'image/jpeg'`**:
   - **Ternary operator**: إذا كان `.png` استخدم `image/png`، وإلا `image/jpeg`
   - **السبب**: الخادم يحتاج معرفة نوع الملف

4. **`FormData.fromMap({...})`**:
   - **FormData**: نوع خاص من البيانات لرفع الملفات
   - **Multipart**: يعني البيانات مقسمة إلى أجزاء

5. **`MultipartFile.fromFile(...)`**:
   - **الوظيفة**: تحويل الملف إلى format يمكن إرساله
   - **`filename`**: اسم الملف
   - **`contentType`**: نوع الملف (image/png أو image/jpeg)

6. **`headersWithoutContentType`**:
   - **السبب**: Dio يضيف `Content-Type` تلقائياً لـ FormData
   - إذا أضفناه يدوياً، قد يحدث خطأ

7. **`if (statusCode == 400 || statusCode == 404)`**:
   - **400**: Bad Request (اسم الحقل خاطئ)
   - **404**: Not Found
   - **`continue`**: جرب الحقل التالي

8. **`rethrow`**:
   - **الوظيفة**: أعد إرجاع الخطأ
   - **السبب**: إذا كان الخطأ ليس 400 أو 404، لا نستمر

---

### 3. ContactRepositoryImpl - تطبيق Repository

```dart
// lib/data/repositories/contact_repository_impl.dart
class ContactRepositoryImpl implements ContactRepository {
  final ContactApiService _apiService;
  final ContactLocalService _localService;

  ContactRepositoryImpl({
    required ContactApiService apiService,
    required ContactLocalService localService,
  })  : _apiService = apiService,
        _localService = localService;

  @override
  Future<List<Contact>> getAllContacts() async {
    try {
      // محاولة من API أولاً
      final contacts = await _apiService.getAllContacts();
      
      // حفظ في Cache
      await _localService.cacheContacts(contacts);
      
      return contacts;
    } catch (e) {
      // إذا فشل API، جلب من Cache
      print('⚠️ API failed, using cache: $e');
      return _localService.getCachedContacts();
    }
  }
}
```

#### شرح:

1. **`implements ContactRepository`**:
   - **الوظيفة**: تطبيق الواجهة
   - **يعني**: يجب تنفيذ جميع الدوال المذكورة في Interface

2. **`final ContactApiService _apiService`**:
   - **Dependency Injection**: نحقن ApiService
   - **الفائدة**: يمكن اختبار Repository مع ApiService وهمي

3. **`try { ... } catch { ... }`**:
   - **Strategy**: جرب API أولاً
   - **Fallback**: إذا فشل، استخدم Cache
   - **الفائدة**: التطبيق يعمل حتى بدون إنترنت

---

## 🔍 الجزء الرابع: Presentation Layer - شرح تفصيلي

### 1. State Management مع Riverpod

#### ما هو State Management؟

**State Management** هو طريقة لإدارة حالة التطبيق (البيانات، التحميل، الأخطاء).

#### Event-State Pattern

```dart
// lib/presentation/providers/contact_provider.dart

// 1. State (الحالة)
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

  ContactsState copyWith({
    List<Contact>? contacts,
    bool? isLoading,
    String? error,
    Map<String, List<Contact>>? groupedContacts,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      groupedContacts: groupedContacts ?? this.groupedContacts,
    );
  }

  static Map<String, List<Contact>> _groupContacts(List<Contact> contacts) {
    // تجميع أبجدي
    final sorted = contacts..sort((a, b) => a.fullName.compareTo(b.fullName));
    final grouped = <String, List<Contact>>{};
    
    for (var contact in sorted) {
      final firstLetter = contact.firstLetter.toUpperCase();
      grouped.putIfAbsent(firstLetter, () => []).add(contact);
    }
    
    return grouped;
  }
}
```

#### شرح:

1. **`class ContactsState`**:
   - **الوظيفة**: تمثل الحالة الحالية للتطبيق
   - **Immutable**: لا يمكن تغييرها مباشرة (ننشئ نسخة جديدة)

2. **`final List<Contact> contacts`**:
   - **قائمة جهات الاتصال**: البيانات الفعلية

3. **`final bool isLoading`**:
   - **true**: البيانات قيد التحميل (نعرض Loading indicator)
   - **false**: التحميل انتهى

4. **`final String? error`**:
   - **null**: لا يوجد خطأ
   - **String**: رسالة الخطأ

5. **`copyWith({...})`**:
   - **الوظيفة**: إنشاء نسخة جديدة مع تغييرات
   - **الفائدة**: State immutable، ننشئ نسخة جديدة بدلاً من التعديل

6. **`_groupContacts`**:
   - **الوظيفة**: تجميع القائمة أبجدياً
   - **`putIfAbsent`**: إذا كان المفتاح غير موجود، أنشئ قائمة جديدة

#### Notifier (المدير)

```dart
class ContactsNotifier extends StateNotifier<ContactsState> {
  final ContactRepository _repository;

  ContactsNotifier(this._repository) : super(ContactsState());

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final contacts = await _repository.getAllContacts();
      state = state.copyWith(
        contacts: contacts,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createContact(Contact contact, {File? imageFile}) async {
    state = state.copyWith(isLoading: true);
    
    try {
      final created = await _repository.createContact(contact, imageFile: imageFile);
      
      // إضافة للقائمة
      final updatedContacts = [...state.contacts, created];
      state = state.copyWith(
        contacts: updatedContacts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
```

#### شرح:

1. **`extends StateNotifier<ContactsState>`**:
   - **StateNotifier**: نوع من Notifier من Riverpod
   - **`<ContactsState>`**: نوع State الذي نديره

2. **`super(ContactsState())`**:
   - **super**: استدعاء constructor من Parent class
   - **`ContactsState()`**: الحالة الابتدائية (فارغة)

3. **`state = state.copyWith(...)`**:
   - **تحديث State**: ننشئ نسخة جديدة
   - **Reactive**: UI يتحدث تلقائياً

4. **`[...state.contacts, created]`**:
   - **Spread operator**: نسخ القائمة الحالية
   - **`created`**: إضافة العنصر الجديد
   - **السبب**: List immutable، ننشئ قائمة جديدة

#### Provider (المزود)

```dart
final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>(
  (ref) => ContactsNotifier(ref.watch(contactRepositoryProvider)),
);
```

#### شرح:

1. **`StateNotifierProvider`**:
   - **الوظيفة**: إنشاء Notifier وإتاحته للتطبيق
   - **Type**: `<ContactsNotifier, ContactsState>`

2. **`(ref) => ContactsNotifier(...)`**:
   - **Factory function**: دالة تنشئ Notifier
   - **`ref`**: مرجع للوصول إلى providers أخرى

3. **`ref.watch(contactRepositoryProvider)`**:
   - **`watch`**: مراقبة provider آخر
   - **الفائدة**: إذا تغير Repository، Notifier يتحدث تلقائياً

---

### 2. استخدام Provider في Screen

```dart
// lib/presentation/screens/contacts_screen.dart
class ContactsScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    // تحميل البيانات عند فتح الشاشة
    Future.microtask(() => ref.read(contactsProvider.notifier).loadContacts());
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);

    if (contactsState.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (contactsState.error != null) {
      return Center(child: Text('Error: ${contactsState.error}'));
    }

    return ListView.builder(
      itemCount: contactsState.groupedContacts.length,
      itemBuilder: (context, index) {
        // عرض القائمة المجمعة
      },
    );
  }
}
```

#### شرح:

1. **`ConsumerStatefulWidget`**:
   - **الوظيفة**: Widget يمكنه الوصول إلى Providers
   - **الفرق**: عادي `StatefulWidget` لا يمكنه

2. **`ref.watch(contactsProvider)`**:
   - **`watch`**: مراقبة State
   - **Reactive**: إذا تغير State، Widget يعيد البناء تلقائياً

3. **`ref.read(contactsProvider.notifier)`**:
   - **`read`**: قراءة Notifier (لا مراقبة)
   - **`notifier`**: الوصول إلى Notifier (للاستدعاءات)

4. **`Future.microtask(...)`**:
   - **السبب**: `initState` لا يمكنه استخدام async
   - **`microtask`**: تنفيذ بعد انتهاء `initState`

---

## 🎯 الخلاصة

### المفاهيم الأساسية:

1. **Clean Architecture**: فصل الطبقات (Presentation, Domain, Data)
2. **Entity vs Model**: Entity للمنطق، Model للبيانات
3. **Repository Pattern**: واجهة للوصول للبيانات
4. **State Management**: إدارة الحالة مع Riverpod
5. **Dependency Injection**: حقن التبعيات للاختبار

### أفضل الممارسات:

1. ✅ استخدم `try-catch` لكل API call
2. ✅ استخدم `await` للعمليات غير المتزامنة
3. ✅ استخدم `copyWith` لتحديث State
4. ✅ استخدم `watch` للمراقبة، `read` للاستدعاءات
5. ✅ استخدم Logging للمساعدة في debugging

---

**تم إنشاء هذا الشرح التفصيلي بتاريخ: 2025-11-22**

