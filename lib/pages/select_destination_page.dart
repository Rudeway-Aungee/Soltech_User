import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../appinfo/app_info.dart';

class SelectDestinationPage extends StatefulWidget {
   const SelectDestinationPage({super.key});
 
   @override
   State<SelectDestinationPage> createState() => _SelectDestinationPageState();
 }
 
 class _SelectDestinationPageState extends State<SelectDestinationPage> {

  TextEditingController pickupTextEditingController = TextEditingController();
  TextEditingController destinationTextEditingController = TextEditingController();


   @override
   Widget build(BuildContext context) {

     String pickupAddressOfUser = Provider.of<AppInfo>(context, listen: true).userPickupLocation?.humanReadableAddress?? "";
     pickupTextEditingController.text = pickupAddressOfUser;


     return Scaffold(
       body: SingleChildScrollView(
         child: Column(
           children: [
             Card(
               elevation: 14,
               child: Container(
                 height: 232,
                 decoration: const BoxDecoration(
                   boxShadow: [
                     BoxShadow(
                       color: Colors.white10,
                       blurRadius: 10,
                       spreadRadius: 0.5,
                       offset: Offset(0.7, 0.7),
                     )
                   ]
                 ),
                 child: Padding(
                     padding: const EdgeInsets.only(left: 24, top: 40, right: 24, bottom: 20),
                      child: Column(
                       children: [
                         const SizedBox(height: 5),

                         Stack(
                           children: [
                             GestureDetector(
                                 onTap: () {
                                   Navigator.pop(context);
                                 },
                                 child: const Icon(Icons.arrow_back, color: Colors.black, size: 22)
                             ),

                             const Center(
                               child: Text(
                                 "Set Destination",
                                 style: TextStyle(
                                     fontSize: 18,
                                     color: Colors.black,
                                     fontWeight: FontWeight.bold
                                 ),
                               ),
                             ),
                           ]
                         ),

                         const SizedBox(height: 16),

                         //Select Pickup Location
                         Row(
                           children: [
                             Image.asset(
                                 "assets/initial.png", height: 16, width: 16),

                             const SizedBox(width: 18),

                              Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[400],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: TextField(
                                        controller: pickupTextEditingController,
                                        decoration: InputDecoration(
                                          hintText: "Pickup Location",
                                          fillColor: Colors.white12,
                                          filled: true,
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.only(bottom: 9, left: 10, top: 8),
                                        ),
                                      ),
                                    ),
                                  )
                              )
                           ],
                         ),

                         const SizedBox(height: 10),



                         //Select destination
                         Row(
                           children: [
                             Image.asset(
                                 "assets/final.png", height: 16, width: 16),

                             const SizedBox(width: 18),

                             Expanded(
                                 child: Container(
                                   decoration: BoxDecoration(
                                     color: Colors.grey[400],
                                     borderRadius: BorderRadius.circular(6),
                                   ),
                                   child: Padding(
                                     padding: const EdgeInsets.all(2),
                                     child: TextField(
                                       controller: destinationTextEditingController,
                                       decoration: InputDecoration(
                                         hintText: "Search Destination Location here",
                                         fillColor: Colors.white12,
                                         filled: true,
                                         border: InputBorder.none,
                                         isDense: true,
                                         contentPadding: const EdgeInsets.only(bottom: 9, left: 10, top: 8),
                                       ),
                                     ),
                                   ),
                                 )
                             )
                           ],
                         ),

                       ]
                   ),
                 ),
               ),
             )
           ]
         ),
       ),
     );
   }
 }
 