package apis

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"

	database "backendathar/database"
)

// ====================================================================================
// CommentHandler: يغطي جدول comments (إضافة، تعديل، حذف، جلب، بحث، عدّ)
// ====================================================================================

type CommentHandler struct {
	queries *database.Queries
}

func NewCommentHandler(queries *database.Queries) *CommentHandler {
	return &CommentHandler{queries: queries}
}

// ---------- CreateComment ----------

type createCommentRequest struct {
	PostID  int64  `json:"post_id" binding:"required"`
	Content string `json:"content" binding:"required"`
}

// CreateComment: محمي بالتوكن - إضافة تعليق جديد ثم تحديث عداد تعليقات المنشور
func (h *CommentHandler) CreateComment(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req createCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	comment, err := h.queries.CreateComment(context.Background(), database.CreateCommentParams{
		PostID: req.PostID,
		UserID: userID,
		Btrim:  req.Content,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر إضافة التعليق")
		return
	}

	_ = h.queries.IncrementPostComments(context.Background(), req.PostID)

	c.JSON(http.StatusCreated, gin.H{"comment": comment})
}

// ---------- GetCommentByID ----------

type getCommentByIDRequest struct {
	ID int64 `json:"id" binding:"required"`
}

// GetCommentByID: مفتوح للعامة - جلب تعليق واحد بواسطة الـ ID
func (h *CommentHandler) GetCommentByID(c *gin.Context) {
	var req getCommentByIDRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	comment, err := h.queries.GetCommentByID(context.Background(), req.ID)
	if err != nil {
		respondError(c, http.StatusNotFound, "التعليق غير موجود")
		return
	}

	c.JSON(http.StatusOK, gin.H{"comment": comment})
}

// ---------- ListPostComments ----------

type listPostCommentsRequest struct {
	PostID int64 `json:"post_id" binding:"required"`
	Cursor int64 `json:"cursor"` // 0 = من البداية
	Limit  int32 `json:"limit"`
}

// ListPostComments: مفتوح للعامة - جلب تعليقات منشور معين مع Cursor Pagination
func (h *CommentHandler) ListPostComments(c *gin.Context) {
	var req listPostCommentsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}
	limit, _ := normalizePagination(req.Limit, 0)

	comments, err := h.queries.ListPostCommentsDetailed(context.Background(), database.ListPostCommentsDetailedParams{
		PostID:  req.PostID,
		Column2: req.Cursor,
		Limit:   limit,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب التعليقات")
		return
	}

	c.JSON(http.StatusOK, gin.H{"comments": comments})
}

// ---------- SearchPostComments ----------

type searchPostCommentsRequest struct {
	PostID int64  `json:"post_id" binding:"required"`
	Query  string `json:"query" binding:"required"`
	Limit  int32  `json:"limit"`
	Offset int32  `json:"offset"`
}

// SearchPostComments: مفتوح للعامة - بحث نصي داخل تعليقات منشور محدد
func (h *CommentHandler) SearchPostComments(c *gin.Context) {
	var req searchPostCommentsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}
	limit, offset := normalizePagination(req.Limit, req.Offset)

	results, err := h.queries.SearchCommentsInPost(context.Background(), database.SearchCommentsInPostParams{
		PostID:  req.PostID,
		Column2: toPgText(req.Query),
		Limit:   limit,
		Offset:  offset,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر تنفيذ البحث")
		return
	}

	c.JSON(http.StatusOK, gin.H{"results": results})
}

// ---------- UpdateComment ----------

type updateCommentRequest struct {
	ID      int64  `json:"id" binding:"required"`
	Content string `json:"content" binding:"required"`
}

// UpdateComment: محمي بالتوكن - تعديل تعليق يخص المستخدم الحالي فقط
func (h *CommentHandler) UpdateComment(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req updateCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	updated, err := h.queries.UpdateCommentSecure(context.Background(), database.UpdateCommentSecureParams{
		ID:     req.ID,
		UserID: userID,
		Btrim:  req.Content,
	})
	if err != nil {
		respondError(c, http.StatusForbidden, "تعذر تعديل التعليق")
		return
	}

	c.JSON(http.StatusOK, gin.H{"comment": updated})
}

// ---------- DeleteComment ----------

type deleteCommentRequest struct {
	ID     int64 `json:"id" binding:"required"`
	PostID int64 `json:"post_id" binding:"required"` // مطلوب لتحديث عداد التعليقات بعد الحذف
}

// DeleteComment: محمي بالتوكن - حذف تعليق (يسمح به لصاحب التعليق أو صاحب المنشور) مع تحديث العداد
func (h *CommentHandler) DeleteComment(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req deleteCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	if err := h.queries.DeleteCommentSecure(context.Background(), database.DeleteCommentSecureParams{
		ID:     req.ID,
		UserID: userID,
	}); err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر حذف التعليق")
		return
	}

	_ = h.queries.DecrementPostComments(context.Background(), req.PostID)

	c.JSON(http.StatusOK, gin.H{"message": "تم حذف التعليق بنجاح"})
}

// ---------- BatchGetComments ----------

type batchGetCommentsRequest struct {
	IDs []int64 `json:"ids" binding:"required"`
}

// BatchGetComments: مفتوح للعامة - جلب مجموعة تعليقات بمصفوفة IDs بطلب واحد
func (h *CommentHandler) BatchGetComments(c *gin.Context) {
	var req batchGetCommentsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	comments, err := h.queries.BatchGetCommentsByIDs(context.Background(), req.IDs)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب التعليقات")
		return
	}

	c.JSON(http.StatusOK, gin.H{"comments": comments})
}

// ---------- CountComments ----------

type countCommentsRequest struct {
	PostID int64 `json:"post_id" binding:"required"`
}

// CountComments: مفتوح للعامة - حساب إجمالي عدد التعليقات على منشور معين
func (h *CommentHandler) CountComments(c *gin.Context) {
	var req countCommentsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	count, err := h.queries.CountCommentsByPostID(context.Background(), req.PostID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر حساب عدد التعليقات")
		return
	}

	c.JSON(http.StatusOK, gin.H{"count": count})
}
