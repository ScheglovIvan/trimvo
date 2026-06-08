import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trimvo/core/theme/app_colors.dart';

Future<String?> showPhotoPickerSheet(
  BuildContext context, {
  required String gender,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PhotoPickerSheet(gender: gender),
  );
}

class _PhotoPickerSheet extends StatelessWidget {
  const _PhotoPickerSheet({required this.gender});

  final String gender;

  static const _maleExamples = [
    'assets/images/photo_picker/example_1.png',
    'assets/images/photo_picker/example_2.jpg',
    'assets/images/photo_picker/example_3.jpg',
    'assets/images/photo_picker/example_4.jpg',
  ];

  static const _femaleExamples = [
    'assets/images/photo_picker/example_1.png',
    'assets/images/photo_picker/example_2.jpg',
    'assets/images/photo_picker/example_3.jpg',
    'assets/images/photo_picker/example_4.jpg',
  ];

  static const _goodExamples = [
    'assets/images/photo_picker/good_1.png',
    'assets/images/photo_picker/good_2.png',
  ];

  static const _badExamples = [
    'assets/images/photo_picker/bad_1.png',
    'assets/images/photo_picker/bad_2.png',
  ];

  List<String> get _examples =>
      gender == 'male' ? _maleExamples : _femaleExamples;

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null && context.mounted) {
      Navigator.of(context).pop(xfile.path);
    }
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera);
    if (xfile != null && context.mounted) {
      Navigator.of(context).pop(xfile.path);
    }
  }

  Future<void> _pickExample(BuildContext context, String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final tmp = await getTemporaryDirectory();
      final ext = assetPath.endsWith('.png') ? 'png' : 'jpg';
      final file = File(
        '${tmp.path}/example_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (context.mounted) Navigator.of(context).pop(file.path);
    } catch (_) {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // unified grid items: camera + photos + example photos
    final gridItems = <_GridItem>[
      _GridItem.camera(),
      _GridItem.photos(),
      ..._examples.map((url) => _GridItem.example(url)),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top area: drag handle centered + X button top-right
          SizedBox(
            height: 52,
            child: Stack(
              children: [
                // Drag handle centered
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: 36,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.textHint,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ),
                // X button — top-right of sheet
                Positioned(
                  top: 10,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.backgroundCard,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rest of content with horizontal padding
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

          // "For best results"
          Text(
            'For best results',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Good/bad examples row — borders already baked into images
          Row(
            children: [
              ..._goodExamples.map((url) => Expanded(child: _ExamplePhoto(url: url))),
              ..._badExamples.map((url) => Expanded(child: _ExamplePhoto(url: url))),
            ].expand((w) => [w, const SizedBox(width: 8)]).toList()
              ..removeLast(),
          ),
          const SizedBox(height: 10),

          // Description — orange, left-aligned
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Match the example\'s framing and keep the subject clear.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFFFAA00),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '☺ Choose a Photo Option',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Unified 3-column grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: gridItems.length,
            itemBuilder: (_, i) {
              final item = gridItems[i];
              if (item.type == _GridItemType.camera) {
                return _ActionCell(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => _pickFromCamera(context),
                );
              }
              if (item.type == _GridItemType.photos) {
                return _ActionCell(
                  icon: Icons.photo_library_rounded,
                  label: 'Photos',
                  onTap: () => _pickFromGallery(context),
                );
              }
              // example photo
              return GestureDetector(
                onTap: () => _pickExample(context, item.url!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item.url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: AppColors.backgroundCard),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid item model
// ─────────────────────────────────────────────────────────────────────────────

enum _GridItemType { camera, photos, example }

class _GridItem {
  const _GridItem._(this.type, [this.url]);
  factory _GridItem.camera() => const _GridItem._(_GridItemType.camera);
  factory _GridItem.photos() => const _GridItem._(_GridItemType.photos);
  factory _GridItem.example(String url) =>
      _GridItem._(_GridItemType.example, url);

  final _GridItemType type;
  final String? url;
}

// ─────────────────────────────────────────────────────────────────────────────
// Example photo with good/bad badge
// ─────────────────────────────────────────────────────────────────────────────

class _ExamplePhoto extends StatelessWidget {
  const _ExamplePhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: AppColors.backgroundCard),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action cell (Camera / Photos)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
