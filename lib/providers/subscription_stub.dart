import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/subscription/models/subscription_plan.dart';
import '../features/subscription/models/entitlement.dart';
import '../features/subscription/services/purchase_service.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) => StubPurchaseService());

final featureAccessProvider = Provider.family<bool, dynamic>((ref, feature) => false);

class StubPurchaseService implements PurchaseService {
  @override
  Future<List<SubscriptionPlan>> fetchPlans({bool includeIntroEligibility = false}) async => [];
  
  @override
  Future<Entitlement> currentEntitlement() async => Entitlement.free;
  
  @override
  Future<Entitlement> purchase(String planId) async => Entitlement.free;
  
  @override
  Future<Entitlement> restore() async => Entitlement.free;
  
  @override
  Future<void> identify(String? userId) async {}
  
  @override
  Future<bool> ensureIdentified(String userId) async => false;
  
  @override
  Future<void> invalidateCustomerInfoCache() async {}
  
  @override
  Future<Map<String, Object?>> debugCustomerInfoSnapshot() async => {};
  
  @override
  Future<String?> storefrontCountryCode() async => null;
  
  @override
  Stream<Entitlement> get entitlementStream => const Stream.empty();
}
