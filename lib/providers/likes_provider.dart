import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final likesProvider = StateNotifierProvider<LikesNotifier, Set<String>>(
  (ref) => LikesNotifier()..loadFromPrefs(),
);

class LikesNotifier extends StateNotifier<Set<String>> {
  LikesNotifier() : super({});

  static const _key = 'liked_templates';

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    if (mounted) state = stored.toSet();
  }

  Future<void> toggleLike(String templateId) async {
    final updated = Set<String>.from(state);
    if (updated.contains(templateId)) {
      updated.remove(templateId);
    } else {
      updated.add(templateId);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated.toList());
  }

  /// Тихо удаляет мёртвый id (шаблон удалён из БД, пришёл 404).
  Future<void> removeDeadId(String templateId) async {
    if (!state.contains(templateId)) return;
    final updated = Set<String>.from(state)..remove(templateId);
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated.toList());
  }

  bool isLiked(String id) => state.contains(id);
}
