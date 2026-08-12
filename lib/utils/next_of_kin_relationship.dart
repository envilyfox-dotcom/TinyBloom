import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

const nextOfKinRelationshipOptions = [
  'Husband / Partner',
  'Mother',
  'Father',
  'Sister',
  'Brother',
  'Friend',
  'Other',
];

// Shows a dialog to pick/edit the next of kin's relationship to the mum,
// saves it to Supabase, and returns the new value (or null if cancelled).
Future<String?> editNextOfKinRelationship(
  BuildContext context, {
  required String? currentRelationship,
}) {
  String? selected = currentRelationship;
  bool saving = false;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Relationship'),
            content: DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(
                  labelText: 'Relationship to Expectant Mother'),
              items: nextOfKinRelationshipOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged:
                  saving ? null : (v) => setDialogState(() => selected = v),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving || selected == null
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await SupabaseService.updateNextOfKinRelationship(
                              selected!);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, selected);
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
