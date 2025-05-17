import 'package:flutter/material.dart';

class Art_Furniture_Detials_Screen extends StatefulWidget {
  final String imageUrl;
  final String title;
  final bool isArt; // True for art, False for furniture
  final Map<String, dynamic>? itemData;

  const Art_Furniture_Detials_Screen({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.isArt,
    this.itemData,
  });

  @override
  State<Art_Furniture_Detials_Screen> createState() => _Art_Furniture_Detials_ScreenState();
}

class _Art_Furniture_Detials_ScreenState extends State<Art_Furniture_Detials_Screen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Extract item details from itemData
    final price = widget.itemData?['price'] ?? 'N/A';
    final description = widget.itemData?['description'] ??
        (widget.isArt
            ? 'Beautiful handcrafted art piece by a local artist.'
            : 'High-quality furniture piece, perfect for any home.');

    // Art specific details
    final artist = widget.isArt ? (widget.itemData?['artist'] ?? 'Unknown Artist') : null;
    final medium = widget.isArt ? (widget.itemData?['medium'] ?? 'Mixed Media') : null;
    final dimensions = widget.isArt ? (widget.itemData?['dimensions'] ?? 'N/A') : null;

    // Furniture specific details
    final material = !widget.isArt ? (widget.itemData?['material'] ?? 'Wood') : null;
    final condition = !widget.isArt ? (widget.itemData?['condition'] ?? 'New') : null;

    // Common details
    final startTime = widget.itemData?['start_time'] ?? 'N/A';
    final endTime = widget.itemData?['end_time'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isArt ? 'Art Details' : 'Furniture Details',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.imageUrl,
                width: double.infinity,
                height: screenHeight * 0.35,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: screenHeight * 0.35,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 80, color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Title and Price Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$price PKR',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description Section
            Text(
              'Description',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                description,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),

            const SizedBox(height: 20),

            // Details Section
            Text(
              'Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.isArt
                    ? [
                  _buildDetailRow('Artist:', artist ?? 'Unknown'),
                  _buildDetailRow('Medium:', medium ?? 'N/A'),
                  _buildDetailRow('Dimensions:', dimensions ?? 'N/A'),
                ]
                    : [
                  _buildDetailRow('Material:', material ?? 'N/A'),
                  _buildDetailRow('Condition:', condition ?? 'N/A'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Auction Timing Section
            Text(
              'Auction Timing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Starts:', startTime.toString()),
                  _buildDetailRow('Ends:', endTime.toString()),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFECD801),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        showDialogueBox(context, "Your Bid has been placed");
                      },
                      child: const Text(
                        "Place Bid",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFECD801)),
                        ),
                      ),
                      onPressed: () {
                        showDialogueBox(context, "AR Visualization Coming Soon");
                      },
                      child: const Text(
                        "AR View",
                        style: TextStyle(
                          color: Color(0xFFECD801),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showDialogueBox(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1C),
          title: Text(
            title,
            style: const TextStyle(color: Colors.yellow),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.yellow),
              ),
            ),
          ],
        );
      },
    );
  }
}