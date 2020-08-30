# nymea_network_manager

Flutter package to interact with nymea network manager in BT BLE

More info on nymea network manager on their repo https://github.com/nymea/nymea-networkmanager

## Configuration

This package is using flutter_blue to manage BLE connection. Be sure to check [their repo](https://github.com/pauldemarco/flutter_blue#setup) to configure Bluetooth permissions. 

Create an instance of `NymeaNetworkManager`:

```
final nymea = NymeaNetworkManager();
```

You can customize `advertisingName` if needed, by default it's `BT WLAN setup`. 

You can also enable logs during development with `enableLogs` field.

## Usage

### Search and connect to a remote device

```
await nymea.connect();
```

It will search and connect a device who advertise `advertisingName` configured previously.

If not device found a `NoDeviceException` will be thrown.

### Get remote device available network

```
final networks = await nymea.getNetworks();
```

### Connect the remote device to a network

You can connect to a visible network or an hidden one. 

For a visible one do:   
```
await nymea.connectNetwork(ssid, password);
```

For a hidden one do:   
```
await nymea.connectHiddenNetwork(ssid, password);
```

### Get remote device network information

```
final info = await nymea.getConnection();
```

### Disconnect remote device from network

```
await nymea.disconnectNetwork();
```

### Disconnect from remote device

```
await nymea.disconnect();
```
