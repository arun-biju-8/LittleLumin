import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserDirectory extends StatefulWidget {
  const AdminUserDirectory({super.key});

  @override
  State<AdminUserDirectory> createState() => _AdminUserDirectoryState();
}

class _AdminUserDirectoryState extends State<AdminUserDirectory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Directory'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Users', icon: Icon(Icons.people, size: 18)),
            Tab(text: 'Parents', icon: Icon(Icons.family_restroom, size: 18)),
            Tab(text: 'LLG', icon: Icon(Icons.verified_user, size: 18)),
            Tab(text: 'Pending', icon: Icon(Icons.pending, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(null),
          _buildUserList('parent'),
          _buildUserList('llg'),
          _buildUserList('llg_pending'),
        ],
      ),
    );
  }

  Widget _buildUserList(String? userType) {
    Query query = FirebaseFirestore.instance.collection('users');
    if (userType != null) {
      query = query.where('userType', isEqualTo: userType);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('No users found');
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            return _buildUserCard(users[index].id, data);
          },
        );
      },
    );
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> data) {
    final userType = data['userType'] ?? 'parent';

    Color typeColor;
    IconData typeIcon;

    switch (userType) {
      case 'llg':
        typeColor = Colors.green;
        typeIcon = Icons.verified_user;
        break;
      case 'llg_pending':
        typeColor = Colors.orange;
        typeIcon = Icons.pending;
        break;
      case 'admin':
        typeColor = Colors.red;
        typeIcon = Icons.admin_panel_settings;
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.family_restroom;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.2),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['email'] ?? 'No email'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    userType.toString().toUpperCase(),
                    style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                  Text(data['phone'].toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showUserDetails(uid, data),
      ),
    );
  }

  void _showUserDetails(String uid, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _detailRow(Icons.email, 'Email', data['email'] ?? 'N/A'),
            _detailRow(Icons.phone, 'Phone', data['phone'] ?? 'N/A'),
            _detailRow(Icons.badge, 'User Type', data['userType'] ?? 'N/A'),
            _detailRow(Icons.info, 'Status', data['status'] ?? 'N/A'),
            _detailRow(Icons.calendar_today, 'Joined', _formatDate(data['createdAt'])),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }
}
