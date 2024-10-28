import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_patient_form.dart';  // Import the AddPatientForm

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
      stream: FirebaseFirestore.instance
          .collection('patients')
          .where('doctorId', isEqualTo: user?.uid)
          .orderBy('lastSeen', descending: true)
          .snapshots(),
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
    Navigator.pushNamed(context, '/patient-details', arguments: patientId);
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
      builder: (context) => const AddPatientForm(),  // Ensure this is correct
    );
  }
}
