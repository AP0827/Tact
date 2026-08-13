import 'package:flutter_riverpod/flutter_riverpod.dart';

// Intentionally inert for the first few versions. Everything is unlocked
// and nothing else in the app should import a store/purchase package yet.
//
// When you're ready to introduce paid features:
//   1. Add in_app_purchase (or RevenueCat) as a dependency.
//   2. Write a StoreEntitlements class implementing Entitlements below.
//   3. Change entitlementsProvider to return StoreEntitlements instead.
// No other file needs to change — every gated feature already reads
// through entitlementsProvider.

abstract class Entitlements {
  bool get isPro;
}

class FreeForNowEntitlements implements Entitlements {
  @override
  bool get isPro => true;
}

final entitlementsProvider = Provider<Entitlements>((ref) => FreeForNowEntitlements());
