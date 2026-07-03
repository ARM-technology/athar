package apis

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"

	database "backendathar/database"
)

// ====================================================================================
// FollowHandler: يغطي جدول follows (متابعة، إلغاء متابعة، فحص الحالة، الاستكشاف)
// ====================================================================================

type FollowHandler struct {
	queries *database.Queries
}

func NewFollowHandler(queries *database.Queries) *FollowHandler {
	return &FollowHandler{queries: queries}
}

// ---------- CheckFollow ----------

type checkFollowRequest struct {
	TargetUserID int64 `json:"target_user_id" binding:"required"`
}

// CheckFollow: محمي بالتوكن - هل المستخدم الحالي يتابع target_user_id؟
func (h *FollowHandler) CheckFollow(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req checkFollowRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	isFollowing, err := h.queries.CheckFollowStatus(context.Background(), database.CheckFollowStatusParams{
		Column1: userID,
		Column2: req.TargetUserID,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر التحقق من حالة المتابعة")
		return
	}

	c.JSON(http.StatusOK, gin.H{"is_following": isFollowing})
}

// ---------- GetFollowing ----------

type getFollowingRequest struct {
	UserID int64 `json:"user_id" binding:"required"`
	Limit  int32 `json:"limit"`
	Offset int32 `json:"offset"`
}

// GetFollowing: مفتوح للعامة - جلب قائمة من يتابعهم مستخدم معين
func (h *FollowHandler) GetFollowing(c *gin.Context) {
	var req getFollowingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}
	limit, offset := normalizePagination(req.Limit, req.Offset)

	list, err := h.queries.GetFollowingList(context.Background(), database.GetFollowingListParams{
		Column1: req.UserID,
		Column2: limit,
		Column3: offset,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب قائمة المتابَعين")
		return
	}

	c.JSON(http.StatusOK, gin.H{"following": list})
}

// ---------- DiscoverPeople ----------

type discoverPeopleRequest struct {
	Limit  int32 `json:"limit"`
	Offset int32 `json:"offset"`
}

// DiscoverPeople: محمي بالتوكن - اقتراح أشخاص للمتابعة بناءً على المتابعين المشتركين
func (h *FollowHandler) DiscoverPeople(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req discoverPeopleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}
	limit, offset := normalizePagination(req.Limit, req.Offset)

	suggestions, err := h.queries.DiscoverPeopleToFollow(context.Background(), database.DiscoverPeopleToFollowParams{
		Column1: userID,
		Column2: limit,
		Column3: offset,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب الاقتراحات")
		return
	}

	c.JSON(http.StatusOK, gin.H{"suggestions": suggestions})
}
