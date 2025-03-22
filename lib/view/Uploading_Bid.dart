import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Navigationbar.dart';

class UploadingBid extends StatefulWidget {
  const UploadingBid({super.key});

  @override
  State<UploadingBid> createState() => _UploadingBidState();
}

class _UploadingBidState extends State<UploadingBid> {
  final ImagePicker picker = ImagePicker();
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, List<XFile>> categoryImages = {
    "Car": [],
    "Furniture": [],
    "Art": [],
  };

  String selectedCategory = "Car";
  String selectedTransmission = "Automatic";
  XFile? fullScreenImage;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController conditionController = TextEditingController();
  final TextEditingController materialController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController makeController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController fuelController = TextEditingController();
  final TextEditingController regCityController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController horsePowerController = TextEditingController();

  Future<void> pickImages() async {
    final List<XFile>? selectedImages = await picker.pickMultiImage();
    if (selectedImages != null) {
      setState(() {
        categoryImages[selectedCategory]!.addAll(selectedImages);
      });
    }
  }

  void deleteImage(int index) {
    setState(() {
      categoryImages[selectedCategory]!.removeAt(index);
    });
  }
  Future<void> uploadBid() async {
    try {
      List<String> uploadedImageUrls = [];

      // Upload images to Supabase Storage
      for (XFile image in categoryImages[selectedCategory]!) {
        final bytes = File(image.path).readAsBytesSync();
        final fileName = "${DateTime.now().millisecondsSinceEpoch}_${image.name}";
        final filePath = "bids/$selectedCategory/$fileName";

        await supabase.storage.from('bids').uploadBinary(filePath, bytes);

        // Get Public URL
        final publicUrl = supabase.storage.from('bids').getPublicUrl(filePath);
        uploadedImageUrls.add(publicUrl);
      }

      // Prepare bid data
      Map<String, dynamic> bidData = {
        'name': nameController.text,
        'price': priceController.text,
        'description': descriptionController.text,
        'images': uploadedImageUrls,
      };

      if (selectedCategory == "Car") {
        bidData.addAll({
          'make': makeController.text,
          'model': modelController.text,
          'year': yearController.text,
          'fuel': fuelController.text,
          'registration_city': regCityController.text,
          'distance': distanceController.text,
          'horse_power': horsePowerController.text,
          'transmission': selectedTransmission,
        });
      } else {
        bidData.addAll({
          'condition': conditionController.text,
          'material': materialController.text,
        });
      }

      // Insert into Supabase
      final response = await supabase.from(selectedCategory.toLowerCase()).insert(bidData);

      if (response.error != null) {
        throw Exception(response.error!.message);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bid uploaded successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
      print("Upload failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          bottomNavigationBar: const Navigationbar(),
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: pickImages,
                      icon: const Icon(Icons.add_photo_alternate, size: 100, color: Colors.white),
                    ),
                    if (categoryImages[selectedCategory]!.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryImages[selectedCategory]!.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() {
                                    fullScreenImage = categoryImages[selectedCategory]![index];
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Image.file(
                                      File(categoryImages[selectedCategory]![index].path),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => deleteImage(index),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    categorySelection(),
                    const SizedBox(height: 20),
                    if (selectedCategory == "Car") ...carInputs(),
                    if (selectedCategory != "Car") ...furnitureAndArtInputs(),
                  ],
                ),
              ),
              if (fullScreenImage != null)
                GestureDetector(
                  onTap: () => setState(() {
                    fullScreenImage = null;
                  }),
                  child: Container(
                    color: Colors.black.withOpacity(0.9),
                    alignment: Alignment.center,
                    child: Image.file(
                      File(fullScreenImage!.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget categorySelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ["Car", "Furniture", "Art"].map((category) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ChoiceChip(
            label: Text(category, style: const TextStyle(color: Colors.white)),
            selected: selectedCategory == category,
            backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
            selectedColor: Colors.green,
            onSelected: (bool selected) {
              setState(() {
                selectedCategory = category;
              });
            },
          ),
        );
      }).toList(),
    );
  }

  List<Widget> carInputs() {
    return [
      buildInputField("Make", makeController),
      buildInputField("Model", modelController),
      buildInputField("Year", yearController),
      buildInputField("Fuel", fuelController),
      buildInputField("Registration City", regCityController),
      buildInputField("Distance", distanceController),
      buildInputField("Horse Power", horsePowerController),
      buildTransmissionSelection(),
      buildInputField("Price", priceController),
      buildInputField("Description", descriptionController, isMultiline: true),
      postButton(),
    ];
  }

  List<Widget> furnitureAndArtInputs() {
    return [
      buildInputField("Name", nameController),
      buildInputField("Condition", conditionController),
      buildInputField("Material", materialController),
      buildInputField("Price", priceController),
      buildInputField("Description", descriptionController, isMultiline: true),
      postButton(),
    ];
  }

  Widget buildTransmissionSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ["Automatic", "Manual"].map((transmission) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ChoiceChip(
            label: Text(transmission, style: const TextStyle(color: Colors.white)),
            selected: selectedTransmission == transmission,
            backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
            selectedColor: Colors.green,
            onSelected: (bool selected) {
              if (selected) setState(() => selectedTransmission = transmission);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget buildInputField(String label, TextEditingController controller, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          maxLines: isMultiline ? null : 1,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white),
            filled: true,
            fillColor: const Color.fromRGBO(27, 27, 27, 1),
          ),
        ),
      ),
    );
  }

  Widget postButton() {
    return ElevatedButton(
      onPressed: uploadBid,
      child: const Text("Post Bid"),
    );
  }
}
