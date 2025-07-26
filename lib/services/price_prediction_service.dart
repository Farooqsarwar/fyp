import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class PricePredictionService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;
  static List<String>? _featureList;

  // Scaler values from your Python model
  static const double yearMean = 2012.48600872;
  static const double yearStd = 8.87689599;
  static const double distanceMean = 89292.92877527;
  static const double distanceStd = 88650.3886;
  static const double hpMean = 1385.26335051;
  static const double hpStd = 687.875528;

  // Load feature list from preprocessing_config.json
  static Future<void> _loadFeatureList() async {
    if (_featureList != null) return;
    try {
      final String jsonString =
      await rootBundle.loadString('assets/preprocessing_config.json');
      final Map<String, dynamic> config = json.decode(jsonString);
      _featureList = List<String>.from(config['input_columns']);
      print('Feature list loaded: $_featureList');
    } catch (e) {
      print('Error loading feature list: $e');
      throw Exception('Failed to load preprocessing_config.json: $e');
    }
  }

  // Initialize the model
  static Future<void> initializeModel() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _interpreter!.allocateTensors(); // Ensure tensors are allocated
      _isInitialized = true;
      print('TensorFlow Lite model loaded successfully');
    } catch (e, stackTrace) {
      print('Error loading TensorFlow Lite model: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to load model: $e');
    }
  }

  // Predict price based on input features
  static Future<double> predictPrice({
    required String name,
    required String brand,
    required String city,
    required String fuel,
    required String transmission,
    required int year,
    required double distanceNumeric,
    required double horsePower,
  }) async {
    await _loadFeatureList();
    if (!_isInitialized) {
      await initializeModel();
    }
    if (_interpreter == null || _featureList == null) {
      throw Exception('Model or feature list not initialized');
    }
    try {
      // Build input array
      List<double> input = List.filled(_featureList!.length, 0.0);
      // Standardize numerical features
      input[_featureList!.indexOf('Year')] = (year - yearMean) / yearStd;
      input[_featureList!.indexOf('Distance_Numeric')] =
          (distanceNumeric - distanceMean) / distanceStd;
      input[_featureList!.indexOf('HorsePower')] =
          (horsePower - hpMean) / hpStd;

      // One-hot encode categorical features with validation
      void setOneHot(String prefix, String value) {
        String colName = '${prefix}_$value';
        int idx = _featureList!.indexOf(colName);
        if (idx == -1) {
          print('Warning: $colName not found in feature list');
        } else {
          input[idx] = 1.0;
        }
      }

      setOneHot('Name', name);
      setOneHot('Brand', brand);
      setOneHot('City', city);
      setOneHot('Fuel', fuel);
      setOneHot('Transmission', transmission);

      // Prepare input for TFLite (batch size 1)
      List<List<double>> inputArray = [input];
      List<List<double>> outputArray =
      List.generate(1, (_) => List.filled(1, 0.0));

      _interpreter!.run(inputArray, outputArray);
      double predictedPrice = outputArray[0][0];

      // Validate output
      if (predictedPrice.isNaN || predictedPrice.isInfinite) {
        throw Exception('Invalid prediction result: $predictedPrice');
      }

      return predictedPrice;
    } catch (e, stackTrace) {
      print('Error during prediction: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Prediction failed: $e');
    }
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _featureList = null;
    print('PricePredictionService disposed');
  }
}