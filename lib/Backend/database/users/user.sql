-- ====================================================================================
-- 1. العمليات الأساسية وإدارة الحساب والأمان (Core CRUD & Authentication)
-- ====================================================================================

-- name: CreateUser :one
-- إنشاء حساب مستخدم جديد كلياً مع تصفير العدادات تلقائياً وإرجاع البيانات الأساسية فوراً
INSERT INTO users (
    username,
    password,
    email,
    name,
    description,
    city,
    location,
    birth_date
) VALUES (
    LOWER(TRIM($1)), -- حماية: تحويل اسم المستخدم للأحرف الصغيرة وإزالة الفراغات الزائدة
    $2,
    LOWER(TRIM($3)),
    TRIM($4),
    $5,
    $6,
    $7,
    $8
)
RETURNING id, username, email, name, description, followers, following, views, likes_count, point, posts_count, city, location, birth_date, created_at;

-- name: GetUserByID :one
-- جلب كامل بيانات المستخدم بواسطة المعرف الفريد الداخلي (ID)
SELECT id, username, password, email, name, description, followers, following, views, likes_count, point, posts_count, city, location, birth_date, created_at
FROM users
WHERE id = $1;

-- name: GetUserByUsernameOrEmail :one
-- كويري تسجيل الدخول الاحترافي: جلب بيانات الحساب بفحص مدمج لاسم المستخدم أو البريد الإلكتروني بطلب واحد
SELECT id, username, password, email, name
FROM users
WHERE username = LOWER(TRIM($1)) OR email = LOWER(TRIM($1))
LIMIT 1;

-- name: UpdateUserProfileSecure :one
-- تحديث الملف الشخصي بشكل آمن ومباشر مع إرجاع الصف المحدث لتحديث واجهة المستخدم (UI State)
UPDATE users
SET
    name = TRIM($2),
    description = $3,
    city = $4,
    location = $5,
    birth_date = $6
WHERE id = $1
RETURNING id, username, email, name, description, city, location, birth_date;

-- name: UpdateUserPasswordSecure :exec
-- تحديث كلمة المرور بشكل منفصل لرفع مستوى الحماية والأمان في السيرفر
UPDATE users
SET password = $2
WHERE id = $1;


-- ====================================================================================
-- 2. كويريات جلب القوائم والبحث المتقدم متعدد الحالات (Advanced Dynamic Search & Batch)
-- ====================================================================================

-- name: SearchUsersAdvanced :many
-- كويري البحث الذهبي (Multi-Criteria Filter): كويري مكثف يقبل عدة حالات في نفس الوقت!
-- يبحث بالنص (Fuzzy Search) في (الاسم، اليوزر، الوصف) ويقوم بالفلترة حسب المدينة، ويشترط حداً أدنى من النقاط أو المتابعين
-- إذا تم تمرير قيم فارغة أو صفرية، يتجاهل الكويري الشرط تلقائياً، مع دعم كامل للـ Pagination لضمان سرعة السيرفر
SELECT id, username, name, description, followers, following, views, likes_count, point, posts_count, city, location, created_at
FROM users
WHERE ($1::text = '' OR username ILIKE '%' || $1 || '%' OR name ILIKE '%' || $1 || '%' OR description ILIKE '%' || $1 || '%')
  AND ($2::text = '' OR city ILIKE $2)
  AND (point >= $3::int)
  AND (followers >= $4::int)
ORDER BY point DESC, followers DESC, created_at DESC
LIMIT $5 OFFSET $6;

-- name: BatchGetUsersByIDs :many
-- كويري عالي الأداء لتطبيقات الـ Production: تمرر له مصفوفة IDs (مثال: [5, 12, 90])
-- ليعيد لك بياناتهم كاملة بطلب واحد (Single Round-Trip)، مفيد جداً عند عرض كتاب المنشورات أو قوائم الإعجابات
SELECT id, username, name, description, followers, following, point, posts_count, city
FROM users
WHERE id = ANY($1::bigint[])
ORDER BY ARRAY_POSITION($1::bigint[], id); -- يحافظ على نفس ترتيب الـ IDs الممررة تماماً


-- ====================================================================================
-- 3. أنظمة الاستكشاف ولوحة الصدارة (Discovery & Gamification Leaderboards)
-- ====================================================================================

-- name: GetUsersLeaderboard :many
-- لوحة الصدارة للمنصة: جلب الحسابات الأكثر تفاعلاً وشهرة بناءً على حقل النقاط (point) أو عدد المتابعين مع الـ Pagination
SELECT id, username, name, description, followers, point, posts_count, city
FROM users
ORDER BY point DESC, followers DESC
LIMIT $1 OFFSET $2;

-- name: DiscoverPopularUsersByCity :many
-- نظام الاقتراحات المحلي: جلب وتصفية الحسابات الأكثر شهرة المتواجدة في نفس مدينة المستخدم الحالي لاستكشافهم
SELECT id, username, name, description, followers, point, city
FROM users
WHERE city = $1 AND id != $2
ORDER BY point DESC, followers DESC
LIMIT $3 OFFSET $4;


-- ====================================================================================
-- 4. إدارة العدادات الذرية الذكية (Safe Atomic Counters Operations)
-- ====================================================================================

-- name: IncrementUserViews :exec
-- زيادة عداد مشاهدات الملف الشخصي بشكل ذري (Atomic) لمنع مشكلة تضارب البيانات (Race Conditions) عند تصفح البروفايل
UPDATE users 
SET views = views + 1 
WHERE id = $1;

-- name: UpdateUserPoints :exec
-- التحكم بنقاط المستخدم (Gamification System): مرر قيمة موجبة لزيادة نقاطه (عند النشر/التفاعل) أو سالبة لخصمها
UPDATE users 
SET point = point + $2 
WHERE id = $1;

-- name: IncrementUserFollowers :exec
-- زيادة عدد المتابعين بمقدار 1 للحساب المتلقّي للمتابعة
UPDATE users 
SET followers = followers + 1 
WHERE id = $1;

-- name: DecrementUserFollowers :exec
-- إنقاص عدد المتابعين بمقدار 1 مع حماية برمجية صارمة `GREATEST(0, ...)` تمنع نزول العداد تحت الصفر نهائياً
UPDATE users 
SET followers = GREATEST(0, followers - 1) 
WHERE id = $1;

-- name: IncrementUserFollowing :exec
-- زيادة عدد الحسابات التي يتابعها المستخدم الحالي بمقدار 1
UPDATE users 
SET following = following + 1 
WHERE id = $1;

-- name: DecrementUserFollowing :exec
-- إنقاص عدد الحسابات التي يتابعها المستخدم الحالي بمقدار 1 مع الحماية من الأرقام السالبة
UPDATE users 
SET following = GREATEST(0, following - 1) 
WHERE id = $1;

-- name: IncrementUserPostsCount :exec
-- زيادة عداد المنشورات للمستخدم فور قيامه بنشر محتوى جديد بنجاح
UPDATE users 
SET posts_count = posts_count + 1 
WHERE id = $1;

-- name: DecrementUserPostsCount :exec
-- إنقاص عداد المنشورات عند قيام المستخدم بحذف أحد منشوراته مع ضمان عدم النزول تحت الصفر
UPDATE users 
SET posts_count = GREATEST(0, posts_count - 1) 
WHERE id = $1;