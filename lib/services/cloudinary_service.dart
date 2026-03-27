import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "dxzaqavfj"; // Cloud Name from dashboard

  /// Upload image to Cloudinary
  /// Accepts [imageFile] and [presetName]
  /// Returns secure URL as String if success, null if fail
  static Future<String?> uploadImage(File imageFile, String presetName) async {
    try {
      final String url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = presetName; // use passed preset
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = json.decode(respStr);
        return data['secure_url'];
      } else {
        print("Cloudinary Upload Failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Cloudinary Upload Exception: $e");
      return null;
    }
  }
}