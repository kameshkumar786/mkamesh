import 'package:flutter/material.dart';

class ProductScreen extends StatefulWidget {
  @override
  _ProductScreenState createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  int _selectedCategory = 0;
  int _selectedFilter = 0;
  final List<String> categories = [
    'Atta, Rice & Dal',
    'Rajma, Chhole & Others',
    'Poha, Daliya & Grains'
  ];
  final List<String> filters = ['Brand', 'Atta Type', 'Price', 'Popularity'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Product Screen', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: Icon(Icons.search), onPressed: () {}),
          IconButton(icon: Icon(Icons.shopping_cart), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          _buildCategoryChips(),
          Expanded(child: _buildProductList()),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Text('Filters', style: TextStyle(fontSize: 14)),
          Icon(Icons.swap_vert, size: 18),
          Spacer(),
          ...List.generate(
            filters.length,
            (index) => Padding(
              padding: EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: Text(filters[index],
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedFilter == index
                          ? Colors.green
                          : Colors.black54,
                      decoration: _selectedFilter == index
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (ctx, index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: ChoiceChip(
            label: Text(categories[index],
                style: TextStyle(
                    fontSize: 14,
                    color: _selectedCategory == index
                        ? Colors.white
                        : Colors.black)),
            selected: _selectedCategory == index,
            selectedColor: Colors.green,
            backgroundColor: Colors.grey[200],
            onSelected: (selected) => setState(() => _selectedCategory = index),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: 4, // Replace with actual item count
      itemBuilder: (ctx, index) => _buildProductItem(),
    );
  }

  Widget _buildProductItem() {
    return Card(
      margin: EdgeInsets.all(8),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              color: Colors.grey[300],
              child: Icon(Icons.image, color: Colors.grey[500]),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('5 kg Wheat Atta',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Spacer(),
                      // Text('13 MINS',
                      //     style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Text('Fortune Chakki Fresh',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  SizedBox(height: 4),
                  // Text('100% Atta, 0% Maida', style: TextStyle(fontSize: 12)),
                  // SizedBox(height: 8),
                  Row(
                    children: [
                      Text('₹268',
                          style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey)),
                      SizedBox(width: 8),
                      Text('₹239',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      Spacer(),
                      Text('74.78/100 g', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('10% OFF',
                          style: TextStyle(fontSize: 12, color: Colors.green)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('Add',
                  style: TextStyle(fontSize: 14, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
