import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ModuleCategoriesScreen extends StatefulWidget {
  @override
  _ModuleCategoriesScreenState createState() => _ModuleCategoriesScreenState();
}

class _ModuleCategoriesScreenState extends State<ModuleCategoriesScreen> {
  final Map<String, List<String>> categories = {
    'Electronics': [
      'Laptop',
      'Smartphone',
      'Headphones',
      'Tablet',
      'Smartwatch',
      'Camera',
      'Speaker',
      'Monitor',
      'Keyboard',
      'Mouse'
    ],
    'Clothing': [
      'Shirt',
      'Jeans',
      'Jacket',
      'T-Shirt',
      'Shorts',
      'Dress',
      'Skirt',
      'Sweater',
      'Socks',
      'Shoes'
    ],
    'Groceries': [
      'Apple',
      'Milk',
      'Bread',
      'Eggs',
      'Cheese',
      'Butter',
      'Cereal',
      'Juice',
      'Tomatoes',
      'Potatoes'
    ],
    'Furniture': [
      'Sofa',
      'Table',
      'Chair',
      'Bed',
      'Dresser',
      'Wardrobe',
      'Desk',
      'Bookshelf',
      'Cabinet',
      'Stool'
    ],
    'Toys': [
      'Action Figure',
      'Doll',
      'Puzzle',
      'Board Game',
      'Lego',
      'RC Car',
      'Stuffed Animal',
      'Yo-Yo',
      'Kite',
      'Toy Train'
    ],
    'Electronics1': [
      'Laptop',
      'Smartphone',
      'Headphones',
      'Tablet',
      'Smartwatch',
      'Camera',
      'Speaker',
      'Monitor',
      'Keyboard',
      'Mouse'
    ],
    'Clothing2': [
      'Shirt',
      'Jeans',
      'Jacket',
      'T-Shirt',
      'Shorts',
      'Dress',
      'Skirt',
      'Sweater',
      'Socks',
      'Shoes'
    ],
    'Groceries3': [
      'Apple',
      'Milk',
      'Bread',
      'Eggs',
      'Cheese',
      'Butter',
      'Cereal',
      'Juice',
      'Tomatoes',
      'Potatoes'
    ],
    'Furniture4': [
      'Sofa',
      'Table',
      'Chair',
      'Bed',
      'Dresser',
      'Wardrobe',
      'Desk',
      'Bookshelf',
      'Cabinet',
      'Stool'
    ],
    'Toys5': [
      'Action Figure',
      'Doll',
      'Puzzle',
      'Board Game',
      'Lego',
      'RC Car',
      'Stuffed Animal',
      'Yo-Yo',
      'Kite',
      'Toy Train'
    ]
  };

  final Map<String, IconData> categoryIcons = {
    'Electronics': Icons.devices,
    'Clothing': Icons.shopping_bag,
    'Groceries': Icons.local_grocery_store,
    'Furniture': Icons.weekend,
    'Toys': Icons.toys,
    'Electronics1': Icons.devices,
    'Clothing2': Icons.shopping_bag,
    'Groceries3': Icons.local_grocery_store,
    'Furniture4': Icons.weekend,
    'Toys5': Icons.toys,
  };

  String selectedCategory = 'Electronics';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  void scrollToCategory(String category) {
    int index = categories.keys.toList().indexOf(category);
    if (index != -1) {
      _scrollController.animateTo(
        index * 450.0,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Module Screen', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: Icon(Icons.search), onPressed: () {}),
          IconButton(icon: Icon(Icons.shopping_cart), onPressed: () {}),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 110,
            color: Colors.grey[100],
            child: ListView(
              children: categories.keys.map((category) {
                return Column(
                  children: [
                    ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(categoryIcons[category]), // Icon at the top
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      selected: selectedCategory == category,
                      selectedTileColor: Colors.red,
                      selectedColor: Colors.green,
                      onTap: () {
                        setState(() {
                          selectedCategory = category;
                        });
                        scrollToCategory(category);
                      },
                    ),
                    Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              padding: EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search anything...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      children: categories.keys.map((category) {
                        List<String> filteredItems = categories[category]!
                            .where((item) => item
                                .toLowerCase()
                                .contains(_searchController.text.toLowerCase()))
                            .toList();
                        return Container(
                          color: selectedCategory == category
                              ? const Color.fromARGB(255, 248, 245, 245)
                              : Colors.transparent,
                          padding: EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Divider(),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio:
                                      1, // Adjust this to control the aspect ratio of the grid items
                                ),
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Handle tap event here
                                      print('Container tapped!');
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      // margin: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize
                                              .min, // Adjusts the column size to fit its children
                                          children: [
                                            Container(
                                              width:
                                                  50.0, // Set your desired width
                                              height:
                                                  50.0, // Set your desired height
                                              decoration: BoxDecoration(
                                                shape: BoxShape
                                                    .circle, // Make the container circular
                                                border: Border.all(
                                                  color: Colors
                                                      .black, // Set the border color
                                                  width:
                                                      0.5, // Set the border width
                                                ),
                                              ),
                                              child: ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl:
                                                      'https://teamloser.in/files/report.png',
                                                  placeholder: (context, url) =>
                                                      CircularProgressIndicator(),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Icon(Icons.error),
                                                  fit: BoxFit
                                                      .cover, // This will ensure the image covers the circular area
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                                height:
                                                    8), // Space between the avatar and the text
                                            Text(
                                              filteredItems[index],
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold),
                                              textAlign: TextAlign
                                                  .center, // Center the text
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
