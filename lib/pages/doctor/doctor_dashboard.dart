import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  DoctorDashboardState createState() => DoctorDashboardState();
}

class DoctorDashboardState extends State<DoctorDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String? _doctorName;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
  }

  Future<void> _loadDoctorInfo() async {
    if (user != null) {
      final doctorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      if (doctorDoc.exists) {
        setState(() {
          _doctorName = doctorDoc.data()?['name'];
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleSignOut,
        ),
        title: Text('Doctor Dashboard - $_doctorName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddPatientForm,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search patients',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(child: _buildPatientsList()),
        ],
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
          return const Center(child: CircularProgressIndicator());
        }

        final patients = snapshot.data?.docs ?? [];
        final filteredPatients = patients.where((doc) {
          final patient = doc.data() as Map<String, dynamic>;
          final searchTerm = _searchController.text.toLowerCase();
          return patient['name'].toString().toLowerCase().contains(searchTerm);
        }).toList();

        return ListView.builder(
          itemCount: filteredPatients.length,
          itemBuilder: (context, index) {
            final patientDoc = filteredPatients[index];
            final patient = patientDoc.data() as Map<String, dynamic>;
            return _buildPatientTile(patientDoc.id, patient);
          },
        );
      },
    );
  }

  Widget _buildPatientTile(String patientId, Map<String, dynamic> patient) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Text(patient['name'] ?? 'Unnamed Patient'),
        subtitle: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('medical_reports')
              .where('patientId', isEqualTo: patientId)
              .snapshots(),
          builder: (context, snapshot) {
            int reportCount = snapshot.data?.docs.length ?? 0;
            return Text(
              'ID: $patientId\nReports: $reportCount\nPhone: ${patient['phone']}',
            );
          },
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_chart),
          onPressed: () => _showAddReportForm(patientId),
        ),
      ),
    );
  }

  void _showAddReportForm(String patientId) {
    // Implement report addition form
    showDialog(
      context: context,
      builder: (context) => AddReportDialog(patientId: patientId, doctorId: user?.uid ?? ''),
    );
  }

  void _showAddPatientForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddPatientForm(doctorId: user?.uid ?? ''),
    );
  }
}

class AddReportDialog extends StatefulWidget {
  final String patientId;
  final String doctorId;

  const AddReportDialog({
    required this.patientId,
    required this.doctorId,
    super.key,
  });

  @override
  AddReportDialogState createState() => AddReportDialogState();
}

class AddReportDialogState extends State<AddReportDialog> {
  final _reportController = TextEditingController();

  Future<void> _submitReport() async {
    if (_reportController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('medical_reports').add({
          'patientId': widget.patientId,
          'doctorId': widget.doctorId,
          'content': _reportController.text,
          'createdAt': Timestamp.now(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Report'),
      content: TextField(
        controller: _reportController,
        decoration: const InputDecoration(
          labelText: 'Report Content',
          border: OutlineInputBorder(),
        ),
        maxLines: 5,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitReport,
          child: const Text('Add Report'),
        ),
      ],
    );
  }
}
class AddPatientForm extends StatefulWidget {
  final String doctorId;

  const AddPatientForm({
    required this.doctorId,
    super.key,
  });

  @override
  AddPatientFormState createState() => AddPatientFormState();
}

class AddPatientFormState extends State<AddPatientForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseFirestore.instance.collection('patients').add({
          'name': _nameController.text,
          'phone': _phoneController.text,
          'age': int.tryParse(_ageController.text) ?? 0,
          'doctorId': widget.doctorId,
          'lastSeen': Timestamp.now(),
          'createdAt': Timestamp.now(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient added successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding patient: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add New Patient',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter patient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter age';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Patient'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}