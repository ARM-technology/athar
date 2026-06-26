-- ==========================================
-- اسم الملف: followuser.sql
-- الوصف: جميع استعلامات نظام المتابعة واكتشاف المستخدمين
-- ==========================================

-- name: FollowUser :exec
-- عملية متابعة مستخدم جديد (تمنع التكرار بفضل ON CONFLICT)
INSERT INTO follows (follower_id, following_id, created_at)
VALUES ($1::bigint, $2::bigint, NOW())
ON CONFLICT (follower_id, following_id) DO NOTHING;


-- name: UnfollowUser :exec
-- إلغاء متابعة مستخدم
DELETE FROM follows
WHERE follower_id = $1::bigint AND following_id = $2::bigint;


-- name: CheckFollowStatus :one
-- التحقق من حالة المتابعة (هل المستخدم أ يتابع المستخدم ب؟)
SELECT EXISTS (
    SELECT 1 FROM follows
    WHERE follower_id = $1::bigint AND following_id = $2::bigint
)::boolean AS is_following;


-- name: GetFollowersList :many
-- جلب قائمة المتابِعين (الأشخاص الذين يتابعون مستخدماً معيناً) مع دعم الترقيم الصفحي
SELECT 
    u.id AS user_id,
    u.username,
    u.name,
    u.description,
    u.followers AS total_followers,
    f.created_at AS followed_at
FROM follows f
INNER JOIN users u ON f.follower_id = u.id
WHERE f.following_id = $1::bigint
ORDER BY f.created_at DESC
LIMIT $2::int OFFSET $3::int;


-- name: GetFollowingList :many
-- جلب قائمة المتابَعين (الأشخاص الذين يقوم هذا المستخدم بمتابعتهم) مع دعم الترقيم الصفحي
SELECT 
    u.id AS user_id,
    u.username,
    u.name,
    u.description,
    u.followers AS total_followers,
    f.created_at AS followed_at
FROM follows f
INNER JOIN users u ON f.following_id = u.id
WHERE f.follower_id = $1::bigint
ORDER BY f.created_at DESC
LIMIT $2::int OFFSET $3::int;


-- name: GetFollowCounters :one
-- حساب أعداد المتابِعين والمتابَعين بشكل ديناميكي ودقيق للمستخدم
SELECT 
    (SELECT COUNT(*)::bigint FROM follows WHERE follower_id = $1::bigint) AS following_count,
    (SELECT COUNT(*)::bigint FROM follows WHERE following_id = $1::bigint) AS followers_count;


-- name: DiscoverPeopleToFollow :many
-- محرك الاقتراحات الذكي للمنصة (اقتراح أصدقاء الأصدقاء بناءً على المتابعين المشتركين)
SELECT 
    u.id AS recommended_user_id,
    u.username,
    u.name,
    u.description,
    COUNT(f2.follower_id)::bigint AS mutual_followers_count
FROM follows f1
INNER JOIN follows f2 ON f1.following_id = f2.follower_id
INNER JOIN users u ON f2.following_id = u.id
WHERE f1.follower_id = $1::bigint
  AND u.id != $1::bigint
  AND NOT EXISTS (
      SELECT 1 FROM follows f3
      WHERE f3.follower_id = $1::bigint AND f3.following_id = u.id
  )
GROUP BY u.id, u.username, u.name, u.description, u.followers
ORDER BY mutual_followers_count DESC, u.followers DESC
LIMIT $2::int OFFSET $3::int;