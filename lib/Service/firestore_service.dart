// import 'package:cloud_firestore/cloud_firestore.dart';

// class FirestoreService {
//   final CollectionReference orders =
//   FirebaseFirestore.instance.collection('orders');

//   Future<int> getCount() async{
//     final aggregate = await FirebaseFirestore.instance
//         .collection('orders')
//         .count()
//         .get();

//     final orderCount = aggregate.count;
//     return orderCount ?? 0;
//   }

//   Future<int> getTotalPages() async {
//     // 1) Kick off the aggregation. Use the top-level sum() helper:
//     final agg = orders
//         .aggregate(
//       sum('pages'),          // ← top-level: sum(fieldName) ✗ not on AggregateField
//     ).get();                  // ← returns Future<AggregateQuerySnapshot> :contentReference[oaicite:0]{index=0}
//     // 2) Await the result
//     final AggregateQuerySnapshot snap = await agg;
//     // 3) Pull out the sum with the typed getter:
//     final double? sumValue = snap.getSum('pages');  // returns double? :contentReference[oaicite:1]{index=1}
//     // 4) Convert to int (your pages field was int-typed)
//     return sumValue?.toInt() ?? 0;
//   }
// }