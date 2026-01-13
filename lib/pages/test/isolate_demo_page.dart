import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import '../../services/http_service.dart';

void main() {
  runApp(const MaterialApp(home: IsolateDemoPage()));
}

// Model for testing
class Photo {
  final int id;
  final String title;
  final String url;
  final String thumbnailUrl;

  Photo.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      title = json['title'],
      url = json['url'],
      thumbnailUrl = json['thumbnailUrl'];
}

// Top-level parser function
List<Photo> parsePhotos(dynamic json) {
  if (json is List) {
    return json.map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
  }
  return [];
}

class IsolateDemoPage extends StatefulWidget {
  const IsolateDemoPage({super.key});

  @override
  State<IsolateDemoPage> createState() => _IsolateDemoPageState();
}

class _IsolateDemoPageState extends State<IsolateDemoPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _status = 'Ready';

  // Large JSON list (5000 items)
  final String _testUrl = 'https://jsonplaceholder.typicode.com/photos';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runRequests({required bool useIsolate}) async {
    setState(() {
      _status =
          'Starting 3 Requests (${useIsolate ? "Background" : "Main Thread"})...\nWatch the spinner!';
    });

    final stopwatch = Stopwatch()..start();
    final results = <int>[];

    try {
      // Request 1
      setState(() => _status = 'Request 1/3 sending...');
      final r1 = await httpService.get(
        _testUrl,
        parser: parsePhotos,
        mode: useIsolate ? ParseMode.pool : ParseMode.main,
      );
      if (r1.success) results.add(r1.data!.length);

      // Request 2
      setState(() => _status = 'Request 2/3 sending...');
      final r2 = await httpService.get(
        _testUrl,
        parser: parsePhotos,
        mode: useIsolate ? ParseMode.pool : ParseMode.main,
      );
      if (r2.success) results.add(r2.data!.length);

      // Request 3
      setState(() => _status = 'Request 3/3 sending...');
      final r3 = await httpService.get(
        _testUrl,
        parser: parsePhotos,
        mode: useIsolate ? ParseMode.pool : ParseMode.main,
      );
      if (r3.success) results.add(r3.data!.length);

      stopwatch.stop();

      setState(() {
        _status =
            'Finished!\n'
            'Mode: ${useIsolate ? "Isolate (Background)" : "Main Thread"}\n'
            'Total Time: ${stopwatch.elapsedMilliseconds}ms\n'
            'Items Parsed: ${results.join(" + ")}';
      });

      SmartDialog.showToast('All done!');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HttpService Isolate Demo')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Performance Indicator
            RotationTransition(
              turns: _controller,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.sync, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Smoothness Indicator\n(Stutter = UI Blocked)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _status,
                style: const TextStyle(fontSize: 16, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _runRequests(useIsolate: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text(
                      'Main Thread\n(Laggy)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _runRequests(useIsolate: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text(
                      'Background Isolate\n(Smooth)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
