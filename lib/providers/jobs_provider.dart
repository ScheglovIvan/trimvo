import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/models/job_model.dart';
import 'package:trimvo/services/api_service.dart';

class JobsState {
  const JobsState({
    this.jobs = const [],
    this.pollingJobId,
    this.page = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<JobModel> jobs;
  final String? pollingJobId;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  JobsState copyWith({
    List<JobModel>? jobs,
    String? pollingJobId,
    bool clearPolling = false,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      pollingJobId: clearPolling ? null : (pollingJobId ?? this.pollingJobId),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class JobsNotifier extends StateNotifier<JobsState> {
  JobsNotifier() : super(const JobsState());

  Timer? _pollTimer;

  Future<String> createJob(
    String? templateId,
    Map<String, dynamic> options,
  ) async {
    final data = await ApiService.createJob(templateId, options);
    final jobId = data['job_id']?.toString() ?? data['id']?.toString() ?? '';
    final job = JobModel.fromJson({
      'id': jobId,
      'status': data['status'] ?? 'queued',
      ...data,
    });
    state = state.copyWith(jobs: [...state.jobs, job]);
    return jobId;
  }

  Future<String> createCustomJob({
    required String photo1Path,
    String? photo2Path,
    String prompt = '',
    String resolution = '1080x1920',
    String quality = 'standard',
    String format = 'mp4',
  }) async {
    final data = await ApiService.createCustomJob(
      photo1Path: photo1Path,
      photo2Path: photo2Path,
      prompt: prompt,
      resolution: resolution,
      quality: quality,
      format: format,
    );
    final jobId = data['job_id']?.toString() ?? data['id']?.toString() ?? '';
    final job = JobModel.fromJson({
      'id': jobId,
      'status': data['status'] ?? 'queued',
      ...data,
    });
    state = state.copyWith(jobs: [...state.jobs, job]);
    return jobId;
  }

  Future<String> createImageJob({
    required String photoPath,
    String prompt = '',
    String aspectRatio = '1:1',
    int numOutputs = 1,
  }) async {
    final data = await ApiService.createImageJob(
      photoPath: photoPath,
      prompt: prompt,
      aspectRatio: aspectRatio,
      numOutputs: numOutputs,
    );
    final jobId = data['job_id']?.toString() ?? data['id']?.toString() ?? '';
    final job = JobModel.fromJson({
      'id': jobId,
      'status': data['status'] ?? 'queued',
      ...data,
    });
    state = state.copyWith(jobs: [...state.jobs, job]);
    return jobId;
  }

  void pollJobStatus(String jobId, {void Function(JobModel)? onUpdate}) {
    _pollTimer?.cancel();
    state = state.copyWith(pollingJobId: jobId);

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final data = await ApiService.getJobStatus(jobId);
        final jobData = Map<String, dynamic>.from(data)
          ..['id'] = jobId;
        final updated = JobModel.fromJson(jobData);
        _updateJob(updated);
        onUpdate?.call(updated);
        if (updated.isDone || updated.isFailed) {
          _pollTimer?.cancel();
          state = state.copyWith(clearPolling: true);
        }
      } catch (_) {
        // silently continue polling on transient errors
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    state = state.copyWith(clearPolling: true);
  }

  Future<void> getUserJobs() async {
    const perPage = 20;
    final data = await ApiService.getUserJobs(page: 1, perPage: perPage);
    final items = data['items'] as List<dynamic>? ?? [];
    final total = (data['total'] as num?)?.toInt();
    final jobs = items
        .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
        .toList();
    state = state.copyWith(
      jobs: jobs,
      page: 1,
      hasMore: total != null ? jobs.length < total : jobs.length >= perPage,
      isLoadingMore: false,
    );
  }

  Future<void> loadMoreJobs() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      const perPage = 20;
      final nextPage = state.page + 1;
      final data = await ApiService.getUserJobs(page: nextPage, perPage: perPage);
      final items = data['items'] as List<dynamic>? ?? [];
      final total = (data['total'] as num?)?.toInt();
      final newJobs = items
          .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final merged = [...state.jobs, ...newJobs];
      state = state.copyWith(
        jobs: merged,
        page: nextPage,
        hasMore: total != null ? merged.length < total : newJobs.length >= perPage,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> fetchImageJobDetails() async {
    final targets = state.jobs
        .where((j) => j.jobType == 'image' && j.isDone)
        .toList();
    await Future.wait(
      targets.map((job) async {
        try {
          final data = await ApiService.getJobStatus(job.id);
          // Detail endpoint returns id=null — force the known id so _updateJob
          // can match the existing job in state.
          final jobData = Map<String, dynamic>.from(data)
            ..['id'] = job.id;
          _updateJob(JobModel.fromJson(jobData));
        } catch (_) {}
      }),
    );
  }

  Future<void> deleteJob(String jobId) async {
    final removed = state.jobs.firstWhere(
      (j) => j.id == jobId,
      orElse: () => state.jobs.first,
    );
    // Optimistic: remove immediately so UI feels instant
    state = state.copyWith(
      jobs: state.jobs.where((j) => j.id != jobId).toList(),
    );
    try {
      await ApiService.deleteJob(jobId);
    } catch (_) {
      // Restore on failure
      state = state.copyWith(jobs: [...state.jobs, removed]);
      rethrow;
    }
  }

  void _updateJob(JobModel updated) {
    final jobs = state.jobs.map((j) => j.id == updated.id ? updated : j).toList();
    if (!jobs.any((j) => j.id == updated.id)) {
      jobs.add(updated);
    }
    state = state.copyWith(jobs: jobs);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final jobsProvider = StateNotifierProvider<JobsNotifier, JobsState>(
  (_) => JobsNotifier(),
);
