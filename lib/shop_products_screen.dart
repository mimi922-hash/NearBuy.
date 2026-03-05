import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopProductsScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const ShopProductsScreen({super.key, required this.shopId, required this.shopName});

  @override
  State<ShopProductsScreen> createState() => _ShopProductsScreenState();
}

class _ShopProductsScreenState extends State<ShopProductsScreen> {
  String _searchText = "";
  double _userRating = 0;
  final TextEditingController _commentController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  double _avgRating = 0; // Average rating

  @override
  void initState() {
    super.initState();
    _calculateAverageRating();
  }

  // ---------------- CALCULATE AVERAGE RATING ----------------
  void _calculateAverageRating() {
    FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('reviews')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        setState(() {
          _avgRating = 0;
        });
        return;
      }

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['rating'] ?? 0).toDouble();
      }

      setState(() {
        _avgRating = total / snapshot.docs.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shopName),
        backgroundColor: const Color.fromARGB(255, 21, 101, 192),
      ),
      body: Column(
        children: [
          // ---------------- Average Rating + Count ----------------
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Average Rating: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    RatingBarIndicator(
                      rating: _avgRating,
                      itemBuilder: (context, _) =>
                          const Icon(Icons.star, color: Colors.amber),
                      itemCount: 5,
                      itemSize: 25.0,
                      direction: Axis.horizontal,
                    ),
                    const SizedBox(width: 8),
                    Text(_avgRating.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 4),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(widget.shopId)
                      .collection('reviews')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final count = snapshot.data!.docs.length;
                    return Text(
                      "$count ratings",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  },
                ),
              ],
            ),
          ),

          // ---------------- Search bar ----------------
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Products...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase();
                });
              },
            ),
          ),

          // ---------------- Products List ----------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final productName =
                      data['name']?.toString().toLowerCase() ?? "";
                  return productName.contains(_searchText);
                }).toList();

                if (products.isEmpty) {
                  return const Center(child: Text("No products found."));
                }

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final data = products[index].data() as Map<String, dynamic>;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: data['image_url'] != null
                            ? Image.network(data['image_url'],
                                width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 50),
                        title: Text(data['name'] ?? "Unnamed Product"),
                        subtitle: Text("Price: \$${data['price'] ?? "0"}"),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(),

          // ---------------- Add Review Section ----------------
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rate this Shop",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                RatingBar.builder(
                  initialRating: 0,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: Colors.amber),
                  onRatingUpdate: (rating) {
                    setState(() {
                      _userRating = rating;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: "Write your review...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 21, 101, 192)),
                    child: const Text("Submit Review"),
                    onPressed: _submitReview,
                  ),
                ),
              ],
            ),
          ),

          // ---------------- Show Reviews ----------------
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('reviews')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final reviews = snapshot.data!.docs;

                if (reviews.isEmpty)
                  return const Center(child: Text("No reviews yet."));

                return ListView.builder(
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final data = reviews[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          data['userName'] != null
                              ? data['userName'][0].toUpperCase()
                              : "?",
                        ),
                      ),
                      title: Text(
                            data['userName'] ?? data['userId'] ?? "Anonymous"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RatingBarIndicator(
                            rating: (data['rating'] ?? 0).toDouble(),
                            itemBuilder: (context, _) =>
                                const Icon(Icons.star, color: Colors.amber),
                            itemCount: 5,
                            itemSize: 20.0,
                            direction: Axis.horizontal,
                          ),
                          Text(data['comment'] ?? ""),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _submitReview() async {
    if (_userRating == 0 || _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide rating and comment")),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('reviews')
        .add({
      'rating': _userRating,
      'comment': _commentController.text,
      'userId': user?.uid,
      'userName': user?.email ?? "Anonymous",
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
    setState(() {
      _userRating = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Review submitted")),
    );
  }
}