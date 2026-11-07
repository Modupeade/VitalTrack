import 'package:flutter/material.dart';
import 'package:vitals_10/services/ai_health_service.dart';
import 'package:vitals_10/services/email_service.dart';
import 'package:vitals_10/utils/constants.dart';

class AiHealthInsightsScreen extends StatefulWidget {
  final AiHealthContext contextData;
  final String report;

  const AiHealthInsightsScreen({
    super.key,
    required this.contextData,
    required this.report,
  });

  @override
  State<AiHealthInsightsScreen> createState() => _AiHealthInsightsScreenState();
}

class _AiHealthInsightsScreenState extends State<AiHealthInsightsScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<AiChatTurn> _followUps = [];
  bool _asking = false;
  bool _emailing = false;
  bool _loadingState = true;
  int _questionsUsed = 0;

  int get _questionsLeft =>
      (AiHealthService.maxFollowUps - _questionsUsed).clamp(
        0,
        AiHealthService.maxFollowUps,
      );

  @override
  void initState() {
    super.initState();
    _restoreFollowUps();
  }

  Future<void> _restoreFollowUps() async {
    final saved = await AiHealthService.loadFollowUpState();
    if (!mounted) return;
    setState(() {
      _questionsUsed = saved.used;
      if (saved.dateRange == widget.contextData.dateRange) {
        _followUps
          ..clear()
          ..addAll(saved.turns);
      }
      _loadingState = false;
    });
  }

  Future<void> _persistFollowUps() {
    return AiHealthService.saveFollowUpState(
      used: _questionsUsed,
      dateRange: widget.contextData.dateRange,
      turns: _followUps,
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _input.text.trim();
    if (question.isEmpty || _asking) return;
    if (_questionsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have used all follow-up questions.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    _input.clear();
    final priorTurns = List<AiChatTurn>.of(_followUps);
    setState(() {
      _asking = true;
      _questionsUsed += 1;
      _followUps.add(AiChatTurn(role: 'user', text: question));
    });
    try {
      final answer = await AiHealthService.askFollowUp(
        ctx: widget.contextData,
        report: widget.report,
        followUps: priorTurns,
        question: question,
      );
      if (!mounted) return;
      setState(() {
        _followUps.add(AiChatTurn(role: 'assistant', text: answer));
      });
      await _persistFollowUps();
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _questionsUsed = (_questionsUsed - 1).clamp(0, AiHealthService.maxFollowUps);
        if (_followUps.isNotEmpty && _followUps.last.role == 'user') {
          _followUps.removeLast();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _emailPdf() async {
    if (_emailing) return;
    FocusScope.of(context).unfocus();
    final email = widget.contextData.userEmail;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found on this account.')),
      );
      return;
    }

    setState(() => _emailing = true);
    try {
      final sent = await EmailService.sendAIHealthReport(
        recipientEmail: email,
        recipientName: widget.contextData.userName,
        dateRange: widget.contextData.dateRange,
        reportText: widget.report,
        followUps: _followUps
            .map((turn) => {'role': turn.role, 'text': turn.text})
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'AI report PDF sent to $email'
                : 'Failed to send the report. Please try again.',
          ),
          backgroundColor: sent ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send the report: $e')),
      );
    } finally {
      if (mounted) setState(() => _emailing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('AI Health Insights'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Period: ${widget.contextData.dateRange}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                10.height,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This is not medical advice. It is based only on the data you logged in Vitals and any device readings for this period.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                16.height,
                _bubble(widget.report, isUser: false, title: 'AI report'),
                for (final turn in _followUps)
                  _bubble(
                    turn.text,
                    isUser: turn.role == 'user',
                    title: turn.role == 'user' ? 'You' : 'AI',
                  ),
                if (_asking)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !_loadingState && _questionsLeft > 0 && !_asking,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: _questionsLeft > 0
                              ? 'Ask a follow-up, e.g. Why is my BP high?'
                              : 'Follow-up limit reached',
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _ask(),
                      ),
                    ),
                    8.width,
                    IconButton(
                      onPressed: _asking ? null : _ask,
                      icon: const Icon(Icons.send),
                      color: primaryColor,
                    ),
                  ],
                ),
                6.height,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$_questionsLeft of ${AiHealthService.maxFollowUps} follow-ups left',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                10.height,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _emailing ? null : _emailPdf,
                    icon: _emailing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text(
                      'Send report as PDF to email',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff00b048),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
        ],
      ),
    );
  }

  Widget _bubble(String text, {required bool isUser, required String title}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFDFF5E5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            8.height,
            SelectableText(text, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}
