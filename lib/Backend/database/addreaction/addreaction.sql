-- ====================================================================================
-- 1. العمليات الأساسية للتفاعل (Core Reaction CRUD)
-- ====================================================================================

-- name: UpsertReaction :one
-- إضافة تفاعل أو تحديثه تلقائياً إذا كان موجوداً مسبقاً (حل مشكلة الـ Conflict)
INSERT INTO post_reactions (
    post_id,
    user_id,
    reaction_type
)
VALUES ($1, $2, $3)
ON CONFLICT (post_id, user_id) 
DO UPDATE SET reaction_type = EXCLUDED.reaction_type
RETURNING *;

-- name: RemoveReaction :exec
-- حذف التفاعل نهائياً عند إلغائه
DELETE FROM post_reactions
WHERE post_id = $1
AND user_id = $2;

-- name: GetReaction :one
-- جلب تفاعل مستخدم محدد على منشور محدد
SELECT post_id, user_id, reaction_type, created_at
FROM post_reactions
WHERE post_id = $1 AND user_id = $2;


-- ====================================================================================
-- 2. كويريات جلب البيانات المتقدمة والخلاصة (Feed & Batch Operations)
-- ====================================================================================

-- name: GetReactionsForFeedByPostIDs :many
-- كويري جوهري للـ Feed: يمرر له مصفوفة من أرقام المنشورات ومعرف المستخدم الحالي،
-- فيجلب لك كل تفاعلات المستخدم عليها بطلب واحد فقط من قاعدة البيانات لتلوين الأزرار في الواجهة.
SELECT post_id, reaction_type
FROM post_reactions
WHERE user_id = $1 
AND post_id = ANY($2::bigint[]);

-- name: GetPostWithReactionStatus :one
-- كويري ضخم يجلب تفاصيل المنشور بالكامل، مع بيانات الكاتب (Author)، 
-- بالإضافة إلى حالة تفاعل المستخدم الحالي (هل وضع لايك أو هيت أم لم يتفاعل أصلاً) في طلب واحد ذكي.
SELECT 
    p.id AS post_id,
    p.title,
    p.description,
    p.url,
    p.likes_count,
    p.hates_count,
    p.comments_count,
    p.shares_count,
    p.saves_count,
    p.point AS post_points,
    p.created_at AS post_created_at,
    u.id AS author_id,
    u.username AS author_username,
    u.name AS author_name,
    COALESCE(pr.reaction_type, '') AS current_user_reaction
FROM posts p
INNER JOIN users u ON p.user_id = u.id
LEFT JOIN post_reactions pr ON pr.post_id = p.id AND pr.user_id = $2
WHERE p.id = $1;


-- ====================================================================================
-- 3. كويريات العدادات وقوائم المستخدمين (Metrics & Users Lists)
-- ====================================================================================

-- name: GetPostReactionCountsLive :one
-- جلب أرقام التفاعلات الحية مباشرة من جدول التفاعلات لغرض المطابقة الحية وضمان دقة البيانات
SELECT 
    COUNT(*) FILTER (WHERE reaction_type = 'LIKE') AS live_likes_count,
    COUNT(*) FILTER (WHERE reaction_type = 'HATE') AS live_hates_count
FROM post_reactions
WHERE post_id = $1;

-- name: ListUsersWhoReacted :many
-- جلب قائمة المستخدمين الذين تفاعلوا مع منشور معين (مثلاً لمعرفة من ضغط لايك)، 
-- مصفية حسب نوع التفاعل ومع دعم كامل للتصفح وعرض البيانات (Pagination) عبر Limit و Offset.
SELECT 
    u.id AS user_id,
    u.username,
    u.name,
    u.city,
    pr.reaction_type,
    pr.created_at AS reacted_at
FROM post_reactions pr
INNER JOIN users u ON pr.user_id = u.id
WHERE pr.post_id = $1 
AND ($2::varchar = '' OR pr.reaction_type = $2)
ORDER BY pr.created_at DESC
LIMIT $3 OFFSET $4;


-- ====================================================================================
-- 4. كويريات المزامنة والتحديث الذري للعدادات (Atomic Counters Synchronization)
-- ====================================================================================

-- name: IncrementPostLikes :exec
UPDATE posts SET likes_count = likes_count + 1 WHERE id = $1;

-- name: DecrementPostLikes :exec
UPDATE posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = $1;

-- name: IncrementPostHates :exec
UPDATE posts SET hates_count = hates_count + 1 WHERE id = $1;

-- name: DecrementPostHates :exec
UPDATE posts SET hates_count = GREATEST(0, hates_count - 1) WHERE id = $1;

-- name: SyncPostCounters :exec
-- كويري طوارئ/صيانة: يقوم بإعادة حساب كافة التفاعلات وتحديث جدول المنشورات تلقائياً لمنع أي تضارب بالعدادات الكاش
UPDATE posts p
SET 
    likes_count = (SELECT COUNT(*) FROM post_reactions WHERE post_id = p.id AND reaction_type = 'LIKE'),
    hates_count = (SELECT COUNT(*) FROM post_reactions WHERE post_id = p.id AND reaction_type = 'HATE')
WHERE p.id = $1;