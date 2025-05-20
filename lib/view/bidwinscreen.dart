import "package:flutter/material.dart";

class BidWinScreen extends StatelessWidget {
  final String imageUrl;
  final String itemTitle;
  final String winningAmount;
  final bool isBidFinished; // Add a flag to indicate if the bid is finished

  const BidWinScreen({
    super.key,
    required this.imageUrl,
    required this.itemTitle,
    required this.winningAmount,
    required this.isBidFinished, // Required parameter for bid status
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 27, 27, 27).withOpacity(0.7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 70,
                      color: const Color.fromRGBO(0, 0, 0, 0.76),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 60,
                      child: Image.asset("assets/person1.png"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              if (isBidFinished) ...[
                // Winner Details Section
                const Text(
                  "Congratulations",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 5),
                const Text(
                  "MaxWell",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 50),
                Text(
                  "Winner of $itemTitle",
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 20),
                Text(
                  "Winning Bid: $winningAmount",
                  style: const TextStyle(color: Colors.yellow, fontSize: 20),
                ),
                const SizedBox(height: 50),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                  ),
                  child: const Text(
                    "Contact",
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () {
                    // Add contact functionality here
                  },
                ),
              ] else ...[
                // Ongoing Bid Section
                const Text(
                  "The bid is still ongoing!",
                  style: TextStyle(color: Colors.yellow, fontSize: 24),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Please check back later for results.",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}