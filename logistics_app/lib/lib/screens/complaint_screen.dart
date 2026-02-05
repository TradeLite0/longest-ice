import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// شاشة تقديم شكوى
class ComplaintScreen extends StatefulWidget {
  final int? shipmentId;

  const ComplaintScreen({Key? key, this.shipmentId}) : super(key: key);

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedType = 'delay';
  String _selectedPriority = 'medium';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _complaintTypes = [
    {'value': 'delay', 'label': 'تأخير في التوصيل', 'icon': Icons.timer_off},
    {'value': 'damage', 'label': 'تلف في البضاعة', 'icon': Icons.broken_image},
    {'value': 'lost', 'label': 'فقدان الشحنة', 'icon': Icons.search_off},
    {'value': 'behavior', 'label': 'سلوك السائق', 'icon': Icons.person_off},
    {'value': 'other', 'label': 'أخرى', 'icon': Icons.more_horiz},
  ];

  final List<Map<String, dynamic>> _priorities = [
    {'value': 'low', 'label': 'منخفض', 'color': Colors.grey},
    {'value': 'medium', 'label': 'متوسط', 'color': Colors.orange},
    {'value': 'high', 'label': 'عالي', 'color': Colors.red},
    {'value': 'urgent', 'label': 'عاجل', 'color': Colors.purple},
  ];

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final result = await authService.submitComplaint(
        title: _titleController.text,
        description: _descriptionController.text,
        complaintType: _selectedType,
        priority: _selectedPriority,
        shipmentId: widget.shipmentId,
      );

      if (result['success']) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text('تم بنجاح'),
                ],
              ),
              content: const Text(
                'تم تقديم شكوتك بنجاح وسيتم مراجعتها من قبل الإدارة في أقرب وقت',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
      } else {
        _showError(result['message'] ?? 'فشل في تقديم الشكوى');
      }
    } catch (e) {
      _showError('خطأ: $e');
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقديم شكوى'),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان الشكوى
              const Text(
                'عنوان الشكوى',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'مثال: تأخير في توصيل الشحنة',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'العنوان مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // نوع الشكوى
              const Text(
                'نوع الشكوى',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _complaintTypes.map((type) {
                  final isSelected = _selectedType == type['value'];
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type['icon'], size: 18),
                        const SizedBox(width: 5),
                        Text(type['label']),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type['value']);
                      }
                    },
                    selectedColor: Colors.red.shade100,
                    checkmarkColor: Colors.red,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // الأولوية
              const Text(
                'درجة الأهمية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: _priorities.map((priority) {
                  final isSelected = _selectedPriority == priority['value'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          priority['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : priority['color'],
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPriority = priority['value']);
                          }
                        },
                        selectedColor: priority['color'],
                        backgroundColor: priority['color'].withOpacity(0.1),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // وصف الشكوى
              const Text(
                'تفاصيل الشكوى',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'اشرح المشكلة بالتفصيل...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الوصف مطلوب';
                  }
                  if (value.length < 10) {
                    return 'الوصف قصير جداً (10 أحرف على الأقل)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // زرار الإرسال
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitComplaint,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isLoading ? 'جاري الإرسال...' : 'إرسال الشكوى',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  );
}