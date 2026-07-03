package apis

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"

	database "backendathar/database"
)

// ====================================================================================
// PostHandler: يغطي جدول posts (إنشاء، تعديل، حذف، وجلب التفاصيل)
// ====================================================================================

type PostHandler struct {
	queries *database.Queries
}

func NewPostHandler(queries *database.Queries) *PostHandler {
	return &PostHandler{queries: queries}
}

// ---------- CreatePost ----------

type createPostRequest struct {
	Title       string `json:"title" binding:"required"`
	Description string `json:"description" binding:"required"`
	Url         string `json:"url"`
}

// CreatePost: محمي بالتوكن - إنشاء منشور جديد ثم مزامنة عداد منشورات المستخدم
func (h *PostHandler) CreatePost(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req createPostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	post, err := h.queries.CreatePost(context.Background(), database.CreatePostParams{
		UserID:  userID,
		Btrim:   req.Title,
		Btrim_2: req.Description,
		Btrim_3: req.Url,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر إنشاء المنشور")
		return
	}

	// تحديث عداد منشورات المستخدم (لا نوقف الطلب لو فشلت هذه الخطوة)
	_ = h.queries.IncrementUserPostsCount(context.Background(), userID)

	c.JSON(http.StatusCreated, gin.H{"post": post})
}

// ---------- UpdatePost ----------

type updatePostRequest struct {
	ID          int64  `json:"id" binding:"required"`
	Title       string `json:"title" binding:"required"`
	Description string `json:"description" binding:"required"`
	Url         string `json:"url"`
}

// UpdatePost: محمي بالتوكن - تعديل منشور يخص المستخدم الحالي فقط
func (h *PostHandler) UpdatePost(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req updatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	updated, err := h.queries.UpdatePostSecure(context.Background(), database.UpdatePostSecureParams{
		ID:      req.ID,
		UserID:  userID,
		Btrim:   req.Title,
		Btrim_2: req.Description,
		Btrim_3: req.Url,
	})
	if err != nil {
		respondError(c, http.StatusForbidden, "تعذر تعديل المنشور، تحقق من الملكية أو المعرف")
		return
	}

	c.JSON(http.StatusOK, gin.H{"post": updated})
}

// ---------- DeletePost ----------

type deletePostRequest struct {
	ID int64 `json:"id" binding:"required"`
}

// DeletePost: محمي بالتوكن - حذف منشور يخص المستخدم الحالي فقط ثم تحديث عداد منشوراته
func (h *PostHandler) DeletePost(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req deletePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	if err := h.queries.DeletePostSecure(context.Background(), database.DeletePostSecureParams{
		ID:     req.ID,
		UserID: userID,
	}); err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر حذف المنشور")
		return
	}

	_ = h.queries.DecrementUserPostsCount(context.Background(), userID)

	c.JSON(http.StatusOK, gin.H{"message": "تم حذف المنشور بنجاح"})
}

// ---------- GetPostByID ----------

type getPostByIDRequest struct {
	ID       int64 `json:"id" binding:"required"`
	ViewerID int64 `json:"viewer_id"` // اختياري: لمعرفة حالة تفاعل المستخدم الحالي مع المنشور
}

// GetPostByID: مفتوح للعامة - يدعم سياق المشاهد الاختياري (viewer_id) لمعرفة حالة تفاعله مع المنشور
func (h *PostHandler) GetPostByID(c *gin.Context) {
	var req getPostByIDRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	if req.ViewerID > 0 {
		post, err := h.queries.GetPostDetailedWithViewerContext(context.Background(), database.GetPostDetailedWithViewerContextParams{
			ID:     req.ID,
			UserID: req.ViewerID,
		})
		if err != nil {
			respondError(c, http.StatusNotFound, "المنشور غير موجود")
			return
		}
		c.JSON(http.StatusOK, gin.H{"post": post})
		return
	}

	post, err := h.queries.GetPostDetailedByID(context.Background(), req.ID)
	if err != nil {
		respondError(c, http.StatusNotFound, "المنشور غير موجود")
		return
	}
	c.JSON(http.StatusOK, gin.H{"post": post})
}
