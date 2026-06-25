-- 1. جدول المستخدمين (users)
CREATE TABLE users (
    user_id VARCHAR(50) PRIMARY KEY,       -- المعرف الفريد للمستخدم (البرايمري كيه)
    username VARCHAR(50) UNIQUE NOT NULL,  -- اسم المستخدم (الإنجليزي الذي لا يتكرر)
    password TEXT ,                -- كلمة السر (يفضل تخزينها دائماً كـ Hash مشفر)
    followers_count INT DEFAULT 0 NOT NULL, -- عدد المتابعين
    following_count INT DEFAULT 0 NOT NULL, -- عدد اللي يتابعهم
    views_count INT DEFAULT 0 NOT NULL,     -- عدد المشاهدين الإجمالي للحساب
    likes_count INT DEFAULT 0 NOT NULL     -- عدد اللايكات كاملة للمستخدم
);

-- 2. جدول المنشورات (posts)
CREATE TABLE posts (
    user_id VARCHAR(50) NOT NULL,           -- المعرف الخاص بالمستخدم (يربط البوست بصاحبه)
    post_id INT NOT NULL,                  -- الرقم التسلسلي للبوست الخاص بهذا المستخدم
    title VARCHAR(50) NOT NULL,            -- عنوان البوست (كحد أقصى 50 حرف)
    content TEXT NOT NULL,                 -- محتوى البوست (يتسع لـ 800 حرف وأكثر)
    likes_count INT DEFAULT 0 NOT NULL,    -- عدد اللايكات للبوست
    dislikes_count INT DEFAULT 0 NOT NULL, -- عدد الديسلايك
    comments_count INT DEFAULT 0 NOT NULL, -- عدد التعليقات
    views_count INT DEFAULT 0 NOT NULL,    -- عدد المشاهدات للبوست
    
    -- 💡 هنا المفتاح المركب (Composite Primary Key) الذي يجمع بين اليوزر والبوست
    PRIMARY KEY (user_id, post_id),
    
    -- ربط العلاقة بجدول المستخدمين (إذا حُذف المستخدم تحذف بوستاته تلقائياً لتنظيف الداتابيز)
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);