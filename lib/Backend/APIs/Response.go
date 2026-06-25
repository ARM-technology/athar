package apis

import (
	"net/http"
	"strconv" // مكتبة لتحويل النصوص إلى أرقام

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgtype"

	// 💡 قم بتعديل هذا المسار إلى مسار مجلد داتابيز الـ sqlc في مشروعك الحقيقي
	database "backendathar/database"
)

// APIHandler سيعمل كجسر لنقل كائن قاعدة البيانات إلى الدوال
type APIHandler struct {
	DB *database.Queries
}

// 1️⃣ دالة إضافة مستخدم باستخدام الستراكت الخاص بك
func (h *APIHandler) AddUser(c *gin.Context) {
	var user User // استخدام الستراكت الخاص بك

	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	arg := database.CreateUserParams{
		UserID:   user.UserID,
		Username: user.Username,
		Password: pgtype.Text{String: user.Password, Valid: true},
	}

	newUser, err := h.DB.CreateUser(c.Request.Context(), arg)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "فشل حفظ المستخدم: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "User added successfully",
		"data":    newUser,
	})
}

// 2️⃣ دالة إضافة منشور باستخدام الستراكت الخاص بك
func (h *APIHandler) AddPost(c *gin.Context) {
	var post Add_Post // استخدام الستراكت الخاص بك

	if err := c.ShouldBindJSON(&post); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	nextPostID, err := h.DB.GetNextPostId(c.Request.Context(), post.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "فشل حساب معرف المنشور: " + err.Error()})
		return
	}

	arg := database.CreatePostParams{
		UserID:  post.UserID,
		PostID:  nextPostID,
		Title:   post.Title,
		Content: post.Content,
	}

	newPost, err := h.DB.CreatePost(c.Request.Context(), arg)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "فشل حفظ المنشور: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Post added successfully",
		"data":    newPost,
	})
}

// 3️⃣ 🔥 الدالة الجديدة المطلوبة: جلب كافة المنشورات (الفيد العام) وإرسالها للفلاتر
func (h *APIHandler) GetGlobalFeed(c *gin.Context) {
	// نستقبل الـ limit والـ offset من الفلاتر كـ Query Parameters (مثال: /posts?limit=20&offset=0)
	// إذا لم يرسلها تطبيق فلاتر، سنضع قيم افتراضية (جلب 100 منشور كحد أقصى)
	limitParam := c.DefaultQuery("limit", "100")
	offsetParam := c.DefaultQuery("offset", "0")

	// تحويل النصوص القادمة في الرابط إلى أرقام صحيحة تناسب كويري sqlc
	limit, errLang := strconv.Atoi(limitParam)
	offset, errOffset := strconv.Atoi(offsetParam)
	if errLang != nil || errOffset != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "المعاملات الممررة غير صالحة، يجب أن تكون أرقاماً"})
		return
	}

	// تجهيز المعاملات للكويري المولد من sqlc
	arg := database.ListGlobalFeedParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	}

	// استدعاء الكويري الفعلي من الداتابيز لجلب كافة المنشورات مع أسماء كتابها وعدادات التفاعل
	posts, err := h.DB.ListGlobalFeed(c.Request.Context(), arg)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "فشل جلب المنشورات من قاعدة البيانات: " + err.Error()})
		return
	}

	// إرسال مصفوفة الرسائل/البوستات كاملة لتطبيق الفلاتر بكود 200
	c.JSON(http.StatusOK, gin.H{
		"message": "Posts retrieved successfully",
		"posts":   posts,
	})
}
