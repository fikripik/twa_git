import '../config/package_config.dart';

class AudioRoomPage extends StatefulWidget {
  final String roomID;
  final bool isHost;
  final String userName;
  final String jenis; // JAMAAH / TL
  final String userId;

  const AudioRoomPage({
    super.key,
    required this.roomID,
    required this.isHost,
    required this.jenis,
    required this.userName,
    required this.userId,
  });

  @override
  State<AudioRoomPage> createState() => _AudioRoomPageState();
}

class _AudioRoomPageState extends State<AudioRoomPage> {
  bool get isHorizontal => false;

  List<ZegoLiveAudioRoomLayoutRowConfig> getResponsiveRowConfigs(
    BuildContext context, {
    bool isHorizontal = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    const seatSize = 120.0; // Adjust based on your seat widget size
    final maxSeatsPerRow = (screenWidth / seatSize).floor();

    if (isHorizontal) {
      // All seats in one row, responsive to screen width
      return [
        ZegoLiveAudioRoomLayoutRowConfig(
          count: maxSeatsPerRow,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly,
        ),
      ];
    } else {
      // Default vertical layout (as before)
      return [
        ZegoLiveAudioRoomLayoutRowConfig(
          count: 1,
          alignment: ZegoLiveAudioRoomLayoutAlignment.center,
        ),
        ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceAround,
        ),
        ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceAround,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: ZegoUIKitPrebuiltLiveAudioRoom(
        appID: AppConfig.zegoAppId,
        appSign: AppConfig.zegoAppSign,
        userID: widget.userId,
        userName: widget.userName,
        roomID: widget.roomID,
        config:
            (widget.isHost
                    ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
                    : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience()
                ..bottomMenuBar = ZegoLiveAudioRoomBottomMenuBarConfig(
                  hostButtons: [
                    // Syle button untuk host
                    ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton,
                    ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
                    ZegoLiveAudioRoomMenuBarButtonName.closeSeatButton,
                  ],

                  audienceButtons: [
                    // Style button untuk jamaah biasa
                    ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
                  ],

                  speakerButtons: [
                    // Style button untuk jamaah/role lain yang dapat seat
                    ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
                    ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton,
                  ],
                ))
              ..seat.hostIndexes = [0]
              ..seat.layout.rowConfigs = getResponsiveRowConfigs(
                context,
                isHorizontal: isHorizontal,
              )
              ..background = background()
              ..signalingPlugin
              ..userAvatarUrl = 'https://robohash.org/${widget.userId}.png/',
      ),
    );
  }

  Widget background() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xD2F5F5F5),
            image: DecorationImage(
              fit: BoxFit.contain,
              image: Image.asset(
                'assets/images/audio_room_background.png',
              ).image,
            ),
          ),
        ),
        const Positioned(
          top: 10,
          left: 10,
          child: Text(
            'Ventour Audio Room',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xff1B1B1B),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Positioned(
          top: 10 + 20,
          left: 10,
          child: Text(
            'ID: ${widget.roomID}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff606060),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
