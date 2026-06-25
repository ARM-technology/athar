-- 1. جدول المستخدمين (USERS)
CREATE DATABASE athar_db WITH ENCODING='UTF8';

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(24) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(60),
    name VARCHAR(45) NOT NULL,
    description VARCHAR(120),
    followers INT DEFAULT 0,
    following INT DEFAULT 0,
    views INT DEFAULT 0,
    likes_count INT DEFAULT 0, -- تم تعديل الاسم لتجنب الكلمة المحجوزة LIKE
    point INT DEFAULT 0,
    posts_count INT DEFAULT 0, -- تم تعديل الاسم لتجنب الكلمة المحجوزة POST
    city VARCHAR(50),
    location VARCHAR(60),
    birth_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. جدول المنشورات (POSTS)
CREATE TABLE posts ( -- تم استخدام صيغة الجمع لتجنب الكلمة المحجوزة POST
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(35) NOT NULL,
    description TEXT NOT NULL, -- تصحيح الإملاء من DESCREPTION
    url VARCHAR(500),
    comments_count INT DEFAULT 0, -- تم تعديل الاسم لتجنب الكلمة المحجوزة COMMENT
    likes_count INT DEFAULT 0,
    hates_count INT DEFAULT 0,
    shares_count INT DEFAULT 0,
    saves_count INT DEFAULT 0,
    point INT DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. جدول المتابعات (FOLLOWS)
CREATE TABLE follows (
    follower_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_id, following_id)
);

-- 4. جدول التعليقات (COMMENTS)
CREATE TABLE comments (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. جدول تفاعلات المنشورات (POST_REACTIONS)
CREATE TABLE post_reactions (
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction_type VARCHAR(10) NOT NULL, -- يستقبل قيم مثل 'LIKE' أو 'HATE'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (post_id, user_id)
);

-- 6. جدول غرف المحادثات (CHAT_ROOMS)
CREATE TABLE chat_rooms (
    id BIGSERIAL PRIMARY KEY,
    user1_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user2_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user1_id, user2_id) -- يمنع إنشاء أكثر من غرفة لنفس الشخصين
);

-- 7. جدول الرسائل الخاصة (PRIVATE_MESSAGES)
CREATE TABLE private_messages (
    id BIGSERIAL PRIMARY KEY,
    room_id BIGINT NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);