import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nymea_network_manager/nymea_network_manager.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _connected = false;
  List<WiFiNetwork> _networks = [];
  NymeaNetworkManager _nymea = NymeaNetworkManager(advertisingName: 'mylisabox');

  @override
  void initState() {
    _nymea.connect().then((value) => setState(() => _connected = value));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _connected ? 'connected' : 'not connected',
            ),
            Visibility(
              visible: !_connected,
              child: RaisedButton(
                onPressed: () async {
                  final result = await _nymea.connect();
                  setState(() {
                    _connected = result;
                  });
                },
                child: Text('Connect to device'),
              ),
            ),
            Visibility(
              visible: _connected,
              child: RaisedButton(
                onPressed: () async {
                  final networks = await _nymea.getNetworks();
                  setState(() {
                    _networks = networks;
                  });
                },
                child: Text('Get network'),
              ),
            ),
            for (var i = 0; i < _networks.length; i++)
              Visibility(
                visible: _connected,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                    onPressed: () async {
                      final password = await showPrompt(context, title: 'Network password');
                      if (password != null) {
                        _nymea.connectNetwork(_networks[i].ssid, password);
                      }
                    },
                    child: Text('Connect to ${_networks[i].ssid}'),
                  ),
                ),
              ),
            Visibility(
              visible: _connected,
              child: RaisedButton(
                onPressed: () async {
                  print((await _nymea.getConnection()).toString());
                },
                child: Text('Get connexion'),
              ),
            ),
            Visibility(
              visible: _connected,
              child: RaisedButton(
                onPressed: () async {
                  await _nymea.disconnect();
                  setState(() {
                    _connected = false;
                  });
                },
                child: Text('disconnect from BT device'),
              ),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

Future<String> showPrompt(
  BuildContext context, {
  String title,
  String label,
  String hint,
}) {
  return showDialog(
    context: context,
    builder: (context) => HookBuilder(
      builder: (context) {
        final controller = useTextEditingController();
        return AlertDialog(
          actions: [
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: Text('Ok'),
            ),
          ],
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label, hintText: hint),
            obscureText: true,
          ),
        );
      },
    ),
  );
}
