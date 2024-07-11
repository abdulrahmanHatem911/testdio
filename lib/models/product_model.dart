class ProductModel {
  int id;
  String? brand;
  String name;
  String? price;

  ProductModel({
    required this.id,
    required this.brand,
    required this.name,
    required this.price,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
      id: json["id"] ?? 0,
      brand: json["brand"] ?? "",
      name: json["name"],
      price: json["price"] ?? "");

  Map<String, dynamic> toJson() => {
        "id": id,
        "brand": brand,
        "name": name,
        "price": price,
      };
}
