import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String cloudName = "dtzjhtowt"; // Thay bằng Cloud Name của bạn
  static const String uploadPreset = "global-chat"; // Cấu hình trên Cloudinary

  static Future<String?> uploadFile(File file, {bool isVideo = false}) async {
    final String apiUrl =
        "https://api.cloudinary.com/v1_1/dtzjhtowt/${isVideo ? 'video' : 'image'}/upload";

    var request = http.MultipartRequest('POST', Uri.parse(apiUrl))
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonResponse["secure_url"]; // Trả về URL ảnh/video trên Cloudinary
    } else {
      print("Upload lỗi: ${jsonResponse['error']['message']}");
      return null;
    }
  }
}
