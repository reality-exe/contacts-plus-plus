import 'package:cached_network_image/cached_network_image.dart';
import 'package:contacts_plus_plus/client_holder.dart';
import 'package:contacts_plus_plus/auxiliary.dart';
import 'package:contacts_plus_plus/clients/messaging_client.dart';
import 'package:contacts_plus_plus/models/friend.dart';
import 'package:contacts_plus_plus/models/message.dart';
import 'package:contacts_plus_plus/models/session.dart';
import 'package:contacts_plus_plus/widgets/message_audio_player.dart';
import 'package:contacts_plus_plus/widgets/generic_avatar.dart';
import 'package:contacts_plus_plus/widgets/message_session_invite.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MessagesList extends StatefulWidget {
  const MessagesList({required this.friend, super.key});

  final Friend friend;

  @override
  State<StatefulWidget> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  final TextEditingController _messageTextController = TextEditingController();
  final ScrollController _sessionListScrollController = ScrollController();
  final ScrollController _messageScrollController = ScrollController();

  bool _isSendable = false;
  bool _showSessionListScrollChevron = false;

  double get _shevronOpacity => _showSessionListScrollChevron ? 1.0 : 0.0;


  @override
  void dispose() {
    _messageTextController.dispose();
    _sessionListScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sessionListScrollController.addListener(() {
      if (_sessionListScrollController.position.maxScrollExtent > 0 && !_showSessionListScrollChevron) {
        setState(() {
          _showSessionListScrollChevron = true;
        });
      }
      if (_sessionListScrollController.position.atEdge && _sessionListScrollController.position.pixels > 0
          && _showSessionListScrollChevron) {
        setState(() {
          _showSessionListScrollChevron = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = ClientHolder
        .of(context)
        .apiClient;
    var sessions = widget.friend.userStatus.activeSessions;
    final appBarColor = Theme
        .of(context)
        .colorScheme
        .surfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friend.username),
        scrolledUnderElevation: 0.0,
        backgroundColor: appBarColor,
      ),
      body: Column(
        children: [
          if (sessions.isNotEmpty) Container(
            constraints: const BoxConstraints(maxHeight: 64),
            decoration: BoxDecoration(
                color: appBarColor,
                border: const Border(top: BorderSide(width: 1, color: Colors.black26),)
            ),
            child: Stack(
              children: [
                ListView.builder(
                  controller: _sessionListScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) => SessionTile(session: sessions[index]),
                ),
                AnimatedOpacity(
                  opacity: _shevronOpacity,
                  curve: Curves.easeOut,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.only(left: 16, right: 4, top: 1, bottom: 1),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            appBarColor.withOpacity(0),
                            appBarColor,
                            appBarColor,
                          ],
                        ),
                      ),
                      height: double.infinity,
                      child: const Icon(Icons.chevron_right),
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Consumer<MessagingClient>(
              builder: (context, mClient, _) {
                final cache = mClient.getUserMessageCache(widget.friend.id);
                if (cache == null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      LinearProgressIndicator()
                    ],
                  );
                }
                if (cache.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.message_outlined),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            "There are no messages here\nWhy not say hello?",
                            textAlign: TextAlign.center,
                            style: Theme
                                .of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        )
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _messageScrollController,
                  reverse: true,
                  itemCount: cache.messages.length,
                  itemBuilder: (context, index) {
                    final entry = cache.messages[index];
                    final widget = entry.senderId == apiClient.userId
                        ? MyMessageBubble(message: entry)
                        : OtherMessageBubble(message: entry);
                    if (index == cache.messages.length - 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: widget,
                      );
                    }
                    return widget;
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: MediaQuery
            .of(context)
            .viewInsets,
        child: BottomAppBar(
          elevation: 0.0,
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 6),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    autocorrect: true,
                    controller: _messageTextController,
                    maxLines: 4,
                    minLines: 1,
                    onChanged: (text) {
                      if (text.isNotEmpty && !_isSendable) {
                        setState(() {
                          _isSendable = true;
                        });
                      } else if (text.isEmpty && _isSendable) {
                        setState(() {
                          _isSendable = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                        isDense: true,
                        hintText: "Send a message to ${widget.friend
                            .username}...",
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)
                        )
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4.0),
                child: Consumer<MessagingClient>(
                  builder: (context, mClient, _) {
                    return IconButton(
                      splashRadius: 24,
                      onPressed: _isSendable ? () async {
                        setState(() {
                          _isSendable = false;
                        });
                        final message = Message(
                          id: Message.generateId(),
                          recipientId: widget.friend.id,
                          senderId: apiClient.userId,
                          type: MessageType.text,
                          content: _messageTextController.text,
                          sendTime: DateTime.now().toUtc(),
                        );
                        try {
                          mClient.sendMessage(message);
                          _messageTextController.clear();
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to send message\n$e",
                                maxLines: null,
                              ),
                            ),
                          );
                          setState(() {
                            _isSendable = true;
                          });
                        }
                      } : null,
                      iconSize: 28,
                      icon: const Icon(Icons.send),
                    );
                  }
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class MyMessageBubble extends StatelessWidget {
  MyMessageBubble({required this.message, super.key});

  final Message message;
  final DateFormat _dateFormat = DateFormat.Hm();

  @override
  Widget build(BuildContext context) {
    var content = message.content;
    switch (message.type) {
      case MessageType.sessionInvite:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme
                  .of(context)
                  .colorScheme
                  .primaryContainer,
              margin: const EdgeInsets.only(left: 32, bottom: 16, right: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: MessageSessionInvite(message: message,),
              ),
            ),
          ],
        );
      case MessageType.object:
        content = "[Asset]";
        continue rawText;
      case MessageType.unknown:
      rawText:
      case MessageType.text:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme
                    .of(context)
                    .colorScheme
                    .primaryContainer,
                margin: const EdgeInsets.only(left: 32, bottom: 16, right: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        content,
                        softWrap: true,
                        maxLines: null,
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyLarge,
                      ),
                      const SizedBox(height: 6,),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              _dateFormat.format(message.sendTime),
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: Colors.white54),
                            ),
                          ),
                          MessageStateIndicator(messageState: message.state),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case MessageType.sound:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme
                  .of(context)
                  .colorScheme
                  .primaryContainer,
              margin: const EdgeInsets.only(left: 32, bottom: 16, right: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: MessageAudioPlayer(message: message,),
              ),
            ),
          ],
        );
    }
  }
}


class OtherMessageBubble extends StatelessWidget {
  OtherMessageBubble({required this.message, super.key});

  final Message message;
  final DateFormat _dateFormat = DateFormat.Hm();

  @override
  Widget build(BuildContext context) {
    var content = message.content;
    switch (message.type) {
      case MessageType.sessionInvite:
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Theme
                .of(context)
                .colorScheme
                .secondaryContainer,
            margin: const EdgeInsets.only(right: 32, bottom: 16, left: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: MessageSessionInvite(message: message,),
            ),
          ),
          ],
        );
      case MessageType.object:
        content = "[Asset]";
        continue rawText;
      case MessageType.unknown:
      rawText:
      case MessageType.text:
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme
                    .of(context)
                    .colorScheme
                    .secondaryContainer,
                margin: const EdgeInsets.only(right: 32, bottom: 16, left: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        softWrap: true,
                        maxLines: null,
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyLarge,
                      ),
                      const SizedBox(height: 6,),
                      Text(
                        _dateFormat.format(message.sendTime),
                        style: Theme
                            .of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case MessageType.sound:
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Theme
                .of(context)
                .colorScheme
                .secondaryContainer,
            margin: const EdgeInsets.only(right: 32, bottom: 16, left: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: MessageAudioPlayer(message: message,),
            ),
          ),
          ],
        );
    }
  }
}

class MessageStateIndicator extends StatelessWidget {
  const MessageStateIndicator({required this.messageState, super.key});

  final MessageState messageState;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    switch (messageState) {
      case MessageState.local:
        icon = Icons.alarm;
        break;
      case MessageState.sent:
        icon = Icons.done;
        break;
      case MessageState.read:
        icon = Icons.done_all;
        break;
    }
    return Icon(
      icon,
      size: 12,
    );
  }
}

class SessionPopup extends StatelessWidget {
  const SessionPopup({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final ScrollController userListScrollController = ScrollController();
    final thumbnailUri = Aux.neosDbToHttp(session.thumbnail);
    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Text(session.name, style: Theme.of(context).textTheme.titleMedium),
                        Text(session.description.isEmpty ? "No description." : session.description, style: Theme.of(context).textTheme.labelMedium),
                        Text("Tags: ${session.tags.isEmpty ? "None" : session.tags.join(", ")}",
                          style: Theme.of(context).textTheme.labelMedium,
                          softWrap: true,
                        ),
                        Text("Access: ${session.accessLevel.toReadableString()}"),
                        Text("Users: ${session.sessionUsers.length}", style: Theme.of(context).textTheme.labelMedium),
                        Text("Maximum users: ${session.maxUsers}", style: Theme.of(context).textTheme.labelMedium),
                        Text("Headless: ${session.headlessHost ? "Yes" : "No"}", style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                  if (session.sessionUsers.isNotEmpty) Expanded(
                    child: Scrollbar(
                      trackVisibility: true,
                      controller: userListScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: userListScrollController,
                        shrinkWrap: true,
                        itemCount: session.sessionUsers.length,
                        itemBuilder: (context, index) {
                          final user = session.sessionUsers[index];
                          return ListTile(
                            dense: true,
                            title: Text(user.username, textAlign: TextAlign.end,),
                            subtitle: Text(user.isPresent ? "Active" : "Inactive", textAlign: TextAlign.end,),
                          );
                        },
                      ),
                    ),
                  ) else Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.person_remove_alt_1_rounded),
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text("No one is currently playing.", textAlign: TextAlign.center,),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child:  CachedNetworkImage(
                  imageUrl: thumbnailUri,
                  placeholder: (context, url) {
                    return const CircularProgressIndicator();
                  },
                  errorWidget: (context, error, what) => Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.no_photography),
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("Failed to load Image"),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

}

class SessionTile extends StatelessWidget {
  const SessionTile({required this.session, super.key});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        showDialog(context: context, builder: (context) => SessionPopup(session: session));
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GenericAvatar(imageUri: Aux.neosDbToHttp(session.thumbnail), placeholderIcon: Icons.no_photography),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.name),
                Text("${session.sessionUsers.length}/${session.maxUsers} active users")
              ],
            ),
          )
        ],
      ),
    );
  }
}