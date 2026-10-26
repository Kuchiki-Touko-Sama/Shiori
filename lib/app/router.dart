import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shiori/app/widgets/root_shell.dart';
import 'package:shiori/features/auth/login_page.dart';
import 'package:shiori/features/evaluation/evaluation_page.dart';
import 'package:shiori/features/exam/exam_page.dart';
import 'package:shiori/features/grades/grades_page.dart';
import 'package:shiori/features/settings/settings_page.dart';
import 'package:shiori/features/timetable/timetable_page.dart';

/// 全局路由。
///
/// 四个主 Tab 由 [StatefulShellRoute.indexedStack] 承载，
/// 各自保持独立导航栈；/login 与 /evaluation 为独立二级页面。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/evaluation',
        builder: (context, state) => const EvaluationPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RootShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const TimetablePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/grades',
                builder: (context, state) => const GradesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exams',
                builder: (context, state) => const ExamPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
