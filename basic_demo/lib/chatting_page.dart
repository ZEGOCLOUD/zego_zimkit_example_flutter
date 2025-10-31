import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_zimkit/zego_zimkit.dart';
import 'package:zego_uikit/zego_uikit.dart';

import 'demo_widgets/demo_widgets.dart';
import 'notification.dart';

class DemoChattingMessageListPage extends StatefulWidget {
  const DemoChattingMessageListPage({
    Key? key,
    required this.conversationID,
    required this.conversationType,
  }) : super(key: key);

  final String conversationID;
  final ZIMConversationType conversationType;

  @override
  State<DemoChattingMessageListPage> createState() =>
      _DemoChattingMessageListPageState();
}

class _DemoChattingMessageListPageState
    extends State<DemoChattingMessageListPage> {
  List<StreamSubscription> subscriptions = [];

  // In the initState method, subscribe the event.
  @override
  void initState() {
    subscriptions = [
      if (widget.conversationType == ZIMConversationType.group)
        ZIMKit().getGroupStateChangedEventStream().listen(
              onGroupStateChangedEvent,
            ),
    ];
    // When on the chat page, the notification for that chat page is not displayed.
    NotificationManager().ignoreConversationID = widget.conversationID;
    super.initState();
  }

  // When the widget is disposed, please remember to cancel subscribe.
  @override
  void dispose() {
    for (final element in subscriptions) {
      element.cancel();
    }
    // After exiting the chat page, if the conversation continues to receive messages, the notification of the chat page needs to be displayed.
    NotificationManager().ignoreConversationID = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZIMKitMessageListMultiModeData>(
        valueListenable: ZIMKitMessageListMultiSelectProcessor().modeNotifier,
        builder: (context, multiModeData, _) {
          return Scaffold(
            appBar: multiModeData.isMultiMode
                ? AppBar(
                    leading: TextButton(
                      onPressed: () {
                        ZIMKitMessageListMultiSelectProcessor()
                            .cancelMultiSelect();
                      },
                      child: const Text(
                        '取消',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    title: Text(
                        '已选择${ZIMKitMessageListMultiSelectProcessor().selectedMessages.length}条'),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0.5,
                  )
                : null,
            body: Stack(
              children: [
                ZIMKitMessageListPage(
                  conversationID: widget.conversationID,
                  conversationType: widget.conversationType,
                  config: ZIMKitMessageListPageConfig(
                    messageInputActions: [
                      ZIMKitMessageInputAction.more(
                        demoSendRedEnvelopeButton(
                          widget.conversationID,
                          widget.conversationType,
                        ),
                      ),
                    ],
                  ),
                  style: ZIMKitMessageListPageStyle(
                    appBarActions: [
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ZIMKitSingleChatDetailPage(
                                conversationID: widget.conversationID,
                                conversationType: widget.conversationType,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    messageContentBuilder: (context, message, defaultWidget) {
                      if (message.type == ZIMMessageType.custom &&
                          message.customContent!.type ==
                              DemoCustomMessageType.redEnvelope.index) {
                        return RedEnvelopeMessage(message: message);
                      } else {
                        return defaultWidget;
                      }
                    },
                  ),
                  callbacks: ZIMKitMessageListPageCallbacks(
                    onCallTap: _showCallOptions,
                    onMessageSent: (ZIMKitMessage message) {
                      if (message.info.error != null) {
                        debugPrint(
                          'onMessageSent error: ${message.info.error!.message}, ${message.info.error!.code}',
                        );
                        BotToast.showText(
                          text: 'message send failed:'
                              '${message.info.error!.message}, '
                              'code:${message.info.error!.code}',
                          contentColor: Colors.red,
                          textStyle: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        );
                      } else {
                        debugPrint('onMessageSent: ${message.type.name}');
                      }
                    },
                  ),
                  // messageInputHeight is now managed automatically by the SDK
                  events: ZIMKitMessageListPageEvents(
                    audioRecord: ZIMKitAudioRecordEvents(
                      onFailed: (int errorCode) {
                        /// audio message's error list:  https://doc-preview-zh.zego.im/article/20148
                        debugPrint('onRecordFailed: $errorCode');
                        var errorMessage = 'record failed:$errorCode';
                        switch (errorCode) {
                          case 32:
                            errorMessage = 'recording time is too short';
                            break;
                        }
                        BotToast.showText(
                          text: errorMessage,
                          contentColor: Colors.red,
                          textStyle: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        );
                      },
                      onCountdownTick: (int remainingSecond) {
                        debugPrint('onCountdownTick: $remainingSecond');
                        if (remainingSecond > 5 || remainingSecond <= 0) {
                          return;
                        }

                        BotToast.showText(
                          text: 'time remaining: $remainingSecond seconds',
                          contentColor: Colors.black.withOpacity(0.3),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                          duration: const Duration(milliseconds: 800),
                        );
                      },
                    ),
                  ),
                  // Pass replied message to input (if ZIMKitMessageListPage supports it in future)
                  // For now, the SDK's message_input already handles repliedMessage internally
                ),
                if (multiModeData.isMultiMode)
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ZIMKitMultiSelectToolbarWidget(),
                  ),
              ],
            ),
          );
        });
  }

  Future<void> onGroupStateChangedEvent(
    ZIMKitEventGroupStateChanged event,
  ) async {
    debugPrint('getGroupStateChangedEventStream: $event');
    // If you need to automatically exit the page and delete a group
    // conversation that is already in the 'quit' state,
    // you can use this code here.

    // if ((event.groupInfo.baseInfo.id == widget.conversationID) && (event.state == ZIMGroupState.quit)) {
    //   debugPrint('app deleteConversation: $event');
    //   await ZIMKit().deleteConversation(widget.conversationID, widget.conversationType);
    //   if (mounted) {
    //     Navigator.pop(context);
    //   }
    // }
  }

  void _showCallOptions() {
    // Get the call buttons using the original logic
    final callButtons = _peerChatCallButtons(
      context,
      widget.conversationID,
      widget.conversationType,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Audio Call
                _buildCallOption(
                  icon: Icons.phone,
                  label: 'Audio Call',
                  onTap: () {
                    Navigator.pop(context);
                    // Trigger the audio call button (isVideoCall: false)
                    if (callButtons.length > 1) {
                      // callButtons[1] is audio call (isVideoCall: false)
                      // We need to programmatically trigger it
                      // For now, show the call UI manually
                      _makeCall(isVideoCall: false);
                    }
                  },
                ),
                const Divider(height: 1),
                // Video Call
                _buildCallOption(
                  icon: Icons.videocam,
                  label: 'Video Call',
                  onTap: () {
                    Navigator.pop(context);
                    // Trigger the video call button (isVideoCall: true)
                    if (callButtons.isNotEmpty) {
                      // callButtons[0] is video call (isVideoCall: true)
                      _makeCall(isVideoCall: true);
                    }
                  },
                ),
                const Divider(height: 8, color: Color(0xFFF5F5F5)),
                _buildCallOption(
                  label: 'Cancel',
                  onTap: () {
                    Navigator.pop(context);
                  },
                  textColor: Colors.black54,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _peerChatCallButtons(
    BuildContext context,
    String conversationID,
    ZIMConversationType type,
  ) {
    return [
      for (final isVideoCall in [true, false])
        ZegoSendCallInvitationButton(
          iconSize: const Size(40, 40),
          buttonSize: const Size(50, 50),
          isVideoCall: isVideoCall,
          resourceID: 'zego_data',
          invitees: [
            ZegoUIKitUser(
              id: conversationID,
              name: ZIMKit().getConversation(conversationID, type).value.name,
            )
          ],
          onPressed: (String code, String message, List<String> errorInvitees) {
            var log = '';
            if (errorInvitees.isNotEmpty) {
              log = "User doesn't exist or is offline: ${errorInvitees[0]}";
              if (code.isNotEmpty) {
                log += ', code: $code, message:$message';
              }
            } else if (code.isNotEmpty) {
              log = 'code: $code, message:$message';
            }
            if (log.isEmpty) {
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(log)),
            );
          },
        )
    ];
  }

  void _makeCall({required bool isVideoCall}) {
    // Use the original call logic from peerChatCallButtons
    ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: [
        ZegoCallUser(
          widget.conversationID,
          ZIMKit()
              .getConversation(widget.conversationID, widget.conversationType)
              .value
              .name,
        ),
      ],
      isVideoCall: isVideoCall,
      resourceID: 'zego_data',
    );
  }

  Widget _buildCallOption({
    IconData? icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24, color: Colors.black87),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: textColor ?? Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
