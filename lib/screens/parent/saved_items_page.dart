import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/saved_items_service.dart';

class SavedItemsPage extends StatefulWidget {
  const SavedItemsPage({super.key});

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

class _SavedItemsPageState extends State<SavedItemsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SavedItemsService _service = SavedItemsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('My Library'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Activities'),
            Tab(icon: Icon(Icons.book), text: 'Stories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivitiesTab(),
          _buildStoriesTab(),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getSavedActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.auto_awesome_outlined,
            title: 'No Saved Activities Yet',
            subtitle: 'Generate AI activities and save them here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildActivityCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildStoriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getSavedStories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.book_outlined,
            title: 'No Saved Stories Yet',
            subtitle: 'Generate AI stories and save them here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildStoryCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildActivityCard(String id, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Icon(Icons.auto_awesome, color: Colors.purple.shade700),
        ),
        title: Text(
          data['title'] ?? 'Activity',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          data['shortDescription'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('📋 Instructions', data['instructions']),
                if ((data['materials'] as List?)?.isNotEmpty ?? false)
                  _buildListSection('📦 Materials', data['materials']),
                if ((data['learningGoals'] as List?)?.isNotEmpty ?? false)
                  _buildListSection('🎯 Goals', data['learningGoals']),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(
                      label: Text(data['skillType'] ?? 'General'),
                      backgroundColor: Colors.purple.shade50,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(data['difficulty'] ?? 'Medium'),
                      backgroundColor: Colors.amber.shade50,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _deleteActivity(id),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(String id, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.shade100,
          child: Icon(Icons.book, color: Colors.amber.shade800),
        ),
        title: Text(
          data['title'] ?? 'Story',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          (data['story'] ?? '').toString().substring(
            0,
            (data['story'] ?? '').toString().length > 80
                ? 80
                : (data['story'] ?? '').toString().length,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['story'] ?? '', style: const TextStyle(height: 1.6)),
                if (data['moral'] != null && data['moral'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 20)),
                        Expanded(
                          child: Text(
                            'Moral: ${data['moral']}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _deleteStory(id),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, dynamic content) {
    if (content == null) return const SizedBox.shrink();
    if (content is List) {
      return _buildListSection(title, content);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(content.toString()),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildListSection(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text('• $item'),
        )),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteActivity(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: const Text('This activity will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteSavedActivity(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity deleted'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _deleteStory(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This story will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteSavedStory(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story deleted'), duration: Duration(seconds: 2)),
        );
      }
    }
  }
}
