import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'doctor_report.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  DoctorDashboardState createState() => DoctorDashboardState();
}

class DoctorDashboardState extends State<DoctorDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A19B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              Expanded(child: _buildPatientsList()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildAddPatientButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset('logo.png', height: 24, width: 24),
        const Text('Patients', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              TextButton(onPressed: _signOut, child: const Text('Log Out', style: TextStyle(color: Colors.red))),
              const CircleAvatar(radius: 16, backgroundColor: Color(0xFFE0E0E0), child: Icon(Icons.person, size: 20, color: Colors.grey)),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Search patients...',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('patients').where('doctorId', isEqualTo: user?.uid).orderBy('lastSeen', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        // Filter patients based on the search query
        final patients = snapshot.data!.docs.where((doc) {
          final patient = doc.data() as Map<String, dynamic>;
          final name = patient['name'] ?? '';
          return name.toLowerCase().contains(_searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index].data() as Map<String, dynamic>;
            return _buildPatientCard(patient, patients[index].id);
          },
        );
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, String patientId) {
    return GestureDetector(
      onTap: () => _viewPatientDetails(patientId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(patient['name'] ?? 'Patient', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
                  GestureDetector(
                    onTap: () => _deletePatient(patientId),
                    child: const Text('Delete Record', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Age: ${patient['age'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              Text('Phone: ${patient['phone'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Last seen ${DateFormat('dd MMMM yyyy').format((patient['lastSeen'] as Timestamp).toDate())}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Records', style: TextStyle(color: Colors.black87, fontSize: 14)),
                  Text('${patient['totalRecords'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPatientButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showAddPatientForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF00A19B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add Patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Future<void> _deletePatient(String patientId) async {
    // Show confirmation dialog before deleting the patient
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Patient Record'),
          content: const Text('Are you sure you want to delete this patient record?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // User pressed Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // User pressed Confirm
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    // If the user confirmed, proceed with deletion
    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('patients').doc(patientId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient record deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error deleting patient record')));
      }
    }
  }

  void _viewPatientDetails(String patientId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientReports(patientId: patientId),
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showAddPatientForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddPatientForm(), // Ensure this is correct
    );
  }
}

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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String errorMessage, {
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
