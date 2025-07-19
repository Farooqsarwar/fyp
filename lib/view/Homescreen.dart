import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fetching data.dart';
import '../services/auction_services.dart';
import 'All_cars_screen.dart';
import 'Cars_Bid_detial_and placing.dart';
import 'Drawer.dart';
import 'Exit_permission.dart';
import 'Navigationbar.dart';
import 'all_art_screen.dart';
import 'all_furniture_screen.dart';
import 'Art_Furniture_detials_screen.dart';
import 'Uploading_Bid.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  final BidsService _bidsService = BidsService();
  final SupabaseClient _supabase = Supabase.instance.client;
  late AuctionService _auctionService;
  int carouselIndex = 0;

  // Search functionality variables
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Skeleton loading variables
  bool _isFirstLoad = true;
  bool _showSkeleton = true;

  List<Map<String, dynamic>> allBids = [];
  List<Map<String, dynamic>> carBids = [];
  List<Map<String, dynamic>> artBids = [];
  List<Map<String, dynamic>> furnitureBids = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _auctionService = AuctionService(supabase: _supabase);
    _auctionService.initialize();
    fetchBids();
    _bidsService.addListener(_handleBidsUpdate);
    _setupRealtime();

    // Hide skeleton after initial load
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
    });
  }

  void _handleBidsUpdate() {
    fetchBids();
  }

  void _setupRealtime() {
    for (final table in ['cars', 'art', 'furniture']) {
      _supabase
          .channel('public:$table')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) {
          fetchBids();
        },
      )
          .subscribe();
    }
  }

  Future<void> fetchBids() async {
    try {
      setState(() {
        isLoading = true;
        _showSkeleton = true;
      });

      final bidsData = await _bidsService.fetchAllBids();

      setState(() {
        allBids = bidsData['allBids']!.map<Map<String, dynamic>>((bid) {
          return {
            ...bid,
            'category': bid['item_type'] == 'cars'
                ? 'Car'
                : bid['item_type'] == 'art'
                ? 'Art'
                : 'Furniture',
          };
        }).toList();

        carBids = bidsData['carBids']!.map<Map<String, dynamic>>((bid) {
          return {...bid, 'category': 'Car', 'item_type': 'cars'};
        }).toList();

        artBids = bidsData['artBids']!.map<Map<String, dynamic>>((bid) {
          return {...bid, 'category': 'Art', 'item_type': 'art'};
        }).toList();

        furnitureBids = bidsData['furnitureBids']!.map<Map<String, dynamic>>((bid) {
          return {...bid, 'category': 'Furniture', 'item_type': 'furniture'};
        }).toList();

        isLoading = false;
        _showSkeleton = false;
      });
    } catch (e) {
      debugPrint("Error fetching bids: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching bids: $e')),
      );
      setState(() {
        isLoading = false;
        _showSkeleton = false;
      });
    }
  }

  void _handleSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = allBids.where((bid) {
        final lowerQuery = query.toLowerCase();
        final bidName = bid['bid_name']?.toString().toLowerCase() ?? '';
        final category = bid['category']?.toString().toLowerCase() ?? '';
        final description = bid['description']?.toString().toLowerCase() ?? '';
        final make = bid['make']?.toString().toLowerCase() ?? '';
        final model = bid['model']?.toString().toLowerCase() ?? '';
        final material = bid['material']?.toString().toLowerCase() ?? '';
        final style = bid['style']?.toString().toLowerCase() ?? '';

        return bidName.contains(lowerQuery) ||
            category.contains(lowerQuery) ||
            description.contains(lowerQuery) ||
            make.contains(lowerQuery) ||
            model.contains(lowerQuery) ||
            material.contains(lowerQuery) ||
            style.contains(lowerQuery);
      }).toList();
    });
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: CircleAvatar(
        backgroundColor: Colors.transparent,
        child: Image.asset(
          "assets/logo.jpg",
          width: 150,
          fit: BoxFit.fitWidth,
        ),
      ),
      backgroundColor: Colors.black,
      centerTitle: true,
      elevation: 2,
      title: SizedBox(
        width: 350,
        height: 50,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search bids...',
            hintStyle: const TextStyle(color: Colors.white70),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.search,
                color: Color(0xFFFFFFFF),
                size: 35,
              ),
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _handleSearch(_searchController.text);
                }
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.white),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.white),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.yellow),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _handleSearch,
          onSubmitted: (value) => _handleSearch(value),
        ),
      ),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _clearSearch,
          ),
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 30),
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
      ],
    );
  }
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final bid = _searchResults[index];
        final hasImages = bid['images'] != null && (bid['images'] as List).isNotEmpty;
        final isArt = bid['category'] == 'Art';
        final isFurniture = bid['category'] == 'Furniture';
        final isActive = bid['is_active'] && DateTime.now().isBefore(DateTime.parse(bid['end_time']));

        return ListTile(
          leading: hasImages
              ? Image.network(
            bid['images'][0],
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.error,
              color: Colors.red,
            ),
          )
              : const Icon(Icons.image_not_supported, color: Colors.grey),
          title: Text(
            bid['bid_name'] ?? 'Untitled Bid',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '${bid['category']} • ${bid['price'].toStringAsFixed(2)} PKR',
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: !isActive
              ? const Text(
            'Ended',
            style: TextStyle(color: Colors.red),
          )
              : null,
          onTap: () {
            if (isArt || isFurniture) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtFurnitureDetailsScreen(
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
                  builder: (context) => CarBidDetailsScreen(
                    imageUrl: hasImages ? bid['images'][0] : '',
                    title: bid['bid_name'] ?? 'Untitled Bid',
                    itemData: bid,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildSkeletonCarousel() {
    return Column(
      children: [
        CarouselSlider(
          items: List.generate(3, (index) => Container(
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
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100,
                          height: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 60,
                          height: 12,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 80,
                          height: 12,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
          options: CarouselOptions(
            height: 350,
            autoPlay: false,
            enlargeCenterPage: true,
            viewportFraction: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonHorizontalList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          return Container(
            width: 150,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  color: Colors.grey[700],
                ),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 12,
                  color: Colors.grey[700],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonPlaceBidButton() {
    return Container(
      width: 150,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  Widget _buildSkeletonCategorySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 60,
            height: 20,
            color: Colors.grey[700],
          ),
          Container(
            width: 80,
            height: 16,
            color: Colors.grey[700],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bidsService.removeListener(_handleBidsUpdate);
    _auctionService.dispose();
    _supabase.removeAllChannels();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          _clearSearch();
          return false;
        }
        return await ExitConfirmation.showExitDialog(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildAppBar(),
        bottomNavigationBar: const Navigationbar(),
        endDrawer: const CustomDrawer(),
        body: _isSearching
            ? _buildSearchResults()
            : (_isFirstLoad || isLoading)
            ? SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildSkeletonCarousel(),
              const SizedBox(height: 10),
              Center(child: _buildSkeletonPlaceBidButton()),
              const SizedBox(height: 20),
              _buildSkeletonCategorySection(),
              _buildSkeletonHorizontalList(),
              const SizedBox(height: 20),
              _buildSkeletonCategorySection(),
              _buildSkeletonHorizontalList(),
              const SizedBox(height: 20),
              _buildSkeletonCategorySection(),
              _buildSkeletonHorizontalList(),
              const SizedBox(height: 20),
            ],
          ),
        )
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
              if (artBids.isNotEmpty) ...[
                _buildCategorySection('Art', artBids, const AllArtScreen()),
                _buildHorizontalBidList(artBids, 'art'),
              ],
              if (furnitureBids.isNotEmpty) ...[
                _buildCategorySection('Furniture', furnitureBids, const AllFurnitureScreen()),
                _buildHorizontalBidList(furnitureBids, 'furniture'),
              ],
              const SizedBox(height: 20),
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
            final isActive = bid['is_active'] && DateTime.now().isBefore(DateTime.parse(bid['end_time']));

            return GestureDetector(
              onTap: () {
                if (isArt || isFurniture) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtFurnitureDetailsScreen(
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
                      builder: (context) => CarBidDetailsScreen(
                        imageUrl: hasImages ? bid['images'][0] : '',
                        title: bid['bid_name'] ?? 'Untitled Bid',
                        itemData: bid,
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
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: hasImages
                                  ? Image.network(
                                bid['images'][0],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                              )
                                  : const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 100,
                              ),
                            ),
                            if (!isActive)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  color: Colors.red,
                                  child: const Text(
                                    'Ended',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              bid['category'],
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            Text(
                              'Price: ${bid['price'].toStringAsFixed(2)} PKR',
                              style: const TextStyle(color: Colors.yellow, fontSize: 12),
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
              setState(() => carouselIndex = index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceBidButton() {
    final bid = allBids[carouselIndex];
    final isArt = bid['category'] == 'Art';
    final isFurniture = bid['category'] == 'Furniture';
    final hasImages = bid['images'] != null && (bid['images'] as List).isNotEmpty;
    final isActive = bid['is_active'] && DateTime.now().isBefore(DateTime.parse(bid['end_time']));

    return TextButton(
      onPressed: isActive
          ? () {
        if (isArt || isFurniture) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtFurnitureDetailsScreen(
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
              builder: (context) => CarBidDetailsScreen(
                imageUrl: hasImages ? bid['images'][0] : '',
                title: bid['bid_name'] ?? 'Untitled Bid',
                itemData: bid,
              ),
            ),
          );
        }
      }
          : null,
      child: Container(
        width: 150,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFECD801) : Colors.grey,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            isActive ? "Place Bid" : "Auction Ended",
            style: const TextStyle(color: Colors.black, fontSize: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<Map<String, dynamic>> bids, Widget viewAllScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
          final isActive = bid['is_active'] && DateTime.now().isBefore(DateTime.parse(bid['end_time']));

          return GestureDetector(
            onTap: () {
              if (isArt || isFurniture) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArtFurnitureDetailsScreen(
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
                    builder: (context) => CarBidDetailsScreen(
                      imageUrl: hasImages ? bid['images'][0] : '',
                      title: bid['bid_name'] ?? 'Untitled Bid',
                      itemData: bid,
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: hasImages
                              ? Image.network(
                            bid['images'][0],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.broken_image, color: Colors.white),
                            ),
                          )
                              : Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.image_not_supported, color: Colors.white),
                          ),
                        ),
                        if (!isActive)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              color: Colors.red,
                              child: const Text(
                                'Ended',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bid['bid_name'] ?? 'Untitled',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${bid['price'].toStringAsFixed(2)} PKR',
                    style: const TextStyle(color: Color(0xFFECD801), fontSize: 14),
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