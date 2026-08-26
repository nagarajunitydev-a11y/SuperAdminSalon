/// Firestore collection names, mirroring the Salon CRM's existing schema.
///
/// The console NEVER invents a collection: every name here already exists and
/// is written by the CRM. Sub-collections live under `salons/{salonId}/...`
/// and are read platform-wide through collection-group queries.
class Col {
  const Col._();

  // Root collections
  static const users = 'users';
  static const salons = 'salons';
  static const rewardTransactions = 'rewardTransactions';

  // Per-salon sub-collections (also queried as collection groups)
  static const customers = 'customers';
  static const appointments = 'appointments';
  static const services = 'services';
  static const staff = 'staff';
  static const referrals = 'referrals';
  static const walletTransactions = 'walletTransactions';

  // Added by the console
  static const adminAuditLogs = 'adminAuditLogs';
}

/// Appointment lifecycle values written by the CRM.
class ApptStatus {
  const ApptStatus._();
  static const confirmed = 'Confirmed';
  static const inProgress = 'In Progress';
  static const completed = 'Completed';
  static const cancelled = 'Cancelled';
  static const pending = 'Pending';

  static const all = [confirmed, inProgress, completed, cancelled, pending];
}

/// Where a booking originated. Absent means it was created inside the CRM.
class BookingSource {
  const BookingSource._();
  static const whatsapp = 'whatsapp';
  static const publicBooking = 'public_booking';
  static const inCrm = 'crm';
}

/// Referral lifecycle, mirroring core/referral.js.
class ReferralStatus {
  const ReferralStatus._();
  static const pending = 'Pending';
  static const qualified = 'Qualified';
  static const credited = 'Credited';
  static const redeemed = 'Redeemed';
  static const expired = 'Expired';
  static const reversed = 'Reversed';

  static const all = [pending, qualified, credited, redeemed, expired, reversed];
}

/// Salon operational status. The CRM predates this field, so ABSENT == active.
class SalonStatus {
  const SalonStatus._();
  static const active = 'active';
  static const suspended = 'suspended';
}
