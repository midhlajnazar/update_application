import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:update_application/update_application.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Update App Demo', home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final UpdateConfig config = UpdateConfig(enableLogging: kDebugMode);
    UpdateApplication.configure(config);
    checkForUpdate();
  }

  Future<void> checkForUpdate() async {
    try {
      final AppUpdateInfo? info = await UpdateApplication.checkForUpdate();
      if (info == null) return;
      final isUpdateAvailable =
          info.updateAvailability == UpdateAvailability.updateAvailable;

      if (isUpdateAvailable) {
        if (Platform.isAndroid) {
          _showUpdateDialog(
            title: 'Update Available',
            content:
                'A new version is available on App Store. Please update to continue',
            onConfirm: () => UpdateApplication.performImmediateUpdate(),
          );
        }

        if (Platform.isIOS && info.appStoreLink != null) {
          final appStoreLink = info.appStoreLink;

          _showUpdateDialog(
            title: 'Update Available',
            content:
                'A new version is available on App Store. Please update to continue',
            onConfirm: () {
              //  final uri = Uri.parse(appStoreLink);
              //   if (await canLaunchUrl(uri)) {
              //     await launchUrl(uri, mode: LaunchMode.externalApplication);
              //   }
              UpdateApplication.openIOSAppStore();
            },
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update check failed: $e');
      }
    }
  }

  void _showUpdateDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // force user to update
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: onConfirm, child: Text('Update'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Update App Example')),
      body: Center(child: Text('Checking for updates...')),
    );
  }
}
