// ⚠️  IMPORTANT: Add this file to .gitignore before committing!
// Add the following line to your .gitignore:
//   lib/constants/api_constants.dart
//
// This file contains sensitive API keys and should NEVER be committed to source control.
// PLEASE NOTE: You must generate a new API key at https://aistudio.google.com/app/apikey 
// as the previous one has been compromised.

class ApiConstants {
  /// Gemini 2.0 Flash API Key
  /// Replace it with a new key from https://aistudio.google.com/app/apikey
  static const String geminiApiKey = 'YOUR_NEW_API_KEY_HERE';

  /// Full Gemini API endpoint with the key appended
  static const String geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey';
}
