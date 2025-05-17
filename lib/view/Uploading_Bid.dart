import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp/view/Homescreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'Navigationbar.dart';

class UploadingBid extends StatefulWidget {
  const UploadingBid({super.key});

  @override
  State<UploadingBid> createState() => _UploadingBidState();
}

class _UploadingBidState extends State<UploadingBid> {
  final ImagePicker picker = ImagePicker();
  final SupabaseClient supabase = Supabase.instance.client;

  // State variables
  final Map<String, List<XFile>> categoryImages = {
    "Car": [],
    "Furniture": [],
    "Art": [],
  };
  String selectedCategory = "Car";
  String selectedTransmission = "Automatic";
  XFile? fullScreenImage;
  DateTime? startTime;
  DateTime? endTime;
  bool isUploading = false;
  double uploadProgress = 0.0;

  // Controllers
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
  final TextEditingController bidNameController = TextEditingController();
  final TextEditingController startTimeController = TextEditingController();
  final TextEditingController endTimeController = TextEditingController();

  @override
  void dispose() {
    conditionController.dispose();
    materialController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    makeController.dispose();
    modelController.dispose();
    yearController.dispose();
    fuelController.dispose();
    regCityController.dispose();
    distanceController.dispose();
    horsePowerController.dispose();
    bidNameController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    try {
      final List<XFile>? selectedImages = await picker.pickMultiImage();
      if (selectedImages != null && selectedImages.isNotEmpty) {
        setState(() {
          categoryImages[selectedCategory]!.addAll(selectedImages);
        });
      }
    } catch (e) {
      debugPrint("Error picking images: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick images: ${e.toString()}")),
        );
      }
    }
  }

  void deleteImage(int index) {
    setState(() {
      categoryImages[selectedCategory]!.removeAt(index);
    });
  }

  Future<void> _pickDateTime(BuildContext context, bool isStartTime) async {
    try {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: isStartTime ? DateTime.now() : (startTime ?? DateTime.now()),
        firstDate: isStartTime ? DateTime.now() : (startTime ?? DateTime.now()),
        lastDate: DateTime(2100),
      );

      if (pickedDate != null) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (pickedTime != null) {
          final DateTime dateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          setState(() {
            if (isStartTime) {
              startTime = dateTime;
              startTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
              if (endTime != null && endTime!.isBefore(dateTime)) {
                endTime = dateTime.add(const Duration(hours: 24));
                endTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(endTime!);
              }
            } else {
              endTime = dateTime;
              endTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking date/time: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to select time: ${e.toString()}")),
        );
      }
    }
  }

  // Progress overlay widget
  Widget _buildProgressOverlay() {
    return isUploading
        ? Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 20),
            Text(
              'Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    )
        : const SizedBox.shrink();
  }

  Future<void> uploadBid() async {
    if (isUploading) return;
    // Validate inputs first
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      if (endTime == null || startTime == null) throw Exception('Please set start and end times');
      if (endTime!.isBefore(startTime!)) throw Exception('End time must be after start time');
      if (bidNameController.text.isEmpty) throw Exception('Please enter a bid name');
      if (categoryImages[selectedCategory]!.isEmpty) throw Exception('Please add at least one image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
    });

    try {
      final user = supabase.auth.currentUser;

      // Upload images
      List<String> uploadedImageUrls = [];
      final totalImages = categoryImages[selectedCategory]!.length;

      for (int i = 0; i < totalImages; i++) {
        final image = categoryImages[selectedCategory]![i];
        try {
          final bytes = await File(image.path).readAsBytes();
          final fileName = "${DateTime.now().millisecondsSinceEpoch}_${image.name}";
          final filePath = "bids/$selectedCategory/$fileName";

          await supabase.storage.from('bids').uploadBinary(filePath, bytes);
          final publicUrl = supabase.storage.from('bids').getPublicUrl(filePath);
          uploadedImageUrls.add(publicUrl);

          // Update progress
          if (mounted) {
            setState(() {
              uploadProgress = (i + 1) / (totalImages + 1); // +1 for database insertion
            });
          }
        } catch (e) {
          debugPrint("Error uploading image: $e");
          throw Exception("Failed to upload image: ${e.toString()}");
        }
      }

      // Prepare bid data
      final bidData = {
        'user_id': user!.id,
        'bid_name': bidNameController.text,
        'start_time': startTime!.toIso8601String(),
        'end_time': endTime!.toIso8601String(),
        'is_active': true,
        'price': priceController.text,
        'description': descriptionController.text,
        'images': uploadedImageUrls,
        if (selectedCategory == "Car") ...{
          'make': makeController.text,
          'model': modelController.text,
          'year': yearController.text,
          'fuel': fuelController.text,
          'registration_city': regCityController.text,
          'distance': distanceController.text,
          'horse_power': horsePowerController.text,
          'transmission': selectedTransmission,
        } else ...{
          'condition': conditionController.text,
          'material': materialController.text,
        }
      };

      // Insert into database
      final response = await supabase
          .from(selectedCategory.toLowerCase())
          .insert(bidData)
          .select()
          .single();

      if (response == null) throw Exception('No response from server');

      // Update final progress before completion
      if (mounted) {
        setState(() {
          uploadProgress = 1.0;
        });
      }

      // Show success and navigate back
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Success"),
            content: const Text("Bid created successfully!"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  setState(() => isUploading = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => Homescreen()),
                  );
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      debugPrint("Error creating bid: $e");
      if (mounted) {
        setState(() => isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating bid: ${e.toString()}")),
        );
      }
    }
  }

  Widget buildTimeInputField(String label, TextEditingController controller, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          readOnly: true,
          onTap: isUploading ? null : onTap,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white),
            filled: true,
            fillColor: const Color.fromRGBO(27, 27, 27, 1),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget buildInputField(String label, TextEditingController controller, {
    bool isMultiline = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          maxLines: isMultiline ? null : 1,
          keyboardType: keyboardType,
          enabled: !isUploading,
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

  Widget categorySelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 8,
        children: ["Car", "Furniture", "Art"].map((category) {
          return ChoiceChip(
            label: Text(category, style: const TextStyle(color: Colors.white)),
            selected: selectedCategory == category,
            selectedColor: Colors.green,
            backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
            onSelected: isUploading ? null : (selected) {
              if (selected) {
                setState(() => selectedCategory = category);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget buildTransmissionSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 8,
        children: ["Automatic", "Manual"].map((transmission) {
          return ChoiceChip(
            label: Text(transmission, style: const TextStyle(color: Colors.white)),
            selected: selectedTransmission == transmission,
            selectedColor: Colors.green,
            backgroundColor: const Color.fromRGBO(27, 27, 27, 1),
            onSelected: isUploading ? null : (selected) {
              if (selected) {
                setState(() => selectedTransmission = transmission);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget buildImagePreview() {
    final images = categoryImages[selectedCategory]!;
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add_a_photo),
          label: const Text("Add Images"),
          onPressed: isUploading ? null : pickImages,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            disabledBackgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        if (images.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : () => setState(() => fullScreenImage = images[index]),
                        child: Image.file(
                          File(images[index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: isUploading ? null : () => deleteImage(index),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget buildFullScreenImage() {
    if (fullScreenImage == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => fullScreenImage = null),
      child: Container(
        color: Colors.black.withOpacity(0.9),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Image.file(File(fullScreenImage!.path)),
        ),
      ),
    );
  }

  List<Widget> buildCarInputs() {
    return [
      buildInputField("Bid Name", bidNameController),
      buildInputField("Make", makeController),
      buildInputField("Model", modelController),
      buildInputField("Year", yearController, keyboardType: TextInputType.number),
      buildInputField("Fuel", fuelController),
      buildInputField("Registration City", regCityController),
      buildInputField("Distance", distanceController, keyboardType: TextInputType.number),
      buildInputField("Horse Power", horsePowerController, keyboardType: TextInputType.number),
      buildTransmissionSelection(),
      buildInputField("Price", priceController, keyboardType: TextInputType.number),
      buildInputField("Description", descriptionController, isMultiline: true),
      buildTimeInputField("Start Time", startTimeController, () => _pickDateTime(context, true)),
      buildTimeInputField("End Time", endTimeController, () => _pickDateTime(context, false)),
    ];
  }

  List<Widget> buildFurnitureInputs() {
    return [
      buildInputField("Bid Name", bidNameController),
      buildInputField("Condition", conditionController),
      buildInputField("Material", materialController),
      buildInputField("Price", priceController, keyboardType: TextInputType.number),
      buildInputField("Description", descriptionController, isMultiline: true),
      buildTimeInputField("Start Time", startTimeController, () => _pickDateTime(context, true)),
      buildTimeInputField("End Time", endTimeController, () => _pickDateTime(context, false)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    categorySelection(),
                    const SizedBox(height: 20),
                    buildImagePreview(),
                    const SizedBox(height: 20),
                    if (selectedCategory == "Car") ...buildCarInputs(),
                    if (selectedCategory != "Car") ...buildFurnitureInputs(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isUploading ? null : uploadBid,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: isUploading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        "Post Bid",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildProgressOverlay(),
            buildFullScreenImage(),
          ],
        ),
        bottomNavigationBar: const Navigationbar(),
      ),
    );
  }
}