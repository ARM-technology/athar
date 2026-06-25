package main

import (
	/*"context"
	"fmt"
	"log"

	_ "github.com/jackc/pgx/v5" */
	//	AI "backendathar/Experimentation"
	//	"fmt"
	en "backendathar/Tools/Cryptography/encryption"
	// _ APIs "backendathar/APIs"
	_ "backendathar/database"
)

const (
	DBUser     = "postgres"
	DBPassword = "12345678"
	DBHost     = "localhost"
	DBPort     = "5432"
	DBName     = "athar_db"
	LogLevel   = "DEBUG"

	// 🔥 المنفذ الجديد الخاص بمشروعك الحالي لتجنب التعارض مع 8080 و 80
	APIPort = "8082"
)

func main() {

	en.Example_encryptedKeyset()

	/*	result, _ := AI.AIemployye(" السلام عليكم  عرفني عنكم ")


		fmt.Println(result)
		fmt.Println("---------------------------------------")
	*/

	/*
	   	for i := 0; i < 10; i++ {
	   		result, _ = AI.AIemployye(" السلام عليكم اسمي قلب و جبل وش عندكم خدمات ")

	   		fmt.Println(result)
	   		fmt.Println("---------------------------------------")
	   	}
	   8/
	   	/*

	   		fmt.Print(" Hate Me I am Crazy 🤪🤪🤪🫨😜🤪")

	   		ctx := context.Background()

	   		// بناء رابط الاتصال بقاعدة البيانات المعزولة
	   		connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/%s",
	   			DBUser, DBPassword, DBHost, DBPort, DBName,
	   		)

	   		conn, err := pgx.Connect(ctx, connStr)
	   		if err != nil {
	   			log.Fatalf("❌ Error connect with DB : %v\n", err)
	   		}
	   		defer conn.Close(ctx)

	   		queries := database.New(conn)
	   		r := APIs.SetupRouter(queries)

	   		// تشغيل السيرفر على المنفذ الجديد المستقل 8082
	   		log.Printf("🚀 السيرفر يعمل الآن بنجاح وبشكل مستقل على المنفذ :%s...\n", APIPort)
	   		if err := r.Run(":" + APIPort); err != nil {
	   			log.Fatalf("❌ فشل تشغيل السيرفر: %v\n", err)
	   		}


	*/

}
