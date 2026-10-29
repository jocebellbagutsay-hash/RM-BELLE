import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityMeshChatScreen extends StatefulWidget {
  const ActivityMeshChatScreen({Key? key}) : super(key: key);

  @override
  State<ActivityMeshChatScreen> createState() => _ActivityMeshChatScreenState();
}

class _ActivityMeshChatScreenState extends State<ActivityMeshChatScreen> {
  final String userName = 'Device_${Random().nextInt(10000)}';
  final Strategy strategy = Strategy.P2P_STAR;
  
  bool isAdvertising = false;
  bool isDiscovering = false;
  
  Map<String, String> discoveredDevices = {}; // endpointId -> endpointName
  Map<String, String> connectedDevices = {}; // endpointId -> endpointName
  
  List<ChatMessage> messages = [];
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
    
    _startAdvertising();
    _startDiscovery();
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    _messageController.dispose();
    super.dispose();
  }

  void _startAdvertising() async {
    try {
      bool a = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            setState(() {
              connectedDevices[id] = discoveredDevices[id] ?? 'Unknown Device';
            });
          }
        },
        onDisconnected: (id) {
          setState(() {
            connectedDevices.remove(id);
          });
        },
      );
      setState(() {
        isAdvertising = a;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _startDiscovery() async {
    try {
      bool a = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          setState(() {
            discoveredDevices[id] = name;
          });
          // Automatically request connection
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                setState(() {
                  connectedDevices[id] = discoveredDevices[id] ?? 'Unknown';
                });
              }
            },
            onDisconnected: (id) {
              setState(() {
                connectedDevices.remove(id);
              });
            },
          );
        },
        onEndpointLost: (id) {
          setState(() {
            discoveredDevices.remove(id);
          });
        },
      );
      setState(() {
        isDiscovering = a;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) async {
    // Automatically accept the connection
    discoveredDevices[id] = info.endpointName;
    try {
      await Nearby().acceptConnection(
        id,
        onPayLoadRecieved: (endpointId, payload) {
          if (payload.type == PayloadType.BYTES) {
            String str = String.fromCharCodes(payload.bytes!);
            setState(() {
              messages.add(ChatMessage(
                text: str,
                senderName: connectedDevices[endpointId] ?? 'Unknown',
                isMe: false,
              ));
            });
          }
        },
        onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || connectedDevices.isEmpty) return;

    for (var id in connectedDevices.keys) {
      Nearby().sendBytesPayload(id, Uint8List.fromList(text.codeUnits));
    }
    
    setState(() {
      messages.add(ChatMessage(text: text, senderName: userName, isMe: true));
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Mesh Chat'),
      ),
      body: Column(
        children: [
          _buildControls(),
          _buildDeviceList(),
          const Divider(height: 1),
          Expanded(child: _buildChatArea()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8,
        children: [
          ElevatedButton(
            onPressed: isAdvertising ? () {
              Nearby().stopAdvertising();
              setState(() { isAdvertising = false; });
            } : _startAdvertising,
            child: Text(isAdvertising ? 'Stop Advertising' : 'Advertise'),
          ),
          ElevatedButton(
            onPressed: isDiscovering ? () {
              Nearby().stopDiscovery();
              setState(() { isDiscovering = false; discoveredDevices.clear(); });
            } : _startDiscovery,
            child: Text(isDiscovering ? 'Stop Discovery' : 'Discover'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (discoveredDevices.isEmpty && connectedDevices.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 100,
      color: Colors.grey.shade200,
      child: ListView(
        children: [
          if (discoveredDevices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(4.0),
              child: Text('Discovered (Tap to connect):', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...discoveredDevices.entries.where((e) => !connectedDevices.containsKey(e.key)).map((e) {
              return ListTile(
                title: Text(e.value),
                trailing: const Icon(Icons.add),
                onTap: () {
                  Nearby().requestConnection(
                    userName,
                    e.key,
                    onConnectionInitiated: _onConnectionInit,
                    onConnectionResult: (id, status) {
                      if (status == Status.CONNECTED) {
                        setState(() {
                          connectedDevices[id] = discoveredDevices[id] ?? 'Unknown';
                        });
                      }
                    },
                    onDisconnected: (id) {
                      setState(() {
                        connectedDevices.remove(id);
                      });
                    },
                  );
                },
              );
            }).toList(),
          ],
          if (connectedDevices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(4.0),
              child: Text('Connected:', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...connectedDevices.entries.map((e) {
              return ListTile(
                title: Text(e.value),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Nearby().disconnectFromEndpoint(e.key);
                    setState(() {
                      connectedDevices.remove(e.key);
                    });
                  },
                ),
              );
            }).toList(),
          ]
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      reverse: false,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return ListTile(
          title: Align(
            alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: msg.isMe ? Colors.blue[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.senderName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(msg.text),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final String senderName;
  final bool isMe;

  ChatMessage({required this.text, required this.senderName, required this.isMe});
}
