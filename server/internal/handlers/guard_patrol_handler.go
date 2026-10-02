package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type GuardPatrolHandler struct {
	repo *repositories.GuardPatrolRepository
}

func NewGuardPatrolHandler(repo *repositories.GuardPatrolRepository) *GuardPatrolHandler {
	return &GuardPatrolHandler{repo: repo}
}

// ─── Checkpoints ──────────────────────────────────────────────

func (h *GuardPatrolHandler) ListCheckpoints(c *gin.Context) {
	checkpoints, err := h.repo.ListCheckpoints()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"checkpoints": checkpoints, "count": len(checkpoints)})
}

type createCheckpointReq struct {
	Name       string `json:"name" binding:"required,max=100"`
	NameMr     string `json:"nameMr,omitempty"`
	Location   string `json:"location,omitempty"`
	LocationMr string `json:"locationMr,omitempty"`
	SortOrder  int    `json:"sortOrder"`
}

func (h *GuardPatrolHandler) CreateCheckpoint(c *gin.Context) {
	var req createCheckpointReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	cp := &models.PatrolCheckpoint{
		Name:       req.Name,
		NameMr:     req.NameMr,
		Location:   req.Location,
		LocationMr: req.LocationMr,
		SortOrder:  req.SortOrder,
		IsActive:   true,
	}
	if err := h.repo.CreateCheckpoint(actor, cp); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, cp)
}

func (h *GuardPatrolHandler) UpdateCheckpoint(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req struct {
		Name       string `json:"name"`
		NameMr     string `json:"nameMr"`
		Location   string `json:"location"`
		LocationMr string `json:"locationMr"`
		IsActive   *bool  `json:"isActive"`
		SortOrder  *int   `json:"sortOrder"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	updates := map[string]interface{}{}
	if req.Name != "" {
		updates["name"] = req.Name
	}
	if req.NameMr != "" {
		updates["name_mr"] = req.NameMr
	}
	if req.Location != "" {
		updates["location"] = req.Location
	}
	if req.LocationMr != "" {
		updates["location_mr"] = req.LocationMr
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}
	if req.SortOrder != nil {
		updates["sort_order"] = *req.SortOrder
	}
	if err := h.repo.UpdateCheckpoint(id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Updated"})
}

func (h *GuardPatrolHandler) DeleteCheckpoint(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	if err := h.repo.DeleteCheckpoint(id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}

// ─── Rounds ───────────────────────────────────────────────────

func (h *GuardPatrolHandler) ListRounds(c *gin.Context) {
	var date *time.Time
	if d := c.Query("date"); d != "" {
		if t, err := time.Parse("2006-01-02", d); err == nil {
			date = &t
		}
	}
	status := c.Query("status")
	rounds, err := h.repo.ListRounds(date, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"rounds": rounds, "count": len(rounds)})
}

func (h *GuardPatrolHandler) GetRound(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	round, err := h.repo.GetRoundByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, round)
}

type startRoundReq struct {
	GuardName string             `json:"guardName" binding:"required,max=100"`
	ShiftType models.PatrolShift `json:"shiftType" binding:"required"`
	Notes     string             `json:"notes,omitempty"`
}

func (h *GuardPatrolHandler) StartRound(c *gin.Context) {
	var req startRoundReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	round := &models.PatrolRound{
		GuardName: req.GuardName,
		ShiftType: req.ShiftType,
		Notes:     req.Notes,
		StartTime: time.Now(),
	}
	if err := h.repo.StartRound(actor, round); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, round)
}

func (h *GuardPatrolHandler) CompleteRound(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req struct {
		Notes string `json:"notes"`
	}
	_ = c.ShouldBindJSON(&req) // intentionally ignored: body is optional (Notes only)
	if err := h.repo.CompleteRound(id, req.Notes); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Round completed"})
}

// ─── Scans ────────────────────────────────────────────────────

type addScanReq struct {
	CheckpointID uuid.UUID `json:"checkpointId" binding:"required"`
	Lat          float64   `json:"lat"`
	Lng          float64   `json:"lng"`
	Notes        string    `json:"notes,omitempty"`
}

func (h *GuardPatrolHandler) AddScan(c *gin.Context) {
	roundID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid round id", Code: "INVALID_ID"})
		return
	}
	var req addScanReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	scan := &models.PatrolScan{
		RoundID:      roundID,
		CheckpointID: req.CheckpointID,
		ScannedAt:    time.Now(),
		Lat:          req.Lat,
		Lng:          req.Lng,
		Notes:        req.Notes,
	}
	if err := h.repo.AddScan(scan); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, scan)
}

// ─── Incidents ────────────────────────────────────────────────

func (h *GuardPatrolHandler) ListIncidents(c *gin.Context) {
	incidentType := c.Query("type")
	severity := c.Query("severity")
	status := c.Query("status")
	incidents, err := h.repo.ListIncidents(incidentType, severity, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"incidents": incidents, "count": len(incidents)})
}

func (h *GuardPatrolHandler) GetIncident(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	incident, err := h.repo.GetIncidentByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, incident)
}

type createIncidentReq struct {
	Title          string                 `json:"title" binding:"required,max=200"`
	TitleMr        string                 `json:"titleMr,omitempty"`
	Description    string                 `json:"description,omitempty"`
	IncidentType   models.IncidentType    `json:"incidentType" binding:"required"`
	Severity       models.IncidentSeverity `json:"severity" binding:"required"`
	Location       string                 `json:"location,omitempty"`
	ReportedByName string                 `json:"reportedByName,omitempty"`
}

func (h *GuardPatrolHandler) CreateIncident(c *gin.Context) {
	var req createIncidentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	incident := &models.PatrolIncident{
		Title:          req.Title,
		TitleMr:        req.TitleMr,
		Description:    req.Description,
		IncidentType:   req.IncidentType,
		Severity:       req.Severity,
		Location:       req.Location,
		ReportedByName: req.ReportedByName,
		Status:         models.IncidentReported,
	}
	if err := h.repo.CreateIncident(actor, incident); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, incident)
}

func (h *GuardPatrolHandler) UpdateIncidentStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req struct {
		Status models.IncidentStatus `json:"status" binding:"required"`
		Notes  string                `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.UpdateIncidentStatus(actor, id, req.Status, req.Notes); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Status updated"})
}
