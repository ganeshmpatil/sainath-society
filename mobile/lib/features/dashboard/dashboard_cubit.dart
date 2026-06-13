import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';

class DashboardData extends Equatable {
  final int memberCount;
  final int flatCount;
  final int grievanceCount;
  final double pendingAmount;
  final int unpaidCount;
  final List<Map<String, dynamic>> recentNotices;
  final List<Map<String, dynamic>> activeGrievances;
  final List<Map<String, dynamic>> upcomingEvents;

  const DashboardData({
    this.memberCount = 0,
    this.flatCount = 0,
    this.grievanceCount = 0,
    this.pendingAmount = 0,
    this.unpaidCount = 0,
    this.recentNotices = const [],
    this.activeGrievances = const [],
    this.upcomingEvents = const [],
  });

  @override
  List<Object?> get props => [memberCount, flatCount, grievanceCount, pendingAmount];
}

sealed class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final DashboardData data;
  const DashboardLoaded(this.data);
  @override
  List<Object?> get props => [data];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit() : super(const DashboardLoading());

  Future<void> load() async {
    emit(const DashboardLoading());
    try {
      final results = await Future.wait([
        api.get('/residents', queryParams: {'activeOnly': 'true'}).catchError((_) => _empty()),
        api.get('/flats').catchError((_) => _empty()),
        api.get('/grievances', queryParams: {'status': 'OPEN'}).catchError((_) => _empty()),
        api.get('/finance/bills/pending-dues').catchError((_) => _empty()),
        api.get('/notices').catchError((_) => _empty()),
        api.get('/events/upcoming').catchError((_) => _empty()),
      ]);

      emit(DashboardLoaded(DashboardData(
        memberCount: _count(results[0].data),
        flatCount: _count(results[1].data),
        grievanceCount: _count(results[2].data),
        pendingAmount: (results[3].data?['pendingAmount'] ?? 0).toDouble(),
        unpaidCount: results[3].data?['unpaidCount'] ?? 0,
        recentNotices: _list(results[4].data, 'notices'),
        activeGrievances: _list(results[2].data, 'grievances'),
        upcomingEvents: _list(results[5].data, 'events'),
      )));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  int _count(dynamic data) {
    if (data is Map) return data['count'] ?? 0;
    return 0;
  }

  List<Map<String, dynamic>> _list(dynamic data, String key) {
    if (data is Map && data[key] is List) {
      return (data[key] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Response _empty() => Response(requestOptions: RequestOptions(), data: <String, dynamic>{});
}
