import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';

import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_zimkit/zego_zimkit.dart';

import 'avatar.dart';
import 'demo_widgets/default_dialogs.dart';
import 'main.dart';

List<Widget>? demoAppBarActions(
  BuildContext context,
  String conversationID,
  ZIMConversationType type,
) {
  return type == ZIMConversationType.peer
      ? peerChatCallButtons(context, conversationID, type)
      : [
          GroupPageCallButton(groupID: conversationID),
          GroupPagePopupMenuButton(groupID: conversationID),
        ];
}

List<Widget> peerChatCallButtons(
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

class GroupPageCallButton extends StatefulWidget {
  const GroupPageCallButton({Key? key, required this.groupID})
      : super(key: key);

  final String groupID;

  @override
  State<GroupPageCallButton> createState() => _GroupPageCallButtonState();
}

class _GroupPageCallButtonState extends State<GroupPageCallButton> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ZIMKit().queryGroupMemberList(widget.groupID),
      builder: (context, List<ZIMGroupMemberInfo> members, _) {
        return IconButton(
          onPressed: () {
            showCallingInvitationListSheet(
              context,
              avatarBuilder: customAvatarBuilder,
              waitingSelectUsers: members
                  .where((member) =>
                      member.userID != ZIMKit().currentUser()!.baseInfo.userID)
                  .toList()
                  .map((member) => ZegoCallUser(
                        member.userID,
                        member.userName,
                      ))
                  .toList(),
              onPressed: (checkUsers) {
                ZegoUIKitPrebuiltCallInvitationService().send(
                  invitees: checkUsers,
                  isVideoCall: true,

                  /// '#' is not a valid char
                  callID: widget.groupID.replaceAll('#', ''),
                  resourceID: 'zego_data',
                );
              },
            );
          },
          icon: const Icon(
            Icons.call,
            color: Colors.green,
          ),
        );
      },
    );
  }
}

class GroupPagePopupMenuButton extends StatefulWidget {
  const GroupPagePopupMenuButton({Key? key, required this.groupID})
      : super(key: key);

  final String groupID;

  @override
  State<GroupPagePopupMenuButton> createState() =>
      _GroupPagePopupMenuButtonState();
}

class _GroupPagePopupMenuButtonState extends State<GroupPagePopupMenuButton> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ZIMKit().queryGroupOwner(widget.groupID),
      builder: (context, ZIMGroupMemberInfo? owner, _) {
        final imGroupOwner =
            owner?.userID == ZIMKit().currentUser()?.baseInfo.userID;
        return PopupMenuButton(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
          position: PopupMenuPosition.under,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: 'Add Member',
                child: const ListTile(
                    leading: Icon(Icons.group_add),
                    title: Text('Add User', maxLines: 1)),
                onTap: () => showDefaultAddUserToGroupDialog(
                  context,
                  widget.groupID,
                ),
              ),
              if (imGroupOwner)
                PopupMenuItem(
                  value: 'Remove Member',
                  child: const ListTile(
                      leading: Icon(Icons.group_remove),
                      title: Text('Remove User', maxLines: 1)),
                  onTap: () => showDefaultRemoveUserFromGroupDialog(
                    context,
                    widget.groupID,
                  ),
                ),
              PopupMenuItem(
                value: 'Member List',
                child: const ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Member List', maxLines: 1)),
                onTap: () => showDefaultGroupMemberListDialog(
                  context,
                  widget.groupID,
                ),
              ),
              PopupMenuItem(
                value: 'Leave Group',
                onTap: leaveGroup,
                child: const ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Leave Group', maxLines: 1)),
              ),
              if (imGroupOwner)
                PopupMenuItem(
                  value: 'Disband Group',
                  onTap: dispandGroup,
                  child: const ListTile(
                    leading: Icon(Icons.close),
                    title: Text('Disband Group', maxLines: 1),
                  ),
                ),
            ];
          },
        );
      },
    );
  }

  void leaveGroup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: const Text('Do you want to leave this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ZIMKit().leaveGroup(widget.groupID);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void dispandGroup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: const Text('Do you want to disband this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ZIMKit().disbandGroup(widget.groupID);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
