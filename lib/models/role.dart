enum Role {
  customer(1, 'Покупатель'),
  seller(2, 'Продавец'),
  admin(3, 'Администратор');

  const Role(this.level, this.label);
  final int level;
  final String label;

  static Role fromString(String? raw) {
    return Role.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => Role.customer,
    );
  }
}

class Permissions {
  static bool canBrowseCatalog(Role role) => true;

  static bool canManageCatalog(Role role) =>
      role == Role.seller || role == Role.admin;

  static bool canManageSuppliers(Role role) => role == Role.admin;

  static bool canManagePromotions(Role role) => role == Role.admin;

  static bool canProcessOrders(Role role) =>
      role == Role.seller || role == Role.admin;

  static bool canViewMyOrders(Role role) => role == Role.customer;

  static bool canPlaceOrder(Role role) => role == Role.customer;

  static bool canHardDelete(Role role) => role == Role.admin;

  static bool canRestore(Role role) => role == Role.admin;

  static bool canManageUsers(Role role) => role == Role.admin;

  static bool canViewReports(Role role) => role == Role.admin;

  static bool canManageCustomers(Role role) =>
      role == Role.seller || role == Role.admin;

  static bool canWriteReview(Role role) => role == Role.customer;
}
