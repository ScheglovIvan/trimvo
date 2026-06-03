class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.order,
  });

  final String id;
  final String name;
  final int order;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}
