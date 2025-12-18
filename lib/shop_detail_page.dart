import 'package:flutter/material.dart';

class ShopDetailPage extends StatelessWidget {
  final String shopId;
  final Map<String, dynamic> shopData;
  final Function(String status) onStatusChange;

  const ShopDetailPage({
    super.key,
    required this.shopId,
    required this.shopData,
    required this.onStatusChange,
  });

  Widget detailItem(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$title: ",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          Expanded(
            child: Text(
              value?.toString() ?? "N/A",
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shopData['shop_name'] ?? "Shop Details"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                detailItem("Shop Name", shopData['shop_name']),
                detailItem("Owner Name", shopData['owner_name']),
                detailItem("Owner Email", shopData['owner_email']),
                detailItem("Owner Contact", shopData['owner_contact']),
                detailItem("CNIC Number", shopData['cnic_number']),
                detailItem("Category", shopData['shop_category']),
                detailItem("Location", shopData['shop_location']),
                detailItem("Open Time", shopData['open_time']),
                detailItem("Close Time", shopData['close_time']),
                detailItem("Description", shopData['shop_description']),
                detailItem("Status", shopData['status']),

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        onStatusChange("verified");
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text("Approve"),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        onStatusChange("rejected");
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text("Reject"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}