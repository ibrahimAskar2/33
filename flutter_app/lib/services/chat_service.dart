import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // إنشاء دردشة فردية جديدة
  Future<String> createPrivateChat(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // التحقق من وجود دردشة سابقة بين المستخدمين
      final existingChatQuery = await _firestore
          .collection('chats')
          .where('type', isEqualTo: 'private')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      for (var doc in existingChatQuery.docs) {
        final data = doc.data();
        final List<dynamic> participants = data['participants'];
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }

      // إنشاء دردشة جديدة
      final chatRef = _firestore.collection('chats').doc();
      await chatRef.set({
        'type': 'private',
        'participants': [currentUser.uid, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
      });

      return chatRef.id;
    } catch (e) {
      print('Error creating private chat: $e');
      rethrow;
    }
  }

  // إنشاء مجموعة دردشة جديدة
  Future<String> createGroupChat(String name, List<String> participants) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // إضافة المستخدم الحالي إلى المشاركين إذا لم يكن موجوداً
      if (!participants.contains(currentUser.uid)) {
        participants.add(currentUser.uid);
      }

      // إنشاء مجموعة دردشة جديدة
      final chatRef = _firestore.collection('chats').doc();
      await chatRef.set({
        'type': 'group',
        'name': name,
        'participants': participants,
        'admin': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
      });

      return chatRef.id;
    } catch (e) {
      print('Error creating group chat: $e');
      rethrow;
    }
  }

  // إضافة مشاركين إلى مجموعة دردشة
  Future<void> addParticipantsToGroup(String chatId, List<String> newParticipants) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // التحقق من أن المستخدم الحالي هو مشرف المجموعة
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw Exception('المجموعة غير موجودة');
      }

      final chatData = chatDoc.data();
      if (chatData == null || chatData['type'] != 'group' || chatData['admin'] != currentUser.uid) {
        throw Exception('ليس لديك صلاحية إضافة مشاركين');
      }

      // الحصول على المشاركين الحاليين
      final List<dynamic> currentParticipants = chatData['participants'];
      
      // إضافة المشاركين الجدد
      for (var participant in newParticipants) {
        if (!currentParticipants.contains(participant)) {
          currentParticipants.add(participant);
        }
      }

      // تحديث المجموعة
      await _firestore.collection('chats').doc(chatId).update({
        'participants': currentParticipants,
      });
    } catch (e) {
      print('Error adding participants to group: $e');
      rethrow;
    }
  }

  // إرسال رسالة نصية
  Future<void> sendTextMessage(String chatId, String text) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // إنشاء رسالة جديدة
      final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
      final message = {
        'type': 'text',
        'text': text,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [currentUser.uid],
        'deliveredTo': [currentUser.uid],
      };

      await messageRef.set(message);

      // تحديث آخر رسالة في الدردشة
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': {
          'type': 'text',
          'text': text,
          'senderId': currentUser.uid,
        },
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending text message: $e');
      rethrow;
    }
  }

  // إرسال رسالة صوتية
  Future<void> sendVoiceMessage(String chatId, File audioFile) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // رفع الملف الصوتي إلى Firebase Storage
      final storageRef = _storage.ref().child('voice_messages/${DateTime.now().millisecondsSinceEpoch}_${audioFile.path.split('/').last}');
      final uploadTask = storageRef.putFile(audioFile);
      final snapshot = await uploadTask;
      final audioUrl = await snapshot.ref.getDownloadURL();

      // إنشاء رسالة جديدة
      final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
      final message = {
        'type': 'voice',
        'url': audioUrl,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [currentUser.uid],
        'deliveredTo': [currentUser.uid],
      };

      await messageRef.set(message);

      // تحديث آخر رسالة في الدردشة
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': {
          'type': 'voice',
          'senderId': currentUser.uid,
        },
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending voice message: $e');
      rethrow;
    }
  }

  // إرسال صورة
  Future<void> sendImageMessage(String chatId, File imageFile) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // رفع الصورة إلى Firebase Storage
      final storageRef = _storage.ref().child('images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}');
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      // إنشاء رسالة جديدة
      final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
      final message = {
        'type': 'image',
        'url': imageUrl,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [currentUser.uid],
        'deliveredTo': [currentUser.uid],
      };

      await messageRef.set(message);

      // تحديث آخر رسالة في الدردشة
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': {
          'type': 'image',
          'senderId': currentUser.uid,
        },
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending image message: $e');
      rethrow;
    }
  }

  // تحديث حالة قراءة الرسالة
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // الحصول على الرسالة
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('الرسالة غير موجودة');
      }

      final messageData = messageDoc.data();
      if (messageData == null) {
        throw Exception('بيانات الرسالة غير موجودة');
      }

      // تحديث قائمة القراء
      final List<dynamic> readBy = messageData['readBy'] ?? [];
      if (!readBy.contains(currentUser.uid)) {
        readBy.add(currentUser.uid);
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
          'readBy': readBy,
        });
      }
    } catch (e) {
      print('Error marking message as read: $e');
      rethrow;
    }
  }

  // تحديث حالة استلام الرسالة
  Future<void> markMessageAsDelivered(String chatId, String messageId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // الحصول على الرسالة
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('الرسالة غير موجودة');
      }

      final messageData = messageDoc.data();
      if (messageData == null) {
        throw Exception('بيانات الرسالة غير موجودة');
      }

      // تحديث قائمة المستلمين
      final List<dynamic> deliveredTo = messageData['deliveredTo'] ?? [];
      if (!deliveredTo.contains(currentUser.uid)) {
        deliveredTo.add(currentUser.uid);
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
          'deliveredTo': deliveredTo,
        });
      }
    } catch (e) {
      print('Error marking message as delivered: $e');
      rethrow;
    }
  }

  // الحصول على قائمة الدردشات
  Stream<QuerySnapshot> getChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // الحصول على رسائل دردشة معينة
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // البحث في رسائل دردشة معينة
  Future<List<QueryDocumentSnapshot>> searchChatMessages(String chatId, String query) async {
    try {
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('type', isEqualTo: 'text')
          .get();

      // البحث في النص
      return messagesQuery.docs.where((doc) {
        final data = doc.data();
        final text = data['text'] as String?;
        if (text == null) {
          return false;
        }
        return text.toLowerCase().contains(query.toLowerCase());
      }).toList();
    } catch (e) {
      print('Error searching chat messages: $e');
      return [];
    }
  }

  // الحصول على معلومات المستخدم
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return null;
      }
      return userDoc.data();
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }

  // الحصول على معلومات الدردشة
  Future<Map<String, dynamic>?> getChatInfo(String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        return null;
      }
      return chatDoc.data();
    } catch (e) {
      print('Error getting chat info: $e');
      return null;
    }
  }
}
