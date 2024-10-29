import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class PatientReports extends StatefulWidget {
  final String patientId;

  const PatientReports({Key? key, required this.patientId}) : super(key: key);

  @override
  PatientReportsState createState() => PatientReportsState();
}

class PatientReportsState extends State<PatientReports> {
  DateTimeRange? _selectedDateRange;
  final ImagePicker _picker = ImagePicker();

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF00A19B),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _addNewReport() async {
    try {
      // Launch camera to capture image
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      
      if (photo != null) {
        // Here you would typically upload the image to Firebase Storage
        // and get the download URL. For this example, we'll just save the report data
        
        final reportsRef = FirebaseFirestore.instance
            .collection('patients')
            .doc(widget.patientId)
            .collection('reports');

        // Get the count of existing reports to determine the new report number
        final QuerySnapshot reportSnapshot = await reportsRef.get();
        final int reportNumber = reportSnapshot.size + 1;
        
        await reportsRef.add({
          'reportNumber': reportNumber,
          'date': Timestamp.now(),
          'imageUrl': 'placeholder_url', // Replace with actual uploaded image URL
          'area': '12 mm²',
          'location': 'Mid foot Heel',
          'colour': 'Normal',
          'woundAge': 'New'
        });

        // Update total records in patient document
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(widget.patientId)
            .update({'totalRecords': FieldValue.increment(1)});

      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A19B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Report', style: TextStyle(color: Colors.white)),
        actions: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDateRange != null
                              ? '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}'
                              : 'Filter',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(widget.patientId)
                  .collection('reports')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                final reports = snapshot.data!.docs;
                
                if (reports.isEmpty) {
                  return const Center(child: Text('No reports yet', style: TextStyle(color: Colors.white)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index].data() as Map<String, dynamic>;
                    return _buildReportCard(report);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.all(16),
        width: double.infinity,
        child: FloatingActionButton.extended(
          onPressed: _addNewReport,
          backgroundColor: Colors.white,
          icon: const Icon(Icons.add, color: Color(0xFF00A19B)),
          label: const Text('Add Report', style: TextStyle(color: Color(0xFF00A19B))),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report ${report['reportNumber']}',
                  style: const TextStyle(
                    color: Color(0xFF00A19B),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd MMM, yyyy').format((report['date'] as Timestamp).toDate()),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Area', '${report['area']}'),
            _buildInfoRow('Location', report['location'] ?? ''),
            _buildInfoRow('Colour', report['colour'] ?? ''),
            _buildInfoRow('Wound Age', report['woundAge'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}