import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zego_zimkit/zego_zimkit.dart';

import 'chatting_page.dart';
import 'home_page_actions.dart';
import 'profile_page.dart';

class ZIMKitDemoHomePage extends StatefulWidget {
  const ZIMKitDemoHomePage({Key? key}) : super(key: key);

  @override
  State<ZIMKitDemoHomePage> createState() => _ZIMKitDemoHomePageState();
}

class _ZIMKitDemoHomePageState extends State<ZIMKitDemoHomePage> {
  var currentPageIndex = ValueNotifier<int>(0);
  late final pages = [
    conversationList(),
    const ProfilePage(),
  ];
  List<StreamSubscription> sbuscriptions = [];

  @override
  void initState() {
    ZIMKit().getGroupStateChangedEventStream().listen(onGroupStateChangedEvent);
    super.initState();
  }

  @override
  void dispose() {
    for (final element in sbuscriptions) {
      element.cancel();
    }
    super.dispose();
  }

  Widget conversationList() {
    return ZIMKitConversationListView(
      filter: (context, conversationList) {
        // 过滤掉 lastMessage 为 null 的空会话
        return conversationList.where((conversation) => conversation.value.lastMessage != null).toList();
      },
      onPressed: (context, conversation, defaultAction) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) {
            return DemoChattingMessageListPage(
              conversationID: conversation.id,
              conversationType: conversation.type,
            );
          },
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Conversations'),
          actions: const [HomePagePopupMenuButton()],
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: currentPageIndex,
          builder: (context, pageIndex, _) {
            return IndexedStack(index: pageIndex, children: pages);
          },
        ),
        bottomNavigationBar: ValueListenableBuilder(
            valueListenable: currentPageIndex,
            builder: (context, pageIndex, _) {
              return NavigationBar(
                selectedIndex: currentPageIndex.value,
                destinations: [
                  ValueListenableBuilder<int>(
                      valueListenable: ZIMKit().getTotalUnreadMessageCount(),
                      builder: (context, unreadMessageCount, _) {
                        return NavigationDestination(
                          icon: Badge.count(
                            count: unreadMessageCount,
                            backgroundColor: Colors.red,
                            isLabelVisible: unreadMessageCount > 0,
                            child: const Icon(Icons.home_outlined),
                          ),
                          selectedIcon: Badge.count(
                            count: unreadMessageCount,
                            backgroundColor: Colors.red,
                            isLabelVisible: unreadMessageCount > 0,
                            child: const Icon(Icons.home),
                          ),
                          label: 'Chats',
                        );
                      }),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Me',
                  ),
                ],
                onDestinationSelected: (index) =>
                    currentPageIndex.value = index,
              );
            }),
      ),
    );
  }

  Future<void> onGroupStateChangedEvent(
      ZIMKitEventGroupStateChanged event) async {
    debugPrint('getGroupStateChangedEventStream: $event');
    // If you need to automatically delete a group conversation that is already in the 'quit' state,
    // you can use this code here.

    // if (event.state == ZIMGroupState.quit) {
    //   debugPrint('app deleteConversation: $event');
    //   ZIMKit().deleteConversation(event.groupInfo.baseInfo.id, ZIMConversationType.group);
    // }
  }
}
