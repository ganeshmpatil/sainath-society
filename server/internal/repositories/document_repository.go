package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type DocumentRepository struct {
	db *gorm.DB
}

func NewDocumentRepository(db *gorm.DB) *DocumentRepository {
	return &DocumentRepository{db: db}
}

// Create — any authenticated member can upload to the vault. Scope + ACL
// decide who can see it later.
func (r *DocumentRepository) Create(actor *ActorContext, d *models.Document) error {
	d.UploadedByID = actor.MemberID
	// Non-admin uploads default to MEMBER scope owned by self, unless they
	// explicitly asked for PUBLIC/FLAT (still limited to their own flat).
	if !actor.IsAdmin() {
		mid := actor.MemberID
		d.OwnerMemberID = &mid
		if d.Scope == models.DocScopeCommittee {
			return ErrForbidden
		}
		if d.Scope == models.DocScopeFlat && actor.FlatID != nil {
			d.FlatID = actor.FlatID
		}
	}
	return r.db.Create(d).Error
}

// ListForActor applies the full scope+ownership+grant ACL:
//
//	Admin:  everything
//	Member: PUBLIC + own uploads (owner_member_id = me)
//	        + docs for my flat (flat_id = my_flat)
//	        + docs explicitly granted to me via soc_mitra_document_access_grants
func (r *DocumentRepository) ListForActor(actor *ActorContext, category *models.DocumentCategory) ([]models.Document, error) {
	q := r.db.Model(&models.Document{}).
		Where("is_latest = ?", true).
		Where("archived_at IS NULL").
		Order("created_at DESC")

	if category != nil {
		q = q.Where("category = ?", *category)
	}

	if !actor.IsAdmin() {
		// Build union of visibility rules
		q = q.Where(
			r.db.Where("scope = ?", models.DocScopePublic).
				Or("owner_member_id = ?", actor.MemberID).
				Or("flat_id = ? AND scope = ?", actor.FlatID, models.DocScopeFlat).
				Or("id IN (?)", r.db.Model(&models.DocumentAccess{}).
					Select("document_id").
					Where("member_id = ?", actor.MemberID)),
		)
	}

	var rows []models.Document
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID returns a single document if the actor may see it.
// Side-effect: writes an audit log row.
func (r *DocumentRepository) GetByID(actor *ActorContext, id uuid.UUID, ip string) (*models.Document, error) {
	var d models.Document
	if err := r.db.First(&d, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if !r.canView(actor, &d) {
		return nil, ErrForbidden
	}
	// Audit log (best effort — don't fail the read if logging fails)
	_ = r.db.Create(&models.DocumentAuditLog{
		DocumentID: d.ID,
		ActorID:    actor.MemberID,
		Action:     "VIEW",
		IPAddress:  ip,
	}).Error
	return &d, nil
}

// canView centralises the scope check used by GetByID and downstream handlers.
func (r *DocumentRepository) canView(actor *ActorContext, d *models.Document) bool {
	if actor.IsAdmin() {
		return true
	}
	switch d.Scope {
	case models.DocScopePublic:
		return true
	case models.DocScopeCommittee:
		return false
	case models.DocScopeMember:
		return d.OwnerMemberID != nil && *d.OwnerMemberID == actor.MemberID
	case models.DocScopeFlat:
		return d.FlatID != nil && actor.FlatID != nil && *d.FlatID == *actor.FlatID
	}
	// Fall back to explicit grants
	var count int64
	r.db.Model(&models.DocumentAccess{}).
		Where("document_id = ? AND member_id = ?", d.ID, actor.MemberID).
		Count(&count)
	return count > 0
}

// Grant explicit access to an extra member (admin or doc owner).
func (r *DocumentRepository) Grant(actor *ActorContext, docID, memberID uuid.UUID, canEdit bool) error {
	var d models.Document
	if err := r.db.First(&d, "id = ?", docID).Error; err != nil {
		return err
	}
	isOwner := d.OwnerMemberID != nil && *d.OwnerMemberID == actor.MemberID
	if !actor.IsAdmin() && !isOwner {
		return ErrForbidden
	}
	return r.db.Create(&models.DocumentAccess{
		DocumentID: docID,
		MemberID:   memberID,
		GrantedBy:  actor.MemberID,
		CanEdit:    canEdit,
	}).Error
}

// Archive soft-removes a document (admin or owner).
func (r *DocumentRepository) Archive(actor *ActorContext, id uuid.UUID) error {
	var d models.Document
	if err := r.db.First(&d, "id = ?", id).Error; err != nil {
		return err
	}
	isOwner := d.OwnerMemberID != nil && *d.OwnerMemberID == actor.MemberID
	if !actor.IsAdmin() && !isOwner {
		return ErrForbidden
	}
	return r.db.Model(&d).Update("archived_at", gorm.Expr("NOW()")).Error
}
