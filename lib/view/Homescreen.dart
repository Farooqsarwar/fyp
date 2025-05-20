import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import '../models/fetching data.dart';
import 'All_cars_screen.dart';
import 'Appbar.dart';
import 'Cars_Bid_detial_and placing.dart';
import 'Drawer.dart';
import 'Exit_permission.dart';
import 'Navigationbar.dart';
import 'all_art_screen.dart';
import 'all_furniture_screen.dart';
import 'Art_Furniture_detials_screen.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  final BidsService _bidsService = BidsService();
  late int carousalindx = 0;

  List<Map<String, dynamic>> allBids = [];
  List<Map<String, dynamic>> carBids = [];
  List<Map<String, dynamic>> artBids = [];
  List<Map<String, dynamic>> furnitureBids = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBids();
    _bidsService.addListener(_handleBidsUpdate);
  }

  void _handleBidsUpdate() {
    fetchBids();
  }

  Future<void> fetchBids() async {
    try {
      setState(() => isLoading = true);
      final bidsData = await _bidsService.fetchAllBids();
      setState(() {
        allBids = bidsData['allBids'];
        carBids = bidsData['carBids'];
        artBids = bidsData['artBids'];
        furnitureBids = bidsData['furnitureBids'];
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching bids: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _bidsService.removeListener(_handleBidsUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => await ExitConfirmation.showExitDialog(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: const Appbar(),
        bottomNavigationBar: const Navigationbar(),
        endDrawer: const CustomDrawer(),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildBidsCarousel(),
              const SizedBox(height: 10),
              if (allBids.isNotEmpty) _buildPlaceBidButton(),
              if (carBids.isNotEmpty) ...[
                _buildCategorySection('Cars', carBids, const AllCarsScreen()),
                _buildHorizontalBidList(carBids, 'car'),
              ],
              if (furnitureBids.isNotEmpty) ...[
                _buildCategorySection('Furniture', furnitureBids, const AllFurnitureScreen()),
                _buildHorizontalBidList(furnitureBids, 'furniture'),
              ],
              if (artBids.isNotEmpty) ...[
                _buildCategorySection('Art', artBids, const AllArtScreen()),
                _buildHorizontalBidList(artBids, 'art'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidsCarousel() {
    if (allBids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Text(
          'No bids available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider(
          items: allBids.map((bid) {
            final hasImages = bid['images'] != null && (bid['images'] as List).isNotEmpty;
            final isArt = bid['category'] == 'Art';
            final isFurniture = bid['category'] == 'Furniture';

            return GestureDetector(
              onTap: () {
                if (isArt || isFurniture) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Art_Furniture_Detials_Screen(
                        imageUrl: hasImages ? bid['images'][0] : '',
                        title: bid['bid_name'] ?? 'Untitled Bid',
                        isArt: isArt,
                        itemData: bid,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CarBidDetails(
                        imageUrl: hasImages ? bid['images'][0] : '',
                        title: bid['bid_name'] ?? 'Untitled Bid',
                        carData: bid,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Card(
                  color: const Color(0xFF1C1C1C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: hasImages
                              ? Image.network(
                            bid['images'][0],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error, color: Colors.red),
                          )
                              : const Icon(Icons.image_not_supported,
                              color: Colors.grey, size: 100),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bid['bid_name'] ?? 'Untitled Bid',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              bid['category'],
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          options: CarouselOptions(
            height: 350,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.5,
            onPageChanged: (index, reason) {
              setState(() => carousalindx = index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceBidButton() {
    final bid = allBids[carousalindx];
    final isArt = bid['category'] == 'Art';
    final isFurniture = bid['category'] == 'Furniture';
    final hasImages = bid['images'] != null && (bid['images'] as List).isNotEmpty;

    return TextButton(
      onPressed: () {
        if (isArt || isFurniture) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Art_Furniture_Detials_Screen(
                imageUrl: hasImages ? bid['images'][0] : '',
                title: bid['bid_name'] ?? 'Untitled Bid',
                isArt: isArt,
                itemData: bid,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CarBidDetails(
                imageUrl: hasImages ? bid['images'][0] : '',
                title: bid['bid_name'] ?? 'Untitled Bid',
                carData: bid,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 150,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFECD801),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text(
            "Place Bid",
            style: TextStyle(color: Colors.black, fontSize: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<Map<String, dynamic>> bids, Widget viewAllScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => viewAllScreen),
            ),
            child: const Text(
              "View All",
              style: TextStyle(color: Color(0xFFECD801), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBidList(List<Map<String, dynamic>> bids, String category) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: bids.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final bid = bids[index];
          final hasImages = bid['images'] != null && (bid['images'] as List).isNotEmpty;
          final isArt = category == 'art';
          final isFurniture = category == 'furniture';

          return GestureDetector(
            onTap: () {
              if (isArt || isFurniture) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Art_Furniture_Detials_Screen(
                      imageUrl: hasImages ? bid['images'][0] : '',
                      title: bid['bid_name'] ?? 'Untitled Bid',
                      isArt: isArt,
                      itemData: bid,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarBidDetails(
                      imageUrl: hasImages ? bid['images'][0] : '',
                      title: bid['bid_name'] ?? 'Untitled Bid',
                      carData: bid,
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: hasImages
                          ? Image.network(
                        bid['images'][0],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.broken_image, color: Colors.white),
                            ),
                      )
                          : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image_not_supported, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bid['bid_name'] ?? 'Untitled',
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${bid['price'] ?? 'N/A'} PKR',
                    style: const TextStyle(color: Colors.yellow, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}