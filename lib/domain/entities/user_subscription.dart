import 'package:equatable/equatable.dart';

enum SubscriptionStatus { none, trial, active, expired, cancelled }

class UserSubscription extends Equatable {
  final String odId;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? expirationDate;
  final bool isTrialUsed;
  final String? productId;
  
  const UserSubscription({
    required this.odId,
    this.status = SubscriptionStatus.none,
    this.startDate,
    this.expirationDate,
    this.isTrialUsed = false,
    this.productId,
  });
  
  bool get isValid => 
    status == SubscriptionStatus.active || 
    (status == SubscriptionStatus.trial && expirationDate != null && expirationDate!.isAfter(DateTime.now()));
  
  @override
  List<Object?> get props => [odId, status, startDate, expirationDate, isTrialUsed, productId];
}
