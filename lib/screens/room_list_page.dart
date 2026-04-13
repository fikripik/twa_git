import '../config/package_config.dart';
import 'package:http/http.dart' as http;

class RoomListPage extends StatefulWidget {
  final String userId;
  final String jenis;
  final String name;
  final String fcmToken;

  const RoomListPage({
    super.key,
    required this.userId,
    required this.jenis,
    required this.name,
    required this.fcmToken,
  });

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  final DatabaseReference roomsRef = FirebaseDatabase.instance.ref("rooms");
  List<String> roomIds = [];
  bool loading = true;
  List<Map<String, dynamic>> paketList = [];
  bool paketLoading = false;
  late String myUserId;

  @override
  void initState() {
    super.initState();
    myUserId = "${widget.jenis}_${widget.userId}";
    fetchRoomsFromBackend();
  }

  Future<void> fetchRoomsFromBackend() async {
    String param = "id_tl";
    Uri url = Uri.parse("${AppConfig.baseUrl}/api_flutter/get_room");

    if (widget.jenis == "JAMAAH") {
      param = "id_jamaah";
      url = Uri.parse("${AppConfig.baseUrl}/api_flutter/get_room_jamaah");
    }

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({param: widget.userId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          roomIds = List<String>.from(data["room_ids"] ?? []);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  String formatTime(dynamic time) {
    if (time == null) return "";
    final dt = DateTime.fromMillisecondsSinceEpoch(time);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> sendRoomToBackend(
    String roomId,
    String idTl,
    String idPaket,
  ) async {
    final url = Uri.parse("${AppConfig.baseUrl}/api_flutter/insert_room");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": roomId,
          "id_tl": idTl,
          "id_paket": idPaket,
        }),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == "success") {
          fetchRoomsFromBackend();
          showToast(
            context,
            result['message'],
            bgColor: const Color.fromARGB(255, 150, 255, 154),
          );
        } else {
          showToast(
            context,
            result['message'],
            bgColor: const Color.fromARGB(255, 255, 95, 83),
          );
        }
      } else {
        // print("Gagal kirim ke backend: ${response.statusCode}");
      }
    } catch (e) {
      print("Error kirim ke backend: $e");
    }
  }

  void createRoom(BuildContext context) async {
    await fetchPaket();

    String? selectedPaket;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Pilih Paket"),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final val = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) {
                        return Container(
                          height: MediaQuery.of(context).size.height * 0.55,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const Text(
                                "Pilih Paket",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Expanded(
                                child: ListView.builder(
                                  itemCount: paketList.length,
                                  itemBuilder: (context, i) {
                                    final p = paketList[i];
                                    final isSelected =
                                        selectedPaket == p["id_paket"];

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pop(
                                          context,
                                          p["id_paket"].toString(),
                                        );
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue.withOpacity(0.1)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.blue
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p["nama_paket"],
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check,
                                                color: Colors.blue,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );

                    if (val != null) {
                      setModalState(() {
                        selectedPaket = val;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedPaket == null
                                ? "Pilih paket"
                                : paketList.firstWhere(
                                    (p) => p["id_paket"] == selectedPaket,
                                  )["nama_paket"],
                            style: TextStyle(
                              fontSize: 15,
                              color: selectedPaket == null
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: selectedPaket == null
                  ? null
                  : () async {
                      final paket = paketList.firstWhere(
                        (p) => p["id_paket"] == selectedPaket,
                      );

                      final newRoomRef = roomsRef.push();
                      final roomId = newRoomRef.key;

                      await newRoomRef.set({
                        "name": paket["nama_paket"],
                        "createdAt": ServerValue.timestamp,
                      });

                      if (roomId != null) {
                        sendRoomToBackend(
                          roomId,
                          widget.userId,
                          paket["id_paket"],
                        );
                      }

                      Navigator.pop(context);
                    },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> fetchPaket() async {
    paketLoading = true;

    final res = await http.post(
      Uri.parse("${AppConfig.baseUrl}/api_flutter/fetch_paket_tl"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id_tl": widget.userId}),
    );

    final data = jsonDecode(res.body);
    paketList = List<Map<String, dynamic>>.from(data["paket"]);
    paketLoading = false;
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/api_flutter/delete_room"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"room_id": roomId, "id_tl": widget.userId}),
      );

      final result = jsonDecode(response.body);
      if (result['status'] == "success") {
        showToast(
          context,
          result['message'],
          bgColor: const Color.fromARGB(255, 150, 255, 154),
        );

        await FirebaseDatabase.instance.ref("chats/$roomId").remove();
        await roomsRef.child(roomId).remove();

        setState(() {
          roomIds.remove(roomId);
        });
      } else {
        showToast(
          context,
          result['message'],
          bgColor: const Color.fromARGB(255, 255, 95, 83),
        );
      }
    } catch (e) {}
  }

  void confirmDeleteRoom(BuildContext context, String roomId, String roomName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Room"),
        content: Text("Hapus grup \"$roomName\" beserta semua chat?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
            onPressed: () {
              Navigator.pop(context);
              deleteRoom(roomId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (roomIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context, "${AppConfig.baseUrl}/jamaah/masuk");
            },
          ),
          title: const Text("Chat Rooms"),
          actions: [
            if (widget.jenis == "TL")
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => createRoom(context),
              ),
          ],
        ),
        body: const Center(child: Text("Belum ada grup saat ini")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Rooms"),
        actions: [
          if (widget.jenis == "TL")
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => createRoom(context),
            ),
        ],
      ),
      body: RefreshIndicator(
        // onRefresh: () async {
        //     await fetchRoomsFromBackend();
        // },
        onRefresh: () async {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => RoomListPage(
                userId: widget.userId,
                jenis: widget.jenis,
                name: widget.name,
                fcmToken: widget.fcmToken,
              ),
              transitionDuration: Duration.zero,
            ),
          );
        },

        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: roomIds.length,
          itemBuilder: (context, index) {
            final roomId = roomIds[index];
            final roomRef = roomsRef.child(roomId);

            return FutureBuilder<DatabaseEvent>(
              future: roomRef.once(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ListTile(title: Text("Loading..."));
                }

                final roomData = snapshot.data!.snapshot.value;
                if (roomData == null) {
                  return const ListTile(title: Text("Belum ada grup saat ini"));
                }

                final room = Map<String, dynamic>.from(roomData as Map);
                final lastMsg = room["lastMessage"] ?? "";
                final lastTime = room["lastTime"];
                final unread = room["unread"]?[myUserId] ?? 0;

                return InkWell(
                  onLongPress: () {
                    confirmDeleteRoom(context, roomId, room["name"]);
                  },
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          roomId: roomId,
                          roomName: room['name'],
                          userId: widget.userId,
                          jenis: widget.jenis,
                          name: widget.name,
                          fcmToken: widget.fcmToken,
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.group)),
                    title: Text(room["name"]),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (lastTime != null)
                          Text(
                            formatTime(lastTime),
                            style: const TextStyle(fontSize: 12),
                          ),
                        const SizedBox(height: 4),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
