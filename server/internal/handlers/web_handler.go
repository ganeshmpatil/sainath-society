package handlers

import (
	"html/template"
	"log"
	"net/http"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

// WebHandler serves the platform admin dashboard HTML pages.
// Data is fetched client-side via the JSON API + JWT stored in localStorage.
type WebHandler struct {
	templateDir string
	cache       map[string]*template.Template
}

func NewWebHandler(templateDir string) *WebHandler {
	h := &WebHandler{
		templateDir: templateDir,
		cache:       make(map[string]*template.Template),
	}
	// Pre-parse each page template with layout
	pages := []string{
		"login.html", "dashboard.html", "requests.html",
		"request_detail.html", "societies.html",
		"society_detail.html", "audit_log.html",
		"invoices.html",
	}
	layoutFile := filepath.Join(templateDir, "layout.html")
	for _, page := range pages {
		pageFile := filepath.Join(templateDir, page)
		t, err := template.ParseFiles(layoutFile, pageFile)
		if err != nil {
			log.Fatalf("Failed to parse template %s: %v", page, err)
		}
		h.cache[page] = t
	}
	return h
}

type pageData struct {
	Title        string
	ActiveNav    string
	ShowNav      bool
	PendingCount int
}

func (h *WebHandler) servePage(c *gin.Context, pageName string, data pageData) {
	t, ok := h.cache[pageName]
	if !ok {
		c.String(http.StatusInternalServerError, "Template not found: "+pageName)
		return
	}
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.Status(http.StatusOK)
	if err := t.ExecuteTemplate(c.Writer, "layout.html", data); err != nil {
		log.Printf("Template error (%s): %v", pageName, err)
	}
}

func (h *WebHandler) LoginPage(c *gin.Context) {
	h.servePage(c, "login.html", pageData{Title: "Login", ShowNav: false})
}

func (h *WebHandler) DashboardPage(c *gin.Context) {
	h.servePage(c, "dashboard.html", pageData{Title: "Dashboard", ActiveNav: "dashboard", ShowNav: true})
}

func (h *WebHandler) RequestsPage(c *gin.Context) {
	h.servePage(c, "requests.html", pageData{Title: "Requests", ActiveNav: "requests", ShowNav: true})
}

func (h *WebHandler) RequestDetailPage(c *gin.Context) {
	h.servePage(c, "request_detail.html", pageData{Title: "Request Detail", ActiveNav: "requests", ShowNav: true})
}

func (h *WebHandler) SocietiesPage(c *gin.Context) {
	h.servePage(c, "societies.html", pageData{Title: "Societies", ActiveNav: "societies", ShowNav: true})
}

func (h *WebHandler) SocietyDetailPage(c *gin.Context) {
	h.servePage(c, "society_detail.html", pageData{Title: "Society Detail", ActiveNav: "societies", ShowNav: true})
}

func (h *WebHandler) AuditLogPage(c *gin.Context) {
	h.servePage(c, "audit_log.html", pageData{Title: "Audit Log", ActiveNav: "audit", ShowNav: true})
}

func (h *WebHandler) InvoicesPage(c *gin.Context) {
	h.servePage(c, "invoices.html", pageData{Title: "Invoices", ActiveNav: "invoices", ShowNav: true})
}
