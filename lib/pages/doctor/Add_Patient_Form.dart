import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPatientForm extends StatefulWidget {
  const AddPatientForm({Key? key}) : super(key: key);

  @override
  _AddPatientFormState createState() => _AddPatientFormState();
}

class _AddPatientFormState extends State<AddPatientForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addPatient() async {
    if (_formKey.currentState!.validate()) {
      try {
        final patientData = {
          'name': _nameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'phone': _phoneController.text.trim(),
          'doctorId': user?.uid,
          'lastSeen': Timestamp.now(),
          'totalRecords': 0,
        };

        await FirebaseFirestore.instance.collection('patients').add(patientData);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient added successfully')));
      } catch (e) {
        print('Error adding patient: $e');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error adding patient')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                'Add Patient',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00A19B),
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(_nameController, 'Patient Name', 'Enter a name'),
              const SizedBox(height: 16),
              _buildTextField(
                _ageController,
                'Age',
                'Enter a valid age',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final age = int.tryParse(value ?? '');
                  if (age == null || age < 0 || age > 120) {
                    return 'Enter a valid age (0-120)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, 'Phone', 'Enter phone number'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addPatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A19B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: const Text(
                  'Add Patient',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String errorMessage, {
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color(0xFFB0B0B0)), // Softer grey color for labels
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF00A19B), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF00A19B), width: 2),
        ),
      ),
      validator: validator ?? (value) => value!.isEmpty ? errorMessage : null,
    );
  }
}
