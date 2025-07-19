import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fyp/services/price_prediction_service.dart';
import 'package:fyp/utils/dialoguebox.dart' as UIUtils;

class PredictScreen extends StatefulWidget {
  final String imageurl;
  final Map<String, dynamic>? carData;

  const PredictScreen({super.key, required this.imageurl, this.carData});

  @override
  _PredictScreenState createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _cityController = TextEditingController();
  final _fuelController = TextEditingController();
  final _transmissionController = TextEditingController();
  final _yearController = TextEditingController();
  final _distanceController = TextEditingController();
  final _horsePowerController = TextEditingController();
  List<String> _validNames = [];
  List<String> _validBrands = [];
  List<String> _validCities = [];
  List<String> _validFuels = [];
  List<String> _validTransmissions = [];
  bool _isPredicting = false;

  @override
  void initState() {
    super.initState();
    print('carData: ${widget.carData}'); // Debug log
    _loadValidFeatures().then((_) {
      _preFillFields();
    });
    PricePredictionService.initializeModel(); // Initialize model
  }

  Future<void> _loadValidFeatures() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/preprocessing_config.json');
      final Map<String, dynamic> config = json.decode(jsonString);
      final List<String> featureList = List<String>.from(config['input_columns']);
      setState(() {
        _validNames = featureList
            .where((name) => name.startsWith('Name_'))
            .map((name) => name.replaceFirst('Name_', ''))
            .toList();
        _validBrands = featureList
            .where((name) => name.startsWith('Brand_'))
            .map((name) => name.replaceFirst('Brand_', ''))
            .toList();
        _validCities = featureList
            .where((name) => name.startsWith('City_'))
            .map((name) => name.replaceFirst('City_', ''))
            .toList();
        _validFuels = featureList
            .where((name) => name.startsWith('Fuel_'))
            .map((name) => name.replaceFirst('Fuel_', ''))
            .toList();
        _validTransmissions = featureList
            .where((name) => name.startsWith('Transmission_'))
            .map((name) => name.replaceFirst('Transmission_', ''))
            .toList();
      });
      print('Valid names: $_validNames');
      print('Valid brands: $_validBrands');
      print('Valid cities: $_validCities');
      print('Valid fuels: $_validFuels');
      print('Valid transmissions: $_validTransmissions');
    } catch (e) {
      print('Error loading valid features: $e');
      if (mounted) {
        UIUtils.showDialogueBox(
          context,
          "Error",
          contextText: "Failed to load feature list: $e",
        );
      }
    }
  }

  void _preFillFields() {
    if (widget.carData != null) {
      final model = widget.carData?['model']?.toString() ?? '';
      final make = widget.carData?['make']?.toString() ?? '';
      final city = widget.carData?['registration_city']?.toString() ?? '';
      final fuel = widget.carData?['fuel']?.toString() ?? '';
      final transmission = widget.carData?['transmission']?.toString() ?? '';
      _nameController.text = _validNames.contains(model) ? model : (_validNames.isNotEmpty ? _validNames.first : '');
      _brandController.text = _validBrands.contains(make) ? make : (_validBrands.isNotEmpty ? _validBrands.first : '');
      _cityController.text = _validCities.contains(city) ? city : (_validCities.isNotEmpty ? _validCities.first : '');
      _fuelController.text = _validFuels.contains(fuel) ? fuel : (_validFuels.isNotEmpty ? _validFuels.first : '');
      _transmissionController.text = _validTransmissions.contains(transmission)
          ? transmission
          : (_validTransmissions.isNotEmpty ? _validTransmissions.first : '');
      _yearController.text = widget.carData?['year']?.toString() ?? '2010';
      _distanceController.text = widget.carData?['distance']?.toString() ?? '0';
      _horsePowerController.text = widget.carData?['horse_power']?.toString() ?? '0';
    } else {
      _nameController.text = _validNames.isNotEmpty ? _validNames.first : '';
      _brandController.text = _validBrands.isNotEmpty ? _validBrands.first : '';
      _cityController.text = _validCities.isNotEmpty ? _validCities.first : '';
      _fuelController.text = _validFuels.isNotEmpty ? _validFuels.first : '';
      _transmissionController.text = _validTransmissions.isNotEmpty ? _validTransmissions.first : '';
      _yearController.text = '2010';
      _distanceController.text = '0';
      _horsePowerController.text = '0';
    }
  }

  Future<void> _predictPrice() async {
    if (_isPredicting || !mounted) return;
    // Validate inputs
    if (!_validNames.contains(_nameController.text)) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please select a valid model from the suggestions.",
      );
      return;
    }
    if (!_validBrands.contains(_brandController.text)) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please select a valid brand from the suggestions.",
      );
      return;
    }
    if (!_validCities.contains(_cityController.text)) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please select a valid city from the suggestions.",
      );
      return;
    }
    if (!_validFuels.contains(_fuelController.text)) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please select a valid fuel type from the suggestions.",
      );
      return;
    }
    if (!_validTransmissions.contains(_transmissionController.text)) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please select a valid transmission from the suggestions.",
      );
      return;
    }
    final year = int.tryParse(_yearController.text);
    if (year == null || year < 1900 || year > DateTime.now().year) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please enter a valid year (1900-${DateTime.now().year}).",
      );
      return;
    }
    final distance = double.tryParse(_distanceController.text);
    if (distance == null || distance < 0) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please enter a valid distance (0 or greater).",
      );
      return;
    }
    final horsePower = double.tryParse(_horsePowerController.text);
    if (horsePower == null || horsePower < 0) {
      UIUtils.showDialogueBox(
        context,
        "Invalid Input",
        contextText: "Please enter a valid horse power (0 or greater).",
      );
      return;
    }

    setState(() => _isPredicting = true);
    try {
      final predictedPrice = await PricePredictionService.predictPrice(
        name: _nameController.text,
        brand: _brandController.text,
        city: _cityController.text,
        fuel: _fuelController.text,
        transmission: _transmissionController.text,
        year: year,
        distanceNumeric: distance,
        horsePower: horsePower,
      );
      if (mounted) {
        UIUtils.showDialogueBox(
          context,
          "Predicted Price",
          contextText: "${predictedPrice.toStringAsFixed(0)} PKR",
        );
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showDialogueBox(
          context,
          "Prediction Error",
          contextText: "Failed to predict price: $e",
        );
        print('Prediction error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPredicting = false);
      }
    }
  }

  Widget customTextField(String hint, TextEditingController controller, {bool isNumeric = false}) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: const Color.fromARGB(255, 45, 45, 45),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget customAutocompleteField(String hint, TextEditingController controller, List<String> options) {
    return SizedBox(
      width: 150,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return options;
          }
          return options.where((option) =>
              option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        onSelected: (String selection) {
          controller.text = selection;
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          // Sync the provided controller with the Autocomplete's controller
          textEditingController.text = controller.text;
          textEditingController.addListener(() {
            controller.text = textEditingController.text;
          });
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color.fromARGB(255, 45, 45, 45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              child: Container(
                color: const Color.fromARGB(255, 45, 45, 45),
                constraints: const BoxConstraints(maxHeight: 200),
                width: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 27, 27, 27).withOpacity(0.7),
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Predict Price',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.network(
                widget.imageurl.isNotEmpty
                    ? widget.imageurl
                    : 'https://via.placeholder.com/300x200?text=No+Image',
                width: 500,
                height: 500,
                fit: BoxFit.fill,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    const Text(
                      "Vehicle details for price prediction",
                      style: TextStyle(color: Colors.white, fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        customAutocompleteField("Model", _nameController, _validNames),
                        customTextField("Year", _yearController, isNumeric: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        customAutocompleteField("Brand", _brandController, _validBrands),
                        customTextField("Distance (km)", _distanceController, isNumeric: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        customAutocompleteField("City", _cityController, _validCities),
                        customTextField("Horse Power", _horsePowerController, isNumeric: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        customAutocompleteField("Fuel Type", _fuelController, _validFuels),
                        customAutocompleteField("Transmission", _transmissionController, _validTransmissions),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _isPredicting ? null : _predictPrice,
                      child: _isPredicting
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                        "Predict",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _cityController.dispose();
    _fuelController.dispose();
    _transmissionController.dispose();
    _yearController.dispose();
    _distanceController.dispose();
    _horsePowerController.dispose();
    PricePredictionService.dispose();
    super.dispose();
  }
}