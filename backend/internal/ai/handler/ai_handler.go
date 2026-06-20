package handler

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/docassist/internal/ai/service"
	"github.com/yourusername/docassist/pkg/groq"
	"github.com/yourusername/docassist/pkg/logger"
	"github.com/yourusername/docassist/pkg/middleware"
	"github.com/yourusername/docassist/pkg/ocr"
)

type AIHandler struct {
	aiService  service.AIService
	ocrService *ocr.Service
}

func NewAIHandler(aiService service.AIService, ocrService *ocr.Service) *AIHandler {
	return &AIHandler{aiService: aiService, ocrService: ocrService}
}

func respond(c *gin.Context, code int, success bool, message string, data interface{}) {
	c.JSON(code, gin.H{"success": success, "code": code, "message": message, "data": data})
}

func parseIDs(c *gin.Context) (docID uuid.UUID, userID uuid.UUID, ok bool) {
	var err error
	docID, err = uuid.Parse(c.Param("document_id"))
	if err != nil {
		respond(c, http.StatusBadRequest, false, "invalid document_id", nil)
		return uuid.Nil, uuid.Nil, false
	}
	userID, err = uuid.Parse(middleware.GetUserID(c))
	if err != nil {
		respond(c, http.StatusBadRequest, false, "invalid user_id in token", nil)
		return uuid.Nil, uuid.Nil, false
	}
	return docID, userID, true
}

func (h *AIHandler) ProcessDocument(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	go func() {
		_, err := h.aiService.ProcessDocument(context.Background(), userID, docID)
		if err != nil {
			logger.Error("Document processing failed",
				logger.Str("doc_id", docID.String()),
				logger.Str("error", err.Error()),
			)
		}
	}()
	respond(c, http.StatusOK, true, "Document processing started", map[string]string{"status": "processing"})
}

func (h *AIHandler) Summarize(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.Summarize(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Summary generated", result)
}

func (h *AIHandler) AskQuestion(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	var req struct {
		Question string `json:"question" binding:"required,min=3,max=500"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		respond(c, http.StatusBadRequest, false, "Question is required (3-500 chars)", nil)
		return
	}
	result, err := h.aiService.AnswerQuestion(c.Request.Context(), userID, docID, req.Question)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Answer generated", result)
}

func (h *AIHandler) ExtractKeyPoints(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.ExtractKeyPoints(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Key points extracted", result)
}

func (h *AIHandler) ExtractTimeline(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.ExtractTimeline(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Timeline extracted", result)
}

func (h *AIHandler) Translate(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	var req struct {
		TargetLanguage string `json:"target_language" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		respond(c, http.StatusBadRequest, false, "target_language is required", nil)
		return
	}
	result, err := h.aiService.Translate(c.Request.Context(), userID, docID, req.TargetLanguage)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Translation complete", result)
}

func (h *AIHandler) AnalyzeDocument(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.AnalyzeDocument(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Analysis complete", result)
}

func (h *AIHandler) ExtractCitations(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.ExtractCitations(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Citations extracted", result)
}

func (h *AIHandler) ScanRisks(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.ScanRisks(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Risk scan complete", result)
}

func (h *AIHandler) ExtractDeadlines(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.ExtractDeadlines(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Deadlines extracted", result)
}

func (h *AIHandler) AutoTag(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.AutoTag(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Tags generated", result)
}

func (h *AIHandler) CheckGrammar(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.CheckGrammar(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Grammar check complete", result)
}

func (h *AIHandler) DraftLegalDocument(c *gin.Context) {
	userID, err := uuid.Parse(middleware.GetUserID(c))
	if err != nil {
		respond(c, http.StatusUnauthorized, false, "invalid token", nil)
		return
	}
	var req groq.LegalDraftRequest
	if err := c.ShouldBindJSON(&req); err != nil || req.DocumentType == "" {
		respond(c, http.StatusBadRequest, false, "document_type is required", nil)
		return
	}
	result, err := h.aiService.DraftLegalDoc(c.Request.Context(), userID, req)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Draft generated", result)
}

func (h *AIHandler) ExtractActionItems(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	result, err := h.aiService.ExtractActionItems(c.Request.Context(), userID, docID)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Action items extracted", result)
}

func (h *AIHandler) GenerateReport(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}
	var req struct {
		ReportType string `json:"report_type" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		respond(c, http.StatusBadRequest, false, "report_type is required", nil)
		return
	}
	result, err := h.aiService.GenerateReport(c.Request.Context(), userID, docID, req.ReportType)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Report generated", result)
}

// StartChat answers a question about the document directly (single-shot RAG Q&A).
// The Flutter app calls this for every message — there is no real session state.
func (h *AIHandler) StartChat(c *gin.Context) {
	docID, userID, ok := parseIDs(c)
	if !ok {
		return
	}

	var req struct {
		Question string `json:"question"`
		Message  string `json:"message"`
	}
	_ = c.ShouldBindJSON(&req)

	message := req.Question
	if message == "" {
		message = req.Message
	}
	if message == "" {
		respond(c, http.StatusBadRequest, false, "question is required", nil)
		return
	}

	result, err := h.aiService.Chat(c.Request.Context(), userID, docID, service.ChatRequest{Message: message})
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Answer generated", result)
}

func (h *AIHandler) SendMessage(c *gin.Context) {
	userID, err := uuid.Parse(middleware.GetUserID(c))
	if err != nil {
		respond(c, http.StatusBadRequest, false, "invalid user_id", nil)
		return
	}
	sessionID, err := uuid.Parse(c.Param("session_id"))
	if err != nil {
		respond(c, http.StatusBadRequest, false, "invalid session_id", nil)
		return
	}
	var req struct {
		Message string `json:"message" binding:"required,min=1,max=1000"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		respond(c, http.StatusBadRequest, false, "message is required", nil)
		return
	}
	result, err := h.aiService.Chat(c.Request.Context(), userID, sessionID, service.ChatRequest{Message: req.Message})
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Message sent", result)
}

func (h *AIHandler) GetChatHistory(c *gin.Context) {
	respond(c, http.StatusOK, true, "Chat history retrieved", []interface{}{})
}

func (h *AIHandler) GetAIUsage(c *gin.Context) {
	respond(c, http.StatusOK, true, "Usage stats retrieved", gin.H{"total_requests": 0})
}

func (h *AIHandler) CompareDocuments(c *gin.Context) {
	userID, err := uuid.Parse(middleware.GetUserID(c))
	if err != nil {
		respond(c, http.StatusUnauthorized, false, "invalid token", nil)
		return
	}
	var req struct {
		DocID1 string `json:"doc1_id" binding:"required"`
		DocID2 string `json:"doc2_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		respond(c, http.StatusBadRequest, false, "doc1_id and doc2_id are required", nil)
		return
	}
	docID1, err := uuid.Parse(req.DocID1)
	if err != nil {
		respond(c, http.StatusBadRequest, false, "invalid doc1_id", nil)
		return
	}
	docID2, err := uuid.Parse(req.DocID2)
	if err != nil {
		respond(c, http.StatusBadRequest, false, "invalid doc2_id", nil)
		return
	}
	result, err := h.aiService.CompareDocuments(c.Request.Context(), userID, docID1, docID2)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "Comparison complete", result)
}

func (h *AIHandler) HelpChat(c *gin.Context) {
	var req struct {
		Message string             `json:"message"`
		History []groq.ChatMessage `json:"history"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.Message == "" {
		respond(c, http.StatusBadRequest, false, "message is required", nil)
		return
	}
	if req.History == nil {
		req.History = []groq.ChatMessage{}
	}
	reply, err := h.aiService.HelpChat(c.Request.Context(), req.History, req.Message)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, err.Error(), nil)
		return
	}
	respond(c, http.StatusOK, true, "ok", gin.H{"reply": reply})
}

func (h *AIHandler) ScanOCR(c *gin.Context) {
	userID, err := uuid.Parse(middleware.GetUserID(c))
	if err != nil {
		respond(c, http.StatusUnauthorized, false, "invalid token", nil)
		return
	}
	_ = userID

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		respond(c, http.StatusBadRequest, false, "file is required", nil)
		return
	}
	defer file.Close()

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".jpg"
	}

	tmp, err := os.CreateTemp("", "ocr-*"+ext)
	if err != nil {
		respond(c, http.StatusInternalServerError, false, "failed to create temp file", nil)
		return
	}
	defer os.Remove(tmp.Name())

	buf := make([]byte, 32*1024)
	for {
		n, readErr := file.Read(buf)
		if n > 0 {
			if _, writeErr := tmp.Write(buf[:n]); writeErr != nil {
				tmp.Close()
				respond(c, http.StatusInternalServerError, false, "failed to write temp file", nil)
				return
			}
		}
		if readErr != nil {
			break
		}
	}
	tmp.Close()

	lang := c.PostForm("language")
	if lang == "" {
		lang = "en"
	}

	result, err := h.ocrService.ExtractText(c.Request.Context(), tmp.Name())
	if err != nil {
		respond(c, http.StatusInternalServerError, false, fmt.Sprintf("OCR failed: %v", err), nil)
		return
	}

	respond(c, http.StatusOK, true, "OCR extraction complete", gin.H{
		"text":       result.Text,
		"word_count": result.WordCount,
		"page_count": result.PageCount,
		"confidence": result.Confidence,
		"language":   lang,
	})
}
