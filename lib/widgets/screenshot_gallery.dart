import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../l10n/app_localizations.dart';

class ScreenshotGallery extends StatelessWidget {
  const ScreenshotGallery({required this.urls, super.key});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ScreenshotThumbnail(
          url: urls[index],
          onTap: () => _showScreenshot(context, index),
        ),
      ),
    );
  }

  void _showScreenshot(BuildContext context, int index) {
    showDialog<void>(
      context: context,
      builder: (_) => ScreenshotViewer(urls: urls, initialIndex: index),
    );
  }
}

class ScreenshotThumbnail extends StatefulWidget {
  const ScreenshotThumbnail({
    required this.url,
    required this.onTap,
    super.key,
  });
  final String url;
  final VoidCallback onTap;

  @override
  State<ScreenshotThumbnail> createState() => _ScreenshotThumbnailState();
}

class _ScreenshotThumbnailState extends State<ScreenshotThumbnail> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double _aspectRatio = 1;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant ScreenshotThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _removeImageListener();
      _aspectRatio = 1;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final stream = NetworkImage(widget.url).resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      final image = info.image;
      if (!mounted || image.height == 0) return;
      final ratio = image.width / image.height;
      if ((ratio - _aspectRatio).abs() > .01) {
        setState(() => _aspectRatio = ratio);
      }
    });
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _imageStream = null;
    _imageListener = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = (190 * _aspectRatio).clamp(112.0, 360.0);
    return SizedBox(
      width: width,
      height: 190,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}

class ScreenshotViewer extends StatefulWidget {
  const ScreenshotViewer({
    required this.urls,
    required this.initialIndex,
    super.key,
  });
  final List<String> urls;
  final int initialIndex;

  @override
  State<ScreenshotViewer> createState() => _ScreenshotViewerState();
}

class _ScreenshotViewerState extends State<ScreenshotViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_currentIndex + 1} / ${widget.urls.length}'),
          actions: [
            IconButton(
              tooltip: AppLocalizations.of(context).saveImage,
              onPressed: _saving ? null : _saveCurrent,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_outlined),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).close,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: PhotoViewGallery.builder(
          pageController: _pageController,
          itemCount: widget.urls.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          builder: (context, index) => PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(widget.urls[index]),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * .8,
            maxScale: PhotoViewComputedScale.covered * 3,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrent() async {
    final strings = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final response = await http.get(Uri.parse(widget.urls[_currentIndex]));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          strings.imageRequestFailed(response.statusCode.toString()),
        );
      }
      await Gal.putImageBytes(
        response.bodyBytes,
        album: 'APK Mesh',
        name: _imageName(widget.urls[_currentIndex], _currentIndex),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).imageSaved)),
      );
    } on GalException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).imageSaveFailed((error.toString()).toString()),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).imageSaveFailed((error).toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _imageName(String url, int index) {
    final path = Uri.tryParse(url)?.path ?? '';
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final last = parts.isEmpty ? null : parts.last;
    final base = (last ?? '')
        .replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return base.isEmpty ? 'apkmesh_screenshot_${index + 1}' : 'apkmesh_$base';
  }
}
