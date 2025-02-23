import 'package:flutter/material.dart';

class Forgetpassword extends StatefulWidget {
  const Forgetpassword({super.key});
  @override
  State<Forgetpassword> createState() => _ForgetpasswordState();
}
class _ForgetpasswordState extends State<Forgetpassword> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 100,),
              const Text("Forget Password",
                style:TextStyle(
                  color: Colors.white,
                    fontFamily:"Nunito",
                    fontSize: 30,
                  wordSpacing: 5,
                  letterSpacing: 2
                ),),
              const SizedBox(height: 5,),
              const Text("Enter Email to reset",
                style:TextStyle(
                  color: Colors.white,
                    fontWeight: FontWeight.normal,
                    fontSize: 20
                ),),
              Image.asset("assets/forget.png",
                width: 430,
                height: 380,
                fit: BoxFit.fitWidth,
              ),
              const SizedBox(height: 25,),
              SizedBox(
                width: 350,height: 58,
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined,color: Color(0xFFFFFFFF),size: 30,),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20)
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10,),
              TextButton(
                  onPressed: (){
                  },
                  child:Container(
                    width: 300,height: 50,
                    decoration: BoxDecoration(
                        color: const Color(0xFFECD801),
                        borderRadius: BorderRadius.circular(15)
                    ),
                    child: const Center(child: Text("Continue",
                      style:TextStyle(
                          color: Colors.black,
                          fontSize: 25
                      ) ,)),
                  )),
              TextButton(
                  onPressed: (){
                    Navigator.pop(context);
                  },
                  child:Container(
                    width: 300,height: 50,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.black, // Border color
                        width: 2.0,         // Border width
                      ),
                    ),
                    child: const Center(child: Text("Cancel",
                      style:TextStyle(
                          color: Colors.black,
                          fontSize: 25
                      ) ,)),
                  )),
                       ],
          ),
        ),
      ),
    );
  }
}