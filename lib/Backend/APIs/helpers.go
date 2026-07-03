package apis

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgtype"
)

// ====================================================================================
// مساعدات مشتركة تُستخدم في جميع الـ Handlers
// ====================================================================================

// getUserID يقرأ هوية المستخدم المُصادق عليه من الـ context (يتم وضعها بواسطة AuthMiddleware)
// افتراض: AuthMiddleware يستدعي c.Set("userID", int64(...)) بعد فك تشفير التوكن
func getUserID(c *gin.Context) (int64, bool) {
	val, exists := c.Get("userID")
	if !exists {
		return 0, false
	}
	id, ok := val.(int64)
	if !ok {
		return 0, false
	}
	return id, true
}

// requireUserID يقرأ هوية المستخدم أو يرسل خطأ 401 تلقائياً ويوقف المعالجة
func requireUserID(c *gin.Context) (int64, bool) {
	id, ok := getUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "غير مصرح لك، الرجاء تسجيل الدخول"})
		c.Abort()
		return 0, false
	}
	return id, true
}

// respondError دالة موحدة لإرسال رسائل الأخطاء
func respondError(c *gin.Context, status int, message string) {
	c.JSON(status, gin.H{"error": message})
}

// ---- تحويلات pgtype ----

func toPgText(s string) pgtype.Text {
	if s == "" {
		return pgtype.Text{Valid: false}
	}
	return pgtype.Text{String: s, Valid: true}
}

func fromPgText(t pgtype.Text) string {
	if !t.Valid {
		return ""
	}
	return t.String
}

func toPgInt4(v int32) pgtype.Int4 {
	return pgtype.Int4{Int32: v, Valid: true}
}

func toPgDate(s string) pgtype.Date {
	if s == "" {
		return pgtype.Date{Valid: false}
	}
	parsed, err := time.Parse("2006-01-02", s)
	if err != nil {
		return pgtype.Date{Valid: false}
	}
	return pgtype.Date{Time: parsed, Valid: true}
}

// normalizePagination يضبط قيم limit/offset الافتراضية والحدود القصوى لحماية السيرفر
func normalizePagination(limit, offset int32) (int32, int32) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	return limit, offset
}
