import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_screen.dart'; // ✅ NEW IMPORT

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

  double _avgRating = 0;

  // ⭐ FAVORITE VARIABLE
  bool isFavorite = false;

  // ✅ Cart count variable
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _calculateAverageRating();
    checkIfFavorite();
    _listenCartCount(); // ✅ NEW
  }

  // ✅ NEW: Listen to cart count for this shop
  void _listenCartCount() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .where('shopId', isEqualTo: widget.shopId)
        .snapshots()
        .listen((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['quantity'] ?? 1) as int;
      }
      if (mounted) {
        setState(() {
          _cartCount = total;
        });
      }
    });
  }

  // ✅ NEW: Add to cart logic
  Future<void> _addToCart(Map<String, dynamic> productData, String productId) async {
    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .doc('${widget.shopId}_$productId'); // unique doc per product per shop

    final existing = await cartRef.get();

    if (existing.exists) {
      // Already in cart — increase quantity
      await cartRef.update({'quantity': (existing.data()!['quantity'] ?? 1) + 1});
    } else {
      // New item
      await cartRef.set({
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'productId': productId,
        'name': productData['name'],
        'price': productData['price'],
        'image_url': productData['image_url'] ?? '',
        'quantity': 1,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${productData['name']} added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1565C0),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CartScreen(shopId: widget.shopId, shopName: widget.shopName),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------- CHECK FAVORITE ----------------
  void checkIfFavorite() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(widget.shopId)
        .get();

    setState(() {
      isFavorite = doc.exists;
    });
  }

  // ---------------- TOGGLE FAVORITE ----------------
  void toggleFavorite() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    if (isFavorite) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(widget.shopId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Removed from favorites")),
      );
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(widget.shopId)
          .set({
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Added to favorites")),
      );
    }

    setState(() {
      isFavorite = !isFavorite;
    });
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
        actions: [
          // ⭐ FAVORITE BUTTON
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: toggleFavorite,
          ),

          // ✅ NEW: Cart icon with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartScreen(shopId: widget.shopId, shopName: widget.shopName),
                    ),
                  );
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
                    final productId = products[index].id;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            // Product image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: data['image_url'] != null
                                  ? Image.network(data['image_url'],
                                      width: 60, height: 60, fit: BoxFit.cover)
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(width: 12),

                            // Product info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? "Unnamed Product",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Rs. ${data['price'] ?? "0"}",
                                    style: const TextStyle(
                                        color: Color(0xFF1565C0),
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (data['description'] != null &&
                                      data['description'].toString().isNotEmpty)
                                    Text(
                                      data['description'],
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),

                            // ✅ NEW: Add to Cart Button
                            ElevatedButton(
                              onPressed: () => _addToCart(data, productId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Add', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                    child: const Text("Submit Review", style: TextStyle(color: Colors.white)),
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
                if (reviews.isEmpty) {
                  return const Center(child: Text("No reviews yet."));
                }

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
