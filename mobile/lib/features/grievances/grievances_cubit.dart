import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';

class GrievancesState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> grievances;
  final int count;
  final String filter;
  final String type;
  final String category;
  final Map<String, dynamic> stats;

  const GrievancesState({
    this.loading = false,
    this.error,
    this.grievances = const [],
    this.count = 0,
    this.filter = '',
    this.type = '',
    this.category = '',
    this.stats = const {},
  });

  GrievancesState copyWith({
    bool? loading,
    String? error,
    List<Map<String, dynamic>>? grievances,
    int? count,
    String? filter,
    String? type,
    String? category,
    Map<String, dynamic>? stats,
  }) {
    return GrievancesState(
      loading: loading ?? this.loading,
      error: error,
      grievances: grievances ?? this.grievances,
      count: count ?? this.count,
      filter: filter ?? this.filter,
      type: type ?? this.type,
      category: category ?? this.category,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [loading, error, grievances, count, filter, type, category, stats];
}

class GrievancesCubit extends Cubit<GrievancesState> {
  GrievancesCubit() : super(const GrievancesState());

  Future<void> load({String? status, String? type, String? category}) async {
    emit(state.copyWith(
      loading: true,
      filter: status ?? state.filter,
      type: type ?? state.type,
      category: category ?? state.category,
    ));
    try {
      final params = <String, dynamic>{};
      final effectiveStatus = status ?? state.filter;
      final effectiveType = type ?? state.type;
      final effectiveCategory = category ?? state.category;
      if (effectiveStatus.isNotEmpty) params['status'] = effectiveStatus;
      if (effectiveType.isNotEmpty) params['type'] = effectiveType;
      if (effectiveCategory.isNotEmpty) params['category'] = effectiveCategory;

      final results = await Future.wait([
        api.get('/grievances', queryParams: params),
        api.get('/grievances/stats'),
      ]);

      final data = results[0].data;
      final list = (data['grievances'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final stats = results[1].data is Map<String, dynamic>
          ? results[1].data as Map<String, dynamic>
          : <String, dynamic>{};

      emit(state.copyWith(
        loading: false,
        grievances: list,
        count: data['count'] ?? 0,
        stats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<bool> create(Map<String, dynamic> form) async {
    try {
      await api.post('/grievances', data: form);
      await load(status: state.filter);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    try {
      await api.patch('/grievances/$id/status', data: {'status': status});
      await load(status: state.filter);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendMessage(String id, String body, {bool isInternal = false}) async {
    try {
      await api.post('/grievances/$id/comments',
          data: {'comment': body, 'isInternal': isInternal});
      return true;
    } catch (e) {
      return false;
    }
  }
}
