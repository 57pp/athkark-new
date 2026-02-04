import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for downloading and managing audio files from GitHub
class AudioDownloadService {
  static AudioDownloadService? _instance;
  static AudioDownloadService get instance => _instance ??= AudioDownloadService();

  static const String _audioBaseUrl = 'https://raw.githubusercontent.com/yourusername/athkark-audio/main/audio';
  static const String _audioVersionUrl = 'https://raw.githubusercontent.com/yourusername/athkark-audio/main/version.json';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Audio file definitions
  static const Map<String, String> audioFiles = {
    'adhan.mp3': 'adhan/adhan.mp3',
    'adhan_soft.mp3': 'adhan/adhan_soft.mp3',
    'takbir.mp3': 'takbir/takbir.mp3',
    'tasbih.mp3': 'tasbih/tasbih.mp3',
    'dua.mp3': 'dua/dua.mp3',
  };

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;

    print('✅ Audio Download Service initialized');
  }

  /// Check if audio files are downloaded
  Future<bool> areAudioFilesDownloaded() async {
    if (!_isInitialized) await initialize();

    final directory = await _getAudioDirectory();
    for (final fileName in audioFiles.keys) {
      final file = File('${directory.path}/$fileName');
      if (!await file.exists()) {
        return false;
      }
    }
    return true;
  }

  /// Check if audio files need update
  Future<bool> areAudioFilesUpToDate() async {
    if (!_isInitialized) await initialize();

    try {
      final response = await http.get(Uri.parse(_audioVersionUrl));
      if (response.statusCode == 200) {
        final remoteVersion = jsonDecode(response.body)['version'] as String?;
        final localVersion = _prefs.getString('audio_version');

        return remoteVersion == localVersion;
      }
    } catch (e) {
      print('Error checking audio version: $e');
    }

    return true; // Assume up to date if check fails
  }

  /// Download all audio files
  Future<bool> downloadAudioFiles({
    Function(double)? onProgress,
    Function(String)? onFileDownloaded,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      print('📥 Starting audio files download...');

      final directory = await _getAudioDirectory();
      final totalFiles = audioFiles.length;
      var downloadedFiles = 0;

      for (final entry in audioFiles.entries) {
        final fileName = entry.key;
        final remotePath = entry.value;
        final url = '$_audioBaseUrl/$remotePath';

        print('📥 Downloading: $fileName');

        final success = await _downloadFile(url, fileName, directory);
        if (success) {
          downloadedFiles++;
          onFileDownloaded?.call(fileName);

          final progress = downloadedFiles / totalFiles;
          onProgress?.call(progress);

          print('✅ Downloaded: $fileName (${(progress * 100).round()}%)');
        } else {
          print('❌ Failed to download: $fileName');
          return false;
        }
      }

      // Update version
      await _updateLocalVersion();

      print('✅ All audio files downloaded successfully');
      return true;

    } catch (e) {
      print('❌ Error downloading audio files: $e');
      return false;
    }
  }

  /// Download single file
  Future<bool> _downloadFile(String url, String fileName, Directory directory) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        print('HTTP Error: ${response.statusCode} for $url');
        return false;
      }
    } catch (e) {
      print('Download error for $fileName: $e');
      return false;
    }
  }

  /// Get local audio file path
  Future<String?> getAudioFilePath(String fileName) async {
    if (!_isInitialized) await initialize();

    final directory = await _getAudioDirectory();
    final file = File('${directory.path}/$fileName');

    if (await file.exists()) {
      return file.path;
    }

    return null;
  }

  /// Get audio directory
  Future<Directory> _getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir;
  }

  /// Update local version after successful download
  Future<void> _updateLocalVersion() async {
    try {
      final response = await http.get(Uri.parse(_audioVersionUrl));
      if (response.statusCode == 200) {
        final version = jsonDecode(response.body)['version'] as String?;
        if (version != null) {
          await _prefs.setString('audio_version', version);
        }
      }
    } catch (e) {
      print('Error updating local version: $e');
    }
  }

  /// Delete all downloaded audio files
  Future<void> deleteAudioFiles() async {
    try {
      final directory = await _getAudioDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await _prefs.remove('audio_version');
      print('🗑️ All audio files deleted');
    } catch (e) {
      print('Error deleting audio files: $e');
    }
  }

  /// Get download size estimate
  Future<int?> getDownloadSizeEstimate() async {
    try {
      // This would need to be implemented by checking file sizes from GitHub API
      // For now, return a rough estimate
      return 1024 * 1024 * 5; // 5MB estimate
    } catch (e) {
      return null;
    }
  }
}