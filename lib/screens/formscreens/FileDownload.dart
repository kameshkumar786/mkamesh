import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'database_helper.dart';

class FileDownloadWidget extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const FileDownloadWidget({
    required this.fileUrl,
    required this.fileName,
    Key? key,
  }) : super(key: key);

  @override
  _FileDownloadWidgetState createState() => _FileDownloadWidgetState();
}

class _FileDownloadWidgetState extends State<FileDownloadWidget> {
  late Future<bool> _fileCheckFuture;

  @override
  void initState() {
    super.initState();
    _fileCheckFuture = _checkFileExistence();
  }

  Future<bool> _checkFileExistence() async {
    return await DatabaseHelper().fileExists(widget.fileUrl);
  }

  Future<String> _getDownloadPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/mkamesh/${widget.fileName}';
  }

  Future<void> _downloadFile() async {
    try {
      final dio = Dio();
      final savePath = await _getDownloadPath();

      // Ensure the "mkamesh" directory exists
      final directory = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/mkamesh');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      await dio.download(
        widget.fileUrl,
        savePath,
        onReceiveProgress: (received, total) {
          // Add progress updates here
        },
      );

      // Save to SQLite database
      await DatabaseHelper().insertFileRecord({
        'fileName': widget.fileName,
        'fileUrl': widget.fileUrl,
        'localPath': savePath,
      });

      setState(() {
        _fileCheckFuture = Future.value(true);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _openFile() async {
    final record = await DatabaseHelper().getFileRecord(widget.fileUrl);
    if (record != null) {
      await OpenFilex.open(record['localPath']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _fileCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final fileExists = snapshot.data ?? false;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fileExists)
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: _openFile,
                tooltip: 'Open File',
              )
            else
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _downloadFile,
                tooltip: 'Download File',
              ),
          ],
        );
      },
    );
  }
}
