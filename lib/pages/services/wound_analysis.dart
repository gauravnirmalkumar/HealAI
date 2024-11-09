// lib/services/wound_analysis_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class WoundAnalysisService {
  static const String baseUrl = 'http://192.168.1.9:5000';

  static Future<Map<String, dynamic>> analyzeWound(XFile imageFile) async {
    try {
      print('Sending request to: $baseUrl/analyze-wound');
      
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-wound'));
      
      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();
      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.name,
      );
      request.files.add(multipartFile);

      print('Sending image: ${imageFile.name}');
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': 'Failed to analyze wound',
          'status': response.statusCode,
          'message': response.body
        };
      }
    } catch (e) {
      print('Error occurred: $e');
      return {
        'error': 'Error analyzing wound',
        'message': e.toString()
      };
    }
  }
}