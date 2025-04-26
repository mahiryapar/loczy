import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadPage extends StatefulWidget {
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  XFile? _mediaFile;
  XFile? _thumbnailFile;
  final TextEditingController _descriptionController = TextEditingController();
  String _privacy = 'public'; // Default privacy
  bool _isUploading = false;
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();
  int _userId = 0;
  String _userNickname = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _privacy = prefs.getString('user_hesap_turu') ?? 'public';
      _userId = prefs.getInt('userId') ?? 0;
      _userNickname = prefs.getString('userNickname') ?? '';
    });
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      // For now, only picking images. Video picking can be added later.
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _mediaFile = pickedFile;
          _errorMessage = ''; // Clear error on new selection
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Medya seçilemedi: $e';
      });
    }
  }

  Future<void> _pickThumbnail(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _thumbnailFile = pickedFile;
          _errorMessage = ''; // Clear error on new selection
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Thumbnail seçilemedi: $e';
      });
    }
  }

  // Reusable file upload function
  Future<String?> _uploadFile(XFile file, String type) async {
    try {
      final apiUrl = await ConfigLoader.apiUrl;
      final bearerToken = await ConfigLoader.bearerToken;
      final uploadUri = Uri.parse('$apiUrl/upload.php');
      // Add parameters specific to post uploads if needed by upload.php
      final uploadUriWithParams = uploadUri.replace(queryParameters: {
        'user_name': _userNickname,
      });

      final request = http.MultipartRequest('POST', uploadUriWithParams)
        ..headers['Authorization'] = 'Bearer $bearerToken'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final responseString = await streamedResponse.stream.bytesToString();
        final responseData = json.decode(responseString);
        if (responseData != null && responseData['file_url'] != null && responseData['file_url'].isNotEmpty) {
          return responseData['file_url'];
        } else {
          throw Exception('Dosya yüklendi ancak URL alınamadı.');
        }
      } else {
        throw Exception('Dosya yükleme hatası: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      print('Upload error for $type: $e');
      setState(() {
        _errorMessage = '$type yüklenirken hata: $e';
      });
      return null;
    }
  }


  Future<void> _submitPost() async {
    if (_mediaFile == null) {
      setState(() => _errorMessage = 'Lütfen bir medya dosyası seçin.');
      return;
    }
    if (_thumbnailFile == null) {
      setState(() => _errorMessage = 'Lütfen bir thumbnail seçin.');
      return;
    }
     if (_descriptionController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Lütfen bir açıklama girin.');
      return;
    }
    if (_userId == 0) {
       setState(() => _errorMessage = 'Kullanıcı bilgileri yüklenemedi, lütfen tekrar deneyin.');
       return;
    }


    setState(() {
      _isUploading = true;
      _errorMessage = '';
    });

    String? mediaUrl;
    String? thumbnailUrl;

    try {
      // 1. Upload Thumbnail
      thumbnailUrl = await _uploadFile(_thumbnailFile!, 'post_thumbnail');
      if (thumbnailUrl == null) {
         // Error message already set in _uploadFile
         setState(() => _isUploading = false);
         return;
      }

      // 2. Upload Media
      mediaUrl = await _uploadFile(_mediaFile!, 'post_media');
       if (mediaUrl == null) {
         // Error message already set in _uploadFile
         setState(() => _isUploading = false);
         // Consider deleting the already uploaded thumbnail if media upload fails
         return;
      }


      // 3. Send Post Data to posts.php
      final apiUrl = await ConfigLoader.apiUrl;
      final postsUri = Uri.parse('$apiUrl/routers/posts.php'); // Adjust endpoint if needed
      final bearerToken = await ConfigLoader.bearerToken;

      final response = await http.post(
        postsUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode({
          'atan_id': _userId,
          'aciklama': _descriptionController.text,
          'video_foto_url': mediaUrl,
          'thumbnail_url': thumbnailUrl,
          'gizlilik_turu': _privacy,
          'konum': 'Konum Bilgisi Eklenecek', // Placeholder for location
          // Add any other required fields for posts.php
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) { // Check for success codes
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' || responseData['status'] == 'created') { // Adjust based on API response
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gönderi başarıyla paylaşıldı!')),
          );
          // Reset form
          setState(() {
            _mediaFile = null;
            _thumbnailFile = null;
            _descriptionController.clear();
            _errorMessage = '';
          });
        } else {
          throw Exception(responseData['message'] ?? 'Gönderi oluşturulamadı.');
        }
      } else {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      print('Submit post error: $e');
      setState(() {
        _errorMessage = 'Gönderi paylaşılırken hata oluştu: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Since this is part of AnaSayfa, we don't use a Scaffold here.
    // Use padding to avoid overlap with the custom AppBar in AnaSayfa.
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 70.0, left: 16.0, right: 16.0, bottom: 16.0), // Adjust top padding as needed
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Gönderi Oluştur', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 20),

          // Media Selection
          Text('Medya Seç', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _mediaFile == null
                ? Center(child: Text('Medya seçilmedi'))
                : Image.file(File(_mediaFile!.path), fit: BoxFit.cover),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickMedia(ImageSource.gallery),
                icon: Icon(Icons.photo_library),
                label: Text('Galeri'),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickMedia(ImageSource.camera),
                icon: Icon(Icons.camera_alt),
                label: Text('Kamera'),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Thumbnail Selection
          Text('Thumbnail Seç', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _thumbnailFile == null
                ? Center(child: Text('Thumbnail\nseçilmedi', textAlign: TextAlign.center,))
                : Image.file(File(_thumbnailFile!.path), fit: BoxFit.cover),
          ),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickThumbnail(ImageSource.gallery),
                icon: Icon(Icons.photo_library),
                label: Text('Galeri'),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickThumbnail(ImageSource.camera),
                icon: Icon(Icons.camera_alt),
                label: Text('Kamera'),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Description
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Açıklama',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          SizedBox(height: 20),

          // Location (Placeholder)
          ListTile(
            leading: Icon(Icons.location_on),
            title: Text('Konum Ekle'),
            subtitle: Text('Yakında eklenecek...'),
            onTap: () {
              // TODO: Implement Google Maps location picker
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Konum özelliği yakında eklenecektir.')),
              );
            },
          ),
          SizedBox(height: 10),

          // Privacy Info
          Text('Gizlilik: Bu gönderi "${_privacy == 'private' ? 'Gizli' : 'Herkese Açık'}" olarak paylaşılacak.', style: TextStyle(color: Colors.grey[700])),
          SizedBox(height: 20),

          // Error Message
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

          // Upload Button
          ElevatedButton(
            onPressed: _isUploading ? null : _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD06100),
              foregroundColor: const Color(0xFFF2E9E9),
              padding: EdgeInsets.symmetric(vertical: 15),
            ),
            child: _isUploading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text('Paylaş'),
          ),
          SizedBox(height: 50), // Add some bottom padding
        ],
      ),
    );
  }
}
