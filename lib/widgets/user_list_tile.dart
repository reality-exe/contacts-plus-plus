import 'package:contacts_plus_plus/auxiliary.dart';
import 'package:contacts_plus_plus/models/user.dart';
import 'package:contacts_plus_plus/widgets/generic_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserListTile extends StatefulWidget {
  const UserListTile({required this.user, required this.isFriend, super.key});

  final User user;
  final bool isFriend;

  @override
  State<UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends State<UserListTile> {
  final DateFormat _regDateFormat = DateFormat.yMMMMd('en_US');
  late bool _localAdded = widget.isFriend;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GenericAvatar(imageUri: Aux.neosDbToHttp(widget.user.userProfile?.iconUrl),),
      title: Text(widget.user.username),
      subtitle: Text(_regDateFormat.format(widget.user.registrationDate)),
      trailing: IconButton(
        onPressed: () {
          setState(() {
            _localAdded = !_localAdded;
          });
        },
        splashRadius: 24,
        icon: _localAdded ? const Icon(Icons.person_remove_alt_1) : const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}