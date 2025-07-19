import 'package:flutter/material.dart';
import '../models/fetching data.dart';
import 'Appbar.dart';
import 'Art_Furniture_detials_screen.dart';
import 'Drawer.dart';
import 'Homescreen.dart';
import 'Navigationbar.dart';

class AllArtScreen extends StatefulWidget {
  const AllArtScreen({super.key});

  @override
  State<AllArtScreen> createState() => _AllArtScreenState();
}

class _AllArtScreenState extends State<AllArtScreen> {
  final BidsService _bidsService = BidsService();
  List<Map<String, dynamic>> artData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchArtData();
    // Add listener to update UI when data changes
    _bidsService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    _bidsService.removeListener(_onDataChanged);
    super.dispose();
  }

  // Callback for when data changes
  void _onDataChanged() {
    fetchArtData();
  }

  Future<void> fetchArtData() async {
    try {
      setState(() => _loading = true);
      final data = await _bidsService.fetchArtBids();
      setState(() {
        artData = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching art: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Homescreen()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar:  Appbar(),
        bottomNavigationBar: const Navigationbar(),
        endDrawer: const CustomDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : artData.isEmpty
            ? const Center(
          child: Text(
            'No art available',
            style: TextStyle(color: Colors.white),
          ),
        )
            : ListView.builder(
          itemCount: artData.length,
          itemBuilder: (context, index) {
            final art = artData[index];
            final imageUrl = _bidsService.getFirstImageUrl(art);

            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtFurnitureDetailsScreen(
                        imageUrl: imageUrl,
                        title: art['bid_name'] ?? 'No Title',
                        isArt: true,  // Changed to true for art items
                        itemData: art,
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
                                  child: const Icon(
                                    Icons.error,
                                    color: Colors.white,
                                  ),
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
                                art['bid_name'] ?? 'No Title',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                              Text(
                                "Bid Start: ${_bidsService.formatDateTime(art['start_time'])}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                              Text(
                                "${art['price'] ?? 'N/A'} pkr",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              if (art['is_active'] == true)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[800],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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