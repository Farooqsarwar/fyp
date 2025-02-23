import "package:flutter/material.dart";
class BidWinScreen extends StatelessWidget {
  const BidWinScreen({super.key});
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
                child: Image.asset("assets/art.png")),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 70,
                    color: const Color.fromRGBO(0, 0, 0, 0.76),
                  )
                ),
                Positioned(
                  bottom: -30,
                  left: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 60,
                    child: Image.asset("assets/person1.png"),
                  )
                ),
              ],
            ),
            const SizedBox(height: 50,),
            const Text("Congratulations", style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 5,),
            const Text("MaxWell", style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 50,),
            const Text("Winner of Afghani stencil art", style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 20,),
            const Text("Contact with seller", style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 50,),
            ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
            child: const Text(
              "Contact",
              style: TextStyle(color: Colors.black),
            ),
            onPressed: () {
              //Code......
            },
          )
          ],
        ),
      )),
    );
  }
}
