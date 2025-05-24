// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables before Firebase is initialized.
  await dotenv.load(fileName: "lib/.env");
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  late MyRouterDelegate _routerDelegate;
  final MyRouteInformationParser _routeInformationParser =
  MyRouteInformationParser();

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _routerDelegate = MyRouterDelegate(
      onSignIn: _handleSignIn,
      onSignOut: _handleSignOut,
    );
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isDark = prefs.getBool('isDarkMode');
    setState(() {
      _themeMode = (isDark != null && isDark) ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void toggleTheme(bool isDark) async {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  void _handleSignIn() {
    _routerDelegate.updateAuthentication(true);
  }

  void _handleSignOut() {
    _routerDelegate.updateAuthentication(false);
  }

  @override
  Widget build(BuildContext context) {
    // Update router delegate with current theme settings.
    _routerDelegate.isDarkMode = _themeMode == ThemeMode.dark;
    _routerDelegate.onThemeChanged = toggleTheme;

    return MaterialApp.router(
      title: 'IELTS Essay App',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      routerDelegate: _routerDelegate,
      routeInformationParser: _routeInformationParser,
    );
  }
}

// --- Routing configuration ---

class MyRoutePath {
  final bool isAuthPage;
  MyRoutePath.auth() : isAuthPage = true;
  MyRoutePath.home() : isAuthPage = false;
}

class MyRouteInformationParser extends RouteInformationParser<MyRoutePath> {
  @override
  Future<MyRoutePath> parseRouteInformation(
      RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    if (uri.pathSegments.isEmpty || uri.pathSegments[0] == 'auth') {
      return MyRoutePath.auth();
    } else if (uri.pathSegments[0] == 'home') {
      return MyRoutePath.home();
    }
    return MyRoutePath.auth();
  }

  @override
  RouteInformation restoreRouteInformation(MyRoutePath configuration) {
    return configuration.isAuthPage
        ? RouteInformation(uri: Uri(path: '/auth'))
        : RouteInformation(uri: Uri(path: '/home'));
  }
}

class MyRouterDelegate extends RouterDelegate<MyRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<MyRoutePath> {
  final GlobalKey<NavigatorState> navigatorKey;
  bool isAuthenticated = false;
  final Function onSignIn;
  final Function onSignOut;

  // These values are updated from MyApp.
  bool isDarkMode = false;
  Function(bool)? onThemeChanged;

  MyRouterDelegate({required this.onSignIn, required this.onSignOut})
      : navigatorKey = GlobalKey<NavigatorState>() {
    // Automatically mark user as authenticated if they're already signed in.
    isAuthenticated = FirebaseAuth.instance.currentUser != null;
  }

  @override
  MyRoutePath get currentConfiguration =>
      isAuthenticated ? MyRoutePath.home() : MyRoutePath.auth();

  @override
  Widget build(BuildContext context) {
    List<Page> stack;
    if (!isAuthenticated) {
      stack = [
        MaterialPage(
          key: const ValueKey('AuthPage'),
          child: AuthScreen(
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged ?? (_) {},
            onSignIn: () => onSignIn(),
          ),
        ),
      ];
    } else {
      stack = [
        MaterialPage(
          key: const ValueKey('HomePage'),
          child: HomeScreen(
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged ?? (_) {},
          ),
        ),
      ];
    }
    return Navigator(
      key: navigatorKey,
      pages: stack,
      onPopPage: (route, result) {
        if (!route.didPop(result)) return false;
        if (isAuthenticated) {
          updateAuthentication(false);
          onSignOut();
        }
        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(MyRoutePath configuration) async {
    isAuthenticated = !configuration.isAuthPage;
    notifyListeners();
  }

  void updateAuthentication(bool auth) {
    isAuthenticated = auth;
    notifyListeners();
  }
}
