import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart'; // Import intl package

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  TextEditingController controlWeight = TextEditingController();
  TextEditingController controlHeight = TextEditingController();
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _info = "Enter your data";
  double _bmiValue = 0.0;

  void _resetFields() {
    controlHeight.clear();
    controlWeight.clear();
    setState(() {
      _info = "Enter your data";
      _bmiValue = 0.0;
      _formKey.currentState?.reset();
    });
  }

  void calculate() async {
    setState(() {
      double? weight = double.tryParse(controlWeight.text);
      double? height = double.tryParse(controlHeight.text);

      if (weight == null || height == null || height == 0) {
        _info = "Invalid input!";
        _bmiValue = 0.0;
        return;
      }

      height = height / 100;
      double imc = weight / (height * height);
      _bmiValue = imc;

      if (imc < 18.5) {
        _info = "Underweight (${imc.toStringAsPrecision(4)})";
      } else if (imc < 25) {
        _info = "Normal weight (${imc.toStringAsPrecision(4)})";
      } else if (imc < 30) {
        _info = "Overweight (${imc.toStringAsPrecision(4)})";
      } else {
        _info = "Obesity (${imc.toStringAsPrecision(4)})";
      }

      // Save the result in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection("bmi_results").add({
          "uid": user.uid,
          "weight": weight,
          "height": height * 100,
          "bmi": imc,
          "timestamp": FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection("bmi_results")
            .where("uid", isEqualTo: user.uid)
            .orderBy("timestamp", descending: true)
            .get();

        // Vérification du nombre de résultats dans Firestore
        print("Nombre de résultats dans Firestore : ${snapshot.docs.length}");

        if (snapshot.docs.isEmpty) {
          print("Aucun document trouvé pour cet utilisateur");
        }

        // Renvoie les données sous forme de liste
        return snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      } catch (e) {
        print('Erreur lors de la récupération des données : $e');
        return [];
      }
    } else {
      print('Utilisateur non authentifié');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("BMI CALCULATOR"),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _resetFields),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.fitness_center, size: 120.0, color: Colors.teal),
              _buildTextField("Weight (Kg)", controlWeight),
              SizedBox(height: 10),
              _buildTextField("Height (cm)", controlHeight),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    calculate();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: Text("Calculate",
                    style: TextStyle(color: Colors.white, fontSize: 20.0)),
              ),
              SizedBox(height: 20),
              _buildBMIGauge(),
              SizedBox(height: 20),
              Text(
                _info,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.teal, fontSize: 22.0),
              ),
              SizedBox(height: 20),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: getHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.hasData) {
                    final history = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        // Format the timestamp here
                        final timestamp = item['timestamp'] as Timestamp?;
                        final formattedDate = timestamp != null
                            ? DateFormat('yyyy-MM-dd HH:mm:ss')
                            .format(timestamp.toDate())
                            : 'N/A';

                        return ListTile(
                          title: Text("BMI: ${item['bmi']}"),
                          subtitle: Text(
                              "Weight: ${item['weight']} Kg, Height: ${item['height']} cm"),
                          trailing: Text(formattedDate),
                        );
                      },
                    );
                  }
                  return Center(child: Text("No history available."));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 20.0),
      controller: controller,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Required";
        }
        return null;
      },
    );
  }

  Widget _buildBMIGauge() {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 10,
          maximum: 40,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 10, endValue: 18.5, color: Colors.blue),
            GaugeRange(startValue: 18.5, endValue: 25, color: Colors.green),
            GaugeRange(startValue: 25, endValue: 30, color: Colors.orange),
            GaugeRange(startValue: 30, endValue: 40, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
                value: _bmiValue,
                enableAnimation: true,
                needleColor: Colors.black),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: AnimatedContainer(
                duration: Duration(milliseconds: 500),
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_bmiValue.toStringAsPrecision(4)}',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
}