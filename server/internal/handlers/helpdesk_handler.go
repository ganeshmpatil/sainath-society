package handlers

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
	"sainath-society/internal/services"
)

type HelpdeskHandler struct {
	repo     *repositories.HelpdeskRepository
	notifier *services.Notifier
}

func NewHelpdeskHandler(repo *repositories.HelpdeskRepository, notifier *services.Notifier) *HelpdeskHandler {
	return &HelpdeskHandler{repo: repo, notifier: notifier}
}

func (h *HelpdeskHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	status := c.Query("status")
	category := c.Query("category")
	rows, err := h.repo.List(actor, status, category)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"tickets": rows, "count": len(rows)})
}

func (h *HelpdeskHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	ticket, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, ticket)
}

type createTicketReq struct {
	Subject     string `json:"subject" binding:"required"`
	Description string `json:"description" binding:"required"`
	Category    string `json:"category" binding:"required"`
	Priority    string `json:"priority"`
	FlatID      string `json:"flatId" binding:"required"`
	FlatNo      string `json:"flatNo" binding:"required"`
}

func (h *HelpdeskHandler) Create(c *gin.Context) {
	var req createTicketReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	flatID, err := uuid.Parse(req.FlatID)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid flat ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	priority := models.HelpdeskPriority(req.Priority)
	if priority == "" {
		priority = models.HelpdeskPriorityMedium
	}
	ticket := &models.HelpdeskTicket{
		Subject:     req.Subject,
		Description: req.Description,
		Category:    models.HelpdeskCategory(req.Category),
		Priority:    priority,
		FlatID:      flatID,
		FlatNo:      req.FlatNo,
	}
	if err := h.repo.Create(actor, ticket); err != nil {
		writeRepoError(c, err)
		return
	}
	// Notify admins about the new ticket
	go h.notifier.NotifyAdmins(
		"New Helpdesk Ticket: "+ticket.TicketNo,
		fmt.Sprintf("A new helpdesk ticket #%s \"%s\" has been raised from flat %s.", ticket.TicketNo, ticket.Subject, ticket.FlatNo),
		fmt.Sprintf("सदनिका %s कडून नवीन हेल्पडेस्क तिकीट #%s \"%s\" नोंदवले गेले आहे.", ticket.FlatNo, ticket.TicketNo, ticket.Subject),
		"HELPDESK_TICKET_CREATED", "helpdesk_ticket", &ticket.ID,
	)
	c.JSON(http.StatusCreated, ticket)
}

type addMessageReq struct {
	Body       string `json:"body" binding:"required"`
	IsInternal bool   `json:"isInternal"`
}

func (h *HelpdeskHandler) AddMessage(c *gin.Context) {
	ticketID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req addMessageReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	// Fetch ticket first for ownership check and notification
	ticket, err := h.repo.GetByID(actor, ticketID)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	msg := &models.HelpdeskMessage{
		TicketID:   ticketID,
		Body:       req.Body,
		IsInternal: req.IsInternal,
	}
	if err := h.repo.AddMessage(actor, msg); err != nil {
		writeRepoError(c, err)
		return
	}

	// Notify the other party
	if actor.IsAdmin() {
		// Admin sent a message — notify the member who raised the ticket (only if not internal)
		if !msg.IsInternal {
			go h.notifier.NotifyOne(ticket.RaisedByID,
				"Helpdesk Reply: "+ticket.TicketNo,
				fmt.Sprintf("You have a new reply on your helpdesk ticket #%s \"%s\".", ticket.TicketNo, ticket.Subject),
				fmt.Sprintf("तुमच्या हेल्पडेस्क तिकीट #%s \"%s\" वर नवीन उत्तर आले आहे.", ticket.TicketNo, ticket.Subject),
				"HELPDESK_MESSAGE", "helpdesk_ticket", &ticket.ID,
			)
		}
	} else {
		// Member sent a message — notify admins
		go h.notifier.NotifyAdmins(
			"Helpdesk Message: "+ticket.TicketNo,
			fmt.Sprintf("New message on ticket #%s \"%s\" from flat %s.", ticket.TicketNo, ticket.Subject, ticket.FlatNo),
			fmt.Sprintf("सदनिका %s कडून तिकीट #%s \"%s\" वर नवीन संदेश.", ticket.FlatNo, ticket.TicketNo, ticket.Subject),
			"HELPDESK_MESSAGE", "helpdesk_ticket", &ticket.ID,
		)
	}

	c.JSON(http.StatusCreated, msg)
}

type helpdeskStatusReq struct {
	Status string `json:"status" binding:"required"`
}

func (h *HelpdeskHandler) UpdateStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req helpdeskStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
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
	c.JSON(http.StatusOK, gin.H{"message": "Status updated"})
}

type assignReq struct {
	AssigneeID string `json:"assigneeId" binding:"required"`
}

func (h *HelpdeskHandler) Assign(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req assignReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	assigneeID, err := uuid.Parse(req.AssigneeID)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid assignee ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.Assign(actor, id, assigneeID); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Ticket assigned"})
}

func (h *HelpdeskHandler) Stats(c *gin.Context) {
	stats, err := h.repo.Stats()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "STATS_FAILED"})
		return
	}
	c.JSON(http.StatusOK, stats)
}
