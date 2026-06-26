-- ====================================================================================
-- 1. العمليات الأساسية وإدارة المنشورات بوضع الحماية الصارم (Secure Post CRUD Engine)
-- ====================================================================================

-- name: CreatePost :one
-- إنشاء منشور جديد وتصفير العدادات تلقائياً مع إرجاع كامل بيانات الصف لحقنها في الواجهة فوراً
INSERT INTO posts (
    user_id,
    title,
    description,
    url
) VALUES (
    $1,
    TRIM($2),
    TRIM($3),
    NULLIF(TRIM($4), '') -- حماية: تحويل الروابط الفارغة إلى NULL تلقائياً
)
RETURNING id, user_id, title, description, url, comments_count, likes_count, hates_count, shares_count, saves_count, point, created_at;

-- name: GetPostDetailedByID :one
-- جلب تفاصيل منشور محدد مدمجاً (JOIN) مع بيانات كاتبه (الاسم، اليوزر) بطلب واحد فائق السرعة
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at AS post_created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE p.id = $1
LIMIT 1;

-- name: GetPostDetailedWithViewerContext :one
-- كويري التفاصيل الذهبي (Single Post View): يجلب بيانات المنشور والكاتب، وبنفس الوقت يتحقق 
-- مما إذا كان المستخدم الحالي الممرر معرفه ($2) قد قام بعمل (LIKE) أو (HATE) لهذا المنشور أم لا!
-- (مهم جداً لإضاءة أزرار التفاعل باللون الأزرق أو الأحمر فور فتح المنشور)
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at AS post_created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name,
    COALESCE((SELECT pr.reaction_type FROM post_reactions pr WHERE pr.post_id = p.id AND pr.user_id = $2), '') AS viewer_reaction
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE p.id = $1
LIMIT 1;

-- name: UpdatePostSecure :one
-- ميزة تعديل المنشور (Edit Post): قيد أمان صارم يمنع التعديل إلا إذا كان المستخدم الحالي ($2) هو الكاتب الفعلي
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
-- 2. محركات الخلاصات اللانهائية الذكية (Advanced Feed Engines - Contextual Cursor Pagination)
-- ====================================================================================

-- name: ListPersonalizedHomeFeedWithViewerContext :many
-- كويري الصفحة الرئيسية الأقوى (Timeline Feed):
-- 1. يجلب منشورات الأشخاص الذين يتابعهم المستخدم ($1) فقط.
-- 2. يدعم الـ Cursor Pagination لضمان الانسيابية والسرعة (p.id < $2).
-- 3. يحقن حالة تفاعل المستخدم الحالي ($1) مع كل منشور (viewer_reaction) لترسم الأزرار متفاعلة وجاهزة في الـ List View!
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at AS post_created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name,
    COALESCE((SELECT pr.reaction_type FROM post_reactions pr WHERE pr.post_id = p.id AND pr.user_id = $1), '') AS viewer_reaction
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE p.user_id IN (SELECT following_id FROM follows WHERE follower_id = $1)
  AND ($2::bigint = 0 OR p.id < $2)
ORDER BY p.id DESC
LIMIT $3;

-- name: ListUserProfilePostsWithCursor :many
-- شاشة الملف الشخصي (Profile Feed): جلب منشورات مستخدم معين ($1) مع الترتيب التنازلي والـ Cursor Pagination
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.point, p.created_at
FROM posts p
WHERE p.user_id = $1
  AND ($2::bigint = 0 OR p.id < $2)
ORDER BY p.id DESC
LIMIT $3;

-- name: ListGlobalRecentFeedWithCursor :many
-- خلاصة أحدث المنشورات العامة (Global / Explore Recent Feed): يجلب أحدث المنشورات على مستوى المنصة بأكملها
-- مع دمج سياق المشاهد الحالي ($1) لمعرفة تفاعلاته ودعم التمرير اللانهائي (Cursor).
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at AS post_created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name,
    COALESCE((SELECT pr.reaction_type FROM post_reactions pr WHERE pr.post_id = p.id AND pr.user_id = $1), '') AS viewer_reaction
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE ($2::bigint = 0 OR p.id < $2)
ORDER BY p.id DESC
LIMIT $3;

-- name: ListTrendingPostsFeed :many
-- قسم المنشورات الشائعة (Trending Feed): ترتيب عالمي للمنشورات الأكثر تفاعلاً وشهرة بناءً على حقل النقاط (point) الأعلى
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
ORDER BY p.point DESC, p.id DESC
LIMIT $1 OFFSET $2;

-- name: ListMostDiscussedPostsFeed :many
-- خلاصة النقاشات الساخنة (Most Discussed Feed): ترتيب المنشورات حسب أكثرها استقبالاً للتعليقات (comments_count)
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.point, p.created_at,
    u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
ORDER BY p.comments_count DESC, p.id DESC
LIMIT $1 OFFSET $2;


-- ====================================================================================
-- 3. سجلات تفاعلات المستخدم التاريخية للمنشورات (User Post Interaction History)
-- ====================================================================================

-- name: ListPostsLikedByUserWithCursor :many
-- شاشة "المنشورات التي أعجبتني": جلب كافة المنشورات التي قام مستخدم معين ($1) بالإعجاب بها عبر جدول التفاعلات
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.point, p.created_at,
    u.username AS author_username, u.name AS author_name
FROM post_reactions pr
INNER JOIN posts p ON pr.post_id = p.id
INNER JOIN users u ON p.user_id = u.id
WHERE pr.user_id = $1 AND pr.reaction_type = 'LIKE'
  AND ($2::bigint = 0 OR p.id < $2)
ORDER BY pr.created_at DESC
LIMIT $3;

-- name: ListPostsHatedByUserWithCursor :many
-- شاشة "المنشورات التي لم تعجبني": جلب كافة المنشورات التي تفاعل معها مستخدم معين ($1) بـ HATE
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.hates_count, p.point, p.created_at,
    u.username AS author_username, u.name AS author_name
FROM post_reactions pr
INNER JOIN posts p ON pr.post_id = p.id
INNER JOIN users u ON p.user_id = u.id
WHERE pr.user_id = $1 AND pr.reaction_type = 'HATE'
  AND ($2::bigint = 0 OR p.id < $2)
ORDER BY pr.created_at DESC
LIMIT $3;

-- name: ListPostsCommentedOnByUser :many
-- جلب المنشورات الفريدة (DISTINCT) التي قام المستخدم ($1) بترك تعليق عليها مسبقاً (سجل النشاط النصي)
SELECT DISTINCT ON (p.id)
    p.id AS post_id, p.title, p.description, p.created_at,
    u.username AS author_username
FROM comments c
INNER JOIN posts p ON c.post_id = p.id
INNER JOIN users u ON p.user_id = u.id
WHERE c.user_id = $1
ORDER BY p.id DESC
LIMIT $2 OFFSET $3;


-- ====================================================================================
-- 4. محرك البحث المتقدم والفلترة (Dynamic Criteria Search Engine)
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
-- 5. إدارة العدادات الذرية وحماية نقاط النظام (Safe Atomic Counters Operations)
-- ====================================================================================

-- name: UpdatePostPoints :exec
-- نظام احتساب خوارزمية المنشور: زيادة نقاط المنشور أو إنقاصها برمجياً (عند حدوث لايك، تعليق، أو شير)
UPDATE posts SET point = point + $2 WHERE id = $1;

-- name: IncrementPostLikesCount :exec
UPDATE posts SET likes_count = likes_count + 1 WHERE id = $1;

-- name: DecrementPostLikesCount :exec
UPDATE posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = $1;

-- name: IncrementPostComments :exec
UPDATE posts SET comments_count = comments_count + 1 WHERE id = $1;

-- name: DecrementPostComments :exec
UPDATE posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = $1;

-- name: IncrementPostHatesCount :exec
UPDATE posts SET hates_count = hates_count + 1 WHERE id = $1;

-- name: DecrementPostHatesCount :exec
UPDATE posts SET hates_count = GREATEST(0, hates_count - 1) WHERE id = $1;

-- name: IncrementPostShares :exec
UPDATE posts SET shares_count = shares_count + 1 WHERE id = $1;

-- name: IncrementPostSaves :exec
UPDATE posts SET saves_count = saves_count + 1 WHERE id = $1;

-- name: DecrementPostSaves :exec
UPDATE posts SET saves_count = GREATEST(0, saves_count - 1) WHERE id = $1;


-- ====================================================================================
-- 6. استعلامات مراجعة وتدقيق ومزامنة العدادات (Counters Audit & Integrity Sync)
-- ====================================================================================

-- name: AuditPostActualCounters :one
-- كويري فحص النزاهة (Integrity Audit): يقوم بحساب الأعداد الحقيقية (اللايكات والتعليقات والـ Hates) 
-- مباشرة من جداول التفاعلات الأساسية لمقارنتها مع العدادات المخزنة في جدول الـ posts في حال حدوث Desync.
SELECT 
    p.id AS post_id,
    p.likes_count AS cached_likes,
    p.hates_count AS cached_hates,
    p.comments_count AS cached_comments,
    (SELECT COUNT(*)::int FROM post_reactions WHERE post_id = p.id AND reaction_type = 'LIKE') AS actual_likes,
    (SELECT COUNT(*)::int FROM post_reactions WHERE post_id = p.id AND reaction_type = 'HATE') AS actual_hates,
    (SELECT COUNT(*)::int FROM comments WHERE post_id = p.id) AS actual_comments
FROM posts p
WHERE p.id = $1;

-- name: SynchronizePostCounters :exec
-- كويري الإصلاح والمزامنة الذاتية (Self-Healing Query)
UPDATE posts
SET 
    likes_count = (SELECT COUNT(*)::int FROM post_reactions WHERE post_id = posts.id AND reaction_type = 'LIKE'),
    hates_count = (SELECT COUNT(*)::int FROM post_reactions WHERE post_id = posts.id AND reaction_type = 'HATE'),
    comments_count = (SELECT COUNT(*)::int FROM comments WHERE post_id = posts.id)
WHERE posts.id = $1; -- تم التعديل هنا صراحة لمنع الـ Ambiguity


-- ====================================================================================
-- 7. العمليات الجماعية عالية الأداء والتحليلات (Batch API Operations & Analytics)
-- ====================================================================================

-- name: BatchGetPostsByIDs :many
-- جلب مصفوفة كاملة من المنشورات بطلب واحد (Single Round-Trip)
-- يُستخدم عند جلب قائمة المفضلة المحفوظة للمستخدم، أو المنشورات المرتبطة بالإشعارات المستلمة.
SELECT 
    p.id AS post_id, p.title, p.description, p.url, 
    p.comments_count, p.likes_count, p.hates_count, p.shares_count, p.saves_count, p.point, p.created_at,
    u.id AS author_id, u.username AS author_username, u.name AS author_name
FROM posts p
INNER JOIN users u ON p.user_id = u.id
WHERE p.id = ANY($1::bigint[])
ORDER BY ARRAY_POSITION($1::bigint[], p.id);

-- name: GetPlatformGlobalPostStats :one
-- لوحة تحليلات المنصة (Admin Global Analytics Dashboard):
-- يعطيك إحصائيات عامة عن المنشورات (إجمالي عدد المنشورات، مجموع اللايكات، متوسط نقاط المنشورات) لمراقبة نشاط التطبيق.
SELECT 
    COUNT(*)::bigint AS total_posts_created,
    COALESCE(SUM(likes_count), 0)::bigint AS total_platform_likes,
    COALESCE(SUM(comments_count), 0)::bigint AS total_platform_comments,
    COALESCE(AVG(point), 0.0)::float AS average_posts_points
FROM posts;