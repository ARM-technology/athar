-- ====================================================================================
-- 1. العمليات الأساسية وإدارة التعليقات بضوابط أمنية (Secure Comments CRUD)
-- ====================================================================================

-- name: CreateComment :one
-- إضافة تعليق جديد على منشور محدد مع إرجاع كامل البيانات فوراً (مفيدة لبث التعليق لحظياً عبر الـ WebSockets)
INSERT INTO comments (
    post_id,
    user_id,
    content
) VALUES (
    $1,
    $2,
    TRIM($3) -- حماية: إزالة الفراغات الزائدة من بداية ونهاية نص التعليق
)
RETURNING id, post_id, user_id, content, created_at;

-- name: GetCommentByID :one
-- جلب تفاصيل تعليق واحد محدد بواسطة الـ ID الخاص به
SELECT id, post_id, user_id, content, created_at
FROM comments
WHERE id = $1;

-- name: UpdateCommentSecure :one
-- ميزة تعديل التعليق (Edit Comment): قيد أمان صارم جداً يمنع التعديل إلا إذا كان المستخدم الحالي ($2) هو الكاتب الفعلي للتعليق
UPDATE comments
SET content = TRIM($3)
WHERE id = $1 AND user_id = $2
RETURNING id, post_id, user_id, content, created_at;

-- name: DeleteCommentSecure :exec
-- هندسة أمنية متطورة للحذف (Secure Double-Check Delete):
-- في الأنظمة الاحترافية، يُسمح بحذف التعليق في حالتين فقط:
-- 1. أن يكون المستخدم ($2) هو الكاتب الفعلي للتعليق (user_id = $2).
-- 2. أو أن يكون المستخدم ($2) هو صاحب المنشور الأصلي الذي كُتب عليه التعليق (صاحب المنشور يملك سلطة إدارة صفحة منشوره).
DELETE FROM comments
WHERE id = $1 
  AND (
    user_id = $2 
    OR post_id IN (SELECT id FROM posts WHERE user_id = $2)
  );


-- ====================================================================================
-- 2. جلب وتصفح قائمة التعليقات المتقدمة (Advanced Feed & Cursor Pagination)
-- ====================================================================================

-- name: ListPostCommentsDetailed :many
-- الكويري الأساسي لعرض التعليقات تحت المنشور:
-- يجلب التعليقات مدمجة (JOIN) مع بيانات كاتب التعليق (معرفه، اسمه، يوزره) لتجنب الطلبات المتكررة.
-- يعتمد الكويري على الـ Cursor Pagination (عبر الـ ID) لضمان عدم تكرار التعليقات أثناء التمرير، 
-- ويرتبها تصاعدياً (من الأقدم للأحدث) وهو النظام القياسي لسلاسل التعليقات.
SELECT 
    c.id AS comment_id,
    c.post_id,
    c.content AS comment_content,
    c.created_at AS comment_created_at,
    u.id AS author_id,
    u.username AS author_username,
    u.name AS author_name
FROM comments c
INNER JOIN users u ON c.user_id = u.id
WHERE c.post_id = $1
  AND ($2::bigint = 0 OR c.id > $2) -- إذا مررنا 0 يجلب من البداية، وإذا مررنا ID يجلب التعليقات التالية له (Scroll Down)
ORDER BY c.id ASC
LIMIT $3;

-- name: SearchCommentsInPost :many
-- ميزة بحث متقدمة: تمكن صاحب المنشور أو المستخدمين من البحث النصي الذكي (Fuzzy Search) عن كلمة معينة
-- داخل تعليقات منشور محدد فقط، مع جلب بيانات كتابها ودعم الـ Pagination
SELECT 
    c.id AS comment_id,
    c.post_id,
    c.content AS comment_content,
    c.created_at AS comment_created_at,
    u.id AS author_id,
    u.username AS author_username,
    u.name AS author_name
FROM comments c
INNER JOIN users u ON c.user_id = u.id
WHERE c.post_id = $1
  AND c.content ILIKE '%' || $2 || '%'
ORDER BY c.id DESC
LIMIT $3 OFFSET $4;


-- ====================================================================================
-- 3. العمليات الجماعية والإحصائيات (Batch Operations & Analytics Counters)
-- ====================================================================================

-- name: CountCommentsByPostID :one
-- حساب إجمالي عدد التعليقات على منشور معين (يستخدم لتحديث العدادات أو العرض السريع على بطاقة المنشور الخارجي)
SELECT COUNT(*)::bigint
FROM comments
WHERE post_id = $1;

-- name: BatchGetCommentsByIDs :many
-- كويري عالي الأداء لبيئات الضغط العالي: تمرير مصفوفة IDs من التعليقات وجلبها كاملة بطلب واحد (Single Round-Trip)
-- مع الحفاظ التام على ترتيب المعرفات الممررة في الطلب
SELECT 
    c.id AS comment_id, c.post_id, c.content, c.created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name
FROM comments c
INNER JOIN users u ON c.user_id = u.id
WHERE c.id = ANY($1::bigint[])
ORDER BY ARRAY_POSITION($1::bigint[], c.id);