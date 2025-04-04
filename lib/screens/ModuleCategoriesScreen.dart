import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mkamesh/screens/formscreens/FormPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mkamesh/screens/formscreens/DoctypeListView.dart';

class ModuleCategoriesScreen extends StatefulWidget {
  @override
  _ModuleCategoriesScreenState createState() => _ModuleCategoriesScreenState();
}

class _ModuleCategoriesScreenState extends State<ModuleCategoriesScreen> {
  List<dynamic> categories = [];
  bool isLoading = true;
  String selectedCategory = '';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchModules();
  }

  Future<void> fetchModules() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('http://localhost:8000/api/method/get_module_data'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': '$token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        categories = data['message']['data'];
        selectedCategory =
            categories.isNotEmpty ? categories[0]['module_name'] : '';
        isLoading = false;
      });
    } else {
      throw Exception('Failed to load modules');
    }
  }

  void scrollToCategory(String category) {
    int index =
        categories.indexWhere((module) => module['module_name'] == category);
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60), // Increased height for TextField
        child: AppBar(
          automaticallyImplyLeading: false, // Removes back button

          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   'Module Screen',
              //   style: TextStyle(fontSize: 16, color: Colors.black),
              // ),
              // SizedBox(height: 8), // Spacing between title and TextField
              Container(
                height: 40,
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.black,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {}); // Update UI after clearing text
                            },
                          )
                        : null,
                    // labelText: 'Search anything...',
                    // labelStyle: TextStyle(fontSize: 14, color: Colors.black),
                    hintText: 'Search Something...',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
              children: [
                //Sidebar hai
                Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: Colors.grey, // Color of the right border
                        width: 0.5, // Width of the right border
                      ),
                    ),
                  ),
                  child: ListView(
                    children: categories.map((category) {
                      bool isSelected = selectedCategory ==
                          category[
                              'module_name']; // Check if the item is selected
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey,
                              width: 0.5,
                            ), // Bottom border for each item
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero, // Remove default padding
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // CachedNetworkImage(
                                    //   imageUrl:
                                    //       'http://localhost:8000${category['image_yjor']}',
                                    //   placeholder: (context, url) =>
                                    //       CircularProgressIndicator(),
                                    //   errorWidget: (context, url, error) =>
                                    //       Icon(Icons.error),
                                    //   fit: BoxFit.cover,
                                    // ),

                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        // border: Border.all(
                                        //     color: Colors.grey, width: 0.5),
                                      ),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          height: 30,
                                          imageUrl:
                                              'http://localhost:8000${category['image']}',
                                          placeholder: (context, url) =>
                                              CircularProgressIndicator(),
                                          errorWidget: (context, url, error) =>
                                              Icon(Icons.error),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),

                                    SizedBox(
                                      height: 5,
                                    ),
                                    // Icon(
                                    //   categoryIcons[category],
                                    //   color: isSelected
                                    //       ? Colors.black
                                    //       : Colors
                                    //           .grey, // Set icon color based on selection
                                    // ), // Icon at the top
                                    Text(
                                      category['module_name'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? null
                                            : Colors
                                                .grey, // Set text color based on selection
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                selectedTileColor: Colors.red,
                                selectedColor: Colors.black,
                                onTap: () {
                                  setState(() {
                                    selectedCategory = category['module_name'];
                                  });
                                  scrollToCategory(category['module_name']);
                                },
                              ),
                            ),
                            // Right border for the selected item
                            if (isSelected)
                              Container(
                                width: 5, // Width of the right border
                                height:
                                    80, // Set height to match the ListTile height
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black, // Color of the right border
                                  borderRadius: BorderRadius.only(
                                    topLeft:
                                        Radius.circular(5), // Top left radius
                                    bottomLeft: Radius.circular(
                                        5), // Bottom left radius
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ), // Main Content

                //main Content

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TextField(
                        //   controller: _searchController,
                        //   decoration: InputDecoration(
                        //     prefixIcon: Icon(Icons.search),
                        //     labelText: 'Search anything...',
                        //     labelStyle:
                        //         TextStyle(fontSize: 14, color: Colors.black),
                        //     hintText: 'Search anything...',
                        //     hintStyle:
                        //         TextStyle(fontSize: 14, color: Colors.grey),
                        //     border: OutlineInputBorder(
                        //         borderRadius: BorderRadius.circular(15)),
                        //     focusedBorder: OutlineInputBorder(
                        //       borderRadius: BorderRadius.circular(15),
                        //       borderSide: BorderSide(color: Colors.black),
                        //     ),
                        //   ),
                        //   onChanged: (value) {
                        //     setState(() {});
                        //   },
                        // ),
                        // SizedBox(height: 10),
                        Expanded(
                          child: ListView(
                            controller: _scrollController,
                            children: categories.map((category) {
                              List<dynamic> items = category['items'];
                              List<dynamic> filteredItems = items.where((item) {
                                return item['label'].toLowerCase().contains(
                                    _searchController.text.toLowerCase());
                              }).toList();
                              return Container(
                                color:
                                    selectedCategory == category['module_name']
                                        ? Colors.grey[100]
                                        : Colors.transparent,
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category['module_name'],
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Divider(),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 1,
                                      ),
                                      itemCount: filteredItems.length,
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onTap: () {
                                            print(
                                                'Item tapped: ${filteredItems[index]['label']}');
                                            if (filteredItems[index]['type'] ==
                                                'Doctype') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      DoctypeListView(
                                                          doctype: filteredItems[
                                                                      index][
                                                                  'refrence_doctype'] ??
                                                              'home',
                                                          prefilters: []),
                                                ),
                                              );
                                            } else if (filteredItems[index]
                                                    ['type'] ==
                                                'Form') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      FrappeCrudForm(
                                                    doctype: filteredItems[
                                                            index]
                                                        ['refrence_doctype'],
                                                    docname: filteredItems[
                                                                index][
                                                            'refrence_docname'] ??
                                                        '',
                                                    baseUrl:
                                                        'http://localhost:8000',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: Colors.grey,
                                                      width: 0.2),
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                        'http://localhost:8000${filteredItems[index]['image']}',
                                                    placeholder: (context,
                                                            url) =>
                                                        CircularProgressIndicator(),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Icon(Icons.error),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                filteredItems[index]['label'],
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
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
