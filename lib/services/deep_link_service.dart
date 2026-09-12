import 'package:app_links/app_links.dart';

/// Restored deep-link handling for the rider app.
///
/// Accepted links use the custom scheme `invoizrider` with host `login`
/// (e.g. `invoizrider://login`) and open the login screen.
abstract class DeepLinkService {
  static const scheme = 'invoizrider';
  static const loginHost = 'login';
  static const loginRouteName = 'deep_link_login';

  /// The link the app was launched from, if it is a login link.
  Future<Uri?> get initialLink;

  /// Live login links received while the app is running.
  Stream<Uri> get loginLinks;

  static bool isLoginLink(Uri? uri) =>
      uri != null && uri.scheme == scheme && uri.host == loginHost;
}

/// [DeepLinkService] backed by the `app_links` plugin.
class AppLinksDeepLinkService implements DeepLinkService {
  AppLinksDeepLinkService({AppLinks? links}) : _links = links ?? AppLinks();

  final AppLinks _links;

  @override
  Future<Uri?> get initialLink async {
    try {
      final uri = await _links.getInitialLink();
      return DeepLinkService.isLoginLink(uri) ? uri : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri> get loginLinks async* {
    await for (final uri in _links.uriLinkStream) {
      if (DeepLinkService.isLoginLink(uri)) yield uri;
    }
  }
}