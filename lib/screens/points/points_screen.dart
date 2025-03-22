import 'package:flutter/material.dart';

class PointsScreen extends StatelessWidget {
  const PointsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dummy points data
    final pointsTable = [
      {'team': 'Team A', 'matches': 5, 'points': 8},
      {'team': 'Team B', 'matches': 5, 'points': 6},
      {'team': 'Team C', 'matches': 5, 'points': 4},
      {'team': 'Team D', 'matches': 5, 'points': 4},
      {'team': 'Team E', 'matches': 5, 'points': 2},
      {'team': 'Team F', 'matches': 5, 'points': 0},
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Points Table',
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: pointsTable.length,
              itemBuilder: (context, index) {
                final Map team = pointsTable[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(team['team']!),
                    subtitle: Text('Matches: ${team['matches']} | Points: ${team['points']}'),
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