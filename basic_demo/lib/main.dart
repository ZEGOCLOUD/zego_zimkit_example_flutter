import 'package:flutter/material.dart';

import 'package:bot_toast/bot_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_zimkit/zego_zimkit.dart';

import 'avatar.dart';
import 'constants.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'notification.dart';
import 'utils.dart';

/// define a navigator key
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final cacheUserID = prefs.get(cacheUserIDKey) as String? ?? '';
  if (cacheUserID.isNotEmpty) {
    currentUser.id = cacheUserID;
    currentUser.name = randomName(key: cacheUserID);
  }

  /// init ZIMKit
  await ZIMKit().init(
    appID: yourAppID /*input your AppID*/,
    appSign: yourAppSign /*input your AppSign*/,
    notificationConfig: ZegoZIMKitNotificationConfig(
      resourceID: 'zego_data_zim',
      androidNotificationConfig: ZegoZIMKitAndroidNotificationConfig(
        channelID: 'ZIM Message',
        channelName: 'Message',
        sound: 'message',
        icon: 'message',
      ),
    ),
  );

  /// set navigator key to ZegoUIKitPrebuiltCallInvitationService
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
  ZegoUIKit().initLog().then((value) {
    /// style of offline call
    ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
      [ZegoUIKitSignalingPlugin()],
    );

    runApp(const ZIMKitDemo());
  });

  NotificationManager().init();
}

class ZIMKitDemo extends StatefulWidget {
  const ZIMKitDemo({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ZIMKitDemoState();
}

class ZIMKitDemoState extends State<ZIMKitDemo> {
  bool autoConnectSuccess = false;
  var autoConnectDoneNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    if (currentUser.id.isNotEmpty) {
      ZIMKit()
          .connectUser(
        id: currentUser.id,
        name: currentUser.name,
        avatarUrl: avatarURL(currentUser.id),
      )
          .then((errorCode) async {
        autoConnectSuccess = errorCode == 0;
        autoConnectDoneNotifier.value = true;

        if (errorCode == 0) {
          onUserLogin(currentUser.id, currentUser.name);
        }
      });
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final botToastBuilder = BotToastInit();
    return MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) {
        child = botToastBuilder(context, child);
        return child;
      },
      navigatorObservers: [BotToastNavigatorObserver()],
      debugShowCheckedModeBanner: false,
      title: 'ZIMKit Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: currentUser.id.isEmpty
          ? const ZIMKitDemoLoginPage()
          : autoConnecting(),
    );
  }

  Widget autoConnecting() {
    return ValueListenableBuilder<bool>(
      valueListenable: autoConnectDoneNotifier,
      builder: (context, connectDone, _) {
        if (connectDone) {
          return autoConnectSuccess
              ? const ZIMKitDemoHomePage()
              : const ZIMKitDemoLoginPage();
        }

        /// waiting for the result of auto connect
        return const Stack(
          children: [
            /// only just show,forbid to interact
            AbsorbPointer(absorbing: true, child: ZIMKitDemoLoginPage()),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// on App's user login
void onUserLogin(String id, String name) {
  final sendCallingInvitationButton = StreamBuilder(
    stream: ZegoUIKit().getUserListStream(),
    builder: (context, snapshot) {
      return ValueListenableBuilder(
          valueListenable:

              /// '#' is removed when send call invitation
              ZIMKit().queryGroupMemberList('#${ZegoUIKit().getRoom().id}'),
          builder: (context, List<ZIMGroupMemberInfo> members, _) {
            final memberIDsInCall =
                ZegoUIKit().getRemoteUsers().map((user) => user.id).toList();
            final membersNotInCall = members.where((member) {
              if (member.userID == ZIMKit().currentUser()!.baseInfo.userID) {
                return false;
              }

              return !memberIDsInCall.contains(member.userID);
            }).toList();
            return ZegoSendCallingInvitationButton(
              avatarBuilder: customAvatarBuilder,
              selectedUsers: ZegoUIKit()
                  .getRemoteUsers()
                  .map((e) => ZegoCallUser(
                        e.id,
                        e.name,
                      ))
                  .toList(),
              waitingSelectUsers: membersNotInCall
                  .map((member) => ZegoCallUser(
                        member.userID,
                        member.userName,
                      ))
                  .toList(),
            );
          });
    },
  );

  /// initialized ZegoUIKitPrebuiltCallInvitationService
  /// when app's user is logged in or re-logged in
  /// We recommend calling this method as soon as the user logs in to your app.
  ZegoUIKitPrebuiltCallInvitationService().init(
    appID: yourAppID /*input your AppID*/,
    appSign: yourAppSign /*input your AppSign*/,
    userID: id,
    userName: name,
    plugins: [ZegoUIKitSignalingPlugin()],
    config: ZegoCallInvitationConfig(
      inCalling: ZegoCallInvitationInCallingConfig(
        canInvitingInCalling: true,
      ),
    ),
    notificationConfig: ZegoCallInvitationNotificationConfig(
      androidNotificationConfig: ZegoCallAndroidNotificationConfig(
        callChannel: ZegoCallAndroidNotificationChannelConfig(
          channelID: 'ZegoUIKit',
          channelName: 'Call Notifications',
          sound: 'call',
          icon: 'call',
        ),
        messageChannel: ZegoCallAndroidNotificationChannelConfig(
          channelID: 'Message',
          channelName: 'Message',
          sound: 'message',
          icon: 'message',
        ),
      ),
    ),
    requireConfig: (ZegoCallInvitationData data) {
      final config = ZegoCallInvitationType.videoCall == data.type
          ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
          : ZegoUIKitPrebuiltCallConfig.groupVoiceCall();

      config.audioVideoView.useVideoViewAspectFill = true;
      config.topMenuBar.extendButtons = [
        sendCallingInvitationButton,
      ];

      config.avatarBuilder = customAvatarBuilder;

      return config;
    },
  );
}

/// on App's user logout
void onUserLogout() {
  /// de-initialization ZegoUIKitPrebuiltCallInvitationService
  /// when app's user is logged out
  ZegoUIKitPrebuiltCallInvitationService().uninit();
}
