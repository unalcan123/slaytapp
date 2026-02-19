import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../settings/presentation/alert_settings_controller.dart';

class SlaytWidget extends ConsumerStatefulWidget {
  final double height;
  final int currentIndex;
  final Function(int)? onPageChanged;
  final List<String>? userImages;

  const SlaytWidget({
    super.key,
    this.userImages,
    required this.height,
    this.currentIndex = 0,
    this.onPageChanged,
  });

  @override
  ConsumerState<SlaytWidget> createState() => _SlaytWidgetState();
}

class _SlaytWidgetState extends ConsumerState<SlaytWidget> {
  List<String> assetImages = [];
  bool isLoading = true;
  final CarouselSliderController _carouselController = CarouselSliderController();
  List<String> userImages = [];

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

  List<String> _getAllImages(String category) {
    if (category == 'Kullanıcı Foto') {
      return userImages;
    }
    return [...assetImages, ...userImages];
  }

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  void _initialLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final category = ref.read(alertSettingsProvider).slideCategory;
        _loadAllImages(category);
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

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAssetImages(String category) async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      final cat = _getEffectiveCategory(category);
      
      final searchPattern = 'resim/$cat/'.toLowerCase();

      final images = manifestMap.keys
          .where((String key) {
            final lowerKey = key.toLowerCase();
            return lowerKey.contains(searchPattern) &&
                (lowerKey.endsWith('.jpg') ||
                 lowerKey.endsWith('.jpeg') ||
                 lowerKey.endsWith('.png') ||
                 lowerKey.endsWith('.webp') ||
                 lowerKey.endsWith('.JPG'));
          })
          .toList();

      if (mounted) {
        setState(() {
          assetImages = images;
        });
      }
    } catch (e) {
      debugPrint("Asset yükleme hatası: $e");
    }
  }

  Future<void> _loadUserImages(String category) async {
    if (kIsWeb) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cat = _getEffectiveCategory(category);
      final categoryDir = Directory('${appDir.path}/userImages/$cat');
      if (await categoryDir.exists()) {
        final imageFiles = categoryDir
            .listSync()
            .where((f) {
              final path = f.path.toLowerCase();
              return path.endsWith('.jpg') ||
                     path.endsWith('.jpeg') ||
                     path.endsWith('.png');
            })
            .map((f) => f.path)
            .toList();

        if (mounted) {
          setState(() {
            userImages = imageFiles;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            userImages = [];
          });
        }
      }
    } catch (e) {
      debugPrint("Kullanıcı resimleri yükleme hatası: $e");
    }
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    } else {
      if (kIsWeb) return NetworkImage(path);
      return FileImage(File(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(alertSettingsProvider);
    
    ref.listen(alertSettingsProvider, (prev, next) {
      if (prev?.slideCategory != next.slideCategory || prev?.lastUpdate != next.lastUpdate) {
        _loadAllImages(next.slideCategory);
      }
    });

    final allImages = _getAllImages(settings.slideCategory);

    return LayoutBuilder(
      builder: (context, constraints) {
        final actualHeight =
        constraints.maxHeight > 0 ? constraints.maxHeight : 300.0;

        return Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
              : allImages.isNotEmpty
              ? CarouselSlider.builder(
            key: ValueKey(
              '${settings.slideCategory}_${settings.slideDuration}_${settings.lastUpdate}_${allImages.length}',
            ),
            carouselController: _carouselController,
            itemCount: allImages.length,
            itemBuilder: (context, index, realIdx) {
              final imagePath = allImages[index];

              return SizedBox.expand(
                child: _SmartFittedImage(
                  provider: _getImageProvider(imagePath),
                ),
              );
            },
            options: CarouselOptions(
              height: actualHeight,
              viewportFraction: 1.0,
              initialPage: 0,
              enlargeCenterPage: false,
              autoPlay: allImages.length > 1,
              autoPlayInterval: Duration(
                seconds: settings.slideDuration > 0
                    ? settings.slideDuration
                    : 15,
              ),
              autoPlayAnimationDuration:
              const Duration(milliseconds: 1200),
              scrollPhysics: const NeverScrollableScrollPhysics(),
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
/// ✅ Resmin gerçek oranını okuyup (width/height) TV’de en iyi fit’i seçer.
/// - Çok yatay (16:9 gibi) => cover (tam ekran, az crop)
/// - Dikey/kare => contain (zoom/crop olmasın)
class _SmartFittedImage extends StatefulWidget {
  const _SmartFittedImage({required this.provider});

  final ImageProvider provider;

  @override
  State<_SmartFittedImage> createState() => _SmartFittedImageState();
}

class _SmartFittedImageState extends State<_SmartFittedImage> {
  double? _imageRatio; // width / height

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
      if (mounted) {
        setState(() => _imageRatio = (h == 0) ? null : (w / h));
      }
      stream.removeListener(listener);
    }, onError: (e, st) {
      stream.removeListener(listener);
    });

    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final screenRatio = c.maxWidth / c.maxHeight;

        // Oran henüz gelmediyse güvenli başlangıç:
        final imgRatio = _imageRatio;

        // ✅ Karar mantığı:
        // - Resim ekran oranına yakınsa => cover
        // - Çok farklıysa (dikey/kare) => contain (zoom/crop olmasın)
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
              // Web’de bazen filtre/örnekleme farkı yapıyor, iyileştirir:
              isAntiAlias: true,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.error, color: Colors.white24),
              ),
            ),
          ),
        );
      },
    );
  }
}