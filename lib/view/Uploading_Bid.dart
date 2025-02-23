import 'package:flutter/material.dart';

import 'Homescreen.dart';
import 'Navigationbar.dart';

class UploadingBid extends StatefulWidget {
  const UploadingBid({super.key});

  @override
  State<UploadingBid> createState() => _UploadingBidState();
}
class _UploadingBidState extends State<UploadingBid> {
  String selectedCategory = "Car"; // Default selection

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
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          bottomNavigationBar: const Navigationbar(),
          body: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.add_photo_alternate,
                      size: 200,
                      color: Colors.white,
                    )),
                // Category Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text(
                        'Car',
                        style: TextStyle(color: Colors.white),
                      ),
                      selected: selectedCategory == "Car",
                      backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
                      selectedColor: Colors.green,
                      onSelected: (bool selected) {
                        setState(() {
                          selectedCategory = "Car";
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text(
                        'Furniture',
                        style: TextStyle(color: Colors.white),
                      ),
                      selected: selectedCategory == "Furniture",
                      backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
                      selectedColor: Colors.green,
                      onSelected: (bool selected) {
                        setState(() {
                          selectedCategory = "Furniture";
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text(
                        'Art',
                        style: TextStyle(color: Colors.white),
                      ),
                      selected: selectedCategory == "Art",
                      backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
                      selectedColor: Colors.green,
                      onSelected: (bool selected) {
                        setState(() {
                          selectedCategory = "Art";
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (selectedCategory == "Car") ...CarInputs(),
                if (selectedCategory == "Furniture" || selectedCategory == "Art")
                  ...FurnitureAndArtInputs(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List CarInputs() {
    return [
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Make'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Model'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Year'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Fuel'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Registration cit'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Distance'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Horse Power'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.only(right: 159, bottom: 5),
        child: Text(
          "Transmission",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      Row(
        children: [
          const SizedBox(
            width: 55,
          ),
          ChoiceChip(
            label: const Text(
              'Automatic',
              style: TextStyle(color: Colors.white),
            ),
            selected: false,
            backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
            selectedColor: Colors.green,
            onSelected: (bool selected) {},
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text(
              'Manual',
              style: TextStyle(color: Colors.white),
            ),
            selected: false,
            backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
            selectedColor: Colors.green,
            onSelected: (bool selected) {},
          ),
        ],
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Price'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 100, // Adjusted the height of the TextField
        child: TextField(
          maxLines: 5, // Allows for multiple lines of text
          decoration: InputDecoration(
            label: Text('Description'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
            contentPadding: EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 10), // Controls inner padding for height
          ),
        ),
      ),
      const SizedBox(
        height: 15,
      ),
      postbutton(),
    ];
  }

  List FurnitureAndArtInputs() {
    return [
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Name'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 50,
        child: TextField(
          decoration: InputDecoration(
            label: Text('Price'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 300,
        height: 100,
        child: TextField(
          maxLines: 5,
          decoration: InputDecoration(
            label: Text('Description'),
            labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            fillColor: Color.fromRGBO(27, 27, 27, 1),
            contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          ),
        ),
      ),
      const SizedBox(
        height: 15,
      ),
      postbutton(),
    ];
  }

  Widget postbutton() {
    return TextButton(
        onPressed: () {
          //to post
        },
        child: Container(
          width: 105,
          height: 35,
          decoration: BoxDecoration(
              color: const Color(0xFFECD801),
              borderRadius: BorderRadius.circular(15)),
          child: const Center(
              child: Text(
            "post",
            style: TextStyle(color: Colors.black, fontSize: 20),
          )),
        ));
  }
}
