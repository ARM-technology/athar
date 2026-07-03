package apis

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"

	database "backendathar/database"
)

// ====================================================================================
// UserHandler: يغطي جدول users (إنشاء الحساب، تحديث الملف الشخصي)
// ====================================================================================

type UserHandler struct {
	queries *database.Queries
}

func NewUserHandler(queries *database.Queries) *UserHandler {
	return &UserHandler{queries: queries}
}

// ---------- AddUser ----------

type addUserRequest struct {
	Username    string `json:"username" binding:"required,min=3,max=30"`
	Password    string `json:"password" binding:"required,min=6"`
	Email       string `json:"email"`
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
	City        string `json:"city"`
	Location    string `json:"location"`
	BirthDate   string `json:"birth_date"` // بصيغة YYYY-MM-DD
}

// AddUser: مفتوح للعامة - إنشاء حساب جديد
func (h *UserHandler) AddUser(c *gin.Context) {
	var req addUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر تشفير كلمة المرور")
		return
	}

	user, err := h.queries.CreateUser(context.Background(), database.CreateUserParams{
		Btrim:       req.Username,
		Password:    string(hashedPassword),
		Btrim_2:     req.Email,
		Btrim_3:     req.Name,
		Description: toPgText(req.Description),
		City:        toPgText(req.City),
		Location:    toPgText(req.Location),
		BirthDate:   toPgDate(req.BirthDate),
	})
	if err != nil {
		respondError(c, http.StatusConflict, "تعذر إنشاء الحساب، ربما اسم المستخدم أو البريد مستخدم مسبقاً")
		return
	}

	c.JSON(http.StatusCreated, gin.H{"user": user})
}

// ---------- UpdateUser ----------

type updateUserRequest struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
	City        string `json:"city"`
	Location    string `json:"location"`
	BirthDate   string `json:"birth_date"`
}

// UpdateUser: محمي بالتوكن - تحديث الملف الشخصي للمستخدم الحالي فقط
func (h *UserHandler) UpdateUser(c *gin.Context) {
	userID, ok := requireUserID(c)
	if !ok {
		return
	}

	var req updateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "بيانات غير صالحة: "+err.Error())
		return
	}

	updated, err := h.queries.UpdateUserProfileSecure(context.Background(), database.UpdateUserProfileSecureParams{
		ID:          userID,
		Btrim:       req.Name,
		Description: toPgText(req.Description),
		City:        toPgText(req.City),
		Location:    toPgText(req.Location),
		BirthDate:   toPgDate(req.BirthDate),
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "تعذر تحديث الملف الشخصي")
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": updated})
}
