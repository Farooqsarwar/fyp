import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp/view/all_furniture_screen.dart';
import 'All_cars_screen.dart';
import 'Appbar.dart';
import 'Cars_Bid_detial_and placing.dart';
import 'Drawer.dart';
import 'Exit_permission.dart';
import 'Navigationbar.dart';
import 'all_art_screen.dart';
class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  List<dynamic> carData = [];
  List<dynamic> ArtData = [];
  List<dynamic> FurnitureData = [];

  late int carousalindx = 0;

  @override
  void initState() {
    super.initState();
    loadJsonData();
  }

  Future<void> loadJsonData() async {
    try {
      // Load the first JSON file
      final String response1 = await rootBundle.loadString('assets/cars.json');
      final data1 = json.decode(response1);
      // Load the second JSON file
      final String response2 = await rootBundle.loadString('assets/art.json');
      final data2 = json.decode(response2);
      final String response3 = await rootBundle.loadString('assets/furniture.json');
      final data3 = json.decode(response3);
      setState(() {
        carData = data1;
        ArtData = data2;
        FurnitureData=data3;
      });
    } catch (e) {
      print("Error loading JSON files: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          return await ExitConfirmation.showExitDialog(context); // Show dialog on back press
        },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: const Appbar(),
        bottomNavigationBar: const Navigationbar(),
        endDrawer:   CustomDrawer(),
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(
                height: 30,
              ),
              CarouselSlider(
                items: carData.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> car = entry.value;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: carousalindx == index
                          ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: -10,
                          offset: const Offset(0, 10), // Creates an oval-like shadow
                        ),
                      ]
                          : [],
                    ),
                    child: Card(
                      color: Color.fromRGBO(0, 0, 0, 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                car['image'],
                                fit: BoxFit.cover,
                                width: 300,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                              child: Text(
                                car['title'],
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                options: CarouselOptions(
                  height: 350.0,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.5,
                  enableInfiniteScroll: true,
                  onPageChanged: (index, reason) {
                    setState(() {
                      carousalindx = index; // Update the index when the page changes
                    });
                  },
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Car_Bid_details(
                          imageUrl: carData[carousalindx]['image'],
                          // Passing image URL
                          title: carData[carousalindx]['title'], art: false, // Passing title
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 150,
                    height: 50,
                    decoration: BoxDecoration(
                        color: const Color(0xFFECD801),
                        borderRadius: BorderRadius.circular(15)),
                    child: const Center(
                        child: Text(
                      "Place Bid",
                      style: TextStyle(color: Colors.black, fontSize: 20),
                    )),
                  )),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Cars",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  TextButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AllCarsScreen()));
                      },
                      child: const Text(
                        "view all",
                        style: TextStyle(color: Color(0xFFECD801), fontSize: 20),
                      ))
                ],
              ),
              Car(carData),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Furniture",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  TextButton(
                      onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>AllFurnitureScreen()));
                      },
                      child: const Text(
                        "view all",
                        style: TextStyle(color: Color(0xFFECD801), fontSize: 20),
                      ))
                ],
              ),
              furniture(FurnitureData),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Art",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  TextButton(
                      onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>const AllArtScreen()));
                      },
                      child: const Text(
                        "view all",
                        style: TextStyle(color: Color(0xFFECD801), fontSize: 20),
                      ))
                ],
              ),
              Art(ArtData),
            ],
          ),
        ),
      ),
    );
  }
  Widget Car(List<dynamic> data) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Image.network(
              data[index]['image'],
              width: 125,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
  Widget Art(List<dynamic> data) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Image.network(
              data[index]['image'],
              width: 125,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
  Widget furniture(List<dynamic> data) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Image.network(
              data[index]['image'],
              width: 125,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}
