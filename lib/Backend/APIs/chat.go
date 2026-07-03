package apis

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"

	database "backendathar/database"
)

// ====================================================================================
// ChatHandler: يغطي جدولي chat_rooms و private_messages (الغرف + الرسائل)
// ====================================================================================

type ChatHandler struct {
	queries *database.Queries
}

func NewChatHandler(queries *database.Queries) *ChatHandler {
	return &ChatHandler{queries: queries}
}

// ---------- CheckRoomAccess ----------

type checkRoomAccessRequest struct {
	RoomID int64 `json:"room_id" binding:"required"`
}

// CheckRoomAccess: محمي بالتوكن - التحقق هل المستخدم الحالي عضو في هذه الغرفة
func (h *ChatHandler) CheckRoomAccess(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req checkRoomAccessRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	hasAccess, err := h.queries.CheckRoomAccess(context.Background(), database.CheckRoomAccessParams{
		ID:      req.RoomID,
		User1ID: userID,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر التحقق من صلاحية الوصول")
		return
	}

	c.JSON(http.StatusOK, gin.H{"has_access": hasAccess})
}

// ---------- GetUserInbox ----------

type getUserInboxRequest struct {
	Limit  int32 `json:"limit"`
	Offset int32 `json:"offset"`
}

// GetUserInbox: محمي بالتوكن - جلب كل محادثات المستخدم الحالي مرتبة حسب آخر نشاط
func (h *ChatHandler) GetUserInbox(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req getUserInboxRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}
	limit, offset := normalizePagination(req.Limit, req.Offset)

	inbox, err := h.queries.ListUserInboxDetailed(context.Background(), database.ListUserInboxDetailedParams{
		User1ID: userID,
		Limit:   limit,
		Offset:  offset,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب صندوق الوارد")
		return
	}

	c.JSON(http.StatusOK, gin.H{"inbox": inbox})
}

// ---------- SendMessage ----------

type sendMessageRequest struct {
	RoomID  int64  `json:"room_id" binding:"required"`
	Message string `json:"message" binding:"required"`
}

// SendMessage: محمي بالتوكن - إرسال رسالة داخل غرفة، مع التحقق من عضوية المرسل في الغرفة أولاً
func (h *ChatHandler) SendMessage(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req sendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	hasAccess, err := h.queries.CheckRoomAccess(context.Background(), database.CheckRoomAccessParams{
		ID:      req.RoomID,
		User1ID: userID,
	})
	if err != nil || !hasAccess {
		respondError(c, http.StatusForbidden, "لا تملك صلاحية الإرسال في هذه الغرفة")
		return
	}

	msg, err := h.queries.SendMessage(context.Background(), database.SendMessageParams{
		RoomID:   req.RoomID,
		SenderID: userID,
		Btrim:    req.Message,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر إرسال الرسالة")
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message_data": msg})
}

// ---------- UpdateMessage ----------

type updateMessageRequest struct {
	ID      int64  `json:"id" binding:"required"`
	Message string `json:"message" binding:"required"`
}

// UpdateMessage: محمي بالتوكن - تعديل رسالة يخص المستخدم الحالي فقط
func (h *ChatHandler) UpdateMessage(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req updateMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	updated, err := h.queries.UpdateMessageSecure(context.Background(), database.UpdateMessageSecureParams{
		ID:       req.ID,
		SenderID: userID,
		Btrim:    req.Message,
	})
	if err != nil {
		respondError(c, http.StatusForbidden, "تعذر تعديل الرسالة")
		return
	}

	c.JSON(http.StatusOK, gin.H{"message_data": updated})
}

// ---------- DeleteMessage ----------

type deleteMessageRequest struct {
	ID int64 `json:"id" binding:"required"`
}

// DeleteMessage: محمي بالتوكن - حذف رسالة يخص المستخدم الحالي فقط (Unsend)
func (h *ChatHandler) DeleteMessage(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req deleteMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	if err := h.queries.DeleteMessageSecure(context.Background(), database.DeleteMessageSecureParams{
		ID:       req.ID,
		SenderID: userID,
	}); err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر حذف الرسالة")
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "تم حذف الرسالة بنجاح"})
}

// ---------- GetUnreadMessagesCount ----------

type getUnreadMessagesCountRequest struct {
	RoomID int64 `json:"room_id" binding:"required"`
}

// GetUnreadMessagesCount: محمي بالتوكن - عدد الرسائل غير المقروءة الموجهة للمستخدم الحالي في غرفة معينة
func (h *ChatHandler) GetUnreadMessagesCount(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req getUnreadMessagesCountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	count, err := h.queries.CountUnreadMessagesInRoom(context.Background(), database.CountUnreadMessagesInRoomParams{
		RoomID:   req.RoomID,
		SenderID: userID,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر جلب عدد الرسائل غير المقروءة")
		return
	}

	// نُحدّث حالة القراءة تلقائياً بعد جلب العدد (اختياري: يمكن فصلها إلى مسار مستقل لو رغبت)
	c.JSON(http.StatusOK, gin.H{"unread_count": count})
}
