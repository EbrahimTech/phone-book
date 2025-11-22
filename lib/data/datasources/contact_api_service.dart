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

          if (options.data is! FormData) {
            options.headers['Content-Type'] = 'application/json';
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (error, handler) {
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

        if (data is List) {
          return data.map((json) => ContactModel.fromJson(json)).toList();
        } else if (data is Map) {
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map;
            if (dataMap.containsKey('users') && dataMap['users'] is List) {
              final list = dataMap['users'] as List;
              return list.map((json) => ContactModel.fromJson(json)).toList();
            }
          }
          
          if (data.containsKey('data') && data['data'] is List) {
            final list = data['data'] as List;
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
          
          if (data.containsKey('users') && data['users'] is List) {
            final list = data['users'] as List;
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
          
          if (data.containsKey('contacts') && data['contacts'] is List) {
            final list = data['contacts'] as List;
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
          
          if (data.containsKey('results') && data['results'] is List) {
            final list = data['results'] as List;
            return list.map((json) => ContactModel.fromJson(json)).toList();
          }
        }
        
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
      String? photoUrl;
      if (imageFile != null) {
        try {
          photoUrl = await _uploadImage(imageFile);
        } catch (e) {
          // Continue without image - don't fail the entire contact creation
        }
      }

      final contactData = {
        'firstName': contact.firstName,
        'lastName': contact.lastName,
        'phoneNumber': contact.phoneNumber,
        if (photoUrl != null) 'profileImageUrl': photoUrl,
      };
      
      final response = await _dio.post(
        ApiConstants.createContact,
        data: contactData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;

        if (data is Map) {
          if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('firstName') || dataMap.containsKey('id')) {
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

      final fieldNames = ['image', 'file', 'photo', 'upload'];
      
      DioException? lastError;
      
      for (final fieldName in fieldNames) {
        try {
          final formData = FormData.fromMap({
            fieldName: await MultipartFile.fromFile(
              imageFile.path,
              filename: fileName,
            ),
          });
          
          final response = await _dio.post(
            ApiConstants.uploadImage,
            data: formData,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = response.data;
            if (data is Map) {
              if (data.containsKey('data') && data['data'] is Map) {
                final dataMap = data['data'] as Map<String, dynamic>;
                if (dataMap.containsKey('imageUrl')) {
                  return dataMap['imageUrl'] as String;
                } else if (dataMap.containsKey('url')) {
                  return dataMap['url'] as String;
                } else if (dataMap.containsKey('photoUrl')) {
                  return dataMap['photoUrl'] as String;
                }
              }
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
          
          if (statusCode != null && statusCode != 400) {
            throw _handleError(e);
          }
          
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

