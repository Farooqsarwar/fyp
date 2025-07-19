import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp/view/Homescreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'Exit_permission.dart';
import 'Navigationbar.dart';

class UploadingBidScreen extends StatefulWidget {
  const UploadingBidScreen({super.key});

  @override
  State<UploadingBidScreen> createState() => _UploadingBidScreenState();
}

class _UploadingBidScreenState extends State<UploadingBidScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker picker = ImagePicker();

  // Controllers
  final bidNameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final makeController = TextEditingController();
  final modelController = TextEditingController();
  final yearController = TextEditingController();
  final fuelController = TextEditingController();
  final regCityController = TextEditingController();
  final distanceController = TextEditingController();
  final horsePowerController = TextEditingController();
  final artistController = TextEditingController();
  final conditionController = TextEditingController();
  final materialController = TextEditingController();

  // State variables
  String selectedCategory = "Car";
  String selectedTransmission = "Automatic";
  DateTime? startTime;
  DateTime? endTime;
  final Map<String, List<XFile>> categoryImages = {
    'Car': [],
    'Art': [],
    'Furniture': [],
  };
  XFile? fullScreenImage;
  double uploadProgress = 0.0;
  bool isUploading = false;

  @override
  void dispose() {
    bidNameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    makeController.dispose();
    modelController.dispose();
    yearController.dispose();
    fuelController.dispose();
    regCityController.dispose();
    distanceController.dispose();
    horsePowerController.dispose();
    artistController.dispose();
    conditionController.dispose();
    materialController.dispose();
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
              if (endTime != null && endTime!.isBefore(dateTime)) {
                endTime = dateTime.add(const Duration(hours: 24));
              }
            } else {
              endTime = dateTime;
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

  Widget _buildProgressOverlay() {
    return isUploading
        ? Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: uploadProgress,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
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
    if (isUploading || !_formKey.currentState!.validate()) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      if (endTime == null || startTime == null) throw Exception('Please set start and end times');
      if (endTime!.isBefore(startTime!)) throw Exception('End time must be after start time');
      if (bidNameController.text.isEmpty) throw Exception('Please enter a bid name');
      if (categoryImages[selectedCategory]!.isEmpty) throw Exception('Please add at least one image');
      if (priceController.text.isEmpty) throw Exception('Please enter a price');
      if (descriptionController.text.isEmpty) throw Exception('Please enter a description');

      if (selectedCategory == 'Car') {
        if (makeController.text.isEmpty) throw Exception('Please enter the car make');
        if (modelController.text.isEmpty) throw Exception('Please enter the car model');
        if (yearController.text.isEmpty) throw Exception('Please enter the car year');
        if (fuelController.text.isEmpty) throw Exception('Please enter the fuel type');
        if (regCityController.text.isEmpty) throw Exception('Please enter the registration city');
        if (distanceController.text.isEmpty) throw Exception('Please enter the distance');
        if (horsePowerController.text.isEmpty) throw Exception('Please enter the horse power');
      } else {
        if (conditionController.text.isEmpty) throw Exception('Please enter the condition');
        if (materialController.text.isEmpty) throw Exception('Please enter the material');
      }

      setState(() {
        isUploading = true;
        uploadProgress = 0.0;
      });

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

      // Map selectedCategory to correct table name
      String tableName;
      switch (selectedCategory) {
        case 'Car':
          tableName = 'cars';
          break;
        case 'Art':
          tableName = 'art';
          break;
        case 'Furniture':
          tableName = 'furniture';
          break;
        default:
          throw Exception('Invalid category: $selectedCategory');
      }

      // Prepare bid data
      final bidData = {
        'user_id': user.id,
        'bid_name': bidNameController.text,
        'start_time': startTime!.toIso8601String(),
        'end_time': endTime!.toIso8601String(),
        'is_active': true,
        'price': double.parse(priceController.text),
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
        },
        if (selectedCategory == "Art") ...{
          'artist': artistController.text,
          'condition': conditionController.text,
          'material': materialController.text,
        },
        if (selectedCategory == "Furniture") ...{
          'condition': conditionController.text,
          'material': materialController.text,
        },
      };

      // Insert into database
      try {
        final response = await supabase
            .from(tableName)
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
                    Navigator.pop(context); // Close the dialog first
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
        debugPrint("Error inserting into $tableName: $e");
        throw Exception("Failed to insert bid into $tableName: ${e.toString()}");
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

  Widget buildTimeInputField(String label, VoidCallback onTap) {
    final controller = label.contains("Start")
        ? TextEditingController(text: startTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(startTime!) : "")
        : TextEditingController(text: endTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(endTime!) : "");

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
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: 300,
        child: TextFormField(
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
          validator: validator,
        ),
      ),
    );
  }

  Widget categorySelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 8,
        children: ["Car", "Art", "Furniture"].map((category) {
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
      buildInputField("Bid Name", bidNameController, validator: (value) => value!.isEmpty ? 'Please enter a bid name' : null),
      buildInputField("Make", makeController, validator: (value) => value!.isEmpty ? 'Please enter the make' : null),
      buildInputField("Model", modelController, validator: (value) => value!.isEmpty ? 'Please enter the model' : null),
      buildInputField("Year", yearController, keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Please enter the year' : null),
      buildInputField("Fuel", fuelController, validator: (value) => value!.isEmpty ? 'Please enter the fuel type' : null),
      buildInputField("Registration City", regCityController, validator: (value) => value!.isEmpty ? 'Please enter the registration city' : null),
      buildInputField("Distance (km)", distanceController, keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Please enter the distance' : null),
      buildInputField("Horse Power", horsePowerController, keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Please enter the horse power' : null),
      buildTransmissionSelection(),
      buildInputField("Price (PKR)", priceController, keyboardType: TextInputType.number, validator: (value) {
        if (value!.isEmpty) return 'Please enter a price';
        if (double.tryParse(value) == null || double.parse(value) <= 0) {
          return 'Please enter a valid price';
        }
        return null;
      }),
      buildInputField("Description", descriptionController, isMultiline: true, validator: (value) => value!.isEmpty ? 'Please enter a description' : null),
      buildTimeInputField("Start Time", () => _pickDateTime(context, true)),
      buildTimeInputField("End Time", () => _pickDateTime(context, false)),
    ];
  }

  List<Widget> buildArtInputs() {
    return [
      buildInputField("Bid Name", bidNameController, validator: (value) => value!.isEmpty ? 'Please enter a bid name' : null),
      buildInputField("Artist", artistController),
      buildInputField("Condition", conditionController, validator: (value) => value!.isEmpty ? 'Please enter the condition' : null),
      buildInputField("Material", materialController, validator: (value) => value!.isEmpty ? 'Please enter the material' : null),
      buildInputField("Price (PKR)", priceController, keyboardType: TextInputType.number, validator: (value) {
        if (value!.isEmpty) return 'Please enter a price';
        if (double.tryParse(value) == null || double.parse(value) <= 0) {
          return 'Please enter a valid price';
        }
        return null;
      }),
      buildInputField("Description", descriptionController, isMultiline: true, validator: (value) => value!.isEmpty ? 'Please enter a description' : null),
      buildTimeInputField("Start Time", () => _pickDateTime(context, true)),
      buildTimeInputField("End Time", () => _pickDateTime(context, false)),
    ];
  }

  List<Widget> buildFurnitureInputs() {
    return [
      buildInputField("Bid Name", bidNameController, validator: (value) => value!.isEmpty ? 'Please enter a bid name' : null),
      buildInputField("Condition", conditionController, validator: (value) => value!.isEmpty ? 'Please enter the condition' : null),
      buildInputField("Material", materialController, validator: (value) => value!.isEmpty ? 'Please enter the material' : null),
      buildInputField("Price (PKR)", priceController, keyboardType: TextInputType.number, validator: (value) {
        if (value!.isEmpty) return 'Please enter a price';
        if (double.tryParse(value) == null || double.parse(value) <= 0) {
          return 'Please enter a valid price';
        }
        return null;
      }),
      buildInputField("Description", descriptionController, isMultiline: true, validator: (value) => value!.isEmpty ? 'Please enter a description' : null),
      buildTimeInputField("Start Time", () => _pickDateTime(context, true)),
      buildTimeInputField("End Time", () => _pickDateTime(context, false)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () => ExitConfirmation.showExitDialog(context),
    child:  SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Center(
                  child: Column(
                    children: [
                      categorySelection(),
                      const SizedBox(height: 20),
                      buildImagePreview(),
                      const SizedBox(height: 20),
                      if (selectedCategory == "Car") ...buildCarInputs(),
                      if (selectedCategory == "Art") ...buildArtInputs(),
                      if (selectedCategory == "Furniture") ...buildFurnitureInputs(),
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
            ),
            _buildProgressOverlay(),
            buildFullScreenImage(),
          ],
        ),
          bottomNavigationBar: const Navigationbar()      ),
    )
    );
  }
}