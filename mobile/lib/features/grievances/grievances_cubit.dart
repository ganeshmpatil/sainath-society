import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';

class GrievancesState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> grievances;
  final int count;
  final String filter;

  const GrievancesState({
    this.loading = false,
    this.error,
    this.grievances = const [],
    this.count = 0,
    this.filter = '',
  });

  GrievancesState copyWith({
    bool? loading,
    String? error,
    List<Map<String, dynamic>>? grievances,
    int? count,
    String? filter,
  }) {
    return GrievancesState(
      loading: loading ?? this.loading,
      error: error,
      grievances: grievances ?? this.grievances,
      count: count ?? this.count,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [loading, error, grievances, count, filter];
}

class GrievancesCubit extends Cubit<GrievancesState> {
  GrievancesCubit() : super(const GrievancesState());

  Future<void> load({String? status}) async {
    emit(state.copyWith(loading: true, filter: status ?? ''));
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;

      final response = await api.get('/grievances', queryParams: params);
      final data = response.data;
      final list = (data['grievances'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      emit(state.copyWith(
        loading: false,
        grievances: list,
        count: data['count'] ?? 0,
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
}
