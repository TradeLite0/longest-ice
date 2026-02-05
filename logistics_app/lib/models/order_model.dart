/// 📦 نموذج الطلب
class Order {
  final String id;
  final String customerName;
  final String customerPhone;
  final String address;
  final double latitude;
  final double longitude;
  final double amount;
  final String status; // pending, in_progress, delivered, no_answer, postponed
  final String createdAt;
  final List<OrderItem>? items;

  Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      address: json['address'],
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'],
      items: json['items'] != null
          ? (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'amount': amount,
      'status': status,
      'created_at': createdAt,
      'items': items?.map((i) => i.toJson()).toList(),
    };
  }

  // 📝 copyWith لتعديل الحالة
  Order copyWith({
    String? status,
  }) {
    return Order(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      address: address,
      latitude: latitude,
      longitude: longitude,
      amount: amount,
      status: status ?? this.status,
      createdAt: createdAt,
      items: items,
    );
  }
}

/// 📦 عنصر الطلب
class OrderItem {
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'],
      quantity: json['quantity'],
      price: (json['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}
