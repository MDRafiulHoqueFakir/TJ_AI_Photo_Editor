import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';

/// Holds the user's entitlement + credit balance.
///
/// Phase 1: in-memory + SharedPreferences (mocked). Phase 3 backs this with
/// RevenueCat (entitlement) and the server credits ledger.
class EntitlementState {
  const EntitlementState({this.entitlement = Entitlement.free, this.credits = 0});

  final Entitlement entitlement;
  final int credits;

  bool get isPro => entitlement == Entitlement.pro;

  EntitlementState copyWith({Entitlement? entitlement, int? credits}) {
    return EntitlementState(
      entitlement: entitlement ?? this.entitlement,
      credits: credits ?? this.credits,
    );
  }
}

class EntitlementNotifier extends Notifier<EntitlementState> {
  @override
  EntitlementState build() {
    // Dev/preview mode: everyone is Pro with ample credits so all features are
    // usable. Flip AppConstants.unlockAllFeatures to false to restore gating.
    if (AppConstants.unlockAllFeatures) {
      return const EntitlementState(entitlement: Entitlement.pro, credits: 9999);
    }
    return const EntitlementState();
  }

  /// Called after a successful RevenueCat purchase (Phase 3).
  void setPro({int grantCredits = 50}) {
    state = state.copyWith(entitlement: Entitlement.pro, credits: grantCredits);
  }

  /// Returns true if a cloud action can run; does NOT debit (debit on success).
  bool canAfford(String actionKey) {
    if (AppConstants.unlockAllFeatures) return true;
    final cost = AppConstants.creditCosts[actionKey] ?? 0;
    return state.isPro && state.credits >= cost;
  }

  /// Debit only after the cloud action succeeds.
  void debit(String actionKey) {
    final cost = AppConstants.creditCosts[actionKey] ?? 0;
    state = state.copyWith(credits: (state.credits - cost).clamp(0, 1 << 30));
  }

  void addCredits(int amount) =>
      state = state.copyWith(credits: state.credits + amount);
}

final entitlementProvider =
    NotifierProvider<EntitlementNotifier, EntitlementState>(
  EntitlementNotifier.new,
);
