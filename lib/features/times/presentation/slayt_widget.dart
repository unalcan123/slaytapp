import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // ✅ gerekli
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/presentation/alert_settings_controller.dart';

class SlaytWidget extends ConsumerStatefulWidget {
  final double height;
  final int currentIndex;
  final Function(int)? onPageChanged;
  final List<String>? userImages;

  /// ✅ Portrait (dikey) olunca slaytı gizle (geri sayım tek başına kalsın)
  final bool hideOnPortrait;

  const SlaytWidget({
    super.key,
    this.userImages,
    required this.height,
    this.currentIndex = 0,
    this.onPageChanged,
    this.hideOnPortrait = false, // ✅ default
  });

  @override
  ConsumerState<SlaytWidget> createState() => _SlaytWidgetState();
}

class _SlaytWidgetState extends ConsumerState<SlaytWidget> {
  List<String> assetImages = [];
  List<String> userImages = [];
  bool isLoading = true;

  int _initialPage = 0;
  bool _initialPageLoaded = false;

  // ✅ Web storage (IndexedDB) - Hive box
  Box get _webBox => Hive.box('web_user_images');

  final CarouselSliderController _carouselController = CarouselSliderController();

  String _getEffectiveCategory(String category) {
    if (category == 'Kullanıcı Foto') return 'user';
    if (category == 'Genel Resimler') return 'resim';
    if (category == 'Hadis-i Şerifler') return 'hadis';
    if (category == 'Dualar') return 'dua';
    if (category == 'Besmele') return 'besmele';
    if (category == 'Namaz Bilgileri') return 'namaz';
    if (category == 'Ramazan') return 'ramazan';
    return category;
  }

  String _webKey(String category) {
    final cat = _getEffectiveCategory(category);
    return 'userImages_$cat';
  }

  /// ✅ WEB: Kaydet (bytes -> base64 list)
  Future<void> addUserImagesWeb(String category) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final key = _webKey(category);
    final List existing = (_webBox.get(key) as List?) ?? [];

    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      existing.add(base64Encode(bytes));
    }

    await _webBox.put(key, existing);

    // ✅ slaytı güncelle
    await _loadUserImages(category);

    // ✅ başka widget'lar da dinliyorsa tetikle (opsiyonel ama iyi)
    ref.read(alertSettingsProvider.notifier).triggerRefresh();
  }

  /// ✅ WEB: Oku
  Future<List<String>> _loadUserImagesWeb(String category) async {
    final key = _webKey(category);
    final List list = (_webBox.get(key) as List?) ?? [];
    return list.map((e) => 'base64:$e').cast<String>().toList();
  }

  String _pageKey(String category) {
    final cat = _getEffectiveCategory(category);
    return 'slayt_last_index_$cat';
  }

  Future<void> _loadLastPage(String category) async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getInt(_pageKey(category)) ?? 0;

    if (!mounted) return;
    setState(() {
      _initialPage = saved;
      _initialPageLoaded = true;
    });
  }

  Future<void> _saveLastPage(String category, int index) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_pageKey(category), index);
  }

  List<String> _getAllImages(String category) {
    if (category == 'Kullanıcı Foto') return userImages;
    return [...assetImages, ...userImages];
  }

  @override
  void initState() {
    super.initState();

    // ✅ İlk yükleme
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final category = ref.read(alertSettingsProvider).slideCategory;
      await _loadLastPage(category);
      await _loadAllImages(category);
    });

    // ✅ Ayar değişince yeniden yükle
    ref.listenManual(alertSettingsProvider, (prev, next) async {
      if (prev == null) return;

      if (prev.slideCategory != next.slideCategory ||
          prev.lastUpdate != next.lastUpdate) {
        setState(() => _initialPageLoaded = false);
        await _loadLastPage(next.slideCategory);
        await _loadAllImages(next.slideCategory);
      }
    });
  }

  Future<void> _loadAllImages(String category) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    if (category != 'Kullanıcı Foto') {
      await _loadAssetImages(category);
    } else {
      assetImages = [];
    }

    await _loadUserImages(category);

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadAssetImages(String category) async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final cat = _getEffectiveCategory(category).toLowerCase();
      final patternA = 'assets/resim/$cat/';
      final patternB = 'resim/$cat/';

      final images = manifestMap.keys.where((key) {
        final k = key.toLowerCase();
        final okFolder = k.contains(patternA) || k.contains(patternB);
        final okExt = k.endsWith('.jpg') ||
            k.endsWith('.jpeg') ||
            k.endsWith('.png') ||
            k.endsWith('.webp');
        return okFolder && okExt;
      }).toList();

      if (mounted) setState(() => assetImages = images);
    } catch (e) {
      debugPrint("Asset yükleme hatası: $e");
    }
  }

  Future<void> _loadUserImages(String category) async {
    try {
      if (kIsWeb) {
        final imgs = await _loadUserImagesWeb(category);
        if (mounted) setState(() => userImages = imgs);
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final cat = _getEffectiveCategory(category);
      final categoryDir = Directory('${appDir.path}/userImages/$cat');

      if (await categoryDir.exists()) {
        final imageFiles = categoryDir
            .listSync()
            .where((f) {
          final p = f.path.toLowerCase();
          return p.endsWith('.jpg') ||
              p.endsWith('.jpeg') ||
              p.endsWith('.png') ||
              p.endsWith('.webp');
        })
            .map((f) => f.path)
            .toList();

        if (mounted) setState(() => userImages = imageFiles);
      } else {
        if (mounted) setState(() => userImages = []);
      }
    } catch (e) {
      debugPrint("Kullanıcı resimleri yükleme hatası: $e");
    }
  }

  ImageProvider _getImageProvider(String path) {
    final p = path.toLowerCase();

    if (p.startsWith('base64:')) {
      final b64 = path.substring('base64:'.length);
      final bytes = base64Decode(b64);
      return MemoryImage(Uint8List.fromList(bytes));
    }

    final isAsset = p.startsWith('assets/') ||
        p.startsWith('resim/') ||
        p.contains('/resim/') ||
        p.startsWith('images/') ||
        p.contains('/images/');

    if (isAsset) return AssetImage(path);

    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Portrait’te slaytı gizle (geri sayım tek başına kalsın)
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    if (widget.hideOnPortrait && isPortrait) {
      return const SizedBox.shrink();
    }

    final settings = ref.watch(alertSettingsProvider);
    final allImages = _getAllImages(settings.slideCategory);

    return LayoutBuilder(
      builder: (context, constraints) {
        final actualHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : (widget.height > 0 ? widget.height : MediaQuery.sizeOf(context).height);

        final safeInitialPage =
        (allImages.isNotEmpty && _initialPage < allImages.length) ? _initialPage : 0;

        return Container(
          color: Colors.black,
          width: double.infinity,
          height: actualHeight,
          child: (isLoading || !_initialPageLoaded)
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : allImages.isNotEmpty
              ? CarouselSlider.builder(
            key: ValueKey(
              '${settings.slideCategory}_${settings.lastUpdate}_${allImages.length}_$safeInitialPage',
            ),
            carouselController: _carouselController,
            itemCount: allImages.length,
            itemBuilder: (context, index, realIdx) {
              final imagePath = allImages[index];
              return ClipRect(
                child: SizedBox(
                  width: double.infinity,
                  height: actualHeight,
                  child: _SmartFittedImage(
                    provider: _getImageProvider(imagePath),
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: actualHeight,
              viewportFraction: 1.0,
              initialPage: safeInitialPage,
              enlargeCenterPage: false,
              autoPlay: allImages.length > 1,
              autoPlayInterval: Duration(
                seconds: settings.slideDuration > 0 ? settings.slideDuration : 15,
              ),
              autoPlayAnimationDuration: const Duration(milliseconds: 1200),
              scrollPhysics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i, reason) {
                widget.onPageChanged?.call(i);
                _saveLastPage(settings.slideCategory, i);
              },
            ),
          )
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_not_supported_outlined,
                    color: Colors.white24, size: 48),
                const SizedBox(height: 8),
                Text(
                  "Görsel bulunamadı: ${settings.slideCategory}",
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SmartFittedImage extends StatefulWidget {
  const _SmartFittedImage({required this.provider});
  final ImageProvider provider;

  @override
  State<_SmartFittedImage> createState() => _SmartFittedImageState();
}

class _SmartFittedImageState extends State<_SmartFittedImage> {
  double? _imageRatio;

  @override
  void initState() {
    super.initState();
    _resolveRatio();
  }

  @override
  void didUpdateWidget(covariant _SmartFittedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      _imageRatio = null;
      _resolveRatio();
    }
  }

  void _resolveRatio() {
    final stream = widget.provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;

    listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted) setState(() => _imageRatio = (h == 0) ? null : (w / h));
      stream.removeListener(listener);
    }, onError: (_, __) {
      stream.removeListener(listener);
    });

    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final screenRatio = c.maxWidth / c.maxHeight;
        final imgRatio = _imageRatio;

        final fit = (imgRatio != null && (imgRatio - screenRatio).abs() < 0.35)
            ? BoxFit.cover
            : BoxFit.contain;

        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: Image(
              image: widget.provider,
              fit: fit,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.error, color: Colors.white24)),
            ),
          ),
        );
      },
    );
  }
}