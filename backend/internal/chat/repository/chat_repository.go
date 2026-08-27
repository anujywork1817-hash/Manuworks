package repository

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/yourusername/docassist/internal/chat/model"
)

var ErrSessionNotFound = errors.New("chat session not found")

type ChatRepository interface {
	CreateSession(ctx context.Context, s *model.ChatSession) error
	GetSession(ctx context.Context, id, userID uuid.UUID) (*model.ChatSession, error)
	// ListSessions returns every session for a user, optionally scoped to
	// one document, newest-updated first — most-recently-continued
	// conversations surface at the top of the History list.
	ListSessions(ctx context.Context, userID uuid.UUID, documentID *uuid.UUID) ([]model.SessionSummary, error)
	TouchSession(ctx context.Context, id uuid.UUID) error
	SetTitleIfEmpty(ctx context.Context, id uuid.UUID, title string) error
	DeleteSession(ctx context.Context, id, userID uuid.UUID) error

	AddMessage(ctx context.Context, m *model.ChatMessage) error
	GetMessages(ctx context.Context, sessionID uuid.UUID) ([]model.ChatMessage, error)
}

type chatRepository struct{ db *gorm.DB }

func NewChatRepository(db *gorm.DB) ChatRepository {
	return &chatRepository{db: db}
}

func (r *chatRepository) CreateSession(ctx context.Context, s *model.ChatSession) error {
	return r.db.WithContext(ctx).Create(s).Error
}

func (r *chatRepository) GetSession(ctx context.Context, id, userID uuid.UUID) (*model.ChatSession, error) {
	var s model.ChatSession
	err := r.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, userID).
		First(&s).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrSessionNotFound
	}
	return &s, err
}

func (r *chatRepository) ListSessions(ctx context.Context, userID uuid.UUID, documentID *uuid.UUID) ([]model.SessionSummary, error) {
	var sessions []model.ChatSession
	q := r.db.WithContext(ctx).Where("user_id = ?", userID)
	if documentID != nil {
		q = q.Where("document_id = ?", *documentID)
	}
	if err := q.Order("updated_at DESC").Find(&sessions).Error; err != nil {
		return nil, err
	}

	summaries := make([]model.SessionSummary, 0, len(sessions))
	for _, s := range sessions {
		var last model.ChatMessage
		var count int64
		r.db.WithContext(ctx).Model(&model.ChatMessage{}).
			Where("session_id = ?", s.ID).Count(&count)
		r.db.WithContext(ctx).Where("session_id = ?", s.ID).
			Order("created_at DESC").Limit(1).First(&last)

		summaries = append(summaries, model.SessionSummary{
			ID:           s.ID,
			DocumentID:   s.DocumentID,
			Title:        s.Title,
			LastMessage:  last.Content,
			MessageCount: count,
			CreatedAt:    s.CreatedAt,
			UpdatedAt:    s.UpdatedAt,
		})
	}
	return summaries, nil
}

func (r *chatRepository) TouchSession(ctx context.Context, id uuid.UUID) error {
	return r.db.WithContext(ctx).Model(&model.ChatSession{}).
		Where("id = ?", id).
		Update("updated_at", gorm.Expr("now()")).Error
}

func (r *chatRepository) SetTitleIfEmpty(ctx context.Context, id uuid.UUID, title string) error {
	return r.db.WithContext(ctx).Model(&model.ChatSession{}).
		Where("id = ? AND (title IS NULL OR title = '')", id).
		Update("title", title).Error
}

// DeleteSession removes the session and its messages. Done explicitly in a
// transaction rather than relying on a DB-level ON DELETE CASCADE, since
// these tables are created via GORM AutoMigrate rather than the SQL in
// migrations/001_init.sql (which does declare the cascade).
func (r *chatRepository) DeleteSession(ctx context.Context, id, userID uuid.UUID) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		res := tx.Where("id = ? AND user_id = ?", id, userID).Delete(&model.ChatSession{})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrSessionNotFound
		}
		return tx.Where("session_id = ?", id).Delete(&model.ChatMessage{}).Error
	})
}

func (r *chatRepository) AddMessage(ctx context.Context, m *model.ChatMessage) error {
	return r.db.WithContext(ctx).Create(m).Error
}

func (r *chatRepository) GetMessages(ctx context.Context, sessionID uuid.UUID) ([]model.ChatMessage, error) {
	var msgs []model.ChatMessage
	err := r.db.WithContext(ctx).
		Where("session_id = ?", sessionID).
		Order("created_at ASC").
		Find(&msgs).Error
	return msgs, err
}
