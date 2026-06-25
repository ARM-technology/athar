-- ====================================================================================
-- 1. إدارة المنشورات بضوابط أمنية صارمة (Secure Content Management CRUD)
-- ====================================================================================

-- name: CreatePost :one
-- إنشاء منشور جديد وتصفير العدادات تلقائياً مع إرجاع كامل بيانات الصف فوراً لحقنها في الواجهة
INSERT INTO posts (
    user_id,
    title,
    description,
    url
) VALUES (
    $1,
    TRIM($2),
    TRIM($3),
    NULLIF(TRIM($4), '') -- حماية: تحويل الروابط الفارغة أو المليئة بالفراغات إلى NULL تلقائياً
)
RETURNING id, user_id, title, description, url, comments_count, likes_count, hates_count, shares_count, saves_count, point, created_at;

-- name: GetPostDetailedByID :one
-- جلب تفاصيل منشور محدد مدمجاً (JOIN) مع بيانات كاتبه (الاسم، اليوزر) بطلب واحد فائق السرعة
-- لمنع معضلة الـ N+1 Query الشائعة في السيرفرات الناشئة
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at AS post_created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE p.id = $1
LIMIT 1;

-- name: UpdatePostSecure :one
-- ميزة تعديل المنشور (Edit Post): قيد أمان صارم يمنع التعديل إلا إذا كان المستخدم الحالي ($2) هو الكاتب الفعلي للمنشور
UPDATE posts
SET
    title = TRIM($3),
    description = TRIM($4),
    url = NULLIF(TRIM($5), '')
WHERE id = $1 AND user_id = $2
RETURNING id, user_id, title, description, url, created_at;

-- name: DeletePostSecure :exec
-- ميزة حذف المنشور نهائياً: قيد أمان صارم يمنع أي مستخدم من تزوير الطلبات وحذف منشورات غيره
DELETE FROM posts
WHERE id = $1 AND user_id = $2;


-- ====================================================================================
-- 2. مخازن الخلاصات الذكية والجدول الزمني (Advanced Feeds & Keyset/Cursor Pagination)
-- ====================================================================================

-- name: ListPersonalizedHomeFeedWithCursor :many
-- كويري الصفحة الرئيسية الذهبي للمنصة (Personalized Timeline Feed):
-- يجلب المنشورات المخصصة للمستخدم الحالي ($1) وهي المنشورات المكتوبة بواسطة الأشخاص الذين يتابعهم فقط!
-- يعتمد على الـ Cursor Pagination (عبر شرط p.id < $2) لضمان انسيابية التصفح اللانهائي دون تكرار المحتوى عند التمرير للأعلى أو الأسفل.
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at AS post_created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE p.user_id IN (SELECT following_id FROM follows WHERE follower_id = $1) -- جلب منشورات من يتابعهم فقط
  AND ($2::bigint = 0 OR p.id < $2) -- إذا مررنا 0 يجلب الأحدث، وإذا مررنا ID يجلب الأقدم منه (Scroll Down)
ORDER BY p.id DESC
LIMIT $3;

-- name: ListUserProfilePostsWithCursor :many
-- شاشة الملف الشخصي (Profile Feed): جلب منشورات مستخدم معين ($1) مع الترتيب التنازلي والـ Cursor Pagination
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at
FROM posts p
WHERE p.user_id = $1
  AND ($2::bigint = 0 OR p.id < $2)
ORDER BY p.id DESC
LIMIT $3;

-- name: ListTrendingPostsFeed :many
-- قسم المنشورات الشائعة (Trending/Explore Feed): ترتيب عالمي للمنشورات الأكثر تفاعلاً وشهرة بناءً على حقل النقاط (point)
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at,
    u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
ORDER BY p.point DESC, p.id DESC
LIMIT $1 OFFSET $2;


-- ====================================================================================
-- 3. محرك البحث المتقدم متعدد الحالات (Dynamic Criteria Search Engine)
-- ====================================================================================

-- name: SearchPostsAdvanced :many
-- كويري البحث الذكي والشامل للمنصة: يبحث بالنص الجزئي (Fuzzy) في (العنوان والوصف)، 
-- ويقبل الفلترة الاختيارية لحساب مستخدم معين، ويشترط حداً أدنى من النقاط، مع دعم كامل للـ Pagination السريع.
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at,
    u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE ($1::text = '' OR p.title ILIKE '%' || $1 || '%' OR p.description ILIKE '%' || $1 || '%')
  AND ($2::bigint = 0 OR p.user_id = $2)
  AND (p.point >= $3::int)
ORDER BY p.id DESC
LIMIT $4 OFFSET $5;


-- ====================================================================================
-- 4. إدارة العدادات الذرية وحماية نقاط النظام (Safe Atomic Counters Operations)
-- ====================================================================================

-- name: UpdatePostPoints :exec
-- نظام احتساب خوارزمية المنشور: زيادة نقاط المنشور أو إنقاصها برمجياً (عند حدوث لايك، تعليق، أو شير)
UPDATE posts 
SET point = point + $2 
WHERE id = $1;

-- name: IncrementPostLikes :exec
UPDATE posts SET likes_count = likes_count + 1 WHERE id = $1;

-- name: DecrementPostLikes :exec
-- إنقاص عداد الإعجابات بمقدار 1 مع حماية لمنع نزول العداد تحت الصفر نهائياً
UPDATE posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = $1;

-- name: IncrementPostComments :exec
UPDATE posts SET comments_count = comments_count + 1 WHERE id = $1;

-- name: DecrementPostComments :exec
UPDATE posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = $1;

-- name: IncrementPostHates :exec
UPDATE posts SET hates_count = hates_count + 1 WHERE id = $1;

-- name: DecrementPostHates :exec
UPDATE posts SET hates_count = GREATEST(0, hates_count - 1) WHERE id = $1;

-- name: IncrementPostShares :exec
UPDATE posts SET shares_count = shares_count + 1 WHERE id = $1;

-- name: IncrementPostSaves :exec
UPDATE posts SET saves_count = saves_count + 1 WHERE id = $1;

-- name: DecrementPostSaves :exec
UPDATE posts SET saves_count = GREATEST(0, saves_count - 1) WHERE id = $1;


-- ====================================================================================
-- 5. العمليات الجماعية عالية الأداء للـ API (High-Concurrency Batch Queries)
-- ====================================================================================

-- name: BatchGetPostsByIDs :many
-- كويري الأداء العالي: جلب مصفوفة كاملة من المنشورات بطلب واحد (Single Round-Trip)
-- يُستخدم عند جلب قائمة المفضلات الحفوظة (Bookmarks) للمستحدم، أو المنشورات المرتبطة بالإشعارات المستلمة.
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.point, p.created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE p.id = ANY($1::bigint[])
ORDER BY ARRAY_POSITION($1::bigint[], p.id); -- الحفاظ التام على نفس ترتيب الـ IDs الممررة في الطلب