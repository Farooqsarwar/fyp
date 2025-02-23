import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Appbar.dart';
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
  List<dynamic> furnituredata = [];
  Future<void> loadJsonData() async {
    final String response = await rootBundle.loadString('assets/furniture.json');
    final data = json.decode(response);
    setState(() {
      furnituredata = data;
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
          itemCount: furnituredata.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Car_Bid_details(
                            imageUrl: furnituredata[index]['image'],
                            title: furnituredata[index]['title'],
                            art: true,)
                      ));
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
                          furnituredata[index]['image'],
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
                            furnituredata[index]['title'],
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
