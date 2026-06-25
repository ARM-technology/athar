-- ========================================================
-- 1. استعلامات جدول المستخدمين (Users Management)
-- ========================================================

-- name: CreateUser :one
-- إنشاء مستخدم جديد
INSERT INTO users (user_id, username, password)
VALUES ($1, $2, $3)
RETURNING user_id, username, password, followers_count, following_count, views_count, likes_count;

-- name: GetUserById :one
-- جلب بيانات مستخدم محدد بالـ ID
SELECT user_id, username, password, followers_count, following_count, views_count, likes_count
FROM users
WHERE user_id = $1 LIMIT 1;

-- name: GetUserByUsername :one
-- جلب بيانات مستخدم عن طريق اسم المستخدم (مفيد في تسجيل الدخول)
SELECT user_id, username, password, followers_count, following_count, views_count, likes_count
FROM users
WHERE username = $1 LIMIT 1;

-- name: UpdateUserProfile :exec
-- تحديث اسم المستخدم أو الباسورد
UPDATE users
SET username = $2, password = $3
WHERE user_id = $1;


-- ========================================================
-- 2. استعلامات جدول المنشورات (Posts Management)
-- ========================================================

-- name: GetNextPostId :one
-- يحسب لك الـ post_id القادم لهذا المستخدم تلقائياً
SELECT COALESCE(MAX(post_id), 0) + 1 AS next_post_id
FROM posts
WHERE user_id = $1;

-- name: CreatePost :one
-- إنشاء منشور جديد
INSERT INTO posts (user_id, post_id, title, content)
VALUES ($1, $2, $3, $4)
RETURNING user_id, post_id, title, content, likes_count, dislikes_count, comments_count, views_count;

-- name: GetPostWithAuthor :one
-- يجلب لك البوست مع الـ username حق الكاتب
SELECT 
    p.user_id, p.post_id, p.title, p.content, 
    p.likes_count, p.dislikes_count, p.comments_count, p.views_count,
    u.username AS author_username
FROM posts AS p
JOIN users AS u ON p.user_id = u.user_id
WHERE p.user_id = $1 AND p.post_id = $2 LIMIT 1;

-- name: DeletePost :exec
-- 💡 تم تصحيح الخطأ هنا بإزالة الـ p الزائدة تماماً
DELETE FROM posts
WHERE user_id = $1 AND post_id = $2;


-- ========================================================
-- 3. استعلامات القوائم والـ Feeds (لجلب البيانات للـ ListView)
-- ========================================================

-- name: ListGlobalFeed :many
-- الفيد العام: يجلب كل بوستات التطبيق مجهزة للـ Pagination
SELECT 
    p.user_id, p.post_id, p.title, p.content, 
    p.likes_count, p.dislikes_count, p.comments_count, p.views_count,
    u.username AS author_username
FROM posts AS p
JOIN users AS u ON p.user_id = u.user_id
ORDER BY p.views_count DESC, p.post_id DESC
LIMIT $1 OFFSET $2;

-- name: ListPostsByUser :many
-- صفحة البروفايل: جلب كل بوستات مستخدم معين من الأحدث للأقدم
SELECT 
    p.user_id, p.post_id, p.title, p.content, 
    p.likes_count, p.dislikes_count, p.comments_count, p.views_count,
    u.username AS author_username
FROM posts AS p
JOIN users AS u ON p.user_id = u.user_id
WHERE p.user_id = $1
ORDER BY p.post_id DESC;


-- ========================================================
-- 4. عدادات التفاعل الذكية (Engagement & Counters)
-- ========================================================

-- name: IncrementPostView :exec
UPDATE posts
SET views_count = views_count + 1
WHERE user_id = $1 AND post_id = $2;

-- name: IncrementPostLike :exec
UPDATE posts
SET likes_count = likes_count + 1
WHERE user_id = $1 AND post_id = $2;

-- name: IncrementPostDislike :exec
UPDATE posts
SET dislikes_count = dislikes_count + 1
WHERE user_id = $1 AND post_id = $2;

-- name: IncrementPostCommentCount :exec
UPDATE posts
SET comments_count = comments_count + 1
WHERE user_id = $1 AND post_id = $2;

-- name: FollowUser :exec
UPDATE users
SET following_count = following_count + 1 WHERE user_id = $1;