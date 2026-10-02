package services

import (
	"context"
	"log"
	"time"
)

// BillingScheduler runs daily billing at midnight IST.
type BillingScheduler struct {
	billingService *PlatformBillingService
	done           chan bool
}

func NewBillingScheduler(billingService *PlatformBillingService) *BillingScheduler {
	return &BillingScheduler{
		billingService: billingService,
		done:           make(chan bool),
	}
}

// Start runs in a goroutine, firing daily at 00:00 IST.
func (s *BillingScheduler) Start(ctx context.Context) {
	log.Println("[BillingScheduler] Started — will run daily at 00:00 IST")

	for {
		now := time.Now().In(IST)
		// Calculate next midnight IST
		nextMidnight := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, IST)
		sleepDuration := nextMidnight.Sub(now)

		log.Printf("[BillingScheduler] Next run at %s (in %s)", nextMidnight.Format("2006-01-02 15:04:05 MST"), sleepDuration)

		select {
		case <-time.After(sleepDuration):
			log.Println("[BillingScheduler] Midnight IST — running daily billing")
			if err := s.billingService.RunDailyBilling(); err != nil {
				log.Printf("[BillingScheduler] Billing run error: %v", err)
			}
		case <-ctx.Done():
			log.Println("[BillingScheduler] Stopping (context cancelled)")
			return
		case <-s.done:
			log.Println("[BillingScheduler] Stopping (done signal)")
			return
		}
	}
}

// Stop signals the scheduler to shut down.
func (s *BillingScheduler) Stop() {
	close(s.done)
}
