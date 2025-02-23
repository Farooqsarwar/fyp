import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  List<dynamic> carData = [];
  Future<void> loadJsonData() async {
    final String response = await rootBundle.loadString('assets/cars.json');
    final data = json.decode(response);
    setState(() {
      carData = data;
    });
  }

  @override
  void initState() {
    super.initState();
    loadJsonData();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Homescreen()),
        );
        // Prevent default back action
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: const Appbar(),
        bottomNavigationBar: const Navigationbar(),
        endDrawer:  CustomDrawer(),
        body: ListView.builder(
          itemCount: carData.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Car_Bid_details(
                              imageUrl: carData[index]['image'],
                              title: carData[index]['title'],
                            art: false,)));
                },
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                      color: const Color(0Xff1C1C1C),
                      borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 3,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          carData[index]['image'],
                          width: 135,
                          height: 145,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(
                        width: 15,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            carData[index]['title'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text(
                            "Bid Start Time",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text(
                            "40,000pkr",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      )
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
