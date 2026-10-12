import 'package:flutter/material.dart';

import '../shared/codekit_bottom_sheet.dart';
import 'search_history_store.dart';

Future<SavedSearch?> showSearchHistorySheet(
  BuildContext context,
  SearchHistoryStore history,
) => showCodeKitBottomSheet<SavedSearch>(
  context,
  actions: [
    AnimatedBuilder(
      animation: history,
      builder: (_, _) => TextButton(
        onPressed: history.entries.isEmpty ? null : history.clear,
        child: const Text('Clear all'),
      ),
    ),
  ],
  body: AnimatedBuilder(
    animation: history,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Search history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (history.entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No recent searches')),
          )
        else
          for (final item in history.entries)
            ListTile(
              leading: Icon(item.isRegex ? Icons.code : Icons.search),
              title: Text(item.text, maxLines: 2),
              subtitle: Text(item.isRegex ? 'Regex' : 'Text'),
              onTap: () => Navigator.pop(context, item),
            ),
      ],
    ),
  ),
);
