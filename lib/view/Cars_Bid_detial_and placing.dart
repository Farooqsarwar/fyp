import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'Predict_price_screen.dart';

class Car_Bid_details extends StatefulWidget {
  final String imageUrl;
  final String title;
  final bool art;

  const Car_Bid_details({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.art,
  });
  @override
  State<Car_Bid_details> createState() => _Car_Bid_detialsState();
}
class _Car_Bid_detialsState extends State<Car_Bid_details> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      width: screenWidth,
                      height: screenHeight * 0.5, // 50% of the screen height
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.4,
                    child: Container(
                      width: screenWidth,
                      height: screenHeight * 0.1, // 10% of the screen height
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: const Color.fromRGBO(
                            27, 27, 27, 0.6980392156862745),
                      ),
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.4,
                    left: 10,
                    child: const Text(
                      "Bid Initial Price",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.465,
                    right: 15,
                    child: const Text(
                      "Total Bids",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(120)),
                      color: Color.fromRGBO(0, 0, 0, 0.76)
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 25,
                        color: Colors.yellow,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Container(
                width: screenWidth * 0.95, // 95% of screen width
                height: screenHeight * 0.09, // 9% of screen height
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  color: Color.fromRGBO(27, 27, 27, 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 17.0, left: 10),
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              if (!widget.art)
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shutter_speed,
                            color: Colors.white,
                            size: screenWidth * 0.08,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          const Text(
                            '12 to 16 km/hr',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.gears,
                            color: Colors.white,
                            size: screenWidth * 0.08,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          const Text(
                            'Automatic',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.gasPump,
                            color: Colors.white,
                            size: screenWidth * 0.07,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          const Text(
                            'Petrol',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              // SizedBox(height: screenHeight * 0.02),
              Padding(
                padding: EdgeInsets.all(screenWidth * 0.02),
                child: const Text(
                  "B2B Genuine, 1st owner, Bio Available, Extra Accessories installed. Just like a Zero Meter car.",
                  textAlign: TextAlign.justify,
                  style: TextStyle(color: Colors.white, fontSize: 17),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      showDialogueBox(
                        context,
                        "Your Bid has been placed",
                      );
                    },
                    child: Container(
                      width: screenWidth * 0.4, // 40% of screen width
                      height: screenHeight * 0.07, // 7% of screen height
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
                  ),
                  TextButton(
                    onPressed: () {
                      if (widget.art) {

                      } else {
                        // Navigate to the Predict Price screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PredictScreen(
                              imageurl: widget.imageUrl,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: screenWidth * 0.45,
                      height: screenHeight * 0.07,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECD801),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          widget.art ? "AR Visualization" : "Predict Price",
                          style: const TextStyle(color: Colors.black, fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showDialogueBox(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 27, 27, 27),
          title: Text(
            title,
            style: const TextStyle(color: Colors.yellow),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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
