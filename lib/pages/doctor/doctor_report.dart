import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/wound_analysis.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/storage_service.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class PatientReports extends StatefulWidget {
  final String patientId;

  const PatientReports({Key? key, required this.patientId}) : super(key: key);

  @override
  PatientReportsState createState() => PatientReportsState();
}

class PatientReportsState extends State<PatientReports> {
  final StorageService _storageService = StorageService();
  DateTimeRange? _selectedDateRange;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;

  Future<void> _selectDateRange() async {
    // Set default range to all time (from 2020 to now)
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime(2020), // Changed to start from 2020 instead of last year
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
      setState(() {
        _isAnalyzing = true;
      });

      XFile? photo;
      if (kIsWeb) {
        // For web platform, show image source dialog
        photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      } else {
        // For mobile platforms
        photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      }

      if (photo == null) {
        throw Exception('No image captured');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading and analyzing wound...')),
      );

      // Upload image first
      final String imageUrl = await _storageService.uploadImage(photo, widget.patientId);

      // Analyze wound
      final analysisResult = await WoundAnalysisService.analyzeWound(photo);

      if (analysisResult.containsKey('error')) {
        // Delete uploaded image if analysis fails
        await _storageService.deleteImage(imageUrl);
        throw Exception(analysisResult['message'] ?? 'Analysis failed');
      }

      // Get reference to reports collection
      final reportsRef = FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .collection('reports');

      // Get report number
      final QuerySnapshot reportSnapshot = await reportsRef.get();
      final int reportNumber = reportSnapshot.size + 1;

      // Store the analysis data with image URL
      await reportsRef.add({
        'reportNumber': reportNumber,
        'date': Timestamp.now(),
        'imageUrl': imageUrl,
        'analysis': {
          'ulcer_area_pixels': analysisResult['ulcer_area_pixels'],
          'sticker_area_pixels': analysisResult['sticker_area_pixels'],
          'sticker_area_mm': analysisResult['sticker_area_mm'],
          'ulcer_area_mm': analysisResult['ulcer_area_mm'],
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update total records
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .update({
        'totalRecords': FieldValue.increment(1),
        'lastReportDate': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      print('Error in _addNewReport: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
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
                          _selectedDateRange != null ? '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}' : 'All Time', // Changed default text to "All Time"
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
              stream: FirebaseFirestore.instance.collection('patients').doc(widget.patientId).collection('reports').orderBy('date', descending: true).snapshots(),
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
  final numberFormat = NumberFormat("#,##0.00");
  final analysis = report['analysis'] as Map<String, dynamic>? ?? {};
  final String? imageUrl = report['imageUrl'];

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('dd MMM, yyyy').format((report['date'] as Timestamp).toDate()),
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (imageUrl != null) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: const Color(0xFF00A19B),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Image loading error: $error');
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Error loading image',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ElevatedButton.icon(
                        onPressed: () => _showImageDialog(context, imageUrl),
                        icon: const Icon(Icons.zoom_in, size: 18),
                        label: const Text('View Full Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Divider(color: Colors.grey),
          const SizedBox(height: 16),
          _buildAnalysisSection(
            'Diabetic Foot Ulcer',
            [
              _buildAnalysisRow(
                'Area (mm²)',
                numberFormat.format(analysis['ulcer_area_mm'] ?? 0),
                Icons.straighten,
              ),
              _buildAnalysisRow(
                'Area (pixels)',
                numberFormat.format(analysis['ulcer_area_pixels'] ?? 0),
                Icons.photo_size_select_small,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnalysisSection(
            'Reference Sticker',
            [
              _buildAnalysisRow(
                'Area (mm²)',
                numberFormat.format(analysis['sticker_area_mm'] ?? 0),
                Icons.straighten,
              ),
              _buildAnalysisRow(
                'Area (pixels)',
                numberFormat.format(analysis['sticker_area_pixels'] ?? 0),
                Icons.photo_size_select_small,
              ),
            ],
          ),
          if (analysis['notes'] != null) ...[
            const SizedBox(height: 16),
            _buildAnalysisSection(
              'Notes',
              [
                Text(
                  analysis['notes'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildAnalysisSection(String title, List<Widget> rows) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00A19B),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      ...rows,
    ],
  );
}

Widget _buildAnalysisRow(String label, String value, IconData icon) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// Add this method to show the full-screen image dialog
void _showImageDialog(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: const Color(0xFF00A19B),
                title: const Text('Wound Image'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF00A19B),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Image loading error: $error');
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          const Text('Unable to load image'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showImageDialog(context, imageUrl);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String> _getImageUrl(String imageUrl) async {
  if (kIsWeb) {
    try {
      // For web platform, get a fresh download URL
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting fresh URL: $e');
      // If getting fresh URL fails, return the original URL
      return imageUrl;
    }
  }
  // For mobile platforms, return the original URL
  return imageUrl;
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
