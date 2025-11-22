class ApiConstants {
  static const String baseUrl = 'http://146.59.52.68:11235';
  static const String apiKey = 'b64f1a7f-f640-49f6-a156-991abf68e8ab';
  static const String swaggerUrl = '$baseUrl/swagger';
  
  // API Endpoints - Based on Swagger documentation
  // Swagger: http://146.59.52.68:11235/swagger
  static const String getAllContacts = '/api/User/GetAll';
  static const String getContact = '/api/User'; // Will append /{id}
  static const String createContact = '/api/User';
  static const String updateContact = '/api/User'; // Will append /{id}
  static const String deleteContact = '/api/User'; // Will append /{id}
  static const String uploadImage = '/api/User/UploadImage';
  
  // Headers
  static Map<String, String> get headers => {
    'accept': 'application/json',
    'ApiKey': apiKey,
    'Content-Type': 'application/json',
  };
  
  // Headers without Content-Type (for FormData)
  static Map<String, String> get headersWithoutContentType => {
    'accept': 'application/json',
    'ApiKey': apiKey,
  };
}

