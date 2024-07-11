import 'package:flutter/material.dart';
import 'package:test_dio_package/core/helper/dio_helper.dart';
import 'package:test_dio_package/models/product_model.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final List<ProductModel> _products = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final service = AutomaticallyService.instance;

    CustomResponse response = await service.sendToServer(
      url: 'v1/products.json',
      method: 'GET',
      // callback: (data) =>
      //     (data as List).map((json) => ProductModel.fromJson(json)).toList(),
    );

    if (response.success) {
      setState(() {
        ProductModel model = ProductModel.fromJson(response.data);
        print("🌍the model=> $model");
        _loading = false;
      });
    } else {
      setState(() {
        _error = response.msg;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dio Example'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text('Error: $_error'))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text('${product.brand} - \$${product.price}'),
                    );
                  },
                ),
    );
  }
}
