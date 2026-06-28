package apis

import (
	"errors"
	"net/http"
	"time"

	"backendathar/database" // تأكد من مطابقة مسار مجلد الـ database الصحيح في مشروعك

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

// UserHandler يجمع التبعيات الخاصة بالمستخدم لضمان سرعة الوصول وتحمل ملايين الطلبات
type UserHandler struct {
	Repo *database.Queries
}

// NewUserHandler منشئ الـ Handler وحقن التبعيات عبر الـ Pointer لسرعة قصوى واستغلال الذاكرة
func NewUserHandler(repo *database.Queries) *UserHandler {
	return &UserHandler{Repo: repo}
}

// ==========================================
// 1. إضافة مستخدم جديد (Add User - التسجيل العام)
// ==========================================

type AddUserRequest struct {
	Username    string    `json:"username" binding:"required,min=3,max=24"`
	Password    string    `json:"password" binding:"required,min=6"`
	Email       string    `json:"email" binding:"required,email,max=60"`
	Name        string    `json:"name" binding:"required,max=45"`
	Description string    `json:"description" binding:"max=120"`
	City        string    `json:"city" binding:"max=50"`
	Location    string    `json:"location" binding:"max=60"`
	BirthDate   time.Time `json:"birth_date"`
}

func (h *UserHandler) AddUser(c *gin.Context) {
	var req AddUserRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	arg := database.CreateUserParams{
		Btrim:       req.Username,
		Password:    req.Password, // نصيحة أمنية: قم بتشفيرها بـ bcrypt هنا قبل الحفظ في الـ DB
		Btrim_2:     req.Email,
		Btrim_3:     req.Name,
		Description: pgtype.Text{String: req.Description, Valid: req.Description != ""},
		City:        pgtype.Text{String: req.City, Valid: req.City != ""},
		Location:    pgtype.Text{String: req.Location, Valid: req.Location != ""},
		BirthDate:   pgtype.Date{Time: req.BirthDate, Valid: !req.BirthDate.IsZero()},
	}

	user, err := h.Repo.CreateUser(c.Request.Context(), arg)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			c.JSON(http.StatusConflict, gin.H{"error": "username or email already exists"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}

	c.JSON(http.StatusCreated, user)
}

// ==========================================
// 2. تعديل بيانات مستخدم (Update User - حماية كاملة)
// ==========================================

type UpdateUserRequest struct {
	Name        string    `json:"name" binding:"required,max=45"`
	Description string    `json:"description" binding:"max=120"`
	City        string    `json:"city" binding:"max=50"`
	Location    string    `json:"location" binding:"max=60"`
	BirthDate   time.Time `json:"birth_date"`
}

func (h *UserHandler) UpdateUser(c *gin.Context) {
	// حماية قصوى: استخراج الـ ID الحقيقي للمستخدم الحالي من الـ Context (الذي وضعه الـ Auth Middleware)
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized access"})
		return
	}
	userID, ok := userIDVal.(int64)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "invalid user identification context"})
		return
	}

	var req UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// إرسال الـ userID المستخرج بأمان من التوكن إلى قاعدة البيانات مباشرة للـ Update
	arg := database.UpdateUserProfileSecureParams{
		ID:          userID,
		Btrim:       req.Name,
		Description: pgtype.Text{String: req.Description, Valid: req.Description != ""},
		City:        pgtype.Text{String: req.City, Valid: req.City != ""},
		Location:    pgtype.Text{String: req.Location, Valid: req.Location != ""},
		BirthDate:   pgtype.Date{Time: req.BirthDate, Valid: !req.BirthDate.IsZero()},
	}

	updatedUser, err := h.Repo.UpdateUserProfileSecure(c.Request.Context(), arg)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update user profile"})
		return
	}

	c.JSON(http.StatusOK, updatedUser)
}
