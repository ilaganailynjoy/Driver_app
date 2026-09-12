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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = widget.service;
      if (service == null) return;
      final initial = await service.initialLink;
      if (mounted && initial != null) _openLogin(initial);
      _linksSubscription = service.loginLinks.listen(_openLogin);
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

  @override
  void dispose() {
    _linksSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}