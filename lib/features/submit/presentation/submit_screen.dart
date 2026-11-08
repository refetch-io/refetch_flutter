import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/error_message.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/submit_repository.dart';

/// Share a story, as on refetch.io: a link and a title, plus an optional note
/// that becomes the first comment of the discussion.
class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({super.key});

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _note = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final analytics = ref.read(analyticsProvider);
    try {
      final id = await ref
          .read(submitRepositoryProvider)
          .submit(
            title: _title.text.trim(),
            url: _url.text.trim(),
            comment: _note.text.trim(),
          );
      analytics.track(
        AnalyticsEvents.storySubmitted,
        props: {'has_note': _note.text.trim().isNotEmpty},
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Shared. It reaches the front page once it has been reviewed.',
          ),
        ),
      );
      if (mounted) router.pushReplacement('/thread/$id');
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            messageForError(error, fallback: 'Could not share your story.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: user == null
          ? EmptyState(
              icon: LucideIcons.squarePen,
              title: 'Share a story',
              message: 'Sign in to share links with the community.',
              action: FilledButton(
                onPressed: () => context.push('/signin'),
                child: const Text('Sign in'),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Share a story',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Links to articles, launches and projects worth a builder’s time.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Link',
                            hintText: 'https://',
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            final uri = Uri.tryParse(value);
                            final ok =
                                uri != null &&
                                (uri.scheme == 'http' ||
                                    uri.scheme == 'https') &&
                                uri.host.isNotEmpty;
                            return ok ? null : 'Enter a valid http(s) link';
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _title,
                          maxLength: 300,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Add a title'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _note,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            hintText:
                                'Why is it worth reading? This starts the discussion.',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Share'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
