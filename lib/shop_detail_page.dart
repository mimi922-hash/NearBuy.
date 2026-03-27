import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// ⭐ Open image fullscreen
  void openImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(imageUrl: url),
      ),
    );
  }

  /// ⭐ Download image
  Future<void> downloadImage(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

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

  Widget imageCard(BuildContext context, String? url, String title) {
    if (url == null || url.isEmpty) {
      return const Text("No Image");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

        const SizedBox(height: 8),

        GestureDetector(
          onTap: () => openImage(context, url),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => downloadImage(url),
            ),
            const Text("Download"),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String status = (shopData['status'] ?? 'pending').toLowerCase();
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
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 6),

                          Text("Owner: ${shopData['owner_name'] ?? 'N/A'}"),

                          const SizedBox(height: 4),

                          Row(
                            children: [
                              const Icon(Icons.email, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  shopData['owner_email'] ?? 'N/A',
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ⭐ SHOP IMAGE (ZOOMABLE)
                    GestureDetector(
                      onTap: () => openImage(
                          context, shopData['shop_image_url'] ?? ""),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          shopData['shop_image_url'] ?? "",
                          width: screenWidth * 0.3,
                          height: screenWidth * 0.3,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: screenWidth * 0.3,
                              height: screenWidth * 0.3,
                              color: Colors.grey[300],
                              child: const Icon(Icons.store),
                            );
                          },
                        ),
                      ),
                    ),
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

                /// ⭐ DOCUMENTS
                const Text(
                  "Documents",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),

                const SizedBox(height: 12),

                imageCard(
                    context,
                    shopData['cnic_front_url'],
                    "CNIC Front"),

                imageCard(
                    context,
                    shopData['cnic_back_url'],
                    "CNIC Back"),

                const SizedBox(height: 20),

                /// APPROVE / REJECT
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
                          ),
                          child: const Text("Reject"),
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
                          ),
                          child: const Text("Approve"),
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
                      hintText: "Enter reason for rejection",
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ⭐ FULLSCREEN IMAGE VIEWER
class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
      ),

      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}