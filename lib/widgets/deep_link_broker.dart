import 'dart:async';

import 'package:flutter/material.dart';

import '../services/deep_link_service.dart';

/// Tracks the top-most route so deep links cannot stack duplicate login
/// screens on top of each other.
class RouteNameTracker extends NavigatorObserver {
  Route<dynamic>? current;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    current = route;
  }

  @override
  void didPop(Route<dynamic>? route, Route<dynamic>? previousRoute) {
    current = previousRoute;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    current = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    current = newRoute;
  }
}

/// Restored deep-link handler: after the first frame it resolves the
/// cold-start link and subscribes to live links, opening the login screen
/// for every valid `invoizrider://login` link.
class AppDeepLinkBroker extends StatefulWidget {
  const AppDeepLinkBroker({
    super.key,
    required this.navKey,
    required this.routeTracker,
    this.service,
    this.child,
  });

  final GlobalKey<NavigatorState> navKey;
  final RouteNameTracker routeTracker;
  final DeepLinkService? service;
  final Widget? child;

  @override
  State<AppDeepLinkBroker> createState() => _AppDeepLinkBrokerState();
}

class _AppDeepLinkBrokerState extends State<AppDeepLinkBroker> {
  StreamSubscription<Uri>? _linksSubscription;
  StreamSubscription<Uri>? _resetSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = widget.service;
      if (service == null) return;
      final initial = await service.initialLink;
      if (mounted && initial != null) _openLogin(initial);
      final initialReset = await service.initialResetLink;
      if (mounted && initialReset != null) _openReset(initialReset);
      _linksSubscription = service.loginLinks.listen(_openLogin);
      _resetSubscription = service.resetLinks.listen(_openReset);
    });
  }

  void _openLogin(Uri uri) {
    if (!DeepLinkService.isLoginLink(uri)) return;
    if (widget.routeTracker.current?.settings.name ==
        DeepLinkService.loginRouteName) {
      return;
    }
    widget.navKey.currentState?.pushNamed(DeepLinkService.loginRouteName);
  }

  void _openReset(Uri uri) {
    final credentials = DeepLinkService.resetCredentials(uri);
    if (credentials == null) return;
    if (widget.routeTracker.current?.settings.name ==
        DeepLinkService.resetRouteName) {
      return;
    }
    widget.navKey.currentState?.pushNamed(
      DeepLinkService.resetRouteName,
      arguments: {'email': credentials.email, 'token': credentials.token},
    );
  }

  @override
  void dispose() {
    _linksSubscription?.cancel();
    _resetSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}