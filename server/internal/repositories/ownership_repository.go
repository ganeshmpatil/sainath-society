package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type OwnershipRepository struct {
	db *gorm.DB
}

func NewOwnershipRepository(db *gorm.DB) *OwnershipRepository {
	return &OwnershipRepository{db: db}
}

// Create stores a new ownership record. Only admins may add ownership rows
// (ownership of someone else's flat is a privileged action); this is enforced
// here in addition to any middleware check.
func (r *OwnershipRepository) Create(actor *ActorContext, o *models.MemberOwnership) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(o).Error
}

// ListForActor returns all ownership rows visible to the actor:
//   - Admin: all rows
//   - Member: only rows where member_id = actor.MemberID
func (r *OwnershipRepository) ListForActor(actor *ActorContext) ([]models.MemberOwnership, error) {
	var rows []models.MemberOwnership
	q := r.db.Preload("Flat").Preload("Documents")
	q = ScopeOwnedOrAdmin(q, actor, "member_id")
	if err := q.Find(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}

// GetByID returns a single ownership row, enforcing ACL.
func (r *OwnershipRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.MemberOwnership, error) {
	var row models.MemberOwnership
	if err := r.db.Preload("Flat").Preload("Documents").First(&row, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, row.MemberID); err != nil {
		return nil, err
	}
	return &row, nil
}

// AddDocument attaches a housing document to an ownership row.
// Only the owner of the ownership row or an admin may add documents.
func (r *OwnershipRepository) AddDocument(actor *ActorContext, ownershipID uuid.UUID, doc *models.HousingDocument) error {
	own, err := r.GetByID(actor, ownershipID)
	if err != nil {
		return err
	}
	doc.OwnershipID = own.ID
	doc.UploadedBy = actor.MemberID
	return r.db.Create(doc).Error
}

// ListDocuments returns all documents under an ownership row (ACL applied).
func (r *OwnershipRepository) ListDocuments(actor *ActorContext, ownershipID uuid.UUID) ([]models.HousingDocument, error) {
	if _, err := r.GetByID(actor, ownershipID); err != nil {
		return nil, err
	}
	var docs []models.HousingDocument
	err := r.db.Where("ownership_id = ?", ownershipID).Find(&docs).Error
	return docs, err
}
