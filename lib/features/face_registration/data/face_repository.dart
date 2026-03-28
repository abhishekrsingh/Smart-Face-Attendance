// ============================================================
// FaceRepository
// PURPOSE: Saves and retrieves face embeddings.
// FIXED: Now saves embedding to profiles.face_embedding (vector)
// instead of face_data table — matches what attendance_provider
// reads during check-in verification.
// ============================================================

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';
import '../../../env/env.dart';

class FaceRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // ── uploadFaceImage() ──────────────────────────────────────
  // PURPOSE: Upload face image to Supabase Storage.
  // WHY raw HTTP PUT: SDK was returning 404 due to resumable
  // upload protocol — direct REST always works.
  Future<String> uploadFaceImage(String imagePath) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _client.auth.refreshSession();
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null) throw Exception('No access token');

    final userId = user.id;
    final storagePath = '$userId/face.jpg';

    AppLogger.debug('📁 Upload path: $storagePath');

    final bytes = await File(imagePath).readAsBytes();
    final url = Uri.parse(
      '${Env.supabaseUrl}/storage/v1/object/face-images/$storagePath',
    );

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'apikey': Env.supabaseAnonKey,
        'Content-Type': 'image/jpeg',
        // WHY x-upsert: allows overwrite on re-registration
        'x-upsert': 'true',
      },
      body: bytes,
    );

    AppLogger.debug('📡 HTTP Status: ${response.statusCode}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Upload failed: HTTP ${response.statusCode} — ${response.body}',
      );
    }

    AppLogger.info('✅ Image uploaded');

    final publicUrl = _client.storage
        .from('face-images')
        .getPublicUrl(storagePath);

    AppLogger.info('🔗 URL: $publicUrl');
    return publicUrl;
  }

  // ── saveFaceEmbedding() ────────────────────────────────────
  // PURPOSE: Save 192-dim embedding to profiles.face_embedding.
  // WHY profiles table: attendance_provider reads from
  // profiles.face_embedding — must save here to match.
  // WHY NOT face_data: old table used jsonEncode string —
  // incompatible with pgvector cosine similarity operations.
  Future<void> saveFaceEmbedding({
    required List<double> embedding,
    required String imageUrl,
  }) async {
    final userId = _client.auth.currentUser!.id;
    try {
      AppLogger.debug('💾 Saving ${embedding.length} dims to profiles');

      // WHY update not upsert: profiles row already exists —
      // created by trigger when user signed up
      await _client
          .from('profiles')
          .update({
            // WHY plain List<double>: Supabase pgvector accepts
            // List<double> directly — no jsonEncode needed
            'face_embedding': embedding,
            'avatar_url': imageUrl.isNotEmpty ? imageUrl : null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.info('✅ Embedding saved to profiles for: $userId');
    } on PostgrestException catch (e) {
      AppLogger.error('DB error: ${e.message}');
      rethrow;
    } catch (e, st) {
      AppLogger.error('Save embedding failed', e, st);
      rethrow;
    }
  }

  // ── getStoredEmbedding() ───────────────────────────────────
  // PURPOSE: Fetch embedding from profiles for attendance check.
  // WHY string parse: pgvector returns vector as string via
  // Supabase REST API e.g. "[0.123,0.456,...]" — not List<dynamic>
  // Must detect type and parse accordingly.
  Future<List<double>?> getStoredEmbedding() async {
    final userId = _client.auth.currentUser!.id;
    try {
      final response = await _client
          .from('profiles')
          .select('face_embedding')
          .eq('id', userId)
          .single();

      final raw = response['face_embedding'];
      if (raw == null) {
        AppLogger.warning('No embedding in profiles for: $userId');
        return null;
      }

      // WHY type check: pgvector returns string "[0.1,0.2,...]"
      // via REST API — but may return List in some SDK versions.
      // Handle both cases safely.
      if (raw is String) {
        // Remove surrounding brackets → split by comma → parse each
        // Input:  "[0.123,-0.456,0.789,...]"
        // Output: [0.123, -0.456, 0.789, ...]
        final cleaned = raw.replaceAll('[', '').replaceAll(']', '');
        return cleaned.split(',').map((e) => double.parse(e.trim())).toList();
      } else if (raw is List) {
        // WHY fallback: future SDK versions may return List directly
        return List<double>.from(raw);
      } else {
        AppLogger.warning('Unknown embedding type: ${raw.runtimeType}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Get embedding failed', e);
      return null;
    }
  }

  // ── hasFaceRegistered() ────────────────────────────────────
  // PURPOSE: Quick check before allowing attendance marking.
  Future<bool> hasFaceRegistered() async {
    final userId = _client.auth.currentUser!.id;
    try {
      final response = await _client
          .from('profiles')
          .select('face_embedding')
          .eq('id', userId)
          .single();
      return response['face_embedding'] != null;
    } catch (e) {
      return false;
    }
  }
}

final faceRepository = FaceRepository();
