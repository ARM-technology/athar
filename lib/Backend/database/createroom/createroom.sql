-- ====================================================================================
-- 1. إنشاء الغرف وفحص التواجد الذكي (Safe Creation & Bidirectional Discovery)
-- ====================================================================================

-- name: CreateChatRoomSecure :one
-- إنشاء غرفة محادثة جديدة بشكل آمن تماماً: لضمان عدم كسر قيد الـ UNIQUE يضمن الكويري وضع المعرّف الأصغر في user1_id والأكبر في user2_id تلقائياً.
-- في حال كانت الغرفة موجودة مسبقاً بين الطرفين، لن يحدث خطأ (No Conflict) بل سيعيد الكويري بيانات الغرفة الحالية فوراً.
INSERT INTO chat_rooms (user1_id, user2_id)
VALUES (
    LEAST($1::bigint, $2::bigint), 
    GREATEST($1::bigint, $2::bigint)
)
ON CONFLICT (user1_id, user2_id) 
DO UPDATE SET user1_id = chat_rooms.user1_id -- خدعة برمجية لإجبار قاعدة البيانات على إرجاع الصف عند النزاع
RETURNING id, user1_id, user2_id, created_at;

-- name: GetRoomByParticipants :one
-- فحص مباشر وثنائي الاتجاه لمعرفة ما إذا كانت هناك غرفة قائمة بين مستخدمين اثنين وجلب معرفها
SELECT id, user1_id, user2_id, created_at
FROM chat_rooms
WHERE user1_id = LEAST($1::bigint, $2::bigint) 
  AND user2_id = GREATEST($1::bigint, $2::bigint)
LIMIT 1;

-- name: GetRoomByID :one
-- جلب بيانات الغرفة الأساسية بواسطة الـ ID الخاص بها
SELECT id, user1_id, user2_id, created_at
FROM chat_rooms
WHERE id = $1;


-- ====================================================================================
-- 2. كويري الـ Inbox الذهبي للمنصة (The Ultimate Inbox & Active Chats Query)
-- ====================================================================================

-- name: ListUserInboxDetailed :many
-- الكويري العملاق لصندوق الوارد (Inbox): يجلب كل الغرف النشطة للمستخدم الحالي ($1) بطلب واحد فائق الكفاءة!
-- يقوم الاستعلام بـ:
-- 1. معرفة الطرف الآخر في المحادثة وجلب بياناته (معرفه، اسمه، يوزره) تلقائياً سواء كان هو user1 أو user2.
-- 2. جلب نص أحدث رسالة مرسلة في الغرفة ووقتها لعرضها كـ Preview Text.
-- 3. حساب عدد الرسائل غير المقروءة الموجهة للمستخدم الحالي فقط في هذه الغرفة لعرض شارة الإشعار الحمراء.
-- 4. ترتيب القائمة ديناميكياً بحيث تظهر المحادثات التي تحتوي على أحدث نشاط (أحدث رسالة) في الأعلى، مع الـ Pagination.
WITH room_latest_message AS (
    SELECT DISTINCT ON (room_id) room_id, message_text, sender_id, created_at
    FROM private_messages
    ORDER BY room_id, id DESC -- جلب الرسالة الأحدث في كل غرفة بناءً على الترقيم التلقائي للأشعّة
),
room_unread_counts AS (
    SELECT room_id, COUNT(*) AS unread_count
    FROM private_messages
    WHERE is_read = FALSE AND sender_id != $1 -- حساب الرسائل غير المقروءة الموجهة لي فقط
    GROUP BY room_id
)
SELECT 
    cr.id AS room_id,
    cr.created_at AS room_created_at,
    -- تحديد هوية وبيانات الطرف الآخر ديناميكياً بناءً على من طلب الـ Inbox
    CASE 
        WHEN cr.user1_id = $1 THEN cr.user2_id
        ELSE cr.user1_id
    END AS other_user_id,
    u.username AS other_username,
    u.name AS other_name,
    -- جلب بيانات المعاينة لأحدث رسالة
    COALESCE(lm.message_text, 'لا توجد رسائل بعد') AS latest_message_text,
    lm.sender_id AS latest_message_sender_id,
    COALESCE(lm.created_at, cr.created_at) AS last_activity_time,
    -- عداد الإشعارات الخاص بكل غرفة
    COALESCE(ur.unread_count, 0)::bigint AS unread_messages_count
FROM chat_rooms cr
INNER JOIN users u ON u.id = CASE WHEN cr.user1_id = $1 THEN cr.user2_id ELSE cr.user1_id END
LEFT JOIN room_latest_message lm ON lm.room_id = cr.id
LEFT JOIN room_unread_counts ur ON ur.room_id = cr.id
WHERE cr.user1_id = $1 OR cr.user2_id = $1
ORDER BY last_activity_time DESC
LIMIT $2 OFFSET $3;


-- ====================================================================================
-- 3. الحماية وصلاحيات الوصول (Security & Access Control)
-- ====================================================================================

-- name: CheckRoomAccess :one
-- جدار حماية السيرفر (Middleware Helper): فحص بولياني صارم للتحقق مما إذا كان المستخدم الحالي ($2) 
-- يمتلك الحق في دخول أو القراءة من الغرفة ($1) لمنع الاختراقات وتزوير الطلبات (IDOR Bypass)
SELECT EXISTS(
    SELECT 1 FROM chat_rooms
    WHERE id = $1 AND (user1_id = $2 OR user2_id = $2)
) AS has_access;

-- name: DeleteRoomSecure :exec
-- حذف الغرفة نهائياً مع كامل أرشيف رسائلها (بفضل ON DELETE CASCADE) بـقيد أمني:
-- يشترط أن يكون طالب الحذف ($2) هو أحد المشاركين الفعليين في الغرفة ($1)
DELETE FROM chat_rooms
WHERE id = $1 AND (user1_id = $2 OR user2_id = $2);