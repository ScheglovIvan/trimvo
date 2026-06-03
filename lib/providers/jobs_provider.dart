import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trimvo/models/job_model.dart';
import 'package:trimvo/services/api_service.dart';

class JobsState {
  const JobsState({
    this.jobs = const [],
    this.pollingJobId,
  });

  final List<JobModel> jobs;
  final String? pollingJobId;

  JobsState copyWith({
    List<JobModel>? jobs,
    String? pollingJobId,
    bool clearPolling = false,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      pollingJobId: clearPolling ? null : (pollingJobId ?? this.pollingJobId),
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
    final items = await ApiService.getUserJobs();
    final jobs = items
        .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
        .toList();
    state = state.copyWith(jobs: jobs);
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
    await ApiService.deleteJob(jobId);
    state = state.copyWith(
      jobs: state.jobs.where((j) => j.id != jobId).toList(),
    );
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
