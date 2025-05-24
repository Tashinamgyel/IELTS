// lib/widgets/essay_view.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/essay.dart';
import '../services/firebase_service.dart';
import '../constants.dart';
import 'interactive_text.dart';

class EssayView extends StatefulWidget {
  final Essay essay;

  const EssayView({super.key, required this.essay});

  @override
  _EssayViewState createState() => _EssayViewState();
}

class _EssayViewState extends State<EssayView> {
  late Essay essay;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    essay = widget.essay;
  }

  Future<void> _upvoteEssay() async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
    });
    int newRating = essay.rating + 1;
    try {
      await _firebaseService.updateEssayRating(essay.id, newRating);
      setState(() {
        essay = Essay(
          id: essay.id,
          topic: essay.topic,
          content: essay.content,
          createdAt: essay.createdAt,
          rating: newRating,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upvoted! New rating: ${essay.rating}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating rating: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _downvoteEssay() async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
    });
    int newRating = (essay.rating > minRating) ? essay.rating - 1 : essay.rating;
    try {
      await _firebaseService.updateEssayRating(essay.id, newRating);
      setState(() {
        essay = Essay(
          id: essay.id,
          topic: essay.topic,
          content: essay.content,
          createdAt: essay.createdAt,
          rating: newRating,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downvoted! New rating: ${essay.rating}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating rating: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _shareEssayAsPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                essay.topic,
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                essay.content,
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Generated: ${_formatDate(essay.createdAt)}'),
              pw.Text('Rating: ${essay.rating}'),
            ],
          );
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    await Printing.sharePdf(bytes: pdfBytes, filename: 'essay_${essay.id}.pdf');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Split the essay content into paragraphs (assuming paragraphs are separated by double newlines).
    final List<String> paragraphs = essay.content.split('\n\n');

    return Container(
      padding: const EdgeInsets.all(16.0),
      // Container with rounded corners and shadow.
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Essay Topic
          Text(
            essay.topic,
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const Divider(height: 24.0),
          // Essay Content: Each paragraph is rendered with InteractiveText (so each word is interactive).
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: paragraphs
                .map((para) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InteractiveText(text: para),
            ))
                .toList(),
          ),
          const SizedBox(height: 16.0),
          // Footer row: Generated Date, Rating, and action icons.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Generated: ${_formatDate(essay.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rating: ${essay.rating}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14.0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    onPressed: _upvoteEssay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.thumb_down_alt_outlined),
                    onPressed: _downvoteEssay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: _shareEssayAsPDF,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
