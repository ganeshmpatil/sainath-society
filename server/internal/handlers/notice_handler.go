package handlers

import (
	"bytes"
	"compress/gzip"
	"io"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
	"sainath-society/internal/services"
)

type NoticeHandler struct {
	repo     *repositories.NoticeRepository
	notifier *services.Notifier
}

func NewNoticeHandler(repo *repositories.NoticeRepository, notifier *services.Notifier) *NoticeHandler {
	return &NoticeHandler{repo: repo, notifier: notifier}
}

type createNoticeReq struct {
	Title    string                `json:"title" binding:"required,max=200"`
	TitleMr  string                `json:"titleMr,omitempty"`
	Body     string                `json:"body" binding:"required"`
	BodyMr   string                `json:"bodyMr,omitempty"`
	Category models.NoticeCategory `json:"category,omitempty"`
	IsPinned bool                  `json:"isPinned,omitempty"`
}

func (h *NoticeHandler) Create(c *gin.Context) {
	var req createNoticeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	n := &models.Notice{
		Title: req.Title, TitleMr: req.TitleMr,
		Body: req.Body, BodyMr: req.BodyMr,
		Category: req.Category, IsPinned: req.IsPinned,
		IsPublished: true,
	}
	if n.Category == "" {
		n.Category = models.NoticeGeneral
	}
	if err := h.repo.Create(actor, n); err != nil {
		writeRepoError(c, err)
		return
	}

	// Notify all members about new notice
	go h.notifier.NoticeCreated(n.Title, n.TitleMr, n.ID)

	c.JSON(http.StatusCreated, n)
}

func (h *NoticeHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"notices": rows, "count": len(rows)})
}

func (h *NoticeHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	n, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, n)
}

func (h *NoticeHandler) Update(c *gin.Context) {
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

// CreateWithAttachment handles multipart notice creation with an optional file.
//
//	POST /notices/with-attachment
//	multipart/form-data: title, titleMr, body, bodyMr, category, isPinned, file (optional)
func (h *NoticeHandler) CreateWithAttachment(c *gin.Context) {
	actor := middleware.GetActor(c)

	title := c.PostForm("title")
	if title == "" {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "title is required", Code: "INVALID_REQUEST"})
		return
	}
	body := c.PostForm("body")
	if body == "" {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "body is required", Code: "INVALID_REQUEST"})
		return
	}
	category := models.NoticeCategory(c.PostForm("category"))
	if category == "" {
		category = models.NoticeGeneral
	}
	isPinned := c.PostForm("isPinned") == "true"

	n := &models.Notice{
		Title: title, TitleMr: c.PostForm("titleMr"),
		Body: body, BodyMr: c.PostForm("bodyMr"),
		Category: category, IsPinned: isPinned,
		IsPublished: true,
	}

	// Handle optional file attachment
	file, header, err := c.Request.FormFile("file")
	if err == nil {
		defer file.Close()
		if header.Size > 10<<20 {
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "file exceeds 10 MB", Code: "FILE_TOO_LARGE"})
			return
		}
		raw, err := io.ReadAll(file)
		if err != nil {
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to read file", Code: "READ_ERROR"})
			return
		}
		var buf bytes.Buffer
		gz, err := gzip.NewWriterLevel(&buf, gzip.BestCompression)
		if err != nil {
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "compression init failed", Code: "COMPRESS_ERROR"})
			return
		}
		if _, err := gz.Write(raw); err != nil {
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "compression failed", Code: "COMPRESS_ERROR"})
			return
		}
		gz.Close()

		mime := header.Header.Get("Content-Type")
		if mime == "" {
			mime = http.DetectContentType(raw)
		}

		n.AttachmentData = buf.Bytes()
		n.AttachmentName = header.Filename
		n.AttachmentMime = mime
		n.AttachmentSize = int64(len(raw))
	}

	if err := h.repo.Create(actor, n); err != nil {
		writeRepoError(c, err)
		return
	}

	go h.notifier.NoticeCreated(n.Title, n.TitleMr, n.ID)

	n.AttachmentData = nil // don't send binary back
	c.JSON(http.StatusCreated, n)
}

// DownloadAttachment decompresses and streams the notice attachment.
//
//	GET /notices/:id/attachment
func (h *NoticeHandler) DownloadAttachment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	n, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	if len(n.AttachmentData) == 0 {
		c.JSON(http.StatusNotFound, response.ErrorResponse{Error: "No attachment", Code: "NO_ATTACHMENT"})
		return
	}
	gz, err := gzip.NewReader(bytes.NewReader(n.AttachmentData))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "decompression failed", Code: "DECOMPRESS_ERROR"})
		return
	}
	defer gz.Close()
	decompressed, err := io.ReadAll(gz)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "decompression failed", Code: "DECOMPRESS_ERROR"})
		return
	}
	safeName := strings.ReplaceAll(strings.ReplaceAll(n.AttachmentName, "\"", "_"), "\n", "_")
	c.Header("Content-Disposition", "inline; filename=\""+safeName+"\"")
	c.Data(http.StatusOK, n.AttachmentMime, decompressed)
}

func (h *NoticeHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}
