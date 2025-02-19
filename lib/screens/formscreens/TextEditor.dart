import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

class QuillEditorField extends StatefulWidget {
  final String label;
  final bool required;
  final bool readOnly;
  final Map<String, dynamic> formData;
  final String fieldName;

  const QuillEditorField({
    Key? key,
    required this.label,
    required this.required,
    required this.readOnly,
    required this.formData,
    required this.fieldName,
    TextEditingController? controller,
  }) : super(key: key);

  @override
  _QuillEditorFieldState createState() => _QuillEditorFieldState();
}

class _QuillEditorFieldState extends State<QuillEditorField> {
  late quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final initialText = widget.formData[widget.fieldName] ?? "";
    final document = initialText.isNotEmpty
        ? quill.Document.fromDelta(Delta()..insert(initialText))
        : quill.Document();
    _controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _controller.document.changes.listen((event) {
      setState(() {
        widget.formData[widget.fieldName] = _controller.document.toPlainText();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.required ? '${widget.label} *' : widget.label,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5),
            color: widget.readOnly ? Colors.grey[300] : Colors.white,
          ),
          child: quill.QuillEditor(
            controller: _controller,
            focusNode: _focusNode,
            scrollController: ScrollController(),
            configurations: quill.QuillEditorConfigurations(
              // readOnly: widget.readOnly,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 5),
          quill.QuillToolbar.simple(
            configurations: quill.QuillSimpleToolbarConfigurations(
              controller: _controller,
            ),
          ),
        ],
      ],
    );
  }
}
