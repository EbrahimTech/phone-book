import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../models/contact_model.dart';

class ContactApiService {
  final Dio _dio;

  ContactApiService() : _dio = Dio() {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add interceptors for logging and headers
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add headers (but not Content-Type for FormData)
          // ApiKey must appear in header (as per Swagger documentation)
          options.headers.addAll({
            'accept': 'application/json',
            'ApiKey': ApiConstants.apiKey, // Case-sensitive: ApiKey (not apiKey or API_KEY)
          });

          // Only add Content-Type if not FormData
          if (options.data is! FormData) {
            options.headers['Content-Type'] = 'application/json';
          }

          print(
            '🚀 Request: ${options.method} ${options.baseUrl}${options.path}',
          );
          print('📤 Headers: ${options.headers}');
          if (options.data != null && options.data is! FormData) {
            print('📦 Body: ${options.data}');
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          print(
            '✅ Response: ${response.statusCode} ${response.requestOptions.path}',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          print(
            '❌ Error: ${error.response?.statusCode} ${error.requestOptions.path}',
          );
          print('Error details: ${error.response?.data}');
          handler.next(error);
        },
      ),
    );
  }

  /// Get all contacts
  Future<List<ContactModel>> getAllContacts() async {
    try {
      final response = await _dio.get(ApiConstants.getAllContacts);

      if (response.statusCode == 200) {
        final data = response.data;
        
        print('📦 Response data type: ${data.runtimeType}');
        print('📦 Response data: $data');

        if (data is List) {
          print('✅ Response is a List with ${data.length} items');
          final contacts = data.map((json) {
            print('📝 Parsing contact: $json');
            return ContactModel.fromJson(json);
          }).toList();
          print('✅ Parsed ${contacts.length} contacts');
          return contacts;
        } else if (data is Map) {
          print('📋 Response is a Map with keys: ${data.keys}');
          
          // Try different response formats
          // Format 1: {success: true, data: {users: [...]}}
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map;
            if (dataMap.containsKey('users') && dataMap['users'] is List) {
              final list = dataMap['users'] as List;
              print(
                '✅ Found users array in data.users with ${list.length} items',
              );
              return list.map((json) => ContactModel.fromJson(json)).toList();
            }
          }
          
          // Format 2: {data: [...]}
          if (data.containsKey('data') && data['data'] is List) {
            final list = data['data'] as List;
            print('✅ Found data array with ${list.length} items');
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
          
          // Format 3: {users: [...]}
          if (data.containsKey('users') && data['users'] is List) {
            final list = data['users'] as List;
            print('✅ Found users array with ${list.length} items');
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
          
          // Format 4: {contacts: [...]}
          if (data.containsKey('contacts') && data['contacts'] is List) {
            final list = data['contacts'] as List;
            print('✅ Found contacts array with ${list.length} items');
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
          
          // Format 5: {results: [...]}
          if (data.containsKey('results') && data['results'] is List) {
            final list = data['results'] as List;
            print('✅ Found results array with ${list.length} items');
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
          
          print('⚠️ Map does not contain expected array fields');
          print('Available keys: ${data.keys}');
        } else {
          print('⚠️ Unexpected response type: ${data.runtimeType}');
        }
        
        print('⚠️ Returning empty list');
        return [];
      }
      throw Exception('Failed to load contacts: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get contact by ID
  Future<ContactModel> getContactById(String id) async {
    try {
      final response = await _dio.get('${ApiConstants.getContact}/$id');

      if (response.statusCode == 200) {
        final data = response.data;
        print('📦 Get contact response: $data');
        
        // Handle different response formats
        if (data is Map) {
          // Format: {success: true, data: {user: {...}}}
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('user')) {
              return ContactModel.fromJson(
                dataMap['user'] as Map<String, dynamic>,
              );
            }
          }
          // Format: direct user object
          return ContactModel.fromJson(data as Map<String, dynamic>);
        }
        
        return ContactModel.fromJson(response.data);
      }
      throw Exception('Failed to load contact: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create new contact
  Future<ContactModel> createContact(
    ContactModel contact, {
    File? imageFile,
  }) async {
    try {
      // If there's an image, try to upload it first
      // If upload fails, continue without image
      String? photoUrl;
      if (imageFile != null) {
        try {
          photoUrl = await _uploadImage(imageFile);
        } catch (e) {
          print('⚠️ Failed to upload image, continuing without image: $e');
          // Continue without image - don't fail the entire contact creation
        }
      }

      // Create contact data
      // Note: API uses profileImageUrl based on response structure
      final contactData = {
        'firstName': contact.firstName,
        'lastName': contact.lastName,
        'phoneNumber': contact.phoneNumber,
        if (photoUrl != null) 'profileImageUrl': photoUrl,
      };

      print('📤 Creating contact with data: $contactData');
      
      final response = await _dio.post(
        ApiConstants.createContact,
        data: contactData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('📦 Create response data: ${response.data}');
        final data = response.data;

        // Handle different response formats
        // Expected format: {success: true, data: {id, firstName, lastName, phoneNumber, profileImageUrl}, status: 200}
        if (data is Map) {
          // Format: {success: true, data: {...}} - data contains user object directly
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            // Check if data contains user fields directly (not nested in 'user')
            if (dataMap.containsKey('firstName') || dataMap.containsKey('id')) {
              print('✅ Found user data directly in data object');
              return ContactModel.fromJson(dataMap);
            } else if (dataMap.containsKey('user')) {
              return ContactModel.fromJson(
                dataMap['user'] as Map<String, dynamic>,
              );
            } else if (dataMap.containsKey('users') &&
                dataMap['users'] is List &&
                (dataMap['users'] as List).isNotEmpty) {
              return ContactModel.fromJson(
                (dataMap['users'] as List).first as Map<String, dynamic>,
              );
            }
          }
          // Format: direct user object (fallback)
          if (data.containsKey('firstName') || data.containsKey('id')) {
            return ContactModel.fromJson(data as Map<String, dynamic>);
          }
        }

        return ContactModel.fromJson(response.data);
      }
      throw Exception('Failed to create contact: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update contact
  Future<ContactModel> updateContact(
    ContactModel contact, {
    File? imageFile,
  }) async {
    try {
      if (contact.id == null) {
        throw Exception('Contact ID is required for update');
      }

      // If there's an image, upload it first
      String? photoUrl = contact.photoUrl;
      if (imageFile != null) {
        photoUrl = await _uploadImage(imageFile);
      }

      // Update contact data
      // Note: API uses profileImageUrl
      final updateData = {
        'firstName': contact.firstName,
        'lastName': contact.lastName,
        'phoneNumber': contact.phoneNumber,
        if (photoUrl != null) 'profileImageUrl': photoUrl,
      };

      final response = await _dio.put(
        '${ApiConstants.updateContact}/${contact.id}',
        data: updateData,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print('📦 Update response: $data');
        
        // Handle different response formats
        if (data is Map) {
          // Format: {success: true, data: {...}}
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('firstName') || dataMap.containsKey('id')) {
              return ContactModel.fromJson(dataMap);
            } else if (dataMap.containsKey('user')) {
              return ContactModel.fromJson(
                dataMap['user'] as Map<String, dynamic>,
              );
            }
          }
          // Format: direct user object
          if (data.containsKey('firstName') || data.containsKey('id')) {
            return ContactModel.fromJson(data as Map<String, dynamic>);
          }
        }
        
        return ContactModel.fromJson(response.data);
      }
      throw Exception('Failed to update contact: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete contact
  Future<void> deleteContact(String id) async {
    try {
      final response = await _dio.delete('${ApiConstants.deleteContact}/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete contact: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload image
  Future<String> _uploadImage(File imageFile) async {
    try {
      // Validate file exists and is readable
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Get file extension and ensure it's valid
      final fileName = imageFile.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      
      if (extension != 'png' && extension != 'jpg' && extension != 'jpeg') {
        throw Exception('Invalid file format. Only PNG and JPG are allowed.');
      }

      // Try different field names that might be expected by the API
      // Based on testing, 'image' works, so we'll try it first
      final fieldNames = ['image', 'file', 'photo', 'upload'];
      
      DioException? lastError;
      
      for (final fieldName in fieldNames) {
        try {
          print('🖼️ Trying to upload image with field name: $fieldName');
          
          final contentType = extension == 'png' 
              ? 'image/png'
              : 'image/jpeg';
          
          final formData = FormData.fromMap({
            fieldName: await MultipartFile.fromFile(
              imageFile.path,
              filename: fileName,
            ),
          });
          
          // Set content type header
          print('📤 Uploading file: $fileName (${contentType})');
          
          final response = await _dio.post(
            ApiConstants.uploadImage,
            data: formData,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            print('✅ Image uploaded successfully with field: $fieldName');
            print('📦 Upload response: ${response.data}');
            
            // Handle different response formats
            // Expected format: {success: true, data: {imageUrl: "..."}, status: 200}
            final data = response.data;
            if (data is Map) {
              // Format: {success: true, data: {imageUrl: "..."}}
              if (data.containsKey('data') && data['data'] is Map) {
                final dataMap = data['data'] as Map<String, dynamic>;
                if (dataMap.containsKey('imageUrl')) {
                  final imageUrl = dataMap['imageUrl'] as String;
                  print('✅ Extracted imageUrl: $imageUrl');
                  return imageUrl;
                } else if (dataMap.containsKey('url')) {
                  return dataMap['url'] as String;
                } else if (dataMap.containsKey('photoUrl')) {
                  return dataMap['photoUrl'] as String;
                }
              }
              // Format: direct fields (fallback)
              if (data.containsKey('imageUrl')) {
                return data['imageUrl'] as String;
              } else if (data.containsKey('url')) {
                return data['url'] as String;
              } else if (data.containsKey('photoUrl')) {
                return data['photoUrl'] as String;
              }
            } else if (data is String) {
              return data;
            }
            throw Exception('Invalid response format from upload image: $data');
          }
        } on DioException catch (e) {
          lastError = e;
          final statusCode = e.response?.statusCode;
          
          // If it's not 400 (InvalidFile), it might be a different error
          if (statusCode != null && statusCode != 400) {
            throw _handleError(e);
          }
          
          // If 400, try next field name
          print('⚠️ Field name $fieldName failed with 400, trying next...');
          continue;
        }
      }
      
      // If all field names failed, throw the last error
      if (lastError != null) {
        throw _handleError(lastError);
      }
      
      throw Exception('Failed to upload image: All field names failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      final requestPath = e.requestOptions.path;
      final baseUrl = e.requestOptions.baseUrl;

      String errorMessage = 'API Error: $statusCode';

      if (data != null) {
        if (data is Map && data.containsKey('message')) {
          errorMessage += ' - ${data['message']}';
        } else if (data is String) {
          errorMessage += ' - $data';
        } else {
          errorMessage += ' - ${data.toString()}';
        }
      }

      errorMessage += '\nRequest: $baseUrl$requestPath';

      return Exception(errorMessage);
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return Exception(
        'Connection timeout. Please check your internet connection.',
      );
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return Exception('Receive timeout. Please try again.');
    } else if (e.type == DioExceptionType.connectionError) {
      return Exception(
        'Connection error. Please check your internet connection and API URL.',
      );
    } else {
      return Exception('Network error: ${e.message}');
    }
  }
}

