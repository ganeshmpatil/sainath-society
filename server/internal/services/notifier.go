package services

import (
	"fmt"
	"log"

	"github.com/google/uuid"

	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

// Notifier provides fire-and-forget helpers to enqueue email + WhatsApp
// notifications from handlers. All methods are safe to call with best-effort
// semantics — failures are logged, never propagated.
type Notifier struct {
	notifRepo  *repositories.NotificationRepository
	memberRepo *repositories.MemberRepository
	push       *WebPushService // nil if VAPID not configured
	fcm        *FCMService     // nil if FCM not configured
}

func NewNotifier(notifRepo *repositories.NotificationRepository, memberRepo *repositories.MemberRepository) *Notifier {
	return &Notifier{notifRepo: notifRepo, memberRepo: memberRepo}
}

// SetPushService attaches the Web Push service after construction
// (avoids circular dependency during bootstrap).
func (n *Notifier) SetPushService(push *WebPushService) {
	n.push = push
}

// SetFCMService attaches the FCM service for mobile push notifications.
func (n *Notifier) SetFCMService(fcm *FCMService) {
	n.fcm = fcm
}

// NotifyOne queues an email (+ WhatsApp) notification to a single member
// and sends a Web Push notification immediately.
func (n *Notifier) NotifyOne(recipientID uuid.UUID, subject, body, bodyMr, eventType string, resourceType string, resourceID *uuid.UUID) {
	for _, ch := range []models.NotificationChannel{models.ChannelEmail, models.ChannelWhatsApp} {
		_ = n.notifRepo.Enqueue(&models.Notification{
			RecipientID:  recipientID,
			Channel:      ch,
			Subject:      subject,
			Body:         body,
			BodyMr:       bodyMr,
			Language:     "en",
			EventType:    eventType,
			ResourceType: resourceType,
			ResourceID:   resourceID,
		})
	}
	// Web Push — immediate, non-blocking
	if n.push != nil {
		rid := ""
		if resourceID != nil {
			rid = resourceID.String()
		}
		go n.push.SendToMember(recipientID, PushPayload{
			Title:      subject,
			Body:       body,
			Icon:       "/sai.jpg",
			EventType:  eventType,
			ResourceID: rid,
		})
	}
	// FCM — immediate, non-blocking
	if n.fcm != nil {
		data := map[string]string{"eventType": eventType, "resourceType": resourceType}
		if resourceID != nil {
			data["resourceId"] = resourceID.String()
		}
		go n.fcm.SendToMember(recipientID, FCMMessage{Title: subject, Body: body, Data: data})
	}
}

// NotifyAllMembers broadcasts an email (+ WhatsApp + Push) notification to
// every active member who has an email set.
func (n *Notifier) NotifyAllMembers(subject, body, bodyMr, eventType string, resourceType string, resourceID *uuid.UUID) {
	members, err := n.memberRepo.ListActiveWithEmail()
	if err != nil {
		log.Printf("notifier: failed to list members for broadcast: %v", err)
		return
	}
	for _, m := range members {
		for _, ch := range []models.NotificationChannel{models.ChannelEmail, models.ChannelWhatsApp} {
			_ = n.notifRepo.Enqueue(&models.Notification{
				RecipientID:  m.ID,
				Channel:      ch,
				Subject:      subject,
				Body:         body,
				BodyMr:       bodyMr,
				Language:     "en",
				EventType:    eventType,
				ResourceType: resourceType,
				ResourceID:   resourceID,
			})
		}
	}
	// Web Push broadcast — immediate
	if n.push != nil {
		rid := ""
		if resourceID != nil {
			rid = resourceID.String()
		}
		go n.push.Broadcast(PushPayload{
			Title:      subject,
			Body:       body,
			Icon:       "/sai.jpg",
			EventType:  eventType,
			ResourceID: rid,
		})
	}
	// FCM broadcast — immediate
	if n.fcm != nil {
		data := map[string]string{"eventType": eventType, "resourceType": resourceType}
		if resourceID != nil {
			data["resourceId"] = resourceID.String()
		}
		go n.fcm.Broadcast(FCMMessage{Title: subject, Body: body, Data: data})
	}
}

// NotifyAdmins sends a notification to all admin members.
func (n *Notifier) NotifyAdmins(subject, body, bodyMr, eventType string, resourceType string, resourceID *uuid.UUID) {
	adminRole := models.RoleAdmin
	members, err := n.memberRepo.ListByRole(&adminRole)
	if err != nil {
		log.Printf("notifier: failed to list admins: %v", err)
		return
	}
	var adminIDs []uuid.UUID
	for _, m := range members {
		adminIDs = append(adminIDs, m.ID)
		for _, ch := range []models.NotificationChannel{models.ChannelEmail, models.ChannelWhatsApp} {
			_ = n.notifRepo.Enqueue(&models.Notification{
				RecipientID:  m.ID,
				Channel:      ch,
				Subject:      subject,
				Body:         body,
				BodyMr:       bodyMr,
				Language:     "en",
				EventType:    eventType,
				ResourceType: resourceType,
				ResourceID:   resourceID,
			})
		}
	}
	// Web Push to admins
	if n.push != nil && len(adminIDs) > 0 {
		rid := ""
		if resourceID != nil {
			rid = resourceID.String()
		}
		go n.push.SendToMembers(adminIDs, PushPayload{
			Title:      subject,
			Body:       body,
			Icon:       "/sai.jpg",
			EventType:  eventType,
			ResourceID: rid,
		})
	}
	// FCM to admins
	if n.fcm != nil && len(adminIDs) > 0 {
		data := map[string]string{"eventType": eventType, "resourceType": resourceType}
		if resourceID != nil {
			data["resourceId"] = resourceID.String()
		}
		go n.fcm.SendToMembers(adminIDs, FCMMessage{Title: subject, Body: body, Data: data})
	}
}

// Convenience helpers that build bilingual messages for common events.

func (n *Notifier) GrievanceCreated(raiserID uuid.UUID, ticketNo string, title string, grievanceID uuid.UUID) {
	n.NotifyOne(raiserID,
		"Grievance Registered: "+ticketNo,
		fmt.Sprintf("Your grievance #%s \"%s\" has been registered successfully.", ticketNo, title),
		fmt.Sprintf("आपली तक्रार #%s \"%s\" यशस्वीरित्या नोंदवली गेली आहे.", ticketNo, title),
		"GRIEVANCE_CREATED", "grievance", &grievanceID,
	)
	n.NotifyAdmins(
		"New Grievance: "+ticketNo,
		fmt.Sprintf("A new grievance #%s \"%s\" has been raised and needs attention.", ticketNo, title),
		fmt.Sprintf("नवीन तक्रार #%s \"%s\" नोंदवली गेली आहे, कृपया लक्ष द्या.", ticketNo, title),
		"GRIEVANCE_CREATED", "grievance", &grievanceID,
	)
}

func (n *Notifier) GrievanceStatusChanged(raiserID uuid.UUID, ticketNo string, newStatus string, grievanceID uuid.UUID) {
	n.NotifyOne(raiserID,
		"Grievance Update: "+ticketNo,
		fmt.Sprintf("Your grievance #%s status has been updated to: %s.", ticketNo, newStatus),
		fmt.Sprintf("आपल्या तक्रार #%s ची स्थिती बदलली: %s.", ticketNo, newStatus),
		"GRIEVANCE_STATUS_CHANGED", "grievance", &grievanceID,
	)
}

func (n *Notifier) NoticeCreated(title, titleMr string, noticeID uuid.UUID) {
	body := fmt.Sprintf("A new notice has been posted: \"%s\". Please check the notices section.", title)
	bodyMr := fmt.Sprintf("नवीन सूचना प्रकाशित: \"%s\". कृपया सूचना विभाग तपासा.", titleMr)
	if titleMr == "" {
		bodyMr = fmt.Sprintf("नवीन सूचना प्रकाशित: \"%s\". कृपया सूचना विभाग तपासा.", title)
	}
	n.NotifyAllMembers("New Notice: "+title, body, bodyMr, "NOTICE_CREATED", "notice", &noticeID)
}

func (n *Notifier) MeetingScheduled(title string, scheduledAt string, meetingID uuid.UUID) {
	n.NotifyAllMembers(
		"Meeting Scheduled: "+title,
		fmt.Sprintf("A new meeting \"%s\" has been scheduled for %s.", title, scheduledAt),
		fmt.Sprintf("नवीन बैठक \"%s\" %s रोजी नियोजित आहे.", title, scheduledAt),
		"MEETING_SCHEDULED", "meeting", &meetingID,
	)
}

func (n *Notifier) EventCreated(title string, startTime string, eventID uuid.UUID) {
	n.NotifyAllMembers(
		"New Event: "+title,
		fmt.Sprintf("A new event \"%s\" is scheduled for %s. Check events for details.", title, startTime),
		fmt.Sprintf("नवीन कार्यक्रम \"%s\" %s रोजी आहे. तपशीलांसाठी कार्यक्रम विभाग पहा.", title, startTime),
		"EVENT_CREATED", "event", &eventID,
	)
}

func (n *Notifier) PollPublished(title string, endsAt string, pollID uuid.UUID) {
	n.NotifyAllMembers(
		"New Poll: "+title,
		fmt.Sprintf("A new poll \"%s\" is now open for voting. Voting ends on %s.", title, endsAt),
		fmt.Sprintf("नवीन मतदान \"%s\" सुरू झाले आहे. मतदान %s पर्यंत आहे.", title, endsAt),
		"POLL_PUBLISHED", "poll", &pollID,
	)
}

func (n *Notifier) TaskAssigned(assigneeID uuid.UUID, title string, taskID uuid.UUID) {
	n.NotifyOne(assigneeID,
		"Task Assigned: "+title,
		fmt.Sprintf("A new task \"%s\" has been assigned to you. Please check your pending tasks.", title),
		fmt.Sprintf("तुम्हाला नवीन काम \"%s\" नेमून दिले आहे. कृपया प्रलंबित कामे तपासा.", title),
		"TASK_ASSIGNED", "task", &taskID,
	)
}

func (n *Notifier) BillGenerated(memberID uuid.UUID, billNo string, amount float64, dueDate string, billID uuid.UUID) {
	n.NotifyOne(memberID,
		"Maintenance Bill: "+billNo,
		fmt.Sprintf("Your maintenance bill #%s for Rs. %.0f has been generated. Due date: %s.", billNo, amount, dueDate),
		fmt.Sprintf("तुमचे देखभाल बिल #%s रु. %.0f तयार झाले आहे. देय तारीख: %s.", billNo, amount, dueDate),
		"BILL_GENERATED", "bill", &billID,
	)
}

func (n *Notifier) BillPaid(memberID uuid.UUID, billNo string, amount float64, billID uuid.UUID) {
	n.NotifyOne(memberID,
		"Payment Received: "+billNo,
		fmt.Sprintf("Payment of Rs. %.0f for bill #%s has been received. Thank you!", amount, billNo),
		fmt.Sprintf("बिल #%s साठी रु. %.0f चे पेमेंट प्राप्त झाले. धन्यवाद!", billNo, amount),
		"BILL_PAID", "bill", &billID,
	)
}

func (n *Notifier) HallBookingDecided(bookerID uuid.UUID, purpose string, approved bool, bookingID uuid.UUID) {
	status := "approved"
	statusMr := "मंजूर"
	if !approved {
		status = "rejected"
		statusMr = "नाकारले"
	}
	n.NotifyOne(bookerID,
		fmt.Sprintf("Hall Booking %s", status),
		fmt.Sprintf("Your hall booking for \"%s\" has been %s.", purpose, status),
		fmt.Sprintf("तुमचे हॉल बुकिंग \"%s\" %s झाले आहे.", purpose, statusMr),
		"HALL_BOOKING_DECIDED", "hall_booking", &bookingID,
	)
}

func (n *Notifier) TenantApproved(landlordID uuid.UUID, tenantName string, tenantID uuid.UUID) {
	n.NotifyOne(landlordID,
		"Tenant Approved: "+tenantName,
		fmt.Sprintf("Your tenant \"%s\" has been approved by the society.", tenantName),
		fmt.Sprintf("तुमचा भाडेकरू \"%s\" सोसायटीने मंजूर केला आहे.", tenantName),
		"TENANT_APPROVED", "tenant", &tenantID,
	)
}
