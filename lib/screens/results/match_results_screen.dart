import 'package:flutter/material.dart';

class MatchResultsScreen extends StatelessWidget {
  const MatchResultsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dummy results data
    final results = [
      {'match': 'Team A vs Team B', 'result': 'Team A won by 3 wickets'},
      {'match': 'Team C vs Team D', 'result': 'Team D won by 42 runs'},
      {'match': 'Team E vs Team F', 'result': 'Match tied'},
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Match Results',
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(result['match']!),
                    subtitle: Text(result['result']!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}