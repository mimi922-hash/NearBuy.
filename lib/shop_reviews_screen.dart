import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopReviewsPage extends StatelessWidget {
  final String shopId;
  const ShopReviewsPage({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shop Reviews"),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('reviews')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final reviews = snapshot.data!.docs;

          if (reviews.isEmpty)
            return const Center(
              child: Text("No reviews yet.", style: TextStyle(color: Colors.grey)),
            );

          // ⭐ Calculate average rating
          double total = 0;
          for (var doc in reviews) {
            final r = doc['rating'];
            if (r is int) total += r.toDouble();
            else if (r is double) total += r;
          }
          double avgRating = reviews.isNotEmpty ? total / reviews.length : 0;

          return Column(
            children: [

              /// ⭐ Average Rating + Total Reviews
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Average Rating",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${avgRating.toStringAsFixed(1)} ⭐",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text("${reviews.length} Reviews"),
                  ],
                ),
              ),

              /// 📝 Reviews List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final data = reviews[index].data() as Map<String, dynamic>;
                    final rating = data['rating'] ?? 0;
                    final comment = data['comment'] ?? '';
                    final userName = data['userName'] ?? data['userId'] ?? "Anonymous";
                    final profilePic = data['profilePic']; // Firestore me store ho profile pic URL
                    final timestamp = data['timestamp'];

                    String formattedDate = "";
                    if (timestamp != null && timestamp is Timestamp) {
                      final date = timestamp.toDate();
                      formattedDate = "${date.day}/${date.month}/${date.year}";
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            /// ⭐ Rating + Date Row
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 5),
                                Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),

                            const SizedBox(height: 8),

                            /// 💬 Comment
                            Text(comment, style: const TextStyle(fontSize: 15)),

                            const SizedBox(height: 12),

                            /// 👤 User Info with Profile Pic
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                                  backgroundColor: Colors.blue,
                                  child: profilePic == null
                                      ? Text(
                                          userName[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}