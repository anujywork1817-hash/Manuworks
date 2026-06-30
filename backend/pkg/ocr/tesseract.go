package ocr

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unicode"


	"github.com/yourusername/docassist/config"
	"github.com/yourusername/docassist/pkg/logger"
)

// ─── Types ────────────────────────────────────────────────────────────────────

type ExtractResult struct {
	Text       string        `json:"text"`
	PageCount  int           `json:"page_count"`
	WordCount  int           `json:"word_count"`
	Language   string        `json:"language"`
	Confidence float64       `json:"confidence"` // 0–100
	Duration   time.Duration `json:"duration"`
}

type PageResult struct {
	PageNumber int     `json:"page_number"`
	Text       string  `json:"text"`
	Confidence float64 `json:"confidence"`
}

// ─── Service ──────────────────────────────────────────────────────────────────

type Service struct {
	cfg *config.OCRConfig
	mu  sync.Mutex // gosseract client is not goroutine-safe; serialize calls
}

func NewService(cfg *config.OCRConfig) *Service {
	return &Service{cfg: cfg}
}

// ExtractFromFile detects the file type and routes to the correct extractor.
// Supported: PDF, PNG, JPG, JPEG, TIFF, BMP
func (s *Service) ExtractFromFile(ctx context.Context, filePath string) (*ExtractResult, error) {
	start := time.Now()

	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(filePath), "."))

	var result *ExtractResult
	var err error

	switch ext {
	case "pdf":
		result, err = s.extractFromPDF(ctx, filePath)
	case "png", "jpg", "jpeg", "tiff", "tif", "bmp", "webp":
		result, err = s.extractFromImage(ctx, filePath)
	default:
		return nil, fmt.Errorf("unsupported file type for OCR: .%s", ext)
	}

	if err != nil {
		return nil, err
	}

	result.Duration = time.Since(start)
	result.WordCount = countWords(result.Text)

	logger.Info("OCR completed",
		logger.Str("file", filepath.Base(filePath)),
		logger.Int("pages", result.PageCount),
		logger.Int("words", result.WordCount),
		logger.Str("duration", result.Duration.String()),
	)

	return result, nil
}

// ─── PDF Extraction ───────────────────────────────────────────────────────────

// extractFromPDF converts each PDF page to an image then runs Tesseract on each.
// Requires: pdftoppm (from poppler-utils) installed on the system.
func (s *Service) extractFromPDF(ctx context.Context, pdfPath string) (*ExtractResult, error) {
	tmpDir, err := os.MkdirTemp("", "ocr_pdf_*")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	outputPrefix := filepath.Join(tmpDir, "page")
	timeoutCtx, cancel := context.WithTimeout(ctx, s.cfg.Timeout)
	defer cancel()

	// Try 300 DPI first, fall back to 150 DPI if system is memory-constrained.
	// NOTE: Never pass a .pdf path to extractFromImage — Tesseract cannot read PDFs.
	var pdftoppmErr string
	for _, dpi := range []string{"300", "150"} {
		cmd := exec.CommandContext(timeoutCtx, "pdftoppm",
			"-r", dpi,
			"-png",
			pdfPath,
			outputPrefix,
		)
		if out, err := cmd.CombinedOutput(); err == nil {
			pdftoppmErr = ""
			break
		} else {
			pdftoppmErr = strings.TrimSpace(string(out))
			logger.Warn("pdftoppm failed at "+dpi+" DPI, retrying",
				logger.Str("error", pdftoppmErr),
			)
			// Clear temp dir before retry
			os.RemoveAll(tmpDir)
			tmpDir, _ = os.MkdirTemp("", "ocr_pdf_*")
			outputPrefix = filepath.Join(tmpDir, "page")
		}
	}

	if pdftoppmErr != "" {
		// Both DPI attempts failed. Try pdftotext as a last resort (works for digital PDFs).
		if text, terr := extractDigitalPDFText(pdfPath); terr == nil && len(strings.TrimSpace(text)) > 50 {
			logger.Info("pdftotext fallback succeeded after pdftoppm failure")
			cleaned := cleanText(text)
			return &ExtractResult{
				Text:       cleaned,
				PageCount:  estimatePageCount(cleaned),
				WordCount:  countWords(cleaned),
				Language:   s.cfg.Lang,
				Confidence: 90.0,
			}, nil
		}
		return nil, fmt.Errorf("PDF text extraction failed: pdftoppm could not convert this PDF to images (%s). The PDF may be encrypted, corrupted, or too large for the server", pdftoppmErr)
	}

	// Find all generated page images (page-1.png, page-2.png, ...)
	pattern := filepath.Join(tmpDir, "page-*.png")
	pages, err := filepath.Glob(pattern)
	if err != nil || len(pages) == 0 {
		// Try alternative naming (page-01.png)
		pattern = filepath.Join(tmpDir, "page-0*.png")
		pages, _ = filepath.Glob(pattern)
	}

	if len(pages) == 0 {
		return nil, fmt.Errorf("no page images generated from PDF")
	}

	// OCR each page
	var allText strings.Builder
	var totalConfidence float64
	pageResults := make([]PageResult, 0, len(pages))

	for i, pagePath := range pages {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}

		pr, err := s.ocrImageFile(pagePath, s.cfg.Lang)
		if err != nil {
			logger.Warn("OCR failed for page",
				logger.Int("page", i+1),
				logger.Str("error", err.Error()),
			)
			continue
		}

		pr.PageNumber = i + 1
		pageResults = append(pageResults, *pr)

		allText.WriteString(pr.Text)
		allText.WriteString("\n\n--- Page ")
		allText.WriteString(fmt.Sprintf("%d", i+2))
		allText.WriteString(" ---\n\n")
		totalConfidence += pr.Confidence
	}

	avgConfidence := 0.0
	if len(pageResults) > 0 {
		avgConfidence = totalConfidence / float64(len(pageResults))
	}

	return &ExtractResult{
		Text:       cleanText(allText.String()),
		PageCount:  len(pages),
		Language:   s.cfg.Lang,
		Confidence: avgConfidence,
	}, nil
}

// ─── Image Extraction ─────────────────────────────────────────────────────────

func (s *Service) extractFromImage(ctx context.Context, imagePath string) (*ExtractResult, error) {
	pr, err := s.ocrImageFile(imagePath, s.cfg.Lang)
	if err != nil {
		return nil, err
	}

	return &ExtractResult{
		Text:       cleanText(pr.Text),
		PageCount:  1,
		Language:   s.cfg.Lang,
		Confidence: pr.Confidence,
	}, nil
}

// ─── Core Tesseract Call ──────────────────────────────────────────────────────

// ocrImageFile runs Tesseract CLI on a single image file.
func (s *Service) ocrImageFile(imagePath, lang string) (*PageResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	tessLang := toTesseractLang(lang)

	cmd := exec.Command("tesseract", imagePath, "stdout", "-l", tessLang, "--oem", "3", "--psm", "3")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("tesseract failed on %s: %w", filepath.Base(imagePath), err)
	}

	return &PageResult{
		Text:       string(output),
		Confidence: 85.0,
	}, nil
}

// toTesseractLang maps ISO 639-1 2-letter codes to Tesseract 3-letter codes.
func toTesseractLang(lang string) string {
	mapping := map[string]string{
		"en": "eng",
		"hi": "hin",
		"mr": "mar",
		"gu": "guj",
		"ta": "tam",
		"te": "tel",
		"kn": "kan",
		"ml": "mal",
		"pa": "pan",
		"bn": "ben",
		"or": "ori",
		"ur": "urd",
	}
	if v, ok := mapping[lang]; ok {
		return v
	}
	if len(lang) == 3 {
		return lang
	}
	return "eng"
}

// ─── DOCX Text Extraction ─────────────────────────────────────────────────────

// ExtractFromDOCX extracts plain text from a .docx file without OCR.
// DOCX files contain XML — we extract the text nodes directly.
func (s *Service) ExtractFromDOCX(ctx context.Context, filePath string) (*ExtractResult, error) {
	start := time.Now()

	// Use python-docx via a shell command if available, otherwise use our Go approach
	text, err := extractDOCXText(filePath)
	if err != nil {
		return nil, fmt.Errorf("docx extraction: %w", err)
	}

	result := &ExtractResult{
		Text:       cleanText(text),
		PageCount:  estimatePageCount(text),
		WordCount:  countWords(text),
		Language:   s.cfg.Lang,
		Confidence: 100.0, // DOCX is digital text, not scanned
		Duration:   time.Since(start),
	}

	return result, nil
}

// extractDOCXText reads the word/document.xml inside the .docx zip archive.
func extractDOCXText(filePath string) (string, error) {
	// .docx is a ZIP file containing word/document.xml
	// We use the archive/zip + encoding/xml approach

	// Shell out to python-docx if available (better formatting preservation)
	cmd := exec.Command("python3", "-c", fmt.Sprintf(`
import sys
try:
    from docx import Document
    doc = Document('%s')
    print('\n'.join([p.text for p in doc.paragraphs]))
except ImportError:
    sys.exit(1)
`, filePath))

	output, err := cmd.Output()
	if err == nil {
		return string(output), nil
	}

	// Fallback: parse the XML directly using Go's zip reader
	return extractDOCXViaZip(filePath)
}

func extractDOCXViaZip(filePath string) (string, error) {
	// Import here to avoid circular import at package level
	// This uses archive/zip + encoding/xml
	return extractDocxGoNative(filePath)
}

// ─── Plain Text Extraction ────────────────────────────────────────────────────

// ExtractFromTXT reads a plain text file directly (no OCR needed).
func (s *Service) ExtractFromTXT(ctx context.Context, filePath string) (*ExtractResult, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("read text file: %w", err)
	}

	text := string(data)
	return &ExtractResult{
		Text:       cleanText(text),
		PageCount:  estimatePageCount(text),
		WordCount:  countWords(text),
		Language:   s.cfg.Lang,
		Confidence: 100.0,
		Duration:   0,
	}, nil
}

// ─── Smart Router ─────────────────────────────────────────────────────────────

// ExtractText is the main entry point — routes to the correct extractor
// based on file extension, no OCR for digital text files.
func (s *Service) ExtractText(ctx context.Context, filePath string) (*ExtractResult, error) {
	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(filePath), "."))

	switch ext {
	case "txt":
		return s.ExtractFromTXT(ctx, filePath)
	case "docx", "doc":
		return s.ExtractFromDOCX(ctx, filePath)
	case "pdf":
		// First try to extract digital text from PDF (faster, more accurate)
		if text, err := extractDigitalPDFText(filePath); err == nil && len(text) > 100 {
			wc := countWords(text)
			return &ExtractResult{
				Text:       cleanText(text),
				PageCount:  estimatePageCount(text),
				WordCount:  wc,
				Language:   s.cfg.Lang,
				Confidence: 100.0,
			}, nil
		}
		// Fall back to OCR for scanned PDFs
		return s.extractFromPDF(ctx, filePath)
	default:
		return s.ExtractFromFile(ctx, filePath)
	}
}

// extractDigitalPDFText tries to extract selectable text from a PDF (not scanned).
// Uses pdftotext from poppler-utils.
func extractDigitalPDFText(filePath string) (string, error) {
	cmd := exec.Command("pdftotext", "-layout", filePath, "-")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// cleanText normalises whitespace and removes non-printable characters.
func cleanText(text string) string {
	// Remove non-printable characters except newlines and tabs
	text = strings.Map(func(r rune) rune {
		if unicode.IsPrint(r) || r == '\n' || r == '\t' {
			return r
		}
		return -1
	}, text)

	// Collapse multiple blank lines into at most two
	for strings.Contains(text, "\n\n\n") {
		text = strings.ReplaceAll(text, "\n\n\n", "\n\n")
	}

	// Collapse multiple spaces
	for strings.Contains(text, "  ") {
		text = strings.ReplaceAll(text, "  ", " ")
	}

	return strings.TrimSpace(text)
}

func countWords(text string) int {
	if text == "" {
		return 0
	}
	return len(strings.Fields(text))
}

// estimatePageCount estimates page count based on ~500 words per page.
func estimatePageCount(text string) int {
	wc := countWords(text)
	pages := wc / 500
	if pages == 0 {
		return 1
	}
	return pages
}

// IsOCRAvailable checks if Tesseract is installed and working.
func IsOCRAvailable() bool {
	cmd := exec.Command("tesseract", "--version")
	return cmd.Run() == nil
}

// IsPDFToolsAvailable checks if poppler-utils (pdftoppm, pdftotext) are installed.
func IsPDFToolsAvailable() bool {
	return exec.Command("pdftoppm", "-v").Run() == nil ||
		exec.Command("pdftotext", "-v").Run() == nil
}







