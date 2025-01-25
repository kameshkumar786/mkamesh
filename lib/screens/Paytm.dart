import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class Paytm extends StatefulWidget {
  @override
  _PaytmState createState() => _PaytmState();
}

class _PaytmState extends State<Paytm> {
  int _currentIndex = 0;
  int _currentIndexUp = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      title: Row(
        children: [
          Icon(Icons.dehaze, color: Colors.white),
          SizedBox(width: 28),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Icon(Icons.search, color: Colors.blue),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.notifications, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      elevation: 0,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue[800],
            child: CarouselSlider.builder(
              itemCount: 2,
              options: CarouselOptions(
                aspectRatio: 5,
                viewportFraction: 1.0,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentIndexUp = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                return GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  children: List.generate(4, (gridIndex) {
                    return _buildTopGridItem(
                      _getGridList()[gridIndex + (_currentIndexUp * 4)],
                    );
                  }),
                );
              },
            ),
          ),
          Container(
            color: Colors.blue[800],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                return _buildDots(_currentIndexUp, index);
              }),
            ),
          ),
          Container(
            color: Colors.white,
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.highlight, color: Colors.black),
                Text(
                  'Get Rs.1000 Cashback on Auto/Taxi rides!',
                  style: TextStyle(fontSize: 15, color: Colors.black),
                ),
                Icon(Icons.arrow_forward, size: 15, color: Colors.black),
              ],
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            children: List.generate(12, (index) {
              return _buildGridItem(_getGridItemList()[index]);
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CarouselSlider.builder(
              itemCount: _getImageSliderList().length,
              options: CarouselOptions(
                aspectRatio: 2,
                viewportFraction: 1.0,
                autoPlay: true,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                return _buildImageSliderItem(_getImageSliderList()[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.white,
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Mall'),
        BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'Scan'),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_balance), label: 'Bank'),
        BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
      ],
    );
  }

  Widget _buildGridItem(GridModel model) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 30, color: Colors.blue),
          SizedBox(height: 5),
          Text(
            model.title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildTopGridItem(GridModel model) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image, size: 30, color: Colors.white),
        SizedBox(height: 5),
        Text(
          model.title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildImageSliderItem(ImageSliderModel model) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(model.path, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildDots(int currentIndex, int index) {
    return Container(
      margin: const EdgeInsets.all(4),
      width: currentIndex == index ? 10 : 8,
      height: currentIndex == index ? 10 : 8,
      decoration: BoxDecoration(
        shape: currentIndex == index ? BoxShape.rectangle : BoxShape.circle,
        color: currentIndex == index ? Colors.white : Colors.grey,
      ),
    );
  }

  List<GridModel> _getGridList() {
    return List.generate(8, (index) => GridModel("Title $index"));
  }

  List<GridModel> _getGridItemList() {
    return List.generate(12, (index) => GridModel("Item $index"));
  }

  List<ImageSliderModel> _getImageSliderList() {
    return List.generate(
        4, (index) => ImageSliderModel("assets/image_$index.jpg"));
  }
}

class GridModel {
  final String title;

  GridModel(this.title);
}

class ImageSliderModel {
  final String path;

  ImageSliderModel(this.path);
}
