import '../models/order.dart';
import '../state/auth_state.dart';

/// Whether the logged-in user may modify [order] (add items / reopen it).
/// Owners may edit any order; a staff member may only edit orders they
/// personally took (matched on the order's [CafeOrder.takenBy] field).
bool canEditOrder(AuthState auth, CafeOrder order) {
  if (auth.isOwner) return true;
  if (auth.isStaff) {
    return order.takenBy != null &&
        order.takenBy!.isNotEmpty &&
        order.takenBy == auth.username;
  }
  return false;
}
