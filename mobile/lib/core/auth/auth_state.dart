import 'package:equatable/equatable.dart';

class UserInfo extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String designation;
  final String flatId;
  final String flatNumber;
  final bool isActive;
  final List<String> permissions;

  const UserInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.designation,
    required this.flatId,
    required this.flatNumber,
    required this.isActive,
    required this.permissions,
  });

  bool get isAdmin => role == 'ADMIN';

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'MEMBER',
      designation: json['designation'] ?? '',
      flatId: json['flatId'] ?? '',
      flatNumber: json['flatNumber'] ?? '',
      isActive: json['isActive'] ?? true,
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  @override
  List<Object?> get props => [id, name, email, role, flatNumber];
}

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final UserInfo user;
  final String accessToken;

  const Authenticated({required this.user, required this.accessToken});

  @override
  List<Object?> get props => [user, accessToken];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}
