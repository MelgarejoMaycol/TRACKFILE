import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AndroidDownloadPrompt extends StatefulWidget {
  const AndroidDownloadPrompt({super.key});

  static const String pendingAfterLoginKey =
      'show_android_download_prompt_after_login';
  static const String apkPath = 'downloads/trackfile.apk';
  static const String bannerAsset = 'assets/ImagenesAPP/banner_1024x500.png';
  static const String iconAsset = 'assets/ImagenesAPP/icono_512x512.png';
  static const List<String> screenshots = [
    'assets/ImagenesAPP/capturas/captura1.png',
    'assets/ImagenesAPP/capturas/captura2.png',
    'assets/ImagenesAPP/capturas/captura3.png',
    'assets/ImagenesAPP/capturas/captura4.png',
    'assets/ImagenesAPP/capturas/captura5.png',
  ];

  static bool shouldShowForContext(BuildContext context) {
    return kIsWeb;
  }

  static Future<void> precacheImages(BuildContext context) async {
    if (!shouldShowForContext(context)) return;

    await Future.wait([
      precacheImage(const AssetImage(bannerAsset), context),
      precacheImage(const AssetImage(iconAsset), context),
      ...screenshots.map((path) => precacheImage(AssetImage(path), context)),
    ]);
  }

  @override
  State<AndroidDownloadPrompt> createState() => _AndroidDownloadPromptState();
}

class _AndroidDownloadPromptState extends State<AndroidDownloadPrompt> {
  final ScrollController _screenshotsController = ScrollController();

  @override
  void dispose() {
    _screenshotsController.dispose();
    super.dispose();
  }

  Future<void> _downloadApk(BuildContext context) async {
    final uri = Uri.base.resolve(AndroidDownloadPrompt.apkPath);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la descarga del APK.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AndroidDownloadPrompt.shouldShowForContext(context)) {
      return const SizedBox.shrink();
    }

    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.width < 620;
    if (isCompact) {
      return _MobileDownloadPrompt(onDownload: () => _downloadApk(context));
    }

    final sideInset = isCompact ? 8.0 : 24.0;
    final dialogWidth = (screen.width - (sideInset * 2)).clamp(280.0, 860.0);
    final dialogHeight = (screen.height - (sideInset * 2)).clamp(360.0, 760.0);
    final horizontalPadding = isCompact ? 14.0 : 24.0;
    final logoSize = isCompact ? 46.0 : 74.0;
    final bannerHeight = (screen.height * (isCompact ? 0.24 : 0.28)).clamp(
      isCompact ? 124.0 : 190.0,
      isCompact ? 180.0 : 260.0,
    );
    final screenshotHeight = (screen.height * (isCompact ? 0.31 : 0.42)).clamp(
      isCompact ? 210.0 : 300.0,
      isCompact ? 300.0 : 420.0,
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: sideInset,
        vertical: sideInset,
      ),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.white,
            child: Column(
              children: [
                _PromptBanner(
                  bannerHeight: bannerHeight,
                  horizontalPadding: horizontalPadding,
                  isCompact: isCompact,
                  logoSize: logoSize,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isCompact ? 14 : 20,
                      horizontalPadding,
                      isCompact ? 16 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PromptIntro(
                          isCompact: isCompact,
                          onDownload: () => _downloadApk(context),
                        ),
                        SizedBox(height: isCompact ? 18 : 22),
                        SizedBox(
                          height: screenshotHeight + 24,
                          child: Scrollbar(
                            controller: _screenshotsController,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _screenshotsController,
                              padding: const EdgeInsets.only(bottom: 18),
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  AndroidDownloadPrompt.screenshots.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 18),
                              itemBuilder: (context, index) {
                                return AspectRatio(
                                  aspectRatio: 9 / 16,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      isCompact ? 18 : 22,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F5FA),
                                        border: Border.all(
                                          color: const Color(0xFFE2E7F0),
                                        ),
                                      ),
                                      child: Image.asset(
                                        AndroidDownloadPrompt
                                            .screenshots[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptBanner extends StatelessWidget {
  const _PromptBanner({
    required this.bannerHeight,
    required this.horizontalPadding,
    required this.isCompact,
    required this.logoSize,
  });

  final double bannerHeight;
  final double horizontalPadding;
  final bool isCompact;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AndroidDownloadPrompt.bannerAsset, fit: BoxFit.cover),
          Positioned(
            top: 14,
            right: 14,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cerrar',
            ),
          ),
          Positioned(
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: isCompact ? 12 : 20,
            child: Row(
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    AndroidDownloadPrompt.iconAsset,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: isCompact ? 9 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TrackFile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 20 : 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Descarga nuestra aplicacion para Android desde el APK.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 11 : 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: isCompact ? 1 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDownloadPrompt extends StatelessWidget {
  const _MobileDownloadPrompt({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          AndroidDownloadPrompt.iconAsset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Descarga nuestra aplicacion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF06135E),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Instala TrackFile en tu celular Android para gestionar tus documentos desde la app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onDownload,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF06135E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.android_rounded),
                      label: const Text(
                        'Descargar APK',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                  color: const Color(0xFF06135E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptIntro extends StatelessWidget {
  const _PromptIntro({required this.isCompact, required this.onDownload});

  final bool isCompact;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: isCompact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isCompact
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: isCompact ? FlexFit.loose : FlexFit.tight,
          child: Padding(
            padding: EdgeInsets.only(right: isCompact ? 0 : 18),
            child: Text(
              'Instala TrackFile en tu celular y lleva tus documentos, solicitudes y mantenimientos contigo.',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: isCompact ? 14 : 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (isCompact) const SizedBox(height: 14),
        SizedBox(
          width: isCompact ? double.infinity : null,
          child: FilledButton.icon(
            onPressed: onDownload,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF06135E),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : 20,
                vertical: isCompact ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.android_rounded),
            label: const Text('Descargar APK', overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}
