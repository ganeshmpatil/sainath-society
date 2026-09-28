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
	ComponentType      string  `json:"componentType,omitempty"`
	ComponentConfig    string  `json:"componentConfig,omitempty"`
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
	compType := models.CompCustom
	if req.ComponentType != "" {
		compType = models.ComponentType(req.ComponentType)
	}
	act := &models.WorkflowActivity{
		Title:           req.Title,
		TitleMr:         req.TitleMr,
		Description:     req.Description,
		DescriptionMr:   req.DescriptionMr,
		ComponentType:   compType,
		ComponentConfig: req.ComponentConfig,
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

// ─── Component catalogue ─────────────────────────────────────────

func (h *WorkflowHandler) ListComponents(c *gin.Context) {
	components := []gin.H{
		{"type": "SCHEDULE_MEETING", "label": "Schedule Meeting", "labelMr": "सभा नियोजन", "icon": "event", "color": "#3B82F6"},
		{"type": "SHARE_MINUTES", "label": "Share Minutes", "labelMr": "इतिवृत्त शेअर करा", "icon": "description", "color": "#8B5CF6"},
		{"type": "UPLOAD_DOCUMENT", "label": "Upload Document", "labelMr": "कागदपत्र अपलोड", "icon": "upload_file", "color": "#10B981"},
		{"type": "ISSUE_CHEQUE", "label": "Issue Cheque / Payment", "labelMr": "चेक / देयक", "icon": "payments", "color": "#F59E0B"},
		{"type": "UPLOAD_INVOICE", "label": "Upload Invoice", "labelMr": "बीजक अपलोड", "icon": "receipt_long", "color": "#EF4444"},
		{"type": "SEND_NOTICE", "label": "Send Notice", "labelMr": "सूचना पाठवा", "icon": "campaign", "color": "#EC4899"},
		{"type": "COLLECT_APPROVAL", "label": "Collect Approval", "labelMr": "मंजुरी घ्या", "icon": "how_to_vote", "color": "#06B6D4"},
		{"type": "CUSTOM", "label": "Custom Task", "labelMr": "सानुकूल कार्य", "icon": "task_alt", "color": "#64748B"},
	}
	c.JSON(http.StatusOK, gin.H{"components": components})
}

// ─── Seed factory templates ──────────────────────────────────────

func (h *WorkflowHandler) SeedTemplates(c *gin.Context) {
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "Admin only", Code: "FORBIDDEN"})
		return
	}

	templates := []struct {
		Title       string
		TitleMr     string
		Description string
		DescMr      string
		Category    models.WorkflowCategory
		Activities  []struct {
			Title     string
			TitleMr   string
			CompType  models.ComponentType
			Desc      string
			DescMr    string
		}
	}{
		{
			Title: "Conduct AGM", TitleMr: "वार्षिक सभा आयोजन",
			Description: "Complete checklist for conducting Annual General Meeting", DescMr: "वार्षिक सर्वसाधारण सभा आयोजनासाठी संपूर्ण चेकलिस्ट",
			Category: models.WFCatAGM,
			Activities: []struct {
				Title    string
				TitleMr  string
				CompType models.ComponentType
				Desc     string
				DescMr   string
			}{
				{"Schedule meeting date & venue", "सभेची तारीख व ठिकाण ठरवा", models.CompScheduleMeeting, "Fix date, time and venue for AGM", "सभेची तारीख, वेळ आणि ठिकाण निश्चित करा"},
				{"Publish agenda notice to members", "सदस्यांना अजेंडा सूचना पाठवा", models.CompSendNotice, "Send 14-day advance notice with agenda", "अजेंडासह 14 दिवस अगोदर सूचना पाठवा"},
				{"Arrange refreshments & logistics", "जेवणाची आणि व्यवस्थेची तयारी", models.CompCustom, "Arrange chairs, projector, refreshments", "खुर्च्या, प्रोजेक्टर, नाश्ता व्यवस्था"},
				{"Conduct the meeting", "सभा आयोजित करा", models.CompScheduleMeeting, "Take attendance and conduct meeting as per agenda", "उपस्थिती घ्या आणि अजेंडानुसार सभा चालवा"},
				{"Record minutes of meeting", "सभेचे इतिवृत्त नोंदवा", models.CompShareMinutes, "Document all discussions, decisions and action items", "सर्व चर्चा, निर्णय आणि कृती बाबी नोंदवा"},
				{"Share minutes with members", "सदस्यांना इतिवृत्त पाठवा", models.CompSendNotice, "Circulate approved minutes to all members", "मंजूर इतिवृत्त सर्व सदस्यांना पाठवा"},
				{"Collect approval on resolutions", "ठरावांवर मंजुरी घ्या", models.CompCollectApproval, "Get member signatures on passed resolutions", "मंजूर ठरावांवर सदस्यांच्या स्वाक्षऱ्या घ्या"},
			},
		},
		{
			Title: "Festival Celebration", TitleMr: "सण उत्सव आयोजन",
			Description: "Plan and execute society festival celebration", DescMr: "सोसायटी सण उत्सवाचे नियोजन आणि आयोजन",
			Category: models.WFCatFestival,
			Activities: []struct {
				Title    string
				TitleMr  string
				CompType models.ComponentType
				Desc     string
				DescMr   string
			}{
				{"Form festival sub-committee", "उत्सव उपसमिती स्थापन करा", models.CompCustom, "Identify volunteers and assign responsibilities", "स्वयंसेवक ओळखा आणि जबाबदाऱ्या नेमा"},
				{"Collect contributions from members", "सदस्यांकडून वर्गणी गोळा करा", models.CompIssueCheque, "Decide per-flat contribution and collect", "प्रति फ्लॅट वर्गणी ठरवा आणि गोळा करा"},
				{"Book vendor / supplies", "विक्रेता / साहित्य बुक करा", models.CompUploadInvoice, "Finalize vendors for idol, decorations, food", "मूर्ती, सजावट, जेवणासाठी विक्रेते निश्चित करा"},
				{"Arrange decoration", "सजावट व्यवस्था करा", models.CompCustom, "Setup pandal, lighting and decoration", "मंडप, रोषणाई आणि सजावट तयार करा"},
				{"Conduct celebration event", "उत्सव कार्यक्रम आयोजित करा", models.CompScheduleMeeting, "Execute the festival program", "सण कार्यक्रम पार पाडा"},
				{"Upload photos & documentation", "फोटो आणि कागदपत्रे अपलोड करा", models.CompUploadDocument, "Archive event photos and receipts", "कार्यक्रमाचे फोटो आणि पावत्या जतन करा"},
				{"Share expense report", "खर्चाचा अहवाल शेअर करा", models.CompUploadInvoice, "Prepare and share final expense statement", "अंतिम खर्च विवरणपत्र तयार करा आणि शेअर करा"},
			},
		},
		{
			Title: "Major Repair Work", TitleMr: "मोठी दुरुस्ती कामे",
			Description: "End-to-end tracking for society repair and maintenance projects", DescMr: "सोसायटी दुरुस्ती आणि देखभाल प्रकल्पांचे संपूर्ण ट्रॅकिंग",
			Category: models.WFCatRepair,
			Activities: []struct {
				Title    string
				TitleMr  string
				CompType models.ComponentType
				Desc     string
				DescMr   string
			}{
				{"Identify scope & get quotations", "कामाची व्याप्ती ठरवा आणि कोटेशन मिळवा", models.CompUploadDocument, "Get 3 vendor quotations for the work", "कामासाठी 3 विक्रेत्यांचे कोटेशन मिळवा"},
				{"Get committee approval", "समिती मंजुरी घ्या", models.CompCollectApproval, "Present quotations and get approval in committee meeting", "कोटेशन सादर करा आणि समिती सभेत मंजुरी घ्या"},
				{"Issue work order to vendor", "विक्रेत्याला वर्क ऑर्डर द्या", models.CompUploadDocument, "Finalize vendor and issue formal work order", "विक्रेता निश्चित करा आणि अधिकृत वर्क ऑर्डर द्या"},
				{"Make advance payment", "आगाऊ रक्कम द्या", models.CompIssueCheque, "Release advance as per work order terms", "वर्क ऑर्डर अटींनुसार आगाऊ रक्कम द्या"},
				{"Monitor work progress", "कामाची प्रगती तपासा", models.CompCustom, "Regular site visits and progress tracking", "नियमित साइट भेटी आणि प्रगती ट्रॅकिंग"},
				{"Verify completion & quality", "काम पूर्ण आणि गुणवत्ता तपासा", models.CompCustom, "Inspect completed work for quality", "पूर्ण झालेल्या कामाची गुणवत्ता तपासा"},
				{"Process final payment", "अंतिम देयक प्रक्रिया", models.CompIssueCheque, "Release balance payment after satisfactory completion", "समाधानकारक पूर्ततेनंतर उर्वरित रक्कम द्या"},
				{"Upload completion certificate", "पूर्णत्व प्रमाणपत्र अपलोड करा", models.CompUploadDocument, "Archive work completion certificate and warranty docs", "काम पूर्ण प्रमाणपत्र आणि वॉरंटी कागदपत्रे जतन करा"},
			},
		},
		{
			Title: "Committee Election", TitleMr: "समिती निवडणूक",
			Description: "Process for conducting society committee election", DescMr: "सोसायटी समिती निवडणूक प्रक्रिया",
			Category: models.WFCatElection,
			Activities: []struct {
				Title    string
				TitleMr  string
				CompType models.ComponentType
				Desc     string
				DescMr   string
			}{
				{"Announce election schedule", "निवडणूक वेळापत्रक जाहीर करा", models.CompSendNotice, "Notify members about upcoming election dates", "सदस्यांना आगामी निवडणुकीच्या तारखा कळवा"},
				{"Invite nominations", "नामांकने मागवा", models.CompSendNotice, "Open nomination period with deadline", "मुदतीसह नामांकन कालावधी उघडा"},
				{"Verify nominations", "नामांकनांची पडताळणी करा", models.CompCustom, "Check eligibility of all nominees", "सर्व उमेदवारांची पात्रता तपासा"},
				{"Publish final candidate list", "अंतिम उमेदवार यादी प्रकाशित करा", models.CompSendNotice, "Share verified candidate list with members", "पडताळलेली उमेदवार यादी सदस्यांसोबत शेअर करा"},
				{"Conduct election / voting", "निवडणूक / मतदान घ्या", models.CompCollectApproval, "Arrange voting and collect ballots", "मतदानाची व्यवस्था करा आणि मतपत्रिका गोळा करा"},
				{"Declare results", "निकाल जाहीर करा", models.CompSendNotice, "Count votes and announce winners", "मतमोजणी करा आणि विजेते जाहीर करा"},
				{"Handover documentation", "कागदपत्रे हस्तांतरित करा", models.CompUploadDocument, "Transfer all society records to new committee", "सर्व सोसायटी रेकॉर्ड नवीन समितीकडे हस्तांतरित करा"},
			},
		},
		{
			Title: "Compliance & Audit", TitleMr: "लेखापरीक्षण व अनुपालन",
			Description: "Annual audit and regulatory compliance checklist", DescMr: "वार्षिक लेखापरीक्षण आणि नियामक अनुपालन चेकलिस्ट",
			Category: models.WFCatCompliance,
			Activities: []struct {
				Title    string
				TitleMr  string
				CompType models.ComponentType
				Desc     string
				DescMr   string
			}{
				{"Appoint auditor", "लेखापरीक्षक नियुक्त करा", models.CompCustom, "Select and appoint chartered accountant", "चार्टर्ड अकाउंटंट निवडा आणि नियुक्त करा"},
				{"Gather financial records", "आर्थिक नोंदी गोळा करा", models.CompUploadDocument, "Compile all receipts, bank statements, invoices", "सर्व पावत्या, बँक स्टेटमेंट, बीजके संकलित करा"},
				{"Conduct audit review meeting", "लेखापरीक्षण आढावा सभा घ्या", models.CompScheduleMeeting, "Review findings with auditor", "लेखापरीक्षकासोबत निष्कर्षांचा आढावा घ्या"},
				{"Address audit observations", "लेखापरीक्षण निरीक्षणांवर कार्यवाही", models.CompCustom, "Resolve any issues raised by auditor", "लेखापरीक्षकाने उपस्थित केलेल्या समस्या सोडवा"},
				{"Upload audit report", "लेखापरीक्षण अहवाल अपलोड करा", models.CompUploadDocument, "Upload signed audit report", "स्वाक्षरीत लेखापरीक्षण अहवाल अपलोड करा"},
				{"Share report with members", "सदस्यांना अहवाल शेअर करा", models.CompSendNotice, "Circulate audit report to all members", "सर्व सदस्यांना लेखापरीक्षण अहवाल पाठवा"},
				{"File compliance documents", "अनुपालन कागदपत्रे दाखल करा", models.CompUploadDocument, "Submit to registrar and relevant authorities", "निबंधक आणि संबंधित प्राधिकरणांना सादर करा"},
			},
		},
		{
			Title: "Society Event / Function", TitleMr: "सामाजिक कार्यक्रम",
			Description: "Organize any society gathering or cultural event", DescMr: "कोणत्याही सोसायटी सभा किंवा सांस्कृतिक कार्यक्रमाचे आयोजन",
			Category: models.WFCatGeneral,
			Activities: []struct {
				Title    string
				TitleMr  string
				CompType models.ComponentType
				Desc     string
				DescMr   string
			}{
				{"Plan event & set date", "कार्यक्रम नियोजन आणि तारीख ठरवा", models.CompScheduleMeeting, "Decide event type, date and budget", "कार्यक्रम प्रकार, तारीख आणि बजेट ठरवा"},
				{"Send invitation notice", "निमंत्रण सूचना पाठवा", models.CompSendNotice, "Notify all residents about the event", "सर्व रहिवाशांना कार्यक्रमाबद्दल कळवा"},
				{"Arrange venue & logistics", "ठिकाण आणि व्यवस्था तयार करा", models.CompCustom, "Book hall, arrange seating, sound system", "हॉल बुक करा, बसण्याची व्यवस्था, ध्वनी यंत्रणा"},
				{"Collect RSVP / registrations", "प्रतिसाद / नोंदणी गोळा करा", models.CompCollectApproval, "Track who is attending", "कोण येणार आहे याचा मागोवा ठेवा"},
				{"Conduct event", "कार्यक्रम पार पाडा", models.CompCustom, "Execute the event as planned", "नियोजनानुसार कार्यक्रम पार पाडा"},
				{"Upload event photos", "कार्यक्रमाचे फोटो अपलोड करा", models.CompUploadDocument, "Share memories with residents", "रहिवाशांसोबत आठवणी शेअर करा"},
				{"Share expense summary", "खर्चाचा सारांश शेअर करा", models.CompUploadInvoice, "Publish final income/expense statement", "अंतिम उत्पन्न/खर्च विवरणपत्र प्रकाशित करा"},
			},
		},
		{
			Title: "Emergency Response", TitleMr: "आपत्कालीन प्रतिसाद",
			Description: "Rapid response checklist for emergencies (fire, flood, structural)", DescMr: "आपत्कालीन परिस्थितीसाठी (आग, पूर, संरचनात्मक) जलद प्रतिसाद चेकलिस्ट",
			Category: models.WFCatGeneral,
			Activities: []struct {
				Title    string
				TitleMr  string
				CompType models.ComponentType
				Desc     string
				DescMr   string
			}{
				{"Assess situation & alert committee", "परिस्थितीचे मूल्यांकन करा आणि समितीला सूचित करा", models.CompSendNotice, "Evaluate severity and inform committee members", "तीव्रता तपासा आणि समिती सदस्यांना कळवा"},
				{"Contact emergency services", "आपत्कालीन सेवांशी संपर्क साधा", models.CompCustom, "Call fire brigade, ambulance, police as needed", "आवश्यकतेनुसार अग्निशमन, रुग्णवाहिका, पोलिसांना बोलवा"},
				{"Notify all residents", "सर्व रहिवाशांना सूचित करा", models.CompSendNotice, "Send emergency alert to all members", "सर्व सदस्यांना आपत्कालीन सूचना पाठवा"},
				{"Arrange immediate resources", "तात्काळ साधनसामग्री जमवा", models.CompCustom, "Water, first aid, temporary shelter arrangements", "पाणी, प्रथमोपचार, तात्पुरत्या निवाऱ्याची व्यवस्था"},
				{"Document damage / incident", "नुकसान / घटना नोंदवा", models.CompUploadDocument, "Take photos and document all damage", "फोटो काढा आणि सर्व नुकसान नोंदवा"},
				{"File insurance claim", "विमा दावा दाखल करा", models.CompUploadDocument, "Submit claim with damage documentation", "नुकसान कागदपत्रांसह दावा सादर करा"},
				{"Share status update with residents", "रहिवाशांना स्थिती अपडेट पाठवा", models.CompSendNotice, "Keep members informed of recovery progress", "पुनर्प्राप्तीच्या प्रगतीबद्दल सदस्यांना माहिती द्या"},
			},
		},
	}

	created := 0
	for _, tmpl := range templates {
		// Skip if template with same title already exists
		var count int64
		h.repo.DB().Model(&models.Workflow{}).Where("title = ? AND is_template = ?", tmpl.Title, true).Count(&count)
		if count > 0 {
			continue
		}

		wf := &models.Workflow{
			Title:             tmpl.Title,
			TitleMr:           tmpl.TitleMr,
			Description:       tmpl.Description,
			DescriptionMr:     tmpl.DescMr,
			Category:          tmpl.Category,
			Status:            models.WorkflowDraft,
			IsTemplate:        true,
			CreatedByMemberID: actor.MemberID,
			IsActive:          true,
		}
		if err := h.repo.CreateRaw(wf); err != nil {
			continue
		}

		for i, a := range tmpl.Activities {
			act := &models.WorkflowActivity{
				WorkflowID:    wf.ID,
				Title:         a.Title,
				TitleMr:       a.TitleMr,
				Description:   a.Desc,
				DescriptionMr: a.DescMr,
				Position:      i,
				Status:        models.ActivityPending,
				ComponentType: a.CompType,
			}
			h.repo.CreateActivityRaw(act)
		}
		created++
	}

	c.JSON(http.StatusOK, gin.H{"message": "Templates seeded", "created": created})
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
