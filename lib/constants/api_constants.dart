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
  static const String geminiApiKey = 'AIzaSyD7C5gO9z76SGrtm_309SaTMvAF8fxvUBI';

  /// Full Gemini API endpoint with the key appended
  static const String geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=$geminiApiKey';
}
