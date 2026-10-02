package services

import (
	"context"
	"fmt"
	"log"
	"time"

	"gorm.io/gorm"

	"aangan/internal/models"
)

// TaskReminderScheduler runs daily at 00:05 IST and sends reminders
// for committee todos due in 10 or 5 days.
type TaskReminderScheduler struct {
	db       *gorm.DB
	notifier *Notifier
	done     chan bool
}

func NewTaskReminderScheduler(db *gorm.DB, notifier *Notifier) *TaskReminderScheduler {
	return &TaskReminderScheduler{db: db, notifier: notifier, done: make(chan bool)}
}

func (s *TaskReminderScheduler) Start(ctx context.Context) {
	log.Println("[TaskReminderScheduler] Started — will run daily at 00:05 IST")
	for {
		now := time.Now().In(IST)
		// Run 5 minutes after midnight to avoid conflicts with billing scheduler
		nextRun := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 5, 0, 0, IST)
		sleepDuration := nextRun.Sub(now)

		log.Printf("[TaskReminderScheduler] Next run at %s (in %s)", nextRun.Format("2006-01-02 15:04:05 MST"), sleepDuration)

		select {
		case <-time.After(sleepDuration):
			log.Println("[TaskReminderScheduler] Running task reminder check")
			s.checkAndNotify()
		case <-ctx.Done():
			log.Println("[TaskReminderScheduler] Stopping (context cancelled)")
			return
		case <-s.done:
			log.Println("[TaskReminderScheduler] Stopping (done signal)")
			return
		}
	}
}

// Stop signals the scheduler to shut down.
func (s *TaskReminderScheduler) Stop() {
	close(s.done)
}

func (s *TaskReminderScheduler) checkAndNotify() {
	// Get all active committee todos that are PENDING or IN_PROGRESS
	var todos []models.CommitteeTodo
	err := s.db.
		Where("is_active = ? AND status NOT IN (?, ?)", true, models.TodoCompleted, models.TodoCancelled).
		Find(&todos).Error
	if err != nil {
		log.Printf("[TaskReminderScheduler] Error fetching todos: %v", err)
		return
	}

	now := time.Now().In(IST)
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, IST)

	for _, todo := range todos {
		dueDate := time.Date(todo.DueDate.Year(), todo.DueDate.Month(), todo.DueDate.Day(), 0, 0, 0, 0, IST)
		daysUntilDue := int(dueDate.Sub(today).Hours() / 24)

		if daysUntilDue == 10 || daysUntilDue == 5 {
			log.Printf("[TaskReminderScheduler] Sending %d-day reminder for todo: %s", daysUntilDue, todo.Title)

			subject := fmt.Sprintf("Task Reminder: %s — Due in %d days", todo.Title, daysUntilDue)
			body := fmt.Sprintf("Reminder: The committee task \"%s\" (Category: %s, Priority: %s) is due in %d days on %s. Please ensure it is completed on time.",
				todo.Title, todo.Category, todo.Priority, daysUntilDue, todo.DueDate.Format("02 Jan 2006"))
			bodyMr := fmt.Sprintf("स्मरणपत्र: समिती कार्य \"%s\" (प्रवर्ग: %s, प्राधान्य: %s) %d दिवसांत %s रोजी देय आहे. कृपया वेळेवर पूर्ण करा.",
				todo.Title, todo.Category, todo.Priority, daysUntilDue, todo.DueDate.Format("02 Jan 2006"))

			s.notifier.NotifyAdmins(subject, body, bodyMr, "TASK_REMINDER", "committee_todo", &todo.ID)
		}
	}
}
