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
)

const maxDocUploadSize = 10 << 20 // 10 MB

type MemberDocumentHandler struct {
	repo *repositories.MemberDocumentRepository
}

func NewMemberDocumentHandler(repo *repositories.MemberDocumentRepository) *MemberDocumentHandler {
	return &MemberDocumentHandler{repo: repo}
}

// Upload handles multipart file upload, gzip-compresses the file, and stores
// it as BYTEA in the soc_mitra_member_documents table.
//
//	POST /member-documents/upload
//	multipart/form-data fields: file, docType, title, titleMr (optional)
func (h *MemberDocumentHandler) Upload(c *gin.Context) {
	actor := middleware.GetActor(c)

	docType := models.MemberDocType(c.PostForm("docType"))
	if docType == "" {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "docType is required", Code: "INVALID_REQUEST"})
		return
	}
	title := c.PostForm("title")
	if title == "" {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "title is required", Code: "INVALID_REQUEST"})
		return
	}
	titleMr := c.PostForm("titleMr")

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "file is required", Code: "INVALID_REQUEST"})
		return
	}
	defer file.Close()

	if header.Size > maxDocUploadSize {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "file size exceeds 10 MB limit", Code: "FILE_TOO_LARGE"})
		return
	}

	// Read file content
	raw, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to read file", Code: "READ_ERROR"})
		return
	}

	// Gzip compress
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

	mimeType := header.Header.Get("Content-Type")
	if mimeType == "" {
		mimeType = http.DetectContentType(raw)
	}

	doc := &models.MemberDocument{
		DocType:        docType,
		Title:          title,
		TitleMr:        titleMr,
		FileName:       header.Filename,
		MimeType:       mimeType,
		OriginalSize:   int64(len(raw)),
		CompressedSize: int64(buf.Len()),
		FileData:       buf.Bytes(),
	}

	if err := h.repo.Create(actor, doc); err != nil {
		writeRepoError(c, err)
		return
	}

	// Return metadata without file data
	doc.FileData = nil
	c.JSON(http.StatusCreated, doc)
}

// List returns document metadata for the authenticated member.
//
//	GET /member-documents?docType=AADHAAR&memberId=...
func (h *MemberDocumentHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)

	var docType *models.MemberDocType
	if s := c.Query("docType"); s != "" {
		dt := models.MemberDocType(s)
		docType = &dt
	}

	var memberID *uuid.UUID
	if s := c.Query("memberId"); s != "" {
		if id, err := uuid.Parse(s); err == nil {
			memberID = &id
		}
	}

	rows, err := h.repo.List(actor, docType, memberID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"memberDocuments": rows, "count": len(rows)})
}

// GetByID returns document metadata (without file data).
//
//	GET /member-documents/:id
func (h *MemberDocumentHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	d, err := h.repo.GetMetadata(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, d)
}

// Download decompresses and streams the stored file back to the client.
//
//	GET /member-documents/:id/download
func (h *MemberDocumentHandler) Download(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	d, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	// Decompress gzip
	gz, err := gzip.NewReader(bytes.NewReader(d.FileData))
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

	safeName := strings.ReplaceAll(strings.ReplaceAll(d.FileName, "\"", "_"), "\n", "_")
	c.Header("Content-Disposition", "attachment; filename=\""+safeName+"\"")
	c.Data(http.StatusOK, d.MimeType, decompressed)
}

// Delete permanently removes a member document.
//
//	DELETE /member-documents/:id
func (h *MemberDocumentHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Document deleted"})
}
