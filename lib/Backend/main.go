package main

import (
	"context"
	_ "embed" // تفعيل ميزة التضمين التلقائي للملفات
	"fmt"
	"log"

	r "backendathar/APIs"
	"backendathar/database" // استيراد الحزمة المولدة عبر sqlc

	"github.com/jackc/pgx/v5/pgxpool"
	// "backendathar/APIs"   // قم بإلغاء التعليق عن هذا السطر عندما تجهز الراوترات الخاصة بك
)

const (
	DBUser     = "postgres"
	DBPassword = "12345678"
	DBHost     = "localhost"
	DBPort     = "5432"
	DBName     = "athar_db"
	LogLevel   = "DEBUG"

	// المنفذ الخاص بمشروعك الحالي لتجنب التعارض
	APIPort = "8082"
)

// تضمين ملف السكيما المتواجد داخل مجلد database تلقائياً وقت بناء التطبيق
//
//go:embed database/schema.sql
var schemaSQL string

func main() {
	ctx := context.Background()

	log.Println("Starting the application...👨🏻‍💻✅")

	// 1. بناء رابط الاتصال بقاعدة البيانات بشكل ديناميكي باستخدام الثوابت المعرفة أعلاه
	connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		DBUser, DBPassword, DBHost, DBPort, DBName,
	)

	log.Println("Starting the database connection...🔄")

	// 2. إنشاء اتصال مجمع (Connection Pool) باستخدام pgxpool وهو الخيار الاحترافي والآمن للـ Concurrency
	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		log.Fatalf("❌Failed to connect to the database: %v\n", err)
	}
	defer pool.Close()

	// 3. التنفيذ التلقائي لملف السكيما لإنشاء الجداول فور تشغيل التطبيق
	log.Println("🔄 جاري فحص وتطبيق السكيما وإنشاء الجداول...")
	_, err = pool.Exec(ctx, schemaSQL)
	if err != nil {
		log.Fatalf("❌ فشل في تطبيق السكيما وإنشاء الجداول: %v\n", err)
	}
	log.Println("✅ تم فحص وتطبيق السكيما بنجاح، وجميع جداولك جاهزة الآن!")

	// 4. ربط الكويري المولّد من أداة sqlc مع قاعدة البيانات الحية عبر الـ pool
	queries := database.New(pool)

	log.Println("🎉Successfully started the application...✅")
	fmt.Println("-----------------------------------------")
	router := r.RouterAPI(queries)
	router.Run(":" + APIPort)
	log.Printf("🚀 Server is running on port %s...\n", APIPort)

}
