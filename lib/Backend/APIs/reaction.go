package apis

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"

	database "backendathar/database"
)

// ====================================================================================
// ReactionHandler: يغطي جدول post_reactions (لايك/هيت، الحالة، القوائم، المزامنة)
// ====================================================================================

type ReactionHandler struct {
	queries *database.Queries
}

func NewReactionHandler(queries *database.Queries) *ReactionHandler {
	return &ReactionHandler{queries: queries}
}

// ---------- SetReaction ----------

type setReactionRequest struct {
	PostID       int64  `json:"post_id" binding:"required"`
	ReactionType string `json:"reaction_type" binding:"required,oneof=LIKE HATE"`
}

// SetReaction: محمي بالتوكن - إضافة أو تحديث تفاعل المستخدم على منشور، ثم مزامنة العدادات
func (h *ReactionHandler) SetReaction(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req setReactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	reaction, err := h.queries.UpsertReaction(context.Background(), database.UpsertReactionParams{
		PostID:       req.PostID,
		UserID:       userID,
		ReactionType: req.ReactionType,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر تسجيل التفاعل")
		return
	}

	// مزامنة العدادات المخزنة في جدول posts مع الحالة الفعلية بعد التفاعل
	_ = h.queries.SyncPostCounters(context.Background(), req.PostID)

	c.JSON(http.StatusOK, gin.H{"reaction": reaction})
}

// ---------- DeleteReaction ----------

type deleteReactionRequest struct {
	PostID int64 `json:"post_id" binding:"required"`
}

// DeleteReaction: محمي بالتوكن - إزالة تفاعل المستخدم من منشور، ثم مزامنة العدادات
func (h *ReactionHandler) DeleteReaction(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req deleteReactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	if err := h.queries.RemoveReaction(context.Background(), database.RemoveReactionParams{
		PostID: req.PostID,
		UserID: userID,
	}); err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر إزالة التفاعل")
		return
	}

	_ = h.queries.SyncPostCounters(context.Background(), req.PostID)

	c.JSON(http.StatusOK, gin.H{"message": "تم إزالة التفاعل بنجاح"})
}

// ---------- GetPostWithStatus ----------

type getPostWithStatusRequest struct {
	PostID   int64 `json:"post_id" binding:"required"`
	ViewerID int64 `json:"viewer_id"` // اختياري: 0 = بدون مستخدم مسجل دخول
}

// GetPostWithStatus: مفتوح للعامة - جلب تفاصيل المنشور مع حالة تفاعل المشاهد (إن وُجد)
func (h *ReactionHandler) GetPostWithStatus(c *gin.Context) {
	var req getPostWithStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	post, err := h.queries.GetPostWithReactionStatus(context.Background(), database.GetPostWithReactionStatusParams{
		ID:     req.PostID,
		UserID: req.ViewerID,
	})
	if err != nil {
		respondError(c, http.StatusNotFound, "المنشور غير موجود")
		return
	}

	c.JSON(http.StatusOK, gin.H{"post": post})
}

// ---------- GetFeedReactions ----------

type getFeedReactionsRequest struct {
	PostIDs []int64 `json:"post_ids" binding:"required"`
}

// GetFeedReactions: محمي بالتوكن - جلب تفاعلات المستخدم الحالي على مجموعة منشورات دفعة واحدة (لتلوين الأزرار في الـ Feed)
func (h *ReactionHandler) GetFeedReactions(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req getFeedReactionsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	reactions, err := h.queries.GetReactionsForFeedByPostIDs(context.Background(), database.GetReactionsForFeedByPostIDsParams{
		UserID:  userID,
		Column2: req.PostIDs,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب التفاعلات")
		return
	}

	c.JSON(http.StatusOK, gin.H{"reactions": reactions})
}

// ---------- GetUsersWhoReacted ----------

type getUsersWhoReactedRequest struct {
	PostID       int64  `json:"post_id" binding:"required"`
	ReactionType string `json:"reaction_type"` // اختياري: LIKE أو HATE، فارغ = الكل
	Limit        int32  `json:"limit"`
	Offset       int32  `json:"offset"`
}

// GetUsersWhoReacted: مفتوح للعامة - قائمة المستخدمين الذين تفاعلوا مع منشور معين
func (h *ReactionHandler) GetUsersWhoReacted(c *gin.Context) {
	var req getUsersWhoReactedRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}
	limit, offset := normalizePagination(req.Limit, req.Offset)

	users, err := h.queries.ListUsersWhoReacted(context.Background(), database.ListUsersWhoReactedParams{
		PostID:  req.PostID,
		Column2: req.ReactionType,
		Limit:   limit,
		Offset:  offset,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب قائمة المتفاعلين")
		return
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}

// ---------- SyncPostMetrics ----------

type syncPostMetricsRequest struct {
	PostID int64 `json:"post_id" binding:"required"`
}

// SyncPostMetrics: مفتوح للعامة / للصيانة - إعادة حساب عدادات اللايكات والهيتات للمنشور من جدول التفاعلات مباشرة
func (h *ReactionHandler) SyncPostMetrics(c *gin.Context) {
	var req syncPostMetricsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	if err := h.queries.SyncPostCounters(context.Background(), req.PostID); err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر مزامنة عدادات المنشور")
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "تمت المزامنة بنجاح"})
}
