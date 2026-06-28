package apis

import (
	"github.com/gin-gonic/gin"

	database "backendathar/database"
)

func RouterAPI(queries *database.Queries) *gin.Engine {
	r := gin.Default()

	handler := NewUserHandler(queries)
	// 2. ربط مسارات المستخدمين بالـ handler الصحيح الخاص بها
	r.POST("api/v0/users/add", handler.AddUser)

	return r
}
