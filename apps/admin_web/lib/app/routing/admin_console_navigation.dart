import 'package:flutter/material.dart';

/// Keeps console URL history outside the authenticated page's lifetime.
class AdminConsoleNavigation extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  AdminConsoleNavigation(this.home);
  final Widget home;
  Uri _uri = Uri(path: '/');
  Uri get uri => _uri;
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Uri get currentConfiguration => _uri;
  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    _uri = configuration;
    notifyListeners();
  }

  void go(BuildContext context, Uri uri, {bool replace = false}) {
    if (_uri == uri) return;
    void update() {
      _uri = uri;
      notifyListeners();
    }

    if (replace) {
      Router.neglect(context, update);
    } else {
      Router.navigate(context, update);
    }
  }

  static AdminConsoleNavigation? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_NavigationScope>()
      ?.navigation;
  @override
  Widget build(BuildContext context) => _NavigationScope(
      navigation: this,
      child: Navigator(
          key: navigatorKey,
          pages: [
            MaterialPage<void>(
                key: const ValueKey('admin-console'), child: home)
          ],
          onDidRemovePage: (_) {}));
}

class _NavigationScope extends InheritedNotifier<AdminConsoleNavigation> {
  const _NavigationScope(
      {required AdminConsoleNavigation navigation, required super.child})
      : super(notifier: navigation);
  AdminConsoleNavigation get navigation => notifier!;
}

class _ConsoleRouteParser extends RouteInformationParser<Uri> {
  const _ConsoleRouteParser();
  @override
  Future<Uri> parseRouteInformation(RouteInformation information) async =>
      information.uri;
  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

class AdminConsoleApp extends StatefulWidget {
  const AdminConsoleApp(
      {super.key,
      required this.home,
      required this.theme,
      required this.title,
      this.debugShowCheckedModeBanner = false});
  final Widget home;
  final ThemeData theme;
  final String title;
  final bool debugShowCheckedModeBanner;
  @override
  State<AdminConsoleApp> createState() => _AdminConsoleAppState();
}

class _AdminConsoleAppState extends State<AdminConsoleApp> {
  late final navigation = AdminConsoleNavigation(widget.home);
  @override
  void dispose() {
    navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
      title: widget.title,
      theme: widget.theme,
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
      routerDelegate: navigation,
      routeInformationParser: const _ConsoleRouteParser());
}
