package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type ElectionHandler struct {
	repo *repositories.ElectionRepository
}

func NewElectionHandler(repo *repositories.ElectionRepository) *ElectionHandler {
	return &ElectionHandler{repo: repo}
}

// List returns all elections.
func (h *ElectionHandler) List(c *gin.Context) {
	rows, err := h.repo.List()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"elections": rows, "count": len(rows)})
}

// GetByID returns a single election with positions and candidates.
func (h *ElectionHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	e, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, e)
}

type createElectionReq struct {
	Title               string `json:"title" binding:"required"`
	TitleMr             string `json:"titleMr"`
	Description         string `json:"description"`
	NominationStartDate string `json:"nominationStartDate" binding:"required"`
	NominationEndDate   string `json:"nominationEndDate" binding:"required"`
	VotingStartDate     string `json:"votingStartDate" binding:"required"`
	VotingEndDate       string `json:"votingEndDate" binding:"required"`
}

func parseElectionDate(s string) (time.Time, error) {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		t, err = time.Parse("2006-01-02", s)
	}
	return t, err
}

// Create adds a new election. Admin only.
func (h *ElectionHandler) Create(c *gin.Context) {
	var req createElectionReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}

	nomStart, err := parseElectionDate(req.NominationStartDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid nominationStartDate", Code: "INVALID_DATE"})
		return
	}
	nomEnd, err := parseElectionDate(req.NominationEndDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid nominationEndDate", Code: "INVALID_DATE"})
		return
	}
	voteStart, err := parseElectionDate(req.VotingStartDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid votingStartDate", Code: "INVALID_DATE"})
		return
	}
	voteEnd, err := parseElectionDate(req.VotingEndDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid votingEndDate", Code: "INVALID_DATE"})
		return
	}

	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	e := &models.Election{
		Title:               req.Title,
		TitleMr:             req.TitleMr,
		Description:         req.Description,
		NominationStartDate: nomStart,
		NominationEndDate:   nomEnd,
		VotingStartDate:     voteStart,
		VotingEndDate:       voteEnd,
	}
	if err := h.repo.Create(actor, e); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, e)
}

type updateElectionReq struct {
	Title               string `json:"title"`
	TitleMr             string `json:"titleMr"`
	Description         string `json:"description"`
	NominationStartDate string `json:"nominationStartDate"`
	NominationEndDate   string `json:"nominationEndDate"`
	VotingStartDate     string `json:"votingStartDate"`
	VotingEndDate       string `json:"votingEndDate"`
}

// Update modifies an election. Admin only.
func (h *ElectionHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req updateElectionReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	updates := map[string]interface{}{}
	if req.Title != "" {
		updates["title"] = req.Title
	}
	if req.TitleMr != "" {
		updates["title_mr"] = req.TitleMr
	}
	if req.Description != "" {
		updates["description"] = req.Description
	}
	if req.NominationStartDate != "" {
		if t, err := parseElectionDate(req.NominationStartDate); err == nil {
			updates["nomination_start_date"] = t
		}
	}
	if req.NominationEndDate != "" {
		if t, err := parseElectionDate(req.NominationEndDate); err == nil {
			updates["nomination_end_date"] = t
		}
	}
	if req.VotingStartDate != "" {
		if t, err := parseElectionDate(req.VotingStartDate); err == nil {
			updates["voting_start_date"] = t
		}
	}
	if req.VotingEndDate != "" {
		if t, err := parseElectionDate(req.VotingEndDate); err == nil {
			updates["voting_end_date"] = t
		}
	}
	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "No valid fields to update", Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.Update(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Election updated"})
}

type electionStatusReq struct {
	Status string `json:"status" binding:"required"`
}

// UpdateStatus changes the election status. Admin only.
func (h *ElectionHandler) UpdateStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req electionStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	switch req.Status {
	case "UPCOMING", "NOMINATIONS_OPEN", "VOTING_OPEN", "COMPLETED", "CANCELLED":
	default:
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid status", Code: "INVALID_STATUS"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.UpdateStatus(actor, id, req.Status); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Election status updated to " + req.Status})
}

type addPositionReq struct {
	Title         string `json:"title" binding:"required"`
	TitleMr       string `json:"titleMr"`
	MaxCandidates int    `json:"maxCandidates"`
	SortOrder     int    `json:"sortOrder"`
}

// AddPosition adds a position to an election. Admin only.
func (h *ElectionHandler) AddPosition(c *gin.Context) {
	electionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req addPositionReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	maxCand := req.MaxCandidates
	if maxCand <= 0 {
		maxCand = 1
	}
	pos := &models.ElectionPosition{
		ElectionID:    electionID,
		Title:         req.Title,
		TitleMr:       req.TitleMr,
		MaxCandidates: maxCand,
		SortOrder:     req.SortOrder,
	}
	if err := h.repo.AddPosition(actor, pos); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, pos)
}

// DeletePosition removes a position. Admin only.
func (h *ElectionHandler) DeletePosition(c *gin.Context) {
	id, err := uuid.Parse(c.Param("posId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.DeletePosition(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Position deleted"})
}

type nominateReq struct {
	PositionID string `json:"positionId" binding:"required"`
	Manifesto  string `json:"manifesto"`
	MemberName string `json:"memberName" binding:"required"`
	FlatNo     string `json:"flatNo"`
}

// Nominate allows a member to self-nominate for a position.
func (h *ElectionHandler) Nominate(c *gin.Context) {
	electionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req nominateReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	posID, err := uuid.Parse(req.PositionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid positionId", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	candidate := &models.ElectionCandidate{
		ElectionID: electionID,
		PositionID: posID,
		MemberName: req.MemberName,
		FlatNo:     req.FlatNo,
		Manifesto:  req.Manifesto,
	}
	if err := h.repo.Nominate(actor, candidate); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, candidate)
}

// ApproveCandidate approves a candidate nomination. Admin only.
func (h *ElectionHandler) ApproveCandidate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("candId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.ApproveCandidate(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Candidate approved"})
}

// RejectCandidate rejects a candidate nomination. Admin only.
func (h *ElectionHandler) RejectCandidate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("candId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.RejectCandidate(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Candidate rejected"})
}

// WithdrawCandidate allows a candidate to withdraw their own nomination.
func (h *ElectionHandler) WithdrawCandidate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("candId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.WithdrawCandidate(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Candidate withdrawn"})
}

type castVoteReq struct {
	PositionID  string `json:"positionId" binding:"required"`
	CandidateID string `json:"candidateId" binding:"required"`
}

// CastVote records a vote for a candidate.
func (h *ElectionHandler) CastVote(c *gin.Context) {
	electionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req castVoteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	posID, err := uuid.Parse(req.PositionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid positionId", Code: "INVALID_ID"})
		return
	}
	candID, err := uuid.Parse(req.CandidateID)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid candidateId", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	vote := &models.ElectionVote{
		ElectionID:  electionID,
		PositionID:  posID,
		CandidateID: candID,
	}
	if err := h.repo.CastVote(actor, vote); err != nil {
		if errors.Is(err, repositories.ErrNotFound) {
			writeRepoError(c, err)
			return
		}
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "VOTE_FAILED"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"message": "Vote cast successfully"})
}

// GetResults returns election results with vote counts per candidate per position.
func (h *ElectionHandler) GetResults(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	results, err := h.repo.GetResults(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "RESULTS_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"results": results})
}
