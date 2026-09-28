package handlers

import (
	"bytes"
	"compress/gzip"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type WorkflowHandler struct {
	repo *repositories.WorkflowRepository
}

func NewWorkflowHandler(repo *repositories.WorkflowRepository) *WorkflowHandler {
	return &WorkflowHandler{repo: repo}
}

// ─── Workflow endpoints ──────────────────────────────────────────

type createWorkflowReq struct {
	Title         string                  `json:"title" binding:"required,max=300"`
	TitleMr       string                  `json:"titleMr,omitempty"`
	Description   string                  `json:"description,omitempty"`
	DescriptionMr string                  `json:"descriptionMr,omitempty"`
	Category      models.WorkflowCategory `json:"category" binding:"required"`
	IsTemplate    bool                    `json:"isTemplate,omitempty"`
	TargetDate    string                  `json:"targetDate,omitempty"`
}

func (h *WorkflowHandler) Create(c *gin.Context) {
	var req createWorkflowReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	wf := &models.Workflow{
		Title:         req.Title,
		TitleMr:       req.TitleMr,
		Description:   req.Description,
		DescriptionMr: req.DescriptionMr,
		Category:      req.Category,
		Status:        models.WorkflowDraft,
		IsTemplate:    req.IsTemplate,
		IsActive:      true,
	}
	if req.TargetDate != "" {
		if t, err := parseDate(req.TargetDate); err == nil {
			wf.TargetDate = &t
		}
	}
	if err := h.repo.Create(actor, wf); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, wf)
}

func (h *WorkflowHandler) List(c *gin.Context) {
	status := c.Query("status")
	isTemplate := c.Query("is_template") == "true"
	rows, err := h.repo.List(status, isTemplate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to list workflows", Code: "LIST_FAILED"})
		return
	}
	// Compute progress for each
	type wfWithProgress struct {
		models.Workflow
		Progress gin.H `json:"progress"`
	}
	var result []wfWithProgress
	for _, w := range rows {
		result = append(result, wfWithProgress{
			Workflow: w,
			Progress: computeProgress(w.Activities),
		})
	}
	c.JSON(http.StatusOK, gin.H{"workflows": result, "count": len(result)})
}

func (h *WorkflowHandler) ListTemplates(c *gin.Context) {
	rows, err := h.repo.List("", true)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to list templates", Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"templates": rows, "count": len(rows)})
}

func (h *WorkflowHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	wf, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"workflow": wf,
		"progress": computeProgress(wf.Activities),
	})
}

func (h *WorkflowHandler) Update(c *gin.Context) {
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

type updateWFStatusReq struct {
	Status models.WorkflowStatus `json:"status" binding:"required"`
}

func (h *WorkflowHandler) UpdateStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateWFStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.UpdateStatus(actor, id, req.Status); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Status updated"})
}

func (h *WorkflowHandler) Delete(c *gin.Context) {
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

type instantiateReq struct {
	Title      string `json:"title" binding:"required"`
	TitleMr    string `json:"titleMr,omitempty"`
	TargetDate string `json:"targetDate,omitempty"`
}

func (h *WorkflowHandler) Instantiate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req instantiateReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	var targetDate *time.Time
	if req.TargetDate != "" {
		if t, err := parseDate(req.TargetDate); err == nil {
			targetDate = &t
		}
	}
	wf, err := h.repo.Instantiate(actor, id, req.Title, req.TitleMr, targetDate)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, wf)
}

// ─── Activity endpoints ──────────────────────────────────────────

type addActivityReq struct {
	Title              string  `json:"title" binding:"required,max=300"`
	TitleMr            string  `json:"titleMr,omitempty"`
	Description        string  `json:"description,omitempty"`
	DescriptionMr      string  `json:"descriptionMr,omitempty"`
	DueDate            string  `json:"dueDate,omitempty"`
	AssignedToMemberID *string `json:"assignedToMemberId,omitempty"`
}

func (h *WorkflowHandler) AddActivity(c *gin.Context) {
	wfID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req addActivityReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	act := &models.WorkflowActivity{
		Title:         req.Title,
		TitleMr:       req.TitleMr,
		Description:   req.Description,
		DescriptionMr: req.DescriptionMr,
	}
	if req.DueDate != "" {
		if t, err := parseDate(req.DueDate); err == nil {
			act.DueDate = &t
		}
	}
	if req.AssignedToMemberID != nil && *req.AssignedToMemberID != "" {
		if uid, err := uuid.Parse(*req.AssignedToMemberID); err == nil {
			act.AssignedToMemberID = &uid
		}
	}
	if err := h.repo.AddActivity(actor, wfID, act); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, act)
}

func (h *WorkflowHandler) UpdateActivity(c *gin.Context) {
	wfID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actID, err := uuid.Parse(c.Param("actId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid activity id", Code: "INVALID_ID"})
		return
	}
	var patch map[string]interface{}
	if err := c.ShouldBindJSON(&patch); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.UpdateActivity(actor, wfID, actID, patch); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Activity updated"})
}

type updateActStatusReq struct {
	Status models.ActivityStatus `json:"status" binding:"required"`
}

func (h *WorkflowHandler) UpdateActivityStatus(c *gin.Context) {
	wfID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actID, err := uuid.Parse(c.Param("actId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid activity id", Code: "INVALID_ID"})
		return
	}
	var req updateActStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.UpdateActivityStatus(actor, wfID, actID, req.Status); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Activity status updated"})
}

type reorderReq struct {
	ActivityIDs []string `json:"activityIds" binding:"required"`
}

func (h *WorkflowHandler) ReorderActivities(c *gin.Context) {
	wfID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req reorderReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	var ids []uuid.UUID
	for _, s := range req.ActivityIDs {
		id, err := uuid.Parse(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid activity id: " + s, Code: "INVALID_ID"})
			return
		}
		ids = append(ids, id)
	}
	actor := middleware.GetActor(c)
	if err := h.repo.ReorderActivities(actor, wfID, ids); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Reordered"})
}

func (h *WorkflowHandler) DeleteActivity(c *gin.Context) {
	wfID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actID, err := uuid.Parse(c.Param("actId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid activity id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.DeleteActivity(actor, wfID, actID); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Activity deleted"})
}

// ─── Comment endpoint ────────────────────────────────────────────

type addCommentWFReq struct {
	Body string `json:"body" binding:"required"`
}

func (h *WorkflowHandler) AddComment(c *gin.Context) {
	wfID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actID, err := uuid.Parse(c.Param("actId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid activity id", Code: "INVALID_ID"})
		return
	}
	var req addCommentWFReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	comment, err := h.repo.AddComment(actor, wfID, actID, req.Body)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, comment)
}

// ─── Attachment endpoints ────────────────────────────────────────

const maxAttachmentSize = 5 * 1024 * 1024 // 5 MB

func (h *WorkflowHandler) UploadAttachment(c *gin.Context) {
	wfID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actID, err := uuid.Parse(c.Param("actId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid activity id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "file is required", Code: "INVALID_REQUEST"})
		return
	}
	defer file.Close()

	if header.Size > maxAttachmentSize {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "file exceeds 5 MB", Code: "FILE_TOO_LARGE"})
		return
	}

	raw, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to read file", Code: "READ_ERROR"})
		return
	}

	var buf bytes.Buffer
	gz, _ := gzip.NewWriterLevel(&buf, gzip.BestCompression)
	gz.Write(raw)
	gz.Close()

	att := &models.WorkflowActivityAttachment{
		ActivityID:     actID,
		FileName:       header.Filename,
		MimeType:       header.Header.Get("Content-Type"),
		OriginalSize:   int64(len(raw)),
		CompressedSize: int64(buf.Len()),
		FileData:       buf.Bytes(),
		UploadedByID:   actor.MemberID,
	}
	if err := h.repo.AddAttachment(actor, wfID, att); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": att.ID, "fileName": att.FileName, "size": att.OriginalSize})
}

func (h *WorkflowHandler) DownloadAttachment(c *gin.Context) {
	attID, err := uuid.Parse(c.Param("attId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid attachment id", Code: "INVALID_ID"})
		return
	}
	att, err := h.repo.GetAttachment(attID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	gz, err := gzip.NewReader(bytes.NewReader(att.FileData))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "decompress failed", Code: "DECOMPRESS_ERROR"})
		return
	}
	defer gz.Close()
	data, _ := io.ReadAll(gz)

	c.Header("Content-Disposition", "attachment; filename=\""+att.FileName+"\"")
	c.Data(http.StatusOK, att.MimeType, data)
}

// ─── Audit endpoint ──────────────────────────────────────────────

func (h *WorkflowHandler) AuditLog(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	logs, err := h.repo.ListAuditLogs(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to fetch audit logs", Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"logs": logs, "count": len(logs)})
}

// ─── Helpers ─────────────────────────────────────────────────────

func parseDate(s string) (time.Time, error) {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		t, err = time.Parse("2006-01-02", s)
	}
	return t, err
}

func computeProgress(activities []models.WorkflowActivity) gin.H {
	total := len(activities)
	completed := 0
	skipped := 0
	inProgress := 0
	for _, a := range activities {
		switch a.Status {
		case models.ActivityCompleted:
			completed++
		case models.ActivitySkipped:
			skipped++
		case models.ActivityInProgress:
			inProgress++
		}
	}
	pct := 0
	if total > 0 {
		pct = (completed + skipped) * 100 / total
	}
	return gin.H{
		"total":      total,
		"completed":  completed,
		"skipped":    skipped,
		"inProgress": inProgress,
		"pending":    total - completed - skipped - inProgress,
		"percent":    pct,
	}
}
