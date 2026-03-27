// ⚠️  IMPORTANT: Add this file to .gitignore before committing!
// Add the following line to your .gitignore:
//   lib/constants/api_constants.dart
//
// This file contains sensitive API keys and should NEVER be committed to source control.

class ApiConstants {
  /// Gemini 2.0 Flash API Key
  /// Replace with your actual key from https://aistudio.google.com/app/apikey
  static const String geminiApiKey = 'AIzaSyA1swLif25b017va3yJIk3Y4UjytpCS8RE';

  /// Full Gemini API endpoint with the key appended
  static const String geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey';
}
