import 'package:flutter/material.dart';
import '../models/fetching data.dart';
import 'Appbar.dart';
import 'Art_Furniture_detials_screen.dart';
import 'Cars_Bid_detial_and placing.dart';
import 'Drawer.dart';
import 'Homescreen.dart';
import 'Navigationbar.dart';

class AllFurnitureScreen extends StatefulWidget {
  const AllFurnitureScreen({super.key});

  @override
  State<AllFurnitureScreen> createState() => _AllFurnitureScreenState();
}

class _AllFurnitureScreenState extends State<AllFurnitureScreen> {
  final BidsService _bidsService = BidsService();
  List<Map<String, dynamic>> furnitureData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchFurnitureData();
    // Add listener for real-time updates
    _bidsService.addListener(_handleBidsUpdate);
  }

  void _handleBidsUpdate() {
    fetchFurnitureData();
  }

  Future<void> fetchFurnitureData() async {
    try {
      setState(() => _loading = true);

      // Use the BidsService to fetch furniture bids
      final furniture = await _bidsService.fetchFurnitureBids();

      setState(() {
        furnitureData = furniture;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching furniture: $e");
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    // Remove listener when disposed
    _bidsService.removeListener(_handleBidsUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Homescreen()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar:  Appbar(),
        bottomNavigationBar: const Navigationbar(),
        endDrawer: CustomDrawer(),
        body: _loading
            ? Center(child: CircularProgressIndicator())
            : furnitureData.isEmpty
            ? Center(child: Text('No furniture available', style: TextStyle(color: Colors.white)))
            : ListView.builder(
          itemCount: furnitureData.length,
          itemBuilder: (context, index) {
            final furnitureItem = furnitureData[index];
            final imageUrl = _bidsService.getFirstImageUrl(furnitureItem);

            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtFurnitureDetailsScreen(
                        imageUrl: imageUrl,
                        title: furnitureItem['title'] ?? 'No Title',
                        isArt: false,
                        itemData: furnitureItem,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0Xff1C1C1C),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 3),
                      // Image container with fixed width
                      Container(
                        width: 135,
                        height: 145,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey,
                                  child: Icon(Icons.error, color: Colors.white),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Text content that can expand
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                furnitureItem['title'] ?? 'No Title',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                              Text(
                                "Bid Start: ${_bidsService.formatDateTime(furnitureItem['start_time'])}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                              Text(
                                "${furnitureItem['price'] ?? 'N/A'} pkr",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10), // Add some right padding
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}