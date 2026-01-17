import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/animated_gradient_container.dart';
import '../services/local_image_service.dart';

class EditSubmissionScreen extends StatefulWidget {
  final String submissionId;
  final Map<String, dynamic> initialData;

  const EditSubmissionScreen({
    super.key,
    required this.submissionId,
    required this.initialData,
  });

  @override
  _EditSubmissionScreenState createState() => _EditSubmissionScreenState();
}

class _EditSubmissionScreenState extends State<EditSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _personNameController;
  late TextEditingController _businessNameController;
  late TextEditingController _emailController;
  late TextEditingController _contactNumberController;
  late TextEditingController _websiteController;
  String? _imageUrl;
  File? _newImage; // To hold the new image selected by the user
  bool _isLoading = false; // Flag to show loading indicator

  final ImagePicker _picker = ImagePicker();
  final LocalImageService _localImageService = LocalImageService();

  @override
  void initState() {
    super.initState();
    _personNameController =
        TextEditingController(text: widget.initialData['personName']);
    _businessNameController =
        TextEditingController(text: widget.initialData['businessName']);
    _emailController = TextEditingController(text: widget.initialData['email']);
    _contactNumberController =
        TextEditingController(text: widget.initialData['contactNumber']);
    _websiteController =
        TextEditingController(text: widget.initialData['website']);
    _imageUrl = widget.initialData['imageUrl'] as String?;
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _updateSubmission() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true; // Show the loader
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Save new image locally if selected
          if (_newImage != null) {
            await _localImageService.saveCardImage(
              widget.submissionId,
              _newImage!.path,
            );
          }

          final submissionRef = FirebaseDatabase.instance
              .ref('users/${user.uid}/createdCards/${widget.submissionId}');

          // Update the database with new values
          await submissionRef.update({
            'personName': _personNameController.text,
            'businessName': _businessNameController.text,
            'email': _emailController.text,
            'contactNumber': _contactNumberController.text,
            'website': _websiteController.text,
          });

          // Go back to the previous screen after the update
          Navigator.pop(context);
        }
      } catch (e) {
        print('Error updating submission: $e');
      } finally {
        setState(() {
          _isLoading = false; // Hide the loader after the update is complete
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _newImage =
            File(pickedFile.path); // Store the selected image in the state
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Edit Business Card",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: ClipRRect(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: ProfessionalAnimatedGradient(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Business Card Details",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade100,
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  image: _newImage != null
                                      ? DecorationImage(
                                          image: FileImage(_newImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : (_imageUrl != null &&
                                              _imageUrl!.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(_imageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                                ),
                                child: _newImage == null &&
                                        (_imageUrl == null ||
                                            _imageUrl!.isEmpty)
                                    ? Icon(
                                        Icons.add_a_photo,
                                        size: 40,
                                        color: Colors.grey.shade400,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              controller: _personNameController,
                              label: 'Person Name',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter a name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _businessNameController,
                              label: 'Business Name',
                              icon: Icons.business_outlined,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter a business name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter an email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _contactNumberController,
                              label: 'Contact Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _websiteController,
                              label: 'Website',
                              icon: Icons.language_outlined,
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 40),
                            Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade600,
                                    Colors.blue.shade800,
                                    Colors.purple.shade700,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _updateSubmission,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: Text(
                                  'Save Changes',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue.shade600,
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    "Saving changes...",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.grey.shade700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey.shade600,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: Colors.grey.shade600,
                size: 20,
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1),
        ),
      ),
      validator: validator,
    );
  }
}
