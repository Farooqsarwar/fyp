import "package:flutter/material.dart";

import "../utils/customcontainer.dart";
import "../utils/customlisttile.dart";
import "../utils/customtextfield.dart";
import "mainscreen.dart";
class LiveBidscreen extends StatelessWidget {
  const LiveBidscreen({super.key});
  @override
  Widget build(BuildContext context) {
    return MainScreen(
        content: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Bid Title",
              style: TextStyle(color: Colors.white, fontSize: 40)),
          const SizedBox(height: 2),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Ends In",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              Text("Highest Bid",
                  style: TextStyle(color: Colors.white, fontSize: 20))
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CustomContainer(
                    number: "00",
                  ),
                  const Text(":",
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                  CustomContainer(number: "15"),
                  const Text(":",
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                  CustomContainer(number: "34"),
                ],
              ),
              const Text("400,000 PKR",
                  style: TextStyle(color: Colors.white, fontSize: 20))
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          const Text("All Bids",
              style: TextStyle(color: Colors.yellow, fontSize: 20)),
          const SizedBox(
            height: 5,
          ),
          CustomListTile(
              image: Image.asset("assets/person1.png"),
              titleText: "maxwell",
              trailingText: "30,000 PKR"),
          const SizedBox(
            height: 5,
          ),
          CustomListTile(
              image: Image.asset("assets/person2.png"),
              titleText: "mitchel starc",
              trailingText: "35,000 PKR"),
          const SizedBox(
            height: 5,
          ),
          CustomListTile(
              image: Image.asset("assets/person3.png"),
              titleText: "Babar Azam",
              trailingText: "40,000 PKR"),
          const SizedBox(
            height: 10,
          ),
          const Text("Your Bid",
              style: TextStyle(color: Colors.white, fontSize: 20)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomTextField(text: "Enter Bid"),
              // ignore: avoid_unnecessary_containers
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color.fromRGBO(51, 51, 51, 1),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("30,000 PKR",
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(
                      width: 10,
                    ),
                    GestureDetector(
                      child: const Icon(
                        Icons.add,
                        color: Colors.yellow,
                      ),
                      onTap: () {
                        //Incrementing Code.....
                      },
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                child: const Text(
                  "Offer Your Bid",
                  style: TextStyle(color: Colors.black),
                ),
                onPressed: () {
                  //Offer Bid......
                },
              )
            ],
          )
        ],
      ),
    ));
  }
}