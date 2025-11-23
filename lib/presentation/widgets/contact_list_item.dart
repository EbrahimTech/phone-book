import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/contact.dart';

class ContactListItem extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContactListItem({
    super.key,
    required this.contact,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(contact.id),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        color: Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: contact.photoUrl != null && contact.photoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(contact.photoUrl!)
                : null,
            backgroundColor: Colors.blue,
            child: contact.photoUrl == null || contact.photoUrl!.isEmpty
                ? Text(
                    contact.firstLetter,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          title: Text(
            contact.fullName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3D3D3D),
            ),
          ),
          subtitle: Text(
            contact.phoneNumber,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6D6D6D),
            ),
          ),
          trailing: contact.isInDeviceContacts
              ? const Icon(
                  Icons.phone_android,
                  color: Colors.green,
                  size: 20,
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

