import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mkamesh/screens/formscreens/FileDownload.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FileViewerWidget extends StatelessWidget {
  final String fileUrl;
  final IconData fileIcon;
  final bool isPrivate;

  const FileViewerWidget({
    required this.fileUrl,
    required this.fileIcon,
    this.isPrivate = false,
    Key? key,
  }) : super(key: key);

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    return token;
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      final dio = Dio();
      final fileName = fileUrl.split('/').last;
      final savePath = await _getDownloadPath(fileName);

      final headers = <String, String>{};
      if (isPrivate) {
        headers['Authorization'] = '${await _getAuthToken()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $fileName...')),
      );

      await dio.download(
        fileUrl,
        savePath.path,
        options: Options(headers: headers),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved to ${savePath.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  Future<File> _getDownloadPath(String fileName) async {
    if (Platform.isAndroid) {
      // Use public downloads directory for Android
      final directory = await getDownloadsDirectory();
      return File('${directory?.path}/$fileName');
    } else {
      // For iOS, use documents directory
      final directory = await getApplicationDocumentsDirectory();
      return File('${directory.path}/$fileName');
    }
  }

  Future<void> _openFile(BuildContext context) async {
    try {
      if (isPrivate) {
        final tempPath = (await getTemporaryDirectory()).path;
        final fileName = fileUrl.split('/').last;
        final savePath = '$tempPath/$fileName';

        final dio = Dio();
        await dio.download(
          fileUrl,
          savePath,
          options:
              Options(headers: {'Authorization': '${await _getAuthToken()}'}),
        );

        await OpenFilex.open(savePath);
      } else {
        if (await canLaunch(fileUrl)) {
          await launch(fileUrl);
        } else {
          throw 'Could not open file';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          icon: Icons.open_in_browser,
          label: 'Open',
          onTap: () => _openFile(context),
        ),
        const SizedBox(width: 20),
        // _buildActionButton(
        //   icon: Icons.download,
        //   label: 'Download',
        //   onTap: () => _downloadFile(context),
        // ),
        FileDownloadWidget(fileUrl: fileUrl, fileName: fileUrl.split('/').last)
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.blue),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
