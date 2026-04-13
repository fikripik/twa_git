import '../config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class ChatPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final String jenis; // JAMAAH / TL
  final String name;
  final String fcmToken;
  final String roomName;

  const ChatPage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.jenis,
    required this.name,
    required this.fcmToken,
    required this.roomName,
  });

  String get myUserId => "${jenis}_$userId";

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageCtrl = TextEditingController();

  late String myUserId;
  late String myName;
  late String myJenis;
  late String myToken;

  final GlobalKey plusKey = GlobalKey();
  OverlayEntry? attachOverlay;
  bool isAttachOpen = false;
  double uploadProgress = 0.0;
  bool isUploading = false;

  final ScrollController _scrollController = ScrollController();
  late DatabaseReference db;

  @override
  void initState() {
    super.initState();
    myUserId = "${widget.jenis}_${widget.userId}";
    myName = widget.name;
    myJenis = widget.jenis;
    myToken = widget.fcmToken;

    db = FirebaseDatabase.instance.ref("chats/${widget.roomId}");

    FirebaseDatabase.instance
        .ref("rooms/${widget.roomId}/unread/$myUserId")
        .set(0);
  }

  @override
  void dispose() {
    VideoCompress.dispose();
    super.dispose();
  }

  Widget buildAttachPopup() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD600),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            attachItem(Icons.image, "Gallery"),
            attachItem(Icons.videocam, "Video"),
            attachItem(Icons.camera_alt, "Camera"),
            attachItem(Icons.insert_drive_file, "File"),
          ],
        ),
      ),
    );
  }

  Widget attachItem(IconData icon, String label) {
    return InkWell(
      onTap: () async {
        closeAttachMenu();

        if (label == "Gallery") pickGallery();
        if (label == "Camera") pickCamera();
        if (label == "Video") pickVideo();
        if (label == "File") pickFile();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [Icon(icon), const SizedBox(width: 10), Text(label)],
        ),
      ),
    );
  }

  Future<void> sendMediaMessage(
    String url,
    String type,
    String fileName,
  ) async {
    await db.push().set({
      "user": {
        "id": myUserId,
        "name": myName,
        "jenis": myJenis,
        "fcm": myToken,
        "avatar": myJenis == "TL"
            ? "https://i.pravatar.cc/150?img=12"
            : "https://i.pravatar.cc/150?img=3",
      },
      "message": url,
      "type": type, // image / video / file
      "filename": fileName,
      "time": ServerValue.timestamp,
      "deletedFor": {myUserId: false},
    });

    await pushToRoom(
      type == "image"
          ? "📷 Photo"
          : type == "video"
          ? "🎥 Video"
          : "📎 File",
    );

    await FirebaseDatabase.instance.ref("rooms/${widget.roomId}").update({
      "lastMessage": type == "image"
          ? "📷 Photo"
          : type == "video"
          ? "🎥 Video"
          : "📎 File",
      "lastTime": ServerValue.timestamp,
      "lastSender": myUserId,
    });
  }

  Future<File> compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      "${file.parent.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg",
      quality: 70,
      minWidth: 1080,
    );

    if (result == null) return file;

    return File(result.path);
  }

  Future<File?> compressVideo(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();

    if (controller.value.duration.inSeconds > 30) {
      controller.dispose();
      return null;
    }

    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );

    controller.dispose();
    return info?.file;
  }

  Future<Map<String, String>?> uploadMedia(File file) async {
    setState(() {
      isUploading = true;
      uploadProgress = 0;
    });

    final request = http.MultipartRequest(
      'POST',
      Uri.parse("${AppConfig.baseUrl}/api_flutter/upload_chat_media"),
    );

    final length = await file.length();
    int sent = 0;

    final stream = http.ByteStream(
      file.openRead().transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            sent += data.length;
            setState(() {
              uploadProgress = sent / length;
            });
            sink.add(data);
          },
        ),
      ),
    );

    request.files.add(
      http.MultipartFile(
        'file',
        stream,
        length,
        filename: path.basename(file.path),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    setState(() {
      isUploading = false;
      uploadProgress = 0;
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {"url": data['url'] as String, "type": data['type'] as String};
    } else {
      return null;
    }
  }

  Future<void> pickGallery() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;

    File file = await compressImage(File(img.path));
    final result = await uploadMedia(file);

    if (result != null) {
      await sendMediaMessage(
        result["url"]!,
        result["type"]!,
        path.basename(img.path),
      );
    }
  }

  Future<void> pickVideo() async {
    final vid = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (vid == null) return;

    final compressed = await compressVideo(File(vid.path));
    if (compressed == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Video maksimal 30 detik")));
      return;
    }

    final result = await uploadMedia(compressed);
    if (result != null) {
      await sendMediaMessage(
        result["url"]!,
        result["type"]!,
        path.basename(vid.path),
      );
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final file = File(result.files.single.path!);
    final upload = await uploadMedia(file);

    if (upload != null) {
      await sendMediaMessage(
        upload["url"]!,
        upload["type"]!,
        path.basename(file.path),
      );
    }
  }

  Future<void> pickCamera() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera);
    if (img == null) return;

    File file = await compressImage(File(img.path));
    final result = await uploadMedia(file);

    if (result != null) {
      await sendMediaMessage(
        result["url"]!,
        result["type"]!,
        path.basename(img.path),
      );
    }
  }

  Future<void> deleteForMe(String messageId) async {
    await db.child(messageId).child("deletedFor/$myUserId").set(true);
  }

  Future<void> deleteForEveryone(String messageId, String mediaUrl) async {
    await db.child(messageId).remove();

    if (mediaUrl.isNotEmpty) {
      await http.post(
        Uri.parse("${AppConfig.baseUrl}/api_flutter/delete_chat_media"),
        body: {"url": mediaUrl},
      );
    }
  }

  void showAttachMenu() {
    if (isAttachOpen) return;

    final overlay = Overlay.of(context);
    final renderBox = plusKey.currentContext!.findRenderObject() as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    double top = pos.dy - 170;
    if (top < 80) {
      top = pos.dy + size.height + 10;
    }

    attachOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: closeAttachMenu,
            child: Container(color: Colors.transparent),
          ),

          Positioned(left: pos.dx + 20, top: top, child: buildAttachPopup()),
        ],
      ),
    );

    overlay.insert(attachOverlay!);
    isAttachOpen = true;
  }

  void closeAttachMenu() {
    attachOverlay?.remove();
    attachOverlay = null;
    isAttachOpen = false;
  }

  void sendMessage() async {
    if (messageCtrl.text.trim().isEmpty) return;

    final text = messageCtrl.text.trim();
    await db.push().set({
      "user": {
        "id": myUserId,
        "name": myName,
        "jenis": myJenis,
        "fcm": myToken,
        "avatar": myJenis == "TL"
            ? "https://i.pravatar.cc/150?img=12"
            : "https://i.pravatar.cc/150?img=3",
      },

      "message": text,
      "type": "text",
      "time": ServerValue.timestamp,
      "deletedFor": {myUserId: false},
    });

    await pushToRoom(text);

    final roomRef = FirebaseDatabase.instance.ref("rooms/${widget.roomId}");
    await roomRef.update({
      "lastMessage": text,
      "lastTime": ServerValue.timestamp,
      "lastSender": myUserId,
    });

    await roomRef.child("unread/$myUserId").set(0);

    final usersSnap = await roomRef.child("members").get();

    if (usersSnap.exists) {
      final members = Map<String, dynamic>.from(usersSnap.value as Map);

      for (final uid in members.keys) {
        if (uid != myUserId) {
          roomRef.child("unread/$uid").runTransaction((value) {
            final current = (value as int?) ?? 0;
            return Transaction.success(current + 1);
          });
        }
      }
    }

    messageCtrl.clear();
  }

  String formatTime(dynamic time) {
    if (time == null) return "";
    final dt = DateTime.fromMillisecondsSinceEpoch(time);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<Map<String, String>> getRoomTokens() async {
    final snap = await db.limitToLast(100).get();
    if (!snap.exists) return {};

    final raw = Map<String, dynamic>.from(snap.value as Map);

    final Map<String, String> tokens = {};

    for (final e in raw.entries) {
      final msg = Map<String, dynamic>.from(e.value);
      final user = Map<String, dynamic>.from(msg["user"]);

      final uid = user["id"];
      final fcm = user["fcm"];

      if (uid != null && fcm != null) {
        tokens[uid] = fcm;
      }
    }

    return tokens;
  }

  Future<void> pushToRoom(String message) async {
    try {
      await http.post(
        Uri.parse("${AppConfig.baseUrl}/api_flutter/send_message"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_id": widget.roomId,
          "sender_id": myUserId,
          "sender_name": myName,
          "message": message,
          "url": "ventour://room_chat/${widget.userId}/${widget.jenis}",
        }),
      );
    } catch (e) {
      debugPrint("Notify backend failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (keyboardOpen && isAttachOpen) {
      Future.microtask(() => closeAttachMenu());
    }

    return WillPopScope(
      onWillPop: () async {
        if (isAttachOpen) {
          closeAttachMenu();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.roomName)),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: db.orderByChild("time").onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!.snapshot.value;
                  if (data == null) {
                    return const Center(child: Text("No messages"));
                  }

                  final raw = Map<String, dynamic>.from(data as Map);

                  final list = raw.entries.map((e) {
                    final msg = Map<String, dynamic>.from(e.value);
                    msg["_key"] = e.key;
                    return msg;
                  }).toList();

                  list.sort((a, b) {
                    final ta = a["time"] ?? 0;
                    final tb = b["time"] ?? 0;
                    return tb.compareTo(ta);
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final msg = Map<String, dynamic>.from(list[i]);
                      final user = Map<String, dynamic>.from(msg["user"]);

                      final bool isMe = user["id"] == myUserId;
                      final deletedFor = msg["deletedFor"] ?? {};
                      if (deletedFor[myUserId] == true) {
                        return const SizedBox();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: NetworkImage(user["avatar"]),
                              ),

                            const SizedBox(width: 6),

                            IntrinsicWidth(
                              child: GestureDetector(
                                onLongPress: () {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (_) {
                                      return SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              title: const Text(
                                                "Delete for me",
                                              ),
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await deleteForMe(msg["_key"]);
                                              },
                                            ),
                                            if (isMe)
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.delete_forever,
                                                  color: Colors.red,
                                                ),
                                                title: const Text(
                                                  "Delete for everyone",
                                                ),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  await deleteForEveryone(
                                                    msg["_key"],
                                                    msg["type"] != "text"
                                                        ? msg["message"]
                                                        : "",
                                                  );
                                                },
                                              ),
                                            ListTile(
                                              leading: const Icon(Icons.close),
                                              title: const Text("Cancel"),
                                              onTap: () =>
                                                  Navigator.pop(context),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFFDCF8C6)
                                        : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: isMe
                                          ? const Radius.circular(12)
                                          : const Radius.circular(0),
                                      bottomRight: isMe
                                          ? const Radius.circular(0)
                                          : const Radius.circular(12),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 3,
                                        offset: const Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isMe)
                                        Text(
                                          user["name"],
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      if (!isMe) const SizedBox(height: 4),
                                      if (msg["type"] == "text")
                                        Text(msg["message"])
                                      else if (msg["type"] == "image")
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                msg["message"],
                                                width: 200,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              right: 6,
                                              bottom: 6,
                                              child: InkWell(
                                                onTap: () =>
                                                    DownloadService.downloadFile(
                                                      msg["message"],
                                                      context,
                                                    ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.download,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (msg["type"] == "file")
                                        InkWell(
                                          onTap: () =>
                                              DownloadService.downloadFile(
                                                msg["message"],
                                                context,
                                              ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.insert_drive_file,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                msg["filename"] ??
                                                    "Download file",
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (msg["type"] == "video")
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => VideoPlayerPage(
                                                  url: msg["message"],
                                                ),
                                              ),
                                            );
                                          },
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: 220,
                                                height: 140,
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.play_circle_fill,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 6,
                                                bottom: 6,
                                                child: InkWell(
                                                  onTap: () =>
                                                      DownloadService.downloadFile(
                                                        msg["message"],
                                                        context,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black54,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.download,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          formatTime(msg["time"]),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isMe) const SizedBox(width: 6),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            if (isUploading) LinearProgressIndicator(value: uploadProgress),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: plusKey,
                      icon: const Icon(Icons.add),
                      onPressed: showAttachMenu,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: messageCtrl,
                          decoration: const InputDecoration(
                            hintText: "Type message...",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
