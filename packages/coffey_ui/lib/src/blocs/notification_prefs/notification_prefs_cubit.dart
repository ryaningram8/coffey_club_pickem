import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../models/notification_prefs_model.dart';
import '../../repositories/notification_repository.dart';

part 'notification_prefs_cubit.freezed.dart';
part 'notification_prefs_state.dart';

/// Toggle-style preferences editing — a Cubit rather than a full BLoC, same
/// as ThemeCubit.
class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit({
    required NotificationRepository notificationRepository,
  }) : _repository = notificationRepository,
       super(const NotificationPrefsState.initial()) {
    _load();
  }

  final NotificationRepository _repository;

  /// Re-runs the initial load — used by the screen's error-state retry
  /// action after a failed fetch.
  Future<void> reload() => _load();

  Future<void> _load() async {
    emit(const NotificationPrefsState.loading());
    try {
      final prefs = await _repository.getPrefs();
      emit(NotificationPrefsState.loaded(prefs: prefs));
    } catch (e) {
      emit(NotificationPrefsState.failure(e.toString()));
    }
  }

  Future<void> setPickRemindersEnabled(bool value) =>
      _patchPickReminders({'enabled': value});
  Future<void> setPickRemindersPush(bool value) =>
      _patchPickReminders({'push': value});
  Future<void> setPickRemindersEmail(bool value) =>
      _patchPickReminders({'email': value});
  Future<void> setHoursBeforeDeadline(int hours) =>
      _patchPickReminders({'hoursBeforeDeadline': hours});

  Future<void> setResultsEnabled(bool value) =>
      _patchResults({'enabled': value});
  Future<void> setResultsPush(bool value) => _patchResults({'push': value});
  Future<void> setResultsEmail(bool value) => _patchResults({'email': value});

  Future<void> _patchPickReminders(Map<String, dynamic> patch) async {
    final current = state;
    if (current is! NotificationPrefsLoaded) return;
    try {
      final updated = await _repository.updatePrefs(pickReminders: patch);
      emit(NotificationPrefsState.loaded(prefs: updated));
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _patchResults(Map<String, dynamic> patch) async {
    final current = state;
    if (current is! NotificationPrefsLoaded) return;
    try {
      final updated = await _repository.updatePrefs(
        resultsNotifications: patch,
      );
      emit(NotificationPrefsState.loaded(prefs: updated));
    } catch (e) {
      emit(current.copyWith(errorMessage: e.toString()));
    }
  }
}
