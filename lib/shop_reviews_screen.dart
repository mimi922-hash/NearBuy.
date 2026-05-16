import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 
class ShopReviewsPage extends StatelessWidget {
  final String shopId;
  const ShopReviewsPage({super.key, required this.shopId});
 
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentOrange = Color(0xFFFF6A1A);
  static const Color bgColor      = Color(0xFFF8FAFC);
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryNavy, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Shop Reviews', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('shops').doc(shopId)
            .collection('reviews').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A1A)));
          final reviews = snapshot.data!.docs;
          if (reviews.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No reviews yet.', style: TextStyle(color: Colors.grey.shade500)),
          ]));
 
          // Average rating
          double total = 0;
          for (var doc in reviews) {
            final r = doc['rating'];
            if (r is int) total += r.toDouble(); else if (r is double) total += r;
          }
          double avgRating = reviews.isNotEmpty ? total / reviews.length : 0;
 
          return Column(children: [
            // ── Average rating card ──
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [primaryNavy, Color(0xFF1A3A5C)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Average Rating', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(avgRating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const Text(' / 5', style: TextStyle(color: Colors.white60, fontSize: 18)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${reviews.length} Reviews', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ]),
                const Spacer(),
                // Star display
                Column(children: List.generate(5, (i) => Icon(
                  i < avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < avgRating.round() ? accentOrange : Colors.white30, size: 22))),
              ]),
            ),
 
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final data      = reviews[index].data() as Map<String, dynamic>;
                final rating    = data['rating'] ?? 0;
                final comment   = data['comment'] ?? '';
                final userName  = data['userName'] ?? data['userId'] ?? 'Anonymous';
                final profilePic = data['profilePic'];
                final ts        = data['timestamp'];
                String dateStr  = '';
                if (ts != null && ts is Timestamp) {
                  final d = ts.toDate();
                  dateStr = '${d.day}/${d.month}/${d.year}';
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                        backgroundColor: const Color(0xFF0E2A47).withOpacity(0.1),
                        child: profilePic == null ? Text(userName[0].toUpperCase(),
                            style: const TextStyle(color: primaryNavy, fontWeight: FontWeight.bold)) : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryNavy)),
                        Text(dateStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      ])),
                      // Star rating badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accentOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFF6A1A), size: 16),
                          const SizedBox(width: 3),
                          Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6A1A))),
                        ]),
                      ),
                    ]),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(comment, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
                    ],
                  ]),
                );
              },
            )),
          ]);
        },
      ),
    );
  }
}
