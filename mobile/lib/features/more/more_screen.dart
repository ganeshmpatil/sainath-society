import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_cubit.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/language_toggle.dart';

class _Module {
  final IconData icon;
  final String labelKey;
  final String route;
  final Color color;
  const _Module(this.icon, this.labelKey, this.route, this.color);
}

const _modules = [
  _Module(Icons.people_rounded, 'nav.residents', '/residents', Color(0x303B82F6)),
  _Module(Icons.apartment_rounded, 'nav.flatDetails', '/flat-details', Color(0x30A855F7)),
  _Module(Icons.directions_car_rounded, 'nav.vehicles', '/vehicles', Color(0x3006B6D4)),
  _Module(Icons.how_to_vote_rounded, 'nav.polls', '/polls', Color(0x30EAB308)),
  _Module(Icons.groups_rounded, 'nav.meetings', '/meetings', Color(0x3010B981)),
  _Module(Icons.checklist_rounded, 'nav.tasks', '/tasks', Color(0x30F97316)),
  _Module(Icons.event_available_rounded, 'nav.hallBooking', '/hall-booking', Color(0x30EF4444)),
  _Module(Icons.menu_book_rounded, 'nav.bylaws', '/bylaws', Color(0x308B5CF6)),
  _Module(Icons.lightbulb_rounded, 'nav.suggestions', '/suggestions', Color(0x30EAB308)),
  _Module(Icons.swap_horiz_rounded, 'nav.moveInOut', '/move-in-out', Color(0x3010B981)),
  _Module(Icons.folder_shared_rounded, 'nav.memberDocs', '/member-documents', Color(0x30EF4444)),
];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    final currentTheme = context.watch<ThemeCubit>().state;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.t('common.allModules'),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(l.t('app.tagline'),
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ],
                    ),
                    const Spacer(),
                    const LanguageToggle(),
                  ],
                ),
              ),
            ),

            // Search
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '${l.t('common.search')} modules...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),

            // Module grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final m = _modules[i];
                    return GestureDetector(
                      onTap: () => context.push(m.route),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: m.color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(m.icon, size: 22, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.t(m.labelKey),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _modules.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 32, indent: 16, endIndent: 16)),

            // Theme Picker
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('common.theme'),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ThemeOption(
                            label: l.t('theme.royalGold'),
                            colors: const [Color(0xFFD4AF37), Color(0xFFF4D03F)],
                            bgColor: const Color(0xFF0C0C1D),
                            isSelected: currentTheme == AppThemeType.royalGold,
                            onTap: () => context.read<ThemeCubit>().setTheme(AppThemeType.royalGold),
                          ),
                          const SizedBox(width: 10),
                          _ThemeOption(
                            label: l.t('theme.oceanBlue'),
                            colors: const [Color(0xFF38BDF8), Color(0xFF6366F1)],
                            bgColor: const Color(0xFF050D1A),
                            isSelected: currentTheme == AppThemeType.oceanBlue,
                            onTap: () => context.read<ThemeCubit>().setTheme(AppThemeType.oceanBlue),
                          ),
                          const SizedBox(width: 10),
                          _ThemeOption(
                            label: l.t('theme.freshEmerald'),
                            colors: const [Color(0xFF059669), Color(0xFF10B981)],
                            bgColor: const Color(0xFFF8FAFC),
                            isSelected: currentTheme == AppThemeType.freshEmerald,
                            onTap: () => context.read<ThemeCubit>().setTheme(AppThemeType.freshEmerald),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Profile
            SliverToBoxAdapter(
              child: GlassCard(
                onTap: () => context.push('/profile'),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _initials(user?.name ?? ''),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? '',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('${user?.flatNumber ?? ''} • ${user?.isAdmin == true ? l.t('common.admin') : l.t('common.member')}',
                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),

            // Logout
            SliverToBoxAdapter(
              child: GlassCard(
                borderColor: AppColors.urgent.withAlpha(50),
                onTap: () {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.urgentBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.power_settings_new_rounded, size: 20, color: AppColors.urgent),
                    ),
                    const SizedBox(width: 12),
                    Text(l.t('common.logout'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.urgent)),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final Color bgColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.colors,
    required this.bgColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors[0] : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors[0] : (bgColor.computeLuminance() > 0.5 ? const Color(0xFF64748B) : const Color(0x80FFFFFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
