// lib/screens/llg/send_recommendation_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child_model.dart';
import '../../utils/constants.dart';

class SendRecommendationPage extends StatefulWidget {
  final ChildModel child;

  const SendRecommendationPage({super.key, required this.child});

  @override
  State<SendRecommendationPage> createState() => _SendRecommendationPageState();
}

class _SendRecommendationPageState extends State<SendRecommendationPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendRecommendation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('recommendations').add({
        'childId': widget.child.childId,
        'llgId': FirebaseAuth.instance.currentUser?.uid,
        'message': _messageController.text.trim(),
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Recommendation sent successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Send Recommendation', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👩‍🏫 Recommendation for ${widget.child.name}',
                  style: AppTextStyles.heading1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Send a friendly, non-clinical recommendation to the parent.',
                  style: AppTextStyles.bodyLight,
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Message',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _messageController,
                  maxLines: 8,
                  validator: (v) => v!.isEmpty ? 'Please enter a message' : null,
                  decoration: InputDecoration(
                    hintText: 'Example: "Aarav is doing great with language! Try sand writing to improve motor skills."',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendRecommendation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text('Send Recommendation', style: AppTextStyles.button),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}