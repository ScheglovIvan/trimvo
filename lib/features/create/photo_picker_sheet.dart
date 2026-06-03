import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200',
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200',
    'https://images.unsplash.com/photo-1521119989659-a83eee488004?w=200',
  ];

  static const _femaleExamples = [
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
    'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=200',
    'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=200',
    'https://images.unsplash.com/photo-1488716820095-cbe80883c496?w=200',
    'https://images.unsplash.com/photo-1500917293891-ef795e70e1f6?w=200',
    'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=200',
  ];

  static const _goodExamples = [
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
  ];

  static const _badExamples = [
    'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=150',
    'https://images.unsplash.com/photo-1554151228-14d9def656e4?w=150',
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // For best results
          Text(
            'For best results',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Good/bad examples row
          const Row(
            children: [
              Expanded(
                child: _ExampleGrid(
                  urls: _goodExamples,
                  borderColor: Colors.green,
                  icon: Icons.check,
                  iconColor: Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ExampleGrid(
                  urls: _badExamples,
                  borderColor: Colors.redAccent,
                  icon: Icons.close,
                  iconColor: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Match the example\'s framing and keep the subject clear.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Text(
            '😊 Choose a Photo Option',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  sublabel: 'Coming soon',
                  enabled: false,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Photos',
                  sublabel: 'Gallery',
                  enabled: true,
                  onTap: () => _pickFromGallery(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Example grid
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Or pick an example',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _examples.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.of(context).pop(_examples[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _examples[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const ColoredBox(color: AppColors.backgroundCard),
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: AppColors.backgroundCard),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleGrid extends StatelessWidget {
  const _ExampleGrid({
    required this.urls,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
  });

  final List<String> urls;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: urls
              .map(
                (url) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: AppColors.backgroundCard),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(
              icon == Icons.check ? 'Good' : 'Bad',
              style: GoogleFonts.inter(fontSize: 12, color: iconColor),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textPrimary : AppColors.textHint;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: enabled ? AppColors.backgroundCard : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? AppColors.accentPurple : AppColors.textHint,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
