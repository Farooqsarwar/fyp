import 'package:flutter/material.dart';
import '../models/fetching data.dart';
import 'Appbar.dart';
import 'Cars_Bid_detial_and placing.dart';
import 'Drawer.dart';
import 'Homescreen.dart';
import 'Navigationbar.dart';

class AllCarsScreen extends StatefulWidget {
  const AllCarsScreen({super.key});

  @override
  State<AllCarsScreen> createState() => _AllCarsScreenState();
}

class _AllCarsScreenState extends State<AllCarsScreen> {
  final BidsService _bidsService = BidsService();
  List<Map<String, dynamic>> carData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchCarData();
    // Add listener for real-time updates
    _bidsService.addListener(_handleBidsUpdate);
  }

  void _handleBidsUpdate() {
    fetchCarData();
  }

  Future<void> fetchCarData() async {
    try {
      setState(() => _loading = true);

      // Use the BidsService to fetch car bids
      final cars = await _bidsService.fetchCarBids();

      setState(() {
        carData = cars;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching cars: $e");
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
            ? const Center(child: CircularProgressIndicator())
            : carData.isEmpty
            ? Center(
          child: Text(
            'No cars available',
            style: TextStyle(color: Colors.white),
          ),
        )
            : RefreshIndicator(
          onRefresh: fetchCarData,
          child: ListView.builder(
            itemCount: carData.length,
            itemBuilder: (context, index) {
              final car = carData[index];
              final imageUrl = _bidsService.getFirstImageUrl(car);
              final title = _bidsService.formatTitle(car);
              final startTime = _bidsService.formatDateTime(car['start_time']);
              final price = car['price'] ?? 'N/A';

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  color: const Color(0Xff1C1C1C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CarBidDetailsScreen(
                            imageUrl: imageUrl,
                            title: title.isNotEmpty ? title : 'No Title',
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              imageUrl,
                              width: 120,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 120,
                                    height: 100,
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.car_repair,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Starts: $startTime',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.money,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$price PKR',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (car['is_active'] == true)
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
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}