import 'package:flutter/material.dart';

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
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ),
        ],
      ),
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

    TextEditingController rejectionController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.grey[100],

      /// CLEAN APPBAR
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        leading: const BackButton(color: Colors.white),
        title: const Text("Verification",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// HEADER WITH IMAGE SAME POSITION
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
                          Text("Owner: ${shopData['owner_name'] ?? 'N/A'}"),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// IMAGE WITH ZOOM
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.black,
                              child: InteractiveViewer(
                                child: safeImage(
                                    shopData['shop_image'], screenWidth * 0.3),
                              ),
                            ),
                          );
                        },
                        child: safeImage(shopData['shop_image'], screenWidth * 0.3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),

                /// SHOP DETAILS
                detailItem(
                    "Shop Category", shopData['shop_category'] ?? "N/A"),

                /// SWAPPED
                detailItem(
                  "Opening Hours",
                  "${shopData['open_time'] ?? "N/A"} - ${shopData['close_time'] ?? "N/A"}",
                ),
                detailItem("Address", shopData['shop_location'] ?? "N/A"),

                const SizedBox(height: 16),
                const Divider(),

                /// UPLOADED DOCUMENTS
                const Text("Uploaded Documents:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (shopData['business_license'] != null)
                      documentThumb(
                          "Business License", shopData['business_license']),
                    const SizedBox(width: 16),
                    if (shopData['owner_id_card'] != null)
                      documentThumb("Owner ID", shopData['owner_id_card']),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),

                /// DESCRIPTION
                const Text("Description:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(shopData['shop_description'] ?? "N/A",
                    style: const TextStyle(color: Colors.black54)),

                const SizedBox(height: 24),

                /// APPROVE / REJECT BUTTONS (only for pending)
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
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(
                                vertical: screenWidth * 0.04),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero, // 👉 makes button rectangle
                            ),    
                          ),
                          child: const Text("Reject",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            onStatusChange("verified");
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                                vertical: screenWidth * 0.04),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero, // 👉 makes button rectangle
                            ),
                          ),
                          child: const Text("Approve",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  /// PENDING ONLY: REJECTION REASON INPUT
                if (status == 'pending') ...[
                  TextField(
                    controller: rejectionController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Enter reason for rejection (Optional)",
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// SAFE IMAGE WIDGET WITH LOCAL FALLBACK
  Widget safeImage(String? url, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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

  Widget documentThumb(String title, String url) {
    return Column(
      children: [
        safeImage(url, 80),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
