package apis

import (
	"github.com/gin-gonic/gin"

	// 💡 الحل القاطع: تم تعديل المسار إلى الأحرف الصغيرة (database) ليطابق تماماً ملف Response.go
	"backendathar/database"
)

// SetupRouter لتجهيز سيرفر Gin وحقن اتصال الداتابيز في الدوال
func SetupRouter(queries *database.Queries) *gin.Engine {
	r := gin.Default()

	// 1. إنشاء كائن الجسر وحقن استعلامات الداتابيز بداخلها
	handler := &APIHandler{
		DB: queries,
	}

	// 2. ربط المسار التجريبي بالدالة المخصصة له من الـ handler
	r.GET("/get/post/beta/v0", handler.GetGlobalFeed)

	// 3. ربط بقية الدوال للتأكد من عمل النظام بالكامل بشكل متناسق
	r.POST("/users/add", handler.AddUser)
	r.POST("/posts/add", handler.AddPost)

	return r
}
