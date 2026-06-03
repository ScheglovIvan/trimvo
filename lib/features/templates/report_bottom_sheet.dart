import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/models/report_reason.dart';
import 'package:trimvo/services/api_service.dart';

Future<void> showReportBottomSheet(BuildContext context, String templateId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(templateId: templateId),
  );
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Report Content',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.textHint, height: 1),
            ...ReportReason.values.map(
              (reason) => _ReasonTile(
                reason: reason,
                templateId: templateId,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason, required this.templateId});

  final ReportReason reason;
  final String templateId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        try {
          await ApiService.submitReport(templateId, reason.apiValue);
        } catch (_) {}
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you.')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
