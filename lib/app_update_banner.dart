import 'package:flutter/material.dart';
import 'app_update_service.dart';

class AppUpdateBanner extends StatefulWidget {
  const AppUpdateBanner({super.key});

  @override
  State<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends State<AppUpdateBanner> {
  AppUpdateInfo? _info;
  bool _loading = true;

  static const _fitlyOrange = Color(0xFFFF9A00);
  static const _fitlySoftOrange = Color(0xFFFFF4E5);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final info = await AppUpdateService.getEffectiveUpdateInfo();
    if (!mounted) return;

    setState(() {
      _info = info;
      _loading = false;
    });

    // If it's a forced update, show a blocking dialog
    if (info != null && info.isForce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Update required',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: const Text(
                'A new version of Fitly is required to continue using the app.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    AppUpdateService.openStore(info.storeUri);
                  },
                  child: const Text(
                    'UPDATE',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _info == null) {
      return const SizedBox.shrink();
    }

    final info = _info!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: _fitlySoftOrange,
        border: Border(
          bottom: BorderSide(color: _fitlyOrange, width: 0.7),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.system_update,
            size: 18,
            color: _fitlyOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info.isForce
                  ? 'A new version of Fitly is required.'
                  : 'A new Fitly update is available.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // UPDATE button – Fitly orange pill
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: _fitlyOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              AppUpdateService.openStore(info.storeUri);
            },
            child: const Text(
              'Update',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // "Not now" only for soft updates
          if (!info.isForce)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onPressed: () async {
                await AppUpdateService.markVersionDismissed(info.latestVersion);
                if (!mounted) return;
                setState(() {
                  _info = null; // hide banner
                });
              },
              child: const Text(
                'Not now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
