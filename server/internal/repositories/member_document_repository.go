package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type MemberDocumentRepository struct {
	db *gorm.DB
}

func NewMemberDocumentRepository(db *gorm.DB) *MemberDocumentRepository {
	return &MemberDocumentRepository{db: db}
}

// Create stores a new member document. Non-admins can only create docs for
// themselves; the handler sets MemberID from the actor context.
func (r *MemberDocumentRepository) Create(actor *ActorContext, d *models.MemberDocument) error {
	d.MemberID = actor.MemberID
	d.FlatID = actor.FlatID
	return r.db.Create(d).Error
}

// List returns documents visible to the actor. Members see their own;
// admins see all (optionally filtered by memberID query param).
func (r *MemberDocumentRepository) List(actor *ActorContext, docType *models.MemberDocType, memberID *uuid.UUID) ([]models.MemberDocument, error) {
	q := r.db.Model(&models.MemberDocument{}).
		Select("id, member_id, flat_id, doc_type, title, title_mr, file_name, mime_type, original_size, compressed_size, expires_at, created_at, updated_at").
		Order("created_at DESC")

	// Row-level ACL
	if !actor.IsAdmin() {
		q = q.Where("member_id = ?", actor.MemberID)
	} else if memberID != nil {
		q = q.Where("member_id = ?", *memberID)
	}

	if docType != nil {
		q = q.Where("doc_type = ?", *docType)
	}

	var rows []models.MemberDocument
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID returns a single document (with file data) if the actor may see it.
func (r *MemberDocumentRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.MemberDocument, error) {
	var d models.MemberDocument
	if err := r.db.First(&d, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, d.MemberID); err != nil {
		return nil, err
	}
	return &d, nil
}

// GetMetadata returns doc metadata (no file data) for display purposes.
func (r *MemberDocumentRepository) GetMetadata(actor *ActorContext, id uuid.UUID) (*models.MemberDocument, error) {
	var d models.MemberDocument
	err := r.db.Select("id, member_id, flat_id, doc_type, title, title_mr, file_name, mime_type, original_size, compressed_size, expires_at, created_at, updated_at").
		First(&d, "id = ?", id).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, d.MemberID); err != nil {
		return nil, err
	}
	return &d, nil
}

// Delete permanently removes a member document.
func (r *MemberDocumentRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	var d models.MemberDocument
	if err := r.db.First(&d, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return ErrNotFound
		}
		return err
	}
	if err := AssertOwnerOrAdmin(actor, d.MemberID); err != nil {
		return err
	}
	return r.db.Delete(&d).Error
}
