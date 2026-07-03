package apis

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// ====================================================================================
// AuthMiddleware — نسخة مبسطة بدون توكن (بدون JWT)
// ====================================================================================
// الفكرة: العميل (الموبايل/الواجهة) يرسل هوية المستخدم مباشرة في الهيدر X-User-ID
// بدون أي تشفير أو تحقق. هذا يناسب مرحلة التطوير/الاختبار السريع فقط.
//
// ⚠️ تحذير أمني مهم:
// هذه الطريقة غير آمنة للإنتاج (Production) لأن أي شخص يقدر يزوّر الهيدر
// ويدّعي أنه أي مستخدم آخر (IDOR / Impersonation). لو رح تنشر التطبيق فعلياً
// لازم تستبدلها لاحقاً بنظام مصادقة حقيقي (JWT أو Session Cookies).
//
// طريقة الاستخدام من الفرونت إند:
//   Header: X-User-ID: 15
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDHeader := c.GetHeader("X-User-ID")
		if userIDHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "مطلوب تمرير هوية المستخدم عبر هيدر X-User-ID"})
			c.Abort()
			return
		}

		userID, err := strconv.ParseInt(userIDHeader, 10, 64)
		if err != nil || userID <= 0 {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "قيمة X-User-ID غير صالحة"})
			c.Abort()
			return
		}

		// نضع هوية المستخدم في الـ context ليستخدمها requireUserID() في كل الـ Handlers
		c.Set("userID", userID)
		c.Next()
	}
}
