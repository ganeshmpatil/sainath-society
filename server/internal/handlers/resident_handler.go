package handlers

import (
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

const maxPhotoSize = 5 * 1024 * 1024 // 5 MB

type ResidentHandler struct {
	repo *repositories.MemberRepository
	db   *gorm.DB
}

func NewResidentHandler(repo *repositories.MemberRepository, db *gorm.DB) *ResidentHandler {
	return &ResidentHandler{repo: repo, db: db}
}

type createResidentReq struct {
	Name        string      `json:"name" binding:"required"`
	Mobile      string      `json:"mobile" binding:"required"`
	FlatID      *uuid.UUID  `json:"flatId,omitempty"`
	Role        models.Role `json:"role,omitempty"`
	Designation string      `json:"designation,omitempty"`
}

func (h *ResidentHandler) Create(c *gin.Context) {
	var req createResidentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	m := &models.Member{
		Name: req.Name, Mobile: req.Mobile, FlatID: req.FlatID,
		Role: req.Role, Designation: req.Designation,
	}
	if m.Role == "" {
		m.Role = models.RoleMember
	}
	if err := h.repo.Create(actor, m); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, m)
}

func (h *ResidentHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	var roleFilter *models.Role
	if s := c.Query("role"); s != "" {
		r := models.Role(s)
		roleFilter = &r
	}
	onlyActive := c.Query("activeOnly") != "false"
	rows, err := h.repo.List(actor, roleFilter, onlyActive)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"residents": rows, "count": len(rows)})
}

func (h *ResidentHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	m, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, m)
}

func (h *ResidentHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var patch map[string]interface{}
	if err := c.ShouldBindJSON(&patch); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Update(actor, id, patch); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Updated"})
}

func (h *ResidentHandler) Deactivate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Deactivate(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deactivated"})
}

// UploadPhoto accepts a multipart "photo" file and stores it for the member.
// Admin can upload for anyone; members can upload their own.
func (h *ResidentHandler) UploadPhoto(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() && actor.MemberID != id {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "forbidden", Code: "FORBIDDEN"})
		return
	}

	file, header, err := c.Request.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "photo file is required", Code: "INVALID_REQUEST"})
		return
	}
	defer file.Close()

	if header.Size > maxPhotoSize {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "photo exceeds 5 MB limit", Code: "FILE_TOO_LARGE"})
		return
	}

	mime := header.Header.Get("Content-Type")
	if mime != "image/jpeg" && mime != "image/png" && mime != "image/webp" {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "only JPEG, PNG, and WebP photos are allowed", Code: "INVALID_FILE_TYPE"})
		return
	}

	data, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to read file", Code: "READ_ERROR"})
		return
	}

	photo := &models.MemberPhoto{
		MemberID:  id,
		PhotoData: data,
		MimeType:  mime,
		Size:      int64(len(data)),
	}

	// Upsert: create or replace
	result := h.db.Where("member_id = ?", id).First(&models.MemberPhoto{})
	if result.Error == gorm.ErrRecordNotFound {
		if err := h.db.Create(photo).Error; err != nil {
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to save photo", Code: "SAVE_ERROR"})
			return
		}
	} else {
		if err := h.db.Model(&models.MemberPhoto{}).Where("member_id = ?", id).Updates(map[string]interface{}{
			"photo_data": data, "mime_type": mime, "size": int64(len(data)),
		}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to save photo", Code: "SAVE_ERROR"})
			return
		}
	}

	// Set has_photo flag on member
	if err := h.db.Model(&models.Member{}).Where("id = ?", id).Update("has_photo", true).Error; err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to update photo flag", Code: "UPDATE_ERROR"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Photo uploaded"})
}

// GetPhoto serves the raw photo bytes with the correct Content-Type.
func (h *ResidentHandler) GetPhoto(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}

	var photo models.MemberPhoto
	if err := h.db.First(&photo, "member_id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, response.ErrorResponse{Error: "no photo found", Code: "NOT_FOUND"})
			return
		}
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "DB_ERROR"})
		return
	}

	c.Header("Cache-Control", "public, max-age=3600")
	c.Data(http.StatusOK, photo.MimeType, photo.PhotoData)
}

// DeletePhoto removes the member's photo. Admin or self.
func (h *ResidentHandler) DeletePhoto(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() && actor.MemberID != id {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "forbidden", Code: "FORBIDDEN"})
		return
	}

	if err := h.db.Where("member_id = ?", id).Delete(&models.MemberPhoto{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to delete photo", Code: "DELETE_ERROR"})
		return
	}
	h.db.Model(&models.Member{}).Where("id = ?", id).Update("has_photo", false)

	c.JSON(http.StatusOK, gin.H{"message": "Photo deleted"})
}
