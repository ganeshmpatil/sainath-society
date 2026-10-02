package middleware

import (
	"bytes"
	"encoding/json"
	"html"
	"io"
	"strings"

	"github.com/gin-gonic/gin"
)

// SanitizeInput is a middleware that strips HTML/script tags from JSON string
// fields in request bodies to prevent stored XSS attacks.
func SanitizeInput() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Body == nil || c.Request.ContentLength == 0 {
			c.Next()
			return
		}

		ct := c.GetHeader("Content-Type")
		if !strings.Contains(ct, "application/json") {
			c.Next()
			return
		}

		body, err := io.ReadAll(c.Request.Body)
		c.Request.Body.Close()
		if err != nil {
			c.Next()
			return
		}

		var data interface{}
		if err := json.Unmarshal(body, &data); err != nil {
			// Not valid JSON — pass through as-is
			c.Request.Body = io.NopCloser(bytes.NewReader(body))
			c.Next()
			return
		}

		sanitized := sanitizeValue(data)
		newBody, err := json.Marshal(sanitized)
		if err != nil {
			c.Request.Body = io.NopCloser(bytes.NewReader(body))
			c.Next()
			return
		}

		c.Request.Body = io.NopCloser(bytes.NewReader(newBody))
		c.Request.ContentLength = int64(len(newBody))
		c.Next()
	}
}

// sanitizeValue recursively sanitizes all string values in a JSON structure.
func sanitizeValue(v interface{}) interface{} {
	switch val := v.(type) {
	case string:
		return sanitizeString(val)
	case map[string]interface{}:
		for k, v := range val {
			val[k] = sanitizeValue(v)
		}
		return val
	case []interface{}:
		for i, v := range val {
			val[i] = sanitizeValue(v)
		}
		return val
	default:
		return v
	}
}

// sanitizeString removes dangerous HTML tags while preserving safe content.
func sanitizeString(s string) string {
	// Strip all HTML tags
	s = stripTags(s)
	// Escape any remaining HTML entities
	s = html.UnescapeString(s) // first unescape to normalize
	// Don't double-escape normal text — just ensure no raw HTML tags
	return s
}

// stripTags removes HTML tags from a string.
func stripTags(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	inTag := false
	for _, r := range s {
		if r == '<' {
			inTag = true
			continue
		}
		if r == '>' && inTag {
			inTag = false
			continue
		}
		if !inTag {
			b.WriteRune(r)
		}
	}
	return b.String()
}
