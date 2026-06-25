-- ====================================================================================
-- 1. عمليات المتابعة وإلغائها بضوابط أمنية (Secure Follow & Unfollow Actions)
-- ====================================================================================

-- name: FollowUserSecure :exec
-- إجراء متابعة مستخدم: يحتوي على حزام أمان مزدوج!
-- 1. شرط (WHERE $1 != $2) يمنع تماماً ثغرة أن يقوم المستخدم بمتابعة نفسه برمجياً.
-- 2. جملة (ON CONFLICT DO NOTHING) تمنع السيرفر من الانهيار أو إرجاع خطأ (500) في حال قام المستخدم بالضغط على زر المتابعة مرتين متتاليتين بسرعة.
INSERT INTO follows (follower_id, following_id)
SELECT $1::bigint, $2::bigint
WHERE $1::bigint != $2::bigint
ON CONFLICT (follower_id, following_id) DO NOTHING;

-- name: UnfollowUserSecure :exec
-- إلغاء متابعة مستخدم بشكل مباشر وآمن
DELETE FROM follows
WHERE follower_id = $1 AND following_id = $2;


-- ====================================================================================
-- 2. فحص الحالات والتحقق الجماعي الفيدرالي (Batch & Single Status Checking)
-- ====================================================================================

-- name: IsFollowing :one
-- فحص بولياني (True/False) لمعرفة ما إذا كان المستخدم ($1) يتابع المستخدم ($2) (مفيد لحماية بعض الصفحات أو الميزات)
SELECT EXISTS(
    SELECT 1 FROM follows
    WHERE follower_id = $1 AND following_id = $2
) AS is_following;

-- name: BatchCheckFollowingStatus :many
-- كويري الأداء العالي لقوائم الاستكشاف: تمرر له معرف المستخدم الحالي ($1) ومصفوفة من معرفات المستخدمين الآخرين ($2) (مثال: [14, 55, 89])
-- ليعيد لك فقط المعرفات التي تتابعها أنت بالفعل من بين هذه المصفوفة.
-- في كود Go، يمكنك تحويل النتيجة إلى Map لتعليق حالة أزرار (Follow/Unfollow) في أجزاء من الملي ثانية بطلب واحد بدلاً من إرهاق السيرفر بطلب لكل يوزر!
SELECT following_id
FROM follows
WHERE follower_id = $1 
  AND following_id = ANY($2::bigint[]);


-- ====================================================================================
-- 3. جلب القوائم التفصيلية مدمجة بسياق العميل (Contextual Followers/Following Lists)
-- ====================================================================================

-- name: ListFollowersDetailed :many
-- كويري شاشة "المتابِعون" (Followers List): يجلب قائمة الأشخاص الذين يتابعون المستخدم ($1).
-- الميزة الاحترافية: يدمج (JOIN) بيانات بروفايلاتهم، وبنفس الوقت يفحص عبر كويري فرعي ذكي ما إذا كان المستخدم الحالي الذي يشاهد القائمة ($2)
-- يتابع هؤلاء الأشخاص أيضاً أم لا (يُرجع الحقل كـ is_followed_by_viewer)، لترسم أزرار المتابعة بدقة متناهية، مع دعم الـ Pagination.
SELECT 
    f.created_at AS followed_at,
    u.id AS user_id,
    u.username,
    u.name,
    u.description,
    EXISTS (
        SELECT 1 FROM follows 
        WHERE follower_id = $2::bigint AND following_id = u.id
    ) AS is_followed_by_viewer
FROM follows f
INNER JOIN users u ON f.follower_id = u.id
WHERE f.following_id = $1::bigint
ORDER BY f.created_at DESC
LIMIT $3 OFFSET $4;

-- name: ListFollowingDetailed :many
-- كويري شاشة "الذين أتابعهم" (Following List): يجلب قائمة الحسابات التي يقوم المستخدم ($1) بمتابعتها.
-- وبنفس الفكرة الاحترافية، يتحقق مما إذا كان المشاهد الحالي للقائمة ($2) يتابعهم أيضاً، لضمان اتساق واجهة المستخدم في كافة أجزاء التطبيق.
SELECT 
    f.created_at AS followed_at,
    u.id AS user_id,
    u.username,
    u.name,
    u.description,
    EXISTS (
        SELECT 1 FROM follows 
        WHERE follower_id = $2::bigint AND following_id = u.id
    ) AS is_followed_by_viewer
FROM follows f
INNER JOIN users u ON f.following_id = u.id
WHERE f.follower_id = $1::bigint
ORDER BY f.created_at DESC
LIMIT $3 OFFSET $4;


-- ====================================================================================
-- 4. عدادات الإحصاء الذرية ونظام الاقتراحات الاجتماعي (Counters & Social Discovery)
-- ====================================================================================

-- name: GetUserFollowStats :one
-- كويري العدادات الموحد: يجلب إجمالي عدد (المتابِعون) وعدد (الذين يتابعهم) المستخدم ($1) في طلب ذري واحد
-- لتحديث عدادات البروفايل فوراً دون الحاجة لكتابة استعلامين منفصلين.
SELECT 
    (SELECT COUNT(*)::bigint FROM follows WHERE following_id = $1) AS followers_count,
    (SELECT COUNT(*)::bigint FROM follows WHERE follower_id = $1) AS following_count;

-- name: DiscoverPeopleToFollow :many
-- محرك الاقتراحات الذكي للمنصة (Social Graph Discovery): "اقترح لي حسابات أتابعها".
-- يحلل هذا الاستعلام سلوك شبكتك؛ فيبحث عن الحسابات التي يتابعها الأشخاص الذين تتابعهم أنت حالياً ($1) (أصدقاء الأصدقاء).
-- يقوم بترتيبهم حسب الأكثر شهرة وعدد المتابعين المشتركين بينكم (mutual_followers_count)، ويستثني تلقائياً:
-- 1. نفسك.
-- 2. أي حساب تتابعه بالفعل.
-- هذا الاستعلام يمنح تطبيقك طابعاً خوارزمياً ذكياً يشبه كبرى المنصات العالمية.
SELECT 
    u.id AS recommended_user_id,
    u.username,
    u.name,
    u.description,
    COUNT(f2.follower_id)::bigint AS mutual_followers_count
FROM follows f1
JOIN follows f2 ON f1.following_id = f2.follower_id
JOIN users u ON f2.following_id = u.id
WHERE f1.follower_id = $1::bigint -- المستخدم الحالي
  AND f2.following_id != $1::bigint -- استبعاد حساب المستخدم نفسه من الاقتراحات
  AND NOT EXISTS (
      SELECT 1 FROM follows 
      WHERE follower_id = $1::bigint AND following_id = u.id
  ) -- استبعاد الحسابات المتابعة مسبقاً
GROUP BY u.id, u.username, u.name, u.description
ORDER BY mutual_followers_count DESC, u.followers DESC
LIMIT $2 OFFSET $3;