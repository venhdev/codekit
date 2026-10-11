import 'package:flutter/material.dart';

import 'search_history_store.dart';

Future<SavedSearch?> showSearchHistorySheet(
  BuildContext context,
  SearchHistoryStore history,
) => showModalBottomSheet<SavedSearch>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .55,
    child: SafeArea(
      child: AnimatedBuilder(
        animation: history,
        builder: (context, _) => Column(
          children: [
            ListTile(
              title: const Text('Search history'),
              trailing: TextButton(
                onPressed: history.entries.isEmpty ? null : history.clear,
                child: const Text('Clear all'),
              ),
            ),
            Expanded(
              child: history.entries.isEmpty
                  ? const Center(child: Text('No recent searches'))
                  : ListView.builder(
                      itemCount: history.entries.length,
                      itemBuilder: (context, index) {
                        final item = history.entries[index];
                        return ListTile(
                          leading: Icon(
                            item.isRegex ? Icons.code : Icons.search,
                          ),
                          title: Text(item.text, maxLines: 2),
                          subtitle: Text(item.isRegex ? 'Regex' : 'Text'),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  ),
);
