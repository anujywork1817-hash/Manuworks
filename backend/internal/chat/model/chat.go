package model

import (
	"time"

	"github.com/google/uuid"
)

// ChatSession groups the messages of one conversation about one document.
// A user may have several sessions per document — each "New Chat" starts a
// fresh one, and past sessions stay listed (and resumable) in the History
// panel.
type ChatSession struct {
	ID         uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	UserID     uuid.UUID `gorm:"type:uuid;not null;index"                       json:"user_id"`
	DocumentID uuid.UUID `gorm:"type:uuid;not null;index"                       json:"document_id"`
	// Title is auto-derived from the first user message so the History list
	// has something more useful than a timestamp to show.
	Title     string    `gorm:"size:255" json:"title"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (ChatSession) TableName() string { return "chat_sessions" }

type ChatMessage struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	SessionID uuid.UUID `gorm:"type:uuid;not null;index"                       json:"session_id"`
	Role      string    `gorm:"size:20;not null"                               json:"role"` // "user" | "assistant"
	Content   string    `gorm:"type:text;not null"                             json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

func (ChatMessage) TableName() string { return "chat_messages" }

// SessionSummary is what the History list shows — no need to ship every
// message just to render a list of past conversations.
type SessionSummary struct {
	ID              uuid.UUID `json:"id"`
	DocumentID      uuid.UUID `json:"document_id"`
	Title           string    `json:"title"`
	LastMessage     string    `json:"last_message"`
	MessageCount    int64     `json:"message_count"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}
