import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';

// ─── Document types ───────────────────────────────────────────────────────────

class _DocType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String hint;

  const _DocType(this.id, this.label, this.icon, this.color, this.hint);
}

const _docTypes = [
  _DocType('Writ Petition', 'Writ Petition', Icons.account_balance_outlined,
      AppColors.secondary, 'Under Art. 226/32 of Constitution'),
  _DocType('Civil Suit / Plaint', 'Civil Plaint', Icons.gavel_outlined,
      AppColors.info, 'CPC Order VII Rule 1'),
  _DocType('Written Statement / Reply', 'Written Statement', Icons.edit_document,
      AppColors.success, 'Reply to Plaint/Petition'),
  _DocType('Legal Notice', 'Legal Notice', Icons.mail_outline_rounded,
      AppColors.warning, 'Under Sec. 80 CPC / 138 NI Act'),
  _DocType('Bail Application', 'Bail Application', Icons.lock_open_outlined,
      AppColors.error, 'Regular / Anticipatory Bail'),
  _DocType('Affidavit', 'Affidavit', Icons.verified_outlined,
      AppColors.secondary, 'Sworn statement'),
  _DocType('Application', 'Application', Icons.assignment_outlined,
      AppColors.info, 'Interlocutory / Misc. Application'),
  _DocType('Appeal', 'Appeal', Icons.upload_outlined,
      AppColors.warning, 'First / Second Appeal'),
  _DocType('Counter Affidavit', 'Counter Affidavit', Icons.swap_horiz_rounded,
      AppColors.textSecondary, 'Reply to Affidavit'),
  _DocType('Vakalatnama', 'Vakalatnama', Icons.handshake_outlined,
      AppColors.textPrimary, 'Authority to Advocate'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class DraftDocumentScreen extends ConsumerStatefulWidget {
  const DraftDocumentScreen({super.key});
  @override
  ConsumerState<DraftDocumentScreen> createState() => _DraftDocumentScreenState();
}

class _DraftDocumentScreenState extends ConsumerState<DraftDocumentScreen> {
  _DocType? _selected;
  bool _generating = false;
  String? _result;
  String? _resultTitle;
  String? _error;

  final _courtCtrl      = TextEditingController();
  final _petCtrl        = TextEditingController();
  final _respCtrl       = TextEditingController();
  final _caseNoCtrl     = TextEditingController();
  final _subjectCtrl    = TextEditingController();
  final _factsCtrl      = TextEditingController();
  final _reliefCtrl     = TextEditingController();
  final _actsCtrl       = TextEditingController();
  final _additionalCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_courtCtrl, _petCtrl, _respCtrl, _caseNoCtrl,
        _subjectCtrl, _factsCtrl, _reliefCtrl, _actsCtrl, _additionalCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    if (_selected == null) return;
    if (_petCtrl.text.trim().isEmpty || _factsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in Petitioner/Applicant name and Facts'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() { _generating = true; _result = null; _error = null; });

    try {
      final res = await DioClient.post('/ai/draft-legal', data: {
        'document_type':    _selected!.id,
        'court_name':       _courtCtrl.text.trim(),
        'petitioner_name':  _petCtrl.text.trim(),
        'respondent_name':  _respCtrl.text.trim(),
        'case_number':      _caseNoCtrl.text.trim(),
        'subject':          _subjectCtrl.text.trim(),
        'facts':            _factsCtrl.text.trim(),
        'relief_sought':    _reliefCtrl.text.trim(),
        'acts_and_sections':_actsCtrl.text.trim(),
        'additional_info':  _additionalCtrl.text.trim(),
      });
      final data = res['data'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _result = data['content'] ?? '';
          _resultTitle = data['title'] ?? _selected!.id;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().contains('Daily AI')
              ? 'Daily AI limit reached. Please try again later.'
              : 'Generation failed: ${e.toString()}';
          _generating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Legal Document Drafter',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          if (_result != null)
            TextButton.icon(
              onPressed: () => setState(() { _result = null; _selected = null; }),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('New Draft'),
            ),
        ],
      ),
      body: _result != null ? _buildResult() : _buildForm(),
    );
  }

  // ── Result view ─────────────────────────────────────────────────────────────

  Widget _buildResult() => Column(children: [
    // Toolbar
    Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(child: Text(_resultTitle ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary))),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _result!));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Document copied to clipboard'),
              behavior: SnackBarBehavior.floating,
            ));
          },
          icon: const Icon(Icons.copy, size: 15),
          label: const Text('Copy'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ]),
    ),
    // Document text
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.sm,
        ),
        child: SelectableText(_result!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.7,
              color: AppColors.primaryLight,
            )),
      ),
    )),
  ]);

  // ── Form view ────────────────────────────────────────────────────────────────

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Document type picker
      const Text('Select Document Type',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, letterSpacing: 0.5)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
        children: _docTypes.map((t) => _TypeTile(
          type: t,
          selected: _selected?.id == t.id,
          onTap: () => setState(() { _selected = t; _result = null; }),
        )).toList(),
      ),

      if (_selected != null) ...[
        const SizedBox(height: 24),

        // Section header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _selected!.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_selected!.icon, color: _selected!.color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selected!.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text(_selected!.hint,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
        const SizedBox(height: 16),

        // Fields
        _field(_courtCtrl, 'Court Name',
            'e.g. High Court of Judicature at Bombay', Icons.account_balance_outlined),
        _field(_petCtrl, 'Petitioner / Applicant / Plaintiff *',
            'Full name of the moving party', Icons.person_outlined),
        _field(_respCtrl, 'Respondent / Defendant / Opposite Party',
            'Full name of the other party', Icons.person_off_outlined),

        if (_needsCaseNumber()) ...[
          _field(_caseNoCtrl, 'Case / Application Number',
              'e.g. CRL.P. No. 1234/2024', Icons.tag),
        ],

        _field(_subjectCtrl, 'Subject / Matter in Brief',
            'e.g. Wrongful termination of service', Icons.subject_outlined),
        _field(_factsCtrl, 'Facts & Grounds *',
            'State the key facts chronologically. Include dates, events, and legal basis.',
            Icons.notes_outlined, lines: 6),
        _field(_reliefCtrl, 'Relief / Prayer Sought',
            'What order/direction are you seeking from the court?',
            Icons.how_to_vote_outlined, lines: 3),
        _field(_actsCtrl, 'Acts & Sections',
            'e.g. Section 302 IPC, Article 21 Constitution',
            Icons.gavel_outlined),
        _field(_additionalCtrl, 'Additional Information',
            'Any other details the AI should include',
            Icons.add_circle_outline, lines: 3),

        const SizedBox(height: 8),

        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13))),
            ]),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_generating ? 'Drafting document...' : 'Generate Draft'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    ]),
  );

  bool _needsCaseNumber() {
    final id = _selected?.id ?? '';
    return id.contains('Reply') || id.contains('Counter') ||
        id.contains('Appeal') || id.contains('Application');
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      IconData icon, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: lines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
              prefixIcon: lines == 1
                  ? Icon(icon, size: 17, color: AppColors.textTertiary)
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: lines > 1 ? 12 : 0),
            ),
          ),
        ]),
      );
}

// ── Type tile ─────────────────────────────────────────────────────────────────

class _TypeTile extends StatelessWidget {
  final _DocType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: selected ? type.color.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? type.color : AppColors.outline,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected ? [] : AppShadows.sm,
      ),
      child: Row(children: [
        Icon(type.icon, color: selected ? type.color : AppColors.textTertiary, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(type.label,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? type.color : const Color(0xFF374151),
            ))),
      ]),
    ),
  );
}
