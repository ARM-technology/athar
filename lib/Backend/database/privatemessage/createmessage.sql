-- ====================================================================================
-- 1. عمليات إرسال وتعديل وحذف الرسائل بضوابط أمنية (Secure Messaging CRUD)
-- ====================================================================================

-- name: SendMessage :one
-- إرسال رسالة جديدة وإرجاع كامل بياناتها فوراً (تُستدعى داخل الـ WebSocket Handler لبثها للطرف الآخر)
INSERT INTO private_messages (
    room_id,
    sender_id,
    message_text
) VALUES ($1, $2, TRIM($3))
RETURNING id, room_id, sender_id, message_text, is_read, created_at;

-- name: GetMessageByID :one
-- جلب تفاصيل رسالة واحدة محددة (مفيدة لمعالجة خلفية إشعارات الـ Push Notifications)
SELECT id, room_id, sender_id, message_text, is_read, created_at
FROM private_messages
WHERE id = $1;

-- name: UpdateMessageSecure :one
-- ميزة تعديل الرسالة (Edit Message): قيد أمان يمنع التعديل إلا من المرسل الفعلي ($2) مع إرجاع البيانات المحدثة
UPDATE private_messages
SET message_text = TRIM($3)
WHERE id = $1 AND sender_id = $2
RETURNING id, room_id, sender_id, message_text, is_read, created_at;

-- name: DeleteMessageSecure :exec
-- ميزة التراجع عن الإرسال (Unsend/Delete Message): قيد أمان صارم يمنع أي مستخدم من حذف رسالة لم يقم هو بإرسالها بنفسه
DELETE FROM private_messages
WHERE id = $1 AND sender_id = $2;


-- ====================================================================================
-- 2. جلب سجل المحادثات المتطور والبحث (Cursor Pagination & Chat History)
-- ====================================================================================

-- name: ListRoomMessagesWithCursor :many
-- كويري شاشة المحادثة الذهبي (Cursor-Based Pagination):
-- في تطبيقات الشات الاحترافية، لا نستخدم OFFSET لأنه يتسبب بتكرار الرسائل أو إسقاطها عند وصول رسائل جديدة أثناء التمرير.
-- هنا نستخدم معرف الرسالة (Message ID) كمؤشر لجلب الرسائل الأقدم تصاعدياً، مدمجة (JOIN) مع بيانات المرسل لتقليل طلبات قاعدة البيانات.
SELECT 
    pm.id AS message_id, pm.room_id, pm.message_text, pm.is_read, pm.created_at AS message_time,
    u.id AS sender_id, u.username AS sender_username, u.name AS sender_name
FROM private_messages pm
INNER JOIN users u ON pm.sender_id = u.id
WHERE pm.room_id = $1
  AND ($2::bigint = 0 OR pm.id < $2) -- إذا مررنا 0 يجلب الأحدث، وإذا مررنا ID يجلب الرسائل الأقدم منه (Scroll Up)
ORDER BY pm.id DESC
LIMIT $3;


-- name: SearchMessagesInRoom :many
-- ميزة البحث الاحترافي: البحث النصي الذكي (Fuzzy Search) داخل غرفة محادثة معينة فقط، 
-- لتمكين المستخدم من العثور على كلمة معينة في أرشيف الشات مع دعم الـ Pagination
SELECT 
    pm.id AS message_id, pm.room_id, pm.message_text, pm.is_read, pm.created_at AS message_time,
    u.id AS sender_id, u.username AS sender_username, u.name AS sender_name
FROM private_messages pm
INNER JOIN users u ON pm.sender_id = u.id
WHERE pm.room_id = $1 
  AND pm.message_text ILIKE '%' || $2 || '%'
ORDER BY pm.id DESC
LIMIT $3 OFFSET $4;


-- ====================================================================================
-- 3. إدارة حالات القراءة والعدادات (Read Receipts & Inbox Badges)
-- ====================================================================================

-- name: MarkAllRoomMessagesAsRead :exec
-- كويري تحديث حالة القراءة الذكي: بمجرد دخول المستخدم ($2) إلى الغرفة ($1)، تتحول جميع الرسائل الواردة إليه إلى "مقروءة".
-- الكويري يستثني تلقائياً الرسائل التي قام المستخدم بإرسالها بنفسه (sender_id != $2) لضمان عدم تلاعب النظام بالبيانات.
UPDATE private_messages
SET is_read = TRUE
WHERE room_id = $1 
  AND sender_id != $2 
  AND is_read = FALSE;

-- name: MarkMultipleMessagesAsRead :exec
-- تحديث الدفعات الجماعية (Batch Update): تحويل مصفوفة من معرفات الرسائل إلى "مقروءة" بطلب واحد عالي الكفاءة
UPDATE private_messages
SET is_read = TRUE
WHERE id = ANY($1::bigint[]) 
  AND sender_id != $2;

-- name: CountUnreadMessagesInRoom :one
-- حساب عدد الرسائل غير المقروءة الموجهة للمستخدم الحالي ($2) داخل غرفة محددة ($1)
-- (يُستخدم لعرض رقم الإشعار الأحمر الصغير بجانب اسم الصديق في قائمة المحادثات)
SELECT COUNT(*)::bigint
FROM private_messages
WHERE room_id = $1
  AND sender_id != $2
  AND is_read = FALSE;


-- ====================================================================================
-- 4. معاينات وتحديثات قائمة صندوق الوارد (Inbox Previews)
-- ====================================================================================

-- name: GetRoomLatestMessagePreview :one
-- كويري القائمة الرئيسية (Inbox Preview): يجلب أحدث رسالة أرسلت في الغرفة (نصها، وقتها، حالة قراءتها، واسم مرسلها)
-- لعرضها تحت اسم المستخدم في القائمة الجانبية للتطبيق مثل تطبيقات المراسلة العالمية
SELECT 
    pm.id AS message_id, pm.room_id, pm.message_text, pm.is_read, pm.created_at,
    u.id AS sender_id, u.username AS sender_username, u.name AS sender_name
FROM private_messages pm
INNER JOIN users u ON pm.sender_id = u.id
WHERE pm.room_id = $1
ORDER BY pm.id DESC
LIMIT 1;