import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  final Function(Locale) onLocaleChanged;

  const HomePage({super.key, required this.onLocaleChanged});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  TextEditingController controlWeight = TextEditingController();
  TextEditingController controlHeight = TextEditingController();
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _info = "";
  double _bmiValue = 0.0;

  void _resetFields() {
    controlHeight.clear();
    controlWeight.clear();
    setState(() {
      _info = "";
      _bmiValue = 0.0;
      _formKey.currentState?.reset();
    });
  }

  void calculate() async {
    setState(() {
      final local = AppLocalizations.of(context)!;
      double? weight = double.tryParse(controlWeight.text);
      double? height = double.tryParse(controlHeight.text);

      if (weight == null || height == null || height == 0) {
        _info = local.invalidInput;
        _bmiValue = 0.0;
        return;
      }

      height = height / 100;
      double imc = weight / (height * height);
      _bmiValue = imc;

      String category;
      if (imc < 18.5) {
        _info = "${local.underweight} (${imc.toStringAsPrecision(4)})";
        category = 'underweight';
      } else if (imc < 25) {
        _info = "${local.normalWeight} (${imc.toStringAsPrecision(4)})";
        category = 'normalWeight';
      } else if (imc < 30) {
        _info = "${local.overweight} (${imc.toStringAsPrecision(4)})";
        category = 'overweight';
      } else {
        _info = "${local.obesity} (${imc.toStringAsPrecision(4)})";
        category = 'obesity';
      }

      final user = _auth.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection("bmi_results").add({
          "uid": user.uid,
          "weight": weight,
          "height": height * 100,
          "bmi": imc,
          "category": category,
          "timestamp": FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection("bmi_results")
            .where("uid", isEqualTo: user.uid)
            .orderBy("timestamp", descending: true)
            .get();
        return snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      } catch (e) {
        print('Erreur Firestore : $e');
        return [];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(local.bmiCalculator),
            SizedBox(width: 10),
            Text(
              _auth.currentUser?.displayName ?? local.guestUser,
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _resetFields),
          IconButton(
            icon: Icon(Icons.language),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(local.chooseLanguage),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text('English'),
                          onTap: () {
                            widget.onLocaleChanged(const Locale('en'));
                            Navigator.of(context).pop();
                          },
                        ),
                        ListTile(
                          title: Text('Français'),
                          onTap: () {
                            widget.onLocaleChanged(const Locale('fr'));
                            Navigator.of(context).pop();
                          },
                        ),
                        ListTile(
                          title: Text('Español'),
                          onTap: () {
                            widget.onLocaleChanged(const Locale('es'));
                            Navigator.of(context).pop();
                          },
                        ),
                        ListTile(
                          title: Text('العربية'),
                          onTap: () {
                            widget.onLocaleChanged(const Locale('ar'));
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: local.logout, // Ajout pour accessibilité (texte localisé)
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/auth');
            },
          ),
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
              _buildTextField(local.weightLabel, controlWeight, local),
              SizedBox(height: 10),
              _buildTextField(local.heightLabel, controlHeight, local),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    calculate();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: Text(local.calculate,
                    style: TextStyle(color: Colors.white, fontSize: 20.0)),
              ),
              SizedBox(height: 20),
              _buildBMIGauge(),
              SizedBox(height: 20),
              Text(
                _info.isEmpty ? local.bmi : _info,
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
                    return history.isEmpty
                        ? Text(local.noHistory)
                        : ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final timestamp = item['timestamp'] as Timestamp?;
                        final formattedDate = timestamp != null
                            ? DateFormat('yyyy-MM-dd HH:mm:ss')
                            .format(timestamp.toDate())
                            : 'N/A';
                        final category = item['category'] ?? 'N/A';

                        return ListTile(
                          title: Text(
                              "${local.bmi}: ${item['bmi']} - ${_getCategoryTranslation(category, local)}"),
                          subtitle: Text(
                              "${local.weight}: ${item['weight']} Kg, ${local.height}: ${item['height']} cm"),
                          trailing: Text(formattedDate),
                        );
                      },
                    );
                  }
                  return Center(child: Text(local.noHistoryAvailable));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, AppLocalizations local) {
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
          return local.requiredField;
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

  String _getCategoryTranslation(String category, AppLocalizations local) {
    switch (category) {
      case 'underweight':
        return local.underweight;
      case 'normalWeight':
        return local.normalWeight;
      case 'overweight':
        return local.overweight;
      case 'obesity':
        return local.obesity;
      default:
        return 'N/A';
    }
  }
}
