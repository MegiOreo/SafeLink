// import 'package:google_generative_ai/google_generative_ai.dart';
//
// class GeminiApiService {
//   final GenerativeModel _model;
//
//   GeminiApiService({required String apiKey})
//       : _model = GenerativeModel(
//     model: 'gemini-pro',
//     apiKey: apiKey,
//   );
//
//   Future<String> sendMessage(String content) async {
//     try {
//       final response = await _model.generateContent([
//         Content.text(content),
//       ]);
//
//       return response.text ?? "No response";
//     } catch (e) {
//       throw Exception("Gemini Error: $e");
//     }
//   }
// }
