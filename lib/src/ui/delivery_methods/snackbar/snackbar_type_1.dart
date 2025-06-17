// import 'package:flutter/material.dart';
//
// import 'snackbar.dart';
// import 'snackbar_data.dart';
//
// class SnackBarType1 extends GravitySnackBar {
//   final SnackBarData data;
//
//   SnackBarType1({
//     required this.data,
//   });
//
//   @override
//   SnackBar toMaterialSnackBar() {
//     return SnackBar(
//       behavior: SnackBarBehavior.floating,
//       padding: EdgeInsets.all(12),
//       backgroundColor: Colors.white,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 0,
//       content: Row(
//         children: [
//           CircleAvatar(
//             radius: 28,
//             backgroundColor: data.circleIconBackground,
//             child: Image.asset(
//               data.circeIconAssetImage,
//               package: 'gravity_sdk',
//             ),
//           ),
//           SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   data.title,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF181d27),
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   data.text,
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w400,
//                     color: Color(0xFF535862),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(
//             width: 8,
//           ),
//           CircleAvatar(
//             radius: 16,
//             backgroundColor: Colors.black,
//             child: Icon(
//               Icons.arrow_forward,
//               color: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
