import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopDetailPage extends StatelessWidget {
  final String shopId;
  final Map<String, dynamic> shopData;
  final Function(String status, {String? reason}) onStatusChange;

  const ShopDetailPage({
    super.key,
    required this.shopId,
    required this.shopData,
    required this.onStatusChange,
  });

  Widget detailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              "$title:",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "N/A",
              style: const TextStyle(
                  fontSize: 15, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  /// ⭐ Calculate Average Rating
  double calculateAverage(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    double total = 0;
    for (var doc in docs) {
      total += (doc['rating'] ?? 0).toDouble();
    }
    return total / docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final String status =
        (shopData['status'] ?? 'pending').toLowerCase();

    final double screenWidth = MediaQuery.of(context).size.width;

    Color statusColor;
    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    final TextEditingController rejectionController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(11, 44, 77, 1),
        leading: const BackButton(color: Colors.white),
        title: const Text(
          "Verification",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopData['shop_name'] ?? "Shop Name",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              "Owner: ${shopData['owner_name'] ?? 'N/A'}"),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  shopData['owner_email'] ?? 'N/A',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 16),
                              const SizedBox(width: 4),
                              Text(shopData['owner_contact'] ?? 'N/A'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 14),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// IMAGE
                    safeImage(shopData['shop_image'], screenWidth * 0.3),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                detailItem("Shop Category", shopData['shop_category'] ?? "N/A"),
                detailItem(
                  "Opening Hours",
                  "${shopData['open_time'] ?? "N/A"} - ${shopData['close_time'] ?? "N/A"}",
                ),
                detailItem("Address", shopData['shop_location'] ?? "N/A"),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  "Description:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  shopData['shop_description'] ?? "N/A",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),

                /// ✅ APPROVE / REJECT BUTTONS
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            onStatusChange(
                              "rejected",
                              reason: rejectionController.text,
                            );
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(
                                vertical: screenWidth * 0.04),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Reject",
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            onStatusChange("verified");
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                                vertical: screenWidth * 0.04),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Approve",
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: rejectionController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Enter reason for rejection (Optional)",
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                /// ⭐ REVIEWS SECTION
                const Text(
                  "Reviews",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .collection('reviews')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final reviews = snapshot.data!.docs;
                    final avgRating = calculateAverage(reviews);

                    if (reviews.isEmpty)
                      return const Text(
                        "No reviews yet.",
                        style: TextStyle(color: Colors.grey),
                      );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Average Rating: ${avgRating.toStringAsFixed(1)} ⭐",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text("${reviews.length} Reviews",
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final data = review.data() as Map<String, dynamic>;
                            final timestamp = data['timestamp'] as Timestamp?;

                            String formattedDate = "";
                            if (timestamp != null) {
                              final date = timestamp.toDate();
                              formattedDate =
                                  "${date.day}/${date.month}/${date.year}";
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    (data['userName'] ??
                                            data['userId'] ??
                                            "A")[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                title: Text(
                                    data['userName'] ??
                                        data['userId'] ??
                                        "Anonymous"),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['comment'] ?? ""),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.report,
                                          color: Colors.orange),
                                      onPressed: () {
                                        FirebaseFirestore.instance
                                            .collection('shops')
                                            .doc(shopId)
                                            .collection('reviews')
                                            .doc(review.id)
                                            .update({'reported': true});
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        FirebaseFirestore.instance
                                            .collection('shops')
                                            .doc(shopId)
                                            .collection('reviews')
                                            .doc(review.id)
                                            .delete();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget safeImage(String? url, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  "assets/logo3.jpeg",
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                );
              },
            )
          : Image.asset(
              "assets/logo3.jpeg",
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
    );
  }
}